import { Avatar } from './Avatar';
import { ColorTokens } from '../tokens/color';
import { IconTokens } from '../tokens/icon';
import { SpaceTokens } from '../tokens/space';
import { TypeTokens } from '../tokens/type';

@Component
export struct AuthorRow {
  @Prop avatar: string = '';
  @Prop name: string = '匿名';
  @Prop meta: string = '';
  @Prop compact: boolean = true;

  private safeAvatar(): string {
    return this.avatar ?? '';
  }

  private safeName(): string {
    return this.name ?? '匿名';
  }

  private safeMeta(): string {
    return this.meta ?? '';
  }

  build() {
    Row({ space: SpaceTokens.inline }) {
      Avatar({
        avatar: this.safeAvatar(),
        name: this.safeName(),
        avatarSize: this.compact ? IconTokens.avatarCompact : IconTokens.standard,
      })
      Text(this.safeName())
        .fontSize(TypeTokens.callout.size).fontFamily(TypeTokens.fontFamily)
        .fontWeight(TypeTokens.callout.weight)
        .lineHeight(TypeTokens.callout.lineHeight)
        .letterSpacing(TypeTokens.callout.tracking)
        .fontColor(ColorTokens.secondary)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
      if (this.safeMeta().length > 0) {
        Text(this.safeMeta())
          .fontSize(TypeTokens.caption.size).fontFamily(TypeTokens.fontFamily)
          .fontWeight(TypeTokens.caption.weight)
          .lineHeight(TypeTokens.caption.lineHeight)
          .letterSpacing(TypeTokens.caption.tracking)
          .fontColor(ColorTokens.tertiary)
          .maxLines(1)
      }
    }
    .width('100%')
    .alignItems(VerticalAlign.Center)
  }
}
