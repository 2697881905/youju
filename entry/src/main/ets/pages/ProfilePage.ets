// 个人主页（我的）：头像/昵称 + 关注/粉丝入口 + 我发布/我收藏 双 Tab + 帖子网格

import { Post, User, UserProfile, BookmarkFolderItem } from '../models/types';
import { listPosts, listMyBookmarks, listMyLikedPosts, listMyCommentedPosts, getUserProfile, cancelBookmarkPost, resolveDisplayImageUrl, listBookmarkFolders, trackPostEvent } from '../services/api';
import { PostCard } from '../components/PostCard';
import { getCurrentUser } from '../utils/auth';
import { safeShowToast } from '../utils/toast';
import { openPostDetailViaNav, postDetailCoverOf } from '../utils/longTake/openPostDetailNav';
import { gridColumnTemplate, gridColumnsForBreakpoint } from '../utils/responsive';
import { barBottomReserve } from '../utils/cardTokens';
import { likeStore } from '../utils/likeStore';
import { postDeletionStore } from '../utils/postDeletionStore';
import { resolveActionIcon } from '../utils/actionIcons';
import { buildProfileShareText, buildProfileShareUrl, copyToClipboard, EXTERNAL_SHARE_ENABLED, shareProfileToSystem } from '../utils/share';
import { PostCollectionState } from '../components/PostCollectionState';
import { EmptyState } from '../design/components/EmptyState';
import { ProfileShareSheet } from '../components/ProfileShareSheet';
import { SegmentedItem } from '../design/components/SegmentedControl';
import { Pressable } from '../design/motion/Pressable';
import { ColorTokens } from '../design/tokens/color';
import { IconTokens } from '../design/tokens/icon';
import { MotionCurves, MotionTokens } from '../design/tokens/motion';
import { RadiusTokens } from '../design/tokens/radius';
import { LayoutTokens, SpaceTokens } from '../design/tokens/space';
import { TypeTokens } from '../design/tokens/type';

// 主分段：我发布 / 我收藏 / 我赞过 / 我评论（导出给 Index 的标题栏渲染；
// 标题栏与本页 Swiper 通过 Index 持有的 @Link 共享选中态）。
export const PROFILE_SEGMENTS: SegmentedItem[] = [
  { key: 'published', label: '我发布' },
  { key: 'bookmarks', label: '我收藏' },
  { key: 'liked', label: '我赞过' },
  { key: 'commented', label: '我评论' },
];

// 「我收藏」子分段：帖子（收藏列表） | 收藏夹（专辑管理）
// 导出给 Index 的标题栏渲染（与主分段栏同一生效区域，沉浸光感才画得出来）。
export const BOOKMARK_SEGMENTS: SegmentedItem[] = [
  { key: 'posts', label: '帖子' },
  { key: 'folders', label: '收藏夹' },
];

// 主分段栏悬浮在列表之上遮住的那一条高度（只算控件本体 36vp）。
// 内容区盒子已伸到窗口顶部，列表首屏内容要让开「整条顶栏（topInset，到分段栏顶边）
// + 这一条」，否则第一张卡片停在分段栏底下。
// 与 Index 的 profileListInset() / profileTitleBarHeight() 配套：两者相差正好这一条。
const PROFILE_SEG_ROW_HEIGHT: number = LayoutTokens.segmentedHeight;

