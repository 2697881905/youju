// 搜索面板：搜索历史（可清除）+ 热搜词，点击关键词触发搜索回调
// 子传父：通过普通函数属性 onKeywordSelect 回调（ArkTS V1 函数型变量不用 @Prop）
import { listSearchHistory, clearSearchHistory, listHotKeywords } from '../services/api';

@Component
export struct SearchPanel {
  // 关键词选中回调（父组件传入，点击历史/热搜词时触发）
  onKeywordSelect: (keyword: string) => void = (keyword: string) => {};

  @State historyList: string[] = [];
  @State hotList: string[] = [];
  @State loadingState: boolean = true;

  aboutToAppear(): void {
    this.loadData();
  }

  // 加载搜索历史 + 热搜词
  async loadData(): Promise<void> {
    this.loadingState = true;
    try {
      const history: string[] = await listSearchHistory();
      const hot: string[] = await listHotKeywords(10);
      this.historyList = history;
      this.hotList = hot;
    } catch (e) {
      // 加载失败不阻断，显示空态
      this.historyList = [];
      this.hotList = [];
    } finally {
      this.loadingState = false;
    }
  }

  // 清除搜索历史
  async clearHistory(): Promise<void> {
    try {
      await clearSearchHistory();
      this.historyList = [];
      this.getUIContext().getPromptAction().showToast({ message: '已清除搜索历史' });
    } catch (e) {
      this.getUIContext().getPromptAction().showToast({ message: '清除失败，请重试' });
    }
  }

  build() {
    Column() {
      if (this.loadingState) {
        // 加载态
        Column() {
          LoadingProgress().width(28).height(28)
        }
        .width('100%')
        .padding(24)
        .alignItems(HorizontalAlign.Center)
      } else {
        // ===== 搜索历史 =====
        Row() {
          Text('搜索历史')
            .fontSize(14)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.text_primary'))
          Blank()
          if (this.historyList.length > 0) {
            Text('清除')
              .fontSize(13)
              .fontColor($r('app.color.text_secondary'))
              .onClick(() => {
                this.clearHistory();
              })
          }
        }
        .width('100%')
        .padding({ left: 16, right: 16, bottom: 8 })

        if (this.historyList.length === 0) {
          Text('暂无搜索历史')
            .fontSize(13)
            .fontColor($r('app.color.text_secondary'))
            .padding({ left: 16, bottom: 12 })
        } else {
          Flex({ direction: FlexDirection.Row, wrap: FlexWrap.Wrap }) {
            ForEach(this.historyList, (kw: string, idx: number) => {
              Text(kw)
                .fontSize(13)
                .padding({ left: 12, right: 12, top: 6, bottom: 6 })
                .backgroundColor($r('app.color.card_bg'))
                .fontColor($r('app.color.text_primary'))
                .borderRadius(16)
                .margin({ right: 8, bottom: 8 })
                .onClick(() => {
                  this.onKeywordSelect(kw);
                })
            }, (kw: string, idx: number) => 'history_' + idx.toString() + '_' + kw)
          }
          .padding({ left: 16, right: 16 })
        }

        // ===== 热搜词 =====
        Text('热搜词')
          .fontSize(14)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.text_primary'))
          .padding({ left: 16, top: 12, bottom: 8 })

        if (this.hotList.length === 0) {
          Text('暂无热搜词')
            .fontSize(13)
            .fontColor($r('app.color.text_secondary'))
            .padding({ left: 16, bottom: 12 })
        } else {
          Flex({ direction: FlexDirection.Row, wrap: FlexWrap.Wrap }) {
            ForEach(this.hotList, (kw: string, idx: number) => {
              Row({ space: 4 }) {
                Text((idx + 1).toString())
                  .fontSize(12)
                  .fontWeight(FontWeight.Bold)
                  .fontColor($r('app.color.brand_primary'))
                Text(kw)
                  .fontSize(13)
                  .fontColor($r('app.color.text_primary'))
              }
              .padding({ left: 10, right: 12, top: 6, bottom: 6 })
              .backgroundColor($r('app.color.card_bg'))
              .borderRadius(16)
              .margin({ right: 8, bottom: 8 })
              .onClick(() => {
                this.onKeywordSelect(kw);
              })
            }, (kw: string, idx: number) => 'hot_' + idx.toString() + '_' + kw)
          }
          .padding({ left: 16, right: 16 })
        }
      }
    }
    .width('100%')
    .backgroundColor($r('app.color.bg_primary'))
  }
}
