import { prisma } from '../prisma';

export async function listComments(postId: number, page = 1, limit = 50) {
  const skip = (page - 1) * limit;
  const [list, total] = await Promise.all([
    prisma.comment.findMany({
      where: { postId },
      orderBy: { upCount: 'desc' },
      skip,
      take: limit,
      include: { user: { select: { id: true, nickname: true, avatar: true } } },
    }),
    prisma.comment.count({ where: { postId } }),
  ]);
  return { list, pagination: { page, limit, total } };
}

export async function createComment(
  postId: number,
  userId: number,
  content: string,
  parentId?: number | null,
  isFact = 0
) {
  return prisma.comment.create({
    data: { postId, userId, content, parentId: parentId ?? null, isFact },
  });
}

export async function deleteComment(id: number, userId: number) {
  const c = await prisma.comment.findUnique({ where: { id } });
  if (!c) return { ok: false, reason: 'not_found' };
  if (c.userId !== userId) return { ok: false, reason: 'forbidden' };
  await prisma.comment.delete({ where: { id } });
  return { ok: true };
}
