import { Router, Response } from 'express';
import { ok, fail, CODE } from '../utils/response';
import { prisma } from '../prisma';
import { auth, AuthRequest } from '../middleware/auth';
import { asyncHandler } from '../middleware/asyncHandler';
import { env } from '../config/env';

// 帖子行为埋点（最小曝光/点击信号）：POST /v1/metrics/post-event
// - action 白名单：expose（信息流曝光）/ click（信息流点击进入详情）
// - 匿名（游客）上报时 userId 为 null；登录用户由 auth 中间件填充
// - 服务端不校验帖子是否存在（埋点不允许引入读放大），仅校验参数形态
const ACTIONS = ['expose', 'click'];

const router = Router();

router.post('/post-event', asyncHandler(async (req: any, res: Response) => {
  const postId = Number(req.body?.postId);
  const action = typeof req.body?.action === 'string' ? req.body.action : '';
  if (!Number.isInteger(postId) || postId <= 0) {
    return fail(res, CODE.BAD_REQUEST, 'postId 无效');
  }
  if (ACTIONS.indexOf(action) < 0) {
    return fail(res, CODE.BAD_REQUEST, 'action 无效');
  }
  const userId: number | null = (req as any).userId != null ? Number((req as any).userId) : null;
  console.log('[metrics] post-event postId=' + postId + ' action=' + action + ' userId=' + userId);
  await prisma.postEvent.create({
    data: { postId, userId, action },
  });
  return ok(res, null, 'ok');
}));

// 诊断：GET /v1/metrics/ping
router.get('/ping', (_req: any, res: Response) => {
  return ok(res, { t: Date.now() }, 'pong');
});

// 帖子创作数据（作者本人 / 管理员）：GET /v1/metrics/posts/:id/stats
// 除基础互动计数外，聚合 PostEvent 的曝光/点击信号（游客埋点计入总数）
router.get('/posts/:id/stats', auth, asyncHandler(async (req: AuthRequest, res: Response) => {
  const postId = Number(req.params.id);
  if (!Number.isInteger(postId) || postId <= 0) {
    return fail(res, CODE.BAD_REQUEST, 'postId 无效');
  }
  const post = await prisma.post.findUnique({
    where: { id: postId },
    select: { userId: true, viewCount: true, upCount: true, bookmarkCount: true, commentCount: true },
  });
  if (!post) {
    return fail(res, CODE.NOT_FOUND, '帖子不存在', 404);
  }
  const isAdmin = env.adminUserIds.includes(req.userId!);
  if (post.userId !== req.userId && !isAdmin) {
    return fail(res, CODE.FORBIDDEN, '仅作者本人可查看数据', 403);
  }
  const grouped = await prisma.postEvent.groupBy({
    by: ['action'],
    where: { postId },
    _count: { _all: true },
  });
  let expose = 0;
  let click = 0;
  for (const g of grouped) {
    if (g.action === 'expose') expose = g._count._all;
    else if (g.action === 'click') click = g._count._all;
  }
  return ok(res, {
    viewCount: post.viewCount,
    upCount: post.upCount,
    bookmarkCount: post.bookmarkCount,
    commentCount: post.commentCount,
    expose,
    click,
    // 曝光→点击转化率（无曝光时为 0）
    clickRate: expose > 0 ? Number(((click / expose) * 100).toFixed(1)) : 0,
  });
}));

export default router;