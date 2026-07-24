// 私信领域：发送（含 dmPolicy + 拉黑权限校验）、会话列表、历史、标记已读、未读总数。
// MVP 仅文字消息；两两人配对即一条会话，不单独建会话表。
import { prisma } from '../prisma';
import { DmPolicy } from './privacyService';
import { DELETED_NICKNAME } from '../utils/userView';

// 私信领域自定义错误（与 FollowError / AccountError 同构）
export class MessageError extends Error {
  code: number;
  httpStatus: number;
  constructor(message: string, code: number, httpStatus: number) {
    super(message);
    this.name = 'MessageError';
    this.code = code;
    this.httpStatus = httpStatus;
  }
}

export interface DmPeer {
  id: number;
  nickname: string;
  avatar: string | null;
  deleted: boolean;
}

export interface Conversation {
  peer: DmPeer;
  lastContent: string;
  lastSenderId: number;
  lastAt: string; // ISO
  unreadCount: number;
}

export interface DmMessage {
  id: number;
  senderId: number;
  receiverId: number;
  content: string;
  read: boolean;
  createdAt: string; // ISO
}

const MAX_LEN = 2000;

// 校验 sender 是否允许给 receiver 发私信（依据 receiver 的 dmPolicy + 拉黑）
async function assertCanMessage(senderId: number, receiverId: number): Promise<void> {
  if (senderId === receiverId) {
    throw new MessageError('不能给自己发私信', 400, 400);
  }
  const receiver = await prisma.user.findUnique({ where: { id: receiverId } });
  if (!receiver) {
    throw new MessageError('用户不存在', 404, 404);
  }
  if (receiver.deletedAt) {
    throw new MessageError('该用户已注销', 404, 404);
  }
  // 拉黑拦截：receiver 拉黑了 sender
  const blocked = await prisma.blocklist.findUnique({
    where: { userId_blockedId: { userId: receiverId, blockedId: senderId } },
  });
  if (blocked) {
    throw new MessageError('对方已屏蔽你，无法发送私信', 403, 403);
  }
  // 读取 receiver 的私信策略
  const ps = await prisma.privacySettings.findUnique({ where: { userId: receiverId } });
  const policy: DmPolicy = (ps?.dmPolicy as DmPolicy) ?? 'all';
  if (policy === 'all') {
    return;
  }
  if (policy === 'followers') {
    // 发送方必须是接收方的粉丝（sender follows receiver）
    const f = await prisma.follow.findUnique({
      where: { followerId_followingId: { followerId: senderId, followingId: receiverId } },
    });
    if (!f) {
      throw new MessageError('对方仅接受粉丝的私信', 403, 403);
    }
    return;
  }
  if (policy === 'mutual') {
    // 双方互相关注
    const [a, b] = await Promise.all([
      prisma.follow.findUnique({
        where: { followerId_followingId: { followerId: senderId, followingId: receiverId } },
      }),
      prisma.follow.findUnique({
        where: { followerId_followingId: { followerId: receiverId, followingId: senderId } },
      }),
    ]);
    if (!a || !b) {
      throw new MessageError('对方仅接受互关好友的私信', 403, 403);
    }
  }
}

// 发送私信（权限校验失败抛 MessageError）
export async function sendMessage(
  senderId: number,
  receiverId: number,
  content: string,
): Promise<DmMessage> {
  const text: string = (content ?? '').trim();
  if (text.length === 0) {
    throw new MessageError('私信内容不能为空', 400, 400);
  }
  if (text.length > MAX_LEN) {
    throw new MessageError('私信内容过长', 400, 400);
  }
  await assertCanMessage(senderId, receiverId);
  const msg = await prisma.message.create({
    data: { senderId, receiverId, content: text },
  });
  return {
    id: msg.id,
    senderId: msg.senderId,
    receiverId: msg.receiverId,
    content: msg.content,
    read: msg.read,
    createdAt: msg.createdAt.toISOString(),
  };
}

