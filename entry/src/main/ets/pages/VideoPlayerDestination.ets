// 独立视频播放器页（Navigation 壳）：承接 Navigation 栈里的 pushPathByName('VideoPlayer')。
//
// 解耦要点：播放器不再以「页内浮层」形式挂在帖子详情等宿主页面里（那会与宿主布局、
// 返回守卫、状态机耦合，并且整屏图层会参与宿主列布局），而是作为独立页面存在：
// - 播放参数只经导航参数传入，页面对宿主一无所知；
// - 返回由 Navigation 栈自身负责（系统返回手势/返回键直接 pop），无需 overlayBackGuard；
// - 页面卸载即销毁播放器，音频必然停止，无需宿主额外停播。
import { VideoViewer } from '../components/VideoViewer';
import { getMainNavStack, VideoPlayerNavParams } from '../utils/navigationTransition';

@Component
export struct VideoPlayerDestination {
  @State url: string = '';
  @State poster: string = '';
  // 状态栏避让：让右上角关闭按钮落在状态栏之下（窗口是全屏沉浸式布局）
  @StorageLink('statusBarHeight') statusBarHeight: number = 0;

  private close(): void {
    const nav: NavPathStack | null = getMainNavStack();
    if (nav !== null) {
      nav.pop();
    }
  }

  build() {
    NavDestination() {
      // 黑底铺满整页：视频 Contain 留边（含状态栏避让区）时观感与全屏播放一致
      Stack() {
        if (this.url.length > 0) {
          VideoViewer({
            url: this.url,
            poster: this.poster,
            onClose: (): void => { this.close(); },
          })
        }
      }
      .width('100%')
      .height('100%')
      .backgroundColor(Color.Black)
      .padding({ top: this.statusBarHeight })
    }
    .hideTitleBar(true)
    .backgroundColor(Color.Black)
    .onReady((ctx: NavDestinationContext) => {
      const param: VideoPlayerNavParams = ctx.pathInfo.param as VideoPlayerNavParams;
      if (param === undefined || param === null || typeof param.url !== 'string') {
        return;
      }
      this.url = param.url;
      this.poster = typeof param.poster === 'string' ? param.poster : '';
    })
  }
}