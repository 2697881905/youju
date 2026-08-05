import { RadiusTokens } from '../tokens/radius';
import { ShadowTokens } from '../tokens/shadow';
import { LayoutTokens, SpaceTokens } from '../tokens/space';

@Component
export struct GlassPanel {
  @BuilderParam content: () => void = this.emptyContent;
  @Prop panelPadding: number = SpaceTokens.base;
  @Prop radius: number = RadiusTokens.xl;
  @Prop glassBlurRadius: number = LayoutTokens.glassBlur;

  @Builder
  emptyContent(): void {}

  build() {
    Column() {
      this.content()
    }
    .width('100%')
    .padding(this.panelPadding)
    .backgroundColor($r('app.color.bar_surface'))
    .border({ width: LayoutTokens.glassBorderWidth, color: $r('app.color.bar_border'), style: BorderStyle.Solid })
    .backdropBlur(this.glassBlurRadius)
    .borderRadius(this.radius)
    .shadow(ShadowTokens.floating)
    .clip(true)
  }
}
