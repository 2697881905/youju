import COS from 'cos-nodejs-sdk-v5';
import { randomUUID } from 'crypto';
import { env } from '../config/env';

// 腾讯云 COS 直传：后端用永久密钥签发「预签名 PUT URL」，前端用该 URL 直传二进制，
// 全程不经过后端转发，省带宽。详见 https://cloud.tencent.com/document/product/436/35217
export interface UploadSignature {
  url: string; // 预签名 PUT URL（前端直传目标）
  key: string; // 对象 Key（存 DB 用）
  cdnUrl: string; // 直传成功后「公开可读」时访问的 URL（有 CDN 则用 CDN，否则与 url 同）
  viewUrl: string; // 直传后「始终可读」的 GET 预签名 URL（私有桶/未配 CDN 也能加载，前端展示与存储一律用这个）
  contentType: string; // 前端 PUT 时必须带上的 Content-Type（需与签名一致）
}

function assertCosConfigured(): void {
  const { secretId, secretKey, bucket, region } = env.cos;
  if (!secretId || !secretKey) {
    throw new Error('COS 未配置：请在 backend/.env 填写 COS_SECRET_ID 与 COS_SECRET_KEY');
  }
  if (!bucket || !region) {
    throw new Error('COS 未配置：请在 backend/.env 填写 COS_BUCKET 与 COS_REGION');
  }
}

// 生成单张图片的预签名 PUT URL（默认按 jpeg 签名 Content-Type）
export function getUploadSignature(contentType: string = 'image/jpeg'): Promise<UploadSignature> {
  assertCosConfigured();
  const { secretId, secretKey, bucket, region, cdnBase } = env.cos;
  const cos = new COS({ SecretId: secretId, SecretKey: secretKey });

  const now = new Date();
  const y = now.getFullYear();
  const m = String(now.getMonth() + 1).padStart(2, '0');
  const key = `uploads/${y}/${m}/${randomUUID()}`;

  return new Promise<UploadSignature>((resolve, reject) => {
    // 1) 生成 PUT 预签名 URL（前端直传目标）
    // params 转 any：cos-nodejs-sdk-v5 的类型定义未必暴露 Headers，但运行时支持把 Content-Type 纳入签名
    const putParams: any = {
      Bucket: bucket,
      Region: region,
      Key: key,
      Method: 'PUT',
      Sign: true,
      Expires: 600,
      // 把 Content-Type 纳入签名：前端 PUT 时务必带上完全相同的 Content-Type
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
        Expires: 31536000, // 1 年，作为用户头像/封面等长期可读链接
      };
      cos.getObjectUrl(getParams, (getErr: any, getData: any) => {
        // GET 签名兜底：极端情况下失败则回退到 cdnUrl（公开可读时才生效）
        const viewUrl: string = getErr ? url : getData.Url;
        const base = cdnBase ? cdnBase.replace(/\/$/, '') : '';
        const cdnUrl = base ? `${base}/${key}` : url;
        resolve({ url, key, cdnUrl, viewUrl, contentType });
      });
    });
  });
}
