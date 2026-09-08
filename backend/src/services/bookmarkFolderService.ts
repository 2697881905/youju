// 收藏夹（专辑）服务：创建/重命名/删除/列表（含计数）与收藏归类/移动
import { prisma } from '../prisma';
import { ValidationError, NotFoundError } from '../utils/errors';
import { USER_PUBLIC_SELECT, publicUserView } from '../utils/userView';

const MAX_FOLDERS = 20; // 每用户收藏夹数量上限
const MAX_NAME_LEN = 20;

// 校验收藏夹名称，返回规范后名称
export function validateFolderName(raw: unknown): string {
  const name = String(raw ?? '').trim();
  if (name.length === 0 || name.length > MAX_NAME_LEN) {
    throw new ValidationError(`收藏夹名称需在 1-${MAX_NAME_LEN} 字`);
  }
  return name;
}

// 我的收藏夹列表（含每夹收藏数与封面图）
export async function listFolders(userId: number) {
  const folders = await prisma.bookmarkFolder.findMany({
    where: { userId },
    orderBy: { createdAt: 'asc' },
  });
  const ids = folders.map((f) => f.id);
  const counts = ids.length > 0
    ? await prisma.bookmark.groupBy({
        by: ['folderId'],
        where: { userId, folderId: { in: ids } },
        _count: { _all: true },
      })
    : [];
  // 每夹一张封面（该夹最近收藏帖子的首图/标题）
  const covers = ids.length > 0
    ? await prisma.bookmark.findMany({
        where: { userId, folderId: { in: ids }, post: { deletedAt: null } },
        orderBy: { createdAt: 'desc' },
        select: { folderId: true, post: { select: { id: true, title: true, images: true, coverImage: true, genre: true } } },
      })
    : [];
  const countMap = new Map<number, number>();
  for (const c of counts) {
    if (c.folderId !== null) {
      countMap.set(c.folderId, c._count._all);
    }
  }
  const coverMap = new Map<number, { postId: number; title: string; image: string; genre: string }>();
  for (const cv of covers) {
    if (cv.folderId === null || coverMap.has(cv.folderId)) {
      continue;
    }
    const p = cv.post;
    const images: string[] = Array.isArray(p.images) ? p.images.filter((x): x is string => typeof x === 'string') : [];
    coverMap.set(cv.folderId, {
      postId: p.id,
      title: p.title ?? '',
      image: images[0] || p.coverImage || '',
      genre: p.genre ?? '',
    });
  }
  return folders.map((f) => ({
    id: f.id,
    name: f.name,
    count: countMap.get(f.id) ?? 0,
    cover: coverMap.get(f.id) ?? null,
  }));
}

// 创建收藏夹
export async function createFolder(userId: number, name: string) {
  const total = await prisma.bookmarkFolder.count({ where: { userId } });
  if (total >= MAX_FOLDERS) {
    throw new ValidationError(`收藏夹数量已达上限（${MAX_FOLDERS} 个），请先删除不再需要的收藏夹`);
  }
  const folder = await prisma.bookmarkFolder.create({ data: { userId, name } });
  return { id: folder.id, name: folder.name, count: 0, cover: null };
}

// 重命名收藏夹
export async function renameFolder(userId: number, folderId: number, name: string) {
  const folder = await prisma.bookmarkFolder.findFirst({ where: { id: folderId, userId } });
  if (!folder) {
    throw new NotFoundError('收藏夹不存在');
  }
  return prisma.bookmarkFolder.update({ where: { id: folderId }, data: { name } });
}

// 删除收藏夹：收藏记录保留但置回未分类（folderId=null）
export async function deleteFolder(userId: number, folderId: number) {
  const folder = await prisma.bookmarkFolder.findFirst({ where: { id: folderId, userId } });
  if (!folder) {
    throw new NotFoundError('收藏夹不存在');
  }
  await prisma.$transaction([
    prisma.bookmark.updateMany({ where: { userId, folderId }, data: { folderId: null } }),
    prisma.bookmarkFolder.delete({ where: { id: folderId } }),
  ]);
  return { success: true };
}

// 收藏夹内帖子列表（分页，返回帖子；仅正常可见帖子，deletedAt 为空的帖子仍在，由调用方过滤）
export async function listFolderPosts(userId: number, folderId: number, page = 1, limit = 20) {
  const p = Math.max(1, Number(page));
  const l = Math.min(50, Math.max(1, Number(limit)));
  const folder = await prisma.bookmarkFolder.findFirst({ where: { id: folderId, userId } });
  if (!folder) {
    throw new NotFoundError('收藏夹不存在');
  }
  const skip = (p - 1) * l;
  const [rows, total] = await Promise.all([
    prisma.bookmark.findMany({
      where: { userId, folderId },
      orderBy: { createdAt: 'desc' },
      skip,
      take: l,
      include: {
        post: {
          include: { user: { select: USER_PUBLIC_SELECT } },
        },
      },
    }),
    prisma.bookmark.count({ where: { userId, folderId } }),
  ]);
  const list = rows.map((r) => ({
    ...r.post,
    userId: r.post.userId,
    user: publicUserView(r.post.user),
    myBookmark: true,
    bookmarkCreatedAt: r.createdAt,
  }));
  return { list, pagination: { page: p, limit: l, total } };
}

// 校验收藏夹归属：folderId 为 null/0 或不传 → 未分类；否则必须是当前用户的收藏夹
export async function assertFolderOwnedOrNull(userId: number, folderId?: number | null): Promise<number | null> {
  if (folderId === undefined || folderId === null || folderId === 0) {
    return null;
  }
  const folder = await prisma.bookmarkFolder.findFirst({ where: { id: folderId, userId } });
  if (!folder) {
    throw new NotFoundError('收藏夹不存在');
  }
  return folderId;
}