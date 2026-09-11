import { prisma } from '../prisma';

// ===== 每日一贴 · 个性化打分服务 =====
// 设计依据：四成员评审报告 deliverables/gstack/daily-post-recommendation-algo-2026-09-11.md
//
// 三条硬原则：
// 1. 全局热度直接复用 Post.hotScore 列（由 hotScoreService.bumpHotScore 维护），
//    绝不在请求路径调用 computeHotScore —— 避免重复计算，也避免时效被计入两次。
// 2. 打分必须是「日切纯函数」：以 asOf（当日上海零点）为固定截止时刻聚合画像，
//    使同一自然日内多次请求得到完全一致的分数，从而不破坏 listDailyPosts 的
//    「同日分页顺序稳定、跨页不重复」契约。跨日 asOf 变化 → 自然轮换。
// 3. 画像构建失败必须降级为空画像：冷路径永不阻断列表返回（也让单测无需桩全部表）。

/** 偏好漂移半衰期（天）：14 天前产生的行为，权重减半 */
const HALF_LIFE_DAYS = 14;
/** 「极新」短窗加成窗口（小时） */
const FRESH_WINDOW_HOURS = 72;
/** 亲和度归一化尺度（tanh 内） */
const AFF_NORM = 5;
/** 全局热度归一化尺度（tanh 内） */
const HOT_NORM = 30;
/** 单命中一个负反馈标签的惩罚 */
const NEG_TAG_PENALTY = 0.6;
/** 冷启动判定：行为数达到此值才认为信号充足 */
const PERSONALIZED_MIN_ACTIONS = 10;
/** 贝叶斯收缩强度：低活跃用户的有效亲和向大盘收缩，避免 1~2 次行为过拟合 */
const SHRINK_M = 5;
/** 上海时区相对 UTC 的毫秒偏移 */
const SHANGHAI_OFFSET_MS = 8 * 3600 * 1000;

// 行为权重：行为成本越高越可信（收藏 > 顶 > 评论 > 关注 > 搜索命中 > 点击）
const W_FOLLOW = 3;
const W_UP = 5;
const W_BOOKMARK = 6;
const W_COMMENT = 4;
const W_CLICK = 1;
const W_SEARCH_HIT = 2;

/** 打分权重（可调，供 A/B 调参；首轮实验使用默认值做二元对照） */
export interface DailyScoreWeights {
  g: number; // 全局热度
  a: number; // 个性化亲和
  f: number; // 新鲜度
  p: number; // 负反馈惩罚
}

export const DEFAULT_DAILY_WEIGHTS: DailyScoreWeights = { g: 1.0, a: 1.4, f: 0.2, p: 0.8 };

/** 用户偏好画像（由行为聚合而来，日切快照） */
export interface ViewerProfile {
  tagW: Map<string, number>;    // 标签亲和权重
  authorW: Map<string, number>; // 作者亲和权重
  followed: Set<string>;        // 已关注标签（显式兴趣）
  negTags: Set<string>;         // 负反馈标签（来自不喜欢的作者帖标签等）
  actionCount: number;          // 有效行为条数（用于冷启动判定与收缩强度）
}

/** 打分所需的帖子最小字段集（放宽类型，便于单测直接构造） */
export interface ScorablePost {
  id: number;
  userId?: number;
  tags?: unknown;
  hotScore?: unknown;
  createdAt?: unknown;
}

export function emptyProfile(): ViewerProfile {
  return {
    tagW: new Map<string, number>(),
    authorW: new Map<string, number>(),
    followed: new Set<string>(),
    negTags: new Set<string>(),
    actionCount: 0,
  };
}

/** 上海时区当日零点（作为日切快照时刻 / freshness 基准） */
export function shanghaiDayStart(now: Date): Date {
  const parts = new Intl.DateTimeFormat('en-US', {
    timeZone: 'Asia/Shanghai',
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
  }).formatToParts(now);
  const pick = (type: string): string => parts.find((item) => item.type === type)?.value ?? '01';
  const year = Number(pick('year'));
  const month = Number(pick('month'));
  const day = Number(pick('day'));
  // 上海 00:00 等于前一日 UTC 16:00
  return new Date(Date.UTC(year, month - 1, day, 0, 0, 0) - SHANGHAI_OFFSET_MS);
}

