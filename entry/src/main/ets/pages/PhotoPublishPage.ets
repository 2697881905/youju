// 图文发布页 — 独立 @Entry 页面，仅处理短文图文，不耦合视频/长文发布逻辑。
// 媒体区直接渲染 ImagePicker，无 mediaTypeSelector 切换行。
import { listTags, aiAssistEnabled, aiPolishDraft, AiPolishDraftResult, resolveDisplayImageUrl } from '../services/api';
import { Genre, StructuredData, StructuredDocument, Tag, MentionRef, MentionCandidate } from '../models/types';
import { ImagePicker } from '../components/ImagePicker';
import { safeShowToast } from '../utils/toast';
import { AiAssistChip } from '../components/AiAssistChip';
import { AiPolishPreviewSheet } from '../components/AiPolishPreviewSheet';
import { findActiveAtMention, applyAtMention } from '../utils/atMention';
import { AtMentionSuggest } from '../components/AtMentionSuggest';
import { Reveal } from '../design/motion/Reveal';
import { ColorTokens } from '../design/tokens/color';
import { RadiusTokens } from '../design/tokens/radius';
import { LayoutTokens, SpaceTokens } from '../design/tokens/space';
import { TypeTokens } from '../design/tokens/type';
import { PublishDraft } from '../utils/publishDraft';
import { removePostDraft } from '../utils/postDraftStore';
import { getUserId } from '../utils/auth';
import { PublishSession, publishFlowStore } from '../utils/publishFlowStore';
import { collectStructuredData } from '../utils/structuredFields';
import { emptyStructuredDocument } from '../utils/structuredDocument';
import { StructuredReviewSheet } from '../components/StructuredReviewSheet';
import { executePublish, PublishOutcome } from '../utils/publishExecutor';
import { PublishTagPanel } from '../components/PublishTagPanel';
import { publishZoneIndexOf, publishZoneKey, zoneOfGenre, fallbackGenreOf } from '../utils/publishZones';
import { FeedZone } from '../utils/feedZones';
import { PublishCircleSelector } from '../components/PublishCircleSelector';
import { PublishCollectionPicker } from '../components/PublishCollectionPicker';
import { consumePendingPublishCircle } from '../utils/publishCircleIntent';
import { PUBLISH_BAR_ROW_VP } from '../components/PublishPageShell';
import { DesignButton } from '../design/components/DesignButton';
import { buildPageTitleBarOptions, GlassTitleRow } from '../design/components/HdsGlassBackSurface';
import { HdsNavigation, HdsNavigationTitleMode } from '@kit.UIDesignKit';
import type { HdsNavigationTitleBarOptions } from '@kit.UIDesignKit';
import { GlassBlurStyle, getSheetImmersiveMaterial, isSystemMaterialActive } from '../utils/immersiveMaterial';
import { buildPageTransition } from '../utils/styles';
import { Pressable } from '../design/motion/Pressable';
import { resolveTextPosterStyle, posterBucketOf, TEXT_POSTER_STYLES, TextPosterStyleOption } from '../utils/poster/posterTokens';
import { renderPosterThumbnail } from '../utils/poster/posterRender';
import { isSerifTypefaceReady } from '../utils/poster/posterText';
import { image } from '@kit.ImageKit';

const MAX_SELECTED_TAGS: number = 3;
const MAX_PICKED_IMAGES: number = 9;
const MAX_PHOTO_CONTENT_LENGTH: number = 300;
const MAX_TITLE_LENGTH: number = 30;
const DRAFT_PROGRESS_TOTAL: number = 3;
// 说明区高度：300 字给 104vp 要在小窗里滚动，读不出排版感
const PHOTO_BODY_HEIGHT: number = 148;

// 样式选择器缩略图：3:4 小图（60×80），选的时候看到什么、发出来就是什么。
// 重绘闸门：缩略图只依赖「标题 + 正文字长所在档」，只有这两者变化才重画；
// 再叠一层防抖，避免每次按键都触发 4 张主线程栅格化。（与长文页同源同参）
const POSTER_THUMB_WIDTH: number = 60;
const POSTER_THUMB_HEIGHT: number = 80;
const POSTER_THUMB_CHIP_HEIGHT: number = 108;
const POSTER_THUMB_DEBOUNCE: number = 250;
const POSTER_THUMB_FONT_RETRY_MAX: number = 10;
const POSTER_THUMB_FONT_RETRY_INTERVAL: number = 200;

@Entry
@Component
struct PhotoPublishPage {
  @State zoneIndex: number = 0; // 默认干货
  @State genre: Genre = 'review'; // 落库体裁；随记时恒为 'share'
  @State selectedTags: string[] = [];
  @State selectedCollectionId: number = 0;
  @State title: string = '';
  // —— AI 联合优化（标题 + 正文轻度润色）：结果先进「新旧对照」预览，作者确认才回填 ——
  @State aiTitleBusy: boolean = false;
  @State aiEnabled: boolean = false;
  // AI 状态是否已落定：未落定时不拦截发布（R8）
  @State aiStatusLoaded: boolean = false;
  @State aiSheetShown: boolean = false;
  @State aiOldTitle: string = '';
  @State aiNewTitle: string = '';
  @State aiOldContent: string = '';
  @State aiNewContent: string = '';

