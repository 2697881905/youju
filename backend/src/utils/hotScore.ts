// 热度分公式的纯函数版本。
//
// 提出来单独放，是为了让「不连库」的场景也能复用同一套权重：冷启动造数工具要在
// 写库前算出排序结果并在 dry-run 里断言「热榜前十是不是这批最好的内容」，
// 如果从 services/hotScoreService 里 import，就会连带把 PrismaClient 拉进来。
// 公式与权重只有这一份，service 那边 import 后再导出，历史调用点不需要改。

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
