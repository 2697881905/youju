// 华为账号登录（Account Kit）服务端封装。
// 使用 Node v22 原生 fetch，零新增依赖。
// 流程：前端用 LoginWithHuaweiIDButton 拿到 Authorization Code
//  -> exchangeCodeForToken 换取 access_token
//  -> fetchHuaweiUserProfile 用 access_token 拉取 UnionID / 昵称 / 头像
// 任何一步失败都向上抛出 Error，由路由 catch 后统一转 480。

const HUAWEI_TOKEN_URL = 'https://oauth-login.cloud.huawei.com/oauth2/v3/token';
const HUAWEI_USERINFO_URL = 'https://account.cloud.huawei.com/rest.php?nsp_svc=GOpen.User.getInfo';

interface HuaweiTokenResponse {
  access_token: string;
  expires_in?: number;
  refresh_token?: string;
  token_type?: string;
  error?: string;
  error_description?: string;
}

interface HuaweiUserProfile {
  unionID: string;
  nickName?: string;
  avatarUri?: string;
}

/**
 * 用 Authorization Code 向华为 OAuth 服务换取 access_token。
 * @param code 前端 LoginWithHuaweiIDButton 回调拿到的 authorization_code
 * @returns access_token 字符串
 * @throws 网络异常 / 华为返回错误 / 缺少 access_token 时抛出 Error
 */
export async function exchangeCodeForToken(code: string): Promise<string> {
  const clientId: string = process.env.HUAWEI_CLIENT_ID ?? '';
  const clientSecret: string = process.env.HUAWEI_CLIENT_SECRET ?? '';
  const redirectUri: string = process.env.HUAWEI_REDIRECT_URI ?? '';

  const body = new URLSearchParams();
  body.set('grant_type', 'authorization_code');
  body.set('client_id', clientId);
  body.set('client_secret', clientSecret);
  body.set('code', code);
  body.set('redirect_uri', redirectUri);

  const resp = await fetch(HUAWEI_TOKEN_URL, {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: body.toString(),
  });

  const text: string = await resp.text();
  if (!resp.ok) {
    throw new Error('华为换取 access_token 失败: HTTP ' + resp.status + ' ' + text);
  }

  let data: HuaweiTokenResponse;
  try {
    data = JSON.parse(text) as HuaweiTokenResponse;
  } catch (e) {
    throw new Error('华为返回 access_token 响应无法解析: ' + text);
  }

  if (data.error) {
    throw new Error('华为 OAuth 错误: ' + data.error + ' ' + (data.error_description ?? ''));
  }
  if (!data.access_token) {
    throw new Error('华为返回结果缺少 access_token');
  }
  return data.access_token;
}

/**
 * 用 access_token 拉取华为账号用户信息（UnionID / 昵称 / 头像）。
 * @param accessToken exchangeCodeForToken 返回的 access_token
 * @returns 含 unionID 的用户资料
 * @throws 网络异常 / 缺少 unionID 时抛出 Error
 */
export async function fetchHuaweiUserProfile(accessToken: string): Promise<HuaweiUserProfile> {
  const resp = await fetch(HUAWEI_USERINFO_URL, {
    method: 'GET',
    headers: { Authorization: 'Bearer ' + accessToken },
  });

  const text: string = await resp.text();
  if (!resp.ok) {
    throw new Error('获取华为用户信息失败: HTTP ' + resp.status + ' ' + text);
  }

  let data: HuaweiUserProfile;
  try {
    data = JSON.parse(text) as HuaweiUserProfile;
  } catch (e) {
    throw new Error('华为返回用户信息响应无法解析: ' + text);
  }

  if (!data.unionID) {
    throw new Error('华为用户信息缺少 unionID');
  }
  return data;
}
