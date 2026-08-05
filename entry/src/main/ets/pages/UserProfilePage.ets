
import { Post, UserProfile } from '../models/types';
import { getUserProfile, followUser, unfollowUser, listPosts, resolveDisplayImageUrl, blockUser, unblockUser, dislikeUser, undislikeUser } from '../services/api';
import { getUserId } from '../utils/auth';
import { PostCard } from '../components/PostCard';
import { ProfileIdentity } from '../components/ProfileIdentity';
import { ProfileStatItem } from '../components/ProfileStatItem';
import { Pressable } from '../design/motion/Pressable';
import { safeShowToast } from '../utils/toast';
import { openChat, openFollowList, openPostDetail, takeUserProfileId } from '../utils/nav';
import { buildPageTransition } from '../utils/styles';
import { ColorTokens } from '../design/tokens/color';
import { LayoutTokens, SpaceTokens } from '../design/tokens/space';
import { RadiusTokens } from '../design/tokens/radius';
import { MotionCurves, MotionTokens } from '../design/tokens/motion';
import { TypeTokens } from '../design/tokens/type';
import { BackButton } from '../design/components/BackButton';
import { PostCollectionState } from '../components/PostCollectionState';

// 关注态局部补丁（乐观更新时只传要改的字段）
interface ProfileFollowPatch {
  isFollowing?: boolean;
  isMutual?: boolean;
  isBlocked?: boolean;
  isDisliked?: boolean;
}

@Entry
@Component
export struct UserProfilePage {
  @StorageLink('authToken') @Watch('onTokenReady') token: string = '';
  @State targetId: number = 0;
  @State profile: UserProfile = {
    id: 0, nickname: '', avatar: null, profileBackground: null, bio: null, gender: null,
    postCount: 0, followingCount: 0, followerCount: 0, totalLikes: 0, isFollowing: false, isMutual: false,
    isBlocked: false, isDisliked: false,
  };
  @State posts: Post[] = [];
  @State page: number = 1;
  @State loading: boolean = false;
  @State finished: boolean = false;
  @State isRefreshing: boolean = false;
  @State error: string = '';
  @State ready: boolean = false;
  @State profilePresented: boolean = false;
  @State followPending: boolean = false;
  @State followPulse: boolean = false;
  @StorageLink('statusBarHeight') statusBarHeight: number = 0;
  @StorageLink('reduceMotion') reduceMotion: boolean = false;
  @StorageLink('systemReduceMotion') systemReduceMotion: boolean = false;
  private profileEntranceTimer: number = 0;
  private followPulseTimer: number = 0;

  aboutToAppear(): void {
    this.resolveTarget();
    if (this.token !== '') {
      this.loadAll();
    }
  }

  aboutToDisappear(): void {
    if (this.profileEntranceTimer !== 0) {
      clearTimeout(this.profileEntranceTimer);
      this.profileEntranceTimer = 0;
    }
    if (this.followPulseTimer !== 0) {
      clearTimeout(this.followPulseTimer);
      this.followPulseTimer = 0;
    }
  }

  private shouldReduceMotion(): boolean {
    return this.reduceMotion || this.systemReduceMotion;
  }

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

  private playFollowConfirmation(): void {
    if (this.shouldReduceMotion()) {
      return;
    }
    if (this.followPulseTimer !== 0) {
      clearTimeout(this.followPulseTimer);
    }
    this.followPulse = true;
    this.followPulseTimer = setTimeout((): void => {
      this.followPulse = false;
      this.followPulseTimer = 0;
    }, MotionTokens.emphasis) as number;
  }

  onTokenReady(): void {
    if (this.token !== '' && this.targetId > 0 && !this.ready) {
      this.loadAll();
    }
  }

  private resolveTarget(): void {
    const id: number = takeUserProfileId();
    if (id > 0) {
      this.targetId = id;
    }
  }

