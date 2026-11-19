// 发布页统一外壳（创作纸结构的可复用载体）—— 三个发布页真机验证后收敛于此，新增同类页面直接消费它。
//
// 它封装了「沉浸渐变模糊顶栏 + 内容穿底 + 双模态分宿主」整套已验证结构，调用方只需塞内容：
//   Stack() {                    // @Entry 根须内置容器；自定义组件尾随闭包后不能直接链通用属性
//     PublishPageShell({ modeLabel, progressValue, progressTotal, hint, actionLabel,
//                        actionDisabled, scroller, onAction, onBack }) {
//       Scroll(同一个 scroller) { /* 页面内容，首行补 topInset 让位 */ }
//         .bindContentCover(...) // 全模态挂调用方自己的 Scroll
//     }
//   }
//   .bindSheet(...)              // 半模态挂外层 Stack
//
// ⚠️ 踩坑清单（新增页面务必遵守，逐条都是真机实证）：
//  1. 双模态分宿主：bindSheet 挂外层 Stack、bindContentCover 挂内层 Scroll，绝不能同组件兼绑
//     ——平台规格「同组件同时绑两者 → 半模态生效、全模态静默失效」。
//  2. bindToScrollable 必须绑「真正挂在 Scroll 上的同一个 Scroller 实例」：调用方建 private scroller，
//     既传给外壳 scroller 属性、又挂 Scroll(scroller)。外壳用普通属性接（非 @Prop，@Prop 会复制实例致绑空）。
//  3. 穿底：enableComponentSafeArea=false + clip(false)，内容从窗口原点起算可画到栏下被模糊采样；
//     让位量由内容首行 topInset = statusBarHeight + PUBLISH_BAR_ROW_VP + 呼吸 补回（系统不再代顶）。
//  4. 材质要折射必须 EXQUISITE(0)，ADAPTIVE 只给普通半透；不支持沉浸光感的设备自动降级 GRADIENT_BLUR。
//  5. stackBuilder 行左内缩 HDS_BACK_SLOT_END_VP(64) 让开官方返回键，否则全宽行 z 序更高会吃掉返回键点击。
//  6. 外壳只有一个 @BuilderParam content：尾随闭包调用要求组件恰好一个 @BuilderParam（ArkTS 10905102），
//     标题行由 props 驱动而非第二个 @BuilderParam。
//  7. @Entry 的 build 根必须是内置容器，且自定义组件尾随闭包 `Shell({...}){...}` 之后不能再链 .bindSheet 等
//     通用属性（会被解析成独立语句报 10505001/10905210）→ 用 Stack 包住外壳，bindSheet 挂 Stack。
import { DesignButton } from '../design/components/DesignButton';
import { IconButton } from '../design/components/IconButton';
import { resolveActionIcon } from '../utils/actionIcons';
import { ColorTokens } from '../design/tokens/color';
import { RadiusTokens } from '../design/tokens/radius';
import { LayoutTokens, SpaceTokens } from '../design/tokens/space';
import { TypeTokens } from '../design/tokens/type';
import { isImmersiveLightSenseSupported, HDS_MATERIAL_TYPE_IMMERSIVE, HDS_MATERIAL_LEVEL_EXQUISITE } from '../utils/immersiveMaterial';
import { HdsNavigation, HdsNavigationTitleMode, ScrollEffectType } from '@kit.UIDesignKit';
import { LengthMetrics } from '@kit.ArkUI';
import type {
  HdsNavigationTitleBarOptions,
  TitleBarContentOptions,
  TitleBarStyleOptions,
  ScrollEffectOptions,
  SystemMaterialParams,
  HdsTitleBarContentStyle,
  HdsNavigationIconItemStyle,
  HdsNavigationBackButtonItemOptions,
  HdsNavigationIconOptions,
} from '@kit.UIDesignKit';

// 官方返回键占 16~56vp（40vp 圆 + 16vp 左内缩）；stackBuilder 行需让出这段（见踩坑 5）。
const HDS_BACK_SLOT_END_VP: number = 64;
// HdsNavigation MINI 标题区栏体高（实测 175px ÷ 3.125 = 56vp）。导出供调用方算穿底让位 topInset。
export const PUBLISH_BAR_ROW_VP: number = 56;
// 渐变模糊生效区间终点默认值（vp）：与草稿箱/聊天页同量级。
const DEFAULT_BLUR_END_VP: number = 32;

@Component
export struct PublishPageShell {
  // 唯一 @BuilderParam：页面内容（调用方自带 Scroll + 全模态绑定），尾随闭包传入。
  @BuilderParam content: () => void = this.emptyContent;
  @Prop modeLabel: string = '发布内容';
  // progressTotal=0 时不渲染进度行；hint 为空亦不渲染。
  @Prop progressValue: number = 0;
  @Prop progressTotal: number = 0;
  @Prop hint: string = '';
  // 右侧动作二选一：actionIcon 非空时渲染图标钮（搜索等），否则用 actionLabel 文字主钮。
  // 两个都空 = 纯标题页。
  @Prop actionIcon: string = '';
  @Prop actionA11y: string = '';
  @Prop actionLabel: string = '';
  @Prop actionDisabled: boolean = false;
  @Prop blurEndVp: number = DEFAULT_BLUR_END_VP;
  // 普通属性接 Scroller（非 @Prop）：与调用方 Scroll 共享同一实例，bindToScrollable 才绑得上（见踩坑 2）。
  scroller: Scroller = new Scroller();
  onAction: () => void = () => {};
  onBack: () => void = () => {};

