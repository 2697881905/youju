// 帖子详情页（真实内容）：标签 → 体裁 → 标题 → 九宫格图 → 结构化字段 → 正文 → 评论区 → 底部操作栏
import { buildPageTransition, buildFadePageTransition } from '../utils/styles';
import { TypeTokens } from '../design/tokens/type';
import { ColorTokens } from '../design/tokens/color';
import { BackButton } from '../design/components/BackButton';
import { IconTokens } from '../design/tokens/icon';
import {
  getPost,
  createComment,
  upPost,
  cancelUpPost,
  bookmarkPost,
  cancelBookmarkPost,
  moveBookmarkFolder,
  listBookmarkFolders,
  createBookmarkFolder,
  deletePost,
  restorePost,
  permanentlyDeletePost,
  voteDebate,
  reportPost,
  reportComment,
  resolveDisplayImageUrl,
  PostWithComments,
  getPostStats,
  PostStats,
} from '../services/api';
import { Genre, StructuredData, ReportReason, DebateVoteResult, DmSharePayload, Comment, BookmarkFolderItem, MentionRef, MentionCandidate } from '../models/types';
import { ReportDialog } from '../components/ReportDialog';
import { FolderPickDialog } from '../components/FolderPickDialog';
import { FolderNameDialog } from '../components/FolderNameDialog';
import { PostStatsDialog } from '../components/PostStatsDialog';
import { openUserProfile, openVideoPlayer, takePostDetailId, takePostDetailCommentId, takePostDetailIntent, PostDetailIntent } from '../utils/nav';
import { safeShowToast } from '../utils/toast';
import { getUserId, getToken } from '../utils/auth';
import { startGripTracking, stopGripTracking, KEY_GRIP_ON_RIGHT } from '../utils/gripAwareness';
import { likeStore } from '../utils/likeStore';
import { postDeletionStore } from '../utils/postDeletionStore';
import { debateVoteStore, DebateVoteInfo } from '../utils/debateVoteStore';
import { structuredFieldPairs, pairValueOf, StructuredFieldPair } from '../utils/structuredFields';
import { ShareSheet } from '../components/ShareSheet';
import { ShareToDmSheet } from '../components/ShareToDmSheet';
import { buildPostShareText, buildPostShareUrl, copyToClipboard, EXTERNAL_SHARE_ENABLED, DM_SHARE_ENABLED, sharePostToSystem } from '../utils/share';
import { markClipboardIdHandled } from '../utils/clipboardJump';
import { generateShareCardBytes } from '../utils/shareCard';
import { structuredSummaryOf, StructuredSummary } from '../utils/structuredBlocks';
import { image } from '@kit.ImageKit';
import { curves, window } from '@kit.ArkUI';
import { DetailMediaCarousel } from '../components/DetailMediaCarousel';
import { ImageViewer } from '../components/ImageViewer';
import { OVERLAY_GUARD_POST_DETAIL, registerOverlayBackGuard, unregisterOverlayBackGuard } from '../utils/overlayBackGuard';
import { VideoPlayer } from '../components/VideoPlayer';
import { DetailPostHeader } from '../components/DetailPostHeader';
import { DetailPostContent } from '../components/DetailPostContent';
import { DetailCommentsSection } from '../components/DetailCommentsSection';
import { commentAnchorId } from '../components/CommentList';
import { DetailActionBar } from '../components/DetailActionBar';
import { AtMentionSuggest } from '../components/AtMentionSuggest';
import { findActiveAtMention, applyAtMention, AtMentionMatch } from '../utils/atMention';
import { barBottomReserve } from '../utils/cardTokens';
import { refreshBottomNavInset } from '../utils/navMode';
import { LayoutTokens, SpaceTokens } from '../design/tokens/space';
import { RadiusTokens } from '../design/tokens/radius';
import { FALLBACK_VIDEO_ASPECT_RATIO, normalizeVideoAspectRatio } from '../utils/video';
import { MotionCurves, MotionTokens } from '../design/tokens/motion';
import { postContentTextOf } from '../utils/postPlainText';
import { resolveActionIcon } from '../utils/actionIcons';
import { Pressable } from '../design/motion/Pressable';
import { SpringPanel } from '../design/motion/SpringPanel';
import { TopButtonMaterialModifier } from '../utils/immersiveMaterial';
import { hilog } from '@kit.PerformanceAnalysisKit';

// 分享卡片链路的诊断输出统一走 hilog：console.* 在 H7 真机不进 hilog，抓日志会看不到。
const SHARE_CARD_DOMAIN: number = 0x0000;
const SHARE_CARD_TAG: string = 'shareCard';

// ── 一镜到底的「对应节点」id（PostDetailDestination 也会引用，单一出处防漂移）──
// 真实内容里的媒体 Stack：整页缩放到「该节点宽 == 卡片宽」再展开。
export const DETAIL_HERO_ID: string = 'detailHeroMedia';
// 加载壳里的媒体占位 id：**必须与真实 hero 不同名** —— 两个分支虽然互斥，
// 但同名会被编译器判 duplicate id（发布构建实测报 WARN），且壳与真内容短暂共存时
// getFrameNodeById 会取到不确定节点。数据是异步的，转场开始那一刻只有壳，
// 量不到真实 hero 就回退量这个壳占位（宽高由飞行目标框比例 flightAspect 决定，与真实 hero 一致）。
export const DETAIL_HERO_SHELL_ID: string = 'detailHeroShellMedia';
// 详情内容滚动视口 id：通知「跳转到具体评论」时量取视口矩形，换算滚动目标偏移
const DETAIL_CONTENT_SCROLL_ID: string = 'detailContentScroll';


// 底部互动使用不可变快照。每次替换顶层 @State，保证 ArkUI 当帧重新渲染计数和选中态。
class DetailInteractionState {
  uped: boolean;
  upCount: number;
  bookmarked: boolean;
  bookmarkCount: number;

  constructor(uped: boolean, upCount: number, bookmarked: boolean, bookmarkCount: number) {
    this.uped = uped;
    this.upCount = upCount;
    this.bookmarked = bookmarked;
    this.bookmarkCount = bookmarkCount;
  }
}

interface GenreMeta {
  label: string;
  iconRes: Resource;
}

function genreMeta(genre?: Genre): GenreMeta {
  switch (genre) {
    case 'review':
      return { label: '测评报告', iconRes: $r('app.media.genre_review') };
    case 'pitfall':
      return { label: '避坑指南', iconRes: $r('app.media.genre_pitfall') };
    case 'tutorial':
      return { label: '实操教程', iconRes: $r('app.media.genre_tutorial') };
    case 'debate':
      return { label: '辩论投票', iconRes: $r('app.media.genre_debate') };
    case 'share':
      return { label: '经验分享', iconRes: $r('app.media.genre_share') };
    default:
      return { label: '经验分享', iconRes: $r('app.media.genre_share') };
  }
}

// 帖子详情「主体视图」：router 壳（pages/DetailPage）与 Navigation 壳（pages/PostDetailDestination）共用。
// 差异点全部收敛为注入回调：Navigation 壳负责返回和二级跳转，router 壳使用系统 router。
@Component
export struct PostDetailView {
  // —— 壳注入（Navigation 壳 pages/PostDetailDestination 使用）——
  // navMode=true：返回/二级跳走 Navigation 回调；navMode=false 使用 router。
  @Prop navMode: boolean = false;
  onBack?: () => void = undefined;                    // Navigation 壳：navStack.pop()
  onOpenProfile?: (userId: number) => void = undefined; // Navigation 壳：pushPathByName('UserProfile')
  // 点视频 → 独立播放器页：Navigation 壳注入（pushPathByName('VideoPlayer')）；
  // 未注入（router 壳）时本页自行 router.pushUrl('pages/VideoPlayerPage')。
  onOpenVideo?: (url: string, poster: string) => void = undefined;
  // Navigation 壳 + 一镜到底：真媒体首帧画出来时回调一次。
  // 目的地页据此把「卡片截图」淡出——截图顶住媒体位，直到真内容能接手，避免中途露灰底/空白。
  onHeroReady?: () => void = undefined;
  // 一镜到底：真媒体首帧是否已就绪（navMode 下就地决定 hero 的可见性）
  @State mediaReady: boolean = false;
  private heroReadyFired: boolean = false;
  @State postId: string = '';
  // 「一镜到底」意图：卡片进入时携带的展示快照（cover 非空才有一镜到底）
  @State intent: PostDetailIntent | null = null;
  // 「通知 → 跳转到具体评论」：待定位评论 id（>0 时加载完滚动定位并短暂高亮）
  @State targetCommentId: number = 0;
  @State highlightCommentId: number = 0;
  // 详情内容滚动器：定位评论时按目标偏移平滑滚动
  private detailScroller: Scroller = new Scroller();
  @State post: PostWithComments | null = null;
  @State fields: StructuredFieldPair[] = [];
  @State images: string[] = [];
  @State videoUrl: string = '';
  @State videoCover: string = '';
  @State videoAspectRatio: number = FALLBACK_VIDEO_ASPECT_RATIO;
  @State activeImageIndex: number = 0;
  @State loading: boolean = true;
  @State error: string = '';
  @State interaction: DetailInteractionState = new DetailInteractionState(false, 0, false, 0);
  @State upPending: boolean = false;
  @State bookmarkPending: boolean = false;
  @State upFeedbackVersion: number = 0;
  @State bookmarkFeedbackVersion: number = 0;
  @State commenting: boolean = false;
  @State commentText: string = '';
  // 楼中楼回复目标：replyTargetId>0 时当前输入处于「回复 @xxx」态（清零即退出）
  @State replyTargetId: number = 0;
  @State replyTargetName: string = '';
  // 评论输入内显式选择的 @提及（精确 userId，随发送透传，后端防重名误通知）
  private commentMentionRefs: MentionRef[] = [];
  @State commentReportId: number = 0;
  @State viewingImage: string = ''; // 全屏看图
  @State shareCardPreview: image.PixelMap | null = null; // 分享卡图 App 内预览
  // ===== 长按结构化内容小菜单：复制正文（自绘浮层，替代 bindContextMenu）=====
  // 标题与正文 Text 已开启系统文本选择复制（copyOption，见 DetailPostHeader / DetailPostContent），
  // 长按它们走原生选择；「复制正文」长按菜单只挂结构化卡片（DetailPostContent 内部），
  // 不与正文文本选择的长按竞争。bindContextMenu 会被子组件 onClick 竞争掉（同 ChatView
  // 消息菜单的结论），故用自绘遮罩浮层。
  @State contentMenuVisible: boolean = false;
  // 帖子操作面板（作者侧）：页内浮层，替代系统 ActionSheet —— 后者只支持 title/icon/action，
  // 选项样式完全不可定制（观感简陋且与项目设计语言脱节）。
  @State postActionsVisible: boolean = false;
  @State contentMenuX: number = 0; // 菜单卡片左上角 x（内容区 Stack 本地坐标，按按压点定位）
  @State contentMenuY: number = 0; // 菜单卡片左上角 y
  // 内容区 Stack 的全局原点与尺寸：按压点全局坐标 → 本地坐标换算 & 边界钳制依赖它
  private contentAreaGlobalX: number = 0;
  private contentAreaGlobalY: number = 0;
  private contentAreaWidth: number = 0;
  private contentAreaHeight: number = 0;
  // 顶部避让状态栏：用「构造时即就位」的全局值（Index 启动时写入 AppStorage），
  // 不能本页异步测量——一镜到底在转场开始那一刻量「媒体位」的落点，若 padding
  // 晚一帧才从 0 变为状态栏高度，整页会在量测之后整体下移一个状态栏高度：
  // 海报落点偏高、交接真图时"瞬移下来"（本轮修的残余偏移）。
  // 与 LoginView / 圈子页等 20+ 页保持一致（同一 AppStorage 键）。
  @StorageLink('statusBarHeight') statusBarHeight: number = 0;
  // 顶栏（返回/分享/更多）驻留 Navigation 标题栏后的动作按钮材质（沉浸光感官方生效区域）。
  // 低版本（API < 26）门禁不通过 → 材质自动跳过，按钮保持原透明图标观感。
  private detailActionMaterial: TopButtonMaterialModifier = new TopButtonMaterialModifier();
  // 系统栏测量来源（挂着 avoidAreaChange 监听，页面销毁时注销）
  private navSourceWin: window.Window | undefined = undefined;
  // 收藏夹选择（收藏时归类）
  @State folderPickFolders: BookmarkFolderItem[] = [];
  private folderPickController: CustomDialogController | null = null;
  private folderNameDialog: CustomDialogController | null = null;
  // 帖子数据面板（作者本人）
  @State postStats: PostStats | null = null;
  @State statsLoading: boolean = false;
  @State statsError: string = '';
  // 帖子数据面板：页内覆盖层（if 分支渲染），由本状态驱动挂载/卸载。
  // 不用 CustomDialog —— 动态 new CustomDialogController 的 builder 传 @Link 会闪退，
  // 传 @Prop 又不随父组件刷新（两个坑都踩过，见 PostStatsDialog 头注释）。
  @State statsPanelShow: boolean = false;
  private statsPostId: number = 0;
  // 监听登录账号：切换账号/登出时重新加载本帖，以服务器为准校准点赞/收藏/投票态（避免 likeStore 单例残留串号）
  @StorageLink('authUserId') @Watch('onAccountSwitch') accountId: string = '';
  // 智感握姿：原始握持手状态（gripAwareness 写入；1=左手 2=右手 0=未握持/不支持）
  @StorageProp('holdingHandStatus') @Watch('onHoldingHandStatusChanged') holdingHandStatus: number = 0;
  // 当前整组贴边侧：true=居右（右手握持）；用于去重，避免同侧重复触发动画
  private gripSideIsRight: boolean = false;

