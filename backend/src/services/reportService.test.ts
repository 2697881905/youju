// 举报服务单元测试：createReport + 阈值触发自动下架 + 幂等（unique 冲突）
// mock prisma + sensitiveWordService.checkText 返回 false（不依赖词库）
import { env } from '../config/env';
import { createReport, listReportsByTarget, resolveReportsByTarget, getReporterIdsByTarget } from './reportService';

// 管理员列表固定为 [99]，断言举报通知推送给管理员而非举报人
const ADMIN_IDS: number[] = [99];
beforeAll(() => {
  env.adminUserIds = ADMIN_IDS;
});
afterAll(() => {
  env.adminUserIds = [];
});

jest.mock('../prisma', () => ({
  prisma: {
    post: {
      findUnique: jest.fn(),
      update: jest.fn(),
    },
    comment: {
      findUnique: jest.fn(),
      update: jest.fn(),
    },
    user: {
      findUnique: jest.fn(),
    },
    report: {
      create: jest.fn(),
      findMany: jest.fn(),
      count: jest.fn(),
      updateMany: jest.fn(),
    },
    notification: {
      create: jest.fn(),
      findFirst: jest.fn(),
      update: jest.fn(),
    },
    // notificationPrefService（notifySystem 链路）依赖：默认无偏好记录 → 全部允许
    notificationPreference: {
      findUnique: jest.fn().mockResolvedValue(null),
    },
    $transaction: jest.fn(),
  },
}));

// mock sensitiveWordService，避免依赖词库文件
jest.mock('./sensitiveWordService', () => ({
  sensitiveWordService: {
    checkText: jest.fn().mockReturnValue(false),
    isLoaded: jest.fn().mockReturnValue(true),
  },
}));

// mock opsNotifier：单测不真正请求飞书 Webhook
jest.mock('./opsNotifier', () => ({
  notifyNewReport: jest.fn().mockResolvedValue(undefined),
}));

import { prisma } from '../prisma';
import { notifyNewReport } from './opsNotifier';
const mockPrisma = prisma as any;
const mockNotifyNewReport = notifyNewReport as jest.Mock;

