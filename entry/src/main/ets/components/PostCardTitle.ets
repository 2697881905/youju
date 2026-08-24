import { ColorTokens } from '../design/tokens/color';
import { RadiusTokens } from '../design/tokens/radius';
import { SpaceTokens } from '../design/tokens/space';
import { TypeTokens } from '../design/tokens/type';

@Component
export struct PostCardTitle {
  @Prop title: string = '';
  @Prop hasMedia: boolean = false;
  @Prop compact: boolean = false;

  build() {
    Column({ space: this.compact ? SpaceTokens.inlineTight : SpaceTokens.sm }) {
      Text(this.title)
        .fontSize(this.compact ? TypeTokens.body.size + 2 : TypeTokens.headline.size)
        .fontFamily(TypeTokens.fontFamilySerif)
        .fontWeight(TypeTokens.headline.weight)
        .lineHeight(this.compact ? 24 : TypeTokens.headline.lineHeight)
        .letterSpacing(TypeTokens.headline.tracking)
        .fontColor(ColorTokens.primary)
        .maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
    }
    .width('100%')
    .padding(this.compact ? SpaceTokens.xs : SpaceTokens.sm)
    .alignItems(HorizontalAlign.Start)
    .backgroundColor(ColorTokens.elevated)
    // 标题是纸面卡片的第一层，只保留极细的纸张分隔线。
    .border({
      width: {
        left: 1,
        right: 1,
        top: 1,
        bottom: 0,
      },
      color: ColorTokens.separator,
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
