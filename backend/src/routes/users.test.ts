// 关注 / 他人主页路由 + 服务集成测试（轻量 in-process HTTP，mock prisma，无需真实 DB）。
// 覆盖：
//   缺 token → 401；
//   POST /v1/users/:id/follow（成功 / 不可自关400 / 不存在404 / 幂等 upsert / 触发关注通知）；
//   DELETE /v1/users/:id/follow（取关成功，幂等 deleteMany）；
//   GET /v1/users/:id（返回 UserProfile，含计数与关系态 / 不存在404）；
//   GET /v1/users/:id/following、/followers（列表，标量外键 + findMany 补 user）；
//   触发辅助 notifyOnFollow：自己关注自己不发，他人则发。
import express from 'express';
import * as http from 'http';
import jwt from 'jsonwebtoken';

import router from './users';
import * as notificationService from '../services/notificationService';
import { env } from '../config/env';
import { CODE } from '../utils/response';

jest.mock('../prisma', () => ({
  prisma: {
    user: {
      findUnique: jest.fn(),
      findMany: jest.fn(),
    },
    follow: {
      upsert: jest.fn(),
      deleteMany: jest.fn(),
      count: jest.fn(),
      findMany: jest.fn(),
    },
    post: {
      count: jest.fn(),
    },
    notification: {
      create: jest.fn(),
    },
  },
}));

import { prisma } from '../prisma';
const mockPrisma = prisma as any;

const TEST_USER_ID = 1;
const TARGET_ID = 2;

function authHeader(userId: number = TEST_USER_ID): Record<string, string> {
  const token: string = jwt.sign({ userId }, env.jwtSecret);
  return { Authorization: 'Bearer ' + token };
}

let server: http.Server;
let baseUrl: string;