function toTags(value: unknown): string[] {
  if (!Array.isArray(value)) {
    return [];
  }
  const out: string[] = [];
  for (const item of value) {
    if (typeof item === 'string' && item.length > 0) {
      out.push(item);
    }
  }
  return out;
}

function toFiniteNumber(value: unknown): number {
  return typeof value === 'number' && Number.isFinite(value) ? value : 0;
}

function ageHours(createdAt: Date, asOf: Date): number {
  return Math.max(0, (asOf.getTime() - createdAt.getTime()) / 3600000);
}

/** 时间衰减系数：0.5 ^ (距 asOf 的天数 / 半衰期) */
function decayFactor(createdAt: Date, asOf: Date): number {
  const days = Math.max(0, (asOf.getTime() - createdAt.getTime()) / 86400000);
  return Math.pow(0.5, days / HALF_LIFE_DAYS);
}

function bump(map: Map<string, number>, key: string, delta: number): void {
  if (!key || delta === 0) {
    return;
  }
  map.set(key, (map.get(key) ?? 0) + delta);
}

interface BehaviorRow {
  createdAt: Date;
  post?: { tags: unknown; userId: number } | null;
}

/** 把一批互动记录累加进画像（标签亲和 + 作者亲和） */
function applyBehaviors(profile: ViewerProfile, rows: BehaviorRow[], weight: number, asOf: Date): void {
  for (const row of rows) {
    const post = row.post;
    if (!post) {
      continue;
    }
    const factor = weight * decayFactor(row.createdAt, asOf);
    for (const tag of toTags(post.tags)) {
      bump(profile.tagW, tag, factor);
    }
    bump(profile.authorW, String(post.userId), factor);
  }
}

/**
 * 构建用户偏好画像（日切快照）。
 * 任意一步失败都降级为空画像 —— 列表接口不因画像不可用而失败。
 */
export async function buildViewerProfile(viewerId: number | undefined, asOf: Date): Promise<ViewerProfile> {
  const profile = emptyProfile();
  if (!viewerId) {
    return profile;
  }
  try {
    const postSelect = { select: { tags: true, userId: true } };
    const [followedTags, ups, bookmarks, comments, votes] = await Promise.all([
      prisma.userFollowTag.findMany({ where: { userId: viewerId }, select: { tagName: true } }),
      prisma.up.findMany({
        where: { userId: viewerId, createdAt: { lte: asOf } },
        select: { createdAt: true, post: postSelect },
      }),
      prisma.bookmark.findMany({
        where: { userId: viewerId, createdAt: { lte: asOf } },
        select: { createdAt: true, post: postSelect },
      }),
      prisma.comment.findMany({
        where: { userId: viewerId, status: 1, createdAt: { lte: asOf } },
        select: { createdAt: true, post: postSelect },
      }),
      prisma.debateVote.findMany({
        where: { userId: viewerId, createdAt: { lte: asOf } },
        // 注意：DebateVote 模型未定义 post 关系，只能取 postId 后再批量回查
        select: { createdAt: true, postId: true },
      }),
    ]);

    // 显式兴趣：关注标签给固定基础权重（不随单条行为衰减）
    for (const row of followedTags) {
      const name = row.tagName;
      if (name && name.length > 0) {
        profile.followed.add(name);
        bump(profile.tagW, name, W_FOLLOW);
      }
    }

    applyBehaviors(profile, ups, W_UP, asOf);
    applyBehaviors(profile, bookmarks, W_BOOKMARK, asOf);
    applyBehaviors(profile, comments, W_COMMENT, asOf);

    // DebateVote 无 post 关系：批量回查帖子标签后再累加
    const votePostIds: number[] = [];
    for (const row of votes) {
      if (!votePostIds.includes(row.postId)) {
        votePostIds.push(row.postId);
      }
    }
    if (votePostIds.length > 0) {
      const votePosts = await prisma.post.findMany({
        where: { id: { in: votePostIds } },
        select: { id: true, tags: true, userId: true },
      });
      const votePostMap = new Map<number, { tags: unknown; userId: number }>();
      for (const post of votePosts) {
        votePostMap.set(post.id, { tags: post.tags, userId: post.userId });
      }
      const voteRows: BehaviorRow[] = [];
      for (const row of votes) {
        const post = votePostMap.get(row.postId);
        if (post) {
          voteRows.push({ createdAt: row.createdAt, post });
        }
      }
      applyBehaviors(profile, voteRows, W_COMMENT, asOf);
    }

    profile.actionCount = ups.length + bookmarks.length + comments.length + votes.length;
    return profile;
  } catch (e) {
    console.warn('[dailyScore] 画像构建降级为空画像：', (e as Error).message);
    return emptyProfile();
  }
}

