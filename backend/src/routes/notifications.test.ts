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
      groupBy: jest.fn(),
    },
    post: {
      findUnique: jest.fn(),
      findMany: jest.fn(),
    },
    comment: {
      findUnique: jest.fn(),
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
            { type: { notIn: ['comment', 'up', 'bookmark', 'mention'] } },
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
            { type: { notIn: ['comment', 'up', 'bookmark', 'mention'] } },
            { postId: { in: [10] } },
          ],
        },
      }),
    );
  });

  it('GET /notifications?type=system → 按类型筛选（AND 合并，不覆盖帖子有效性约束）', async () => {
    mockPrisma.notification.findMany.mockResolvedValue([
      { id: 5, userId: 1, actorId: null, type: 'system', postId: null, content: '你的帖子《x》已通过审核', read: false, createdAt: new Date() },
    ]);
    mockPrisma.post.findMany.mockResolvedValue([]);
    mockPrisma.notification.count.mockResolvedValue(1);

    const res = await req('GET', '/v1/notifications?page=1&limit=20&type=system', undefined, authHeader());
    expect(res.status).toBe(200);
    expect(res.json.data.list[0].type).toBe('system');
    expect(mockPrisma.notification.findMany).toHaveBeenCalledWith(
      expect.objectContaining({
        where: {
          AND: [
            { userId: TEST_USER_ID, type: { notIn: ['comment', 'up', 'bookmark', 'mention'] } },
            { type: 'system' },
          ],
        },
      }),
    );
  });

  it('GET /notifications?type=非法值 → 忽略类型筛选（优雅降级为不过滤）', async () => {
    mockPrisma.notification.findMany.mockResolvedValue([]);
    mockPrisma.notification.count.mockResolvedValue(0);

    const res = await req('GET', '/v1/notifications?page=1&limit=20&type=hack', undefined, authHeader());
    expect(res.status).toBe(200);
    expect(mockPrisma.notification.findMany).toHaveBeenCalledWith(
      expect.objectContaining({
        where: { userId: TEST_USER_ID, type: { notIn: ['comment', 'up', 'bookmark', 'mention'] } },
      }),
    );
  });

  it('GET /unread-count → 返回未读数 + 按类型分布（同样过滤已删除帖子的通知）', async () => {
    // 无任何帖子类通知 → visiblePostIds 为空 → 仅保留非帖子类通知的未读数
    mockPrisma.notification.findMany.mockResolvedValue([]);
    mockPrisma.notification.count.mockResolvedValue(3);
    // byType：groupBy 按类型聚合未读（消息页三类快捷筛选红点的数据源）
    mockPrisma.notification.groupBy.mockResolvedValue([
      { type: 'comment', _count: { _all: 2 } },
      { type: 'follow', _count: { _all: 1 } },
    ]);
    const res = await req('GET', '/v1/notifications/unread-count', undefined, authHeader());
    expect(res.status).toBe(200);
    expect(res.json.code).toBe(0);
    expect(res.json.data.count).toBe(3);
    expect(res.json.data.byType).toEqual({
      comment: 2, up: 0, bookmark: 0, follow: 1, mention: 0, system: 0,
    });
    expect(mockPrisma.notification.count).toHaveBeenCalledWith(
      expect.objectContaining({
        where: { userId: TEST_USER_ID, read: false, type: { notIn: ['comment', 'up', 'bookmark', 'mention'] } },
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
    await notificationService.notifyOnComment(10, 1, 88);
    expect(mockPrisma.notification.create).not.toHaveBeenCalled();
  });

  it('notifyOnComment：他人评论自己帖子则发通知（含昵称文案 + 评论 id 定位）', async () => {
    mockPrisma.post.findUnique.mockResolvedValue({ userId: 1 });
    mockPrisma.user.findUnique.mockResolvedValue({ nickname: '张三' });
    mockPrisma.notification.create.mockResolvedValue({});
    await notificationService.notifyOnComment(10, 2, 88);
    expect(mockPrisma.notification.create).toHaveBeenCalledTimes(1);
    const arg = mockPrisma.notification.create.mock.calls[0][0];
    expect(arg.data.userId).toBe(1);
    expect(arg.data.actorId).toBe(2);
    expect(arg.data.type).toBe('comment');
    expect(arg.data.postId).toBe(10);
    expect(arg.data.commentId).toBe(88);
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

  it('notifyOnCommentReply：自己回复自己不发通知', async () => {
    await notificationService.notifyOnCommentReply(10, 2, 2, 89);
    expect(mockPrisma.notification.create).not.toHaveBeenCalled();
  });

  it('notifyOnCommentReply：他人回复我的评论 → 发通知（含文案/postId/回复id）', async () => {
    mockPrisma.post.findUnique.mockResolvedValue({ userId: 3 }); // 帖子作者是第三人，与被回复人不同
    mockPrisma.user.findUnique.mockResolvedValue({ nickname: '李四' });
    mockPrisma.notification.create.mockResolvedValue({});
    await notificationService.notifyOnCommentReply(10, 2, 1, 89);
    expect(mockPrisma.notification.create).toHaveBeenCalledTimes(1);
    const arg = mockPrisma.notification.create.mock.calls[0][0];
    expect(arg.data.userId).toBe(1);
    expect(arg.data.actorId).toBe(2);
    expect(arg.data.type).toBe('comment');
    expect(arg.data.postId).toBe(10);
    expect(arg.data.commentId).toBe(89);
    expect(arg.data.content).toBe('李四 回复了你的评论');
  });

  it('notifyOnCommentReply：被回复人即帖子作者 → 不重复发（已有「评论了你的帖子」）', async () => {
    mockPrisma.post.findUnique.mockResolvedValue({ userId: 1 });
    await notificationService.notifyOnCommentReply(10, 2, 1, 89);
    expect(mockPrisma.notification.create).not.toHaveBeenCalled();
  });

  it('notifyOnCommentUp：他人赞我的评论 → 通知带 postId + commentId（点击定位该评论）', async () => {
    mockPrisma.comment.findUnique.mockResolvedValue({ userId: 1, postId: 10 });
    mockPrisma.user.findUnique.mockResolvedValue({ nickname: '李四' });
    mockPrisma.notification.create.mockResolvedValue({});
    await notificationService.notifyOnCommentUp(88, 3);
    expect(mockPrisma.notification.create).toHaveBeenCalledTimes(1);
    const arg = mockPrisma.notification.create.mock.calls[0][0];
    expect(arg.data.userId).toBe(1);
    expect(arg.data.type).toBe('up');
    expect(arg.data.postId).toBe(10);
    expect(arg.data.commentId).toBe(88);
    expect(arg.data.content).toBe('李四 赞了你的评论');
  });

  it('notifyOnCommentUp：自己赞自己评论不发通知', async () => {
    mockPrisma.comment.findUnique.mockResolvedValue({ userId: 3, postId: 10 });
    await notificationService.notifyOnCommentUp(88, 3);
    expect(mockPrisma.notification.create).not.toHaveBeenCalled();
  });

  it('notifySystem：评论类系统消息同时落 postId + commentId（点击精准定位）', async () => {
    mockPrisma.notification.create.mockResolvedValue({});
    await notificationService.notifySystem(5, '你的评论未通过审核', 10, undefined, 88);
    expect(mockPrisma.notification.create).toHaveBeenCalledTimes(1);
    const arg = mockPrisma.notification.create.mock.calls[0][0];
    expect(arg.data.userId).toBe(5);
    expect(arg.data.type).toBe('system');
    expect(arg.data.postId).toBe(10);
    expect(arg.data.commentId).toBe(88);
    expect(arg.data.content).toBe('你的评论未通过审核');
  });

  it('notifyCommentMentions：@提及 发 mention 通知并携带 commentId（点击可定位到该评论）', async () => {
    mockPrisma.user.findUnique.mockResolvedValue({ nickname: '张三' });
    mockPrisma.notification.create.mockResolvedValue({});
    await notificationService.notifyCommentMentions(10, 88, 2, '谢谢 @张三', new Set<number>([2]), [{ name: '张三', userId: 1 }]);
    expect(mockPrisma.notification.create).toHaveBeenCalledTimes(1);
    const arg = mockPrisma.notification.create.mock.calls[0][0];
    expect(arg.data.userId).toBe(1);
    expect(arg.data.actorId).toBe(2);
    expect(arg.data.type).toBe('mention');
    expect(arg.data.postId).toBe(10);
    expect(arg.data.commentId).toBe(88);
    expect(arg.data.content).toBe('张三 在评论中提到了你');
  });

  it('notifyCommentMentions：排除集命中时不发通知（自己/帖子作者不重复打扰）', async () => {
    mockPrisma.user.findUnique.mockResolvedValue({ nickname: '张三' });
    await notificationService.notifyCommentMentions(10, 88, 3, '@张三 你好', new Set<number>([3, 1]), [{ name: '张三', userId: 1 }]);
    expect(mockPrisma.notification.create).not.toHaveBeenCalled();
  });

  it('notifyOnCommentReply：被回复人 userId 恰等于帖子 ID → 仍正常发通知（旧「拿帖子ID比对」bug 回归）', async () => {
    // 回归场景：postId=7、被回复人 userId=7（非帖子作者），旧实现会误判为「作者已通知」而漏发
    mockPrisma.post.findUnique.mockResolvedValue({ userId: 3 });
    mockPrisma.user.findUnique.mockResolvedValue({ nickname: '王五' });
    mockPrisma.notification.create.mockResolvedValue({});
    await notificationService.notifyOnCommentReply(7, 2, 7, 89);
    expect(mockPrisma.notification.create).toHaveBeenCalledTimes(1);
    const arg = mockPrisma.notification.create.mock.calls[0][0];
    expect(arg.data.userId).toBe(7);
    expect(arg.data.commentId).toBe(89);
    expect(arg.data.content).toBe('王五 回复了你的评论');
  });
});
