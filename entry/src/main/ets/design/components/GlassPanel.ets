import { RadiusTokens } from '../tokens/radius';
import { ShadowTokens } from '../tokens/shadow';
import { SpaceTokens } from '../tokens/space';

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
    .backgroundColor($r('app.color.ds_elevated'))
    .border({ width: 1, color: $r('app.color.ds_separator'), style: BorderStyle.Solid })
    .borderRadius(this.radius)
    .shadow(ShadowTokens.cardAmbient)
    .clip(true)
  }
}
