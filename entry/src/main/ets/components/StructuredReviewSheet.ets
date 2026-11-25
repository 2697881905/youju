// 结构化审稿弹层（2026-11-07 发布流改版的核心）：发布页点「发布」→ 全屏 bindContentCover 挂载。
// 三态：loading（AI 拆块中）→ ready（块折叠单行卡，点开微调/排序/删块）→ 确认即发布；
// AI 失败或不可用 → empty 态（选骨架或手动加块），发布永不被 AI 卡死。
// 编辑页手填过块时直接进 ready 展示现有块，不重调 AI、不覆盖手填内容。
import { image } from '@kit.ImageKit';
import {
  Genre,
  MentionRef,
  StructuredBlock,
  StructuredBlockType,
  StructuredDocument,
} from '../models/types';
import {
  addStructuredBlock,
  collectStructuredDocument,
  emptyStructuredDocument,
  moveStructuredBlock,
  removeStructuredBlock,
  structuredBlockTypeHint,
  structuredBlockTypeLabel,
  structuredBlockTypesForGenre,
  structuredItemsText,
  withStructuredBlockItems,
  withStructuredBlockText,
} from '../utils/structuredDocument';
import { structuredDocumentFromTemplate, structuredTemplatesForGenre,
  StructuredTemplateMeta, STRUCTURED_TEMPLATES } from '../utils/structuredTemplates';
import { aiStructureDraft, AiDraftResult, resolveDisplayImageUrl } from '../services/api';
import { FeedZone } from '../utils/feedZones';
import { safeShowToast } from '../utils/toast';
import { BackButton } from '../design/components/BackButton';
import { GlassTitleRow, HDS_MINI_BAR_ROW_VP } from '../design/components/HdsGlassBackSurface';
import { DetailPostHeader } from './DetailPostHeader';
import { DetailPostContent } from './DetailPostContent';
import { VideoPlayer } from './VideoPlayer';
import { DesignButton } from '../design/components/DesignButton';
import { SoftChip } from '../design/components/SoftChip';
import { Pressable } from '../design/motion/Pressable';
import { ColorTokens } from '../design/tokens/color';
import { RadiusTokens } from '../design/tokens/radius';
import { LayoutTokens, SpaceTokens } from '../design/tokens/space';
import { TypeTokens } from '../design/tokens/type';
import { bottomNavInset } from '../utils/cardTokens';
import { publishGenreMeta } from '../utils/publishGenres';
import { getCurrentUser } from '../utils/auth';
import { FALLBACK_VIDEO_ASPECT_RATIO } from '../utils/video';
import { StructuredFieldPair } from '../utils/structuredFields';
import { renderPosterPixelMap } from '../utils/poster/posterRender';
import { resolveTextPosterStyle } from '../utils/poster/posterTokens';

// 审稿阶段：0=AI 拆块中 1=就绪（可编辑可发布） 2=手动起步（AI 失败/不可用）
const PHASE_LOADING: number = 0;
const PHASE_READY: number = 1;
const PHASE_EMPTY: number = 2;

const MAX_BLOCKS: number = 8;

// 组件内持状态必须具体化：三元不能直接当 @State 初始化的 Record 索引读取
function genreDisplayName(genre: string): string {
  switch (genre) {
    case 'review': return '测评';
    case 'pitfall': return '避坑';
    case 'tutorial': return '教程';
    case 'debate': return '辩论';
    case 'share': return '分享';
    default: return '结构化';
  }
}

function templateTitle(key: string): string {
  for (const template of STRUCTURED_TEMPLATES) {
    if (template.key === key) {
      return template.title;
    }
  }
  return '';
}

function toGenre(value: string): Genre | undefined {
  if (value === 'review' || value === 'pitfall' || value === 'tutorial'
    || value === 'debate' || value === 'share') {
    return value as Genre;
  }
  return undefined;
}

@Component
export struct StructuredReviewSheet {
  // 作者倾向体裁（不是「已选体裁」）：干货发布固定传空串，让模型在干货候选内自由推断；
  // 最终回传的体裁由 onConfirm 的 inferredGenre 优先决定。
  @Prop genre: string = '';
  // 内容区：随记不做结构化（不调 AI，直接给骨架/原文出口）
  @Prop zone: FeedZone = 'insight';
  // AI 拆块的原料 = 发布页正文（AI 只做原文驱动的整理，没有正文就没有依据）
  @Prop contentText: string = '';
  // 发布页已手填的结构化文档：非空时直接进 ready，不重调 AI
  @Prop initialDocument: StructuredDocument = emptyStructuredDocument();
  @Prop aiAvailable: boolean = false;
  // 每次打开弹层自增：bindContentCover 可能复用组件实例（不重新 aboutToAppear），
  // 靠 key 变化强制重新初始化，保证「改完正文再点发布」拿到的是最新拆块结果。
  @Prop @Watch('onResetKeyChanged') resetKey: number = 0;
  @StorageLink('statusBarHeight') statusBarHeight: number = 0;

  // 预览数据由发布页草稿传入（C-302）：ready 态渲染 = 详情页内容列，作者发布前所见即所得
  @Prop draftTitle: string = '';
  @Prop draftTags: string[] = [];
  @Prop draftMentions: MentionRef[] = [];
  @Prop draftMediaUrl: string = '';
  @Prop draftVideoUrl: string = '';
  // C-304/C-303：无图无视频帖的封面海报样式 key；非空时媒体位渲染与发布产物同源的海报卡
  // （长文/图文页传各自 textPosterStyle，视频页恒传 ''——视频帖媒体位永远进海报分支）
  @Prop draftPosterStyle: string = '';

