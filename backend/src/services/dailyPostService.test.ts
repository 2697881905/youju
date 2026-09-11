import { listDailyPosts } from './postService';
import { prisma } from '../prisma';
import { env } from '../config/env';
import { getExcludedAuthorIds, getDislikedAuthorIds } from './accessControl';

jest.mock('../prisma', () => ({
  prisma: {
    post: { findMany: jest.fn(), count: jest.fn() },
    userFollowTag: { findMany: jest.fn() },
    tag: { findMany: jest.fn() },
    up: { findMany: jest.fn() },
    bookmark: { findMany: jest.fn() },
    debateVote: { findMany: jest.fn() },
    // 个性化画像（buildViewerProfile）读取的表，必须补齐，
    // 否则每日路径会因 prisma.xxx is undefined 而降级/报错。
    comment: { findMany: jest.fn() },
    postEvent: { findMany: jest.fn() },
    follow: { findMany: jest.fn() },
    searchHistory: { findMany: jest.fn() },
    // 合规开关（个性化推荐总开关）读取表
    privacySettings: { findUnique: jest.fn() },
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
    (prisma.comment.findMany as jest.Mock).mockResolvedValue([]);
    // 默认：未设置过 → 个性化开启
    (prisma.privacySettings.findUnique as jest.Mock).mockResolvedValue(null);
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

  it('总数小于 take 时轮换起始偏移不重复（回归：list 曾把首段元素重复取一遍）', async () => {
    // 兴趣流只有 2 帖、take=10（大于总数）：offset 非 0 时曾出现 id 重复（如 [25,24,25]）
    mockedFollowedTags.mockResolvedValue([{ tagName: '数码' }]);
    installRows([post(1, ['数码']), post(2, ['数码'])], []);

    const result = await listDailyPosts({ viewerId: 5, page: 1, limit: 10, now: DAY });

    const ids = result.list.map((item) => item.id);
    expect(ids.length).toBe(2);                 // 不能因 take=10 而被撑成 3
    expect(new Set(ids).size).toBe(ids.length); // 无重复
    expect(new Set(ids)).toEqual(new Set([1, 2]));
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

  it('行为亲和路径可正常构建画像且不丢条目（排序与按日轮转解耦）', async () => {
    // 无关注标签、无热门标签 → 不分区，全部进 fallback
    mockedFollowedTags.mockResolvedValue([]);
    mockedPopularTags.mockResolvedValue([]);
    installRows([], [post(1, ['旅行']), post(2, ['职场'])]);
    // 用户曾收藏过一篇「旅行」帖 → 画像对「旅行」与该作者产生亲和
    (prisma.bookmark.findMany as jest.Mock).mockResolvedValue([
      { createdAt: DAY, post: { tags: ['旅行'], userId: 101 } },
    ]);

    const result = await listDailyPosts({ viewerId: 21, page: 1, limit: 2, now: DAY });

    // 注：最终页序 = 个性化排序 + 按日轮转（轮转会打乱排序），故此处只断言集合完整、
    // 不丢条目；打分的相对顺序由 dailyScoreService.rankPostsByDailyScore 单测覆盖。
    expect(new Set(result.list.map((item) => item.id))).toEqual(new Set([1, 2]));
  });

  it('用户关闭个性化推荐后：忽略兴趣标签、不读取行为数据，降级为非个性化排序', async () => {
    mockedFollowedTags.mockResolvedValue([{ tagName: '数码' }]);
    // 隐私设置：用户显式关闭个性化推荐（合规开关，优先于实验分流）
    (prisma.privacySettings.findUnique as jest.Mock).mockResolvedValue({ personalizedRecommendation: false });
    installRows([], [post(1, ['数码']), post(2, ['旅行'])]);

    const result = await listDailyPosts({ viewerId: 33, page: 1, limit: 2, now: DAY });

    // 不返回兴趣标签，且完全不读取关注标签（不构建画像）
    expect(result.interestTags).toEqual([]);
    expect(mockedFollowedTags).not.toHaveBeenCalled();
    // 不再做兴趣/非兴趣分区的双 count，只按非个性化单分区取数
    expect(mockedPostCount).toHaveBeenCalledTimes(1);
    expect(mockedPostCount.mock.calls[0][0].where.OR).toBeUndefined();
    expect(new Set(result.list.map((item) => item.id))).toEqual(new Set([1, 2]));
  });

  it('灰度比例为 0 时全量走对照组：保留标签规则排序，但不构建画像', async () => {
    const original = env.dailyPersonalizationRollout;
    env.dailyPersonalizationRollout = 0;
    try {
      mockedFollowedTags.mockResolvedValue([{ tagName: '数码' }]);
      installRows([post(1, ['数码'])], [post(2, ['旅行'])]);

      const result = await listDailyPosts({ viewerId: 44, page: 1, limit: 2, now: DAY });

      // 对照组与改造前一致：仍有兴趣分区与标签返回
      expect(result.interestTags).toEqual(['数码']);
      expect(mockedPostCount.mock.calls[0][0].where.OR).toEqual([{ tags: { array_contains: '数码' } }]);
      expect(new Set(result.list.map((item) => item.id))).toEqual(new Set([1, 2]));
      // 对照组不构建画像：comment.findMany 仅画像构建会调用（装饰列表走 up/bookmark/debateVote）
      expect(prisma.comment.findMany).not.toHaveBeenCalled();
    } finally {
      env.dailyPersonalizationRollout = original;
    }
  });
});
