import { Request, Response, NextFunction } from 'express';
import jwt from 'jsonwebtoken';
import { env } from '../config/env';
import { fail, CODE } from '../utils/response';

export interface AuthRequest extends Request {
  userId?: number;
}

// Bearer Token 鉴权中间件
export function auth(req: AuthRequest, res: Response, next: NextFunction) {
  const header = req.headers.authorization;
  if (!header || !header.startsWith('Bearer ')) {
    return fail(res, CODE.UNAUTHORIZED, '未登录', 401);
  }
  try {
    const payload = jwt.verify(header.slice(7), env.jwtSecret) as { userId: number };
    req.userId = payload.userId;
    return next();
  } catch {
    return fail(res, CODE.UNAUTHORIZED, '登录已过期', 401);
  }
}