  // 确认发布：document 为审稿后的最终文档，genre 为 AI 推断体裁（供发布页回填分段栏）
  onConfirm: (document: StructuredDocument, genre: string) => void =
    (_document: StructuredDocument, _genre: string): void => {};
  onClose: () => void = (): void => {};
  // 「按原文发布」出口：无信息块、不结构化，由发布页显式豁免闸门
  onPublishRaw: () => void = (): void => {};

  @State private document: StructuredDocument = emptyStructuredDocument();
  @State private phase: number = PHASE_LOADING;
  @State private expandedBlockId: string = '';
  @State private aiBusy: boolean = false;
  @State private inferredGenre: string = '';
  @State private inferredTemplate: string = '';
  @State private skeletonShown: boolean = false;
  // C-402 整理弹窗显隐：EMPTY 进入路径自动弹出（首次），可关闭；关闭后经预览尾部轻提示条重开
  @State private guideSheetShown: boolean = false;
  // AI 失败的具体原因（额度用尽 / 服务不可用 / 拆不出块）：空态标题与副标题据此区分，避免一律「拆不出块」
  @State private emptyReason: string = '';
  // 空态骨架 chips 的选中态：最近一次应用的骨架 key，选中面走 brandTint（屏4）
  @State private appliedTemplateKey: string = '';
  // 「手动加一块」虚线框入口的展开态：默认收起保持空态一屏可读，点开才出现类型选择行
  @State private addBlockExpanded: boolean = false;
  // C-303 海报卡成品（scale=1 全尺寸 ≈5.9MiB）：渲染完成前为 null，媒体位显示底色占位。
  // 渲染放 setTimeout 异步执行，避免阻塞弹层首帧；离场/复用重渲染时按先例释放旧图。
  @State private posterMap: image.PixelMap | null = null;
  // 组件销毁后 setTimeout 回调可能仍在队列：置位守卫，避免销毁后赋值导致 PixelMap 泄漏
  private posterDisposed: boolean = false;

  aboutToAppear(): void {
    this.posterDisposed = false;
    this.setup();
    this.requestPosterRender();
  }

  aboutToDisappear(): void {
    this.posterDisposed = true;
    const map: image.PixelMap | null = this.posterMap;
    if (map !== null) {
      map.release().catch((): void => {});
      this.posterMap = null;
    }
  }

  private onResetKeyChanged(): void {
    this.setup();
    this.requestPosterRender();
  }

  private setup(): void {
    this.document = this.initialDocument;
    this.inferredGenre = this.genre;
    this.expandedBlockId = '';
    this.skeletonShown = false;
    this.guideSheetShown = false;
    this.appliedTemplateKey = '';
    this.addBlockExpanded = false;
    if (this.zone === 'life') {
      // 随记是轻量图文，不做结构化：不发起 AI 请求，直接给骨架与「按原文发布」出口
      this.emptyReason = '';
      this.phase = PHASE_EMPTY;
      this.guideSheetShown = true;
      return;
    }
    if (this.document.blocks.length > 0) {
      // 手填块直接审稿：AI 不再插手，避免覆盖作者已确认的内容
      this.phase = PHASE_READY;
      return;
    }
    if (!this.aiAvailable || this.contentText.trim().length === 0) {
      // 未发起请求的空态没有后端原因，空态文案回到默认口径
      this.emptyReason = '';
      this.phase = PHASE_EMPTY;
      this.guideSheetShown = true;
      return;
    }
    this.phase = PHASE_LOADING;
    this.requestAiDraft();
  }

  // —— AI 拆块（进层自动一次；ready 态「重新拆块」复用） ——
  private requestAiDraft(): void {
    if (this.aiBusy) {
      return;
    }
    this.aiBusy = true;
    aiStructureDraft(this.contentText, this.genre, this.zone)
      .then((result: AiDraftResult): void => {
        this.document = result.document;
        this.inferredGenre = result.genre;
        this.inferredTemplate = result.template;
        this.phase = PHASE_READY;
        this.expandedBlockId = '';
      })
      .catch((e: Object): void => {
        const err: Error = e as Error;
        safeShowToast(this.getUIContext(), {
          message: (err.message.length > 0 ? err.message : 'AI 拆块失败') + '，可在下方选骨架手动起步',
        });
this.emptyReason = err.message.length > 0 ? err.message : 'AI 拆块失败';
        this.phase = PHASE_EMPTY;
        this.guideSheetShown = true;
      })
      .finally((): void => {
        this.aiBusy = false;
      });
  }

  private requestRedraft(): void {
    if (this.document.blocks.length > 0) {
      this.getUIContext().showAlertDialog({
        title: '重新拆块？',
        message: 'AI 会按正文重新整理，替换当前 ' + String(this.document.blocks.length) + ' 个信息块。',
        primaryButton: { value: '取消', action: (): void => {} },
        secondaryButton: { value: '重新拆', action: (): void => { this.requestAiDraft(); } },
      });
      return;
    }
    this.requestAiDraft();
  }

  private applyTemplate(key: string): void {
    this.skeletonShown = false;
    if (this.document.blocks.length > 0) {
      this.getUIContext().showAlertDialog({
        title: '换成「' + templateTitle(key) + '」骨架？',
        message: '当前信息块会被清空，从新骨架重新填起。',
        primaryButton: { value: '取消', action: (): void => {} },
        secondaryButton: {
          value: '换骨架',
          action: (): void => {
            this.document = structuredDocumentFromTemplate(key);
            this.appliedTemplateKey = key;
            this.expandedBlockId = '';
          },
        },
      });
      return;
    }
    this.document = structuredDocumentFromTemplate(key);
    this.appliedTemplateKey = key;
    this.expandedBlockId = '';
  }

  // —— document 回查：@Builder 参数是值快照，编辑面板一律按 blockId 从 this.document 取最新值 ——
  private blockById(blockId: string): StructuredBlock | null {
    for (const block of this.document.blocks) {
      if (block.id === blockId) {
        return block;
      }
    }
    return null;
  }

