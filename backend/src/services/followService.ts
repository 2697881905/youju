import { prisma } from '../prisma';
import { notifyOnFollow } from './notificationService';
import { DELETED_NICKNAME } from '../utils/userView';
import * as blockService from './blockService';
import * as dislikeService from './dislikeService';

// 关注领域自定义错误（与 accountBindingService 的 AccountError 同构）
export class FollowError extends Error {
  code: number;
  httpStatus: number;
  constructor(message: string, code: number, httpStatus: number) {
    super(message);
    this.name = 'FollowError';
    this.code = code;
    this.httpStatus = httpStatus;
  }
}

// 解析路径中的 :id（可为 'me' 或数字 id），非法则抛 FollowError
function resolveTargetId(raw: string, viewerId: number): number {
  if (raw === 'me') {
    return viewerId;
  }
  const n = Number(raw);
  if (!Number.isInteger(n) || n <= 0) {
    throw new FollowError('无效的用户 id', 400, 400);
  }
  return n;
}

export interface FollowListParams {
  page?: number;
  limit?: number;
}

// 关注他人（校验目标存在、不可自关；仅首次创建关系时发送通知）
export async function followUser(viewerId: number, rawTargetId: string): Promise<void> {
  const targetId = resolveTargetId(rawTargetId, viewerId);
  if (targetId === viewerId) {
    throw new FollowError('不能关注自己', 400, 400);
  }
  const target = await prisma.user.findUnique({ where: { id: targetId } });
  if (!target) {
    throw new FollowError('用户不存在', 404, 404);
  }
  // 隐私：对方关闭「允许关注」则拒绝
  const ps = await prisma.privacySettings.findUnique({ where: { userId: targetId } });
  if (ps && ps.allowFollow === false) {
    throw new FollowError('对方已关闭被关注', 403, 403);
  }
  const where = { followerId_followingId: { followerId: viewerId, followingId: targetId } };
  const existing = await prisma.follow.findUnique({ where });
  if (existing) {
    return;
  }
  try {
    await prisma.follow.create({ data: { followerId: viewerId, followingId: targetId } });
  } catch (e: any) {
    if (e?.code === 'P2002') {
      return;
    }
    throw e;
  }
  // 触发关注通知：自己关注他人，失败绝不阻断主流程（与 interactService 一致）
  notifyOnFollow(targetId, viewerId).catch(() => {});
}

// 取消关注（deleteMany 幂等，未关注也不报错）
export async function unfollowUser(viewerId: number, rawTargetId: string): Promise<void> {
  const targetId = resolveTargetId(rawTargetId, viewerId);
  await prisma.follow.deleteMany({
    where: { followerId: viewerId, followingId: targetId },
  });
}

// 他人/自己资料（含 runtime 聚合计数 + 关系态）
export async function getUserProfile(viewerId: number, rawTargetId: string) {
  const targetId = resolveTargetId(rawTargetId, viewerId);
  const user = await prisma.user.findUnique({ where: { id: targetId } });
  if (!user) {
    throw new FollowError('用户不存在', 404, 404);
  }
  const [followingCount, followerCount, postCount, isFollowing, isMutual, likesAgg, isBlocked, isDisliked] = await Promise.all([
    prisma.follow.count({ where: { followerId: targetId } }),
    prisma.follow.count({ where: { followingId: targetId } }),
    prisma.post.count({ where: { userId: targetId, status: 1, deletedAt: null } }),
    prisma.follow.count({ where: { followerId: viewerId, followingId: targetId } }),
    prisma.follow.count({ where: { followerId: targetId, followingId: viewerId } }),
    // 获赞总数：该用户全部已发布帖的点赞计数之和（排除软删/待审帖）
    prisma.post.aggregate({ _sum: { upCount: true }, where: { userId: targetId, status: 1, deletedAt: null } }),
    // 拉黑/不喜欢状态（viewer → target，单向）
    blockService.isBlocked(viewerId, targetId),
    dislikeService.isDisliked(viewerId, targetId),
  ]);
  const totalLikes = Number(likesAgg._sum?.upCount ?? 0);
  // 已注销用户：匿名化昵称/头像/bio，并标记 deleted，前端据 deleted 降级展示。
  if (user.deletedAt) {
    return {
      id: user.id,
      nickname: DELETED_NICKNAME,
      avatar: null,
      profileBackground: null,
      bio: null,
      gender: null,
      postCount,
      followingCount,
      followerCount,
      totalLikes,
      isFollowing: false,
      isMutual: false,
      isBlocked: false,
      isDisliked: false,
      deleted: true,
    };
  }
  return {
    id: user.id,
    nickname: user.nickname,
    avatar: user.avatar,
    profileBackground: user.profileBackground,
    bio: user.bio,
    gender: user.gender,
    postCount,
    followingCount,
    followerCount,
    totalLikes,
    isFollowing: isFollowing > 0,
    isMutual: isMutual > 0,
    isBlocked,
    isDisliked,
    deleted: false,
  };
}