  private get pid(): number {
    return Number(this.postId);
  }

  private authorId(): number | undefined {
    if (typeof this.post?.user?.id === 'number') {
      return this.post.user.id;
    }
    return typeof this.post?.userId === 'number' ? this.post.userId : undefined;
  }

  private isDeletedAuthor(): boolean {
    return this.post?.user?.deleted === true || this.post?.user?.nickname === '已注销用户';
  }

  private authorName(): string {
    if (this.isDeletedAuthor()) {
      return '已注销用户';
    }
    return this.post?.user?.nickname ?? (this.authorId() !== undefined ? '贴主' : '匿名用户');
  }

  private authorAvatar(): string {
    return this.isDeletedAuthor() ? '' : (this.post?.user?.avatar ?? '');
  }

  // 一镜到底（navMode）下，详情媒体框的**阅读**比例（转场结束后长期生效）：
  // 整页缩放展开需要「媒体高度在转场期间稳定」，否则首图解码出真实比例时会二次跳位；
  // 普通 router 入口返回 0，媒体按真实比例展示。
  private readingAspect(): number {
    if (!this.navMode || this.intent === null || !(this.intent.aspect > 0)) {
      return 0;
    }
    return this.intent.aspect;
  }

  // 一镜到底的**飞行目标框**比例（转场进行时生效）：= 卡面比例，让截图落点严丝合缝。
  // 与阅读比例解耦（如卡堆：卡面 4:3、阅读 3:4，同一个值无法两全）；
  // 未提供时回退阅读比例。真媒体首帧就绪后，媒体框再从该比例平滑过渡到阅读比例
  // （图片轮播见 DetailMediaCarousel 的 applyReadingAspect，视频见 videoBoxAspect）。
  private flightAspect(): number {
    const fa: number = this.intent?.flightAspect ?? 0;
    return fa > 0 ? fa : this.readingAspect();
  }

  private openAuthorProfile(): void {
    const authorId: number | undefined = this.authorId();
    if (authorId === undefined || this.isDeletedAuthor()) {
      return;
    }
    if (this.onOpenProfile !== undefined) {
      this.onOpenProfile(authorId);
      return;
    }
    openUserProfile(authorId);
    this.getUIContext().getRouter().pushUrl({ url: 'pages/UserProfilePage' });
  }

  // 独立播放器页（与作者主页同款双壳分发）：Navigation 壳注入 onOpenVideo 走主栈 push，
  // router 壳经 utils/nav 意图通道 + router.pushUrl。播放器页是独立页面，不在此处叠浮层。
  private openPlayerPage(): void {
    if (this.videoUrl.length === 0) {
      return;
    }
    if (this.onOpenVideo !== undefined) {
      this.onOpenVideo(this.videoUrl, this.videoCover);
      return;
    }
    openVideoPlayer(this.videoUrl, this.videoCover);
    this.getUIContext().getRouter().pushUrl({ url: 'pages/VideoPlayerPage' });
  }

  // 统一返回入口：模态/Navigation 壳走 onBack（动画关闭/栈 pop），router 壳普通返回
  private navigateBack(): void {
    if (this.onBack !== undefined) {
      this.onBack();
      return;
    }
    this.getUIContext().getRouter().back();
  }

  // 帖子举报弹窗控制器
  private reportController: CustomDialogController = new CustomDialogController({
    builder: ReportDialog({
      targetType: 'post',
      targetId: 0,
      onSubmit: (reason: ReportReason, description: string) => {
        this.submitReport(reason, description);
      },
    }),
    alignment: DialogAlignment.Center,
    customStyle: false,
  });

  // 评论举报弹窗控制器
  private commentReportController: CustomDialogController = new CustomDialogController({
    builder: ReportDialog({
      targetType: 'comment',
      targetId: 0,
      onSubmit: (reason: ReportReason, description: string) => {
        this.submitCommentReport(reason, description);
      },
    }),
    alignment: DialogAlignment.Center,
    customStyle: false,
  });

  // 分享面板控制器（底部拉起式菜单：关注头像直发私信/更多/复制链接/复制标题/系统分享/分享卡片）
  private shareController: CustomDialogController = new CustomDialogController({
    builder: ShareSheet({
      getPayload: (): DmSharePayload | null => this.buildSharePayload(),
      onShared: (receiverId: number, nickname: string): void => {
        this.bumpDmSignal();
      },
      onShareCard: (): void => {
        this.doShareCard();
      },
      onCopyLink: (): void => {
        this.doShareLink();
      },
      onCopyTitle: (): void => {
        this.doShareTitle();
      },
      onSystemShare: (): void => {
        this.doSystemShare();
      },
      onShareToDm: (): void => {
        this.onShareToDm();
      },
    }),
    alignment: DialogAlignment.Bottom,
    customStyle: true,
    autoCancel: true,
  });

  // 分享到私信：联系人选择弹窗（底部 bottom sheet）
  private shareDmController: CustomDialogController = new CustomDialogController({
    builder: ShareToDmSheet({
      getPayload: (): DmSharePayload | null => this.buildSharePayload(),
      onShared: (receiverId: number, nickname: string): void => {
        this.bumpDmSignal();
      },
    }),
    alignment: DialogAlignment.Bottom,
    customStyle: true,
    autoCancel: true,
  });

  // 分享私信成功后自增 dmRefreshSignal，驱动消息页会话列表与红点刷新
  private bumpDmSignal(): void {
    const cur: number = (AppStorage.get<number>('dmRefreshSignal') ?? 0) as number;
    AppStorage.setOrCreate('dmRefreshSignal', cur + 1);
  }

  aboutToAppear(): void {
    // 读取系统栏高度（全屏布局下顶部内容避让 + 底部栏高随导航模式实时变化）
    this.loadWindowInsets();
    this.intent = takePostDetailIntent();
    this.postId = takePostDetailId().trim();
    // 通知「跳转到这条评论」：读取待定位评论 id（0 = 普通进入，不定位）
    this.targetCommentId = takePostDetailCommentId();
    // 智感握姿：订阅握持手原始状态（holdingHandStatus），由本页派生 gripOnRight 并带过渡提交
    startGripTracking();
    // @StorageProp 初始化不触发 @Watch：进入页面时若系统已握持左手/右手
    // （握姿事件早于本页触发并残留 holdingHandStatus），onHoldingHandStatusChanged 不会回调，
    // gripOnRight 会停在默认假值 → 头部/输入框不迁移到正确一侧。这里按当前状态派生一次。
    const right: boolean = this.holdingHandStatus === 2;
    if (this.gripSideIsRight !== right) {
      this.gripSideIsRight = right;
      AppStorage.setOrCreate<boolean>(KEY_GRIP_ON_RIGHT, right);
    }
    this.load();
    // 页内覆盖层（图片查看器 / 分享卡预览 / 数据面板）的返回拦截：
    // 它们是 if 分支渲染的页内图层，不由路由或 Navigation 托管，系统返回手势不会先关它们，
    // 而是直接 pop 掉整页 —— 首页卡片走 openDetailViaNav 把详情页 push 进 Navigation 栈，
    // 表现就是「看图后返回一下回到首页」。登记守卫，交由两套壳的返回拦截先消费一次。
    registerOverlayBackGuard(OVERLAY_GUARD_POST_DETAIL,
      (): boolean => this.hasPageOverlay(),
      (): void => { this.closeTopPageOverlay(); });
  }

  // 读取系统栏高度（全屏布局下顶部内容需避让），并监听 avoidAreaChange：
  // 三键/手势导航切换会触发回调 → 重新测量 → AppStorage 更新 → 底部功能栏高度实时响应。
  private async loadWindowInsets(): Promise<void> {
    try {
      const ctx = this.getUIContext().getHostContext();
      if (!ctx) {
        return;
      }
      const win = await window.getLastWindow(ctx);
      this.navSourceWin = win;
      this.applyWindowInsets(win);
      win.on('avoidAreaChange', this.handleAvoidAreaChanged);
    } catch (e) {
      // 读取失败维持已有效果（不阻塞页面渲染）
    }
  }

