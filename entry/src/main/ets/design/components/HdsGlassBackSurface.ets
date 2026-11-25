// 共享玻璃返回键配置：收敛 HdsNavigation 官方 content.backIcon 与栏级 EXQUISITE 沉浸光感，
// 并提供标准二级页标题栏三件套（options 工厂 / 居中标题行 / 让位占位行）。
// 页面 import 这里的 builder/组件/工厂，不再各自手抄一份材质/返回键/标题栏样板。
import { ScrollEffectType } from '@kit.UIDesignKit';
import type {
  TitleBarStyleOptions,
  TitleBarContentOptions,
  HdsNavigationTitleBarOptions,
  HdsNavigationMenuItemOptions,
  HdsNavigationMenuContentOptions,
  ScrollEffectOptions,
  SystemMaterialParams,
  HdsTitleBarContentStyle,
  HdsNavigationIconItemStyle,
  HdsNavigationBackButtonItemOptions,
  HdsNavigationBackgroundStyle,
} from '@kit.UIDesignKit';
import { LengthMetrics } from '@kit.ArkUI';
import { ColorTokens } from '../tokens/color';
import { SpaceTokens } from '../tokens/space';
import { TypeTokens } from '../tokens/type';
import { resolveActionIcon } from '../../utils/actionIcons';
import {
  isImmersiveLightSenseSupported,
  HDS_MATERIAL_TYPE_IMMERSIVE,
  HDS_MATERIAL_LEVEL_EXQUISITE,
} from '../../utils/immersiveMaterial';

// 官方返回键占 16~56vp（40vp 圆 + 16vp 左内缩）。stackBuilder 那行是全宽的、且在返回键的
// 后一个兄弟节点上（z 序更高），不留出这段就会吃掉返回键的点击（基准 §7.6.31）。
export const HDS_BACK_SLOT_END_VP: number = 64;
// MINI 栏体高（vp）：穿底时内容顶部要让位 statusBarHeight + 这个值。
export const HDS_MINI_BAR_ROW_VP: number = 56;

// 栏体渐变模糊的生效区间：从内容贴顶处到 32vp，与详情页/搜索页同口径。
const BAR_BLUR_END_VP: number = 32;

export function buildGlassBackIcon(action: () => void): HdsNavigationBackButtonItemOptions {
  return {
    icon: resolveActionIcon('back'),
    label: '返回',
    action: action,
  } as HdsNavigationBackButtonItemOptions;
}

// IMMERSIVE 变体滚动后常驻模糊值（vp）：CircleDetail/PostDetail/Chat 三页统一口径 50，
// 门控布尔（xxxB arScrolled）由页面经 scrolledBlur 传入（IMMERSIVE 磨砂出图开关，基准 §36）。
const HDS_SCROLLED_BLUR_VP: number = 50;

// 栏样式定制参数：全部可选，零参调用与升级前产出逐字一致（既有 21 页消费零影响）。
export interface GlassTitleBarStyleParams {
  // IMMERSIVE 滚动后常驻模糊门控（页面 @State 布尔闭包）：传入时 originalStyle.backgroundStyle
  // 写动态 blurRadius（true→50 / false→0）；不传不写该字段（渐变行为不变）。闭包在 options
  // 构建时求值，页面每次 build 重建 options → 响应式与页内手写等价。
  scrolledBlur?: () => boolean;
  // 追加 contentStyle.menuStyle（官方圆钮钮色，PostDetail「与返回键同策略」口径）
  menuIconColor?: ResourceColor;
  // 写 scrollEffectStyle（两态同值防漂移，Chat 口径：本页从不切白，接管前后同色）
  writeScrollEffectStyle?: boolean;
}

