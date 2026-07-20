// 评论路由集成测试：POST /v1/posts/:id/comments
// 覆盖：
//   缺 token → 401；
//   缺 content → 400；
//   命中敏感词 → 400 + 友好提示（P0 Bug 回归）；
//   正常评论 → 200 + code 0（成功路径不回归）。
// 参考 admin.test.ts 的 mock 风格（真实 HTTP + JWT + mock prisma/sensitiveWordService/notificationService）。
import express from 'express';
import * as http from 'http';
import jwt from 'jsonwebtoken';

import commentRouter from './comments';
import { env } from '../config/env';
import { CODE } from '../utils/response';

// mock prisma（commentService.createComment 依赖 comment.create；auth 中间件依赖 user.findUnique）
jest.mock('../prisma', () => ({
  prisma: {
    comment: {
      create: jest.fn(),
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

// mock notificationService（createComment 内部调用 notifyOnComment，需 mock 避免副作用）
jest.mock('../services/notificationService', () => ({
  notifyOnComment: jest.fn().mockResolvedValue(undefined),
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
  // comments 路由使用完整路径（/v1/posts/:id/comments），挂在 /v1 下
  app.use('/v1', commentRouter);
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

describe('POST /v1/posts/:id/comments（评论）', () => {
  it('缺 Authorization → UNAUTHORIZED(401)', async () => {
    const res = await req('POST', '/v1/posts/1/comments', { content: '评论内容' });
    expect(res.status).toBe(401);
    expect(res.json.code).toBe(CODE.UNAUTHORIZED);
  });

  it('缺 content → BAD_REQUEST(400)', async () => {
    const res = await req('POST', '/v1/posts/1/comments', {}, authHeader());
    expect(res.status).toBe(400);
    expect(res.json.code).toBe(CODE.BAD_REQUEST);
    expect(res.json.message).toContain('评论内容');
  });

  it('命中敏感词 → 400 + 友好提示（P0 Bug 回归）', async () => {
    // 模拟敏感词命中
    mockCheckText.mockReturnValue(true);

    const res = await req(
      'POST',
      '/v1/posts/1/comments',
      { content: '含敏感词的评论' },
      authHeader()
    );

    // 关键断言：不再超时，立即返回 400
    expect(res.status).toBe(400);
    expect(res.json.code).toBe(CODE.BAD_REQUEST);
    expect(res.json.message).toContain('敏感词');
    // 不应调用 prisma.comment.create（敏感词拦截在前）
    expect(mockPrisma.comment.create).not.toHaveBeenCalled();
  });

  it('正常评论 → 200 + code 0（成功路径不回归）', async () => {
    // 模拟敏感词未命中
    mockCheckText.mockReturnValue(false);
    const createdComment = {
      id: 88,
      postId: 1,
      userId: TEST_USER_ID,
      content: '正常评论',
      parentId: null,
      isFact: 0,
    };
    mockPrisma.comment.create.mockResolvedValue(createdComment);

    const res = await req(
      'POST',
      '/v1/posts/1/comments',
      { content: '正常评论' },
      authHeader()
    );

    expect(res.status).toBe(200);
    expect(res.json.code).toBe(0);
    expect(res.json.data.id).toBe(88);
    expect(res.json.data.content).toBe('正常评论');
    // 确认敏感词检测被调用
    expect(mockCheckText).toHaveBeenCalled();
    // 确认 comment.create 被调用
    expect(mockPrisma.comment.create).toHaveBeenCalledWith(
      expect.objectContaining({
        data: expect.objectContaining({
          postId: 1,
          userId: TEST_USER_ID,
          content: '正常评论',
        }),
      })
    );
  });

  it('带 parentId 的楼中楼评论 → 200', async () => {
    mockCheckText.mockReturnValue(false);
    mockPrisma.comment.create.mockResolvedValue({
      id: 89,
      postId: 1,
      userId: TEST_USER_ID,
      content: '回复',
      parentId: 88,
      isFact: 0,
    });

    const res = await req(
      'POST',
      '/v1/posts/1/comments',
      { content: '回复', parentId: 88 },
      authHeader()
    );

    expect(res.status).toBe(200);
    expect(res.json.code).toBe(0);
    expect(mockPrisma.comment.create).toHaveBeenCalledWith(
      expect.objectContaining({
        data: expect.objectContaining({
          parentId: 88,
        }),
      })
    );
  });
});
