// 私信聊天页（router 壳）：主题逻辑全部在 ChatView（双壳共享），
// 本文件仅作为 main_pages.json「pages/ChatPage」的 @Entry 入口，
// 保持消息页等 router 入口跳入聊天页的既有行为。
import { ChatView } from './ChatView';

@Entry
@Component
struct ChatPage {
  build() {
    Stack() {
      ChatView({ navMode: false })
    }
    .width('100%')
    .height('100%')
  }
}