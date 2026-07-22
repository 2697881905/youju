// 个人主页（我的）：头像/昵称 + 关注/粉丝入口 + 我发布/我收藏 双 Tab + 帖子网格

import { Post, User, UserProfile } from '../models/types';
import { listPosts, listMyBookmarks, listMyLikedPosts, listMyCommentedPosts, getUserProfile, cancelBookmarkPost } from '../services/api';
import { PostCard } from '../components/PostCard';
import { ensureLogin, getCurrentUser } from '../utils/auth';
import { safeShowToast } from '../utils/toast';
import { setDetailPostId } from '../utils/nav';
import { observeGridColumns, gridColumnTemplate } from '../utils/responsive';
import { GRID_GAP, GRID_PADDING } from '../utils/cardTokens';
import { common } from '@kit.AbilityKit';

const SUB_TABS: string[] = ['我发布', '我收藏', '我赞过', '我评论'];

@Component
export struct ProfilePage {
  @State user: User = {};
  @State followingCount: number = 0;
  @State followerCount: number = 0;
  @State tabIdx: number = 0; // 0 我发布, 1 我收藏, 2 我赞过, 3 我评论
  @State posts: Post[] = [];
  @State page: number = 1;
  @State loading: boolean = false;
  @State finished: boolean = false;
  @State isRefreshing: boolean = false;
  @State error: string = '';
  @State ready: boolean = false;
  // 响应式列数（按屏幕宽度 2/3/4 列自适应）
  @State gridColumns: number = 2;
  @State gridTemplate: string = '1fr 1fr';
  private unregisterColumns: () => void = () => {};

  aboutToAppear(): void {
    this.unregisterColumns = observeGridColumns(
      this.getUIContext().getHostContext() as common.Context,
      (cols: number): void => {
        this.gridColumns = cols;
        this.gridTemplate = gridColumnTemplate(cols);
      }
    );
    this.init();
  }

  aboutToDisappear(): void {
    this.unregisterColumns();
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
    await this.fetchCounts();
    await this.refresh();
  }

  // 拉取关注/粉丝数 + 简介（写入本地状态，不阻断主列表）
  private async fetchCounts(): Promise<void> {
    const uid: number = this.user.id ?? 0;
    if (uid === 0) {
      return;
    }
    try {
      const p: UserProfile = await getUserProfile(uid);
      this.followingCount = p.followingCount;
      this.followerCount = p.followerCount;
      // 始终用后端最新数据覆盖本地缓存（昵称/头像/性别/简介）
      this.user = {
        id: this.user.id,
        nickname: p.nickname,
        avatar: p.avatar ?? undefined,
        gender: p.gender ?? undefined,
        bio: p.bio ?? this.user.bio,
        followTags: this.user.followTags,
      };
    } catch (e) {
      // 计数失败不影响主列表
    }
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
      } else if (this.tabIdx === 1) {
        const res = await listMyBookmarks(this.page, 20);
        list = res.list;
      } else if (this.tabIdx === 2) {
        const res = await listMyLikedPosts(this.page, 20);
        list = res.list;
      } else {
        const res = await listMyCommentedPosts(this.page, 20);
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

  // 跳关注/粉丝列表页
  private goFollow(mode: string): void {
    const uid: number = this.user.id ?? 0;
    if (uid === 0) {
      return;
    }
    AppStorage.setOrCreate('targetUserId', String(uid));
    AppStorage.setOrCreate('followMode', mode);
    this.getUIContext().getRouter().pushUrl({ url: 'pages/MyFollowPage', params: { userId: String(uid), mode: mode } });
  }

  onTabChange(idx: number): void {
    if (this.tabIdx === idx) {
      return;
    }
    this.tabIdx = idx;
    this.refresh();
  }

  // 收藏 Tab：取消收藏（乐观移除 + 失败回滚）
  private async handleCancelBookmark(id: number): Promise<void> {
    try {
      await cancelBookmarkPost(id);
      this.posts = this.posts.filter((p: Post) => p.id !== id);
    } catch (e) {
      safeShowToast(this.getUIContext(), { message: (e as Error).message });
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
      // 顶栏：设置 + 我的 + 占位
      Row() {
        Text('').width(48)
        Text('我的').fontSize(17).fontWeight(600).layoutWeight(1).textAlign(TextAlign.Center)
        Text('设置')
          .fontSize(16)
          .fontColor($r('app.color.text_secondary'))
          .width(48)
          .onClick(() => {
            this.getUIContext().getRouter().pushUrl({ url: 'pages/SettingsPage' });
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
          if (this.user.bio) {
            Text(this.user.bio)
              .fontSize(12).fontColor($r('app.color.text_secondary'))
              .maxLines(2).textOverflow({ overflow: TextOverflow.Ellipsis })
          }
          Text('ID: ' + String(this.user.id ?? '-'))
            .fontSize(12).fontColor($r('app.color.text_secondary'))
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)

        // 编辑资料入口（原设置页入口，移至此处头像/名称右侧）
        Button('编辑资料')
          .height(34)
          .padding({ left: 16, right: 16 })
          .borderRadius(17)
          .fontSize(13)
          .fontColor($r('app.color.brand_primary'))
          .backgroundColor($r('app.color.bg_secondary'))
          .onClick(() => {
            this.getUIContext().getRouter().pushUrl({ url: 'pages/EditProfilePage' });
          })
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 8, bottom: 8 })

      // 关注 / 粉丝入口
      Row({ space: 28 }) {
        Row({ space: 4 }) {
          Text(String(this.followingCount))
            .fontSize(15).fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.text_primary'));
          Text('关注').fontSize(13).fontColor($r('app.color.text_secondary'));
        }
        .onClick(() => {
          this.goFollow('following');
        })

        Row({ space: 4 }) {
          Text(String(this.followerCount))
            .fontSize(15).fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.text_primary'));
          Text('粉丝').fontSize(13).fontColor($r('app.color.text_secondary'));
        }
        .onClick(() => {
          this.goFollow('followers');
        })
      }
      .width('100%')
      .padding({ left: 16, right: 16, bottom: 12 })

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
          Text(this.error
            ? ('加载失败：' + this.error)
            : (this.tabIdx === 0
              ? '还没有发布过帖子'
              : this.tabIdx === 1
                ? '还没有收藏过帖子'
                : this.tabIdx === 2
                  ? '还没有赞过的帖子'
                  : '还没有评论过帖子'))
            .fontSize(14).fontColor($r('app.color.text_secondary'))
        }
        .layoutWeight(1).width('100%').justifyContent(FlexAlign.Center)
      } else {
        Refresh({ refreshing: this.isRefreshing, builder: this.refreshBuilder }) {
          Grid() {
            ForEach(this.posts, (post: Post) => {
              GridItem() {
                PostCard({
                  post: post,
                  // 仅「我收藏」Tab 传取消收藏回调；「我发布」Tab 不传（不显示取消入口）
                  onCancelBookmark: this.tabIdx === 1
                    ? (id: number): void => {
                        this.handleCancelBookmark(id);
                      }
                    : undefined,
                })
                  .onClick(() => {
                    if (post.id !== undefined) {
                      const id = post.id.toString();
                      AppStorage.setOrCreate('detailPostId', id);
                      setDetailPostId(id);
                      this.getUIContext().getRouter().pushUrl({ url: 'pages/DetailPage' });
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
              .columnStart(0).columnEnd(this.gridColumns - 1)
            }
          }
          .columnsTemplate(this.gridTemplate)
          .columnsGap(GRID_GAP).rowsGap(GRID_GAP).padding(GRID_PADDING)
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