  // 一次点击同时产出优化标题与润色正文（轻度润色：只改语病，不新增事实）；确认后才覆盖
  private aiPolish(): void {
    if (!this.aiEnabled || this.aiTitleBusy) {
      return;
    }
    if (this.content.trim().length === 0) {
      safeShowToast(this.getUIContext(), { message: '先写点正文，AI 才有依据优化' });
      return;
    }
    this.aiTitleBusy = true;
    aiPolishDraft(this.title, this.content, this.genre, MAX_PHOTO_CONTENT_LENGTH)
      .then((result: AiPolishDraftResult): void => {
        this.aiOldTitle = this.title;
        this.aiNewTitle = result.title;
        this.aiOldContent = this.content;
        this.aiNewContent = result.content;
        this.aiSheetShown = true;
      })
      .catch((e: Object): void => {
        const err: Error = e as Error;
        safeShowToast(this.getUIContext(), { message: err.message.length > 0 ? err.message : 'AI 优化失败，请稍后再试' });
      })
      .finally((): void => {
        this.aiTitleBusy = false;
      });
  }

  private applyAiPolish(applyTitle: boolean, applyContent: boolean): void {
    // 分项采纳（spec 1c）：只应用作者勾选的部分，未勾选的保持原稿
    if (applyTitle) {
      this.title = this.aiNewTitle;
    }
    if (applyContent) {
      this.content = this.aiNewContent;
    }
    this.aiSheetShown = false;
    safeShowToast(this.getUIContext(), { message: '已应用 AI 优化，可继续手改' });
  }
  @State content: string = '';
  @State sd: StructuredData = {};
  @State structuredDocument: StructuredDocument = emptyStructuredDocument();
  // 默认款：素纸（暖纸 + 纯排印，最克制、最像书页，也最像 App 里的东西）；无图帖发布时用作卡片封面
  @State textPosterStyle: string = 'paper';
  @State images: string[] = [];
  // 图片全屏预览：页面级根模态承载（ImagePicker 在 Reveal 内自挂模态渲染异常——黑屏实证）；
  // 以 remoteUrl 定位（上传中的图无 remoteUrl 不参与预览），Swiper 在已上传列表内左右切换。
  @State previewUrl: string = '';
  private previewSwiperController: SwiperController = new SwiperController();
  @State tags: Tag[] = [];

  @State showTagPanel: boolean = false;
  // —— 结构化审稿层（点发布弹出；revision 用于弹层复用时强制重新初始化） ——
  @State reviewSheetShown: boolean = false;
  @State reviewSheetRevision: number = 0;
  @State editingSavedDraftId: string = '';
  @StorageLink('authUserId') @Watch('onUserChange') uid: string = '';
  @StorageLink('statusBarHeight') statusBarHeight: number = 0;
  @State categoryList: string[] = [];
  @State tagsByCategory: Record<string, Tag[]> = {};
  // —— 封面海报样式缩略图 ——
  // 与发布产物同源（renderPosterThumbnail → renderPosterPixelMap），只是倍率 0.22。
  @State posterThumbs: image.PixelMap[] = [];
  // 递增版本号：PixelMap 数组是引用类型，整体替换后配合版本号可靠触发刷新。
  @State posterThumbVersion: number = 0;
  private thumbTitle: string = '';
  private thumbBucket: number = -1;
  private thumbTimer: number = 0;
  private thumbDisposed: boolean = false;
  private thumbFontAttempt: number = 0;
  // —— 图文说明 @提及 选择器 ——
  @State mentionActive: boolean = false;
  @State mentionKeyword: string = '';
  private mentionAt: number = -1;
  private mentionRefs: MentionRef[] = [];
  private unsubscribePublishFlow: () => void = () => {};
  private lastPublishFlowRevision: number = -1;

  // 交给 HdsNavigation.bindToScrollable 驱动顶栏渐变模糊（同一实例挂 Scroll，不经 @Prop 复制）
  private publishScroller: Scroller = new Scroller();

  private calcDraftProgress(): number {
    let done: number = 0;
    if (this.title.trim().length > 0) {
      done += 1;
    }
    if (this.content.trim().length > 0 || this.images.length > 0) {
      done += 1;
    }
    if (this.selectedTags.length > 0) {
      done += 1;
    }
    return done;
  }

  // 顶栏进度条旁边那句「下一步做什么」：只报缺口，不报已完成的事。
  private draftHint(): string {
    if (this.title.trim().length === 0) {
      return '先写一句标题';
    }
    if (this.content.trim().length === 0 && this.images.length === 0) {
      return '配图或写句说明';
    }
    if (this.selectedTags.length === 0) {
      return '选一个圈子';
    }
    return '可以发布了';
  }

