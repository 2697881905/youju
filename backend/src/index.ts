import { app } from './app';
import { env } from './config/env';

if (env.jwtSecret === 'dev-secret-change-me') {
  console.warn(
    '[安全警示] 正在使用默认 JWT 密钥 "dev-secret-change-me"，生产环境请设置强随机 JWT_SECRET 环境变量，否则 token 可被伪造。',
  );
}
if (!env.corsOrigin) {
  console.warn(
    '[安全警示] CORS_ORIGIN 未配置，当前允许所有来源跨域。生产环境请设置具体域名（逗号分隔）。',
  );
}

app.listen(env.port, () => {
  console.log(`BigBlueBook API listening on http://localhost:${env.port}`);
});
