// 账号绑定路由集成测试（轻量 in-process HTTP，无需 supertest）。
// mock 两个外部依赖：exchangeCodeForToken / fetchHuaweiUserProfile（复用现有 huaweiAuth），
// 以及 prisma（避免真实 DB 连接）。覆盖：
//   缺 token → 401；同 unionID 跨账号 → 409；
//   DELETE harmony → 403；DELETE 不存在 provider → 404；
//   正常 bind → list → unbind 路径。
import express from 'express';
import * as http from 'http';
import jwt from 'jsonwebtoken';

import * as huaweiAuth from '../services/huaweiAuth';
import router from './account';
import { env } from '../config/env';
import { CODE } from '../utils/response';

jest.mock('../services/huaweiAuth', () => ({
  exchangeCodeForToken: jest.fn(),
  fetchHuaweiUserProfile: jest.fn(),
}));
// postService / tagService 等不在本路由被引用，仅占位 prisma 即可避免真实 DB 连接。
jest.mock('../prisma', () => ({
  prisma: {
    user: {
      findUnique: jest.fn(),
      findFirst: jest.fn(),
      update: jest.fn(),
    },
    userBinding: {
      findMany: jest.fn(),
      findFirst: jest.fn(),
      findUnique: jest.fn(),
      create: jest.fn(),
      delete: jest.fn(),
    },
  },
}));

import { prisma } from '../prisma';
const mockPrisma = prisma as any;
const mockExchange = huaweiAuth.exchangeCodeForToken as jest.Mock;
const mockFetchUser = huaweiAuth.fetchHuaweiUserProfile as jest.Mock;

const TEST_USER_ID = 1;

// 生成一个经 auth 中间件可验证的合法 Bearer Token
function authHeader(userId: number = TEST_USER_ID): Record<string, string> {
  const token: string = jwt.sign({ userId }, env.jwtSecret);
  return { Authorization: 'Bearer ' + token };
}

let server: http.Server;
let baseUrl: string;

beforeAll((done) => {
  const app = express();
  app.use(express.json());
  app.use('/v1/account', router);
  server = app.listen(0, () => {
    const addr = server.address();
    const port = typeof addr === 'object' && addr ? addr.port : 0;
    baseUrl = `http://127.0.0.1:${port}`;
    done();
  });
});

afterAll((done) => {
  server.close(() => done());
});

beforeEach(() => {
  jest.clearAllMocks();
});

function req(
  method: string,
  path: string,
  body?: unknown,
  headers: Record<string, string> = {},
): Promise<{ status: number; json: any }> {
  return new Promise((resolve, reject) => {
    const data = body ? JSON.stringify(body) : undefined;
    const reqHeaders: Record<string, string> = { 'Content-Type': 'application/json', ...headers };
    const r = http.request(
      `${baseUrl}${path}`,
      { method, headers: reqHeaders },
      (res) => {
        let raw = '';
        res.on('data', (chunk) => (raw += chunk));
        res.on('end', () => {
          try {
            resolve({ status: res.statusCode ?? 0, json: raw ? JSON.parse(raw) : null });
          } catch {
            resolve({ status: res.statusCode ?? 0, json: null });
          }
        });
      },
    );
    r.on('error', reject);
    if (data) r.write(data);
    r.end();
  });
}

