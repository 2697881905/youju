// 图文发布页 — 独立 @Entry 页面，仅处理短文图文，不耦合视频/长文发布逻辑。
// 媒体区直接渲染 ImagePicker，无 mediaTypeSelector 切换行。
import { listTags, aiAssistEnabled, aiPolishDraft, AiPolishDraftResult } from '../services/api';
import { Genre, StructuredData, StructuredDocument, Tag, MentionRef, MentionCandidate } from '../models/types';
import { ImagePicker } from '../components/ImagePicker';
import { safeShowToast } from '../utils/toast';
import { AiAssistChip } from '../components/AiAssistChip';
import { AiPolishPreviewSheet } from '../components/AiPolishPreviewSheet';
import { findActiveAtMention, applyAtMention } from '../utils/atMention';
import { AtMentionSuggest } from '../components/AtMentionSuggest';
import { Reveal } from '../design/motion/Reveal';
import { ImmersiveSegmentBar } from '../design/components/ImmersiveSegmentBar';
import { ColorTokens } from '../design/tokens/color';
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
import { StructuredReviewSheet } from '../components/StructuredReviewSheet';
import { executePublish, PublishOutcome } from '../utils/publishExecutor';
import { PublishTagPanel } from '../components/PublishTagPanel';
import { PUBLISH_GENRES, PUBLISH_GENRE_SEGMENTS, publishGenreMeta } from '../utils/publishGenres';
import { PublishSection } from '../components/PublishSection';
import { PublishCircleSelector } from '../components/PublishCircleSelector';
import { PublishCollectionPicker } from '../components/PublishCollectionPicker';
import { consumePendingPublishCircle } from '../utils/publishCircleIntent';
import { PublishPageShell, PUBLISH_BAR_ROW_VP } from '../components/PublishPageShell';
import { GlassBlurStyle, getSheetImmersiveMaterial, isSystemMaterialActive } from '../utils/immersiveMaterial';

const MAX_SELECTED_TAGS: number = 3;
const MAX_PICKED_IMAGES: number = 9;
const MAX_PHOTO_CONTENT_LENGTH: number = 300;
const DRAFT_PROGRESS_TOTAL: number = 3;
// 说明区高度：300 字给 104vp 要在小窗里滚动，读不出排版感
const PHOTO_BODY_HEIGHT: number = 148;

@Entry
@Component
struct PhotoPublishPage {
  @State genre: Genre = 'share';
  @State genreIndex: number = 4; // share 位于 PUBLISH_GENRES 下标 4
  @State selectedTags: string[] = [];
  @State selectedCollectionId: number = 0;
  @State title: string = '';
  // —— AI 联合优化（标题 + 正文轻度润色）：结果先进「新旧对照」预览，作者确认才回填 ——
  @State aiTitleBusy: boolean = false;
  @State aiEnabled: boolean = false;
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
  @State images: string[] = [];
  @State tags: Tag[] = [];
  // 结构化区默认折叠（2026-11-07 发布流改版）：主路径是「写说明 → 点发布 → AI 拆块 → 审稿」。
  @State showFields: boolean = false;
  @State showTagPanel: boolean = false;
  // —— 结构化审稿层（点发布弹出；revision 用于弹层复用时强制重新初始化） ——
  @State reviewSheetShown: boolean = false;
  @State reviewSheetRevision: number = 0;
  @State editingSavedDraftId: string = '';
  @StorageLink('authUserId') @Watch('onUserChange') uid: string = '';
  @StorageLink('statusBarHeight') statusBarHeight: number = 0;
  @State categoryList: string[] = [];
  @State tagsByCategory: Record<string, Tag[]> = {};
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
    aiAssistEnabled().then((enabled: boolean): void => { this.aiEnabled = enabled; });
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

