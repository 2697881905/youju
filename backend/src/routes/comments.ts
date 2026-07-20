import { Router, Response } from 'express';
import { ok, fail, CODE } from '../utils/response';
import { auth, AuthRequest } from '../middleware/auth';
import { prisma } from '../prisma';
import * as commentService from '../services/commentService';
import * as reportService from '../services/reportService';
import { SensitiveWordError } from '../utils/errors';

// 该路由挂在 /v1 下，因此路径为完整路径
const router = Router();

// 举报理由枚举（与 reportService 对齐）
const VALID_REASONS = [
  'political',
  'pornographic',
  'personal_attack',
  'gender_war',
  'advertisement',
  'spam',
  'other',
];

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
  try {
    const comment = await commentService.createComment(
      postId,
      req.userId!,
      content,
      parentId,
      isFact ? 1 : 0
    );
    return ok(res, comment);
  } catch (e: any) {
    if (e instanceof SensitiveWordError || e.reason === 'sensitive_word') {
      return fail(res, CODE.BAD_REQUEST, e.message);
    }
    console.error('[comments.create] error:', e);
    return fail(res, CODE.SERVER_ERROR, '评论失败', 500);
  }
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

// 评论点赞（顶）：POST /v1/comments/:id/up（幂等）
router.post('/comments/:id/up', auth, async (req: AuthRequest, res: Response) => {
  const commentId = Number(req.params.id);
  if (!commentId) return fail(res, CODE.BAD_REQUEST, '无效评论ID');
  try {
    // 幂等：已点赞则忽略
    const existing = await prisma.commentUp.findUnique({
      where: { userId_commentId: { userId: req.userId!, commentId } },
    });
    if (existing) return ok(res, { up: true });
    // 写 CommentUp + increment upCount
    await prisma.commentUp.create({ data: { userId: req.userId!, commentId } });
    await prisma.comment.update({ where: { id: commentId }, data: { upCount: { increment: 1 } } });
    return ok(res, { up: true });
  } catch (e) {
    return fail(res, CODE.SERVER_ERROR, (e as Error).message);
  }
});

// 取消评论点赞：DELETE /v1/comments/:id/up（幂等）
router.delete('/comments/:id/up', auth, async (req: AuthRequest, res: Response) => {
  const commentId = Number(req.params.id);
  if (!commentId) return fail(res, CODE.BAD_REQUEST, '无效评论ID');
  try {
    const existing = await prisma.commentUp.findUnique({
      where: { userId_commentId: { userId: req.userId!, commentId } },
    });
    if (!existing) return ok(res, { up: false });
    await prisma.commentUp.delete({ where: { id: existing.id } });
    await prisma.comment.update({ where: { id: commentId }, data: { upCount: { increment: -1 } } });
    return ok(res, { up: false });
  } catch (e) {
    return fail(res, CODE.SERVER_ERROR, (e as Error).message);
  }
});

// 举报评论：POST /v1/comments/:id/report
router.post('/comments/:id/report', auth, async (req: AuthRequest, res: Response) => {
  const commentId = Number(req.params.id);
  if (!commentId) return fail(res, CODE.BAD_REQUEST, '无效评论ID');
  const { reason, description } = req.body ?? {};

  // 校验 reason 合法性
  if (!reason || !VALID_REASONS.includes(reason)) {
    return fail(res, CODE.BAD_REQUEST, '请选择举报理由');
  }
  // other 必填 description
  if (reason === 'other' && (!description || !description.trim())) {
    return fail(res, CODE.BAD_REQUEST, '请填写补充说明');
  }

  try {
    await reportService.createReport({
      reporterId: req.userId!,
      targetType: 'comment',
      targetId: commentId,
      reason: reason as reportService.ReportReason,
      description: description?.trim() || undefined,
    });
    return ok(res, null, '举报已提交');
  } catch (e: any) {
    if (e.reason === 'conflict')
      return fail(res, CODE.CONFLICT, '你已举报过该内容', 409);
    if (e.reason === 'not_found')
      return fail(res, CODE.NOT_FOUND, '评论不存在', 404);
    return fail(res, CODE.SERVER_ERROR, '举报失败', 500);
  }
});

export default router;
