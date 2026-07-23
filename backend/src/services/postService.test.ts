import { listPosts, getPost, listLikedPosts, listCommentedPosts } from './postService';
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
      count: jest.fn(),
    },
    bookmark: {
      findFirst: jest.fn(),
      findMany: jest.fn(),
    },
    comment: {
      groupBy: jest.fn(),
    },
    user: {
      // 默认返回有效（已发布、未注销）作者，使 canViewerSeeAuthorPosts 通过
      findUnique: jest.fn().mockResolvedValue({ status: 1, deletedAt: null }),
    },
    // accessControl 依赖：默认无隐私限制、无拉黑，全部公开可见
    privacySettings: {
      findMany: jest.fn().mockResolvedValue([]),
      findUnique: jest.fn().mockResolvedValue(null),
    },
    blocklist: {
      findMany: jest.fn().mockResolvedValue([]),
      findUnique: jest.fn().mockResolvedValue(null),
    },
    follow: {
      findMany: jest.fn().mockResolvedValue([]),
      findUnique: jest.fn().mockResolvedValue(null),
    },
  },
}));

const mockedFindMany = prisma.post.findMany as jest.Mock;
const mockedFindFirst = prisma.post.findFirst as jest.Mock;
const mockedCount = prisma.post.count as jest.Mock;
const mockedUpFindFirst = prisma.up.findFirst as jest.Mock;
const mockedUpFindMany = prisma.up.findMany as jest.Mock;
const mockedUpCount = prisma.up.count as jest.Mock;
const mockedBmFindFirst = prisma.bookmark.findFirst as jest.Mock;
const mockedBmFindMany = prisma.bookmark.findMany as jest.Mock;
const mockedCommentGroupBy = prisma.comment.groupBy as jest.Mock;

const DELETED_NICKNAME = '已注销用户';

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

describe('listPosts - myUp/myBookmark 批量打标 + 作者匿名化', () => {
  beforeEach(() => {
    jest.clearAllMocks();
    mockedFindMany.mockResolvedValue([]);
    mockedCount.mockResolvedValue(0);
  });

  it('无 viewerId 时不查 up/bookmark，原样返回 list（含 user 视图）', async () => {
    const raw = [
      { id: 1, user: { id: 1, nickname: 'A', avatar: 'a.png' } },
      { id: 2, user: { id: 2, nickname: 'B', avatar: null } },
    ];
    mockedFindMany.mockResolvedValue(raw);

    const res = await listPosts({});

    expect(mockedUpFindMany).not.toHaveBeenCalled();
    expect(mockedBmFindMany).not.toHaveBeenCalled();
    expect(res.list).toEqual([
      { id: 1, user: { id: 1, nickname: 'A', avatar: 'a.png' } },
      { id: 2, user: { id: 2, nickname: 'B', avatar: null } },
    ]);
  });

  it('有 viewerId 时对列表批量打标（Set 聚合）+ user 透传', async () => {
    const raw = [
      { id: 1, user: { id: 1, nickname: 'A', avatar: 'a.png' } },
      { id: 2, user: { id: 2, nickname: 'B', avatar: null } },
      { id: 3, user: { id: 3, nickname: 'C', avatar: 'c.png' } },
    ];
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
    // user 透传（无 deletedAt）
    expect(res.list[0].user).toEqual({ id: 1, nickname: 'A', avatar: 'a.png' });
  });

  it('空列表 + viewerId 时不触发打标查询（短路）', async () => {
    mockedFindMany.mockResolvedValue([]);
    const res = await listPosts({ viewerId: 5 });
    expect(mockedUpFindMany).not.toHaveBeenCalled();
    expect(mockedBmFindMany).not.toHaveBeenCalled();
    expect(res.list).toEqual([]);
  });

  it('已注销作者 → user 被匿名化为「已注销用户」且 deleted=true', async () => {
    const raw = [
      {
        id: 1,
        user: { id: 5, nickname: '旧用户', avatar: 'old.png', deletedAt: new Date('2024-01-01') },
      },
    ];
    mockedFindMany.mockResolvedValue(raw);

    const res = await listPosts({});

    expect(res.list[0].user).toEqual({
      id: 5,
      nickname: DELETED_NICKNAME,
      avatar: null,
      deleted: true,
    });
  });
});

