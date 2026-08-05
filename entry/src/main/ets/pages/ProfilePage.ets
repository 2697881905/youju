// 个人主页（我的）：头像/昵称 + 关注/粉丝入口 + 我发布/我收藏 双 Tab + 帖子网格

import { Post, User, UserProfile } from '../models/types';
import { listPosts, listMyBookmarks, listMyLikedPosts, listMyCommentedPosts, getUserProfile, cancelBookmarkPost, resolveDisplayImageUrl } from '../services/api';
import { PostCard } from '../components/PostCard';
import { ensureLogin, getCurrentUser } from '../utils/auth';
import { safeShowToast } from '../utils/toast';
import { openFollowList, openPostDetail } from '../utils/nav';
import { observeGridColumns, gridColumnTemplate } from '../utils/responsive';
import { barBottomReserve } from '../utils/cardTokens';
import { common } from '@kit.AbilityKit';
import { likeStore } from '../utils/likeStore';
import { resolveSettingsIcon } from '../utils/settingsIcons';
import { resolveActionIcon } from '../utils/actionIcons';
import { buildProfileShareText, buildProfileShareUrl, copyToClipboard } from '../utils/share';
import { PostCollectionState } from '../components/PostCollectionState';
import { ProfileShareSheet } from '../components/ProfileShareSheet';
import { SegmentedControl, SegmentedItem } from '../design/components/SegmentedControl';
import { ProfileHeader } from '../components/ProfileHeader';
import { Pressable } from '../design/motion/Pressable';
import { ColorTokens } from '../design/tokens/color';
import { IconTokens } from '../design/tokens/icon';
import { MotionCurves, MotionTokens } from '../design/tokens/motion';
import { RadiusTokens } from '../design/tokens/radius';
import { LayoutTokens, SpaceTokens } from '../design/tokens/space';
import { TypeTokens } from '../design/tokens/type';

const PROFILE_SEGMENTS: SegmentedItem[] = [
  { key: 'published', label: '我发布' },
  { key: 'bookmarks', label: '我收藏' },
  { key: 'liked', label: '我赞过' },
  { key: 'commented', label: '我评论' },
];

@Component
export struct ProfilePage {
  @State user: User = {};

  // 订阅登录态资料字段：编辑资料页 setSession 会写回 authNickname/avatar/bio/gender，
  // 此处 @Watch 即时触发把最新值同步到 this.user，规避 TabContent 内 router.back 不触发
  // onPageShow 导致的「改完名字/头像/简介主页不更新」。与 likeStore 订阅思路一致。
  @StorageLink('authNickname') @Watch('onProfileCacheChange') _syncNick: string = '';
  @StorageLink('authAvatar') @Watch('onProfileCacheChange') _syncAvatar: string = '';
  @StorageLink('authProfileBackground') @Watch('onProfileCacheChange') _syncProfileBackground: string = '';
  @StorageLink('authBio') @Watch('onProfileCacheChange') _syncBio: string = '';
  @StorageLink('authGender') @Watch('onProfileCacheChange') _syncGender: number = 0;
  // 订阅登录账号：切换账号（如老张↔小美互测）时重拉「我的」资料/计数/帖子，
  // 否则 TabContent 内组件被保留，残留上一个账号的关注/粉丝数、帖子列表。
  @StorageLink('authUserId') @Watch('onUserChange') uid: string = '';
  @State followingCount: number = 0;
  @State followerCount: number = 0;
  @State totalLikes: number = 0; // 获赞总数
  @State tabIdx: number = 0; // 0 我发布, 1 我收藏, 2 我赞过, 3 我评论
  @State posts: Post[] = [];
  @State page: number = 1;
  @State loading: boolean = false;
  @State finished: boolean = false;
  @State isRefreshing: boolean = false;
  @State error: string = '';
  @State ready: boolean = false;
  @State profilePresented: boolean = false;
  @StorageLink('reduceMotion') reduceMotion: boolean = false;
  @StorageLink('systemReduceMotion') systemReduceMotion: boolean = false;
  // 当前激活的底部 Tab（由 Index 经 AppStorage 广播），用于感知「我的」页是否可见，
  // 切到本页时重新拉取列表，使「我赞过/我收藏」在跨页点赞、取消收藏后即时刷新。
  @StorageLink('activeTab') @Watch('onActiveTab') activeTab: number = 0;
  @StorageLink('authToken') @Watch('onTokenReady') token: string = '';
  // 响应式列数（按屏幕宽度 2/3/4 列自适应）
  @State gridColumns: number = 2;
  @State gridTemplate: string = '1fr 1fr';
  private unregisterColumns: () => void = () => {};
  // 每次切换分段或刷新都推进版本号；延迟返回的旧请求不能覆盖当前分段的数据。
  private listVersion: number = 0;
  // 模拟器启动时后端端口转发可能尚未就绪，个人页列表失败后自动补拉一次。
  private retryTimer: number = 0;
  private profileEntranceTimer: number = 0;
  // 订阅全局点赞仓库：任意位置取消点赞后，「我赞过」列表即时移除该帖（不依赖切 Tab / onPageShow）
  private unsubLike: () => void = () => {};
  private profileShareController: CustomDialogController = new CustomDialogController({
    builder: ProfileShareSheet({
      getProfile: () => ({
        avatar: this.user.avatar ?? '',
        nickname: this.user.nickname ?? '大蓝书用户',
        bio: this.user.bio ?? '',
        followingCount: this.followingCount,
        followerCount: this.followerCount,
        likeCount: this.totalLikes,
        profileUrl: buildProfileShareUrl(this.user.id ?? 0),
      }),
      onCopyLink: (): void => { this.copyProfileLink(); },
      onCopyCardText: (): void => { this.copyProfileShareText(); },
    }),
    alignment: DialogAlignment.Bottom,
    customStyle: false,
    autoCancel: true,
  });

