import { Router, Response } from 'express';
import { ok, fail, CODE } from '../utils/response';
import { auth, AuthRequest } from '../middleware/auth';
import * as searchService from '../services/searchService';

// 搜索历史 / 热搜词路由，挂在 /v1/search 下
import { asyncHandler } from '../middleware/asyncHandler';

const router = Router();

// 记录搜索历史：POST /v1/search/history  body { keyword }
router.post('/history', auth, asyncHandler(async (req: AuthRequest, res: Response) => {
  const keyword: string = (req.body?.keyword ?? '').toString();
  if (!keyword.trim()) {
    return fail(res, CODE.BAD_REQUEST, '关键词不能为空');
  }
  await searchService.recordSearchHistory(req.userId!, keyword);
  return ok(res, null, '已记录');
}));

// 搜索历史列表：GET /v1/search/history?limit=10
router.get('/history', auth, asyncHandler(async (req: AuthRequest, res: Response) => {
  const limit = req.query.limit ? Number(req.query.limit) : 10;
  const list = await searchService.listSearchHistory(req.userId!, limit);
  return ok(res, { list });
}));

// 清除搜索历史：DELETE /v1/search/history
router.delete('/history', auth, asyncHandler(async (req: AuthRequest, res: Response) => {
  await searchService.clearSearchHistory(req.userId!);
  return ok(res, null, '已清除');
}));

// 热搜词列表：GET /v1/search/hot?limit=10
router.get('/hot', auth, asyncHandler(async (req: AuthRequest, res: Response) => {
  const limit = req.query.limit ? Number(req.query.limit) : 10;
  const list = await searchService.listHotKeywords(limit);
  return ok(res, { list });
}));

// 搜索联想：GET /v1/search/suggest?keyword=xx&limit=8
// 公开接口（联想 = 历史关键词聚合 + 公开圈子标签，无个人隐私，游客也可用）
router.get('/suggest', asyncHandler(async (req: AuthRequest, res: Response) => {
  const keyword = String(req.query.keyword ?? '').trim();
  if (keyword.length === 0) {
    return ok(res, { list: [] });
  }
  const limit = req.query.limit ? Number(req.query.limit) : 8;
  const list = await searchService.suggestKeywords(keyword, limit);
  return ok(res, { list });
}));

// @提及 用户检索：GET /v1/search/users?keyword=&scope=following|all&limit=
// 供发帖编辑器 @ 面板使用：keyword 为空时（默认 scope=following）返回我关注的人，
// 输入昵称后（scope=all）全站检索，帮助用户在重名昵称中精确定位想提及的用户。
router.get('/users', auth, asyncHandler(async (req: AuthRequest, res: Response) => {
  const keyword = String(req.query.keyword ?? '').trim().slice(0, 32);
  const scope: 'following' | 'all' =
    String(req.query.scope ?? 'following') === 'all' ? 'all' : 'following';
  const limit = req.query.limit ? Number(req.query.limit) : 20;
  const list = await searchService.searchMentionUsers(req.userId!, keyword, scope, limit);
  return ok(res, { list });
}));

export default router;
