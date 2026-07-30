import { Tag } from '../models/types';
import { TagIcon } from './TagIcon';
import { resolveActionIcon } from '../utils/actionIcons';
import { ChipItem, ChipRow } from '../design/components/ChipRow';
import { Pressable } from '../design/motion/Pressable';
import { ColorTokens } from '../design/tokens/color';
import { IconTokens } from '../design/tokens/icon';
import { MotionCurves, MotionTokens } from '../design/tokens/motion';
import { RadiusTokens } from '../design/tokens/radius';
import { LayoutTokens, SpaceTokens } from '../design/tokens/space';
import { TypeTokens } from '../design/tokens/type';

@Component
export struct TagNav {
  @Prop tags: Tag[] = [];
  @Link selectedIndex: number;
  @State showDropdown: boolean = false;
  @State filterName: string = '';

  private get displayTags(): Tag[] {
    if (this.filterName.length === 0) {
      return this.tags;
    }
    return this.tags.filter((t: Tag) => (t.name ?? '') === this.filterName);
  }

  private chipItems(): ChipItem[] {
    return this.tags.map((tag: Tag): ChipItem => {
      const label: string = tag.name ?? '';
      return {
        key: tag.id?.toString() ?? label,
        label: label,
        iconName: label,
      };
    });
  }

  build() {
    Column() {
      // 标签横向滚动 + 下拉按钮
      Row() {
        ChipRow({
          items: this.chipItems(),
          selectedIndex: $selectedIndex,
          sidePadding: SpaceTokens.pageCompact,
          itemGap: SpaceTokens.item,
          chipHeight: LayoutTokens.segmentedHeight,
        })
          .layoutWeight(1)

        // 下拉按钮
        Column() {
          Pressable({
            visualHeight: LayoutTokens.segmentedHeight,
            touchTargetHeight: LayoutTokens.minTouchTarget,
            action: () => { this.showDropdown = !this.showDropdown; },
          }) {
            Row() {
              Image(resolveActionIcon('chevronDown'))
                .width(IconTokens.compact)
                .height(IconTokens.compact)
                .fillColor(ColorTokens.secondary)
                .rotate({ angle: this.showDropdown ? 180 : 0 })
                .animation({ duration: MotionTokens.fast, curve: MotionCurves.standard })
            }
            .width(LayoutTokens.minTouchTarget)
            .height(LayoutTokens.segmentedHeight)
            .justifyContent(FlexAlign.Center)
            .alignItems(VerticalAlign.Center)
            .backgroundColor(ColorTokens.sunken)
            .borderRadius(RadiusTokens.sm)
          }
        }
        .margin({ left: SpaceTokens.sm, right: SpaceTokens.pageCompact })
      }
      .width('100%')
      .padding({ bottom: SpaceTokens.sm })

      // 下拉面板
      if (this.showDropdown) {
        Scroll() {
          Column({ space: 0 }) {
            Row({ space: SpaceTokens.inline }) {
              TagIcon({ name: '全部', iconSize: IconTokens.compact, tint: ColorTokens.primary })
              Text('全部圈子')
                .fontSize(TypeTokens.callout.size)
                .fontWeight(TypeTokens.callout.weight)
                .fontColor(ColorTokens.primary)
            }
            .width('100%')
            .padding({ left: SpaceTokens.lg, right: SpaceTokens.lg, top: SpaceTokens.item, bottom: SpaceTokens.item })
            .onClick(() => {
              this.filterName = '';
              this.showDropdown = false;
              this.selectedIndex = 0;
            })

            Divider().color(ColorTokens.separator)

            ForEach(
              this.tags,
              (t: Tag) => {
                Row({ space: SpaceTokens.inline }) {
                  TagIcon({
                    name: t.name ?? '',
                    iconSize: IconTokens.compact,
                    tint: this.filterName === t.name ? ColorTokens.brand : ColorTokens.primary,
                  })
                  Text(t.name ?? '')
                    .fontSize(TypeTokens.callout.size)
                    .fontWeight(TypeTokens.callout.weight)
                    .fontColor(this.filterName === t.name ? ColorTokens.brand : ColorTokens.primary)
                }
                .width('100%')
                .padding({ left: SpaceTokens.lg, right: SpaceTokens.lg, top: SpaceTokens.item, bottom: SpaceTokens.item })
                .onClick(() => {
                  this.filterName = t.name ?? '';
                  this.showDropdown = false;
                  // 找到对应 tag 的 index
                  const idx = this.tags.indexOf(t);
                  if (idx >= 0) {
                    this.selectedIndex = idx;
                  }
                })
              },
              (t: Tag) => t.name ?? ''
            )
          }
          .width('100%')
        }
        .height(Math.min(this.tags.length * LayoutTokens.minTouchTarget + LayoutTokens.minTouchTarget, 320))
        .width('100%')
        .backgroundColor(ColorTokens.elevated)
        .borderRadius(RadiusTokens.sm)
        .shadow({ radius: SpaceTokens.sm, color: ColorTokens.shadowPopover, offsetY: 2 })
        .margin({ left: SpaceTokens.pageCompact, right: SpaceTokens.pageCompact, bottom: SpaceTokens.sm })
      }
    }
    .width('100%')
  }
}
