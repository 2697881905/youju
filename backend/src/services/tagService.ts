import { prisma } from '../prisma';
import { Tag } from '@prisma/client';
import { sensitiveWordService } from './sensitiveWordService';
import { ForbiddenError, NotFoundError, SensitiveWordError, ValidationError } from '../utils/errors';
import { SUPPORTED_CITIES, findCity } from '../utils/cities';
import { getExcludedAuthorIds } from './accessControl';

// 星图 Live 三期：分类白名单（与客户端 CIRCLE_META 的五大类一致）
// 「同城」为星图子模式「降落地球」专用类：只服务挂靠城市的圈子，不进星图行星分类。
export const TAG_CATEGORIES: string[] = ['消费选购', '动手改造', '职场与收入', '生活与家庭', '兴趣休闲', '同城'];
export const CITY_CATEGORY = '同城';

// 获取所有标签（按使用次数降序）
export async function listTags() {
  return prisma.tag.findMany({ orderBy: { useCount: 'desc' } });
}

// 深空目录全量：可按关键词过滤（名字/分类/简介），供 GET /v1/tags?all=1&keyword=
export async function searchTags(keyword?: string): Promise<Tag[]> {
  const kw = keyword?.trim();
  const where = kw
    ? {
        OR: [
          { name: { contains: kw } },
          { category: { contains: kw } },
          { description: { contains: kw } },
        ],
      }
    : {};
  return prisma.tag.findMany({ where, orderBy: [{ activeScore: 'desc' }, { followCount: 'desc' }] });
}

// 同城圈列表：挂靠某城市的圈子按活跃度降序（城市页主体数据）。
export async function listCityTags(cityCode: string): Promise<Tag[]> {
  return prisma.tag.findMany({
    where: { cityCode },
    orderBy: [{ activeScore: 'desc' }, { followCount: 'desc' }],
  });
}

export interface CitySummary {
  code: string;
  name: string;
  province: string;
  circleCount: number;
  postCount: number;
  lng: number; // 参考坐标（GCJ-02）：地图选城 marker / 定位反解比对用
  lat: number;
}

// 城市列表（选城页）：白名单全量 + 每城圈子数/帖子数聚合。
// postCount 按发帖所选城市（Post.cityCode）统计；同城圈内容按 tag 过滤，此处只做展示计数。
export async function listCities(): Promise<CitySummary[]> {
  const [circleRows, postRows] = await Promise.all([
    prisma.tag.groupBy({ by: ['cityCode'], where: { cityCode: { not: null } }, _count: { _all: true } }),
    prisma.post.groupBy({ by: ['cityCode'], where: { cityCode: { not: null }, deletedAt: null, status: 1 }, _count: { _all: true } }),
  ]);
  const circleMap = new Map(circleRows.map((r) => [r.cityCode as string, r._count._all]));
  const postMap = new Map(postRows.map((r) => [r.cityCode as string, r._count._all]));
  return SUPPORTED_CITIES.map((c) => ({
    code: c.code,
    name: c.name,
    province: c.province,
    circleCount: circleMap.get(c.code) ?? 0,
    postCount: postMap.get(c.code) ?? 0,
    lng: c.lng,
    lat: c.lat,
  }));
}

