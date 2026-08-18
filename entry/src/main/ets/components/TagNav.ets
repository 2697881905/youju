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
  // 首页紧凑模式仅压缩视觉尺寸，Pressable 仍保持 44vp 触控热区。
  @Prop compact: boolean = false;
  @Prop glass: boolean = false;
  @State showDropdown: boolean = false;
  @State filterName: string = '';
  @State menuIconsRaised: boolean = false;
  @StorageLink('reduceMotion') appReduceMotion: boolean = false;
  @StorageLink('systemReduceMotion') systemReduceMotion: boolean = false;

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

  private dropdownHeight(): number {
    const rows: number = Math.max(1, Math.ceil(this.tags.length / 3));
    const gaps: number = Math.max(0, rows - 1) * SpaceTokens.sm;
    return Math.min(rows * LayoutTokens.minTouchTarget + gaps + SpaceTokens.sm * 2, 320);
  }

  private shouldReduceMotion(): boolean {
    return this.appReduceMotion || this.systemReduceMotion;
  }

  private setDropdownVisible(visible: boolean): void {
    if (!visible) {
      this.menuIconsRaised = false;
    }
    if (this.shouldReduceMotion()) {
      this.showDropdown = visible;
      return;
    }
    this.getUIContext().animateTo({ duration: MotionTokens.base, curve: MotionCurves.decelerate }, () => {
      this.showDropdown = visible;
    });
  }

  build() {
    // 外层始终只占一行高度；展开菜单作为 Stack 叠层覆盖下方帖子，不参与列表排版。
    Stack({ alignContent: Alignment.TopStart }) {
      // 标签横向滚动 + 下拉按钮
      if (!this.showDropdown) {
        Column() {
          Row() {
            ChipRow({
              items: this.chipItems(),
              selectedIndex: $selectedIndex,
              sidePadding: SpaceTokens.pageCompact,
              itemGap: this.glass ? SpaceTokens.xs : (this.compact ? SpaceTokens.sm : SpaceTokens.item),
              chipHeight: this.compact ? SpaceTokens.x2l : LayoutTokens.segmentedHeight,
              compact: this.compact,
              glass: this.glass,
            })
              .layoutWeight(1)

            // 下拉按钮
            Column() {
              Pressable({
                visualHeight: LayoutTokens.segmentedHeight,
                touchTargetHeight: LayoutTokens.minTouchTarget,
                action: () => { this.setDropdownVisible(true); },
              }) {
                Row() {
                  Image(resolveActionIcon('chevronDown'))
                    .width(IconTokens.compact)
                    .height(IconTokens.compact)
                    .fillColor(ColorTokens.secondary)
                }
                .width(LayoutTokens.minTouchTarget)
                .height(LayoutTokens.segmentedHeight)
                .justifyContent(FlexAlign.Center)
                .alignItems(VerticalAlign.Center)
                .backgroundColor(this.glass ? Color.Transparent : ColorTokens.sunken)
                .borderRadius(this.glass ? RadiusTokens.lg : RadiusTokens.sm)
              }
            }
            .margin({ left: SpaceTokens.xs, right: this.glass ? SpaceTokens.xs : SpaceTokens.pageCompact })
          }
        }
        .width('100%')
        .height(LayoutTokens.segmentedHeight)
        .padding({ left: this.glass ? SpaceTokens.xs : SpaceTokens.none, right: this.glass ? SpaceTokens.xs : SpaceTokens.none })
        .padding({ bottom: this.compact ? SpaceTokens.xs : SpaceTokens.sm })
        .backdropBlur(this.glass ? LayoutTokens.glassBlur : 0)
        .backgroundColor(this.glass ? ColorTokens.barSurface : Color.Transparent)
        .border({
          width: this.glass ? LayoutTokens.glassBorderWidth : 0,
          color: this.glass ? ColorTokens.barBorder : Color.Transparent,
          style: BorderStyle.Solid,
        })
        .borderRadius(this.glass ? RadiusTokens.floatingBar : RadiusTokens.none)
        .shadow({
          radius: this.glass ? 22 : 0,
          color: this.glass ? ColorTokens.barShadow : Color.Transparent,
          offsetY: this.glass ? 10 : 0,
        })
        .clip(true)
      }

      // 展开态菜单位于圈子栏原位置，并向下覆盖帖子区域。
      if (this.showDropdown) {
        // 点击菜单外部收回：透明遮罩从菜单底部延伸到屏幕下方（zIndex 低于菜单，不挡菜单点击）
        Column()
          .width('100%')
          .height(2000)
          .position({ x: 0, y: this.dropdownHeight() })
          .backgroundColor(Color.Transparent)
          .onClick((): void => { this.setDropdownVisible(false); })
          .zIndex(0)
        Scroll() {
          Grid() {
            ForEach(
              this.tags,
              (t: Tag, index: number) => {
                GridItem() {
                  Row({ space: SpaceTokens.inline }) {
                    Column() {
                      TagIcon({
                        name: t.name ?? '',
                        iconSize: IconTokens.compact,
                        tint: this.filterName === t.name ? ColorTokens.brand : ColorTokens.primary,
                        colorful: this.filterName !== t.name,
                      })
                    }
                    .width(IconTokens.compact)
                    .height(IconTokens.compact)
                    .scale({
                      x: this.shouldReduceMotion() || this.menuIconsRaised ? 1 : 0.88,
                      y: this.shouldReduceMotion() || this.menuIconsRaised ? 1 : 0.88,
                    })
                    .translate({ y: this.shouldReduceMotion() || this.menuIconsRaised ? 0 : SpaceTokens.xs })
                    .animation({
                      duration: this.shouldReduceMotion() ? MotionTokens.instant : MotionTokens.base,
                      delay: this.shouldReduceMotion() ? 0 : Math.min(index, 6) * MotionTokens.stagger,
                      curve: MotionCurves.spring,
                    })
                    Text(t.name ?? '')
                      .fontSize(TypeTokens.callout.size).fontFamily(TypeTokens.fontFamily)
                      .fontWeight(TypeTokens.callout.weight)
                      .fontColor(this.filterName === t.name ? ColorTokens.brand : ColorTokens.primary)
                      .layoutWeight(1)
                      .maxLines(1)
                      .textOverflow({ overflow: TextOverflow.Ellipsis })
                  }
                  .width('100%')
                  .height(LayoutTokens.minTouchTarget)
                  .padding({ left: SpaceTokens.sm, right: SpaceTokens.sm })
                  .onClick(() => {
                    this.filterName = t.name ?? '';
                    this.setDropdownVisible(false);
                    // 找到对应 tag 的 index
                    const idx = this.tags.indexOf(t);
                    if (idx >= 0) {
                      this.selectedIndex = idx;
                    }
                  })
                }
              },
              (t: Tag) => t.name ?? ''
            )
          }
          .columnsTemplate('1fr 1fr 1fr')
          .columnsGap(SpaceTokens.sm)
          .rowsGap(SpaceTokens.sm)
          .padding(SpaceTokens.sm)
          .width('100%')
        }
        .height(this.dropdownHeight())
        .width('100%')
        .position({ x: 0, y: 0 })
        .backdropBlur(this.glass ? LayoutTokens.glassBlur : 0)
        .backgroundColor(this.glass ? ColorTokens.barSurface : ColorTokens.elevated)
        .border({
          width: this.glass ? LayoutTokens.glassBorderWidth : 0,
          color: this.glass ? ColorTokens.barBorder : Color.Transparent,
          style: BorderStyle.Solid,
        })
        .borderRadius(this.glass ? RadiusTokens.floatingBar : RadiusTokens.sm)
        .shadow({
          radius: this.glass ? 22 : SpaceTokens.sm,
          color: this.glass ? ColorTokens.barShadow : ColorTokens.shadowPopover,
          offsetY: this.glass ? 10 : 2,
        })
        .clip(true)
        .zIndex(1)
        .onAppear(() => {
          if (!this.shouldReduceMotion()) {
            this.menuIconsRaised = true;
          }
        })
        .transition(TransitionEffect.OPACITY
          .animation({ duration: MotionTokens.base, curve: MotionCurves.decelerate })
          .combine(TransitionEffect.translate({ y: -SpaceTokens.sm })
            .animation({ duration: MotionTokens.base, curve: MotionCurves.decelerate }))
          .combine(TransitionEffect.scale({ x: 1, y: 0.88 })
            .animation({ duration: MotionTokens.base, curve: MotionCurves.decelerate })))
      }
    }
    // 展开时保留完整绘制高度；负边距抵消额外高度，帖子流仍从收起态位置开始。
    .height(this.showDropdown ? this.dropdownHeight() : LayoutTokens.segmentedHeight)
    .width('100%')
    .margin({
      bottom: this.showDropdown ? LayoutTokens.segmentedHeight - this.dropdownHeight() : 0,
    })
    .zIndex(10)
    .animation({
      duration: this.shouldReduceMotion() ? MotionTokens.instant : MotionTokens.base,
      curve: MotionCurves.decelerate,
    })
  }
}
