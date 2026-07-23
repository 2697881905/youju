import { prisma } from '../prisma';
import { Tag } from '@prisma/client';

// 获取所有标签（按使用次数降序）
export async function listTags() {
  return prisma.tag.findMany({ orderBy: { useCount: 'desc' } });
}

// 关注标签（幂等）：仅当新建关注时 Tag.followCount + 1，返回更新后的标签
export async function followTag(userId: number, tagName: string): Promise<Tag> {
  await prisma.$transaction(async (tx) => {
    const existing = await tx.userFollowTag.findUnique({
      where: { userId_tagName: { userId, tagName } },
    });
    if (existing) {
      return; // 幂等：已关注，不重复 +1
    }
    await tx.userFollowTag.create({ data: { userId, tagName } });
    await tx.tag.updateMany({
      where: { name: tagName },
      data: { followCount: { increment: 1 } },
    });
  });
  const tag = await prisma.tag.findFirst({ where: { name: tagName } });
  return tag!;
}

// 取消关注标签：仅当存在关注记录时 Tag.followCount - 1，返回更新后的标签
export async function unfollowTag(userId: number, tagName: string): Promise<Tag> {
  await prisma.$transaction(async (tx) => {
    const deleted = await tx.userFollowTag.deleteMany({
      where: { userId, tagName },
    });
    if (deleted.count > 0) {
      await tx.tag.updateMany({
        where: { name: tagName, followCount: { gt: 0 } },
        data: { followCount: { decrement: 1 } },
      });
    }
  });
  const tag = await prisma.tag.findFirst({ where: { name: tagName } });
  return tag!;
}

// 当前用户关注的标签名列表（按关注时间倒序）
export async function listFollowedTags(userId: number): Promise<string[]> {
  const rows = await prisma.userFollowTag.findMany({
    where: { userId },
    select: { tagName: true },
    orderBy: { createdAt: 'desc' },
  });
  return rows.map((r) => r.tagName);
}
