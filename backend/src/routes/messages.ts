// 私信路由：会话列表 / 历史 / 发送 / 标记已读 / 未读总数
import { Router, Response } from 'express';
import { ok, fail, CODE } from '../utils/response';
import { auth, AuthRequest } from '../middleware/auth';
import * as messageService from '../services/messageService';

const router = Router();

// 解析路径中的 :userId（可为 'me' 或数字 id）
function resolvePeerId(raw: string, viewerId: number): number {
  if (raw === 'me') return viewerId;
  const n = Number(raw);
  if (!Number.isInteger(n) || n <= 0) {
    throw new Error('无效的用户 id');
  }
  return n;
}

// GET /v1/messages/conversations —— 会话列表（最近一条 + 未读）
router.get('/conversations', auth, async (req: AuthRequest, res: Response) => {
  try {
    const list = await messageService.listConversations(req.userId!);
    return ok(res, { list });
  } catch (e) {
    return fail(res, CODE.SERVER_ERROR, (e as Error).message);
  }
});

// GET /v1/messages/unread —— 私信未读总数
router.get('/unread', auth, async (req: AuthRequest, res: Response) => {
  try {
    const count = await messageService.getUnreadCount(req.userId!);
    return ok(res, { count });
  } catch (e) {
    return fail(res, CODE.SERVER_ERROR, (e as Error).message);
  }
});

// GET /v1/messages/:userId —— 与某用户的私信历史（旧→新）
router.get('/:userId', auth, async (req: AuthRequest, res: Response) => {
  try {
    const peerId = resolvePeerId(req.params.userId, req.userId!);
    const page = Math.max(1, Number(req.query.page ?? 1));
    const list = await messageService.getMessages(req.userId!, peerId, page, 30);
    return ok(res, { list });
  } catch (e) {
    return fail(res, CODE.SERVER_ERROR, (e as Error).message);
  }
});

// POST /v1/messages/:userId/read —— 标记与该用户私信已读
router.post('/:userId/read', auth, async (req: AuthRequest, res: Response) => {
  try {
    const peerId = resolvePeerId(req.params.userId, req.userId!);
    const updated = await messageService.markRead(req.userId!, peerId);
    return ok(res, { updated });
  } catch (e) {
    return fail(res, CODE.SERVER_ERROR, (e as Error).message);
  }
});

// POST /v1/messages —— 发送私信（含权限校验）
router.post('/', auth, async (req: AuthRequest, res: Response) => {
  try {
    const receiverId = Number(req.body?.receiverId);
    const content = typeof req.body?.content === 'string' ? req.body.content : '';
    if (!Number.isInteger(receiverId) || receiverId <= 0) {
      return fail(res, CODE.BAD_REQUEST, '缺少有效的接收者', 400);
    }
    const msg = await messageService.sendMessage(req.userId!, receiverId, content);
    return ok(res, msg);
  } catch (e) {
    if (e instanceof messageService.MessageError) {
      return fail(res, e.code, e.message, e.httpStatus);
    }
    return fail(res, CODE.SERVER_ERROR, (e as Error).message);
  }
});

export default router;
