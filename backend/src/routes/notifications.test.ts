// 消息通知路由 + 服务集成测试（轻量 in-process HTTP，mock prisma，无需真实 DB）。
// 覆盖：
//   缺 token → 401；
//   GET /notifications（列表，含 actor include）；GET /unread-count；
//   POST /:id/read（非本人 → 403；本人 → 200 并 update）；
//   POST /read-all（updateMany）；
//   触发辅助 notifyOnComment / notifyOnInteract：自己操作自己不发通知，他人则发。
import express from 'express';
import * as http from 'http';
import jwt from 'jsonwebtoken';

import router from './notifications';
import * as notificationService from '../services/notificationService';
import { env } from '../config/env';
import { CODE } from '../utils/response';

jest.mock('../prisma', () => ({
  prisma: {
    notification: {
      create: jest.fn(),
      findMany: jest.fn(),
      count: jest.fn(),
      findUnique: jest.fn(),
      update: jest.fn(),
      updateMany: jest.fn(),
    },
    post: {
      findUnique: jest.fn(),
      findMany: jest.fn(),
    },
    user: {
      findUnique: jest.fn().mockResolvedValue({ deletedAt: null }),
      findMany: jest.fn(),
    },
    // notificationPrefService（notifyOnComment/Interact 链路）依赖：默认无偏好记录 → 全部允许
    notificationPreference: {
      findUnique: jest.fn().mockResolvedValue(null),
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
  app.use('/v1', router);
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

describe('GET/POST /v1/notifications', () => {
  it('缺 Authorization → UNAUTHORIZED(401)', async () => {
    const res = await req('GET', '/v1/notifications');
    expect(res.status).toBe(401);
    expect(res.json.code).toBe(CODE.UNAUTHORIZED);
  });

  it('GET /notifications → 返回列表并 include actor', async () => {
    mockPrisma.notification.findMany.mockResolvedValue([
      { id: 1, userId: 1, actorId: 2, type: 'comment', postId: 10, content: '张三 评论了你的帖子', read: false, createdAt: new Date() },
    ]);
    // 帖子类通知需校验帖子仍有效：visiblePostIds 收集 postId=10 → post.findMany 返回有效帖子
    mockPrisma.post.findMany.mockResolvedValue([{ id: 10 }]);
    mockPrisma.notification.count.mockResolvedValue(1);
    // listForUser 用 user.findMany 按需补全 actor 信息
    mockPrisma.user.findMany.mockResolvedValue([{ id: 2, nickname: '张三', avatar: null }]);

    const res = await req('GET', '/v1/notifications?page=1&limit=20', undefined, authHeader());
    expect(res.status).toBe(200);
    expect(res.json.code).toBe(0);
    const list = res.json.data.list as any[];
    expect(list.length).toBe(1);
    expect(list[0].content).toBe('张三 评论了你的帖子');
    expect(list[0].actor.nickname).toBe('张三');
    // 帖子类通知仅在帖子仍有效时返回：where 含 OR（非帖子类通知 或 帖子仍有效）
    expect(mockPrisma.notification.findMany).toHaveBeenCalledWith(
      expect.objectContaining({
        where: {
          userId: TEST_USER_ID,
          OR: [
            { type: { notIn: ['comment', 'up', 'bookmark'] } },
            { postId: { in: [10] } },
          ],
        },
        orderBy: [{ pinned: 'desc' }, { createdAt: 'desc' }],
      }),
    );
    expect(mockPrisma.user.findMany).toHaveBeenCalledWith(
      expect.objectContaining({ where: { id: { in: [2] } } }),
    );
  });

  it('GET /notifications → 帖子已删除(软删除/彻底删除)的帖子类通知被过滤', async () => {
    // 收集可见 postId 时返回两条帖子类通知；实际列表查询也返回同一批行（同一 mock）
    mockPrisma.notification.findMany.mockResolvedValue([
      { id: 1, userId: 1, actorId: 2, type: 'comment', postId: 10, content: '张三 评论了你的帖子', read: false, createdAt: new Date() },
      { id: 2, userId: 1, actorId: 3, type: 'up', postId: 11, content: '李四 顶了你的帖子', read: false, createdAt: new Date() },
    ]);
    // 只有帖子 10 仍有效；帖子 11 已删除 → 通知 2 应被过滤
    mockPrisma.post.findMany.mockResolvedValue([{ id: 10 }]);
    mockPrisma.notification.count.mockResolvedValue(1);
    mockPrisma.user.findMany.mockResolvedValue([{ id: 2, nickname: '张三', avatar: null }]);

    const res = await req('GET', '/v1/notifications?page=1&limit=20', undefined, authHeader());
    expect(res.status).toBe(200);
    // 列表查询 where 的 OR 只放行「非帖子类」或「帖子仍有效(postId=10)」的通知
    expect(mockPrisma.notification.findMany).toHaveBeenCalledWith(
      expect.objectContaining({
        where: {
          userId: TEST_USER_ID,
          OR: [
            { type: { notIn: ['comment', 'up', 'bookmark'] } },
            { postId: { in: [10] } },
          ],
        },
      }),
    );
  });

  it('GET /unread-count → 返回未读数（同样过滤已删除帖子的通知）', async () => {
    // 无任何帖子类通知 → visiblePostIds 为空 → 仅保留非帖子类通知的未读数
    mockPrisma.notification.findMany.mockResolvedValue([]);
    mockPrisma.notification.count.mockResolvedValue(3);
    const res = await req('GET', '/v1/notifications/unread-count', undefined, authHeader());
    expect(res.status).toBe(200);
    expect(res.json.code).toBe(0);
    expect(res.json.data.count).toBe(3);
    expect(mockPrisma.notification.count).toHaveBeenCalledWith(
      expect.objectContaining({
        where: { userId: TEST_USER_ID, read: false, type: { notIn: ['comment', 'up', 'bookmark'] } },
      }),
    );
  });

  it('POST /:id/read 非本人 → FORBIDDEN(403)', async () => {
    mockPrisma.notification.findUnique.mockResolvedValue({ id: 1, userId: 99, read: false });
    const res = await req('POST', '/v1/notifications/1/read', undefined, authHeader());
    expect(res.status).toBe(403);
    expect(res.json.code).toBe(CODE.FORBIDDEN);
    expect(mockPrisma.notification.update).not.toHaveBeenCalled();
  });

  it('POST /:id/read 本人 → 200 并标记已读', async () => {
    mockPrisma.notification.findUnique.mockResolvedValue({ id: 1, userId: TEST_USER_ID, read: false });
    mockPrisma.notification.update.mockResolvedValue({});
    const res = await req('POST', '/v1/notifications/1/read', undefined, authHeader());
    expect(res.status).toBe(200);
    expect(res.json.code).toBe(0);
    expect(mockPrisma.notification.update).toHaveBeenCalledWith(
      expect.objectContaining({ where: { id: 1 }, data: { read: true } }),
    );
  });

  it('POST /read-all → updateMany 全部已读', async () => {
    mockPrisma.notification.updateMany.mockResolvedValue({ count: 4 });
    const res = await req('POST', '/v1/notifications/read-all', undefined, authHeader());
    expect(res.status).toBe(200);
    expect(res.json.code).toBe(0);
    expect(mockPrisma.notification.updateMany).toHaveBeenCalledWith(
      expect.objectContaining({ where: { userId: TEST_USER_ID, read: false }, data: { read: true } }),
    );
  });
});

describe('触发辅助函数', () => {
  it('notifyOnComment：自己评论自己不发通知', async () => {
    mockPrisma.post.findUnique.mockResolvedValue({ userId: 1 });
    await notificationService.notifyOnComment(10, 1);
    expect(mockPrisma.notification.create).not.toHaveBeenCalled();
  });

  it('notifyOnComment：他人评论自己帖子则发通知（含昵称文案）', async () => {
    mockPrisma.post.findUnique.mockResolvedValue({ userId: 1 });
    mockPrisma.user.findUnique.mockResolvedValue({ nickname: '张三' });
    mockPrisma.notification.create.mockResolvedValue({});
    await notificationService.notifyOnComment(10, 2);
    expect(mockPrisma.notification.create).toHaveBeenCalledTimes(1);
    const arg = mockPrisma.notification.create.mock.calls[0][0];
    expect(arg.data.userId).toBe(1);
    expect(arg.data.actorId).toBe(2);
    expect(arg.data.type).toBe('comment');
    expect(arg.data.content).toBe('张三 评论了你的帖子');
  });

  it('notifyOnInteract up：他人顶帖发通知', async () => {
    mockPrisma.post.findUnique.mockResolvedValue({ userId: 1 });
    mockPrisma.user.findUnique.mockResolvedValue({ nickname: '李四' });
    mockPrisma.notification.create.mockResolvedValue({});
    await notificationService.notifyOnInteract(10, 3, 'up');
    const arg = mockPrisma.notification.create.mock.calls[0][0];
    expect(arg.data.userId).toBe(1);
    expect(arg.data.type).toBe('up');
    expect(arg.data.content).toBe('李四 顶了你的帖子');
  });

  it('notifyOnInteract bookmark：自己收藏自己不发通知', async () => {
    mockPrisma.post.findUnique.mockResolvedValue({ userId: 5 });
    await notificationService.notifyOnInteract(10, 5, 'bookmark');
    expect(mockPrisma.notification.create).not.toHaveBeenCalled();
  });
});
