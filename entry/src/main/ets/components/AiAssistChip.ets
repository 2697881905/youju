import { ColorTokens } from '../design/tokens/color';
import { RadiusTokens } from '../design/tokens/radius';
import { LayoutTokens, SpaceTokens } from '../design/tokens/space';
import { TypeTokens } from '../design/tokens/type';

// AI 辅助入口的统一小胶囊：空闲态 ✦ 前缀、加载态转圈。供「AI 优化标题」（三个发布页）
// 与「AI 整理成结构化」（StructuredComposer）共用，保证入口观感一致。
//
// enabled=false（服务端未配置 LLM 凭证）时整颗隐藏——调用方用 if 包裹，本组件不自行隐藏，
// 以便 Row 布局里与提示文案的配合由调用方决定。
// ⚠️ 属性名用 available 而非 enabled：后者是 CustomComponent 基类通用属性，同名 @Prop 编译冲突。
@Component
export struct AiAssistChip {
  label: string = 'AI 优化';
  @Prop busy: boolean = false;
  @Prop available: boolean = true;
  action: () => void = (): void => {};

  build() {
    Row({ space: 4 }) {
      if (this.busy) {
        LoadingProgress()
          .width(13)
          .height(13)
          .color(ColorTokens.brandPress)
      } else {
        Text('✦')
          .fontSize(TypeTokens.caption.size)
          .fontFamily(TypeTokens.fontFamily)
          .fontColor(ColorTokens.brandPress)
      }
      Text(this.busy ? 'AI 思考中' : this.label)
        .fontSize(TypeTokens.caption.size)
        .fontFamily(TypeTokens.fontFamily)
        .fontColor(ColorTokens.brandPress)
    }
    .padding({ left: SpaceTokens.sm, right: SpaceTokens.sm, top: 5, bottom: 5 })
    .borderRadius(RadiusTokens.pill)
    .border({ width: LayoutTokens.hairlineWidth, color: ColorTokens.separator, style: BorderStyle.Solid })
    .constraintSize({ minWidth: LayoutTokens.minTouchTarget })
    .justifyContent(FlexAlign.Center)
    .onClick((): void => {
      if (this.available && !this.busy) {
        this.action();
      }
    })
  }
}
