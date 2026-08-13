import { listDailyPosts } from './postService';
import { prisma } from '../prisma';
import { getExcludedAuthorIds, getDislikedAuthorIds } from './accessControl';

jest.mock('../prisma', () => ({
  prisma: {
    post: { findMany: jest.fn(), count: jest.fn() },
    userFollowTag: { findMany: jest.fn() },
    tag: { findMany: jest.fn() },
    up: { findMany: jest.fn() },
    bookmark: { findMany: jest.fn() },
    debateVote: { findMany: jest.fn() },
  },
}));

jest.mock('./accessControl', () => ({
  getExcludedAuthorIds: jest.fn(),
  getDislikedAuthorIds: jest.fn(),
  canViewerSeeAuthorPosts: jest.fn(),
}));

const mockedPostFindMany = prisma.post.findMany as jest.Mock;
const mockedPostCount = prisma.post.count as jest.Mock;
const mockedFollowedTags = prisma.userFollowTag.findMany as jest.Mock;
const mockedPopularTags = prisma.tag.findMany as jest.Mock;
const mockedExcluded = getExcludedAuthorIds as jest.Mock;
const mockedDisliked = getDislikedAuthorIds as jest.Mock;

const DAY = new Date('2026-08-11T04:00:00.000Z');

function post(id: number, tags: string[]): Record<string, unknown> {
  return { id, title: '帖子 ' + id, tags, user: { id: id + 100, nickname: '作者 ' + id, avatar: null } };
}

function installRows(interest: Record<string, unknown>[], fallback: Record<string, unknown>[]): void {
  mockedPostCount.mockImplementation(({ where }: { where: Record<string, unknown> }) =>
    Promise.resolve(where.OR ? interest.length : fallback.length));
  mockedPostFindMany.mockImplementation(({ where, skip, take }: { where: Record<string, unknown>, skip: number, take: number }) => {
    const rows = where.OR ? interest : fallback;
    return Promise.resolve(rows.slice(skip, skip + take));
  });
}

describe('listDailyPosts', () => {
  beforeEach(() => {
    jest.clearAllMocks();
    mockedFollowedTags.mockResolvedValue([]);
    mockedPopularTags.mockResolvedValue([]);
    mockedExcluded.mockResolvedValue([]);
    mockedDisliked.mockResolvedValue([]);
    (prisma.up.findMany as jest.Mock).mockResolvedValue([]);
    (prisma.bookmark.findMany as jest.Mock).mockResolvedValue([]);
    (prisma.debateVote.findMany as jest.Mock).mockResolvedValue([]);
  });

  it('优先返回已关注标签的帖子，并给出命中标签', async () => {
    mockedFollowedTags.mockResolvedValue([{ tagName: '数码' }]);
    installRows([post(1, ['数码']), post(2, ['数码', '外设'])], [post(3, ['旅行'])]);

    const result = await listDailyPosts({ viewerId: 7, page: 1, limit: 2, now: DAY });

    expect(result.interestTags).toEqual(['数码']);
    expect(result.list.map((item) => item.id).sort()).toEqual([1, 2]);
    expect(result.list.every((item) => item.matchedTags.includes('数码'))).toBe(true);
    expect(mockedPostCount.mock.calls[0][0].where.OR).toEqual([{ tags: { array_contains: '数码' } }]);
    expect(mockedPostCount.mock.calls[1][0].where.NOT).toEqual({ OR: [{ tags: { array_contains: '数码' } }] });
  });

  it('访客使用热门标签作为兴趣兜底', async () => {
    mockedPopularTags.mockResolvedValue([{ name: '露营' }, { name: '旅行' }]);
    installRows([post(10, ['旅行'])], [post(11, ['职场'])]);

    const result = await listDailyPosts({ page: 1, limit: 1, now: DAY });

    expect(result.interestTags).toEqual(['露营', '旅行']);
    expect(result.list[0].matchedTags).toEqual(['旅行']);
    expect(mockedFollowedTags).not.toHaveBeenCalled();
  });

  it('同一天分页顺序稳定，跨页不会重复', async () => {
    mockedFollowedTags.mockResolvedValue([{ tagName: '数码' }]);
    installRows(
      [post(1, ['数码']), post(2, ['数码']), post(3, ['数码'])],
      [post(4, ['旅行']), post(5, ['职场'])],
    );

    const first = await listDailyPosts({ viewerId: 9, page: 1, limit: 2, now: DAY });
    const firstAgain = await listDailyPosts({ viewerId: 9, page: 1, limit: 2, now: DAY });
    const second = await listDailyPosts({ viewerId: 9, page: 2, limit: 2, now: DAY });
    const third = await listDailyPosts({ viewerId: 9, page: 3, limit: 2, now: DAY });
    const ids = first.list.concat(second.list, third.list).map((item) => item.id);

    expect(first.list.map((item) => item.id)).toEqual(firstAgain.list.map((item) => item.id));
    expect(new Set(ids).size).toBe(5);
    expect(new Set(ids)).toEqual(new Set([1, 2, 3, 4, 5]));
    expect(first.dateKey).toBe('2026-08-11');
  });

  it('跨上海日期会轮换同一兴趣流的起始位置', async () => {
    mockedFollowedTags.mockResolvedValue([{ tagName: '数码' }]);
    installRows([
      post(1, ['数码']), post(2, ['数码']), post(3, ['数码']), post(4, ['数码']),
      post(5, ['数码']), post(6, ['数码']), post(7, ['数码']),
    ], []);

    const today = await listDailyPosts({ viewerId: 9, page: 1, limit: 3, now: DAY });
    const tomorrow = await listDailyPosts({
      viewerId: 9,
      page: 1,
      limit: 3,
      now: new Date('2026-08-12T04:00:00.000Z'),
    });

    expect(today.dateKey).toBe('2026-08-11');
    expect(tomorrow.dateKey).toBe('2026-08-12');
    expect(today.list.map((item) => item.id)).not.toEqual(tomorrow.list.map((item) => item.id));
  });

  it('将隐私/拉黑与不喜欢作者统一排除在每日流之外', async () => {
    mockedExcluded.mockResolvedValue([41]);
    mockedDisliked.mockResolvedValue([52]);
    mockedFollowedTags.mockResolvedValue([]);
    mockedPopularTags.mockResolvedValue([]);
    installRows([], []);

    await listDailyPosts({ viewerId: 7, now: DAY });

    const where = mockedPostCount.mock.calls[0][0].where;
    expect(where.userId).toEqual({ notIn: [41, 52] });
  });
});
