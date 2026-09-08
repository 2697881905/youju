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
