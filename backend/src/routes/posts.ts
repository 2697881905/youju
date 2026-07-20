import { Router, Response } from 'express';
import jwt from 'jsonwebtoken';
import { ok, fail, CODE } from '../utils/response';
import { auth, AuthRequest } from '../middleware/auth';
import { env } from '../config/env';
import { prisma } from '../prisma';
import * as postService from '../services/postService';
import * as reportService from '../services/reportService';
import { SensitiveWordError } from '../utils/errors';

const router = Router();

// 软鉴权（仅用于公开浏览 GET 路由：信息流 / 详情）：
// 手动从 Authorization 头解析 Bearer token；有合法 token 则取 viewerId，
// 缺失 / 非法 token 不返回 401（保证匿名用户也能浏览推荐流与详情，不破坏公开浏览）。
// 解析方式参考 middleware/auth.ts，但失败时降级为 undefined 而非 401。
function resolveViewerId(req: AuthRequest): number | undefined {
  const header = req.headers.authorization;
  if (!header || !header.startsWith('Bearer ')) {
    return undefined;
  }
  try {
    const payload = jwt.verify(header.slice(7), env.jwtSecret) as { userId?: number };
    return typeof payload.userId === 'number' ? payload.userId : undefined;
  } catch {
    return undefined;
  }
}

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
// 软鉴权：匿名可浏览；带合法 token 时按 viewerId 批量打标 myUp/myBookmark。
router.get('/', async (req: AuthRequest, res: Response) => {
  const { page, limit, sort, tag, author, keyword } = req.query;
  const data = await postService.listPosts({
    page: page ? Number(page) : 1,
    limit: limit ? Number(limit) : 20,
    sort: (sort as postService.SortType) ?? 'latest',
    tag: tag as string | undefined,
    author: author ? Number(author) : undefined,
    keyword: keyword as string | undefined,
    viewerId: resolveViewerId(req),
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
// 软鉴权：匿名可访问；带合法 token 时返回该帖的 myUp/myBookmark。
router.get('/:id', async (req: AuthRequest, res: Response) => {
  const id = Number(req.params.id);
  if (!id) return fail(res, CODE.BAD_REQUEST, '无效帖子ID');
  const viewerId = resolveViewerId(req);
  const post = await postService.getPost(id, viewerId);
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
  if (!id || isNaN(id)) return fail(res, CODE.BAD_REQUEST, '无效帖子ID');
  const result = await postService.deletePost(id, req.userId!);
  if (!result.ok) {
    if (result.reason === 'not_found') return fail(res, CODE.NOT_FOUND, '帖子不存在', 404);
    if (result.reason === 'forbidden') return fail(res, CODE.FORBIDDEN, '只能删除自己的帖子', 403);
  }
  return ok(res, null, '已删除');
});

// 编辑帖子（仅本人）：PUT /v1/posts/:id
router.put('/:id', auth, async (req: AuthRequest, res: Response) => {
  const id = Number(req.params.id);
  if (!id || isNaN(id)) return fail(res, CODE.BAD_REQUEST, '无效帖子ID');
  const result = await postService.updatePost(id, req.userId!, req.body ?? {});
  if (!result.ok) {
    if (result.reason === 'not_found') return fail(res, CODE.NOT_FOUND, '帖子不存在', 404);
    if (result.reason === 'forbidden') return fail(res, CODE.FORBIDDEN, '只能编辑自己的帖子', 403);
  }
  return ok(res, result.post);
});

// 辩论投票：POST /v1/posts/:id/vote { choice: 'A' | 'B' }（幂等，同用户改票以最后一次为准）
router.post('/:id/vote', auth, async (req: AuthRequest, res: Response) => {
  const postId = Number(req.params.id);
  const choice = req.body?.choice as string;
  if (!postId || isNaN(postId)) return fail(res, CODE.BAD_REQUEST, '无效帖子ID');
  if (choice !== 'A' && choice !== 'B') return fail(res, CODE.BAD_REQUEST, 'choice 必须为 A 或 B');
  try {
    // 查现有投票记录
    const existing = await prisma.debateVote.findUnique({
      where: { userId_postId: { userId: req.userId!, postId } },
    });
    if (existing) {
      if (existing.choice === choice) {
        // 同选项重复投 → 幂等，不更新
        return ok(res, { voted: true, choice });
      }
      // 改票：减旧票 + 加新票
      const decField = existing.choice === 'A' ? 'planAVotes' : 'planBVotes';
      const incField = choice === 'A' ? 'planAVotes' : 'planBVotes';
      await prisma.post.update({ where: { id: postId }, data: { [decField]: { decrement: 1 } } });
      await prisma.post.update({ where: { id: postId }, data: { [incField]: { increment: 1 } } });
      await prisma.debateVote.update({ where: { id: existing.id }, data: { choice } });
    } else {
      // 新投票
      const incField = choice === 'A' ? 'planAVotes' : 'planBVotes';
      await prisma.post.update({ where: { id: postId }, data: { [incField]: { increment: 1 } } });
      await prisma.debateVote.create({ data: { userId: req.userId!, postId, choice } });
    }
    // 返回最新票数
    const post = await prisma.post.findUnique({ where: { id: postId }, select: { planAVotes: true, planBVotes: true } });
    return ok(res, { voted: true, choice, planAVotes: post?.planAVotes ?? 0, planBVotes: post?.planBVotes ?? 0 });
  } catch (e) {
    return fail(res, CODE.SERVER_ERROR, (e as Error).message);
  }
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
