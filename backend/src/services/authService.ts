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

export async function updateProfile(userId: number, nickname?: string, avatar?: string) {
  return prisma.user.update({
    where: { id: userId },
    data: {
      ...(nickname ? { nickname } : {}),
      ...(avatar ? { avatar } : {}),
    },
  });
}
