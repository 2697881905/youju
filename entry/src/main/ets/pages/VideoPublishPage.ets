// 视频发布页 — 独立 @Entry 页面，仅处理视频发布，不耦合图文/长文发布逻辑。
// 媒体区直接渲染 VideoPicker，无 mediaTypeSelector 切换行。
import { listTags } from '../services/api';
import { Genre, StructuredData, StructuredDocument, Tag, MentionRef, MentionCandidate } from '../models/types';
import { VideoPicker } from '../components/VideoPicker';
import { safeShowToast } from '../utils/toast';
import { findActiveAtMention, applyAtMention } from '../utils/atMention';
import { AtMentionSuggest } from '../components/AtMentionSuggest';
import { Reveal } from '../design/motion/Reveal';
import { ImmersiveSegmentBar } from '../design/components/ImmersiveSegmentBar';
import { ColorTokens } from '../design/tokens/color';
import { RadiusTokens } from '../design/tokens/radius';
import { SpaceTokens } from '../design/tokens/space';
import { TypeTokens } from '../design/tokens/type';
import { PublishDraft } from '../utils/publishDraft';
import { removePostDraft } from '../utils/postDraftStore';
import { getUserId } from '../utils/auth';
import { PublishSession, publishFlowStore } from '../utils/publishFlowStore';
import { collectStructuredData } from '../utils/structuredFields';
import { emptyStructuredDocument, filterStructuredDocumentForGenre } from '../utils/structuredDocument';
import { StructuredComposer } from '../components/StructuredComposer';
import { PublishTagPanel } from '../components/PublishTagPanel';
import { PUBLISH_GENRES, PUBLISH_GENRE_SEGMENTS, publishGenreMeta } from '../utils/publishGenres';
import { PublishSection } from '../components/PublishSection';
import { PublishCircleSelector } from '../components/PublishCircleSelector';
import { PublishTopBar } from '../components/PublishTopBar';
import { GlassBlurStyle, getSheetImmersiveMaterial, isSystemMaterialActive } from '../utils/immersiveMaterial';
import { FALLBACK_VIDEO_ASPECT_RATIO } from '../utils/video';

const MAX_SELECTED_TAGS: number = 3;
const DRAFT_PROGRESS_TOTAL: number = 3;
// 顶栏占位：栏体 48vp + 与首张卡之间 12vp 呼吸（与 PublishTopBar 内高对齐）
const COMPOSER_TOP_RESERVE: number = 60;
// 视频正文区：5000 字的「展开讲讲」给 104vp，等于在小窗里滚动写长评
const VIDEO_BODY_HEIGHT: number = 220;
const MAX_VIDEO_TITLE_LENGTH: number = 100;
const MAX_VIDEO_CONTENT_LENGTH: number = 5000;

