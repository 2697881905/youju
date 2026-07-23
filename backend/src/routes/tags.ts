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
  if (!name) {
    return fail(res, CODE.BAD_REQUEST, '缺少标签名');
  }
  await tagService.followTag(req.userId!, name);
  return ok(res, null);
}));

// 取消关注标签：DELETE /v1/tags/:name/follow
router.delete('/:name/follow', auth, asyncHandler(async (req: AuthRequest, res: Response) => {
  const name = req.params.name;
  if (!name) {
    return fail(res, CODE.BAD_REQUEST, '缺少标签名');
  }
  await tagService.unfollowTag(req.userId!, name);
  return ok(res, null);
}));

export default router;
