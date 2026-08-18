// 隐私设置路由：GET 查询 / PUT 更新当前用户的隐私设置
import { Router, Response } from 'express';
import { ok, fail, internalError, CODE } from '../utils/response';
import { auth, AuthRequest } from '../middleware/auth';
import * as privacyService from '../services/privacyService';
import { ValidationError } from '../utils/errors';

const router = Router();

// GET /v1/me/privacy
router.get('/me/privacy', auth, async (req: AuthRequest, res: Response) => {
  try {
    const settings = await privacyService.getSettings(req.userId!);
    return ok(res, settings);
  } catch (e) {
    return internalError(res, 'privacy.get', e);
  }
});

// PUT /v1/me/privacy
router.put('/me/privacy', auth, async (req: AuthRequest, res: Response) => {
  try {
    const settings = await privacyService.updateSettings(req.userId!, req.body ?? {});
    return ok(res, settings);
  } catch (e) {
    if (e instanceof ValidationError) {
      return fail(res, CODE.BAD_REQUEST, e.message, 400);
    }
    return internalError(res, 'privacy.update', e);
  }
});

export default router;
