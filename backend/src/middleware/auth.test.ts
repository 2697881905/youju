import jwt from 'jsonwebtoken';
import { auth } from './auth';
import { prisma } from '../prisma';

// mock prisma（仅 user.findUnique 被 auth 中间件调用）
jest.mock('../prisma', () => ({
  prisma: {
    user: {
      findUnique: jest.fn(),
    },
  },
}));

// 固定密钥用于签发测试 token（覆盖 config/env 的真实 jwtSecret）
jest.mock('../config/env', () => ({
  env: {
    jwtSecret: 'test-secret',
    jwtExpiresIn: '1h',
    adminUserIds: [],
  },
}));

const mockedFindUnique = prisma.user.findUnique as jest.Mock;

interface MockRes {
  statusCode: number;
  body: any;
  status(code: number): MockRes;
  json(payload: any): MockRes;
}

function makeRes(): any {
  const res: MockRes = {
    statusCode: 0,
    body: undefined,
    status(code: number) {
      this.statusCode = code;
      return this;
    },
    json(payload: any) {
      this.body = payload;
      return this;
    },
  };
  return res;
}

describe('auth middleware', () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  it('a) 缺失 Authorization → 401 未登录', async () => {
    const req: any = { headers: {} };
    const res = makeRes();
    const next = jest.fn();
    await auth(req, res, next);
    expect(next).not.toHaveBeenCalled();
    expect(res.statusCode).toBe(401);
    expect(res.body.message).toBe('未登录');
  });

  it('b) token 过期/非法 → 401 登录已过期', async () => {
    const req: any = { headers: { authorization: 'Bearer invalid.token.here' } };
    const res = makeRes();
    const next = jest.fn();
    await auth(req, res, next);
    expect(next).not.toHaveBeenCalled();
    expect(res.statusCode).toBe(401);
    expect(res.body.message).toBe('登录已过期');
  });

  it('c) 正常用户 → 放行 next 且写入 req.userId', async () => {
    const token = jwt.sign({ userId: 2 }, 'test-secret');
    mockedFindUnique.mockResolvedValue({ deletedAt: null });
    const req: any = { headers: { authorization: 'Bearer ' + token } };
    const res = makeRes();
    const next = jest.fn();
    await auth(req, res, next);
    expect(next).toHaveBeenCalledTimes(1);
    expect(req.userId).toBe(2);
  });

  it('d) 已注销用户（deletedAt 非空）→ 401 账号已注销，next 不调用', async () => {
    const token = jwt.sign({ userId: 3 }, 'test-secret');
    mockedFindUnique.mockResolvedValue({ deletedAt: new Date() });
    const req: any = { headers: { authorization: 'Bearer ' + token } };
    const res = makeRes();
    const next = jest.fn();
    await auth(req, res, next);
    expect(next).not.toHaveBeenCalled();
    expect(res.statusCode).toBe(401);
    expect(res.body.message).toBe('账号已注销');
  });

  it('e) 用户不存在 → 401 账号已注销', async () => {
    const token = jwt.sign({ userId: 99 }, 'test-secret');
    mockedFindUnique.mockResolvedValue(null);
    const req: any = { headers: { authorization: 'Bearer ' + token } };
    const res = makeRes();
    const next = jest.fn();
    await auth(req, res, next);
    expect(next).not.toHaveBeenCalled();
    expect(res.statusCode).toBe(401);
    expect(res.body.message).toBe('账号已注销');
  });
});
