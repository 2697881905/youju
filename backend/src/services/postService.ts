import { prisma } from '../prisma';
import { Prisma } from '@prisma/client';
import { sensitiveWordService } from './sensitiveWordService';
import { SensitiveWordError, ValidationError } from '../utils/errors';
import { USER_PUBLIC_SELECT, publicUserView } from '../utils/userView';
import { getExcludedAuthorIds, canViewerSeeAuthorPosts, getDislikedAuthorIds } from './accessControl';
import { searchPosts } from './searchService';
import { createNotification } from './notificationService';
import { buildCommentTree } from './commentService';
import { env } from '../config/env';
import { enqueueMediaDeletion } from './mediaDeletionService';

export type SortType = 'hot' | 'latest' | 'recommend';

export interface ListParams {
  page?: number;
  limit?: number;
  sort?: SortType;
  tag?: string;
  author?: number;
  keyword?: string;
  following?: boolean; // 关注流：仅返回当前用户关注的人发布的帖子
  viewerId?: number; // 当前登录用户 id（来自 auth 中间件 req.userId）
}

export interface DailyListParams {
  page?: number;
  limit?: number;
  viewerId?: number;
  // 仅供单元测试注入时间；路由调用始终使用当前时间。
  now?: Date;
}

// 帖子列表（分页 + 标签筛选 + 排序 + 作者筛选）
export async function listPosts(params: ListParams) {
  const page = Math.max(1, Number(params.page ?? 1));
  const limit = Math.min(50, Math.max(1, Number(params.limit ?? 20)));
  const skip = (page - 1) * limit;

  const where: any = { status: 1, deletedAt: null }; // 仅已发布且未移入废纸篓
  // 关键词搜索：升级为相关度排序（标题>标签>体裁>正文，权重见 searchService.scoreSearchPost）
  if (params.keyword && params.keyword.trim().length > 0) {
    const sort: 'relevance' | 'hot' | 'latest' =
      params.sort === 'hot' || params.sort === 'latest' ? params.sort : 'relevance';
    return searchPosts({
      page: params.page,
      limit: params.limit,
      keyword: params.keyword,
      tag: params.tag,
      author: params.author,
      sort,
      following: params.following,
      viewerId: params.viewerId,
    });
  }
  if (params.tag) {
    where.tags = { array_contains: params.tag };
  }
  if (params.author) {
    where.userId = params.author;
  }

  let orderBy: any = { createdAt: 'desc' };
  if (params.sort === 'hot' || params.sort === 'recommend') {
    // 热榜与推荐流统一按热度分排序（互动对数加权 + 时效衰减，见 hotScoreService）
    orderBy = [{ hotScore: 'desc' }, { createdAt: 'desc' }];
  }

  // 关注流：仅返回当前用户关注的人发布的帖子（公开流不进入此分支）
  let followIds: number[] | undefined;
  if (params.following && params.viewerId) {
    const follows = await prisma.follow.findMany({
      where: { followerId: params.viewerId },
      select: { followingId: true },
    });
    followIds = follows.map((f) => f.followingId);
    if (followIds.length === 0) {
      // 未关注任何人：直接返回空结果，不查 post 表（省一次 count）
      return { list: [], pagination: { page, limit, total: 0 } };
    }
    where.userId = { in: followIds };
  }

  // 可见性 / 拉黑 / 隐私 过滤
  if (params.author) {
    // 单作者（个人主页）场景：无权限则直接返回空列表
    const allowed = await canViewerSeeAuthorPosts(params.viewerId, params.author);
    if (!allowed) {
      return { list: [], pagination: { page, limit, total: 0 } };
    }
  } else {
    // 全局信息流 / 关注流：隐藏被封禁(status≠1)或被注销(deletedAt≠null)作者的帖子 + 拉黑/隐私不可见作者
    // （与详情接口 accessControl 一致：作者封禁或注销 → 帖子不可见）
    where.user = { status: 1, deletedAt: null };
    const excluded = await getExcludedAuthorIds(params.viewerId);
    // recommend 流额外排除「不喜欢」的作者（减少推送）；latest/following 流仅排除拉黑
    if (params.sort === 'recommend' && params.viewerId) {
      const disliked = await getDislikedAuthorIds(params.viewerId);
      const existingSet = new Set(excluded);
      for (const id of disliked) {
        if (!existingSet.has(id)) {
          excluded.push(id);
        }
      }
    }
    if (excluded.length > 0) {
      if (params.following) {
        where.userId = { in: followIds!, notIn: excluded };
      } else {
        where.userId = { notIn: excluded };
      }
    }
  }

  const [list, total] = await Promise.all([
    prisma.post.findMany({
      where,
      orderBy,
      skip,
      take: limit,
      include: { user: { select: USER_PUBLIC_SELECT } },
    }),
    prisma.post.count({ where }),
  ]);

  // 批量打标 myUp / myBookmark / myVote：仅当有 viewerId 且列表非空时执行，
  // 整页只额外发 3 次查询（up / bookmark / debateVote 各一次，与列表长度无关，杜绝 N+1）。
  // 无 viewerId 时短路，直接返回原 list，保证匿名请求不打标、不触发多余查询。
  if (params.viewerId && list.length > 0) {
    const ids: number[] = list.map((p) => p.id);
    const [ups, bms, votes] = await Promise.all([
      prisma.up.findMany({
        where: { postId: { in: ids }, userId: params.viewerId },
        select: { postId: true },
      }),
      prisma.bookmark.findMany({
        where: { postId: { in: ids }, userId: params.viewerId },
        select: { postId: true },
      }),
      prisma.debateVote.findMany({
        where: { postId: { in: ids }, userId: params.viewerId },
        select: { postId: true, choice: true },
      }),
    ]);
    const upSet = new Set<number>();
    for (const u of ups) {
      upSet.add(u.postId);
    }
    const bmSet = new Set<number>();
    for (const b of bms) {
      bmSet.add(b.postId);
    }
    const voteMap = new Map<number, string>();
    for (const v of votes) {
      voteMap.set(v.postId, v.choice);
    }
    const enriched = list.map((p) => ({
      ...p,
      myUp: upSet.has(p.id),
      myBookmark: bmSet.has(p.id),
      myVote: voteMap.get(p.id) ?? '',
    }));
    return {
      list: enriched.map((p) => ({ ...p, user: publicUserView(p.user) })),
      pagination: { page, limit, total },
    };
  }

  return {
    list: list.map((p) => ({ ...p, user: publicUserView(p.user) })),
    pagination: { page, limit, total },
  };
}

