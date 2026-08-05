import { CountRoll } from '../design/motion/CountRoll';
import { Pressable } from '../design/motion/Pressable';
import { ColorTokens } from '../design/tokens/color';
import { LayoutTokens, SpaceTokens } from '../design/tokens/space';
import { TypeTokens } from '../design/tokens/type';

// 资料统计项只呈现数值与触控反馈；页面通过回调决定是否允许进入关注/粉丝列表。
@Component
export struct ProfileStatItem {
  @Prop value: number = 0;
  @Prop label: string = '';
  @Prop onBackground: boolean = false;
  @Prop clickable: boolean = false;
  onOpen: () => void = (): void => {};

  build() {
    Pressable({
      disabled: !this.clickable,
      visualHeight: LayoutTokens.segmentedHeight,
      touchTargetHeight: LayoutTokens.minTouchTarget,
      action: (): void => { this.onOpen(); },
    }) {
      Column({ space: SpaceTokens.inlineTight }) {
        CountRoll({
          value: this.value,
          textSize: TypeTokens.headline.size,
          textColor: this.onBackground ? '#FFFFFFFF' : ColorTokens.primary,
        })
          .margin({ left: 3 })
        Text(this.label)
          .fontSize(TypeTokens.caption.size).fontFamily(TypeTokens.fontFamily)
          .fontWeight(TypeTokens.caption.weight)
          .lineHeight(TypeTokens.caption.lineHeight)
          .letterSpacing(TypeTokens.caption.tracking)
          .fontColor(this.onBackground ? '#E6FFFFFF' : ColorTokens.secondary)
      }
      .width(LayoutTokens.profileStatWidth)
      .alignItems(HorizontalAlign.Start)
      .margin({ left: SpaceTokens.xs })
    }
  }
}
