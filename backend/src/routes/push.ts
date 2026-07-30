import { Router, Response } from 'express';
import { ok, fail, CODE } from '../utils/response';
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
    return fail(res, CODE.SERVER_ERROR, (e as Error).message);
  }
}));

export default router;
