import { app } from './app';
import { env } from './config/env';

function failHard(message: string): never {
  console.error('[启动失败] ' + message);
  process.exit(1);
}

// 安全启动校验：生产环境缺失关键安全配置时拒绝启动，
// 避免带着默认/开放配置上线（token 可被伪造、任意站点可跨域调用）。
if (!env.jwtSecret) {
  if (env.isProduction) {
    failHard('JWT_SECRET 未设置，生产环境拒绝启动（token 可被伪造）。请在环境变量中配置强随机密钥。');
  }
  console.warn('[安全警示] JWT_SECRET 未设置，当前使用空密钥（仅开发期，严禁用于生产）。');
}

if (!env.corsOrigin) {
  if (env.isProduction) {
    failHard('CORS_ORIGIN 未配置，生产环境拒绝启动（不允许开放跨域）。请配置具体允许的域名（逗号分隔）。');
  }
  console.warn('[安全警示] CORS_ORIGIN 未配置，当前允许所有来源跨域（仅开发期）。');
}

app.listen(env.port, () => {
  console.log(`BigBlueBook API listening on http://localhost:${env.port}`);
});
