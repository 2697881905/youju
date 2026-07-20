// 通知偏好服务单元测试
import { prisma } from '../prisma';
import { getPrefs, updatePrefs, isNotificationAllowed, DEFAULT_PREFS } from './notificationPrefService';

jest.mock('../prisma', () => ({
  prisma: {
    notificationPreference: {
      findUnique: jest.fn(),
      upsert: jest.fn(),
    },
  },
}));

const mockedFindUnique = prisma.notificationPreference.findUnique as jest.Mock;
const mockedUpsert = prisma.notificationPreference.upsert as jest.Mock;

beforeEach(() => {
  jest.clearAllMocks();
});

describe('getPrefs', () => {
  it('无记录时返回全 true 默认值', async () => {
    mockedFindUnique.mockResolvedValue(null);
    const prefs = await getPrefs(1);
    expect(mockedFindUnique).toHaveBeenCalledWith({ where: { userId: 1 } });
    expect(prefs).toEqual(DEFAULT_PREFS);
  });

  it('有记录时返回数据库中值', async () => {
    mockedFindUnique.mockResolvedValue({
      id: 1, userId: 1, comment: false, up: true, bookmark: false, follow: true, system: true, updatedAt: new Date(),
    });
    const prefs = await getPrefs(1);
    expect(prefs).toEqual({ comment: false, up: true, bookmark: false, follow: true, system: true });
  });
});

describe('updatePrefs', () => {
  it('部分更新 — 仅传 comment: false', async () => {
    mockedUpsert.mockResolvedValue({
      id: 1, userId: 1, comment: false, up: true, bookmark: true, follow: true, system: true, updatedAt: new Date(),
    });
    const prefs = await updatePrefs(1, { comment: false });
    expect(mockedUpsert).toHaveBeenCalled();
    expect(prefs.comment).toBe(false);
    expect(prefs.up).toBe(true);
  });

  it('全部字段更新', async () => {
    const input = { comment: false, up: false, bookmark: false, follow: false, system: false };
    mockedUpsert.mockResolvedValue({ id: 1, userId: 1, ...input, updatedAt: new Date() });
    const prefs = await updatePrefs(1, input);
    expect(prefs).toEqual(input);
  });
});

describe('isNotificationAllowed', () => {
  it('comment 关闭 → 返回 false', async () => {
    mockedFindUnique.mockResolvedValue({
      id: 1, userId: 1, comment: false, up: true, bookmark: true, follow: true, system: true, updatedAt: new Date(),
    });
    const allowed = await isNotificationAllowed(1, 'comment');
    expect(allowed).toBe(false);
  });

  it('follow 开启 → 返回 true', async () => {
    mockedFindUnique.mockResolvedValue(null); // 无记录 → 默认全开
    const allowed = await isNotificationAllowed(1, 'follow');
    expect(allowed).toBe(true);
  });

  it('未知通知类型 → 默认允许', async () => {
    mockedFindUnique.mockResolvedValue(null);
    const allowed = await isNotificationAllowed(1, 'unknown_type');
    expect(allowed).toBe(true);
  });
});
