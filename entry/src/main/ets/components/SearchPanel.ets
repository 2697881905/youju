// 搜索面板：下拉式搜索建议（无独立头部，搜索框在首页顶栏）
// 子传父：通过普通函数属性回调（ArkTS V1 函数型变量不用 @Prop）
import { listSearchHistory, clearSearchHistory, listHotKeywords } from '../services/api';
import { safeShowToast } from '../utils/toast';

@Component
export struct SearchPanel {
  // 关键词选中回调（父组件传入，点击历史/热搜词时触发）
  onKeywordSelect: (keyword: string) => void = (keyword: string) => {};

  // 取消/返回回调（父组件关闭面板、回到原页面）
  onCancel: () => void = () => {};

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
      safeShowToast(this.getUIContext(), { message: '已清除搜索历史' });
    } catch (e) {
      safeShowToast(this.getUIContext(), { message: '清除失败，请重试' });
    }
  }

  build() {
    Column() {
      // 顶部取消（不搜索时返回，右对齐；非独立头部栏）
      Row() {
        Blank()
        Text('取消')
          .fontSize(15)
          .fontColor($r('app.color.brand_primary'))
          .padding({ right: 16, top: 12, bottom: 12 })
          .onClick(() => {
            this.onCancel();
          })
      }
      .width('100%')

      if (this.loadingState) {
        // 加载态
        Column() {
          LoadingProgress().width(28).height(28)
        }
        .layoutWeight(1)
        .width('100%')
        .justifyContent(FlexAlign.Center)
        .alignItems(HorizontalAlign.Center)
      } else {
        Scroll() {
          Column() {
            // ----- 搜索历史（列表形式，可清除）-----
            if (this.historyList.length > 0) {
              Row() {
                Text('搜索历史')
                  .fontSize(14)
                  .fontWeight(FontWeight.Bold)
                  .fontColor($r('app.color.text_primary'))
                Blank()
                Text('清除')
                  .fontSize(13)
                  .fontColor($r('app.color.text_secondary'))
                  .onClick(() => {
                    this.clearHistory();
                  })
              }
              .width('100%')
              .padding({ left: 16, right: 16, top: 4, bottom: 8 })

              ForEach(this.historyList, (kw: string, idx: number) => {
                Text(kw)
                  .width('100%')
                  .fontSize(15)
                  .fontColor($r('app.color.text_primary'))
                  .padding({ left: 16, right: 16, top: 12, bottom: 12 })
                  .onClick(() => {
                    this.onKeywordSelect(kw);
                  })
              }, (kw: string, idx: number) => 'history_' + idx.toString() + '_' + kw)

              Divider()
                .width('100%')
                .height(1)
                .color($r('app.color.divider'))
                .margin({ left: 16, right: 16, top: 4, bottom: 4 })
            }

            // ----- 猜你想搜 -----
            Row() {
              Text('猜你想搜')
                .fontSize(14)
                .fontWeight(FontWeight.Bold)
                .fontColor($r('app.color.text_primary'))
              Blank()
            }
            .width('100%')
            .padding({ left: 16, right: 16, top: 16, bottom: 8 })

            if (this.hotList.length === 0) {
              Text('暂无热搜词')
                .width('100%')
                .fontSize(14)
                .fontColor($r('app.color.text_secondary'))
                .padding({ left: 16, right: 16, top: 8, bottom: 12 })
            } else {
              ForEach(this.hotList, (kw: string, idx: number) => {
                Row({ space: 8 }) {
                  Text(kw)
                    .fontSize(15)
                    .fontColor($r('app.color.text_primary'))
                    .layoutWeight(1)
                  if (idx < 3) {
                    Text('热')
                      .fontSize(10)
                      .fontColor('#FFFFFF')
                      .backgroundColor('#FF453A')
                      .borderRadius(4)
                      .padding({ left: 4, right: 4, top: 2, bottom: 2 })
                  }
                }
                .width('100%')
                .padding({ left: 16, right: 16, top: 12, bottom: 12 })
                .onClick(() => {
                  this.onKeywordSelect(kw);
                })
              }, (kw: string, idx: number) => 'hot_' + idx.toString() + '_' + kw)
            }
          }
          .width('100%')
          .alignItems(HorizontalAlign.Start)
        }
        .layoutWeight(1)
        .width('100%')
        .scrollBar(BarState.Off)
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.bg_primary'))
  }
}
