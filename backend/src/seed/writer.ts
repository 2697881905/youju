// 唯一碰数据库的一层。
//
// 三个原则：
//   1) 种子数据可识别：作者 openId 一律以 seed_coldstart_ 开头，除此之外不靠任何标记列，
//      也不改 schema。回滚只按这个前缀找人，再按人名下清帖。
//   2) 幂等：帖子按 (作者, 标题) 判重，重复跑只跳过不重复插入。
//   3) 计数对齐生产口径：Tag.useCount / followCount 用真实行重算，
//      commentCount 用实际评论行数回填，不做「看起来更好」的注水。

import { Prisma } from '@prisma/client';
import { prisma } from '../prisma';
import { recomputeActiveScores } from '../services/tagService';
import { CIRCLE_CATALOG } from './catalog';
import { PlannedPost } from './planner';
import { SeedAuthorRecord } from './types';

export const SEED_OPENID_PREFIX = 'seed_coldstart_';

export interface Logger {
  (message: string): void;
}

export interface WriteResult {
  created: number;
  skipped: number;
  comments: number;
}

function authorOpenId(slug: string): string {
  return `${SEED_OPENID_PREFIX}${slug}`;
}

export async function upsertAuthors(
  authors: SeedAuthorRecord[],
  usedSlugs: Set<string>,
  now: Date,
  log: Logger,
): Promise<Map<string, number>> {
  const map = new Map<string, number>();
  for (const author of authors) {
    if (!usedSlugs.has(author.slug)) continue;
    // 账号建得比最早一条帖子更早，避免出现「先发帖后注册」的时间倒挂
    const createdDayOffset = 210 + (author.slug.length * 7) % 260;
    const createdAt = new Date(now.getTime() - createdDayOffset * 86400000);
    const user = await prisma.user.upsert({
      where: { openId: authorOpenId(author.slug) },
      update: {
        nickname: author.nickname,
        bio: author.bio,
        gender: author.gender,
      },
      create: {
        openId: authorOpenId(author.slug),
        nickname: author.nickname,
        bio: author.bio,
        gender: author.gender,
        avatar: `cos://avatars/seed/${author.slug}.png`,
        status: 1,
        createdAt,
        updatedAt: createdAt,
      },
    });
    map.set(author.slug, user.id);

    for (const circle of author.circles) {
      await prisma.userFollowTag.upsert({
        where: { userId_tagName: { userId: user.id, tagName: circle } },
        update: {},
        create: { userId: user.id, tagName: circle },
      });
    }
  }
  log(`作者就绪 ${map.size} 人`);
  return map;
}

function postCreateData(item: PlannedPost, userId: number): Prisma.PostUncheckedCreateInput {
  const record = item.record;
  return {
    userId,
    title: record.title,
    content: record.content,
    coverImage: item.coverImage,
    videoUrl: null,
    videoCover: null,
    videoAspectRatio: null,
    images: [] as Prisma.InputJsonValue,
    genre: record.genre,
    tags: record.tags as Prisma.InputJsonValue,
    structuredData: item.derived.structuredData as Prisma.InputJsonValue,
    structuredDocument: item.derived.structuredDocument === null
      ? Prisma.DbNull
      : (item.derived.structuredDocument as unknown as Prisma.InputJsonValue),
    structuredSearchText: item.derived.structuredSearchText,
    metricValue: item.derived.metric.metricValue,
    metricKind: item.derived.metric.metricKind,
    metricLabel: item.derived.metric.metricLabel,
    metricText: item.derived.metric.metricText,
    mentions: Prisma.DbNull,
    upCount: item.ups,
    bookmarkCount: item.bookmarks,
    commentCount: item.comments.length,
    viewCount: item.views,
    hotScore: item.hotScore,
    planAVotes: record.genre === 'debate' ? item.planAVotes : 0,
    planBVotes: record.genre === 'debate' ? item.planBVotes : 0,
    status: 1,
    reportCount: 0,
    createdAt: item.createdAt,
    updatedAt: item.updatedAt,
  };
}