beforeAll((done) => {
  const app = express();
  app.use(express.json());
  // 与 app.ts 一致：userRouter 挂在 /v1/users 下，内部路由为 /:id/follow 等
  app.use('/v1/users', router);
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
  // 默认：任何 user.findUnique 都返回一个带昵称的用户（供 resolveTargetId 校验 + notifyOnFollow 取 actor）
  mockPrisma.user.findUnique.mockImplementation((args: any) => {
    const id = args?.where?.id;
    return Promise.resolve({ id, nickname: 'U' + id, avatar: null, bio: null, gender: 1 });
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

describe('POST /v1/users/:id/follow', () => {
  it('缺 Authorization → UNAUTHORIZED(401)', async () => {
    const res = await req('POST', `/v1/users/${TARGET_ID}/follow`);
    expect(res.status).toBe(401);
    expect(res.json.code).toBe(CODE.UNAUTHORIZED);
  });

  it('关注他人成功（upsert 幂等 + 触发关注通知）', async () => {
    mockPrisma.follow.upsert.mockResolvedValue({});
    mockPrisma.notification.create.mockResolvedValue({});
    const res = await req('POST', `/v1/users/${TARGET_ID}/follow`, undefined, authHeader());
    expect(res.status).toBe(200);
    expect(res.json.code).toBe(0);
    expect(mockPrisma.follow.upsert).toHaveBeenCalledWith(
      expect.objectContaining({
        where: { followerId_followingId: { followerId: TEST_USER_ID, followingId: TARGET_ID } },
        create: { followerId: TEST_USER_ID, followingId: TARGET_ID },
      }),
    );
    // 关注通知发出
    expect(mockPrisma.notification.create).toHaveBeenCalledTimes(1);
    const arg = mockPrisma.notification.create.mock.calls[0][0];
    expect(arg.data.userId).toBe(TARGET_ID);
    expect(arg.data.actorId).toBe(TEST_USER_ID);
    expect(arg.data.type).toBe('follow');
  });

  it('关注自己 → BAD_REQUEST(400)', async () => {
    const res = await req('POST', `/v1/users/${TEST_USER_ID}/follow`, undefined, authHeader());
    expect(res.status).toBe(400);
    expect(res.json.code).toBe(CODE.BAD_REQUEST);
    expect(mockPrisma.follow.upsert).not.toHaveBeenCalled();
  });

  it('关注不存在用户 → NOT_FOUND(404)', async () => {
    mockPrisma.user.findUnique.mockResolvedValue(null);
    const res = await req('POST', `/v1/users/999/follow`, undefined, authHeader());
    expect(res.status).toBe(404);
    expect(res.json.code).toBe(CODE.NOT_FOUND);
    expect(mockPrisma.follow.upsert).not.toHaveBeenCalled();
  });
});

describe('DELETE /v1/users/:id/follow', () => {
  it('取消关注成功（deleteMany 幂等）', async () => {
    mockPrisma.follow.deleteMany.mockResolvedValue({ count: 1 });
    const res = await req('DELETE', `/v1/users/${TARGET_ID}/follow`, undefined, authHeader());
    expect(res.status).toBe(200);
    expect(res.json.code).toBe(0);
    expect(mockPrisma.follow.deleteMany).toHaveBeenCalledWith(
      expect.objectContaining({ where: { followerId: TEST_USER_ID, followingId: TARGET_ID } }),
    );
  });
});

describe('GET /v1/users/:id', () => {
  it('返回 UserProfile（计数 + 关系态）', async () => {
    mockPrisma.user.findUnique.mockImplementation((args: any) => {
      const id = args?.where?.id;
      return Promise.resolve({ id, nickname: 'B', avatar: null, bio: 'hi', gender: 1 });
    });
    mockPrisma.follow.count.mockImplementation((args: any) => {
      const w = args?.where ?? {};
      if (w.followerId === TARGET_ID && w.followingId === undefined) return Promise.resolve(5); // followingCount
      if (w.followingId === TARGET_ID && w.followerId === undefined) return Promise.resolve(3); // followerCount
      if (w.followerId === TEST_USER_ID && w.followingId === TARGET_ID) return Promise.resolve(1); // isFollowing
      if (w.followerId === TARGET_ID && w.followingId === TEST_USER_ID) return Promise.resolve(0); // isMutual
      return Promise.resolve(0);
    });
    mockPrisma.post.count.mockResolvedValue(7);

    const res = await req('GET', `/v1/users/${TARGET_ID}`, undefined, authHeader());
    expect(res.status).toBe(200);
    expect(res.json.code).toBe(0);
    const d = res.json.data;
    expect(d.id).toBe(TARGET_ID);
    expect(d.followingCount).toBe(5);
    expect(d.followerCount).toBe(3);
    expect(d.postCount).toBe(7);
    expect(d.isFollowing).toBe(true);
    expect(d.isMutual).toBe(false);
    expect(d.bio).toBe('hi');
  });

  it('用户不存在 → NOT_FOUND(404)', async () => {
    mockPrisma.user.findUnique.mockResolvedValue(null);
    const res = await req('GET', `/v1/users/999`, undefined, authHeader());
    expect(res.status).toBe(404);
    expect(res.json.code).toBe(CODE.NOT_FOUND);
  });
});

describe('GET /v1/users/:id/following | /followers', () => {
  it('关注列表：follow.findMany + user.findMany 补 user', async () => {
    mockPrisma.follow.findMany.mockImplementation((args: any) => {
      if (args?.where?.followerId === TARGET_ID && args?.where?.followingId === undefined) {
        return Promise.resolve([{ followerId: TARGET_ID, followingId: 10 }, { followerId: TARGET_ID, followingId: 11 }]);
      }
      return Promise.resolve([]); // isFollowing map 查询（空）
    });
    mockPrisma.follow.count.mockResolvedValue(2);
    mockPrisma.user.findMany.mockResolvedValue([
      { id: 10, nickname: 'A', avatar: null, bio: null },
      { id: 11, nickname: 'B', avatar: null, bio: null },
    ]);

    const res = await req('GET', `/v1/users/${TARGET_ID}/following?page=1&limit=20`, undefined, authHeader());
    expect(res.status).toBe(200);
    expect(res.json.code).toBe(0);
    const list = res.json.data.list as any[];
    expect(list.length).toBe(2);
    expect(list[0].id).toBe(10);
    expect(list[0].nickname).toBe('A');
    expect(mockPrisma.user.findMany).toHaveBeenCalledWith(
      expect.objectContaining({ where: { id: { in: [10, 11] } } }),
    );
  });

  it('粉丝列表：按 followingId 查询', async () => {
    mockPrisma.follow.findMany.mockImplementation((args: any) => {
      if (args?.where?.followingId === TARGET_ID && args?.where?.followerId === undefined) {
        return Promise.resolve([{ followerId: 20, followingId: TARGET_ID }]);
      }
      return Promise.resolve([]);
    });
    mockPrisma.follow.count.mockResolvedValue(1);
    mockPrisma.user.findMany.mockResolvedValue([{ id: 20, nickname: 'F', avatar: null, bio: null }]);

    const res = await req('GET', `/v1/users/${TARGET_ID}/followers?page=1&limit=20`, undefined, authHeader());
    expect(res.status).toBe(200);
    expect(res.json.code).toBe(0);
    const list = res.json.data.list as any[];
    expect(list.length).toBe(1);
    expect(list[0].id).toBe(20);
  });
});

describe('触发辅助函数 notifyOnFollow', () => {
  it('自己关注自己不发通知', async () => {
    await notificationService.notifyOnFollow(2, 2);
    expect(mockPrisma.notification.create).not.toHaveBeenCalled();
  });

  it('他人关注则发通知（含昵称文案）', async () => {
    mockPrisma.user.findUnique.mockResolvedValue({ nickname: 'C' });
    mockPrisma.notification.create.mockResolvedValue({});
    await notificationService.notifyOnFollow(2, 3);
    expect(mockPrisma.notification.create).toHaveBeenCalledTimes(1);
    const arg = mockPrisma.notification.create.mock.calls[0][0];
    expect(arg.data.userId).toBe(2);
    expect(arg.data.actorId).toBe(3);
    expect(arg.data.type).toBe('follow');
    expect(arg.data.content).toBe('C 关注了你');
  });
});
