// 视频播放器封装（ArkUI Video）：封面预览 + 播放/暂停/全屏由系统控件提供。
// src 支持本地 uri（发布页预览）或远端 URL（详情/信息流播放）。
@Component
export struct VideoPlayer {
  @Prop src: string = '';
  @Prop poster: string = '';
  @Prop videoHeight: number = 200;

  build() {
    if (this.src.length > 0) {
      Video({ src: this.src, previewUri: this.poster })
        .width('100%')
        .height(this.videoHeight)
        .controls(true)
        .autoPlay(false)
        .objectFit(ImageFit.Contain)
        .borderRadius(8)
    }
  }
}