  aboutToAppear(): void {
    this.unregisterColumns = observeGridColumns(
      this.getUIContext().getHostContext() as common.Context,
      (cols: number): void => {
        this.gridColumns = cols;
        this.gridTemplate = gridColumnTemplate(cols);
      }
    );
    // TabContent 会提前创建隐藏页面，只在“我的”真正可见时校验登录和拉取数据。
    if (this.activeTab === 4) {
      this.init();
    }
    // 订阅全局点赞仓库：首页/详情页取消点赞后，若当前停在「我赞过」Tab，列表立即移除该帖。
    // 这覆盖了 router pop 返回（activeTab 不变、@Watch 不触发）与"期望立即同步"两类场景。
    this.unsubLike = likeStore.subscribe((changedId: number): void => {
      if (this.tabIdx === 2) {
        const info = likeStore.get(changedId);
        if (info && !info.liked) {
          this.posts = this.posts.filter((p: Post) => p.id !== changedId);
        }
      }
    });
  }

  aboutToDisappear(): void {
    this.unregisterColumns();
    this.unsubLike();
    if (this.retryTimer !== 0) {
      clearTimeout(this.retryTimer);
      this.retryTimer = 0;
    }
    if (this.profileEntranceTimer !== 0) {
      clearTimeout(this.profileEntranceTimer);
      this.profileEntranceTimer = 0;
    }
  }

  private shouldReduceMotion(): boolean {
    return this.reduceMotion || this.systemReduceMotion;
  }

  // 每次真正进入“我的”页后再揭示资料区，避免 TabContent 预创建时在后台消耗动效。
  private presentProfile(): void {
    this.profilePresented = false;
    if (this.profileEntranceTimer !== 0) {
      clearTimeout(this.profileEntranceTimer);
    }
    if (this.shouldReduceMotion()) {
      this.profilePresented = true;
      return;
    }
    this.profileEntranceTimer = setTimeout((): void => {
      this.getUIContext().animateTo({ duration: MotionTokens.page, curve: MotionCurves.emphasized }, () => {
        this.profilePresented = true;
      });
      this.profileEntranceTimer = 0;
    }, MotionTokens.instant) as number;
  }

