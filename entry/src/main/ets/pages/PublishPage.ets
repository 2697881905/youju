// 发布器 — Phase 2.5：玻璃操作栏 + 渐进式发布工作流；业务提交语义保持不变。
import { LengthMetrics } from '@kit.ArkUI';
import { listTags } from '../services/api';
import { Genre, StructuredData, Tag } from '../models/types';
import { ImagePicker } from '../components/ImagePicker';
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
import { barBottomReserve } from '../utils/cardTokens';
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
const MAX_PICKED_IMAGES: number = 9;
const DRAFT_PROGRESS_TOTAL: number = 3;

@Component
export struct PublishPage {
  @State genre: Genre = 'review';
  @State genreIndex: number = 0;
  @State selectedTags: string[] = [];
  @State title: string = '';
  @State content: string = '';
  @State sd: StructuredData = {};
  @State images: string[] = [];
  @State videoUrl: string = '';
  @State videoCover: string = '';
  @State tags: Tag[] = [];
  @State showFields: boolean = false;
  @State showGenreMenu: boolean = false;
  @State showTagPanel: boolean = false;
  @State publishMode: 'photo' | 'text' | 'video' = 'photo';
  @State textPosterStyle: string = 'paper';
  @State editingSavedDraftId: string = '';
  @State imagePickerRequest: number = 0;
  @StorageLink('authUserId') @Watch('onUserChange') uid: string = '';
  @State categoryList: string[] = [];
  @State tagsByCategory: Record<string, Tag[]> = {};
  private unsubscribePublishFlow: () => void = () => {};
  private lastPublishFlowRevision: number = -1;

  private calcDraftProgress(): number {
    let done: number = 0;
    if (this.title.trim().length > 0) {
      done += 1;
    }
    if (this.content.trim().length > 0 || this.images.length > 0 || this.videoUrl.length > 0) {
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
    const out: Record<string, string | number> = {};
    for (const item of genreStructuredFields(this.genre)) {
      const raw = readStructuredField(this.sd, item[0]);
      if (raw !== undefined && raw !== '') {
        if (item[0] === 'rating') {
          const n = Number(raw);
          if (!isNaN(n)) {
            out['rating'] = n;
          }
        } else {
          out[item[0] as string] = String(raw);
        }
      }
    }
    return out as StructuredData;
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
      images: this.images,
      videoUrl: this.videoUrl,
      videoCover: this.videoCover,
      textPosterStyle: this.textPosterStyle,
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
    this.images = [...draft.images];
    this.videoUrl = draft.videoUrl ?? '';
    this.videoCover = draft.videoCover ?? '';
    this.textPosterStyle = draft.textPosterStyle ?? 'paper';
    this.publishMode = (draft.videoUrl && draft.videoUrl.length > 0)
      ? 'video'
      : (draft.images.length === 0 ? 'text' : 'photo');
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
      this.publishMode = session.mode;
      if (session.mode === 'photo') {
        this.imagePickerRequest += 1;
      }
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
    this.genre = 'review';
    this.genreIndex = 0;
    this.selectedTags = [];
    this.title = '';
    this.content = '';
    this.sd = {};
    this.images = [];
    this.videoUrl = '';
    this.videoCover = '';
    this.textPosterStyle = 'paper';
    this.publishMode = 'photo';
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

  // 图文 / 视频 / 文字 严格互斥：切换时清理其它媒体的本地与远端引用，避免混排。
  private switchMediaMode(mode: 'photo' | 'text' | 'video'): void {
    if (mode === this.publishMode) {
      return;
    }
    if (mode === 'video') {
      this.images = [];
    } else if (mode === 'photo') {
      this.videoUrl = '';
      this.videoCover = '';
    } else {
      this.images = [];
      this.videoUrl = '';
      this.videoCover = '';
    }
    this.publishMode = mode;
    if (mode === 'photo') {
      this.imagePickerRequest += 1;
    }
  }

  @Builder
  mediaTypeChip(mode: 'photo' | 'text' | 'video', label: string): void {
    Pressable({
      fillWidth: true,
      visualHeight: LayoutTokens.segmentedHeight,
      action: (): void => { this.switchMediaMode(mode); },
    }) {
      Row() {
        Text(label)
          .fontSize(TypeTokens.callout.size).fontFamily(TypeTokens.fontFamily)
          .fontWeight(this.publishMode === mode ? TypeTokens.headline.weight : TypeTokens.callout.weight)
          .lineHeight(TypeTokens.callout.lineHeight)
          .fontColor(this.publishMode === mode ? ColorTokens.onBrand : ColorTokens.primary)
      }
      .width('100%')
      .height(LayoutTokens.segmentedHeight)
      .justifyContent(FlexAlign.Center)
      .backgroundColor(this.publishMode === mode ? ColorTokens.brand : ColorTokens.barSurface)
      .borderRadius(RadiusTokens.sm)
    }
  }

  @Builder
  mediaTypeSelector(): void {
    Row({ space: SpaceTokens.xs }) {
      this.mediaTypeChip('photo', '图文')
      this.mediaTypeChip('video', '视频')
      this.mediaTypeChip('text', '文字')
    }
    .width('100%')
  }

  @Builder
  compositionSection(): void {
    BaseCard({ cardPadding: SpaceTokens.md, radius: RadiusTokens.md, elevation: 1 }) {
      Column({ space: SpaceTokens.sm }) {
        // 创作类型属于一次发布的上下文，和正文放在同一编辑面中，避免首屏出现两张割裂的卡片。
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
          // 默认正文区略短一些，让首屏能看到更多发布结构；输入时仍可继续滚动编辑。
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
        this.mediaTypeSelector()
        if (this.publishMode === 'photo') {
          Divider().height(LayoutTokens.hairlineWidth).color(ColorTokens.separator).margin({ top: SpaceTokens.sm })
          ImagePicker({
            selected: $images,
            maxCount: MAX_PICKED_IMAGES,
            pickerRequest: this.imagePickerRequest,
            autoOpen: this.imagePickerRequest > 0,
          })
        } else if (this.publishMode === 'video') {
          Divider().height(LayoutTokens.hairlineWidth).color(ColorTokens.separator).margin({ top: SpaceTokens.sm })
          VideoPicker({ videoUrl: $videoUrl, videoCover: $videoCover })
        }
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
          // 与无卡片工具栏保留必要间隙，避免首张卡片被推得过低。
          Row().height(52).width('100%')
          this.compositionSection()
          Row().height(SpaceTokens.x2l).width('100%')
        }
        .width('100%')
        .padding({ left: SpaceTokens.sm, right: SpaceTokens.sm, bottom: SpaceTokens.md })
        .alignItems(HorizontalAlign.Start)
      }
      .width('100%')
      .height('100%')
      .scrollBar(BarState.Off)
      .padding({ bottom: barBottomReserve() })
      .backgroundColor(ColorTokens.canvas)

      Row() {
        PublishTopBar({
          progressText: this.draftProgressText(),
          previewDisabled: this.title.trim().length === 0,
          onClear: (): void => { this.reset(); },
          onPreview: (): void => { this.openPreview(); },
        })
      }
      .width('100%')
      .padding({ left: SpaceTokens.sm, right: SpaceTokens.sm, top: SpaceTokens.xs, bottom: SpaceTokens.sm })

      if (this.showTagPanel) {
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
    .width('100%')
    .height('100%')
    .backgroundColor(ColorTokens.canvas)
  }
}