describe('createReport - 帖子举报', () => {
  beforeEach(() => {
    jest.clearAllMocks();
    // 默认 post 存在
    mockPrisma.post.findUnique.mockResolvedValue({
      id: 1,
      userId: 10,
      title: '测试帖子',
    });
    // 默认 report.create 成功
    mockPrisma.report.create.mockResolvedValue({ id: 100, reporterId: 1, targetType: 'post', targetId: 1 });
    // 默认 post.update（increment reportCount）返回未达阈值
    mockPrisma.post.update.mockResolvedValue({ reportCount: 1, status: 1 });
    mockPrisma.notification.create.mockResolvedValue({});
    // 默认无既有「举报中心」置顶消息 → 走新建分支
    mockPrisma.notification.findFirst.mockResolvedValue(null);
    mockPrisma.report.count.mockResolvedValue(1);
    mockPrisma.$transaction.mockImplementation((callback: any) => callback(mockPrisma));
  });

  it('正常创建举报，未达阈值不触发下架', async () => {
    const result = await createReport({
      reporterId: 1,
      targetType: 'post',
      targetId: 1,
      reason: 'spam',
    });
    expect(result.autoTakenDown).toBe(false);
    expect(mockPrisma.report.create).toHaveBeenCalledTimes(1);
    expect(mockPrisma.post.update).toHaveBeenCalledTimes(1);
    // 不应触发自动下架相关通知
    const updateCall = mockPrisma.post.update.mock.calls[0][0];
    expect(updateCall.data.reportCount).toEqual({ increment: 1 });
    // 举报通知推送管理员（固定「举报中心」置顶消息），举报人/作者不收到受理回执
    expect(mockPrisma.notification.create).toHaveBeenCalledTimes(1);
    const ackArg = mockPrisma.notification.create.mock.calls[0][0];
    expect(ackArg.data.userId).toBe(99);
    expect(ackArg.data.actorId).toBeNull();
    expect(ackArg.data.type).toBe('system');
    expect(ackArg.data.pinned).toBe(true);
    expect(ackArg.data.content).toBe('举报中心：有 1 条举报待处理');
    // 但每次新举报都应推送运营通知（不阻塞，fire-and-forget）
    expect(mockNotifyNewReport).toHaveBeenCalledTimes(1);
    expect(mockNotifyNewReport).toHaveBeenCalledWith(
      expect.objectContaining({
        reportId: 100,
        targetType: 'post',
        targetId: 1,
        reportCount: 1,
        autoTakenDown: false,
      })
    );
  });

  it('reportCount 达阈值（3）触发自动下架 status=0 + notifySystem', async () => {
    // 第一次 update（increment）返回 reportCount=3
    mockPrisma.post.update.mockResolvedValueOnce({ reportCount: 3, status: 1 });

    const result = await createReport({
      reporterId: 2,
      targetType: 'post',
      targetId: 1,
      reason: 'spam',
    });
    expect(result.autoTakenDown).toBe(true);
    // 第二次 update 设置 status=0
    expect(mockPrisma.post.update).toHaveBeenCalledTimes(2);
    const secondCall = mockPrisma.post.update.mock.calls[1][0];
    expect(secondCall.data.status).toBe(0);
    // 两次通知：报举报中心置顶（管理员 userId=99）→ 自动下架审核（作者 userId=10），均置顶
    expect(mockPrisma.notification.create).toHaveBeenCalledTimes(2);
    const ackArg = mockPrisma.notification.create.mock.calls[0][0];
    expect(ackArg.data.userId).toBe(99);
    expect(ackArg.data.pinned).toBe(true);
    expect(ackArg.data.content).toContain('举报中心：有 1 条举报待处理');
    const notifArg = mockPrisma.notification.create.mock.calls[1][0];
    expect(notifArg.data.userId).toBe(10);
    expect(notifArg.data.type).toBe('system');
    expect(notifArg.data.pinned).toBe(true);
    expect(notifArg.data.content).toContain('正在审核中');
    // 运营通知携带下架信息
    expect(mockNotifyNewReport).toHaveBeenCalledTimes(1);
    expect(mockNotifyNewReport).toHaveBeenCalledWith(
      expect.objectContaining({ autoTakenDown: true, reportCount: 3 })
    );
  });

  it('帖子不存在抛 not_found', async () => {
    mockPrisma.post.findUnique.mockResolvedValue(null);
    await expect(
      createReport({
        reporterId: 1,
        targetType: 'post',
        targetId: 999,
        reason: 'spam',
      })
    ).rejects.toMatchObject({ reason: 'not_found' });
    expect(mockPrisma.report.create).not.toHaveBeenCalled();
  });

  it('重复举报（unique 冲突）抛 conflict', async () => {
    const conflictError = new Error('Unique constraint failed');
    (conflictError as any).code = 'P2002';
    mockPrisma.report.create.mockRejectedValue(conflictError);

    await expect(
      createReport({
        reporterId: 1,
        targetType: 'post',
        targetId: 1,
        reason: 'spam',
      })
    ).rejects.toMatchObject({ reason: 'conflict' });
  });

  it('reason=other 无 description 抛 validation', async () => {
    await expect(
      createReport({
        reporterId: 1,
        targetType: 'post',
        targetId: 1,
        reason: 'other',
        description: '',
      })
    ).rejects.toMatchObject({ reason: 'validation' });
    expect(mockPrisma.report.create).not.toHaveBeenCalled();
  });
});

