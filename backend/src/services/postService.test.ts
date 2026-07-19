import { listPosts, getPost } from './postService';
import { prisma } from '../prisma';

// 用 jest 替掉真实的 Prisma client（沙箱无 MySQL，不需要真实 DB）
// 注意：mock 只校验 where 对象的「形状」，不会触发 Prisma 真实的参数校验，
// 因此 mode:'insensitive'(MySQL 不支持)、arrayContains(应为 array_contains) 这类
// 语法错误无法被本测试捕获——改动 where 语法时务必对照 schema/生成客户端类型人工复核。
jest.mock('../prisma', () => ({
  prisma: {
    post: {
      findMany: jest.fn(),
      findFirst: jest.fn(),
      count: jest.fn(),
    },
    up: {
      findFirst: jest.fn(),
      findMany: jest.fn(),
    },
    bookmark: {
      findFirst: jest.fn(),
      findMany: jest.fn(),
    },
  },
}));

const mockedFindMany = prisma.post.findMany as jest.Mock;
const mockedFindFirst = prisma.post.findFirst as jest.Mock;
const mockedCount = prisma.post.count as jest.Mock;
const mockedUpFindFirst = prisma.up.findFirst as jest.Mock;
const mockedUpFindMany = prisma.up.findMany as jest.Mock;
const mockedBmFindFirst = prisma.bookmark.findFirst as jest.Mock;
const mockedBmFindMany = prisma.bookmark.findMany as jest.Mock;

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

describe('listPosts - myUp/myBookmark 批量打标', () => {
  beforeEach(() => {
    jest.clearAllMocks();
    mockedFindMany.mockResolvedValue([]);
    mockedCount.mockResolvedValue(0);
  });

  it('无 viewerId 时不查 up/bookmark，原样返回 list', async () => {
    const raw = [{ id: 1 }, { id: 2 }];
    mockedFindMany.mockResolvedValue(raw);

    const res = await listPosts({});

    expect(mockedUpFindMany).not.toHaveBeenCalled();
    expect(mockedBmFindMany).not.toHaveBeenCalled();
    expect(res.list).toEqual(raw);
  });

  it('有 viewerId 时对列表批量打标（Set 聚合）', async () => {
    const raw = [{ id: 1 }, { id: 2 }, { id: 3 }];
    mockedFindMany.mockResolvedValue(raw);
    mockedUpFindMany.mockResolvedValue([{ postId: 1 }, { postId: 3 }]);
    mockedBmFindMany.mockResolvedValue([{ postId: 2 }]);

    const res = await listPosts({ viewerId: 5 });

    // 整页仅 +2 次查询，与列表长度无关
    expect(mockedUpFindMany).toHaveBeenCalledTimes(1);
    expect(mockedBmFindMany).toHaveBeenCalledTimes(1);
    // up: post 1/3 已顶；bm: post 2 已收藏
    expect(res.list[0].myUp).toBe(true);
    expect(res.list[0].myBookmark).toBe(false);
    expect(res.list[1].myUp).toBe(false);
    expect(res.list[1].myBookmark).toBe(true);
    expect(res.list[2].myUp).toBe(true);
    expect(res.list[2].myBookmark).toBe(false);
  });

  it('空列表 + viewerId 时不触发打标查询（短路）', async () => {
    mockedFindMany.mockResolvedValue([]);
    const res = await listPosts({ viewerId: 5 });
    expect(mockedUpFindMany).not.toHaveBeenCalled();
    expect(mockedBmFindMany).not.toHaveBeenCalled();
    expect(res.list).toEqual([]);
  });
});

describe('getPost - myUp/myBookmark', () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  it('无 viewerId：不查 up/bookmark，返回原 post', async () => {
    const raw = { id: 1, title: 't' };
    mockedFindFirst.mockResolvedValue(raw);

    const res = await getPost(1);

    expect(mockedUpFindFirst).not.toHaveBeenCalled();
    expect(mockedBmFindFirst).not.toHaveBeenCalled();
    expect(res).toEqual(raw);
  });

  it('有 viewerId 且已顶已藏：返回 myUp/myBookmark 均为 true', async () => {
    mockedFindFirst.mockResolvedValue({ id: 1, title: 't' });
    mockedUpFindFirst.mockResolvedValue({ id: 9, postId: 1, userId: 5 });
    mockedBmFindFirst.mockResolvedValue({ id: 7, postId: 1, userId: 5 });

    const res = await getPost(1, 5);

    expect(mockedUpFindFirst).toHaveBeenCalledTimes(1);
    expect(mockedBmFindFirst).toHaveBeenCalledTimes(1);
    expect(res?.myUp).toBe(true);
    expect(res?.myBookmark).toBe(true);
  });

  it('有 viewerId 但未顶未藏：myUp/myBookmark 均为 false', async () => {
    mockedFindFirst.mockResolvedValue({ id: 2, title: 't2' });
    mockedUpFindFirst.mockResolvedValue(null);
    mockedBmFindFirst.mockResolvedValue(null);

    const res = await getPost(2, 5);

    expect(res?.myUp).toBe(false);
    expect(res?.myBookmark).toBe(false);
  });

  it('帖子不存在返回 null（且不触发打标查询）', async () => {
    mockedFindFirst.mockResolvedValue(null);
    const res = await getPost(999, 5);
    expect(res).toBeNull();
    expect(mockedUpFindFirst).not.toHaveBeenCalled();
    expect(mockedBmFindFirst).not.toHaveBeenCalled();
  });
});
