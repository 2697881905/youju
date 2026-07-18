import { router } from '@kit.ArkUI';
import { Post, UserProfile } from '../models/types';
import { getUserProfile, followUser, unfollowUser, listPosts } from '../services/api';
import { PostCard } from '../components/PostCard';
import { safeShowToast } from '../utils/toast';
import { setDetailPostId } from '../utils/nav';

// 关注态局部补丁（乐观更新时只传要改的字段）
interface ProfileFollowPatch {
  isFollowing?: boolean;
  isMutual?: boolean;
}

@Entry
@Component
export struct UserProfilePage {
  @StorageLink('authToken') @Watch('onTokenReady') token: string = '';
  @State targetId: number = 0;
  @State profile: UserProfile = {
    id: 0, nickname: '', avatar: null, bio: null, gender: null,
    postCount: 0, followingCount: 0, followerCount: 0, isFollowing: false, isMutual: false,
  };
  @State posts: Post[] = [];
  @State page: number = 1;
  @State loading: boolean = false;
  @State finished: boolean = false;
  @State isRefreshing: boolean = false;
  @State error: string = '';
  @State ready: boolean = false;

  aboutToAppear(): void {
    this.resolveTarget();
    if (this.token !== '') {
      this.loadAll();
    }
  }

  onTokenReady(): void {
    if (this.token !== '' && this.targetId > 0 && !this.ready) {
      this.loadAll();
    }
  }

  private resolveTarget(): void {
    let raw: string | undefined = AppStorage.get<string>('targetUserId');
    if (!raw) {
      const params: Object | undefined = router.getParams();
      if (params !== undefined && typeof params === 'object') {
        const p: Record<string, Object> = params as Record<string, Object>;
        const v: Object | undefined = p['userId'];
        if (typeof v === 'string') {
          raw = v;
        }
      }
    }
    const id: number = Number(raw);
    if (!Number.isNaN(id) && id > 0) {
      this.targetId = id;
    }
  }

  async loadAll(): Promise<void> {
    this.ready = false;
    await this.loadProfile();
    await this.refresh();
    this.ready = true;
  }

