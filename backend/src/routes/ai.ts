import { Router, Response } from 'express';
import { ok } from '../utils/response';
import { auth, AuthRequest } from '../middleware/auth';
import { asyncHandler } from '../middleware/asyncHandler';
import { aiLimiter } from '../middleware/rateLimit';
import { aiEnabled, polishTitle, polishDraft, structureDraft } from '../services/aiService';
import { ValidationError } from '../utils/errors';

const router = Router();

function userIdOf(req: AuthRequest): number {
  const userId = Number(req.userId ?? 0);
  if (!(userId > 0)) {
    throw new ValidationError('请先登录');
  }
  return userId;
}

function stringField(body: unknown, key: string): string {
  const value = (body as Record<string, unknown>)?.[key];
  return typeof value === 'string' ? value : '';
}

// GET /v1/ai/status：前端据此显隐 AI 入口。凭证未配置时 enabled:false，前端整体隐藏，不报错。
router.get('/status', (_req, res: Response) => {
  ok(res, { enabled: aiEnabled() });
});

// POST /v1/ai/polish-title：标题优化。{ title, content, genre } → { title }
router.post('/polish-title', auth, aiLimiter, asyncHandler(async (req: AuthRequest, res: Response) => {
  const userId: number = userIdOf(req);
  const result = await polishTitle(userId, stringField(req.body, 'title'), stringField(req.body, 'content'), stringField(req.body, 'genre'));
  return ok(res, result);
}));

// POST /v1/ai/polish-draft：标题 + 正文联合轻度润色。{ title, content, genre, maxContent } → { title, content }
// maxContent：前端按发布页正文上限传入（图文说明 300 / 长文 5000），后端钳制并写进 prompt。
router.post('/polish-draft', auth, aiLimiter, asyncHandler(async (req: AuthRequest, res: Response) => {
  const userId: number = userIdOf(req);
  const maxContent = Number((req.body as Record<string, unknown>)?.maxContent);
  const result = await polishDraft(
    userId,
    stringField(req.body, 'title'),
    stringField(req.body, 'content'),
    stringField(req.body, 'genre'),
    maxContent
  );
  return ok(res, result);
}));

// POST /v1/ai/structure-draft：正文整理结构化。{ content, genre? } → { document, genre, template }
// genre 可选：空则 LLM 从正文推断体裁；响应 genre 为推断/回退结果、template 为推荐骨架 key。
// 返回的 document 已过 validateStructuredDocument 硬校验，前端灌入审稿层由作者逐块确认。
router.post('/structure-draft', auth, aiLimiter, asyncHandler(async (req: AuthRequest, res: Response) => {
  const userId: number = userIdOf(req);
  const result = await structureDraft(userId, stringField(req.body, 'content'), stringField(req.body, 'genre'));
  return ok(res, result);
}));

export default router;