  private handleAvoidAreaChanged = (_opts: window.AvoidAreaOptions): void => {
    if (this.navSourceWin) {
      this.applyWindowInsets(this.navSourceWin);
    }
  };

  private applyWindowInsets(win: window.Window): void {
    try {
      const sys = win.getWindowAvoidArea(window.AvoidAreaType.TYPE_SYSTEM);
      const indicator = win.getWindowAvoidArea(window.AvoidAreaType.TYPE_NAVIGATION_INDICATOR);
      this.statusBarHeight = this.getUIContext().px2vp(sys.topRect.height);
      AppStorage.setOrCreate<number>('navBarHeight',
        Math.max(this.getUIContext().px2vp(sys.bottomRect.height), this.getUIContext().px2vp(indicator.bottomRect.height)));
      // navBarHeight 变了，底部避让量随之重算（三键/手势切换或分屏时导航区高度变化）
      refreshBottomNavInset();
    } catch (e) {
      // 单独一次测量失败不影响已生效值
    }
  }

  aboutToDisappear(): void {
    // 注销返回守卫：回调闭包持有本页实例，不成对注销会拖住已销毁的页面
    unregisterOverlayBackGuard(OVERLAY_GUARD_POST_DETAIL);
    // 智感握姿退订（详情页关闭即退订，官方功耗建议）
    stopGripTracking();
    if (this.navSourceWin) {
      try {
        this.navSourceWin.off('avoidAreaChange', this.handleAvoidAreaChanged);
      } catch (e) {
        // 注销失败可忽略
      }
      this.navSourceWin = undefined;
    }
  }

  // 握持手变化 → 整组换边。对齐/justifyContent 是瞬变布局属性，
  // 状态变化必须包进 animateTo，头部内容才会连续滑动到对侧而非瞬跳。
  onHoldingHandStatusChanged(): void {
    // 仅单手状态驱动：2=右手→整组居右，1=左手→整组居左；离手/双手保持当前侧
    const right: boolean = this.holdingHandStatus === 2;
    if (right === this.gripSideIsRight) {
      return;
    }
    this.gripSideIsRight = right;
    this.getUIContext().animateTo({
      duration: 350,
      curve: curves.interpolatingSpring(0, 1, 170, 17),
    }, () => {
      AppStorage.setOrCreate<boolean>(KEY_GRIP_ON_RIGHT, right);
    });
  }

  async load(): Promise<void> {
    const raw: string = this.postId;
    if (raw === '') {
      this.loading = false;
      this.error = '帖子参数缺失(raw empty)';
      return;
    }
    const idNum: number = parseInt(raw, 10);
    if (isNaN(idNum)) {
      this.loading = false;
      this.error = '帖子参数缺失(raw=' + JSON.stringify(raw) + ',type=' + typeof raw + ')';
      return;
    }
    this.loading = true;
    this.error = '';
    try {
      const p = await getPost(idNum);
      if (!p) {
        this.error = '帖子不存在或已下架';
        return;
      }
      this.post = p;
      // 依据后端返回的 myUp/myBookmark 初始化互动态，确保已点赞/已收藏帖进入详情时
      // 高亮态正确（避免初始 false 导致再次点击「顶」重复 upPost 造成 upCount 膨胀）。
      this.interaction = new DetailInteractionState(
        p.myUp ?? false,
        p.upCount ?? 0,
        p.myBookmark ?? false,
        p.bookmarkCount ?? 0,
      );
      // 校准全局点赞仓库：详情页打开时以服务器为准，回写后首页卡片也即时同步
      if (p.id !== undefined) {
        likeStore.syncFromServer(p.id, this.interaction.uped, this.interaction.upCount);
      }
      // 浏览信号：详情已打开（后端 viewCount 已去重自增），列表页收到后静默刷新卡片浏览数
      AppStorage.setOrCreate('postViewSignal', Date.now());
      this.fields = this.buildFields(p);
      this.images = this.imagesOf(p);
      this.videoUrl = resolveDisplayImageUrl(p.videoUrl ?? '');
      this.videoCover = resolveDisplayImageUrl(p.videoCover ?? '');
      this.videoAspectRatio = normalizeVideoAspectRatio(p.videoAspectRatio ?? FALLBACK_VIDEO_ASPECT_RATIO);
      this.activeImageIndex = 0;
      // 辩论投票数据初始化
      debateVoteStore.syncFromServer(
        p.id ?? 0,
        (p as Record<string, Object>).planAVotes as number ?? 0,
        (p as Record<string, Object>).planBVotes as number ?? 0,
        (p as Record<string, Object>).myVote as string ?? '',
      );
    } catch (e) {
      this.error = (e as Error).message;
    } finally {
      this.loading = false;
      // 一镜到底兜底：视频等形态没有「首图就绪」事件，给个上限无条件交接，
      // 避免卡片截图长期压住媒体位（正常情况下轮播 onFirstReady 会先到，此处即空跑）。
      if (this.navMode && this.post !== null) {
        setTimeout((): void => { this.markHeroReady(); }, 900);
      }
      // 通知「跳转到这条评论」：内容渲染后滚动定位（量测晚于数据赋值，方法内自带重试）
      if (this.post !== null && this.targetCommentId > 0) {
        this.locateTargetComment(0);
      }
    }
  }

  // 通知「跳转到这条评论」：量取评论锚点与滚动视口矩形，换算目标偏移后平滑滚动，
  // 并把该条短暂高亮。评论随详情接口一起返回，加载完成即可定位；组件量测晚于数据赋值，
  // 按「320ms 起、失败重试 2 次」的节奏补偿；始终量不到（评论不在返回窗口内）则放弃，
  // 停留在帖子顶部，与旧行为一致（不阻断、不报错）。
  private locateTargetComment(attempt: number): void {
    const cid: number = this.targetCommentId;
    if (cid <= 0) {
      return;
    }
    setTimeout((): void => {
      // 目标已变（页面重载/二次跳转）→ 放弃本次定位，避免滚到错误位置
      if (this.targetCommentId !== cid) {
        return;
      }
      let deltaVp: number = Number.NaN;
      try {
        const utils = this.getUIContext().getComponentUtils();
        const commentRect = utils.getRectangleById(commentAnchorId(cid));
        const scrollRect = utils.getRectangleById(DETAIL_CONTENT_SCROLL_ID);
        if (commentRect && scrollRect) {
          deltaVp = this.getUIContext().px2vp(
            (commentRect.windowOffset?.y ?? 0) - (scrollRect.windowOffset?.y ?? 0)
          );
        }
      } catch (e) {
        deltaVp = Number.NaN;
      }
      if (isNaN(deltaVp)) {
        if (attempt < 2) {
          this.locateTargetComment(attempt + 1);
        }
        return;
      }
      // 评论当前在视口内的相对偏移 + 已滚动量 = 目标绝对偏移；上留 12vp 呼吸空间
      const target: number = Math.max(0, this.detailScroller.currentOffset().yOffset + deltaVp - 12);
      this.detailScroller.scrollTo({
        xOffset: 0,
        yOffset: target,
        animation: { duration: 360, curve: Curve.EaseOut },
      });
      this.targetCommentId = 0;
      this.highlightCommentId = cid;
      // 高亮只做「一眼定位」，随后撤下（瞬时切换，不做颜色动画）
      setTimeout((): void => {
        if (this.highlightCommentId === cid) {
          this.highlightCommentId = 0;
        }
      }, 2600);
    }, attempt === 0 ? 320 : 480);
  }

  // 账号切换/登出：已登录则重新加载本帖，以服务器为准校准点赞/收藏/投票态；
  // 避免 likeStore 单例残留上个账号的 liked/upCount 导致串号
  onAccountSwitch(): void {
    if (getToken() !== '') {
      this.load();
    }
  }

  // 结构化字段的展示投影：字段表、读取与空值过滤都在 utils/structuredFields 的唯一定义处。
  private buildFields(p: PostWithComments): StructuredFieldPair[] {
    return structuredFieldPairs(p.structuredData, p.genre);
  }

  // 取某方案（方案A/方案B）的介绍文字，用于把方案介绍合并进投票卡片
  private planTextOf(planLabel: string): string {
    return pairValueOf(this.fields, planLabel);
  }

  private imagesOf(p: PostWithComments): string[] {
    const source: string[] = p.images ?? [];
    const images: string[] = [];
    for (let index = 0; index < source.length && index < 9; index++) {
      const image: string = source[index];
      if (image.length > 0) {
        images.push(resolveDisplayImageUrl(image));
      }
    }
    // 无图时回退显示封面（含纯文字海报封面：coverOnlyTextPoster），保证详情页与卡片封面一致
    if (images.length === 0 && typeof p.coverImage === 'string' && p.coverImage.length > 0) {
      images.push(resolveDisplayImageUrl(p.coverImage));
    }
    return images;
  }

  private setInteraction(uped: boolean, upCount: number, bookmarked: boolean, bookmarkCount: number): void {
    this.interaction = new DetailInteractionState(
      uped,
      Math.max(0, upCount),
      bookmarked,
      Math.max(0, bookmarkCount),
    );
  }

  async onUp(): Promise<void> {
    if (this.upPending || !this.post || this.post.id === undefined) {
      return;
    }
    const id = this.post.id;
    const previous: DetailInteractionState = this.interaction;
    const willUp = !previous.uped;
    this.upPending = true;
    this.setInteraction(willUp, previous.upCount + (willUp ? 1 : -1), previous.bookmarked, previous.bookmarkCount);
    this.upFeedbackVersion = this.upFeedbackVersion + 1;
    // 同步写入全局仓库：首页卡片随详情点赞即时变化
    const prev = likeStore.applyOptimistic(id, willUp);
    try {
      if (willUp) {
        await upPost(id);
      } else {
        await cancelUpPost(id);
      }
    } catch (e) {
      this.setInteraction(previous.uped, previous.upCount, previous.bookmarked, previous.bookmarkCount);
      likeStore.revert(id, prev);
      safeShowToast(this.getUIContext(),{ message: '操作失败，请先登录' });
    } finally {
      this.upPending = false;
    }
  }

