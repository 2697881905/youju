
import { Post, UserProfile, ReportReason } from '../models/types';
import { getUserProfile, followUser, unfollowUser, listPosts, resolveDisplayImageUrl, blockUser, unblockUser, dislikeUser, undislikeUser, reportUser } from '../services/api';
import { postDeletionStore } from '../utils/postDeletionStore';
import { getUserId, getToken } from '../utils/auth';
import { PostCard } from '../components/PostCard';
import { ProfileIdentity } from '../components/ProfileIdentity';
import { ProfileStatItem } from '../components/ProfileStatItem';
import { ReportDialog } from '../components/ReportDialog';
import { Pressable } from '../design/motion/Pressable';
import { safeShowToast } from '../utils/toast';
import { openChat, openFollowList, openPostDetail, takeUserProfileId } from '../utils/nav';
import { getMainNavStack, EmptyNavParams, PostDetailNavParams } from '../utils/navigationTransition';
import { buildPageTransition } from '../utils/styles';
import { ColorTokens } from '../design/tokens/color';
import { LayoutTokens, SpaceTokens } from '../design/tokens/space';
import { RadiusTokens } from '../design/tokens/radius';
import { ShadowTokens } from '../design/tokens/shadow';
import { MotionCurves, MotionTokens } from '../design/tokens/motion';
import { TypeTokens } from '../design/tokens/type';
import { BackButton } from '../design/components/BackButton';
import { PostCollectionState } from '../components/PostCollectionState';
import { isImmersiveLightSenseSupported, isSystemMaterialActive, GlassBlurStyle, TopButtonMaterialModifier } from '../utils/immersiveMaterial';

// 关注态局部补丁（乐观更新时只传要改的字段）
interface ProfileFollowPatch {
  isFollowing?: boolean;
  isMutual?: boolean;
  isBlocked?: boolean;
  isDisliked?: boolean;
}

@Component
export struct UserProfileView {
  @Prop navMode: boolean = false;
  onBack?: () => void = undefined;
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
  // 举报用户（防骚扰/违规账号；targetType='user'，复用聊天举报链路）
  private reportController: CustomDialogController = new CustomDialogController({
    builder: ReportDialog({
      targetType: 'user',
      targetId: 0,
      onSubmit: (reason: ReportReason, description: string): void => {
        this.submitUserReport(reason, description);
      },
    }),
    alignment: DialogAlignment.Center,
    customStyle: true,
    width: 344,
  });
  @StorageLink('statusBarHeight') statusBarHeight: number = 0;
  // 标题栏（导航行 + 资料区）驻留 Navigation 标题栏后：资料区高度实测回写（内容驱动，
  // 首帧用与 Builder 同源的估算兜底，见教程模板 E）；关注/私信按钮由系统材质接管表面。
  @State titleBarProfileHeight: number = 0;
  private followActionMaterial: TopButtonMaterialModifier = new TopButtonMaterialModifier();
  private profileEntranceTimer: number = 0;
  private followPulseTimer: number = 0;
  // 订阅帖子删除事件：该作者帖子被删除后，本页网格即时移除（不依赖刷新/重进）
  private unsubDeletion: () => void = () => {};

  aboutToAppear(): void {
    this.resolveTarget();
    // 登录态 + 有效的目标用户 id 才发起加载；targetId 为 0 时发 getUserProfile(0) 是无效请求，
    // 且 ready 会一直停在 false（渲染进「加载中…」）——改由渲染侧给出「参数缺失」出口。
    if (this.token !== '' && this.targetId > 0) {
      this.loadAll();
    }
    // 帖子删除广播：详情页删除成功后，本页 posts 数组即时剔除该帖
    this.unsubDeletion = postDeletionStore.subscribe((deletedId: number): void => {
      this.posts = this.posts.filter((p: Post) => p.id !== deletedId);
    });
  }

