// 旧页面兼容适配层：数值唯一来源已迁移到 design/tokens，Phase4 完成后删除这些别名。
import { RadiusTokens } from '../design/tokens/radius';
import { ShadowTokens } from '../design/tokens/shadow';
import { LayoutTokens, SpaceTokens } from '../design/tokens/space';
import { bottomNavInset as computeNavInset } from './navMode';

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

// 底部导航条避让（审核问题③ + AGC「详情页底栏被三键导航遮挡」）：
// 判别与计算已统一迁移到 utils/navMode.ets —— settings 'float_navigation_info' 权威判别
// （showType 0=三键 / 1=悬浮球 / -1=手势，region 给出真实栏高）+ 避让区高度阈值兜底
// （手势条约 16-24vp、三键条约 28-42vp，阈值 24）+ 三键 10vp 呼吸。本文件只保留旧入口，
// 免改 6 处既有调用点。
// ⚠️ 响应式消费方（随导航方式切换要立即重排的贴底栏）**不要**用 bottomNavInset()：
//    普通函数读 AppStorage 不建立 UI 绑定。应 @StorageLink('bottomNavInsetVp') 并在
//    build 属性里**直接读该变量**（见 DetailActionBar；只在 build 里挂 link 不读变量
//    等于没挂 —— ArkUI 只为「初始渲染时被读过的状态变量」建立更新绑定，两次实测踩坑）。
export function bottomNavInset(): number {
  return computeNavInset();
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