function dailyKey(now: Date): string {
  const parts = new Intl.DateTimeFormat('en-US', {
    timeZone: 'Asia/Shanghai',
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
  }).formatToParts(now);
  const part = (type: string): string => parts.find((item) => item.type === type)?.value ?? '';
  return part('year') + '-' + part('month') + '-' + part('day');
}

function stableOffset(seed: string, total: number): number {
  if (total <= 0) {
    return 0;
  }
  let hash = 2166136261;
  for (let index = 0; index < seed.length; index++) {
    hash = Math.imul(hash ^ seed.charCodeAt(index), 16777619);
  }
  return (hash >>> 0) % total;
}

function normalizePage(value: number | undefined, fallback: number): number {
  const numberValue = Number(value ?? fallback);
  if (!Number.isFinite(numberValue)) {
    return fallback;
  }
  return numberValue;
}

async function dailyInterestTags(viewerId?: number): Promise<string[]> {
  if (viewerId) {
    const followed = await prisma.userFollowTag.findMany({
      where: { userId: viewerId },
      select: { tagName: true },
      orderBy: { createdAt: 'desc' },
      take: 6,
    });
    const names = followed.map((row) => row.tagName).filter((name) => name.length > 0);
    if (names.length > 0) {
      return names;
    }
  }
  const popular = await prisma.tag.findMany({
    select: { name: true },
    orderBy: [{ followCount: 'desc' }, { useCount: 'desc' }],
    take: 3,
  });
  return popular.map((tag) => tag.name).filter((name) => name.length > 0);
}

async function dailyVisibleWhere(viewerId?: number): Promise<any> {
  const where: any = { status: 1, deletedAt: null, user: { status: 1, deletedAt: null } };
  const excluded = new Set(await getExcludedAuthorIds(viewerId));
  if (viewerId) {
    for (const id of await getDislikedAuthorIds(viewerId)) {
      excluded.add(id);
    }
  }
  if (excluded.size > 0) {
    where.userId = { notIn: [...excluded] };
  }
  return where;
}

