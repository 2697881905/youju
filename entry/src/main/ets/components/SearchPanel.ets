// 搜索面板：全屏搜索页（参考小红书布局），自带 < 返回 + 输入框 + 搜索 头部栏
// 子传父：通过普通函数属性回调（ArkTS V1 函数型变量不用 @Prop）
import { listSearchHistory, clearSearchHistory, listHotKeywords } from '../services/api';
import { safeShowToast } from '../utils/toast';
import { CARD_RADIUS, CARD_SHADOW } from '../utils/cardTokens';

@Component
export struct SearchPanel {
  // 关键词选中回调（父组件传入，点击搜索/历史/热搜词时触发）
  onKeywordSelect: (keyword: string) => void = (keyword: string) => {};

  // 取消/返回回调（父组件关闭面板、回到原页面）
  onCancel: () => void = () => {};

  @State keyword: string = '';
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

  // 提交搜索
  private doSearch(): void {
    const kw = this.keyword.trim();
    if (!kw) {
      safeShowToast(this.getUIContext(), { message: '请输入搜索内容' });
      return;
    }
    this.onKeywordSelect(kw);
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
      // ===== 顶部导航栏： < 返回 | 搜索输入框 | 搜索按钮 =====
      Row({ space: 12 }) {
        // 返回按钮：nav_back 线条图标（48x44 容器包裹 24x24 图标，避免 Image 重复设宽高）
        Row() {
          Image($r('app.media.nav_back'))
            .width(22)
            .height(22)
            .fillColor($r('app.color.text_primary'))
        }
        .width(44)
        .height(44)
        .justifyContent(FlexAlign.Center)
        .onClick(() => {
          this.onCancel();
        })

        // 搜索输入框
        TextInput({ placeholder: '搜索', text: this.keyword })
          .height(36)
          .backgroundColor($r('app.color.bg_secondary'))
          .borderRadius(18)
          .layoutWeight(1)
          .onChange((v: string) => {
            this.keyword = v;
          })
          .onSubmit(() => {
            this.doSearch();
          })

        // 搜索按钮
        Text('搜索')
          .fontSize(15)
          .fontColor($r('app.color.brand_primary'))
          .padding({ left: 8, right: 16, top: 8, bottom: 8 })
          .onClick(() => {
            this.doSearch();
          })
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)
      .backgroundColor($r('app.color.bg_primary'))

      // ===== 内容区 =====
      if (this.loadingState) {
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
            // ----- 搜索历史（包进统一圆角卡片）-----
            if (this.historyList.length > 0) {
              Column() {
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
                .padding({ left: 16, right: 16, top: 12, bottom: 8 })

                ForEach(this.historyList, (kw: string, idx: number) => {
                  Column() {
                    Row({ space: 10 }) {
                      Image($r('app.media.history'))
                        .width(16)
                        .height(16)
                        .fillColor($r('app.color.text_secondary'))
                      Text(kw)
                        .fontSize(15)
                        .fontColor($r('app.color.text_primary'))
                        .layoutWeight(1)
                    }
                    .width('100%')
                    .padding({ left: 16, right: 16, top: 12, bottom: 12 })
                    .onClick(() => {
                      this.onKeywordSelect(kw);
                    })

                    if (idx < this.historyList.length - 1) {
                      Divider()
                        .color($r('app.color.divider'))
                        .margin({ left: 16, right: 16 })
                    }
                  }
                }, (kw: string, idx: number) => 'history_' + idx.toString() + '_' + kw)
              }
              .width('100%')
              .backgroundColor($r('app.color.card_bg'))
              .borderRadius(CARD_RADIUS)
              .shadow(CARD_SHADOW)
              .margin({ left: 16, right: 16, top: 8, bottom: 8 })
            }

            // ----- 猜你想搜（包进统一圆角卡片）-----
            Column() {
              Row() {
                Text('猜你想搜')
                  .fontSize(14)
                  .fontWeight(FontWeight.Bold)
                  .fontColor($r('app.color.text_primary'))
                Blank()
              }
              .width('100%')
              .padding({ left: 16, right: 16, top: 14, bottom: 8 })

              if (this.hotList.length === 0) {
                Text('暂无热搜词')
                  .width('100%')
                  .fontSize(14)
                  .fontColor($r('app.color.text_secondary'))
                  .padding({ left: 16, right: 16, top: 8, bottom: 14 })
              } else {
                ForEach(this.hotList, (kw: string, idx: number) => {
                  Column() {
                    Row({ space: 10 }) {
                      Image($r('app.media.empty_search'))
                        .width(16)
                        .height(16)
                        .fillColor($r('app.color.text_secondary'))
                      Text(kw)
                        .fontSize(15)
                        .fontColor($r('app.color.text_primary'))
                        .layoutWeight(1)
                      if (idx < 3) {
                        Text('热')
                          .fontSize(10)
                          .fontColor('#FFFFFF')
                          .backgroundColor($r('app.color.semantic_red'))
                          .borderRadius(4)
                          .padding({ left: 4, right: 4, top: 2, bottom: 2 })
                      }
                    }
                    .width('100%')
                    .padding({ left: 16, right: 16, top: 12, bottom: 12 })
                    .onClick(() => {
                      this.onKeywordSelect(kw);
                    })

                    if (idx < this.hotList.length - 1) {
                      Divider()
                        .color($r('app.color.divider'))
                        .margin({ left: 16, right: 16 })
                    }
                  }
                }, (kw: string, idx: number) => 'hot_' + idx.toString() + '_' + kw)
              }
            }
            .width('100%')
            .backgroundColor($r('app.color.card_bg'))
            .borderRadius(CARD_RADIUS)
            .shadow(CARD_SHADOW)
            .margin({ left: 16, right: 16, top: 6, bottom: 12 })
          }
          .width('100%')
        }
        .layoutWeight(1)
        .width('100%')
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.bg_primary'))
  }
}
