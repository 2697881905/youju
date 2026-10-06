// 一次性冒烟：验证 per-user 限流按 userId 计数（用户 A 打满 → 429；用户 B 不受影响）。
// 运行：npx tsx scripts/smoke-user-limiter.mjs（NODE_ENV 需非 test，绕过测试豁免）
process.env.NODE_ENV = 'production';
import express from 'express';
import { dmLimiter } from '../src/middleware/rateLimit';

const app = express();
// 冒烟请求来自 127.0.0.1，会命中 skipLocal 开发豁免 → 伪造公网来源 IP 绕过豁免，验证真实计数
app.set('trust proxy', true);
app.post('/t', ((req: any, _res, next) => {
  req.userId = Number(req.headers['x-uid']);
  next();
}) as any, dmLimiter, ((_req: any, res: any) => res.json({ ok: true })) as any);

const server = app.listen(0);
const port = (server.address() as any).port;
const fire = async (uid: number): Promise<number> => {
  const r = await fetch(`http://127.0.0.1:${port}/t`, { method: 'POST', headers: { 'x-uid': String(uid), 'x-forwarded-for': '203.0.113.7' } });
  return r.status;
};

let userA_429 = 0;
for (let i = 0; i < 31; i++) {
  const s = await fire(1);
  if (s === 429) userA_429 += 1;
}
const userB = await fire(2);
server.close();

console.log(`userA 31 连发中 429 数量: ${userA_429}（期望 1）`);
console.log(`userB 首发状态码: ${userB}（期望 200，不被 A 的配额影响）`);
if (userA_429 === 1 && userB === 200) {
  console.log('SMOKE PASS');
  process.exit(0);
}
console.log('SMOKE FAIL');
process.exit(1);
