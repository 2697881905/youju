// 媒体引用白名单：业务表里的媒体字段（帖图/封面/视频/私信媒体/资料背景）只接受
// 「本系统上传体系」产出的引用——COS 直传引用（cos://<key>，客户端 toStoredMediaRef
// 落库的规范形态）与本地调试上传（/uploads/...，无真实 COS 时的开发期兜底）。
//
// 为什么必须白名单：这些字段会被其他用户的客户端 Image 组件**自动 GET**（无需点击），
// 任意外链 = 跟踪打点（收集浏览者 IP/UA/时间）+ 强制请求 + 钓鱼图注入。
// 只信「本系统上传体系」产出的引用，外链一律拒绝。
//
// 历史数据兼容：只约束**写路径**（新写入），存量行读路径零变化。本地模式历史上落库过
// 带主机名的绝对 URL（如 http://192.168.x.x/uploads/..），写入时归一化为 /uploads/
// 相对路径；客户端 resolveDisplayImageUrl 对相对路径统一重写回 BASE_URL。

import { isValidMediaKey } from '../services/uploadService';

const COS_MEDIA_REF_PREFIX = 'cos://';
// 本地调试上传的静态直链路径（localUploadSignature 落点，uploadService 落盘 uploads/）
const UPLOADS_PATH_PATTERN = /^\/uploads\/[A-Za-z0-9._/-]+$/;
// 本地模式带主机的绝对 URL 只可能来自开发期后端（localhost / 局域网 IP，与
// rateLimit.isPrivateOrLocalIp 同一口径）；公网主机的 /uploads/ 路径 = 伪造外链，拒绝
const ABSOLUTE_UPLOADS_PATTERN =
  /^https?:\/\/(localhost|127\.0\.0\.1|10\.\d+\.\d+\.\d+|172\.(1[6-9]|2\d|3[01])\.\d+\.\d+|192\.168\.\d+\.\d+)(:\d+)?(\/uploads\/[A-Za-z0-9._/-]+)$/;

export interface MediaRefNormalizeResult {
  ok: boolean;
  // 归一化后的存储值（ok=true 时有效）：cos:// 引用原样保留；带主机的 /uploads/ 绝对
  // URL 归一化为相对路径（主机随环境漂移，不应进库）
  ref: string;
}

// 归一化 + 校验一个媒体引用输入。任何不认识的形态（外链、data:、javascript:、
// 路径穿越）返回 ok=false，调用方决定拒绝或剥离。
export function normalizeMediaRefInput(raw: unknown): MediaRefNormalizeResult {
  const fail: MediaRefNormalizeResult = { ok: false, ref: '' };
  if (typeof raw !== 'string') {
    return fail;
  }
  const v: string = raw.trim();
  if (v.length === 0 || v.length > 512) {
    return fail;
  }
  // COS 直传引用：key 必须过 uploadService 的目录白名单 + 防穿越校验
  if (v.startsWith(COS_MEDIA_REF_PREFIX)) {
    const key: string = v.slice(COS_MEDIA_REF_PREFIX.length);
    return isValidMediaKey(key) ? { ok: true, ref: v } : fail;
  }
  // 带主机的绝对 /uploads/ URL（本地模式历史形态，主机限 localhost/局域网）→ 归一化为相对路径
  const absolute: RegExpMatchArray | null = v.match(ABSOLUTE_UPLOADS_PATTERN);
  if (absolute !== null) {
    // 字符集允许「..」，显式排除路径穿越
    return absolute[4].includes('..') ? fail : { ok: true, ref: absolute[4] };
  }
  // 相对 /uploads/ 路径
  if (v.startsWith('/uploads/') && !v.includes('..')) {
    return UPLOADS_PATH_PATTERN.test(v) ? { ok: true, ref: v } : fail;
  }
  return fail;
}
