// 视频发布页 — 独立 @Entry 页面，仅处理视频发布，不耦合图文/文字发布逻辑。
// 媒体区直接渲染 VideoPicker，无 mediaTypeSelector 切换行。
import { LengthMetrics, router } from '@kit.ArkUI';
import { listTags } from '../services/api';
import { Genre, StructuredData, Tag } from '../models/types';
import { VideoPicker } from '../components/VideoPicker';
import { safeShowToast } from '../utils/toast';
import { resolveActionIcon } from '../utils/actionIcons';
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
import { genreStructuredFields, readStructuredField, withStructuredField } from '../utils/structuredFields';
import { PublishStructuredSupplement } from '../components/PublishStructuredSupplement';
import { PublishTagPanel } from '../components/PublishTagPanel';
import { PUBLISH_GENRES, publishGenreMeta } from '../utils/publishGenres';
import { PublishGenreSection } from '../components/PublishGenreSection';
import { PublishTopBar } from '../components/PublishTopBar';

const MAX_SELECTED_TAGS: number = 3;
const DRAFT_PROGRESS_TOTAL: number = 3;

@Entry
@Component
struct VideoPublishPage {
  @State genre: Genre = 'share';
  @State genreIndex: number = 4; // share 位于 PUBLISH_GENRES 下标 4
  @State selectedTags: string[] = [];
  @State title: string = '';
  @State content: string = '';
  @State sd: StructuredData = {};
  @State videoUrl: string = '';
  @State videoCover: string = '';
  @State tags: Tag[] = [];
  @State showFields: boolean = false;
  @State showGenreMenu: boolean = false;
  @State showTagPanel: boolean = false;
  @State editingSavedDraftId: string = '';
  @StorageLink('authUserId') @Watch('onUserChange') uid: string = '';
  @StorageLink('statusBarHeight') statusBarHeight: number = 0;
  @State categoryList: string[] = [];
  @State tagsByCategory: Record<string, Tag[]> = {};
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

  private onFieldChange(key: keyof StructuredData, value: string): void {
    this.sd = withStructuredField(this.sd, key, value);
  }

  private buildStructuredData(): StructuredData {
    let out: StructuredData = {};
    for (const item of genreStructuredFields(this.genre)) {
      const raw: string | number | undefined = readStructuredField(this.sd, item[0]);
      if (raw !== undefined && raw !== '') {
        out = withStructuredField(out, item[0], String(raw));
      }
    }
    return out;
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
    const draft: PublishDraft = this.currentPublishDraft();
    publishFlowStore.beginPreview(draft, this.editingSavedDraftId);
    this.getUIContext().getRouter().pushUrl({ url: 'pages/PublishPreviewPage' });
  }

  private currentPublishDraft(): PublishDraft {
    return {
      title: this.title.trim(),
      content: this.content,
      genre: this.genre,
      tags: this.selectedTags,
      structuredData: this.buildStructuredData(),
      images: [],
      videoUrl: this.videoUrl,
      videoCover: this.videoCover,
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
    this.videoUrl = draft.videoUrl ?? '';
    this.videoCover = draft.videoCover ?? '';
    this.editingSavedDraftId = savedDraftId;
    this.showFields = false;
    this.showGenreMenu = false;
    this.showTagPanel = false;
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
    this.videoUrl = '';
    this.videoCover = '';
    this.editingSavedDraftId = '';
    this.showFields = false;
    this.showGenreMenu = false;
    this.showTagPanel = false;
  }

  private currentGenreHint(): string {
    return publishGenreMeta(this.genre).hint;
  }

  private selectGenre(index: number): void {
    if (index < 0 || index >= PUBLISH_GENRES.length) {
      return;
    }
    this.genreIndex = index;
    this.genre = PUBLISH_GENRES[index].key;
    this.showGenreMenu = false;
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
          .fontSize(TypeTokens.title.size).fontFamily(TypeTokens.fontFamily)
          .fontWeight(TypeTokens.title.weight)
          .lineHeight(TypeTokens.title.lineHeight)
          .letterSpacing(TypeTokens.title.tracking)
          .fontColor(ColorTokens.primary)
          .placeholderColor(ColorTokens.quaternary)
          .backgroundColor(Color.Transparent)
          .onChange((value: string) => { this.title = value; })
        Divider().height(LayoutTokens.hairlineWidth).color(ColorTokens.separator)
        TextArea({ text: this.content, placeholder: '展开讲讲背景、过程、结论。尽量给出你踩过的坑、判断标准和适用人群。' })
          .width('100%')
          .height(104)
          .fontSize(TypeTokens.body.size).fontFamily(TypeTokens.fontFamily)
          .fontWeight(TypeTokens.body.weight)
          .lineHeight(TypeTokens.body.lineHeight)
          .letterSpacing(TypeTokens.body.tracking)
          .fontColor(ColorTokens.primary)
          .placeholderColor(ColorTokens.quaternary)
          .backgroundColor(Color.Transparent)
          .onChange((value: string) => { this.content = value; })
        Divider().height(LayoutTokens.hairlineWidth).color(ColorTokens.separator).margin({ top: SpaceTokens.sm })
        VideoPicker({ videoUrl: $videoUrl, videoCover: $videoCover })
        PublishStructuredSupplement({
          genre: this.genre,
          hint: this.currentGenreHint(),
          data: this.sd,
          expanded: $showFields,
          onChange: (key: keyof StructuredData, value: string): void => { this.onFieldChange(key, value); },
        })
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
        Image(resolveActionIcon('close'))
          .width(IconTokens.compact)
          .height(IconTokens.compact)
          .fillColor(ColorTokens.onBrand)
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
          onBack: (): void => { router.back(); },
        })
      }
      .width('100%')
      .padding({ left: SpaceTokens.sm, right: SpaceTokens.sm, top: this.statusBarHeight + SpaceTokens.xs, bottom: SpaceTokens.sm })

      if (this.showTagPanel) {
        Column() {
          PublishTagPanel({
            categoryList: this.categoryList,
            tagsByCategory: this.tagsByCategory,
            selectedTags: this.selectedTags,
            maxSelected: MAX_SELECTED_TAGS,
            onToggle: (name: string): void => { this.toggleTag(name); },
            onClose: (): void => { this.showTagPanel = false; },
          })
        }
        .width('100%')
        .height('100%')
        .padding({ top: this.statusBarHeight })
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(ColorTokens.canvas)
  }
}
