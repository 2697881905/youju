import { RadiusTokens } from '../tokens/radius';
import { resolveDisplayImageUrl } from '../../services/api';

// 头像从不参与拖拽：Image 的 draggable 默认 true，长按后拖动会被系统拖拽接管，
// 使所在容器的手势（PanGesture / LongPressGesture / Swiper 滑动）收不到 Update。
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
        .draggable(false)
        .clip(true)
    } else {
      // 无头像兜底：品牌默认头像（据印·经验叠层），去蓝、中性、跨主题
      Image($r('app.media.default_avatar'))
        .width(this.avatarSize)
        .height(this.avatarSize)
        .borderRadius(RadiusTokens.pill)
        .objectFit(ImageFit.Cover)
        .draggable(false)
        .clip(true)
    }
  }
}
