import COS from 'cos-nodejs-sdk-v5';
import { randomUUID } from 'crypto';
import { env } from '../config/env';

// 腾讯云 COS 直传：后端用永久密钥签发「预签名 PUT URL」，前端用该 URL 直传二进制，
// 全程不经过后端转发，省带宽。详见 https://cloud.tencent.com/document/product/436/35217
export interface UploadSignature {
  url: string; // 预签名 PUT URL（前端直传目标）
  key: string; // 对象 Key（存 DB 用）
  mediaRef: string; // COS 持久化引用（cos://<key>）；local 模式为静态 URL
  cdnUrl: string; // 兼容字段：仅供直传调试，不允许写入业务表
  viewUrl: string; // 上传完成后的短时预览 URL（COS=GET 预签名；local=静态直链）
  contentType: string; // 前端 PUT 时必须带上的 Content-Type（需与签名一致）
  mode: 'cos' | 'local'; // 上传模式：cos=直传腾讯云；local=直传后端 /v1/upload/local
}

export type UploadFolder = 'avatars' | 'backgrounds' | 'posts' | 'video';

const COS_MEDIA_REF_PREFIX = 'cos://';
const COS_VIEW_URL_EXPIRES_SECONDS = 300;

export function toStoredMediaRef(signature: UploadSignature): string {
  return signature.mediaRef;
}

export function isCosMediaRef(value: string): boolean {
  return value.startsWith(COS_MEDIA_REF_PREFIX) && isValidMediaKey(value.slice(COS_MEDIA_REF_PREFIX.length));
}

export function mediaKeyFromRef(value: string): string | null {
  return isCosMediaRef(value) ? value.slice(COS_MEDIA_REF_PREFIX.length) : null;
}

export function isValidMediaKey(key: string): boolean {
  return /^(avatars|backgrounds|posts|video)\/[A-Za-z0-9_./-]+$/.test(key) &&
    !key.includes('..') && !key.includes('\\');
}

// 是否具备真实可用的 COS 凭据（secretId/secretKey/bucket/region 齐全）
export function isCosConfigured(): boolean {
  const { secretId, secretKey, bucket, region } = env.cos;
  return Boolean(secretId && secretKey && bucket && region);
}

// 本地文件存储模式（无真实 COS 时的开发期兜底）：
// 前端直传二进制到后端 PUT /v1/upload/local，后端落盘到 uploads/，返回静态直链。
function localUploadSignature(contentType: string, folder: UploadFolder): UploadSignature {
  const ext = contentType.includes('png')
    ? 'png'
    : contentType.includes('webp')
      ? 'webp'
      : contentType.includes('gif')
        ? 'gif'
        : 'jpg';
  const key = `${folder}/${randomUUID()}.${ext}`;
  const base = env.backendPublicUrl.replace(/\/$/, '');
  const viewUrl = `${base}/uploads/${key}`;
  return {
    url: `${base}/v1/upload/local?key=${encodeURIComponent(key)}`,
    key,
    mediaRef: viewUrl,
    cdnUrl: viewUrl,
    viewUrl,
    contentType,
    mode: 'local',
  };
}

function createCosClient(): COS {
  const { secretId, secretKey } = env.cos;
  return new COS({ SecretId: secretId, SecretKey: secretKey });
}

// COS 模式：生成 PUT + GET 预签名 URL
function cosUploadSignature(contentType: string, folder: UploadFolder): Promise<UploadSignature> {
  const { bucket, region, cdnBase } = env.cos;
  const cos = createCosClient();

  const now = new Date();
  const y = now.getFullYear();
  const m = String(now.getMonth() + 1).padStart(2, '0');
    const key = `${folder}/${y}/${m}/${randomUUID()}`;

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
      // 2) 仅供上传完成后的即时预览使用的短时 GET URL。
      // 业务表必须保存 mediaRef，后续展示经 /v1/media 动态签发。
      const getParams: any = {
        Bucket: bucket,
        Region: region,
        Key: key,
        Method: 'GET',
        Sign: true,
        Expires: COS_VIEW_URL_EXPIRES_SECONDS,
      };
      cos.getObjectUrl(getParams, (getErr: any, getData: any) => {
        const viewUrl: string = getErr ? url : getData.Url;
        const base = cdnBase ? cdnBase.replace(/\/$/, '') : '';
        const cdnUrl = base ? `${base}/${key}` : url;
        resolve({
          url,
          key,
          mediaRef: COS_MEDIA_REF_PREFIX + key,
          cdnUrl,
          viewUrl,
          contentType,
          mode: 'cos',
        });
      });
    });
  });
}

export function getCosViewUrl(key: string): string {
  if (!isCosConfigured() || !isValidMediaKey(key)) {
    throw new Error('COS 媒体读取配置无效');
  }
  const { bucket, region } = env.cos;
  return createCosClient().getObjectUrl({
    Bucket: bucket,
    Region: region,
    Key: key,
    Method: 'GET',
    Sign: true,
    Expires: COS_VIEW_URL_EXPIRES_SECONDS,
  });
}

export async function deleteCosObjects(keys: string[]): Promise<void> {
  const uniqueKeys = Array.from(new Set(keys.filter((key) => isValidMediaKey(key))));
  if (uniqueKeys.length === 0) {
    return;
  }
  if (!isCosConfigured()) {
    throw new Error('COS 未配置，无法清理媒体对象');
  }
  const { bucket, region } = env.cos;
  const cos = createCosClient();
  for (let start = 0; start < uniqueKeys.length; start += 1000) {
    const objects = uniqueKeys.slice(start, start + 1000).map((Key) => ({ Key }));
    await cos.deleteMultipleObject({ Bucket: bucket, Region: region, Objects: objects, Quiet: true });
  }
}

// 生成单张图片的上传签名（默认 image/jpeg）。
// 配置了真实 COS → 返回 COS 预签名 URL；未配置 → 返回本地文件直传签名。
export function getUploadSignature(
  contentType: string = 'image/jpeg',
  folder: UploadFolder = 'avatars',
  mode: 'auto' | 'local' = 'auto',
): Promise<UploadSignature> {
  // 视频体积大，本地模式 10MB 限制与本地写盘均不适用，强制走 COS 预签名（即便 debug 也如此）。
  if (folder === 'video') {
    if (!isCosConfigured()) {
      return Promise.reject(new Error('视频上传需要配置真实 COS 存储（未检测到 COS 凭据）'));
    }
    return cosUploadSignature(contentType, folder);
  }
  // 调试包通过 hdc rport 访问本机服务，不能依赖模拟器对外部 COS 的 IPv6/HTTPS 直连。
  if (mode === 'local') {
    return Promise.resolve(localUploadSignature(contentType, folder));
  }
  if (isCosConfigured()) {
    return cosUploadSignature(contentType, folder);
  }
  return Promise.resolve(localUploadSignature(contentType, folder));
}
