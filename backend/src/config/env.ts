import dotenv from 'dotenv';
import path from 'path';

dotenv.config();

// 百分比配置的容错解析：非法值回退 100（全量），并钳制到 [0, 100]。
function clampPercent(raw: string | undefined): number {
  const value = Number(raw);
  if (!Number.isFinite(value)) {
    return 100;
  }
  return Math.min(100, Math.max(0, value));
}

export const env = {
  port: Number(process.env.PORT ?? 3000),
  nodeEnv: process.env.NODE_ENV ?? 'development',
  isProduction: (process.env.NODE_ENV ?? 'development') === 'production',
  databaseUrl: process.env.DATABASE_URL ?? '',
  jwtSecret: process.env.JWT_SECRET ?? '',
  jwtExpiresIn: process.env.JWT_EXPIRES_IN ?? '30d',
  cos: {
    secretId: process.env.COS_SECRET_ID ?? '',
    secretKey: process.env.COS_SECRET_KEY ?? '',
    bucket: process.env.COS_BUCKET ?? '',
    region: process.env.COS_REGION ?? '',
    cdnBase: process.env.COS_CDN_BASE ?? '',
  },
  // 内容审核 & 举报系统
  adminUserIds: (process.env.ADMIN_USER_IDS ?? '')
    .split(',')
    .map((s) => parseInt(s.trim(), 10))
    .filter((n) => !isNaN(n) && n > 0),
  reportThreshold: Number(process.env.REPORT_THRESHOLD ?? 3),
  // 运营通知 Webhook（如飞书群自定义机器人）：出现新举报时向运营推送。
  // 留空 = 不推送（静默降级，不影响举报落库与自动下架）。
  opsWebhookUrl: process.env.OPS_WEBHOOK_URL ?? '',
  // CORS 允许的源（逗号分隔）。留空 = 允许所有（仅开发期，生产务必配置具体域名）。
  corsOrigin: process.env.CORS_ORIGIN ?? '',
  // 本地文件上传（无真实对象存储时的开发期兜底）：对外可访问的基础地址 + 落盘目录
  // 模拟器通过 BASE_URL（默认 http://127.0.0.1:3000）访问，故此处默认与之对齐。
  backendPublicUrl: process.env.BACKEND_PUBLIC_URL ?? 'http://127.0.0.1:3000',
  uploadsDir: process.env.UPLOADS_DIR ?? path.resolve(process.cwd(), 'uploads'),
  // 视频上传体积上限（字节）。前端拦截 + 后端 token 接口二次兜底，防直传 COS 绕过客户端限制。
  maxVideoSizeBytes: Number(process.env.MAX_VIDEO_SIZE_MB ?? 50) * 1024 * 1024,
  // 华为推送服务（Push Kit）凭证。留空 = 未配置 → 所有推送静默降级（不阻断通知落库）。
  // 真实设备推送需在 AGC 开启「推送服务」并填入对应应用的 APP ID 与 APP SECRET。
  huaweiPush: {
    appId: process.env.HUAWEI_PUSH_APP_ID ?? '',
    appSecret: process.env.HUAWEI_PUSH_APP_SECRET ?? '',
    // 鉴权与下发端点（默认华为官方，一般无需改动）
    tokenUrl:
      process.env.HUAWEI_PUSH_TOKEN_URL ?? 'https://oauth-login.cloud.huawei.com/oauth2/v3/token',
    apiUrl: process.env.HUAWEI_PUSH_API_URL ?? 'https://push-api.cloud.huawei.com',
  },
  // 华为账号登录（Account Kit）凭证。留空 = 真实华为登录不可用（前端授权后后端换 token 失败）。
  huaweiAccount: {
    clientId: process.env.HUAWEI_CLIENT_ID ?? '',
    clientSecret: process.env.HUAWEI_CLIENT_SECRET ?? '',
    redirectUri: process.env.HUAWEI_REDIRECT_URI ?? '',
  },
  // 当前生效的隐私政策版本（前端弹窗同意时上报此版本；低于此版本视为需重新征求）
  privacyPolicyVersion: process.env.PRIVACY_POLICY_VERSION ?? '1.0.0',
  // 每日一贴个性化推荐灰度比例（0-100，按 userId 稳定 hash 分流）。
  // 100 = 全量个性化（默认，行为与历史一致）；0 = 全部走非个性化对照组；
  // 中间值 = A/B 实验。改配置 + 重启即可放量/回滚，无需发版。
  dailyPersonalizationRollout: clampPercent(process.env.DAILY_PERSONALIZATION_ROLLOUT),
};

// 生产环境安全闸口：BACKEND_PUBLIC_URL 必须使用 https，避免下发明文 http 链接（F-005）。
// 与 index.ts 的 fail-hard 风格一致：配置缺失/不安全时启动即崩溃，而非静默降级。
if (env.isProduction && env.backendPublicUrl.startsWith('http://')) {
  throw new Error('[env] 生产环境 BACKEND_PUBLIC_URL 必须使用 https，请配置 https 域名');
}

// 华为账号登录凭证自检：缺失则在启动日志告警，避免「前端授权成功、后端静默失败」。
if (!env.huaweiAccount.clientId || !env.huaweiAccount.clientSecret) {
  console.warn('[env] 警告：HUAWEI_CLIENT_ID / HUAWEI_CLIENT_SECRET 未配置，华为账号真实登录将不可用（仅开发桩可登录）。请从 AGC 复制填入 backend/.env 后重启后端。');
}
