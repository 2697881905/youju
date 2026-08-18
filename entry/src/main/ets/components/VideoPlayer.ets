import { resolveDisplayImageUrl } from '../services/api';

// 沉浸式短视频播放器：系统只负责解码，默认仅展示封面与播放入口。
@Component
export struct VideoPlayer {
  @Prop @Watch('onSourceChanged') src: string = '';
  @Prop poster: string | PixelMap = '';
  private controller: VideoController = new VideoController();
  @State playing: boolean = false;

  private onSourceChanged(): void {
    this.playing = false;
  }

  private togglePlayback(): void {
    if (this.playing) {
      this.controller.pause();
    } else {
      this.controller.start();
    }
  }

  @Builder
  playControl(): void {
    Column() {
      Image($r('app.media.video_play'))
        .width(32)
        .height(32)
        .fillColor(Color.White)
        // 三角形的视觉重心偏左，轻微右移后与圆形光学居中。
        .translate({ x: 2 })
    }
    .width(68)
    .height(68)
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
    .backgroundColor('#66000000')
    .border({ width: 1, color: '#80FFFFFF', style: BorderStyle.Solid })
    .borderRadius(34)
    .onClick((): void => { this.togglePlayback(); })
  }

  build() {
    if (this.src.length > 0) {
      Stack({ alignContent: Alignment.Center }) {
        Video({
          src: resolveDisplayImageUrl(this.src),
          previewUri: typeof this.poster === 'string' ? resolveDisplayImageUrl(this.poster) : this.poster,
          controller: this.controller,
          posterOptions: { showFirstFrame: true },
        })
          .width('100%')
          .height('100%')
          .controls(false)
          .autoPlay(false)
          // 短视频预览必须同时填满容器宽高；比例不一致时裁掉边缘，不能留黑边。
          .objectFit(ImageFit.Cover)
          .onStart((): void => { this.playing = true; })
          .onPause((): void => { this.playing = false; })
          .onFinish((): void => { this.playing = false; })
          .onClick((): void => { this.togglePlayback(); })

        if (!this.playing) {
          this.playControl()
        }
      }
      .width('100%')
      .height('100%')
      .backgroundColor('#000000')
    }
  }
}
