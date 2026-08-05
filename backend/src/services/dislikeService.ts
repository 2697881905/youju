// 不喜欢（减少推送）管理：用户可对作者标记"不喜欢"，使该作者帖子在推荐流中不再出现。
// 与拉黑的区别：单向（仅 viewer 侧过滤），latest/following 流保留，作者主页/搜索仍可见。
// 结构仿 blockService.ts，保持幂等与错误处理一致。
import { prisma } from '../prisma';

export class DislikeError extends Error {
  constructor(message: string) {
    super(message);
    this.name = 'DislikeError';
  }
}

// 不喜欢某作者（幂等，不可对自己操作）
export async function dislikeUser(userId: number, dislikedId: number): Promise<void> {
  if (userId === dislikedId) {
    throw new DislikeError('不能对自己操作');
  }
  try {
    await prisma.dislike.create({ data: { userId, dislikedId } });
  } catch (e: any) {
    if (e?.code === 'P2002') {
      // 已存在（unique 冲突）→ 幂等，不报错
      return;
    }
    throw e;
  }
}

// 取消不喜欢（幂等）
export async function undislikeUser(userId: number, dislikedId: number): Promise<void> {
  try {
    await prisma.dislike.delete({ where: { userId_dislikedId: { userId, dislikedId } } });
  } catch (e: any) {
    if (e?.code === 'P2025') {
      // 记录不存在 → 幂等
      return;
    }
    throw e;
  }
}

// 不喜欢列表（分页，连带被不喜欢者基础信息 — 与 listBlocked 同模式）
export async function listDisliked(userId: number, page: number = 1, limit: number = 20) {
  const skip = (page - 1) * limit;
  const rows = await prisma.dislike.findMany({
    where: { userId },
    orderBy: { createdAt: 'desc' },
    skip,
    take: limit,
  });
  const total = await prisma.dislike.count({ where: { userId } });

  // 补充被不喜欢者的昵称/头像
  const dislikedIds = rows.map(r => r.dislikedId);
  const users = dislikedIds.length > 0
    ? await prisma.user.findMany({ where: { id: { in: dislikedIds } } })
    : [];
  const userMap = new Map(users.map(u => [u.id, u]));

  const list = rows.map(r => {
    const u = userMap.get(r.dislikedId);
    return {
      id: r.dislikedId,
      nickname: u?.deletedAt ? '已注销用户' : (u?.nickname ?? '未知用户'),
      avatar: u?.deletedAt ? null : (u?.avatar ?? null),
      dislikedAt: r.createdAt.toISOString(),
    };
  });

  return {
    list,
    pagination: { page, limit, total },
  };
}

// 检查 userId 是否 dislike 了 dislikedId
export async function isDisliked(userId: number, dislikedId: number): Promise<boolean> {
  const row = await prisma.dislike.findUnique({
    where: { userId_dislikedId: { userId, dislikedId } },
  });
  return row !== null;
}
