import { Router, Response } from 'express';
import { ok } from '../utils/response';
import { auth, AuthRequest } from '../middleware/auth';
import * as interactService from '../services/interactService';

// 该路由挂在 /v1 下，路径为完整路径
import { asyncHandler } from '../middleware/asyncHandler';

const router = Router();

// 顶帖子：POST /v1/posts/:id/up
router.post('/posts/:id/up', auth, asyncHandler(async (req: AuthRequest, res: Response) => {
  await interactService.upPost(Number(req.params.id), req.userId!);
  return ok(res, null, '已顶');
}));

// 取消顶：DELETE /v1/posts/:id/up
router.delete('/posts/:id/up', auth, asyncHandler(async (req: AuthRequest, res: Response) => {
  await interactService.cancelUp(Number(req.params.id), req.userId!);
  return ok(res, null, '已取消顶');
}));

// 收藏（抄作业）：POST /v1/posts/:id/bookmark
router.post('/posts/:id/bookmark', auth, asyncHandler(async (req: AuthRequest, res: Response) => {
  await interactService.bookmarkPost(Number(req.params.id), req.userId!);
  return ok(res, null, '已收藏');
}));

// 取消收藏：DELETE /v1/posts/:id/bookmark
router.delete('/posts/:id/bookmark', auth, asyncHandler(async (req: AuthRequest, res: Response) => {
  await interactService.cancelBookmark(Number(req.params.id), req.userId!);
  return ok(res, null, '已取消收藏');
}));

export default router;
