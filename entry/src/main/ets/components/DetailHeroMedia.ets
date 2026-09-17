import { resolveDisplayImageUrl } from '../services/api';
import { ColorTokens } from '../design/tokens/color';
import { MotionShared } from '../design/tokens/motion';
import { RadiusTokens } from '../design/tokens/radius';
import { LayoutTokens } from '../design/tokens/space';

// 「一镜到底」loading 期目标元素：与详情媒体区同帧（幅宽 0.75、lg 圆角、clip、黑底）。
// 帖子数据到达后同帧原位切换为 DetailMediaCarousel / VideoPlayer，媒体区位置零跳变；
// 共享元素 id 始终挂在「当前渲染的媒体容器」上，push/pop 时框架据此把源卡面飞进/飞回。

@Component
export struct DetailHeroMedia {
  @Prop url: string = '';
  // 空串 = 无共享元素（非卡片进入态，走普通占位）
  @Prop sharedId: string = '';
  // 卡面媒体展示比例（宽/高）：与源卡片同比例渲染，共享元素飞行全程等比放大
  @Prop mediaRatio: number = 0.75;

  @Builder
  heroFace(): void {
    Stack({ alignContent: Alignment.Center }) {
      Image(resolveDisplayImageUrl(this.url))
        .width('100%')
        .height('100%')
        .objectFit(ImageFit.Cover)
        .backgroundColor(ColorTokens.sunken)
        // 详情头图不吃拖拽：Image 默认 draggable=true，长按拖动会被系统拖拽接管，
        // 详情页需要向下拖动关页/滚动时会卡住（与信息流封面同一处理）
        .draggable(false)
    }
    .width('100%')
    .aspectRatio(this.mediaRatio)
    .backgroundColor(ColorTokens.sunken)
    .borderRadius(RadiusTokens.lg)
    .clip(true)
  }

  build() {
    if (this.sharedId.length > 0) {
      Stack() {
        this.heroFace()
      }
      .width('100%')
      .sharedTransition(this.sharedId, MotionShared.transition)
    } else {
      this.heroFace()
    }
  }
}