import { TagIcon } from '../../components/TagIcon';
import { Pressable } from '../motion/Pressable';
import { ColorTokens } from '../tokens/color';
import { IconTokens } from '../tokens/icon';
import { MotionCurves, MotionTokens } from '../tokens/motion';
import { RadiusTokens } from '../tokens/radius';
import { LayoutTokens, SpaceTokens } from '../tokens/space';
import { TypeTokens } from '../tokens/type';

export interface ChipItem {
  key: string;
  label: string;
  iconName?: string;
}

@Component
export struct ChipRow {
  @Prop items: ChipItem[] = [];
  @Link selectedIndex: number;
  @Prop showIcon: boolean = true;
  @Prop sidePadding: number = SpaceTokens.pageCompact;
  @Prop itemGap: number = SpaceTokens.item;
  @Prop chipHeight: number = LayoutTokens.segmentedHeight;
  // 首页信息流使用紧凑标签，其他页面仍保持默认的舒适尺寸。
  @Prop compact: boolean = false;
  @Prop glass: boolean = false;
  onSelect?: (index: number) => void = undefined;

  private select(index: number): void {
    if (index < 0 || index >= this.items.length) {
      return;
    }
    if (this.selectedIndex !== index) {
      this.selectedIndex = index;
    }
    if (this.onSelect !== undefined) {
      this.onSelect(index);
    }
  }

  build() {
    Scroll() {
      Row({ space: this.itemGap }) {
        ForEach(
          this.items,
          (item: ChipItem, index: number) => {
            Pressable({
              visualHeight: this.chipHeight,
              touchTargetHeight: LayoutTokens.minTouchTarget,
              action: () => { this.select(index); },
            }) {
              Row({ space: this.compact ? SpaceTokens.inlineTight : SpaceTokens.inline }) {
                if (this.showIcon && item.iconName !== undefined) {
                  TagIcon({
                    name: item.iconName,
                    iconSize: IconTokens.compact,
                    tint: this.selectedIndex === index
                      ? (this.glass ? ColorTokens.primary : ColorTokens.onBrand)
                      : (this.glass ? ColorTokens.secondary : ColorTokens.primary),
                    colorful: this.selectedIndex !== index,
                  })
                }
                Text(item.label)
                  .fontSize(this.compact ? TypeTokens.caption.size : TypeTokens.callout.size).fontFamily(TypeTokens.fontFamily)
                  .fontWeight(this.selectedIndex === index ? TypeTokens.headline.weight : TypeTokens.caption.weight)
                  .lineHeight(TypeTokens.callout.lineHeight)
                  .letterSpacing(TypeTokens.callout.tracking)
                  .fontColor(this.selectedIndex === index
                    ? (this.glass ? ColorTokens.primary : ColorTokens.onBrand)
                    : (this.glass ? ColorTokens.secondary : ColorTokens.primary))
                  .maxLines(1)
                  .textOverflow({ overflow: TextOverflow.Ellipsis })
              }
              .height(this.chipHeight)
              .padding({
                left: this.compact ? SpaceTokens.sm : SpaceTokens.item,
                right: this.compact ? SpaceTokens.sm : SpaceTokens.item,
              })
              .backgroundColor(this.selectedIndex === index
                ? (this.glass ? ColorTokens.barSelectionSurface : ColorTokens.brand)
                : (this.glass ? Color.Transparent : ColorTokens.sunken))
              .borderRadius(this.glass ? RadiusTokens.lg : RadiusTokens.sm)
              .alignItems(VerticalAlign.Center)
              .animation({ duration: MotionTokens.fast, curve: MotionCurves.standard })
            }
          },
          (item: ChipItem) => item.key
        )
      }
      .padding({ left: this.sidePadding, right: this.sidePadding })
    }
    .width('100%')
    .height(this.chipHeight)
    .scrollable(ScrollDirection.Horizontal)
    .scrollBar(BarState.Off)
  }
}
