/**
 * 每日一贴推荐算法离线评估脚本（AUC / NDCG@10 / Recall@10）
 *
 * 用法：
 *   npm run eval:daily
 *   npx tsx scripts/eval-daily-recommendation.ts --users=200 --seed=42 --days=30 --max-neg=20
 *
 * 方法（对齐交付报告 §3 离线评估方案）：
 * - 按时间切分，严禁随机切分：画像窗口为 [now-days, asOf]，测试标签窗口为 [asOf, now]，
 *   画像构建使用固定截止时刻 asOf，不含测试窗口信息 → 无未来信息泄漏。
 * - 正例：测试窗口内用户对帖子的任一正向行为（up/bookmark/comment/debateVote/click）。
 * - 负例：优先取「曝光过但无任何正向行为」的帖子（PostEvent action=expose）；
 *   当前曝光数据量不足时降级为随机负例，并在输出中明确标注（此时指标仅具参考性）。
 * - 对照组（control）= 全局热度排序（Post.hotScore desc，即改造前信号）；
 *   实验组（treatment）= 线上个性化打分（复用 dailyScoreService，评估的就是真实算法）。
 * - 固定随机种子保证可复现；输出同时附数据区间与种子，便于归档对比。
 */
import { prisma } from '../src/prisma';
import {
  buildViewerProfile,
  computeDailyScore,
  shanghaiDayStart,
  ViewerProfile,
} from '../src/services/dailyScoreService';

interface EvalOptions {
  users: number;      // 参与评估的用户数上限（采样）
  seed: number;       // 随机种子（可复现）
  days: number;       // 画像窗口天数（测试窗口为其后一周）
  maxNegPerUser: number; // 每用户负例上限
}

function parseArgs(): EvalOptions {
  const opts: EvalOptions = { users: 200, seed: 42, days: 30, maxNegPerUser: 20 };
  for (const arg of process.argv.slice(2)) {
    const m = /^--([a-z-]+)=(.+)$/.exec(arg);
    if (!m) continue;
    const key = m[1];
    const value = Number(m[2]);
    if (!Number.isFinite(value)) continue;
    if (key === 'users') opts.users = Math.max(1, Math.floor(value));
    if (key === 'seed') opts.seed = Math.floor(value);
    if (key === 'days') opts.days = Math.max(7, Math.floor(value));
    if (key === 'max-neg') opts.maxNegPerUser = Math.max(1, Math.floor(value));
  }
  return opts;
}

