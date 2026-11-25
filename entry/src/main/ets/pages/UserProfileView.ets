
import { Post, UserProfile, ReportReason } from '../models/types';
import { getUserProfile, followUser, unfollowUser, listPosts, resolveDisplayImageUrl, blockUser, unblockUser, dislikeUser, undislikeUser, reportUser } from '../services/api';
import { postDeletionStore } from '../utils/postDeletionStore';
import { getUserId, getToken } from '../utils/auth';
import { PostCard } from '../components/PostCard';
import { ProfileIdentity } from '../components/ProfileIdentity';
import { ProfileStatItem } from '../components/ProfileStatItem';
import { ReportDialog } from '../components/ReportDialog';
import { AppModalController } from '../utils/modal';
import { safeShowToast } from '../utils/toast';
import { openChat, openFollowList, openPostDetail, takeUserProfileId } from '../utils/nav';
import { getMainNavStack, EmptyNavParams, PostDetailNavParams } from '../utils/navigationTransition';
import { buildPageTransition } from '../utils/styles';
import { SpaceTokens } from '../design/tokens/space';
import { MotionCurves, MotionTokens } from '../design/tokens/motion';
import { TypeTokens } from '../design/tokens/type';
import {
  HdsNavigation,
  HdsNavigationTitleMode,
  HdsNavigationTitleBarOptions,
  HdsNavigationIconOptions,
  HdsNavigationMenuItemOptions,
} from '@kit.UIDesignKit';
import { ComponentContent } from '@kit.ArkUI';
import { ColorTokens } from '../design/tokens/color';
import { resolveActionIcon } from '../utils/actionIcons';
import {
  HDS_MINI_BAR_ROW_VP,
  buildPageTitleBarOptions,
  GlassTitleRow,
} from '../design/components/HdsGlassBackSurface';
import { DesignButton } from '../design/components/DesignButton';
import { GlassPillButton } from '../design/components/GlassPillButton';
import { PostCollectionState } from '../components/PostCollectionState';
import { isSystemMaterialActive, getMenuImmersiveMaterial } from '../utils/immersiveMaterial';
import { gridColumnsForBreakpoint } from '../utils/responsive';

// 「更多」系统 Menu 的弹出锚点 id：与标题栏「更多」官方圆钮同位的透明锚点（见 build()）
const USER_PROFILE_MORE_ANCHOR_ID: string = 'userProfileMoreMenuAnchor';

// 「更多」菜单项：图标 + 文案 + 文字色 + 动作（与帖子详情页 moreMenuBuilder 同构）
interface ProfileMoreMenuItem {
  icon: Resource;
  label: string;
  color: ResourceColor;
  action: () => void;
}

// openMenu 渲染的就是系统 Menu；builder 写纯 Menu/MenuItem（startIcon + contentFontColor），
// 与帖子详情页右上角「更多」的菜单渲染完全同构。
@Builder
function userProfileMoreMenuBuilder(items: ProfileMoreMenuItem[]): void {
  Menu() {
    ForEach(items, (item: ProfileMoreMenuItem, idx: number): void => {
      MenuItem({ startIcon: item.icon, content: item.label })
        .contentFontColor(item.color)
        .onClick((): void => { item.action(); });
    }, (item: ProfileMoreMenuItem, idx: number): string => `${idx}`)
  }
}

// 关注态局部补丁（乐观更新时只传要改的字段）
interface ProfileFollowPatch {
  isFollowing?: boolean;
  isMutual?: boolean;
  isBlocked?: boolean;
  isDisliked?: boolean;
}

// 举报弹窗参数对象：ComponentContent 需要「全局 @Builder + class 参数」，回调闭包捕获宿主
// this 在 open 时构造；关闭走 closeCustomDialog(content) 同步可靠（不依赖 dialogId——其
// Promise 真机在弹窗关闭时才回填，2026-11-25 双层弹窗实锤）。
export class UserReportDialogParams {
  onSubmit: (reason: ReportReason, description: string) => void = (_r: ReportReason, _d: string) => {};
  onClose: () => void = (): void => {};
}

