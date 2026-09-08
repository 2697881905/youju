import { prisma } from '../prisma';
import { DELETED_NICKNAME } from '../utils/userView';
import { isNotificationAllowed } from './notificationPrefService';
import { pushToUser } from './huaweiPush';
// @提及 昵称提取统一走 mentionService（与发帖正文同一口径/正则）
import { MentionRef, extractMentionNames } from './mentionService';
export { extractMentionNames };

// 通知类型（与前端 NotificationType 单一来源对齐）
export type NotificationType = 'comment' | 'up' | 'bookmark' | 'follow' | 'mention' | 'system';

// 依赖帖子的通知类型：帖子被删除（软删除/彻底删除）后，这类通知不应再出现在通知中心
const POST_RELATED_TYPES = ['comment', 'up', 'bookmark', 'mention'];

export interface CreateNotificationInput {
  userId: number; // 接收者
  actorId?: number | null; // 触发者（系统消息为 null）
  type: NotificationType;
  postId?: number | null;
  content: string;
  pinned?: boolean; // 置顶（举报受理/审核等系统重要消息，列表恒在最前）
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
  pinned: boolean;
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
      pinned: input.pinned ?? false,
    },
  });

  // 华为推送：通知落库后下发系统推送（未配置凭证 / 无设备 token 时静默降级，绝不阻断）
  pushToUser(input.userId, pushTitle(input.type), input.content).catch(() => {});
}

// 推送标题按通知类型本地化（正文复用预渲染 content）
function pushTitle(type: string): string {
  switch (type) {
    case 'comment':
      return '新评论';
    case 'up':
      return '新赞';
    case 'bookmark':
      return '新收藏';
    case 'follow':
      return '新粉丝';
    case 'mention':
      return '有人提到了你';
    case 'system':
      return '系统通知';
    default:
      return '有据';
  }
}

// 用户帖子类通知中，帖子仍有效（存在且未移入废纸篓）的 postId 集合
// 用于列表/未读数过滤：帖子删除后其点赞/收藏/评论通知不应出现在通知中心
async function visiblePostIds(userId: number): Promise<number[]> {
  const rows = await prisma.notification.findMany({
    where: { userId, type: { in: POST_RELATED_TYPES }, postId: { not: null } },
    select: { postId: true },
    distinct: ['postId'],
  });
  const postIds: number[] = rows.map((r) => r.postId as number);
  if (postIds.length === 0) return [];
  const posts = await prisma.post.findMany({
    where: { id: { in: postIds }, deletedAt: null },
    select: { id: true },
  });
  return posts.map((p) => p.id);
}

// 构建可展示通知的查询条件：帖子类通知仅在帖子仍有效时返回；follow/system 等无帖子依赖的通知始终返回
async function visibleWhere(userId: number): Promise<any> {
  const validPostIds = await visiblePostIds(userId);
  return validPostIds.length > 0
    ? {
        userId,
        OR: [
          { type: { notIn: POST_RELATED_TYPES } },
          { postId: { in: validPostIds } },
        ],
      }
    : { userId, type: { notIn: POST_RELATED_TYPES } };
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

  const where = await visibleWhere(userId);
  const [rows, total] = await Promise.all([
    prisma.notification.findMany({
      where,
      // 置顶通知恒在最前（举报受理/审核等系统重要消息）；其余按时间倒序
      orderBy: [{ pinned: 'desc' }, { createdAt: 'desc' }],
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
      pinned: n.pinned,
      createdAt: n.createdAt,
      actor: n.actorId !== null && n.actorId !== undefined ? (actorMap.get(n.actorId) ?? null) : null,
    })),
    pagination: { page, limit, total },
  };
}

