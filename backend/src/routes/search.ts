import { Router, Response } from 'express';
import { ok, fail, CODE } from '../utils/response';
import { auth, AuthRequest } from '../middleware/auth';
import * as searchService from '../services/searchService';

// 搜索历史 / 热搜词路由，挂在 /v1/search 下
const router = Router();

// 记录搜索历史：POST /v1/search/history  body { keyword }
router.post('/history', auth, async (req: AuthRequest, res: Response) => {
  const keyword: string = (req.body?.keyword ?? '').toString();
  if (!keyword.trim()) {
    return fail(res, CODE.BAD_REQUEST, '关键词不能为空');
  }
  await searchService.recordSearchHistory(req.userId!, keyword);
  return ok(res, null, '已记录');
});

// 搜索历史列表：GET /v1/search/history?limit=10
router.get('/history', auth, async (req: AuthRequest, res: Response) => {
  const limit = req.query.limit ? Number(req.query.limit) : 10;
  const list = await searchService.listSearchHistory(req.userId!, limit);
  return ok(res, { list });
});

// 清除搜索历史：DELETE /v1/search/history
router.delete('/history', auth, async (req: AuthRequest, res: Response) => {
  await searchService.clearSearchHistory(req.userId!);
  return ok(res, null, '已清除');
});

// 热搜词列表：GET /v1/search/hot?limit=10
router.get('/hot', auth, async (req: AuthRequest, res: Response) => {
  const limit = req.query.limit ? Number(req.query.limit) : 10;
  const list = await searchService.listHotKeywords(limit);
  return ok(res, { list });
});

export default router;
