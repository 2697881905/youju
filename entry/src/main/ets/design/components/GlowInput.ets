// GlowInput —— 统一输入框（**已按产品要求移除聚焦流光**）
//
// 历史：曾用 HdsVisualComponent + DUAL_EDGE_FLOW_LIGHT_WITH_BACKGROUND_MASK 在聚焦时
// 点亮鸿蒙沉浸光感「双边流光」。现全部输入框（搜索框、评论/聊天输入、编辑资料、
// 收藏夹命名、分享到私信…）统一去掉该效果，因此这里也一并移除了流光层与相关依赖。
// 文件名/组件名保留 GlowInput（7 处调用方不动），仅作历史命名。
//
// 现在的视觉：系统玻璃（backgroundBlurStyle）+ 主题描边 + 圆角，与 API 版本无关；
// segmentStyle=true 时用「分段栏同款」半透明白玻璃底 + backdropBlur + 1px 高光边框。
// 聚焦不再有额外高亮（流光已移除）。
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

import { GlassBlurStyle } from '../../utils/immersiveMaterial';
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
  }

  private notifyFocus(focus: boolean): void {
    if (this.onFocusChanged !== undefined) {
      this.onFocusChanged(focus);
    }
  }
}
