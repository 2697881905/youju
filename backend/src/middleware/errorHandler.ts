import { Request, Response, NextFunction } from 'express';
import { CODE } from '../utils/response';
import { SensitiveWordError, ValidationError } from '../utils/errors';
import { env } from '../config/env';

/**
 * 全局兜底错误处理中间件。
 * 必须注册在路由之后，且仅声明 4 个参数（err, req, res, next）才会被 Express
 * 识别为错误处理中间件。捕获经 asyncHandler 转交的异步异常，统一返回 JSON，
 * 避免 DB/运行期异常导致连接挂起。
 */
export function errorHandler(
  err: any,
  _req: Request,
  res: Response,
  _next: NextFunction
): void {
  if (res.headersSent) {
    return;
  }

  // 敏感词命中：统一 400 友好提示
  if (err instanceof SensitiveWordError) {
    res.status(400).json({ code: CODE.BAD_REQUEST, data: null, message: err.message });
    return;
  }

  if (err instanceof ValidationError) {
    res.status(400).json({ code: CODE.BAD_REQUEST, data: null, message: err.message });
    return;
  }

  // Prisma 校验/约束类错误：本质是「客户端输入问题」，映射为 4xx，
  // 避免因调用方传入非法参数（如 NaN 分页）被误报为 500 并污染 5xx 日志。
  if (err?.name === 'PrismaClientValidationError') {
    res.status(400).json({ code: CODE.BAD_REQUEST, data: null, message: '请求参数不合法' });
    return;
  }
  const prismaCode: string | undefined = typeof err?.code === 'string' ? err.code : undefined;
  if (prismaCode === 'P2002') {
    res.status(409).json({ code: CODE.CONFLICT, data: null, message: '重复操作' });
    return;
  }
  if (prismaCode === 'P2025') {
    res.status(404).json({ code: CODE.NOT_FOUND, data: null, message: '记录不存在' });
    return;
  }
  if (prismaCode === 'P2003') {
    res.status(400).json({ code: CODE.BAD_REQUEST, data: null, message: '关联数据无效' });
    return;
  }

  const rawStatus = typeof err?.status === 'number' ? err.status : undefined;
  const status =
    rawStatus && rawStatus >= 400 && rawStatus < 600 ? rawStatus : 500;

  const code =
    status === 401 ? CODE.UNAUTHORIZED :
    status === 403 ? CODE.FORBIDDEN :
    status === 404 ? CODE.NOT_FOUND :
    status === 409 ? CODE.CONFLICT :
    status === 400 ? CODE.BAD_REQUEST :
    CODE.SERVER_ERROR;

  // 5xx 不向客户端泄露内部细节
  // 4xx 在生产环境对含内部线索（prisma/sql/stack/jwt 等）的消息归一化，避免泄露实现细节；开发环境原样透传便于调试。
  const INTERNAL_HINT = /prisma|sqlstate|sequelize|enoent|econnrefused|stack|jwt|raw query|aggregate/i;
  const rawMessage = err?.message ?? '请求处理失败';
  const dev = !env.isProduction;
  const message =
    status >= 500 ? '服务器内部错误，请稍后重试'
      : (dev || !INTERNAL_HINT.test(rawMessage) ? rawMessage : '请求处理失败');

  res.status(status).json({ code, data: null, message });

  if (status >= 500) {
    console.error('[errorHandler]', err);
  }
}
