// 隐私设置服务单元测试
import { prisma } from '../prisma';
import { getSettings, updateSettings } from './privacyService';

jest.mock('../prisma', () => ({
  prisma: {
    privacySettings: {
      findUnique: jest.fn(),
      upsert: jest.fn(),
    },
  },
}));

const mockedFindUnique = prisma.privacySettings.findUnique as jest.Mock;
const mockedUpsert = prisma.privacySettings.upsert as jest.Mock;

beforeEach(() => {
  jest.clearAllMocks();
});

describe('getSettings', () => {
  it('无记录 → 返回默认值（public / allowFollow / allowMessage）', async () => {
    mockedFindUnique.mockResolvedValue(null);
    const s = await getSettings(1);
    expect(s).toEqual({ postVisibility: 'public', allowFollow: true, allowMessage: true });
  });

  it('有记录 → 返回数据库中值', async () => {
    mockedFindUnique.mockResolvedValue({
      id: 1, userId: 1, postVisibility: 'followers', allowFollow: false, allowMessage: true, updatedAt: new Date(),
    });
    const s = await getSettings(1);
    expect(s).toEqual({ postVisibility: 'followers', allowFollow: false, allowMessage: true });
  });
});

describe('updateSettings', () => {
  it('部分更新 — 仅改可见性', async () => {
    mockedUpsert.mockResolvedValue({
      id: 1, userId: 1, postVisibility: 'private', allowFollow: true, allowMessage: true, updatedAt: new Date(),
    });
    const s = await updateSettings(1, { postVisibility: 'private' });
    expect(s.postVisibility).toBe('private');
    expect(s.allowFollow).toBe(true);
  });

  it('全量更新', async () => {
    mockedUpsert.mockResolvedValue({
      id: 1, userId: 1, postVisibility: 'followers', allowFollow: false, dmPolicy: 'followers', updatedAt: new Date(),
    });
    const s = await updateSettings(1, { postVisibility: 'followers', allowFollow: false, dmPolicy: 'followers' });
    expect(s).toEqual({ postVisibility: 'followers', allowFollow: false, dmPolicy: 'followers' });
  });
});
