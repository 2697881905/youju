import { TagIcon } from './TagIcon';
import { Pressable } from '../design/motion/Pressable';
import { ColorTokens } from '../design/tokens/color';
import { IconTokens } from '../design/tokens/icon';
import { MotionCurves, MotionTokens } from '../design/tokens/motion';
import { RadiusTokens } from '../design/tokens/radius';
import { LayoutTokens, SpaceTokens } from '../design/tokens/space';
import { TypeTokens } from '../design/tokens/type';
import { isImmersiveLightSenseSupported, GlassBlurStyle } from '../utils/immersiveMaterial';
import { ImmersiveSurface } from '../design/components/ImmersiveSurface';

// 星环选中态资料卡独立于角度/手势计算，保留底部栏一致的玻璃层级和切换编舞。
// 沉浸光感绑定：ImmersiveSurface 作为 Row 的 flex 子项（layoutWeight）拿到确定宽度，
// 流光层由根 Stack 实测尺寸贴合卡片；不能用 calc(100%-x) 百分比（在 auto 父级下解析失效）。
@Component
export struct CircleSelectionCard {
  @Prop name: string = '';
  @Prop description: string = '';
  @Prop memberCount: number = 0;
  @Prop todayActive: number = 0;
  @Prop category: string = '';
  onOpen: () => void = (): void => {};

  @Builder
  cardBody(): void {
    Column({ space: SpaceTokens.xs }) {
      Row({ space: SpaceTokens.sm }) {
        TagIcon({ name: this.name, iconSize: IconTokens.standard + 8, tint: ColorTokens.brand })
          .width(40)
          .height(40)
        Column({ space: 2 }) {
          Text(this.name)
            .fontSize(TypeTokens.callout.size).fontFamily(TypeTokens.fontFamily)
            .fontWeight(TypeTokens.headline.weight)
            .lineHeight(TypeTokens.callout.lineHeight)
            .fontColor(ColorTokens.primary)
          Text(this.description)
            .fontSize(TypeTokens.navLabel.size).fontFamily(TypeTokens.fontFamily)
            .fontWeight(TypeTokens.navLabel.weight)
            .lineHeight(TypeTokens.navLabel.lineHeight)
            .fontColor(ColorTokens.secondary)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)
        Pressable({
          visualHeight: LayoutTokens.segmentedHeight,
          touchTargetHeight: LayoutTokens.minTouchTarget,
          action: (): void => { this.onOpen(); },
        }) {
          Text('进入')
            .width(64)
            .height(LayoutTokens.segmentedHeight)
            .fontSize(TypeTokens.caption.size).fontFamily(TypeTokens.fontFamily)
            .fontWeight(TypeTokens.headline.weight)
            .lineHeight(TypeTokens.caption.lineHeight)
            .fontColor(ColorTokens.primary)
            .textAlign(TextAlign.Center)
            .backgroundColor(Color.Transparent)
            .border({ width: LayoutTokens.glassBorderWidth, color: ColorTokens.barBorder, style: BorderStyle.Solid })
            .borderRadius(RadiusTokens.lg)
        }
      }
      Row({ space: SpaceTokens.sm }) {
        Text(String(this.memberCount) + ' 人加入')
          .fontSize(TypeTokens.caption.size).fontFamily(TypeTokens.fontFamily)
          .fontWeight(TypeTokens.caption.weight)
          .lineHeight(TypeTokens.caption.lineHeight)
          .fontFeature(TypeTokens.tabularFeature)
          .fontColor(ColorTokens.tertiary)
        if (this.todayActive > 0) {
          Text('今日活跃 ' + this.todayActive)
            .fontSize(TypeTokens.caption.size).fontFamily(TypeTokens.fontFamily)
            .fontWeight(TypeTokens.caption.weight)
            .lineHeight(TypeTokens.caption.lineHeight)
            .fontFeature(TypeTokens.tabularFeature)
            .fontColor(ColorTokens.tertiary)
        }
        Text(this.category)
          .fontSize(TypeTokens.overline.size).fontFamily(TypeTokens.fontFamily)
          .fontWeight(TypeTokens.overline.weight)
          .lineHeight(TypeTokens.overline.lineHeight)
          .fontColor(ColorTokens.primary)
          .padding({ left: SpaceTokens.xs, right: SpaceTokens.xs, top: 1, bottom: 1 })
          .backgroundBlurStyle(GlassBlurStyle.Press)
          .backgroundColor(isImmersiveLightSenseSupported() ? Color.Transparent : ColorTokens.barSurface)
          .border({ width: LayoutTokens.glassBorderWidth, color: ColorTokens.barBorder, style: BorderStyle.Solid })
          .borderRadius(RadiusTokens.pill)
          .shadow({ radius: 6, color: ColorTokens.barShadow, offsetY: 2 })
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)
    }
    .width('100%')
    .height(116)
    .padding(SpaceTokens.md)
    .justifyContent(FlexAlign.SpaceBetween)
    .backgroundBlurStyle(GlassBlurStyle.Card)
    .backgroundColor(isImmersiveLightSenseSupported() ? Color.Transparent : ColorTokens.barSurface)
    .border({ width: LayoutTokens.glassBorderWidth, color: ColorTokens.barBorder, style: BorderStyle.Solid })
    .borderRadius(RadiusTokens.lg)
    .shadow({ radius: 14, color: ColorTokens.barShadow, offsetY: 6 })
    .clip(true)
  }

  build() {
    Row() {
      ImmersiveSurface({
        radius: RadiusTokens.lg,
        content: (): void => { this.cardBody() },
      })
        .layoutWeight(1)
        .margin({ top: SpaceTokens.x2l })
    }
    .width('100%')
    .padding({ left: 18, right: 18 })
    .justifyContent(FlexAlign.Center)
    .transition(TransitionEffect.OPACITY
      .animation({ duration: MotionTokens.enter, curve: MotionCurves.spring })
      .combine(TransitionEffect.scale({ x: 0.8, y: 0.8 })
        .animation({ duration: MotionTokens.enter, curve: MotionCurves.spring }))
      .combine(TransitionEffect.translate({ y: SpaceTokens.md })
        .animation({ duration: MotionTokens.enter, curve: MotionCurves.spring })))
  }
}
