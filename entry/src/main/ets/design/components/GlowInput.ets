// GlowInput —— 统一输入框（沉浸光感为**可选增强**，默认关闭）
//
// 历史：曾内置聚焦流光（HdsVisualComponent + DUAL_EDGE_FLOW_LIGHT_WITH_BACKGROUND_MASK），
// 后按产品要求全局移除（eadadf5）。2026-09-29 搜索栏要求恢复鸿蒙 6 沉浸光感原生材质
// （对齐官方「多设备新闻阅读界面」样例的沉浸式搜索栏：材质常显，不随聚焦开关），
// 故以 @Prop immersive 开关形式恢复——**仅显式传入的调用方生效**，其余 7 处调用方零变化。
//
// 两种视觉：
//   immersive=false（默认）→ 系统玻璃（backgroundBlurStyle）+ 主题描边 + 圆角，与 API 无关；
//   segmentStyle=true      → 「分段栏同款」半透明白玻璃底 + backdropBlur + 1px 高光边框 + lg 圆角；
//   immersive=true         → 在上述任一底色下叠原生双边流光（不支持光感的设备自动跳过，
//                             保留底色，视觉与现在一致、绝不白屏——同 ImmersiveSurface 降级策略）。
//
// 布局模式：
//   fillWidth=true  → 根 Stack 参与 flex 拉伸（.layoutWeight(1)），用于 Row 内
//                    与 BackButton/发送按钮等并排的输入框（搜索框/评论框/消息框…）
//   fillWidth=false → 根 Stack 占满父容器宽度（.width('100%')），用于 Column 内
//                    独立成行的输入框（命名弹窗/发布标题/编辑资料…）
//
// 流光层放在 TextInput **下层**：输入文字可读性优先，光晕透过半透明玻璃底透出；
// 尺寸用根 Stack onAreaChange 实测驱动（同尺寸铁律：不用 width/height('100%')，
// 避免自动尺寸 Stack 撑满父容器——发布弹窗全屏发光的根因）。

import { HdsSceneController, HdsSceneType, HdsVisualComponent } from '@kit.UIDesignKit';
import { isImmersiveLightSenseSupported, GlassBlurStyle } from '../../utils/immersiveMaterial';
import { ColorTokens } from '../tokens/color';
import { RadiusTokens } from '../tokens/radius';
import { LayoutTokens, SpaceTokens } from '../tokens/space';
import { TypeTokens } from '../tokens/type';

// —— 分段栏同款参数（与 SegmentedControl.ets 顶部 IMMERSIVE_* 完全同值）——
const SEGMENT_GLASS_BG: ResourceColor = '#20FFFFFF';
const SEGMENT_GLASS_BLUR: number = 20;
const SEGMENT_GLASS_BORDER: ResourceColor = '#30FFFFFF';

@Component
export struct GlowInput {
  // 受控文本：外部 @State 变量经 $ 双向绑定（与 TextInput text 一致）
  @Link text: string;
  @Prop placeholder: string = '';
  @Prop fillWidth: boolean = true;
  // 输入框高度（不叫 height，避开 CustomComponent 基类同名方法）
  @Prop inputHeight: number = LayoutTokens.minTouchTarget;
  // 文字/占位字号（fp；默认 16 = TextInput 系统默认，既有使用方不传则视觉不变）
  @Prop fontSize: number = 16;
  @Prop radius: number = RadiusTokens.floatingBar;
  // 分段栏同款样式（搜索框试点）：半透明白玻璃底 + backdropBlur + 1px 高光边框 + lg 圆角，
  // 与 SegmentedControl immersive 完全同规格，视觉上输入框与分段栏属于同一材质体系
  @Prop segmentStyle: boolean = false;
  // 沉浸光感原生材质（鸿蒙 6 双边流光）：仅显式传入的调用方生效（当前唯一：搜索面板搜索框）。
  // 材质常显（对齐官方样例），不支持光感的设备自动跳过——流光层不渲染，底色不变。
  @Prop immersive: boolean = false;
  // 最大输入长度（0=不限）
  @Prop maxLength: number = 0;
  onChange?: (value: string) => void = undefined;
  onEnter?: () => void = undefined;
  // 聚焦/失焦变化透出（如搜索面板需在再次聚焦时恢复联想词）
  onFocusChanged?: (focused: boolean) => void = undefined;

  // 流光层像素尺寸：由根 Stack onAreaChange 实测驱动（同尺寸铁律，不用 '100%'——
  // 自动尺寸 Stack 会按父约束解析百分比，弹窗场景曾撑满整屏）。
  @State inputW: number = 0;
  @State inputH: number = 0;

  // HdsSceneController @since 6.0.2(22)：API 20/21 上构造函数不存在。
  // 惰性创建，且仅在 immersive && isImmersiveLightSenseSupported()（API 23+）路径下使用——
  // 低版本设备/未开启沉浸的调用方永远不会触碰构造，避免字段初始化即崩。
  private glowController: HdsSceneController | null = null;