// 创建圈子（点亮新星）：名称唯一 + 敏感词 + 分类白名单；创建者自动关注并计入 followCount。
// cityCode 可选：带值 = 同城圈（分类必须为「同城」且城市在白名单内），落 Tag.cityCode。
export async function createTag(
  userId: number,
  name: string,
  category: string,
  description: string,
  cityCode?: string,
): Promise<Tag> {
  const trimmed = name.trim();
  if (trimmed.length < 2 || trimmed.length > 8) {
    throw new ValidationError('圈子名字需 2~8 个字');
  }
  if (!TAG_CATEGORIES.includes(category)) {
    throw new ValidationError('分类无效');
  }
  let city: string | null = null;
  if (cityCode !== undefined && cityCode !== null && cityCode !== '') {
    if (!findCity(cityCode)) {
      throw new ValidationError('暂不支持该城市');
    }
    if (category !== CITY_CATEGORY) {
      throw new ValidationError('同城圈子分类必须为「同城」');
    }
    city = cityCode;
  }
  // 反向校验：「同城」分类必须带城市，否则会建出既不进主星图、也不进任何城市页的孤儿圈。
  if (category === CITY_CATEGORY && city === null) {
    throw new ValidationError('同城圈子需要指定城市');
  }
  const desc = description.trim();
  if (desc.length === 0 || desc.length > 24) {
    throw new ValidationError('一句话简介需 1~24 字');
  }
  if (sensitiveWordService.checkText(trimmed) || sensitiveWordService.checkText(desc)) {
    throw new SensitiveWordError('名称或简介含敏感词');
  }
  const existing = await prisma.tag.findUnique({ where: { name: trimmed } });
  if (existing) {
    throw new ValidationError('已有同名圈子');
  }
  // 建圈 + 创建者自动加入必须在同一个事务里：旧实现先建 Tag 再调 followTag（独立事务），
  // 关注一步失败会留下「圈已建、创建者未加入」的半成品，重试又被重名挡住。
  try {
    const created = await prisma.$transaction(async (tx) => {
      const tag = await tx.tag.create({
        data: {
          name: trimmed,
          category,
          description: desc,
          emoji: '🌟',
          cityCode: city,
          creatorId: userId,
        },
      });
      await tx.userFollowTag.create({ data: { userId, tagName: trimmed } });
      await tx.tag.update({
        where: { name: trimmed },
        data: { followCount: { increment: 1 } },
      });
      return tag;
    });
    return await prisma.tag.findUnique({ where: { name: trimmed } }) ?? created;
  } catch (e) {
    // 并发重名：findUnique 与 create 之间的竞态由唯一索引兜底，映射成与前置校验一致的文案。
    if ((e as { code?: string })?.code === 'P2002') {
      throw new ValidationError('已有同名圈子');
    }
    throw e;
  }
}

// 删除自建圈子（仅创建者 + 仅空圈）：预置/同城圈 creatorId 为 NULL，永远不可删。
// 圈子里已有帖子时拒绝，避免帖子留在 tags 里指向一个不存在的圈子。
export async function deleteTag(userId: number, name: string): Promise<void> {
  const tag = await prisma.tag.findUnique({ where: { name } });
  if (!tag) {
    throw new NotFoundError('圈子不存在');
  }
  if (tag.creatorId === null || tag.creatorId !== userId) {
    throw new ForbiddenError('仅创建者可以删除该圈子');
  }
  const postCount = await prisma.post.count({
    where: { deletedAt: null, tags: { array_contains: name } },
  });
  if (postCount > 0) {
    throw new ValidationError('圈子里已有帖子，不能删除');
  }
  // 关联行一起清掉：关注 / 引力档位 / 已读游标都不允许指向已删除的圈子。
  await prisma.$transaction([
    prisma.userFollowTag.deleteMany({ where: { tagName: name } }),
    prisma.userTagPref.deleteMany({ where: { tagName: name } }),
    prisma.userTagRead.deleteMany({ where: { tagName: name } }),
    prisma.tag.delete({ where: { name } }),
  ]);
}

// 星等刷新：近 14 天发帖按时间衰减累加。activeScore>阈值即亮星。
// 由启动 + 定时 worker 调用；帖子量级小，逐标签 count 可接受。
export async function recomputeActiveScores(): Promise<number> {
  const WINDOW_DAYS = 14;
  const start = new Date(Date.now() - WINDOW_DAYS * 86400000);
  const tags = await prisma.tag.findMany({ select: { name: true } });
  for (const tag of tags) {
    const posts = await prisma.post.findMany({
      where: { deletedAt: null, status: 1, createdAt: { gte: start }, tags: { array_contains: tag.name } },
      select: { createdAt: true },
    });
    let score = 0;
    for (const p of posts) {
      const ageDays = (Date.now() - p.createdAt.getTime()) / 86400000;
      score += Math.exp(-ageDays / 7); // 半衰约 5 天的指数衰减
    }
    await prisma.tag.update({ where: { name: tag.name }, data: { activeScore: Math.round(score * 1000) / 1000 } });
  }
  return tags.length;
}

