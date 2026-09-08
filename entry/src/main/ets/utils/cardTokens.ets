// 旧页面兼容适配层：数值唯一来源已迁移到 design/tokens，Phase4 完成后删除这些别名。
import { RadiusTokens } from '../design/tokens/radius';
import { ShadowTokens } from '../design/tokens/shadow';
import { LayoutTokens, SpaceTokens } from '../design/tokens/space';

export const CARD_RADIUS: number = RadiusTokens.lg;
export const CARD_PADDING: number = SpaceTokens.base;
export const CARD_COVER_RADIUS: number = RadiusTokens.xs;
export const CARD_SHADOW: ShadowOptions = ShadowTokens.cardAmbient;
export const GRID_GAP: number = LayoutTokens.gridGutter;
export const GRID_PADDING: number = SpaceTokens.pageCompact;
export const CARD_INNER_GAP: number = SpaceTokens.item;
export const PAGE_HORIZONTAL_PADDING: number = SpaceTokens.pageCompact;
export const SECTION_GAP: number = SpaceTokens.block;
export const CONTROL_RADIUS: number = RadiusTokens.sm;
export const CONTROL_HEIGHT: number = LayoutTokens.segmentedHeight;

// 悬浮底栏（Index 底部 HdsTabs 药丸）占用的屏幕底部高度。
// 几何 = barBottomMargin 28 + 药丸高 ~64 + 呼吸 ~28，已并入 LayoutTokens.floatingBarReserve(120)；
// 另加系统导航条高度 nav（手势/三键导航区域），该值由 Index.setupFullScreen 写入 AppStorage。
// 各滚动列表（含 WaterFlow footer / List 尾部占位）用此值，保证最后一张卡片能完整滑到药丸上方。
export function barBottomReserve(): number {
  const nav: number = AppStorage.get<number>('navBarHeight') ?? 0;
  return LayoutTokens.floatingBarReserve + nav;
}
