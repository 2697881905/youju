import { sign, constants } from 'crypto';
import { readFileSync } from 'fs';
import { prisma } from '../prisma';
import { env } from '../config/env';

// 华为推送服务客户端（Push Kit REST API v3）。
// 设计：凭证缺失时整体降级为 no-op，绝不阻断主流程 —— 通知仍正常落库，只是不弹系统推送。
//
// ⚠️ 协议口径（与旧版 Android HMS Push 完全不同，别混用）：
//   URL     POST https://push-api.cloud.huawei.com/v3/{projectId}/messages:send
//   Header  Authorization: Bearer <服务账号 JWT>   push-type: 0
//   Body    payload.notification / target.token / pushOptions
//   HarmonyOS 5 起已废弃 OAuth 2.0 client_credentials 鉴权，必须使用服务账号 JWT。

// 通知点击后透传给客户端的业务数据（落 want.parameters，客户端据此自行跳转）
export interface PushMessageData {
  type?: string;
  postId?: number | null;
  // 关联评论 id：客户端点推送后定位到具体评论（见前端 utils/push.ets PushRoute）
  commentId?: number | null;
  nid?: number;
}

interface ServiceAccountCreds {
  projectId: string;
  keyId: string;
  privateKey: string;
  subAccount: string;
  tokenUri: string;
}

interface CachedJwt {
  token: string;
  expireAt: number; // 毫秒时间戳
}

const DEFAULT_TOKEN_URI = 'https://oauth-login.cloud.huawei.com/oauth2/v3/token';
// 单次下发最多携带 1000 个 Push Token（超出会被服务端拒绝）
const MAX_TOKENS_PER_SEND = 1000;

// 凭据读取结果缓存：undefined = 尚未读取，null = 读取失败（后续不再重试，避免每次推送都读盘/报错）
let credsCache: ServiceAccountCreds | null | undefined = undefined;
let jwtCache: CachedJwt | null = null;

function base64Url(input: Buffer | string): string {
  const buf: Buffer = typeof input === 'string' ? Buffer.from(input, 'utf8') : input;
  return buf.toString('base64').replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/g, '');
}

// 读取 AGC 服务账号凭据文件。私钥不入库，只走本地文件路径。
function loadCreds(): ServiceAccountCreds | null {
  if (credsCache !== undefined) {
    return credsCache;
  }
  const cfg = env.huaweiPush;
  if (cfg.projectId === '') {
    console.warn('[huaweiPush] HUAWEI_PUSH_PROJECT_ID 未配置，推送降级为 no-op');
    credsCache = null;
    return null;
  }
  try {
    const raw = JSON.parse(readFileSync(cfg.serviceAccountPath, 'utf8')) as Record<string, string>;
    const keyId: string = raw['key_id'] ?? '';
    const privateKey: string = raw['private_key'] ?? '';
    const subAccount: string = raw['sub_account'] ?? '';
    if (keyId === '' || privateKey === '' || subAccount === '') {
      throw new Error('凭据文件缺少 key_id / private_key / sub_account');
    }
    credsCache = {
      projectId: raw['project_id'] || cfg.projectId,
      keyId,
      privateKey,
      subAccount,
      tokenUri: raw['token_uri'] || DEFAULT_TOKEN_URI,
    };
    return credsCache;
  } catch (e) {
    console.warn(`[huaweiPush] 读取服务账号凭据失败（${cfg.serviceAccountPath}）：${(e as Error).message}`);
    credsCache = null;
    return null;
  }
}

// 是否已具备推送条件（供上层判断是否跳过无用调用）
export function isPushConfigured(): boolean {
  return loadCreds() !== null;
}

// 生成服务账号鉴权 JWT：PS256（SHA256withRSA/PSS），Header 带 kid，Payload 带 iss/aud/iat/exp。
// 注意是 PSS 填充而非 PKCS#1 v1.5 —— 用错会在调用 REST API 时返回鉴权失败。
function createJwt(c: ServiceAccountCreds): string {
  const iat: number = Math.floor(Date.now() / 1000);
  const exp: number = iat + 3600;
  const header: string = base64Url(JSON.stringify({ kid: c.keyId, typ: 'JWT', alg: 'PS256' }));
  const payload: string = base64Url(JSON.stringify({ aud: c.tokenUri, iss: c.subAccount, exp, iat }));
  const signingInput: string = `${header}.${payload}`;
  const signature: Buffer = sign('sha256', Buffer.from(signingInput, 'utf8'), {
    key: c.privateKey,
    padding: constants.RSA_PKCS1_PSS_PADDING,
    saltLength: constants.RSA_PSS_SALTLEN_DIGEST,
  });
  return `${signingInput}.${base64Url(signature)}`;
}

