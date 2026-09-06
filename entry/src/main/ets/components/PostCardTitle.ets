import { ColorTokens } from '../design/tokens/color';
import { SpaceTokens } from '../design/tokens/space';
import { TypeTokens } from '../design/tokens/type';

// 标题纯文字层：底色/边框/圆角由外层信息区统一提供（PostCard 中与点赞/作者合并为一块）。
@Component
export struct PostCardTitle {
  @Prop title: string = '';
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
    .alignItems(HorizontalAlign.Start)
  }
}
