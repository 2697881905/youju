// 拉黑管理路由：列表 / 拉黑 / 取消拉黑
import { Router, Response } from 'express';
import { ok, fail, CODE } from '../utils/response';
import { auth, AuthRequest } from '../middleware/auth';
import * as blockService from '../services/blockService';

const router = Router();

// GET /v1/me/blocklist?page=1&limit=20  拉黑列表（分页）
router.get('/me/blocklist', auth, async (req: AuthRequest, res: Response) => {
  try {
    const page = req.query.page ? Number(req.query.page) : 1;
    const limit = req.query.limit ? Number(req.query.limit) : 20;
    const data = await blockService.listBlocked(req.userId!, page, limit);
    return ok(res, data);
  } catch (e) {
    return fail(res, CODE.SERVER_ERROR, (e as Error).message);
  }
});

// POST /v1/me/block/:blockedId  拉黑某人
router.post('/me/block/:blockedId', auth, async (req: AuthRequest, res: Response) => {
  try {
    const blockedId = Number(req.params.blockedId);
    if (!blockedId || isNaN(blockedId)) {
      return fail(res, CODE.BAD_REQUEST, '无效的用户 ID');
    }
    await blockService.blockUser(req.userId!, blockedId);
    return ok(res, { blocked: true });
  } catch (e) {
    if (e instanceof blockService.BlockError) {
      return fail(res, CODE.BAD_REQUEST, e.message);
    }
    return fail(res, CODE.SERVER_ERROR, (e as Error).message);
  }
});

// DELETE /v1/me/block/:blockedId  取消拉黑
router.delete('/me/block/:blockedId', auth, async (req: AuthRequest, res: Response) => {
  try {
    const blockedId = Number(req.params.blockedId);
    if (!blockedId || isNaN(blockedId)) {
      return fail(res, CODE.BAD_REQUEST, '无效的用户 ID');
    }
    await blockService.unblockUser(req.userId!, blockedId);
    return ok(res, { unblocked: true });
  } catch (e) {
    return fail(res, CODE.SERVER_ERROR, (e as Error).message);
  }
});

export default router;
