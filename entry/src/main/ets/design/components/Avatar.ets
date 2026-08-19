import { RadiusTokens } from '../tokens/radius';
import { resolveDisplayImageUrl } from '../../services/api';

@Component
export struct Avatar {
  @Prop avatar: string = '';
  @Prop name: string = '';
  @Prop avatarSize: number = 40;

  private safeAvatar(): string {
    return this.avatar ?? '';
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
      // 无头像兜底：品牌默认头像（据印·经验叠层），去蓝、中性、跨主题
      Image($r('app.media.default_avatar'))
        .width(this.avatarSize)
        .height(this.avatarSize)
        .borderRadius(RadiusTokens.pill)
        .objectFit(ImageFit.Cover)
        .clip(true)
    }
  }
}