  private indexOfBlock(blockId: string): number {
    for (let i = 0; i < this.document.blocks.length; i++) {
      if (this.document.blocks[i].id === blockId) {
        return i;
      }
    }
    return -1;
  }

  private availableBlockTypes(): StructuredBlockType[] {
    return structuredBlockTypesForGenre(this.currentGenre());
  }

  // 折叠行的标题与摘要：一眼看懂这块装了什么。@Builder 内不能写复杂表达式，
  // 统一回查方法里做完判空与 fallback。
  private blockTitleOf(blockId: string): string {
    const block: StructuredBlock | null = this.blockById(blockId);
    if (block === null) {
      return '';
    }
    return block.title.length > 0 ? block.title : structuredBlockTypeLabel(block.type);
  }

  private blockSummaryOf(blockId: string): string {
    const block: StructuredBlock | null = this.blockById(blockId);
    if (block === null) {
      return '';
    }
    return this.blockSummary(block);
  }

  private blockSummary(block: StructuredBlock): string {
    if (block.type === 'insight') {
      return block.value;
    }
    if (block.type === 'compare') {
      return block.leftLabel + '：' + block.leftValue + '　' + block.rightLabel + '：' + block.rightValue;
    }
    if (block.type === 'metric') {
      return block.value + (block.unit.length > 0 ? ' ' + block.unit : '');
    }
    return structuredItemsText(block);
  }

  private updateText(blockId: string, field: 'title' | 'value' | 'unit'
    | 'leftLabel' | 'leftValue' | 'rightLabel' | 'rightValue', value: string): void {
    this.document = withStructuredBlockText(this.document, blockId, field, value);
  }

  private updateItems(blockId: string, text: string): void {
    this.document = withStructuredBlockItems(this.document, blockId, text);
  }

  private moveBlock(blockId: string, offset: number): void {
    const from: number = this.indexOfBlock(blockId);
    const to: number = from + offset;
    if (from < 0 || to < 0 || to >= this.document.blocks.length) {
      return;
    }
    this.document = moveStructuredBlock(this.document, blockId, offset);
  }

  // 顶栏（C-501）：官方栏布局复刻的 Stack 叠加——第一层全宽全高 Row 放 BackButton（贴左
  // 垂直居中），第二层 GlassTitleRow 居中标题行（副标题进 subRow、「返回编辑」进 actions，
  // 内置 64vp 让位避让返回键/右侧动作）。容器高 = MINI 栏体口径 56vp。模态内无官方栏，
  // 返回键保留 BackButton（图标与官方 backIcon 同源，豁免玻璃底）。
  @Builder
  private topBar(): void {
    Stack({ alignContent: Alignment.Center }) {
      Row() {
        BackButton({ action: (): void => { this.onClose(); } })
      }
      .width('100%')
      .height('100%')
      .justifyContent(FlexAlign.Start)
      .alignItems(VerticalAlign.Center)
      .padding({ left: SpaceTokens.sm })

      GlassTitleRow({
        title: '预览',
        headlineSerif: true,
        hasSubRow: true,
        subRow: (): void => { this.previewSubtitleRow(); },
        hasActions: true,
        actions: (): void => { this.closeAction(); },
      })
    }
    .width('100%')
    .height(HDS_MINI_BAR_ROW_VP)
  }

  // 副标题行：原 topBar 副标题 Text 逐字迁入 subRow 槽（三态文案仍由 subtitleText() 决定）
  @Builder
  private previewSubtitleRow(): void {
    Text(this.subtitleText())
      .fontSize(TypeTokens.caption.size).fontFamily(TypeTokens.fontFamily)
      .fontColor(ColorTokens.secondary)
      .maxLines(1)
      .textOverflow({ overflow: TextOverflow.Ellipsis })
  }

  // 右侧动作：原「返回编辑」Text 逐字迁入 actions 槽（onClick 链路 = onClose 不变）
  @Builder
  private closeAction(): void {
    Text('返回编辑')
      .fontSize(TypeTokens.caption.size).fontFamily(TypeTokens.fontFamily)
      .fontColor(ColorTokens.brand)
      .padding({ right: SpaceTokens.md })
      .onClick((): void => { this.onClose(); })
  }

  private subtitleText(): string {
    if (this.phase === PHASE_LOADING) {
      return 'AI 正在把正文拆成信息块…';
    }
    if (this.phase === PHASE_EMPTY) {
      if (this.emptyReason.length > 0) {
        return '可重试、选骨架，或按原文发布';
      }
      return 'AI 暂不可用，选骨架或手动加块，也可按原文发布';
    }
    const template: string = templateTitle(this.inferredTemplate);
    const base: string = '这是帖子发出后的样子';
    return template.length > 0 ? 'AI 参考了「' + template + '」骨架 · ' + base : base;
  }

  @Builder
  private loadingBody(): void {
    Column({ space: SpaceTokens.md }) {
      LoadingProgress()
        .width(36)
        .height(36)
        .color(ColorTokens.brand)
      Text('AI 正在把正文拆成信息块')
        .fontSize(TypeTokens.callout.size).fontFamily(TypeTokens.fontFamily)
        .fontColor(ColorTokens.secondary)
      Text('通常需要几秒钟，期间可以随时返回')
        .fontSize(TypeTokens.caption.size).fontFamily(TypeTokens.fontFamily)
        .fontColor(ColorTokens.tertiary)
    }
    .width('100%')
    .padding({ top: 96 })
    .alignItems(HorizontalAlign.Center)
  }

