// design token: radius. 内嵌元素遵守外层半径减内边距的同心原则。
export class RadiusTokens {
  static readonly none: number = 0;
  static readonly xs: number = 6;
  static readonly sm: number = 10;
  static readonly md: number = 14;
  static readonly lg: number = 20;
  // 卡内嵌套媒体的同心圆角：lg(20) − 卡片内边距 item(12) = 8。
  // 图片格 / 视频预览 / 虚线添加位统一走它，避免各处手填 8/12 两档 drift。
  static readonly nested: number = 8;
  static readonly xl: number = 28;
  static readonly floatingBar: number = 30;
  static readonly pill: number = 999;
}
