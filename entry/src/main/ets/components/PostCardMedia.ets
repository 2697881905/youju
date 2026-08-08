import { resolveDisplayImageUrl } from '../services/api';
import { ColorTokens } from '../design/tokens/color';
import { RadiusTokens } from '../design/tokens/radius';
import { LayoutTokens } from '../design/tokens/space';

// 信息流媒体只负责稳定的 3:4 展示；草稿和发布预览有各自的专用内容模型，不复用此组件。
// 视频：信息流仅展示封面 + 播放角标（点击进详情播放，非自动播放）。
// 图片：统一 3:4 Cover 裁切（长图不再失调）；图片本身不绑定点击，
// 点击事件冒泡到卡片 Pressable 进入帖子详情，查看器仅在详情页内打开。
@Component
export struct PostCardMedia {
  @Prop imageUrl: string = '';
  @Prop videoUrl: string = '';
  @Prop videoCover: string = '';
  @Prop compact: boolean = false;

  build() {
    if (this.videoUrl.length > 0) {
      Stack({ alignContent: Alignment.Center }) {
        Image(resolveDisplayImageUrl(this.videoCover.length > 0 ? this.videoCover : this.imageUrl))
          .width('100%')
          .aspectRatio(LayoutTokens.cardMediaAspectRatio)
          .objectFit(ImageFit.Cover)
          .backgroundColor(ColorTokens.sunken)
        // 半透明黑底圆
        Column()
          .width(44)
          .height(44)
          .backgroundColor('#99000000')
          .borderRadius(22)
        // 播放三角（Path SVG commands，规避 ArkTS 元组数组类型风险）
        Path()
          .width(20)
          .height(22)
          .commands('M4,2 L18,11 L4,20 Z')
          .fill('#FFFFFF')
      }
      .width('100%')
      .aspectRatio(LayoutTokens.cardMediaAspectRatio)
      .borderRadius({ topLeft: this.compact ? RadiusTokens.xs : RadiusTokens.lg, topRight: this.compact ? RadiusTokens.xs : RadiusTokens.lg, bottomLeft: 0, bottomRight: 0 })
      .clip(true)
    } else if (this.imageUrl.length > 0) {
      Image(resolveDisplayImageUrl(this.imageUrl))
        .width('100%')
        .aspectRatio(LayoutTokens.cardMediaAspectRatio)
        // Cover 裁切填满 3:4 容器，长图不再缩小失调；完整内容在详情页查看器中查看。
        .objectFit(ImageFit.Cover)
        .backgroundColor(ColorTokens.sunken)
        .borderRadius({ topLeft: this.compact ? RadiusTokens.xs : RadiusTokens.lg, topRight: this.compact ? RadiusTokens.xs : RadiusTokens.lg, bottomLeft: 0, bottomRight: 0 })
        .clip(true)
    }
  }
}
