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
// ⚠️ 两种导航模式共用 TYPE_NAVIGATION_INDICATOR：三键≈28-42vp、手势指示条≈16-24vp，
// 无公开 API 区分模式，按高度阈值判别（2026-09-12 用户要求：间隙只对三键变大，
// 手势态维持原设计间距）。三键时再加 10vp 呼吸空间（真机实测贴上沿仍显挤）。
const GESTURE_INDICATOR_MAX: number = 24;
const NAV_INSET_EXTRA: number = 10;

export function bottomNavInset(): number {
  const nav: number = AppStorage.get<number>('navBarHeight') ?? 0;
  if (nav <= GESTURE_INDICATOR_MAX) {
    return 0; // 手势指示条：维持原布局（18vp gap 原设计）
  }
  return nav + NAV_INSET_EXTRA; // 三键导航条：避让 + 呼吸空间
}
