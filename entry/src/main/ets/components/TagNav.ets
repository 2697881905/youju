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
import { ShadowTokens } from '../design/tokens/shadow';
import { TypeTokens } from '../design/tokens/type';
import {
  isImmersiveLightSenseSupported,
  isSystemMaterialActive,
  GlassBlurStyle,
  getMenuImmersiveMaterial,
  FloatingTopButtonMaterialModifier,
} from '../utils/immersiveMaterial';
import { ImmersiveSurface } from '../design/components/ImmersiveSurface';
import { FEED_ZONE_LABELS, zoneLabel } from '../utils/feedZones';

// 下拉菜单最多显示的行数，超出交给系统菜单自身滚动（maxHeight 亦为 26+ 才有的选项）。
const DROPDOWN_MAX_ROWS: number = 8;
// 系统 MenuItem 的实测行高：真机 dumpLayout 单行 150px ÷ 3.125 = 48vp。
const DROPDOWN_ROW_HEIGHT: number = 48;
// 圈子 chip 的补影（真机逐档取证 2026-11-15）：同参数材质挂在自绘 Row 上时，系统给的落影
// 比官方 SegmentButton 轨道浅 11 级（胶囊底边下方 3px：分段栏 230 / chip 241 / 画布 255）。
// 官方没有调投影浓度的开关，只能自绘补一层。
// ⚠️ 不能挂在 chip 那颗 Row 上：节点被 attributeModifier(systemMaterial) 接管表面后
// .shadow() 完全不出图（连 #66000000 深色实测都零变化）。必须挂在不带材质的外层 Column，
// 且该 Column 要显式 width/height/borderRadius 与 chip 对齐，否则阴影底边会上移 12px。
// 定值：radius 56 / 8.6% 黑 / offsetY 5 → 底边下方 3px 实测 232（分段栏 228）。
// 梯度记录：12.5% 黑实测 229（用户判偏重）→ 10% 232 → 8.6% 232，两轮复看逐档调轻。
// 下限：再淡中远段会明显脱节（453 处已差分段栏 7 级），不要继续降 alpha。
const CHIP_SHADOW: ShadowOptions = { radius: 56, color: '#16000000', offsetY: 5 };

@Component
export struct TagNav {
  @Prop tags: Tag[] = [];
  @Link selectedIndex: number;
  // 首页内容分区（干货/生活）：与圈子是两个独立筛选维度，各自持有选中态。
  @Link zoneIndex: number;
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

  // 与同排官方分段栏同源：ULTRA_THIN / interactive / applyShadow:true。
  // 不用 TopButtonMaterialModifier（那份关投影，是给窄行裁切场景的）。
  private chipMaterialModifier: FloatingTopButtonMaterialModifier = new FloatingTopButtonMaterialModifier();

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

  // chip 常驻显示一级维度（内容区）；圈子名退回菜单里的系统选中对勾。
  private selectedLabel(): string {
    return zoneLabel(this.zoneIndex);
  }

  private setDropdownVisible(visible: boolean): void {
    this.getUIContext().animateTo({ duration: MotionTokens.base, curve: MotionCurves.decelerate }, () => {
      this.dropdownVisible = visible;
    });
  }

  // 菜单高度上限：按行折算（行高取真机实测 48vp），超出交给系统菜单滚动。
  private menuMaxHeight(): number {
    // 区组与圈子组共用一份滚动上限；异常态（只有「全部」）也要留出区组两行。
    const rows: number = Math.min(DROPDOWN_MAX_ROWS, Math.max(1, this.tags.length + FEED_ZONE_LABELS.length));
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
          // 表面：材质生效时交给系统，自绘细描边必须让位，否则叠成第二圈描边；
          // 低版本门禁不过时保留 outlined 兜底（透明底 + glassBorderWidth/barBorder + lg 圆角，无实色垫底）。
          // 注：36 高的元素半径上限为半高 18，lg(20) 与 pill(999) 在此高度渲染结果一致（均为全胶囊），
          // 统一取 lg 只为与分段栏共用同一个形状 token，两处圆角不会再走散。
          .backgroundColor(Color.Transparent)
          .border({
            width: (this.useSystemMaterial && isSystemMaterialActive()) ? 0 : LayoutTokens.glassBorderWidth,
            color: this.lightContent ? '#66FFFFFF' : ColorTokens.barBorder,
            style: BorderStyle.Solid,
          })
          .borderRadius(RadiusTokens.lg)
          // 沉浸光感（systemMaterial，@since 26.0.0）：与同排官方 SegmentButton 同档材质
          // （getSegmentImmersiveMaterial 同参数），bottomBuilder 行已按 segmentBarShadowRoom 留净空；
          // 低版本设备门禁不通过 → 不设材质，保留上面的细描边样式（见 utils/immersiveMaterial.ets）。
          .attributeModifier(this.useSystemMaterial ? this.chipMaterialModifier : undefined)
          // 下拉菜单交给系统弹层（bindMenu @since 11）：定位、点外关闭、越界翻转、滚动都由系统承担，
          // 取代原先「内容区自绘玻璃面板 + 2000vp 透明遮罩 + 共享开合态」那一套。
          // 锚点就是这个可见的 chip 本体（不是 Pressable 的 44vp 热区），菜单才会贴着按钮下沿。
          .bindMenu(this.dropdownVisible, this.circleMenu(), this.menuOptions())
        }
      }
      // 阴影承载层：尺寸/圆角与内层 chip 完全对齐；材质挂内层、阴影挂本层（无材质），互不吞掉。
      // 低版本门禁不过时不出自绘阴影，保留 outlined 兜底。
      .width(this.dropdownOnly ? 88 : LayoutTokens.minTouchTarget)
      .height(LayoutTokens.segmentedHeight)
      .borderRadius(RadiusTokens.lg)
      .shadow((this.useSystemMaterial && isSystemMaterialActive()) ? CHIP_SHADOW : ShadowTokens.none)
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

  // 下拉菜单分两组：内容区与圈子是两个独立维度，各用各的选中态与系统对勾，
  // 可同时生效（如「干货 + 手机数码」）。MenuItemGroup 的 header 是系统原生分组标题，
  // 不需要自定义 builder，也不改变 bindMenu 的交互。
  @Builder
  circleMenu() {
    Menu() {
      MenuItemGroup({ header: '内容区' }) {
        ForEach(
          FEED_ZONE_LABELS,
          (label: string, index: number) => {
            MenuItem({ content: label })
              .selected(this.zoneIndex === index)
              .selectIcon(true)
              .onClick((): void => {
                this.zoneIndex = index;
                this.setDropdownVisible(false);
              })
          },
          (label: string) => 'zone_' + label
        )
      }
      MenuItemGroup({ header: '圈子' }) {
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
  }

  build() {
    // 只出「圈子」chip（渲染在 Navigation 标题栏）；下拉菜单由 chip 上的 bindMenu 系统弹层承载。
    this.chipBar()
  }
}
