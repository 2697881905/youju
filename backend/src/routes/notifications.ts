import { Router, Response } from 'express';
import { ok, fail, CODE } from '../utils/response';
import { auth, AuthRequest } from '../middleware/auth';
import * as notificationService from '../services/notificationService';

// 该路由挂在 /v1 下，路径为完整路径
const router = Router();

// 通知列表：GET /v1/notifications?page=1&limit=20
router.get('/notifications', auth, async (req: AuthRequest, res: Response) => {
  const page = req.query.page ? Number(req.query.page) : 1;
  const limit = req.query.limit ? Number(req.query.limit) : 20;
  const data = await notificationService.listForUser(req.userId!, { page, limit });
  return ok(res, data);
});

// 未读总数：GET /v1/notifications/unread-count
router.get('/notifications/unread-count', auth, async (req: AuthRequest, res: Response) => {
  const count = await notificationService.unreadCount(req.userId!);
  return ok(res, { count });
});

// 标记单条已读：POST /v1/notifications/:id/read
router.post('/notifications/:id/read', auth, async (req: AuthRequest, res: Response) => {
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
});

// 全部已读：POST /v1/notifications/read-all
router.post('/notifications/read-all', auth, async (req: AuthRequest, res: Response) => {
  const count = await notificationService.markAllRead(req.userId!);
  return ok(res, { count }, '全部已读');
});

export default router;