@Component
export struct ProfilePage {
  // —— 顶栏（我的/分享/设置 + 资料区 + 主分段栏）迁入 Navigation 标题栏后，
  // 以下状态由 Index 持有、这里 @Link 共用（标题栏渲染资料区与分段，列表据此联动）——
  @Link user: User;

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
  @Link followingCount: number;
  @Link followerCount: number;
  @Link totalLikes: number; // 获赞总数
  @Link @Watch('onTabIdxChanged') tabIdx: number; // 0 我发布, 1 我收藏, 2 我赞过, 3 我评论
  // 标题栏分享按钮 → 本页分享流程的信号：递增序号触发 @Watch，
  // 分享弹层 / 文案 / 剪贴板逻辑仍全部留在本页（Index 只负责发起）。
  @Link @Watch('onShareRequested') profileShareSeq: number;
  // 四个分段各自的列表缓存。分页要求每一页都能立刻拿到"自己的"内容：
  // 只保留当前分段的列表，会让相邻页在拖动过程中显示当前分段的数据。
  @State postsCache: Post[][] = [[], [], [], []];
  // 「我收藏」子分段：0 帖子列表 / 1 收藏夹网格（切换时懒加载收藏夹）。
  // 控件本体已上移到 Index 的标题栏（与主分段栏同一条磨砂区），选中态由 Index 持有、这里 @Link 共用。
  @Link @Watch('onBookmarkSubTabChange') bookmarkSubTab: number;
  // 收藏夹条数上抛给 Index 的标题栏（「管理」入口只在有收藏夹时出现）；loadFolders 收尾时回写。
  @Link folderCount: number;
  @State folders: BookmarkFolderItem[] = [];
  @State foldersReady: boolean = true;
  @State posts: Post[] = [];
  @State page: number = 1;
  @State loading: boolean = false;
  @State finished: boolean = false;
  @State isRefreshing: boolean = false;
  // 刷新指示器显隐：isRefreshing 只在越过阈值后为 true，拉拽过程（Drag/OverDrag）不置位。
  // Refresh 的 builder 内容**永远参与绘制**，.offset() 只挪绘制不挪布局——不做属性级门控，
  // 「刷新中…」会常驻在分段栏下方（真机实证；同 HomeTab.ets:598 注释）。
  @State refreshIndicatorVisible: boolean = false;
  @State error: string = '';
  @State ready: boolean = false;
  // 资料区入场动效（资料区已在标题栏内渲染）：由本页在真正进入「我的」页时置位
  @Link profilePresented: boolean;
  // 穿底内缩：外层 Navigation 标题栏是 BarStyle.STACK（覆盖式）且栏底透明磨砂，
  // 内容区盒子从窗口顶部起算——列表因此能一路穿到整条顶栏（含资料卡）底下，
  // 由栏体系统磨砂把穿过的内容糊成玻璃底。本页不再给根节点加内边距，
  // 而是把这一条用在「列表内容的顶部留白 / 悬浮件位置 / 刷新指示器偏移」上。
  // 数值由 Index 按标题栏实测高度下发（资料卡高度是内容驱动的）。
  @Prop topInset: number = 0;
  // 状态页撑底高度（vp）。整页一条 List，切段瞬间新分段缓存为空会渲染 loading/空态；
  // 它若只有几十 vp，列表总高骤降 → 滚动位被钳死且回不来 = 「点分段栏画面跳一下」。
  // ListItem 里 constraintSize minHeight 写 '100%' 实测不生效，必须给具体值（§7.6.25）。
  @Prop viewportMinHeightVp: number = 0;
  // 列表纵向**绝对偏移**上抛：顶栏模糊出图开关（IMMERSIVE 变体的 blurRadius 门控）读它。
  // 用 currentOffset 而非每帧增量——增量正负会被松手回弹的负帧打灭（「松手模糊消失」根因）。
  onListScroll?: (offsetY: number) => void = undefined;
  // 单一滚动源：整页一条 List（四分段改点击切换，不再有 4 页 Swiper 各带一条 Scroll）。
  // 必须**从上游往下传**而不是本页造好再回调上去——后者要让 Index 等一次异步握手，
  // 首帧绑定为空就等于没绑，模糊慢一帧才出现。
  scrollers: Scroller[] = [new Scroller()];
  // 资料卡本体由 Index 以 @Builder 下发，渲染在这里第 0 个 ListItem 里。
  // 留在 Index 是因为它读的那批资料状态（profileUser/计数/编辑入口）都在 Index，搬过来要连
  // 一串 @Link 一起挪；@BuilderParam 里读的仍是父组件的 this，响应式不受影响。
  @BuilderParam heroHeader: () => void = this.emptyHero;
  // 主分段 + （子分段）两行：作为 List 的吸顶组头渲染，位置在资料卡之下、列表之上。
  @BuilderParam segHeader: () => void = this.emptySegRows;
  // 当前激活的底部 Tab（由 Index 经 AppStorage 广播），用于感知「我的」页是否可见，
  // 切到本页时重新拉取列表，使「我赞过/我收藏」在跨页点赞、取消收藏后即时刷新。
  @StorageLink('activeTab') @Watch('onActiveTab') activeTab: number = 0;
  @StorageLink('authToken') @Watch('onTokenReady') token: string = '';
  // 详情页浏览信号：每次打开帖子详情递增（PostDetailView.load 落笔）。收到后静默刷新
  // 「我发布」—— 卡片浏览数即时，返回列表不再要切 Tab/下拉（QA 浏览量审计「卡片不即时」）。
  @StorageProp('postViewSignal') @Watch('onPostViewSignal') postViewSignal: number = 0;
  // 响应式列数（按全局断点 2/3/4 列自适应）；断点后经 @Watch 修正
  @State gridColumns: number = 2;
  @State gridTemplate: string = '1fr 1fr';
  @StorageProp('currentBreakpoint') @Watch('onBreakpointChanged') currentBreakpoint: string = 'sm';
  // 每次切换分段或刷新都推进版本号；延迟返回的旧请求不能覆盖当前分段的数据。
  private listVersion: number = 0;
  // 模拟器启动时后端端口转发可能尚未就绪，个人页列表失败后自动补拉一次。
  private retryTimer: number = 0;
  private profileEntranceTimer: number = 0;
  // 订阅全局点赞仓库：任意位置取消点赞后，「我赞过」列表即时移除该帖（不依赖切 Tab / onPageShow）
  private unsubLike: () => void = () => {};
  // 订阅帖子删除事件：详情页删除帖子后，当前子 Tab（发布/收藏/赞过/评论过）列表立即移除该帖
  private unsubDeletion: () => void = () => {};
  private profileShareController: CustomDialogController = new CustomDialogController({
    builder: ProfileShareSheet({
      getProfile: () => ({
        avatar: this.user.avatar ?? '',
        nickname: this.user.nickname ?? '有据用户',
        bio: this.user.bio ?? '',
        followingCount: this.followingCount,
        followerCount: this.followerCount,
        likeCount: this.totalLikes,
        profileUrl: buildProfileShareUrl(this.user.id ?? 0),
      }),
      onCopyLink: (): void => { this.copyProfileLink(); },
      onCopyCardText: (): void => { this.copyProfileShareText(); },
      onSystemShare: (): void => { this.systemShareProfile(); },
    }),
    alignment: DialogAlignment.Bottom,
    // 与帖子分享面板（ShareSheet）一致：去掉系统 Dialog 自带背景/内边距，
    // 由 ProfileShareSheet 自身提供卡片背景与圆角
    customStyle: true,
    autoCancel: true,
  });

