// 私信聊天页（router 壳）：主题逻辑全部在 ChatView（双壳共享），
// 本文件仅作为 main_pages.json「pages/ChatPage」的 @Entry 入口，
// 保持消息页等 router 入口跳入聊天页的既有行为。
import { ChatView } from './ChatView';
import { consumeOverlayBack } from '../utils/overlayBackGuard';

@Entry
@Component
struct ChatPage {
  // 页内全屏查看器（图片 / 视频）打开时，返回手势先关查看器，不要直接退出聊天页。
  // ⚠️ onBackPress **只对 @Entry 组件生效** —— ChatView 里曾写过一份同逻辑的 onBackPress，
  // 因为它是 @Component（双壳共享）而从来没被调用过，属于「写了但不生效」的死代码。
  // Navigation 壳的对应拦截见 ChatDestination.onBackPressed。
  onBackPress(): boolean {
    return consumeOverlayBack();
  }

  build() {
    Stack() {
      ChatView({ navMode: false })
    }
    .width('100%')
    .height('100%')
  }
}
