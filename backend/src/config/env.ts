import dotenv from 'dotenv';
import path from 'path';

dotenv.config();

export const env = {
  port: Number(process.env.PORT ?? 3000),
  nodeEnv: process.env.NODE_ENV ?? 'development',
  isProduction: (process.env.NODE_ENV ?? 'development') === 'production',
  databaseUrl: process.env.DATABASE_URL ?? '',
  jwtSecret: process.env.JWT_SECRET ?? '',
  jwtExpiresIn: process.env.JWT_EXPIRES_IN ?? '30d',
  oss: {
    region: process.env.OSS_REGION ?? '',
    bucket: process.env.OSS_BUCKET ?? '',
    accessKey: process.env.OSS_ACCESS_KEY ?? '',
    secretKey: process.env.OSS_SECRET_KEY ?? '',
    endpoint: process.env.OSS_ENDPOINT ?? '',
    cdnBase: process.env.CDN_BASE ?? '',
  },
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
  // CORS 允许的源（逗号分隔）。留空 = 允许所有（仅开发期，生产务必配置具体域名）。
  corsOrigin: process.env.CORS_ORIGIN ?? '',
  // 本地文件上传（无真实对象存储时的开发期兜底）：对外可访问的基础地址 + 落盘目录
  // 模拟器通过 BASE_URL（默认 http://127.0.0.1:3000）访问，故此处默认与之对齐。
  backendPublicUrl: process.env.BACKEND_PUBLIC_URL ?? 'http://127.0.0.1:3000',
  uploadsDir: process.env.UPLOADS_DIR ?? path.resolve(process.cwd(), 'uploads'),
};
