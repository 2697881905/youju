import { createAppeal, listMyAppeals, listAppeals, reviewAppeal } from './appealService';
import { prisma } from '../prisma';
import { resolveReportsByTarget } from './reportService';

// 申诉服务单测：Prisma 与举报处置全部替身，只验证申诉流程的门控和审批分支。
jest.mock('../prisma', () => ({
  prisma: {
    post: { findUnique: jest.fn() },
    comment: { findUnique: jest.fn() },
    appeal: {
      create: jest.fn(),
      findUnique: jest.fn(),
      findMany: jest.fn().mockResolvedValue([]),
      update: jest.fn().mockResolvedValue({}),
    },
  },
}));

jest.mock('./reportService', () => ({
  resolveReportsByTarget: jest.fn().mockResolvedValue(undefined),
}));

const mockedPostFind = prisma.post.findUnique as jest.Mock;
const mockedCommentFind = prisma.comment.findUnique as jest.Mock;
const mockedAppealCreate = prisma.appeal.create as jest.Mock;
const mockedAppealFind = prisma.appeal.findUnique as jest.Mock;
const mockedAppealFindMany = prisma.appeal.findMany as jest.Mock;
const mockedAppealUpdate = prisma.appeal.update as jest.Mock;
const mockedResolve = resolveReportsByTarget as jest.Mock;

describe('appealService - 提交申诉', () => {
  beforeEach(() => {
    jest.clearAllMocks();
    mockedPostFind.mockResolvedValue({ userId: 7, status: 0, deletedAt: null, reportCount: 3 });
    mockedCommentFind.mockResolvedValue({ userId: 7, status: 0, reportCount: 3 });
    mockedAppealCreate.mockResolvedValue({ id: 1 });
  });

  it('拒绝非法目标类型', async () => {
    await expect(createAppeal({
      authorId: 7,
      targetType: 'user' as any,
      targetId: 10,
      reason: '误判',
    })).rejects.toThrow('目标类型无效');
    expect(mockedAppealCreate).not.toHaveBeenCalled();
  });

  it('拒绝空理由和超长理由', async () => {
    await expect(createAppeal({
      authorId: 7,
      targetType: 'post',
      targetId: 10,
      reason: '   ',
    })).rejects.toThrow('申诉理由');
    await expect(createAppeal({
      authorId: 7,
      targetType: 'post',
      targetId: 10,
      reason: 'x'.repeat(501),
    })).rejects.toThrow('申诉理由');
    expect(mockedAppealCreate).not.toHaveBeenCalled();
  });

  it('只能申诉自己的内容', async () => {
    await expect(createAppeal({
      authorId: 8,
      targetType: 'post',
      targetId: 10,
      reason: '误判',
    })).rejects.toThrow('只能申诉自己的内容');
    expect(mockedAppealCreate).not.toHaveBeenCalled();
  });

  it('已发布内容不可申诉', async () => {
    mockedPostFind.mockResolvedValue({ userId: 7, status: 1, deletedAt: null, reportCount: 3 });
    await expect(createAppeal({
      authorId: 7,
      targetType: 'post',
      targetId: 10,
      reason: '误判',
    })).rejects.toThrow('仅被处置下架的内容可申诉');
    expect(mockedAppealCreate).not.toHaveBeenCalled();
  });

  it('待审核内容（无举报处置）不可申诉', async () => {
    mockedPostFind.mockResolvedValue({ userId: 7, status: 0, deletedAt: null, reportCount: 0 });
    await expect(createAppeal({
      authorId: 7,
      targetType: 'post',
      targetId: 10,
      reason: '误判',
    })).rejects.toThrow('仅被处置下架的内容可申诉');
    expect(mockedAppealCreate).not.toHaveBeenCalled();
  });

  it('重复申诉返回友好错误', async () => {
    mockedAppealCreate.mockRejectedValue({ code: 'P2002' });
    await expect(createAppeal({
      authorId: 7,
      targetType: 'post',
      targetId: 10,
      reason: '误判',
    })).rejects.toThrow('已有申诉');
  });

  it('查询列表按作者/状态过滤并传排序', async () => {
    await listMyAppeals(7);
    expect(mockedAppealFindMany).toHaveBeenCalledWith({
      where: { authorId: 7 },
      orderBy: { createdAt: 'desc' },
      take: 100,
    });
    await listAppeals('pending');
    expect(mockedAppealFindMany).toHaveBeenLastCalledWith({
      where: { status: 'pending' },
      orderBy: [{ status: 'asc' }, { createdAt: 'asc' }],
      take: 200,
    });
  });
});

describe('appealService - 管理员复核', () => {
  beforeEach(() => {
    jest.clearAllMocks();
    mockedAppealFind.mockResolvedValue({
      id: 5,
      targetType: 'post',
      targetId: 10,
      authorId: 7,
      status: 'pending',
    });
    mockedPostFind.mockResolvedValue({ status: 1, deletedAt: null });
    mockedAppealUpdate.mockResolvedValue({});
  });

  it('驳回：不改内容状态，仅标记 rejected', async () => {
    await reviewAppeal(5, 99, 'rejected', '证据不足');
    expect(mockedResolve).not.toHaveBeenCalled();
    expect(mockedAppealUpdate).toHaveBeenCalledWith({
      where: { id: 5 },
      data: expect.objectContaining({ status: 'rejected', reviewerId: 99, reviewNote: '证据不足' }),
    });
  });

  it('通过且 dismissed 已恢复内容：不再调 restore', async () => {
    await reviewAppeal(5, 99, 'approved', '误判');
    expect(mockedResolve).toHaveBeenCalledTimes(1);
    expect(mockedResolve).toHaveBeenCalledWith('post', 10, 'dismissed', '误判');
    expect(mockedAppealUpdate).toHaveBeenCalledWith({
      where: { id: 5 },
      data: expect.objectContaining({ status: 'approved', reviewerId: 99 }),
    });
  });

  it('通过但内容仍下架（敏感词/历史裁决/无举报）：再走 restore', async () => {
    mockedPostFind.mockResolvedValue({ status: 0, deletedAt: null });
    await reviewAppeal(5, 99, 'approved');
    expect(mockedResolve).toHaveBeenCalledTimes(2);
    expect(mockedResolve).toHaveBeenNthCalledWith(1, 'post', 10, 'dismissed', '申诉复核通过');
    expect(mockedResolve).toHaveBeenNthCalledWith(2, 'post', 10, 'restore', '申诉复核通过');
  });

  it('已处理的申诉不允许二次复核', async () => {
    mockedAppealFind.mockResolvedValue({ id: 5, status: 'approved', targetType: 'post', targetId: 10 });
    await expect(reviewAppeal(5, 99, 'approved')).rejects.toThrow('已处理');
    expect(mockedResolve).not.toHaveBeenCalled();
    expect(mockedAppealUpdate).not.toHaveBeenCalled();
  });

  it('复核失败不写 approved 状态', async () => {
    mockedResolve.mockRejectedValueOnce(new Error('db down'));
    await expect(reviewAppeal(5, 99, 'approved')).rejects.toThrow('db down');
    expect(mockedAppealUpdate).not.toHaveBeenCalled();
  });
});
