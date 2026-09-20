// 我的关注/粉丝页（router 壳）：主题逻辑全部在 MyFollowView（双壳共享），
// 本文件仅作为 main_pages.json「pages/MyFollowPage」的 @Entry 入口，
// 保持主页/他人主页 router 入口的行为。
import { MyFollowView } from './MyFollowView';

@Entry
@Component
export struct MyFollowPage {
  build() {
    Stack() {
      MyFollowView({ navMode: false })
    }
    .width('100%')
    .height('100%')
  }
}