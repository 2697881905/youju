// 帖子关键词搜索结果页：顶栏(返回+可改搜索框+清除✕+结果计数) + 2列Grid(复用PostCard) + 三态(加载/空/失败)
// 数据来源：searchPosts（services/api.ets，复用 /v1/posts 端点）
// 点击跳转详情：照抄 HomeTab 父级 GridItem().onClick 包裹模式（PostCard 自身不处理点击）

import { Post } from '../models/types';
import { searchPosts } from '../services/api';
import { PostCard } from '../components/PostCard';
import { setDetailPostId } from '../utils/nav';
import { safeShowToast } from '../utils/toast';
import { buildPageTransition } from '../utils/styles';

@Entry
@Component
struct SearchResultPage {
  @State keyword: string = '';
  @State searchList: Post[] = [];
  @State total: number = 0;
  // 初始必须为 false：fetch 的并发守卫 `if (this.loading) return` 会拦截首次加载。
  // aboutToAppear→refresh→fetch 会在首个 await 前同步置 loading=true，build 仍能正常展示加载态。
  @State loading: boolean = false;
  @State error: string = '';
  @State finished: boolean = false;
  @StorageLink('statusBarHeight') statusBarHeight: number = 0;
  @State isRefreshing: boolean = false;
  @State pageNum: number = 1;
  private readonly limitNum: number = 10;

  aboutToAppear(): void {
    // API 24 router.getParams 失效；keyword 跨页传递用 AppStorage（与 detailPostId 一致）
    const kw: string | undefined = AppStorage.get<string>('searchKeyword');
    this.keyword = kw ?? '';
    this.refresh();
  }

  // 重置并加载第一页
  async refresh(): Promise<void> {
    this.pageNum = 1;
    this.finished = false;
    await this.fetch(true);
  }

  // 追加下一页
  async loadMore(): Promise<void> {
    if (this.finished || this.loading || this.isRefreshing) {
      return;
    }
    this.pageNum += 1;
    await this.fetch(false);
  }

  // 二次搜索：更新 keyword 后重搜（保留本页作为搜索结果页）
  private doSearch(raw: string): void {
    const kw = raw.trim();
    if (!kw) {
      safeShowToast(this.getUIContext(),{ message: '请输入搜索内容' });
      return;
    }
    AppStorage.setOrCreate('searchKeyword', kw);
    this.keyword = kw;
    this.refresh();
  }

  // 跳详情：照抄 HomeTab 父级包裹模式
  private goDetail(post: Post): void {
    if (post.id !== undefined) {
      const id = post.id.toString();
      AppStorage.setOrCreate('detailPostId', id);
      setDetailPostId(id);
      this.getUIContext().getRouter().pushUrl({ url: 'pages/DetailPage' });
    }
  }

  private async fetch(reset: boolean): Promise<void> {
    if (this.loading) {
      return;
    }
    this.loading = true;
    this.error = '';
    try {
      const res = await searchPosts({
        keyword: this.keyword,
        page: this.pageNum,
        pageSize: this.limitNum,
        sort: 'latest',
      });
      if (reset) {
        this.searchList = res.list;
        this.total = res.pagination.total;
      } else {
        this.searchList = this.searchList.concat(res.list);
      }
      if (res.list.length < this.limitNum) {
        this.finished = true;
      }
    } catch (e) {
      this.error = (e as Error).message;
    } finally {
      this.loading = false;
    }
  }

  @Builder
  refreshBuilder(): void {
    Row({ space: 8 }) {
      LoadingProgress().width(20).height(20)
      Text('刷新中…').fontSize(12).fontColor($r('app.color.text_secondary'))
    }
  }

  build() {
    Column() {
      // 顶栏：返回 + 可改搜索框 + 清除✕
      Row({ space: 8 }) {
        Text('←')
          .fontSize(20)
          .fontColor($r('app.color.text_primary'))
          .onClick(() => this.getUIContext().getRouter().back())

        TextInput({ placeholder: '搜索', text: this.keyword })
          .layoutWeight(1)
          .height(36)
          .backgroundColor($r('app.color.bg_secondary'))
          .borderRadius(18)
          .onChange((v: string) => {
            this.keyword = v;
          })
          .onSubmit(() => {
            this.doSearch(this.keyword);
          })

        if (this.keyword !== '') {
          Text('✕')
            .fontSize(16)
            .fontColor($r('app.color.text_secondary'))
            .onClick(() => {
              this.keyword = '';
            })
        }
      }
      .width('100%')
      .padding({ left: 12, right: 12, top: 12, bottom: 10 })
      .alignItems(VerticalAlign.Center)

      // 结果计数
      Row() {
        Text('共找到 ' + this.total + ' 篇')
          .fontSize(13)
          .fontColor($r('app.color.text_secondary'))
      }
      .width('100%')
      .padding({ left: 16, right: 16, bottom: 8 })

      // 三态主体
      if (this.searchList.length === 0 && this.loading) {
        // 加载中
        Column() {
          LoadingProgress().width(28).height(28)
          Text('加载中…')
            .fontSize(13)
            .fontColor($r('app.color.text_secondary'))
            .margin({ top: 10 })
        }
        .layoutWeight(1)
        .width('100%')
        .justifyContent(FlexAlign.Center)
      } else if (this.searchList.length === 0 && this.error !== '') {
        // 失败态
        Column() {
          Text('⚠️')
            .fontSize(36)
            .fontColor($r('app.color.text_secondary'))
          Text(this.error)
            .fontSize(14)
            .fontColor($r('app.color.text_secondary'))
            .margin({ top: 8 })
          Button('重试')
            .margin({ top: 16 })
            .onClick(() => this.refresh())
        }
        .layoutWeight(1)
        .width('100%')
        .justifyContent(FlexAlign.Center)
      } else if (this.searchList.length === 0) {
        // 空态
        Column() {
          Text('🔍')
            .fontSize(36)
            .fontColor($r('app.color.text_secondary'))
          Text('未找到相关帖子，换个关键词试试')
            .fontSize(14)
            .fontColor($r('app.color.text_secondary'))
            .margin({ top: 8 })
        }
        .layoutWeight(1)
        .width('100%')
        .justifyContent(FlexAlign.Center)
      } else {
        // 结果列表
        Refresh({ refreshing: this.isRefreshing, builder: this.refreshBuilder }) {
          Grid() {
            ForEach(
              this.searchList,
              (post: Post) => {
                GridItem() {
                  PostCard({ post: post })
                    .onClick(() => this.goDetail(post))
                }
              },
              (post: Post) => post.id?.toString() ?? ''
            )
            if (this.finished) {
              GridItem() {
                Text('没有更多了')
                  .fontSize(12)
                  .fontColor($r('app.color.text_secondary'))
                  .width('100%')
                  .textAlign(TextAlign.Center)
                  .padding(16)
              }
              .columnStart(0)
              .columnEnd(1)
            }
          }
          .columnsTemplate('1fr 1fr')
          .columnsGap(12)
          .rowsGap(12)
          .padding(12)
          .onScrollIndex((_start: number, end: number) => {
            if (end >= this.searchList.length - 1) {
              this.loadMore();
            }
          })
        }
        .onRefreshing(() => {
          this.isRefreshing = true;
          this.refresh().finally(() => {
            this.isRefreshing = false;
          });
        })
        .layoutWeight(1)
        .width('100%')
      }
    }
    .width('100%')
    .padding({ top: this.statusBarHeight })
    .height('100%')
    .alignItems(HorizontalAlign.Start)
    .backgroundColor($r('app.color.bg_primary'))
    .transition(buildPageTransition())
  }
}
