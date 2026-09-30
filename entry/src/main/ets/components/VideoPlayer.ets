import { resolveDisplayImageUrl } from '../services/api';

// 沉浸式短视频播放器：未播放时用「封面 Image」盖住 Video 表面——
// Video 首次解码首帧可能需几百毫秒，期间表面为纯黑，直接显示会“闪黑”；
// 播放按钮也悬浮在封面之上，观感与信息流卡片一致，点播放（onStart）后才撤封面。
@Component
export struct VideoPlayer {
  @Prop @Watch('onSourceChanged') src: string = '';
  @Prop poster: string | PixelMap = '';
  // 可选：传入后点击（视频/播放按钮）不再内联播放，而是回调由父级打开全屏查看器。
  onOpen: (() => void) | null = null;
  // 「媒体可显示」回调：封面解码完成 / 视频首帧就绪（onPrepared）/ 出错 —— 三者只发一次。
  // 一镜到底详情页据此放行 hero：视频帖没有真正的「首帧图」事件，只能靠封面来定这个时点。
  // （此前详情页没接这个回调，只能等 900ms 兜底计时器 → 进详情后媒体位空白约 1 秒。）
  onReady: (() => void) | null = null;
  private controller: VideoController = new VideoController();
  @State playing: boolean = false;
  // 是否已开始过播放：播放后再暂停显示 Video 真实画面（而非封面），避免打断观看
  private hasStarted: boolean = false;
  // onReady 只发一次：封面解码 / 首帧就绪 / 出错三个触发源会互相竞争，先到者生效
  private readyFired: boolean = false;

  private notifyReady(): void {
    if (this.readyFired) {
      return;
    }
    this.readyFired = true;
    this.onReady?.();
  }

  private onSourceChanged(): void {
    this.playing = false;
    this.hasStarted = false;
    this.readyFired = false;
  }

  private togglePlayback(): void {
    if (this.onOpen !== null) {
      this.onOpen();
      return;
    }
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
          .onPrepared((): void => { this.notifyReady(); })
          .onError((): void => { this.notifyReady(); })
          .onStart((): void => {
            this.playing = true;
            this.hasStarted = true;
          })
          .onPause((): void => { this.playing = false; })
          .onFinish((): void => { this.playing = false; })
          .onClick((): void => { this.togglePlayback(); })

        // 封面层：尚未开始播放时盖住 Video 表面（首帧未就绪期间也是封面，杜绝黑屏闪烁）
        if (!this.playing && !this.hasStarted && (this.poster as string).length > 0) {
          Image(typeof this.poster === 'string' ? resolveDisplayImageUrl(this.poster) : this.poster)
            .width('100%')
            .height('100%')
            .objectFit(ImageFit.Cover)
            .backgroundColor('#000000')
            .draggable(false)
            // 封面必须自己接点击：Image 默认吃掉触摸且不向下透传，此前只有悬浮播放按钮
            // （叠在封面之上）能点到，点封面本身无反应。点击语义与按钮一致（togglePlayback）。
            .onClick((): void => { this.togglePlayback(); })
            // 封面解码完成即放行 hero：这张图与信息流卡片用的是同一个 URL，通常已在
            // Image 缓存里，onComplete 会比视频 onPrepared 早得多 —— 详情页因此能在
            // 首帧就把封面显示出来，不必等兜底计时器。
            // 这里刻意**不加** .syncLoad(true)：URL 命中缓存时它没用，未命中时会用
            // 同步解码阻塞主线程（一镜到底动画正在跑），得不偿失。
            .onComplete((): void => { this.notifyReady(); })
        }

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