  // 惰性获取控制器：只在 API 23+ 路径下触发 new，低版本设备不会执行。
  private getGlowController(): HdsSceneController {
    if (this.glowController === null) {
      this.glowController = new HdsSceneController();
    }
    return this.glowController;
  }

  aboutToAppear(): void {
    if (this.immersive && isImmersiveLightSenseSupported()) {
      this.getGlowController().setSceneParams({
        backgroundMaskColors: ['#1EFFFFFF', '#1E86CFFF'],
        firstEdgeFlowLight: { startPos: 0, endPos: 0.5, color: '#C4FFFFFF' },
        secondEdgeFlowLight: { startPos: 0, endPos: -0.5, color: '#8FC8EFFF' },
      });
    }
  }

  build() {
    Stack({ alignContent: Alignment.Center }) {
      // 原生流光层：仅 immersive 且支持光感时渲染；置于 TextInput 下层
      // （文字可读性优先，光晕透过半透明玻璃底透出）+ 触摸透传，不遮挡输入交互。
      // 尺寸实测：Root Stack onAreaChange（layoutWeight 拉伸下内层量测会偏小，见文件头）。
      if (this.immersive && isImmersiveLightSenseSupported() && this.inputW > 0 && this.inputH > 0) {
        HdsVisualComponent()
          .scene(HdsSceneType.DUAL_EDGE_FLOW_LIGHT_WITH_BACKGROUND_MASK, this.getGlowController())
          .width(this.inputW)
          .height(this.inputH)
          .borderRadius(this.segmentStyle ? RadiusTokens.lg : this.radius)
          .clip(true)
          .hitTestBehavior(HitTestMode.Transparent)
      }

      TextInput({ placeholder: this.placeholder, text: this.text })
        .fontFamily(TypeTokens.fontFamily)
        // 固定 LTR：父层握姿镜像（Rtl）时输入内容仍从左排版，中文不被挤到右边
        .direction(Direction.Ltr)
        .fontSize(this.fontSize)
        // 行高按字号定比（1.45 倍）：不显式给的话走系统默认行盒，
        // 小字号 + 紧凑高度（如详情页 Dock 的 32vp）时文字底部会被裁掉。
        .lineHeight(this.fontSize * 1.45)
        .fontColor(ColorTokens.primary)
        .width('100%')
        .height(this.inputHeight)
        // 分段栏同款（segmentStyle）：backdropBlur 伪沉浸 + 半透明白玻璃底 + 1px 高光边框 + lg 圆角；
        // 普通模式维持系统玻璃（backgroundBlurStyle）方案
        .backgroundBlurStyle(this.segmentStyle ? BlurStyle.NONE : GlassBlurStyle.Floating)
        .backdropBlur(this.segmentStyle ? SEGMENT_GLASS_BLUR : 0)
        .backgroundColor(this.segmentStyle ? SEGMENT_GLASS_BG : ColorTokens.barSurface)
        .border({
          width: 1,
          color: this.segmentStyle ? SEGMENT_GLASS_BORDER : ColorTokens.barBorder,
          style: BorderStyle.Solid,
        })
        .borderRadius(this.segmentStyle ? RadiusTokens.lg : this.radius)
        // 上下内边距显式归零：否则默认值叠加在小高度容器上会把文字挤出可视区（底部截断）
        .padding({ left: SpaceTokens.md, right: SpaceTokens.md, top: 0, bottom: 0 })
        .maxLength(this.maxLength > 0 ? this.maxLength : 2147483647)
        .onChange((v: string): void => {
          this.text = v;
          if (this.onChange !== undefined) {
            this.onChange(String(v));
          }
        })
        .onSubmit((): void => {
          if (this.onEnter !== undefined) {
            this.onEnter();
          }
        })
        .onFocus((): void => { this.notifyFocus(true); })
        .onBlur((): void => { this.notifyFocus(false); })
    }
    .layoutWeight(this.fillWidth ? 1 : 0)
    .width(this.fillWidth ? 'auto' : '100%')
    .height(this.inputHeight)
    // 流光层实测尺寸来源：layoutWeight 拉伸下根 Stack 拿到最终分配尺寸
    // （内层 TextInput '100%' 量到的可能偏小——搜索框流光「尺寸太小」的历史根因）。
    .onAreaChange((_oldValue: Area, newValue: Area): void => {
      const w: number = parseFloat(String(newValue.width));
      const h: number = parseFloat(String(newValue.height));
      if (w > 0 && h > 0 && (w !== this.inputW || h !== this.inputH)) {
        this.inputW = w;
        this.inputH = h;
      }
    })
  }

  private notifyFocus(focus: boolean): void {
    if (this.onFocusChanged !== undefined) {
      this.onFocusChanged(focus);
    }
  }
}