describe('GET/POST/DELETE /v1/account/bindings', () => {
  it('缺 Authorization → UNAUTHORIZED(401)', async () => {
    const res = await req('GET', '/v1/account/bindings');
    expect(res.status).toBe(401);
    expect(res.json.code).toBe(CODE.UNAUTHORIZED);
  });

  it('POST 缺 code → BAD_REQUEST(400)', async () => {
    const res = await req('POST', '/v1/account/bindings', { provider: 'huawei' }, authHeader());
    expect(res.status).toBe(400);
    expect(res.json.code).toBe(CODE.BAD_REQUEST);
  });

  it('POST harmony（不允许主动绑定）→ BAD_REQUEST(400)', async () => {
    const res = await req('POST', '/v1/account/bindings', { provider: 'harmony', code: 'C' }, authHeader());
    expect(res.status).toBe(400);
    expect(res.json.code).toBe(CODE.BAD_REQUEST);
  });

  it('同 unionID 已被其他账号占用 → CONFLICT(409)', async () => {
    mockExchange.mockResolvedValue('ACCESS_TOKEN');
    mockFetchUser.mockResolvedValue({ unionID: 'U_DUP' });
    // UserBinding 中已被 userId=2 占用
    mockPrisma.userBinding.findFirst.mockResolvedValue({ userId: 2, provider: 'huawei', externalId: 'U_DUP' });
    mockPrisma.user.findFirst.mockResolvedValue(null);

    const res = await req('POST', '/v1/account/bindings', { provider: 'huawei', code: 'CODE' }, authHeader());

    expect(res.status).toBe(409);
    expect(res.json.code).toBe(CODE.CONFLICT);
    expect(res.json.message).toContain('已关联其他');
    // 占用则不应写表
    expect(mockPrisma.userBinding.create).not.toHaveBeenCalled();
  });

  it('DELETE harmony → FORBIDDEN(403)', async () => {
    const res = await req('DELETE', '/v1/account/bindings/harmony', undefined, authHeader());
    expect(res.status).toBe(403);
    expect(res.json.code).toBe(CODE.FORBIDDEN);
  });

  it('DELETE 不存在的 provider → NOT_FOUND(404)', async () => {
    mockPrisma.userBinding.findUnique.mockResolvedValue(null);
    const res = await req('DELETE', '/v1/account/bindings/wechat', undefined, authHeader());
    expect(res.status).toBe(404);
    expect(res.json.code).toBe(CODE.NOT_FOUND);
  });

  it('正常 bind → list → unbind 路径', async () => {
    // ---- bind ----
    mockExchange.mockResolvedValue('ACCESS_TOKEN');
    mockFetchUser.mockResolvedValue({ unionID: 'U_1' });
    // 占用校验：两处均无他人占用
    mockPrisma.userBinding.findFirst.mockResolvedValue(null);
    mockPrisma.user.findFirst.mockResolvedValue(null);
    mockPrisma.userBinding.create.mockResolvedValue({ boundAt: new Date('2026-07-18T08:00:00Z') });
    mockPrisma.user.update.mockResolvedValue({});

    const bindRes = await req('POST', '/v1/account/bindings', { provider: 'huawei', code: 'CODE' }, authHeader());
    expect(bindRes.status).toBe(200);
    expect(bindRes.json.code).toBe(0);
    expect(bindRes.json.data.provider).toBe('huawei');
    expect(bindRes.json.data.status).toBe('bound');
    expect(bindRes.json.data.externalId).toBe('****' + 'U_1'.slice(-4)); // 脱敏
    expect(mockPrisma.userBinding.create).toHaveBeenCalledTimes(1);
    expect(mockPrisma.user.update).toHaveBeenCalledWith(
      expect.objectContaining({ where: { id: TEST_USER_ID }, data: { unionID: 'U_1' } }),
    );

    // ---- list：harmony 置顶 + huawei 已绑定 ----
    mockPrisma.user.findUnique.mockResolvedValue({
      openId: 'openid1234',
      createdAt: new Date('2026-07-09T08:00:00Z'),
    });
    mockPrisma.userBinding.findMany.mockResolvedValue([
      { provider: 'huawei', externalId: 'U_1', boundAt: new Date('2026-07-18T08:00:00Z'), isPrimary: false },
    ]);
    const listRes = await req('GET', '/v1/account/bindings', undefined, authHeader());
    expect(listRes.status).toBe(200);
    expect(listRes.json.code).toBe(0);
    const items = listRes.json.data as any[];
    expect(items.length).toBe(2);
    expect(items[0].provider).toBe('harmony');
    expect(items[0].isPrimary).toBe(true);
    expect(items[0].status).toBe('primary');
    expect(items[0].externalId).toBe('op****34'); // harmony 保留前2后2
    expect(items[1].provider).toBe('huawei');
    expect(items[1].status).toBe('bound');

    // ---- unbind ----
    mockPrisma.userBinding.findUnique.mockResolvedValue({ userId: TEST_USER_ID, provider: 'huawei' });
    mockPrisma.userBinding.delete.mockResolvedValue({});
    const unbindRes = await req('DELETE', '/v1/account/bindings/huawei', undefined, authHeader());
    expect(unbindRes.status).toBe(200);
    expect(unbindRes.json.code).toBe(0);
    expect(unbindRes.json.data.unbound).toBe(true);
    expect(mockPrisma.userBinding.delete).toHaveBeenCalledTimes(1);
  });
});