  async onBookmark(): Promise<void> {
    if (this.bookmarkPending || !this.post || this.post.id === undefined) {
      return;
    }
    const id = this.post.id;
    const previous: DetailInteractionState = this.interaction;
    const willMark = !previous.bookmarked;
    if (!willMark) {
      // 取消收藏：保持原逻辑
      this.bookmarkPending = true;
      this.setInteraction(previous.uped, previous.upCount, false, previous.bookmarkCount - 1);
      this.bookmarkFeedbackVersion = this.bookmarkFeedbackVersion + 1;
      try {
        await cancelBookmarkPost(id);
      } catch (e) {
        this.setInteraction(previous.uped, previous.upCount, previous.bookmarked, previous.bookmarkCount);
        safeShowToast(this.getUIContext(), { message: '操作失败，请先登录' });
      } finally {
        this.bookmarkPending = false;
      }
      return;
    }
    // 收藏：点击即完成收藏（未分类），随即弹出收藏夹选择供可选归类（关闭弹窗=不放进收藏夹）。
    // 不再「先选夹再收藏」——收藏主流程不依赖弹窗；收藏夹列表与收藏请求并行拉取，弹窗尽快出现。
    this.bookmarkPending = true;
    this.setInteraction(previous.uped, previous.upCount, true, previous.bookmarkCount + 1);
    this.bookmarkFeedbackVersion = this.bookmarkFeedbackVersion + 1;
    const foldersTask: Promise<BookmarkFolderItem[] | null> = listBookmarkFolders()
      .then((list: BookmarkFolderItem[]): BookmarkFolderItem[] | null => list)
      .catch((): BookmarkFolderItem[] | null => null);
    try {
      await bookmarkPost(id);
    } catch (e) {
      this.setInteraction(previous.uped, previous.upCount, previous.bookmarked, previous.bookmarkCount);
      safeShowToast(this.getUIContext(), { message: '操作失败，请先登录' });
      this.bookmarkPending = false;
      return;
    }
    this.bookmarkPending = false;
    // 收藏夹列表加载失败不算收藏失败：帖子已进未分类，仅跳过归类弹窗
    const folders: BookmarkFolderItem[] | null = await foldersTask;
    if (folders !== null) {
      this.folderPickFolders = folders;
      this.openFolderPick();
    }
  }

  // 归类结果：>0 移入指定收藏夹（弹窗不列「未分类」行，关闭弹窗即保持未分类，无需请求）
  private async onFolderPick(folderId: number): Promise<void> {
    if (folderId <= 0) {
      return;
    }
    const id = this.post?.id;
    if (id === undefined || !this.interaction.bookmarked) {
      return; // 弹窗期间已取消收藏：忽略归类
    }
    try {
      await moveBookmarkFolder(id, folderId);
    } catch (e) {
      safeShowToast(this.getUIContext(), { message: (e as Error).message });
    }
  }

  // 新建收藏夹（从收藏夹选择弹窗进入）
  private onNewFolderFromPick(): void {
    this.folderNameDialog = new CustomDialogController({
      builder: FolderNameDialog({
        title: '新建收藏夹',
        onSubmit: (name: string): void => {
          this.onCreateFolderAndBookmark(name);
        },
      }),
      autoCancel: true,
      customStyle: true,
    });
    this.folderNameDialog.open();
  }

  // 新建收藏夹后归入该夹（帖子已在收藏态，走移动；弹窗期间恰已取消收藏则仅建夹不归入）
  private async onCreateFolderAndBookmark(name: string): Promise<void> {
    const id = this.post?.id;
    if (id === undefined) {
      return;
    }
    try {
      const folder = await createBookmarkFolder(name);
      if (this.interaction.bookmarked) {
        await moveBookmarkFolder(id, folder.id);
      }
    } catch (e) {
      safeShowToast(this.getUIContext(), { message: (e as Error).message });
    }
  }

  private openFolderPick(): void {
    this.folderPickController = new CustomDialogController({
      builder: FolderPickDialog({
        folders: this.folderPickFolders,
        afterBookmark: true,
        onPick: (folderId: number): void => { this.onFolderPick(folderId); },
        onNewFolder: (): void => { this.onNewFolderFromPick(); },
      }),
      autoCancel: true,
      customStyle: true,
    });
    this.folderPickController.open();
  }

  onShare(): void {
    if (!EXTERNAL_SHARE_ENABLED && !DM_SHARE_ENABLED) {
      return;
    }
    this.shareController.open();
  }

  // 分享到私信：先校验登录，再打开联系人选择弹窗
  private onShareToDm(): void {
    if (getToken() === '') {
      safeShowToast(this.getUIContext(), { message: '请先登录后再分享' });
      return;
    }
    this.shareController.close();
    this.shareDmController.open();
  }

  // 构造分享到私信的帖子摘要负载（封面取详情页展示首图，正文截断为摘要）
  private buildSharePayload(): DmSharePayload | null {
    const post = this.post;
    if (!post || post.id === undefined) {
      return null;
    }
    const summaryRaw: string = post.content ?? '';
    const summary: string = summaryRaw.length > 100 ? summaryRaw.substring(0, 100) + '…' : summaryRaw;
    const cover: string = this.images.length > 0
      ? this.images[0]
      : (post.coverImage ? resolveDisplayImageUrl(post.coverImage) : '');
    return {
      postId: post.id,
      title: post.title ?? '有据帖子',
      summary: summary,
      coverImage: cover,
      authorName: this.authorName(),
      authorId: this.authorId() ?? 0,
      authorAvatar: this.authorAvatar(),
      categoryLabel: (post.tags ?? []).length > 0
        ? (post.tags ?? [])[0] + ' · ' + genreMeta(post.genre).label.replace('报告', '')
        : genreMeta(post.genre).label,
      commentCount: post.commentCount ?? 0,
      upCount: post.upCount ?? this.interaction.upCount,
    };
  }

  // 复制抖音式分享文案（帖主 + 标题 + 标签 + 链接）到剪贴板
  private doShareLink(): void {
    if (!this.post || this.post.id === undefined) {
      return;
    }
    try {
      copyToClipboard(buildPostShareText(this.authorName(), this.post.title ?? '', this.post.tags ?? [], this.post.id));
      // 应用内刚复制过的链接不再参与剪贴板检查：避免自己复制完回前台被提示打开同一帖子
      markClipboardIdHandled(this.post.id);
      safeShowToast(this.getUIContext(), { message: '文案已复制，去粘贴给好友吧' });
    } catch (e) {
      safeShowToast(this.getUIContext(), { message: '复制失败，请重试' });
    }
    this.shareController.close();
  }

  // 复制帖子标题到剪贴板
  private doShareTitle(): void {
    if (!this.post) {
      return;
    }
    try {
      copyToClipboard(this.post.title ?? '有据帖子');
      safeShowToast(this.getUIContext(), { message: '标题已复制' });
    } catch (e) {
      safeShowToast(this.getUIContext(), { message: '复制失败，请重试' });
    }
    this.shareController.close();
  }

  // ===== 长按结构化内容 → 复制正文 =====

  private closeContentMenu(): void {
    this.contentMenuVisible = false;
  }

  // 长按定位：菜单显示在长按内容的**上方**（卡片底边距按压点 10vp，不遮住被长按的文字），
  // 水平中心对准按压点；贴近内容区顶部放不下时翻转到按压点下方；均钳制在内容区边界内。
  private openContentMenu(event: GestureEvent): void {
    // 兜底中心点（fingerList 理论上必有值，防御性处理）
    let gx: number = this.contentAreaGlobalX + this.contentAreaWidth / 2;
    let gy: number = this.contentAreaGlobalY + this.contentAreaHeight / 2;
    if (event.fingerList.length > 0) {
      gx = event.fingerList[0].globalX;
      gy = event.fingerList[0].globalY;
    }
    // 全局坐标 → 内容区 Stack 本地坐标
    const lx: number = gx - this.contentAreaGlobalX;
    const ly: number = gy - this.contentAreaGlobalY;
    // 单行菜单卡片（行高 42 + 上下内边距 8）
    const cardW: number = 148;
    const cardH: number = 50;
    const gap: number = 10;
    const maxX: number = Math.max(8, this.contentAreaWidth - cardW - 8);
    const maxY: number = Math.max(8, this.contentAreaHeight - cardH - 8);
    this.contentMenuX = Math.max(8, Math.min(maxX, lx - cardW / 2));
    let y: number = ly - cardH - gap;
    if (y < 8) {
      // 上方放不下（长按位置贴近内容区顶部）：翻转到按压点下方
      y = ly + gap;
    }
    this.contentMenuY = Math.max(8, Math.min(maxY, y));
    this.contentMenuVisible = true;
  }

  // 正文纯文本：结构化信息（V2 文档优先，旧帖回退字段投影）+ 正文，不含标题
  private postContentText(): string {
    if (!this.post) {
      return '';
    }
    return postContentTextOf(
      this.post.content ?? '',
      this.post.structuredDocument ?? null,
      this.fields,
    );
  }

  private copyPostContent(): void {
    this.closeContentMenu();
    const text: string = this.postContentText();
    if (text.length === 0) {
      safeShowToast(this.getUIContext(), { message: '没有可复制的内容' });
      return;
    }
    try {
      copyToClipboard(text);
      safeShowToast(this.getUIContext(), { message: '正文已复制，去粘贴吧' });
    } catch (e) {
      safeShowToast(this.getUIContext(), { message: '复制失败，请重试' });
    }
  }

  // 系统分享占位：真实域名确定后接入 @ohos.application.SystemShareKit 系统分享面板
  private async doSystemShare(): Promise<void> {
    this.shareController.close();
    if (!this.post || this.post.id === undefined) {
      return;
    }
    // 封面图取详情页展示的第一张图（封面或首图）；无图则纯文本分享
    const cover: string = this.images.length > 0 ? this.images[0] : '';
    safeShowToast(this.getUIContext(), { message: '正在准备分享…' });
    try {
      await sharePostToSystem(this.getUIContext(), this.post.id, this.post.title ?? '', cover);
    } catch (e) {
      safeShowToast(this.getUIContext(), { message: '分享失败，请重试' });
    }
  }

  // 分享卡片：生成卡图并在 App 内全屏预览（不依赖系统分享/相册弹窗）。
  // 带走方式：复制链接到微信（自动渲染落地卡片）或系统截图保存卡图。
  private async doShareCard(): Promise<void> {
    this.shareController.close();
    if (!this.post || this.post.id === undefined) {
      return;
    }
    const cover: string = this.images.length > 0 ? this.images[0] : '';
    safeShowToast(this.getUIContext(), { message: '正在生成分享卡片…' });
    try {
      const bytes: ArrayBuffer = await generateShareCardBytes(
        this.getUIContext(),
        this.post.title ?? '',
        this.shareCardExcerpt(),
        this.authorName(),
        resolveDisplayImageUrl(this.authorAvatar()),
        cover,
      );
      const source: image.ImageSource = image.createImageSource(bytes);
      try {
        this.shareCardPreview = source.createPixelMapSync();
      } finally {
        // ImageSource 只用于解码一次，立即释放（否则每点一次分享都留一份句柄）
        source.release().catch((): void => {});
      }
    } catch (e) {
      hilog.error(SHARE_CARD_DOMAIN, SHARE_CARD_TAG, 'DetailPage 分享卡片异常: %{public}s',
        String((e as Error).message ?? e));
      safeShowToast(this.getUIContext(), { message: '卡片生成失败，请重试' });
    }
  }