describe('createReport - 评论举报', () => {
  beforeEach(() => {
    jest.clearAllMocks();
    mockPrisma.comment.findUnique.mockResolvedValue({
      id: 5,
      userId: 20,
      content: '测试评论',
    });
    mockPrisma.report.create.mockResolvedValue({ id: 101, reporterId: 1, targetType: 'comment', targetId: 5 });
    mockPrisma.comment.update.mockResolvedValue({ reportCount: 1, status: 1 });
    mockPrisma.notification.create.mockResolvedValue({});
    mockPrisma.$transaction.mockImplementation((callback: any) => callback(mockPrisma));
  });

  it('正常创建评论举报', async () => {
    const result = await createReport({
      reporterId: 1,
      targetType: 'comment',
      targetId: 5,
      reason: 'personal_attack',
    });
    expect(result.autoTakenDown).toBe(false);
    expect(mockPrisma.comment.update).toHaveBeenCalledTimes(1);
  });

  it('评论举报达阈值触发下架', async () => {
    mockPrisma.comment.update.mockResolvedValueOnce({ reportCount: 3, status: 1 });
    const result = await createReport({
      reporterId: 2,
      targetType: 'comment',
      targetId: 5,
      reason: 'personal_attack',
    });
    expect(result.autoTakenDown).toBe(true);
    expect(mockPrisma.comment.update).toHaveBeenCalledTimes(2);
    const secondCall = mockPrisma.comment.update.mock.calls[1][0];
    expect(secondCall.data.status).toBe(0);
  });
});

describe('createReport - 用户举报', () => {
  beforeEach(() => {
    jest.clearAllMocks();
    mockPrisma.user.findUnique.mockResolvedValue({ id: 30 });
    mockPrisma.report.create.mockResolvedValue({ id: 200, reporterId: 1, targetType: 'user', targetId: 30 });
    mockPrisma.notification.findFirst.mockResolvedValue(null);
    mockPrisma.report.count.mockResolvedValue(1);
    mockPrisma.$transaction.mockImplementation((callback: any) => callback(mockPrisma));
  });

  it('只落举报记录，不做自动下架，但仍推送运营通知', async () => {
    const result = await createReport({
      reporterId: 1,
      targetType: 'user',
      targetId: 30,
      reason: 'spam',
      description: '私信骚扰',
    });
    expect(result.autoTakenDown).toBe(false);
    // 无计数逻辑：不触碰 post/comment.update
    expect(mockPrisma.post.update).not.toHaveBeenCalled();
    expect(mockPrisma.comment.update).not.toHaveBeenCalled();
    // 举报通知推送管理员（固定「举报中心」置顶消息），不通知举报人/作者
    expect(mockPrisma.notification.create).toHaveBeenCalledTimes(1);
    const ackArg = mockPrisma.notification.create.mock.calls[0][0];
    expect(ackArg.data.userId).toBe(99);
    expect(ackArg.data.pinned).toBe(true);
    expect(ackArg.data.content).toContain('举报中心：有 1 条举报待处理');
    // 运营通知照常推送
    expect(mockNotifyNewReport).toHaveBeenCalledTimes(1);
    expect(mockNotifyNewReport).toHaveBeenCalledWith(
      expect.objectContaining({
        targetType: 'user',
        targetId: 30,
        description: '私信骚扰',
      })
    );
  });

  it('已存在「举报中心」置顶消息：再次举报走更新而非新建（不刷屏）', async () => {
    // 模拟第 2+ 次举报：管理员已有「举报中心」置顶消息
    mockPrisma.notification.findFirst.mockResolvedValue({ id: 55, userId: 99, type: 'system', pinned: true, content: '举报中心：有 1 条举报待处理' });
    mockPrisma.report.count.mockResolvedValue(4);
    mockPrisma.notification.update.mockResolvedValue({});
    const result = await createReport({
      reporterId: 1,
      targetType: 'user',
      targetId: 30,
      reason: 'spam',
      description: '持续骚扰',
    });
    expect(result.autoTakenDown).toBe(false);
    // 更新既有置顶消息，不新建
    expect(mockPrisma.notification.update).toHaveBeenCalledTimes(1);
    const updateArg = mockPrisma.notification.update.mock.calls[0][0];
    expect(updateArg.where.id).toBe(55);
    expect(updateArg.data).toEqual({ content: '举报中心：有 4 条举报待处理', read: false, pinned: true });
    expect(mockPrisma.notification.create).not.toHaveBeenCalled();
  });
});

