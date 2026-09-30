// 华为推送 Token 注册路由（POST /v1/push/register、DELETE /v1/push/token）
// 客户端在登录成功 / 冷启动会话恢复后调用 getToken() 取设备 Token 并上报；
// 登出或注销账号前调用 DELETE 解绑，避免给已登出的设备继续下发他人动态通知。
import { Router, Response } from 'express';
import { ok, fail, internalError, CODE } from '../utils/response';
import { auth, AuthRequest } from '../middleware/auth';
import { prisma } from '../prisma';
import { asyncHandler } from '../middleware/asyncHandler';

// 该路由挂在 /v1 下，因此路径为完整路径
const router = Router();

// 注册/更新华为推送 Token：POST /v1/push/register
// 前端登录后调用 pushService.getToken() 取得设备 Token 并上报；同一用户对同一 Token 幂等。
router.post('/push/register', auth, asyncHandler(async (req: AuthRequest, res: Response) => {
  const { token, deviceId } = req.body ?? {};
  if (!token || typeof token !== 'string' || token.trim() === '') {
    return fail(res, CODE.BAD_REQUEST, 'token 必填');
  }
  const t = token.trim();
  try {
    await prisma.$transaction([
      prisma.pushToken.deleteMany({
        where: { token: t, userId: { not: req.userId! } },
      }),
      prisma.pushToken.upsert({
        where: { token: t },
        update: { userId: req.userId!, updatedAt: new Date(), deviceId: deviceId ?? null },
        create: { userId: req.userId!, token: t, deviceId: deviceId ?? null },
      }),
    ]);
    return ok(res, null, '已注册');
  } catch (e) {
    return internalError(res, 'push.register', e);
  }
}));

// 解绑推送 Token：DELETE /v1/push/token?token=xxx
// token 走 query 而非 body：HarmonyOS 的 http DELETE 带 body 行为不稳定，且无需额外校验。
// 只删自己的记录（多设备互不干扰）；token 为空视为已解绑，返回成功保证登出流程不被卡住。
router.delete('/push/token', auth, asyncHandler(async (req: AuthRequest, res: Response) => {
  const t = typeof req.query.token === 'string' ? req.query.token.trim() : '';
  if (t === '') {
    return ok(res, null, '已解绑');
  }
  try {
    await prisma.pushToken.deleteMany({ where: { token: t, userId: req.userId! } });
    return ok(res, null, '已解绑');
  } catch (e) {
    return internalError(res, 'push.unregister', e);
  }
}));

export default router;
