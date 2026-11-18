// 合集（连载）路由：创建/列表/详情/编辑/删除 + 加帖/移除
// 挂载在 /v1/collections 下（全部需登录）；作者列表走 ?authorId=，避免与 users/:id 冲突。
import { Router, Response } from 'express';
import { ok } from '../utils/response';
import { auth, AuthRequest } from '../middleware/auth';
import { asyncHandler } from '../middleware/asyncHandler';
import { ValidationError } from '../utils/errors';
import { parsePage, parseLimit } from '../utils/pagination';
import * as collectionService from '../services/collectionService';

const router = Router();

router.use(auth);

function parseId(raw: unknown, label: string): number {
  const id = Number(raw);
  if (!Number.isInteger(id) || id <= 0) {
    throw new ValidationError(label + ' ID 无效');
  }
  return id;
}

// POST /v1/collections { title, description } — 创建合集
router.post('/', asyncHandler(async (req: AuthRequest, res: Response) => {
  const data = await collectionService.createCollection(
    req.userId!, (req.body ?? {}).title, (req.body ?? {}).description,
  );
  return ok(res, data);
}));

// GET /v1/collections?authorId= — 合集列表（不传 authorId 则查自己的）
router.get('/', asyncHandler(async (req: AuthRequest, res: Response) => {
  const authorId = req.query.authorId ? parseId(req.query.authorId, '作者') : req.userId!;
  const list = await collectionService.listCollections(authorId);
  return ok(res, { list });
}));

// GET /v1/collections/:id?page=&limit= — 合集详情（含有序帖子）
router.get('/:id', asyncHandler(async (req: AuthRequest, res: Response) => {
  const id = parseId(req.params.id, '合集');
  const page = parsePage(req.query.page);
  const limit = parseLimit(req.query.limit, 20);
  const data = await collectionService.getCollection(id, page, limit);
  return ok(res, data);
}));

// PATCH /v1/collections/:id { title, description } — 编辑合集（仅作者）
router.patch('/:id', asyncHandler(async (req: AuthRequest, res: Response) => {
  const id = parseId(req.params.id, '合集');
  const data = await collectionService.updateCollection(
    req.userId!, id, (req.body ?? {}).title, (req.body ?? {}).description,
  );
  return ok(res, data);
}));

// DELETE /v1/collections/:id — 删除合集（含条目，仅作者）
router.delete('/:id', asyncHandler(async (req: AuthRequest, res: Response) => {
  const id = parseId(req.params.id, '合集');
  const data = await collectionService.deleteCollection(req.userId!, id);
  return ok(res, data);
}));

// POST /v1/collections/:id/posts { postId } — 加帖（仅作者，帖子须为本人已发布）
router.post('/:id/posts', asyncHandler(async (req: AuthRequest, res: Response) => {
  const id = parseId(req.params.id, '合集');
  const postId = parseId((req.body ?? {}).postId, '帖子');
  const data = await collectionService.addPost(req.userId!, id, postId);
  return ok(res, data);
}));

// DELETE /v1/collections/:id/posts/:postId — 移除帖子（仅作者，幂等）
router.delete('/:id/posts/:postId', asyncHandler(async (req: AuthRequest, res: Response) => {
  const id = parseId(req.params.id, '合集');
  const postId = parseId(req.params.postId, '帖子');
  const data = await collectionService.removePost(req.userId!, id, postId);
  return ok(res, data);
}));

export default router;
