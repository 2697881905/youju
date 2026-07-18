import { Router, Response } from 'express';
import { ok, fail, CODE } from '../utils/response';
import { auth, AuthRequest } from '../middleware/auth';
import * as postService from '../services/postService';
import * as reportService from '../services/reportService';
import { SensitiveWordError } from '../utils/errors';

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

// 关注流：GET /v1/posts/following?page=&limit=&sort=&tag=&keyword=
// 仅当前用户关注的人的公开帖（必须登录，由 auth 中间件保证）
// ⚠️ 必须注册在 GET /:id 之前，否则 /following 会被当作 id='following' 命中详情路由。
router.get('/following', auth, async (req: AuthRequest, res: Response) => {
  const { page, limit, sort, tag, keyword } = req.query;
  const data = await postService.listPosts({
    page: page ? Number(page) : 1,
    limit: limit ? Number(limit) : 20,
    sort: (sort as postService.SortType) ?? 'latest',
    tag: tag as string | undefined,
    keyword: keyword as string | undefined,
    following: true,
    viewerId: req.userId,
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
  try {
    const post = await postService.createPost(req.body, req.userId!);
    return ok(res, post);
  } catch (e: any) {
    if (e instanceof SensitiveWordError || e.reason === 'sensitive_word') {
      return fail(res, CODE.BAD_REQUEST, e.message);
    }
    console.error('[posts.create] error:', e);
    return fail(res, CODE.SERVER_ERROR, '发布失败', 500);
  }
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

// 举报帖子：POST /v1/posts/:id/report
router.post('/:id/report', auth, async (req: AuthRequest, res: Response) => {
  const postId = Number(req.params.id);
  if (!postId) return fail(res, CODE.BAD_REQUEST, '无效帖子ID');
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
      targetType: 'post',
      targetId: postId,
      reason: reason as reportService.ReportReason,
      description: description?.trim() || undefined,
    });
    return ok(res, null, '举报已提交');
  } catch (e: any) {
    if (e.reason === 'conflict')
      return fail(res, CODE.CONFLICT, '你已举报过该内容', 409);
    if (e.reason === 'not_found')
      return fail(res, CODE.NOT_FOUND, '帖子不存在', 404);
    return fail(res, CODE.SERVER_ERROR, '举报失败', 500);
  }
});

export default router;
