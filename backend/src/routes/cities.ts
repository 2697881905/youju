// 城市路由（星图子模式「降落地球」）：GET /v1/cities 城市列表 + 圈子/帖子计数。
// 公开接口（选城无需登录——游客也能看城市与圈子，进圈/发帖才要身份）。
import { Router, Response } from 'express';
import { ok } from '../utils/response';
import * as tagService from '../services/tagService';
import { asyncHandler } from '../middleware/asyncHandler';

const router = Router();

router.get('/', asyncHandler(async (_req, res: Response) => {
  const cities = await tagService.listCities();
  return ok(res, cities);
}));

export default router;
