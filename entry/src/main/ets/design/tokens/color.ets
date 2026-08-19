// design token: color. 页面与组件只消费此入口，不直接依赖资源名。
export class ColorTokens {
  static readonly canvas: ResourceColor = $r('app.color.ds_canvas');
  static readonly elevated: ResourceColor = $r('app.color.ds_elevated');
  static readonly subtle: ResourceColor = $r('app.color.ds_subtle');
  static readonly sunken: ResourceColor = $r('app.color.ds_sunken');

  static readonly primary: ResourceColor = $r('app.color.ds_text_primary');
  static readonly secondary: ResourceColor = $r('app.color.ds_text_secondary');
  static readonly tertiary: ResourceColor = $r('app.color.ds_text_tertiary');
  static readonly quaternary: ResourceColor = $r('app.color.ds_text_quaternary');

  static readonly brand: ResourceColor = $r('app.color.ds_brand');
  static readonly brandTint: ResourceColor = $r('app.color.ds_brand_tint');
  static readonly brandPress: ResourceColor = $r('app.color.ds_brand_press');
  static readonly onBrand: ResourceColor = $r('app.color.ds_on_brand');

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
  static readonly glassGlowHeavy: ResourceColor = '#E6FFFFFF';
  static readonly glassGlowMedium: ResourceColor = '#70FFFFFF';
  static readonly glassSheenTop: ResourceColor = '#30FFFFFF';
  static readonly glassSheenUpper: ResourceColor = '#14FFFFFF';
  static readonly glassSheenLower: ResourceColor = '#06FFFFFF';
  static readonly glassSheenBottom: ResourceColor = '#10000000';
  static readonly barSurface: ResourceColor = $r('app.color.bar_surface');
  static readonly barBorder: ResourceColor = $r('app.color.bar_border');
  static readonly barShadow: ResourceColor = $r('app.color.bar_shadow');
  static readonly barSelectionSurface: ResourceColor = $r('app.color.bar_selection_surface');
  static readonly barSelectionBorder: ResourceColor = $r('app.color.bar_selection_border');
}
