// 数据导出：聚合打包当前用户的全部数据（个人信息、帖子、评论、收藏、关注）为 JSON。
// MVP 纯读操作，不生成文件，前端可保存到本地或分享。
import { prisma } from '../prisma';

export interface UserExportData {
  exportedAt: string;
  profile: {
    nickname: string;
    avatar: string | null;
    bio: string | null;
    gender: number | null;
    createdAt: string;
  };
  postsCount: number;
  posts: Array<{
    id: number;
    title: string;
    content: string | null;
    genre: string;
    tags: any;
    upCount: number;
    bookmarkCount: number;
    commentCount: number;
    createdAt: string;
  }>;
  commentsCount: number;
  comments: Array<{
    id: number;
    postId: number;
    content: string;
    createdAt: string;
  }>;
  bookmarksCount: number;
  followingsCount: number;
  followersCount: number;
}

export async function exportUserData(userId: number): Promise<UserExportData> {
  const user = await prisma.user.findUnique({ where: { id: userId } });
  if (!user || user.deletedAt) {
    throw new Error('用户不存在或已注销');
  }

  const [posts, comments, bookmarks, followings, followers] = await Promise.all([
    prisma.post.findMany({
      where: { userId, status: { not: 2 } }, // 排除已拒绝的
      orderBy: { createdAt: 'desc' },
      select: { id: true, title: true, content: true, genre: true, tags: true, upCount: true, bookmarkCount: true, commentCount: true, createdAt: true },
    }),
    prisma.comment.findMany({
      where: { userId, status: 1 },
      orderBy: { createdAt: 'desc' },
      select: { id: true, postId: true, content: true, createdAt: true },
    }),
    prisma.bookmark.count({ where: { userId } }),
    prisma.follow.count({ where: { followerId: userId } }),
    prisma.follow.count({ where: { followingId: userId } }),
  ]);

  return {
    exportedAt: new Date().toISOString(),
    profile: {
      nickname: user.nickname,
      avatar: user.avatar,
      bio: user.bio,
      gender: user.gender,
      createdAt: user.createdAt.toISOString(),
    },
    postsCount: posts.length,
    posts: posts.map((post) => ({ ...post, createdAt: post.createdAt.toISOString() })),
    commentsCount: comments.length,
    comments: comments.map((comment) => ({ ...comment, createdAt: comment.createdAt.toISOString() })),
    bookmarksCount: bookmarks,
    followingsCount: followings,
    followersCount: followers,
  };
}
