import { Router, Response } from 'express';
import { ok, fail } from '../utils/response';
import { auth, AuthRequest } from '../middleware/auth';
import { getUploadSignature } from '../services/uploadService';

// 获取上传签名：POST /v1/upload/token
// body: { contentType?: string } 默认 image/jpeg
// 返回 { url, key, cdnUrl, viewUrl, contentType } 供前端直传 COS
// viewUrl 为 GET 预签名可读链接（私有桶也能加载），前端展示与存储一律用 viewUrl。
import { asyncHandler } from '../middleware/asyncHandler';

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
    return fail(res, 400, msg, 400);
  }
}));

export default router;