// 关注标签（幂等）：仅当新建关注时 Tag.followCount + 1，返回更新后的标签
export async function followTag(userId: number, tagName: string): Promise<Tag> {
  await prisma.$transaction(async (tx) => {
    const existing = await tx.userFollowTag.findUnique({
      where: { userId_tagName: { userId, tagName } },
    });
    if (existing) {
      return; // 幂等：已关注，不重复 +1
    }
    await tx.userFollowTag.create({ data: { userId, tagName } });
    await tx.tag.updateMany({
      where: { name: tagName },
      data: { followCount: { increment: 1 } },
    });
  });
  const tag = await prisma.tag.findFirst({ where: { name: tagName } });
  return tag!;
}

// 取消关注标签：仅当存在关注记录时 Tag.followCount - 1，返回更新后的标签
export async function unfollowTag(userId: number, tagName: string): Promise<Tag> {
  await prisma.$transaction(async (tx) => {
    const deleted = await tx.userFollowTag.deleteMany({
      where: { userId, tagName },
    });
    if (deleted.count > 0) {
      await tx.tag.updateMany({
        where: { name: tagName, followCount: { gt: 0 } },
        data: { followCount: { decrement: 1 } },
      });
    }
  });
  const tag = await prisma.tag.findFirst({ where: { name: tagName } });
  return tag!;
}

// 当前用户关注的标签名列表（按关注时间倒序）
export async function listFollowedTags(userId: number): Promise<string[]> {
  const rows = await prisma.userFollowTag.findMany({
    where: { userId },
    select: { tagName: true },
    orderBy: { createdAt: 'desc' },
  });
  return rows.map((r) => r.tagName);
}

// ===== 星图 Live：引力档位 / 未读角标 / 圈子活跃度 =====

export interface TagWeightItem {
  tagName: string;
  weight: number; // 1=强关注 2=常关注 3=轻关注
}

// 读取当前用户全部引力档位（仅返回显式设置过的；缺省由客户端按 2 处理）
export async function listTagWeights(userId: number): Promise<TagWeightItem[]> {
  const rows = await prisma.userTagPref.findMany({
    where: { userId },
    select: { tagName: true, weight: true },
  });
  return rows.map((r) => ({ tagName: r.tagName, weight: r.weight }));
}

// 设置引力档位（upsert）。仅允许已加入的圈子调节——未加入没有「推送强度」可言。
export async function setTagWeight(userId: number, tagName: string, weight: number): Promise<boolean> {
  const w = weight === 1 || weight === 3 ? weight : 2;
  const followed = await prisma.userFollowTag.findUnique({
    where: { userId_tagName: { userId, tagName } },
  });
  if (!followed) {
    return false;
  }
  await prisma.userTagPref.upsert({
    where: { userId_tagName: { userId, tagName } },
    create: { userId, tagName, weight: w },
    update: { weight: w },
  });
  return true;
}

// 记录「已读到此刻」：进圈子（降落/详情页）时调用，未读角标随之归零
export async function markTagRead(userId: number, tagName: string): Promise<void> {
  await prisma.userTagRead.upsert({
    where: { userId_tagName: { userId, tagName } },
    create: { userId, tagName, lastReadAt: new Date() },
    update: { lastReadAt: new Date() },
  });
}

export interface TagActivityItem {
  tagName: string;
  unread: number; // 自 lastReadAt 起的新帖数（未浏览过=全部近期新帖）
  active: boolean; // 近 7 天有新帖
  activeScore: number; // 星等（近14天衰减热度，驱动行星亮度分级）
  latestPostId: number | null; // 最新一帖（星子点击直达）
}

const ACTIVE_WINDOW_DAYS = 7;

// 圈子活跃度 + 未读数：一次查询给出星图「亮星/暗星 + 角标 + 星子」所需数据。
// 帖子 tags 为 JSON 数组列，MySQL 下用 JSON_CONTAINS 匹配；按标签名逐个统计，
// 标签总量受 CIRCLE_META 约束（数十个），逐个 count 在千级帖子量下开销可接受。
export async function listTagActivity(userId: number): Promise<TagActivityItem[]> {
  const tags = await prisma.tag.findMany({ select: { name: true, activeScore: true } });
  const reads = await prisma.userTagRead.findMany({
    where: { userId },
    select: { tagName: true, lastReadAt: true },
  });
  const readMap = new Map(reads.map((r) => [r.tagName, r.lastReadAt]));
  const windowStart = new Date(Date.now() - ACTIVE_WINDOW_DAYS * 86400000);

  const items: TagActivityItem[] = [];
  for (const tag of tags) {
    const since = readMap.get(tag.name) ?? windowStart;
    const [recent, unread, latest] = await Promise.all([
      prisma.post.count({
        where: { deletedAt: null, status: 1, createdAt: { gte: windowStart }, tags: { array_contains: tag.name } },
      }),
      prisma.post.count({
        where: { deletedAt: null, status: 1, createdAt: { gt: since }, tags: { array_contains: tag.name } },
      }),
      prisma.post.findFirst({
        where: { deletedAt: null, status: 1, tags: { array_contains: tag.name } },
        orderBy: { createdAt: 'desc' },
        select: { id: true },
      }),
    ]);
    items.push({ tagName: tag.name, unread, active: recent > 0, activeScore: tag.activeScore, latestPostId: latest?.id ?? null });
  }
  return items;
}

