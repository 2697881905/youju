// 独立搜索页：承载搜索探索面板（最近搜索 + 热搜），提交/选中关键词后进结果页。
// 搜索面板从 HomeTab 解耦为独立路由页：全屏独立、无底部 Tab 栏、返回直达上一页。
// 独立页没有主框架的状态栏顶边距，需自行预留顶部安全区（否则内容顶到状态栏下）。
import { SearchPanel } from '../components/SearchPanel';
import { openSearch } from '../utils/nav';
import { recordSearchHistory } from '../services/api';
import { ColorTokens } from '../design/tokens/color';

@Entry
@Component
struct SearchPanelPage {
  @StorageLink('statusBarHeight') statusBarHeight: number = 0;

  // 关键词进入结果页：先写入进程内搜索意图，再替换本页，使结果页返回时直达上一页（首页）。
  private search(kw: string): void {
    openSearch(kw);
    // fire-and-forget：记录搜索历史，失败不阻断
    recordSearchHistory(kw).catch((): void => {});
    this.getUIContext().getRouter().replaceUrl({ url: 'pages/SearchResultPage' });
  }

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
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
    // 顶部安全区 padding 会露出容器自身背景：补画布底色，避免顶部出现白色空白带
    .padding({ top: this.statusBarHeight })
    .backgroundColor(ColorTokens.canvas)
  }
}