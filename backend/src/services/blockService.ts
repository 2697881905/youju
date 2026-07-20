// 拉黑/静音管理：用户可将他人加入黑名单，阻止对方互动。
// MVP 仅实现 CRUD（拉黑/取消拉黑/列表/查询），互动阻止后续单独迭代。
import { prisma } from '../prisma';

export class BlockError extends Error {
  constructor(message: string) {
    super(message);
    this.name = 'BlockError';
  }
}

// 拉黑用户（幂等，不可自拉黑）
export async function blockUser(userId: number, blockedId: number): Promise<void> {
  if (userId === blockedId) {
    throw new BlockError('不能拉黑自己');
  }
  try {
    await prisma.blocklist.create({ data: { userId, blockedId } });
  } catch (e: any) {
    if (e?.code === 'P2002') {
      // 已存在（unique 冲突）→ 幂等，不报错
      return;
    }
    throw e;
  }
}

// 取消拉黑（幂等）
export async function unblockUser(userId: number, blockedId: number): Promise<void> {
  try {
    await prisma.blocklist.delete({ where: { userId_blockedId: { userId, blockedId } } });
  } catch (e: any) {
    if (e?.code === 'P2025') {
      // 记录不存在 → 幂等
      return;
    }
    throw e;
  }
}

// 拉黑列表（分页，连带被拉黑者基础信息 — 与 followService.listFollowers 同模式）
export async function listBlocked(userId: number, page: number = 1, limit: number = 20) {
  const skip = (page - 1) * limit;
  const rows = await prisma.blocklist.findMany({
    where: { userId },
    orderBy: { createdAt: 'desc' },
    skip,
    take: limit,
  });
  const total = await prisma.blocklist.count({ where: { userId } });

  // 补充被拉黑者的昵称/头像
  const blockedIds = rows.map(r => r.blockedId);
  const users = blockedIds.length > 0
    ? await prisma.user.findMany({ where: { id: { in: blockedIds } } })
    : [];
  const userMap = new Map(users.map(u => [u.id, u]));

  const list = rows.map(r => {
    const u = userMap.get(r.blockedId);
    return {
      id: r.blockedId,
      nickname: u?.deletedAt ? '已注销用户' : (u?.nickname ?? '未知用户'),
      avatar: u?.deletedAt ? null : (u?.avatar ?? null),
      blockedAt: r.createdAt.toISOString(),
    };
  });

  return {
    list,
    pagination: { page, limit, total },
  };
}

// 检查 userA 是否拉黑了 userB
export async function isBlocked(userId: number, blockedId: number): Promise<boolean> {
  const row = await prisma.blocklist.findUnique({
    where: { userId_blockedId: { userId, blockedId } },
  });
  return row !== null;
}
