// design token: space. 所有布局间距保持 4vp 基线。
export class SpaceTokens {
  static readonly none: number = 0;
  static readonly xs: number = 4;
  static readonly sm: number = 8;
  static readonly md: number = 12;
  static readonly base: number = 16;
  static readonly lg: number = 20;
  static readonly xl: number = 24;
  static readonly x2l: number = 32;
  static readonly x3l: number = 48;

  static readonly inlineTight: number = SpaceTokens.xs;
  static readonly inline: number = SpaceTokens.sm;
  static readonly item: number = SpaceTokens.md;
  static readonly block: number = SpaceTokens.base;
  static readonly section: number = SpaceTokens.xl;
  static readonly pageCompact: number = SpaceTokens.base;
  static readonly pageWide: number = SpaceTokens.lg;
}

export class LayoutTokens {
  static readonly gridGutter: number = SpaceTokens.md;
  static readonly compactBreakpoint: number = 440;
  static readonly expandedBreakpoint: number = 840;
  static readonly contentMaxWidth: number = 720;
  static readonly minTouchTarget: number = 44;
  // 帖子封面统一使用 3:4 竖版比例，保证信息流中的图片完整可见。
  static readonly cardMediaAspectRatio: number = 0.75;
  static readonly revealOffset: number = SpaceTokens.sm;
  static readonly skeletonDefaultWidth: number = 160;
  static readonly skeletonHighlightWidth: number = 56;
  static readonly segmentedHeight: number = 36;
  // 顶栏圆形图标钮的可视尺寸：对齐官方实测 40×40vp（原生电话 HdsTitleBar 菜单钮节点真值）。
  // 原用 segmentedHeight(36) 是借了分段栏的数，与官方差 4vp。见
  // docs/harmonyos-official-ui-alignment-baseline.md §7.6。
  static readonly iconButton: number = 40;
  // 官方 SegmentButton（tab 样式）分段栏高度：参考App 设备详情页顶栏实测 123px = 39.4vp，取整 40。
  static readonly segmentBarHeight: number = 40;
  // 该栏下方要留出的投影净空：真机实测 ULTRA_THIN 材质投影从轨道底边 227 起，要 84px（26.9vp）
  // 才收敛回画布白 → 净空给到 28vp（87.5px）。bottomBuilder 行对内容双向裁切，
  // 行高不足时投影收尾被拦腰截断成一条硬边灰带（同 docs/tutorial-titlebar-immersive-light.md 案例 9）。
  static readonly segmentBarShadowRoom: number = 28;
  // 该栏上方的投影净空：材质投影同样向上散开，真机实测从轨道顶边 246 起、上探 34px（10.9vp）
  // 收敛回画布白 → 给 14vp。分段栏顶边原先与 bottomBuilder 行裁切边界齐平，向上的投影被硬切。
  static readonly segmentBarTopRoom: number = 14;
  // 首页品牌标题行高度：容纳双行品牌块（有据 + 标语），触控目标(44) + 一个 base 步进(16)。
  static readonly titleBarHeight: number = LayoutTokens.minTouchTarget + SpaceTokens.base;
  static readonly tabBarHeight: number = 64;
  static readonly tabBarItemWidth: number = 58;
  static readonly tabBarItemHeight: number = 50;
  static readonly tabBarGlowSize: number = 180;
  static readonly tabBarSideMargin: number = 18;
  static readonly tabBarBottomGap: number = 18;
  static readonly glassBlur: number = 24;
  static readonly glassBorderWidth: number = 1;
  static readonly floatingBarReserve: number = 94;
  static readonly composerGenreCardHeight: number = 112;
  static readonly composerBodyHeight: number = 124;
  static readonly composerFieldHeight: number = 72;
  static readonly composerTopOverlayReserve: number = 104;
  static readonly profileStatWidth: number = 72;
  static readonly hairlineWidth: number = 0.5;
}
