// 发帖路由集成测试 + GET 列表/详情（软鉴权）集成测试
// 覆盖：
//   POST /v1/posts：缺 token → 401；缺 title/genre → 400；命中敏感词 → 400；正常 → 200（不回归）；
//   GET  /v1/posts：匿名可浏览（200，不打标）；带 token → 列表项含 myUp/myBookmark；
//   GET  /v1/posts/:id：匿名可访问（200，不 401）；带 token → 返回 myUp/myBookmark；不存在 → 404。
// 参考 admin.test.ts 的 mock 风格（真实 HTTP + JWT + mock prisma/sensitiveWordService）。
import express from 'express';
import * as http from 'http';
import jwt from 'jsonwebtoken';

import postRouter from './posts';
import { env } from '../config/env';
import { CODE } from '../utils/response';

// mock prisma（postService 依赖 post/create/findMany/findFirst/count + up/bookmark findFirst/findMany）
jest.mock('../prisma', () => ({
  prisma: {
    post: {
      create: jest.fn(),
      findMany: jest.fn(),
      findFirst: jest.fn(),
      count: jest.fn(),
    },
    up: {
      findFirst: jest.fn(),
      findMany: jest.fn(),
    },
    bookmark: {
      findFirst: jest.fn(),
      findMany: jest.fn(),
    },
    user: {
      findUnique: jest.fn().mockResolvedValue({ deletedAt: null }),
    },
  },
}));

// mock sensitiveWordService（避免依赖词库文件，可按用例动态控制 checkText 返回值）
jest.mock('../services/sensitiveWordService', () => ({
  sensitiveWordService: {
    checkText: jest.fn(),
    isLoaded: jest.fn().mockReturnValue(true),
  },
}));

import { prisma } from '../prisma';
import { sensitiveWordService } from '../services/sensitiveWordService';
const mockPrisma = prisma as any;
const mockCheckText = sensitiveWordService.checkText as jest.Mock;

const mockedPostFindMany = prisma.post.findMany as jest.Mock;
const mockedPostFindFirst = prisma.post.findFirst as jest.Mock;
const mockedPostCount = prisma.post.count as jest.Mock;
const mockedUpFindFirst = prisma.up.findFirst as jest.Mock;
const mockedUpFindMany = prisma.up.findMany as jest.Mock;
const mockedBmFindFirst = prisma.bookmark.findFirst as jest.Mock;
const mockedBmFindMany = prisma.bookmark.findMany as jest.Mock;

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
  app.use('/v1/posts', postRouter);
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
  headers: Record<string, string> = {}
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
      }
    );
    r.on('error', reject);
    if (data) r.write(data);
    r.end();
  });
}

describe('POST /v1/posts（发帖）', () => {
  it('缺 Authorization → UNAUTHORIZED(401)', async () => {
    const res = await req('POST', '/v1/posts', { title: '标题', genre: '数码' });
    expect(res.status).toBe(401);
    expect(res.json.code).toBe(CODE.UNAUTHORIZED);
  });

  it('缺 title → BAD_REQUEST(400)', async () => {
    const res = await req('POST', '/v1/posts', { genre: '数码' }, authHeader());
    expect(res.status).toBe(400);
    expect(res.json.code).toBe(CODE.BAD_REQUEST);
    expect(res.json.message).toContain('标题');
  });

  it('缺 genre → BAD_REQUEST(400)', async () => {
    const res = await req('POST', '/v1/posts', { title: '标题' }, authHeader());
    expect(res.status).toBe(400);
    expect(res.json.code).toBe(CODE.BAD_REQUEST);
    expect(res.json.message).toContain('体裁');
  });

  it('命中敏感词 → 400 + 友好提示（P0 Bug 回归）', async () => {
    // 模拟敏感词命中
    mockCheckText.mockReturnValue(true);

    const res = await req(
      'POST',
      '/v1/posts',
      { title: '含敏感词的标题', genre: '数码', content: '正文' },
      authHeader()
    );

    // 关键断言：不再超时，立即返回 400
    expect(res.status).toBe(400);
    expect(res.json.code).toBe(CODE.BAD_REQUEST);
    expect(res.json.message).toContain('敏感词');
    // 不应调用 prisma.post.create（敏感词拦截在前）
    expect(mockPrisma.post.create).not.toHaveBeenCalled();
  });

  it('正常发帖 → 200 + code 0（成功路径不回归）', async () => {
    // 模拟敏感词未命中
    mockCheckText.mockReturnValue(false);
    const createdPost = {
      id: 42,
      userId: TEST_USER_ID,
      title: '正常标题',
      content: '正常正文',
      genre: '数码',
      tags: [],
      images: [],
      status: 1,
    };
    mockPrisma.post.create.mockResolvedValue(createdPost);

    const res = await req(
      'POST',
      '/v1/posts',
      { title: '正常标题', genre: '数码', content: '正常正文' },
      authHeader()
    );

    expect(res.status).toBe(200);
    expect(res.json.code).toBe(0);
    expect(res.json.data.id).toBe(42);
    expect(res.json.data.title).toBe('正常标题');
    // 确认敏感词检测被调用
    expect(mockCheckText).toHaveBeenCalled();
    // 确认 post.create 被调用且 status=1（直接发布）
    expect(mockPrisma.post.create).toHaveBeenCalledWith(
      expect.objectContaining({
        data: expect.objectContaining({
          userId: TEST_USER_ID,
          title: '正常标题',
          status: 1,
        }),
      })
    );
  });
});

