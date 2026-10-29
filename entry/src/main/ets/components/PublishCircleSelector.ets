// 发布页「分类」区：已选圈子胶囊 + 虚线添加位（同一行内换行排布）。
// 三页此前各自复制一份 tagPill/circleSelector builder，样式改一处就要改三处，现收敛为组件。
// 添加位用虚线框而不是实体按钮：它永远是队列末尾的「下一步」，不是与胶囊同级的操作。
import { LengthMetrics } from '@kit.ArkUI';
import { ColorTokens } from '../design/tokens/color';
import { IconTokens } from '../design/tokens/icon';
import { MotionCurves, MotionTokens } from '../design/tokens/motion';
import { RadiusTokens } from '../design/tokens/radius';
import { LayoutTokens, SpaceTokens } from '../design/tokens/space';
import { TypeTokens } from '../design/tokens/type';
import { Pressable } from '../design/motion/Pressable';
import { TagIcon } from './TagIcon';

@Component
export struct PublishCircleSelector {
  @Prop selectedTags: string[] = [];
  @Prop maxSelected: number = 3;
  onAdd: () => void = (): void => {};
  onRemove: (name: string) => void = (_name: string): void => {};

  private canAdd(): boolean {
    return this.selectedTags.length < this.maxSelected;
  }

  // Pressable 是自定义组件，不能直接挂通用属性 → 动效挂在外层 Row（Flex 的队列单元）上
  @Builder
  private circlePill(name: string): void {
    Row() {
      Pressable({
        visualHeight: LayoutTokens.segmentedHeight,
        action: (): void => { this.onRemove(name); },
      }) {
        Row({ space: SpaceTokens.inlineTight }) {
          TagIcon({
            name: name,
            iconSize: IconTokens.compact,
            tint: ColorTokens.onBrand,
            colorful: false,
          })
          Text(name)
            .fontSize(TypeTokens.callout.size).fontFamily(TypeTokens.fontFamily)
            .fontWeight(TypeTokens.caption.weight)
            .lineHeight(TypeTokens.callout.lineHeight)
            .fontColor(ColorTokens.onBrand)
          Image($r('app.media.close_x_white'))
            .width(IconTokens.compact)
            .height(IconTokens.compact)
            .fillColor(Color.White)
        }
        .height(LayoutTokens.segmentedHeight)
        .padding({ left: SpaceTokens.item, right: SpaceTokens.xs })
        .backgroundColor(ColorTokens.brandSolid)
        .borderRadius(RadiusTokens.pill)
        .alignItems(VerticalAlign.Center)
      }
    }
    .transition(TransitionEffect.OPACITY
      .combine(TransitionEffect.scale({ x: 0.88, y: 0.88 }))
      .animation({ duration: MotionTokens.fast, curve: MotionCurves.decelerate }))
  }

  @Builder
  private addChip(): void {
    Row() {
      Pressable({
        visualHeight: LayoutTokens.segmentedHeight,
        action: (): void => { this.onAdd(); },
      }) {
        Text(this.selectedTags.length === 0 ? '添加圈子' : '继续添加')
          .fontSize(TypeTokens.callout.size).fontFamily(TypeTokens.fontFamily)
          .fontWeight(TypeTokens.caption.weight)
          .lineHeight(TypeTokens.callout.lineHeight)
          .fontColor(ColorTokens.brand)
          .height(LayoutTokens.segmentedHeight)
          .padding({ left: SpaceTokens.item, right: SpaceTokens.item })
          .borderRadius(RadiusTokens.pill)
          .border({ width: 1, color: ColorTokens.brandTint, style: BorderStyle.Dashed })
          .textAlign(TextAlign.Center)
      }
    }
    .transition(TransitionEffect.OPACITY
      .animation({ duration: MotionTokens.fast, curve: MotionCurves.decelerate }))
  }

  build() {
    Flex({
      wrap: FlexWrap.Wrap,
      space: { main: LengthMetrics.px(SpaceTokens.inline), cross: LengthMetrics.px(SpaceTokens.inline) },
    }) {
      ForEach(this.selectedTags, (name: string) => {
        this.circlePill(name)
      }, (name: string) => 'circle_' + name)
      if (this.canAdd()) {
        this.addChip()
      }
    }
    .width('100%')
  }
}
