// admin 审核 API 路由（统一 auth + adminAuth 前置中间件）
// GET  /v1/admin/posts/pending      待审核帖子列表
// POST /v1/admin/posts/:id/moderate 审核帖子（approve/reject）
// GET  /v1/admin/reports            举报记录列表
import { Router, Response } from 'express';
import { ok, fail, CODE } from '../utils/response';
import { auth, AuthRequest } from '../middleware/auth';
import { adminAuth } from '../middleware/adminAuth';
import { prisma } from '../prisma';
import { env } from '../config/env';
import * as moderationService from '../services/moderationService';
import * as reportService from '../services/reportService';

import { asyncHandler } from '../middleware/asyncHandler';

const router = Router();

// 所有 admin 路由统一使用 auth + adminAuth
router.use(auth, adminAuth);

// GET /v1/admin/posts/pending?page=&limit= — 待审核帖子列表
router.get('/posts/pending', asyncHandler(async (req: AuthRequest, res: Response) => {
  const page = req.query.page ? Number(req.query.page) : 1;
  const limit = req.query.limit ? Number(req.query.limit) : 20;
  const data = await moderationService.listPendingPosts(page, limit);
  return ok(res, data);
}));

// POST /v1/admin/posts/:id/moderate — 审核帖子
router.post('/posts/:id/moderate', asyncHandler(async (req: AuthRequest, res: Response) => {
  const postId = Number(req.params.id);
  if (!postId) return fail(res, CODE.BAD_REQUEST, '无效帖子ID');
  const { action, reason } = req.body ?? {};
  if (!action || !['approve', 'reject'].includes(action)) {
    return fail(res, CODE.BAD_REQUEST, 'action 必须为 approve 或 reject');
  }
  try {
    await moderationService.moderatePost(postId, action as 'approve' | 'reject', reason);
    return ok(res, null, '审核完成');
  } catch (e: any) {
    if (e.reason === 'not_found') return fail(res, CODE.NOT_FOUND, '帖子不存在', 404);
    if (e.reason === 'invalid_status')
      return fail(res, CODE.BAD_REQUEST, '该帖子不在待审核状态');
    return fail(res, CODE.SERVER_ERROR, '审核失败', 500);
  }
}));

// GET /v1/admin/reports?page=&limit=&status= — 举报记录列表
router.get('/reports', asyncHandler(async (req: AuthRequest, res: Response) => {
  const page = req.query.page ? Number(req.query.page) : 1;
  const limit = req.query.limit ? Number(req.query.limit) : 20;
  const status = req.query.status ? String(req.query.status) : undefined;
  const data = await reportService.listReports(page, limit, status);
  return ok(res, data);
}));

// POST /v1/admin/users/:id/ban — 封禁用户（status=0）
router.post('/users/:id/ban', asyncHandler(async (req: AuthRequest, res: Response) => {
  const id = Number(req.params.id);
  if (!id || isNaN(id)) return fail(res, CODE.BAD_REQUEST, '无效用户ID');
  if (env.adminUserIds.includes(id)) {
    return fail(res, CODE.FORBIDDEN, '不能封禁管理员', 403);
  }
  const target = await prisma.user.findUnique({ where: { id } });
  if (!target) return fail(res, CODE.NOT_FOUND, '用户不存在', 404);
  await prisma.user.update({ where: { id }, data: { status: 0 } });
  return ok(res, null, '已封禁');
}));

// POST /v1/admin/users/:id/unban — 解封用户（status=1）
router.post('/users/:id/unban', asyncHandler(async (req: AuthRequest, res: Response) => {
  const id = Number(req.params.id);
  if (!id || isNaN(id)) return fail(res, CODE.BAD_REQUEST, '无效用户ID');
  const target = await prisma.user.findUnique({ where: { id } });
  if (!target) return fail(res, CODE.NOT_FOUND, '用户不存在', 404);
  await prisma.user.update({ where: { id }, data: { status: 1 } });
  return ok(res, null, '已解封');
}));

export default router;
