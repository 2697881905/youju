// admin 处置 API 路由（统一 auth + adminAuth 前置中间件）
// GET  /v1/admin/reports             举报记录列表（处置台数据源，含内容状态与作者）
// POST /v1/admin/reports/resolve     处置某目标：resolved 成立并下架 / dismissed 驳回并恢复 / restore 改判恢复
// POST /v1/admin/users/:id/ban|unban 封禁 / 解封用户
// POST /v1/admin/recompute-hot       运维专用：全量重算热度分
import { Router, Response } from 'express';
import { ok, fail, CODE } from '../utils/response';
import { auth, AuthRequest } from '../middleware/auth';
import { adminAuth } from '../middleware/adminAuth';
import { prisma } from '../prisma';
import { env } from '../config/env';
import * as reportService from '../services/reportService';
import { recomputeAllHotScores } from '../services/hotScoreService';
import { parsePage, parseLimit } from '../utils/pagination';

import { asyncHandler } from '../middleware/asyncHandler';

const router = Router();

// 所有 admin 路由统一使用 auth + adminAuth
router.use(auth, adminAuth);

// GET /v1/admin/reports?page=&limit=&status= — 举报记录列表
router.get('/reports', asyncHandler(async (req: AuthRequest, res: Response) => {
  const page = parsePage(req.query.page);
  const limit = parseLimit(req.query.limit, 20);
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

// POST /v1/admin/reports/resolve — 处置台统一动作：对该目标的全部 pending 举报与内容状态一次性裁决
// body: { targetType: 'post'|'comment'|'user', targetId, action: 'resolved'|'dismissed'|'restore', reason? }
//   - resolved  成立并下架（通知作者未通过审核）
//   - dismissed 驳回举报（内容若因举报被下架则一并恢复）
//   - restore   改判/误封恢复（仅内容，需无 pending 举报）
// 通知（作者 / 举报人）已下沉到 service，与本路由不再重复发送。
router.post('/reports/resolve', asyncHandler(async (req: AuthRequest, res: Response) => {
  const { targetType, targetId, action, reason } = req.body ?? {};
  if (!['post', 'comment', 'user'].includes(targetType)) {
    return fail(res, CODE.BAD_REQUEST, 'targetType 必须为 post/comment/user');
  }
  const id = Number(targetId);
  if (!id || isNaN(id)) return fail(res, CODE.BAD_REQUEST, '无效目标ID');
  if (!['resolved', 'dismissed', 'restore'].includes(action)) {
    return fail(res, CODE.BAD_REQUEST, 'action 必须为 resolved、dismissed 或 restore');
  }
  const trimmedReason: string | undefined =
    typeof reason === 'string' && reason.trim().length > 0 ? reason.trim().slice(0, 200) : undefined;
  try {
    await reportService.resolveReportsByTarget(
      targetType,
      id,
      action as 'resolved' | 'dismissed' | 'restore',
      trimmedReason
    );
  } catch (e: any) {
    if (e?.reason === 'not_found') return fail(res, CODE.NOT_FOUND, '目标不存在', 404);
    if (e?.reason === 'has_pending') return fail(res, CODE.BAD_REQUEST, '该内容仍有待处理举报，请先处置举报');
    if (e?.reason === 'not_taken_down') return fail(res, CODE.BAD_REQUEST, '该内容当前未下架，无需恢复');
    if (e?.reason === 'invalid_target') return fail(res, CODE.BAD_REQUEST, '用户举报不支持该操作');
    return fail(res, CODE.SERVER_ERROR, '处理失败', 500);
  }
  return ok(res, null, '已处理');
}));

// POST /v1/admin/recompute-hot —— 运维/后台专用接口：全量重算热度分（调参、修数后手动触发）。
// 前端无 UI 入口，需带管理员 token 直接调用；由 adminAuth 保证权限。
router.post('/recompute-hot', asyncHandler(async (req: AuthRequest, res: Response) => {
  const count = await recomputeAllHotScores();
  return ok(res, { count }, '热榜已重算');
}));

export default router;
