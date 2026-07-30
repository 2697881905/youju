import { prisma } from '../prisma';
import { env } from '../config/env';

// 华为推送服务客户端（Push Kit）。
// 设计：凭证缺失时整体降级为 no-op，绝不阻断主流程 —— 通知仍正常落库，只是不弹系统推送。
// 真实设备推送需在 AGC 开启「推送服务」并配置对应应用 APP ID / APP SECRET（见 env.huaweiPush）。

interface CachedToken {
  token: string;
  expireAt: number; // 毫秒时间戳
}

let cachedToken: CachedToken | null = null;

// 是否已配置推送凭证（前端调用前可据此跳过注册）
export function isPushConfigured(): boolean {
  return env.huaweiPush.appId !== '' && env.huaweiPush.appSecret !== '';
}

// 获取华为推送 access_token（client_credentials），内存缓存至过期前 5 分钟
async function getAccessToken(): Promise<string> {
  const now = Date.now();
  if (cachedToken && cachedToken.expireAt > now) {
    return cachedToken.token;
  }
  const { appId, appSecret, tokenUrl } = env.huaweiPush;
  const body = new URLSearchParams({
    grant_type: 'client_credentials',
    client_id: appId,
    client_secret: appSecret,
  });
  const resp = await fetch(tokenUrl, {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: body.toString(),
  });
  if (!resp.ok) {
    throw new Error(`华为推送鉴权失败: ${resp.status}`);
  }
  const data = (await resp.json()) as { access_token?: string; expires_in?: number };
  if (!data.access_token) {
    throw new Error('华为推送鉴权返回无 access_token');
  }
  // expires_in 单位秒，提前 5 分钟过期以留余量
  const ttl = (data.expires_in ?? 3600) * 1000 - 5 * 60 * 1000;
  cachedToken = { token: data.access_token, expireAt: now + ttl };
  return data.access_token;
}

// 向一组设备 token 下发通知（单次上限 1000 个，超出由调用方分批）
async function sendToTokens(tokens: string[], title: string, body: string): Promise<void> {
  const { appId, apiUrl } = env.huaweiPush;
  const accessToken = await getAccessToken();
  const payload = {
    validate_only: false,
    message: {
      token: tokens,
      notification: { title, body },
      android: {
        notification: {
          // type=1：点击通知打开应用（AGC 可进一步配置 deepLink 直达具体页）
          click_action: { type: 1 },
        },
      },
    },
  };
  const resp = await fetch(`${apiUrl}/v1/${appId}/messages:send`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      Authorization: `Bearer ${accessToken}`,
    },
    body: JSON.stringify(payload),
  });
  if (!resp.ok) {
    const text = await resp.text();
    throw new Error(`华为推送下发失败: ${resp.status} ${text}`);
  }
}

// 给某用户的所有设备下发推送（无 token / 未配置时静默返回，失败仅记录不抛出）
export async function pushToUser(userId: number, title: string, body: string): Promise<void> {
  if (!isPushConfigured()) return;
  try {
    const rows = await prisma.pushToken.findMany({
      where: { userId },
      select: { token: true },
    });
    if (rows.length === 0) return;
    const list = rows.map((r) => r.token);
    for (let i = 0; i < list.length; i += 1000) {
      await sendToTokens(list.slice(i, i + 1000), title, body);
    }
  } catch (e) {
    console.warn('[huaweiPush] pushToUser 失败:', (e as Error).message);
  }
}
