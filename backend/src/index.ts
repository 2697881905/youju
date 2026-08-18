import { app } from './app';
import { env } from './config/env';
import { startMediaDeletionWorker } from './services/mediaDeletionService';

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

// 显式监听 IPv4，确保 DevEco 模拟器通过 hdc rport 转发到 127.0.0.1 时可达。
app.listen(env.port, '0.0.0.0', () => {
  console.log(`有据 API listening on http://0.0.0.0:${env.port}`);
  // 存储模式自检：云真机/真机只能加载公网图；local 模式图片为 LAN 直链，云侧必空白。
  const cosReady = Boolean(env.cos.secretId && env.cos.secretKey && env.cos.bucket && env.cos.region);
  console.log(`[存储] 上传模式 = ${cosReady ? 'COS（私有桶，媒体经 /v1/media 短签名读取）' : 'local（图片为 LAN 直链，仅本机/模拟器可见，云真机将空白）'}`);
  if (!cosReady) {
    console.warn('[存储警示] 未检测到完整 COS 凭据，图片走 local 模式；在云手机/真机上图片将无法加载。请检查 backend/.env 的 COS_* 变量。');
  }
  startMediaDeletionWorker();
});
