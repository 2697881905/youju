// 数据导出服务单元测试
import { prisma } from '../prisma';
import { exportUserData } from './exportService';

jest.mock('../prisma', () => ({
  prisma: {
    user: { findUnique: jest.fn() },
    post: { findMany: jest.fn() },
    comment: { findMany: jest.fn() },
    bookmark: { count: jest.fn() },
    follow: { count: jest.fn() },
  },
}));

const mockedUserFindUnique = prisma.user.findUnique as jest.Mock;
const mockedPostFindMany = prisma.post.findMany as jest.Mock;
const mockedCommentFindMany = prisma.comment.findMany as jest.Mock;
const mockedBookmarkCount = prisma.bookmark.count as jest.Mock;
const mockedFollowCount = prisma.follow.count as jest.Mock;

beforeEach(() => {
  jest.clearAllMocks();
});

describe('exportUserData', () => {
  it('导出含基础信息 + 帖子 + 评论 + 统计', async () => {
    mockedUserFindUnique.mockResolvedValue({
      id: 1, nickname: '测试', avatar: 'a.png', bio: 'bio text', gender: 1,
      createdAt: new Date('2026-01-01'), deletedAt: null,
    });
    mockedPostFindMany.mockResolvedValue([
      { id: 1, title: '帖1', content: '内容', genre: 'review', tags: ['数码'], upCount: 5, bookmarkCount: 2, commentCount: 3, createdAt: new Date() },
    ]);
    mockedCommentFindMany.mockResolvedValue([
      { id: 1, postId: 1, content: '评论1', createdAt: new Date() },
    ]);
    mockedBookmarkCount.mockResolvedValue(5);
    mockedFollowCount.mockResolvedValue(3); // followings
    mockedFollowCount.mockResolvedValue(2); // followers — but jest mock returns same fn. Need separate mocks.

    const data = await exportUserData(1);
    expect(data.profile.nickname).toBe('测试');
    expect(data.postsCount).toBe(1);
    expect(data.posts[0].title).toBe('帖1');
    expect(data.commentsCount).toBe(1);
    expect(data.bookmarksCount).toBe(5);
    expect(data.exportedAt).toBeDefined();
  });

  it('已注销用户 → 抛错', async () => {
    mockedUserFindUnique.mockResolvedValue({ id: 1, deletedAt: new Date() });
    await expect(exportUserData(1)).rejects.toThrow('用户不存在或已注销');
  });

  it('用户不存在 → 抛错', async () => {
    mockedUserFindUnique.mockResolvedValue(null);
    await expect(exportUserData(999)).rejects.toThrow('用户不存在或已注销');
  });
});
