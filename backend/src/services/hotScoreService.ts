import { prisma } from '../prisma';

// 热度分（hotScore）：推荐流与热榜的排序信号。
// 第一版公式 = 互动对数加权（up/comment/bookmark 边际收益递减）+ 浏览补充信号 - 线性时效衰减。
// 权重与衰减系数集中在本文件，便于后续 A/B 调参。
const W_UP = 12;
const W_COMMENT = 6;
const W_BOOKMARK = 8;
const W_VIEW = 0.2;
const DECAY_PER_HOUR = 0.22; // 每小时衰减 0.22 分（约 4.5 天后互动分优势被时间抹平）

export function computeHotScore(
  ups: number,
  comments: number,
  bookmarks: number,
  views: number,
  createdAt: Date,
  now: Date = new Date(),
): number {
  const ageHours = Math.max(0, (now.getTime() - createdAt.getTime()) / 3600000);
  // 浏览量边际收益递减：按 50 次为一档取对数，避免刷量内容靠纯浏览量拔高热度
  const viewBonus = Math.log2(1 + Math.max(views - 50, 0) / 50 + 1);
  const engagement =
    W_UP * Math.log2(1 + ups) +
    W_COMMENT * Math.log2(1 + comments) +
    W_BOOKMARK * Math.log2(1 + bookmarks) +
    W_VIEW * viewBonus;
  // toFixed(6) 截断噪声；最终以数值返回
  return Number(Math.max(0, engagement - DECAY_PER_HOUR * ageHours).toFixed(6));
}

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