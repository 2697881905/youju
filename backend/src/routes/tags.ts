import { Router, Response } from 'express';
import { ok, fail, CODE } from '../utils/response';
import { auth, AuthRequest } from '../middleware/auth';
import * as tagService from '../services/tagService';

// 标签路由：GET / 列表 | POST /:name/follow 关注 | DELETE /:name/follow 取消关注
import { asyncHandler } from '../middleware/asyncHandler';

const router = Router();

// 标签列表：GET /v1/tags
router.get('/', asyncHandler(async (_req, res: Response) => {
  const tags = await tagService.listTags();
  return ok(res, tags);
}));

// 关注标签：POST /v1/tags/:name/follow
router.post('/:name/follow', auth, asyncHandler(async (req: AuthRequest, res: Response) => {
  const name = req.params.name;
  // tagName 是 VarChar(20) 列硬约束：超长直接 500；且必须在 Tag 表存在——
  // 关注任意不存在的名字会制造孤儿关注行（无 FK），并可持续灌库
  if (!name || name.length > 20) {
    return fail(res, CODE.BAD_REQUEST, '标签名无效');
  }
  const tag = await tagService.followTag(req.userId!, name);
  if (!tag) {
    return fail(res, CODE.NOT_FOUND, '标签不存在', 404);
  }
  return ok(res, tag);
}));

// 取消关注标签：DELETE /v1/tags/:name/follow
router.delete('/:name/follow', auth, asyncHandler(async (req: AuthRequest, res: Response) => {
  const name = req.params.name;
  if (!name || name.length > 20) {
    return fail(res, CODE.BAD_REQUEST, '标签名无效');
  }
  const tag = await tagService.unfollowTag(req.userId!, name);
  // 幂等：取消关注不存在的标签（含未入库名字）视为成功，保证取消流程不被卡住
  return ok(res, tag);
}));

export default router;
