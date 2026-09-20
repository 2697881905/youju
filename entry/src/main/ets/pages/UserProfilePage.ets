// 用户主页（router 壳）：主体逻辑在 UserProfileView（双壳共享）
import { UserProfileView } from './UserProfileView';
@Entry
@Component
struct UserProfilePage {
  build() {
    Stack() {
      UserProfileView({ navMode: false })
    }
    .width('100%')
    .height('100%')
  }
}