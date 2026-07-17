import { listPosts } from './postService';
import { prisma } from '../prisma';

// 用 jest 替掉真实的 Prisma client（沙箱无 MySQL，不需要真实 DB）
// 注意：mock 只校验 where 对象的「形状」，不会触发 Prisma 真实的参数校验，
// 因此 mode:'insensitive'(MySQL 不支持)、arrayContains(应为 array_contains) 这类
// 语法错误无法被本测试捕获——改动 where 语法时务必对照 schema/生成客户端类型人工复核。
jest.mock('../prisma', () => ({
  prisma: {
    post: {
      findMany: jest.fn(),
      count: jest.fn(),
    },
  },
}));

const mockedFindMany = prisma.post.findMany as jest.Mock;
const mockedCount = prisma.post.count as jest.Mock;

describe('listPosts - 关键词 OR 过滤逻辑', () => {
  beforeEach(() => {
    jest.clearAllMocks();
    mockedFindMany.mockResolvedValue([]);
    mockedCount.mockResolvedValue(0);
  });

  it('keyword 非空时构造 where.OR 含 4 个条件', async () => {
    await listPosts({ keyword: '科幻' });

    expect(mockedFindMany).toHaveBeenCalledTimes(1);
    const where = mockedFindMany.mock.calls[0][0].where;

    // 基础过滤保持
    expect(where.status).toBe(1);
    // OR 必须存在且有 4 个条件
    expect(Array.isArray(where.OR)).toBe(true);
    expect(where.OR).toHaveLength(4);
    // title / content / genre contains（MySQL 默认 ci 排序规则即大小写不敏感）+ tags array_contains
    expect(where.OR[0]).toEqual({ title: { contains: '科幻' } });
    expect(where.OR[1]).toEqual({ content: { contains: '科幻' } });
    expect(where.OR[2]).toEqual({ genre: { contains: '科幻' } });
    expect(where.OR[3]).toEqual({ tags: { array_contains: '科幻' } });

    // count 与 findMany 使用同一个 where（OR 同样生效）
    const countWhere = mockedCount.mock.calls[0][0].where;
    expect(countWhere.OR).toHaveLength(4);
  });

  it('keyword 为空字符串时 OR 不生效，仅保留 status:1', async () => {
    await listPosts({ keyword: '' });

    const where = mockedFindMany.mock.calls[0][0].where;
    expect(where.status).toBe(1);
    expect(where.OR).toBeUndefined();
  });

  it('keyword 为纯空白时 OR 不生效（trim 后为空）', async () => {
    await listPosts({ keyword: '   ' });

    const where = mockedFindMany.mock.calls[0][0].where;
    expect(where.status).toBe(1);
    expect(where.OR).toBeUndefined();
  });

  it('keyword 带前后空格时按 trim 后生效', async () => {
    await listPosts({ keyword: ' 科幻 ' });

    const where = mockedFindMany.mock.calls[0][0].where;
    expect(where.OR).toHaveLength(4);
    expect(where.OR[0]).toEqual({ title: { contains: '科幻' } });
  });

  it('keyword 与 tag 同时使用时 status / tag 与 OR 并存', async () => {
    await listPosts({ keyword: 'a', tag: '数码' });

    const where = mockedFindMany.mock.calls[0][0].where;
    expect(where.status).toBe(1);
    expect(where.tags).toEqual({ array_contains: '数码' });
    expect(where.OR).toHaveLength(4);
  });

  it('返回结构为 { list, pagination:{page,limit,total} }', async () => {
    mockedFindMany.mockResolvedValue([{ id: 1 }]);
    mockedCount.mockResolvedValue(1);

    const res = await listPosts({ keyword: 'x', page: 2, limit: 10 });
    expect(res).toHaveProperty('list');
    expect(res).toHaveProperty('pagination');
    expect(res.pagination).toEqual({ page: 2, limit: 10, total: 1 });
  });
});
