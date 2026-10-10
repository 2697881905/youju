// GlowInput —— 统一输入框（官方原生样式）
//
// 视觉（2026-10-04 改版）：对齐官方 HarmonyOS Design 的文本输入范式 ——
// 实色填充底（ColorTokens.subtle）+ 无描边 + 无模糊 + lg 胶囊圆角（20vp）+ 默认 40vp 高；
// 参照官方示例 HarmonyOSComponentUXExamples 输入类组件（文本框基于原生 TextInput/TextArea 定制）。
// 历史：曾用系统玻璃（backgroundBlurStyle）+ 主题描边，聚焦时点亮沉浸光感「双边流光」；
// 流光与玻璃底均已移除，文件名/组件名保留 GlowInput，仅作历史命名。
// segmentStyle=true 仍走「分段栏同款」半透明白玻璃底 + backdropBlur + 1px 高光边框（当前无调用方）。
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

import { GlassTokens } from '../tokens/GlassTokens';
import { ColorTokens } from '../tokens/color';
import { RadiusTokens } from '../tokens/radius';
import { SpaceTokens } from '../tokens/space';
import { TypeTokens } from '../tokens/type';

@Component
export struct GlowInput {
  // 受控文本：外部 @State 变量经 $ 双向绑定（与 TextInput text 一致）
  @Link text: string;
  @Prop placeholder: string = '';
  @Prop fillWidth: boolean = true;
  // 输入框高度（不叫 height，避开 CustomComponent 基类同名方法）；默认 40 = 官方 TextInput 标准高
  @Prop inputHeight: number = 40;
  // 文字/占位字号（fp；默认 16 = TextInput 系统默认，既有使用方不传则视觉不变）
  @Prop fontSize: number = 16;
  // 圆角：默认 lg(20) —— 与 40vp 高度构成官方胶囊输入框
  @Prop radius: number = RadiusTokens.lg;
  // 分段栏同款样式（搜索框试点）：半透明白玻璃底 + backdropBlur + 1px 高光边框 + lg 圆角，
  // 与 SegmentedControl immersive 完全同规格，视觉上输入框与分段栏属于同一材质体系
  @Prop segmentStyle: boolean = false;
  // 最大输入长度（0=不限）
  @Prop maxLength: number = 0;
  onChange?: (value: string) => void = undefined;
  onEnter?: () => void = undefined;
  // 聚焦/失焦变化透出（如搜索面板需在再次聚焦时恢复联想词）
  onFocusChanged?: (focused: boolean) => void = undefined;

  build() {
    Stack({ alignContent: Alignment.Center }) {
      TextInput({ placeholder: this.placeholder, text: this.text })
        .fontFamily(TypeTokens.fontFamily)
        // 固定 LTR：父层握姿镜像（Rtl）时输入内容仍从左排版，中文不被挤到右边
        .direction(Direction.Ltr)
        .fontSize(this.fontSize)
        // 行高按字号定比（1.45 倍）：不显式给的话走系统默认行盒，
        // 小字号 + 固定框高时文字底部会被裁掉。
        .lineHeight(this.fontSize * 1.45)
        .fontColor(ColorTokens.primary)
        // 占位文字对比度 ≥4.5:1（AGC 色彩审核项）：系统默认灰不达标，统一走 tertiary
        .placeholderColor(ColorTokens.tertiary)
        .width('100%')
        .height(this.inputHeight)
        // 默认分支 = 官方原生样式：实色填充底（subtle）+ 无模糊 + 无描边 + lg 胶囊圆角；
        // segmentStyle 分支保留原「分段栏同款」玻璃配方（半透明白玻璃底 + backdropBlur + 1px 高光边框）
        .backdropBlur(this.segmentStyle ? GlassTokens.SEGMENT_BLUR : 0)
        .backgroundColor(this.segmentStyle ? GlassTokens.SEGMENT_BG : ColorTokens.subtle)
        .border({
          width: this.segmentStyle ? 1 : 0,
          color: this.segmentStyle ? GlassTokens.SEGMENT_BORDER : ColorTokens.barBorder,
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
  }

  private notifyFocus(focus: boolean): void {
    if (this.onFocusChanged !== undefined) {
      this.onFocusChanged(focus);
    }
  }
}