  aboutToAppear(): void {
    aiAssistEnabled()
      .then((enabled: boolean): void => { this.aiEnabled = enabled; })
      .finally((): void => { this.aiStatusLoaded = true; });
    // 登录闸门（纵深防御）：发布页只该从 Index 底栏进入，而未登录在那边已被拦住。
    // 这里是第二道 —— 将来若新增入口直接 push 本页，也不允许带着空登录态进来。
    // 用 replaceUrl 而非 push：本页从路由栈里被替换掉，用户取消登录返回时落到主页，
    // 而不是露出发布页半成品（旧行为即「发布页内部的 ensureLogin 把登录页压在它之上」）。
    if (getUserId() === 0) {
      this.getUIContext().getRouter().replaceUrl({ url: 'pages/LoginPage' });
      return;
    }
    this.loadTags();
    this.unsubscribePublishFlow();
    this.unsubscribePublishFlow = publishFlowStore.subscribe((session: PublishSession): void => {
      this.applyPublishSession(session);
    });
    this.applyPublishSession(publishFlowStore.getSession());
    this.scheduleThumbnails();
  }

  aboutToDisappear(): void {
    this.unsubscribePublishFlow();
    this.unsubscribePublishFlow = () => {};
    this.thumbDisposed = true;
    if (this.thumbTimer !== 0) {
      clearTimeout(this.thumbTimer);
      this.thumbTimer = 0;
    }
    this.releaseThumbnails();
  }

  // ───────────────────────── 封面海报样式缩略图 ─────────────────────────

  private scheduleThumbnails(): void {
    if (this.thumbDisposed) {
      return;
    }
    if (this.thumbTimer !== 0) {
      clearTimeout(this.thumbTimer);
      this.thumbTimer = 0;
    }
    this.thumbTimer = setTimeout((): void => {
      this.thumbTimer = 0;
      this.refreshThumbnails();
    }, POSTER_THUMB_DEBOUNCE) as number;
  }

  private refreshThumbnails(): void {
    if (this.thumbDisposed) {
      return;
    }
    const title: string = this.title.trim();
    const bucket: number = posterBucketOf(this.content);
    // 只有「标题」或「正文字长所在档」变了，画面才可能变 —— 否则直接跳过这次重绘
    if (title === this.thumbTitle && bucket === this.thumbBucket && this.posterThumbs.length > 0) {
      return;
    }
    // 衬线字体（Index.ets 启动时注册）未就绪：先不画，否则会用系统字体渲染出与发布产物不一致的一版
    if (!isSerifTypefaceReady()) {
      this.retryThumbsForFont(0);
      return;
    }
    this.releaseThumbnails();
    const maps: image.PixelMap[] = [];
    for (const style of TEXT_POSTER_STYLES) {
      try {
        maps.push(renderPosterThumbnail(title, this.content, style.key));
      } catch (e) {
        // 单一样式渲染失败不阻断其余样式；该位置回退为纯色占位
      }
    }
    if (this.thumbDisposed) {
      for (const map of maps) {
        map.release().catch((): void => {});
      }
      return;
    }
    this.thumbTitle = title;
    this.thumbBucket = bucket;
    this.posterThumbs = maps;
    this.posterThumbVersion = this.posterThumbVersion + 1;
  }

  private releaseThumbnails(): void {
    for (const map of this.posterThumbs) {
      map.release().catch((): void => {});
    }
    if (this.posterThumbs.length > 0) {
      this.posterThumbs = [];
    }
  }

  // 字体未就绪时轮询等待，就绪后重绘一次；超过上限则放弃（保持纯色占位）。
  private retryThumbsForFont(attempt: number): void {
    if (this.thumbDisposed || attempt >= POSTER_THUMB_FONT_RETRY_MAX) {
      return;
    }
    this.thumbFontAttempt = attempt;
    setTimeout((): void => {
      if (this.thumbDisposed) {
        return;
      }
      if (isSerifTypefaceReady()) {
        this.refreshThumbnails();
      } else {
        this.retryThumbsForFont(attempt + 1);
      }
    }, POSTER_THUMB_FONT_RETRY_INTERVAL) as number;
  }

  private onUserChange(): void {
    this.reset();
  }

  private async loadTags(): Promise<void> {
    try {
      this.tags = await listTags();
      this.buildTagCategoryData();
    } catch (e) {
      // 标签加载失败不阻断正文编辑；打开面板时只展示空列表。
    }
  }

  private buildTagCategoryData(): void {
    const map: Map<string, Tag[]> = new Map();
    for (const t of this.tags) {
      const cat: string = t.category ?? '其他';
      const arr: Tag[] | undefined = map.get(cat);
      if (arr !== undefined) {
        arr.push(t);
      } else {
        map.set(cat, [t]);
      }
    }
    const rec: Record<string, Tag[]> = {};
    const cats: string[] = [];
    map.forEach((value: Tag[], key: string) => {
      rec[key] = value;
      cats.push(key);
    });
    this.tagsByCategory = rec;
    this.categoryList = cats;
  }

  private toggleTag(name: string): void {
    if (name.length === 0) {
      return;
    }
    if (this.selectedTags.indexOf(name) >= 0) {
      this.selectedTags = this.selectedTags.filter((n: string) => n !== name);
    } else {
      if (this.selectedTags.length >= MAX_SELECTED_TAGS) {
        safeShowToast(this.getUIContext(), { message: '最多选 ' + MAX_SELECTED_TAGS + ' 个标签' });
        return;
      }
      this.selectedTags = [...this.selectedTags, name];
    }
  }