describe('getPost - myUp/myBookmark + 作者匿名化', () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  it('无 viewerId：不查 up/bookmark，返回原 post（含 user/comments 视图）', async () => {
    const raw = {
      id: 1,
      status: 1,
      title: 't',
      user: { id: 1, nickname: 'A', avatar: 'a.png' },
      comments: [{ id: 9, content: 'c', user: { id: 2, nickname: 'B', avatar: null } }],
    };
    mockedFindFirst.mockResolvedValue(raw);

    const res = await getPost(1);

    expect(mockedUpFindFirst).not.toHaveBeenCalled();
    expect(mockedBmFindFirst).not.toHaveBeenCalled();
    expect(res).toEqual({
      id: 1,
      status: 1,
      title: 't',
      user: { id: 1, nickname: 'A', avatar: 'a.png' },
      comments: [{ id: 9, content: 'c', user: { id: 2, nickname: 'B', avatar: null } }],
    });
  });

  it('有 viewerId 且已顶已藏：返回 myUp/myBookmark 均为 true', async () => {
    mockedFindFirst.mockResolvedValue({
      id: 1,
      status: 1,
      title: 't',
      user: { id: 1, nickname: 'A', avatar: 'a.png' },
      comments: [],
    });
    mockedUpFindFirst.mockResolvedValue({ id: 9, postId: 1, userId: 5 });
    mockedBmFindFirst.mockResolvedValue({ id: 7, postId: 1, userId: 5 });

    const res = await getPost(1, 5);

    expect(mockedUpFindFirst).toHaveBeenCalledTimes(1);
    expect(mockedBmFindFirst).toHaveBeenCalledTimes(1);
    expect(res?.myUp).toBe(true);
    expect(res?.myBookmark).toBe(true);
  });

  it('有 viewerId 但未顶未藏：myUp/myBookmark 均为 false', async () => {
    mockedFindFirst.mockResolvedValue({
      id: 2,
      status: 1,
      title: 't2',
      user: { id: 1, nickname: 'A', avatar: 'a.png' },
      comments: [],
    });
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

  it('已注销作者 → user 被匿名化且评论作者同样匿名化', async () => {
    mockedFindFirst.mockResolvedValue({
      id: 1,
      status: 1,
      title: 't',
      user: { id: 5, nickname: '旧用户', avatar: 'old.png', deletedAt: new Date('2024-01-01') },
      comments: [
        { id: 9, content: 'c', user: { id: 5, nickname: '旧用户', avatar: 'old.png', deletedAt: new Date('2024-01-01') } },
      ],
    });

    const res = await getPost(1);

    expect(res?.user).toEqual({ id: 5, nickname: DELETED_NICKNAME, avatar: null, deleted: true });
    expect(res?.comments[0].user).toEqual({
      id: 5,
      nickname: DELETED_NICKNAME,
      avatar: null,
      deleted: true,
    });
  });
});

describe('listLikedPosts - 我赞过的帖子', () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  it('分页参数 + 返回结构为 { list, pagination }', async () => {
    mockedUpFindMany.mockResolvedValue([
      { postId: 3, post: { id: 3, user: { id: 3, nickname: 'C' } } },
    ]);
    mockedUpCount.mockResolvedValue(1);

    const res = await listLikedPosts(7, 2, 10);

    // up.findMany 分页参数正确
    expect(mockedUpFindMany).toHaveBeenCalledTimes(1);
    const fmArg = mockedUpFindMany.mock.calls[0][0];
    expect(fmArg.where).toEqual({ userId: 7 });
    expect(fmArg.orderBy).toEqual({ createdAt: 'desc' });
    expect(fmArg.skip).toBe(10);
    expect(fmArg.take).toBe(10);
    expect(fmArg.include.post.include.user).toBeDefined();
    // 结构
    expect(res.pagination).toEqual({ page: 2, limit: 10, total: 1 });
    expect(res.list).toHaveLength(1);
    expect(res.list[0].id).toBe(3);
    expect(res.list[0].user).toEqual({ id: 3, nickname: 'C' });
  });

  it('空列表返回空数组', async () => {
    mockedUpFindMany.mockResolvedValue([]);
    mockedUpCount.mockResolvedValue(0);
    const res = await listLikedPosts(7);
    expect(res.list).toEqual([]);
    expect(res.pagination.total).toBe(0);
  });
});

describe('listCommentedPosts - 我评论过的帖子（去重）', () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  it('同一帖多次评论只出现一次，且按最新评论时间倒序保序', async () => {
    // 用户 7 评论过：post 1(评论a/b) + post 2(评论c) + post 3(评论d)
    // groupBy 返回 3 个去重 postId，按 _max.createdAt 倒序：3,1,2
    mockedCommentGroupBy
      .mockResolvedValueOnce([
        { postId: 3, _max: { createdAt: new Date('2024-03-01') } },
        { postId: 1, _max: { createdAt: new Date('2024-02-01') } },
        { postId: 2, _max: { createdAt: new Date('2024-01-01') } },
      ])
      // 计数 groupBy（不依赖分页）
      .mockResolvedValueOnce([
        { postId: 3 },
        { postId: 1 },
        { postId: 2 },
      ]);
    mockedFindMany.mockResolvedValue([
      { id: 1, user: { id: 1, nickname: 'A' } },
      { id: 2, user: { id: 2, nickname: 'B' } },
      { id: 3, user: { id: 3, nickname: 'C' } },
    ]);

    const res = await listCommentedPosts(7, 1, 20);

    // findMany 用 in 查询三个去重 postId
    expect(mockedFindMany).toHaveBeenCalledTimes(1);
    expect(mockedFindMany.mock.calls[0][0].where.id).toEqual({ in: [3, 1, 2] });
    // 返回顺序与 groupBy 顺序一致（3,1,2），而非 findMany 原始顺序
    expect(res.list.map((p) => p.id)).toEqual([3, 1, 2]);
    expect(res.list[0].user).toEqual({ id: 3, nickname: 'C' });
    expect(res.pagination.total).toBe(3);
  });

  it('某页无评论时返回空数组', async () => {
    mockedCommentGroupBy
      .mockResolvedValueOnce([])
      .mockResolvedValueOnce([]);
    mockedFindMany.mockResolvedValue([]);

    const res = await listCommentedPosts(7, 99, 20);
    expect(res.list).toEqual([]);
    expect(res.pagination.total).toBe(0);
  });
});
