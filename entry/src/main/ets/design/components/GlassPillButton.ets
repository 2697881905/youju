// GlassPillButton —— 玻璃胶囊按钮（家族唯一样式源）
//
// 「草稿箱 / 废纸篓 / 关注 / 私信」同款：系统玻璃模糊底 + 细描边 + floatingBar 圆角
// + 柔和投影 + Pressable 统一按压动效。新增玻璃胶囊按钮一律引用本组件，禁止再手写配方。
//
// 两套表面配方按 useSystemMaterial 分发（由按钮**所处位置**决定，调用方只做选择）：
// - true（驻留标题栏/浮层，systemMaterial 能出图的位置）：材质接管表面——blur 置 NONE
//   （官方 FAQ：背景模糊遮挡材质）、描边/阴影归零；低版本门禁不通过自动回落玻璃兜底。
// - false（内容区，材质渲染不出图的位置）：常驻 backgroundBlurStyle + barSurface 兜底
//   （真机实测内容区押材质会退化成「只剩描边的透明壳」，见基准 §7.6.26）。
// 两套守卫逻辑只在本组件写一份——修复此前 ProfileHeader/UserProfileView 各写一套且
// 守卫项不一致的问题。
import { Pressable } from '../motion/Pressable';
import { ColorTokens } from '../tokens/color';
import { IconTokens } from '../tokens/icon';
import { MotionCurves, MotionTokens } from '../tokens/motion';
import { RadiusTokens } from '../tokens/radius';
import { ShadowTokens } from '../tokens/shadow';
import { LayoutTokens, SpaceTokens } from '../tokens/space';
import { TypeTokens } from '../tokens/type';
import {
  GlassBlurStyle,
  isImmersiveLightSenseSupported,
  isSystemMaterialActive,
  TopButtonMaterialModifier,
} from '../../utils/immersiveMaterial';
import { resolveActionIcon } from '../../utils/actionIcons';

@Component
export struct GlassPillButton {
  @Prop label: string = '';
  // 前置线条图标（ACTION_ICONS 名，'' = 无图标）
  @Prop icon: string = '';
  @Prop fillWidth: boolean = false;
  @Prop disabled: boolean = false;
  // 文字降为 secondary（「已关注」这类已达成态）
  @Prop muted: boolean = false;
  // 强调态（「去登录」这类转化入口）：brandTint 底 + brand 描边 + brandPress 字，
  // 盖过玻璃表面（brand 字压 brandTint 只 3.58:1，压深一档 brandPress 4.56:1 起）
  @Prop highlight: boolean = false;
  // 成功脉冲（关注成功的 spring 放大；调用方在动作成功后置 true，回弹时置回 false）
  @Prop successPulse: boolean = false;
  // 按钮位置是否允许系统材质出图：标题栏/浮层=true，内容区=false（见文件头）
  @Prop useSystemMaterial: boolean = false;
  action: () => void = (): void => {};
  private materialModifier: TopButtonMaterialModifier = new TopButtonMaterialModifier();

  // 材质生效时自绘表面全部让位；否则按玻璃兜底配方
  private materialActive(): boolean {
    return this.useSystemMaterial && isSystemMaterialActive();
  }

  build() {
    Pressable({
      disabled: this.disabled,
      fillWidth: this.fillWidth,
      visualHeight: LayoutTokens.segmentedHeight,
      action: this.action,
    }) {
      Row({ space: SpaceTokens.inlineTight }) {
        if (this.icon !== '') {
          Image(resolveActionIcon(this.icon))
            .width(IconTokens.compact)
            .height(IconTokens.compact)
            .fillColor(ColorTokens.icon)
        }
        Text(this.label)
          .fontSize(this.fillWidth ? TypeTokens.callout.size : TypeTokens.caption.size)
          .fontFamily(TypeTokens.fontFamily)
          .fontWeight(TypeTokens.headline.weight)
          .lineHeight(this.fillWidth ? TypeTokens.callout.lineHeight : TypeTokens.caption.lineHeight)
          .fontColor(this.highlight ? ColorTokens.brandPress
            : (this.muted ? ColorTokens.secondary : ColorTokens.primary))
          .maxLines(1)
      }
      .width(this.fillWidth ? '100%' : 'auto')
      .height(LayoutTokens.segmentedHeight)
      .padding({ left: SpaceTokens.md, right: SpaceTokens.md })
      .justifyContent(FlexAlign.Center)
      .alignItems(VerticalAlign.Center)
      .backgroundBlurStyle(this.materialActive() ? BlurStyle.NONE : GlassBlurStyle.Press)
      // 沉浸光感设备走透明玻璃；不支持的设备以 barSurface 实色兜底（绝不白屏）；
      // highlight 态 brandTint 底盖过玻璃表面
      .backgroundColor(this.highlight ? ColorTokens.brandTint
        : (isImmersiveLightSenseSupported() ? Color.Transparent : ColorTokens.barSurface))
      .border({
        width: this.materialActive() ? 0 : LayoutTokens.glassBorderWidth,
        color: this.highlight ? ColorTokens.brand : ColorTokens.barBorder,
        style: BorderStyle.Solid,
      })
      .borderRadius(RadiusTokens.floatingBar)
      .shadow(this.materialActive()
        ? ShadowTokens.none
        : { radius: 12, color: ColorTokens.barShadow, offsetY: 4 })
      .attributeModifier(this.useSystemMaterial ? this.materialModifier : undefined)
      // 成功脉冲独立于 Pressable 的按压缩放（挂在内容行上，双动画互不打断）
      .scale({
        x: this.successPulse ? MotionTokens.successScale : 1,
        y: this.successPulse ? MotionTokens.successScale : 1,
      })
      .animation({ duration: MotionTokens.emphasis, curve: MotionCurves.springSoft })
    }
  }
}
