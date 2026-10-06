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

// 测试环境（jest 默认 NODE_ENV=test）跳过业务限流：测试会真实连续命中对应路由，
// 被限流误伤会弄脏断言；部署环境 NODE_ENV=production，生产行为不受影响。
const skipTest: (req: any) => boolean = (req: any): boolean =>
  process.env.NODE_ENV === 'test' || skipLocal(req);

// 全站基础限流：每 IP 15 分钟 600 次（防刷接口）。
// 原 300 次对正常客户端偏紧：私信页轮询 + 信息流埋点 + 页面/详情请求叠加后，
// 活跃用户 15 分钟可接近甚至超过 300，配额一旦耗尽，后续所有请求都返回 429，
// 表现为「一进私信页就提示请求过于频繁」（2026-09-24 定位）。
// 600 = 40 次/分钟，对真人操作留有余量，对脚本刷量仍构成限制。
export const globalLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  max: 600,
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

// 行为埋点接口：高频但需防刷（伪造曝光/点击污染热度与个性化画像）。
// 每 IP 每分钟 240 次：正常滑动信息流的曝光上报远低于此上限，但足以挡住脚本刷量。
export const metricsLimiter = rateLimit({
  windowMs: 60 * 1000,
  max: 240,
  standardHeaders: true,
  legacyHeaders: false,
  skip: skipLocal,
  handler,
});

// 搜索联想（匿名可调）：单请求并发 3 个 DB 查询，全局限流下仍可被放大为 DB 压力。
// 每 IP 每分钟 60 次：真人输入联想远低于此，脚本批量探测打不动。
export const suggestLimiter = rateLimit({
  windowMs: 60 * 1000,
  max: 60,
  standardHeaders: true,
  legacyHeaders: false,
  skip: skipTest,
  handler,
});

// —— 内容生产端点 per-user 限流（必须挂在 auth 之后，按 req.userId 计数）——
// globalLimiter 按 IP 计数：同 IP 多账号互不影响、换 IP 即绕过；这三个封口
// 「单账号高频刷量/骚扰」（换 IP 无效，因为同一账号就是同一把钥匙）。阈值即产品口径：
//   私信 30 条/分钟——正常聊天远打不到，脚本轰炸被挡（接收方另有 dmPolicy + 拉黑兜底）；
//   发帖  5 条/分钟——发布是重操作（敏感词检测 + 结构化字段），真人不可能触达；
//   评论 10 条/分钟——热烈讨论留足余量，纯灌水被挡。
function userKey(req: any): string {
  return 'u' + String(req.userId ?? 0);
}

export const dmLimiter = rateLimit({
  windowMs: 60 * 1000,
  max: 30,
  standardHeaders: true,
  legacyHeaders: false,
  keyGenerator: userKey,
  skip: skipTest,
  handler,
});

export const postCreateLimiter = rateLimit({
  windowMs: 60 * 1000,
  max: 5,
  standardHeaders: true,
  legacyHeaders: false,
  keyGenerator: userKey,
  skip: skipTest,
  handler,
});

export const commentLimiter = rateLimit({
  windowMs: 60 * 1000,
  max: 10,
  standardHeaders: true,
  legacyHeaders: false,
  keyGenerator: userKey,
  skip: skipTest,
  handler,
});


