import { RadiusTokens } from '../tokens/radius';
import { ShadowTokens } from '../tokens/shadow';
import { SpaceTokens } from '../tokens/space';
import { GlassBlurStyle } from '../../utils/immersiveMaterial';

// 普通内容卡片（搜索历史/热榜等）：用系统背景模糊，不加流光。
// 沉浸光感只应出现在浮层/输入框/悬浮条上；内容卡片发光会喧宾夺主。
@Component
export struct GlassPanel {
  @BuilderParam content: () => void = this.emptyContent;
  @Prop panelPadding: number = SpaceTokens.base;
  @Prop radius: number = RadiusTokens.xl;
  @Prop glassBlurRadius: number = 0;

  @Builder
  emptyContent(): void {}

  build() {
    Column() {
      this.content()
    }
    .width('100%')
    .padding(this.panelPadding)
    .backgroundBlurStyle(GlassBlurStyle.Card)
    .backgroundColor($r('app.color.ds_elevated'))
    .border({ width: 1, color: $r('app.color.ds_separator'), style: BorderStyle.Solid })
    .borderRadius(this.radius)
    .shadow(ShadowTokens.cardAmbient)
    .clip(true)
  }
}
