// 发帖路由集成测试：POST /v1/posts
// 覆盖：
//   缺 token → 401；
//   缺 title/genre → 400；
//   命中敏感词 → 400 + 友好提示（P0 Bug 回归）；
//   正常发帖 → 200 + code 0（成功路径不回归）。
// 参考 admin.test.ts 的 mock 风格（真实 HTTP + JWT + mock prisma/sensitiveWordService）。
import express from 'express';
import * as http from 'http';
import jwt from 'jsonwebtoken';

import postRouter from './posts';
import { env } from '../config/env';
import { CODE } from '../utils/response';

// mock prisma（postService.createPost 依赖 post.create）
jest.mock('../prisma', () => ({
  prisma: {
    post: {
      create: jest.fn(),
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
