// admin 路由集成测试：admin 鉴权 + moderatePost 审核流转
// 覆盖：缺 token → 401；非 admin → 403；GET /posts/pending；POST /posts/:id/moderate（approve/reject）
import express from 'express';
import * as http from 'http';
import jwt from 'jsonwebtoken';

import adminRouter from './admin';
import { env } from '../config/env';
import { CODE } from '../utils/response';

// mock prisma（reportService + moderationService 依赖）
jest.mock('../prisma', () => ({
  prisma: {
    post: {
      findUnique: jest.fn(),
      findMany: jest.fn(),
      count: jest.fn(),
      update: jest.fn(),
    },
    comment: {
      findUnique: jest.fn(),
      update: jest.fn(),
    },
    report: {
      create: jest.fn(),
      findMany: jest.fn(),
      count: jest.fn(),
      updateMany: jest.fn(),
    },
    notification: {
      create: jest.fn(),
    },
    user: {
      findUnique: jest.fn().mockResolvedValue({ deletedAt: null }),
    },
    // notificationPrefService（notifySystem 链路）依赖：默认无偏好记录 → 全部允许
    notificationPreference: {
      findUnique: jest.fn().mockResolvedValue(null),
    },
  },
}));

// mock sensitiveWordService（避免依赖词库文件）
jest.mock('../services/sensitiveWordService', () => ({
  sensitiveWordService: {
    checkText: jest.fn().mockReturnValue(false),
    isLoaded: jest.fn().mockReturnValue(true),
  },
}));

import { prisma } from '../prisma';
const mockPrisma = prisma as any;

function authHeader(userId: number): Record<string, string> {
  const token: string = jwt.sign({ userId }, env.jwtSecret);
  return { Authorization: 'Bearer ' + token };
}

let server: http.Server;
let baseUrl: string;