  async loadAll(): Promise<void> {
    this.profilePresented = false;
    this.ready = false;
    await this.loadProfile();
    await this.refresh();
    this.ready = true;
    this.presentProfile();
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
      profileBackground: this.profile.profileBackground,
      bio: this.profile.bio,
      gender: this.profile.gender,
      postCount: this.profile.postCount,
      followingCount: this.profile.followingCount,
      followerCount: this.profile.followerCount,
      totalLikes: this.profile.totalLikes,
      isFollowing: next.isFollowing !== undefined ? next.isFollowing : this.profile.isFollowing,
      isMutual: next.isMutual !== undefined ? next.isMutual : this.profile.isMutual,
      isBlocked: next.isBlocked !== undefined ? next.isBlocked : this.profile.isBlocked,
      isDisliked: next.isDisliked !== undefined ? next.isDisliked : this.profile.isDisliked,
    };
  }

  async onFollowClick(): Promise<void> {
    if (this.targetId === 0 || this.followPending) {
      return;
    }
    if (!this.profile.isFollowing) {
      const prev: UserProfile = this.profile;
      this.profile = this.cloneProfile({ isFollowing: true });
      this.followPending = true;
      try {
        await followUser(this.targetId);
        this.playFollowConfirmation();
      } catch (e) {
        this.profile = prev;
        safeShowToast(this.getUIContext(), { message: (e as Error).message });
      } finally {
        this.followPending = false;
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
          fontColor: $r('app.color.semantic_red'),
          action: (): void => {
            this.doUnfollow();
          },
        },
      });
    }
  }

  async doUnfollow(): Promise<void> {
    if (this.followPending) {
      return;
    }
    const prev: UserProfile = this.profile;
    this.profile = this.cloneProfile({ isFollowing: false, isMutual: false });
    this.followPending = true;
    try {
      await unfollowUser(this.targetId);
      this.playFollowConfirmation();
    } catch (e) {
      this.profile = prev;
      safeShowToast(this.getUIContext(), { message: (e as Error).message });
    } finally {
      this.followPending = false;
    }
  }

  private goFollowList(mode: string): void {
    openFollowList({ userId: this.targetId, mode: mode === 'followers' ? 'followers' : 'following' });
    this.getUIContext().getRouter().pushUrl({ url: 'pages/MyFollowPage' });
  }

  private goDetail(post: Post): void {
    if (post.id !== undefined) {
      const pid: string = post.id.toString();
      openPostDetail(pid);
      this.getUIContext().getRouter().pushUrl({ url: 'pages/DetailPage' });
    }
  }

  @Builder
  statItem(count: string, label: string, mode: string, onBackground: boolean = false): void {
    ProfileStatItem({
      value: Number(count),
      label: label,
      onBackground: onBackground,
      clickable: mode.length > 0,
      onOpen: (): void => { this.goFollowList(mode); },
    })
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

  // 是否本人的主页（本人不显示关注/私信按钮）
  private isSelf(): boolean {
    return this.targetId === getUserId();
  }

  // 发起私信：使用短暂导航意图传递对端信息，跳转聊天页。
  // 服务端会按对方 dmPolicy + 拉黑做权限校验，越权时聊天页发送阶段报错提示
  private onMessageClick(): void {
    if (this.targetId === 0) {
      return;
    }
    openChat({
      peerId: this.targetId,
      peerName: this.profile.nickname !== '' ? this.profile.nickname : '用户',
      peerAvatar: this.profile.avatar ?? '',
    });
    this.getUIContext().getRouter().pushUrl({ url: 'pages/ChatPage' });
  }

  // ===== 拉黑 / 不喜欢（减少推送）=====
  // 拉黑 toggle：已拉黑 → 直接取消；未拉黑 → 二次确认后执行
  private onBlockClick(): void {
    if (this.targetId === 0 || this.isSelf()) {
      return;
    }
    if (this.profile.isBlocked === true) {
      this.doUnblock();
    } else {
      this.getUIContext().showAlertDialog({
        title: '拉黑用户',
        message: '拉黑后，你和对方将互相看不到彼此的内容。确定要拉黑 ' + (this.profile.nickname !== '' ? this.profile.nickname : '') + ' 吗？',
        primaryButton: {
          value: '取消',
          action: (): void => {},
        },
        secondaryButton: {
          value: '拉黑',
          fontColor: $r('app.color.semantic_red'),
          action: (): void => {
            this.doBlock();
          },
        },
      });
    }
  }

  private async doBlock(): Promise<void> {
    const prev: UserProfile = this.profile;
    this.profile = this.cloneProfile({ isBlocked: true });
    try {
      await blockUser(this.targetId);
      safeShowToast(this.getUIContext(), { message: '已拉黑' });
    } catch (e) {
      this.profile = prev;
      safeShowToast(this.getUIContext(), { message: (e as Error).message });
    }
  }

  private async doUnblock(): Promise<void> {
    const prev: UserProfile = this.profile;
    this.profile = this.cloneProfile({ isBlocked: false });
    try {
      await unblockUser(this.targetId);
      safeShowToast(this.getUIContext(), { message: '已取消拉黑' });
    } catch (e) {
      this.profile = prev;
      safeShowToast(this.getUIContext(), { message: (e as Error).message });
    }
  }

  // 不喜欢 toggle：直接切换（影响较小，无需二次确认）
  private onDislikeClick(): void {
    if (this.targetId === 0 || this.isSelf()) {
      return;
    }
    if (this.profile.isDisliked === true) {
      this.doUndislike();
    } else {
      this.doDislike();
    }
  }

  private async doDislike(): Promise<void> {
    const prev: UserProfile = this.profile;
    this.profile = this.cloneProfile({ isDisliked: true });
    try {
      await dislikeUser(this.targetId);
      safeShowToast(this.getUIContext(), { message: '已减少推送' });
    } catch (e) {
      this.profile = prev;
      safeShowToast(this.getUIContext(), { message: (e as Error).message });
    }
  }

  private async doUndislike(): Promise<void> {
    const prev: UserProfile = this.profile;
    this.profile = this.cloneProfile({ isDisliked: false });
    try {
      await undislikeUser(this.targetId);
      safeShowToast(this.getUIContext(), { message: '已取消' });
    } catch (e) {
      this.profile = prev;
      safeShowToast(this.getUIContext(), { message: (e as Error).message });
    }
  }

  @Builder
  profileInformation(onBackground: boolean): void {
    Column() {
      ProfileIdentity({
        avatar: this.profile.avatar ?? '',
        name: this.profile.nickname,
        gender: this.profile.gender ?? 0,
        bio: this.profile.bio ?? '',
        userId: this.profile.id,
        deleted: this.profile.deleted === true,
        onBackground: onBackground,
      })

      Row({ space: SpaceTokens.sm }) {
        if (this.profile.deleted) {
          this.statItem('0', '关注', '', onBackground);
          this.statItem('0', '粉丝', '', onBackground);
          this.statItem('0', '获赞', '', onBackground);
        } else {
          this.statItem(String(this.profile.followingCount), '关注', 'following', onBackground);
          this.statItem(String(this.profile.followerCount), '粉丝', 'followers', onBackground);
          this.statItem(String(this.profile.totalLikes), '获赞', '', onBackground);
        }
      }
      .width('100%')
      .padding({ left: SpaceTokens.sm, right: SpaceTokens.sm, bottom: SpaceTokens.sm });

      if (!this.profile.deleted && !this.isSelf()) {
        Row({ space: SpaceTokens.sm }) {
          Column() {
          Pressable({
            disabled: this.followPending,
            fillWidth: true,
            visualHeight: LayoutTokens.segmentedHeight,
            touchTargetHeight: LayoutTokens.minTouchTarget,
            action: (): void => { this.onFollowClick(); },
          }) {
            Text(this.followPending ? '处理中' : this.followBtnText())
              .width('100%')
              .height(LayoutTokens.segmentedHeight)
              .textAlign(TextAlign.Center)
              .fontSize(TypeTokens.callout.size).fontFamily(TypeTokens.fontFamily)
              .fontWeight(TypeTokens.headline.weight)
              .fontColor(this.profile.isFollowing ? ColorTokens.secondary : ColorTokens.primary)
              .backgroundColor(ColorTokens.barSurface)
              .backdropBlur(LayoutTokens.glassBlur)
              .border({ width: LayoutTokens.glassBorderWidth, color: ColorTokens.barBorder, style: BorderStyle.Solid })
              .borderRadius(RadiusTokens.floatingBar)
              .shadow({ radius: 12, color: ColorTokens.barShadow, offsetY: 4 })
              .scale({ x: this.followPulse ? MotionTokens.successScale : 1, y: this.followPulse ? MotionTokens.successScale : 1 })
              .animation({ duration: this.shouldReduceMotion() ? MotionTokens.instant : MotionTokens.emphasis, curve: MotionCurves.springSoft });
          }
          }
          .layoutWeight(1)
          Column() {
          Pressable({
            fillWidth: true,
            visualHeight: LayoutTokens.segmentedHeight,
            touchTargetHeight: LayoutTokens.minTouchTarget,
            action: (): void => { this.onMessageClick(); },
          }) {
            Text('私信')
              .width('100%')
              .height(LayoutTokens.segmentedHeight)
              .textAlign(TextAlign.Center)
              .fontSize(TypeTokens.callout.size).fontFamily(TypeTokens.fontFamily)
              .fontWeight(TypeTokens.headline.weight)
              .fontColor(ColorTokens.primary)
              .backgroundColor(ColorTokens.barSurface)
              .backdropBlur(LayoutTokens.glassBlur)
              .border({ width: LayoutTokens.glassBorderWidth, color: ColorTokens.barBorder, style: BorderStyle.Solid })
              .borderRadius(RadiusTokens.floatingBar)
              .shadow({ radius: 12, color: ColorTokens.barShadow, offsetY: 4 });
          }
          }
          .layoutWeight(1)
        }
        .width('100%')
        .padding({ left: SpaceTokens.sm, right: SpaceTokens.sm, bottom: SpaceTokens.xs });
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .opacity(this.shouldReduceMotion() || this.profilePresented ? 1 : 0)
    .translate({ y: this.shouldReduceMotion() || this.profilePresented ? 0 : SpaceTokens.xl })
    .scale({
      x: this.shouldReduceMotion() || this.profilePresented ? 1 : MotionTokens.enterScale,
      y: this.shouldReduceMotion() || this.profilePresented ? 1 : MotionTokens.enterScale,
    })
    .animation({
      duration: this.shouldReduceMotion() ? MotionTokens.instant : MotionTokens.page,
      curve: MotionCurves.emphasized,
    });
  }

  @Builder
  refreshBuilder(): void {
    Row({ space: 8 }) {
      LoadingProgress().width(20).height(20);
      Text('刷新中…').fontSize(12).fontFamily($r('app.string.font_family')).fontColor($r('app.color.text_secondary'));
    }
  }

  build() {
    Column() {
      // 顶栏
      Row() {
        BackButton({ action: (): void => { this.getUIContext().getRouter().back(); } })
        Text(this.profile.deleted ? '已注销用户' : (this.profile.nickname !== '' ? this.profile.nickname : '用户主页'))
          .fontSize(17).fontFamily($r('app.string.font_family')).fontWeight(600).layoutWeight(1).textAlign(TextAlign.Center);
        if (!this.profile.deleted && !this.isSelf()) {
          Text('⋯')
            .width(44).height(44).textAlign(TextAlign.Center).fontSize(22)
            .fontColor($r('app.color.text_primary'))
            .bindMenu([
              { value: this.profile.isBlocked === true ? '取消拉黑' : '拉黑该作者', action: (): void => { this.onBlockClick(); } },
              { value: this.profile.isDisliked === true ? '取消不喜欢' : '不喜欢该作者', action: (): void => { this.onDislikeClick(); } },
            ])
        } else {
          Text('').width(44)
        }
      }
      .width('100%').padding({ left: 16, right: 16, top: 12, bottom: 8 });

      if (!this.ready) {
        Column() {
          LoadingProgress().width(28).height(28);
          Text('加载中…').fontSize(13).fontFamily($r('app.string.font_family')).fontColor($r('app.color.text_secondary')).margin({ top: 10 });
        }
        .layoutWeight(1).width('100%').justifyContent(FlexAlign.Center);
      } else {
        // 背景图作为资料区底图；头像、资料、统计和操作在同一张资料卡上叠加显示。
        if (this.profile.profileBackground && !this.profile.deleted) {
          Stack() {
            Image(resolveDisplayImageUrl(this.profile.profileBackground))
              .width('100%')
              .height('100%')
              .objectFit(ImageFit.Cover);
            Column() {
              this.profileInformation(true);
            }
            .width('100%')
            .height('100%')
            .justifyContent(FlexAlign.End)
            .backgroundColor('#52000000');
          }
          .width('100%')
          .aspectRatio(16 / 10)
          .borderRadius(10)
          .clip(true)
          .margin({ left: 8, right: 8, bottom: 8 });
        } else {
          this.profileInformation(false);
        }

        // 帖子网格
        if (this.posts.length === 0 && this.loading) {
          PostCollectionState({ loading: true })
            .layoutWeight(1);
        } else if (this.posts.length === 0) {
          PostCollectionState({
            error: this.error,
            emptyTitle: 'TA 还没有发布过帖子',
            onRetry: (): void => { this.refresh(); },
          })
            .layoutWeight(1);
        } else {
          Refresh({ refreshing: this.isRefreshing, builder: this.refreshBuilder }) {
            Grid() {
              ForEach(this.posts, (post: Post) => {
                GridItem() {
                  PostCard({
                    post: post,
                    onOpen: () => {
                      this.goDetail(post);
                    },
                  });
                }
              }, (post: Post) => post.id !== undefined ? post.id.toString() : '');
              if (this.finished) {
                GridItem() {
                  Text('没有更多了')
                    .fontSize(12).fontFamily($r('app.string.font_family')).fontColor($r('app.color.text_secondary'))
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
    .width('100%').padding({ top: this.statusBarHeight }).height('100%').backgroundColor($r('app.color.bg_primary'))
    .transition(buildPageTransition())
  }
}
