// 华为账号登录服务端封装的单元测试。
// 通过 mock 全局 fetch 覆盖 token 端点 / getInfo 端点的各种返回（成功 / 非 200 / 缺字段 / 含 error）。
// 无外部依赖（不连真实华为、不连 DB）。

// 在导入被测模块前准备全局 fetch 的 mock。
// 注意：ES import 会被提升，但 huaweiAuth 仅在函数体内调用 fetch，
// 因此本模块顶层把 global.fetch 指向 jest mock 后，调用时即可命中。
const mockFetch = jest.fn();
(global as unknown as { fetch: jest.Mock }).fetch = mockFetch;

import { exchangeCodeForToken, fetchHuaweiUserProfile } from './huaweiAuth';

// 构造一个类 Response 的 mock 对象（被测代码只用 .ok / .status / .text()）。
function makeResponse(
  ok: boolean,
  status: number,
  body: string,
): { ok: boolean; status: number; text: () => Promise<string> } {
  return {
    ok,
    status,
    text: async () => body,
  };
}

beforeEach(() => {
  mockFetch.mockReset();
});

describe('exchangeCodeForToken', () => {
  it('a) token 端点 200 + 合法 JSON 含 access_token → 返回该 token', async () => {
    mockFetch.mockResolvedValue(
      makeResponse(true, 200, JSON.stringify({ access_token: 'TOKEN_123', token_type: 'Bearer' })),
    );

    const token = await exchangeCodeForToken('auth_code_xyz');

    expect(token).toBe('TOKEN_123');
    expect(mockFetch).toHaveBeenCalledTimes(1);
    const [url, opts] = mockFetch.mock.calls[0];
    expect(String(url)).toContain('oauth-login.cloud.huawei.com');
    expect(opts.method).toBe('POST');
    expect(String(opts.body)).toContain('grant_type=authorization_code');
  });

  it('b) token 端点返回非 200 → 抛错', async () => {
    mockFetch.mockResolvedValue(makeResponse(false, 400, 'bad request'));
    await expect(exchangeCodeForToken('x')).rejects.toThrow();
  });

  it('c) token 端点 200 但 JSON 含 error 字段 → 抛错', async () => {
    mockFetch.mockResolvedValue(
      makeResponse(true, 200, JSON.stringify({ error: 'invalid_grant', error_description: 'bad' })),
    );
    await expect(exchangeCodeForToken('x')).rejects.toThrow(/错误|OAuth/);
  });

  it('d) token 端点 200 但缺 access_token → 抛错', async () => {
    mockFetch.mockResolvedValue(makeResponse(true, 200, JSON.stringify({ token_type: 'Bearer' })));
    await expect(exchangeCodeForToken('x')).rejects.toThrow(/access_token/);
  });
});

describe('fetchHuaweiUserProfile', () => {
  it('e) getInfo 端点 200 + 含 unionID → 返回 {unionID,...}', async () => {
    mockFetch.mockResolvedValue(
      makeResponse(
        true,
        200,
        JSON.stringify({ unionID: 'U_001', nickName: '小明', avatarUri: 'http://a.png' }),
      ),
    );

    const profile = await fetchHuaweiUserProfile('TOKEN_123');

    expect(profile.unionID).toBe('U_001');
    expect(profile.nickName).toBe('小明');
    expect(profile.avatarUri).toBe('http://a.png');

    const [url, opts] = mockFetch.mock.calls[0];
    expect(String(url)).toContain('account.cloud.huawei.com');
    expect(opts.method).toBe('GET');
    expect(opts.headers.Authorization).toBe('Bearer TOKEN_123');
  });

  it('f) getInfo 端点 200 但缺 unionID → 抛错', async () => {
    mockFetch.mockResolvedValue(makeResponse(true, 200, JSON.stringify({ nickName: '小明' })));
    await expect(fetchHuaweiUserProfile('TOKEN_123')).rejects.toThrow(/unionID/);
  });

  it('g) getInfo 端点非 200 → 抛错', async () => {
    mockFetch.mockResolvedValue(makeResponse(false, 401, 'unauthorized'));
    await expect(fetchHuaweiUserProfile('TOKEN_123')).rejects.toThrow();
  });
});