// 关注/粉丝列表内部实现（mode 切换 following/followers）
async function listFollows(
  viewerId: number,
  rawTargetId: string,
  mode: 'following' | 'followers',
  params: FollowListParams,
) {
  const targetId = resolveTargetId(rawTargetId, viewerId);
  const page = Math.max(1, Number(params.page ?? 1));
  const limit = Math.min(50, Math.max(1, Number(params.limit ?? 20)));
  const skip = (page - 1) * limit;

  const where = mode === 'following' ? { followerId: targetId } : { followingId: targetId };
  const [rows, total] = await Promise.all([
    prisma.follow.findMany({
      where,
      orderBy: { createdAt: 'desc' },
      skip,
      take: limit,
    }),
    prisma.follow.count({ where }),
  ]);

  // 收集对方 id：关注列表取 followingId，粉丝列表取 followerId
  const otherIds: number[] = rows.map((r) => (mode === 'following' ? r.followingId : r.followerId));

  // 批量补 user 信息（沿 Notification 取向：标量外键 + findMany 补 user）
  const userMap = new Map<
    number,
    { id: number; nickname: string; avatar: string | null; bio: string | null; deletedAt: Date | null }
  >();
  if (otherIds.length > 0) {
    const users = await prisma.user.findMany({
      where: { id: { in: otherIds } },
      select: { id: true, nickname: true, avatar: true, bio: true, deletedAt: true },
    });
    for (const u of users) {
      userMap.set(u.id, {
        id: u.id,
        nickname: u.nickname,
        avatar: u.avatar,
        bio: u.bio,
        deletedAt: u.deletedAt,
      });
    }
  }

  // 计算 viewer 是否已关注列表中的每一项（粉丝列表用于「回关」态）
  const followingMap = new Map<number, boolean>();
  if (otherIds.length > 0) {
    const fRows = await prisma.follow.findMany({
      where: { followerId: viewerId, followingId: { in: otherIds } },
      select: { followingId: true },
    });
    for (const f of fRows) {
      followingMap.set(f.followingId, true);
    }
  }

  const list = rows.map((r) => {
    const uid = mode === 'following' ? r.followingId : r.followerId;
    const u = userMap.get(uid);
    const deleted = u?.deletedAt != null;
    return {
      id: u?.id ?? uid,
      nickname: deleted ? DELETED_NICKNAME : (u?.nickname ?? '用户'),
      avatar: deleted ? null : (u?.avatar ?? null),
      bio: deleted ? null : (u?.bio ?? null),
      isFollowing: followingMap.get(uid) ?? false,
      deleted,
    };
  });

  return { list, pagination: { page, limit, total } };
}

// 关注列表：GET /v1/users/:id/following
export function listFollowing(
  viewerId: number,
  rawTargetId: string,
  params: FollowListParams = {},
) {
  return listFollows(viewerId, rawTargetId, 'following', params);
}

// 粉丝列表：GET /v1/users/:id/followers
export function listFollowers(
  viewerId: number,
  rawTargetId: string,
  params: FollowListParams = {},
) {
  return listFollows(viewerId, rawTargetId, 'followers', params);
}
