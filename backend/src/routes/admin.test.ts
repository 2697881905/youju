// admin 路由集成测试：admin 鉴权 + 举报中心统一处置（/reports 列表 + /reports/resolve 三动作）
// 覆盖：缺 token → 401；非 admin → 403；GET /reports；POST /reports/resolve（resolved/dismissed/restore + 负例）；
//       旧审核台接口 /posts/pending、/posts/:id/moderate 已下线 → 404 护栏
import express from 'express';
import * as http from 'http';
import jwt from 'jsonwebtoken';

import adminRouter from './admin';
import { env } from '../config/env';
import { CODE } from '../utils/response';

// mock prisma（reportService 依赖）
jest.mock('../prisma', () => ({
  prisma: {
    post: {
      findUnique: jest.fn(),
      findMany: jest.fn(),
      count: jest.fn(),
      update: jest.fn(),
      updateMany: jest.fn(),
    },
    comment: {
      findUnique: jest.fn(),
      update: jest.fn(),
      updateMany: jest.fn(),
    },
    report: {
      create: jest.fn(),
      findMany: jest.fn().mockResolvedValue([]),
      count: jest.fn(),
      updateMany: jest.fn(),
    },
    notification: {
      create: jest.fn(),
      findFirst: jest.fn().mockResolvedValue(null),
      update: jest.fn(),
    },
    user: {
      findUnique: jest.fn().mockResolvedValue({ deletedAt: null }),
      findMany: jest.fn().mockResolvedValue([]),
    },
    // notificationPrefService（notifySystem 链路）依赖：默认无偏好记录 → 全部允许
    notificationPreference: {
      findUnique: jest.fn().mockResolvedValue(null),
    },
    $transaction: jest.fn(),
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
  mockPrisma.$transaction.mockImplementation((callback: any) => callback(mockPrisma));
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
    const res = await req('GET', '/v1/admin/reports');
    expect(res.status).toBe(401);
    expect(res.json.code).toBe(CODE.UNAUTHORIZED);
  });

  it('非 admin 用户 → FORBIDDEN(403)', async () => {
    // userId=999 不在 adminUserIds 中
    const res = await req('GET', '/v1/admin/reports', undefined, authHeader(999));
    expect(res.status).toBe(403);
    expect(res.json.code).toBe(CODE.FORBIDDEN);
  });
});

describe('旧内容审核台接口已下线（合并进举报中心）', () => {
  it('GET /v1/admin/posts/pending → 404（接口已移除）', async () => {
    (env as any).adminUserIds = [1];
    const res = await req('GET', '/v1/admin/posts/pending', undefined, authHeader(1));
    expect(res.status).toBe(404);
  });

  it('POST /v1/admin/posts/1/moderate → 404（接口已移除）', async () => {
    (env as any).adminUserIds = [1];
    const res = await req('POST', '/v1/admin/posts/1/moderate', { action: 'approve' }, authHeader(1));
    expect(res.status).toBe(404);
  });
});

