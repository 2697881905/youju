// POST /huawei/exchange 路由集成测试（轻量 in-process HTTP，无需 supertest）。
// mock 三个外部依赖：exchangeCodeForToken / fetchHuaweiUserProfile / loginWithHuawei，
// 验证：缺 code → BAD_REQUEST；链路成功 → 200 + {token,user}；链路抛错 → HUAWEI_AUTH_FAILED(480) 且 httpStatus 200。
import express from 'express';
import * as http from 'http';

import * as huaweiAuth from '../services/huaweiAuth';
import * as authService from '../services/authService';
import router from './auth';
import { CODE } from '../utils/response';

jest.mock('../services/huaweiAuth', () => ({
  exchangeCodeForToken: jest.fn(),
  fetchHuaweiUserProfile: jest.fn(),
}));
jest.mock('../services/authService', () => ({
  login: jest.fn(),
  loginWithHuawei: jest.fn(),
  updateProfile: jest.fn(),
}));
// postService / tagService 在路由模块内被 import，需要 prisma 占位，避免真实 DB 连接。
jest.mock('../prisma', () => ({
  prisma: {
    user: { findUnique: jest.fn(), create: jest.fn() },
    post: { findMany: jest.fn(), count: jest.fn() },
    bookmark: { findMany: jest.fn(), count: jest.fn() },
  },
}));

const mockExchange = huaweiAuth.exchangeCodeForToken as jest.Mock;
const mockFetchUser = huaweiAuth.fetchHuaweiUserProfile as jest.Mock;
const mockLoginWithHuawei = authService.loginWithHuawei as jest.Mock;

let server: http.Server;
let baseUrl: string;

beforeAll((done) => {
  const app = express();
  app.use(express.json());
  app.use('/v1/auth', router);
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

function post(path: string, body?: unknown): Promise<{ status: number; json: any }> {
  return new Promise((resolve, reject) => {
    const data = body ? JSON.stringify(body) : undefined;
    const req = http.request(
      `${baseUrl}${path}`,
      { method: 'POST', headers: { 'Content-Type': 'application/json' } },
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
    req.on('error', reject);
    if (data) req.write(data);
    req.end();
  });
}

describe('POST /v1/auth/huawei/exchange', () => {
  it('缺 code → BAD_REQUEST(400)，httpStatus 400，不触发下游调用', async () => {
    const res = await post('/v1/auth/huawei/exchange', {});

    expect(res.status).toBe(400);
    expect(res.json.code).toBe(CODE.BAD_REQUEST);
    expect(res.json.data).toBeNull();
    expect(mockExchange).not.toHaveBeenCalled();
  });

  it('链路成功 → 200 + {code:0, data:{token,user}}，下游调用参数正确', async () => {
    mockExchange.mockResolvedValue('ACCESS_TOKEN');
    mockFetchUser.mockResolvedValue({ unionID: 'U_1', nickName: '小华', avatarUri: 'a.png' });
    mockLoginWithHuawei.mockResolvedValue({ token: 'JWT_TOKEN', user: { id: 10, nickname: '小华' } });

    const res = await post('/v1/auth/huawei/exchange', { code: 'AUTH_CODE' });

    expect(res.status).toBe(200);
    expect(res.json.code).toBe(0);
    expect(res.json.data.token).toBe('JWT_TOKEN');
    expect(res.json.data.user.id).toBe(10);
    expect(mockExchange).toHaveBeenCalledWith('AUTH_CODE');
    expect(mockFetchUser).toHaveBeenCalledWith('ACCESS_TOKEN');
    expect(mockLoginWithHuawei).toHaveBeenCalledWith('U_1', '小华', 'a.png');
  });

  it('链路抛错（exchange 失败） → HUAWEI_AUTH_FAILED(480)，httpStatus 200', async () => {
    mockExchange.mockRejectedValue(new Error('华为 token 失败'));

    const res = await post('/v1/auth/huawei/exchange', { code: 'AUTH_CODE' });

    expect(res.status).toBe(200);
    expect(res.json.code).toBe(CODE.HUAWEI_AUTH_FAILED); // 480
    expect(res.json.data).toBeNull();
  });
});
