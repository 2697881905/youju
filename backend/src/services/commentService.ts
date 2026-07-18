import { prisma } from '../prisma';
import { notifyOnComment } from './notificationService';

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
  const comment = await prisma.comment.create({
    data: { postId, userId, content, parentId: parentId ?? null, isFact },
  });
  // 触发通知：评论完成后通知帖子作者（自己评自己不发；失败不影响主流程）
  notifyOnComment(postId, userId).catch(() => {});
  return comment;
}

export async function deleteComment(id: number, userId: number) {
  const c = await prisma.comment.findUnique({ where: { id } });
  if (!c) return { ok: false, reason: 'not_found' };
  if (c.userId !== userId) return { ok: false, reason: 'forbidden' };
  await prisma.comment.delete({ where: { id } });
  return { ok: true };
}