@Builder
function userReportDialogBuilder(p: UserReportDialogParams) {
  ReportDialog({
    targetType: 'user',
    targetId: 0,
    onSubmit: (reason: ReportReason, description: string): void => {
      p.onSubmit(reason, description);
    },
    onClose: (): void => {
      p.onClose();
    },
  })
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
  private reportModal: AppModalController = new AppModalController();

  @StorageProp('currentBreakpoint') currentBreakpoint: string = 'sm';
  // 穿底前提：内容区从窗口原点起算（enableComponentSafeArea:false），列表再靠
  // contentStartOffset 让开整条标题栏（状态栏 + 56vp 行高）。
  @StorageProp('statusBarHeight') statusBarHeight: number = 0;
  // 「更多」系统 Menu 的 ComponentContent 载体（openMenu 需自行维护 content 以支持 update 换选项集）
  private profileMenuContent: ComponentContent<ProfileMoreMenuItem[]> | null = null;
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
    this.profileMenuContent = null;
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

  // 标题栏只留一行（返回 + 昵称 + 更多官方圆钮）：资料卡回到列表流里随列表滚走。
  // 栏体节点之内抓不到滚动源，装进栏里的东西等于从手势里摘出去（基准 §7.6.13b）。
  private userProfileTitleBarOptions(): HdsNavigationTitleBarOptions {
    const moreItem: HdsNavigationMenuItemOptions = {
      content: {
        icon: resolveActionIcon('more'),
        label: '更多操作',
        action: (): void => { this.showUserProfileMoreActions(); },
      } as HdsNavigationIconOptions,
    };
    return buildPageTitleBarOptions({
      back: (): void => { this.backAction(); },
      stackBuilder: (): void => { this.userProfileNavRow(); },
      // 已注销 / 本人主页不挂「更多」（menu 项构造与挂载条件同改造前）
      menuItems: (!this.profile.deleted && !this.isSelf()) ? [moreItem] : undefined,
      // content.menu 图标色默认白，浅色画布上不可见（工厂仅在挂 menu 时写入 menuStyle）
      menuIconColor: ColorTokens.primary,
      // true 会把内容区顶到栏体之下（列表起点 = 栏底）→ 资料卡穿不到栏底下。
      // false 让内容区从窗口原点起算，让位由 List 的 contentStartOffset 承担。
      enableComponentSafeArea: false,
    });
  }

  // 弹「更多」系统 Menu（官方 content.menu 圆钮 action 里唯一可编程弹菜单入口）：
  // target 用与圆钮同位的透明锚点，placement 显式 BottomRight（默认 BottomLeft 会把菜单弹到左下方）。
  private showUserProfileMoreActions(): void {
    const items: ProfileMoreMenuItem[] = [
      {
        icon: resolveActionIcon('lock'),
        label: this.profile.isBlocked === true ? '取消拉黑' : '拉黑该作者',
        color: ColorTokens.primary,
        action: (): void => { this.onBlockClick(); },
      },
      {
        icon: resolveActionIcon('close'),
        label: this.profile.isDisliked === true ? '取消不喜欢' : '不喜欢该作者',
        color: ColorTokens.primary,
        action: (): void => { this.onDislikeClick(); },
      },
      {
        icon: resolveActionIcon('warning'),
        label: '举报该用户',
        color: ColorTokens.primary,
        action: (): void => { this.onReportClick(); },
      },
    ];
    const uiContext: UIContext = this.getUIContext();
    if (this.profileMenuContent === null) {
      this.profileMenuContent = new ComponentContent<ProfileMoreMenuItem[]>(
        uiContext, wrapBuilder(userProfileMoreMenuBuilder), items);
    } else {
      // 复用 + update：拉黑/不喜欢状态变化后选项文案随 @State 重建，不复用会串旧选项
      this.profileMenuContent.update(items);
    }
    // 弹层材质：沉浸玻璃配方·弹层菜单档（THICK，与首页圈子下拉 bindMenu 同款配方）。
    // @since 26.0.0 的 systemMaterial 字段走 isSystemMaterialActive() 门禁：
    // 低版本不传该字段，菜单退回系统默认底色，其余行为不变。
    const menuOptions: MenuOptions = {
      placement: Placement.BottomRight,
    };
    if (isSystemMaterialActive()) {
      // SystemUiMaterial 是全局声明类型（= uiMaterial.Material），无需 import uiMaterial
      // （低版本设备加载即崩的老坑，TagNav.menuOptions 同款处理）。
      const material: SystemUiMaterial | undefined = getMenuImmersiveMaterial();
      if (material !== undefined) {
        menuOptions.systemMaterial = material;
      }
    }
    uiContext.getPromptAction()
      .openMenu(this.profileMenuContent, { id: USER_PROFILE_MORE_ANCHOR_ID }, menuOptions)
      .catch((): void => {
        // 无有效 target 等异常：无操作
      });
  }

  // 列表首项要让开的整条标题栏（状态栏 + 56vp 行高）
  private userProfileListInset(): number {
    return this.statusBarHeight + HDS_MINI_BAR_ROW_VP;
  }

  // 导航行（昵称居中）：GlassTitleRow serif 形态承担居中样板与返回键让位；
  // 「更多」已迁 content.menu 官方圆钮（栏级玻璃珠）
  @Builder
  userProfileNavRow(): void {
    GlassTitleRow({
      title: this.profile.deleted ? '已注销用户' : (this.profile.nickname !== '' ? this.profile.nickname : '用户主页'),
      serif: true,
    })
  }

  // 资料区（身份/统计/关注私信按钮，含背景图变体与入场动效）：列表第 0 项，随列表滚走
  @Builder
  userProfileProfileBlock(): void {
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

    }
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
    const params: UserReportDialogParams = new UserReportDialogParams();
    params.onSubmit = (reason: ReportReason, description: string): void => {
      this.submitUserReport(reason, description);
    };
    params.onClose = (): void => { this.reportModal.close(); };
    const content: ComponentContent<UserReportDialogParams> =
      new ComponentContent(this.getUIContext(), wrapBuilder(userReportDialogBuilder), params);
    this.reportModal.openContent(this.getUIContext(), content, {
      onDismiss: (): void => {
        this.reportModal.close();
      },
    });
  }

  // 提交用户举报（targetType='user'，复用后端 /v1/users/:id/report）
  private async submitUserReport(reason: ReportReason, description: string): Promise<void> {
    if (this.targetId <= 0) {
      this.reportModal.close();
      return;
    }
    try {
      await reportUser(this.targetId, { reason: reason, description: description });
      this.reportModal.close();
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
          // 关注/私信走 GlassPillButton 模板（useSystemMaterial=false：内容区材质不出图，
          // 走玻璃兜底配方）；关注成功的 spring 脉冲由 successPulse 承接
          Column() {
            GlassPillButton({
              label: this.followPending ? '处理中' : this.followBtnText(),
              fillWidth: true,
              disabled: this.followPending,
              muted: this.profile.isFollowing,
              successPulse: this.followPulse,
              useSystemMaterial: false,
              action: (): void => { this.onFollowClick(); },
            })
          }
          .layoutWeight(1)
          Column() {
            GlassPillButton({
              label: '私信',
              fillWidth: true,
              useSystemMaterial: false,
              action: (): void => { this.onMessageClick(); },
            })
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
    HdsNavigation() {
      Stack({ alignContent: Alignment.TopStart }) {
        Column() {
          this.userProfileContent()
        }
        .width('100%')
        .height('100%')
        .backgroundColor($r('app.color.bg_primary'))

        // 「更多」系统 Menu 弹出锚点：与标题栏「更多」官方圆钮同位（右上、MINI 栏区内）。
        // content.menu 圆钮是 HDS 内部渲染、无 id 可引用，故补一个不响应事件的透明锚点供 openMenu 定位。
        Row()
          .id(USER_PROFILE_MORE_ANCHOR_ID)
          .width(40)
          .height(40)
          .hitTestBehavior(HitTestMode.None)
          .position({ x: '100%', y: this.statusBarHeight + 8 })
          .markAnchor({ x: 52, y: 0 })
      }
      .width('100%')
      .height('100%')
    }
    .mode(NavigationMode.Stack)
    .titleMode(HdsNavigationTitleMode.MINI)
    .titleBar(this.userProfileTitleBarOptions())
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
          GlassPillButton({
            label: '去登录',
            action: (): void => {
              const stack = getMainNavStack();
              if (this.navMode && stack !== null) {
                stack.pushPathByName('Login', new EmptyNavParams());
              } else {
                this.getUIContext().getRouter().pushUrl({ url: 'pages/LoginPage' });
              }
            },
          })
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
          DesignButton({
            label: '返回',
            variant: 'outlined',
            action: (): void => { this.backAction(); },
          })
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
      // 整页一条 List：资料卡是第 0 项（随列表滚走、一路滑到标题栏底下被磨砂糊掉），
      // 帖子在第 1 项；让位由 contentStartOffset 承担（与「我的」页同构）。
      Refresh({ refreshing: $$this.isRefreshing, builder: this.refreshBuilder }) {
        List() {
          ListItem() {
            Column() {
              this.userProfileProfileBlock()
            }
            .width('100%')
            .padding({ top: SpaceTokens.xs })
          }
          .width('100%')

          ListItem() {
            Column() {
              this.userProfileFeedBody()
            }
            .width('100%')
          }
          .width('100%')
        }
        .width('100%')
        .height('100%')
        .scrollBar(BarState.Off)
        .contentStartOffset(this.userProfileListInset())
        .edgeEffect(EdgeEffect.Spring)
        .divider({ strokeWidth: 0 })
        .padding({ bottom: SpaceTokens.xl })
        .onReachEnd((): void => {
          this.loadMore();
        })
      }
      .onRefreshing(() => {
        this.refresh().finally(() => {
          this.isRefreshing = false;
        });
      })
      .layoutWeight(1).width('100%');
    }
  }

  // 帖子区（原网格平移）：空/加载态撑一个可视高度 —— 整页一条 List，
  // 状态页若只有几十 vp，列表总高骤降会把当前滚动位钳死
  @Builder
  userProfileFeedBody(): void {
    if (this.posts.length === 0 && this.loading) {
      Column() {
        PostCollectionState({ loading: true });
      }
      .width('100%')
      .constraintSize({ minHeight: 360 });
    } else if (this.posts.length === 0) {
      Column() {
        PostCollectionState({
          error: this.error,
          emptyTitle: 'TA 还没有发布过帖子',
          onRetry: (): void => { this.refresh(); },
        });
      }
      .width('100%')
      .constraintSize({ minHeight: 360 });
    } else {
      this.multiColumnFeed()
      if (this.finished) {
        Text('没有更多了')
          .fontSize(12).fontFamily($r('app.string.font_family')).fontColor($r('app.color.text_secondary'))
          .width('100%').textAlign(TextAlign.Center).padding(16);
      }
    }
  }

  // 多列：按原始下标对列数取模分列，首项恒在左上角。
  // List 里不能放可滚动的 Grid（内层滚动源会把高度吞掉），故与「我的」页同用手排多列
  @Builder
  multiColumnFeed(): void {
    Row({ space: SpaceTokens.xs }) {
      ForEach(this.gridColumnIndexes(), (colIdx: number) => {
        Column({ space: SpaceTokens.xs }) {
          ForEach(this.posts.filter((_post: Post, idx: number) => idx % this.gridColumnCount() === colIdx),
            (post: Post) => {
              PostCard({
                post: post,
                // 两列网格小卡用紧凑档（xs 圆角/小字号），与「我的」主页一致；
                // 默认大圆角(lg)在半宽卡片上与图片比例失调
                compact: true,
                navMode: this.navMode,
                onOpen: () => {
                  this.goDetail(post);
                },
              });
            }, (post: Post) => 'col' + colIdx + '-' + (post.id ?? ''))
        }
        .layoutWeight(1)
      }, (colIdx: number) => colIdx.toString())
    }
    .width('100%')
    .alignItems(VerticalAlign.Top)
    .padding({ left: SpaceTokens.sm, right: SpaceTokens.sm, top: 12 });
  }

  private gridColumnCount(): number {
    return Math.max(2, Math.min(4, gridColumnsForBreakpoint(this.currentBreakpoint)));
  }

  private gridColumnIndexes(): number[] {
    const arr: number[] = [];
    for (let i = 0; i < this.gridColumnCount(); i++) {
      arr.push(i);
    }
    return arr;
  }
}
