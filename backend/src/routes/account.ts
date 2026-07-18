import { Router, Response } from 'express';
import { ok, fail, CODE } from '../utils/response';
import { auth, AuthRequest } from '../middleware/auth';
import {
  listBindings,
  bind,
  unbind,
  AccountError,
  Provider,
} from '../services/accountBindingService';

// 账号绑定管理路由（挂在 /v1/account 下，故路径均为 /bindings*）
// 三个接口全部经 auth 中间件保护；所有 DB 操作强制以 req.userId 为过滤条件防越权。
const router = Router();

// 列表：GET /v1/account/bindings
router.get('/bindings', auth, async (req: AuthRequest, res: Response) => {
  try {
    const items = await listBindings(req.userId!);
    return ok(res, items);
  } catch (e) {
    return handleError(res, e);
  }
});

// 绑定：POST /v1/account/bindings  body { provider, code }
router.post('/bindings', auth, async (req: AuthRequest, res: Response) => {
  const body = req.body ?? {};
  const provider: unknown = body.provider;
  const code: unknown = body.code;
  if (typeof provider !== 'string' || !provider || typeof code !== 'string' || !code) {
    return fail(res, CODE.BAD_REQUEST, '缺少 provider 或授权码', 400);
  }
  try {
    const item = await bind(req.userId!, provider as Provider, code);
    return ok(res, item);
  } catch (e) {
    return handleError(res, e);
  }
});

// 解绑：DELETE /v1/account/bindings/:provider
router.delete('/bindings/:provider', auth, async (req: AuthRequest, res: Response) => {
  const provider: string = req.params.provider;
  try {
    const result = await unbind(req.userId!, provider as Provider);
    return ok(res, result);
  } catch (e) {
    return handleError(res, e);
  }
});

// 统一错误转换：已知 AccountError 用其携带的 code/httpStatus；其余归为 500
function handleError(res: Response, e: unknown): Response {
  if (e instanceof AccountError) {
    return fail(res, e.code, e.message, e.httpStatus);
  }
  const err = e as Error;
  return fail(res, CODE.SERVER_ERROR, err.message || '服务异常', 500);
}

export default router;
