// 私信聊天「Navigation 壳」：承接 Navigation 内跳入聊天页的导航（pushPathByName('Chat', ...)）。
// 跳转方已在 push 前写入 openChat intent，onReady 内 ChatView.aboutToAppear 消费，故无需在壳层处理。
import { ChatView } from './ChatView';
import { getMainNavStack, VideoPlayerNavParams } from '../utils/navigationTransition';
import { ColorTokens } from '../design/tokens/color';
import { consumeOverlayBack } from '../utils/overlayBackGuard';

@Component
export struct ChatDestination {
  // 点聊天视频 → 独立播放器页（与帖子视频同一个页面，解耦于聊天页自身状态）
  private openVideo(url: string, poster: string): void {
    const nav: NavPathStack | null = getMainNavStack();
    if (nav === null) {
      return;
    }
    const p: VideoPlayerNavParams = new VideoPlayerNavParams();
    p.url = url;
    p.poster = poster;
    nav.pushPathByName('VideoPlayer', p);
  }

  build() {
    NavDestination() {
      ChatView({
        navMode: true,
        onOpenVideo: (url: string, poster: string): void => { this.openVideo(url, poster); },
        onBack: (): void => {
          // 页内全屏查看器（图片）打开时，页内返回按钮先关查看器，
          // 与系统返回手势保持一致（系统手势的拦截见下面的 onBackPressed）
          if (consumeOverlayBack()) {
            return;
          }
          const nav: NavPathStack | null = getMainNavStack();
          if (nav !== null) {
            nav.pop();
          }
        },
      })
    }
    .hideTitleBar(true)
    .backgroundColor(ColorTokens.canvas)
    // 系统返回手势/返回键：页内查看器打开时先关查看器（返回 true = 已处理，不执行默认 pop）。
    // Navigation 壳取代了 router 壳的 onBackPress —— 两者都要接，见 ChatPage.ets。
    .onBackPressed((): boolean => consumeOverlayBack())
    // 重新显示（含从播放器页/他人主页返回）→ 递增刷新信号：ChatView @Watch 承接静默重拉
    // （对方撤回/新消息在停留期间无实时推送，返回页面即同步；首次显示由
    // ChatView.hasLoadedOnce 去重，不会与 aboutToAppear 的首拉叠加）
    .onShown((): void => {
      AppStorage.setOrCreate<number>('chatRefreshSignal',
        (AppStorage.get<number>('chatRefreshSignal') ?? 0) + 1);
    })
  }
}