describe('POST /v1/admin/reports/resolve', () => {
  beforeEach(() => {
    (env as any).adminUserIds = [1];
    // 事务：直接把 tx 指向同一批 mock（形态与 reportService.test 一致）
    mockPrisma.$transaction.mockImplementation((cb: any) => cb(mockPrisma));
    mockPrisma.report.updateMany.mockResolvedValue({ count: 1 });
    mockPrisma.report.findMany.mockResolvedValue([{ reporterId: 2 }]);
    mockPrisma.report.count.mockResolvedValue(0);
    mockPrisma.post.findUnique.mockResolvedValue({ id: 1, userId: 10, title: '待审帖', status: 0 });
    mockPrisma.post.updateMany.mockResolvedValue({ count: 1 });
    mockPrisma.notification.create.mockResolvedValue({});
    mockPrisma.notification.findFirst.mockResolvedValue(null);
  });

  it('参数非法 → 400（targetType / targetId / action）', async () => {
    const bad1 = await req(
      'POST',
      '/v1/admin/reports/resolve',
      { targetType: 'xxx', targetId: 1, action: 'resolved' },
      authHeader(1)
    );
    expect(bad1.status).toBe(400);
    expect(bad1.json.code).toBe(CODE.BAD_REQUEST);

    const bad2 = await req(
      'POST',
      '/v1/admin/reports/resolve',
      { targetType: 'post', targetId: 0, action: 'resolved' },
      authHeader(1)
    );
    expect(bad2.status).toBe(400);

    const bad3 = await req(
      'POST',
      '/v1/admin/reports/resolve',
      { targetType: 'post', targetId: 1, action: 'approve' },
      authHeader(1)
    );
    expect(bad3.status).toBe(400);
    expect(bad3.json.message).toContain('resolved');
  });

  it('目标不存在 → 404', async () => {
    mockPrisma.post.findUnique.mockResolvedValue(null);
    const res = await req(
      'POST',
      '/v1/admin/reports/resolve',
      { targetType: 'post', targetId: 999, action: 'resolved' },
      authHeader(1)
    );
    expect(res.status).toBe(404);
    expect(res.json.code).toBe(CODE.NOT_FOUND);
  });

  it('resolved 成功：举报→resolved + 内容下架 + 通知作者（含原因）与举报人', async () => {
    const res = await req(
      'POST',
      '/v1/admin/reports/resolve',
      { targetType: 'post', targetId: 1, action: 'resolved', reason: '含广告推广' },
      authHeader(1)
    );
    expect(res.status).toBe(200);
    expect(res.json.code).toBe(0);
    expect(res.json.message).toBe('已处理');

    // 举报记录 → resolved
    expect(mockPrisma.report.updateMany).toHaveBeenCalledWith(
      expect.objectContaining({
        where: { targetType: 'post', targetId: 1, status: 'pending' },
        data: { status: 'resolved', resolvedAt: expect.any(Date) },
      })
    );

    // 内容 → 下架（status=0）
    expect(mockPrisma.post.updateMany).toHaveBeenCalledWith({ where: { id: 1 }, data: { status: 0 } });

    // 作者收「未通过审核，原因：…」+ 举报人收「你的举报已处理」= 2 条
    expect(mockPrisma.notification.create).toHaveBeenCalledTimes(2);
    const authorNotif = mockPrisma.notification.create.mock.calls[0][0];
    expect(authorNotif.data.userId).toBe(10);
    expect(authorNotif.data.content).toContain('未通过审核');
    expect(authorNotif.data.content).toContain('含广告推广');

    // 处置后按真实待处理数回写「举报中心」置顶消息（清零 → 文案更新且熄灭未读）
    expect(mockPrisma.report.count).toHaveBeenCalledWith({ where: { status: 'pending' } });
  });

  it('dismissed 成功：举报→dismissed + 内容恢复（0→1）+ 通知作者已通过审核', async () => {
    const res = await req(
      'POST',
      '/v1/admin/reports/resolve',
      { targetType: 'post', targetId: 1, action: 'dismissed' },
      authHeader(1)
    );
    expect(res.status).toBe(200);

    // 举报记录 → dismissed
    expect(mockPrisma.report.updateMany).toHaveBeenCalledWith(
      expect.objectContaining({
        data: { status: 'dismissed', resolvedAt: expect.any(Date) },
      })
    );

    // 内容因举报被下架 → 驳回时一并恢复（修「驳回后内容滞留」）
    expect(mockPrisma.post.updateMany).toHaveBeenCalledWith({ where: { id: 1, status: 0 }, data: { status: 1 } });

    // 作者收「已通过审核」
    const authorNotif = mockPrisma.notification.create.mock.calls[0][0];
    expect(authorNotif.data.userId).toBe(10);
    expect(authorNotif.data.content).toContain('已通过审核');
  });

  it('dismissed：内容本就未下架 → 不发作者通知（仅举报人收「已处理」）', async () => {
    mockPrisma.post.findUnique.mockResolvedValue({ id: 1, userId: 10, title: '已发布帖', status: 1 });
    const res = await req(
      'POST',
      '/v1/admin/reports/resolve',
      { targetType: 'post', targetId: 1, action: 'dismissed' },
      authHeader(1)
    );
    expect(res.status).toBe(200);
    expect(mockPrisma.post.updateMany).not.toHaveBeenCalled();
    expect(mockPrisma.notification.create).toHaveBeenCalledTimes(1);
    const onlyNotif = mockPrisma.notification.create.mock.calls[0][0];
    expect(onlyNotif.data.userId).toBe(2);
    expect(onlyNotif.data.content).toBe('你的举报已处理');
  });

  it('restore：内容恢复且不改举报状态；有 pending 举报 → 400', async () => {
    const okRes = await req(
      'POST',
      '/v1/admin/reports/resolve',
      { targetType: 'post', targetId: 1, action: 'restore' },
      authHeader(1)
    );
    expect(okRes.status).toBe(200);
    // 不动举报状态、不通知举报人；仅作者收「已通过审核」
    expect(mockPrisma.report.updateMany).not.toHaveBeenCalled();
    expect(mockPrisma.post.updateMany).toHaveBeenCalledWith({ where: { id: 1, status: 0 }, data: { status: 1 } });
    expect(mockPrisma.notification.create).toHaveBeenCalledTimes(1);
    expect(mockPrisma.notification.create.mock.calls[0][0].data.userId).toBe(10);

    mockPrisma.report.count.mockResolvedValue(2);
    const bad = await req(
      'POST',
      '/v1/admin/reports/resolve',
      { targetType: 'post', targetId: 1, action: 'restore' },
      authHeader(1)
    );
    expect(bad.status).toBe(400);
    expect(bad.json.message).toContain('仍有待处理举报');
  });

  it('restore 负例：user 目标 → 400（不支持）；内容未下架 → 400（无需恢复）', async () => {
    const userRes = await req(
      'POST',
      '/v1/admin/reports/resolve',
      { targetType: 'user', targetId: 5, action: 'restore' },
      authHeader(1)
    );
    expect(userRes.status).toBe(400);
    expect(userRes.json.message).toContain('不支持');

    mockPrisma.post.findUnique.mockResolvedValue({ id: 1, userId: 10, title: '已发布帖', status: 1 });
    const notDown = await req(
      'POST',
      '/v1/admin/reports/resolve',
      { targetType: 'post', targetId: 1, action: 'restore' },
      authHeader(1)
    );
    expect(notDown.status).toBe(400);
    expect(notDown.json.message).toContain('无需恢复');
  });
});