  @Builder
  private blockTypeBadge(type: string): void {
    Text(structuredBlockTypeLabel(type as StructuredBlockType))
      .fontSize(TypeTokens.overline.size).fontFamily(TypeTokens.fontFamily)
      .fontWeight(600)
      .fontColor(ColorTokens.primary)
      .backgroundColor(ColorTokens.brandTint)
      .borderRadius(RadiusTokens.pill)
      .padding({ left: SpaceTokens.sm, right: SpaceTokens.sm, top: 5, bottom: 5 })
  }

  // 折叠单行卡：类型徽标 + 标题/摘要 + 「微调」。点卡片展开编辑。
  @Builder
  private blockCard(blockId: string): void {
    Column({ space: SpaceTokens.sm }) {
      Pressable({
        fillWidth: true,
        visualHeight: LayoutTokens.minTouchTarget,
        action: (): void => {
          this.expandedBlockId = this.expandedBlockId === blockId ? '' : blockId;
        },
      }) {
        Row({ space: SpaceTokens.sm }) {
          this.blockTypeBadge(this.blockTypeOf(blockId))
          Column({ space: 2 }) {
            Text(this.blockTitleOf(blockId))
              .fontSize(TypeTokens.callout.size).fontFamily(TypeTokens.fontFamily)
              .fontWeight(600)
              .fontColor(ColorTokens.primary)
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
            Text(this.blockSummaryOf(blockId))
              .fontSize(TypeTokens.caption.size).fontFamily(TypeTokens.fontFamily)
              .fontColor(ColorTokens.secondary)
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
          }
          .layoutWeight(1)
          .alignItems(HorizontalAlign.Start)
          Text(this.expandedBlockId === blockId ? '收起' : '微调')
            .fontSize(TypeTokens.caption.size).fontFamily(TypeTokens.fontFamily)
            .fontColor(ColorTokens.brand)
        }
        .width('100%')
        .alignItems(VerticalAlign.Center)
      }
      if (this.expandedBlockId === blockId) {
        this.blockEditor(blockId)
      }
    }
    .width('100%')
    .padding(SpaceTokens.md)
    .backgroundColor(ColorTokens.elevated)
    .borderRadius(RadiusTokens.md)
    .border({ width: LayoutTokens.hairlineWidth, color: ColorTokens.separator, style: BorderStyle.Solid })
    .alignItems(HorizontalAlign.Start)
  }

  private blockTypeOf(blockId: string): string {
    const block: StructuredBlock | null = this.blockById(blockId);
    return block === null ? 'insight' : block.type;
  }