@Entry
@Component
struct VideoPublishPage {
  @State genre: Genre = 'share';
  @State genreIndex: number = 4; // share 位于 PUBLISH_GENRES 下标 4
  @State selectedTags: string[] = [];
  @State title: string = '';
  @State content: string = '';
  @State sd: StructuredData = {};
  @State structuredDocument: StructuredDocument = emptyStructuredDocument();
  @State videoUrl: string = '';
  @State videoCover: string = '';
  @State videoAspectRatio: number = FALLBACK_VIDEO_ASPECT_RATIO;
  @State tags: Tag[] = [];
  // 结构化区默认展开：它是产品核心特色，藏在折叠里等于没有（覆盖率的最大杀手）
  @State showFields: boolean = true;
  @State showTagPanel: boolean = false;
  @State editingSavedDraftId: string = '';
  @StorageLink('authUserId') @Watch('onUserChange') uid: string = '';
  @StorageLink('statusBarHeight') statusBarHeight: number = 0;
  @State categoryList: string[] = [];
  @State tagsByCategory: Record<string, Tag[]> = {};
  // —— 视频说明 @提及 选择器 ——
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
    if (this.content.trim().length > 0 || this.videoUrl.length > 0) {
      done += 1;
    }
    if (this.selectedTags.length > 0) {
      done += 1;
    }
    return done;
  }

  // 顶栏进度条旁边那句「下一步做什么」：只报缺口，不报已完成的事。
  private draftHint(): string {
    if (this.videoUrl.length === 0) {
      return '先选一条视频';
    }
    if (this.title.trim().length === 0) {
      return '再写一句标题';
    }
    if (this.selectedTags.length === 0) {
      return '选一个圈子';
    }
    return '可以预览了';
  }

  aboutToAppear(): void {
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
  }

  aboutToDisappear(): void {
    this.unsubscribePublishFlow();
    this.unsubscribePublishFlow = () => {};
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

  // —— 视频说明 @提及 编辑辅助 ——
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
    if (nextText.length > 20000) {
      safeShowToast(this.getUIContext(), { message: '正文过长' });
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

  private openPreview(): void {
    if (!this.title.trim()) {
      safeShowToast(this.getUIContext(), { message: '请填写标题' });
      return;
    }
    const draft: PublishDraft = this.currentPublishDraft();
    publishFlowStore.beginPreview(draft, this.editingSavedDraftId);
    this.getUIContext().getRouter().pushUrl({ url: 'pages/PublishPreviewPage' });
  }

  private currentPublishDraft(): PublishDraft {
    return {
      mode: 'video',
      title: this.title.trim(),
      content: this.content,
      genre: this.genre,
      tags: this.selectedTags,
      structuredData: collectStructuredData(this.sd, this.genre),
      structuredDocument: this.structuredDocument,
      images: [],
      videoUrl: this.videoUrl,
      videoCover: this.videoCover,
      videoAspectRatio: this.videoAspectRatio,
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
    this.videoUrl = draft.videoUrl ?? '';
    this.videoCover = draft.videoCover ?? '';
    this.videoAspectRatio = draft.videoAspectRatio ?? FALLBACK_VIDEO_ASPECT_RATIO;
    this.editingSavedDraftId = savedDraftId;
    this.showFields = true;
    this.showTagPanel = false;
    this.closeMention();
    this.mentionRefs = draft.mentions !== undefined ? draft.mentions.map((m: MentionRef): MentionRef => ({
      name: m.name,
      userId: m.userId,
    })) : [];
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
    this.videoUrl = '';
    this.videoCover = '';
    this.videoAspectRatio = FALLBACK_VIDEO_ASPECT_RATIO;
    this.editingSavedDraftId = '';
    this.showFields = true;
    this.showTagPanel = false;
    this.mentionRefs = [];
    this.closeMention();
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
  }

  // ─────────────── 版式：体裁 → 媒体 → 正文 → 分类 → 结构化 ───────────────
  // 每个环节一张卡（PublishSection 自带衬线小节标题与错峰入场），
  // 不再是一整张巨卡里用 5 条 Divider 切字段。

  @Builder
  sectionLabel(text: string): void {
    Text(text)
      .fontSize(TypeTokens.overline.size).fontFamily(TypeTokens.fontFamily)
      .fontWeight(TypeTokens.overline.weight)
      .lineHeight(TypeTokens.overline.lineHeight)
      .letterSpacing(TypeTokens.overline.tracking)
      .fontColor(ColorTokens.tertiary)
      .width('100%')
  }

  // 体裁：直接从 5 个候选里点选，取代「自绘玻璃按钮 → 系统滚轮弹窗 → 确认」三步。
  @Builder
  genreBar(): void {
    Reveal({ index: 0 }) {
      Column({ space: SpaceTokens.sm }) {
        this.sectionLabel('内容体裁')
        // 内容体裁分段（官方 SegmentButton 默认轨道材质，内容区正常出图）
        ImmersiveSegmentBar({
          items: PUBLISH_GENRE_SEGMENTS,
          selectedIndex: $genreIndex,
          onSelect: (index: number): void => { this.selectGenre(index); },
        })
        Text(this.currentGenreHint())
          .fontSize(TypeTokens.callout.size).fontFamily(TypeTokens.fontFamily)
          .fontWeight(TypeTokens.callout.weight)
          .lineHeight(TypeTokens.callout.lineHeight)
          .fontColor(ColorTokens.secondary)
          .width('100%')
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
    }
  }

  @Builder
  mediaSection(): void {
    PublishSection({ title: '视频', meta: '封面自动取首帧', index: 1 }) {
      VideoPicker({ videoUrl: $videoUrl, videoCover: $videoCover, videoAspectRatio: $videoAspectRatio })
    }
  }

  @Builder
  bodySection(): void {
    PublishSection({ title: '正文', meta: '标题 + 说明', index: 2 }) {
      Column({ space: SpaceTokens.sm }) {
        this.sectionLabel('标题')
        TextInput({ text: this.title, placeholder: '一句话标题' })
          .maxLength(MAX_VIDEO_TITLE_LENGTH)
          .width('100%')
          .fontSize(TypeTokens.title.size).fontFamily(TypeTokens.fontFamilySerif)
          .fontWeight(TypeTokens.title.weight)
          .lineHeight(TypeTokens.title.lineHeight)
          .letterSpacing(TypeTokens.title.tracking)
          .fontColor(ColorTokens.primary)
          .placeholderColor(ColorTokens.tertiary)
          .backgroundColor(ColorTokens.subtle)
          .borderRadius(RadiusTokens.md)
          .padding({ left: SpaceTokens.md, right: SpaceTokens.md })
          .enterKeyType(EnterKeyType.Next)
          .onChange((value: string) => { this.title = value; })
        this.sectionLabel('说明')
        // @提及候选：输入框「上方」的横向条（左右滑动、点选回填）
        if (this.mentionActive) {
          AtMentionSuggest({
            keyword: this.mentionKeyword,
            onPick: (c: MentionCandidate): void => { this.pickMention(c); },
          })
            .width('100%')
        }
        TextArea({ text: this.content, placeholder: '展开讲讲背景、过程、结论。尽量给出你踩过的坑、判断标准和适用人群。' })
          .maxLength(MAX_VIDEO_CONTENT_LENGTH)
          .width('100%')
          .height(VIDEO_BODY_HEIGHT)
          .fontSize(TypeTokens.body.size).fontFamily(TypeTokens.fontFamily)
          .fontWeight(TypeTokens.body.weight)
          .lineHeight(TypeTokens.body.lineHeight)
          .letterSpacing(TypeTokens.body.tracking)
          .fontColor(ColorTokens.primary)
          .placeholderColor(ColorTokens.tertiary)
          .backgroundColor(ColorTokens.subtle)
          .borderRadius(RadiusTokens.md)
          .padding(SpaceTokens.md)
          // 系统字数计数器：视频页此前完全没有字数提示
          .showCounter(true, { highlightBorder: false })
          .onChange((value: string) => {
            this.content = value;
            this.syncMention(value);
          })
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
    }
  }

  @Builder
  circleSection(): void {
    PublishSection({
      title: '分类',
      meta: '已选 ' + this.selectedTags.length + '/' + MAX_SELECTED_TAGS,
      index: 3,
    }) {
      PublishCircleSelector({
        selectedTags: this.selectedTags,
        maxSelected: MAX_SELECTED_TAGS,
        onAdd: (): void => { this.showTagPanel = true; },
        onRemove: (name: string): void => { this.toggleTag(name); },
      })
    }
  }

  @Builder
  compositionColumn(): void {
    this.genreBar()
    this.mediaSection()
    this.bodySection()
    this.circleSection()
    // 分享体裁是轻量图文，不展示结构化信息流编辑区（见 publishGenres 的 structured 标记）
    if (publishGenreMeta(this.genre).structured) {
      Reveal({ index: 4 }) {
        StructuredComposer({
          document: this.structuredDocument,
          genreLabel: this.genre,
          expanded: $showFields,
          onDocumentChange: (document: StructuredDocument): void => { this.structuredDocument = document; },
        })
      }
    }
  }

  build() {
    Stack({ alignContent: Alignment.Top }) {
      Scroll() {
        Column({ space: SpaceTokens.md }) {
          Row().height(this.statusBarHeight + COMPOSER_TOP_RESERVE).width('100%')
          this.compositionColumn()
          Row().height(SpaceTokens.x2l).width('100%')
        }
        .width('100%')
        .padding({ left: SpaceTokens.base, right: SpaceTokens.base, bottom: SpaceTokens.x3l })
        .alignItems(HorizontalAlign.Start)
      }
      .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true })
      .width('100%')
      .height('100%')
      .scrollBar(BarState.Off)
      .backgroundColor(ColorTokens.canvas)

      // 顶栏是压在 Scroll 之上的浮层（本页不是 Navigation 页），CustomComponent 不能挂
      // 通用属性 → 状态栏留白交给外层 Row
      Row() {
        PublishTopBar({
          progressValue: this.calcDraftProgress(),
          progressTotal: DRAFT_PROGRESS_TOTAL,
          hint: this.draftHint(),
          previewDisabled: this.title.trim().length === 0,
          onClear: (): void => { this.reset(); },
          onPreview: (): void => { this.openPreview(); },
          onBack: (): void => { this.getUIContext().getRouter().back(); },
        })
      }
      .width('100%')
      .padding({ top: this.statusBarHeight })
    }
    .width('100%')
    .height('100%')
    .backgroundColor(ColorTokens.canvas)
    // 选择圈子：bindSheet 底部弹层（替代原全屏覆盖面板）
    .bindSheet(this.showTagPanel, this.tagSheet(), {
      height: '60%',
      dragBar: true,
      // 材质载体是 SheetOptions.systemMaterial（半模态的唯一生效入口），面板内部不再自绘暖纸
      systemMaterial: getSheetImmersiveMaterial(),
      blurStyle: isSystemMaterialActive() ? BlurStyle.NONE : GlassBlurStyle.Floating,
      backgroundColor: isSystemMaterialActive() ? undefined : ColorTokens.canvas,
      // 关闭由内容内「完成」按钮与下滑手势负责，隐藏系统右上角关闭按钮避免与标题重叠
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