async function writeOne(item: PlannedPost, userId: number, commentUserIds: Map<string, number>, update: boolean): Promise<'created' | 'skipped' | 'updated'> {
  const existing = await prisma.post.findFirst({
    where: { userId, title: item.record.title },
    select: { id: true },
  });

  if (existing && !update) return 'skipped';

  if (existing) {
    await prisma.post.update({
      where: { id: existing.id },
      data: {
        content: item.record.content,
        coverImage: item.coverImage,
        genre: item.record.genre,
        tags: item.record.tags as Prisma.InputJsonValue,
        structuredData: item.derived.structuredData as Prisma.InputJsonValue,
        structuredDocument: item.derived.structuredDocument === null
          ? Prisma.DbNull
          : (item.derived.structuredDocument as unknown as Prisma.InputJsonValue),
        structuredSearchText: item.derived.structuredSearchText,
        metricValue: item.derived.metric.metricValue,
        metricKind: item.derived.metric.metricKind,
        metricLabel: item.derived.metric.metricLabel,
        metricText: item.derived.metric.metricText,
        updatedAt: new Date(),
      },
    });
    return 'updated';
  }

  await prisma.$transaction(async (tx) => {
    const post = await tx.post.create({ data: postCreateData(item, userId) });
    const createdIds: number[] = [];
    for (let index = 0; index < item.comments.length; index += 1) {
      const comment = item.comments[index];
      const commentUserId = commentUserIds.get(comment.authorSlug);
      if (commentUserId === undefined) {
        throw new Error(`评论作者 ${comment.authorSlug} 缺少账号（帖子 ${item.record.id}）`);
      }
      const parentId = comment.parentIndex === null ? 0 : createdIds[comment.parentIndex];
      const row = await tx.comment.create({
        data: {
          postId: post.id,
          userId: commentUserId,
          parentId: parentId ?? 0,
          content: comment.text,
          isFact: comment.isFact,
          status: 1,
          upCount: comment.upCount,
          createdAt: comment.createdAt,
          updatedAt: comment.createdAt,
        },
      });
      createdIds.push(row.id);
    }
    await tx.post.update({
      where: { id: post.id },
      data: { commentCount: createdIds.length },
    });
  });
  return 'created';
}

export async function writePosts(
  plan: PlannedPost[],
  userMap: Map<string, number>,
  options: { update: boolean; log: Logger },
): Promise<WriteResult> {
  let created = 0;
  let skipped = 0;
  let comments = 0;
  for (let index = 0; index < plan.length; index += 1) {
    const item = plan[index];
    const userId = userMap.get(item.record.author);
    if (userId === undefined) {
      throw new Error(`作者 ${item.record.author} 没有账号（帖子 ${item.record.id}）`);
    }
    const result = await writeOne(item, userId, userMap, options.update);
    if (result === 'created') {
      created += 1;
      comments += item.comments.length;
    } else if (result === 'skipped') {
      skipped += 1;
    }
    if ((index + 1) % 25 === 0) {
      options.log(`进度 ${index + 1}/${plan.length}`);
    }
  }
  return { created, skipped, comments };
}

/** 圈子计数按真实行重算。useCount 语义是「被多少条已发布帖子用到」。 */
export async function recountTags(log: Logger): Promise<void> {
  for (const entry of CIRCLE_CATALOG) {
    const useCount = await prisma.post.count({
      where: {
        status: 1,
        deletedAt: null,
        tags: { array_contains: entry.name },
      },
    });
    const followCount = await prisma.userFollowTag.count({ where: { tagName: entry.name } });
    await prisma.tag.updateMany({
      where: { name: entry.name },
      data: { useCount, followCount },
    });
  }
  const refreshed = await recomputeActiveScores();
  log(`圈子计数已重算，星等刷新 ${refreshed} 个`);
}

export interface WipeSummary {
  users: number;
  posts: number;
  comments: number;
}

