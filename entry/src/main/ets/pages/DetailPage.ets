// 帖子详情页（router 壳）：主题逻辑全部在 PostDetailView（双壳共享），
// 本文件仅作为 main_pages.json「pages/DetailPage」的 @Entry 入口，
// 保持搜索/圈子/我的/收藏等 8 个 router 入口与既有 sharedTransition 一镜到底行为。
import { PostDetailView } from './PostDetailView';

@Entry
@Component
struct DetailPage {
  build() {
    Stack() {
      PostDetailView({ navMode: false })
    }
    .width('100%')
    .height('100%')
  }
}