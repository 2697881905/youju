// 圈子详情页（router 壳）：主题逻辑全部在 CircleDetailView（双壳共享），
// 本文件仅作为 main_pages.json「pages/CircleDetailPage」的 @Entry 入口，
// 保持圈子页 router 入口的行为。
import { CircleDetailView } from './CircleDetailView';

@Entry
@Component
struct CircleDetailPage {
  build() {
    Stack() {
      CircleDetailView({ navMode: false })
    }
    .width('100%')
    .height('100%')
  }
}