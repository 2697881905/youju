import express, { Router, Response, Request } from 'express';
import { ok, fail, CODE } from '../utils/response';
import { auth, AuthRequest } from '../middleware/auth';
import { getUploadSignature } from '../services/uploadService';
import { asyncHandler } from '../middleware/asyncHandler';
import path from 'path';
import fs from 'fs';
import { env } from '../config/env';

// 获取上传签名：POST /v1/upload/token
// body: { contentType?: string } 默认 image/jpeg
// 返回 { url, key, cdnUrl, viewUrl, contentType } 供前端直传。
// 已配置真实 COS → 返回 COS 预签名 URL；未配置 → 返回本地文件直传签名（PUT /v1/upload/local）。
const router = Router();

router.post('/token', auth, asyncHandler(async (req: AuthRequest, res: Response) => {
  try {
    const contentType =
      typeof req.body?.contentType === 'string' && req.body.contentType
        ? req.body.contentType
        : 'image/jpeg';
    const sig = await getUploadSignature(contentType);
    return ok(res, sig);
  } catch (e) {
    const msg = e instanceof Error ? e.message : String(e);
    return fail(res, CODE.BAD_REQUEST, msg, 400);
  }
}));

// 本地文件直传落地：PUT /v1/upload/local?key=avatars/<uuid>.<ext>
// 仅用于「未配置真实对象存储」的开发期；前端 putBinary 直传二进制，不含鉴权头。
// 经全局 express.json 跳过（Content-Type=image/*），由本路由的 express.raw 接管为 Buffer。
function isValidLocalKey(key: string): boolean {
  if (!/^(avatars|posts)\//.test(key)) return false;
  if (key.includes('..') || key.startsWith('/') || key.includes('\\')) return false;
  return /^[A-Za-z0-9_./-]+$/.test(key);
}

const ALLOWED_LOCAL_TYPES = ['image/jpeg', 'image/png', 'image/webp', 'image/gif'];

router.put(
  '/local',
  express.raw({ type: () => true, limit: '10mb' }),
  (req: Request, res: Response) => {
    const key = typeof req.query.key === 'string' ? req.query.key : '';
    if (!isValidLocalKey(key)) {
      return fail(res, CODE.BAD_REQUEST, '非法的上传 key');
    }
    const ct = (req.headers['content-type'] ?? 'image/jpeg').toString();
    if (!ALLOWED_LOCAL_TYPES.includes(ct)) {
      return fail(res, CODE.BAD_REQUEST, '不支持的文件类型');
    }
    if (!Buffer.isBuffer(req.body) || (req.body as Buffer).length === 0) {
      return fail(res, CODE.BAD_REQUEST, '空文件');
    }
    const dest = path.join(env.uploadsDir, key);
    try {
      fs.mkdirSync(path.dirname(dest), { recursive: true });
      fs.writeFileSync(dest, req.body as Buffer);
    } catch (e) {
      return fail(res, CODE.SERVER_ERROR, '保存失败', 500);
    }
    return ok(res, { key, viewUrl: `${env.backendPublicUrl.replace(/\/$/, '')}/uploads/${key}` });
  }
);

export default router;
