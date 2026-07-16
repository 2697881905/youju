import { Router, Response } from 'express';
import { ok } from '../utils/response';
import * as tagService from '../services/tagService';

// 标签列表：GET /v1/tags
const router = Router();

router.get('/', async (_req, res: Response) => {
  const tags = await tagService.listTags();
  return ok(res, tags);
});

export default router;