  private shareCardExcerpt(): string {
    if (this.post === null) return '';
    const summary: StructuredSummary | null = structuredSummaryOf(
      this.post.structuredData, this.post.genre, this.post.structuredDocument);
    if (summary === null) return this.post.content ?? '';
    let text: string = summary.label + '：' + summary.primary;
    if (summary.secondary.length > 0) text += ' · ' + summary.secondary.join(' · ');
    return text;
  }

  private closeShareCardPreview(): void {
    if (this.shareCardPreview !== null) {
      this.shareCardPreview.release().catch((): void => {});
      this.shareCardPreview = null;
    }
  }

  // 是否有页内覆盖层打开（返回手势要先关它们，而不是退出详情页）
  private hasPageOverlay(): boolean {
    return this.viewingImage.length > 0 || this.shareCardPreview !== null || this.statsPanelShow
      || this.contentMenuVisible || this.postActionsVisible;
  }

  // 关掉最上层那个覆盖层。层级从高到低：图片查看器(999) → 分享卡预览(200) → 数据面板(210) → 长按菜单。
  private closeTopPageOverlay(): void {
    if (this.viewingImage.length > 0) {
      this.viewingImage = '';
      return;
    }
    if (this.shareCardPreview !== null) {
      this.closeShareCardPreview();
      return;
    }
    if (this.contentMenuVisible) {
      this.closeContentMenu();
      return;
    }
    if (this.statsPanelShow) {
      this.statsPanelShow = false;
      return;
    }
    this.postActionsVisible = false;
  }

  // 辩论投票：乐观更新票数
  private async onDebateVote(choice: string): Promise<void> {
    if (!this.post || this.post.id === undefined) {
      return;
    }
    const postId: number = this.post.id;
    const current: DebateVoteInfo | undefined = debateVoteStore.get(postId);
    if (current?.choice === choice) {
      return;
    }
    // 广播后由正文组件写入自己的 @State，投票数字和进度会在请求返回前立即更新。
    const previous: DebateVoteInfo = debateVoteStore.applyOptimistic(postId, choice);
    try {
      // 投票请求失败自动重试一次（自愈模拟器 rport 偶发抖动），仍失败才回滚
      await this.voteWithRetry(postId, choice);
      // 该请求只作为提交确认。当前后端/连接组合可能返回事务提交前的聚合票数，
      // 成功时回写它会把已显示的即时结果覆盖掉；下一次进入详情页再由 load() 校准。
    } catch (e) {
      debateVoteStore.revert(postId, previous);
      safeShowToast(this.getUIContext(), { message: (e as Error).message });
    }
  }

  // 投票请求：最多尝试 2 次，任一次成功即返回最新票数；全部失败才抛出
  private async voteWithRetry(postId: number, choice: string): Promise<DebateVoteResult> {
    let lastErr: Error = new Error('投票失败，请重试');
    for (let i = 0; i < 2; i++) {
      try {
        return await voteDebate(postId, choice);
      } catch (e) {
        lastErr = e as Error;
      }
    }
    throw lastErr;
  }

  // 删除帖子：二次确认 → 移入废纸篓 → toast + 返回
  private onDeletePost(): void {
    this.getUIContext().showAlertDialog({
      title: '删除帖子？',
      message: '帖子会先移入废纸篓，可在“我的”中恢复。',
      primaryButton: { value: '取消', action: (): void => {} },
      secondaryButton: { value: '确认删除', fontColor: $r('app.color.semantic_red'), action: async (): Promise<void> => {
        try {
          if (!this.post || this.post.id === undefined) return;
          await deletePost(this.post.id);
          // 广播删除事件：所有订阅的列表宿主（首页/我的/他人主页）立即移除该帖，无需刷新
          postDeletionStore.notifyDeleted(this.post.id);
          safeShowToast(this.getUIContext(), { message: '已移入废纸篓' });
          this.navigateBack();
        } catch (e) {
          safeShowToast(this.getUIContext(), { message: (e as Error).message });
        }
      } },
    });
  }

  // 恢复帖子（仅废纸篓中的帖子）：二次确认 → 恢复 → 返回列表
  private onRestorePost(): void {
    if (!this.post || this.post.id === undefined) return;
    const id: number = this.post.id;
    this.getUIContext().showAlertDialog({
      title: '恢复帖子？',
      message: '恢复后帖子会重新出现在你的主页与信息流中。',
      primaryButton: { value: '取消', action: (): void => {} },
      secondaryButton: { value: '恢复', action: (): void => {
        restorePost(id).then((): void => {
          safeShowToast(this.getUIContext(), { message: '帖子已恢复' });
          this.navigateBack();
        }).catch((e: Error): void => {
          safeShowToast(this.getUIContext(), { message: e.message });
        });
      } },
    });
  }

  // 彻底删除（仅废纸篓中的帖子）：不可恢复，同时广播删除事件清列表
  private onPermanentlyDelete(): void {
    if (!this.post || this.post.id === undefined) return;
    const id: number = this.post.id;
    this.getUIContext().showAlertDialog({
      title: '彻底删除帖子？',
      message: '彻底删除后无法恢复，帖子相关评论和互动也会被清除。',
      primaryButton: { value: '取消', action: (): void => {} },
      secondaryButton: { value: '彻底删除', fontColor: ColorTokens.danger, action: (): void => {
        permanentlyDeletePost(id).then((): void => {
          postDeletionStore.notifyDeleted(id);
          safeShowToast(this.getUIContext(), { message: '帖子已彻底删除' });
          this.navigateBack();
        }).catch((e: Error): void => {
          safeShowToast(this.getUIContext(), { message: e.message });
        });
      } },
    });
  }

  // 弹出帖子操作菜单：作者可见数据面板 +（恢复·彻底删除 | 删除帖子），他人可见举报+分享。
  // 作者侧用 ActionSheet —— AlertDialog 最多两个按钮，容纳不下「数据面板 + 恢复 + 彻底删除」。
  private showPostActions(): void {
    if (!this.post) return;
    const isOwner: boolean = this.post.userId === getUserId();
    if (isOwner) {
      // 帖子在废纸篓中（软删标记非空）时，作者菜单给出「恢复 / 彻底删除」；
      // 否则维持「删除帖子」（移入废纸篓）。删除入口已从废纸篓列表卡片收进此处。
      // 选项集由 postInTrash() 在面板内分支，这里只负责打开。
      this.postActionsVisible = true;
    } else if (EXTERNAL_SHARE_ENABLED) {
      this.getUIContext().showAlertDialog({
        title: '操作',
        message: '',
        primaryButton: {
          value: '举报该帖子',
          fontColor: $r('app.color.semantic_red'),
          action: (): void => { this.reportController.open(); },
        },
        secondaryButton: {
          value: '分享',
          action: (): void => { this.onShare(); },
        },
      });
    } else {
      this.getUIContext().showAlertDialog({
        title: '操作',
        message: '',
        primaryButton: {
          value: '举报该帖子',
          fontColor: $r('app.color.semantic_red'),
          action: (): void => { this.reportController.open(); },
        },
      });
    }
  }

  // 打开帖子数据面板（作者本人）：重置旧数据防串帖 → 挂载覆盖层 → 拉取
  private showPostStats(): void {
    const postId: number = this.post?.id ?? this.pid;
    if (isNaN(postId) || postId <= 0) {
      safeShowToast(this.getUIContext(), { message: '无效帖子ID' });
      return;
    }
    // 先清掉上一帖的数据：覆盖层经 @Prop 同步，带着旧数据挂载会串帖
    this.postStats = null;
    this.statsLoading = true;
    this.statsError = '';
    this.statsPostId = postId;
    this.statsPanelShow = true;
    this.loadPostStats(postId);
  }

  // 拉取聚合数据（也供面板内「重试」复用，不重挂覆盖层）
  private loadPostStats(postId: number): void {
    this.statsLoading = true;
    this.statsError = '';
    getPostStats(postId).then((s: PostStats): void => {
      this.postStats = s;
      this.statsLoading = false;
    }).catch((e: Error): void => {
      this.statsLoading = false;
      this.statsError = (e as Error).message;
    });
  }

  // 提交帖子举报
  private async submitReport(reason: ReportReason, description: string): Promise<void> {
    // 优先用服务端已加载帖子的权威 id，兜底 URL 解析 id（pid）。
    // 从分享/落地/通知等特殊入口进入时 URL id 可能解析失败，服务器端校验会报"无效帖子ID"。
    const targetId: number = (typeof this.post?.id === 'number' && this.post.id > 0) ? this.post.id : this.pid;
    if (isNaN(targetId) || targetId <= 0) {
      this.reportController.close();
      safeShowToast(this.getUIContext(), { message: '无效帖子ID' });
      return;
    }
    try {
      await reportPost(targetId, { reason, description: description || undefined });
      this.reportController.close();
      safeShowToast(this.getUIContext(), { message: '举报已提交，我们会在48小时内处理' });
    } catch (e) {
      const msg: string = (e as Error).message;
      this.reportController.close();
      safeShowToast(this.getUIContext(), { message: msg });
    }
  }

  // 打开评论举报弹窗
  private openCommentReport(commentId: number): void {
    this.commentReportId = commentId;
    this.commentReportController.open();
  }

  // 提交评论举报
  private async submitCommentReport(reason: ReportReason, description: string): Promise<void> {
    try {
      await reportComment(this.commentReportId, { reason, description: description || undefined });
      this.commentReportController.close();
      safeShowToast(this.getUIContext(), { message: '举报已提交，我们会在48小时内处理' });
    } catch (e) {
      const msg: string = (e as Error).message;
      this.commentReportController.close();
      safeShowToast(this.getUIContext(), { message: msg });
    }
  }

  // —— 评论输入 @提及 编辑辅助 ——
  // 文尾正在输入「@昵称」时显示候选（与发帖页/私信同策略：只看文本，不额外要求输入态）。
  // 此前这里有 `if (!this.commenting) return null` 守卫，但 commenting 全文件只在
  // onReplyComment（点「回复评论」）时置 true —— 直接在底部输入框聚焦打字时它仍是 false，
  // 于是候选永远不弹。改为只看文本：commentText 为空时 findActiveAtMention 自身返回 null，
  // 不需要额外的输入态守卫。
  private commentMentionMatch(): AtMentionMatch | null {
    return findActiveAtMention(this.commentText);
  }

