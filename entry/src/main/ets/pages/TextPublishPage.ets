// 长文发布页 — 独立 @Entry 页面，仅处理长文发布，不耦合图文/视频发布逻辑。
// 媒体区渲染文字海报样式选择器，无图片/视频入口，无 mediaTypeSelector 切换行。
import { LengthMetrics } from '@kit.ArkUI';
import { listTags } from '../services/api';
import { Genre, StructuredData, StructuredDocument, Tag, MentionRef, MentionCandidate } from '../models/types';
import { safeShowToast } from '../utils/toast';
import { resolveActionIcon } from '../utils/actionIcons';
import { findActiveAtMention, applyAtMention } from '../utils/atMention';
import { AtMentionSuggest } from '../components/AtMentionSuggest';
import { BaseCard } from '../design/components/BaseCard';
import { Pressable } from '../design/motion/Pressable';
import { ColorTokens } from '../design/tokens/color';
import { IconTokens } from '../design/tokens/icon';
import { RadiusTokens } from '../design/tokens/radius';
import { LayoutTokens, SpaceTokens } from '../design/tokens/space';
import { TypeTokens } from '../design/tokens/type';
import { PublishDraft } from '../utils/publishDraft';
import { removePostDraft } from '../utils/postDraftStore';
import { getUserId } from '../utils/auth';
import { PublishSession, publishFlowStore } from '../utils/publishFlowStore';
import { collectStructuredData } from '../utils/structuredFields';
import { emptyStructuredDocument, filterStructuredDocumentForGenre } from '../utils/structuredDocument';
import { StructuredComposer } from '../components/StructuredComposer';
import { PublishTagPanel } from '../components/PublishTagPanel';
import { PUBLISH_GENRES, publishGenreMeta } from '../utils/publishGenres';
import { PublishGenreSection } from '../components/PublishGenreSection';
import { PublishTopBar } from '../components/PublishTopBar';
import { resolveTextPosterStyle, posterBucketOf, TEXT_POSTER_STYLES, TextPosterStyleOption } from '../utils/poster/posterTokens';
import { renderPosterThumbnail } from '../utils/poster/posterRender';
import { isSerifTypefaceReady } from '../utils/poster/posterText';
import { image } from '@kit.ImageKit';

const MAX_SELECTED_TAGS: number = 3;
const MAX_LONG_FORM_CONTENT_LENGTH: number = 5000;
const DRAFT_PROGRESS_TOTAL: number = 3;

// 样式选择器缩略图：3:4 小图（60×80），选的时候看到什么、发出来就是什么。
// 重绘闸门：缩略图只依赖「标题 + 正文字长所在档」，只有这两者变化才重画；
// 再叠一层防抖，避免每次按键都触发 4 张主线程栅格化。
const POSTER_THUMB_WIDTH: number = 60;
const POSTER_THUMB_HEIGHT: number = 80;
const POSTER_THUMB_CHIP_HEIGHT: number = 108;
const POSTER_THUMB_DEBOUNCE: number = 250;
const POSTER_THUMB_FONT_RETRY_MAX: number = 10;
const POSTER_THUMB_FONT_RETRY_INTERVAL: number = 200;

@Entry
@Component
struct TextPublishPage {
  @State genre: Genre = 'share';
  @State genreIndex: number = 4; // share 位于 PUBLISH_GENRES 下标 4
  @State selectedTags: string[] = [];
  @State title: string = '';
  @State content: string = '';
  @State sd: StructuredData = {};
  @State structuredDocument: StructuredDocument = emptyStructuredDocument();
  // 默认款：素纸（暖纸 + 纯排印，最克制、最像书页，也最像 App 里的东西）
  @State textPosterStyle: string = 'paper';
  @State tags: Tag[] = [];
  // 结构化区默认展开：它是产品核心特色，藏在折叠里等于没有（覆盖率的最大杀手）
  @State showFields: boolean = true;
  @State showGenreMenu: boolean = false;
  @State showTagPanel: boolean = false;
  @State editingSavedDraftId: string = '';
  @StorageLink('authUserId') @Watch('onUserChange') uid: string = '';
  @StorageLink('statusBarHeight') statusBarHeight: number = 0;
  @State categoryList: string[] = [];
  @State tagsByCategory: Record<string, Tag[]> = {};
  // —— 文字海报样式缩略图 ——
  // 与发布产物同源（renderPosterThumbnail → renderPosterPixelMap），只是倍率 0.22。
  @State posterThumbs: image.PixelMap[] = [];
  // 递增版本号：PixelMap 数组是引用类型，整体替换后配合版本号可靠触发刷新。
  @State posterThumbVersion: number = 0;
  private thumbTitle: string = '';
  private thumbBucket: number = -1;
  private thumbTimer: number = 0;
  private thumbDisposed: boolean = false;
  private thumbFontAttempt: number = 0;
  // —— 正文 @提及 选择器 ——
  @State mentionActive: boolean = false;
  @State mentionKeyword: string = '';
  private mentionAt: number = -1;
  private mentionRefs: MentionRef[] = [];
  private unsubscribePublishFlow: () => void = () => {};
  private lastPublishFlowRevision: number = -1;