// ===== 圈子聚合总览（M2）=====
// 目标：把圈子页首屏需要的「圈子列表 + 关注态 + 权重 + 未读 + 成员数 + 最近帖 + 今日圈内」
// 收敛到一次请求，避免客户端同时打 tags/followed/weights/activity/posts 五套接口。
// 最近帖只取全局最近 120 条可见帖做窗口：圈子量级（数十个）下足够覆盖首屏与角标；
// 超出窗口的长尾内容由圈子详情页自己的分页补齐。

export type CircleOverviewScope = 'main' | 'city' | 'all';

export interface CircleOverviewPost {
  id: number;
  title: string;
  upCount: number;
}

export interface CircleOverviewItem {
  name: string;
  emoji: string;
  category: string;
  cityCode: string;
  description: string;
  memberCount: number;
  joined: boolean;
  // 创建者 id（NULL=预置/同城圈）：客户端据此只给创建者显示「删除圈子」。
  creatorId: number | null;
  weight: number;
  unread: number;
  active7d: boolean;
  lastPostAt: string | null;
  latestPosts: CircleOverviewPost[];
}

export interface CircleDigestItem {
  postId: number;
  title: string;
  authorName: string;
  circleName: string;
  upCount: number;
  createdAt: string;
}

export interface CircleOverview {
  circles: CircleOverviewItem[];
  digest: CircleDigestItem[];
}

const OVERVIEW_POST_WINDOW: number = 120;
const OVERVIEW_ACTIVE_WINDOW_MS: number = 7 * 86400000;
const DIGEST_LIMIT: number = 3;

// Json 列里的标签列表：只接受字符串项，脏数据直接丢弃。
function postTagNames(tags: unknown): string[] {
  if (!Array.isArray(tags)) {
    return [];
  }
  return tags.filter((item): item is string => typeof item === 'string');
}

