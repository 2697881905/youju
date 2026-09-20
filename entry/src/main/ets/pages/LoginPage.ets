// 登录欢迎页（router 壳）：主题逻辑全部在 LoginView（双壳共享），
// 本文件仅作为 main_pages.json「pages/LoginPage」的 @Entry 入口，
// 保持引导流程等 router 入口跳入登录页的既有行为。
import { LoginView } from './LoginView';

@Entry
@Component
struct LoginPage {
  build() {
    Stack() {
      LoginView({ navMode: false })
    }
    .width('100%')
    .height('100%')
  }
}