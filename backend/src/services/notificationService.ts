import { prisma } from '../prisma';
import { DELETED_NICKNAME } from '../utils/userView';
import { isNotificationAllowed } from './notificationPrefService';

// 通知类型（与前端 NotificationType 单一来源对齐）
export type NotificationType = 'comment' | 'up' | 'bookmark' | 'follow' | 'system';

export interface CreateNotificationInput {
  userId: number; // 接收者
  actorId?: number | null; // 触发者（系统消息为 null）
  type: NotificationType;
  postId?: number | null;
  content: string;
}

// 列表项（含触发者脱敏信息，便于前端直接渲染）
export interface NotificationItem {
  id: number;
  userId: number;
  actorId: number | null;
  type: string;
  postId: number | null;
  content: string;
  read: boolean;
  createdAt: Date;
  actor?: { id: number; nickname: string; avatar: string | null } | null;
}

export interface ListResult {
  list: NotificationItem[];
  pagination: { page: number; limit: number; total: number };
}

// 创建一条通知（内部/触发调用），写入前检查通知偏好：用户关闭该类通知时静默跳过。
export async function createNotification(input: CreateNotificationInput): Promise<void> {
  // 检查用户是否允许此类通知（不存在记录时默认允许）
  const allowed = await isNotificationAllowed(input.userId, input.type);
  if (!allowed) return;

  await prisma.notification.create({
    data: {
      userId: input.userId,
      actorId: input.actorId ?? null,
      type: input.type,
      postId: input.postId ?? null,
      content: input.content,
      read: false,
    },
  });
}

// 用户通知列表（分页，按时间倒序，含触发者信息）
// 设计取舍：Notification 不建 @relation，actor 昵称/头像用单独查询按需补全，避免 Prisma include 推断为 never。
export async function listForUser(
  userId: number,
  params: { page?: number; limit?: number } = {},
): Promise<ListResult> {
  const page = Math.max(1, Number(params.page ?? 1));
  const limit = Math.min(50, Math.max(1, Number(params.limit ?? 20)));
  const skip = (page - 1) * limit;

  const where = { userId };
  const [rows, total] = await Promise.all([
    prisma.notification.findMany({
      where,
      orderBy: { createdAt: 'desc' },
      skip,
      take: limit,
    }),
    prisma.notification.count({ where }),
  ]);

  // 收集 actorId，批量查触发者昵称/头像
  const actorIds: number[] = rows
    .filter((n) => n.actorId !== null && n.actorId !== undefined)
    .map((n) => n.actorId as number);
  const actorMap = new Map<number, { id: number; nickname: string; avatar: string | null }>();
  if (actorIds.length > 0) {
    const actors = await prisma.user.findMany({
      where: { id: { in: actorIds } },
      select: { id: true, nickname: true, avatar: true, deletedAt: true },
    });
    for (const a of actors) {
      if (a.deletedAt) {
        // 已注销触发者：匿名化昵称/头像，前端据 nickname 显示「已注销用户」
        actorMap.set(a.id, { id: a.id, nickname: DELETED_NICKNAME, avatar: null });
      } else {
        actorMap.set(a.id, { id: a.id, nickname: a.nickname, avatar: a.avatar });
      }
    }
  }

  return {
    list: rows.map((n) => ({
      id: n.id,
      userId: n.userId,
      actorId: n.actorId,
      type: n.type,
      postId: n.postId,
      content: n.content,
      read: n.read,
      createdAt: n.createdAt,
      actor: n.actorId !== null && n.actorId !== undefined ? (actorMap.get(n.actorId) ?? null) : null,
    })),
    pagination: { page, limit, total },
  };
}

// 未读总数
export async function unreadCount(userId: number): Promise<number> {
  return prisma.notification.count({ where: { userId, read: false } });
}

// 标记单条已读（校验归属，否则抛错由路由转 403）
export async function markRead(id: number, userId: number): Promise<void> {
  const n = await prisma.notification.findUnique({ where: { id } });
  if (!n) return; // 幂等：不存在视为已处理
  if (n.userId !== userId) {
    const err = new Error('只能操作自己的通知');
    (err as any).reason = 'forbidden';
    throw err;
  }
  await prisma.notification.update({ where: { id }, data: { read: true } });
}

// 全部已读
export async function markAllRead(userId: number): Promise<number> {
  const res = await prisma.notification.updateMany({
    where: { userId, read: false },
    data: { read: true },
  });
  return res.count;
}

// ===== 安全触发辅助（供评论/互动服务调用，绝不阻断主流程） =====

// 评论：通知帖子作者（自己评论自己不发通知）
export async function notifyOnComment(postId: number, actorId: number): Promise<void> {
  const post = await prisma.post.findUnique({ where: { id: postId }, select: { userId: true } });
  if (!post || post.userId === actorId) return;
  const actor = await prisma.user.findUnique({
    where: { id: actorId },
    select: { nickname: true },
  });
  const nickname = actor?.nickname ?? '有人';
  await createNotification({
    userId: post.userId,
    actorId,
    type: 'comment',
    postId,
    content: `${nickname} 评论了你的帖子`,
  });
}

// 顶/收藏：通知帖子作者（自己操作自己不发通知）
export async function notifyOnInteract(
  postId: number,
  actorId: number,
  type: 'up' | 'bookmark',
): Promise<void> {
  const post = await prisma.post.findUnique({ where: { id: postId }, select: { userId: true } });
  if (!post || post.userId === actorId) return;
  const actor = await prisma.user.findUnique({
    where: { id: actorId },
    select: { nickname: true },
  });
  const nickname = actor?.nickname ?? '有人';
  const verb = type === 'up' ? '顶了' : '收藏了';
  await createNotification({
    userId: post.userId,
    actorId,
    type,
    postId,
    content: `${nickname} ${verb}你的帖子`,
  });
}

// 关注：通知被关注者（自己关注自己不发通知；与 notifyOnComment 同构）
export async function notifyOnFollow(receiverId: number, actorId: number): Promise<void> {
  if (receiverId === actorId) return; // 自己关注自己不发通知
  const actor = await prisma.user.findUnique({
    where: { id: actorId },
    select: { nickname: true },
  });
  const nickname = actor?.nickname ?? '有人';
  await createNotification({
    userId: receiverId,
    actorId,
    type: 'follow',
    content: `${nickname} 关注了你`,
  });
}

// 系统通知（actorId=null, type='system'）
// 用于：帖子被举报下架 → 通知作者；审核通过/拒绝 → 通知作者；举报处理完成 → 通知举报人。
export async function notifySystem(
  userId: number,
  content: string,
  postId?: number | null
): Promise<void> {
  await createNotification({
    userId,
    actorId: null,
    type: 'system',
    content,
    postId: postId ?? null,
  });
}