  aboutToDisappear(): void {
    this.unsubDeletion();
    if (this.profileEntranceTimer !== 0) {
      clearTimeout(this.profileEntranceTimer);
      this.profileEntranceTimer = 0;
    }
    if (this.followPulseTimer !== 0) {
      clearTimeout(this.followPulseTimer);
      this.followPulseTimer = 0;
    }
  }

  private backAction(): void {
    if (this.onBack !== undefined) { this.onBack(); return; }
    this.getUIContext().getRouter().back();
  }

  private presentProfile(): void {
    this.profilePresented = false;
    if (this.profileEntranceTimer !== 0) {
      clearTimeout(this.profileEntranceTimer);
    }
    this.profileEntranceTimer = setTimeout((): void => {
      this.getUIContext().animateTo({ duration: MotionTokens.page, curve: MotionCurves.emphasized }, () => {
        this.profilePresented = true;
      });
      this.profileEntranceTimer = 0;
    }, MotionTokens.instant) as number;
  }

  private playFollowConfirmation(): void {
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

  // 请求序号：每次发起自增；响应回来时若序号已落后则整体丢弃（最后一次发起的请求生效）。
  // 与 HomeTab.fetch 同一竞态（提审审计 P1-3）：加载更多在途时下拉刷新，旧实现
  // refresh 先重置 page=1 再被 if (this.loading) return 静默丢弃 → 旧页回包 concat、结果重复。
  private fetchSeq: number = 0;

  private async fetch(reset: boolean): Promise<void> {
    const seq: number = ++this.fetchSeq;
    if (this.targetId === 0) {
      // 序号已自增：作废在途请求；不发无效请求
      this.loading = false;
      return;
    }
    this.loading = true;
    this.error = '';
    try {
      const res = await listPosts({ page: this.page, limit: 20, sort: 'latest', author: this.targetId });
      const list: Post[] = res.list;
      if (seq !== this.fetchSeq) {
        return; // 过期响应：期间已有更新的请求发起，整体丢弃
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
      if (seq !== this.fetchSeq) {
        return; // 过期请求的失败不覆盖新请求的状态
      }
      // 分页回滚：loadMore 先 +1 再请求，失败不回滚会让失败那一页被静默跳过
      if (!reset && this.page > 1) {
        this.page -= 1;
      }
      this.error = (e as Error).message;
    } finally {
      // 只有仍是「当前请求」才有资格退出加载态
      if (seq === this.fetchSeq) {
        this.loading = false;
      }
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
    const stack = getMainNavStack();
    if (this.navMode && stack !== null) {
      stack.pushPathByName('MyFollow', new EmptyNavParams());
    } else {
      this.getUIContext().getRouter().pushUrl({ url: 'pages/MyFollowPage' });
    }
  }

  private goDetail(post: Post): void {
    if (post.id !== undefined) {
      const pid: string = post.id.toString();
      openPostDetail(pid);
      const stack = getMainNavStack();
      if (this.navMode && stack !== null) {
        // ⚠️ postId 必须显式赋值：PostDetailNavParams.postId 默认 0（非 undefined），
        // 目的地 onReady 的 typeof 守卫对 0 放行，openPostDetail(String(0)) 会把意图通道里
        // 已设好的正确 id 覆盖成 "0" → getPost(0) → 「帖子不存在」。此通道是唯一出处，
        // 意图通道的值会被目的地重写，单靠 openPostDetail(pid) 带不上参数。
        const p: PostDetailNavParams = new PostDetailNavParams();
        p.postId = post.id;
        stack.pushPathByName('PostDetail', p);
      } else {
        this.getUIContext().getRouter().pushUrl({ url: 'pages/DetailPage' });
      }
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

  // 资料区首帧估算（与 profileInformation 行结构同源；onAreaChange 实测后不再使用）：
  // ProfileIdentity 固定高 146 + 统计行(36 + 底部 sm) + 关注/私信按钮行(36 + 底部 xs，
  // 注销用户/本人主页不显示)。背景图变体走 16:10 卡片，实测值下一帧即纠正。
  private profileBlockEstimate(): number {
    const stats: number = LayoutTokens.segmentedHeight + SpaceTokens.sm;
    const actions: number = (!this.profile.deleted && !this.isSelf())
      ? LayoutTokens.segmentedHeight + SpaceTokens.xs : 0;
    return 146 + stats + actions;
  }

  // 标题栏总高：状态栏 + 导航行(top 12 + 44 + bottom 8) + 资料区（非就绪态仅导航行）
  private userProfileTitleBarHeight(): number {
    const profile: number = this.ready
      ? (this.titleBarProfileHeight > 0 ? this.titleBarProfileHeight : this.profileBlockEstimate())
      : 0;
    return this.statusBarHeight + SpaceTokens.md + LayoutTokens.minTouchTarget + SpaceTokens.sm + profile;
  }

  // 标题栏：导航行（返回 + 昵称 + ⋯ 菜单）+ 资料区（身份/统计/关注私信按钮，含背景图
  // 变体与入场动效）整体驻留——用户指定边界为「关注/私信按钮及其以上区域」。
  // 全屏布局下状态栏避让由本 Builder 的外层节点手动承担（同一节点写两次 .padding 是
  // 整体覆盖，行内边距必须留在内层行上）；bindMenu 系统菜单全页面生效，可直接驻留。
  @Builder
  userProfileTitleBar(): void {
    Column() {
      Row() {
        BackButton({ action: (): void => { this.backAction(); } })
        Text(this.profile.deleted ? '已注销用户' : (this.profile.nickname !== '' ? this.profile.nickname : '用户主页'))
          .fontSize(17).fontFamily($r('app.string.font_family')).fontWeight(600).layoutWeight(1).textAlign(TextAlign.Center);
        if (!this.profile.deleted && !this.isSelf()) {
          Text('⋯')
            .width(44).height(44).textAlign(TextAlign.Center).fontSize(22)
            .fontColor($r('app.color.text_primary'))
            .bindMenu([
              { value: this.profile.isBlocked === true ? '取消拉黑' : '拉黑该作者', action: (): void => { this.onBlockClick(); } },
              { value: this.profile.isDisliked === true ? '取消不喜欢' : '不喜欢该作者', action: (): void => { this.onDislikeClick(); } },
              { value: '举报该用户', action: (): void => { this.onReportClick(); } },
            ])
        } else {
          Text('').width(44)
        }
      }
      .width('100%').padding({ left: 16, right: 16, top: 12, bottom: 8 });

      // 资料区整体驻留；高度实测回写供 .title({ height }) 使用（阈值防抖，模板 E）
      if (this.ready) {
        Column() {
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
        }
        .width('100%')
        .onAreaChange((_old: Area, area: Area): void => {
          const h: number = parseFloat(String(area.height));
          if (h > 0 && Math.abs(h - this.titleBarProfileHeight) > 0.5) {
            this.titleBarProfileHeight = h;
          }
        })
      }
    }
    .width('100%')
    // 手动避让状态栏（含在栏高内；避让只此一处——内容区根节点不再重复加）
    .padding({ top: this.statusBarHeight })
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
    const stack = getMainNavStack();
    if (this.navMode && stack !== null) {
      stack.pushPathByName('ChatPage', new EmptyNavParams());
    } else {
      this.getUIContext().getRouter().pushUrl({ url: 'pages/ChatPage' });
    }
  }

  // 举报用户：未登录先提示登录；已登录拉起举报弹窗（同上「私信长按举报」责任链）
  private onReportClick(): void {
    if (this.targetId === 0 || this.isSelf()) {
      return;
    }
    if (getToken() === '' || getUserId() <= 0) {
      safeShowToast(this.getUIContext(), { message: '请先登录后再举报' });
      return;
    }
    this.reportController.open();
  }

  // 提交用户举报（targetType='user'，复用后端 /v1/users/:id/report）
  private async submitUserReport(reason: ReportReason, description: string): Promise<void> {
    if (this.targetId <= 0) {
      this.reportController.close();
      return;
    }
    try {
      await reportUser(this.targetId, { reason: reason, description: description });
      this.reportController.close();
      safeShowToast(this.getUIContext(), { message: '举报已提交，我们会尽快处理' });
    } catch (e) {
      const err: Error = e as Error;
      safeShowToast(this.getUIContext(), { message: (err.message ?? '').length > 0 ? err.message : '举报失败，请稍后重试' });
    }
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
              // 沉浸光感（驻留标题栏后）：材质生效时自绘让位——blur 置 NONE（背景模糊遮挡
              // 材质，官方 FAQ）、描边/阴影归零（否则实心毛玻璃/双圈描边/脏阴影），系统材质
              // 接管表面；低版本门禁不通过 → 保留原 HDS 玻璃兜底（blur + barSurface + 描边）
              .backgroundBlurStyle(isSystemMaterialActive() ? BlurStyle.NONE : GlassBlurStyle.Press)
              .backgroundColor(isImmersiveLightSenseSupported() ? Color.Transparent : ColorTokens.barSurface)
              .border({ width: isSystemMaterialActive() ? 0 : LayoutTokens.glassBorderWidth, color: ColorTokens.barBorder, style: BorderStyle.Solid })
              .borderRadius(RadiusTokens.floatingBar)
              .shadow(isSystemMaterialActive() ? ShadowTokens.none : { radius: 12, color: ColorTokens.barShadow, offsetY: 4 })
              .attributeModifier(this.followActionMaterial)
              .scale({ x: this.followPulse ? MotionTokens.successScale : 1, y: this.followPulse ? MotionTokens.successScale : 1 })
              .animation({ duration: MotionTokens.emphasis, curve: MotionCurves.springSoft });
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
              // 与关注按钮同一套材质让位规则（见上方注释）
              .backgroundBlurStyle(isSystemMaterialActive() ? BlurStyle.NONE : GlassBlurStyle.Press)
              .backgroundColor(isImmersiveLightSenseSupported() ? Color.Transparent : ColorTokens.barSurface)
              .border({ width: isSystemMaterialActive() ? 0 : LayoutTokens.glassBorderWidth, color: ColorTokens.barBorder, style: BorderStyle.Solid })
              .borderRadius(RadiusTokens.floatingBar)
              .shadow(isSystemMaterialActive() ? ShadowTokens.none : { radius: 12, color: ColorTokens.barShadow, offsetY: 4 })
              .attributeModifier(this.followActionMaterial);
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
    .opacity(this.profilePresented ? 1 : 0)
    .translate({ y: this.profilePresented ? 0 : SpaceTokens.xl })
    .scale({
      x: this.profilePresented ? 1 : MotionTokens.enterScale,
      y: this.profilePresented ? 1 : MotionTokens.enterScale,
    })
    .animation({
      duration: MotionTokens.page,
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
    Navigation() {
      Column() {
        this.userProfileContent()
      }
      .width('100%')
      .height('100%')
      .backgroundColor($r('app.color.bg_primary'))
    }
    .mode(NavigationMode.Stack)
    .title({
      builder: this.userProfileTitleBar,
      height: this.userProfileTitleBarHeight(),
    }, { barStyle: BarStyle.STANDARD, backgroundColor: ColorTokens.canvas })
    .width('100%')
    .height('100%')
    .transition(buildPageTransition())
  }

  // 内容区（标题栏之下）：未就绪三分支 + 帖子网格（原 build 内容整体平移，仅换壳；
  // 导航行与资料区已迁入标题栏，状态栏避让随之移交，内容区不再持有 statusBar padding）
  @Builder
  userProfileContent(): void {
    if (!this.ready) {
      if (getToken() === '' || getUserId() <= 0) {
        // 未登录：展示手动登录入口（不自动跳转，避免登录页返回死循环）；
        // 登录成功后 onTokenReady 监听到 token 变化会自动触发 loadAll。
        Column({ space: SpaceTokens.sm }) {
          Text('登录后可查看用户主页、关注与私信')
            .fontSize(TypeTokens.body.size)
            .fontFamily(TypeTokens.fontFamily)
            .fontColor($r('app.color.text_secondary'))
            .textAlign(TextAlign.Center)
            .padding({ left: SpaceTokens.lg, right: SpaceTokens.lg })
          Pressable({
            fillWidth: false,
            visualHeight: LayoutTokens.segmentedHeight,
            touchTargetHeight: LayoutTokens.minTouchTarget,
            action: (): void => {
              const stack = getMainNavStack();
              if (this.navMode && stack !== null) {
                stack.pushPathByName('Login', new EmptyNavParams());
              } else {
                this.getUIContext().getRouter().pushUrl({ url: 'pages/LoginPage' });
              }
            },
          }) {
            Text('去登录')
              .width(120)
              .height(LayoutTokens.segmentedHeight)
              .textAlign(TextAlign.Center)
              .fontSize(TypeTokens.callout.size)
              .fontFamily(TypeTokens.fontFamily)
              .fontWeight(TypeTokens.headline.weight)
              .fontColor(ColorTokens.primary)
              .backgroundBlurStyle(GlassBlurStyle.Press)
              .backgroundColor(isImmersiveLightSenseSupported() ? Color.Transparent : ColorTokens.barSurface)
              .border({ width: LayoutTokens.glassBorderWidth, color: ColorTokens.barBorder, style: BorderStyle.Solid })
              .borderRadius(RadiusTokens.floatingBar);
          }
        }
        .layoutWeight(1)
        .width('100%')
        .justifyContent(FlexAlign.Center);
      } else if (this.targetId <= 0) {
        // 已是登录态但目标用户 id 缺失（takeUserProfileId() 未设置）：
        // 此前会落进下面的 Loading 分支永久转圈，这里显式给出出口。
        Column({ space: SpaceTokens.sm }) {
          Text('页面参数缺失，请返回重新进入')
            .fontSize(TypeTokens.body.size)
            .fontFamily(TypeTokens.fontFamily)
            .fontColor($r('app.color.text_secondary'))
            .textAlign(TextAlign.Center)
            .padding({ left: SpaceTokens.lg, right: SpaceTokens.lg })
          Pressable({
            fillWidth: false,
            visualHeight: LayoutTokens.segmentedHeight,
            touchTargetHeight: LayoutTokens.minTouchTarget,
            action: (): void => { this.backAction(); },
          }) {
            Text('返回')
              .width(120)
              .height(LayoutTokens.segmentedHeight)
              .textAlign(TextAlign.Center)
              .fontSize(TypeTokens.callout.size)
              .fontFamily(TypeTokens.fontFamily)
              .fontWeight(TypeTokens.headline.weight)
              .fontColor(ColorTokens.primary)
              .border({ width: LayoutTokens.glassBorderWidth, color: ColorTokens.barBorder, style: BorderStyle.Solid })
              .borderRadius(RadiusTokens.lg);
          }
        }
        .layoutWeight(1)
        .width('100%')
        .justifyContent(FlexAlign.Center);
      } else {
        Column() {
          LoadingProgress().width(28).height(28);
          Text('加载中…').fontSize(13).fontFamily($r('app.string.font_family')).fontColor($r('app.color.text_secondary')).margin({ top: 10 });
        }
        .layoutWeight(1).width('100%').justifyContent(FlexAlign.Center);
      }
    } else {
      // 帖子网格（资料区已随导航行迁入标题栏，见 userProfileTitleBar）
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
                  // 两列网格小卡用紧凑档（xs 圆角/小字号），与「我的」主页一致；
                  // 默认大圆角(lg)在半宽卡片上与图片比例失调
                  compact: true,
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
          .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true })
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
}
