// 首页 feed（真实内容）：顶栏(三子Tab+搜索框同水平) + 标签筛选 + 帖子网格
// 数据来源：listPosts / listTags（services/api.ets）
import { router, promptAction } from '@kit.ArkUI';
import { Post, Tag } from '../models/types';
import { listPosts, listTags } from '../services/api';
import { PostCard } from './PostCard';
import { TagNav } from './TagNav';
import { setDetailPostId } from '../utils/nav';

type SortKey = 'hot' | 'latest' | 'recommend';

const SUB_TABS: string[] = ['热榜', '最新', '推荐'];
const SORT_KEYS: SortKey[] = ['hot', 'latest', 'recommend'];
const ALL_TAG: Tag = { name: '全部', emoji: '🔥' };

@Component
export struct HomeTab {
  @State posts: Post[] = [];
  @State displayTags: Tag[] = [];
  @State sortIndex: number = 0;
  @State @Watch('onTagChanged') tagIndex: number = 0;
  @State page: number = 1;
  @State loading: boolean = false;
  @State finished: boolean = false;
  @State isRefreshing: boolean = false;
  @State error: string = '';
  @State searchKeyword: string = '';

  aboutToAppear(): void {
    this.loadTags();
    this.refresh();
  }

  async loadTags(): Promise<void> {
    try {
      const tags = await listTags();
      this.displayTags = [ALL_TAG, ...tags];
    } catch (e) {
      // 标签加载失败不阻断列表；保留 "全部"
      this.displayTags = [ALL_TAG];
    }
  }

  // 重置并加载第一页
  async refresh(): Promise<void> {
    this.page = 1;
    this.finished = false;
    await this.fetch(true);
  }

  // 追加下一页
  async loadMore(): Promise<void> {
    if (this.finished || this.loading || this.isRefreshing) {
      return;
    }
    this.page += 1;
    await this.fetch(false);
  }

  onTagChanged(): void {
    this.refresh();
  }

  private currentTag(): string | undefined {
    return this.tagIndex > 0 ? this.displayTags[this.tagIndex]?.name : undefined;
  }

  private async fetch(reset: boolean): Promise<void> {
    if (this.loading) {
      return;
    }
    this.loading = true;
    this.error = '';
    const sort = SORT_KEYS[this.sortIndex];
    try {
      const res = await listPosts({ page: this.page, limit: 20, sort, tag: this.currentTag() });
      if (reset) {
        this.posts = res.list;
      } else {
        this.posts = this.posts.concat(res.list);
      }
      if (res.list.length < 20) {
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
      // 顶栏：左侧三子Tab（热榜/最新/推荐）+ 右侧搜索框（同一水平行）
      Row({ space: 12 }) {
        // 三子 Tab（下划线指示器）
        Row({ space: 18 }) {
          ForEach(SUB_TABS, (name: string, idx: number) => {
            Column() {
              Text(name)
                .fontSize(16)
                .fontWeight(this.sortIndex === idx ? FontWeight.Bold : FontWeight.Medium)
                .fontColor(this.sortIndex === idx ? $r('app.color.text_primary') : $r('app.color.text_secondary'))
                .padding({ bottom: 6 })
              if (this.sortIndex === idx) {
                Divider().width(20).height(2).color($r('app.color.brand_primary'))
              }
            }
            .onClick(() => {
              if (this.sortIndex !== idx) {
                this.sortIndex = idx;
                this.refresh();
              }
            })
          }, (name: string) => name)
        }

        Blank()

        // 右侧搜索框
        Row({ space: 4 }) {
          Text('🔍')
            .fontSize(15)
            .fontColor($r('app.color.text_secondary'))
          TextInput({ placeholder: '搜索', text: this.searchKeyword })
            .width(118)
            .height(34)
            .backgroundColor($r('app.color.bg_secondary'))
            .borderRadius(17)
            .onChange((v: string) => {
              this.searchKeyword = v;
            })
            .onSubmit(() => {
              const kw = this.searchKeyword.trim();
              if (!kw) {
                promptAction.showToast({ message: '请输入搜索内容' });
                return;
              }
              AppStorage.setOrCreate('searchKeyword', kw);
              router.pushUrl({ url: 'pages/SearchResultPage' });
            })
        }
      }
      .alignItems(VerticalAlign.Center)
      .padding({ left: 16, right: 12, top: 12, bottom: 10 })
      .width('100%')

      // 标签筛选栏
      TagNav({
        tags: this.displayTags,
        selectedIndex: $tagIndex
      })
      .padding({ bottom: 8 })

      // 列表区
      if (this.posts.length === 0 && this.loading) {
        Column() {
          LoadingProgress().width(28).height(28)
          Text('加载中…').fontSize(13).fontColor($r('app.color.text_secondary')).margin({ top: 10 })
        }
        .layoutWeight(1)
        .width('100%')
        .justifyContent(FlexAlign.Center)
      } else if (this.posts.length === 0) {
        Column() {
          if (this.error) {
            Text('⚠️')
              .fontSize(36)
              .fontColor($r('app.color.text_secondary'))
              .margin({ bottom: 8 })
            Text('加载失败：' + this.error)
              .fontSize(14)
              .fontColor($r('app.color.text_secondary'))
              .margin({ top: 8 })
            Button('重试')
              .margin({ top: 16 })
              .onClick(() => {
                this.refresh();
              })
          } else {
            Text('暂无内容')
              .fontSize(14)
              .fontColor($r('app.color.text_secondary'))
          }
        }
        .layoutWeight(1)
        .width('100%')
        .justifyContent(FlexAlign.Center)
      } else {
        Refresh({ refreshing: this.isRefreshing, builder: this.refreshBuilder }) {
          Grid() {
            ForEach(
              this.posts,
              (post: Post) => {
                GridItem() {
                  PostCard({ post: post })
                    .onClick(() => {
                      if (post.id !== undefined) {
                        const id = post.id.toString();
                        AppStorage.setOrCreate('detailPostId', id);
                        setDetailPostId(id);
                        router.pushUrl({ url: 'pages/DetailPage' });
                      }
                    })
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
            if (end >= this.posts.length - 1) {
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
    .height('100%')
    .alignItems(HorizontalAlign.Start)
    .backgroundColor($r('app.color.bg_primary'))
  }
}
