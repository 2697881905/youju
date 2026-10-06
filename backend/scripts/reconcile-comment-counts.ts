// 一次性校准：把每个帖子的 commentCount 重算为「可见评论数(status=1)」。
//
// 背景：举报下架/恢复评论此前只改 Comment.status，未同步 Post.commentCount，
// 导致评论区计数虚高（评论被举报删除后计数不变）。增量维护已在 reportService
// 修复，但历史已下架数据不会自动回正，需运行本脚本校准一次。
//
// 运行：npx tsx scripts/reconcile-comment-counts.ts
import { prisma } from '../src/prisma';

async function main(): Promise<void> {
  // 一次 groupBy 拿到每个帖子的可见评论数，避免逐帖 count 的 N+1 查询
  const grouped = await prisma.comment.groupBy({
    by: ['postId'],
    where: { status: 1 },
    _count: { _all: true },
  });
  const actualByPost = new Map<number, number>();
  for (const row of grouped) {
    const postId = row.postId;
    if (postId !== null && postId !== undefined) {
      actualByPost.set(postId, row._count._all);
    }
  }

  const posts = await prisma.post.findMany({ select: { id: true, commentCount: true } });
  let changed = 0;
  for (const post of posts) {
    const actual = actualByPost.get(post.id) ?? 0;
    if (actual !== post.commentCount) {
      await prisma.post.update({ where: { id: post.id }, data: { commentCount: actual } });
      changed += 1;
      console.log(`post ${post.id}: ${post.commentCount} -> ${actual}`);
    }
  }
  console.log(`校准完成：${changed}/${posts.length} 个帖子已更新`);
}

main()
  .catch((e: unknown) => {
    console.error('校准失败：', e);
    process.exitCode = 1;
  })
  .finally(() => {
    void prisma.$disconnect();
  });