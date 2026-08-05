// 帖子详情页（真实内容）：标签 → 体裁 → 标题 → 九宫格图 → 结构化字段 → 正文 → 评论区 → 底部操作栏
import { buildPageTransition } from '../utils/styles';
import {
  getPost,
  createComment,
  upPost,
  cancelUpPost,
  bookmarkPost,
  cancelBookmarkPost,
  deletePost,
  voteDebate,
  reportPost,
  reportComment,
  resolveDisplayImageUrl,
  PostWithComments,
} from '../services/api';
import { Genre, StructuredData, ReportReason, DebateVoteResult } from '../models/types';
import { ReportDialog } from '../components/ReportDialog';
import { openUserProfile, takePostDetailId } from '../utils/nav';
import { safeShowToast } from '../utils/toast';
import { getUserId, getToken } from '../utils/auth';
import { resolveActionIcon } from '../utils/actionIcons';
import { likeStore } from '../utils/likeStore';
import { ShareSheet } from '../components/ShareSheet';
import { buildPostShareUrl, copyToClipboard } from '../utils/share';
import { window } from '@kit.ArkUI';
import { DetailToolbar } from '../components/DetailToolbar';
import { DetailMediaCarousel } from '../components/DetailMediaCarousel';
import { VideoPlayer } from '../components/VideoPlayer';
import { DetailPostHeader } from '../components/DetailPostHeader';
import { DetailPostContent, DetailField } from '../components/DetailPostContent';
import { DetailCommentsSection } from '../components/DetailCommentsSection';
import { DetailActionBar } from '../components/DetailActionBar';

// 字段定义：[结构化字段键, 中文标签]，按产品文档 2.4 各体裁字段表
type FieldDef = [keyof StructuredData, string];
// 渲染用：[中文标签, 值]
type FieldPair = DetailField;

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

// ArkTS V1 禁止按变量索引对象，这里用显式 switch 读取结构化字段
function readField(sd: StructuredData, key: keyof StructuredData): string | number | undefined {
  switch (key) {
    case 'pros':
      return sd.pros;
    case 'cons':
      return sd.cons;
    case 'rating':
      return sd.rating;
    case 'targetAudience':
      return sd.targetAudience;
    case 'pitfallExperience':
      return sd.pitfallExperience;
    case 'lossAmount':
      return sd.lossAmount;
    case 'correctApproach':
      return sd.correctApproach;
    case 'tools':
      return sd.tools;
    case 'steps':
      return sd.steps;
    case 'timeDifficulty':
      return sd.timeDifficulty;
    case 'planA':
      return sd.planA;
    case 'planB':
      return sd.planB;
    default:
      return undefined;
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
    default:
      return { label: '经验分享', iconRes: $r('app.media.genre_share') };
  }
}

function structuredFieldDefs(genre?: Genre): FieldDef[] {
  switch (genre) {
    case 'review':
      return [['pros', '优点'], ['cons', '缺点'], ['rating', '推荐指数'], ['targetAudience', '适合人群']];
    case 'pitfall':
      return [['pitfallExperience', '踩坑经历'], ['lossAmount', '损失金额'], ['correctApproach', '正确做法']];
    case 'tutorial':
      return [['tools', '准备工具'], ['steps', '步骤拆解'], ['timeDifficulty', '耗时/难度']];
    case 'debate':
      return [['planA', '方案A'], ['planB', '方案B']];
    default:
      return [];
  }
}

@Entry
@Component
struct DetailPage {
  @State postId: string = '';
  @State post: PostWithComments | null = null;
  @State fields: FieldPair[] = [];
  @State images: string[] = [];
  @State videoUrl: string = '';
  @State videoCover: string = '';
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
  @State commentReportId: number = 0;
  @State viewingImage: string = ''; // 全屏看图
  @State planAVotes: number = 0;
  @State planBVotes: number = 0;
  @State myVote: string = ''; // '' | 'A' | 'B'
  @State statusBarHeight: number = 0; // 全屏布局下顶部避让状态栏
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