async function fetchRotatedDailyPosts(
  where: any,
  total: number,
  offset: number,
  start: number,
  take: number,
): Promise<any[]> {
  if (total === 0 || take === 0) {
    return [];
  }
  const firstIndex = (offset + start) % total;
  const firstTake = Math.min(take, total - firstIndex);
  const orderBy: Prisma.PostOrderByWithRelationInput[] = [
    { upCount: 'desc' },
    { createdAt: 'desc' },
    { id: 'desc' },
  ];
  const first = await prisma.post.findMany({
    where,
    orderBy,
    skip: firstIndex,
    take: firstTake,
    include: { user: { select: USER_PUBLIC_SELECT } },
  });
  if (firstTake === take) {
    return first;
  }
  const second = await prisma.post.findMany({
    where,
    orderBy,
    skip: 0,
    take: take - firstTake,
    include: { user: { select: USER_PUBLIC_SELECT } },
  });
  return first.concat(second);
}

async function decorateViewerPosts(list: any[], viewerId?: number): Promise<any[]> {
  if (!viewerId || list.length === 0) {
    return list.map((post) => ({ ...post, user: publicUserView(post.user) }));
  }
  const ids: number[] = list.map((post) => post.id);
  const [ups, bookmarks, votes] = await Promise.all([
    prisma.up.findMany({ where: { postId: { in: ids }, userId: viewerId }, select: { postId: true } }),
    prisma.bookmark.findMany({ where: { postId: { in: ids }, userId: viewerId }, select: { postId: true } }),
    prisma.debateVote.findMany({ where: { postId: { in: ids }, userId: viewerId }, select: { postId: true, choice: true } }),
  ]);
  const upIds = new Set(ups.map((item) => item.postId));
  const bookmarkIds = new Set(bookmarks.map((item) => item.postId));
  const voteMap = new Map(votes.map((item) => [item.postId, item.choice]));
  return list.map((post) => ({
    ...post,
    user: publicUserView(post.user),
    myUp: upIds.has(post.id),
    myBookmark: bookmarkIds.has(post.id),
    myVote: voteMap.get(post.id) ?? '',
  }));
}

// 每日一帖：兴趣命中优先，热门/通用内容补齐。排序按上海日期稳定轮换，
// 不写入推荐表，因此当日可分页到底、次日会自然更新。
export async function listDailyPosts(params: DailyListParams = {}) {
  const page = Math.max(1, Math.floor(normalizePage(params.page, 1)));
  const limit = Math.min(50, Math.max(1, Math.floor(normalizePage(params.limit, 10))));
  const dateKey = dailyKey(params.now ?? new Date());
  const interestTags = await dailyInterestTags(params.viewerId);
  const visibleWhere = await dailyVisibleWhere(params.viewerId);
  const tagFilters = interestTags.map((tag) => ({ tags: { array_contains: tag } }));
  const interestWhere: any = tagFilters.length > 0 ? { ...visibleWhere, OR: tagFilters } : null;
  const fallbackWhere: any = tagFilters.length > 0
    ? { ...visibleWhere, NOT: { OR: tagFilters } }
    : visibleWhere;
  const [interestTotal, fallbackTotal] = await Promise.all([
    interestWhere ? prisma.post.count({ where: interestWhere }) : Promise.resolve(0),
    prisma.post.count({ where: fallbackWhere }),
  ]);
  const total = interestTotal + fallbackTotal;
  const globalStart = (page - 1) * limit;
  if (globalStart >= total) {
    return { list: [], pagination: { page, limit, total }, dateKey, interestTags };
  }

  const viewerKey = params.viewerId ? 'user:' + params.viewerId : 'guest';
  const interestOffset = stableOffset(dateKey + ':' + viewerKey + ':interest', interestTotal);
  const fallbackOffset = stableOffset(dateKey + ':' + viewerKey + ':fallback', fallbackTotal);
  let rawList: any[] = [];
  if (globalStart < interestTotal && interestWhere) {
    const interestTake = Math.min(limit, interestTotal - globalStart);
    rawList = await fetchRotatedDailyPosts(interestWhere, interestTotal, interestOffset, globalStart, interestTake);
    if (interestTake < limit) {
      rawList = rawList.concat(await fetchRotatedDailyPosts(
        fallbackWhere, fallbackTotal, fallbackOffset, 0, limit - interestTake,
      ));
    }
  } else {
    rawList = await fetchRotatedDailyPosts(
      fallbackWhere, fallbackTotal, fallbackOffset, globalStart - interestTotal, limit,
    );
  }

  const list = (await decorateViewerPosts(rawList, params.viewerId)).map((post) => {
    const postTags = Array.isArray(post.tags) ? post.tags.filter((tag: unknown): tag is string => typeof tag === 'string') : [];
    return { ...post, matchedTags: postTags.filter((tag: string) => interestTags.includes(tag)) };
  });
  return { list, pagination: { page, limit, total }, dateKey, interestTags };
}

