// GlowInput —— 聚焦流光输入框
//
// 统一所有输入框的聚焦态视觉：点击键入（聚焦）时点亮鸿蒙沉浸光感**原生流光**，
// 失焦后流光随之熄灭（区别于此前常显的"亮色描边+冷色光晕"模拟发光）。
//
// 实现：HdsVisualComponent + DUAL_EDGE_FLOW_LIGHT_WITH_BACKGROUND_MASK，
// 与 ImmersiveSurface 同款双边流光。尺寸用根 Stack onAreaChange 实测驱动
// （同尺寸铁律：不使用 width/height('100%')，避免自动尺寸 Stack 撑满父容器）。
//
// 布局模式：
//   fillWidth=true  → 根 Stack 参与 flex 拉伸（.layoutWeight(1)），用于 Row 内
//                    与 BackButton/发送按钮等并排的输入框（搜索框/评论框/消息框…）
//   fillWidth=false → 根 Stack 占满父容器宽度（.width('100%')），用于 Column 内
//                    独立成行的输入框（命名弹窗/发布标题/编辑资料…）
//
// 用法：
//   GlowInput({
//     placeholder: '说点什么…',
//     text: $commentText,
//     fillWidth: true,
//     onEnter: (): void => { this.onSend(); },
//   })

import { HdsSceneController, HdsSceneType, HdsVisualComponent } from '@kit.UIDesignKit';
import { isImmersiveLightSenseSupported, GlassBlurStyle } from '../../utils/immersiveMaterial';
import { ColorTokens } from '../tokens/color';
import { RadiusTokens } from '../tokens/radius';
import { LayoutTokens, SpaceTokens } from '../tokens/space';
import { TypeTokens } from '../tokens/type';

@Component
export struct GlowInput {
  // 受控文本：外部 @State 变量经 $ 双向绑定（与 TextInput text 一致）
  @Link text: string;
  @Prop placeholder: string = '';
  @Prop fillWidth: boolean = true;
  // 输入框高度（不叫 height，避开 CustomComponent 基类同名方法）
  @Prop inputHeight: number = LayoutTokens.minTouchTarget;
  @Prop radius: number = RadiusTokens.floatingBar;
  // 最大输入长度（0=不限）
  @Prop maxLength: number = 0;
  onChange?: (value: string) => void = undefined;
  onEnter?: () => void = undefined;
  // 聚焦/失焦变化透出（如搜索面板需在再次聚焦时恢复联想词）
  onFocusChanged?: (focused: boolean) => void = undefined;

  @State focused: boolean = false;
  // 流光层像素尺寸：由根 Stack 实测驱动（同尺寸铁律，不用 '100%'）
  @State inputW: number = 0;
  @State inputH: number = 0;

  private glowController: HdsSceneController = new HdsSceneController();

  aboutToAppear(): void {
    if (isImmersiveLightSenseSupported()) {
      this.glowController.setSceneParams({
        backgroundMaskColors: ['#1EFFFFFF', '#1E86CFFF'],
        firstEdgeFlowLight: { startPos: 0, endPos: 0.5, color: '#C4FFFFFF' },
        secondEdgeFlowLight: { startPos: 0, endPos: -0.5, color: '#8FC8EFFF' },
      });
    }
  }

  private toggleFocus(focus: boolean): void {
    this.focused = focus;
    if (this.onFocusChanged !== undefined) {
      this.onFocusChanged(focus);
    }
  }

  build() {
    Stack({ alignContent: Alignment.Center }) {
      // 原生流光层：仅聚焦时点亮；置顶 + 触摸透传，不遮挡输入交互
      if (isImmersiveLightSenseSupported() && this.focused && this.inputW > 0 && this.inputH > 0) {
        HdsVisualComponent()
          .scene(HdsSceneType.DUAL_EDGE_FLOW_LIGHT_WITH_BACKGROUND_MASK, this.glowController)
          .width(this.inputW)
          .height(this.inputH)
          .borderRadius(this.radius)
          .clip(true)
          .hitTestBehavior(HitTestMode.Transparent)
      }

      TextInput({ placeholder: this.placeholder, text: this.text })
        .fontFamily(TypeTokens.fontFamily)
        .fontColor(ColorTokens.primary)
        .width('100%')
        .height(this.inputHeight)
        .backgroundBlurStyle(GlassBlurStyle.Floating)
        .backgroundColor(isImmersiveLightSenseSupported() ? Color.Transparent : ColorTokens.barSurface)
        .border({ width: LayoutTokens.glassBorderWidth, color: ColorTokens.barBorder, style: BorderStyle.Solid })
        .borderRadius(this.radius)
        .padding({ left: SpaceTokens.md, right: SpaceTokens.md })
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
        .onFocus((): void => { this.toggleFocus(true); })
        .onBlur((): void => { this.toggleFocus(false); })
    }
    .layoutWeight(this.fillWidth ? 1 : 0)
    .width(this.fillWidth ? 'auto' : '100%')
    .height(this.inputHeight)
    .onAreaChange((_oldValue: Area, newValue: Area): void => {
      const w: number = parseFloat(String(newValue.width));
      const h: number = parseFloat(String(newValue.height));
      if (w > 0 && h > 0 && (w !== this.inputW || h !== this.inputH)) {
        this.inputW = w;
        this.inputH = h;
      }
    })
  }
}