describe('listReportsByTarget / resolveReportsByTarget / getReporterIdsByTarget', () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  it('listReportsByTarget 查询按 targetType + targetId', async () => {
    mockPrisma.report.findMany.mockResolvedValue([{ id: 1, reporterId: 1 }]);
    const result = await listReportsByTarget('post', 1);
    expect(result.length).toBe(1);
    expect(mockPrisma.report.findMany).toHaveBeenCalledWith(
      expect.objectContaining({
        where: { targetType: 'post', targetId: 1 },
      })
    );
  });

  it('resolveReportsByTarget 成立举报：事务内更新报告状态并下架帖子', async () => {
    const txReport = { updateMany: jest.fn().mockResolvedValue({ count: 2 }) };
    const txPost = { updateMany: jest.fn().mockResolvedValue({ count: 1 }) };
    const txComment = { updateMany: jest.fn().mockResolvedValue({ count: 1 }) };
    (mockPrisma.$transaction as jest.Mock).mockImplementation(
      async (cb: (tx: any) => Promise<void>) => cb({ report: txReport, post: txPost, comment: txComment })
    );
    await resolveReportsByTarget('post', 1, 'resolved');
    expect(txReport.updateMany).toHaveBeenCalledWith(
      expect.objectContaining({
        where: { targetType: 'post', targetId: 1, status: 'pending' },
        data: { status: 'resolved', resolvedAt: expect.any(Date) },
      })
    );
    expect(txPost.updateMany).toHaveBeenCalledWith({ where: { id: 1 }, data: { status: 0 } });
    expect(txComment.updateMany).not.toHaveBeenCalled();
  });

  it('resolveReportsByTarget 成立举报：下架评论（comment 目标）', async () => {
    const txReport = { updateMany: jest.fn().mockResolvedValue({ count: 1 }) };
    const txPost = { updateMany: jest.fn().mockResolvedValue({ count: 0 }) };
    const txComment = { updateMany: jest.fn().mockResolvedValue({ count: 1 }) };
    (mockPrisma.$transaction as jest.Mock).mockImplementation(
      async (cb: (tx: any) => Promise<void>) => cb({ report: txReport, post: txPost, comment: txComment })
    );
    await resolveReportsByTarget('comment', 7, 'resolved');
    expect(txComment.updateMany).toHaveBeenCalledWith({ where: { id: 7 }, data: { status: 0 } });
    expect(txPost.updateMany).not.toHaveBeenCalled();
  });

  it('resolveReportsByTarget 驳回举报：仅更新报告状态，不下架内容', async () => {
    const txReport = { updateMany: jest.fn().mockResolvedValue({ count: 1 }) };
    const txPost = { updateMany: jest.fn().mockResolvedValue({ count: 0 }) };
    const txComment = { updateMany: jest.fn().mockResolvedValue({ count: 0 }) };
    (mockPrisma.$transaction as jest.Mock).mockImplementation(
      async (cb: (tx: any) => Promise<void>) => cb({ report: txReport, post: txPost, comment: txComment })
    );
    await resolveReportsByTarget('post', 1, 'dismissed');
    expect(txReport.updateMany).toHaveBeenCalledWith(
      expect.objectContaining({
        where: { targetType: 'post', targetId: 1, status: 'pending' },
        data: { status: 'dismissed', resolvedAt: expect.any(Date) },
      })
    );
    expect(txPost.updateMany).not.toHaveBeenCalled();
    expect(txComment.updateMany).not.toHaveBeenCalled();
  });

  it('getReporterIdsByTarget 返回举报人 ID 数组', async () => {
    mockPrisma.report.findMany.mockResolvedValue([
      { reporterId: 1 },
      { reporterId: 2 },
      { reporterId: 3 },
    ]);
    const ids = await getReporterIdsByTarget('post', 1);
    expect(ids).toEqual([1, 2, 3]);
  });
});
