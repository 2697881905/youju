// 帖子详情页（真实内容）：标签 → 体裁 → 标题 → 九宫格图 → 结构化字段 → 正文 → 评论区 → 底部操作栏
import { buildPageTransition, buildFadePageTransition } from '../utils/styles';
import { TypeTokens } from '../design/tokens/type';
import { ColorTokens } from '../design/tokens/color';
import {
  getPost,
  createComment,
  upPost,
  cancelUpPost,
  bookmarkPost,
  cancelBookmarkPost,
  listBookmarkFolders,
  createBookmarkFolder,
  deletePost,
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
import { openUserProfile, takePostDetailId, takePostDetailIntent, PostDetailIntent } from '../utils/nav';
import { safeShowToast } from '../utils/toast';
import { getUserId, getToken } from '../utils/auth';
import { likeStore } from '../utils/likeStore';
import { postDeletionStore } from '../utils/postDeletionStore';
import { debateVoteStore, DebateVoteInfo } from '../utils/debateVoteStore';
import { structuredFieldPairs, pairValueOf, StructuredFieldPair } from '../utils/structuredFields';
import { ShareSheet } from '../components/ShareSheet';
import { ShareToDmSheet } from '../components/ShareToDmSheet';
import { buildPostShareUrl, copyToClipboard, EXTERNAL_SHARE_ENABLED, DM_SHARE_ENABLED, sharePostToSystem } from '../utils/share';
import { generateShareCardBytes } from '../utils/shareCard';
import { structuredSummaryOf, StructuredSummary } from '../utils/structuredBlocks';
import { image } from '@kit.ImageKit';
import { window } from '@kit.ArkUI';
import { DetailToolbar } from '../components/DetailToolbar';
import { DetailMediaCarousel } from '../components/DetailMediaCarousel';
import { ImageViewer } from '../components/ImageViewer';
import { VideoPlayer } from '../components/VideoPlayer';
import { DetailPostHeader } from '../components/DetailPostHeader';
import { DetailPostContent } from '../components/DetailPostContent';
import { DetailCommentsSection } from '../components/DetailCommentsSection';
import { DetailActionBar } from '../components/DetailActionBar';
import { AtMentionSuggest } from '../components/AtMentionSuggest';
import { findActiveAtMention, applyAtMention, AtMentionMatch } from '../utils/atMention';
import { barBottomReserve } from '../utils/cardTokens';
import { SpaceTokens } from '../design/tokens/space';
import { FALLBACK_VIDEO_ASPECT_RATIO, normalizeVideoAspectRatio } from '../utils/video';
import { MotionCurves, MotionTokens } from '../design/tokens/motion';


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
  // 首页卡片转场时暂时隐藏真实媒体，避免覆盖层从卡片位飞出前露出目标位首帧。
  @Prop mediaCovered: boolean = false;
  // 媒体区屏幕帧回报（vp，窗口坐标）：模态入口依据它摆放一镜到底覆盖层
  onFlyMediaArea: ((left: number, top: number, width: number, height: number) => void) | null = null;
  private mediaAreaReported: boolean = false;
  @State postId: string = '';
  // 「一镜到底」意图：卡片进入时携带的展示快照（cover 非空才有一镜到底）
  @State intent: PostDetailIntent | null = null;
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
  @State statusBarHeight: number = 0; // 全屏布局下顶部避让状态栏
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
  private statsDialog: CustomDialogController | null = null;
  // 监听登录账号：切换账号/登出时重新加载本帖，以服务器为准校准点赞/收藏/投票态（避免 likeStore 单例残留串号）
  @StorageLink('authUserId') @Watch('onAccountSwitch') accountId: string = '';

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

  // 模态一镜到底时，详情媒体先沿用卡片的比例，等封面覆盖层完成后也不会发生
  // 首图解码导致的高度跳变；普通 router 入口返回 0，媒体按真实比例展示。
  private transitionAspect(): number {
    if (!this.navMode || this.intent === null || !(this.intent.aspect > 0)) {
      return 0;
    }
    return this.intent.aspect;
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
    this.mediaAreaReported = false;
    this.loadWindowInsets();
    this.intent = takePostDetailIntent();
    this.postId = takePostDetailId().trim();
    this.load();
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
      this.statusBarHeight = px2vp(sys.topRect.height);
      AppStorage.setOrCreate<number>('navBarHeight',
        Math.max(px2vp(sys.bottomRect.height), px2vp(indicator.bottomRect.height)));
    } catch (e) {
      // 单独一次测量失败不影响已生效值
    }
  }

  aboutToDisappear(): void {
    if (this.navSourceWin) {
      try {
        this.navSourceWin.off('avoidAreaChange', this.handleAvoidAreaChanged);
      } catch (e) {
        // 注销失败可忽略
      }
      this.navSourceWin = undefined;
    }
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
    }
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
    // 收藏：弹出收藏夹选择（加载收藏夹列表；加载失败时回退直接收藏到未分类）
    this.bookmarkPending = true;
    try {
      const folders = await listBookmarkFolders();
      this.folderPickFolders = folders;
      this.openFolderPick();
    } catch (e) {
      // 加载收藏夹失败 → 直接收藏（未分类），保证收藏主流程可用
      this.setInteraction(previous.uped, previous.upCount, true, previous.bookmarkCount + 1);
      this.bookmarkFeedbackVersion = this.bookmarkFeedbackVersion + 1;
      try {
        await bookmarkPost(id);
      } catch (err) {
        this.setInteraction(previous.uped, previous.upCount, previous.bookmarked, previous.bookmarkCount);
        safeShowToast(this.getUIContext(), { message: '操作失败，请先登录' });
      }
    } finally {
      this.bookmarkPending = false;
    }
  }

  // 收藏夹选择结果：folderId=0 未分类；>0 归入指定收藏夹
  private async onFolderPick(folderId: number): Promise<void> {
    const id = this.post?.id;
    if (id === undefined) {
      return;
    }
    const previous: DetailInteractionState = this.interaction;
    this.bookmarkPending = true;
    this.setInteraction(previous.uped, previous.upCount, true, previous.bookmarkCount + 1);
    this.bookmarkFeedbackVersion = this.bookmarkFeedbackVersion + 1;
    try {
      await bookmarkPost(id, folderId > 0 ? folderId : undefined);
    } catch (e) {
      this.setInteraction(previous.uped, previous.upCount, previous.bookmarked, previous.bookmarkCount);
      safeShowToast(this.getUIContext(), { message: '操作失败，请先登录' });
    } finally {
      this.bookmarkPending = false;
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

  // 新建收藏夹后直接收藏到该夹
  private async onCreateFolderAndBookmark(name: string): Promise<void> {
    const id = this.post?.id;
    if (id === undefined) {
      return;
    }
    const previous: DetailInteractionState = this.interaction;
    this.bookmarkPending = true;
    this.setInteraction(previous.uped, previous.upCount, true, previous.bookmarkCount + 1);
    this.bookmarkFeedbackVersion = this.bookmarkFeedbackVersion + 1;
    try {
      const folder = await createBookmarkFolder(name);
      await bookmarkPost(id, folder.id);
    } catch (e) {
      this.setInteraction(previous.uped, previous.upCount, previous.bookmarked, previous.bookmarkCount);
      safeShowToast(this.getUIContext(), { message: (e as Error).message });
    } finally {
      this.bookmarkPending = false;
    }
  }

  private openFolderPick(): void {
    this.folderPickController = new CustomDialogController({
      builder: FolderPickDialog({
        folders: this.folderPickFolders,
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

  // 复制帖子分享链接到剪贴板（占位域名，待真实域名确定后改 utils/share.ets 的 SHARE_BASE）
  private doShareLink(): void {
    if (!this.post || this.post.id === undefined) {
      return;
    }
    try {
      copyToClipboard(buildPostShareUrl(this.post.id));
      safeShowToast(this.getUIContext(), { message: '链接已复制，去粘贴给好友吧' });
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
        this.post.id,
        this.post.title ?? '',
        this.shareCardExcerpt(),
        this.authorName(),
        cover,
      );
      const source: image.ImageSource = image.createImageSource(bytes);
      const pixelMap: image.PixelMap = source.createPixelMapSync();
      this.shareCardPreview = pixelMap;
    } catch (e) {
      console.error('[shareCard] DetailPage 分享卡片异常: ' + ((e as Error).message ?? JSON.stringify(e)));
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

  // 弹出帖子操作菜单：作者可见删除+编辑，他人可见举报+分享
  private showPostActions(): void {
    if (!this.post) return;
    const isOwner: boolean = this.post.userId === getUserId();
    if (isOwner) {
      this.getUIContext().showAlertDialog({
        title: '操作',
        message: '',
        primaryButton: { value: '数据面板', action: (): void => { this.showPostStats(); } },
        secondaryButton: {
          value: '删除帖子',
          fontColor: $r('app.color.semantic_red'),
          action: (): void => { this.onDeletePost(); },
        },
      });
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

  // 打开帖子数据面板（作者本人）：请求聚合数据并弹窗展示
  private showPostStats(): void {
    const postId: number = this.post?.id ?? this.pid;
    if (isNaN(postId) || postId <= 0) {
      safeShowToast(this.getUIContext(), { message: '无效帖子ID' });
      return;
    }
    this.statsLoading = true;
    this.statsError = '';
    this.statsDialog = new CustomDialogController({
      builder: PostStatsDialog({
        stats: this.postStats,
        loading: this.statsLoading,
        error: this.statsError,
      }),
      autoCancel: true,
      customStyle: true,
    });
    this.statsDialog.open();
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
  // 输入态且文尾正在输入「@昵称」时显示候选；无稳定光标 API，取全文词尾判定（与发帖页同策略）
  private commentMentionMatch(): AtMentionMatch | null {
    if (!this.commenting) {
      return null;
    }
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
    // 模态一镜到底的覆盖层已经负责媒体动势，详情媒体本身不能再缩放一次。
    if (this.navMode) {
      return TransitionEffect.OPACITY.animation({ duration: 1, curve: MotionCurves.linear });
    }
    return this.animMediaEnter();
  }

  // 媒体进入：仅透明度淡入（无缩放），避免加载完成切媒体时"缩一下"。
  @Builder
  videoFace(): void {
    Column() {
      VideoPlayer({ src: this.videoUrl, poster: this.videoCover })
    }
    .width('100%')
    .aspectRatio(this.transitionAspect() > 0 ? this.transitionAspect() : this.videoAspectRatio)
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
      initialAspect: this.transitionAspect(),
      preserveContent: this.transitionAspect() > 1,
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

  private reportMediaArea(newValue: Area): void {
    // 加载壳阶段（intent 占位数据）头部高度与真实内容不一致：
    // 头像位于标题下方后头部更高，此时回报的媒体区位置会偏离真实落点，
    // 因此等真实内容就绪（loading=false）再回报，一镜到底落点才准确。
    if (this.loading || this.mediaAreaReported || this.onFlyMediaArea === null) {
      return;
    }
    const w: number = newValue.width as number;
    const h: number = newValue.height as number;
    if (w > 0 && h > 0) {
      this.mediaAreaReported = true;
      this.onFlyMediaArea(
        newValue.globalPosition.x as number,
        newValue.globalPosition.y as number,
        w,
        h);
    }
  }

  // 详情接口还在加载时，先用卡片意图绘制同尺寸的标题/媒体锚点。
  // 这样覆盖层可以立即从卡片位飞出，不会先出现 LoadingProgress；真实内容返回后
  // 复用相同布局，媒体帧也不会突然跳位。
  @Builder
  transitionLoadingShell(): void {
    if (this.intent !== null && this.transitionAspect() > 0) {
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
        Stack()
          .width('100%')
          .aspectRatio(this.transitionAspect())
          .backgroundColor(ColorTokens.sunken)
          .opacity(this.mediaCovered ? 0 : 0.01)
          .onAreaChange((_oldValue: Area, newValue: Area): void => {
            this.reportMediaArea(newValue);
          })
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


  build() {
    Column() {
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
          .width('100%')
          .justifyContent(FlexAlign.Start)
          .padding({ top: 24 })

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
        .zIndex(200)
      }

      // 全屏图片查看器：支持双击/双指缩放、拖动平移、单击或按钮关闭
      if (this.viewingImage.length > 0) {
        ImageViewer({
          url: this.viewingImage,
          onClose: (): void => { this.viewingImage = ''; },
        })
      }

      DetailToolbar({
        title: genreMeta(this.post?.genre).label,
        onBack: (): void => { this.navigateBack(); },
        onMore: (): void => { this.showPostActions(); },
      })
        .zIndex(10)

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
          Scroll() {
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

              // 媒体区（视频/轮播）：真实媒体直接展示。onAreaChange 回报本块屏幕帧（vp 窗口坐标），
              // 模态入口据此摆放一镜到底覆盖层（打开放大/返回缩回）。
              Stack() {
                this.mediaSlot()
              }
              .width('100%')
              .opacity(this.mediaCovered ? 0 : 1)
              .onAreaChange((_oldValue: Area, newValue: Area): void => {
                this.reportMediaArea(newValue);
              })

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
              })
                .transition(this.animLayerEnter(120))

              DetailCommentsSection({
                comments: this.post.comments ?? [],
                commentCount: this.post.commentCount ?? 0,
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
              commentCount: this.post.commentCount ?? 0,
              uped: this.interaction.uped,
              bookmarked: this.interaction.bookmarked,
              upPending: this.upPending,
              bookmarkPending: this.bookmarkPending,
              upFeedbackVersion: this.upFeedbackVersion,
              bookmarkFeedbackVersion: this.bookmarkFeedbackVersion,
              showShare: EXTERNAL_SHARE_ENABLED || DM_SHARE_ENABLED,
              onUp: (): void => { this.onUp(); },
              onBookmark: (): void => { this.onBookmark(); },
              onSendComment: (): void => { this.onSendComment(); },
              onShare: (): void => { this.onShare(); },
              replyName: this.replyTargetName,
              onCancelReply: (): void => { this.onCancelReply(); },
            })
              .transition(this.animLayerEnter(80))
          }
          .width('100%')
          .zIndex(1)
        }
        .layoutWeight(1)
        .width('100%')
      }
    }
    .width('100%')
    .height('100%')
    .padding({ top: this.statusBarHeight })
    .backgroundColor($r('app.color.bg_primary'))
    // Navigation 壳和 bindContentCover 模态都由外层的明确转场状态机负责，
    // 页面本身不再叠加 fade/scale，避免与封面飞行产生双重动效。
    .transition(this.navMode ? this.navNoopTransition() : this.pageEnterTransition())
  }
}
