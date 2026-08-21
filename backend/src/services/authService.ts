import { prisma } from '../prisma';
import jwt from 'jsonwebtoken';
import { env } from '../config/env';
import { sessionUserView } from '../utils/userView';
import { enqueueMediaDeletion } from './mediaDeletionService';

// 附加 isAdmin 标记（运行时由 env.adminUserIds 计算，避免改动 DB schema）
function withIsAdmin(user: any) {
  return sessionUserView(user, env.adminUserIds.includes(user.id));
}

// 鸿蒙账号授权登录（MVP：前端传 openId；后续接 Account Kit 真实鉴权）
export async function login(openId: string, nickname?: string, avatar?: string) {
  const existing = await prisma.user.findUnique({ where: { openId } });
  const isNewUser: boolean = existing === null;
  const user = existing === null
    ? await prisma.user.create({
      data: {
        openId,
        nickname: nickname || '用户' + openId.slice(-4),
        ...(avatar ? { avatar } : {}),
      },
    })
    : await prisma.user.update({
      where: { id: existing.id },
      data: {
        ...(nickname ? { nickname } : {}),
        ...(avatar ? { avatar } : {}),
      },
    });

  const token = jwt.sign({ userId: user.id }, env.jwtSecret, {
    expiresIn: env.jwtExpiresIn,
  } as jwt.SignOptions);

  return { token, user: withIsAdmin(user), isNewUser };
}

// 华为账号登录（按 unionID 落地用户，与 openId 登录并存）
export async function loginWithHuawei(
  unionID: string,
  nickname?: string,
  avatar?: string,
) {
  // 已存在则直接返回原用户（不覆盖昵称/头像，保留用户此前修改）
  const existing = await prisma.user.findUnique({ where: { unionID } });
  if (existing) {
    const token = signToken(existing.id);
    return { token, user: withIsAdmin(existing), isNewUser: false };
  }

  // 新用户：openId 留空，unionID 必填。
  // 华为 profile.nickName 通常是“华为用户xxxx”等平台昵称，不作为有据的默认昵称；
  // 用户后续仍可在编辑资料中主动修改，已有用户也在上方保持原昵称不变。
  const defaultNickname: string = '据友' + String(Math.floor(100000 + Math.random() * 900000));
  const created = await prisma.user.create({
    data: {
      openId: null,
      unionID,
      nickname: defaultNickname,
      ...(avatar ? { avatar } : {}),
    },
  });

  const token = signToken(created.id);
  return { token, user: withIsAdmin(created), isNewUser: true };
}

function signToken(userId: number): string {
  return jwt.sign({ userId }, env.jwtSecret, {
    expiresIn: env.jwtExpiresIn,
  } as jwt.SignOptions);
}

// 更新个人信息（昵称/头像/主页背景/简介/性别）；仅传入的字段才更新。
export async function updateProfile(
  userId: number,
  nickname?: string,
  avatar?: string,
  profileBackground?: string,
  bio?: string,
  gender?: number | null,
) {
  const user = await prisma.$transaction(async (tx) => {
    const previous = await tx.user.findUnique({
      where: { id: userId },
      select: { avatar: true, profileBackground: true },
    });
    const updated = await tx.user.update({
      where: { id: userId },
      data: {
        ...(nickname ? { nickname } : {}),
        ...(avatar ? { avatar } : {}),
        ...(profileBackground !== undefined ? { profileBackground } : {}),
        ...(bio !== undefined ? { bio } : {}),
        ...(gender !== undefined ? { gender } : {}),
      },
    });
    const obsolete: Array<string | null | undefined> = [];
    if (avatar !== undefined && avatar !== previous?.avatar) {
      obsolete.push(previous?.avatar);
    }
    if (profileBackground !== undefined && profileBackground !== previous?.profileBackground) {
      obsolete.push(previous?.profileBackground);
    }
    await enqueueMediaDeletion(tx, obsolete);
    return updated;
  });
  return withIsAdmin(user);
}

// 注销（软删）：置 deletedAt + 匿名化昵称 + 清空头像。
// 保留 posts/comments（FK 不变）；经核实 nickname 无 @@unique，可直接赋固定串。
export const DELETED_NICKNAME = '已注销用户';

export async function deactivateUser(userId: number) {
  return prisma.$transaction(async (tx) => {
    const [user, posts] = await Promise.all([
      tx.user.findUnique({ where: { id: userId }, select: { avatar: true, profileBackground: true } }),
      tx.post.findMany({
        where: { userId },
        select: { coverImage: true, videoUrl: true, videoCover: true, images: true },
      }),
    ]);
    const mediaValues: Array<string | null | undefined | unknown> = [user?.avatar, user?.profileBackground];
    for (const post of posts) {
      mediaValues.push(post.coverImage, post.videoUrl, post.videoCover, post.images);
    }
    await enqueueMediaDeletion(tx, mediaValues);
    await tx.pushToken.deleteMany({ where: { userId } });
    await tx.userBinding.deleteMany({ where: { userId } });
    return tx.user.update({
      where: { id: userId },
      data: {
        deletedAt: new Date(),
        nickname: DELETED_NICKNAME,
        avatar: null,
        profileBackground: null,
        bio: null,
        gender: null,
        openId: null,
        unionID: null,
      },
    });
  });
}

// 记录隐私政策同意（PIPL 可追溯）：落地同意版本与时间戳。
export async function recordPrivacyConsent(userId: number, version: string) {
  return prisma.user.update({
    where: { id: userId },
    data: { privacyPolicyVersion: version, privacyAgreedAt: new Date() },
  });
}
