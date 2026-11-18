// 合集（连载）服务：作者公开的有序帖子集合。与私人收藏夹不同——合集对所有人可见，
// 但只有作者能增删条目；一篇帖子同一时间只能进一个合集。
import { prisma } from '../prisma';
import { ValidationError, NotFoundError, ForbiddenError } from '../utils/errors';
import { USER_PUBLIC_SELECT, publicUserView } from '../utils/userView';

const MAX_COLLECTIONS = 20;
const MAX_POSTS_PER_COLLECTION = 100;
const MAX_TITLE_LEN = 50;
const MAX_DESC_LEN = 300;

function validateTitle(raw: unknown): string {
  const title = String(raw ?? '').trim();
  if (title.length === 0 || title.length > MAX_TITLE_LEN) {
    throw new ValidationError(`合集标题需在 1-${MAX_TITLE_LEN} 字`);
  }
  return title;
}

function validateDescription(raw: unknown): string | null {
  if (raw === undefined || raw === null) {
    return null;
  }
  const desc = String(raw).trim();
  if (desc.length > MAX_DESC_LEN) {
    throw new ValidationError(`合集简介不能超过 ${MAX_DESC_LEN} 字`);
  }
  return desc.length > 0 ? desc : null;
}

async function assertOwned(authorId: number, collectionId: number) {
  const c = await prisma.collection.findUnique({ where: { id: collectionId } });
  if (!c) {
    throw new NotFoundError('合集不存在');
  }
  if (c.authorId !== authorId) {
    throw new ForbiddenError('只能编辑自己的合集');
  }
  return c;
}

/** 我的合集列表 / 某作者的公开合集列表（含条目数与封面） */
export async function listCollections(authorId: number) {
  const rows = await prisma.collection.findMany({
    where: { authorId },
    orderBy: { updatedAt: 'desc' },
  });
  if (rows.length === 0) {
    return [];
  }
  const covers = await prisma.collectionPost.findMany({
    where: { collectionId: { in: rows.map((r) => r.id) } },
    orderBy: { addedAt: 'asc' },
    select: {
      collectionId: true,
      post: { select: { id: true, title: true, images: true, coverImage: true, genre: true } },
    },
  });
  const coverMap = new Map<number, { postId: number; title: string; image: string; genre: string }>();
  for (const cp of covers) {
    if (coverMap.has(cp.collectionId)) {
      continue;
    }
    const p = cp.post;
    const images: string[] = Array.isArray(p.images) ? p.images.filter((x): x is string => typeof x === 'string') : [];
    coverMap.set(cp.collectionId, {
      postId: p.id,
      title: p.title ?? '',
      image: images[0] || p.coverImage || '',
      genre: p.genre ?? '',
    });
  }
  return rows.map((r) => ({
    id: r.id,
    authorId: r.authorId,
    title: r.title,
    description: r.description,
    postCount: r.postCount,
    cover: coverMap.get(r.id) ?? null,
    createdAt: r.createdAt,
    updatedAt: r.updatedAt,
  }));
}

export async function createCollection(authorId: number, rawTitle: unknown, rawDesc: unknown) {
  const total = await prisma.collection.count({ where: { authorId } });
  if (total >= MAX_COLLECTIONS) {
    throw new ValidationError(`合集数量已达上限（${MAX_COLLECTIONS} 个）`);
  }
  const title = validateTitle(rawTitle);
  const description = validateDescription(rawDesc);
  const c = await prisma.collection.create({ data: { authorId, title, description } });
  return { id: c.id, authorId: c.authorId, title: c.title, description: c.description, postCount: 0, cover: null };
}

export async function updateCollection(authorId: number, collectionId: number, rawTitle: unknown, rawDesc: unknown) {
  await assertOwned(authorId, collectionId);
  const title = validateTitle(rawTitle);
  const description = validateDescription(rawDesc);
  const c = await prisma.collection.update({
    where: { id: collectionId },
    data: { title, description },
  });
  return { id: c.id, authorId: c.authorId, title: c.title, description: c.description, postCount: c.postCount };
}

export async function deleteCollection(authorId: number, collectionId: number) {
  await assertOwned(authorId, collectionId);
  await prisma.$transaction([
    prisma.collectionPost.deleteMany({ where: { collectionId } }),
    prisma.collection.delete({ where: { id: collectionId } }),
  ]);
  return { success: true };
}

/** 合集详情：返回合集元信息 + 有序帖子分页 */
export async function getCollection(collectionId: number, page = 1, limit = 20) {
  const c = await prisma.collection.findUnique({ where: { id: collectionId } });
  if (!c) {
    throw new NotFoundError('合集不存在');
  }
  const p = Math.max(1, Number(page));
  const l = Math.min(50, Math.max(1, Number(limit)));
  const skip = (p - 1) * l;
  const [rows, total] = await Promise.all([
    prisma.collectionPost.findMany({
      where: { collectionId },
      orderBy: { addedAt: 'asc' },
      skip,
      take: l,
      include: { post: { include: { user: { select: USER_PUBLIC_SELECT } } } },
    }),
    prisma.collectionPost.count({ where: { collectionId } }),
  ]);
  const list = rows.map((r) => ({
    ...r.post,
    user: publicUserView(r.post.user),
    collectionAddedAt: r.addedAt,
  }));
  return {
    collection: { id: c.id, authorId: c.authorId, title: c.title, description: c.description, postCount: c.postCount },
    list,
    pagination: { page: p, limit: l, total },
  };
}

/** 向合集追加帖子：帖子必须是本人的、已发布、未删除，且尚未进任何合集 */
export async function addPost(authorId: number, collectionId: number, postId: number) {
  await assertOwned(authorId, collectionId);
  const count = await prisma.collectionPost.count({ where: { collectionId } });
  if (count >= MAX_POSTS_PER_COLLECTION) {
    throw new ValidationError(`单个合集最多 ${MAX_POSTS_PER_COLLECTION} 篇帖子`);
  }
  const post = await prisma.post.findFirst({
    where: { id: postId, userId: authorId, status: 1, deletedAt: null },
    select: { id: true },
  });
  if (!post) {
    throw new NotFoundError('帖子不存在、未发布或不属于你');
  }
  const existing = await prisma.collectionPost.findUnique({ where: { postId } });
  if (existing) {
    throw new ValidationError('该帖子已加入其他合集');
  }
  await prisma.$transaction([
    prisma.collectionPost.create({ data: { collectionId, postId } }),
    prisma.collection.update({ where: { id: collectionId }, data: { postCount: { increment: 1 } } }),
  ]);
  return { success: true };
}

/** 从合集移除帖子：只校验合集归属，条目不存在时仍幂等返回成功 */
export async function removePost(authorId: number, collectionId: number, postId: number) {
  await assertOwned(authorId, collectionId);
  await prisma.$transaction(async (tx) => {
    const removed = await tx.collectionPost.deleteMany({ where: { collectionId, postId } });
    if (removed.count > 0) {
      await tx.collection.update({
        where: { id: collectionId },
        data: { postCount: { decrement: 1 } },
      });
    }
  });
  return { success: true };
}