  private commentMentionKeyword(): string {
    const m = this.commentMentionMatch();
    return m !== null ? m.keyword : '';
  }

  // 点选候选：回填「@昵称 」并记录精确 userId（随发送透传，后端按此发通知）
  private pickCommentMention(c: MentionCandidate): void {
    const m = this.commentMentionMatch();
    if (m === null) {
      return;
    }
    const nickname: string = c.nickname.trim();
    if (nickname.length === 0) {
      return;
    }
    const nextText: string = applyAtMention(this.commentText, m.atIndex, nickname);
    if (nextText.length > 2000) {
      safeShowToast(this.getUIContext(), { message: '评论最多 2000 字' });
      return;
    }
    this.commentText = nextText;
    let exists: boolean = false;
    for (const r of this.commentMentionRefs) {
      if (r.userId === c.id) {
        exists = true;
        break;
      }
    }
    if (!exists) {
      const next: MentionRef[] = this.commentMentionRefs.slice();
      next.push({ name: nickname, userId: c.id });
      this.commentMentionRefs = next;
    }
  }

  private clearCommentMentions(): void {
    this.commentMentionRefs = [];
  }

  async onSendComment(): Promise<void> {
    const text = this.commentText.trim();
    if (!text || !this.post || this.post.id === undefined) {
      return;
    }
    try {
      // 楼中楼：处于回复态（replyTargetId>0）时携带 parentId，回复后清除回复目标回到普通评论态
      const parentId: number | undefined = this.replyTargetId > 0 ? this.replyTargetId : undefined;
      const mentionRefs: MentionRef[] | undefined =
        this.commentMentionRefs.length > 0 ? this.commentMentionRefs : undefined;
      await createComment(this.post.id, { content: text, parentId: parentId, mentions: mentionRefs });
      this.commentText = '';
      this.commenting = false;
      this.replyTargetId = 0;
      this.replyTargetName = '';
      this.clearCommentMentions();
      await this.load();
    } catch (e) {
      // 透传后端错误 message（如"内容含敏感词，请修改后重试"）
      safeShowToast(this.getUIContext(), { message: (e as Error).message });
    }
  }

  // 楼中楼：点击评论下「回复」进入回复态（以目标评论为父评论）
  private onReplyComment(comment: Comment): void {
    const name: string = (comment.user?.nickname ?? '') || (comment.userId !== undefined ? String(comment.userId) : '');
    this.replyTargetId = comment.id ?? 0;
    this.replyTargetName = name;
    this.commenting = true;
  }

  // 取消回复态（返回普通评论输入）
  private onCancelReply(): void {
    this.replyTargetId = 0;
    this.replyTargetName = '';
    this.clearCommentMentions();
  }

  // 详情页「分层进入」转场：媒体区先到（无延迟的缩放淡入），标题/正文/评论区按
  // delay 错峰进入（共享动势 + 错峰）。仅动 transform/opacity，不参与布局属性动画。
  // duration 从 320ms 缩短到 280ms，translate 从 10px 减到 6px，让各层入场更紧凑轻盈。
  private animLayerEnter(delay: number): TransitionEffect {
    // 一镜到底（navMode）：真内容是「长镜头」的落点，它自己再滑一下就会被看成"跳一下"，
    // 因此只保留透明度、去掉 6vp 位移与错峰。router 入口无长镜头，保留完整入场动势。
    if (this.navMode) {
      return TransitionEffect.OPACITY
        .animation({ duration: 200, curve: MotionCurves.decelerate, delay: delay });
    }
    return TransitionEffect.OPACITY
      .animation({ duration: 280, curve: MotionCurves.decelerate, delay: delay })
      .combine(TransitionEffect.translate({ y: 6 })
        .animation({ duration: 280, curve: MotionCurves.decelerate, delay: delay }));
  }

  // 详情页媒体区：以缩放起步（与列表卡片视觉动量一致的共享动势），无延迟先到
  // duration 从 320ms 缩短到 280ms，让媒体区更快就位。
  private animMediaEnter(): TransitionEffect {
    return TransitionEffect.OPACITY
      .animation({ duration: 280, curve: MotionCurves.decelerate })
      .combine(TransitionEffect.scale({ x: MotionTokens.enterScale, y: MotionTokens.enterScale })
        .animation({ duration: 280, curve: MotionCurves.decelerate }));
  }

  private mediaEnterTransition(): TransitionEffect {
    // 一镜到底由目的地页整体变形负责媒体动势，详情媒体本身不能再缩放一次。
    if (this.navMode) {
      return TransitionEffect.OPACITY.animation({ duration: 1, curve: MotionCurves.linear });
    }
    return this.animMediaEnter();
  }

  // 视频媒体框比例：飞行段用「飞行目标框」比例（与截图落点一致）；
  // 首帧就绪（mediaReady，随 markHeroReady 的 animateTo 一起）后过渡到阅读比例 /
  // 视频真实比例 —— 视频不接管轮播的 initialAspect，这里显式分阶段。
  private videoBoxAspect(): number {
    const phaseAspect: number = this.mediaReady ? this.readingAspect() : this.flightAspect();
    return phaseAspect > 0 ? phaseAspect : this.videoAspectRatio;
  }

  // 媒体进入：仅透明度淡入（无缩放），避免加载完成切媒体时"缩一下"。
  @Builder
  videoFace(): void {
    Column() {
      VideoPlayer({
        src: this.videoUrl,
        poster: this.videoCover,
        // 视频帖点击媒体区/播放按钮 → 独立播放器页（不再内联播放暂停、不再页内浮层）
        onOpen: (): void => { this.openPlayerPage(); },
        // 关键接线：视频帖此前没有任何「媒体可显示」信号，hero 只能等 900ms 兜底计时器
        // （计时器还在 getPost 返回之后才起算）→ 进详情后媒体位空白约 1 秒。
        // 现在封面解码完成 / 视频首帧就绪 / 出错任一发生即放行（VideoPlayer 内已做只发一次；
        // markHeroReady 自身幂等；转场侧的截图交接有 MIN 300ms 下限保护，早调用不会抢跳）。
        onReady: (): void => { this.markHeroReady(); },
      })
    }
    .width('100%')
    .aspectRatio(this.videoBoxAspect())
    .backgroundColor(Color.Black)
    .borderRadius(12)
    .clip(true)
    .transition(this.mediaEnterTransition())
  }

  @Builder
  carouselFace(): void {
    DetailMediaCarousel({
      images: this.images,
      activeIndex: $activeImageIndex,
      // 飞行段锁「飞行目标框」比例（截图落点严丝合缝）；
      // 首图就绪后轮播自己平滑切到 readingAspect（竖图不被压横）
      initialAspect: this.flightAspect(),
      readingAspect: this.readingAspect(),
      onFirstReady: (): void => { this.markHeroReady(); },
      onOpenImage: (url: string): void => { this.viewingImage = url; },
    })
      .transition(this.mediaEnterTransition())
  }

  @Builder
  mediaSlot(): void {
    if (this.videoUrl.length > 0) {
      this.videoFace()
    } else if (this.images.length > 0) {
      this.carouselFace()
    }
  }

  @Builder
  private contentMenuRow(label: string, action: () => void): void {
    Text(label)
      .fontSize(TypeTokens.body.size).fontFamily(TypeTokens.fontFamily)
      .fontWeight(TypeTokens.headline.weight)
      .fontColor(ColorTokens.primary)
      .width('100%')
      .height(42)
      .textAlign(TextAlign.Center)
      .onClick(() => { action(); })
  }

  // 长按结构化内容菜单浮层：全屏透明遮罩（点击关闭）+ 卡片显示在长按内容上方 + 轻量进场动效
  @Builder
  private contentActionSheet(): void {
    Column() {
      Column() {
        this.contentMenuRow('复制正文', (): void => { this.copyPostContent(); })
      }
      .width(148)
      .padding({ top: SpaceTokens.xs, bottom: SpaceTokens.xs })
      .backgroundColor(ColorTokens.elevated)
      .borderRadius(RadiusTokens.md)
      .clip(true)
      .shadow({ radius: 20, color: ColorTokens.barShadow, offsetY: 6 })
      // 按压点定位（openContentMenu 已把坐标钳制在内容区边界内，不溢出屏幕）
      .position({ x: this.contentMenuX, y: this.contentMenuY })
      // 进/出场：淡入 + 轻微缩放（0.94→1），只动 transform/opacity 保证性能
      .transition(
        TransitionEffect.opacity(0)
          .combine(TransitionEffect.scale({ x: 0.94, y: 0.94 }))
          .animation({ duration: 180, curve: MotionCurves.standard })
      )
    }
    .width('100%')
    .height('100%')
    // 透明遮罩：视觉上无灰色覆盖，但仍捕获点击以关闭菜单
    .backgroundColor(Color.Transparent)
    // 盖过底部互动栏（zIndex 1）：菜单打开时点互动栏先关菜单，不误触发点赞/评论
    .zIndex(2)
    .onClick((): void => { this.closeContentMenu(); })
  }

  // 帖子在废纸篓中（软删标记非空）→ 作者菜单给的选项集不同
  private postInTrash(): boolean {
    return (this.post?.deletedAt ?? '').length > 0;
  }

  private closePostActions(): void {
    this.postActionsVisible = false;
  }

  // 操作项：标题 + 副标题，语言与 PublishModeSheet 的条目一致
  //（标题 body 字号 + headline 字重；副标题 caption/tertiary；危险项标题用 danger 色）。
  @Builder
  private postActionRow(label: string, subtitle: string, danger: boolean, action: () => void): void {
    Pressable({
      fillWidth: true,
      visualHeight: 60,
      touchTargetHeight: LayoutTokens.minTouchTarget,
      action: (): void => {
        this.closePostActions();
        action();
      },
    }) {
      Row({ space: SpaceTokens.md }) {
        Column({ space: SpaceTokens.inlineTight }) {
          Text(label)
            .fontSize(TypeTokens.body.size).fontFamily(TypeTokens.fontFamily)
            .fontWeight(TypeTokens.headline.weight)
            .lineHeight(TypeTokens.body.lineHeight)
            .fontColor(danger ? ColorTokens.danger : ColorTokens.primary)
          Text(subtitle)
            .fontSize(TypeTokens.caption.size).fontFamily(TypeTokens.fontFamily)
            .fontWeight(TypeTokens.caption.weight)
            .lineHeight(TypeTokens.caption.lineHeight)
            .fontColor(ColorTokens.tertiary)
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)
      }
      .width('100%')
      .height(60)
      .padding({ left: SpaceTokens.base, right: SpaceTokens.base })
      .alignItems(VerticalAlign.Center)
      .backgroundColor(Color.Transparent)
    }
  }