// 圈子总览：main=全球兴趣圈（排除同城），city=指定城市，all=全量（发现页）。
export async function listCircleOverview(
  viewerId?: number,
  scope: CircleOverviewScope = 'main',
  cityCode?: string,
  name?: string,
): Promise<CircleOverview> {
  const where: any = {};
  if (name !== undefined && name.length > 0) {
    // 单圈详情：只取目标圈子，不再叠加 scope 过滤（同城圈也能查）。
    where.name = name;
  } else if (scope === 'city') {
    where.cityCode = cityCode;
  }

  const tagsRaw: Tag[] = await prisma.tag.findMany({
    where,
    orderBy: [{ activeScore: 'desc' }, { followCount: 'desc' }, { useCount: 'desc' }],
  });
  if (tagsRaw.length === 0) {
    return { circles: [], digest: [] };
  }

  const [followRows, prefRows, readRows, excluded] = await Promise.all([
    viewerId
      ? prisma.userFollowTag.findMany({ where: { userId: viewerId }, select: { tagName: true } })
      : Promise.resolve([]),
    viewerId
      ? prisma.userTagPref.findMany({ where: { userId: viewerId }, select: { tagName: true, weight: true } })
      : Promise.resolve([]),
    viewerId
      ? prisma.userTagRead.findMany({ where: { userId: viewerId }, select: { tagName: true, lastReadAt: true } })
      : Promise.resolve([]),
    getExcludedAuthorIds(viewerId),
  ]);

  const joinedNames = new Set<string>(followRows.map((row) => row.tagName));
  const weightByName = new Map<string, number>(prefRows.map((row) => [row.tagName, row.weight]));
  const readByName = new Map<string, Date>(readRows.map((row) => [row.tagName, row.lastReadAt]));

  // 主星图排除同城圈；但用户已加入的同城圈要保留，否则「已加入 N 个」与列表数量对不上。
  const tags: Tag[] = scope === 'main' && name === undefined
    ? tagsRaw.filter((tag) =>
      (tag.cityCode === null && tag.category !== CITY_CATEGORY) || joinedNames.has(tag.name))
    : tagsRaw;
  if (tags.length === 0) {
    return { circles: [], digest: [] };
  }

  const recentPosts = await prisma.post.findMany({
    where: {
      status: 1,
      deletedAt: null,
      user: { status: 1, deletedAt: null },
      ...(excluded.length > 0 ? { userId: { notIn: excluded } } : {}),
    },
    orderBy: { createdAt: 'desc' },
    take: OVERVIEW_POST_WINDOW,
    select: {
      id: true,
      title: true,
      upCount: true,
      createdAt: true,
      tags: true,
      user: { select: { nickname: true } },
    },
  });

  const scopeNames = new Set<string>(tags.map((tag) => tag.name));
  const postsByTag = new Map<string, typeof recentPosts>();
  for (const post of recentPosts) {
    for (const name of postTagNames(post.tags)) {
      if (!scopeNames.has(name)) {
        continue;
      }
      const bucket = postsByTag.get(name);
      if (bucket === undefined) {
        postsByTag.set(name, [post]);
      } else {
        bucket.push(post);
      }
    }
  }

  const now = Date.now();
  const activeEdge = now - OVERVIEW_ACTIVE_WINDOW_MS;
  const readWindowEdge = activeEdge; // 从未读过：只统计近 7 天新帖，避免历史全量算未读
  const circles: CircleOverviewItem[] = tags.map((tag) => {
    const bucket = postsByTag.get(tag.name) ?? [];
    const joined = joinedNames.has(tag.name);
    const since: Date = readByName.get(tag.name) ?? new Date(readWindowEdge);
    let unread = 0;
    if (viewerId) {
      for (const post of bucket) {
        if (post.createdAt.getTime() > since.getTime()) {
          unread += 1;
        }
      }
    }
    return {
      name: tag.name,
      emoji: tag.emoji ?? '',
      category: tag.category ?? '',
      cityCode: tag.cityCode ?? '',
      description: tag.description ?? '',
      memberCount: tag.followCount,
      joined,
      creatorId: tag.creatorId,
      weight: weightByName.get(tag.name) ?? 2,
      unread,
      active7d: bucket.length > 0 && bucket[0].createdAt.getTime() >= activeEdge,
      lastPostAt: bucket.length > 0 ? bucket[0].createdAt.toISOString() : null,
      latestPosts: bucket.slice(0, 2).map((post) => ({
        id: post.id,
        title: post.title,
        upCount: post.upCount,
      })),
    };
  });

  // 今日圈内：优先「已加入圈子」的最近帖，不足 3 条时用其余可见圈子补齐；
  // 每个圈子只占一条，避免同一圈子刷屏。
  const joinedPosts = recentPosts.filter((post) =>
    postTagNames(post.tags).some((name) => scopeNames.has(name) && joinedNames.has(name)));
  const fallbackPosts = recentPosts.filter((post) =>
    postTagNames(post.tags).some((name) => scopeNames.has(name)));
  const digest: CircleDigestItem[] = [];
  const usedCircles = new Set<string>();
  const pushDigest = (post: typeof recentPosts[number]): void => {
    const circleName = postTagNames(post.tags).find((name) => scopeNames.has(name));
    if (circleName === undefined || usedCircles.has(circleName)) {
      return;
    }
    usedCircles.add(circleName);
    digest.push({
      postId: post.id,
      title: post.title,
      authorName: post.user.nickname ?? '',
      circleName,
      upCount: post.upCount,
      createdAt: post.createdAt.toISOString(),
    });
  };
  for (const post of joinedPosts) {
    if (digest.length >= DIGEST_LIMIT) {
      break;
    }
    pushDigest(post);
  }
  if (digest.length < DIGEST_LIMIT) {
    for (const post of fallbackPosts) {
      if (digest.length >= DIGEST_LIMIT) {
        break;
      }
      pushDigest(post);
    }
  }

  return { circles, digest };
}
