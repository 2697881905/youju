// 账号绑定路由集成测试（轻量 in-process HTTP，无需 supertest）。
// mock prisma（避免真实 DB 连接）。覆盖当前契约（v1 单一登录方式 = 华为账号）：
//   缺 token → 401；POST huawei → 400（登录即绑定，无需重复绑定）；
//   GET list → 华为主账号置顶且脱敏、跳过 UserBinding 里的 huawei 重复行；
//   DELETE huawei → 403（解绑即丢失登录能力）；DELETE 不存在 provider → 404；
//   DELETE wechat 已绑定 → 200 且只删行、不碰 User.unionID。
import express from 'express';
import * as http from 'http';
import jwt from 'jsonwebtoken';

import router from './account';
import { env } from '../config/env';
import { CODE } from '../utils/response';

// 本路由不再经华为换 token（v1 无主动绑定），仅占位 prisma 避免真实 DB 连接。
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
    $transaction: jest.fn().mockImplementation((ops: any) => Promise.all(ops ?? [])),
  },
}));

import { prisma } from '../prisma';
const mockPrisma = prisma as any;

const TEST_USER_ID = 1;
const TEST_UNION_ID = 'U_ABCDEFG';
const CREATED_AT = new Date('2026-07-09T08:00:00Z');

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
  // auth 中间件与 listBindings 共用同一 stub：字段取并集
  mockPrisma.user.findUnique.mockResolvedValue({
    id: TEST_USER_ID,
    deletedAt: null,
    unionID: TEST_UNION_ID,
    openId: null,
    createdAt: CREATED_AT,
  });
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

  it('POST huawei（登录即绑定，不允许主动绑定）→ BAD_REQUEST(400)', async () => {
    const res = await req('POST', '/v1/account/bindings', { provider: 'huawei', code: 'CODE' }, authHeader());
    expect(res.status).toBe(400);
    expect(res.json.code).toBe(CODE.BAD_REQUEST);
    expect(res.json.message).toContain('无需重复绑定');
    // 拒绝时不得写 UserBinding，也不得改动 User.unionID（防串号）
    expect(mockPrisma.userBinding.create).not.toHaveBeenCalled();
    expect(mockPrisma.user.update).not.toHaveBeenCalled();
  });

  it('POST 未知 provider → BAD_REQUEST(400)', async () => {
    const res = await req('POST', '/v1/account/bindings', { provider: 'harmony', code: 'C' }, authHeader());
    expect(res.status).toBe(400);
    expect(res.json.code).toBe(CODE.BAD_REQUEST);
  });

  it('GET list → 华为主账号置顶 + 跳过 UserBinding 里的 huawei 重复行', async () => {
    mockPrisma.userBinding.findMany.mockResolvedValue([
      { provider: 'huawei', externalId: TEST_UNION_ID, boundAt: new Date('2026-07-18T08:00:00Z'), isPrimary: false },
      { provider: 'wechat', externalId: 'WX_OPENID_9', boundAt: new Date('2026-07-20T08:00:00Z'), isPrimary: false },
    ]);

    const res = await req('GET', '/v1/account/bindings', undefined, authHeader());
    expect(res.status).toBe(200);
    expect(res.json.code).toBe(0);

    const items = res.json.data as any[];
    expect(items.length).toBe(2); // huawei 主账号 + wechat；huawei 表行被跳过
    expect(items[0].provider).toBe('huawei');
    expect(items[0].isPrimary).toBe(true);
    expect(items[0].status).toBe('primary');
    expect(items[0].displayName).toBe('华为账号');
    expect(items[0].externalId).toBe('****' + TEST_UNION_ID.slice(-4)); // 脱敏末 4 位
    expect(items[1].provider).toBe('wechat');
    expect(items[1].status).toBe('bound');
  });

  it('DELETE huawei（主账号/登录方式）→ FORBIDDEN(403)', async () => {
    const res = await req('DELETE', '/v1/account/bindings/huawei', undefined, authHeader());
    expect(res.status).toBe(403);
    expect(res.json.code).toBe(CODE.FORBIDDEN);
    // 绝不允许把 User.unionID 置空（否则用户永久失去登录能力）
    expect(mockPrisma.user.update).not.toHaveBeenCalled();
    expect(mockPrisma.userBinding.delete).not.toHaveBeenCalled();
  });

  it('DELETE 不存在的 provider → NOT_FOUND(404)', async () => {
    mockPrisma.userBinding.findUnique.mockResolvedValue(null);
    const res = await req('DELETE', '/v1/account/bindings/wechat', undefined, authHeader());
    expect(res.status).toBe(404);
    expect(res.json.code).toBe(CODE.NOT_FOUND);
  });

  it('DELETE wechat 已绑定 → 200 且只删行、不动 User.unionID', async () => {
    mockPrisma.userBinding.findUnique.mockResolvedValue({ userId: TEST_USER_ID, provider: 'wechat' });
    mockPrisma.userBinding.delete.mockResolvedValue({});

    const res = await req('DELETE', '/v1/account/bindings/wechat', undefined, authHeader());
    expect(res.status).toBe(200);
    expect(res.json.code).toBe(0);
    expect(res.json.data.unbound).toBe(true);
    expect(mockPrisma.userBinding.delete).toHaveBeenCalledTimes(1);
    expect(mockPrisma.user.update).not.toHaveBeenCalled();
  });
});