// 帖子详情（含楼中楼评论树：一级评论按顶数降序，子回复按时间升序，仅返回 status=1 的正常评论）。
// 已移入废纸篓的帖子仅允许原作者通过带登录态的详情请求查看，其他访问仍返回不存在。
// viewerId 可选：传入时并发查 Up/Bookmark 记录，给返回体附加 myUp / myBookmark
// （当前登录用户对该帖的互动态，纯增量字段，不影响原有结构；缺失则不附加）。
export async function getPost(id: number, viewerId?: number) {
  const post = await prisma.post.findFirst({
    where: { id },
    include: {
      user: { select: USER_PUBLIC_SELECT },
    },
  });
  if (!post) {
    return null;
  }
  // 软删除不删除记录：仅帖子作者可从废纸篓继续查看详情，且必须携带本人登录态。
  if (post.deletedAt && viewerId !== post.userId) {
    return null;
  }
  // 可见性 / 拉黑 / 隐私 校验：无权限则视为不存在（404）
  if (!post.deletedAt && !(await canViewerSeeAuthorPosts(viewerId, post.userId))) {
    return null;
  }
  // 内容安全：非作者 & 非管理员，仅可见已发布(status=1)的帖。
  // 被下架(status=0)/审核拒绝(status=2)的帖通过详情接口直接读取即绕过审核，故拦截。
  const isAdmin = viewerId !== undefined && env.adminUserIds.includes(viewerId);
  if (post.status !== 1 && viewerId !== post.userId && !isAdmin) {
    return null;
  }
  // 浏览计数（数据面板/热度信号）：异步自增，失败不阻断详情返回
  prisma.post.update({ where: { id }, data: { viewCount: { increment: 1 } } }).catch(() => {});
  // 楼中楼评论：一次取足量扁平评论（按顶数降序，混排一级/子回复），再组装成树
  const rawComments = await prisma.comment.findMany({
    where: { postId: id, status: 1 },
    orderBy: { upCount: 'desc' },
    take: 100,
    include: { user: { select: USER_PUBLIC_SELECT } },
  });
  const comments = buildCommentTree(rawComments.map((c) => ({ ...c, user: publicUserView(c.user) })));
  if (!viewerId) {
    return {
      ...post,
      user: publicUserView(post.user),
      comments,
    };
  }
  const [up, bm, vote] = await Promise.all([
    prisma.up.findFirst({ where: { postId: id, userId: viewerId } }),
    prisma.bookmark.findFirst({ where: { postId: id, userId: viewerId } }),
    prisma.debateVote.findFirst({ where: { postId: id, userId: viewerId } }),
  ]);
  return {
    ...post,
    user: publicUserView(post.user),
    comments,
    myUp: !!up,
    myBookmark: !!bm,
    myVote: vote?.choice ?? '',
  };
}

// 提取正文中的 @昵称（2-20 字，不含空白与常见标点）
const MENTION_RE = /@([^@\s，。！？、；：""''《》（）【】]{2,20})/g;
// 提取 #话题#（2-15 字）
const TOPIC_RE = /#([^#\s，。！？、；：""''《》（）【】]{2,15})#/g;

function uniqueMatches(text: string, re: RegExp): string[] {
  const out: string[] = [];
  const seen = new Set<string>();
  let m: RegExpExecArray | null;
  while ((m = re.exec(text)) !== null) {
    const name = m[1].trim();
    if (name.length > 0 && !seen.has(name)) {
      seen.add(name);
      out.push(name);
    }
  }
  return out;
}