  // 展开编辑区：标题 + 按类型的核心字段 + 排序/删除。证据仍回编辑页挂（审稿层保持轻）。
  @Builder
  private blockEditor(blockId: string): void {
    Column({ space: SpaceTokens.sm }) {
      TextInput({ text: this.blockById(blockId)?.title ?? '', placeholder: '这块信息叫什么' })
        .width('100%')
        .fontSize(TypeTokens.callout.size).fontFamily(TypeTokens.fontFamily)
        .fontWeight(600)
        .fontColor(ColorTokens.primary)
        .placeholderColor(ColorTokens.tertiary)
        .backgroundColor(ColorTokens.subtle)
        .borderRadius(RadiusTokens.sm)
        .padding({ left: SpaceTokens.md, right: SpaceTokens.md })
        .maxLength(30)
        .onChange((value: string): void => { this.updateText(blockId, 'title', value); })
      Text(this.blockTypeHintOf(blockId))
        .fontSize(TypeTokens.caption.size).fontFamily(TypeTokens.fontFamily)
        .fontColor(ColorTokens.tertiary)
        .width('100%')
      this.blockFields(blockId)
      Row({ space: SpaceTokens.sm }) {
        Blank().layoutWeight(1)
        if (this.indexOfBlock(blockId) > 0) {
          SoftChip({ label: '上移', tone: 'neutral', action: (): void => { this.moveBlock(blockId, -1); } })
        }
        if (this.indexOfBlock(blockId) < this.document.blocks.length - 1) {
          SoftChip({ label: '下移', tone: 'neutral', action: (): void => { this.moveBlock(blockId, 1); } })
        }
        SoftChip({
          label: '删除',
          tone: 'danger',
          action: (): void => {
            this.document = removeStructuredBlock(this.document, blockId);
            if (this.expandedBlockId === blockId) {
              this.expandedBlockId = '';
            }
          },
        })
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  private blockTypeHintOf(blockId: string): string {
    const block: StructuredBlock | null = this.blockById(blockId);
    return block === null ? '' : structuredBlockTypeHint(block.type);
  }

  @Builder
  private blockFields(blockId: string): void {
    if (this.blockById(blockId)?.type === 'insight') {
      TextArea({ text: this.blockById(blockId)?.value ?? '', placeholder: '一句话写清你的判断' })
        .width('100%')
        .height(82)
        .fontSize(TypeTokens.callout.size).fontFamily(TypeTokens.fontFamily)
        .fontColor(ColorTokens.primary)
        .placeholderColor(ColorTokens.tertiary)
        .backgroundColor(ColorTokens.subtle)
        .borderRadius(RadiusTokens.sm)
        .padding(SpaceTokens.md)
        .maxLength(300)
        .onChange((value: string): void => { this.updateText(blockId, 'value', value); })
    } else if (this.blockById(blockId)?.type === 'compare') {
      Row({ space: SpaceTokens.sm }) {
        this.compareSide(blockId, true)
        this.compareSide(blockId, false)
      }
      .width('100%')
      .alignItems(VerticalAlign.Top)
    } else if (this.blockById(blockId)?.type === 'metric') {
      // metric 已退役不再新增；存量块给最小编辑保住内容
      Row({ space: SpaceTokens.sm }) {
        TextInput({ text: this.blockById(blockId)?.value ?? '', placeholder: '数值' })
          .layoutWeight(1)
          .fontSize(TypeTokens.callout.size).fontFamily(TypeTokens.fontFamily)
          .fontColor(ColorTokens.primary)
          .backgroundColor(ColorTokens.subtle)
          .borderRadius(RadiusTokens.sm)
          .padding({ left: SpaceTokens.md, right: SpaceTokens.md })
          .maxLength(30)
          .onChange((value: string): void => { this.updateText(blockId, 'value', value); })
        TextInput({ text: this.blockById(blockId)?.unit ?? '', placeholder: '单位' })
          .width(88)
          .fontSize(TypeTokens.callout.size).fontFamily(TypeTokens.fontFamily)
          .fontColor(ColorTokens.secondary)
          .backgroundColor(ColorTokens.subtle)
          .borderRadius(RadiusTokens.sm)
          .padding({ left: SpaceTokens.sm, right: SpaceTokens.sm })
          .maxLength(16)
          .onChange((value: string): void => { this.updateText(blockId, 'unit', value); })
      }
      .width('100%')
    } else {
      TextArea({
        text: this.itemsTextOf(blockId),
        placeholder: this.itemsPlaceholderOf(blockId),
      })
        .width('100%')
        .height(104)
        .fontSize(TypeTokens.callout.size).fontFamily(TypeTokens.fontFamily)
        .fontColor(ColorTokens.primary)
        .placeholderColor(ColorTokens.tertiary)
        .backgroundColor(ColorTokens.subtle)
        .borderRadius(RadiusTokens.sm)
        .padding(SpaceTokens.md)
        .maxLength(800)
        .onChange((value: string): void => { this.updateItems(blockId, value); })
    }
  }

  @Builder
  private compareSide(blockId: string, left: boolean): void {
    Column({ space: SpaceTokens.sm }) {
      TextInput({
        text: left ? this.blockById(blockId)?.leftLabel ?? '' : this.blockById(blockId)?.rightLabel ?? '',
        placeholder: left ? 'A 标签' : 'B 标签',
      })
        .fontSize(TypeTokens.overline.size).fontFamily(TypeTokens.fontFamily)
        .fontColor(ColorTokens.brand)
        .backgroundColor(Color.Transparent)
        .maxLength(12)
        .onChange((value: string): void => { this.updateText(blockId, left ? 'leftLabel' : 'rightLabel', value); })
      TextArea({
        text: left ? this.blockById(blockId)?.leftValue ?? '' : this.blockById(blockId)?.rightValue ?? '',
        placeholder: left ? '第一种选择' : '第二种选择',
      })
        .width('100%')
        .height(72)
        .fontSize(TypeTokens.callout.size).fontFamily(TypeTokens.fontFamily)
        .fontColor(ColorTokens.primary)
        .placeholderColor(ColorTokens.tertiary)
        .backgroundColor(ColorTokens.subtle)
        .borderRadius(RadiusTokens.sm)
        .padding(SpaceTokens.sm)
        .maxLength(180)
        .onChange((value: string): void => { this.updateText(blockId, left ? 'leftValue' : 'rightValue', value); })
    }
    .layoutWeight(1)
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  private addBlockBar(): void {
    Flex({ direction: FlexDirection.Row, wrap: FlexWrap.Wrap }) {
      ForEach(this.availableBlockTypes(), (type: StructuredBlockType) => {
        Column() {
          SoftChip({
            label: '+ ' + structuredBlockTypeLabel(type),
            tone: 'neutral',
            visualHeight: 36,
            disabled: this.document.blocks.length >= MAX_BLOCKS,
            action: (): void => {
              this.document = addStructuredBlock(this.document, type);
            },
          })
        }
        .margin({ right: SpaceTokens.sm, bottom: SpaceTokens.sm })
      }, (type: StructuredBlockType) => type)
    }
    .width('100%')
  }

  // ready 态顶部动作行：体裁徽标 + 重新拆块（AI 可用）+ 换骨架
  @Builder
  private readyToolbar(): void {
    Row({ space: SpaceTokens.sm }) {
      Text(genreDisplayName(this.currentGenre()))
        .fontSize(TypeTokens.caption.size).fontFamily(TypeTokens.fontFamily)
        .fontWeight(600)
        .fontColor(ColorTokens.brandPress)
        .backgroundColor(ColorTokens.subtle)
        .borderRadius(RadiusTokens.pill)
        .padding({ left: SpaceTokens.sm, right: SpaceTokens.sm, top: 6, bottom: 6 })
      Blank().layoutWeight(1)
      if (this.aiAvailable && this.contentText.trim().length > 0) {
        SoftChip({
          label: this.aiBusy ? '拆块中…' : '重新拆块',
          tone: 'neutral',
          disabled: this.aiBusy,
          action: (): void => { this.requestRedraft(); },
        })
      }
      SoftChip({ label: '换骨架', tone: 'neutral', action: (): void => { this.skeletonShown = true; } })
    }
    .width('100%')
    .alignItems(VerticalAlign.Center)
  }

  // empty 态（AI 失败/不可用）：骨架选择是主要起步路径
  @Builder
  private skeletonList(): void {
    Column({ space: SpaceTokens.sm }) {
      ForEach(structuredTemplatesForGenre(this.currentGenre()), (template: StructuredTemplateMeta) => {
        Pressable({
          fillWidth: true,
          fullResponseRegion: true,
          action: (): void => { this.applyTemplate(template.key); },
        }) {
          Row({ space: SpaceTokens.md }) {
            Column({ space: SpaceTokens.inlineTight }) {
              Text(template.title)
                .fontSize(TypeTokens.callout.size).fontFamily(TypeTokens.fontFamilySerif)
                .fontWeight(600)
                .fontColor(ColorTokens.primary)
              Text(template.description)
                .fontSize(TypeTokens.caption.size).fontFamily(TypeTokens.fontFamily)
                .fontColor(ColorTokens.secondary)
            }
            .layoutWeight(1)
            .alignItems(HorizontalAlign.Start)
            Text('选用')
              .fontSize(TypeTokens.caption.size).fontFamily(TypeTokens.fontFamily)
              .fontColor(ColorTokens.brandPress)
          }
          .width('100%')
          .padding(SpaceTokens.md)
          .backgroundColor(ColorTokens.subtle)
          .borderRadius(RadiusTokens.md)
          .alignItems(VerticalAlign.Center)
        }
      }, (template: StructuredTemplateMeta) => template.key)
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  // 体裁三级回退：AI 推断 → 作者倾向 → 内容区兜底（干货=测评 / 随记=分享）
  private currentGenre(): Genre {
    const inferred: Genre | undefined = toGenre(this.inferredGenre);
    if (inferred !== undefined) {
      return inferred;
    }
    const preferred: Genre | undefined = toGenre(this.genre);
    if (preferred !== undefined) {
      return preferred;
    }
    return this.zone === 'insight' ? 'review' : 'share';
  }

  // list/steps 编辑区取值与占位：@Builder 内不允许局部变量声明，抽成方法
  private itemsTextOf(blockId: string): string {
    const block: StructuredBlock | null = this.blockById(blockId);
    return block !== null ? structuredItemsText(block) : '';
  }

  private itemsPlaceholderOf(blockId: string): string {
    const block: StructuredBlock | null = this.blockById(blockId);
    return block !== null && block.type === 'steps' ? '每行一个条目，按执行顺序填写' : '每行一个要点';
  }

  // 预览作者 = 当前用户；预览时间 = 当前时刻（@Builder 内不写表达式，抽方法）
  private currentUserName(): string {
    return getCurrentUser()?.nickname ?? '';
  }

  private currentUserAvatar(): string {
    return getCurrentUser()?.avatar ?? '';
  }

  private previewCreatedAt(): string {
    return new Date().toISOString();
  }

  // V2 结构化帖走 structuredDocument，pairs 传空数组（与 PublishPreviewPage.structuredPreview 一致）
  private previewPairs(): StructuredFieldPair[] {
    return [];
  }

  // C-303 海报渲染：进入条件与 mediaPreview 海报分支严格同口径（无视频、无图、样式 key 非空），
  // 其余情况零渲染零内存。setTimeout 让弹层先出首帧（底色占位），渲染完成后再赋值刷新。
  private requestPosterRender(): void {
    if (this.draftVideoUrl.length > 0 || this.draftMediaUrl.length > 0
      || this.draftPosterStyle.length === 0) {
      return;
    }
    setTimeout((): void => {
      if (this.posterDisposed) {
        return;
      }
      try {
        const map: image.PixelMap = renderPosterPixelMap(this.draftTitle, this.contentText, this.draftPosterStyle);
        const old: image.PixelMap | null = this.posterMap;
        this.posterMap = map;
        if (old !== null) {
          old.release().catch((): void => {});
        }
      } catch (e) {
        // 渲染失败保持底色占位，不阻断审稿（先例：TextPosterCover / PublishPreviewPage 同口径）
      }
    }, 0) as number;
  }

  // 海报未就绪/渲染失败时的占位底色 = 所选样式的海报 background（契约 C-303）
  private posterPlaceholderColor(): string {
    return resolveTextPosterStyle(this.draftPosterStyle).background;
  }

  // 媒体预览：draft 单图/单视频，圆角/宽度/观感对齐详情页 mediaSlot（不复刻多图轮播/封帧细节）
  // C-303 海报分支：无视频无图且样式非空时渲染 3:4 海报卡；占位与成品共用同一容器，
  // 未就绪只见底色不发生尺寸跳变。（海报容器内联于本 @Builder——@Builder 方法根级 if
  // 包裹单组件真机不产出节点，故不抽独立海报 @Builder，只在容器内部条件渲染 Image。）
  @Builder
  private mediaPreview(): void {
    if (this.draftVideoUrl.length > 0) {
      VideoPlayer({ src: this.draftVideoUrl })
        .width('100%')
        .aspectRatio(FALLBACK_VIDEO_ASPECT_RATIO)
        .backgroundColor(Color.Black)
        .borderRadius(12)
        .clip(true)
    } else if (this.draftMediaUrl.length > 0) {
      Image(resolveDisplayImageUrl(this.draftMediaUrl))
        .width('100%')
        .aspectRatio(LayoutTokens.cardMediaAspectRatio)
        .objectFit(ImageFit.Cover)
        .backgroundColor(ColorTokens.sunken)
        .borderRadius(12)
        .clip(true)
        .draggable(false)
    } else if (this.draftPosterStyle.length > 0) {
      Column() {
        if (this.posterMap !== null) {
          Image(this.posterMap)
            .width('100%')
            .height('100%')
            .objectFit(ImageFit.Cover)
            .draggable(false)
        }
      }
      .width('100%')
      .aspectRatio(1080 / 1440)
      .backgroundColor(this.posterPlaceholderColor())
      .borderRadius(12)
      .clip(true)
    }
  }

  @Builder
  private readyBody(): void {
    Column({ space: SpaceTokens.base }) {
      DetailPostHeader({
        title: this.draftTitle,
        genreLabel: publishGenreMeta(this.currentGenre()).label,
        genreIcon: publishGenreMeta(this.currentGenre()).iconRes,
        tags: this.draftTags,
        authorName: this.currentUserName(),
        authorAvatar: this.currentUserAvatar(),
        createdAt: this.previewCreatedAt(),
        postId: 0,
        ratingAvg: null, ratingCount: 0, myRating: 0,
        onRatingUpdated: (): void => {},
        onExpandRequest: (): boolean => true,
        onOpenAuthor: (): void => {},
      })
      // 媒体与正文编为一组（组内间距 8）：图/视频紧贴正文，对齐 detailBodyScroll
      Column({ space: SpaceTokens.sm }) {
        this.mediaPreview()
        DetailPostContent({
          navMode: false,
          pairs: this.previewPairs(),
          structuredDocument: collectStructuredDocument(this.document),
          genre: this.currentGenre(),
          content: this.contentText,
          coverOnlyTextPoster: false,
          planA: '', planB: '',
          votePostId: 0,
          mentions: this.draftMentions,
          onVote: (_choice: string): void => {},
          onLongPressContent: (_event: GestureEvent): void => {},
          onBodyCollapsed: (): void => {},
        })
      }
      .width('100%')
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  // ForEach 数据源：块 id 列表。document 变化（增删/排序）时重新求值驱动卡片刷新。
  private blockIdList(): string[] {
    const ids: string[] = [];
    for (const block of this.document.blocks) {
      ids.push(block.id);
    }
    return ids;
  }

  // 回传体裁：AI 推断优先，否则回作者倾向（可能为空串，由发布页按内容区兜底）
  private confirmGenre(): string {
    return this.inferredGenre.length > 0 ? this.inferredGenre : this.genre;
  }

  // 空态标题优先用后端给出的具体原因（@Builder 内不写表达式，抽成方法）
  private emptyTitle(): string {
    if (this.emptyReason.length > 0) {
      return this.emptyReason;
    }
    return 'AI 暂时没能把正文拆成信息块';
  }

  // 无信息块时「按原文发布」是唯一可用出口：提为主按钮并排第一
  private rawPublishFirst(): boolean {
    return this.phase === PHASE_EMPTY && this.document.blocks.length === 0;
  }

  // C-403 提示条判定：EMPTY 且仍无信息块（applyTemplate/手动加块后有块即消失，不依赖 phase 翻转）
  private showEmptyGuideHint(): boolean {
    return this.phase === PHASE_EMPTY && this.document.blocks.length === 0;
  }

  // 「按原文发布」文案按内容区区分口径：干货区直称目标（屏4 主按钮文案），随记区不是干货回退通用文案
  private rawPublishLabel(): string {
    return this.zone === 'life' ? '按原文发布' : '按原文发布到干货';
  }

  // empty 态（屏4 视觉重排）：17/700 标题直陈原因 → 13 说明 → 骨架 wrap chips → 虚线框加块入口。
  // 骨架 chips 专供空态（panel 底一行 wrap），ready 态「换骨架」弹层仍用 skeletonList 卡片列表。
  @Builder
  private emptyBody(): void {
    Column({ space: SpaceTokens.md }) {
      Text(this.emptyTitle())
        .fontSize(17).fontFamily(TypeTokens.fontFamily)
        .fontWeight(700)
        .fontColor(ColorTokens.primary)
      Text('可以重试、选骨架手动起步，或按原文直接发布——发布不会被 AI 卡住。')
        .fontSize(13).fontFamily(TypeTokens.fontFamily)
        .fontColor(ColorTokens.secondary)
      this.skeletonChipRow()
      this.addBlockDashedEntry()
      if (this.addBlockExpanded) {
        this.addBlockBar()
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  // 空态骨架选择：一行 wrap chips（panel 底 + glassBorder 描边 + 圆角 16），最近应用的骨架选中面走 brandTint
  @Builder
  private skeletonChipRow(): void {
    Flex({ direction: FlexDirection.Row, wrap: FlexWrap.Wrap }) {
      ForEach(structuredTemplatesForGenre(this.currentGenre()), (template: StructuredTemplateMeta) => {
        Pressable({
          fullResponseRegion: true,
          action: (): void => { this.applyTemplate(template.key); },
        }) {
          Text(template.title)
            .fontSize(TypeTokens.callout.size).fontFamily(TypeTokens.fontFamily)
            .fontColor(this.appliedTemplateKey === template.key ? ColorTokens.primary : ColorTokens.secondary)
            .padding({ left: 16, right: 16, top: 10, bottom: 10 })
            .backgroundColor(this.appliedTemplateKey === template.key ? ColorTokens.brandTint : ColorTokens.panel)
            .borderRadius(16)
            .border({
              width: LayoutTokens.glassBorderWidth,
              color: ColorTokens.barBorder,
              style: BorderStyle.Solid,
            })
            .margin({ right: SpaceTokens.sm, bottom: SpaceTokens.sm })
        }
      }, (template: StructuredTemplateMeta) => template.key)
    }
    .width('100%')
  }

  // 「手动加一块」虚线框入口（border 1.5 Dashed tertiary + 圆角 18）：点击展开类型选择行（复用 addBlockBar）
  @Builder
  private addBlockDashedEntry(): void {
    Pressable({
      fillWidth: true,
      fullResponseRegion: true,
      action: (): void => { this.addBlockExpanded = !this.addBlockExpanded; },
    }) {
      Text('＋ 手动加一块')
        .fontSize(TypeTokens.callout.size).fontFamily(TypeTokens.fontFamily)
        .fontColor(ColorTokens.secondary)
        .width('100%')
        .textAlign(TextAlign.Center)
        .padding(16)
        .border({
          width: 1.5,
          color: ColorTokens.tertiary,
          style: BorderStyle.Dashed,
        })
        .borderRadius(18)
    }
  }

  build() {
    Column() {
      // 顶栏容器：左右 padding 移除（C-502），边距由 topBar 自管理；容器仅保留宽度语义
      Column() {
        this.topBar()
      }
      .width('100%')
      // 整理弹窗（C-402）：与换骨架 bindSheet 同参口径；宿主分节点挂载——同组件只能绑一个
      // bindSheet（换骨架已占根 Column，两页并行实证过「同组件双模态」规格坑）
      .bindSheet(this.guideSheetShown, this.guideSheet(), {
        height: '48%',
        dragBar: true,
        showClose: false,
        maskColor: '#33000000',
        onDisappear: (): void => { this.guideSheetShown = false; },
      })

      Scroll() {
        Column({ space: SpaceTokens.md }) {
          // C-401 预览常驻：READY 与 EMPTY 同走 readyBody——EMPTY 无块时正文走 DetailPostContent
          // 的纯文本兜底（hasStructuredFlow 对空 blocks 返回 false，已验证），海报卡经
          // mediaPreview 的 draftPosterStyle 分支自动生效；仅 LOADING 保持 loadingBody
          if (this.phase === PHASE_LOADING) {
            this.loadingBody()
          } else {
            this.readyBody()
          }
          // C-403 轻提示条：EMPTY 且仍无信息块时展示，点击重开整理弹窗；有信息块后即消失
          if (this.showEmptyGuideHint()) {
            this.emptyGuideHintBar()
          }
          Row().height(LayoutTokens.minTouchTarget).width('100%')
        }
        .width('100%')
        .padding({ left: SpaceTokens.lg, right: SpaceTokens.lg, top: SpaceTokens.md })
        .alignItems(HorizontalAlign.Start)
      }
      .layoutWeight(1)
      .width('100%')
      .scrollBar(BarState.Off)
      .align(Alignment.Top)
      .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true })

      Column({ space: SpaceTokens.sm }) {
        if (this.rawPublishFirst()) {
          DesignButton({
            label: this.rawPublishLabel(),
            fillWidth: true,
            action: (): void => { this.onPublishRaw(); },
          })
          DesignButton({
            label: '确认发布（先加一个信息块）',
            fillWidth: true,
            disabled: true,
            action: (): void => { this.onConfirm(this.document, this.confirmGenre()); },
          })
        } else {
          DesignButton({
            label: this.document.blocks.length === 0 ? '确认发布（先加一个信息块）' : '确认发布',
            fillWidth: true,
            disabled: this.document.blocks.length === 0,
            action: (): void => { this.onConfirm(this.document, this.confirmGenre()); },
          })
          if (this.phase === PHASE_EMPTY) {
            DesignButton({
              label: this.rawPublishLabel(),
              variant: 'ghost',
              fillWidth: true,
              action: (): void => { this.onPublishRaw(); },
            })
          }
        }
      }
      .width('100%')
      .padding({ left: SpaceTokens.lg, right: SpaceTokens.lg, bottom: SpaceTokens.md + bottomNavInset() })
    }
    .width('100%')
    .height('100%')
    .padding({ top: this.statusBarHeight })
    .backgroundColor(ColorTokens.canvas)
    // 换骨架：半模态底部弹层
    .bindSheet(this.skeletonShown, this.skeletonSheet(), {
      height: '48%',
      dragBar: true,
      showClose: false,
      maskColor: '#33000000',
      onDisappear: (): void => { this.skeletonShown = false; },
    })
  }

  @Builder
  private skeletonSheet(): void {
    Column({ space: SpaceTokens.md }) {
      Text('选一副骨架')
        .fontSize(TypeTokens.headline.size).fontFamily(TypeTokens.fontFamilySerif)
        .fontWeight(TypeTokens.headline.weight)
        .fontColor(ColorTokens.primary)
      Scroll() {
        this.skeletonList()
      }
      .layoutWeight(1)
      .scrollBar(BarState.Off)
      .align(Alignment.Top)
    }
    .width('100%')
    .height('100%')
    .padding(SpaceTokens.lg)
    .alignItems(HorizontalAlign.Start)
  }

  // 整理弹窗（C-402）：标题 + 原 emptyBody 全量（emptyTitle/说明/骨架 chips/手动加块/类型行）
  // 原样搬入、行为不变；emptyBody 定义保留，仅不再被 build 直接调用（C-404 防引用断裂）。
  // 形态与换骨架弹窗同构（标题 + Scroll 内容 + lg padding）。
  @Builder
  private guideSheet(): void {
    Column({ space: SpaceTokens.md }) {
      Text('整理内容')
        .fontSize(TypeTokens.headline.size).fontFamily(TypeTokens.fontFamilySerif)
        .fontWeight(TypeTokens.headline.weight)
        .fontColor(ColorTokens.primary)
      Scroll() {
        this.emptyBody()
      }
      .layoutWeight(1)
      .scrollBar(BarState.Off)
      .align(Alignment.Top)
    }
    .width('100%')
    .height('100%')
    .padding(SpaceTokens.lg)
    .alignItems(HorizontalAlign.Start)
  }

  // C-403 预览尾部轻提示条：弹窗关闭后仍无信息块时的整理入口。根级 Column 容器包裹，
  // 规避「@Builder 根级单组件」真机渲染坑（mediaPreview 海报分支同口径先例）
  @Builder
  private emptyGuideHintBar(): void {
    Column() {
      Pressable({
        fillWidth: true,
        fullResponseRegion: true,
        action: (): void => { this.guideSheetShown = true; },
      }) {
        Text('未做 AI 整理 · 点此整理或按原文发布')
          .fontSize(TypeTokens.callout.size).fontFamily(TypeTokens.fontFamily)
          .fontColor(ColorTokens.secondary)
          .width('100%')
          .textAlign(TextAlign.Center)
          .padding({ left: SpaceTokens.md, right: SpaceTokens.md, top: 12, bottom: 12 })
          .backgroundColor(ColorTokens.subtle)
          .borderRadius(RadiusTokens.md)
      }
    }
    .width('100%')
  }
}
