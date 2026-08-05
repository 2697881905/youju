import { ColorTokens } from '../design/tokens/color';
import { RadiusTokens } from '../design/tokens/radius';
import { LayoutTokens, SpaceTokens } from '../design/tokens/space';
import { TypeTokens } from '../design/tokens/type';

@Component
export struct PostCardTitle {
  @Prop title: string = '';
  @Prop hasMedia: boolean = false;
  @Prop compact: boolean = false;

  build() {
    Column({ space: this.compact ? SpaceTokens.inlineTight : SpaceTokens.sm }) {
      Text(this.title)
        .fontSize(this.compact ? TypeTokens.body.size : TypeTokens.headline.size).fontFamily(TypeTokens.fontFamily)
        .fontWeight(TypeTokens.headline.weight)
        .lineHeight(this.compact ? 20 : TypeTokens.headline.lineHeight)
        .letterSpacing(TypeTokens.headline.tracking)
        .fontColor(ColorTokens.primary)
        .maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
    }
    .width('100%')
    .padding(this.compact ? SpaceTokens.xs : SpaceTokens.sm)
    .alignItems(HorizontalAlign.Start)
    .backgroundColor(ColorTokens.barSurface)
    .border({
      width: LayoutTokens.glassBorderWidth,
      color: ColorTokens.barBorder,
      style: BorderStyle.Solid,
    })
    .borderRadius({
      topLeft: this.hasMedia ? 0 : (this.compact ? RadiusTokens.xs : RadiusTokens.lg),
      topRight: this.hasMedia ? 0 : (this.compact ? RadiusTokens.xs : RadiusTokens.lg),
      bottomLeft: 0,
      bottomRight: 0,
    })
  }
}
