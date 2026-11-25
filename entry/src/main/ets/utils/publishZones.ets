// 发布页「内容区」数据源：顺序与 key 必须与首页分区（feedZones）完全一致，禁止另立一套文案。
import { FeedZone, FEED_ZONE_KEYS, FEED_ZONE_LABELS } from './feedZones';
import { Genre } from '../models/types';
import type { SegmentedItem } from '../design/components/ImmersiveSegmentBar';

export const PUBLISH_ZONE_SEGMENTS: SegmentedItem[] = FEED_ZONE_KEYS.map(
  (key: FeedZone, index: number): SegmentedItem => {
    return { key: key, label: FEED_ZONE_LABELS[index] };
  });

export function publishZoneKey(index: number): FeedZone {
  return FEED_ZONE_KEYS[index] ?? 'insight';
}

export function publishZoneIndexOf(zone: FeedZone): number {
  for (let i = 0; i < FEED_ZONE_KEYS.length; i++) {
    if (FEED_ZONE_KEYS[i] === zone) {
      return i;
    }
  }
  return 0;
}

export function zoneOfGenre(genre: string): FeedZone {
  return genre === 'share' ? 'life' : 'insight';
}

// 内容区在体裁尚未确定时的兜底落库体裁：干货 → review，随记 → share。
// 用函数而非 Record 常量：ArkTS 不支持以联合类型为键的对象字面量（arkts-no-untyped-obj-literals）。
export function fallbackGenreOf(zone: FeedZone): Genre {
  return zone === 'life' ? 'share' : 'review';
}

export function publishZoneHint(zone: FeedZone): string {
  return zone === 'life'
    ? '随记是轻量图文，不做结构化'
    : 'AI 会把正文整理成结构化信息块，发布前确认';
}