describe('GET /v1/posts（信息流，软鉴权）', () => {
  it('匿名（无 token）仍可浏览信息流，返回 200（不 401）', async () => {
    mockedPostFindMany.mockResolvedValue([{ id: 1, user: {} }]);
    mockedPostCount.mockResolvedValue(1);

    const res = await req('GET', '/v1/posts');

    expect(res.status).toBe(200);
    expect(res.json.code).toBe(0);
    expect(Array.isArray(res.json.data.list)).toBe(true);
    // 匿名不打标（无 viewerId 分支），不触发 up/bookmark 查询
    expect(mockedUpFindMany).not.toHaveBeenCalled();
    expect(mockedBmFindMany).not.toHaveBeenCalled();
  });

  it('带 token 时列表项含 myUp/myBookmark', async () => {
    mockedPostFindMany.mockResolvedValue([{ id: 1, user: {} }]);
    mockedPostCount.mockResolvedValue(1);
    mockedUpFindMany.mockResolvedValue([{ postId: 1 }]);
    mockedBmFindMany.mockResolvedValue([]);

    const res = await req('GET', '/v1/posts', undefined, authHeader());

    expect(res.status).toBe(200);
    expect(res.json.code).toBe(0);
    expect(res.json.data.list[0].myUp).toBe(true);
    expect(res.json.data.list[0].myBookmark).toBe(false);
  });
});

describe('GET /v1/posts/:id（详情，软鉴权）', () => {
  it('匿名（无 token）仍可访问详情，返回 200（不 401）', async () => {
    mockedPostFindFirst.mockResolvedValue({ id: 1, user: {} });

    const res = await req('GET', '/v1/posts/1');

    expect(res.status).toBe(200);
    expect(res.json.code).toBe(0);
    // 匿名不打标（无 viewerId 分支）
    expect(mockedUpFindFirst).not.toHaveBeenCalled();
    expect(mockedBmFindFirst).not.toHaveBeenCalled();
  });

  it('带 token 时返回 myUp/myBookmark', async () => {
    mockedPostFindFirst.mockResolvedValue({ id: 1, user: {} });
    mockedUpFindFirst.mockResolvedValue({ id: 9, postId: 1, userId: 1 });
    mockedBmFindFirst.mockResolvedValue(null);

    const res = await req('GET', '/v1/posts/1', undefined, authHeader());

    expect(res.status).toBe(200);
    expect(res.json.code).toBe(0);
    expect(res.json.data.myUp).toBe(true);
    expect(res.json.data.myBookmark).toBe(false);
  });

  it('帖子不存在返回 404', async () => {
    mockedPostFindFirst.mockResolvedValue(null);

    const res = await req('GET', '/v1/posts/999');

    expect(res.status).toBe(404);
    expect(res.json.code).toBe(CODE.NOT_FOUND);
  });
});
