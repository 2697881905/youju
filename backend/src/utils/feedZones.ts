// 首页内容分区 → 体裁集合。区是 genre 的派生视图：不落库、不新增分类字段、不需要存量回填。
// 前端镜像：entry/src/main/ets/utils/feedZones.ets（ArkTS 与 Node 不共享模块，改动须同批提交）。
export type FeedZone = 'insight' | 'life';

export const FEED_ZONE_GENRES: Record<FeedZone, string[]> = {
  insight: ['review', 'pitfall', 'tutorial', 'debate'],
  life: ['share'],
};

export function isFeedZone(value: unknown): value is FeedZone {
  return typeof value === 'string' && Object.prototype.hasOwnProperty.call(FEED_ZONE_GENRES, value);
}
