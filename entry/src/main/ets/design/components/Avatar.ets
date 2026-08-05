import { ColorTokens } from '../tokens/color';
import { RadiusTokens } from '../tokens/radius';
import { TypeTokens } from '../tokens/type';
import { resolveDisplayImageUrl } from '../../services/api';

@Component
export struct Avatar {
  @Prop avatar: string = '';
  @Prop name: string = '';
  @Prop avatarSize: number = 40;

  private safeAvatar(): string {
    return this.avatar ?? '';
  }

  private safeName(): string {
    return this.name ?? '';
  }

  private initial(): string {
    const trimmed = this.safeName().trim();
    return trimmed.length > 0 ? trimmed.charAt(0) : '?';
  }

  build() {
    if (this.safeAvatar().length > 0) {
      Image(resolveDisplayImageUrl(this.safeAvatar()))
        .width(this.avatarSize)
        .height(this.avatarSize)
        .borderRadius(RadiusTokens.pill)
        .objectFit(ImageFit.Cover)
        .clip(true)
    } else {
      Text(this.initial())
        .width(this.avatarSize)
        .height(this.avatarSize)
        .borderRadius(RadiusTokens.pill)
        .fontSize(TypeTokens.body.size).fontFamily(TypeTokens.fontFamily)
        .fontWeight(TypeTokens.headline.weight)
        .fontColor(ColorTokens.brand)
        .backgroundColor(ColorTokens.brandTint)
        .textAlign(TextAlign.Center)
    }
  }
}
