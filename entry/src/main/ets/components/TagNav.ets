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
import { isImmersiveLightSenseSupported, GlassBlurStyle, TopButtonMaterialModifier } from '../utils/immersiveMaterial';
import { ImmersiveSurface } from '../design/components/ImmersiveSurface';

// 点外关闭遮罩高度：从面板底部一直铺到屏幕下方（沿用旧就地展开实现的固定值）。
const DROPDOWN_MASK_HEIGHT: number = 2000;

@Component
export struct TagNav {
  @Prop tags: Tag[] = [];
  @Link selectedIndex: number;
  // 下拉展开态：由宿主共享 —— 标题栏 chip 与内容区面板是两个实例，靠它同步开合。
  @Link dropdownVisible: boolean;
  // 首页紧凑模式仅压缩视觉尺寸，Pressable 仍保持 44vp 触控热区。
  @Prop compact: boolean = false;
  @Prop glass: boolean = false;
  @Prop dropdownOnly: boolean = false;
  // —— 拆分布局（顶栏整体迁入 Navigation 标题栏后的两张形态）——
  // 默认（panelOnly=false）：只渲染「圈子」下拉按钮，渲染在标题栏内，可挂系统材质；
  // panelOnly=true：只渲染展开面板 + 点外关闭遮罩，渲染在内容区顶部，向下覆盖信息流。
  @Prop panelOnly: boolean = false;
  // 系统材质（沉浸光感，@since 26.0.0）：挂在标题栏内的 chip 表面，低版本设备自动跳过。
  // 注：属性名不能叫 systemMaterial —— 与 ArkUI 内置通用属性同名会与 CustomComponent 基类冲突。
  @Prop useSystemMaterial: boolean = false;
  // 浅色内容态（模糊背板变深时切白）：chip 文字/chevron/描边随宿主滚动状态联动（首页顶栏模糊切白用）。
  // 默认 false = 原有 token 配色；仅影响 chip 按钮形态（chipBarInner），下拉面板不受影响。
  @Prop lightContent: boolean = false;
  @State menuIconsRaised: boolean = false;

  private chipMaterialModifier: TopButtonMaterialModifier = new TopButtonMaterialModifier();

