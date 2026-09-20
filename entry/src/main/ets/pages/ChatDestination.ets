// 私信聊天「Navigation 壳」：承接 Navigation 内跳入聊天页的导航（pushPathByName('Chat', ...)）。
// 跳转方已在 push 前写入 openChat intent，onReady 内 ChatView.aboutToAppear 消费，故无需在壳层处理。
import { ChatView } from './ChatView';
import { getMainNavStack } from '../utils/navigationTransition';
import { ColorTokens } from '../design/tokens/color';

@Component
export struct ChatDestination {
  build() {
    NavDestination() {
      ChatView({
        navMode: true,
        onBack: (): void => {
          const nav: NavPathStack | null = getMainNavStack();
          if (nav !== null) {
            nav.pop();
          }
        },
      })
    }
    .hideTitleBar(true)
    .backgroundColor(ColorTokens.canvas)
  }
}