export function buildGlassTitleBarStyle(params?: GlassTitleBarStyleParams): TitleBarStyleOptions {
  const immersive: boolean = isImmersiveLightSenseSupported();
  const scrollEffect: ScrollEffectOptions = {
    enableScrollEffect: true,
    scrollEffectType: immersive ? ScrollEffectType.IMMERSIVE_GRADIENT_BLUR : ScrollEffectType.GRADIENT_BLUR,
    blurEffectiveStartOffset: LengthMetrics.vp(0),
    blurEffectiveEndOffset: LengthMetrics.vp(BAR_BLUR_END_VP),
  };
  const contentStyle: HdsTitleBarContentStyle = {
    backIconStyle: { iconColor: ColorTokens.primary } as HdsNavigationIconItemStyle,
  } as HdsTitleBarContentStyle;
  if (params?.menuIconColor !== undefined) {
    contentStyle.menuStyle = { iconColor: params.menuIconColor } as HdsNavigationIconItemStyle;
  }
  const backgroundStyle: HdsNavigationBackgroundStyle = {
    backgroundColor: Color.Transparent,
    maskExtraHeight: 0,
  };
  if (params?.scrolledBlur !== undefined) {
    backgroundStyle.blurRadius = params.scrolledBlur() ? HDS_SCROLLED_BLUR_VP : 0;
  }
  const style: TitleBarStyleOptions = {
    scrollEffectOpts: scrollEffect,
    originalStyle: {
      backgroundStyle: backgroundStyle,
      contentStyle: contentStyle,
    },
  };
  if (params?.writeScrollEffectStyle === true) {
    style.scrollEffectStyle = { contentStyle: contentStyle };
  }
  // 栏级材质是唯一能让官方圆钮出玻璃珠（rim + 折射）的入口，且只能整条栏挂。
  if (immersive) {
    style.systemMaterialEffect = {
      materialType: HDS_MATERIAL_TYPE_IMMERSIVE,
      materialLevel: HDS_MATERIAL_LEVEL_EXQUISITE,
    } as SystemMaterialParams;
  }
  return style;
}
// 标准二级页标题栏参数集：back 闭包逐字保留页面原逻辑，stackBuilder 传页面自己的
// @Builder 方法引用（禁止闭包内联组件树，ArkTS 145 错陷阱）。
export interface PageTitleBarParams {
  // 返回动作（逐字保留页面原逻辑）
  back: () => void;
  // 页面自己的 @Builder 方法引用
  stackBuilder: CustomBuilder;
  // 官方 content.menu 项，缺省不挂 menu
  menuItems?: HdsNavigationMenuItemOptions[];
  // content.menu 圆钮图标色，缺省 ColorTokens.primary
  menuIconColor?: ResourceColor;
  // 默认 true
  avoidLayoutSafeArea?: boolean;
  // 默认 false
  enableComponentSafeArea?: boolean;
}

export function buildPageTitleBarOptions(params: PageTitleBarParams): HdsNavigationTitleBarOptions {
  const content: TitleBarContentOptions = {
    backIcon: buildGlassBackIcon(params.back),
    stackBuilder: params.stackBuilder,
  } as TitleBarContentOptions;
  const style: TitleBarStyleOptions = buildGlassTitleBarStyle();
  // menuItems 非空数组才挂官方圆钮，缺省不挂 menu；content.menu 图标色默认白，浅色画布上
  // 不可见，只写 originalStyle（与返回键 backIconStyle 同策略，守卫写法对齐 UserProfileView 现状）。
  if (params.menuItems !== undefined && params.menuItems.length > 0) {
    content.menu = { value: params.menuItems } as HdsNavigationMenuContentOptions;
    const originalStyle = style.originalStyle;
    if (originalStyle !== undefined) {
      const contentStyle: HdsTitleBarContentStyle = originalStyle.contentStyle as HdsTitleBarContentStyle;
      contentStyle.menuStyle = { iconColor: params.menuIconColor ?? ColorTokens.primary } as HdsNavigationIconItemStyle;
      originalStyle.contentStyle = contentStyle;
    }
  }
  // avoidLayoutSafeArea 默认 true；enableComponentSafeArea 默认 false（true 会把内容区顶到
  // 栏体之下，穿底页面的让位由 List 的 contentStartOffset / 占位行承担）。
  return {
    content: content,
    style: style,
    avoidLayoutSafeArea: params.avoidLayoutSafeArea ?? true,
    enableComponentSafeArea: params.enableComponentSafeArea ?? false,
  };
}

