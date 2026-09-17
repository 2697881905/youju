import { resolveDisplayImageUrl } from '../services/api';
import { ColorTokens } from '../design/tokens/color';
import { MotionShared } from '../design/tokens/motion';
import { RadiusTokens } from '../design/tokens/radius';
import { LayoutTokens } from '../design/tokens/space';

// 信息流媒体只负责稳定的 3:4 展示；草稿和发布预览有各自的专用内容模型，不复用此组件。
// 视频：信息流仅展示干净封面，点击卡片进入详情后再播放。
// 图片：统一 3:4 Cover 裁切（长图不再失调）；图片本身不绑定点击，
// 点击事件冒泡到卡片 Pressable 进入帖子详情，查看器仅在详情页内打开。
@Component
export struct PostCardMedia {
  @Prop imageUrl: string = '';
  @Prop videoUrl: string = '';
  @Prop videoCover: string = '';
  @Prop compact: boolean = false;
  // 「一镜到底」源元素：由 PostCard 注入 'card-expand-{id}'，空串 = 纯文字卡不挂
  @Prop sharedId: string = '';

  // 封面卡面（视频封面 / 首图共用同一 3:4 Cover 展示）
  @Builder
  coverFace(url: string): void {
    Image(resolveDisplayImageUrl(url))
      .width('100%')
      .aspectRatio(LayoutTokens.cardMediaAspectRatio)
      .objectFit(ImageFit.Cover)
      .backgroundColor(ColorTokens.sunken)
      // 封面不吃拖拽：Image 默认 draggable=true，长按后拖动会被系统拖拽接管，
      // 信息流滚动条会被卡住（与 DailyPostDeck 卡面同一处理）
      .draggable(false)
      .borderRadius({ topLeft: this.compact ? RadiusTokens.xs : RadiusTokens.lg, topRight: this.compact ? RadiusTokens.xs : RadiusTokens.lg, bottomLeft: 0, bottomRight: 0 })
      .clip(true)
  }

  // 「一镜到底」共享卡面：同 coverFace，追加共享元素（仅 sharedId 非空时选用）
  @Builder
  coverFaceShared(url: string): void {
    Image(resolveDisplayImageUrl(url))
      .width('100%')
      .aspectRatio(LayoutTokens.cardMediaAspectRatio)
      .objectFit(ImageFit.Cover)
      .backgroundColor(ColorTokens.sunken)
      // 封面不吃拖拽：Image 默认 draggable=true，长按后拖动会被系统拖拽接管，
      // 信息流滚动条会被卡住（与 DailyPostDeck 卡面同一处理）
      .draggable(false)
      .borderRadius({ topLeft: this.compact ? RadiusTokens.xs : RadiusTokens.lg, topRight: this.compact ? RadiusTokens.xs : RadiusTokens.lg, bottomLeft: 0, bottomRight: 0 })
      .clip(true)
      .sharedTransition(this.sharedId, MotionShared.transition)
  }

  // 视频场景展示图：视频封面优先，其次封面图（与信息流展示口径一致）
  private videoSource(): string {
    return this.videoCover.length > 0 ? this.videoCover : this.imageUrl;
  }

  build() {
    if (this.videoUrl.length > 0) {
      if (this.sharedId.length > 0) {
        this.coverFaceShared(this.videoSource())
      } else {
        this.coverFace(this.videoSource())
      }
    } else if (this.imageUrl.length > 0) {
      if (this.sharedId.length > 0) {
        this.coverFaceShared(this.imageUrl)
      } else {
        this.coverFace(this.imageUrl)
      }
    }
  }
}