// 取可用的 Bearer 令牌（JWT 本身），JWT 有效期 1 小时，缓存至剩余 5 分钟时重建
function getAuthToken(creds: ServiceAccountCreds): string {
  if (jwtCache !== null && jwtCache.expireAt > Date.now()) {
    return jwtCache.token;
  }
  const token: string = createJwt(creds);
  jwtCache = { token, expireAt: Date.now() + 55 * 60 * 1000 };
  return token;
}

// 向一批设备 token 下发通知消息（上限 1000 个，超出由调用方分批）
async function sendToTokens(
  tokens: string[],
  title: string,
  body: string,
  data: PushMessageData,
): Promise<void> {
  const creds: ServiceAccountCreds | null = loadCreds();
  if (creds === null) {
    return;
  }
  const cfg = env.huaweiPush;
  const reqBody = {
    payload: {
      notification: {
        category: resolveCategory(data.type),
        title,
        body,
        clickAction: {
          // actionType 0 = 打开应用首页。业务路由走 data 透传：客户端在
          // UIAbility 的 onCreate / onNewWant 里读 want.parameters 后自行跳转，
          // 无需在 module.json5 配 skills / uris（配错反而点不开）。
          actionType: 0,
          data,
        },
      },
    },
    target: { token: tokens },
    pushOptions: {
      ttl: cfg.ttl,
      // 调测消息：true 时不受「未申请自分类权益的单设备每日 2 条」频控限制。生产务必为 false。
      testMessage: cfg.testMessage,
    },
  };
  const resp = await fetch(`${cfg.apiUrl}/v3/${cfg.projectId}/messages:send`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      Authorization: `Bearer ${getAuthToken(creds)}`,
      'push-type': '0',
    },
    body: JSON.stringify(reqBody),
  });
  if (!resp.ok) {
    const text: string = await resp.text();
    throw new Error(`华为推送下发失败: ${resp.status} ${text}`);
  }
}

// 通知类型 → 华为「通知消息自分类」category。
// ⚠️ 必须与 AGC 已申请并通过的自分类权益逐项对应：传一个未开通的 category 不会报错，
//    华为会静默降级归到资讯营销类（MARKETING，单设备每日 2 条限流），表面看只是"收不到"。
//    项目已申请：SUBSCRIPTION（订阅·社交动态）。评论/赞/收藏/@提及/关注都走这一类。
//    私信申请了 IM，但站内私信目前尚未接推送，确认后再补映射到这里的 'dm'。
//    系统通知（举报受理/审核结果）未申请对应权益，老实退回默认兜底（MARKETING）。
const CATEGORY_BY_NOTIFY_TYPE: Record<string, string> = {
  comment: 'SUBSCRIPTION',
  up: 'SUBSCRIPTION',
  bookmark: 'SUBSCRIPTION',
  mention: 'SUBSCRIPTION',
  follow: 'SUBSCRIPTION',
};

function resolveCategory(notifyType: string | undefined): string {
  return (notifyType !== undefined ? CATEGORY_BY_NOTIFY_TYPE[notifyType] : undefined) ?? env.huaweiPush.category;
}

// token 脱敏后落库，避免 PushLog 里存明文设备地址
function maskToken(token: string): string {
  if (token.length <= 16) {
    return token.substring(0, 6) + '…';
  }
  return token.substring(0, 8) + '…' + token.substring(token.length - 8);
}

// 给某用户的所有设备下发推送（无 token / 未配置时静默返回，失败仅记录不抛出）
// 成功/失败均落 PushLog 审计。
export async function pushToUser(
  userId: number,
  title: string,
  body: string,
  data: PushMessageData = {},
): Promise<void> {
  if (!isPushConfigured()) return;
  try {
    const rows = await prisma.pushToken.findMany({
      where: { userId },
      select: { token: true },
    });
    if (rows.length === 0) return;
    const list: string[] = rows.map((r) => r.token);
    // PushLog.data 是 Json 列：Prisma 的 InputJsonValue 不接受 Record<string, unknown>，
    // 用 JSON 往返得到可赋值的结构（顺带保证落库内容一定可序列化）。
    const logData = JSON.parse(JSON.stringify(data));
    for (let i = 0; i < list.length; i += MAX_TOKENS_PER_SEND) {
      const batch: string[] = list.slice(i, i + MAX_TOKENS_PER_SEND);
      const logRows = batch.map((token) => ({
        userId,
        token: maskToken(token),
        title,
        body,
        data: logData,
        status: 'sent' as string,
        error: null as string | null,
      }));
      try {
        await sendToTokens(batch, title, body, data);
        await prisma.pushLog.createMany({ data: logRows }).catch(() => {});
      } catch (e) {
        const err: string = String((e as Error).message ?? e).slice(0, 500);
        await prisma.pushLog
          .createMany({ data: logRows.map((r) => ({ ...r, status: 'failed', error: err })) })
          .catch(() => {});
      }
    }
  } catch (e) {
    console.warn('[huaweiPush] pushToUser 失败:', (e as Error).message);
  }
}
