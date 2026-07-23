import express from 'express';
import cors from 'cors';
import helmet from 'helmet';
import { env } from './config/env';
import authRouter from './routes/auth';
import postRouter from './routes/posts';
import commentRouter from './routes/comments';
import interactRouter from './routes/interact';
import tagRouter from './routes/tags';
import uploadRouter from './routes/upload';
import searchRouter from './routes/search';
import accountRouter from './routes/account';
import notificationRouter from './routes/notifications';
import userRouter from './routes/users';
import adminRouter from './routes/admin';
// 用户安全设置类路由（通知偏好 / 拉黑 / 隐私 / 数据导出），均挂 /v1 前缀
import notificationPrefRouter from './routes/notificationPrefs';
import blockRouter from './routes/block';
import privacyRouter from './routes/privacy';
import exportRouter from './routes/export';
import { sensitiveWordService } from './services/sensitiveWordService';
import { errorHandler } from './middleware/errorHandler';
import { globalLimiter, loginLimiter, uploadLimiter } from './middleware/rateLimit';

export const app = express();

// 安全响应头（CSP / HSTS / X-Content-Type-Options 等）
app.use(helmet());

// 全站基础限流：防爆破 / 刷接口
app.use(globalLimiter);

// CORS：生产环境通过 CORS_ORIGIN 限定具体来源（逗号分隔）。
// 留空时放开全部（开发期方便真机/模拟器联调），但 index.ts 会在生产环境拒绝启动。
const allowedOrigins = env.corsOrigin
  ? env.corsOrigin.split(',').map((s) => s.trim()).filter(Boolean)
  : undefined;
app.use(cors(allowedOrigins ? { origin: allowedOrigins } : undefined));
app.use(express.json());

app.get('/health', (_req, res) => res.json({ ok: true }));

// 启动时加载敏感词库（文件不存在时降级为空词库，不拦截）
sensitiveWordService.loadFromFiles([
  'data/sensitive-words.txt',
  'data/gender-war-words.txt',
]);

// 登录接口：防爆破 / 撞库（每 IP 15 分钟 20 次）
app.use('/v1/auth/login', loginLimiter);
// 上传预签名接口：防 COS 配额滥用（每 IP 每分钟 30 次）
app.use('/v1/upload/token', uploadLimiter);

// 同时挂 /v1/auth 与 /v1/users，覆盖文档两类路径
app.use('/v1/auth', authRouter);
app.use('/v1/users', authRouter);
// 用户资料 / 关注关系（挂在 /v1/users，authRouter 之后；GET /me 仍由 authRouter 命中）
app.use('/v1/users', userRouter);
app.use('/v1/posts', postRouter);
app.use('/v1/tags', tagRouter);
app.use('/v1/upload', uploadRouter);
app.use('/v1/search', searchRouter);
// 账号绑定管理（GET/POST/DELETE /v1/account/bindings），与 /v1/auth、/v1/posts 同级
app.use('/v1/account', accountRouter);
// 消息通知（GET /v1/notifications、GET /v1/notifications/unread-count、
// POST /v1/notifications/:id/read、POST /v1/notifications/read-all）
app.use('/v1', notificationRouter);
// 评论/互动使用完整路径（/v1/posts/:id/comments、/v1/posts/:id/up 等）
app.use('/v1', commentRouter);
app.use('/v1', interactRouter);
// admin 审核 API（GET /v1/admin/posts/pending、POST /v1/admin/posts/:id/moderate、GET /v1/admin/reports）
app.use('/v1/admin', adminRouter);
// 用户安全设置（通知偏好 / 拉黑 / 隐私 / 数据导出），统一挂 /v1
app.use('/v1', notificationPrefRouter);
app.use('/v1', blockRouter);
app.use('/v1', privacyRouter);
app.use('/v1', exportRouter);

// 全局错误处理（必须最后注册：捕获经 asyncHandler 转交的异步异常，避免连接挂起）
app.use(errorHandler);
