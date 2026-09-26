// 私信聊天「Navigation 壳」：承接 Navigation 内跳入聊天页的导航（pushPathByName('Chat', ...)）。
// 跳转方已在 push 前写入 openChat intent，onReady 内 ChatView.aboutToAppear 消费，故无需在壳层处理。
import { ChatView } from './ChatView';
import { getMainNavStack } from '../utils/navigationTransition';
import { ColorTokens } from '../design/tokens/color';
import { consumeOverlayBack } from '../utils/overlayBackGuard';

@Component
export struct ChatDestination {
  build() {
    NavDestination() {
      ChatView({
        navMode: true,
        onBack: (): void => {
          // 页内全屏查看器（图片/视频）打开时，页内返回按钮先关查看器，
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
  }
}