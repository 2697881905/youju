import { Router, Response } from 'express';
import { ok, fail, CODE } from '../utils/response';
import { prisma } from '../prisma';
import { auth, AuthRequest, resolveOptionalUserId } from '../middleware/auth';
import { asyncHandler } from '../middleware/asyncHandler';
import { metricsLimiter } from '../middleware/rateLimit';
import { env } from '../config/env';

// 帖子行为埋点：POST /v1/metrics/post-event
// - action 白名单：expose（曝光）/ click（点击进详情）/ up / comment / bookmark / daily_open（进入每日一贴）
// - 帖子级动作（expose/click/up/comment/bookmark）必须带有效 postId，并校验帖子存在，
//   防止伪造 postId 刷量、污染热度分与个性化画像。
// - 页面级动作（daily_open）无帖子，postId 允许为空。
// - 鉴权：软鉴权（resolveOptionalUserId）。带有效 token 回填真实 userId；无/失效 token 按匿名（null）处理，
//   不因未登录而 401 —— 埋点不能阻断客户端。
// - scene：来源场景（daily | feed | hot | search | profile），用于区分「每日一贴」与其它信息流的曝光/点击。
const ACTIONS = ['expose', 'click', 'up', 'comment', 'bookmark', 'daily_open'];
const POST_LEVEL_ACTIONS = ['expose', 'click', 'up', 'comment', 'bookmark'];
const SCENES = ['daily', 'feed', 'hot', 'search', 'circle', 'profile'];

const router = Router();

router.post('/post-event', metricsLimiter, asyncHandler(async (req: any, res: Response) => {
  const action = typeof req.body?.action === 'string' ? req.body.action : '';
  if (ACTIONS.indexOf(action) < 0) {
    return fail(res, CODE.BAD_REQUEST, 'action 无效');
  }
  const sceneRaw = typeof req.body?.scene === 'string' ? req.body.scene : '';
  const scene: string | null = SCENES.indexOf(sceneRaw) >= 0 ? sceneRaw : null;

  // 软鉴权：有效 token → 真实 userId；否则匿名。游客数据不进个人画像，仅计入全局热度。
  const resolvedUserId = await resolveOptionalUserId(req as AuthRequest);
  const userId: number | null = resolvedUserId != null ? resolvedUserId : null;

  let postId: number | null = null;
  if (POST_LEVEL_ACTIONS.indexOf(action) >= 0) {
    postId = Number(req.body?.postId);
    if (!Number.isInteger(postId) || postId <= 0) {
      return fail(res, CODE.BAD_REQUEST, 'postId 无效');
    }
    // 存在性校验：伪造 postId 会让热度分与画像被脏数据污染，故拒绝不存在的帖子。
    const exists = await prisma.post.findUnique({ where: { id: postId }, select: { id: true } });
    if (!exists) {
      return fail(res, CODE.NOT_FOUND, '帖子不存在', 404);
    }
  }

  await prisma.postEvent.create({
    data: { postId, userId, action, scene },
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