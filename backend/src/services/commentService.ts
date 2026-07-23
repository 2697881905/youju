import { prisma } from '../prisma';
import { notifyOnComment } from './notificationService';
import { sensitiveWordService } from './sensitiveWordService';
import { SensitiveWordError } from '../utils/errors';

export async function listComments(postId: number, page = 1, limit = 50) {
  const skip = (page - 1) * limit;
  const where = { postId, status: 1 }; // 仅返回正常评论（隐藏被举报下架的）
  const [list, total] = await Promise.all([
    prisma.comment.findMany({
      where,
      orderBy: { upCount: 'desc' },
      skip,
      take: limit,
      include: { user: { select: { id: true, nickname: true, avatar: true } } },
    }),
    prisma.comment.count({ where }),
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
  // 敏感词前置检测
  if (sensitiveWordService.checkText(content)) {
    throw new SensitiveWordError();
  }
  const [comment] = await prisma.$transaction([
    prisma.comment.create({
      data: { postId, userId, content, parentId: parentId ?? null, isFact },
    }),
    // 维护帖子评论数（与删除时 decrement 配对，避免评论数失真）
    prisma.post.update({ where: { id: postId }, data: { commentCount: { increment: 1 } } }),
  ]);
  // 触发通知：评论完成后通知帖子作者（自己评自己不发；失败不影响主流程）
  notifyOnComment(postId, userId).catch(() => {});
  return comment;
}

export async function deleteComment(id: number, userId: number) {
  const c = await prisma.comment.findUnique({ where: { id } });
  if (!c) return { ok: false, reason: 'not_found' };
  if (c.userId !== userId) return { ok: false, reason: 'forbidden' };
  await prisma.$transaction([
    prisma.comment.delete({ where: { id } }),
    // 维护帖子评论数（与发布时 increment 配对）
    prisma.post.update({ where: { id: c.postId }, data: { commentCount: { decrement: 1 } } }),
  ]);
  return { ok: true };
}