// 未读总数（与列表同源过滤：不存在的帖子相关通知不计入未读）
export async function unreadCount(userId: number): Promise<number> {
  const where = await visibleWhere(userId);
  return prisma.notification.count({ where: { ...where, read: false } });
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

// 评论中 @提及：命中真实用户则发 mention 通知
// excludeIds：自己/帖子作者/被回复的评论作者等已收过通知的对象，避免重复打扰
// mentionRefs：编辑器显式选择（精确到 userId，调用方已用 resolveMentionRefs 校验）——
//   提供时仅通知选择到的用户（重名用户不会被误@）；缺失时回退按昵称解析（兼容老客户端/手输场景）
export async function notifyCommentMentions(
  postId: number,
  actorId: number,
  content: string,
  excludeIds: ReadonlySet<number>,
  mentionRefs?: MentionRef[]
): Promise<void> {
  const actor = await prisma.user.findUnique({
    where: { id: actorId },
    select: { nickname: true },
  });
  const nickname = actor?.nickname ?? '有人';

  // 显式路径：只通知点选到的精确用户（重名用户不会被误扰）
  if (mentionRefs !== undefined && mentionRefs.length > 0) {
    for (const ref of mentionRefs) {
      if (excludeIds.has(ref.userId)) {
        continue;
      }
      await createNotification({
        userId: ref.userId,
        actorId,
        type: 'mention',
        postId,
        content: `${nickname} 在评论中提到了你`,
      });
    }
    return;
  }

  // 回退路径：按昵称命中全部真实同名用户（保证手输场景不遗漏）
  const names = extractMentionNames(content);
  if (names.length === 0) {
    return;
  }
  const users = await prisma.user.findMany({
    where: { nickname: { in: names }, deletedAt: null },
    select: { id: true },
  });
  if (users.length === 0) {
    return;
  }
  for (const u of users) {
    if (excludeIds.has(u.id)) {
      continue;
    }
    await createNotification({
      userId: u.id,
      actorId,
      type: 'mention',
      postId,
      content: `${nickname} 在评论中提到了你`,
    });
  }
}

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

// 楼中楼回复：通知被回复的评论作者（自己回复自己不发；
// 若被回复人恰为帖子作者，则已有「评论了你的帖子」通知，不重复打扰）
export async function notifyOnCommentReply(
  postId: number,
  actorId: number,
  parent: { userId: number | null; postUserId: number }
): Promise<void> {
  if (parent.userId === null || parent.userId === actorId || parent.userId === parent.postUserId) return;
  const actor = await prisma.user.findUnique({
    where: { id: actorId },
    select: { nickname: true },
  });
  const nickname = actor?.nickname ?? '有人';
  await createNotification({
    userId: parent.userId,
    actorId,
    type: 'comment',
    postId,
    content: `${nickname} 回复了你的评论`,
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

// 评论点赞（顶评论）：通知评论作者（自己顶自己评论不发；postId 带上以便跳转定位）
export async function notifyOnCommentUp(commentId: number, actorId: number): Promise<void> {
  const comment = await prisma.comment.findUnique({
    where: { id: commentId },
    select: { userId: true, postId: true },
  });
  if (!comment || comment.userId === actorId) return; // 评论不存在 / 自己顶自己评论不发
  const actor = await prisma.user.findUnique({
    where: { id: actorId },
    select: { nickname: true },
  });
  const nickname = actor?.nickname ?? '有人';
  await createNotification({
    userId: comment.userId,
    actorId,
    type: 'up',
    postId: comment.postId,
    content: `${nickname} 赞了你的评论`,
  });
}

// 关注：通知被关注者（自己关注自己不发通知；与 notifyOnComment 同构）
export async function notifyOnFollow(receiverId: number, actorId: number): Promise<void> {  if (receiverId === actorId) return; // 自己关注自己不发通知
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
// pinned 为 true 时该通知在消息中心恒置顶（举报受理/审核等重要系统消息）。
export async function notifySystem(
  userId: number,
  content: string,
  postId?: number | null,
  pinned?: boolean
): Promise<void> {
  await createNotification({
    userId,
    actorId: null,
    type: 'system',
    content,
    postId: postId ?? null,
    pinned: pinned ?? false,
  });
}
