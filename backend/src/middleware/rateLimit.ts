import rateLimit from 'express-rate-limit';
import { Response } from 'express';
import { isIPv4 } from 'net';

const handler = (_req: any, res: Response) => {
  res.status(429).json({ code: 429, data: null, message: '请求过于频繁，请稍后再试' });
};

// 开发联调豁免：来自私有网段（本机 / 局域网）的请求不做限流，
// 避免真机调试时因 IP 计数被误伤触发 429；公网真实客户端仍照常限流，安全性不受影响。
// 生产环境后端位于 nginx 之后（trust proxy=1），公网客户端 req.ip 为真实公网地址，不会被豁免。
function isPrivateOrLocalIp(ip: string | undefined): boolean {
  if (!ip) {
    return false;
  }
  // 处理 IPv4-mapped IPv6（如 ::ffff:192.168.1.5）
  if (ip.startsWith('::ffff:')) {
    ip = ip.slice('::ffff:'.length);
  }
  if (ip === '127.0.0.1' || ip === '::1') {
    return true;
  }
  if (ip === 'localhost') {
    return true;
  }
  if (!isIPv4(ip)) {
    return false;
  }
  const p: number[] = ip.split('.').map((s: string): number => Number(s));
  if (p[0] === 10) {
    return true; // 10.0.0.0/8
  }
  if (p[0] === 172 && p[1] >= 16 && p[1] <= 31) {
    return true; // 172.16.0.0/12
  }
  if (p[0] === 192 && p[1] === 168) {
    return true; // 192.168.0.0/16
  }
  if (p[0] === 169 && p[1] === 254) {
    return true; // 169.254.0.0/16 link-local
  }
  return false;
}

const skipLocal: (req: any) => boolean = (req: any): boolean => isPrivateOrLocalIp(req.ip);

// 全站基础限流：每 IP 15 分钟 300 次（防刷接口）
export const globalLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  max: 300,
  standardHeaders: true,
  legacyHeaders: false,
  skip: skipLocal,
  handler,
});

// 登录接口：防爆破 / 撞库，每 IP 15 分钟 20 次
export const loginLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  max: 20,
  standardHeaders: true,
  legacyHeaders: false,
  skip: skipLocal,
  handler,
});

// 上传预签名接口：防 COS 配额滥用，每 IP 每分钟 30 次
export const uploadLimiter = rateLimit({
  windowMs: 60 * 1000,
  max: 30,
  standardHeaders: true,
  legacyHeaders: false,
  skip: skipLocal,
  handler,
});

