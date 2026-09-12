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

// 悬浮底栏占用的屏幕底部高度（BAR_HEIGHT 62 + BAR_BOTTOM_GAP 18 + 系统导航条高度）
// 各滚动列表底部内边距用此值，末尾内容可滚动到底栏上方而不被遮挡
export function barBottomReserve(): number {
  const nav: number = AppStorage.get<number>('navBarHeight') ?? 0;
  return LayoutTokens.floatingBarReserve + nav;
}

// 底部导航条避让（审核问题③）：三键导航设备上系统导航条占据屏幕底部区域，
// 贴底交互控件必须整体抬高避让，否则被审核判定「底部控件抬高避让小于 28vp」。
// navBarHeight = max(TYPE_SYSTEM, TYPE_NAVIGATION_INDICATOR) 的 bottomRect（Index 启动时测量）。
// 三键导航下系统报告值之上再加 10vp 呼吸空间（2026-09-12 真机实测：正好贴导航区上沿仍显挤）；
// 手势导航 navBarHeight≈指示条高度（>0），同样享受余量；纯无导航环境为 0 不受影响。
const NAV_INSET_EXTRA: number = 10;

export function bottomNavInset(): number {
  const nav: number = AppStorage.get<number>('navBarHeight') ?? 0;
  return nav > 0 ? nav + NAV_INSET_EXTRA : 0;
}
