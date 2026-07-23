import { Router, Response } from 'express';
import { ok, fail, CODE } from '../utils/response';
import { auth, AuthRequest } from '../middleware/auth';
import * as followService from '../services/followService';

// 用户资料 / 关注关系路由（挂在 /v1/users 下，与 authRouter 同前缀、在其后注册）
// 端点：POST/DELETE /:id/follow、GET /:id、GET /:id/following、GET /:id/followers
// 注意：GET /me 由 authRouter 的 /me 命中（前缀匹配优先），不会落到本路由的 :id。
import { asyncHandler } from '../middleware/asyncHandler';

const router = Router();

// 关注：POST /v1/users/:id/follow
router.post('/:id/follow', auth, asyncHandler(async (req: AuthRequest, res: Response) => {
  try {
    await followService.followUser(req.userId!, req.params.id);
    return ok(res, null);
  } catch (e) {
    return handleError(res, e);
  }
}));

// 取消关注：DELETE /v1/users/:id/follow（幂等）
router.delete('/:id/follow', auth, asyncHandler(async (req: AuthRequest, res: Response) => {
  try {
    await followService.unfollowUser(req.userId!, req.params.id);
    return ok(res, null);
  } catch (e) {
    return handleError(res, e);
  }
}));

// 他人/自己资料：GET /v1/users/:id
router.get('/:id', auth, asyncHandler(async (req: AuthRequest, res: Response) => {
  try {
    const data = await followService.getUserProfile(req.userId!, req.params.id);
    return ok(res, data);
  } catch (e) {
    return handleError(res, e);
  }
}));

// 关注列表：GET /v1/users/:id/following
router.get('/:id/following', auth, asyncHandler(async (req: AuthRequest, res: Response) => {
  try {
    const page = req.query.page ? Number(req.query.page) : 1;
    const limit = req.query.limit ? Number(req.query.limit) : 20;
    const data = await followService.listFollowing(req.userId!, req.params.id, { page, limit });
    return ok(res, data);
  } catch (e) {
    return handleError(res, e);
  }
}));

// 粉丝列表：GET /v1/users/:id/followers
router.get('/:id/followers', auth, asyncHandler(async (req: AuthRequest, res: Response) => {
  try {
    const page = req.query.page ? Number(req.query.page) : 1;
    const limit = req.query.limit ? Number(req.query.limit) : 20;
    const data = await followService.listFollowers(req.userId!, req.params.id, { page, limit });
    return ok(res, data);
  } catch (e) {
    return handleError(res, e);
  }
}));

// 统一错误转换：已知 FollowError 用其携带的 code/httpStatus；其余归为 500
function handleError(res: Response, e: unknown): Response {
  if (e instanceof followService.FollowError) {
    return fail(res, e.code, e.message, e.httpStatus);
  }
  const err = e as Error;
  return fail(res, CODE.SERVER_ERROR, err.message || '服务异常', 500);
}

export default router;
