import { Router, Response } from 'express';
import { ok, fail, internalError, CODE } from '../utils/response';
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
  return internalError(res, 'users.follow', e);
}

// ===== 举报用户（聊天/私信骚扰等场景的举报渠道，审核要求） =====
// POST /v1/users/:id/report
import * as reportService from '../services/reportService';

const USER_REPORT_REASONS = [
  'political',
  'pornographic',
  'personal_attack',
  'gender_war',
  'advertisement',
  'spam',
  'other',
];

router.post('/:id/report', auth, asyncHandler(async (req: AuthRequest, res: Response) => {
  const userId = Number(req.params.id);
  if (!userId) return fail(res, CODE.BAD_REQUEST, '无效用户ID');
  const { reason, description } = req.body ?? {};

  if (!reason || !USER_REPORT_REASONS.includes(reason)) {
    return fail(res, CODE.BAD_REQUEST, '请选择举报理由');
  }
  if (reason === 'other' && (!description || !description.trim())) {
    return fail(res, CODE.BAD_REQUEST, '请填写补充说明');
  }

  try {
    await reportService.createReport({
      reporterId: req.userId!,
      targetType: 'user',
      targetId: userId,
      reason: reason as reportService.ReportReason,
      description: description?.trim() || undefined,
    });
    return ok(res, null, '举报已提交');
  } catch (e: any) {
    if (e.reason === 'conflict')
      return fail(res, CODE.CONFLICT, '你已举报过该用户', 409);
    if (e.reason === 'not_found')
      return fail(res, CODE.NOT_FOUND, '用户不存在', 404);
    return fail(res, CODE.SERVER_ERROR, '举报失败', 500);
  }
}));

export default router;
