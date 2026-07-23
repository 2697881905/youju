// 数据导出路由：GET 返回当前用户全部数据的 JSON 打包
import { Router, Response } from 'express';
import { ok, fail, CODE } from '../utils/response';
import { auth, AuthRequest } from '../middleware/auth';
import { exportUserData } from '../services/exportService';

import { asyncHandler } from '../middleware/asyncHandler';

const router = Router();

// GET /v1/me/export
router.get('/me/export', auth, asyncHandler(async (req: AuthRequest, res: Response) => {
  try {
    const data = await exportUserData(req.userId!);
    return ok(res, data);
  } catch (e) {
    return fail(res, CODE.SERVER_ERROR, (e as Error).message);
  }
}));

export default router;
