import { prisma } from '../prisma';
import { sensitiveWordService } from './sensitiveWordService';
import { SensitiveWordError } from '../utils/errors';
import { USER_PUBLIC_SELECT, publicUserView } from '../utils/userView';

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

// 帖子列表（分页 + 标签筛选 + 排序 + 作者筛选）
export async function listPosts(params: ListParams) {
  const page = Math.max(1, Number(params.page ?? 1));
  const limit = Math.min(50, Math.max(1, Number(params.limit ?? 20)));
  const skip = (page - 1) * limit;

  const where: any = { status: 1 }; // 仅已发布
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
  if (params.following && params.viewerId) {
    const follows = await prisma.follow.findMany({
      where: { followerId: params.viewerId },
      select: { followingId: true },
    });
    const ids: number[] = follows.map((f) => f.followingId);
    if (ids.length === 0) {
      // 未关注任何人：直接返回空结果，不查 post 表（省一次 count）
      return { list: [], pagination: { page, limit, total: 0 } };
    }
    where.userId = { in: ids };
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

  // 批量打标 myUp / myBookmark：仅当有 viewerId 且列表非空时执行，
  // 整页只额外发 2 次查询（up / bookmark 各一次，与列表长度无关，杜绝 N+1）。
  // 无 viewerId 时短路，直接返回原 list，保证匿名请求不打标、不触发多余查询。
  if (params.viewerId && list.length > 0) {
    const ids: number[] = list.map((p) => p.id);
    const [ups, bms] = await Promise.all([
      prisma.up.findMany({
        where: { postId: { in: ids }, userId: params.viewerId },
        select: { postId: true },
      }),
      prisma.bookmark.findMany({
        where: { postId: { in: ids }, userId: params.viewerId },
        select: { postId: true },
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
    const enriched = list.map((p) => ({
      ...p,
      myUp: upSet.has(p.id),
      myBookmark: bmSet.has(p.id),
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

// 帖子详情（含评论，评论按顶数降序，仅返回 status=1 的正常评论）
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
  if (!viewerId) {
    return {
      ...post,
      user: publicUserView(post.user),
      comments: (post.comments ?? []).map((c) => ({ ...c, user: publicUserView(c.user) })),
    };
  }
  const [up, bm] = await Promise.all([
    prisma.up.findFirst({ where: { postId: id, userId: viewerId } }),
    prisma.bookmark.findFirst({ where: { postId: id, userId: viewerId } }),
  ]);
  return {
    ...post,
    user: publicUserView(post.user),
    comments: (post.comments ?? []).map((c) => ({ ...c, user: publicUserView(c.user) })),
    myUp: !!up,
    myBookmark: !!bm,
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
  // 先清理子表（评论/点赞/收藏）再删主表，避免外键约束导致删除失败。
  // 兜底方案：规范做法是在 schema 给子关系配置 onDelete: Cascade（已加，prisma db push 后由数据库级联）。
  await prisma.comment.deleteMany({ where: { postId: id } });
  await prisma.up.deleteMany({ where: { postId: id } });
  await prisma.bookmark.deleteMany({ where: { postId: id } });
  await prisma.post.delete({ where: { id } });
  return { ok: true };
}

// 编辑帖子（仅本人，仅更新传入字段；体裁不可改）
export interface UpdatePostInput {
  title?: string;
  content?: string;
  coverImage?: string | null;
  images?: string[];
  tags?: string[];
  structuredData?: any;
}

export async function updatePost(id: number, userId: number, input: UpdatePostInput) {
  const post = await prisma.post.findUnique({ where: { id } });
  if (!post) return { ok: false, reason: 'not_found' };
  if (post.userId !== userId) return { ok: false, reason: 'forbidden' };

  const data: Record<string, any> = {};
  if (input.title !== undefined) data.title = input.title;
  if (input.content !== undefined) data.content = input.content;
  if (input.coverImage !== undefined) data.coverImage = input.coverImage;
  if (input.images !== undefined) data.images = input.images;
  if (input.tags !== undefined) data.tags = input.tags;
  if (input.structuredData !== undefined) data.structuredData = input.structuredData;

  const updated = await prisma.post.update({ where: { id }, data });
  return { ok: true, post: updated };
}

// ===== 热点（时窗加权热帖） =====
// 综合 upCount / commentCount / bookmarkCount 加权，并按时窗衰减
// 公式：rawScore = upCount*3 + commentCount*5 + bookmarkCount*2
//       hoursAgo = max(0, 距现在的时差)
//       decay = 1 / (1 + hoursAgo * 0.08)  （约每 12.5h 折半）
//       heat = rawScore * decay
export interface HotPostsParams {
  windowHours?: number; // 时间窗口（小时），默认 24
  page?: number;
  limit?: number;
  tag?: string;
  viewerId?: number;
}

export async function listHotPosts(params: HotPostsParams) {
  const windowHours = Math.max(1, Number(params.windowHours ?? 24));
  const page = Math.max(1, Number(params.page ?? 1));
  const limit = Math.min(50, Math.max(1, Number(params.limit ?? 20)));

  const since = new Date(Date.now() - windowHours * 60 * 60 * 1000);
  const where: any = { status: 1, createdAt: { gte: since } };
  if (params.tag) {
    where.tags = { array_contains: params.tag };
  }

  // 取时窗内全部帖子（后续在内存中计算热度分 + 排序，再分页）
  const rows = await prisma.post.findMany({
    where,
    orderBy: { createdAt: 'desc' },
    include: { user: { select: USER_PUBLIC_SELECT } },
  });

  const now = Date.now();
  const scored = rows.map((p) => {
    const rawScore = (p.upCount ?? 0) * 3 + (p.commentCount ?? 0) * 5 + (p.bookmarkCount ?? 0) * 2;
    const hoursAgo = Math.max(0, (now - new Date(p.createdAt).getTime()) / (1000 * 60 * 60));
    const decay = 1 / (1 + hoursAgo * 0.08);
    return { post: p, heat: rawScore * decay };
  });

  scored.sort((a, b) => b.heat - a.heat);

  const total = scored.length;
  const skip = (page - 1) * limit;
  const list = scored.slice(skip, skip + limit).map((s) => s.post);

  // 复用 viewerId 批量打标 myUp / myBookmark
  if (params.viewerId && list.length > 0) {
    const ids: number[] = list.map((p) => p.id);
    const [ups, bms] = await Promise.all([
      prisma.up.findMany({
        where: { postId: { in: ids }, userId: params.viewerId },
        select: { postId: true },
      }),
      prisma.bookmark.findMany({
        where: { postId: { in: ids }, userId: params.viewerId },
        select: { postId: true },
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
    const enriched = list.map((p) => ({
      ...p,
      myUp: upSet.has(p.id),
      myBookmark: bmSet.has(p.id),
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

// 个人主页：我发布的帖子
export async function listByUser(userId: number) {
  const rows = await prisma.post.findMany({
    where: { userId },
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