  // —— 图文说明 @提及 编辑辅助 ——
  private syncMention(text: string): void {
    const m = findActiveAtMention(text);
    if (m === null) {
      if (this.mentionActive) {
        this.mentionActive = false;
      }
      this.mentionKeyword = '';
      this.mentionAt = -1;
      return;
    }
    this.mentionAt = m.atIndex;
    this.mentionKeyword = m.keyword;
    if (!this.mentionActive) {
      this.mentionActive = true;
    }
  }

  private pickMention(c: MentionCandidate): void {
    if (this.mentionAt < 0) {
      return;
    }
    const nickname: string = c.nickname.trim();
    if (nickname.length === 0) {
      return;
    }
    const nextText: string = applyAtMention(this.content, this.mentionAt, nickname);
    if (nextText.length > MAX_PHOTO_CONTENT_LENGTH) {
      safeShowToast(this.getUIContext(), { message: '图文说明最多 ' + MAX_PHOTO_CONTENT_LENGTH + ' 字' });
      return;
    }
    this.content = nextText;
    let exists: boolean = false;
    for (const m of this.mentionRefs) {
      if (m.userId === c.id) {
        exists = true;
        break;
      }
    }
    if (!exists) {
      const next: MentionRef[] = this.mentionRefs.slice();
      next.push({ name: nickname, userId: c.id });
      this.mentionRefs = next;
    }
    this.mentionActive = false;
    this.mentionKeyword = '';
    this.mentionAt = -1;
  }

  private closeMention(): void {
    this.mentionActive = false;
    this.mentionKeyword = '';
    this.mentionAt = -1;
  }

  // 点发布：干货进审稿层（AI 拆块 → 逐块确认 → 确认即发布），
  // 随记保持「预览页 → 确认发布」原路径。发布永不被 AI 卡死：层内自带手动骨架兜底。
  private onPublish(): void {
    if (!this.title.trim()) {
      safeShowToast(this.getUIContext(), { message: '请填写标题' });
      return;
    }
    if (this.content.length > MAX_PHOTO_CONTENT_LENGTH) {
      safeShowToast(this.getUIContext(), { message: '图文说明最多 ' + MAX_PHOTO_CONTENT_LENGTH + ' 字' });
      return;
    }
    // 干货区依赖 AI 拆块：AI 明确不可用时先轻确认，避免作者点发布后才发现只能按原文发
    if (this.currentZone() === 'insight' && this.aiStatusLoaded && !this.aiEnabled) {
      this.getUIContext().showAlertDialog({
        title: 'AI 整理暂不可用',
        message: '将按原文发布到干货区，不在发布前整理成信息块。',
        primaryButton: {
          value: '取消',
          action: (): void => {},
        },
        secondaryButton: {
          value: '按原文发布',
          action: (): void => { this.publishRaw(); },
        },
      });
      return;
    }
    if (this.currentZone() === 'insight') {
      this.reviewSheetRevision = this.reviewSheetRevision + 1;
      this.reviewSheetShown = true;
      return;
    }
    const draft: PublishDraft = this.currentPublishDraft();
    publishFlowStore.beginPreview(draft, this.editingSavedDraftId);
    this.getUIContext().getRouter().pushUrl({ url: 'pages/PublishPreviewPage' });
  }

  // 审稿层确认：回填最终信息块与 AI 推断体裁，直接走共享发布链路（不再经过预览页）。
  private async confirmPublish(document: StructuredDocument, genre: string): Promise<void> {
    this.reviewSheetShown = false;
    this.structuredDocument = document;
    const insightGenres: string[] = ['review', 'pitfall', 'tutorial', 'debate'];
    if (insightGenres.indexOf(genre) >= 0) {
      this.genre = genre as Genre;
    } else if (this.currentZone() === 'insight') {
      this.genre = 'review';
    }
    const outcome: PublishOutcome = await executePublish(this.currentPublishDraft(), this.getUIContext());
    if (outcome.ok) {
      this.getUIContext().getRouter().back();
    }
  }

  // 降级出口：不结构化、不带信息块，按原文直接发布。
  private async publishRaw(): Promise<void> {
    this.reviewSheetShown = false;
    this.structuredDocument = emptyStructuredDocument();
    this.genre = 'review';
    const outcome: PublishOutcome = await executePublish(this.currentPublishDraft(), this.getUIContext(),
      { allowEmptyStructured: true });
    if (outcome.ok) {
      this.getUIContext().getRouter().back();
    }
  }

  private currentPublishDraft(): PublishDraft {
    return {
      mode: 'photo',
      title: this.title.trim(),
      content: this.content,
      genre: this.genre,
      zone: this.currentZone(),
      tags: this.selectedTags,
      structuredData: collectStructuredData(this.sd, this.genre),
      structuredDocument: this.structuredDocument,
      images: this.images,
      textPosterStyle: this.textPosterStyle,
      mentions: this.mentionRefs.length > 0 ? this.mentionRefs : undefined,
      collectionId: this.selectedCollectionId,
    };
  }

