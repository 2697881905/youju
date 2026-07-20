import { Request, Response, NextFunction } from 'express';
import jwt from 'jsonwebtoken';
import { env } from '../config/env';
import { fail, CODE } from '../utils/response';
import { prisma } from '../prisma';

export interface AuthRequest extends Request {
  userId?: number;
}

// Bearer Token 鉴权中间件（async：解析出 userId 后多查一次 User，
// 若 deletedAt 非空则视为已注销，使旧 token 全面失效——替代 token 黑名单）。
export async function auth(req: AuthRequest, res: Response, next: NextFunction): Promise<void> {
  const header = req.headers.authorization;
  if (!header || !header.startsWith('Bearer ')) {
    fail(res, CODE.UNAUTHORIZED, '未登录', 401);
    return;
  }
  let userId: number;
  try {
    const payload = jwt.verify(header.slice(7), env.jwtSecret) as { userId: number };
    userId = payload.userId;
  } catch {
    fail(res, CODE.UNAUTHORIZED, '登录已过期', 401);
    return;
  }
  let user: { deletedAt: Date | null } | null;
  try {
    user = await prisma.user.findUnique({
      where: { id: userId },
      select: { deletedAt: true },
    });
  } catch {
    fail(res, CODE.SERVER_ERROR, '鉴权失败', 500);
    return;
  }
  if (!user || user.deletedAt) {
    fail(res, CODE.UNAUTHORIZED, '账号已注销', 401);
    return;
  }
  req.userId = userId;
  next();
}
