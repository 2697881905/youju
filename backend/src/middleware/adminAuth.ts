// admin 鉴权中间件（必须在 auth 之后使用，依赖 req.userId）
// 校验 req.userId 是否在 env.adminUserIds（来自 ADMIN_USER_IDS 环境变量）
import { Response, NextFunction } from 'express';
import { AuthRequest } from './auth';
import { fail, CODE } from '../utils/response';
import { env } from '../config/env';

export function adminAuth(req: AuthRequest, res: Response, next: NextFunction) {
  if (!req.userId || !env.adminUserIds.includes(req.userId)) {
    return fail(res, CODE.FORBIDDEN, '无管理员权限', 403);
  }
  return next();
}
