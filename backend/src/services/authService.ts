import { prisma } from '../prisma';
import jwt from 'jsonwebtoken';
import { env } from '../config/env';

// 鸿蒙账号授权登录（MVP：前端传 openId；后续接 Account Kit 真实鉴权）
export async function login(openId: string, nickname?: string, avatar?: string) {
  const user = await prisma.user.upsert({
    where: { openId },
    update: {
      ...(nickname ? { nickname } : {}),
      ...(avatar ? { avatar } : {}),
    },
    create: {
      openId,
      nickname: nickname || '用户' + openId.slice(-4),
      ...(avatar ? { avatar } : {}),
    },
  });

  const token = jwt.sign({ userId: user.id }, env.jwtSecret, {
    expiresIn: env.jwtExpiresIn,
  } as jwt.SignOptions);

  return { token, user };
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
    return { token, user: existing };
  }

  // 新用户：openId 留空，unionID 必填；昵称缺失时生成默认名
  const defaultNickname: string = nickname && nickname.trim().length > 0
    ? nickname
    : '华为用户' + Math.random().toString(36).slice(2, 6);
  const created = await prisma.user.create({
    data: {
      openId: null,
      unionID,
      nickname: defaultNickname,
      ...(avatar ? { avatar } : {}),
    },
  });

  const token = signToken(created.id);
  return { token, user: created };
}

function signToken(userId: number): string {
  return jwt.sign({ userId }, env.jwtSecret, {
    expiresIn: env.jwtExpiresIn,
  } as jwt.SignOptions);
}

export async function updateProfile(userId: number, nickname?: string, avatar?: string) {
  return prisma.user.update({
    where: { id: userId },
    data: {
      ...(nickname ? { nickname } : {}),
      ...(avatar ? { avatar } : {}),
    },
  });
}
