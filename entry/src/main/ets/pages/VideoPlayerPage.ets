// 独立视频播放器页（router 壳）：main_pages.json「pages/VideoPlayerPage」入口，
// 服务非 Navigation 栈的入口（路由壳详情页 / 分享链接冷启动等）。
// 与 VideoPlayerDestination 同为独立页面：参数经 utils/nav 的意图通道传入，返回走 router。
import { VideoViewer } from '../components/VideoViewer';
import { takeVideoPlayerIntent, VideoPlayerIntent } from '../utils/nav';

@Entry
@Component
struct VideoPlayerPage {
  @State url: string = '';
  @State poster: string = '';
  // 状态栏避让：让右上角关闭按钮落在状态栏之下（窗口是全屏沉浸式布局）
  @StorageLink('statusBarHeight') statusBarHeight: number = 0;

  aboutToAppear(): void {
    const intent: VideoPlayerIntent | null = takeVideoPlayerIntent();
    if (intent !== null) {
      this.url = intent.url;
      this.poster = intent.poster;
    }
  }

  build() {
    Stack() {
      if (this.url.length > 0) {
        VideoViewer({
          url: this.url,
          poster: this.poster,
          onClose: (): void => { this.getUIContext().getRouter().back(); },
        })
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(Color.Black)
    .padding({ top: this.statusBarHeight })
  }
}