import express, { Router, Response, Request } from 'express';
import { ok, fail, internalError, CODE } from '../utils/response';
import { auth, AuthRequest } from '../middleware/auth';
import { getUploadSignature, UploadFolder } from '../services/uploadService';
import { asyncHandler } from '../middleware/asyncHandler';
import path from 'path';
import fs from 'fs';
import { env } from '../config/env';

// 获取上传签名：POST /v1/upload/token
// body: { contentType?: string } 默认 image/jpeg
// 返回 { url, key, mediaRef, viewUrl, contentType }；前端直传后持久化 mediaRef。
// 已配置真实 COS → 返回 COS 预签名 URL；未配置 → 返回本地文件直传签名（PUT /v1/upload/local）。
const router = Router();

router.post('/token', auth, asyncHandler(async (req: AuthRequest, res: Response) => {
  try {
    const contentType =
      typeof req.body?.contentType === 'string' && req.body.contentType
        ? req.body.contentType
        : 'image/jpeg';
    const folder: UploadFolder = req.body?.folder === 'posts'
      ? 'posts'
      : req.body?.folder === 'backgrounds' ? 'backgrounds'
      : req.body?.folder === 'video' ? 'video' : 'avatars';
    const mode: 'auto' | 'local' = req.body?.mode === 'local' ? 'local' : 'auto';
    const size: number | undefined =
      typeof req.body?.size === 'number' && req.body.size > 0 ? req.body.size : undefined;
    if (!isAllowedUpload(contentType, folder)) {
      return fail(res, CODE.BAD_REQUEST, '不支持的文件类型', 400);
    }
    // 服务端兜底：视频体积强校验，防客户端 50MB 拦截被绕过（直传 COS 无法在传输层限制大小）
    if (contentType.startsWith('video/') && size !== undefined && size > env.maxVideoSizeBytes) {
      return fail(
        res,
        CODE.BAD_REQUEST,
        `视频大小不能超过 ${Math.floor(env.maxVideoSizeBytes / 1024 / 1024)}MB`,
        400
      );
    }
    const sig = await getUploadSignature(contentType, folder, mode);
    return ok(res, sig);
  } catch (e) {
    return internalError(res, 'upload.token', e);
  }
}));

// 本地文件直传落地：PUT /v1/upload/local?key=avatars/<uuid>.<ext>
// 仅用于「未配置真实对象存储」的开发期；前端 putBinary 直传二进制，不含鉴权头。
// 经全局 express.json 跳过（Content-Type=image/*），由本路由的 express.raw 接管为 Buffer。
function isValidLocalKey(key: string): boolean {
  if (!/^(avatars|backgrounds|posts|videos)\//.test(key)) return false;
  if (key.includes('..') || key.startsWith('/') || key.includes('\\')) return false;
  return /^[A-Za-z0-9_./-]+$/.test(key);
}

const ALLOWED_UPLOAD_TYPES = ['image/jpeg', 'image/png', 'image/webp', 'image/gif', 'video/mp4'];

export function isAllowedUpload(contentType: string, folder: UploadFolder): boolean {
  return folder === 'video'
    ? contentType === 'video/mp4'
    : contentType !== 'video/mp4' && ALLOWED_UPLOAD_TYPES.includes(contentType);
}

// 本地文件直传落地仅用于「未配置真实对象存储」的开发期（前端 local 模式直传二进制）。
// 生产环境匿名可达该路由存在存储滥用/DoS 风险，故生产不挂载此路由（生产走 COS 预签名直传）。
if (!env.isProduction) {
  router.put(
    '/local',
    express.raw({ type: () => true, limit: '10mb' }),
    (req: Request, res: Response) => {
      const key = typeof req.query.key === 'string' ? req.query.key : '';
      if (!isValidLocalKey(key)) {
        return fail(res, CODE.BAD_REQUEST, '非法的上传 key');
      }
      const ct = (req.headers['content-type'] ?? 'image/jpeg').toString();
      const folder: UploadFolder = key.startsWith('video/') || key.startsWith('videos/') ? 'video' : 'avatars';
      if (!isAllowedUpload(ct, folder)) {
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
}

export default router;
