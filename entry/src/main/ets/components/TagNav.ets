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
import { isImmersiveLightSenseSupported, GlassBlurStyle } from '../utils/immersiveMaterial';
import { ImmersiveSurface } from '../design/components/ImmersiveSurface';

@Component
export struct TagNav {
  @Prop tags: Tag[] = [];
  @Link selectedIndex: number;
  // 首页紧凑模式仅压缩视觉尺寸，Pressable 仍保持 44vp 触控热区。
  @Prop compact: boolean = false;
  @Prop glass: boolean = false;
  @Prop dropdownOnly: boolean = false;
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

  private selectedLabel(): string {
    const selected: Tag | undefined = this.tags[this.selectedIndex];
    const name: string = selected?.name ?? '';
    return name.length > 0 && name !== '全部' ? name : '圈子';
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

  // 分段栏内容（玻璃/非玻璃两种容器共享同一内层）
  @Builder
  chipBarInner() {
    Row() {
      if (!this.dropdownOnly) {
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
      } else {
        Blank().layoutWeight(1)
      }

      // 下拉按钮
      Column() {
        Pressable({
          visualHeight: LayoutTokens.segmentedHeight,
          touchTargetHeight: LayoutTokens.minTouchTarget,
          action: () => { this.setDropdownVisible(true); },
        }) {
          Row({ space: this.dropdownOnly ? SpaceTokens.xs : SpaceTokens.none }) {
            if (this.dropdownOnly) {
              Text(this.selectedLabel())
                .fontSize(TypeTokens.caption.size)
                .fontFamily(TypeTokens.fontFamily)
                .fontColor(ColorTokens.primary)
            }
            Image(resolveActionIcon('chevronDown'))
              .width(IconTokens.compact)
              .height(IconTokens.compact)
          }
          .width(this.dropdownOnly ? 88 : LayoutTokens.minTouchTarget)
          .height(LayoutTokens.segmentedHeight)
          .justifyContent(FlexAlign.Center)
          .alignItems(VerticalAlign.Center)
          .backgroundColor(this.glass ? Color.Transparent : ColorTokens.elevated)
          .border({ width: 1, color: ColorTokens.separator, style: BorderStyle.Solid })
          .borderRadius(this.glass ? RadiusTokens.lg : RadiusTokens.pill)
        }
      }
      .margin({
        left: SpaceTokens.xs,
        right: this.dropdownOnly ? SpaceTokens.none : (this.glass ? SpaceTokens.xs : SpaceTokens.pageCompact),
      })
    }
    .width('100%')
  }

  // 分段栏容器：沉浸光感态叠加流光层，非玻璃态透明无模糊（保持原视觉）
  @Builder
  chipBar() {
    if (this.glass) {
      ImmersiveSurface({ radius: RadiusTokens.floatingBar }) {
        Column() { this.chipBarInner() }
          .width('100%')
          .height(LayoutTokens.segmentedHeight)
          .padding({
            left: this.dropdownOnly ? SpaceTokens.none : SpaceTokens.xs,
            right: this.dropdownOnly ? SpaceTokens.none : SpaceTokens.xs,
          })
          .padding({ bottom: this.compact ? SpaceTokens.xs : SpaceTokens.sm })
          .backgroundBlurStyle(GlassBlurStyle.Floating)
          .backgroundColor(isImmersiveLightSenseSupported() ? Color.Transparent : ColorTokens.barSurface)
          .border({ width: LayoutTokens.glassBorderWidth, color: ColorTokens.barBorder, style: BorderStyle.Solid })
          .borderRadius(RadiusTokens.floatingBar)
          .shadow({ radius: 22, color: ColorTokens.barShadow, offsetY: 10 })
          .clip(true)
      }
    } else {
      Column() { this.chipBarInner() }
        .width('100%')
        .height(LayoutTokens.segmentedHeight)
        .padding({
          left: this.dropdownOnly ? SpaceTokens.none : SpaceTokens.none,
          right: this.dropdownOnly ? SpaceTokens.none : SpaceTokens.none,
        })
        .padding({ bottom: this.compact ? SpaceTokens.xs : SpaceTokens.sm })
        .backgroundColor(Color.Transparent)
    }
  }

  // 展开态菜单网格（两种材质分支共享同一滚动内容）
  @Builder
  dropdownGrid() {
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
  }

  // 展开态菜单容器：玻璃/非玻璃两种材质分支
  @Builder
  dropdownMenu() {
    if (this.glass) {
      // 菜单位于分段栏（推荐/关注/每日一帖）之下，向下覆盖帖子区域。
      // 用 margin-top 下移（而非 position）：margin 参与外层 Stack 测量，
      // 流光层才能由 onAreaChange 贴合整个展开区域；编舞加在玻璃内层。
      ImmersiveSurface({ radius: RadiusTokens.floatingBar }) {
        Column() {
          this.dropdownGrid()
        }
        .height(this.dropdownHeight())
        .width('100%')
        .margin({ top: LayoutTokens.segmentedHeight })
        .backgroundBlurStyle(GlassBlurStyle.Floating)
        .backgroundColor(isImmersiveLightSenseSupported() ? Color.Transparent : ColorTokens.barSurface)
        .border({ width: LayoutTokens.glassBorderWidth, color: ColorTokens.barBorder, style: BorderStyle.Solid })
        .borderRadius(RadiusTokens.floatingBar)
        .shadow({ radius: 22, color: ColorTokens.barShadow, offsetY: 10 })
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
    } else {
      // 菜单位于分段栏（推荐/关注/每日一帖）之下，避免与其重合
      Column() {
        this.dropdownGrid()
      }
      .height(this.dropdownHeight())
      .width('100%')
      .position({ x: 0, y: LayoutTokens.segmentedHeight })
      .backgroundColor(ColorTokens.elevated)
      .borderRadius(RadiusTokens.sm)
      .shadow({ radius: SpaceTokens.sm, color: ColorTokens.shadowPopover, offsetY: 2 })
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

  build() {
    // 外层始终只占一行高度；展开菜单作为 Stack 叠层覆盖下方帖子，不参与列表排版。
    Stack({ alignContent: Alignment.TopStart }) {
      // 标签横向滚动 + 下拉按钮
      if (!this.showDropdown) {
        this.chipBar()
      }

      // 展开态菜单下移到分段栏之下，并向下覆盖帖子区域。
      if (this.showDropdown) {
        // 点击菜单外部收回：透明遮罩从菜单底部延伸到屏幕下方（zIndex 低于菜单，不挡菜单点击）
        Column()
          .width('100%')
          .height(2000)
          .position({ x: 0, y: this.dropdownHeight() + LayoutTokens.segmentedHeight })
          .backgroundColor(Color.Transparent)
          .onClick((): void => { this.setDropdownVisible(false); })
          .zIndex(0)
        this.dropdownMenu()
      }
    }
    // 展开时保留完整绘制高度（分段栏 + 菜单）；负边距抵消额外高度，帖子流仍从收起态位置开始。
    .height(this.showDropdown ? this.dropdownHeight() + LayoutTokens.segmentedHeight : LayoutTokens.segmentedHeight)
    .width('100%')
    .margin({
      bottom: this.showDropdown ? -this.dropdownHeight() : 0,
    })
    .zIndex(10)
    .animation({
      duration: this.shouldReduceMotion() ? MotionTokens.instant : MotionTokens.base,
      curve: MotionCurves.decelerate,
    })
  }
}
