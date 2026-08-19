// loginWithHuawei 单元测试：mock prisma user 表的 findUnique / create。
// 已知限制：jest mock prisma 不校验真实 SQL / 生成客户端 where 语法，
// 此处只验证「按 unionID 落地用户」的业务逻辑（命中返回 / 未命中创建）。
import { prisma } from '../prisma';
import { loginWithHuawei, deactivateUser, DELETED_NICKNAME } from './authService';

jest.mock('../prisma', () => {
  const user = {
    findUnique: jest.fn(),
    create: jest.fn(),
    update: jest.fn(),
  };
  const client = {
    user,
    post: { findMany: jest.fn().mockResolvedValue([]) },
    pushToken: { deleteMany: jest.fn() },
    userBinding: { deleteMany: jest.fn() },
    mediaDeletionTask: { createMany: jest.fn() },
  };
  return {
    prisma: {
      ...client,
      $transaction: jest.fn().mockImplementation((input: any) =>
        typeof input === 'function' ? input(client) : Promise.all(input ?? [])),
    },
  };
});

const mockedFindUnique = prisma.user.findUnique as jest.Mock;
const mockedCreate = prisma.user.create as jest.Mock;
const mockedUpdate = prisma.user.update as jest.Mock;
const mockedPostFindMany = prisma.post.findMany as jest.Mock;

const EXISTING_USER = { id: 1, openId: null, unionID: 'U_EXIST', nickname: '老用户', avatar: 'a.png' };
const NEW_USER = { id: 2, openId: null, unionID: 'U_NEW', nickname: '据友123456', avatar: 'b.png' };

beforeEach(() => {
  jest.clearAllMocks();
  mockedPostFindMany.mockResolvedValue([]);
});

describe('loginWithHuawei', () => {
  it('a) unionID 已存在 → 返回现有 user，不调用 create', async () => {
    mockedFindUnique.mockResolvedValue(EXISTING_USER);

    const result = await loginWithHuawei('U_EXIST', '新昵称', 'new.png');

    expect(mockedFindUnique).toHaveBeenCalledWith({ where: { unionID: 'U_EXIST' } });
    expect(mockedCreate).not.toHaveBeenCalled();
    // 命中既有用户时直接返回原对象，不应覆盖昵称/头像
    expect(result.user).toMatchObject({ id: 1, nickname: '老用户', avatar: 'a.png' });
    expect(result.user).not.toHaveProperty('openId');
    expect(result.user).not.toHaveProperty('unionID');
    expect(result.user.nickname).toBe('老用户');
    // 返回结构含 token（JWT 字符串）
    expect(typeof result.token).toBe('string');
    expect(result.token.length).toBeGreaterThan(0);
  });

  it('b) unionID 不存在 → create 新 user（openId 为 null、unionID 必填）', async () => {
    mockedFindUnique.mockResolvedValue(null);
    mockedCreate.mockResolvedValue(NEW_USER);

    const result = await loginWithHuawei('U_NEW', '华为小王', 'b.png');

    expect(mockedFindUnique).toHaveBeenCalledTimes(1);
    expect(mockedCreate).toHaveBeenCalledTimes(1);
    expect(mockedCreate).toHaveBeenCalledWith({
      data: { openId: null, unionID: 'U_NEW', nickname: '华为小王', avatar: 'b.png' },
    });
    expect(result.user).toMatchObject({ id: 2, nickname: '据友123456', avatar: 'b.png' });
    expect(result.user).not.toHaveProperty('unionID');
    expect(typeof result.token).toBe('string');
  });

  it('c) unionID 不存在且昵称缺省 → openId 仍 null、unionID 必填、默认昵称、无 avatar', async () => {
    mockedFindUnique.mockResolvedValue(null);
    mockedCreate.mockResolvedValue({ ...NEW_USER, nickname: '据友654321' });

    await loginWithHuawei('U_NEW');

    const callData = mockedCreate.mock.calls[0][0].data;
    expect(callData.openId).toBeNull();
    expect(callData.unionID).toBe('U_NEW');
    expect(callData.nickname).toMatch(/^据友\d{6}$/);
    expect(callData.avatar).toBeUndefined();
  });

  it('c2) 返回结构始终含 token 与 user', async () => {
    mockedFindUnique.mockResolvedValue(EXISTING_USER);

    const result = await loginWithHuawei('U_EXIST');

    expect(result).toHaveProperty('token');
    expect(result).toHaveProperty('user');
  });
});

describe('deactivateUser', () => {
  it('a) 置 deletedAt + 匿名化 nickname + 清空 avatar', async () => {
    const deletedAt = new Date('2024-01-01T00:00:00Z');
    mockedUpdate.mockResolvedValue({
      id: 5,
      nickname: DELETED_NICKNAME,
      avatar: null,
      deletedAt,
    });
    mockedFindUnique.mockResolvedValue({ avatar: null, profileBackground: null });

    const result = await deactivateUser(5);

    expect(mockedUpdate).toHaveBeenCalledWith({
      where: { id: 5 },
      data: {
        deletedAt: expect.any(Date),
        nickname: DELETED_NICKNAME,
        avatar: null,
        profileBackground: null,
        bio: null,
        gender: null,
        openId: null,
        unionID: null,
      },
    });
    expect(result.nickname).toBe(DELETED_NICKNAME);
    expect(result.avatar).toBeNull();
    expect(result.deletedAt).not.toBeNull();
  });

  it('b) 旧 token 经 auth 中间件将被拒（软删后 deletedAt 非空）', async () => {
    // deactivateUser 仅负责写入软删标记；auth 中间件对 deletedAt 非空返回 401 的断言见 auth.test.ts
    mockedUpdate.mockResolvedValue({ id: 7, nickname: DELETED_NICKNAME, avatar: null, deletedAt: new Date() });
    mockedFindUnique.mockResolvedValue({ avatar: null, profileBackground: null });
    const result = await deactivateUser(7);
    expect(result.deletedAt).not.toBeNull();
  });
});
