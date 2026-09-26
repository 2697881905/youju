// 帖子详情页（router 壳）：主题逻辑全部在 PostDetailView（双壳共享），
// 本文件仅作为 main_pages.json「pages/DetailPage」的 @Entry 入口，
// 保持搜索/圈子/我的/收藏等 8 个 router 入口与既有 sharedTransition 一镜到底行为。
import { PostDetailView } from './PostDetailView';
import { consumeOverlayBack } from '../utils/overlayBackGuard';

@Entry
@Component
struct DetailPage {
  // 页内全屏覆盖层（图片查看器 / 分享卡预览 / 数据面板）打开时，返回手势先关掉覆盖层，
  // 不要直接退出详情页。
  // ⚠️ onBackPress **只对 @Entry 组件生效**：写在共享的 PostDetailView 里不会被调用。
  // 本文件是 router 壳的 @Entry，Navigation 壳的对应拦截见 PostDetailDestination.onBackPressed。
  onBackPress(): boolean {
    return consumeOverlayBack();
  }

  build() {
    Stack() {
      PostDetailView({ navMode: false })
    }
    .width('100%')
    .height('100%')
  }
}