  // 帖子操作面板：暗色遮罩（点空白关闭）+ 居中实色面板（SpringPanel solid，与数据面板/发布方式
  // 同材质：elevated 底 + separator 发丝描边 + cardAmbient 阴影，不透明、承载文字可读）。
  // 选项集：未删除 = 数据面板 / 删除帖子；已删除 = 数据面板 / 恢复帖子 / 彻底删除。
  @Builder
  private postActionsSheet(): void {
    Stack({ alignContent: Alignment.Center }) {
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor('rgba(0,0,0,0.35)')
        .onClick((): void => { this.closePostActions(); })

      SpringPanel({ panelWidth: 344, panelPadding: SpaceTokens.lg, solid: true }) {
        Column({ space: SpaceTokens.base }) {
          Row() {
            Text('操作')
              .fontSize(TypeTokens.headline.size).fontFamily(TypeTokens.fontFamilySerif)
              .fontWeight(TypeTokens.headline.weight)
              .lineHeight(TypeTokens.headline.lineHeight)
              .fontColor(ColorTokens.primary)
            Blank().layoutWeight(1)
            Pressable({
              visualHeight: LayoutTokens.segmentedHeight,
              touchTargetHeight: LayoutTokens.minTouchTarget,
              action: (): void => { this.closePostActions(); },
            }) {
              Image(resolveActionIcon('close'))
                .width(IconTokens.compact)
                .height(IconTokens.compact)
                .fillColor(ColorTokens.icon)
            }
          }
          .width('100%')
          .alignItems(VerticalAlign.Center)

          // 选项容器：共用一条发丝描边 + lg 圆角，条目间 Divider（与 PublishModeSheet 同构，
          // 也与分段栏「1 条容器描边 + 内部无边框」的语言一致）
          Column() {
            this.postActionRow('数据面板', '查看浏览与互动数据', false, (): void => { this.showPostStats(); })
            Divider().height(LayoutTokens.hairlineWidth).color(ColorTokens.separator)
            if (this.postInTrash()) {
              this.postActionRow('恢复帖子', '重新出现在主页与信息流', false, (): void => { this.onRestorePost(); })
              Divider().height(LayoutTokens.hairlineWidth).color(ColorTokens.separator)
              this.postActionRow('彻底删除', '删除后无法恢复', true, (): void => { this.onPermanentlyDelete(); })
            } else {
              this.postActionRow('删除帖子', '先移入废纸篓，可再恢复', true, (): void => { this.onDeletePost(); })
            }
          }
          .width('100%')
          .backgroundColor(Color.Transparent)
          .border({ width: 1, color: ColorTokens.separator, style: BorderStyle.Solid })
          .borderRadius(RadiusTokens.lg)
          .clip(true)
        }
        .width('100%')
      }
    }
    .width('100%')
    .height('100%')
    .zIndex(220)
  }

  // 一镜到底（navMode）下 hero 的可见性：真媒体首帧就绪前**保持透明**，
  // 让下层的卡片截图透出来顶住媒体位。若直接显示，轮播图自带的 sunken 灰底会盖住截图，
  // 观感就是「卡片图 → 灰块 → 照片」闪一下（本轮修的跳动主因）。
  // 走 router 入口（非 navMode）没有截图层，必须立即显示。
  private heroVisible(): boolean {
    return !this.navMode || this.mediaReady;
  }

  private heroOpacity(): number {
    return this.heroVisible() ? 1 : 0;
  }

  // 真媒体首帧就绪（轮播 onFirstReady / 兜底超时）：淡入真媒体并通知目的地页淡出卡片截图。
  private markHeroReady(): void {
    if (this.heroReadyFired) {
      return;
    }
    this.heroReadyFired = true;
    this.getUIContext().animateTo(
      { duration: 180, curve: MotionCurves.decelerate },
      (): void => { this.mediaReady = true; });
    if (this.onHeroReady !== undefined) {
      this.onHeroReady();
    }
  }

  // 详情接口还在加载时，先用卡片意图绘制同尺寸的标题/媒体锚点。
  // 这样「一镜到底」在转场开始那一刻就有可量的对应节点（否则量不到 → 动画不出现），
  // 也不会先闪一下 LoadingProgress；真实内容返回后复用相同布局，媒体帧不会跳位。
  @Builder
  transitionLoadingShell(): void {
    if (this.intent !== null && this.flightAspect() > 0) {
      Column({ space: 16 }) {
        DetailPostHeader({
          title: this.intent.title,
          genreLabel: genreMeta(this.intent.genre as Genre).label,
          genreIcon: genreMeta(this.intent.genre as Genre).iconRes,
          tags: this.intent.tags,
          authorName: this.intent.authorName,
          authorAvatar: this.intent.authorAvatar,
          createdAt: this.intent.createdAt,
          onOpenAuthor: (): void => {},
        })
        // 这个盒子只承担一个职责：给一镜到底提供**可量的「对应节点」**
        // （转场开始那一刻就要量它的宽高与位置，量不到动画整体不出现）。
        // 因此它必须与真实 hero 同比例（飞行目标框比例 flightAspect），但**不能画任何东西**：
        // 卡片截图位于内容层**之下**，这里一旦有底色就会把截图盖住
        // （观感变成「卡片图 → 灰块 → 照片」）；不加 opacity 也免得赌
        // 「完全透明是否被渲染层裁掉」这种实现细节——空盒子照样能量。
        // id 用独立的 DETAIL_HERO_SHELL_ID：与真实 hero 不同名（防 duplicate id）。
        Stack()
          .width('100%')
          .aspectRatio(this.flightAspect())
          .id(DETAIL_HERO_SHELL_ID)
      }
      .padding(16)
      .width('100%')
    } else {
      Column() {
        LoadingProgress().width(28).height(28)
        Text('加载中…')
          .fontSize(13).fontFamily($r('app.string.font_family'))
          .fontColor($r('app.color.text_secondary'))
          .margin({ top: 10 })
      }
      .layoutWeight(1)
      .width('100%')
      .justifyContent(FlexAlign.Center)
    }
  }

  // 页面进入转场：模态/Navigation 壳由外层负责；普通 router 入口保留轻量进入动画。
  private pageEnterTransition(): TransitionEffect {
    const i: PostDetailIntent | null = this.intent;
    if (i !== null) {
      return buildFadePageTransition()
        .combine(TransitionEffect.scale({ x: 0.985, y: 0.985 })
          .animation({ duration: 280, curve: MotionCurves.decelerate }));
    }
    return buildPageTransition();
  }

  // Navigation 壳：不叠加页面级转场（无动画直切；NavDestination 系统转场已在跳转侧关闭）
  private navNoopTransition(): TransitionEffect {
    return TransitionEffect.OPACITY
      .animation({ duration: 1, curve: MotionCurves.linear });
  }

  // 顶栏迁入标题栏后的栏高：状态栏 + 上间距(sm) + 44 触控行 + 下间距(xs)。
  // 与 detailTitleBar 的行内边距严格同源；内容固定（图标按钮，无折行/媒体等不定因素），
  // 按教程 Step 3「固定内容用 token 表达式直算」，无需 onAreaChange 实测回写。
  private detailTitleBarHeight(): number {
    return this.statusBarHeight + SpaceTokens.sm + LayoutTokens.minTouchTarget + SpaceTokens.xs;
  }

  // 标题栏：原 DetailToolbar（返回 + 分享 + 更多）整体驻留于此。
  // 为什么迁：通用属性 systemMaterial（沉浸光感）只在 Navigation/NavDestination 标题栏
  // 生效，内容区设置不报错但完全不渲染（官方 FAQ 生效范围），详见
  // docs/tutorial-titlebar-immersive-light.md。结构约定：
  // - 根节点单容器；全屏布局下标题栏不代为避让状态栏 → 根容器手动下移（避让只此一处，
  //   内容区根容器不再加状态栏 padding）；
  // - 分享/更多是原生 Row 表面：材质直接 attributeModifier 挂 44×44 节点，lg 圆角给材质
  //   定形（低版本无材质时透明圆角无观感差异）；按钮无自绘底/边框/阴影，无需让位处理；
  // - 返回键 BackButton 是尾随闭包组件（Pressable），闭包后不能再接属性链 → 材质无法从
  //   外部挂到内层表面，与圈子详情标题栏同口径：纯图标无自绘样式，交由应用级 enable 自动材质。
  @Builder
  detailTitleBar(): void {
    Column() {
      Row({ space: SpaceTokens.sm }) {
        BackButton({ action: (): void => { this.navigateBack(); } })
        // 居中标题位保留为纯撑开空间：让右侧动作组继续贴右边缘（与原 DetailToolbar 一致）
        Blank()
        Row({ space: SpaceTokens.xs }) {
          // 每个动作独立 44×44 命中区，图标 24vp（与原 DetailToolbar 相同的规格）
          Row() {
            Image(resolveActionIcon('share'))
              .width(IconTokens.standard)
              .height(IconTokens.standard)
              .fillColor(ColorTokens.icon)
              .draggable(false)
          }
          .width(LayoutTokens.minTouchTarget)
          .height(LayoutTokens.minTouchTarget)
          .justifyContent(FlexAlign.Center)
          .alignItems(VerticalAlign.Center)
          .borderRadius(RadiusTokens.lg)
          .attributeModifier(this.detailActionMaterial)
          .accessibilityText('分享')
          .onClick((): void => { this.onShare(); })

          Row() {
            Image(resolveActionIcon('more'))
              .width(IconTokens.standard)
              .height(IconTokens.standard)
              .fillColor(ColorTokens.icon)
              .draggable(false)
          }
          .width(LayoutTokens.minTouchTarget)
          .height(LayoutTokens.minTouchTarget)
          .justifyContent(FlexAlign.Center)
          .alignItems(VerticalAlign.Center)
          .borderRadius(RadiusTokens.lg)
          .attributeModifier(this.detailActionMaterial)
          .accessibilityText('更多操作')
          .onClick((): void => { this.showPostActions(); })
        }
        .height(LayoutTokens.minTouchTarget)
        .alignItems(VerticalAlign.Center)
      }
      .width('100%')
      .padding({ left: SpaceTokens.sm, right: SpaceTokens.sm, top: SpaceTokens.sm, bottom: SpaceTokens.xs })
    }
    .width('100%')
    // 手动避让状态栏（含在栏高内）；与行内边距分放两层节点，避免同节点 padding 互相覆盖
    .padding({ top: this.statusBarHeight })
  }