beforeAll((done) => {
  const app = express();
  app.use(express.json());
  app.use('/v1/admin', adminRouter);
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

describe('admin 路由鉴权', () => {
  it('缺 Authorization → UNAUTHORIZED(401)', async () => {
    const res = await req('GET', '/v1/admin/posts/pending');
    expect(res.status).toBe(401);
    expect(res.json.code).toBe(CODE.UNAUTHORIZED);
  });

  it('非 admin 用户 → FORBIDDEN(403)', async () => {
    // userId=999 不在 adminUserIds 中
    const res = await req('GET', '/v1/admin/posts/pending', undefined, authHeader(999));
    expect(res.status).toBe(403);
    expect(res.json.code).toBe(CODE.FORBIDDEN);
  });
});

describe('GET /v1/admin/posts/pending', () => {
  it('admin 用户获取待审核列表', async () => {
    // 确保 env.adminUserIds 包含 userId=1（.env 或默认）
    // 测试环境可能未配置 ADMIN_USER_IDS，动态注入
    const originalAdminIds = env.adminUserIds;
    (env as any).adminUserIds = [1];

    mockPrisma.post.findMany.mockResolvedValue([
      {
        id: 1,
        title: '待审帖',
        status: 0,
        userId: 10,
        reportCount: 3,
        user: { id: 10, nickname: '作者', avatar: null },
        reports: [
          { id: 100, targetType: 'post', targetId: 1, reason: 'spam', description: null, status: 'pending', reporter: { nickname: '举报人A' } },
        ],
      },
    ]);
    mockPrisma.post.count.mockResolvedValue(1);

    const res = await req('GET', '/v1/admin/posts/pending?page=1&limit=20', undefined, authHeader(1));
    expect(res.status).toBe(200);
    expect(res.json.code).toBe(0);
    expect(res.json.data.list.length).toBe(1);
    expect(mockPrisma.post.findMany).toHaveBeenCalledWith(
      expect.objectContaining({
        where: { status: 0 },
        orderBy: { createdAt: 'desc' },
        include: expect.objectContaining({
          reports: expect.objectContaining({
            include: { reporter: { select: { nickname: true } } },
          }),
        }),
      })
    );
    // 待审帖子应携带举报列表，供前端展示举报理由
    expect(Array.isArray(res.json.data.list[0].reports)).toBe(true);
    expect(res.json.data.list[0].reports[0].reason).toBe('spam');
    expect(res.json.data.list[0].reports[0].reporter.nickname).toBe('举报人A');

    (env as any).adminUserIds = originalAdminIds;
  });
});

describe('POST /v1/admin/posts/:id/moderate', () => {
  beforeEach(() => {
    (env as any).adminUserIds = [1];
  });

  it('action 无效 → 400', async () => {
    const res = await req('POST', '/v1/admin/posts/1/moderate', { action: 'invalid' }, authHeader(1));
    expect(res.status).toBe(400);
    expect(res.json.code).toBe(CODE.BAD_REQUEST);
  });

  it('approve 帖子不存在 → 404', async () => {
    mockPrisma.post.findUnique.mockResolvedValue(null);
    const res = await req('POST', '/v1/admin/posts/999/moderate', { action: 'approve' }, authHeader(1));
    expect(res.status).toBe(404);
    expect(res.json.code).toBe(CODE.NOT_FOUND);
  });

  it('approve 非待审状态 → 400', async () => {
    mockPrisma.post.findUnique.mockResolvedValue({ id: 1, userId: 10, title: '已发布', status: 1 });
    const res = await req('POST', '/v1/admin/posts/1/moderate', { action: 'approve' }, authHeader(1));
    expect(res.status).toBe(400);
    expect(res.json.code).toBe(CODE.BAD_REQUEST);
    expect(res.json.message).toContain('不在待审核状态');
  });

  it('approve 成功：status→1 + reports→dismissed + 通知作者', async () => {
    mockPrisma.post.findUnique.mockResolvedValue({ id: 1, userId: 10, title: '待审帖', status: 0 });
    mockPrisma.post.update.mockResolvedValue({});
    mockPrisma.report.updateMany.mockResolvedValue({ count: 2 });
    mockPrisma.report.findMany.mockResolvedValue([{ reporterId: 2 }, { reporterId: 3 }]);
    mockPrisma.notification.create.mockResolvedValue({});

    const res = await req('POST', '/v1/admin/posts/1/moderate', { action: 'approve' }, authHeader(1));
    expect(res.status).toBe(200);
    expect(res.json.code).toBe(0);
    expect(res.json.message).toBe('审核完成');

    // 帖子 status → 1
    const postUpdateCall = mockPrisma.post.update.mock.calls[0][0];
    expect(postUpdateCall.data.status).toBe(1);

    // 举报记录 → dismissed
    expect(mockPrisma.report.updateMany).toHaveBeenCalledWith(
      expect.objectContaining({
        data: { status: 'dismissed', resolvedAt: expect.any(Date) },
      })
    );

    // 通知作者"已通过审核" + 通知举报人"已处理"（2 个举报人）= 3 次
    expect(mockPrisma.notification.create).toHaveBeenCalledTimes(3);
    const authorNotif = mockPrisma.notification.create.mock.calls[0][0];
    expect(authorNotif.data.userId).toBe(10);
    expect(authorNotif.data.content).toContain('已通过审核');
  });

  it('reject 成功：status→2 + reports→resolved + 通知作者含原因', async () => {
    mockPrisma.post.findUnique.mockResolvedValue({ id: 1, userId: 10, title: '待审帖', status: 0 });
    mockPrisma.post.update.mockResolvedValue({});
    mockPrisma.report.updateMany.mockResolvedValue({ count: 1 });
    mockPrisma.report.findMany.mockResolvedValue([{ reporterId: 2 }]);
    mockPrisma.notification.create.mockResolvedValue({});

    const res = await req(
      'POST',
      '/v1/admin/posts/1/moderate',
      { action: 'reject', reason: '内容违规' },
      authHeader(1)
    );
    expect(res.status).toBe(200);

    const postUpdateCall = mockPrisma.post.update.mock.calls[0][0];
    expect(postUpdateCall.data.status).toBe(2);

    // 举报记录 → resolved
    expect(mockPrisma.report.updateMany).toHaveBeenCalledWith(
      expect.objectContaining({
        data: { status: 'resolved', resolvedAt: expect.any(Date) },
      })
    );

    // 通知作者"未通过审核" + 原因
    const authorNotif = mockPrisma.notification.create.mock.calls[0][0];
    expect(authorNotif.data.content).toContain('未通过审核');
    expect(authorNotif.data.content).toContain('内容违规');
  });
});