  private openAuthorProfile(): void {
    const authorId: number | undefined = this.authorId();
    if (authorId === undefined || this.isDeletedAuthor()) {
      return;
    }
    openUserProfile(authorId);
    this.getUIContext().getRouter().pushUrl({ url: 'pages/UserProfilePage' });
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

  // 分享面板控制器（占位：复制链接/复制标题；系统分享待域名确定后接入）
  private shareController: CustomDialogController = new CustomDialogController({
    builder: ShareSheet({
      onCopyLink: (): void => {
        this.doShareLink();
      },
      onCopyTitle: (): void => {
        this.doShareTitle();
      },
      onSystemShare: (): void => {
        this.doSystemShare();
      },
    }),
    alignment: DialogAlignment.Center,
    customStyle: false,
    autoCancel: true,
  });

  aboutToAppear(): void {
    // 读取状态栏高度（全屏布局下顶部内容需避让）
    this.loadStatusBarHeight();
    this.postId = takePostDetailId().trim();
    this.load();
  }

  // 读取系统状态栏高度（全屏布局下顶部内容需避让）
  private async loadStatusBarHeight(): Promise<void> {
    try {
      const ctx = this.getUIContext().getHostContext();
      if (!ctx) {
        return;
      }
      const win = await window.getLastWindow(ctx);
      const area = win.getWindowAvoidArea(window.AvoidAreaType.TYPE_SYSTEM);
      this.statusBarHeight = px2vp(area.topRect.height);
    } catch (e) {
      // 读取失败维持 0（不阻塞页面渲染）
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
      this.activeImageIndex = 0;
      // 辩论投票数据初始化
      this.planAVotes = (p as Record<string, Object>).planAVotes as number ?? 0;
      this.planBVotes = (p as Record<string, Object>).planBVotes as number ?? 0;
      this.myVote = (p as Record<string, Object>).myVote as string ?? '';
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

  // 把后端自由结构的结构化字段，按体裁映射成 [中文标签, 值] 列表
  private buildFields(p: PostWithComments): FieldPair[] {
    const defs = structuredFieldDefs(p.genre);
    if (defs.length === 0) {
      return [];
    }
    const sd: StructuredData | undefined = p.structuredData;
    const out: FieldPair[] = [];
    if (sd) {
      for (const item of defs) {
        const raw = readField(sd, item[0]);
        if (raw !== undefined && raw !== null) {
          out.push([item[1], String(raw)]);
        }
      }
    }
    return out;
  }

  // 取某方案（方案A/方案B）的介绍文字，用于把方案介绍合并进投票卡片
  private planTextOf(planLabel: string): string {
    for (const f of this.fields) {
      if (f[0] === planLabel) {
        return f[1];
      }
    }
    return '';
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
    this.bookmarkPending = true;
    this.setInteraction(previous.uped, previous.upCount, willMark, previous.bookmarkCount + (willMark ? 1 : -1));
    this.bookmarkFeedbackVersion = this.bookmarkFeedbackVersion + 1;
    try {
      if (willMark) {
        await bookmarkPost(id);
      } else {
        await cancelBookmarkPost(id);
      }
    } catch (e) {
      this.setInteraction(previous.uped, previous.upCount, previous.bookmarked, previous.bookmarkCount);
      safeShowToast(this.getUIContext(),{ message: '操作失败，请先登录' });
    } finally {
      this.bookmarkPending = false;
    }
  }

  onShare(): void {
    this.shareController.open();
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
      copyToClipboard(this.post.title ?? '大蓝书帖子');
      safeShowToast(this.getUIContext(), { message: '标题已复制' });
    } catch (e) {
      safeShowToast(this.getUIContext(), { message: '复制失败，请重试' });
    }
    this.shareController.close();
  }

  // 系统分享占位：真实域名确定后接入 @ohos.application.SystemShareKit 系统分享面板
  private doSystemShare(): void {
    safeShowToast(this.getUIContext(), { message: '系统分享即将上线' });
    this.shareController.close();
  }

  // 辩论投票：乐观更新票数
  private async onDebateVote(choice: string): Promise<void> {
    if (this.myVote === choice) return; // 重复投同选项
    if (!this.post || this.post.id === undefined) return;
    const prevVote: string = this.myVote;
    const prevA: number = this.planAVotes;
    const prevB: number = this.planBVotes;
    // 乐观更新
    if (prevVote !== '') {
      if (prevVote === 'A') this.planAVotes -= 1;
      else this.planBVotes -= 1;
    }
    if (choice === 'A') this.planAVotes += 1;
    else this.planBVotes += 1;
    this.myVote = choice;
    try {
      // 投票请求失败自动重试一次（自愈模拟器 rport 偶发抖动），仍失败才回滚
      const r: DebateVoteResult = await this.voteWithRetry(this.post.id, choice);
      this.planAVotes = r.planAVotes;
      this.planBVotes = r.planBVotes;
    } catch (e) {
      this.myVote = prevVote;
      this.planAVotes = prevA;
      this.planBVotes = prevB;
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

  // 删除帖子：二次确认 → 调 deletePost API → toast + 返回
  private onDeletePost(): void {
    this.getUIContext().showAlertDialog({
      title: '删除帖子？',
      message: '删除后不可恢复，确定要删除吗？',
      primaryButton: { value: '取消', action: (): void => {} },
      secondaryButton: { value: '确认删除', fontColor: $r('app.color.semantic_red'), action: async (): Promise<void> => {
        try {
          if (!this.post || this.post.id === undefined) return;
          await deletePost(this.post.id);
          safeShowToast(this.getUIContext(), { message: '帖子已删除' });
          this.getUIContext().getRouter().back();
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
        primaryButton: { value: '取消', action: (): void => {} },
        secondaryButton: {
          value: '删除帖子',
          fontColor: $r('app.color.semantic_red'),
          action: (): void => { this.onDeletePost(); },
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
        secondaryButton: {
          value: '分享',
          action: (): void => { this.onShare(); },
        },
      });
    }
  }

  // 提交帖子举报
  private async submitReport(reason: ReportReason, description: string): Promise<void> {
    try {
      await reportPost(this.pid, { reason, description: description || undefined });
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

  async onSendComment(): Promise<void> {
    const text = this.commentText.trim();
    if (!text || !this.post || this.post.id === undefined) {
      return;
    }
    try {
      await createComment(this.post.id, { content: text });
      this.commentText = '';
      this.commenting = false;
      await this.load();
    } catch (e) {
      // 透传后端错误 message（如"内容含敏感词，请修改后重试"）
      safeShowToast(this.getUIContext(), { message: (e as Error).message });
    }
  }

  build() {
    Column() {
      // 全屏图片查看器
      if (this.viewingImage.length > 0) {
        Stack() {
          // 黑色背景铺底，承载点击关闭（点任意空白处退出）
          Column()
            .width('100%')
            .height('100%')
            .backgroundColor('#000000')
            .onClick(() => { this.viewingImage = ''; });

          // 图片本体也绑定关闭：Image 铺满全屏会拦截 tap，
          // 若只绑在背景层上，点图片区域无法触发关闭（历史 Bug）
          Image(this.viewingImage)
            .objectFit(ImageFit.Contain)
            .width('100%')
            .height('100%')
            .onClick(() => { this.viewingImage = ''; });

          // 右上角关闭按钮，提升可发现性
          Image(resolveActionIcon('close'))
            .width(24)
            .height(24)
            .fillColor(Color.White)
            .position({ top: 16, right: 16 })
            .onClick(() => { this.viewingImage = ''; });
        }
        .width('100%')
        .height('100%')
        .zIndex(999);
      }

      DetailToolbar({
        title: genreMeta(this.post?.genre).label,
        onBack: (): void => { this.getUIContext().getRouter().back(); },
        onMore: (): void => { this.showPostActions(); },
      })
        .zIndex(10)

      if (this.loading) {
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
      } else if (this.error) {
        Column() {
          Text(this.error)
            .fontSize(14).fontFamily($r('app.string.font_family'))
            .fontColor($r('app.color.text_secondary'))
          Button('重试')
            .margin({ top: 16 })
            .onClick(() => this.load())
        }
        .layoutWeight(1)
        .width('100%')
        .justifyContent(FlexAlign.Center)
      } else if (this.post) {
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

            if (this.videoUrl.length > 0) {
              Column() {
                VideoPlayer({ src: this.videoUrl, poster: this.videoCover, videoHeight: 240 })
              }
              .width('100%')
            } else {
              DetailMediaCarousel({
                images: this.images,
                activeIndex: $activeImageIndex,
                onOpenImage: (url: string): void => { this.viewingImage = url; },
              })
            }

            DetailPostContent({
              fields: this.fields,
              genre: this.post.genre ?? '',
              content: this.post.content ?? '',
              planA: this.planTextOf('方案A'),
              planB: this.planTextOf('方案B'),
              planAVotes: this.planAVotes,
              planBVotes: this.planBVotes,
              myVote: this.myVote,
              onVote: (choice: string): void => { this.onDebateVote(choice); },
            })

            DetailCommentsSection({
              comments: this.post.comments ?? [],
              commentCount: this.post.commentCount ?? 0,
              onReportComment: (commentId: number): void => { this.openCommentReport(commentId); },
            })
          }
          .padding(16)
          .width('100%')
        }
        .layoutWeight(1)
        .width('100%')

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
          onUp: (): void => { this.onUp(); },
          onBookmark: (): void => { this.onBookmark(); },
          onSendComment: (): void => { this.onSendComment(); },
          onShare: (): void => { this.onShare(); },
        })
      }
    }
    .width('100%')
    .height('100%')
    .padding({ top: this.statusBarHeight })
    .backgroundColor($r('app.color.bg_primary'))
    .transition(buildPageTransition())
  }
}