  private applyDraft(draft: PublishDraft, savedDraftId: string): void {
    this.genre = draft.genre;
    this.zoneIndex = publishZoneIndexOf(zoneOfGenre(draft.genre));
    this.selectedTags = [...draft.tags];
    this.title = draft.title;
    this.content = draft.content;
    this.sd = draft.structuredData;
    this.structuredDocument = draft.structuredDocument;
    this.images = [...draft.images];
    this.textPosterStyle = resolveTextPosterStyle(draft.textPosterStyle).key;
    this.selectedCollectionId = draft.collectionId ?? 0;
    this.editingSavedDraftId = savedDraftId;

    this.showTagPanel = false;
    this.closeMention();
    this.mentionRefs = draft.mentions !== undefined ? draft.mentions.map((m: MentionRef): MentionRef => ({
      name: m.name,
      userId: m.userId,
    })) : [];
    this.scheduleThumbnails();
  }

  private applyPublishSession(session: PublishSession): void {
    if (session.revision <= this.lastPublishFlowRevision) {
      return;
    }
    this.lastPublishFlowRevision = session.revision;
    if (session.intent === 'new') {
      // 新发布不自动弹系统相册：三种方式一律落在编辑页，选图由图片区的「+ 添加」触发。
      this.reset();
      this.applyZone(session.zone);
      return;
    }
    if (session.intent === 'edit' && session.previewDraft !== null) {
      this.applyDraft(session.previewDraft, session.activeDraftId);
      return;
    }
    if (session.intent === 'sync') {
      this.editingSavedDraftId = session.activeDraftId;
      return;
    }
    if (session.intent === 'reset') {
      if (session.completedDraftId.length > 0) {
        removePostDraft(getUserId(), session.completedDraftId);
      }
      this.reset();
    }
  }

  private reset(): void {
    this.zoneIndex = 0;
    this.genre = 'review';
    const pendingCircle: string = consumePendingPublishCircle();
    this.selectedTags = pendingCircle.length > 0 ? [pendingCircle] : [];
    this.title = '';
    this.content = '';
    this.sd = {};
    this.structuredDocument = emptyStructuredDocument();
    this.images = [];
    this.textPosterStyle = 'paper';
    this.editingSavedDraftId = '';

    this.showTagPanel = false;
    this.mentionRefs = [];
    this.closeMention();
    this.scheduleThumbnails();
  }

  private currentZone(): FeedZone {
    return publishZoneKey(this.zoneIndex);
  }

  // 会话入口带来的内容区：只改分区与落库体裁，结构化文档由 R5 的确认分支决定去留
  private applyZone(zone: FeedZone): void {
    this.zoneIndex = publishZoneIndexOf(zone);
    this.genre = fallbackGenreOf(zone);
  }

  // 单片缩略图：与发布产物同源渲染，选中态用品牌色描边 + 标签变色（图片本身不能加底色）
  @Builder
  posterStyleThumb(index: number, style: TextPosterStyleOption): void {
    Stack({ alignContent: Alignment.Center }) {
      if (index < this.posterThumbs.length) {
        Image(this.posterThumbs[index])
          .width(POSTER_THUMB_WIDTH)
          .height(POSTER_THUMB_HEIGHT)
          .objectFit(ImageFit.Cover)
          .interpolation(ImageInterpolation.High)
          .draggable(false)
      } else {
        // 缩略图未就绪（衬线字体未注册 / 正在防抖重绘）：用款式底色占位，避免闪白
        Column()
          .width(POSTER_THUMB_WIDTH)
          .height(POSTER_THUMB_HEIGHT)
          .backgroundColor(style.background)
      }
    }
    .width(POSTER_THUMB_WIDTH)
    .height(POSTER_THUMB_HEIGHT)
    .borderRadius(RadiusTokens.xs)
    .clip(true)
    .border({
      width: this.textPosterStyle === style.key ? 2 : LayoutTokens.glassBorderWidth,
      color: this.textPosterStyle === style.key ? ColorTokens.brand : ColorTokens.separator,
      style: BorderStyle.Solid,
    })
  }

  @Builder
  posterStyleChip(index: number, style: TextPosterStyleOption): void {
    Pressable({
      visualHeight: POSTER_THUMB_CHIP_HEIGHT,
      action: (): void => { this.textPosterStyle = style.key; },
    }) {
      Column({ space: SpaceTokens.inlineTight }) {
        this.posterStyleThumb(index, style)
        Text(style.label)
          .fontSize(TypeTokens.caption.size).fontFamily(TypeTokens.fontFamily)
          .fontWeight(this.textPosterStyle === style.key ? TypeTokens.headline.weight : TypeTokens.caption.weight)
          .lineHeight(TypeTokens.caption.lineHeight)
          .fontColor(this.textPosterStyle === style.key ? ColorTokens.brand : ColorTokens.secondary)
      }
      .height(POSTER_THUMB_CHIP_HEIGHT)
      .padding({ left: SpaceTokens.xs, right: SpaceTokens.xs })
      .alignItems(HorizontalAlign.Center)
    }
  }

