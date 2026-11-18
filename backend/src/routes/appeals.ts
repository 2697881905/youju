// 内容处置申诉（用户端）：提交申诉 / 查自己的申诉。
// 管理端复核入口在 admin.ts（auth + adminAuth）。
import { Router, Response } from 'express';
import { ok, fail, CODE } from '../utils/response';
import { auth, AuthRequest } from '../middleware/auth';
import { asyncHandler } from '../middleware/asyncHandler';
import * as appealService from '../services/appealService';
import type { TargetType } from '../services/reportService';

const router = Router();

// 所有申诉操作需登录
router.use(auth);

// POST /v1/appeals — 提交申诉（body: { targetType: 'post'|'comment', targetId, reason }）
router.post('/', asyncHandler(async (req: AuthRequest, res: Response) => {
  const targetType = req.body?.targetType as TargetType;
  const targetId = Number(req.body?.targetId);
  if (!Number.isInteger(targetId) || targetId <= 0) {
    return fail(res, CODE.BAD_REQUEST, '目标 ID 无效');
  }
  await appealService.createAppeal({
    authorId: req.userId!,
    targetType,
    targetId,
    reason: typeof req.body?.reason === 'string' ? req.body.reason : '',
  });
  return ok(res, null, '申诉已提交');
}));

// GET /v1/appeals/mine — 我的申诉列表
router.get('/mine', asyncHandler(async (req: AuthRequest, res: Response) => {
  const list = await appealService.listMyAppeals(req.userId!);
  return ok(res, { list });
}));

export default router;
