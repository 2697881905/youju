// 举报服务单元测试：createReport + 阈值触发自动下架 + 幂等（unique 冲突）
// mock prisma + sensitiveWordService.checkText 返回 false（不依赖词库）
import { createReport, listReportsByTarget, resolveReportsByTarget, getReporterIdsByTarget } from './reportService';

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
    report: {
      create: jest.fn(),
      findMany: jest.fn(),
      count: jest.fn(),
      updateMany: jest.fn(),
    },
    notification: {
      create: jest.fn(),
    },
    // notificationPrefService（notifySystem 链路）依赖：默认无偏好记录 → 全部允许
    notificationPreference: {
      findUnique: jest.fn().mockResolvedValue(null),
    },
  },
}));

// mock sensitiveWordService，避免依赖词库文件
jest.mock('./sensitiveWordService', () => ({
  sensitiveWordService: {
    checkText: jest.fn().mockReturnValue(false),
    isLoaded: jest.fn().mockReturnValue(true),
  },
}));

import { prisma } from '../prisma';
const mockPrisma = prisma as any;

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
    // 仅 increment reportCount，不应再 update status=0
    const updateCall = mockPrisma.post.update.mock.calls[0][0];
    expect(updateCall.data.reportCount).toEqual({ increment: 1 });
    // 不应触发 notifySystem（notification.create 未被调用）
    expect(mockPrisma.notification.create).not.toHaveBeenCalled();
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
    // notifySystem 通知作者
    expect(mockPrisma.notification.create).toHaveBeenCalledTimes(1);
    const notifArg = mockPrisma.notification.create.mock.calls[0][0];
    expect(notifArg.data.userId).toBe(10);
    expect(notifArg.data.type).toBe('system');
    expect(notifArg.data.content).toContain('正在审核中');
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

  it('resolveReportsByTarget 批量更新 pending 举报状态', async () => {
    mockPrisma.report.updateMany.mockResolvedValue({ count: 2 });
    await resolveReportsByTarget('post', 1, 'resolved');
    expect(mockPrisma.report.updateMany).toHaveBeenCalledWith(
      expect.objectContaining({
        where: { targetType: 'post', targetId: 1, status: 'pending' },
        data: { status: 'resolved', resolvedAt: expect.any(Date) },
      })
    );
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
