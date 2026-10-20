import { prisma } from '../prisma';
import { computeHotScore } from '../utils/hotScore';

// 热度分（hotScore）：推荐流与热榜的排序信号。
// 公式与权重在 utils/hotScore.ts（纯函数，不依赖 Prisma），这里负责落库与批量重算。
// 保留同名导出，历史调用点不感知这次拆分。
export { computeHotScore };

// 单帖增量重算：互动/评论/浏览等计数变化后调用，保证排序信号近实时
export async function bumpHotScore(postId: number): Promise<void> {
  try {
    const post = await prisma.post.findUnique({
      where: { id: postId },
      select: {
        upCount: true,
        commentCount: true,
        bookmarkCount: true,
        viewCount: true,
        createdAt: true,
      },
    });
    if (!post) {
      return;
    }
    const score = computeHotScore(
      post.upCount,
      post.commentCount,
      post.bookmarkCount,
      post.viewCount,
      post.createdAt,
    );
    await prisma.post.update({ where: { id: postId }, data: { hotScore: score } });
  } catch (e) {
    // 热度重算失败不阻断主流程（排序短暂滞后可接受）
    console.warn('[hotScore] bumpHotScore 失败:', (e as Error).message);
  }
}

// 全量重算：部署/初始化后或运营调参时触发（低频率，批内逐条更新，量小时足够）
export async function recomputeAllHotScores(now: Date = new Date()): Promise<number> {
  const rows = await prisma.post.findMany({
    where: { deletedAt: null },
    select: {
      id: true,
      upCount: true,
      commentCount: true,
      bookmarkCount: true,
      viewCount: true,
      createdAt: true,
    },
  });
  for (const r of rows) {
    const score = computeHotScore(
      r.upCount,
      r.commentCount,
      r.bookmarkCount,
      r.viewCount,
      r.createdAt,
      now,
    );
    await prisma.post.update({ where: { id: r.id }, data: { hotScore: score } });
  }
  return rows.length;
}