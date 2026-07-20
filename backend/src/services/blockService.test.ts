// 拉黑服务单元测试
import { prisma } from '../prisma';
import { blockUser, unblockUser, listBlocked, isBlocked, BlockError } from './blockService';

jest.mock('../prisma', () => ({
  prisma: {
    blocklist: {
      create: jest.fn(),
      delete: jest.fn(),
      findMany: jest.fn(),
      findUnique: jest.fn(),
      count: jest.fn(),
    },
    user: {
      findMany: jest.fn(),
    },
  },
}));

const mockedBlockCreate = prisma.blocklist.create as jest.Mock;
const mockedBlockDelete = prisma.blocklist.delete as jest.Mock;
const mockedBlockFindMany = prisma.blocklist.findMany as jest.Mock;
const mockedBlockFindUnique = prisma.blocklist.findUnique as jest.Mock;
const mockedBlockCount = prisma.blocklist.count as jest.Mock;
const mockedUserFindMany = prisma.user.findMany as jest.Mock;

beforeEach(() => {
  jest.clearAllMocks();
});

describe('blockUser', () => {
  it('不能拉黑自己', async () => {
    await expect(blockUser(1, 1)).rejects.toThrow(BlockError);
    expect(mockedBlockCreate).not.toHaveBeenCalled();
  });

  it('正常拉黑', async () => {
    mockedBlockCreate.mockResolvedValue({ id: 1, userId: 1, blockedId: 2, createdAt: new Date() });
    await blockUser(1, 2);
    expect(mockedBlockCreate).toHaveBeenCalledWith({ data: { userId: 1, blockedId: 2 } });
  });

  it('重复拉黑（P2002 唯一冲突）幂等不报错', async () => {
    mockedBlockCreate.mockRejectedValue({ code: 'P2002' });
    await expect(blockUser(1, 2)).resolves.toBeUndefined();
  });
});

describe('unblockUser', () => {
  it('正常取消拉黑', async () => {
    mockedBlockDelete.mockResolvedValue({ id: 1, userId: 1, blockedId: 2 });
    await unblockUser(1, 2);
    expect(mockedBlockDelete).toHaveBeenCalledWith({
      where: { userId_blockedId: { userId: 1, blockedId: 2 } },
    });
  });

  it('记录不存在（P2025）幂等不报错', async () => {
    mockedBlockDelete.mockRejectedValue({ code: 'P2025' });
    await expect(unblockUser(1, 999)).resolves.toBeUndefined();
  });
});

describe('listBlocked', () => {
  it('返回分页列表，含被拉黑者信息', async () => {
    mockedBlockFindMany.mockResolvedValue([
      { id: 1, userId: 1, blockedId: 2, createdAt: new Date('2026-07-20') },
    ]);
    mockedBlockCount.mockResolvedValue(1);
    mockedUserFindMany.mockResolvedValue([
      { id: 2, nickname: '测试用户', avatar: null, deletedAt: null },
    ]);
    const result = await listBlocked(1, 1, 20);
    expect(result.list).toHaveLength(1);
    expect(result.list[0]).toMatchObject({
      id: 2, nickname: '测试用户', avatar: null, blockedAt: expect.any(String),
    });
    expect(result.pagination).toEqual({ page: 1, limit: 20, total: 1 });
  });

  it('空列表', async () => {
    mockedBlockFindMany.mockResolvedValue([]);
    mockedBlockCount.mockResolvedValue(0);
    mockedUserFindMany.mockResolvedValue([]);
    const result = await listBlocked(1);
    expect(result.list).toHaveLength(0);
  });

  it('已注销用户显示匿名化', async () => {
    mockedBlockFindMany.mockResolvedValue([
      { id: 1, userId: 1, blockedId: 3, createdAt: new Date() },
    ]);
    mockedBlockCount.mockResolvedValue(1);
    mockedUserFindMany.mockResolvedValue([
      { id: 3, nickname: 'old', avatar: 'a.png', deletedAt: new Date() },
    ]);
    const result = await listBlocked(1);
    expect(result.list[0].nickname).toBe('已注销用户');
    expect(result.list[0].avatar).toBeNull();
  });
});

describe('isBlocked', () => {
  it('已拉黑 → true', async () => {
    mockedBlockFindUnique.mockResolvedValue({ id: 1, userId: 1, blockedId: 2 });
    const result = await isBlocked(1, 2);
    expect(result).toBe(true);
  });

  it('未拉黑 → false', async () => {
    mockedBlockFindUnique.mockResolvedValue(null);
    const result = await isBlocked(1, 999);
    expect(result).toBe(false);
  });
});