// 话题归并：正文 #xx# 中已存在于 Tag 表的话题并入 tags（上限 3 个，避免噪音标签）
async function mergeTopicTags(baseTags: string[], content: string): Promise<string[]> {
  if (!content || content.length === 0) {
    return baseTags ?? [];
  }
  const topics = uniqueMatches(content, TOPIC_RE);
  if (topics.length === 0) {
    return baseTags ?? [];
  }
  const existing = await prisma.tag.findMany({
    where: { name: { in: topics } },
    select: { name: true },
  });
  const known = existing.map((t) => t.name);
  const merged = (baseTags ?? []).slice();
  for (const name of known) {
    if (merged.length >= 3) {
      break;
    }
    if (merged.indexOf(name) < 0) {
      merged.push(name);
    }
  }
  return merged;
}

// @提及解析：正文 @昵称 命中真实用户（状态正常、未注销），返回 [{name, userId}] 供入库与通知复用
async function resolveMentions(content: string): Promise<Array<{ name: string; userId: number }>> {
  if (!content) {
    return [];
  }
  const names = uniqueMatches(content, MENTION_RE);
  if (names.length === 0) {
    return [];
  }
  const users = await prisma.user.findMany({
    where: { nickname: { in: names }, status: 1, deletedAt: null },
    select: { id: true, nickname: true },
  });
  const byName = new Map<string, number>();
  for (const u of users) {
    if (!byName.has(u.nickname) && u.id !== undefined) {
      byName.set(u.nickname, u.id);
    }
  }
  const result: Array<{ name: string; userId: number }> = [];
  for (const name of names) {
    const uid = byName.get(name);
    if (uid !== undefined) {
      result.push({ name, userId: uid });
    }
  }
  return result;
}

type MentionRef = { name: string; userId: number };

/**
 * 生成入库的 @提及映射：
 * - 编辑器显式选择（data.mentions，精确到 userId）时优先采用，规避重名昵称的歧义；
 *   服务端逐一校验：目标用户真实存在（status=1 未注销）、昵称与正文 @name 一致（防冒充）、
 *   正文确实出现对应 '@昵称'（防止编辑器残留的过期选择污染入库）。
 * - 显式列表缺失或全部无效时，回退为按昵称解析（兼容手工输入 @昵称 的老场景）。
 */
async function buildMentionRefs(content: string | undefined | null, explicit: unknown): Promise<MentionRef[]> {
  if (!content || content.trim().length === 0) {
    return [];
  }
  if (!Array.isArray(explicit) || explicit.length === 0) {
    return resolveMentions(content);
  }
  const picked: MentionRef[] = [];
  const seenUserId = new Set<number>();
  for (const item of explicit) {
    if (typeof item !== 'object' || item === null) {
      continue;
    }
    const rec = item as Record<string, unknown>;
    const name = rec.name;
    const userId = rec.userId;
    if (typeof name !== 'string' || name.length < 2 || name.length > 20) {
      continue;
    }
    if (typeof userId !== 'number' || !Number.isFinite(userId) || userId <= 0) {
      continue;
    }
    if (seenUserId.has(userId)) {
      continue;
    }
    if (content.indexOf('@' + name) < 0) {
      continue; // 正文中已不再包含该 @，丢弃过期选择
    }
    seenUserId.add(userId);
    picked.push({ name, userId });
  }
  if (picked.length === 0) {
    return resolveMentions(content);
  }
  const rows = await prisma.user.findMany({
    where: { id: { in: Array.from(seenUserId) }, status: 1, deletedAt: null },
    select: { id: true, nickname: true },
  });
  const nickById = new Map<number, string>();
  for (const u of rows) {
    nickById.set(u.id, u.nickname);
  }
  const verified: MentionRef[] = [];
  for (const p of picked) {
    if (nickById.get(p.userId) === p.name) {
      verified.push(p);
    }
  }
  if (verified.length === 0) {
    return resolveMentions(content);
  }
  // 显式选择未覆盖的手工输入 @昵称（未走选择器直接键入的）按昵称解析补全，避免入库映射丢失
  const resolved = await resolveMentions(content);
  const merged: MentionRef[] = verified.slice();
  const haveIds = new Set<number>();
  for (const v of verified) {
    haveIds.add(v.userId);
  }
  for (const r of resolved) {
    if (!haveIds.has(r.userId)) {
      haveIds.add(r.userId);
      merged.push(r);
    }
  }
  return merged;
}

// @提及通知：按入库映射推送（排除发布者自己），通知内容与展示映射严格一致
async function notifyMentions(
  mentionList: MentionRef[],
  postId: number,
  actorId: number,
  title: string
): Promise<void> {
  if (mentionList.length === 0) {
    return;
  }
  for (const m of mentionList) {
    if (m.userId === actorId) {
      continue;
    }
    await createNotification({
      userId: m.userId,
      actorId,
      type: 'mention',
      postId,
      content: '有人在新帖《' + (title ?? '') + '》中提到了你',
    }).catch(() => {});
  }
}