  // 切回「我的」Tab 时，重新拉取当前子 Tab 的帖子列表：
  // 这样在首页/详情取消点赞后，进入「我赞过」会立即剔除该帖；收藏/评论计数也同步为最新。
  onActiveTab(): void {
    if (this.activeTab !== 4) {
      return;
    }
    if (!this.ready) {
      this.init();
    } else {
      this.refresh();
      this.presentProfile();
    }
  }

  onTokenReady(): void {
    if (this.token !== '' && this.activeTab === 4 && this.ready && this.posts.length === 0) {
      this.refresh();
    }
  }

  // 切换登录账号（登出/切换虚拟账号）→ 立即用新账号身份重拉资料与计数/帖子，
  // 避免 TabContent 内组件被保留导致「我的」页仍显示上一个账号的数据。
  onUserChange(): void {
    // 清空点赞缓存，避免切账号后「我赞过」/帖子点赞态残留上个账号
    likeStore.clear();
    const u: User | null = getCurrentUser();
    if (!u || !u.id) {
      return; // 登出态不拉取
    }
    this.user = {
      id: u.id,
      nickname: u.nickname,
      avatar: u.avatar,
      profileBackground: u.profileBackground,
      isAdmin: u.isAdmin,
      gender: u.gender,
      bio: u.bio,
      followTags: this.user.followTags,
    };
    if (this.ready) {
      this.fetchCounts();
      this.refresh();
    }
  }

  // 从编辑资料/设置等子页返回时，重新拉取最新用户资料（昵称/头像/简介/计数），
  // 否则 this.user 仍是进入子页前的旧快照，导致"改完名字头像主页不更新"。
  onPageShow(): void {
    const cached: User | null = getCurrentUser();
    if (cached && cached.id) {
      // 先用本机登录态立刻覆盖（避免闪烁），随后 fetchCounts 再用后端最新数据覆盖
      this.user = {
        id: cached.id,
        nickname: cached.nickname,
        avatar: cached.avatar,
        profileBackground: cached.profileBackground,
        isAdmin: cached.isAdmin,
        gender: cached.gender,
        bio: cached.bio,
        followTags: this.user.followTags,
      };
    }
    this.fetchCounts();
  }

  // 编辑资料返回：登录态资料字段变化即把最新昵称/头像/简介/性别同步到 this.user，
  // 使个人主页信息卡立即刷新（不依赖 onPageShow——TabContent 内 router.back 不触发 onPageShow）。
  private onProfileCacheChange(): void {
    const cached: User | null = getCurrentUser();
    if (cached && cached.id) {
      this.user = {
        id: this.user.id,
        nickname: cached.nickname,
        avatar: cached.avatar,
        profileBackground: cached.profileBackground,
        isAdmin: this.user.isAdmin,
        gender: cached.gender,
        bio: cached.bio,
        followTags: this.user.followTags,
      };
    }
  }