/**
 * 计算单帖的每日一贴排序分。
 * score = w_g·tanh(hotScore/HOT_NORM) + w_a·tanh(亲和/AFF_NORM) + w_f·新鲜度 − w_p·负反馈
 */
export function computeDailyScore(
  post: ScorablePost,
  profile: ViewerProfile,
  asOf: Date,
  weights: DailyScoreWeights = DEFAULT_DAILY_WEIGHTS,
): number {
  const tags = toTags(post.tags);

  const globalPart = Math.tanh(toFiniteNumber(post.hotScore) / HOT_NORM);

  let affinity = 0;
  const authorKey = post.userId != null ? String(post.userId) : '';
  if (authorKey) {
    affinity += profile.authorW.get(authorKey) ?? 0;
  }
  for (const tag of tags) {
    affinity += profile.tagW.get(tag) ?? 0;
  }
  const affinityPart = Math.tanh(affinity / AFF_NORM);

  const created = post.createdAt instanceof Date ? post.createdAt : null;
  const freshPart = created === null ? 0 : Math.max(0, 1 - ageHours(created, asOf) / FRESH_WINDOW_HOURS);

  let negHits = 0;
  for (const tag of tags) {
    if (profile.negTags.has(tag)) {
      negHits += 1;
    }
  }
  const penaltyPart = NEG_TAG_PENALTY * negHits;

  return weights.g * globalPart + weights.a * affinityPart + weights.f * freshPart - weights.p * penaltyPart;
}

/**
 * 按每日一贴打分为候选池排序（稳定降序）。
 * 同分时保持候选池原序 → 结果确定、可复现（日内多次请求得到同一顺序）。
 * 注意：抽成纯函数以便单测；最终页序还会叠加「按日轮转」，故不可据此断言某帖一定排第一。
 */
export function rankPostsByDailyScore<T extends ScorablePost>(
  rows: T[],
  profile: ViewerProfile,
  asOf: Date,
  weights: DailyScoreWeights = DEFAULT_DAILY_WEIGHTS,
): T[] {
  const scored = rows.map((post, index) => ({
    post,
    index,
    score: computeDailyScore(post, profile, asOf, weights),
  }));
  scored.sort((a, b) => (b.score - a.score) || (a.index - b.index));
  return scored.map((item) => item.post);
}

/** 冷启动档位（用于降级链与分层诊断；注意：非随机分配，不可作 A/B 因果主指标） */
export type ColdStartStage = 'personalized' | 'shrunk' | 'popular' | 'hot';
export function coldStartChain(profile: ViewerProfile, followedCount: number): ColdStartStage {
  if (profile.actionCount >= PERSONALIZED_MIN_ACTIONS) {
    return 'personalized';
  }
  if (profile.actionCount > 0) {
    return 'shrunk'; // 低活跃：向大盘收缩，防 1~2 次行为过拟合
  }
  if (followedCount > 0) {
    return 'popular'; // 有显式标签、无行为
  }
  return 'hot'; // 全冷：退化为全局热度（再由时间兜底）
}

/** 贝叶斯收缩后的有效亲和（低活跃用户向大盘均值收缩，m 为收缩强度） */
export function shrinkAffinity(own: number, population: number, actionCount: number): number {
  const n = Math.max(0, actionCount);
  return (n * own + SHRINK_M * population) / (n + SHRINK_M);
}