// 发布帖子（敏感词前置检测，通过后 status=1 直接发布）
export async function createPost(data: any, userId: number) {
  // 敏感词检测：检测 title + content
  const fullText = (data.title ?? '') + ' ' + (data.content ?? '');
  if (sensitiveWordService.checkText(fullText)) {
    throw new SensitiveWordError();
  }
  const mergedTags = await mergeTopicTags(data.tags ?? [], data.content ?? '');
  const mentionRefs = await buildMentionRefs(data.content ?? '', data.mentions);
  return prisma.post.create({
    data: {
      userId,
      title: data.title,
      content: data.content ?? null,
      coverImage: data.coverImage ?? null,
      videoUrl: data.videoUrl ?? null,
      videoCover: data.videoCover ?? null,
      videoAspectRatio: data.videoAspectRatio ?? null,
      images: data.images ?? [],
      genre: data.genre,
      tags: mergedTags.slice(0, 3),
      structuredData: data.structuredData ?? {},
      mentions: mentionRefs.length > 0 ? mentionRefs : Prisma.DbNull,
      status: 1,
    },
  }).then(async (post) => {
    // @提及 与 话题标记告一段落：提及通知失败不影响发布主流程
    notifyMentions(mentionRefs, post.id, userId, post.title).catch(() => {});
    return post;
  });
}

export async function deletePost(id: number, userId: number) {
  const post = await prisma.post.findUnique({ where: { id } });
  if (!post) return { ok: false, reason: 'not_found' };
  if (post.userId !== userId) return { ok: false, reason: 'forbidden' };
  if (post.deletedAt) return { ok: true };
  await prisma.post.update({ where: { id }, data: { deletedAt: new Date() } });
  return { ok: true };
}

// 废纸篓仅返回当前用户主动删除的帖子，按删除时间倒序。
export async function listTrashedPosts(userId: number, page: number = 1, limit: number = 20) {
  const p = Math.max(1, Number(page));
  const l = Math.min(50, Math.max(1, Number(limit)));
  const skip = (p - 1) * l;
  const where = { userId, deletedAt: { not: null } };
  const [list, total] = await Promise.all([
    prisma.post.findMany({
      where,
      orderBy: { deletedAt: 'desc' },
      skip,
      take: l,
      include: { user: { select: USER_PUBLIC_SELECT } },
    }),
    prisma.post.count({ where }),
  ]);
  return {
    list: list.map((post) => ({ ...post, user: publicUserView(post.user) })),
    pagination: { page: p, limit: l, total },
  };
}

export async function restorePost(id: number, userId: number) {
  const post = await prisma.post.findUnique({ where: { id } });
  if (!post) return { ok: false, reason: 'not_found' };
  if (post.userId !== userId) return { ok: false, reason: 'forbidden' };
  if (!post.deletedAt) return { ok: false, reason: 'not_deleted' };
  await prisma.post.update({ where: { id }, data: { deletedAt: null } });
  return { ok: true };
}

// 彻底删除只允许处理已经移入当前用户废纸篓的帖子。
export async function permanentlyDeletePost(id: number, userId: number) {
  const post = await prisma.post.findUnique({ where: { id } });
  if (!post) return { ok: false, reason: 'not_found' };
  if (post.userId !== userId) return { ok: false, reason: 'forbidden' };
  if (!post.deletedAt) return { ok: false, reason: 'not_deleted' };
  const comments = await prisma.comment.findMany({ where: { postId: id }, select: { id: true } });
  const commentIds = comments.map((comment) => comment.id);
  await prisma.$transaction(async (tx) => {
    await enqueueMediaDeletion(tx, [post.coverImage, post.videoUrl, post.videoCover, post.images]);
    await tx.commentUp.deleteMany({ where: { commentId: { in: commentIds } } });
    await tx.report.deleteMany({
      where: {
        OR: [
          { targetType: 'post', targetId: id },
          { targetType: 'comment', targetId: { in: commentIds } },
        ],
      },
    });
    await tx.debateVote.deleteMany({ where: { postId: id } });
    // Comment / Up / Bookmark 由数据库外键级联删除。
    await tx.post.delete({ where: { id } });
  });
  return { ok: true };
}

