import { Router, Response } from 'express';
import { ok, fail, CODE } from '../utils/response';
import { auth, AuthRequest } from '../middleware/auth';
import * as notificationService from '../services/notificationService';
import { parsePage, parseLimit } from '../utils/pagination';

// 该路由挂在 /v1 下，路径为完整路径
import { asyncHandler } from '../middleware/asyncHandler';

const router = Router();

// 通知列表：GET /v1/notifications?page=1&limit=20&type=system
// type 可选（前端「系统通知」收纳页只取 system 消息）：白名单由服务端校验，非法值忽略（不过滤）
router.get('/notifications', auth, asyncHandler(async (req: AuthRequest, res: Response) => {
  const page = parsePage(req.query.page);
  const limit = parseLimit(req.query.limit, 20);
  const type = typeof req.query.type === 'string' ? req.query.type : undefined;
  const data = await notificationService.listForUser(req.userId!, { page, limit, type });
  return ok(res, data);
}));

// 未读总数 + 按类型分布：GET /v1/notifications/unread-count
// byType 供消息页三类快捷筛选（赞和收藏/新增关注/评论）红点使用（此前客户端从已加载
// 列表里数未读，未读不在第一页时恒为 0）；新增字段向后兼容，旧客户端只读 count。
router.get('/notifications/unread-count', auth, asyncHandler(async (req: AuthRequest, res: Response) => {
  const [count, byType] = await Promise.all([
    notificationService.unreadCount(req.userId!),
    notificationService.unreadCountByType(req.userId!),
  ]);
  return ok(res, { count, byType });
}));

// 标记单条已读：POST /v1/notifications/:id/read
router.post('/notifications/:id/read', auth, asyncHandler(async (req: AuthRequest, res: Response) => {
  try {
    await notificationService.markRead(Number(req.params.id), req.userId!);
    return ok(res, null, '已读');
  } catch (e) {
    const err = e as any;
    if (err?.reason === 'forbidden') {
      return fail(res, CODE.FORBIDDEN, '只能操作自己的通知', 403);
    }
    return fail(res, CODE.SERVER_ERROR, '操作失败', 500);
  }
}));

// 全部已读：POST /v1/notifications/read-all
router.post('/notifications/read-all', auth, asyncHandler(async (req: AuthRequest, res: Response) => {
  const count = await notificationService.markAllRead(req.userId!);
  return ok(res, { count }, '全部已读');
}));

export default router;