  async init(): Promise<void> {
    try {
      const u: User | null = await ensureLogin();
      if (!u) {
        // 无登录态：ensureLogin 已跳 LoginPage，本页不再加载
        this.ready = true;
        return;
      }
      this.user = u;
    } catch (e) {
      const cached: User | null = getCurrentUser();
      if (cached) {
        this.user = cached;
      }
    }
    this.ready = true;
    this.presentProfile();
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
      this.totalLikes = p.totalLikes;
      // 始终用后端最新数据覆盖本地缓存（昵称/头像/性别/简介）
      this.user = {
        id: this.user.id,
        nickname: p.nickname,
        avatar: p.avatar ?? undefined,
        profileBackground: p.profileBackground ?? undefined,
        gender: p.gender ?? undefined,
        bio: p.bio ?? this.user.bio,
        followTags: this.user.followTags,
      };
    } catch (e) {
      // 计数失败不影响主列表
    }
  }

  async refresh(): Promise<void> {
    const version: number = this.listVersion + 1;
    this.listVersion = version;
    this.page = 1;
    this.finished = false;
    this.error = '';
    // 先移除上一分段内容，避免请求期间显示错误的帖子集合。
    this.posts = [];
    await this.fetch(true, version);
  }

  async loadMore(): Promise<void> {
    if (this.finished || this.loading || this.isRefreshing) {
      return;
    }
    this.page += 1;
    await this.fetch(false, this.listVersion);
  }

  private async fetch(reset: boolean, version: number): Promise<void> {
    if (!reset && this.loading) {
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
      if (version !== this.listVersion) {
        return;
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
      if (version === this.listVersion) {
        this.error = (e as Error).message;
        const msg: string = this.error.toLowerCase();
        if ((msg.includes('connect') || msg.includes('refused') || msg.includes('network') || msg.includes('无法连接后端')) && this.retryTimer === 0) {
          this.retryTimer = setTimeout((): void => {
            this.retryTimer = 0;
            this.refresh();
          }, 1500) as number;
        }
      }
    } finally {
      if (version === this.listVersion) {
        this.loading = false;
      }
    }
  }

  // 跳关注/粉丝列表页
  private goFollow(mode: string): void {
    const uid: number = this.user.id ?? 0;
    if (uid === 0) {
      return;
    }
    openFollowList({ userId: uid, mode: mode === 'followers' ? 'followers' : 'following' });
    this.getUIContext().getRouter().pushUrl({ url: 'pages/MyFollowPage' });
  }

  private shareProfile(): void {
    if (!this.user.id) {
      safeShowToast(this.getUIContext(), { message: '主页信息加载中，请稍后重试' });
      return;
    }
    this.profileShareController.open();
  }

  private copyProfileLink(): void {
    try {
      copyToClipboard(buildProfileShareUrl(this.user.id ?? 0));
      safeShowToast(this.getUIContext(), { message: '主页链接已复制' });
    } catch (e) {
      safeShowToast(this.getUIContext(), { message: '复制失败，请重试' });
    }
    this.profileShareController.close();
  }

  private copyProfileShareText(): void {
    try {
      copyToClipboard(buildProfileShareText(this.user.nickname ?? '', this.user.id ?? 0));
      safeShowToast(this.getUIContext(), { message: '主页分享文案已复制' });
    } catch (e) {
      safeShowToast(this.getUIContext(), { message: '复制失败，请重试' });
    }
    this.profileShareController.close();
  }

  onTabChange(idx: number): void {
    // SegmentedControl 会先写入双向绑定的 tabIdx，再触发 onSelect。
    // 因此不能把“索引相同”当作无需刷新，否则只会切换选中态而继续显示旧分段数据。
    if (this.tabIdx !== idx) {
      this.tabIdx = idx;
    }
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
    Row({ space: SpaceTokens.inline }) {
      LoadingProgress().width(IconTokens.compact).height(IconTokens.compact)
      Text('刷新中…')
        .fontSize(TypeTokens.caption.size).fontFamily(TypeTokens.fontFamily)
        .fontWeight(TypeTokens.caption.weight)
        .lineHeight(TypeTokens.caption.lineHeight)
        .letterSpacing(TypeTokens.caption.tracking)
        .fontColor(ColorTokens.secondary)
    }
  }

  // 瀑布流 footer 与内容列解耦，避免末尾提示占用某一列的卡片位置。
  @Builder
  postFooter(): void {
    if (this.finished) {
      Text('没有更多了')
        .fontSize(TypeTokens.caption.size).fontFamily(TypeTokens.fontFamily)
        .fontWeight(TypeTokens.caption.weight)
        .lineHeight(TypeTokens.caption.lineHeight)
        .letterSpacing(TypeTokens.caption.tracking)
        .fontColor(ColorTokens.tertiary)
        .width('100%')
        .textAlign(TextAlign.Center)
        .padding(SpaceTokens.base)
    }
    // 使用真实 footer 占位，而不是依赖 WaterFlow padding，确保 Refresh 嵌套时
    // 最后一张卡片仍可滚动到悬浮底栏上方。
    Column() {
      Blank()
        .width('100%')
        .height(barBottomReserve())
    }
    .width('100%')
  }

  @Builder
  profilePostCard(post: Post): void {
    PostCard({
      post: post,
      compact: true,
      onOpen: () => {
        if (post.id !== undefined) {
          const id = post.id.toString();
          openPostDetail(id);
          this.getUIContext().getRouter().pushUrl({ url: 'pages/DetailPage' });
        }
      },
      onCancelBookmark: this.tabIdx === 1
        ? (id: number): void => { this.handleCancelBookmark(id); }
        : undefined,
    })
  }

  @Builder
  profileHeader(onBackground: boolean): void {
    ProfileHeader({
      avatar: this.user.avatar ?? '',
      name: this.user.nickname ?? '未登录',
      gender: this.user.gender ?? 0,
      bio: this.user.bio ?? '',
      userId: this.user.id ?? 0,
      followingCount: this.followingCount,
      followerCount: this.followerCount,
      totalLikes: this.totalLikes,
      onBackground: onBackground,
      onOpenFollowing: (): void => { this.goFollow('following'); },
      onOpenFollowers: (): void => { this.goFollow('followers'); },
      onEdit: (): void => { this.getUIContext().getRouter().pushUrl({ url: 'pages/EditProfilePage' }); },
      onOpenDrafts: (): void => { this.getUIContext().getRouter().pushUrl({ url: 'pages/DraftBoxPage' }); },
    })
  }

  build() {
    Column() {
      // 顶栏
      Row({ space: SpaceTokens.sm }) {
        Text('我的')
          .fontSize(TypeTokens.title.size).fontFamily(TypeTokens.fontFamily)
          .fontWeight(TypeTokens.title.weight)
          .lineHeight(TypeTokens.title.lineHeight)
          .letterSpacing(TypeTokens.title.tracking)
          .fontColor(ColorTokens.primary)
        Blank()
        Pressable({
          visualHeight: LayoutTokens.segmentedHeight,
          touchTargetHeight: LayoutTokens.minTouchTarget,
          action: (): void => { this.shareProfile(); },
        }) {
          Row() {
            Image(resolveActionIcon('share'))
              .width(IconTokens.small)
              .height(IconTokens.small)
          }
          .width(LayoutTokens.segmentedHeight)
          .height(LayoutTokens.segmentedHeight)
          .justifyContent(FlexAlign.Center)
          .backgroundColor(ColorTokens.barSurface)
          .backdropBlur(LayoutTokens.glassBlur)
          .border({ width: LayoutTokens.glassBorderWidth, color: ColorTokens.barBorder, style: BorderStyle.Solid })
          .borderRadius(RadiusTokens.lg)
          .shadow({ radius: 10, color: ColorTokens.barShadow, offsetY: 4 })
          .accessibilityText('分享主页')
        }
        Pressable({
          visualHeight: LayoutTokens.segmentedHeight,
          touchTargetHeight: LayoutTokens.minTouchTarget,
          action: (): void => {
            this.getUIContext().getRouter().pushUrl({ url: 'pages/SettingsPage' });
          },
        }) {
          Row() {
            Image(resolveSettingsIcon('gear'))
              .width(IconTokens.small)
              .height(IconTokens.small)
          }
          .width(LayoutTokens.segmentedHeight)
          .height(LayoutTokens.segmentedHeight)
          .justifyContent(FlexAlign.Center)
          .backgroundColor(ColorTokens.barSurface)
          .backdropBlur(LayoutTokens.glassBlur)
          .border({ width: LayoutTokens.glassBorderWidth, color: ColorTokens.barBorder, style: BorderStyle.Solid })
          .borderRadius(RadiusTokens.lg)
          .shadow({ radius: 10, color: ColorTokens.barShadow, offsetY: 4 })
          .accessibilityText('设置')
        }
      }
      .width('100%')
      .padding({
        left: SpaceTokens.sm,
        right: SpaceTokens.sm,
        top: SpaceTokens.xs,
        bottom: SpaceTokens.xs,
      })

      // 有背景图时，资料内容叠加在 16:10 图片之上；没有时维持紧凑布局。
      Column() {
      if (this.user.profileBackground) {
        Column() {
          Stack() {
            Image(resolveDisplayImageUrl(this.user.profileBackground))
              .width('100%')
              .height('100%')
              .objectFit(ImageFit.Cover);
            Column() {
              this.profileHeader(true);
            }
            .width('100%')
            .height('100%')
            .justifyContent(FlexAlign.End)
            .backgroundColor('#52000000');
          }
          .width('100%')
          .aspectRatio(16 / 10)
          .borderRadius(RadiusTokens.lg)
          .clip(true);
        }
        .width('100%')
        .padding({ left: SpaceTokens.sm, right: SpaceTokens.sm, top: SpaceTokens.xs, bottom: SpaceTokens.xs });
      } else {
        Column() {
          this.profileHeader(false);
        }
        .width('100%');
      }
      }
      .width('100%')
      .opacity(this.shouldReduceMotion() || this.profilePresented ? 1 : 0)
      .translate({ y: this.shouldReduceMotion() || this.profilePresented ? 0 : SpaceTokens.xl })
      .scale({
        x: this.shouldReduceMotion() || this.profilePresented ? 1 : MotionTokens.enterScale,
        y: this.shouldReduceMotion() || this.profilePresented ? 1 : MotionTokens.enterScale,
      })
      .animation({
        duration: this.shouldReduceMotion() ? MotionTokens.instant : MotionTokens.page,
        curve: MotionCurves.emphasized,
      })

      // 列表区与分段栏共享同一滚动空间，帖子上滑时可进入分段栏下方。
      Stack({ alignContent: Alignment.TopStart }) {
      if (!this.ready || (this.posts.length === 0 && this.loading)) {
        PostCollectionState({ loading: true })
      } else if (this.posts.length === 0) {
        PostCollectionState({
          error: this.error,
          emptyTitle: this.tabIdx === 0
            ? '还没有发布过帖子'
            : this.tabIdx === 1
              ? '还没有收藏过帖子'
              : this.tabIdx === 2 ? '还没有赞过的帖子' : '还没有评论过帖子',
          onRetry: (): void => { this.refresh(); },
        })
      } else {
        Refresh({ refreshing: this.isRefreshing, builder: this.refreshBuilder }) {
          // 显式双列：偶数项固定左列、奇数项固定右列，首项始终位于左上角。
          // 两列独立排列，保留瀑布流的紧凑效果且不受 WaterFlow 列测量顺序影响。
          Scroll() {
            Column() {
              Row({ space: SpaceTokens.xs }) {
                Column({ space: SpaceTokens.xs }) {
                  ForEach(this.posts.filter((_post: Post, idx: number) => idx % 2 === 0), (post: Post) => {
                    this.profilePostCard(post)
                  }, (post: Post) => this.tabIdx + '-left-' + (post.id ?? ''))
                }
                .layoutWeight(1)
                Column({ space: SpaceTokens.xs }) {
                  ForEach(this.posts.filter((_post: Post, idx: number) => idx % 2 === 1), (post: Post) => {
                    this.profilePostCard(post)
                  }, (post: Post) => this.tabIdx + '-right-' + (post.id ?? ''))
                }
                .layoutWeight(1)
              }
              .width('100%')
              .alignItems(VerticalAlign.Top)
              Column() {
                Blank().width('100%').height(barBottomReserve())
              }
              .width('100%')
            }
            .width('100%')
            .padding({
              left: SpaceTokens.sm,
              right: SpaceTokens.sm,
              top: LayoutTokens.segmentedHeight + SpaceTokens.md,
              bottom: SpaceTokens.md,
            })
          }
          .scrollable(ScrollDirection.Vertical)
          .onScrollEdge((edge: Edge) => {
            if (edge === Edge.Bottom) {
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
        .width('100%').height('100%')
      }
      SegmentedControl({
        items: PROFILE_SEGMENTS,
        selectedIndex: $tabIdx,
        itemWidth: 67,
        glass: true,
        onSelect: (idx: number): void => { this.onTabChange(idx); },
      })
      .margin({
        left: SpaceTokens.sm,
        right: SpaceTokens.sm,
        top: SpaceTokens.xs,
      })
      .zIndex(1)
      }
      .layoutWeight(1)
      .width('100%')
    }
    .width('100%').height('100%')
    .backgroundColor(ColorTokens.canvas)
  }
}