// 编辑帖子（仅本人，仅更新传入字段；体裁不可改）
export interface UpdatePostInput {
  title?: string;
  content?: string;
  coverImage?: string | null;
  videoUrl?: string | null;
  videoCover?: string | null;
  videoAspectRatio?: number | null;
  images?: string[];
  tags?: string[];
  structuredData?: any;
  // 编辑器显式选择的 @提及（精确到 userId，防重名歧义）；缺失时回退按昵称解析
  mentions?: Array<{ name: string; userId: number }>;
}

export async function updatePost(id: number, userId: number, input: UpdatePostInput) {
  const post = await prisma.post.findUnique({ where: { id } });
  if (!post) return { ok: false, reason: 'not_found' };
  if (post.userId !== userId) return { ok: false, reason: 'forbidden' };
  if (post.deletedAt) return { ok: false, reason: 'not_found' };

  const nextTitle = input.title !== undefined ? input.title : post.title;
  const nextContent = input.content !== undefined ? input.content : post.content;
  if (typeof nextTitle !== 'string' || nextTitle.trim().length === 0 || nextTitle.length > 100) {
    throw new ValidationError('标题长度需在 1-100 字');
  }
  if (nextContent !== null && nextContent !== undefined && typeof nextContent !== 'string') {
    throw new ValidationError('正文格式无效');
  }
  if (typeof nextContent === 'string' && nextContent.length > 20000) {
    throw new ValidationError('正文过长（≤20000 字）');
  }
  if (input.tags !== undefined && (!Array.isArray(input.tags) || input.tags.length > 3 || input.tags.some((tag) => typeof tag !== 'string'))) {
    throw new ValidationError('标签格式无效或超过 3 个');
  }
  if (input.images !== undefined && (!Array.isArray(input.images) || input.images.length > 9 || input.images.some((url) => typeof url !== 'string'))) {
    throw new ValidationError('图片格式无效或超过 9 张');
  }
  if (input.coverImage !== undefined && input.coverImage !== null && typeof input.coverImage !== 'string') {
    throw new ValidationError('封面图片格式无效');
  }
  if (input.videoUrl !== undefined && input.videoUrl !== null && typeof input.videoUrl !== 'string') {
    throw new ValidationError('视频地址格式无效');
  }
  if (input.videoCover !== undefined && input.videoCover !== null && typeof input.videoCover !== 'string') {
    throw new ValidationError('视频封面格式无效');
  }
  if (input.videoAspectRatio !== undefined && input.videoAspectRatio !== null &&
    (typeof input.videoAspectRatio !== 'number' || !Number.isFinite(input.videoAspectRatio) || input.videoAspectRatio < 0.45 || input.videoAspectRatio > 2.2)) {
    throw new ValidationError('视频比例格式无效');
  }
  if (sensitiveWordService.checkText(nextTitle + ' ' + (nextContent ?? ''))) {
    throw new SensitiveWordError();
  }

  const data: Record<string, any> = {};
  if (input.title !== undefined) data.title = input.title.trim();
  if (input.content !== undefined) data.content = input.content;
  if (input.coverImage !== undefined) data.coverImage = input.coverImage;
  if (input.videoUrl !== undefined) data.videoUrl = input.videoUrl;
  if (input.videoCover !== undefined) data.videoCover = input.videoCover;
  if (input.videoAspectRatio !== undefined) data.videoAspectRatio = input.videoAspectRatio;
  if (input.images !== undefined) data.images = input.images;
  // 话题归并：正文 #xx# 已存在的圈子话题并入 tags（上限 3）
  if (input.tags !== undefined || input.content !== undefined) {
    const baseTags: string[] = input.tags !== undefined
      ? input.tags
      : (Array.isArray(post.tags) ? (post.tags as string[]) : []);
    const merged = await mergeTopicTags(baseTags, input.content ?? post.content ?? '');
    data.tags = merged.slice(0, 3);
  }
  // @提及解析入库：正文变化时重算 [{name, userId}]，供前端点击跳转
  // 优先采用编辑器显式选择（精确到 userId，规避重名），缺失时按昵称回退解析
  let mentionRefs: MentionRef[] = [];
  if (input.content !== undefined) {
    mentionRefs = await buildMentionRefs(input.content ?? '', input.mentions);
    data.mentions = mentionRefs.length > 0 ? mentionRefs : null;
  }
  if (input.structuredData !== undefined) data.structuredData = input.structuredData;

  const updated = await prisma.post.update({ where: { id }, data });
  // @提及通知（正文变化时）：按入库映射推送，失败不阻断编辑
  if (input.content !== undefined) {
    notifyMentions(mentionRefs, id, userId, updated.title).catch(() => {});
  }
  return { ok: true, post: updated };
}