  private calcDraftProgress(): number {
    let done: number = 0;
    if (this.title.trim().length > 0) {
      done += 1;
    }
    if (this.content.trim().length > 0) {
      done += 1;
    }
    if (this.selectedTags.length > 0) {
      done += 1;
    }
    return done;
  }

  private draftProgressText(): string {
    return '草稿完成 ' + this.calcDraftProgress() + '/' + DRAFT_PROGRESS_TOTAL;
  }

  aboutToAppear(): void {
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

  // ───────────────────────── 海报样式缩略图 ─────────────────────────

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

  // —— 正文 @提及 编辑辅助 ——
  // 正文尾部正在输入「@昵称」时激活候选面板；键入空格/标点/@ 或删除 @ 后自动收起
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

  // 点选候选：回填「@昵称 」并记录精确 userId（防重名歧义，随发布透传后端）
  private pickMention(c: MentionCandidate): void {
    if (this.mentionAt < 0) {
      return;
    }
    const nickname: string = c.nickname.trim();
    if (nickname.length === 0) {
      return;
    }
    const nextText: string = applyAtMention(this.content, this.mentionAt, nickname);
    if (nextText.length > MAX_LONG_FORM_CONTENT_LENGTH) {
      safeShowToast(this.getUIContext(), { message: '长文最多 ' + MAX_LONG_FORM_CONTENT_LENGTH + ' 字' });
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

  private openPreview(): void {
    if (!this.title.trim()) {
      safeShowToast(this.getUIContext(), { message: '请填写标题' });
      return;
    }
    if (this.content.length > MAX_LONG_FORM_CONTENT_LENGTH) {
      safeShowToast(this.getUIContext(), { message: '长文最多 ' + MAX_LONG_FORM_CONTENT_LENGTH + ' 字' });
      return;
    }
    const draft: PublishDraft = this.currentPublishDraft();
    publishFlowStore.beginPreview(draft, this.editingSavedDraftId);
    this.getUIContext().getRouter().pushUrl({ url: 'pages/PublishPreviewPage' });
  }

  private currentPublishDraft(): PublishDraft {
    return {
      mode: 'text',
      title: this.title.trim(),
      content: this.content,
      genre: this.genre,
      tags: this.selectedTags,
      structuredData: collectStructuredData(this.sd, this.genre),
      structuredDocument: this.structuredDocument,
      images: [],
      textPosterStyle: this.textPosterStyle,
      mentions: this.mentionRefs.length > 0 ? this.mentionRefs : undefined,
    };
  }

  private applyDraft(draft: PublishDraft, savedDraftId: string): void {
    this.genre = draft.genre;
    for (let i = 0; i < PUBLISH_GENRES.length; i++) {
      if (PUBLISH_GENRES[i].key === draft.genre) {
        this.genreIndex = i;
        break;
      }
    }
    this.selectedTags = [...draft.tags];
    this.title = draft.title;
    this.content = draft.content;
    this.sd = draft.structuredData;
    this.structuredDocument = draft.structuredDocument;
    this.textPosterStyle = resolveTextPosterStyle(draft.textPosterStyle).key;
    this.editingSavedDraftId = savedDraftId;
    this.showFields = true;
    this.showGenreMenu = false;
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
      this.reset();
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
    this.genre = 'share';
    this.genreIndex = 4; // share 位于 PUBLISH_GENRES 下标 4
    this.selectedTags = [];
    this.title = '';
    this.content = '';
    this.sd = {};
    this.structuredDocument = emptyStructuredDocument();
    this.textPosterStyle = 'paper';
    this.editingSavedDraftId = '';
    this.showFields = true;
    this.showGenreMenu = false;
    this.showTagPanel = false;
    this.mentionRefs = [];
    this.closeMention();
    this.scheduleThumbnails();
  }

  private currentGenreHint(): string {
    return publishGenreMeta(this.genre).hint;
  }

  private selectGenre(index: number): void {
    if (index < 0 || index >= PUBLISH_GENRES.length) {
      return;
    }
    const nextGenre: Genre = PUBLISH_GENRES[index].key;
    this.genreIndex = index;
    this.genre = nextGenre;
    this.structuredDocument = filterStructuredDocumentForGenre(this.structuredDocument, nextGenre);
    this.showGenreMenu = false;
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
      Text('文字海报样式')
        .fontSize(TypeTokens.callout.size).fontFamily(TypeTokens.fontFamily)
        .fontWeight(TypeTokens.headline.weight)
        .lineHeight(TypeTokens.callout.lineHeight)
        .fontColor(ColorTokens.primary)
        .width('100%')
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
      .scrollable(ScrollDirection.Horizontal)
      .scrollBar(BarState.Off)
      .width('100%')
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  compositionSection(): void {
    BaseCard({ cardPadding: SpaceTokens.md, radius: RadiusTokens.md, elevation: 1 }) {
      Column({ space: SpaceTokens.sm }) {
        PublishGenreSection({
          genre: this.genre,
          genreIndex: this.genreIndex,
          menuVisible: $showGenreMenu,
          onSelectGenre: (index: number): void => { this.selectGenre(index); },
          onOpenTags: (): void => { this.showTagPanel = true; },
        })
        if (this.selectedTags.length > 0) {
          Divider().height(LayoutTokens.hairlineWidth).color(ColorTokens.separator)
          this.circleSelector()
        }
        Divider().height(LayoutTokens.hairlineWidth).color(ColorTokens.separator)
        TextInput({ text: this.title, placeholder: '一句话标题' })
          .width('100%')
          .fontSize(TypeTokens.title.size).fontFamily(TypeTokens.fontFamilySerif)
          .fontWeight(TypeTokens.title.weight)
          .lineHeight(TypeTokens.title.lineHeight)
          .letterSpacing(TypeTokens.title.tracking)
          .fontColor(ColorTokens.primary)
          .placeholderColor(ColorTokens.quaternary)
          .backgroundColor(Color.Transparent)
          .onChange((value: string) => { this.title = value; this.scheduleThumbnails(); })
        Divider().height(LayoutTokens.hairlineWidth).color(ColorTokens.separator)
        // @提及候选：输入框「上方」的横向条（左右滑动、点选回填）
        if (this.mentionActive) {
          AtMentionSuggest({
            keyword: this.mentionKeyword,
            onPick: (c: MentionCandidate): void => { this.pickMention(c); },
          })
            .margin({ bottom: SpaceTokens.xs })
            .width('100%')
        }
        TextArea({ text: this.content, placeholder: '展开写下完整的背景、过程和结论。' })
          .width('100%')
          .height(104)
          .fontSize(TypeTokens.body.size).fontFamily(TypeTokens.fontFamily)
          .fontWeight(TypeTokens.body.weight)
          .lineHeight(TypeTokens.body.lineHeight)
          .letterSpacing(TypeTokens.body.tracking)
          .fontColor(ColorTokens.primary)
          .placeholderColor(ColorTokens.quaternary)
          .backgroundColor(Color.Transparent)
          .maxLength(MAX_LONG_FORM_CONTENT_LENGTH)
          .onChange((value: string) => {
            this.content = value;
            this.syncMention(value);
            this.scheduleThumbnails();
          })
        Text(this.content.length + '/' + MAX_LONG_FORM_CONTENT_LENGTH)
          .fontSize(TypeTokens.caption.size).fontFamily(TypeTokens.fontFamily)
          .fontColor(ColorTokens.secondary)
          .width('100%')
          .textAlign(TextAlign.End)
        Divider().height(LayoutTokens.hairlineWidth).color(ColorTokens.separator).margin({ top: SpaceTokens.sm })
        this.textPosterStyleSelector()
        // 分享体裁是轻量图文，不展示结构化信息流编辑区（见 publishGenres 的 structured 标记）
        if (publishGenreMeta(this.genre).structured) {
          StructuredComposer({
            document: this.structuredDocument,
            genreLabel: this.genre,
            expanded: $showFields,
            onDocumentChange: (document: StructuredDocument): void => { this.structuredDocument = document; },
          })
        }
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
    }
  }

  @Builder
  tagPill(name: string): void {
    Pressable({
      visualHeight: LayoutTokens.segmentedHeight,
      action: () => { this.toggleTag(name); },
    }) {
      Row({ space: SpaceTokens.inlineTight }) {
        Text(name)
          .fontSize(TypeTokens.callout.size).fontFamily(TypeTokens.fontFamily)
          .fontWeight(TypeTokens.caption.weight)
          .lineHeight(TypeTokens.callout.lineHeight)
          .fontColor(ColorTokens.onBrand)
        Image($r('app.media.close_x_white'))
          .width(IconTokens.compact)
          .height(IconTokens.compact)
          .fillColor(Color.White)
      }
      .height(LayoutTokens.segmentedHeight)
      .padding({ left: SpaceTokens.item, right: SpaceTokens.item })
      .backgroundColor(ColorTokens.brand)
      .borderRadius(RadiusTokens.sm)
      .alignItems(VerticalAlign.Center)
    }
  }

  @Builder
  circleSelector(): void {
    if (this.selectedTags.length > 0) {
      Flex({
        wrap: FlexWrap.Wrap,
        space: { main: LengthMetrics.px(SpaceTokens.inline), cross: LengthMetrics.px(SpaceTokens.inline) },
      }) {
        ForEach(this.selectedTags, (name: string) => {
          this.tagPill(name)
        }, (name: string) => 'selected_' + name)
      }
      .width('100%')
    }
  }

  build() {
    Stack({ alignContent: Alignment.Top }) {
      Scroll() {
        Column({ space: SpaceTokens.md }) {
          Row().height(this.statusBarHeight + 52).width('100%')
          this.compositionSection()
          Row().height(SpaceTokens.x2l).width('100%')
        }
        .width('100%')
        .padding({ left: SpaceTokens.sm, right: SpaceTokens.sm, bottom: SpaceTokens.x3l })
        .alignItems(HorizontalAlign.Start)
      }
      .width('100%')
      .height('100%')
      .scrollBar(BarState.Off)
      .backgroundColor(ColorTokens.canvas)

      Row() {
        PublishTopBar({
          progressText: this.draftProgressText(),
          previewDisabled: this.title.trim().length === 0,
          onClear: (): void => { this.reset(); },
          onPreview: (): void => { this.openPreview(); },
          onBack: (): void => { this.getUIContext().getRouter().back(); },
        })
      }
      .width('100%')
      .padding({ left: SpaceTokens.sm, right: SpaceTokens.sm, top: this.statusBarHeight + SpaceTokens.xs, bottom: SpaceTokens.sm })
    }
    .width('100%')
    .height('100%')
    .backgroundColor(ColorTokens.canvas)
    // 选择圈子：bindSheet 底部弹层（替代原全屏覆盖面板）
    .bindSheet(this.showTagPanel, this.tagSheet(), {
      height: '60%',
      dragBar: true,
      // 内容自绘分段栏同款玻璃（backdropBlur + 高光边框），不再叠系统模糊
      blurStyle: BlurStyle.NONE,
      // 关闭由内容内"完成"按钮与下滑手势负责，隐藏系统右上角关闭按钮避免与标题重叠
      showClose: false,
      maskColor: '#33000000',
      onDisappear: (): void => { this.showTagPanel = false; },
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
      onToggle: (name: string): void => { this.toggleTag(name); },
      onClose: (): void => { this.showTagPanel = false; },
    })
  }
}
