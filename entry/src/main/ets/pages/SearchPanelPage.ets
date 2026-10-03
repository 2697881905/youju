// 独立搜索页：承载搜索探索面板（最近搜索 + 热搜），提交/选中关键词后进结果页。
// 搜索面板从 HomeTab 解耦为独立路由页：全屏独立、无底部 Tab 栏、返回直达上一页。
// 面板内部自带 Navigation 标题栏（返回 + 搜索框 + 搜索按钮，沉浸光感生效区域），
// 状态栏避让由标题栏承担 —— 因此本页不再需要额外预留顶部安全区。
import { SearchPanel } from '../components/SearchPanel';
import { openSearch } from '../utils/nav';
import { recordSearchHistory } from '../services/api';

@Entry
@Component
struct SearchPanelPage {
  // 关键词进入结果页：先写入进程内搜索意图，再替换本页，使结果页返回时直达上一页（首页）。
  private search(kw: string): void {
    openSearch(kw);
    // fire-and-forget：记录搜索历史，失败不阻断
    recordSearchHistory(kw).catch((): void => {});
    this.getUIContext().getRouter().replaceUrl({ url: 'pages/SearchResultPage' });
  }

  build() {
    // @Entry 页面的 build 只允许一个容器根节点：用 Column 包住面板
    Column() {
      SearchPanel({
        onKeywordSelect: (kw: string): void => {
          this.search(kw);
        },
        onCancel: (): void => {
          this.getUIContext().getRouter().back();
        },
      })
    }
    .width('100%')
    .height('100%')
  }
}