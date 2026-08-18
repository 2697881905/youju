// 不喜欢（减少推送）管理路由：列表 / 不喜欢 / 取消不喜欢
// 仿 block.ts 结构，均需 auth 中间件
import { Router, Response } from 'express';
import { ok, fail, internalError, CODE } from '../utils/response';
import { auth, AuthRequest } from '../middleware/auth';
import * as dislikeService from '../services/dislikeService';

import { asyncHandler } from '../middleware/asyncHandler';

const router = Router();

// GET /v1/me/dislikelist?page=1&limit=20  不喜欢列表（分页）
router.get('/me/dislikelist', auth, asyncHandler(async (req: AuthRequest, res: Response) => {
  try {
    const page = req.query.page ? Number(req.query.page) : 1;
    const limit = req.query.limit ? Number(req.query.limit) : 20;
    const data = await dislikeService.listDisliked(req.userId!, page, limit);
    return ok(res, data);
  } catch (e) {
    return internalError(res, 'dislike.list', e);
  }
}));

// POST /v1/me/dislike/:dislikedId  不喜欢某作者（减少推送）
router.post('/me/dislike/:dislikedId', auth, asyncHandler(async (req: AuthRequest, res: Response) => {
  try {
    const dislikedId = Number(req.params.dislikedId);
    if (!dislikedId || isNaN(dislikedId)) {
      return fail(res, CODE.BAD_REQUEST, '无效的用户 ID');
    }
    await dislikeService.dislikeUser(req.userId!, dislikedId);
    return ok(res, { disliked: true });
  } catch (e) {
    if (e instanceof dislikeService.DislikeError) {
      return fail(res, CODE.BAD_REQUEST, e.message);
    }
    return internalError(res, 'dislike.create', e);
  }
}));

// DELETE /v1/me/dislike/:dislikedId  取消不喜欢
router.delete('/me/dislike/:dislikedId', auth, asyncHandler(async (req: AuthRequest, res: Response) => {
  try {
    const dislikedId = Number(req.params.dislikedId);
    if (!dislikedId || isNaN(dislikedId)) {
      return fail(res, CODE.BAD_REQUEST, '无效的用户 ID');
    }
    await dislikeService.undislikeUser(req.userId!, dislikedId);
    return ok(res, { undisliked: true });
  } catch (e) {
    return internalError(res, 'dislike.delete', e);
  }
}));

export default router;
