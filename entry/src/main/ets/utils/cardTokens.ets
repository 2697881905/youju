// 旧页面兼容适配层：数值唯一来源已迁移到 design/tokens，Phase4 完成后删除这些别名。
import { RadiusTokens } from '../design/tokens/radius';
import { ShadowTokens } from '../design/tokens/shadow';
import { LayoutTokens, SpaceTokens } from '../design/tokens/space';
import { NAV_MODE_KEY, NAV_BUTTON_BAR_HEIGHT_KEY, NAV_MODE_THREE_BUTTON, NAV_MODE_GESTURE, NAV_MODE_FLOATING_BALL } from './navMode';

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

// 底部导航条避让（审核问题③ + 本次 AGC 反馈「详情页底栏被三键导航遮挡」）：
// 三键导航设备上系统导航条占据屏幕底部区域，贴底交互控件必须整体抬高避让，
// 否则被审核判定「底部控件抬高避让小于 28vp」。
// 双信号判别（详见 utils/navMode.ets）：
//   ① 权威：settings 'float_navigation_info' 的 showType（0=三键 / 1=悬浮球 / -1=手势），
//      三键时还给出 region 真实栏高（px→vp），无启发式；
//   ② 兜底：navBarHeight（= max(TYPE_SYSTEM, TYPE_NAVIGATION_INDICATOR) 的 bottomRect，vp）
//      高度阈值判别 —— 三键≈28-42vp、手势指示条≈16-24vp，区间不重叠，阈值取 24。
//   ①不可用（键缺失/非华为 ROM/模拟器）时退回②，行为与历史版本一致。
// 数据刷新：navBarHeight 由 Index 启动测量 + PostDetailView avoidAreaChange 监听实时刷新；
// navMode 由 EntryAbility 启动时经 navMode.initNavModeWatcher 注册 settings 监听实时刷新。
// 三键时再加 10vp 呼吸空间（真机实测贴上沿仍显挤）。手势/悬浮球返回 0（维持原布局）。
// 阈值与呼吸间隔导出给 DetailActionBar 等响应式消费方复用，避免魔法数分叉。
export const GESTURE_INDICATOR_MAX: number = 24;
export const NAV_INSET_EXTRA: number = 10;

// 当前是否三键导航（settings 判别优先；键缺失时退回高度阈值判别）
export function isThreeButtonNav(): boolean {
  const mode: string = (AppStorage.get<string>(NAV_MODE_KEY) ?? '');
  if (mode === NAV_MODE_GESTURE || mode === NAV_MODE_FLOATING_BALL) {
    return false;
  }
  if (mode === NAV_MODE_THREE_BUTTON) {
    return true;
  }
  return (AppStorage.get<number>('navBarHeight') ?? 0) > GESTURE_INDICATOR_MAX;
}

export function bottomNavInset(): number {
  if (isThreeButtonNav()) {
    // 三键：settings 给出的真实栏高与避让区测量取大者，再加 10vp 呼吸
    const bar: number = AppStorage.get<number>(NAV_BUTTON_BAR_HEIGHT_KEY) ?? 0;
    const nav: number = AppStorage.get<number>('navBarHeight') ?? 0;
    return Math.max(bar, nav) + NAV_INSET_EXTRA;
  }
  // 手势导航条 / 悬浮球：底部无系统栏遮挡，维持原布局
  return 0;
}

// —— 悬浮 Dock 几何（首页 HdsTabs 悬浮条 与 详情页 Dock 共用；改这里两处同步）——
// barWidth.smallWidth：手机竖屏档 Dock 宽（Index 的 barFloatingStyle 与 DetailActionBar 共用）
export const DOCK_WIDTH_SMALL: number = 300;
// barBottomMargin 基数：Dock 底沿到系统导航区上沿的呼吸（实际 = 此值 + bottomNavInset()）
export const DOCK_BOTTOM_MARGIN_BASE: number = 28;
// barSideMargin：Dock 距屏幕侧边的最小留白
export const DOCK_SIDE_MARGIN_MIN: number = 16;
// 首页系统 HdsTabs.barFloatingStyle 的材质参数；详情页 Dock 只在系统组件不可用时降级。
export const DOCK_GRADIENT_MASK_HEIGHT: number = 92;
export const DOCK_MATERIAL_TYPE: number = 101;
export const DOCK_MATERIAL_LEVEL: number = 10;
