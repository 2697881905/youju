import { prisma } from '../prisma';

export type SortType = 'hot' | 'latest' | 'recommend';

export interface ListParams {
  page?: number;
  limit?: number;
  sort?: SortType;
  tag?: string;
  author?: number;
  keyword?: string;
}

// 帖子列表（分页 + 标签筛选 + 排序 + 作者筛选）
export async function listPosts(params: ListParams) {
  const page = Math.max(1, Number(params.page ?? 1));
  const limit = Math.min(50, Math.max(1, Number(params.limit ?? 20)));
  const skip = (page - 1) * limit;

  const where: any = { status: 1 }; // 仅已发布
  if (params.tag) {
    where.tags = { arrayContains: params.tag };
  }
  if (params.author) {
    where.userId = params.author;
  }
  // 关键词搜索：标题/正文/体裁/标签之间用 OR（任一命中即返回）
  // tags 是 Json 列，标签关键词用 arrayContains 精确包含某标签；images 不参与搜索
  if (params.keyword) {
    const kw = params.keyword.trim();
    if (kw) {
      where.OR = [
        { title: { contains: kw, mode: 'insensitive' } },
        { content: { contains: kw, mode: 'insensitive' } },
        { genre: { contains: kw, mode: 'insensitive' } },
        { tags: { arrayContains: kw } },
      ];
    }
  }

  let orderBy: any = { createdAt: 'desc' };
  if (params.sort === 'hot') {
    orderBy = [{ upCount: 'desc' }, { createdAt: 'desc' }];
  }
  // recommend（P1）初期用简单规则：回退到最新

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

// 帖子详情（含评论，评论按顶数降序）
export async function getPost(id: number) {
  return prisma.post.findFirst({
    where: { id },
    include: {
      user: { select: { id: true, nickname: true, avatar: true } },
      comments: {
        orderBy: { upCount: 'desc' },
        take: 50,
        include: { user: { select: { id: true, nickname: true, avatar: true } } },
      },
    },
  });
}

// 发布帖子（MVP 无审核流，直接发布 status=1；后续接入审核可改回 0）
export async function createPost(data: any, userId: number) {
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
