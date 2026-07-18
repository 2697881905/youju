import { prisma } from '../prisma';
import { sensitiveWordService } from './sensitiveWordService';
import { SensitiveWordError } from '../utils/errors';

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
      include: { user: { select: { id: true, nickname: true, avatar: true } } },
    }),
    prisma.post.count({ where }),
  ]);

  return { list, pagination: { page, limit, total } };
}

// 帖子详情（含评论，评论按顶数降序，仅返回 status=1 的正常评论）
export async function getPost(id: number) {
  return prisma.post.findFirst({
    where: { id },
    include: {
      user: { select: { id: true, nickname: true, avatar: true } },
      comments: {
        where: { status: 1 },
        orderBy: { upCount: 'desc' },
        take: 50,
        include: { user: { select: { id: true, nickname: true, avatar: true } } },
      },
    },
  });
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
  await prisma.post.delete({ where: { id } });
  return { ok: true };
}

// 个人主页：我发布的帖子
export async function listByUser(userId: number) {
  return prisma.post.findMany({
    where: { userId },
    orderBy: { createdAt: 'desc' },
    include: { user: { select: { id: true, nickname: true, avatar: true } } },
  });
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
          include: { user: { select: { id: true, nickname: true, avatar: true } } },
        },
      },
    }),
    prisma.bookmark.count({ where: { userId } }),
  ]);
  const list = rows.map((r) => r.post);
  return { list, pagination: { page: p, limit: l, total } };
}
