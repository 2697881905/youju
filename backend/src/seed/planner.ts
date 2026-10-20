// 时间、互动、媒体 key 的规划层。
//
// 这一层不碰数据库，只把「作者写的文字」变成「一条可以落库的帖子」：
// 发布时间、点赞/收藏/浏览、评论时间、封面 key、热度分，全在这里算完。
// 好处是 dry-run 可以把整批数据摊开给人看，写库前就能判断首屏够不够好看。

import { computeHotScore } from '../utils/hotScore';
import { CIRCLE_BY_NAME, CIRCLE_CATALOG, themeForCircle } from './catalog';
import { DerivedContent, deriveContent } from './derive';
import { rngFor } from './rng';
import { LoadedContent, SeedPostRecord, SeedTier } from './types';

export interface PlannedComment {
  authorSlug: string;
  text: string;
  isFact: number;
  upCount: number;
  createdAt: Date;
  parentIndex: number | null;
}

export interface PlannedPost {
  record: SeedPostRecord;
  circleName: string;
  createdAt: Date;
  updatedAt: Date;
  coverImage: string | null;
  ups: number;
  bookmarks: number;
  views: number;
  hotScore: number;
  planAVotes: number;
  planBVotes: number;
  derived: DerivedContent;
  comments: PlannedComment[];
}

interface TierRange {
  ups: [number, number];
  bookmarks: [number, number];
  views: [number, number];
}

const TIER_STATS: Record<SeedTier, TierRange> = {
  hero: { ups: [180, 420], bookmarks: [40, 120], views: [2500, 9000] },
  solid: { ups: [40, 110], bookmarks: [8, 40], views: [600, 2600] },
  normal: { ups: [8, 40], bookmarks: [2, 12], views: [120, 800] },
  tail: { ups: [0, 9], bookmarks: [0, 4], views: [30, 200] },
};

const POSTER_STYLES: Array<'paper' | 'film' | 'kraft' | 'sticky'> = ['paper', 'film', 'kraft', 'sticky'];

function coverFor(post: SeedPostRecord): string | null {
  // 无图短帖在信息流里会退化成纯文字卡。留一小部分不放封面，是为了让双列瀑布流
  // 有长短差；比例压得很低，且只给分享体裁的短帖，首屏不会出现。
  const rng = rngFor(`${post.id}:cover`);
  const shortShare = post.genre === 'share' && Array.from(post.content).length < 240;
  if (shortShare && post.tier !== 'hero' && rng.chance(0.16)) {
    return null;
  }
  return `cos://posts/seed/${post.id}.jpg`;
}

function planComments(post: SeedPostRecord, createdAt: Date, now: Date): PlannedComment[] {
  const list = post.comments ?? [];
  const out: PlannedComment[] = [];
  list.forEach((comment, index) => {
    const rng = rngFor(`${post.id}:comment:${index}`);
    const offset = comment.offsetMinutes ?? rng.int(8, Math.max(9, Math.floor(post.ageHours * 60) - 5));
    const time = new Date(createdAt.getTime() + offset * 60000);
    const safeTime = time.getTime() > now.getTime() - 120000
      ? new Date(now.getTime() - 120000 - index * 60000)
      : time;
    out.push({
      authorSlug: comment.author,
      text: comment.text,
      isFact: comment.isFact ?? 0,
      upCount: comment.upCount ?? rng.int(0, 12),
      createdAt: safeTime,
      parentIndex: comment.replyToIndex ?? null,
    });
  });
  return out;
}

function createdAtFor(post: SeedPostRecord, now: Date): Date {
  const rng = rngFor(`${post.id}:time`);
  const jitter = rng.float(-0.08, 0.08) * post.ageHours;
  const hours = Math.max(0.2, post.ageHours + jitter);
  const date = new Date(now.getTime() - hours * 3600000);
  // 发布时间精确到分钟，避免出现 03:17:42 这种一看就是脚本写的秒
  date.setSeconds(0, 0);
  return date;
}