// 可复现伪随机（mulberry32）：同一 seed 产生同一序列
function mulberry32(seed: number): () => number {
  let a = seed >>> 0;
  return (): number => {
    a = (a + 0x6D2B79F5) >>> 0;
    let t = a;
    t = Math.imul(t ^ (t >>> 15), t | 1);
    t ^= t + Math.imul(t ^ (t >>> 7), t | 61);
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}

function seededSample<T>(items: T[], count: number, rand: () => number): T[] {
  const pool = items.slice();
  for (let i = pool.length - 1; i > 0; i -= 1) {
    const j = Math.floor(rand() * (i + 1));
    const tmp = pool[i];
    pool[i] = pool[j];
    pool[j] = tmp;
  }
  return pool.slice(0, Math.min(count, pool.length));
}

const DAY_MS = 86400000;
const POS_ACTIONS = ['up', 'bookmark', 'comment', 'debateVote', 'click'] as const;

interface ScoredPost {
  id: number;
  userId: number;
  tags: unknown;
  hotScore: number;
  createdAt: Date;
}

interface UserEval {
  positives: number;
  negatives: number;
  control: { auc: number; ndcg: number; recall: number } | null;
  treatment: { auc: number; ndcg: number; recall: number } | null;
}

/** 单用户一组的排序质量指标 */
function rankMetrics(scores: Array<{ id: number; score: number }>, positives: Set<number>): {
  auc: number;
  ndcg: number;
  recall: number;
} {
  const ranked = scores.slice().sort((a, b) => b.score - a.score);
  const posScores: number[] = [];
  const negScores: number[] = [];
  for (const item of scores) {
    (positives.has(item.id) ? posScores : negScores).push(item.score);
  }
  // AUC：正例得分高于负例的比例（并列计 0.5）
  let wins = 0;
  let pairs = 0;
  for (const p of posScores) {
    for (const n of negScores) {
      pairs += 1;
      wins += p > n ? 1 : p === n ? 0.5 : 0;
    }
  }
  const auc = pairs > 0 ? wins / pairs : 0.5;
  // NDCG@10（正例相关度 1、负例 0）
  const k = Math.min(10, ranked.length);
  let dcg = 0;
  for (let i = 1; i <= k; i += 1) {
    dcg += (positives.has(ranked[i - 1].id) ? 1 : 0) / Math.log2(i + 1);
  }
  const idealPos = Math.min(positives.size, 10);
  let idcg = 0;
  for (let i = 1; i <= idealPos; i += 1) {
    idcg += 1 / Math.log2(i + 1);
  }
  const ndcg = idcg > 0 ? dcg / idcg : 0;
  // Recall@10
  let hits = 0;
  for (let i = 0; i < k; i += 1) {
    if (positives.has(ranked[i].id)) hits += 1;
  }
  const recall = positives.size > 0 ? hits / positives.size : 0;
  return { auc, ndcg, recall };
}

function mean(values: number[]): number {
  if (values.length === 0) return 0;
  return values.reduce((sum, v) => sum + v, 0) / values.length;
}

async function main(): Promise<void> {
  const opts = parseArgs();
  const rand = mulberry32(opts.seed);
  const now = new Date();
  const asOf = shanghaiDayStart(new Date(now.getTime() - 7 * DAY_MS)); // 测试窗口起点（画像截止）
  const since = new Date(now.getTime() - opts.days * DAY_MS);

  console.log('=== 每日一贴离线评估 ===');
  console.log('数据区间：画像窗口 ' + since.toISOString().slice(0, 10) + ' ~ ' + asOf.toISOString().slice(0, 10)
    + '，测试窗口 ' + asOf.toISOString().slice(0, 10) + ' ~ ' + now.toISOString().slice(0, 10));
  console.log('参数：users=' + opts.users + ' seed=' + opts.seed + ' days=' + opts.days + ' maxNegPerUser=' + opts.maxNegPerUser);

  // 1) 找出有行为的用户（任一正向动作表，近 days 天）
  const [ups, bookmarks, comments, votes, clicks] = await Promise.all([
    prisma.up.findMany({ where: { createdAt: { gte: since } }, select: { userId: true } }),
    prisma.bookmark.findMany({ where: { createdAt: { gte: since } }, select: { userId: true } }),
    prisma.comment.findMany({ where: { createdAt: { gte: since }, status: 1 }, select: { userId: true } }),
    prisma.debateVote.findMany({ where: { createdAt: { gte: since } }, select: { userId: true } }),
    prisma.postEvent.findMany({
      where: { createdAt: { gte: since }, action: 'click', userId: { not: null } },
      select: { userId: true },
    }),
  ]);
  const activeUsers = new Set<number>();
  for (const rows of [ups, bookmarks, comments, votes, clicks]) {
    for (const row of rows) {
      if (row.userId != null) activeUsers.add(row.userId);
    }
  }
  if (activeUsers.size === 0) {
    console.log('\n[警告] 评估区间内没有任何用户行为数据，无法评估。');
    console.log('说明：应用尚未产生真实互动（未上架/灰度前属预期）。建议上线积累 2 周行为数据后再跑本脚本。');
    await prisma.$disconnect();
    return;
  }

  // 2) 测试窗口标签：正向行为 → 正例；曝光未正向 → 负例（不足则随机补足）
  const [testUps, testBookmarks, testComments, testVotes, testClicks, testExposes] = await Promise.all([
    prisma.up.findMany({ where: { createdAt: { gte: asOf } }, select: { userId: true, postId: true } }),
    prisma.bookmark.findMany({ where: { createdAt: { gte: asOf } }, select: { userId: true, postId: true } }),
    prisma.comment.findMany({ where: { createdAt: { gte: asOf }, status: 1 }, select: { userId: true, postId: true } }),
    prisma.debateVote.findMany({ where: { createdAt: { gte: asOf } }, select: { userId: true, postId: true } }),
    prisma.postEvent.findMany({
      where: { createdAt: { gte: asOf }, action: 'click', userId: { not: null } },
      select: { userId: true, postId: true },
    }),
    prisma.postEvent.findMany({
      where: { createdAt: { gte: asOf }, action: 'expose', userId: { not: null } },
      select: { userId: true, postId: true },
      take: 200000,
    }),
  ]);

  const positivesByUser = new Map<number, Set<number>>();
  for (const rows of [testUps, testBookmarks, testComments, testVotes, testClicks]) {
    for (const row of rows) {
      if (row.userId == null) continue;
      const set = positivesByUser.get(row.userId) ?? new Set<number>();
      set.add(row.postId);
      positivesByUser.set(row.userId, set);
    }
  }
  const exposedByUser = new Map<number, Set<number>>();
  for (const row of testExposes) {
    if (row.userId == null) continue;
    const set = exposedByUser.get(row.userId) ?? new Set<number>();
    set.add(row.postId);
    exposedByUser.set(row.userId, set);
  }

  // 3) 采样用户：必须有正例才可评估
  const candidates: number[] = [];
  for (const userId of activeUsers) {
    const pos = positivesByUser.get(userId);
    if (pos !== undefined && pos.size > 0) candidates.push(userId);
  }
  const sampled = seededSample(candidates, opts.users, rand);
  if (sampled.length === 0) {
    console.log('\n[警告] 测试窗口内没有带正例的用户，无法评估。');
    await prisma.$disconnect();
    return;
  }

  // 4) 全量取回涉及帖子的打分字段
  const postIdSet = new Set<number>();
  for (const userId of sampled) {
    for (const postId of positivesByUser.get(userId) ?? []) postIdSet.add(postId);
    for (const postId of exposedByUser.get(userId) ?? []) postIdSet.add(postId);
  }
  const postRows = await prisma.post.findMany({
    where: { id: { in: [...postIdSet] }, status: 1, deletedAt: null },
    select: { id: true, userId: true, tags: true, hotScore: true, createdAt: true },
  });
  const postMap = new Map<number, ScoredPost>();
  for (const row of postRows) {
    postMap.set(row.id, row as ScoredPost);
  }

  // 5) 逐用户评估（画像走线上 buildViewerProfile，截止 asOf，无泄漏）
  const controlAuc: number[] = [];
  const controlNdcg: number[] = [];
  const controlRecall: number[] = [];
  const treatAuc: number[] = [];
  const treatNdcg: number[] = [];
  const treatRecall: number[] = [];
  let randomNegUsers = 0; // 负例来自随机补足的用户数（用于诚实标注数据质量）
  let skipped = 0;

  for (const userId of sampled) {
    const posSet = positivesByUser.get(userId);
    if (posSet === undefined || posSet.size === 0) continue;

    // 负例：曝光过但从未产生正向行为的帖子
    const negCandidates: number[] = [];
    const exposed = exposedByUser.get(userId);
    if (exposed !== undefined) {
      for (const postId of exposed) {
        if (!posSet.has(postId) && postMap.has(postId)) negCandidates.push(postId);
      }
    }
    let usedRandomNeg = false;
    const wantNeg = Math.min(opts.maxNegPerUser, Math.max(4, posSet.size * 4));
    if (negCandidates.length < wantNeg) {
      usedRandomNeg = true;
      const pool: number[] = [];
      for (const id of postMap.keys()) {
        if (!posSet.has(id) && negCandidates.indexOf(id) < 0) pool.push(id);
      }
      const extra = seededSample(pool, wantNeg - negCandidates.length, rand);
      negCandidates.push(...extra);
    }
    if (usedRandomNeg) randomNegUsers += 1;

    const candidateIds = new Set<number>([...posSet, ...negCandidates]);
    const posts: ScoredPost[] = [];
    for (const id of candidateIds) {
      const post = postMap.get(id);
      if (post !== undefined) posts.push(post);
    }
    // 至少 1 正 1 负才有评估意义
    const hasNeg = posts.length > posSet.size;
    if (!hasNeg) {
      skipped += 1;
      continue;
    }

    let profile: ViewerProfile;
    try {
      profile = await buildViewerProfile(userId, asOf);
    } catch {
      skipped += 1;
      continue;
    }

    const controlScores = posts.map((post) => ({ id: post.id, score: post.hotScore }));
    const treatScores = posts.map((post) => ({
      id: post.id,
      score: computeDailyScore(post, profile, asOf),
    }));

    const control = rankMetrics(controlScores, posSet);
    const treatment = rankMetrics(treatScores, posSet);
    controlAuc.push(control.auc);
    controlNdcg.push(control.ndcg);
    controlRecall.push(control.recall);
    treatAuc.push(treatment.auc);
    treatNdcg.push(treatment.ndcg);
    treatRecall.push(treatment.recall);
  }

  // 6) 汇总输出
  const summary = {
    evaluatedUsers: treatAuc.length,
    skippedUsers: skipped,
    randomNegativeUsers: randomNegUsers,
    seed: opts.seed,
    window: { profileFrom: since.toISOString(), profileTo: asOf.toISOString(), testTo: now.toISOString() },
    control: { auc: mean(controlAuc), ndcgAt10: mean(controlNdcg), recallAt10: mean(controlRecall) },
    treatment: { auc: mean(treatAuc), ndcgAt10: mean(treatNdcg), recallAt10: mean(treatRecall) },
  };

  console.log('\n--- 结果（' + treatAuc.length + ' 个用户，跳过 ' + skipped + '）---');
  const fmt = (v: number): string => v.toFixed(4);
  console.log('指标          对照组(hotScore)   实验组(个性化)   提升');
  console.log('AUC           ' + fmt(summary.control.auc) + '            ' + fmt(summary.treatment.auc) + '            '
    + fmt(summary.treatment.auc - summary.control.auc));
  console.log('NDCG@10       ' + fmt(summary.control.ndcgAt10) + '            ' + fmt(summary.treatment.ndcgAt10) + '            '
    + fmt(summary.treatment.ndcgAt10 - summary.control.ndcgAt10));
  console.log('Recall@10     ' + fmt(summary.control.recallAt10) + '            ' + fmt(summary.treatment.recallAt10) + '            '
    + fmt(summary.treatment.recallAt10 - summary.control.recallAt10));
  if (randomNegUsers > 0) {
    const ratio = Math.round((randomNegUsers / Math.max(1, treatAuc.length)) * 100);
    console.log('\n[提示] ' + randomNegUsers + '/' + treatAuc.length + '（' + ratio + '%）用户的负例来自随机补足'
      + '（曝光数据不足）。此时指标仅具参考性，建议曝光埋点积累数据后重跑。');
  }
  console.log('\nJSON：' + JSON.stringify(summary));

  await prisma.$disconnect();
}

main()
  .catch((e) => {
    console.error('[eval] 失败：', (e as Error).message);
    process.exitCode = 1;
  });
