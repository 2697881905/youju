import { Router, Response } from 'express';
import { ok, fail, CODE } from '../utils/response';
import { auth, AuthRequest } from '../middleware/auth';
import * as postService from '../services/postService';

const router = Router();

// 帖子列表：GET /v1/posts?page=1&limit=20&sort=hot|latest|recommend&tag=数码选购&author=1
router.get('/', async (req: AuthRequest, res: Response) => {
  const { page, limit, sort, tag, author, keyword } = req.query;
  const data = await postService.listPosts({
    page: page ? Number(page) : 1,
    limit: limit ? Number(limit) : 20,
    sort: (sort as postService.SortType) ?? 'latest',
    tag: tag as string | undefined,
    author: author ? Number(author) : undefined,
    keyword: keyword as string | undefined,
  });
  return ok(res, data);
});

// 帖子详情：GET /v1/posts/:id
router.get('/:id', async (req: AuthRequest, res: Response) => {
  const id = Number(req.params.id);
  if (!id) return fail(res, CODE.BAD_REQUEST, '无效帖子ID');
  const post = await postService.getPost(id);
  if (!post) return fail(res, CODE.NOT_FOUND, '帖子不存在', 404);
  return ok(res, post);
});

// 发布帖子（进入待审核）：POST /v1/posts
router.post('/', auth, async (req: AuthRequest, res: Response) => {
  const { title, genre } = req.body ?? {};
  if (!title || !genre) return fail(res, CODE.BAD_REQUEST, '标题和体裁必填');
  const post = await postService.createPost(req.body, req.userId!);
  return ok(res, post);
});

// 删除帖子（仅本人）：DELETE /v1/posts/:id
router.delete('/:id', auth, async (req: AuthRequest, res: Response) => {
  const id = Number(req.params.id);
  const result = await postService.deletePost(id, req.userId!);
  if (!result.ok) {
    if (result.reason === 'not_found') return fail(res, CODE.NOT_FOUND, '帖子不存在', 404);
    if (result.reason === 'forbidden') return fail(res, CODE.FORBIDDEN, '只能删除自己的帖子', 403);
  }
  return ok(res, null, '已删除');
});

export default router;
