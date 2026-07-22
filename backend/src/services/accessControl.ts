// 可见性 / 社交控制统一层：拉黑（双向）与隐私设置在此汇总，
// 供 postService（信息流 / 详情 / 个人主页）与 followService（关注拦截）复用。
// 设计原则：单作者场景用 canViewerSeeAuthorPosts（精准），信息流场景用
// getExcludedAuthorIds（一次性算出不可见作者集合，配合 where.userId.notIn，分页计数准确）。
import { prisma } from '../prisma';

// 计算 viewer 应当在信息流中「看不到」的作者 id 集合：
//  - 拉黑（双向）：viewer 拉黑的人 + 拉黑 viewer 的人
//  - 隐私：postVisibility='private' 的作者（除非是自己）；
//          postVisibility='followers' 的作者（除非 viewer 已关注）
// viewerId 为 undefined（匿名）时：仅按隐私规则隐藏 private/followers 作者，拉黑不适用。
export async function getExcludedAuthorIds(viewerId?: number): Promise<number[]> {
  const hidden = new Set<number>();

  // 1) 拉黑（双向）
  if (viewerId) {
    const [blockedByMe, blockedMe] = await Promise.all([
      prisma.blocklist.findMany({ where: { userId: viewerId }, select: { blockedId: true } }),
      prisma.blocklist.findMany({ where: { blockedId: viewerId }, select: { userId: true } }),
    ]);
    for (const r of blockedByMe) hidden.add(r.blockedId);
    for (const r of blockedMe) hidden.add(r.userId);
  }

  // 2) 隐私限制作者
  const restricted = await prisma.privacySettings.findMany({
    where: { postVisibility: { in: ['private', 'followers'] } },
    select: { userId: true, postVisibility: true },
  });
  if (restricted.length > 0) {
    const privateIds = restricted.filter((r) => r.postVisibility === 'private').map((r) => r.userId);
    const followerIds = restricted.filter((r) => r.postVisibility === 'followers').map((r) => r.userId);
    for (const id of privateIds) {
      if (id !== viewerId) hidden.add(id);
    }
    if (followerIds.length > 0) {
      if (viewerId) {
        const followed = await prisma.follow.findMany({
          where: { followerId: viewerId, followingId: { in: followerIds } },
          select: { followingId: true },
        });
        const followedSet = new Set(followed.map((f) => f.followingId));
        for (const id of followerIds) {
          if (!followedSet.has(id)) hidden.add(id);
        }
      } else {
        for (const id of followerIds) hidden.add(id);
      }
    }
  }

  return [...hidden];
}

// 判断 viewer 是否能查看 authorId 的帖子（单作者场景：详情 / 个人主页）。
export async function canViewerSeeAuthorPosts(
  viewerId: number | undefined,
  authorId: number,
): Promise<boolean> {
  // 作者被封禁（status=0）或被注销（deletedAt） → 不可见
  const author = await prisma.user.findUnique({
    where: { id: authorId },
    select: { status: true, deletedAt: true },
  });
  if (!author || author.status === 0 || author.deletedAt) return false;

  // 双向拉黑 → 互相不可见
  if (viewerId) {
    const [a, b] = await Promise.all([
      prisma.blocklist.findUnique({
        where: { userId_blockedId: { userId: viewerId, blockedId: authorId } },
      }),
      prisma.blocklist.findUnique({
        where: { userId_blockedId: { userId: authorId, blockedId: viewerId } },
      }),
    ]);
    if (a || b) return false;
  }

  // 隐私设置
  const ps = await prisma.privacySettings.findUnique({ where: { userId: authorId } });
  const vis = ps?.postVisibility ?? 'public';
  if (vis === 'public') return true;
  if (!viewerId) return false; // 匿名用户看不到非公开内容
  if (authorId === viewerId) return true; // 自己总能看到自己
  if (vis === 'private') return false;
  if (vis === 'followers') {
    const f = await prisma.follow.findUnique({
      where: { followerId_followingId: { followerId: viewerId, followingId: authorId } },
    });
    return !!f;
  }
  return true;
}