export function planContent(content: LoadedContent, now: Date = new Date()): PlannedPost[] {
  const planned: PlannedPost[] = [];
  for (const post of content.posts) {
    const circleName = content.circleOfPost.get(post.id) ?? '';
    const entry = CIRCLE_BY_NAME.get(circleName);
    if (!entry) throw new Error(`帖子 ${post.id} 的圈子 ${circleName} 不存在`);

    const createdAt = createdAtFor(post, now);
    const rng = rngFor(`${post.id}:stats`);
    const range = TIER_STATS[post.tier];
    const ups = rng.int(range.ups[0], range.ups[1]);
    const bookmarks = rng.int(range.bookmarks[0], range.bookmarks[1]);
    const views = Math.max(ups + 30, rng.int(range.views[0], range.views[1]));
    const comments = planComments(post, createdAt, now);
    const hotScore = computeHotScore(ups, comments.length, bookmarks, views, createdAt, now);

    const voteTotal = rng.int(40, 260);
    const planAVotes = post.planAVotes ?? Math.floor(voteTotal * rng.float(0.3, 0.7));
    const planBVotes = post.planBVotes ?? voteTotal - planAVotes;

    planned.push({
      record: post,
      circleName,
      createdAt,
      updatedAt: createdAt,
      coverImage: coverFor(post),
      ups,
      bookmarks,
      views,
      hotScore,
      planAVotes,
      planBVotes,
      derived: deriveContent(post, circleName),
      comments,
    });
  }
  return planned;
}

export interface PlanReport {
  total: number;
  byCircle: Array<{ circle: string; count: number; within72h: number; within7d: number }>;
  byGenre: Array<{ genre: string; count: number }>;
  topPosts: Array<{ id: string; title: string; tier: string; hotScore: number }>;
}

export function summarize(plan: PlannedPost[]): PlanReport {
  const byCircle = new Map<string, { count: number; within72h: number; within7d: number }>();
  const byGenre = new Map<string, number>();
  for (const item of plan) {
    const ageHours = (Date.now() - item.createdAt.getTime()) / 3600000;
    const bucket = byCircle.get(item.circleName) ?? { count: 0, within72h: 0, within7d: 0 };
    bucket.count += 1;
    if (ageHours <= 72) bucket.within72h += 1;
    if (ageHours <= 168) bucket.within7d += 1;
    byCircle.set(item.circleName, bucket);
    byGenre.set(item.record.genre, (byGenre.get(item.record.genre) ?? 0) + 1);
  }
  const topPosts = plan
    .slice()
    .sort((a, b) => b.hotScore - a.hotScore)
    .slice(0, 10)
    .map((item) => ({ id: item.record.id, title: item.record.title, tier: item.record.tier, hotScore: item.hotScore }));
  return {
    total: plan.length,
    byCircle: CIRCLE_CATALOG.map((entry) => ({
      circle: entry.name,
      ...(byCircle.get(entry.name) ?? { count: 0, within72h: 0, within7d: 0 }),
    })),
    byGenre: Array.from(byGenre.entries()).map(([genre, count]) => ({ genre, count })),
    topPosts,
  };
}

/**
 * 排序与新鲜度断言。这几条不满足就不要写库——冷启动最怕首屏难看，
 * 而「难看」在数字上是可判定的：热榜前十必须全是 hero 档，每个圈子近三天得有新帖。
 */
export function assertPlan(plan: PlannedPost[]): string[] {
  const failures: string[] = [];
  const hero = plan.filter((item) => item.record.tier === 'hero');
  const solid = plan.filter((item) => item.record.tier === 'solid');

  if (hero.length === 0) {
    failures.push('没有任何 hero 档帖子，首屏会由旧内容占据');
  } else if (solid.length > 0) {
    const minHero = Math.min(...hero.map((item) => item.hotScore));
    const maxSolid = Math.max(...solid.map((item) => item.hotScore));
    if (minHero <= maxSolid + 8) {
      failures.push(`hero 最低分 ${minHero.toFixed(1)} 未明显高于 solid 最高分 ${maxSolid.toFixed(1)}，热榜前十会被稀释`);
    }
  }

  for (const circle of CIRCLE_CATALOG) {
    const items = plan.filter((item) => item.circleName === circle.name);
    const within72 = items.filter((item) => item.record.ageHours <= 72).length;
    const within7d = items.filter((item) => item.record.ageHours <= 168).length;
    if (items.length !== circle.targetPosts) {
      failures.push(`${circle.name} 计划 ${items.length} 条，目标是 ${circle.targetPosts} 条`);
    }
    if (within72 < 1) failures.push(`${circle.name} 近 72 小时没有新帖`);
    if (within7d < 2) failures.push(`${circle.name} 近 7 天少于 2 条`);
  }

  const heroCircles = new Set(hero.map((item) => item.circleName));
  const heroGenres = new Set(hero.map((item) => item.record.genre));
  if (heroCircles.size < 6) failures.push(`hero 只覆盖 ${heroCircles.size} 个圈子，至少 6 个`);
  if (heroGenres.size < 3) failures.push(`hero 只覆盖 ${heroGenres.size} 种体裁，至少 3 种`);

  return failures;
}

export function plannedMediaKeys(plan: PlannedPost[]): string[] {
  return plan
    .filter((item) => item.coverImage !== null)
    .map((item) => String(item.coverImage).replace('cos://', ''));
}

export { themeForCircle };
