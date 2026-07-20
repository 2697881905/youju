// 通知偏好路由：GET 查询 / PUT 更新当前用户的通知类别开关
import { Router, Response } from 'express';
import { ok, fail, CODE } from '../utils/response';
import { auth, AuthRequest } from '../middleware/auth';
import * as prefService from '../services/notificationPrefService';

const router = Router();

// GET /v1/me/notification-prefs
router.get('/me/notification-prefs', auth, async (req: AuthRequest, res: Response) => {
  try {
    const prefs = await prefService.getPrefs(req.userId!);
    return ok(res, prefs);
  } catch (e) {
    return fail(res, CODE.SERVER_ERROR, (e as Error).message);
  }
});

// PUT /v1/me/notification-prefs
router.put('/me/notification-prefs', auth, async (req: AuthRequest, res: Response) => {
  try {
    const prefs = await prefService.updatePrefs(req.userId!, req.body ?? {});
    return ok(res, prefs);
  } catch (e) {
    return fail(res, CODE.SERVER_ERROR, (e as Error).message);
  }
});

export default router;