  build() {
    Stack() {
      Navigation() {
        Column() {
          this.detailBody()
        }
        .width('100%')
        .height('100%')
      }
      .title({
        builder: this.detailTitleBar,
        height: this.detailTitleBarHeight(),
      }, { barStyle: BarStyle.STANDARD, backgroundColor: ColorTokens.canvas })
      .width('100%')
      .height('100%')

      // —— 全屏覆盖层（if 分支渲染）：必须盖过标题栏与状态栏 ——
      // STANDARD 标题栏为占位式，Navigation 内容区从栏下开始：覆盖层若留在内容区会被压到
      // 栏下、盖不住顶栏（且顶栏返回键会在看图时绕过覆盖层返回拦截），故全部迁到 Navigation
      // 之外作为 Stack 兄弟节点（叠放，不挤占布局）。根容器的状态栏避让已移交标题栏
      // （避让只此一处）→ 覆盖层内容自行补回状态栏下移量，保持与迁移前一致的内容落点
      // （数据面板为居中卡片，无需补偿）。

      // 分享卡图全屏预览（无系统依赖，可截图/复制链接带走）
      if (this.shareCardPreview !== null) {
        Stack({ alignContent: Alignment.TopEnd }) {
          Column() {
            Text('分享卡片 · 生成好了')
              .fontSize(16).fontFamily($r('app.string.font_family'))
              .fontWeight(FontWeight.Bold)
              .fontColor(Color.White)
              .margin({ top: 8 })
            Text('把它发给朋友：复制链接到微信，或截图保存这张卡片')
              .fontSize(12).fontFamily($r('app.string.font_family'))
              .fontColor('rgba(255,255,255,0.7)')
              .margin({ top: 6 })
            Image(this.shareCardPreview)
              .width('88%')
              .aspectRatio(3 / 4)
              .objectFit(ImageFit.Contain)
              .borderRadius(12)
              .margin({ top: 12 })
            Row({ space: 12 }) {
              Button('关闭')
                .layoutWeight(1)
                .backgroundColor('rgba(255,255,255,0.14)')
                .fontColor(Color.White)
                .onClick(() => { this.closeShareCardPreview(); })
              Button('复制链接')
                .layoutWeight(1)
                .backgroundColor('#34C759')
                .fontColor(Color.White)
                .onClick(() => {
                  if (this.post?.id !== undefined) {
                    copyToClipboard(buildPostShareUrl(this.post.id));
                    safeShowToast(this.getUIContext(), { message: '链接已复制，去微信粘贴即可自动显示卡片' });
                  }
                })
            }
            .width('88%')
            .margin({ top: 16, bottom: 32 })
          }
          // 整组内容（标题+卡图+按钮）在预览层内垂直居中：卡图 88% 宽在竖屏上只占一半高度，
          // 顶对齐会让下方留出一大块空（右上角 X 由 Stack 的 TopEnd 单独定位，不受影响）
          .width('100%')
          .height('100%')
          .justifyContent(FlexAlign.Center)
          .padding({ top: 24, bottom: 24 })

          Text('X')
            .fontSize(18).fontFamily($r('app.string.font_family'))
            .fontColor(Color.White)
            .width(40).height(40)
            .textAlign(TextAlign.Center)
            .margin({ top: 20, right: 12 })
            .onClick(() => { this.closeShareCardPreview(); })
        }
        .width('100%')
        .height('100%')
        .backgroundColor('#E8000000')
        .padding({ top: this.statusBarHeight })
        .zIndex(200)
      }

      // 全屏图片查看器：支持双击/双指缩放、拖动平移、单击或按钮关闭。
      // 外层补状态栏 padding：关闭按钮 position(top:16) 的落点与迁移前一致（避让已由
      // 标题栏接管，组件内不再自带该偏移）。
      if (this.viewingImage.length > 0) {
        ImageViewer({
          url: this.viewingImage,
          onClose: (): void => { this.viewingImage = ''; },
        })
          .padding({ top: this.statusBarHeight })
      }

      // 帖子数据面板（作者侧）：页内覆盖层（if 分支渲染，同 ImageViewer 惯例）。
      // position 脱离文档流，避免半透明遮罩把页面内容推走；zIndex 压过页面内容。
      if (this.statsPanelShow) {
        PostStatsDialog({
          stats: this.postStats,
          loading: this.statsLoading,
          error: this.statsError,
          onClose: (): void => { this.statsPanelShow = false; },
          onRetry: (): void => { this.loadPostStats(this.statsPostId); },
        })
          .width('100%')
          .height('100%')
          .position({ x: 0, y: 0 })
          .zIndex(210)
      }

      // 帖子操作面板（作者侧）：最高层浮层，替代系统 ActionSheet
      if (this.postActionsVisible) {
        this.postActionsSheet()
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.bg_primary'))
    // Navigation 壳和 bindContentCover 模态都由外层的明确转场状态机负责，
    // 页面本身不再叠加 fade/scale，避免与封面飞行产生双重动效。
    .transition(this.navMode ? this.navNoopTransition() : this.pageEnterTransition())
  }

  // 详情主体（加载壳 / 错误 / 帖子内容）：原 build 根 Column 的三分支原样平移进
  // Navigation 内容区（仅换壳，内部结构零改动）。状态栏避让已移交标题栏，
  // 内容区不再持有 padding({ top: statusBarHeight })。
  @Builder
  detailBody(): void {
    if (this.loading) {
      this.transitionLoadingShell()
    } else if (this.error) {
      Column() {
        Text(this.error)
          .fontSize(TypeTokens.callout.size).fontFamily(TypeTokens.fontFamily)
          .fontWeight(TypeTokens.callout.weight)
          .lineHeight(TypeTokens.callout.lineHeight)
          .fontColor(ColorTokens.secondary)
        Button('重试')
          .margin({ top: 16 })
          .onClick(() => this.load())
      }
      .layoutWeight(1)
      .width('100%')
      .justifyContent(FlexAlign.Center)
    } else if (this.post) {
      Stack({ alignContent: Alignment.Bottom }) {
        Scroll(this.detailScroller) {
          Column({ space: 16 }) {
            // 待审核横幅（作者查看自己 status=0 帖子时显示）
            if (this.post.status === 0 && this.post.userId === getUserId()) {
              Row({ space: 8 }) {
                Text('该帖子正在审核中，仅你自己可见')
                  .fontSize(13).fontFamily($r('app.string.font_family'))
                  .fontColor('#FF9500')
              }
              .width('100%')
              .padding({ left: 12, right: 12, top: 8, bottom: 8 })
              .backgroundColor($r('app.color.warning_surface'))
              .borderRadius(8)
            }

            DetailPostHeader({
              title: this.post.title ?? '',
              genreLabel: genreMeta(this.post.genre).label,
              genreIcon: genreMeta(this.post.genre).iconRes,
              tags: this.post.tags ?? [],
              authorName: this.authorName(),
              authorAvatar: this.authorAvatar(),
              createdAt: this.post.createdAt,
              onOpenAuthor: (): void => { this.openAuthorProfile(); },
            })
              .transition(this.animLayerEnter(80))

            // 媒体+正文编为一组（组内间距 8）：图/视频紧贴正文。
            // 不用负 margin——Column({ space }) 对负 margin 不生效（实测间距无变化）；
            // 组外与 标题/评论区 之间仍是父容器的 16，两层间距互不干扰。
            Column({ space: 8 }) {
              // 媒体区（视频/轮播）：真实媒体直接展示。这个 id 是「一镜到底的对应节点」——
              // 目的地页把它缩放/挪移到卡片帧，因此加载壳里的占位必须挂同一个 id。
              Stack() {
                this.mediaSlot()
              }
              .width('100%')
              .id(DETAIL_HERO_ID)
              .opacity(this.heroOpacity())

              DetailPostContent({
                pairs: this.fields,
                structuredDocument: this.post.structuredDocument ?? null,
                genre: this.post.genre ?? '',
                content: this.post.content ?? '',
                coverOnlyTextPoster: this.post.structuredData?.coverOnlyTextPoster ?? false,
                planA: this.planTextOf('方案A'),
                planB: this.planTextOf('方案B'),
                votePostId: this.post.id ?? 0,
                mentions: this.post.mentions ?? [],
                onVote: (choice: string): void => { this.onDebateVote(choice); },
                // 长按结构化卡片弹「复制正文」菜单（正文 Text 自带系统文本选择，见组件内说明）
                onLongPressContent: (event: GestureEvent): void => { this.openContentMenu(event); },
              })
                .transition(this.animLayerEnter(120))
            }

            DetailCommentsSection({
              comments: this.post.comments ?? [],
              commentCount: this.post.commentCount ?? 0,
              highlightCommentId: this.highlightCommentId,
              onReportComment: (commentId: number): void => { this.openCommentReport(commentId); },
              onReplyComment: (comment: Comment): void => { this.onReplyComment(comment); },
            })
              .transition(this.animLayerEnter(180))

            // 真实滚动内容占位，末尾评论可完整滑出悬浮互动栏下方。
            Blank()
              .width('100%')
              .height(barBottomReserve())
          }
          .padding(16)
          .width('100%')
        }
        .width('100%')
        .height('100%')
        .id(DETAIL_CONTENT_SCROLL_ID)

        // @提及候选 + 底部互动栏：评论输入态下输入「@昵称」时在栏上方弹候选，点选回填精确 userId
        Column() {
          if (this.commentMentionMatch() !== null) {
            Column() {
              AtMentionSuggest({
                keyword: this.commentMentionKeyword(),
                onPick: (c: MentionCandidate): void => { this.pickCommentMention(c); },
              })
                .width('100%')
            }
            .width('100%')
            .padding({ left: 12, right: 12, bottom: 8 })
          }
          DetailActionBar({
            commenting: $commenting,
            commentText: $commentText,
            upCount: this.interaction.upCount,
            bookmarkCount: this.interaction.bookmarkCount,
            uped: this.interaction.uped,
            bookmarked: this.interaction.bookmarked,
            upPending: this.upPending,
            bookmarkPending: this.bookmarkPending,
            upFeedbackVersion: this.upFeedbackVersion,
            bookmarkFeedbackVersion: this.bookmarkFeedbackVersion,
            onUp: (): void => { this.onUp(); },
            onBookmark: (): void => { this.onBookmark(); },
            onSendComment: (): void => { this.onSendComment(); },
            replyName: this.replyTargetName,
            onCancelReply: (): void => { this.onCancelReply(); },
          })
            .transition(this.animLayerEnter(80))
        }
        .width('100%')
        .zIndex(1)

        // 长按结构化内容菜单浮层：置于 Stack 最上层，遮罩点击关闭
        if (this.contentMenuVisible) {
          this.contentActionSheet()
        }
      }
      .layoutWeight(1)
      .width('100%')
      // 采集内容区全局原点与尺寸：长按菜单按压点定位的坐标换算与边界钳制依赖它
      .onAreaChange((_old: Area, area: Area): void => {
        this.contentAreaGlobalX = area.globalPosition.x as number;
        this.contentAreaGlobalY = area.globalPosition.y as number;
        this.contentAreaWidth = area.width as number;
        this.contentAreaHeight = area.height as number;
      })
    }
  }
}