// 会话列表：每对联系人取最近一条消息为代表，按最近活跃时间倒序；附对方资料与未读数
export async function listConversations(viewerId: number): Promise<Conversation[]> {
  // 用原生 SQL 按 (两人配对) 取每组最近一条消息 id（MySQL 的 LEAST/GREATEST）
  const rows: any[] = await prisma.$queryRawUnsafe(
    `SELECT m.* FROM Message m
     INNER JOIN (
       SELECT LEAST(senderId, receiverId) AS a, GREATEST(senderId, receiverId) AS b, MAX(id) AS maxId
       FROM Message
       WHERE senderId = ? OR receiverId = ?
       GROUP BY LEAST(senderId, receiverId), GREATEST(senderId, receiverId)
     ) latest ON m.id = latest.maxId
     ORDER BY m.createdAt DESC`,
    viewerId,
    viewerId,
  );

  if (!rows || rows.length === 0) {
    return [];
  }

  const peerIds: number[] = rows.map((r) => (r.senderId === viewerId ? r.receiverId : r.senderId));
  const users = await prisma.user.findMany({
    where: { id: { in: peerIds } },
    select: { id: true, nickname: true, avatar: true, deletedAt: true },
  });
  const userMap = new Map<number, { nickname: string; avatar: string | null; deletedAt: Date | null }>();
  for (const u of users) {
    userMap.set(u.id, { nickname: u.nickname, avatar: u.avatar, deletedAt: u.deletedAt });
  }

  // 未读：receiverId=viewerId 且未读的、按发送方分组计数
  const unreadRows = await prisma.message.groupBy({
    by: ['senderId'],
    where: { receiverId: viewerId, read: false, senderId: { in: peerIds } },
    _count: { _all: true },
  });
  const unreadMap = new Map<number, number>();
  for (const u of unreadRows) {
    unreadMap.set(u.senderId, u._count._all);
  }

  return rows.map((r) => {
    const peerId: number = r.senderId === viewerId ? r.receiverId : r.senderId;
    const u = userMap.get(peerId);
    const deleted: boolean = !!u?.deletedAt;
    return {
      peer: {
        id: peerId,
        nickname: deleted ? DELETED_NICKNAME : (u?.nickname ?? '用户'),
        avatar: deleted ? null : (u?.avatar ?? null),
        deleted,
      },
      lastContent: r.content,
      lastSenderId: r.senderId,
      lastAt: new Date(r.createdAt).toISOString(),
      unreadCount: unreadMap.get(peerId) ?? 0,
    };
  });
}

// 与某用户的私信历史（旧→新），分页；同时标记这些消息为已读由独立接口处理
export async function getMessages(
  viewerId: number,
  peerId: number,
  page: number = 1,
  limit: number = 30,
): Promise<DmMessage[]> {
  const p = Math.max(1, page);
  const take = Math.min(50, Math.max(1, limit));
  const rows = await prisma.message.findMany({
    where: {
      OR: [
        { senderId: viewerId, receiverId: peerId },
        { senderId: peerId, receiverId: viewerId },
      ],
    },
    orderBy: { createdAt: 'asc' },
    skip: (p - 1) * take,
    take,
  });
  return rows.map((m) => ({
    id: m.id,
    senderId: m.senderId,
    receiverId: m.receiverId,
    content: m.content,
    read: m.read,
    createdAt: m.createdAt.toISOString(),
  }));
}

// 标记与某用户的私信为已读（接收方=viewerId），返回更新的条数
export async function markRead(viewerId: number, peerId: number): Promise<number> {
  const res = await prisma.message.updateMany({
    where: { receiverId: viewerId, senderId: peerId, read: false },
    data: { read: true },
  });
  return res.count;
}

// 当前用户私信未读总数
export async function getUnreadCount(viewerId: number): Promise<number> {
  return prisma.message.count({ where: { receiverId: viewerId, read: false } });
}
