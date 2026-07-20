// loginWithHuawei 单元测试：mock prisma user 表的 findUnique / create。
// 已知限制：jest mock prisma 不校验真实 SQL / 生成客户端 where 语法，
// 此处只验证「按 unionID 落地用户」的业务逻辑（命中返回 / 未命中创建）。
import { prisma } from '../prisma';
import { loginWithHuawei } from './authService';

jest.mock('../prisma', () => ({
  prisma: {
    user: {
      findUnique: jest.fn(),
      create: jest.fn(),
    },
  },
}));

const mockedFindUnique = prisma.user.findUnique as jest.Mock;
const mockedCreate = prisma.user.create as jest.Mock;

const EXISTING_USER = { id: 1, openId: null, unionID: 'U_EXIST', nickname: '老用户', avatar: 'a.png' };
const NEW_USER = { id: 2, openId: null, unionID: 'U_NEW', nickname: '华为用户abcd', avatar: 'b.png' };

beforeEach(() => {
  jest.clearAllMocks();
});

describe('loginWithHuawei', () => {
  it('a) unionID 已存在 → 返回现有 user，不调用 create', async () => {
    mockedFindUnique.mockResolvedValue(EXISTING_USER);

    const result = await loginWithHuawei('U_EXIST', '新昵称', 'new.png');

    expect(mockedFindUnique).toHaveBeenCalledWith({ where: { unionID: 'U_EXIST' } });
    expect(mockedCreate).not.toHaveBeenCalled();
    // 命中既有用户时直接返回原对象，不应覆盖昵称/头像
    expect(result.user).toMatchObject(EXISTING_USER);
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
    expect(result.user).toMatchObject(NEW_USER);
    expect(typeof result.token).toBe('string');
  });

  it('c) unionID 不存在且昵称缺省 → openId 仍 null、unionID 必填、默认昵称、无 avatar', async () => {
    mockedFindUnique.mockResolvedValue(null);
    mockedCreate.mockResolvedValue({ ...NEW_USER, nickname: '华为用户wxyz' });

    await loginWithHuawei('U_NEW');

    const callData = mockedCreate.mock.calls[0][0].data;
    expect(callData.openId).toBeNull();
    expect(callData.unionID).toBe('U_NEW');
    expect(typeof callData.nickname).toBe('string');
    expect(callData.nickname.length).toBeGreaterThan(0);
    expect(callData.avatar).toBeUndefined();
  });

  it('c2) 返回结构始终含 token 与 user', async () => {
    mockedFindUnique.mockResolvedValue(EXISTING_USER);

    const result = await loginWithHuawei('U_EXIST');

    expect(result).toHaveProperty('token');
    expect(result).toHaveProperty('user');
  });
});
