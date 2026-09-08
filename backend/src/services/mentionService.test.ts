import { resolveMentionRefs, extractMentionNames } from './mentionService';
import { prisma } from '../prisma';

// 沙箱无 MySQL：mock Prisma client，只校验解析逻辑与 where 形状
jest.mock('../prisma', () => ({
  prisma: {
    user: {
      findMany: jest.fn(),
    },
  },
}));

const mockedFindMany = prisma.user.findMany as jest.Mock;

type Row = { id: number; nickname: string };

// 按调用顺序依次返回结果（缺省返回 []）
function mockFindMany(...sequences: Row[][]): void {
  mockedFindMany.mockReset();
  for (const rows of sequences) {
    mockedFindMany.mockResolvedValueOnce(rows);
  }
}

function lastCallWhere(): { where: Record<string, unknown> } {
  const calls = mockedFindMany.mock.calls;
  const last = calls[calls.length - 1];
  return { where: (last[0] as { where: Record<string, unknown> }).where };
}

describe('extractMentionNames', () => {
  it('提取合法 @昵称并去重、忽略过短', () => {
    expect(extractMentionNames('谢谢 @张三 提醒，@李四 也好，@三 太短')).toEqual(['张三', '李四']);
    expect(extractMentionNames('')).toEqual([]);
    expect(extractMentionNames('@ 空格后')).toEqual([]);
    expect(extractMentionNames('@a 太短')).toEqual([]);
  });
});

describe('resolveMentionRefs - 回退按昵称解析', () => {
  it('无显式列表时按昵称命中真实用户', async () => {
    mockFindMany([{ id: 11, nickname: '张三' }]);
    expect(await resolveMentionRefs('@张三 的结论很对', undefined))
      .toEqual([{ name: '张三', userId: 11 }]);
  });

  it('昵称解析的 where 限定 status=1 且未注销', async () => {
    mockFindMany([{ id: 11, nickname: '张三' }]);
    await resolveMentionRefs('@张三 好', null);
    const w = lastCallWhere().where;
    expect(w.status).toBe(1);
    expect(w.deletedAt).toBeNull();
  });
});

describe('resolveMentionRefs - 显式精确到 userId（防重名）', () => {
  it('重名时显式选择的后建者被精确命中，同名首人不被并入', async () => {
    // 两个「王伟」：user 1 先建、user 2 后建；编辑器选择了 user 2
    mockFindMany(
      [{ id: 2, nickname: '王伟' }], // 第一次：按显式 userId 校验
      [{ id: 1, nickname: '王伟' }]  // 补全扫描（命中同名的 user1 应被 name 去重跳过）
    );
    const refs = await resolveMentionRefs(
      '感谢 @王伟 的分享',
      [{ name: '王伟', userId: 2 }]
    );
    expect(refs).toEqual([{ name: '王伟', userId: 2 }]);
    // 校验查询走 id in，而非昵称猜测
    const first = mockedFindMany.mock.calls[0][0] as { where: { id: { in: number[] } } };
    expect(first.where.id.in).toEqual([2]);
  });

  it('显式用户不存在/昵称不符时丢弃并回退昵称解析', async () => {
    mockFindMany(
      [], // 用户 999 不存在
      [{ id: 1, nickname: '王伟' }] // 回退
    );
    expect(await resolveMentionRefs('@王伟 在吗', [{ name: '王伟', userId: 999 }]))
      .toEqual([{ name: '王伟', userId: 1 }]);
  });

  it('显式列表中文本已不含该 @ 的过期选择被丢弃', async () => {
    mockFindMany(
      [{ id: 5, nickname: '李四' }] // content 无 @王伟 → 直接按昵称解析一次
    );
    expect(await resolveMentionRefs('你好 @李四', [{ name: '王伟', userId: 2 }]))
      .toEqual([{ name: '李四', userId: 5 }]);
  });

  it('显式选择与手工 @ 混用时，未覆盖的手工 @ 补全、被覆盖的不重复并入', async () => {
    mockFindMany(
      [{ id: 7, nickname: '李四' }], // 显式校验
      [
        { id: 7, nickname: '李四' },
        { id: 8, nickname: '王五' },
      ] // 补全扫描：李四(同名已覆盖跳过)、王五 并入
    );
    const refs = await resolveMentionRefs(
      '@李四 与 @王五 都说了',
      [{ name: '李四', userId: 7 }]
    );
    expect(refs).toEqual([
      { name: '李四', userId: 7 },
      { name: '王五', userId: 8 },
    ]);
  });

  it('空正文/无 @ 返回空数组', async () => {
    mockFindMany();
    expect(await resolveMentionRefs('', [{ name: '张三', userId: 1 }])).toEqual([]);
    mockFindMany();
    expect(await resolveMentionRefs('普通文本', undefined)).toEqual([]);
  });
});