  @Builder
  textPosterStyleSelector(): void {
    Column({ space: SpaceTokens.xs }) {
      Scroll() {
        Row({ space: SpaceTokens.sm }) {
          // key 带上缩略图版本号：PixelMap 数组被整体替换时强制重建 Image，否则会留在旧帧
          ForEach(TEXT_POSTER_STYLES, (style: TextPosterStyleOption, index: number) => {
            this.posterStyleChip(index, style)
          }, (style: TextPosterStyleOption) => style.key + '_' + this.posterThumbVersion)
        }
        .padding({ left: SpaceTokens.xs, right: SpaceTokens.xs })
        .alignItems(VerticalAlign.Top)
      }
      .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true })
      .scrollable(ScrollDirection.Horizontal)
      .scrollBar(BarState.Off)
      .width('100%')
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  // ─────────────── 版式（创作纸）：媒体附件 → 标题/正文纸面 → 加入合集 → 圈子 ───────────────
  // 写作是主角：标题与正文直接落在纸面上，不套表单卡；AI 优化驻纸面顶部，圈子/合集为轻量独立区块。

  // 轻量分区题头（无卡壳）：左标签 + 右元信息，用于媒体等附件区与独立区块分组。
  @Builder
  blockCaption(label: string, meta: string): void {
    Row() {
      Text(label)
        .fontSize(TypeTokens.callout.size).fontFamily(TypeTokens.fontFamily)
        .fontWeight(TypeTokens.headline.weight)
        .lineHeight(TypeTokens.callout.lineHeight)
        .fontColor(ColorTokens.secondary)
      Blank().layoutWeight(1)
      if (meta.length > 0) {
        Text(meta)
          .fontSize(TypeTokens.caption.size).fontFamily(TypeTokens.fontFamily)
          .fontWeight(TypeTokens.caption.weight)
          .lineHeight(TypeTokens.caption.lineHeight)
          .fontColor(ColorTokens.tertiary)
      }
    }
    .width('100%')
    .alignItems(VerticalAlign.Center)
  }