  // 点发布：结构化体裁进审稿层（AI 拆块 → 逐块确认 → 确认即发布），
  // 分享体裁保持「预览页 → 确认发布」原路径。发布永不被 AI 卡死：层内自带手动骨架兜底。
  private onPublish(): void {
    if (!this.title.trim()) {
      safeShowToast(this.getUIContext(), { message: '请填写标题' });
      return;
    }
    if (this.content.length > MAX_PHOTO_CONTENT_LENGTH) {
      safeShowToast(this.getUIContext(), { message: '图文说明最多 ' + MAX_PHOTO_CONTENT_LENGTH + ' 字' });
      return;
    }
    if (publishGenreMeta(this.genre).structured) {
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
    if (genre.length > 0 && genre !== this.genre) {
      for (let i = 0; i < PUBLISH_GENRES.length; i++) {
        if (PUBLISH_GENRES[i].key === genre) {
          this.genreIndex = i;
          this.genre = PUBLISH_GENRES[i].key;
          break;
        }
      }
    }
    const draft: PublishDraft = this.currentPublishDraft();
    const outcome: PublishOutcome = await executePublish(draft, this.getUIContext());
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
      tags: this.selectedTags,
      structuredData: collectStructuredData(this.sd, this.genre),
      structuredDocument: this.structuredDocument,
      images: this.images,
      mentions: this.mentionRefs.length > 0 ? this.mentionRefs : undefined,
      collectionId: this.selectedCollectionId,
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
    this.images = [...draft.images];
    this.selectedCollectionId = draft.collectionId ?? 0;
    this.editingSavedDraftId = savedDraftId;
    this.showFields = false;
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
      // 新发布不自动弹系统相册：三种方式一律落在编辑页，选图由图片区的「+ 添加」触发。
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
    const pendingCircle: string = consumePendingPublishCircle();
    this.selectedTags = pendingCircle.length > 0 ? [pendingCircle] : [];
    this.title = '';
    this.content = '';
    this.sd = {};
    this.structuredDocument = emptyStructuredDocument();
    this.images = [];
    this.editingSavedDraftId = '';
    this.showFields = false;
    this.showTagPanel = false;
    this.mentionRefs = [];
    this.closeMention();
  }

  // 清空是破坏性动作（标题/正文/已选媒体一并抹掉且不可恢复）：先二次确认，避免与「发布」并排误触。
  private confirmClear(): void {
    this.getUIContext().showAlertDialog({
      title: '清空草稿？',
      message: '标题、正文与已选媒体将被清空，且无法恢复。',
      primaryButton: {
        value: '取消',
        action: (): void => {},
      },
      secondaryButton: {
        value: '清空',
        fontColor: ColorTokens.danger,
        action: (): void => { this.reset(); },
      },
    });
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

  // ─────────────── 版式（创作纸）：媒体附件 → 标题/正文纸面 → 发布设置托盘 → 结构化 ───────────────
  // 写作是主角：标题与正文直接落在纸面上，不套表单卡；体裁/圈子/合集/AI/清空收进单一设置托盘。

  // 轻量分区题头（无卡壳）：左标签 + 右元信息，用于媒体等附件区与托盘内分组。
  @Builder
  blockCaption(label: string, meta: string): void {
    Row() {
      Text(label)
        .fontSize(TypeTokens.overline.size).fontFamily(TypeTokens.fontFamily)
        .fontWeight(TypeTokens.overline.weight)
        .lineHeight(TypeTokens.overline.lineHeight)
        .letterSpacing(TypeTokens.overline.tracking)
        .fontColor(ColorTokens.tertiary)
      Blank().layoutWeight(1)
      if (meta.length > 0) {
        Text(meta)
          .fontSize(TypeTokens.overline.size).fontFamily(TypeTokens.fontFamily)
          .fontWeight(TypeTokens.overline.weight)
          .lineHeight(TypeTokens.overline.lineHeight)
          .letterSpacing(TypeTokens.overline.tracking)
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
        })
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
    }
  }

  // 创作纸：标题与正文同处一张软质纸面（subtle 底大圆角），发丝线分隔，统一写作面语言。
  @Builder
  writingSheet(): void {
    Reveal({ index: 1 }) {
      Column() {
        TextInput({
          text: $$this.title,
          placeholder: this.aiEnabled && this.title.length === 0 && this.content.trim().length > 0
            ? '写完正文了？AI 润色可顺带起标题'
            : '给这篇起个标题',
        })
          .width('100%')
          .fontSize(TypeTokens.displaySerif.size).fontFamily(TypeTokens.fontFamilySerif)
          .fontWeight(TypeTokens.displaySerif.weight)
          .lineHeight(TypeTokens.displaySerif.lineHeight)
          .fontColor(ColorTokens.primary)
          .placeholderColor(ColorTokens.tertiary)
          .backgroundColor(Color.Transparent)
          .padding({ left: SpaceTokens.base, right: SpaceTokens.base, top: SpaceTokens.base, bottom: SpaceTokens.md })
          .enterKeyType(EnterKeyType.Next)
          .onChange((value: string) => { this.title = value; })
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
          .height(PHOTO_BODY_HEIGHT)
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
          })
      }
      .width('100%')
      .backgroundColor(ColorTokens.subtle)
      .borderRadius(RadiusTokens.lg)
      .alignItems(HorizontalAlign.Start)
    }
  }

  // 发布设置托盘：体裁 / 圈子 / 合集 / AI / 清空 收进单一卡，发丝线分组，取代四张平级表单卡。
  @Builder
  settingsTray(): void {
    PublishSection({ title: '发布设置', index: 2 }) {
      Column({ space: SpaceTokens.md }) {
        Column({ space: SpaceTokens.sm }) {
          this.blockCaption('体裁', '')
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

        Divider().strokeWidth(LayoutTokens.hairlineWidth).color(ColorTokens.separator)

        Column({ space: SpaceTokens.sm }) {
          this.blockCaption('圈子', '已选 ' + this.selectedTags.length + '/' + MAX_SELECTED_TAGS)
          PublishCircleSelector({
            selectedTags: this.selectedTags,
            maxSelected: MAX_SELECTED_TAGS,
            onAdd: (): void => { this.showTagPanel = true; },
            onRemove: (name: string): void => { this.toggleTag(name); },
          })
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)

        Divider().strokeWidth(LayoutTokens.hairlineWidth).color(ColorTokens.separator)

        PublishCollectionPicker({ selectedId: $selectedCollectionId })

        Divider().strokeWidth(LayoutTokens.hairlineWidth).color(ColorTokens.separator)

        Row() {
          Row() {
            AiAssistChip({
              label: 'AI 优化',
              busy: this.aiTitleBusy,
              available: this.aiEnabled,
              action: (): void => { this.aiPolish(); },
            })
          }
          .height(LayoutTokens.minTouchTarget)
          .alignItems(VerticalAlign.Center)
          .onClick((): void => { this.aiPolish(); })
          Blank().layoutWeight(1)
          Row() {
            Text('清空草稿')
              .fontSize(TypeTokens.callout.size).fontFamily(TypeTokens.fontFamily)
              .fontWeight(TypeTokens.callout.weight)
              .fontColor(ColorTokens.tertiary)
          }
          .height(LayoutTokens.minTouchTarget)
          .alignItems(VerticalAlign.Center)
          .onClick((): void => { this.confirmClear(); })
        }
        .width('100%')
        .alignItems(VerticalAlign.Center)
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
    }
  }

  @Builder
  compositionColumn(): void {
    this.mediaBlock()
    this.writingSheet()
    this.settingsTray()
    // 分享体裁是轻量图文，不展示结构化信息流编辑区（见 publishGenres 的 structured 标记）
    if (publishGenreMeta(this.genre).structured) {
      Reveal({ index: 3 }) {
        StructuredComposer({
          document: this.structuredDocument,
          genreLabel: this.genre,
          contentText: this.content,
          expanded: $showFields,
          onDocumentChange: (document: StructuredDocument): void => { this.structuredDocument = document; },
        })
      }
    }
  }

  build() {
    // 统一外壳 PublishPageShell 封装渐变模糊顶栏 + 穿底。@Entry 根须内置容器，且自定义组件尾随闭包后
    // 不能直接链通用属性 → 用 Stack 包住外壳：bindSheet 挂 Stack（半模态），bindContentCover 挂内层 Scroll（全模态）。
    Stack() {
      PublishPageShell({
        modeLabel: '发布图文',
        progressValue: this.calcDraftProgress(),
        progressTotal: DRAFT_PROGRESS_TOTAL,
        hint: this.draftHint(),
        actionLabel: '发布',
        actionDisabled: this.title.trim().length === 0,
        scroller: this.publishScroller,
        onAction: (): void => { this.onPublish(); },
        onBack: (): void => { this.getUIContext().getRouter().back(); },
      }) {
        Scroll(this.publishScroller) {
          Column({ space: SpaceTokens.md }) {
            // 穿底让位：状态栏 + 栏高 + 呼吸（enableComponentSafeArea=false 后自补）
            Row().height(this.statusBarHeight + PUBLISH_BAR_ROW_VP + SpaceTokens.sm).width('100%')
            this.compositionColumn()
          }
          .width('100%')
          .padding({ left: SpaceTokens.base, right: SpaceTokens.base, bottom: SpaceTokens.x2l })
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
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(ColorTokens.canvas)
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

  // 结构化审稿弹层：revision 递增驱动内部重新初始化（复用实例时 aboutToAppear 不会再跑）
  @Builder
  reviewSheet(): void {
    StructuredReviewSheet({
      genre: this.genre,
      contentText: this.content,
      initialDocument: this.structuredDocument,
      aiAvailable: this.aiEnabled,
      resetKey: this.reviewSheetRevision,
      onConfirm: (document: StructuredDocument, genre: string): void => { this.confirmPublish(document, genre); },
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