export async function wipeSeedData(apply: boolean, log: Logger): Promise<WipeSummary> {
  const users = await prisma.user.findMany({
    where: { openId: { startsWith: SEED_OPENID_PREFIX } },
    select: { id: true, nickname: true },
  });
  const userIds = users.map((user) => user.id);
  const summary: WipeSummary = { users: users.length, posts: 0, comments: 0 };
  if (userIds.length === 0) {
    log('没有找到种子账号，无需清理');
    return summary;
  }
  const posts = await prisma.post.findMany({ where: { userId: { in: userIds } }, select: { id: true } });
  const postIds = posts.map((post) => post.id);
  const comments = postIds.length > 0
    ? await prisma.comment.findMany({ where: { postId: { in: postIds } }, select: { id: true } })
    : [];
  const commentIds = comments.map((comment) => comment.id);
  summary.posts = postIds.length;
  summary.comments = commentIds.length;

  log(`将删除 ${summary.users} 个账号、${summary.posts} 条帖子、${summary.comments} 条评论`);
  if (!apply) return summary;

  if (commentIds.length > 0) {
    await prisma.commentUp.deleteMany({ where: { commentId: { in: commentIds } } });
  }
  if (postIds.length > 0) {
    await prisma.report.deleteMany({ where: { targetType: 'post', targetId: { in: postIds } } });
    await prisma.postEvent.deleteMany({ where: { postId: { in: postIds } } });
    await prisma.debateVote.deleteMany({ where: { postId: { in: postIds } } });
    await prisma.notification.deleteMany({ where: { postId: { in: postIds } } });
    // Comment / Up / Bookmark 对 Post 是级联删除，直接删帖即可
    await prisma.post.deleteMany({ where: { id: { in: postIds } } });
  }
  if (commentIds.length > 0) {
    await prisma.report.deleteMany({ where: { targetType: 'comment', targetId: { in: commentIds } } });
  }
  await prisma.userFollowTag.deleteMany({ where: { userId: { in: userIds } } });
  await prisma.userTagPref.deleteMany({ where: { userId: { in: userIds } } });
  await prisma.userTagRead.deleteMany({ where: { userId: { in: userIds } } });
  await prisma.searchHistory.deleteMany({ where: { userId: { in: userIds } } });
  await prisma.blocklist.deleteMany({ where: { userId: { in: userIds } } });
  await prisma.dislike.deleteMany({ where: { userId: { in: userIds } } });
  await prisma.message.deleteMany({ where: { senderId: { in: userIds } } });
  await prisma.user.deleteMany({ where: { id: { in: userIds } } });
  log('清理完成，下面重算圈子计数');
  await recountTags(log);
  return summary;
}

export interface VerifyResult {
  seedPosts: number;
  commentCountMismatch: number;
  metricMissing: number;
  coverMissing: number;
  duplicateTitles: number;
}

export async function verifySeedData(): Promise<VerifyResult> {
  const users = await prisma.user.findMany({
    where: { openId: { startsWith: SEED_OPENID_PREFIX } },
    select: { id: true },
  });
  const userIds = users.map((user) => user.id);
  if (userIds.length === 0) {
    return { seedPosts: 0, commentCountMismatch: 0, metricMissing: 0, coverMissing: 0, duplicateTitles: 0 };
  }
  const posts = await prisma.post.findMany({
    where: { userId: { in: userIds } },
    select: { id: true, title: true, genre: true, commentCount: true, coverImage: true, metricValue: true },
  });
  const actualComments = await prisma.comment.groupBy({
    by: ['postId'],
    where: { postId: { in: posts.map((post) => post.id) } },
    _count: { _all: true },
  });
  const commentMap = new Map(actualComments.map((row) => [row.postId, row._count._all]));
  const titleSet = new Set<string>();
  let duplicateTitles = 0;
  for (const post of posts) {
    if (titleSet.has(post.title)) duplicateTitles += 1;
    titleSet.add(post.title);
  }
  return {
    seedPosts: posts.length,
    commentCountMismatch: posts.filter((post) => (commentMap.get(post.id) ?? 0) !== post.commentCount).length,
    metricMissing: posts.filter((post) => (post.genre === 'review' || post.genre === 'debate') && post.metricValue === null).length,
    coverMissing: posts.filter((post) => post.coverImage !== null && !post.coverImage.startsWith('cos://posts/seed/')).length,
    duplicateTitles,
  };
}