// 个人主页：我发布的帖子
export async function listByUser(userId: number, viewerId?: number) {
  // 无权限查看该用户帖子（隐私/拉黑/封禁）时返回空列表
  if (!(await canViewerSeeAuthorPosts(viewerId, userId))) {
    return [];
  }
  const rows = await prisma.post.findMany({
    where: { userId, deletedAt: null },
    orderBy: { createdAt: 'desc' },
    include: { user: { select: USER_PUBLIC_SELECT } },
  });
  return rows.map((p) => ({ ...p, user: publicUserView(p.user) }));
}

// 我的收藏列表（分页，返回帖子）
export async function listBookmarks(userId: number, page: number = 1, limit: number = 20) {
  const p = Math.max(1, Number(page));
  const l = Math.min(50, Math.max(1, Number(limit)));
  const skip = (p - 1) * l;
  const [rows, total] = await Promise.all([
    prisma.bookmark.findMany({
      where: { userId },
      orderBy: { createdAt: 'desc' },
      skip,
      take: l,
      include: {
        post: {
          include: { user: { select: USER_PUBLIC_SELECT } },
        },
      },
    }),
    prisma.bookmark.count({ where: { userId } }),
  ]);
  const list = rows.map((r) => ({ ...r.post, user: publicUserView(r.post.user) }));
  return { list, pagination: { page: p, limit: l, total } };
}

// 我赞过的帖子（分页，返回帖子）
export async function listLikedPosts(userId: number, page: number = 1, limit: number = 20) {
  const p = Math.max(1, Number(page));
  const l = Math.min(50, Math.max(1, Number(limit)));
  const skip = (p - 1) * l;
  const [rows, total] = await Promise.all([
    prisma.up.findMany({
      where: { userId },
      orderBy: { createdAt: 'desc' },
      skip,
      take: l,
      include: {
        post: {
          include: { user: { select: USER_PUBLIC_SELECT } },
        },
      },
    }),
    prisma.up.count({ where: { userId } }),
  ]);
  const list = rows.map((r) => ({ ...r.post, user: publicUserView(r.post.user) }));
  return { list, pagination: { page: p, limit: l, total } };
}

// 我评论过的帖子（按帖子去重，分页，返回帖子；同一帖子多次评论只出现一次）
export async function listCommentedPosts(userId: number, page: number = 1, limit: number = 20) {
  const p = Math.max(1, Number(page));
  const l = Math.min(50, Math.max(1, Number(limit)));
  const skip = (p - 1) * l;
  // 先按 postId 分组聚合，取每组最新评论时间用于排序分页（同一帖多次评论只算一条）
  const grouped = await prisma.comment.groupBy({
    by: ['postId'],
    where: { userId },
    _max: { createdAt: true },
    orderBy: { _max: { createdAt: 'desc' } },
    skip,
    take: l,
  });
  const postIds: number[] = grouped.map((g) => g.postId);
  const [posts, total] = await Promise.all([
    prisma.post.findMany({
      where: { id: { in: postIds } },
      include: { user: { select: USER_PUBLIC_SELECT } },
    }),
    // 去重后的帖子总数（不依赖分页，直接 groupBy 计数）
    prisma.comment.groupBy({ by: ['postId'], where: { userId } }).then((r) => r.length),
  ]);
  // findMany 不保证 id 顺序，按分组顺序（最新评论时间倒序）重排
  const orderMap: Record<number, number> = {};
  for (let i = 0; i < postIds.length; i++) {
    orderMap[postIds[i]] = i;
  }
  const sorted = posts.slice().sort((a, b) => {
    const ai = orderMap[a.id] ?? Number.MAX_SAFE_INTEGER;
    const bi = orderMap[b.id] ?? Number.MAX_SAFE_INTEGER;
    return ai - bi;
  });
  const list = sorted.map((po) => ({ ...po, user: publicUserView(po.user) }));
  return { list, pagination: { page: p, limit: l, total } };
}
