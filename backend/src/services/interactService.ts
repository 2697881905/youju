import { prisma } from '../prisma';

// 顶帖子（幂等：唯一约束 userId+postId）
export async function upPost(postId: number, userId: number) {
  await prisma.up.upsert({
    where: { userId_postId: { userId, postId } },
    update: {},
    create: { userId, postId },
  });
  await prisma.post.update({
    where: { id: postId },
    data: { upCount: { increment: 1 } },
  });
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
  await prisma.bookmark.upsert({
    where: { userId_postId: { userId, postId } },
    update: {},
    create: { userId, postId },
  });
  await prisma.post.update({
    where: { id: postId },
    data: { bookmarkCount: { increment: 1 } },
  });
}

export async function cancelBookmark(postId: number, userId: number) {
  const existing = await prisma.bookmark.findUnique({ where: { userId_postId: { userId, postId } } });
  if (existing) {
    await prisma.bookmark.delete({ where: { userId_postId: { userId, postId } } });
    await prisma.post.update({ where: { id: postId }, data: { bookmarkCount: { decrement: 1 } } });
  }
}
