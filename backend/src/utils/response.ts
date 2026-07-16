import { Response } from 'express';

// 统一错误码
export const CODE = {
  OK: 0,
  BAD_REQUEST: 400,
  UNAUTHORIZED: 401,
  FORBIDDEN: 403,
  NOT_FOUND: 404,
  CONFLICT: 409,
  SERVER_ERROR: 500,
};

// 统一响应包：{ code, data, message }
export function ok<T>(res: Response, data: T, message = 'success') {
  return res.json({ code: CODE.OK, data, message });
}

export function fail(res: Response, code: number, message: string, httpStatus = 400) {
  return res.status(httpStatus).json({ code, data: null, message });
}
