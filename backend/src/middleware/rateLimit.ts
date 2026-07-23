import rateLimit from 'express-rate-limit';
import { Response } from 'express';

const handler = (_req: any, res: Response) => {
  res.status(429).json({ code: 429, data: null, message: '请求过于频繁，请稍后再试' });
};

// 全站基础限流：每 IP 15 分钟 300 次（防刷接口）
export const globalLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  max: 300,
  standardHeaders: true,
  legacyHeaders: false,
  handler,
});

// 登录接口：防爆破 / 撞库，每 IP 15 分钟 20 次
export const loginLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  max: 20,
  standardHeaders: true,
  legacyHeaders: false,
  handler,
});

// 上传预签名接口：防 COS 配额滥用，每 IP 每分钟 30 次
export const uploadLimiter = rateLimit({
  windowMs: 60 * 1000,
  max: 30,
  standardHeaders: true,
  legacyHeaders: false,
  handler,
});
