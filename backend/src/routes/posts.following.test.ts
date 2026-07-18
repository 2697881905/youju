// 关注流路由集成测试（轻量 in-process HTTP，mock prisma，无需真实 DB）。
// 覆盖：
//   缺 token → 401；
//   关注 0 人 → 返回 {list:[], pagination:{total:0}} 且不查 post 表；
//   关注 2 人 → post.findMany 的 where.userId 为 { in: [ids] } 且返回其帖子；
//   tag/sort 透传。
import express from 'express';
import * as http from 'http';
import jwt from 'jsonwebtoken';

import router from './posts';
import { env } from '../config/env';
import { CODE } from '../utils/response';

jest.mock('../prisma', () => ({
  prisma: {
    follow: {
      findMany: jest.fn(),
    },
    post: {
      findMany: jest.fn(),
      count: jest.fn(),
      findUnique: jest.fn(),
    },
  },
}));

import { prisma } from '../prisma';
const mockPrisma = prisma as any;

const TEST_USER_ID = 1;

function authHeader(userId: number = TEST_USER_ID): Record<string, string> {
  const token: string = jwt.sign({ userId }, env.jwtSecret);
  return { Authorization: 'Bearer ' + token };
}

let server: http.Server;
let baseUrl: string;

beforeAll((done) => {
  const app = express();
  app.use(express.json());
  app.use('/v1/posts', router);
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

describe('GET /v1/posts/following', () => {
  it('缺 Authorization → UNAUTHORIZED(401)', async () => {
    const res = await req('GET', '/v1/posts/following');
    expect(res.status).toBe(401);
    expect(res.json.code).toBe(CODE.UNAUTHORIZED);
    // 未登录不查任何表
    expect(mockPrisma.follow.findMany).not.toHaveBeenCalled();
    expect(mockPrisma.post.findMany).not.toHaveBeenCalled();
  });

  it('关注 0 人 → 返回空列表且不查 post 表', async () => {
    mockPrisma.follow.findMany.mockResolvedValue([]);
    const res = await req('GET', '/v1/posts/following', undefined, authHeader());
    expect(res.status).toBe(200);
    expect(res.json.code).toBe(0);
    expect(res.json.data.list).toEqual([]);
    expect(res.json.data.pagination.total).toBe(0);
    // 空关注集：直接返回，省一次 count / findMany
    expect(mockPrisma.post.findMany).not.toHaveBeenCalled();
    expect(mockPrisma.post.count).not.toHaveBeenCalled();
  });

  it('关注 2 人 → where.userId in [ids] 且返回其帖子', async () => {
    mockPrisma.follow.findMany.mockResolvedValue([{ followingId: 2 }, { followingId: 3 }]);
    mockPrisma.post.findMany.mockResolvedValue([
      { id: 10, userId: 2, title: 'A 的帖子' },
      { id: 11, userId: 3, title: 'B 的帖子' },
    ]);
    mockPrisma.post.count.mockResolvedValue(2);
    const res = await req('GET', '/v1/posts/following', undefined, authHeader());
    expect(res.status).toBe(200);
    expect(res.json.code).toBe(0);
    expect(mockPrisma.follow.findMany).toHaveBeenCalledWith(
      expect.objectContaining({ where: { followerId: TEST_USER_ID }, select: { followingId: true } }),
    );
    expect(mockPrisma.post.findMany).toHaveBeenCalledWith(
      expect.objectContaining({ where: expect.objectContaining({ userId: { in: [2, 3] } }) }),
    );
    expect(mockPrisma.post.count).toHaveBeenCalledWith(
      expect.objectContaining({ where: expect.objectContaining({ userId: { in: [2, 3] } }) }),
    );
    expect(res.json.data.list.length).toBe(2);
    expect(res.json.data.pagination.total).toBe(2);
  });

  it('tag/sort 透传（关注流内叠加生效）', async () => {
    mockPrisma.follow.findMany.mockResolvedValue([{ followingId: 5 }]);
    mockPrisma.post.findMany.mockResolvedValue([]);
    mockPrisma.post.count.mockResolvedValue(0);
    const res = await req('GET', '/v1/posts/following?tag=数码&sort=hot', undefined, authHeader());
    expect(res.status).toBe(200);
    expect(res.json.code).toBe(0);
    expect(mockPrisma.post.findMany).toHaveBeenCalledWith(
      expect.objectContaining({
        where: expect.objectContaining({
          userId: { in: [5] },
          tags: { array_contains: '数码' },
        }),
        orderBy: [{ upCount: 'desc' }, { createdAt: 'desc' }],
      }),
    );
  });
});