@Component
export struct GlassTitleRow {
  @Prop title: string = '';
  // true → TypeTokens.title + fontFamilySerif（他人主页/发布壳）
  @Prop serif: boolean = false;
  // true 且 serif=false → TypeTokens.headline + fontFamilySerif（草稿/废纸篓/发布预览/发布壳）
  @Prop headlineSerif: boolean = false;
  // 副行开关（发布页进度行）
  @Prop hasSubRow: boolean = false;
  // 副行插槽（调用方传 @Builder 方法引用）
  @BuilderParam subRow: () => void = this.emptySlot;
  // 右侧动作开关（保存/提示等）
  @Prop hasActions: boolean = false;
  // 右侧动作插槽
  @BuilderParam actions: () => void = this.emptySlot;

  // @BuilderParam 未传时的空默认插槽
  @Builder
  emptySlot() {
  }

  build() {
    Stack({ alignContent: Alignment.Center }) {
      Column({ space: SpaceTokens.xs }) {
        Text(this.title)
          .width('100%')
          .textAlign(TextAlign.Center)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .padding({ left: HDS_BACK_SLOT_END_VP, right: HDS_BACK_SLOT_END_VP })
          .fontSize(this.serif ? TypeTokens.title.size : TypeTokens.headline.size)
          .fontWeight(this.serif ? TypeTokens.title.weight : TypeTokens.headline.weight)
          .lineHeight(this.serif ? TypeTokens.title.lineHeight : TypeTokens.headline.lineHeight)
          .fontFamily(this.serif || this.headlineSerif ? TypeTokens.fontFamilySerif : TypeTokens.fontFamily)
          .fontColor(ColorTokens.primary)
        if (this.hasSubRow) {
          this.subRow()
        }
      }
      .width('100%')
      .alignItems(HorizontalAlign.Center)
      // ⚠️ 标题层零交互、必须整体退出命中测试：Stack 两个全宽子节点完全重叠，若标题层
      // 盖在 actions 层之上（真机 UI tree 实证标题 Text bound=[0,125,1136,200] 覆盖发布钮
      // 中心点），Default 命中会被无手势的标题层吞掉——发布主钮「按压态亮但 onClick 不触发、
      // 程序化 tap（accessibility 通道）有效」的真机 bug 根因。None 让手指必然穿透到 actions 层。
      .hitTestBehavior(HitTestMode.None)

      if (this.hasActions) {
        Row() {
          Blank()
          this.actions()
        }
        .width('100%')
        // ⚠️ 必须撑满 MINI 标题区（同 MessagePage「全部已读」容器先例）：自适应高的全宽行
        // 在 Stack 居中后坐标系相对栏体错位，按钮下半截溢出栏体下缘（真机 UI tree 实测
        // 发布钮 bound y=137..250px、栏体 175px，中心 193px 在栏外）——HdsNavigation 标题栏
        // 触摸命中存在区域边界，手指点中心（栏外段）无响应、程序化 tap（accessibility 通道）
        // 无视边界却有效。撑满后按钮垂直居中回落栏内，命中区完整。
        .height('100%')
        .alignItems(VerticalAlign.Center)
      }
    }
    .width('100%')
    .height('100%')
  }
}

@Component
export struct GlassBarInsetRow {
  // 状态栏高度：穿底时内容顶部要让位 statusBarHeight + MINI 栏体高
  @Prop statusBarHeight: number = 0;

  build() {
    Row()
      .height(this.statusBarHeight + HDS_MINI_BAR_ROW_VP)
      .width('100%')
  }
}