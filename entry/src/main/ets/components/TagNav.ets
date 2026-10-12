import { Tag } from '../models/types';
import { LengthMetrics } from '@kit.ArkUI';
import { resolveActionIcon } from '../utils/actionIcons';
import { resolveTagIcon } from '../utils/tagIcons';
import { ChipItem, ChipRow } from '../design/components/ChipRow';
import { Pressable } from '../design/motion/Pressable';
import { ColorTokens } from '../design/tokens/color';
import { IconTokens } from '../design/tokens/icon';
import { MotionCurves, MotionTokens } from '../design/tokens/motion';
import { RadiusTokens } from '../design/tokens/radius';
import { LayoutTokens, SpaceTokens } from '../design/tokens/space';
import { TypeTokens } from '../design/tokens/type';
import {
  isImmersiveLightSenseSupported,
  isSystemMaterialActive,
  GlassBlurStyle,
  getMenuImmersiveMaterial,
  TopButtonMaterialModifier,
} from '../utils/immersiveMaterial';
import { ImmersiveSurface } from '../design/components/ImmersiveSurface';

// 下拉菜单最多显示的行数，超出交给系统菜单自身滚动（maxHeight 亦为 26+ 才有的选项）。
const DROPDOWN_MAX_ROWS: number = 8;
// 系统 MenuItem 的实测行高：真机 dumpLayout 单行 150px ÷ 3.125 = 48vp。
const DROPDOWN_ROW_HEIGHT: number = 48;

@Component
export struct TagNav {
  @Prop tags: Tag[] = [];
  @Link selectedIndex: number;
  // 下拉展开态：由宿主共享 —— 标题栏 chip 与系统菜单弹层靠它同步开合
  // （bindMenu 走 isShow 受控 + options.onDisappear 回写）。
  @Link dropdownVisible: boolean;
  // 首页紧凑模式仅压缩视觉尺寸，Pressable 仍保持 44vp 触控热区。
  @Prop compact: boolean = false;
  @Prop glass: boolean = false;
  @Prop dropdownOnly: boolean = false;
  // —— 拆分布局（顶栏整体迁入 Navigation 标题栏后的形态）——
  // 下拉面板已交给系统菜单弹层（bindMenu），不再需要「chip 在标题栏 / 面板在内容区」的双宿主。
  // 系统材质（沉浸光感，@since 26.0.0）：挂在标题栏内的 chip 表面，低版本设备自动跳过。
  // 注：属性名不能叫 systemMaterial —— 与 ArkUI 内置通用属性同名会与 CustomComponent 基类冲突。
  @Prop useSystemMaterial: boolean = false;
  // 浅色内容态（模糊背板变深时切白）：chip 文字/chevron/描边随宿主滚动状态联动（首页顶栏模糊切白用）。
  // 默认 false = 原有 token 配色；仅影响 chip 按钮形态（chipBarInner），下拉菜单不受影响。
  @Prop lightContent: boolean = false;

  private chipMaterialModifier: TopButtonMaterialModifier = new TopButtonMaterialModifier();

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

  private selectedLabel(): string {
    const selected: Tag | undefined = this.tags[this.selectedIndex];
    const name: string = selected?.name ?? '';
    return name.length > 0 && name !== '全部' ? name : '圈子';
  }

  private setDropdownVisible(visible: boolean): void {
    this.getUIContext().animateTo({ duration: MotionTokens.base, curve: MotionCurves.decelerate }, () => {
      this.dropdownVisible = visible;
    });
  }

  // 菜单高度上限：按行折算（行高取真机实测 48vp），超出交给系统菜单滚动。
  private menuMaxHeight(): number {
    const rows: number = Math.min(DROPDOWN_MAX_ROWS, Math.max(1, this.tags.length));
    return rows * DROPDOWN_ROW_HEIGHT + SpaceTokens.base;
  }

  // 系统菜单选项。@since 26.0.0 的字段（systemMaterial / maxHeight / targetSpace）
  // 统一走 isSystemMaterialActive() 门禁：低版本设备不传，退回系统默认列表 + 圆角/动效。
  private menuOptions(): MenuOptions {
    const options: MenuOptions = {
      // chip 在标题栏行最右端，菜单右对齐向下展开，越界时系统自动翻到上方。
      placement: Placement.BottomRight,
      borderRadius: RadiusTokens.floatingBar,
      transition: TransitionEffect.OPACITY
        .combine(TransitionEffect.scale({ x: 0.96, y: 0.92 }))
        .animation({ duration: MotionTokens.base, curve: MotionCurves.decelerate }),
      // 点外/选中项/返回键关闭时系统只回调 onDisappear，不回写 isShow，必须在这里同步收回，
      // 否则 dropdownVisible 卡在 true，下一次点 chip 的取反逻辑会变成「关不掉」。
      onDisappear: (): void => {
        this.dropdownVisible = false;
      },
    };
    if (isSystemMaterialActive()) {
      // SystemUiMaterial 是全局声明类型（= uiMaterial.Material），此处不必再 import uiMaterial，
      // 免得把 @kit.ArkUI 的 uiMaterial 引入到启动路径文件里（低版本设备加载即崩的老坑）。
      const material: SystemUiMaterial | undefined = getMenuImmersiveMaterial();
      if (material !== undefined) {
        options.systemMaterial = material;
      }
      options.maxHeight = LengthMetrics.vp(this.menuMaxHeight());
      options.targetSpace = LengthMetrics.vp(SpaceTokens.xs);
      // 刻意不开 gridStyle：真机实测它只对 MenuElement[] 载体生效（本例的 MenuItem+MenuItemOptions
      // 走 CustomBuilder，传了不出网格），而 MenuElement[] 没有选中态字段 → 系统对勾没了；
      // 且网格单元只有约 61vp 宽，「手机数码」这类四字名会被截成「手机…」。单列列表两项都保住。
    }
    return options;
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
          // 下拉菜单交给系统弹层（bindMenu @since 11）：定位、点外关闭、越界翻转、滚动都由系统承担，
          // 取代原先「内容区自绘玻璃面板 + 2000vp 透明遮罩 + 共享开合态」那一套。
          // 锚点就是这个可见的 chip 本体（不是 Pressable 的 44vp 热区），菜单才会贴着按钮下沿。
          .bindMenu(this.dropdownVisible, this.circleMenu(), this.menuOptions())
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

  // 圈子下拉菜单内容：系统 Menu + MenuItem（图标 + 文案 + 系统选中对勾）。
  // 用 MenuItemOptions（固定样式）而不是自定义 builder：自定义内容会丢掉系统的
  // 行高/分隔/对勾，等于又回到自绘。
  @Builder
  circleMenu() {
    Menu() {
      ForEach(
        this.tags,
        (t: Tag, index: number) => {
          MenuItem({
            startIcon: resolveTagIcon(t.name ?? ''),
            content: t.name ?? '',
          })
            .selected(this.selectedIndex === index)
            // 选中态交给系统对勾（selectIcon 只在 selected=true 时出图），不再靠自绘品牌色染字
            .selectIcon(true)
            .onClick((): void => {
              this.selectedIndex = index;
              this.setDropdownVisible(false);
            })
        },
        (t: Tag) => t.name ?? ''
      )
    }
  }

  build() {
    // 只出「圈子」chip（渲染在 Navigation 标题栏）；下拉菜单由 chip 上的 bindMenu 系统弹层承载。
    this.chipBar()
  }
}
