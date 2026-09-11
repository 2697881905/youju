// 行为数据到期清理服务单元测试
import { prisma } from '../prisma';
import { env } from '../config/env';
import { purgeExpiredBehaviorData, startBehaviorRetentionWorker } from './retentionService';

jest.mock('../prisma', () => ({
  prisma: {
    postEvent: { deleteMany: jest.fn() },
    searchHistory: { deleteMany: jest.fn() },
  },
}));

const mockedPostEventDelete = prisma.postEvent.deleteMany as jest.Mock;
const mockedSearchDelete = prisma.searchHistory.deleteMany as jest.Mock;

const NOW = new Date('2026-09-11T00:00:00.000Z');
const DAY_MS = 86400000;

beforeEach(() => {
  jest.clearAllMocks();
  mockedPostEventDelete.mockResolvedValue({ count: 0 });
  mockedSearchDelete.mockResolvedValue({ count: 0 });
});

describe('purgeExpiredBehaviorData', () => {
  it('按留存天数计算截止时间，并删除两张表的过期明细', async () => {
    mockedPostEventDelete.mockResolvedValue({ count: 12 });
    mockedSearchDelete.mockResolvedValue({ count: 3 });

    const result = await purgeExpiredBehaviorData(NOW, 180);

    const expectedCutoff = new Date(NOW.getTime() - 180 * DAY_MS);
    expect(result.cutoff).toEqual(expectedCutoff);
    expect(result.retentionDays).toBe(180);
    expect(result.postEvents).toBe(12);
    expect(result.searchHistory).toBe(3);
    expect(mockedPostEventDelete).toHaveBeenCalledWith({ where: { createdAt: { lt: expectedCutoff } } });
    expect(mockedSearchDelete).toHaveBeenCalledWith({ where: { createdAt: { lt: expectedCutoff } } });
  });

  it('留存天数 < 1 时钳制为 1 天（避免刚写入即被删）', async () => {
    const result = await purgeExpiredBehaviorData(NOW, 0);
    expect(result.retentionDays).toBe(1);
    expect(result.cutoff).toEqual(new Date(NOW.getTime() - DAY_MS));
  });

  it('负留存天数同样钳制为 1 天', async () => {
    const result = await purgeExpiredBehaviorData(NOW, -30);
    expect(result.retentionDays).toBe(1);
  });

  it('只删明细，不触碰其它表（越权删除的回归保护）', async () => {
    await purgeExpiredBehaviorData(NOW, 30);
    expect(mockedPostEventDelete).toHaveBeenCalledTimes(1);
    expect(mockedSearchDelete).toHaveBeenCalledTimes(1);
  });
});

describe('startBehaviorRetentionWorker', () => {
  it('开关关闭时不做任何清理', () => {
    const original = env.behaviorRetentionEnabled;
    env.behaviorRetentionEnabled = false;
    try {
      startBehaviorRetentionWorker();
      expect(mockedPostEventDelete).not.toHaveBeenCalled();
      expect(mockedSearchDelete).not.toHaveBeenCalled();
    } finally {
      env.behaviorRetentionEnabled = original;
    }
  });
});
