// 首页内容分区：由帖子体裁派生，不产生独立分类数据。
// 后端镜像：backend/src/utils/feedZones.ts（ArkTS 与 Node 不共享模块，改动须同批提交）。
export type FeedZone = 'insight' | 'life';

export const FEED_ZONE_KEYS: FeedZone[] = ['insight', 'life'];
export const FEED_ZONE_LABELS: string[] = ['干货', '随记'];

export function zoneKey(index: number): FeedZone {
  return FEED_ZONE_KEYS[index] ?? 'insight';
}

export function zoneLabel(index: number): string {
  return FEED_ZONE_LABELS[index] ?? FEED_ZONE_LABELS[0];
}