  // 媒体附件：紧凑落在纸面上，不套表单卡。
  @Builder
  mediaBlock(): void {
    Reveal({ index: 0 }) {
      Column({ space: SpaceTokens.sm }) {
        this.blockCaption('图片', '最多 ' + MAX_PICKED_IMAGES + ' 张' + (this.images.length > 1 ? ' · 长按排序' : ''))
        ImagePicker({
          selected: $images,
          maxCount: MAX_PICKED_IMAGES,
          onPreview: (url: string): void => { this.previewUrl = url; },
        })
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
    }
  }

  // 创作纸：标题与正文同处一张软质纸面（subtle 底大圆角），发丝线分隔，统一写作面语言；
  // 纸面之下挂「封面海报」区块（与长文页 writingSheet 同位）：无图帖发布时该样式即帖子卡片封面。
  @Builder
  writingSheet(): void {
    Reveal({ index: 1 }) {
      Column({ space: SpaceTokens.md }) {
        Column() {

          TextArea({
            text: $$this.title,
            placeholder: this.aiEnabled && this.title.length === 0 && this.content.trim().length > 0
              ? '写完正文了？AI 润色可顺带起标题'
              : '给这篇起个标题',
          })
            .width('100%')
            .fontSize(TypeTokens.titleSerif.size).fontFamily(TypeTokens.fontFamilySerif)
            .fontWeight(TypeTokens.titleSerif.weight)
            .lineHeight(TypeTokens.titleSerif.lineHeight)
            .fontColor(ColorTokens.primary)
            .placeholderColor(ColorTokens.tertiary)
            .backgroundColor(Color.Transparent)
            .padding({ left: SpaceTokens.base, right: SpaceTokens.base, top: SpaceTokens.base, bottom: SpaceTokens.md })
            .maxLines(3)
            .maxLength(MAX_TITLE_LENGTH)
            .showCounter(true, { highlightBorder: false })
            .onChange((value: string) => { this.title = value; this.scheduleThumbnails(); })
          Divider().strokeWidth(LayoutTokens.hairlineWidth).color(ColorTokens.separator)
            .margin({ left: SpaceTokens.base, right: SpaceTokens.base })
          // @提及候选：输入框「上方」的横向条（左右滑动、点选回填）
          if (this.mentionActive) {
            AtMentionSuggest({
              keyword: this.mentionKeyword,
              onPick: (c: MentionCandidate): void => { this.pickMention(c); },
            })
              .width('100%')
          }
          TextArea({ text: this.content, placeholder: '写句说明，无图自动生成封面' })
            .width('100%')
            .constraintSize({ minHeight: PHOTO_BODY_HEIGHT })
            .fontSize(TypeTokens.body.size).fontFamily(TypeTokens.fontFamily)
            .fontWeight(TypeTokens.body.weight)
            .lineHeight(TypeTokens.body.lineHeight)
            .letterSpacing(TypeTokens.body.tracking)
            .fontColor(ColorTokens.primary)
            .placeholderColor(ColorTokens.tertiary)
            .backgroundColor(Color.Transparent)
            .padding(SpaceTokens.base)
            .maxLength(MAX_PHOTO_CONTENT_LENGTH)
            .showCounter(true, { highlightBorder: false })
            .onChange((value: string) => {
              this.content = value;
              this.syncMention(value);
              this.scheduleThumbnails();
            })
        }
        .width('100%')
        .backgroundColor(ColorTokens.subtle)
        .borderRadius(RadiusTokens.lg)
        .alignItems(HorizontalAlign.Start)

        Row() {
          Blank().layoutWeight(1)
          AiAssistChip({ label: 'Ai润色', busy: this.aiTitleBusy, available: this.aiEnabled,
            action: (): void => { this.aiPolish(); } })
        }
        .width('100%')
        .onClick((): void => { this.aiPolish(); })

        if (this.images.length === 0) {
          Column({ space: SpaceTokens.sm }) {
            this.blockCaption('封面海报', '未加图时用作帖子卡片')
            this.textPosterStyleSelector()
          }
          .width('100%')
          .alignItems(HorizontalAlign.Start)
          .transition(TransitionEffect.OPACITY.animation({ duration: 200, curve: Curve.EaseInOut }))
        }
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
    }
  }

  // 加入合集：轻量独立区块（无卡壳），入场节奏顺延 writingSheet（Reveal index 2）。
  @Builder
  collectionBlock(): void {
    Reveal({ index: 2 }) {
      Column({ space: SpaceTokens.sm }) {
        this.blockCaption('加入合集', '')
        PublishCollectionPicker({ selectedId: $selectedCollectionId })
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
    }
  }

  // 圈子：轻量独立区块（无卡壳），入场节奏顺延加入合集（Reveal index 3）。
  @Builder
  circleBlock(): void {
    Reveal({ index: 3 }) {
      Column({ space: SpaceTokens.sm }) {
        this.blockCaption('圈子', '已选 ' + this.selectedTags.length + '/' + MAX_SELECTED_TAGS)
        PublishCircleSelector({ selectedTags: this.selectedTags, maxSelected: MAX_SELECTED_TAGS,
          onAdd: (): void => { this.showTagPanel = true; },
          onRemove: (name: string): void => { this.toggleTag(name); } })
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
    }
  }

  @Builder
  compositionColumn(): void {
    this.mediaBlock()
    this.writingSheet()
    this.collectionBlock()
    this.circleBlock()
  }

  // 标题栏配置走 buildPageTitleBarOptions 工厂（与 EditProfilePage 保存钮同一实证可点模式）。
  private photoTitleBarOptions(): HdsNavigationTitleBarOptions {
    return buildPageTitleBarOptions({
      back: (): void => { this.getUIContext().getRouter().back(); },
      stackBuilder: (): void => { this.photoPublishTitleRow(); },
    });
  }

  // 标题行：GlassTitleRow 居中标题样板 + 进度副行 + 右侧发布主钮。
  @Builder
  photoPublishTitleRow(): void {
    GlassTitleRow({
      title: '发布图文',
      headlineSerif: true,
      hasSubRow: true,
      subRow: (): void => { this.photoProgressRow(); },
      hasActions: true,
      actions: (): void => { this.publishActionButton(); },
    })
  }

  @Builder
  photoProgressRow(): void {
    Row({ space: SpaceTokens.inline }) {
      Progress({ value: this.calcDraftProgress(), total: DRAFT_PROGRESS_TOTAL, type: ProgressType.Linear })
        .width(44)
        .color(ColorTokens.brand)
        .backgroundColor(ColorTokens.separator)
        .style({ strokeWidth: SpaceTokens.xs, strokeRadius: RadiusTokens.xs, enableSmoothEffect: true })
      Text(this.draftHint())
        .fontSize(TypeTokens.caption.size).fontFamily(TypeTokens.fontFamily)
        .fontWeight(TypeTokens.caption.weight)
        .lineHeight(TypeTokens.caption.lineHeight)
        .fontColor(this.calcDraftProgress() >= DRAFT_PROGRESS_TOTAL ? ColorTokens.brand : ColorTokens.secondary)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
    }
    .width('100%')
    .justifyContent(FlexAlign.Center)
    .alignItems(VerticalAlign.Center)
  }

  // 发布主钮：与 PublishPageShell.publishActionRow 同源（DesignButton 材质药丸）。
  @Builder
  publishActionButton(): void {
    DesignButton({
      label: '发布',
      variant: 'primary',
      useSystemMaterial: true,
      materialPill: true,
      visualHeight: LayoutTokens.segmentedHeight,
      disabled: this.title.trim().length === 0,
      action: (): void => { this.onPublish(); },
    })
      .margin({ right: SpaceTokens.md })
  }

  build() {
    // HdsNavigation 直接做 @Entry build 根（EditProfilePage 同款结构）。
    // 模态分宿主：圈子半模态挂栏根节点、两个全模态挂内层 Scroll——同组件兼绑两者会让
    // 全模态静默失效（a39dfc9c 平台规格）；两个宿主都是页面自有组件，弹层开关状态变化
    // 即时重评估绑定（挂进外壳尾随闭包会随外壳复用而不重评估，弹层永不出现）。
    HdsNavigation() {
      Scroll(this.publishScroller) {
        Column({ space: SpaceTokens.md }) {
          // 穿底让位：状态栏 + 栏高 + 呼吸（enableComponentSafeArea=false 后自补）
          Row().height(this.statusBarHeight + PUBLISH_BAR_ROW_VP + SpaceTokens.sm).width('100%')
          this.compositionColumn()
        }
        .width('100%')
        .padding({ left: SpaceTokens.pageCompact, right: SpaceTokens.pageCompact, bottom: SpaceTokens.x2l })
        .alignItems(HorizontalAlign.Start)
      }
      .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true })
      .width('100%')
      .height('100%')
      .scrollBar(BarState.Off)
      .backgroundColor(ColorTokens.canvas)
      .bindContentCover(this.aiSheetShown, this.aiPolishSheet(), {
        modalTransition: ModalTransition.DEFAULT,
        onDisappear: (): void => { this.aiSheetShown = false; },
      })
      .bindContentCover(this.reviewSheetShown, this.reviewSheet(), {
        modalTransition: ModalTransition.DEFAULT,
        onDisappear: (): void => { this.reviewSheetShown = false; },
      })
      .bindContentCover(this.previewUrl.length > 0, this.previewOverlay(), {
        modalTransition: ModalTransition.DEFAULT,
        onDisappear: (): void => { this.previewUrl = ''; },
      })
    }
    .mode(NavigationMode.Stack)
    .titleMode(HdsNavigationTitleMode.MINI)
    .titleBar(this.photoTitleBarOptions())
    .bindToScrollable([this.publishScroller])
    .clip(false)
    .width('100%')
    .height('100%')
    .backgroundColor(ColorTokens.canvas)
    // 页面转场是真实触摸可用的前提：发布三页曾是全站唯三未配置转场的路由页，
    // 手指点击全死、accessibility tap 绕过（2026-11-24 真机实证），与全站路由页同款。
    .transition(buildPageTransition())
    .bindSheet(this.showTagPanel, this.tagSheet(), {
      height: '60%',
      dragBar: true,
      systemMaterial: getSheetImmersiveMaterial(),
      blurStyle: isSystemMaterialActive() ? BlurStyle.NONE : GlassBlurStyle.Floating,
      backgroundColor: isSystemMaterialActive() ? undefined : ColorTokens.canvas,
      showClose: false,
      maskColor: '#33000000',
      onDisappear: (): void => { this.showTagPanel = false; },
    })
  }

  // 图片全屏预览：页面级根模态承载（ImagePicker 在 Reveal 内自挂模态渲染异常——黑屏实证）。
  // Swiper 多图左右切换：打开时按 remoteUrl 在已上传列表中定位；点图或 ✕ 退出。
  // 页面级模态与审稿层同宿主（PixelMap/网络图渲染成功先例），此前 Swiper 黑屏根因是 Reveal 内自挂模态。
  @Builder
  previewOverlay(): void {
    Stack({ alignContent: Alignment.TopEnd }) {
      Swiper(this.previewSwiperController) {
        ForEach(this.images, (url: string) => {
          Image(resolveDisplayImageUrl(url))
            .width('100%')
            .height('100%')
            .objectFit(ImageFit.Contain)
            .onClick(() => { this.previewUrl = ''; })
        }, (url: string) => url)
      }
      .index(Math.max(0, this.images.indexOf(this.previewUrl)))
      .width('100%')
      .height('100%')
      .indicator(true)
      .loop(false)
      .backgroundColor(Color.Black)
      Text('✕')
        .fontSize(22)
        .fontColor(Color.White)
        .width(44)
        .height(44)
        .textAlign(TextAlign.Center)
        .margin({ top: 48, right: 12 })
        .onClick(() => { this.previewUrl = ''; })
    }
    .width('100%')
    .height('100%')
    .backgroundColor(Color.Black)
  }

  // 结构化审稿弹层：revision 递增驱动内部重新初始化（复用实例时 aboutToAppear 不会再跑）
  @Builder
  reviewSheet(): void {
    StructuredReviewSheet({
      zone: this.currentZone(),
      genre: this.currentZone() === 'insight' ? '' : this.genre,
      contentText: this.content,
      initialDocument: this.structuredDocument,
      aiAvailable: this.aiEnabled,
      resetKey: this.reviewSheetRevision,
      draftTitle: this.title,
      draftTags: this.selectedTags,
      draftMentions: this.mentionRefs,
      draftMediaUrl: '',
      draftVideoUrl: '',
      draftPosterStyle: this.textPosterStyle,
      onConfirm: (document: StructuredDocument, genre: string): void => { this.confirmPublish(document, genre); },
      onPublishRaw: (): void => { this.publishRaw(); },
      onClose: (): void => { this.reviewSheetShown = false; },
    })
  }

  // AI 优化新旧对照弹层：确认后回填标题与说明
  @Builder
  aiPolishSheet(): void {
    AiPolishPreviewSheet({
      oldTitle: this.aiOldTitle,
      newTitle: this.aiNewTitle,
      oldContent: this.aiOldContent,
      newContent: this.aiNewContent,
      onApply: (applyTitle: boolean, applyContent: boolean): void => { this.applyAiPolish(applyTitle, applyContent); },
      onClose: (): void => { this.aiSheetShown = false; },
    })
  }

  // 选择圈子弹层内容：按分类多选标签（最多 MAX_SELECTED_TAGS 个）
  @Builder
  tagSheet(): void {
    PublishTagPanel({
      categoryList: this.categoryList,
      tagsByCategory: this.tagsByCategory,
      selectedTags: this.selectedTags,
      maxSelected: MAX_SELECTED_TAGS,
      content: this.content,
      genre: this.genre,
      aiEnabled: this.aiEnabled,
      onToggle: (name: string): void => { this.toggleTag(name); },
      onClose: (): void => { this.showTagPanel = false; },
    })
  }
}
