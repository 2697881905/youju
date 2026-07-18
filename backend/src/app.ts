import express from 'express';
import cors from 'cors';
import authRouter from './routes/auth';
import postRouter from './routes/posts';
import commentRouter from './routes/comments';
import interactRouter from './routes/interact';
import tagRouter from './routes/tags';
import uploadRouter from './routes/upload';
import searchRouter from './routes/search';
import accountRouter from './routes/account';

export const app = express();

app.use(cors());
app.use(express.json());

app.get('/health', (_req, res) => res.json({ ok: true }));

// 同时挂 /v1/auth 与 /v1/users，覆盖文档两类路径
app.use('/v1/auth', authRouter);
app.use('/v1/users', authRouter);
app.use('/v1/posts', postRouter);
app.use('/v1/tags', tagRouter);
app.use('/v1/upload', uploadRouter);
app.use('/v1/search', searchRouter);
// 账号绑定管理（GET/POST/DELETE /v1/account/bindings），与 /v1/auth、/v1/posts 同级
app.use('/v1/account', accountRouter);
// 评论/互动使用完整路径（/v1/posts/:id/comments、/v1/posts/:id/up 等）
app.use('/v1', commentRouter);
app.use('/v1', interactRouter);
