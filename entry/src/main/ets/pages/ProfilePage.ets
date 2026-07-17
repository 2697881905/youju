// 个人主页（我的）：头像/昵称 + 我发布/我收藏 双 Tab + 帖子网格
import { router, promptAction } from '@kit.ArkUI';
import { Post, User } from '../models/types';
import { listPosts, listMyBookmarks } from '../services/api';
import { PostCard } from '../components/PostCard';
import { ensureLogin, getCurrentUser } from '../utils/auth';
import { setDetailPostId } from '../utils/nav';

const SUB_TABS: string[] = ['我发布', '我收藏'];

@Component
export struct ProfilePage {
  @State user: User = {};
  @State tabIdx: number = 0; // 0 我发布, 1 我收藏
  @State posts: Post[] = [];
  @State page: number = 1;
  @State loading: boolean = false;
  @State finished: boolean = false;
  @State isRefreshing: boolean = false;
  @State error: string = '';
  @State ready: boolean = false;

  aboutToAppear(): void {
    this.init();
  }

  async init(): Promise<void> {
    try {
      const u: User = await ensureLogin();
      this.user = u;
    } catch (e) {
      const cached: User | null = getCurrentUser();
      if (cached) {
        this.user = cached;
      }
    }
    this.ready = true;
    await this.refresh();
  }

  async refresh(): Promise<void> {
    this.page = 1;
    this.finished = false;
    await this.fetch(true);
  }

  async loadMore(): Promise<void> {
    if (this.finished || this.loading || this.isRefreshing) {
      return;
    }
    this.page += 1;
    await this.fetch(false);
  }

  private async fetch(reset: boolean): Promise<void> {
    if (this.loading) {
      return;
    }
    const uid: number = this.user.id ?? 0;
    if (uid === 0) {
      return;
    }
    this.loading = true;
    this.error = '';
    let list: Post[] = [];
    try {
      if (this.tabIdx === 0) {
        const res = await listPosts({ page: this.page, limit: 20, sort: 'latest', author: uid });
        list = res.list;
      } else {
        const res = await listMyBookmarks(this.page, 20);
        list = res.list;
      }
      if (reset) {
        this.posts = list;
      } else {
        this.posts = this.posts.concat(list);
      }
      if (list.length < 20) {
        this.finished = true;
      }
    } catch (e) {
      this.error = (e as Error).message;
    } finally {
      this.loading = false;
    }
  }

  onTabChange(idx: number): void {
    if (this.tabIdx === idx) {
      return;
    }
    this.tabIdx = idx;
    this.refresh();
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
      // 顶栏：设置 + 我的 + 占位
      Row() {
        Text('').width(48)
        Text('我的').fontSize(17).fontWeight(600).layoutWeight(1).textAlign(TextAlign.Center)
        Text('设置')
          .fontSize(16)
          .fontColor($r('app.color.text_secondary'))
          .width(48)
          .onClick(() => {
            promptAction.showToast({ message: '设置功能开发中' });
          })
      }
      .width('100%')
      .padding({ top: 12, bottom: 8 })

      // 用户信息卡
      Row({ space: 14 }) {
        if (this.user.avatar) {
          Image(this.user.avatar)
            .width(64).height(64).borderRadius(32)
            .objectFit(ImageFit.Cover)
        } else {
          Text((this.user.nickname ?? '我').charAt(0))
            .width(64).height(64).borderRadius(32)
            .fontSize(28).fontColor('#fff')
            .backgroundColor($r('app.color.brand_primary'))
            .textAlign(TextAlign.Center)
        }
        Column({ space: 4 }) {
          Text(this.user.nickname ?? '未登录')
            .fontSize(18).fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.text_primary'))
          Text('ID: ' + String(this.user.id ?? '-'))
            .fontSize(12).fontColor($r('app.color.text_secondary'))
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 8, bottom: 16 })

      // 子 Tab（我发布 / 我收藏）
      Row({ space: 24 }) {
        ForEach(SUB_TABS, (name: string, idx: number) => {
          Column() {
            Text(name)
              .fontSize(16)
              .fontWeight(this.tabIdx === idx ? FontWeight.Bold : FontWeight.Medium)
              .fontColor(this.tabIdx === idx ? $r('app.color.text_primary') : $r('app.color.text_secondary'))
              .padding({ bottom: 6 })
            if (this.tabIdx === idx) {
              Divider().width(20).height(2).color($r('app.color.brand_primary'))
            }
          }
          .onClick(() => {
            this.onTabChange(idx);
          })
        }, (name: string) => name)
      }
      .padding({ left: 16, bottom: 10 })

      // 列表区
      if (!this.ready || (this.posts.length === 0 && this.loading)) {
        Column() {
          LoadingProgress().width(28).height(28)
          Text('加载中…').fontSize(13).fontColor($r('app.color.text_secondary')).margin({ top: 10 })
        }
        .layoutWeight(1).width('100%').justifyContent(FlexAlign.Center)
      } else if (this.posts.length === 0) {
        Column() {
          Text(this.error ? ('加载失败：' + this.error) : (this.tabIdx === 0 ? '还没有发布过帖子' : '还没有收藏过帖子'))
            .fontSize(14).fontColor($r('app.color.text_secondary'))
        }
        .layoutWeight(1).width('100%').justifyContent(FlexAlign.Center)
      } else {
        Refresh({ refreshing: this.isRefreshing, builder: this.refreshBuilder }) {
          Grid() {
            ForEach(this.posts, (post: Post) => {
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
            }, (post: Post) => post.id?.toString() ?? '')
            if (this.finished) {
              GridItem() {
                Text('没有更多了')
                  .fontSize(12).fontColor($r('app.color.text_secondary'))
                  .width('100%').textAlign(TextAlign.Center).padding(16)
              }
              .columnStart(0).columnEnd(1)
            }
          }
          .columnsTemplate('1fr 1fr')
          .columnsGap(12).rowsGap(12).padding(12)
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
        .layoutWeight(1).width('100%')
      }
    }
    .width('100%').height('100%')
    .backgroundColor($r('app.color.bg_primary'))
  }
}
