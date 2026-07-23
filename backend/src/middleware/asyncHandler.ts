import { Request, Response, NextFunction, RequestHandler } from 'express';

/**
 * 包装 async 路由处理器，捕获未处理的 Promise rejection 并转交 Express 错误中间件。
 * Express 4 不会自动捕获 async handler 抛出的异常，未处理时连接会挂起（客户端报
 * "Failed to receive data"）。所有路由 handler 都应经此包装。
 */
export function asyncHandler(
  fn: (req: any, res: Response, next: NextFunction) => Promise<unknown> | void
): RequestHandler {
  return (req: Request, res: Response, next: NextFunction) => {
    Promise.resolve(fn(req, res, next)).catch(next);
  };
}
