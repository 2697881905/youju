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
      updateMany: jest.fn(),
    },
    comment: {
      findUnique: jest.fn(),
      findMany: jest.fn().mockResolvedValue([]),
      update: jest.fn(),
      updateMany: jest.fn(),
    },
    user: {
      findUnique: jest.fn(),
    },
    report: {
      create: jest.fn(),
      findMany: jest.fn(),
      count: jest.fn(),
      updateMany: jest.fn(),
      // 举报中心待处理数按 targetType 分类统计（countPendingReportsByType）
      groupBy: jest.fn(),
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
    // 举报中心文案按板块分流：帖子 1 条待处理
    mockPrisma.report.groupBy.mockResolvedValue([{ targetType: 'post', _count: 1 }]);
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
    expect(ackArg.data.content).toBe('举报中心：帖子 1 · 评论 0 · 用户 0 待处理');
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
    expect(ackArg.data.content).toContain('举报中心：帖子 1 · 评论 0 · 用户 0 待处理');
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
      postId: 5,
    });
    mockPrisma.report.create.mockResolvedValue({ id: 101, reporterId: 1, targetType: 'comment', targetId: 5 });
    mockPrisma.comment.update.mockResolvedValue({ reportCount: 1, status: 1 });
    mockPrisma.comment.updateMany.mockResolvedValue({ count: 1 });
    mockPrisma.post.update.mockResolvedValue({});
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
    // reportCount increment 一次；下架改走条件 updateMany，并扣减帖子评论数
    expect(mockPrisma.comment.update).toHaveBeenCalledTimes(1);
    expect(mockPrisma.comment.updateMany).toHaveBeenCalledWith({ where: { id: { in: [5] }, status: 1 }, data: { status: 0 } });
    expect(mockPrisma.post.update).toHaveBeenCalledWith({ where: { id: 5 }, data: { commentCount: { decrement: 1 } } });
  });
});

