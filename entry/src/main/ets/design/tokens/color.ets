// design token: color. 页面与组件只消费此入口，不直接依赖资源名。
export class ColorTokens {
  static readonly canvas: ResourceColor = $r('app.color.ds_canvas');
  static readonly elevated: ResourceColor = $r('app.color.ds_elevated');
  static readonly subtle: ResourceColor = $r('app.color.ds_subtle');
  static readonly sunken: ResourceColor = $r('app.color.ds_sunken');
  // 次级内容面板底：比卡片底（elevated）深一档、比 sunken 浅得多的中性灰。
  // 用途：媒体下方的信息条 / 需要「看得出是一块面板」但不想厚重的区域。
  // 浅色 #EFEFF2（对卡片底 #F7F7F8 可辨但不厚重）；深色 #28282C（比卡片底 #1E1E1E 略亮，
  // 是「微微抬起的面板」而不是一个黑洞 —— sunken 的 #0D0D0F 在深色下更黑）。
  static readonly panel: ResourceColor = $r('app.color.ds_panel');
  // 悬浮面板的磨砂底/描边（深浅成对）：叠在页面底上要「看得出是一块面板」。
  // 浅色 = 中性黑低透明（叠白底呈深一档磨砂）；深色 = 白低透明（叠深灰底呈亮一档磨砂）。
  // 用途：私信表情面板 / 媒体菜单 —— 写死的 #20FFFFFF 在白底上不可辨（QA D3）。
  // 消费方式：backdropBlur + backgroundColor(overlay) + border(overlayBorder)。
  static readonly overlay: ResourceColor = $r('app.color.ds_overlay');
  static readonly overlayBorder: ResourceColor = $r('app.color.ds_overlay_border');

  static readonly primary: ResourceColor = $r('app.color.ds_text_primary');
  static readonly secondary: ResourceColor = $r('app.color.ds_text_secondary');
  // 图标专用色：浅色 #3C3C43（比次要文字 #5A5A60 深一档，线条更挺括），深色为纯白。
  // 与次要文字分开放的原因：深色下次要文字用中性灰（#A8A8AE），图标线条用纯白，可视对比更好。
  static readonly icon: ResourceColor = $r('app.color.ds_icon');
  static readonly tertiary: ResourceColor = $r('app.color.ds_text_tertiary');
  static readonly quaternary: ResourceColor = $r('app.color.ds_text_quaternary');

  static readonly brand: ResourceColor = $r('app.color.ds_brand');
  static readonly brandTint: ResourceColor = $r('app.color.ds_brand_tint');
  static readonly brandPress: ResourceColor = $r('app.color.ds_brand_press');
  static readonly onBrand: ResourceColor = $r('app.color.ds_on_brand');
  // @提及专用靛蓝：品牌色改蓝后，与 #话题#（brand 蓝 #0066CC）靠色相区分（靛 243° vs 蓝 210°），
  // 让用户一眼看出点的是「人」而不是「话题」。
  // 两套色板均按 WCAG AA 校过对比度：浅色 #5856D6 对 ds_canvas #FFFFFF ≈ 5.65:1；
  // 深色 #7D7AFF 对 ds_canvas #121212 ≈ 5.44:1。
  static readonly mention: ResourceColor = $r('app.color.ds_mention');

  static readonly warm: ResourceColor = $r('app.color.ds_warm');
  static readonly success: ResourceColor = $r('app.color.ds_success');
  static readonly danger: ResourceColor = $r('app.color.ds_danger');
  static readonly like: ResourceColor = $r('app.color.ds_like');
  static readonly bookmark: ResourceColor = $r('app.color.ds_bookmark');
  static readonly separator: ResourceColor = $r('app.color.ds_separator');

  static readonly skeletonBase: ResourceColor = $r('app.color.ds_skeleton_base');
  static readonly skeletonHighlight: ResourceColor = $r('app.color.ds_skeleton_highlight');

  static readonly shadowSegmented: ResourceColor = '#10000000';
  static readonly shadowPopover: ResourceColor = '#12000000';

  static readonly glassClear: ResourceColor = '#00FFFFFF';
  static readonly glassWhite: ResourceColor = '#FFFFFF';
  // 按压光斑专用色（normal 混合，替代白底上数学不可见的 SCREEN 白光斑）
  static readonly glowTint: ResourceColor = $r('app.color.glow_tint');
  // 分段玻璃（白底上"白玻璃+白高光"失效：浅色改烟灰玻璃，深色保持白高光）
  static readonly segmentBg: ResourceColor = $r('app.color.glass_segment_bg');
  static readonly segmentBorder: ResourceColor = $r('app.color.glass_segment_border');
  static readonly barSurface: ResourceColor = $r('app.color.bar_surface');
  static readonly barBorder: ResourceColor = $r('app.color.bar_border');
  static readonly barShadow: ResourceColor = $r('app.color.bar_shadow');
  static readonly barSelectionSurface: ResourceColor = $r('app.color.bar_selection_surface');
  static readonly barSelectionBorder: ResourceColor = $r('app.color.bar_selection_border');
}