  async loadProfile(): Promise<void> {
    try {
      this.profile = await getUserProfile(this.targetId);
    } catch (e) {
      // 失败不阻断帖子列表
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
    if (this.targetId === 0) {
      return;
    }
    this.loading = true;
    this.error = '';
    try {
      const res = await listPosts({ page: this.page, limit: 20, sort: 'latest', author: this.targetId });
      const list: Post[] = res.list;
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

  // 关注/取关（乐观更新，避免对象展开，用显式拷贝）
  private cloneProfile(next: ProfileFollowPatch): UserProfile {
    return {
      id: this.profile.id,
      nickname: this.profile.nickname,
      avatar: this.profile.avatar,
      bio: this.profile.bio,
      gender: this.profile.gender,
      postCount: this.profile.postCount,
      followingCount: this.profile.followingCount,
      followerCount: this.profile.followerCount,
      isFollowing: next.isFollowing !== undefined ? next.isFollowing : this.profile.isFollowing,
      isMutual: next.isMutual !== undefined ? next.isMutual : this.profile.isMutual,
    };
  }

  async onFollowClick(): Promise<void> {
    if (this.targetId === 0) {
      return;
    }
    if (!this.profile.isFollowing) {
      const prev: UserProfile = this.profile;
      this.profile = this.cloneProfile({ isFollowing: true });
      try {
        await followUser(this.targetId);
      } catch (e) {
        this.profile = prev;
        safeShowToast(this.getUIContext(), { message: (e as Error).message });
      }
    } else {
      this.getUIContext().showAlertDialog({
        title: '取消关注',
        message: '确定不再关注 ' + (this.profile.nickname !== '' ? this.profile.nickname : '') + ' 吗？',
        primaryButton: {
          value: '取消',
          action: (): void => {},
        },
        secondaryButton: {
          value: '取消关注',
          fontColor: '#FF453A',
          action: (): void => {
            this.doUnfollow();
          },
        },
      });
    }
  }

  async doUnfollow(): Promise<void> {
    const prev: UserProfile = this.profile;
    this.profile = this.cloneProfile({ isFollowing: false, isMutual: false });
    try {
      await unfollowUser(this.targetId);
    } catch (e) {
      this.profile = prev;
      safeShowToast(this.getUIContext(), { message: (e as Error).message });
    }
  }

  private goFollowList(mode: string): void {
    AppStorage.setOrCreate('targetUserId', String(this.targetId));
    AppStorage.setOrCreate('followMode', mode);
    router.pushUrl({ url: 'pages/MyFollowPage', params: { userId: String(this.targetId), mode: mode } });
  }

  private goDetail(post: Post): void {
    if (post.id !== undefined) {
      const pid: string = post.id.toString();
      AppStorage.setOrCreate('detailPostId', pid);
      setDetailPostId(pid);
      router.pushUrl({ url: 'pages/DetailPage' });
    }
  }

  @Builder
  statItem(count: string, label: string, mode: string): void {
    Column({ space: 2 }) {
      Text(count).fontSize(16).fontWeight(FontWeight.Bold).fontColor($r('app.color.text_primary'));
      Text(label).fontSize(12).fontColor($r('app.color.text_secondary'));
    }
    .onClick(() => {
      if (mode !== '') {
        this.goFollowList(mode);
      }
    });
  }

  private followBtnText(): string {
    if (!this.profile.isFollowing) {
      return '+ 关注';
    }
    if (this.profile.isMutual) {
      return '互相关注';
    }
    return '已关注';
  }

  @Builder
  refreshBuilder(): void {
    Row({ space: 8 }) {
      LoadingProgress().width(20).height(20);
      Text('刷新中…').fontSize(12).fontColor($r('app.color.text_secondary'));
    }
  }

  build() {
    Column() {
      // 顶栏
      Row() {
        Text('返回')
          .fontSize(16)
          .fontColor($r('app.color.text_primary'))
          .width(48)
          .onClick(() => {
            router.back();
          });
        Text(this.profile.nickname !== '' ? this.profile.nickname : '用户主页')
          .fontSize(17).fontWeight(600).layoutWeight(1).textAlign(TextAlign.Center);
        Text('').width(48);
      }
      .width('100%').padding({ top: 12, bottom: 8 });

      if (!this.ready) {
        Column() {
          LoadingProgress().width(28).height(28);
          Text('加载中…').fontSize(13).fontColor($r('app.color.text_secondary')).margin({ top: 10 });
        }
        .layoutWeight(1).width('100%').justifyContent(FlexAlign.Center);
      } else {
        // 信息卡
        Column({ space: 10 }) {
          Row({ space: 14 }) {
            if (this.profile.avatar) {
              Image(this.profile.avatar).width(64).height(64).borderRadius(32).objectFit(ImageFit.Cover);
            } else {
              Text((this.profile.nickname !== '' ? this.profile.nickname : '?').charAt(0))
                .width(64).height(64).borderRadius(32).fontSize(28).fontColor('#fff')
                .backgroundColor($r('app.color.brand_primary')).textAlign(TextAlign.Center);
            }
            Column({ space: 4 }) {
              Text(this.profile.nickname).fontSize(18).fontWeight(FontWeight.Medium).fontColor($r('app.color.text_primary'));
              if (this.profile.bio) {
                Text(this.profile.bio).fontSize(13).fontColor($r('app.color.text_secondary')).maxLines(2).textOverflow({ overflow: TextOverflow.Ellipsis });
              }
            }
            .alignItems(HorizontalAlign.Start).layoutWeight(1);
          }
          .width('100%').padding({ left: 16, right: 16 });

          // 三计数（关注/粉丝可点）
          Row({ space: 24 }) {
            this.statItem(String(this.profile.postCount), '帖子', '');
            this.statItem(String(this.profile.followingCount), '关注', 'following');
            this.statItem(String(this.profile.followerCount), '粉丝', 'followers');
          }
          .padding({ left: 16, bottom: 10 });

          // 关注按钮（三态）
          Button(this.followBtnText())
            .width(140).height(36).borderRadius(18)
            .backgroundColor(this.profile.isFollowing ? $r('app.color.card_bg') : $r('app.color.brand_primary'))
            .fontColor(this.profile.isFollowing ? $r('app.color.text_primary') : '#fff')
            .onClick(() => {
              this.onFollowClick();
            });
        }
        .alignItems(HorizontalAlign.Start);

        // 帖子网格
        if (this.posts.length === 0 && this.loading) {
          Column() {
            LoadingProgress().width(28).height(28);
            Text('加载中…').fontSize(13).fontColor($r('app.color.text_secondary')).margin({ top: 10 });
          }
          .layoutWeight(1).width('100%').justifyContent(FlexAlign.Center);
        } else if (this.posts.length === 0) {
          Column() {
            Text(this.error ? ('加载失败：' + this.error) : 'TA 还没有发布过帖子')
              .fontSize(14).fontColor($r('app.color.text_secondary'));
          }
          .layoutWeight(1).width('100%').justifyContent(FlexAlign.Center);
        } else {
          Refresh({ refreshing: this.isRefreshing, builder: this.refreshBuilder }) {
            Grid() {
              ForEach(this.posts, (post: Post) => {
                GridItem() {
                  PostCard({ post: post })
                    .onClick(() => {
                      this.goDetail(post);
                    });
                }
              }, (post: Post) => post.id !== undefined ? post.id.toString() : '');
              if (this.finished) {
                GridItem() {
                  Text('没有更多了')
                    .fontSize(12).fontColor($r('app.color.text_secondary'))
                    .width('100%').textAlign(TextAlign.Center).padding(16);
                }
                .columnStart(0).columnEnd(1);
              }
            }
            .columnsTemplate('1fr 1fr')
            .columnsGap(12).rowsGap(12).padding(12)
            .onScrollIndex((_start: number, end: number) => {
              if (end >= this.posts.length - 1) {
                this.loadMore();
              }
            });
          }
          .onRefreshing(() => {
            this.isRefreshing = true;
            this.refresh().finally(() => {
              this.isRefreshing = false;
            });
          })
          .layoutWeight(1).width('100%');
        }
      }
    }
    .width('100%').height('100%').backgroundColor($r('app.color.bg_primary'));
  }
}