  @Builder
  emptyContent(): void {}

  private isReady(): boolean {
    return this.progressTotal > 0 && this.progressValue >= this.progressTotal;
  }

  private titleBarOptions(): HdsNavigationTitleBarOptions {
    const immersive: boolean = isImmersiveLightSenseSupported();
    const scrollEffect: ScrollEffectOptions = {
      enableScrollEffect: true,
      scrollEffectType: immersive ? ScrollEffectType.IMMERSIVE_GRADIENT_BLUR : ScrollEffectType.GRADIENT_BLUR,
      blurEffectiveStartOffset: LengthMetrics.vp(0),
      blurEffectiveEndOffset: LengthMetrics.vp(this.blurEndVp),
    };
    const style: TitleBarStyleOptions = {
      scrollEffectOpts: scrollEffect,
      originalStyle: {
        backgroundStyle: { backgroundColor: Color.Transparent },
        contentStyle: {
          backIconStyle: { iconColor: ColorTokens.primary } as HdsNavigationIconItemStyle,
        } as HdsTitleBarContentStyle,
      },
    };
    if (immersive) {
      style.systemMaterialEffect = {
        materialType: HDS_MATERIAL_TYPE_IMMERSIVE,
        materialLevel: HDS_MATERIAL_LEVEL_EXQUISITE,
      } as SystemMaterialParams;
    }
    const backContent: HdsNavigationIconOptions = {
      icon: resolveActionIcon('back'),
      label: '返回',
      action: (): void => { this.onBack(); },
    };
    const backIcon: HdsNavigationBackButtonItemOptions = backContent;
    const content: TitleBarContentOptions = {
      stackBuilder: (): void => { this.titleRow(); },
      backIcon: backIcon,
    };
    const options: HdsNavigationTitleBarOptions = {
      content: content,
      style: style,
      avoidLayoutSafeArea: true,
      enableComponentSafeArea: false,
    };
    return options;
  }

  // 标题行：模式标题 + （可选）细进度与下一步提示 + （可选）主钮。左内缩让开官方返回键。
  @Builder
  titleRow(): void {
    Row({ space: SpaceTokens.sm }) {
      Column({ space: SpaceTokens.xs }) {
        Text(this.modeLabel)
          .fontSize(TypeTokens.headline.size).fontFamily(TypeTokens.fontFamilySerif)
          .fontWeight(TypeTokens.headline.weight)
          .lineHeight(TypeTokens.headline.lineHeight)
          .fontColor(ColorTokens.primary)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        if (this.progressTotal > 0) {
          Row({ space: SpaceTokens.inline }) {
            Progress({ value: this.progressValue, total: this.progressTotal, type: ProgressType.Linear })
              .width(44)
              .color(ColorTokens.brand)
              .backgroundColor(ColorTokens.separator)
              .style({ strokeWidth: SpaceTokens.xs, strokeRadius: RadiusTokens.xs, enableSmoothEffect: true })
            Text(this.hint)
              .fontSize(TypeTokens.caption.size).fontFamily(TypeTokens.fontFamily)
              .fontWeight(TypeTokens.caption.weight)
              .lineHeight(TypeTokens.caption.lineHeight)
              .fontColor(this.isReady() ? ColorTokens.brand : ColorTokens.secondary)
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
              .layoutWeight(1)
              .textAlign(TextAlign.Start)
          }
          .width('100%')
          .alignItems(VerticalAlign.Center)
        }
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)

      if (this.actionIcon.length > 0) {
        IconButton({
          icon: this.actionIcon,
          a11yText: this.actionA11y,
          action: (): void => { this.onAction(); },
        })
      } else if (this.actionLabel.length > 0) {
        DesignButton({
          label: this.actionLabel,
          variant: 'primary',
          visualHeight: LayoutTokens.segmentedHeight,
          disabled: this.actionDisabled,
          action: (): void => { this.onAction(); },
        })
      }
    }
    .width('100%')
    .height('100%')
    .alignItems(VerticalAlign.Center)
    .padding({ left: HDS_BACK_SLOT_END_VP, right: SpaceTokens.md })
  }

  build() {
    // 根 Stack 供调用方挂 bindSheet（半模态）；内层 content 的 Scroll 挂 bindContentCover（全模态）。
    Stack() {
      HdsNavigation() {
        this.content()
      }
      .mode(NavigationMode.Stack)
      .titleBar(this.titleBarOptions())
      .titleMode(HdsNavigationTitleMode.MINI)
      .bindToScrollable([this.scroller])
      .clip(false)
      .width('100%')
      .height('100%')
      .backgroundColor(ColorTokens.canvas)
    }
    .width('100%')
    .height('100%')
    .backgroundColor(ColorTokens.canvas)
  }
}