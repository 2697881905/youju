import { Router, Response } from 'express';
import { ok, fail, CODE } from '../utils/response';
import { auth, AuthRequest } from '../middleware/auth';
import { tagCreateLimiter } from '../middleware/rateLimit';
import * as tagService from '../services/tagService';

// 标签路由：GET / 列表 | POST / 创建圈子 | POST /:name/follow 关注 | DELETE /:name/follow 取消关注
import { asyncHandler } from '../middleware/asyncHandler';

const router = Router();

// 标签列表：GET /v1/tags ；all=1 时返回深空目录全量（可按 keyword 过滤）；
// cityCode=xx 时返回该城市的同城圈（星图子模式「降落地球」城市页主体）。
router.get('/', asyncHandler(async (req, res: Response) => {
  const cityCode = req.query.cityCode as string | undefined;
  if (cityCode) {
    const tags = await tagService.listCityTags(cityCode);
    return ok(res, tags);
  }
  if (String(req.query.all ?? '') === '1') {
    const tags = await tagService.searchTags(req.query.keyword as string | undefined);
    return ok(res, tags);
  }
  const tags = await tagService.listTags();
  return ok(res, tags);
}));

// 创建圈子（点亮新星）：POST /v1/tags { name, category, description }
router.post('/', auth, tagCreateLimiter, asyncHandler(async (req: AuthRequest, res: Response) => {
  const { name, category, description, cityCode } = req.body ?? {};
  if (typeof name !== 'string' || typeof category !== 'string' || typeof description !== 'string') {
    return fail(res, CODE.BAD_REQUEST, '缺少 name/category/description');
  }
  const tag = await tagService.createTag(req.userId!, name, category, description, cityCode);
  return ok(res, tag);
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

// ===== 星图 Live：引力档位 / 活跃度 / 已读 =====

// 引力档位列表：GET /v1/tags/weights（需登录）
router.get('/weights', auth, asyncHandler(async (req: AuthRequest, res: Response) => {
  return ok(res, await tagService.listTagWeights(req.userId!));
}));

// 设置引力档位：PUT /v1/tags/:name/weight { weight: 1|2|3 }
router.put('/:name/weight', auth, asyncHandler(async (req: AuthRequest, res: Response) => {
  const name = req.params.name;
  if (!name || name.length > 20) {
    return fail(res, CODE.BAD_REQUEST, '标签名无效');
  }
  const weight = Number(req.body?.weight);
  if (![1, 2, 3].includes(weight)) {
    return fail(res, CODE.BAD_REQUEST, 'weight 需为 1|2|3');
  }
  const updated = await tagService.setTagWeight(req.userId!, name, weight);
  if (!updated) {
    return fail(res, CODE.FORBIDDEN, '仅可调节已加入的圈子', 403);
  }
  return ok(res, { tagName: name, weight });
}));

// 圈子活跃度 + 未读：GET /v1/tags/activity（需登录）
router.get('/activity', auth, asyncHandler(async (req: AuthRequest, res: Response) => {
  return ok(res, await tagService.listTagActivity(req.userId!));
}));

// 标记已读：POST /v1/tags/:name/read（进入圈子时调用，未读角标归零）
router.post('/:name/read', auth, asyncHandler(async (req: AuthRequest, res: Response) => {
  const name = req.params.name;
  if (!name || name.length > 20) {
    return fail(res, CODE.BAD_REQUEST, '标签名无效');
  }
  await tagService.markTagRead(req.userId!, name);
  return ok(res, { tagName: name });
}));

export default router;