  aboutToAppear(): void {
    // 网格列数：按当前全局断点换算（断点中心异步就绪后经 @Watch 修正）
    this.applyGridColumns();
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
          this.removeFromSegment(2, changedId);
        }
      }
    });
    // 订阅帖子删除事件：无论当前停在哪个子 Tab，只要列表含该帖即即时移除
    this.unsubDeletion = postDeletionStore.subscribe((deletedId: number): void => {
      this.removeFromAllSegments(deletedId);
    });
  }

  // 网格列数换算（断点 → 列数/模板）
  private applyGridColumns(): void {
    const cols: number = gridColumnsForBreakpoint(this.currentBreakpoint);
    this.gridColumns = cols;
    this.gridTemplate = gridColumnTemplate(cols);
  }

  // 断点变化（展开折叠屏/旋转/分屏）→ 即时换算网格列数
  onBreakpointChanged(): void {
    this.applyGridColumns();
  }

  aboutToDisappear(): void {
    this.unsubLike();
    this.unsubDeletion();
    if (this.retryTimer !== 0) {
      clearTimeout(this.retryTimer);
      this.retryTimer = 0;
    }
    if (this.profileEntranceTimer !== 0) {
      clearTimeout(this.profileEntranceTimer);
      this.profileEntranceTimer = 0;
    }
  }

  // 每次真正进入“我的”页后再揭示资料区，避免 TabContent 预创建时在后台消耗动效。
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

  // 是否已登录：userId 存在即视为已登录（未登录展示「去登录」入口，不自动跳转）
  private isLoggedIn(): boolean {
    return (this.user.id ?? 0) > 0;
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
    if (this.token !== '' && this.activeTab === 4 && this.ready && this.pagePostsOf(this.tabIdx).length === 0) {
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
      // 登出：必须清空资料/计数/列表快照。TabContent 内本组件会被保留，不清的话
      // 登出后仍显示上一账号的头像、昵称、关注/粉丝数与帖子（隐私观感问题）。
      this.user = {};
      this.postsCache = [[], [], [], []];
      this.folders = [];
      this.followingCount = 0;
      this.followerCount = 0;
      this.totalLikes = 0;
      this.page = 1;
      this.finished = false;
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
    this.ready = true;
    // 未登录不自动跳转；主页渲染「去登录」入口，由用户主动进入登录页。
    const u: User | null = getCurrentUser();
    if (!u || !u.id) {
      this.followingCount = 0;
      this.followerCount = 0;
      this.totalLikes = 0;
      this.postsCache = [[], [], [], []];
      // 未登录也要呈现资料区（显示「去登录」按钮），否则主体被透明度动画隐藏。
      this.presentProfile();
      return;
    }
    this.user = u;
    if (u.isAdmin) {
      AppStorage.setOrCreate('authIsAdmin', true);
    }
    try {
      const cached: User | null = getCurrentUser();
      if (cached && cached.id) {
        this.user = cached;
      }
    } catch (e) {
      const cached: User | null = getCurrentUser();
      if (cached) {
        this.user = cached;
      }
    }
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

  // 浏览信号到达：静默刷新「我发布」分段（stale-while-revalidate，无感知）。
  // 其余分段不显示浏览数，不刷新。
  private onPostViewSignal(): void {
    if (this.tabIdx === 0) {
      this.refresh();
    }
  }

  async refresh(): Promise<void> {
    const version: number = this.listVersion + 1;
    this.listVersion = version;
    this.page = 1;
    this.finished = false;
    this.error = '';
    // 不再清空列表：分页里每一页只读自己那份缓存，
    // 切段时先显示该分段上次的内容、拿到新数据后整体替换（stale-while-revalidate），
    // 避免每次切段都闪一次加载态；首次访问的分段缓存为空，页内自然呈现加载态。
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
    // 「我收藏 → 收藏夹」视图：不请求帖子列表（由 loadFolders 管理）
    if (this.tabIdx === 1 && this.bookmarkSubTab === 1) {
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
        this.setPagePosts(this.tabIdx, list);
      } else {
        this.setPagePosts(this.tabIdx, this.pagePostsOf(this.tabIdx).concat(list));
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

  // 标题栏分享按钮触发（信号递增 → @Watch）：分享弹层/文案/系统分享仍全部在本页完成
  onShareRequested(): void {
    this.shareProfile();
  }

  private shareProfile(): void {
    if (!EXTERNAL_SHARE_ENABLED) {
      return;
    }
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

  private async systemShareProfile(): Promise<void> {
    this.profileShareController.close();
    safeShowToast(this.getUIContext(), { message: '正在准备分享…' });
    try {
      await shareProfileToSystem(this.getUIContext(), this.user.nickname ?? '', this.user.id ?? 0);
    } catch (e) {
      safeShowToast(this.getUIContext(), { message: '分享失败，请重试' });
    }
  }

  // 主分段变更（标题栏点击 / Swiper 滑动共用）：统一由 @Watch(tabIdx) 触发加载。
  // 两条路径都只写 tabIdx（同值写入不触发 @Watch），刷新因此不会重复。
  onTabIdxChanged(): void {
    // 这里**不要**回顶。分段栏现在是列表里的普通一项，用户能点到它就说明它就在眼前，
    // scrollTo(0,0) 等于把当前滚动位白白扔掉 —— 真机实测点一次「我收藏」整屏弹回 324px
    // （分段栏 y 707→1031），就是「画面跳一下」的成因（基准 §7.6.25）。
    // 换段后列表停在原偏移是正确行为：新分段的瀑布流就地换内容，滚动深度由各自的
    // 内容高度自然钳制。
    this.refresh();
  }

  // 分页每一页只读自己那份缓存：拖动过程中相邻页显示的是它自己的内容
  private pagePostsOf(seg: number): Post[] {
    return this.postsCache[seg] ?? [];
  }

  // 整体替换数组以触发 @State 刷新（ArkTS 不观察数组元素的原地修改）
  private setPagePosts(seg: number, list: Post[]): void {
    const next: Post[][] = [[], [], [], []];
    for (let i: number = 0; i < PROFILE_SEGMENTS.length; i++) {
      next[i] = i === seg ? list : this.pagePostsOf(i);
    }
    this.postsCache = next;
  }

  private removeFromSegment(seg: number, id: number): void {
    this.setPagePosts(seg, this.pagePostsOf(seg).filter((p: Post) => p.id !== id));
  }

  // 帖子被删除：任何分段都可能含该帖，逐段移除
  private removeFromAllSegments(id: number): void {
    for (let i: number = 0; i < PROFILE_SEGMENTS.length; i++) {
      this.removeFromSegment(i, id);
    }
  }

  // 收藏 Tab：取消收藏（乐观移除 + 失败回滚）
  private async handleCancelBookmark(id: number): Promise<void> {
    try {
      await cancelBookmarkPost(id);
      this.removeFromSegment(1, id);
    } catch (e) {
      safeShowToast(this.getUIContext(), { message: (e as Error).message });
    }
  }

  // 收藏子分段切换：切到「收藏夹」时懒加载收藏夹列表，回到「帖子」时刷新收藏列表
  onBookmarkSubTabChange(): void {
    // 同主分段：不回顶。子分段栏也在列表里，回顶同样会造成一次可见弹跳。
    if (this.bookmarkSubTab === 1) {
      this.loadFolders();
    } else {
      this.refresh();
    }
  }

  // 加载我的收藏夹（幂等：已加载且非空则跳过，保持滚动/编辑后状态）
  private async loadFolders(): Promise<void> {
    if (this.foldersReady && this.folders.length > 0) {
      this.folderCount = this.folders.length;
      return;
    }
    this.foldersReady = false;
    try {
      this.folders = await listBookmarkFolders();
    } catch (e) {
      // 收藏夹加载失败：保留旧数据，不阻塞
    } finally {
      this.foldersReady = true;
      this.folderCount = this.folders.length;
    }
  }

  // 打开收藏夹详情页（夹内帖子）
  private openFolderDetail(item: BookmarkFolderItem): void {
    this.getUIContext().getRouter().pushUrl({
      url: 'pages/BookmarkFolderDetailPage',
      params: { folderId: String(item.id), folderName: item.name },
    });
  }

  // 收藏夹列表行：封面缩略 + 名称 + 条数 + 右箭头（收藏夹用列表展示，夹内帖子才是双列卡片流）
  @Builder
  folderListItem(item: BookmarkFolderItem) {
    Pressable({
      fillWidth: true,
      fullResponseRegion: true,
      action: (): void => { this.openFolderDetail(item); },
    }) {
      Row({ space: SpaceTokens.sm }) {
        if (item.cover !== null && item.cover.image !== '') {
          Image(resolveDisplayImageUrl(item.cover.image))
            .width(48)
            .height(48)
            .borderRadius(RadiusTokens.xs)
            .objectFit(ImageFit.Cover)
            .backgroundColor(ColorTokens.sunken)
        } else {
          Column() {
            Text('收藏夹')
              .fontSize(TypeTokens.caption.size).fontFamily(TypeTokens.fontFamily)
              .fontColor(ColorTokens.tertiary)
          }
          .width(48)
          .height(48)
          .justifyContent(FlexAlign.Center)
          .backgroundColor(ColorTokens.sunken)
          .borderRadius(RadiusTokens.xs)
        }
        Column({ space: 2 }) {
          Text(item.name)
            .fontSize(TypeTokens.body.size).fontFamily(TypeTokens.fontFamily)
            .fontWeight(TypeTokens.headline.weight)
            .fontColor(ColorTokens.primary)
            .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
          Text(item.count + ' 条收藏')
            .fontSize(TypeTokens.caption.size).fontFamily(TypeTokens.fontFamily)
            .fontColor(ColorTokens.secondary)
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)
        Image(resolveActionIcon('chevronRight'))
          .width(IconTokens.small)
          .height(IconTokens.small)
          // tertiary（浅 #69696E / 深 #97979E 对卡片底 5.10:1 / 5.74:1）：可操作箭头不能低于 3:1 图形下限，
          // 之前 icon + opacity(0.55) 在浅色实际只有 2.96:1（等于把可点行的入口抹掉了）。
          .fillColor(ColorTokens.tertiary)
      }
      .width('100%')
      .height(56)
      .padding({ left: SpaceTokens.sm, right: SpaceTokens.sm })
      .backgroundColor(ColorTokens.elevated)
      .border({ width: 1, color: ColorTokens.separator, style: BorderStyle.Solid })
      .borderRadius(RadiusTokens.md)
    }
  }


  @Builder
  refreshBuilder(): void {
    // ⚠️ 显隐必须属性级驱动（opacity），禁止结构条件化渲染（if 包内容）：Refresh 的指示区高度
    // 参与布局，builder 内容抽空会导致区域塌陷、内容区整体上移铺满屏幕（真机实证，HomeTab 同注释）。
    Row({ space: SpaceTokens.inline }) {
      LoadingProgress().width(IconTokens.compact).height(IconTokens.compact)
      Text('刷新中…')
        .fontSize(TypeTokens.caption.size).fontFamily(TypeTokens.fontFamily)
        .fontWeight(TypeTokens.caption.weight)
        .lineHeight(TypeTokens.caption.lineHeight)
        .letterSpacing(TypeTokens.caption.tracking)
        .fontColor(ColorTokens.secondary)
    }
    .opacity((this.isRefreshing || this.refreshIndicatorVisible) ? 1 : 0)
    .hitTestBehavior((this.isRefreshing || this.refreshIndicatorVisible) ? HitTestMode.Default : HitTestMode.None)
    // 穿底改造后 Refresh 盒子的顶边落在窗口顶部，指示器槽位整个藏在整条顶栏底下。
    // offset 只挪绘制不挪布局：槽位仍是原来那一条高（下拉时内容只让开它），
    // 图形画到「栏底之下」——topInset 到分段栏顶边，再补控件本体一条 + 自身高度，
    // 才落到磨砂区之外（真机实测：只加 topInset 时图形停在 909~959，被 106~1071 的栏体糊住）。
    // 「我收藏」再让开子分段那一条，否则图形压在 帖子/收藏夹 胶囊上（实测 1071 与 1089 重叠）。
    .offset({
      y: this.topInset + PROFILE_SEG_ROW_HEIGHT + IconTokens.compact
        + (this.tabIdx === 1 ? LayoutTokens.segmentedHeight + 2 * SpaceTokens.xs : 0),
    })
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
  profilePostCard(post: Post, seg: number): void {
    PostCard({
      post: post,
      compact: true,
      // 创作者面板基础：「我发布」网格展示浏览数（其他列表保持原样）
      showBrowses: this.tabIdx === 0,
      // 一镜到底飞行 id：前缀带分段号 —— Swiper 四页常驻，同一帖可同时挂在两个分段，
      // 不带分段号会在 ProfilePage 内部复刻跨面 id 撞车；也绝不能与首页 cardMedia- 同前缀
      mediaTag: 'profileMedia' + seg + '-',
      onOpen: () => {
        if (post.id !== undefined) {
          // 点击埋点（漏斗口径对齐，QA 审计）：此前 profile 入口不上报 click，
          // 数据面板「曝光→点击→浏览」会出现浏览>点击的倒挂观感
          trackPostEvent(post.id, 'click', 'profile');
          // 一镜到底：与首页同构的 3:4 卡面 → 飞行/阅读比例同值；圆角对齐 compact 封面 xs。
          // 共享发起器内部：Navigation 未就绪/量不到帧时兜底 router 整页，点击绝不吞。
          openPostDetailViaNav(this.getUIContext(), post, LayoutTokens.cardMediaAspectRatio,
            postDetailCoverOf(post), 'profileMedia' + seg + '-' + post.id, RadiusTokens.xs,
            LayoutTokens.cardMediaAspectRatio);
        }
      },
      onCancelBookmark: this.tabIdx === 1
        ? (id: number): void => { this.handleCancelBookmark(id); }
        : undefined,
    })
  }

  // 未登录时各分段的标题（登录引导用）：比一句通用文案更能说明「登录后能看到什么」
  private loginPromptTitle(seg: number): string {
    if (seg === 1 && this.bookmarkSubTab === 1) {
      return '登录后查看你的收藏夹';
    }
    if (seg === 0) {
      return '登录后查看你的发布';
    }
    if (seg === 1) {
      return '登录后查看你的收藏';
    }
    if (seg === 2) {
      return '登录后查看你赞过的';
    }
    return '登录后查看你的评论';
  }

  // 未登录时的分段内容：给登录引导，**不**用「还没有…」空态 ——
  // 那是在断言「你没有内容」，而真相是「我们不知道你有什么」（未登录根本拉不到数据）。
  // 布局与 PostCollectionState 一致：满高居中。
  @Builder
  loginGate(seg: number): void {
    Column() {
      EmptyState({
        icon: resolveActionIcon('lock'),
        title: this.loginPromptTitle(seg),
        message: '登录后你的发布、收藏、赞过与评论都会汇总在这里',
        actionLabel: '登录',
        onAction: (): void => { this.getUIContext().getRouter().pushUrl({ url: 'pages/LoginPage' }); },
      })
    }
    .width('100%')
    .height('100%')
    .padding({ top: this.topInset })
    .justifyContent(FlexAlign.Center)
  }

  // 分页内容：每个分段一页。每页只读自己那份缓存，因此拖动过程中相邻页显示的是它自己的内容，
  // 而不是当前分段的数据；未访问过的分段缓存为空，页内会先呈现加载态。
  // 整页一条 List（不再有 4 页 Swiper）。资料卡是它的第 0 项 —— 于是资料卡会随列表滚走、
  // 并穿到顶栏底下被栏体模糊，而不是钉死在标题栏 bottomBuilder 里占住 41% 屏高的手势盲区
  // （基准 §7.6.13b：栏体节点 [0,106][1136,1209] 之内一律抓不到滚动源）。
  // 分段栏仍留在标题栏里（它是控件行，不吃滚动是应有之义），栏体因此从 1103px 缩到约 425px。
  @Builder
  feedBody(): void {
    if (!this.isLoggedIn()) {
      this.loginGate(this.tabIdx)
    } else if (this.tabIdx === 1 && this.bookmarkSubTab === 1) {
      this.folderListBody()
    } else if (this.pagePostsOf(this.tabIdx).length === 0 && (!this.ready || this.loading)) {
      // ⚠️ 状态页必须撑满一屏（constraintSize minHeight 100%）。整页只有一条 List，
      // 切段瞬间新分段缓存为空会渲染这一支；它若只有几十 vp，列表总高骤降 → 当前滚动位
      // 被钳死 → 数据回来后内容长回去但滚动位回不来，表现为「点分段栏画面跳一下」
      // 实测 +235px 整屏位移；预热缓存（不触发这一支）后位移归零，据此定位。
      // 旧版每条 Scroll 的内层 Column 本来就有这条 minHeight，改单条 List 时丢过一次。
      Column() {
        PostCollectionState({ loading: true });
      }
      .width('100%')
      .constraintSize({ minHeight: this.viewportMinHeightVp })
      .padding({ top: SpaceTokens.xl, bottom: SpaceTokens.xl })
    } else if (this.pagePostsOf(this.tabIdx).length === 0) {
      Column() {
        PostCollectionState({
          error: this.error,
          emptyTitle: this.tabIdx === 0
            ? '还没有发布过帖子'
            : this.tabIdx === 1
              ? '还没有收藏过帖子'
                : this.tabIdx === 2 ? '还没有赞过的帖子' : '还没有评论过帖子',
          onRetry: (): void => { this.refresh(); },
        });
      }
      .width('100%')
      .constraintSize({ minHeight: this.viewportMinHeightVp })
      .padding({ top: SpaceTokens.xl, bottom: SpaceTokens.xl })
    } else {
      // refreshing 走 $$ 双向绑定（对齐 HomeTab.ets:836）：单向表达式会让内部手势态与外部
      // 变量不同源，「刷新中…」常驻收不回。onRefreshing 里不能再手动置 true。
      this.twoColumnFeed(this.tabIdx)
      this.postFooter()
    }
  }

  // 显式双列：偶数项固定左列、奇数项固定右列，首项始终位于左上角。
  // 两列独立排列，保留瀑布流的紧凑效果且不受 WaterFlow 列测量顺序影响。
  @Builder
  twoColumnFeed(seg: number): void {
    Row({ space: SpaceTokens.xs }) {
      Column({ space: SpaceTokens.xs }) {
        ForEach(this.pagePostsOf(seg).filter((_post: Post, idx: number) => idx % 2 === 0), (post: Post) => {
          this.profilePostCard(post, seg)
        }, (post: Post) => seg + '-left-' + (post.id ?? ''))
      }
      .layoutWeight(1)
      Column({ space: SpaceTokens.xs }) {
        ForEach(this.pagePostsOf(seg).filter((_post: Post, idx: number) => idx % 2 === 1), (post: Post) => {
          this.profilePostCard(post, seg)
        }, (post: Post) => seg + '-right-' + (post.id ?? ''))
      }
      .layoutWeight(1)
    }
    .width('100%')
    .alignItems(VerticalAlign.Top)
  }

  // 「我收藏 → 收藏夹」列表本体（单列行：缩略图 + 名称 + 条数 + 箭头）。
  // 原先它自带一条 Scroll，现在滚动统一交给整页那一条 List。
  @Builder
  folderListBody(): void {
    Column({ space: SpaceTokens.sm }) {
      if (!this.foldersReady) {
        Row({ space: SpaceTokens.inline }) {
          LoadingProgress().width(IconTokens.compact).height(IconTokens.compact)
          Text('加载中…')
            .fontSize(TypeTokens.caption.size).fontFamily(TypeTokens.fontFamily)
            .fontColor(ColorTokens.secondary)
        }
        .width('100%').justifyContent(FlexAlign.Center).padding({ top: SpaceTokens.xl })
      } else if (this.folders.length === 0) {
        Text('还没有收藏夹\n收藏帖子时可创建收藏夹')
          .fontSize(TypeTokens.callout.size).fontFamily(TypeTokens.fontFamily)
          .fontColor(ColorTokens.secondary)
          .textAlign(TextAlign.Center)
          .width('100%')
          .padding({ top: SpaceTokens.xl })
      } else {
        Text('共 ' + this.folders.length + ' 个收藏夹')
          .fontSize(TypeTokens.caption.size).fontFamily(TypeTokens.fontFamily)
          .fontWeight(TypeTokens.caption.weight)
          .lineHeight(TypeTokens.caption.lineHeight)
          .fontColor(ColorTokens.secondary)
          .textAlign(TextAlign.Start)
          .width('100%')
        ForEach(this.folders, (f: BookmarkFolderItem) => {
          this.folderListItem(f)
        }, (f: BookmarkFolderItem) => 'folder-list-' + String(f.id))
      }
    }
    .width('100%')
  }

  @Builder
  emptyHero(): void {
  }

  @Builder
  emptySegRows(): void {
  }

  build() {
    Refresh({ refreshing: $$this.isRefreshing, builder: this.refreshBuilder }) {
      // scroller 由 Index 创建并下发：标题栏渐变模糊（bindToScrollable）要读滚动源。
      // 必须从上游往下传，本页造好再回调上去会让首帧绑定为空、模糊慢一帧才出现。
      //
      // 视口仍从窗口原点起（资料卡能一路滑到 56vp 标题栏底下、被栏体材质糊掉 = 穿底），
      // 让位改由 contentStartOffset 承担：内容起始端挪到标题栏之下，吸顶组头也就粘在那儿。
      // 于是「资料卡 → 主分段 → 子分段 → 列表」这条已上线的视觉顺序原样保住，
      // 而资料卡不再是标题栏的一部分 —— 栏体节点之内抓不到滚动源，它留在栏里会把屏顶
      // 41% 变成手势盲区（基准 §7.6.13b）。
      List({ scroller: this.scrollers[0] }) {
        ListItem() {
          Column() {
            this.heroHeader()
          }
          .width('100%')
        }
        .width('100%')

        // 分段栏两行是**普通列表项**，跟着资料区一起滚走 —— 与官方参照一致
        //（智慧生活「我的 | 探索」那条也在 Scroll 里）。
        // 不吸顶是刻意的：吸顶就得给这一行自带表面，而内容区拿不到栏体材质
        //（systemMaterial 在内容区普通组件上不渲染），只能退 backgroundBlurStyle，
        // 于是要么实心板要么丢对比度，来回三版都收不了口（基准 §7.6.19 / §7.6.23）。
        // 让它滚走后这一行不需要任何底，官方轨道直接站在页面画布上 —— 那正是已验证
        // 与原生同档的情形。代价：滚深后要换分段得先回顶，收藏夹的管理入口也会跟着卷走。
        ListItem() {
          Column() {
            this.segHeader()
          }
          .width('100%')
        }
        .width('100%')

        ListItem() {
          Column() {
            // ⚠️ 每个分段独占一个 if 分支（分支体相同是有意的）：快速多次切换分段时，
            // 同一分支内的数据源换段更新存在丢帧——build 重跑、数据就位，但 List 子树
            // 不上屏且不再自愈（真机复现 2026-10-24，冻结后连下拉/换 Tab 都唤不回）。
            // 分支切换是结构变化，强制框架走节点重建路径，绕开同分支 diff 的更新丢失。
            if (this.tabIdx === 0) {
              this.feedBody()
            } else if (this.tabIdx === 1) {
              this.feedBody()
            } else if (this.tabIdx === 2) {
              this.feedBody()
            } else {
              this.feedBody()
            }
          }
          .width('100%')
          .padding({ left: SpaceTokens.sm, right: SpaceTokens.sm })
        }
        .width('100%')
      }
      .width('100%')
      .height('100%')
      .scrollBar(BarState.Off)
      .contentStartOffset(this.topInset)
      .onDidScroll((): void => {
        if (this.onListScroll !== undefined) {
          this.onListScroll(this.scrollers[0].currentOffset().yOffset);
        }
      })
      // 滚动停止的权威复核：万一拖尾帧的 onDidScroll 丢失，静止后开关可能停在旧值
      //（表现为松手后模糊异常消失/残留）——停止时按最终偏移重算一次，兜住所有手势路径
      .onScrollStop((): void => {
        if (this.onListScroll !== undefined) {
          this.onListScroll(this.scrollers[0].currentOffset().yOffset);
        }
      })
      .edgeEffect(EdgeEffect.Spring)
      .divider({ strokeWidth: 0 })
      // ⚠️ 不要给这条 List 挂自定义手势（PanGesture/SwipeGesture 都试过）：挂上之后快速
      // 多次切换分段，List 子树的重渲染会被框架丢弃——选中面照常切换、fetch/setPagePosts
      // 照常执行，但列表内容冻结在旧分段的渲染上且不再自愈（真机复现 2026-10-24，
      // 连手势回调里延迟写状态都救不了，手势挂载本身就是触发条件）。
      // 屏幕横滑切分段因此不可用；分段切换走 点击 + 官方分段栏拖动（indexes @Watch 同步）。
      .onReachEnd((): void => {
        this.loadMore();
      })
    }
    .onStateChange((state: RefreshStatus) => {
      // 拉拽/刷新全程显示指示器；空闲与完成回弹隐藏
      this.refreshIndicatorVisible = state === RefreshStatus.Drag
        || state === RefreshStatus.OverDrag || state === RefreshStatus.Refresh;
    })
    .onRefreshing(() => {
      this.refresh().finally(() => {
        this.isRefreshing = false;
      });
    })
    .width('100%')
    .height('100%')
    // 画布回白（1.0.1 原色）：材质画布（#F1F3F5）是为让官方 SegmentButton 轨道显层次引入的，
    // 分段栏已回迁自绘（透明轨道不吃画布层次），该适配随之退役。
    .backgroundColor(ColorTokens.canvas)
  }
}