  // 面板里高亮项 = 当前选中的圈子：用共享的 selectedIndex 推导
  // （面板随开合挂载/卸载，不能依赖实例内状态，否则重开后面板高亮丢失）。
  private selectedName(): string {
    return this.tags[this.selectedIndex]?.name ?? '';
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

  private selectedLabel(): string {
    const selected: Tag | undefined = this.tags[this.selectedIndex];
    const name: string = selected?.name ?? '';
    return name.length > 0 && name !== '全部' ? name : '圈子';
  }

  private setDropdownVisible(visible: boolean): void {
    if (!visible) {
      this.menuIconsRaised = false;
    }
    this.getUIContext().animateTo({ duration: MotionTokens.base, curve: MotionCurves.decelerate }, () => {
      this.dropdownVisible = visible;
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
          action: () => { this.setDropdownVisible(!this.dropdownVisible); },
        }) {
          Row({ space: this.dropdownOnly ? SpaceTokens.xs : SpaceTokens.none }) {
            if (this.dropdownOnly) {
              Text(this.selectedLabel())
                .fontSize(TypeTokens.caption.size)
                .fontFamily(TypeTokens.fontFamily)
                .fontColor(this.lightContent ? Color.White : ColorTokens.primary)
            }
            Image(resolveActionIcon('chevronDown'))
              .width(IconTokens.compact)
              .height(IconTokens.compact)
              .fillColor(this.lightContent ? Color.White : ColorTokens.icon)
          }
          .width(this.dropdownOnly ? 88 : LayoutTokens.minTouchTarget)
          .height(LayoutTokens.segmentedHeight)
          .justifyContent(FlexAlign.Center)
          .alignItems(VerticalAlign.Center)
          // 与首页分段栏（SegmentedControl 的 outlined 分支）同款规格：
          // 透明底 + glassBorderWidth 细描边 barBorder + lg 大圆角，无实色垫底、无阴影。
          // 注：36 高的元素半径上限为半高 18，lg(20) 与 pill(999) 在此高度渲染结果一致（均为全胶囊），
          // 统一取 lg 只为与分段栏共用同一个形状 token，两处圆角不会再走散。
          .backgroundColor(Color.Transparent)
          .border({
            width: LayoutTokens.glassBorderWidth,
            color: this.lightContent ? '#66FFFFFF' : ColorTokens.barBorder,
            style: BorderStyle.Solid,
          })
          .borderRadius(RadiusTokens.lg)
          // 沉浸光感（systemMaterial，@since 26.0.0）：驻留标题栏时由系统材质接管表面；
          // 低版本设备门禁不通过 → 保留上面的细描边样式（见 utils/immersiveMaterial.ets）。
          .attributeModifier(this.useSystemMaterial ? this.chipMaterialModifier : undefined)
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
                    tint: this.selectedName() === t.name ? ColorTokens.brand : ColorTokens.primary,
                    colorful: this.selectedName() !== t.name,
                  })
                }
                .width(IconTokens.compact)
                .height(IconTokens.compact)
                .scale({
                  x: this.menuIconsRaised ? 1 : 0.88,
                  y: this.menuIconsRaised ? 1 : 0.88,
                })
                .translate({ y: this.menuIconsRaised ? 0 : SpaceTokens.xs })
                .animation({
                  duration: MotionTokens.base,
                  delay: Math.min(index, 6) * MotionTokens.stagger,
                  curve: MotionCurves.spring,
                })
                Text(t.name ?? '')
                  .fontSize(TypeTokens.callout.size).fontFamily(TypeTokens.fontFamily)
                  .fontWeight(TypeTokens.callout.weight)
                  .fontColor(this.selectedName() === t.name ? ColorTokens.brand : ColorTokens.primary)
                  .layoutWeight(1)
                  .maxLines(1)
                  .textOverflow({ overflow: TextOverflow.Ellipsis })
              }
              .width('100%')
              .height(LayoutTokens.minTouchTarget)
              .padding({ left: SpaceTokens.sm, right: SpaceTokens.sm })
              .onClick(() => {
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
    .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true })
  }

  // 展开态菜单容器：玻璃/非玻璃两种材质分支。
  // 迁入标题栏后，面板由内容区宿主渲染、贴在内容区顶部（y=0，紧随标题栏之下），
  // 因此不再需要「分段栏高度」偏移与负边距撑高（原就地展开的排版技巧已随拆分移除）。
  @Builder
  dropdownMenu() {
    if (this.glass) {
      ImmersiveSurface({ radius: RadiusTokens.floatingBar }) {
        Column() {
          this.dropdownGrid()
        }
        .height(this.dropdownHeight())
        .width('100%')
        .backgroundBlurStyle(GlassBlurStyle.Floating)
        .backgroundColor(isImmersiveLightSenseSupported() ? Color.Transparent : ColorTokens.barSurface)
        .border({ width: LayoutTokens.glassBorderWidth, color: ColorTokens.barBorder, style: BorderStyle.Solid })
        .borderRadius(RadiusTokens.floatingBar)
        .shadow({ radius: 22, color: ColorTokens.barShadow, offsetY: 10 })
        .clip(true)
        .zIndex(1)
        .onAppear(() => {
          this.menuIconsRaised = true;
        })
        .transition(TransitionEffect.OPACITY
          .animation({ duration: MotionTokens.base, curve: MotionCurves.decelerate })
          .combine(TransitionEffect.translate({ y: -SpaceTokens.sm })
            .animation({ duration: MotionTokens.base, curve: MotionCurves.decelerate }))
          .combine(TransitionEffect.scale({ x: 1, y: 0.88 })
            .animation({ duration: MotionTokens.base, curve: MotionCurves.decelerate })))
      }
    } else {
      Column() {
        this.dropdownGrid()
      }
      .height(this.dropdownHeight())
      .width('100%')
      .position({ x: 0, y: 0 })
      .backgroundColor(ColorTokens.elevated)
      .borderRadius(RadiusTokens.sm)
      .shadow({ radius: SpaceTokens.sm, color: ColorTokens.shadowPopover, offsetY: 2 })
      .clip(true)
      .zIndex(1)
      .onAppear(() => {
        this.menuIconsRaised = true;
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
    if (this.panelOnly) {
      // 面板形态（渲染在内容区宿主）：贴内容区顶部、向下覆盖信息流；透明遮罩点外关闭。
      // 遮罩铺到屏幕下方；外框高度覆盖到遮罩底部，保证整块遮罩都落在父节点范围内
      // （ArkUI 触摸只命中父节点区域内的子节点，超出部分点不到）。
      Stack({ alignContent: Alignment.TopStart }) {
        Column()
          .width('100%')
          .height(DROPDOWN_MASK_HEIGHT)
          .position({ x: 0, y: this.dropdownHeight() })
          .backgroundColor(Color.Transparent)
          .onClick((): void => { this.setDropdownVisible(false); })
          .zIndex(0)
        this.dropdownMenu()
      }
      .width('100%')
      .height(this.dropdownHeight() + DROPDOWN_MASK_HEIGHT)
      .position({ x: 0, y: 0 })
      .zIndex(10)
    } else {
      // 按钮形态（渲染在 Navigation 标题栏）：只出「圈子」chip
      this.chipBar()
    }
  }
}
