import { prisma } from '../prisma';
import { notifyOnInteract } from './notificationService';

// 顶帖子（幂等：唯一约束 userId+postId）
export async function upPost(postId: number, userId: number) {
  try {
    // 仅当尚未顶过时创建记录 + 计数 +1；已顶过则唯一约束兜底，不重复计数
    await prisma.$transaction([
      prisma.up.create({ data: { userId, postId } }),
      prisma.post.update({ where: { id: postId }, data: { upCount: { increment: 1 } } }),
    ]);
  } catch (e: any) {
    if (e?.code === 'P2002') return; // 并发重复顶：唯一约束冲突，视为已顶，不重复计数
    throw e;
  }
  // 触发通知：顶了帖子（自己顶自己不发；失败不影响主流程）
  notifyOnInteract(postId, userId, 'up').catch(() => {});
}

export async function cancelUp(postId: number, userId: number) {
  const existing = await prisma.up.findUnique({ where: { userId_postId: { userId, postId } } });
  if (existing) {
    await prisma.up.delete({ where: { userId_postId: { userId, postId } } });
    await prisma.post.update({ where: { id: postId }, data: { upCount: { decrement: 1 } } });
  }
}

// 抄作业（收藏，幂等）
export async function bookmarkPost(postId: number, userId: number) {
  try {
    // 仅当尚未收藏时创建记录 + 计数 +1；已收藏则唯一约束兜底，不重复计数
    await prisma.$transaction([
      prisma.bookmark.create({ data: { userId, postId } }),
      prisma.post.update({ where: { id: postId }, data: { bookmarkCount: { increment: 1 } } }),
    ]);
  } catch (e: any) {
    if (e?.code === 'P2002') return; // 并发重复收藏：唯一约束冲突，视为已收藏，不重复计数
    throw e;
  }
  // 触发通知：收藏了帖子（自己藏自己不发；失败不影响主流程）
  notifyOnInteract(postId, userId, 'bookmark').catch(() => {});
}

export async function cancelBookmark(postId: number, userId: number) {
  const existing = await prisma.bookmark.findUnique({ where: { userId_postId: { userId, postId } } });
  if (existing) {
    await prisma.bookmark.delete({ where: { userId_postId: { userId, postId } } });
    await prisma.post.update({ where: { id: postId }, data: { bookmarkCount: { decrement: 1 } } });
  }
}
