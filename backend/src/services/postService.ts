import { prisma } from '../prisma';
import { Prisma } from '@prisma/client';
import { sensitiveWordService } from './sensitiveWordService';
import { SensitiveWordError, ValidationError } from '../utils/errors';
import { USER_PUBLIC_SELECT, publicUserView } from '../utils/userView';
import { getExcludedAuthorIds, canViewerSeeAuthorPosts, getDislikedAuthorIds } from './accessControl';
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
  if (params.tag) {
    where.tags = { array_contains: params.tag };
  }
  if (params.author) {
    where.userId = params.author;
  }
  // 关键词搜索：标题/正文/体裁/标签之间用 OR（任一命中即返回）
  // - MySQL 不支持 Prisma 的 mode:'insensitive'（该选项仅 PostgreSQL/MongoDB 可用，
  //   生成客户端里根本没有 QueryMode/mode 字段，传入会触发 PrismaClientValidationError）。
  //   MySQL 默认排序规则 utf8mb4_*_ci 已是大小写不敏感，故 contains 即为大小写不敏感匹配。
  // - tags 是 Json 数组列，用 array_contains（snake_case；整列即数组，无需 path）
  //   做标签精确包含匹配；images 不参与搜索。
  if (params.keyword) {
    const kw = params.keyword.trim();
    if (kw) {
      where.OR = [
        { title: { contains: kw } },
        { content: { contains: kw } },
        { genre: { contains: kw } },
        { tags: { array_contains: kw } },
      ];
    }
  }

  let orderBy: any = { createdAt: 'desc' };
  if (params.sort === 'hot') {
    orderBy = [{ upCount: 'desc' }, { createdAt: 'desc' }];
  }
  // recommend（P1）初期用简单规则：回退到最新

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

// 帖子详情（含评论，评论按顶数降序，仅返回 status=1 的正常评论）。
// 已移入废纸篓的帖子仅允许原作者通过带登录态的详情请求查看，其他访问仍返回不存在。
// viewerId 可选：传入时并发查 Up/Bookmark 记录，给返回体附加 myUp / myBookmark
// （当前登录用户对该帖的互动态，纯增量字段，不影响原有结构；缺失则不附加）。
export async function getPost(id: number, viewerId?: number) {
  const post = await prisma.post.findFirst({
    where: { id },
    include: {
      user: { select: USER_PUBLIC_SELECT },
      comments: {
        where: { status: 1 },
        orderBy: { upCount: 'desc' },
        take: 50,
        include: { user: { select: USER_PUBLIC_SELECT } },
      },
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
  if (!viewerId) {
    return {
      ...post,
      user: publicUserView(post.user),
      comments: (post.comments ?? []).map((c) => ({ ...c, user: publicUserView(c.user) })),
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
    comments: (post.comments ?? []).map((c) => ({ ...c, user: publicUserView(c.user) })),
    myUp: !!up,
    myBookmark: !!bm,
    myVote: vote?.choice ?? '',
  };
}

// 发布帖子（敏感词前置检测，通过后 status=1 直接发布）
export async function createPost(data: any, userId: number) {
  // 敏感词检测：检测 title + content
  const fullText = (data.title ?? '') + ' ' + (data.content ?? '');
  if (sensitiveWordService.checkText(fullText)) {
    throw new SensitiveWordError();
  }
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
      tags: data.tags ?? [],
      structuredData: data.structuredData ?? {},
      status: 1,
    },
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
  if (input.tags !== undefined) data.tags = input.tags;
  if (input.structuredData !== undefined) data.structuredData = input.structuredData;

  const updated = await prisma.post.update({ where: { id }, data });
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