describe('createReport - 用户举报', () => {
  beforeEach(() => {
    jest.clearAllMocks();
    mockPrisma.user.findUnique.mockResolvedValue({ id: 30 });
    mockPrisma.report.create.mockResolvedValue({ id: 200, reporterId: 1, targetType: 'user', targetId: 30 });
    mockPrisma.notification.findFirst.mockResolvedValue(null);
    mockPrisma.report.count.mockResolvedValue(1);
    // 举报中心文案按板块分流：用户 1 条待处理
    mockPrisma.report.groupBy.mockResolvedValue([{ targetType: 'user', _count: 1 }]);
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
    expect(ackArg.data.content).toContain('举报中心：帖子 0 · 评论 0 · 用户 1 待处理');
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
    mockPrisma.report.groupBy.mockResolvedValue([{ targetType: 'user', _count: 4 }]);
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
    expect(updateArg.data).toEqual({ content: '举报中心：帖子 0 · 评论 0 · 用户 4 待处理', read: false, pinned: true });
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

  // 构造事务 tx mock：统一入口需要 findUnique（目标快照）+ updateMany（状态流转）+ count/findMany
  function makeTx(opts: { postStatus?: number; commentStatus?: number; pendingCount?: number; reporters?: number[] } = {}): any {
    return {
      post: {
        findUnique: jest.fn().mockResolvedValue({
          id: 1, userId: 10, title: '测试帖子', status: opts.postStatus ?? 0,
        }),
        updateMany: jest.fn().mockResolvedValue({ count: 1 }),
        update: jest.fn().mockResolvedValue({}),
      },
      comment: {
        findUnique: jest.fn().mockResolvedValue({
          id: 7, userId: 11, postId: 5, status: opts.commentStatus ?? 0,
        }),
        findMany: jest.fn().mockResolvedValue([]),
        updateMany: jest.fn().mockResolvedValue({ count: 1 }),
      },
      user: { findUnique: jest.fn().mockResolvedValue({ id: 30 }) },
      report: {
        updateMany: jest.fn().mockResolvedValue({ count: 1 }),
        count: jest.fn().mockResolvedValue(opts.pendingCount ?? 0),
        findMany: jest.fn().mockResolvedValue((opts.reporters ?? [2]).map((rid) => ({ reporterId: rid }))),
      },
    };
  }

  function useTx(tx: any): void {
    (mockPrisma.$transaction as jest.Mock).mockImplementation(async (cb: (t: any) => Promise<void>) => cb(tx));
  }

  it('resolved（post）：举报→resolved + 内容下架 + 作者收「未通过审核（原因）」+ 举报人收「已处理」', async () => {
    const tx = makeTx();
    useTx(tx);
    await resolveReportsByTarget('post', 1, 'resolved', '含广告推广');

    expect(tx.report.updateMany).toHaveBeenCalledWith(
      expect.objectContaining({
        where: { targetType: 'post', targetId: 1, status: 'pending' },
        data: { status: 'resolved', resolvedAt: expect.any(Date) },
      })
    );
    // 成立即下架（0），不写 2
    expect(tx.post.updateMany).toHaveBeenCalledWith({ where: { id: 1 }, data: { status: 0 } });
    expect(tx.comment.updateMany).not.toHaveBeenCalled();

    // 作者通知（含原因）+ 举报人通知 = 2 条
    expect(mockPrisma.notification.create).toHaveBeenCalledTimes(2);
    const authorNotif = mockPrisma.notification.create.mock.calls[0][0];
    expect(authorNotif.data.userId).toBe(10);
    expect(authorNotif.data.content).toBe('你的帖子《测试帖子》未通过审核，原因：含广告推广');
    const reporterNotif = mockPrisma.notification.create.mock.calls[1][0];
    expect(reporterNotif.data.userId).toBe(2);
    expect(reporterNotif.data.content).toBe('你的举报已处理');
  });

  it('resolved（comment）：下架评论 + 作者通知挂到所属帖子', async () => {
    const tx = makeTx();
    useTx(tx);
    await resolveReportsByTarget('comment', 7, 'resolved');

    expect(tx.comment.updateMany).toHaveBeenCalledWith({ where: { id: { in: [7] }, status: 1 }, data: { status: 0 } });
    expect(tx.post.updateMany).not.toHaveBeenCalled();
    // 评论下架 → 帖子评论数 -1：评论区计数与实际可见评论保持一致
    expect(tx.post.update).toHaveBeenCalledWith({ where: { id: 5 }, data: { commentCount: { decrement: 1 } } });
    const authorNotif = mockPrisma.notification.create.mock.calls[0][0];
    expect(authorNotif.data.userId).toBe(11);
    expect(authorNotif.data.content).toBe('你的评论未通过审核');
    expect(authorNotif.data.postId).toBe(5);
  });

  it('resolved（comment）：评论已被阈值下架（updateMany 命中 0）→ 不重复扣减评论数', async () => {
    const tx = makeTx();
    tx.comment.updateMany.mockResolvedValue({ count: 0 });
    useTx(tx);
    await resolveReportsByTarget('comment', 7, 'resolved');

    expect(tx.post.update).not.toHaveBeenCalled();
  });

  it('dismissed（comment）：评论恢复展示（0→1）→ 补回帖子评论数', async () => {
    const tx = makeTx({ commentStatus: 0 });
    tx.comment.updateMany
      .mockResolvedValueOnce({ count: 1 })  // root 0→1
      .mockResolvedValueOnce({ count: 0 }); // 级联恢复后代（无）
    useTx(tx);
    await resolveReportsByTarget('comment', 7, 'dismissed');

    expect(tx.comment.updateMany).toHaveBeenCalledWith({ where: { id: 7, status: 0 }, data: { status: 1 } });
    expect(tx.comment.updateMany).toHaveBeenCalledWith({ where: { id: { in: [7] }, status: 0 }, data: { status: 1 } });
    expect(tx.post.update).toHaveBeenCalledWith({ where: { id: 5 }, data: { commentCount: { increment: 1 } } });
  });

  it('restore（comment）：评论恢复展示（0→1）→ 补回帖子评论数', async () => {
    const tx = makeTx({ commentStatus: 0 });
    tx.comment.updateMany
      .mockResolvedValueOnce({ count: 1 })  // root 0→1
      .mockResolvedValueOnce({ count: 0 }); // 级联恢复后代（无）
    useTx(tx);
    await resolveReportsByTarget('comment', 7, 'restore');

    expect(tx.post.update).toHaveBeenCalledWith({ where: { id: 5 }, data: { commentCount: { increment: 1 } } });
  });

  it('dismissed：举报驳回 + 内容从下架恢复（0→1）+ 作者收「已通过审核」', async () => {
    const tx = makeTx({ postStatus: 0 });
    useTx(tx);
    await resolveReportsByTarget('post', 1, 'dismissed');

    expect(tx.report.updateMany).toHaveBeenCalledWith(
      expect.objectContaining({
        data: { status: 'dismissed', resolvedAt: expect.any(Date) },
      })
    );
    // 修「驳回后内容滞留在处置台之外」：一并恢复展示
    expect(tx.post.updateMany).toHaveBeenCalledWith({ where: { id: 1, status: 0 }, data: { status: 1 } });
    const authorNotif = mockPrisma.notification.create.mock.calls[0][0];
    expect(authorNotif.data.userId).toBe(10);
    expect(authorNotif.data.content).toBe('你的帖子《测试帖子》已通过审核');
  });

  it('dismissed：内容本就未下架 → 不碰内容、不发作者通知（仅举报人收「已处理」）', async () => {
    const tx = makeTx({ postStatus: 1 });
    useTx(tx);
    await resolveReportsByTarget('post', 1, 'dismissed');

    expect(tx.post.updateMany).not.toHaveBeenCalled();
    expect(mockPrisma.notification.create).toHaveBeenCalledTimes(1);
    expect(mockPrisma.notification.create.mock.calls[0][0].data.userId).toBe(2);
  });

  it('dismissed：举报人即作者 → 只发作者一条（自举报不重复打扰）', async () => {
    const tx = makeTx({ postStatus: 0, reporters: [10] });
    useTx(tx);
    await resolveReportsByTarget('post', 1, 'dismissed');

    expect(mockPrisma.notification.create).toHaveBeenCalledTimes(1);
    const onlyNotif = mockPrisma.notification.create.mock.calls[0][0];
    expect(onlyNotif.data.userId).toBe(10);
    expect(onlyNotif.data.content).toBe('你的帖子《测试帖子》已通过审核');
  });

  it('restore：仅恢复内容（0→1）+ 作者收「已通过审核」；不改举报状态、不通知举报人', async () => {
    const tx = makeTx({ postStatus: 0 });
    useTx(tx);
    await resolveReportsByTarget('post', 1, 'restore');

    expect(tx.report.updateMany).not.toHaveBeenCalled();
    expect(tx.post.updateMany).toHaveBeenCalledWith({ where: { id: 1, status: 0 }, data: { status: 1 } });
    expect(mockPrisma.notification.create).toHaveBeenCalledTimes(1);
    expect(mockPrisma.notification.create.mock.calls[0][0].data.userId).toBe(10);
  });

  it('restore：仍有 pending 举报 → 拒绝且不改内容', async () => {
    const tx = makeTx({ pendingCount: 1 });
    useTx(tx);
    await expect(resolveReportsByTarget('post', 1, 'restore')).rejects.toMatchObject({ reason: 'has_pending' });
    expect(tx.post.updateMany).not.toHaveBeenCalled();
  });

  it('restore：user 目标不支持 / 内容未下架 → 各自拒绝', async () => {
    const txUser = makeTx();
    useTx(txUser);
    await expect(resolveReportsByTarget('user', 30, 'restore')).rejects.toMatchObject({ reason: 'invalid_target' });

    const txDown = makeTx({ postStatus: 1 });
    useTx(txDown);
    await expect(resolveReportsByTarget('post', 1, 'restore')).rejects.toMatchObject({ reason: 'not_taken_down' });
  });

  it('resolved（user）：不碰内容、无作者通知，举报人仍收「已处理」', async () => {
    const tx = makeTx();
    useTx(tx);
    await resolveReportsByTarget('user', 30, 'resolved');

    expect(tx.post.updateMany).not.toHaveBeenCalled();
    expect(tx.comment.updateMany).not.toHaveBeenCalled();
    expect(mockPrisma.notification.create).toHaveBeenCalledTimes(1);
    const onlyNotif = mockPrisma.notification.create.mock.calls[0][0];
    expect(onlyNotif.data.userId).toBe(2);
    expect(onlyNotif.data.content).toBe('你的举报已处理');
    expect(onlyNotif.data.postId).toBeNull();
  });

  it('处置后同步「举报中心」：待处理清零 → 文案改「暂无待处理举报」并熄灭未读', async () => {
    const tx = makeTx();
    useTx(tx);
    mockPrisma.report.groupBy.mockResolvedValue([]);
    mockPrisma.notification.findFirst.mockResolvedValue({
      id: 55, userId: 99, type: 'system', pinned: true, content: '举报中心：有 1 条举报待处理',
    });
    mockPrisma.notification.update.mockResolvedValue({});

    await resolveReportsByTarget('post', 1, 'dismissed');

    // 处置后按真实待处理数回写：缺这一步消息中心会一直挂着旧数字（用户报障）
    expect(mockPrisma.report.groupBy).toHaveBeenCalledWith({
      by: ['targetType'],
      where: { status: 'pending' },
      _count: true,
    });
    expect(mockPrisma.notification.update).toHaveBeenCalledWith({
      where: { id: 55 },
      data: { content: '举报中心：暂无待处理举报', pinned: true, read: true },
    });
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
