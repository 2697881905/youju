import COS from 'cos-nodejs-sdk-v5';
import { randomUUID } from 'crypto';
import { env } from '../config/env';

// 腾讯云 COS 直传：后端用永久密钥签发「预签名 PUT URL」，前端用该 URL 直传二进制，
// 全程不经过后端转发，省带宽。详见 https://cloud.tencent.com/document/product/436/35217
export interface UploadSignature {
  url: string; // 预签名 PUT URL（前端直传目标）
  key: string; // 对象 Key（存 DB 用）
  cdnUrl: string; // 直传成功后「公开可读」时访问的 URL（有 CDN 则用 CDN，否则与 url 同）
  viewUrl: string; // 直传后「始终可读」的 URL（COS=GET 预签名；本地=静态直链），前端展示与存储一律用这个
  contentType: string; // 前端 PUT 时必须带上的 Content-Type（需与签名一致）
  mode: 'cos' | 'local'; // 上传模式：cos=直传腾讯云；local=直传后端 /v1/upload/local
}

// 是否具备真实可用的 COS 凭据（secretId/secretKey/bucket/region 齐全）
function isCosConfigured(): boolean {
  const { secretId, secretKey, bucket, region } = env.cos;
  return Boolean(secretId && secretKey && bucket && region);
}

// 本地文件存储模式（无真实 COS 时的开发期兜底）：
// 前端直传二进制到后端 PUT /v1/upload/local，后端落盘到 uploads/，返回静态直链。
function localUploadSignature(contentType: string): UploadSignature {
  const ext = contentType.includes('png')
    ? 'png'
    : contentType.includes('webp')
      ? 'webp'
      : contentType.includes('gif')
        ? 'gif'
        : 'jpg';
  const key = `avatars/${randomUUID()}.${ext}`;
  const base = env.backendPublicUrl.replace(/\/$/, '');
  const viewUrl = `${base}/uploads/${key}`;
  return {
    url: `${base}/v1/upload/local?key=${encodeURIComponent(key)}`,
    key,
    cdnUrl: viewUrl,
    viewUrl,
    contentType,
    mode: 'local',
  };
}

// COS 模式：生成 PUT + GET 预签名 URL
function cosUploadSignature(contentType: string): Promise<UploadSignature> {
  const { secretId, secretKey, bucket, region, cdnBase } = env.cos;
  const cos = new COS({ SecretId: secretId, SecretKey: secretKey });

  const now = new Date();
  const y = now.getFullYear();
  const m = String(now.getMonth() + 1).padStart(2, '0');
  const key = `uploads/${y}/${m}/${randomUUID()}`;

  return new Promise<UploadSignature>((resolve, reject) => {
    // 1) 生成 PUT 预签名 URL（前端直传目标）
    const putParams: any = {
      Bucket: bucket,
      Region: region,
      Key: key,
      Method: 'PUT',
      Sign: true,
      Expires: 600,
      Headers: { 'Content-Type': contentType },
    };
    cos.getObjectUrl(putParams, (putErr: any, putData: any) => {
      if (putErr) {
        reject(putErr instanceof Error ? putErr : new Error(JSON.stringify(putErr)));
        return;
      }
      const url: string = putData.Url;
      // 2) 额外生成 GET 预签名 URL（前端展示/存储用，私有桶也能加载）
      const getParams: any = {
        Bucket: bucket,
        Region: region,
        Key: key,
        Method: 'GET',
        Sign: true,
        Expires: 31536000,
      };
      cos.getObjectUrl(getParams, (getErr: any, getData: any) => {
        const viewUrl: string = getErr ? url : getData.Url;
        const base = cdnBase ? cdnBase.replace(/\/$/, '') : '';
        const cdnUrl = base ? `${base}/${key}` : url;
        resolve({ url, key, cdnUrl, viewUrl, contentType, mode: 'cos' });
      });
    });
  });
}

// 生成单张图片的上传签名（默认 image/jpeg）。
// 配置了真实 COS → 返回 COS 预签名 URL；未配置 → 返回本地文件直传签名。
export function getUploadSignature(contentType: string = 'image/jpeg'): Promise<UploadSignature> {
  if (isCosConfigured()) {
    return cosUploadSignature(contentType);
  }
  return Promise.resolve(localUploadSignature(contentType));
}
