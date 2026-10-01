import dotenv from 'dotenv';
import path from 'path';

dotenv.config();

const NODE_ENV: string = process.env.NODE_ENV ?? 'development';
const IS_PRODUCTION: boolean = NODE_ENV === 'production';

// 百分比配置的容错解析：非法值回退 100（全量），并钳制到 [0, 100]。
function clampPercent(raw: string | undefined): number {
  const value = Number(raw);
  if (!Number.isFinite(value)) {
    return 100;
  }
  return Math.min(100, Math.max(0, value));
}

// 正整数配置的容错解析：非法或非正值回退默认值（用于留存天数等）。
function clampPositiveInt(raw: string | undefined, fallback: number): number {
  const value = Number(raw);
  if (!Number.isFinite(value) || value <= 0) {
    return fallback;
  }
  return Math.floor(value);
}

export const env = {
  port: Number(process.env.PORT ?? 3000),
  nodeEnv: NODE_ENV,
  isProduction: IS_PRODUCTION,
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
  // 华为推送服务（Push Kit REST API v3）。凭证缺失 → 所有推送静默降级（不阻断通知落库）。
  // ⚠️ HarmonyOS 5+ 已废弃 OAuth 2.0 client_credentials 鉴权，改为「服务账号 JWT 直签」：
  //    AGC → 用户与访问 → API 密钥 → Connect API → Service Account（开发者级）→ 下载凭据 JSON。
  //    凭据文件含私钥，禁止入库 —— 放到服务器本地路径，由 serviceAccountPath 指向。
  huaweiPush: {
    // 项目 ID（v3 接口路径参数）：AGC → 项目设置 → 项目 ID
    projectId: process.env.HUAWEI_PUSH_PROJECT_ID ?? '',
    // 服务账号凭据 JSON 的绝对路径（默认 backend/agc-service-account.json）
    serviceAccountPath:
      process.env.HUAWEI_PUSH_SERVICE_ACCOUNT_PATH ??
      path.resolve(process.cwd(), 'agc-service-account.json'),
    // 下行端点（一般无需改动）
    apiUrl: process.env.HUAWEI_PUSH_API_URL ?? 'https://push-api.cloud.huawei.com',
    // 兜底 category：未被 huaweiPush 的 CATEGORY_BY_NOTIFY_TYPE 映射覆盖的通知类型用它。
    // ⚠️ 传一个 AGC 未授予权益的 category 不会报错，华为会静默把它降级归到资讯营销类
    //    （单设备每日 2 条限流）。与其自欺欺人地填 IM，不如显式填 MARKETING ——
    //    行为与华为的实际处理一致，排查时不用再怀疑"到底发出去的是哪一类"。
    category: process.env.HUAWEI_PUSH_CATEGORY ?? 'MARKETING',
    // 调测消息：true 时不触发上述频控（每项目每日上限 1000 条）。默认非生产环境开启。
    // ⚠️ 上线前务必确认生产环境为 false，否则调试配额耗尽后消息被丢弃。
    testMessage: (process.env.HUAWEI_PUSH_TEST_MESSAGE ?? (IS_PRODUCTION ? 'false' : 'true')) === 'true',
    // 离线消息缓存时长（秒），默认 24 小时
    ttl: Number(process.env.HUAWEI_PUSH_TTL ?? 86400),
  },
  // 华为账号登录（Account Kit）凭证。留空 = 真实华为登录不可用（前端授权后后端换 token 失败）。
  huaweiAccount: {
    clientId: process.env.HUAWEI_CLIENT_ID ?? '',
    clientSecret: process.env.HUAWEI_CLIENT_SECRET ?? '',
    redirectUri: process.env.HUAWEI_REDIRECT_URI ?? '',
  },
  // 当前生效的隐私政策版本（前端弹窗同意时上报此版本；低于此版本视为需重新征求）
  // 1.1.0：补充「个性化推荐与自动化决策」专节（算法原理/信息范围/应用内关闭路径）
  privacyPolicyVersion: process.env.PRIVACY_POLICY_VERSION ?? '1.1.0',
  // 每日一贴个性化推荐灰度比例（0-100，按 userId 稳定 hash 分流）。
  // 100 = 全量个性化（默认，行为与历史一致）；0 = 全部走非个性化对照组；
  // 中间值 = A/B 实验。改配置 + 重启即可放量/回滚，无需发版。
  dailyPersonalizationRollout: clampPercent(process.env.DAILY_PERSONALIZATION_ROLLOUT),
  // 行为明细数据（PostEvent 浏览/互动埋点、SearchHistory 搜索历史）的留存天数。
  // 到期由后台任务自动清理明细（PIPL 第 19 条：保存期限应为实现目的所必需的最短时间）。
  behaviorRetentionDays: clampPositiveInt(process.env.BEHAVIOR_RETENTION_DAYS, 180),
  // 是否启用行为数据到期清理（默认启用；本地调试或需保留样本时可设为 false）
  behaviorRetentionEnabled: (process.env.BEHAVIOR_RETENTION_ENABLED ?? 'true') !== 'false',
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
