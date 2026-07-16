import { Router, Response } from 'express';
import { ok, fail, CODE } from '../utils/response';
import { auth, AuthRequest } from '../middleware/auth';
import * as commentService from '../services/commentService';

// 该路由挂在 /v1 下，因此路径为完整路径
const router = Router();

// 评论列表：GET /v1/posts/:id/comments?page=1&limit=50
router.get('/posts/:id/comments', async (req: AuthRequest, res: Response) => {
  const postId = Number(req.params.id);
  const page = req.query.page ? Number(req.query.page) : 1;
  const data = await commentService.listComments(postId, page);
  return ok(res, data);
});

// 发布评论：POST /v1/posts/:id/comments
router.post('/posts/:id/comments', auth, async (req: AuthRequest, res: Response) => {
  const postId = Number(req.params.id);
  const { content, parentId, isFact } = req.body ?? {};
  if (!content) return fail(res, CODE.BAD_REQUEST, '评论内容必填');
  const comment = await commentService.createComment(
    postId,
    req.userId!,
    content,
    parentId,
    isFact ? 1 : 0
  );
  return ok(res, comment);
});

// 删除评论（仅本人）：DELETE /v1/comments/:id
router.delete('/comments/:id', auth, async (req: AuthRequest, res: Response) => {
  const id = Number(req.params.id);
  const result = await commentService.deleteComment(id, req.userId!);
  if (!result.ok) {
    if (result.reason === 'not_found') return fail(res, CODE.NOT_FOUND, '评论不存在', 404);
    if (result.reason === 'forbidden') return fail(res, CODE.FORBIDDEN, '只能删除自己的评论', 403);
  }
  return ok(res, null, '已删除');
});

export default router;
