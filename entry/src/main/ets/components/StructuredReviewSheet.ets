// 结构化审稿弹层（2026-11-07 发布流改版的核心）：发布页点「发布」→ 全屏 bindContentCover 挂载。
// 三态：loading（AI 拆块中）→ ready（块折叠单行卡，点开微调/排序/删块）→ 确认即发布；
// AI 失败或不可用 → empty 态（选骨架或手动加块），发布永不被 AI 卡死。
// 编辑页手填过块时直接进 ready 展示现有块，不重调 AI、不覆盖手填内容。
import {
  Genre,
  StructuredBlock,
  StructuredBlockType,
  StructuredDocument,
} from '../models/types';
import {
  addStructuredBlock,
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
import { aiStructureDraft, AiDraftResult } from '../services/api';
import { safeShowToast } from '../utils/toast';
import { BackButton } from '../design/components/BackButton';
import { DesignButton } from '../design/components/DesignButton';
import { SoftChip } from '../design/components/SoftChip';
import { Pressable } from '../design/motion/Pressable';
import { ColorTokens } from '../design/tokens/color';
import { RadiusTokens } from '../design/tokens/radius';
import { LayoutTokens, SpaceTokens } from '../design/tokens/space';
import { TypeTokens } from '../design/tokens/type';
import { bottomNavInset } from '../utils/cardTokens';

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

@Component
export struct StructuredReviewSheet {
  // 用户在发布页选的体裁：作为 AI 推断的倾向传入；推断结果通过 onConfirm 回传发布页回填
  @Prop genre: string = 'share';
  // AI 拆块的原料 = 发布页正文（AI 只做原文驱动的整理，没有正文就没有依据）
  @Prop contentText: string = '';
  // 发布页已手填的结构化文档：非空时直接进 ready，不重调 AI
  @Prop initialDocument: StructuredDocument = emptyStructuredDocument();
  @Prop aiAvailable: boolean = false;
  // 每次打开弹层自增：bindContentCover 可能复用组件实例（不重新 aboutToAppear），
  // 靠 key 变化强制重新初始化，保证「改完正文再点发布」拿到的是最新拆块结果。
  @Prop @Watch('onResetKeyChanged') resetKey: number = 0;
  @StorageLink('statusBarHeight') statusBarHeight: number = 0;

  // 确认发布：document 为审稿后的最终文档，genre 为 AI 推断体裁（供发布页回填分段栏）
  onConfirm: (document: StructuredDocument, genre: string) => void =
    (_document: StructuredDocument, _genre: string): void => {};
  onClose: () => void = (): void => {};

  @State private document: StructuredDocument = emptyStructuredDocument();
  @State private phase: number = PHASE_LOADING;
  @State private expandedBlockId: string = '';
  @State private aiBusy: boolean = false;
  @State private inferredGenre: string = '';
  @State private inferredTemplate: string = '';
  @State private skeletonShown: boolean = false;

  aboutToAppear(): void {
    this.setup();
  }

  private onResetKeyChanged(): void {
    this.setup();
  }

  private setup(): void {
    this.document = this.initialDocument;
    this.inferredGenre = this.genre;
    this.expandedBlockId = '';
    this.skeletonShown = false;
    if (this.document.blocks.length > 0) {
      // 手填块直接审稿：AI 不再插手，避免覆盖作者已确认的内容
      this.phase = PHASE_READY;
      return;
    }
    if (!this.aiAvailable || this.contentText.trim().length === 0) {
      this.phase = PHASE_EMPTY;
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
    aiStructureDraft(this.contentText, this.genre)
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
        this.phase = PHASE_EMPTY;
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
            this.expandedBlockId = '';
          },
        },
      });
      return;
    }
    this.document = structuredDocumentFromTemplate(key);
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

  @Builder
  private topBar(): void {
    Row({ space: SpaceTokens.sm }) {
      BackButton({ action: (): void => { this.onClose(); } })
      Column({ space: SpaceTokens.xs }) {
        Text('审稿发布')
          .fontSize(TypeTokens.headline.size).fontFamily(TypeTokens.fontFamilySerif)
          .fontWeight(TypeTokens.headline.weight)
          .lineHeight(TypeTokens.headline.lineHeight)
          .fontColor(ColorTokens.primary)
        Text(this.subtitleText())
          .fontSize(TypeTokens.caption.size).fontFamily(TypeTokens.fontFamily)
          .fontColor(ColorTokens.secondary)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
      Text('返回编辑')
        .fontSize(TypeTokens.caption.size).fontFamily(TypeTokens.fontFamily)
        .fontColor(ColorTokens.brand)
        .padding({ left: SpaceTokens.sm, right: SpaceTokens.xs, top: SpaceTokens.sm, bottom: SpaceTokens.sm })
        .onClick((): void => { this.onClose(); })
    }
    .width('100%')
    .alignItems(VerticalAlign.Center)
  }

  private subtitleText(): string {
    if (this.phase === PHASE_LOADING) {
      return 'AI 正在把正文拆成信息块…';
    }
    if (this.phase === PHASE_EMPTY) {
      return '选一副骨架或手动加块，改完就能发';
    }
    const template: string = templateTitle(this.inferredTemplate);
    const base: string = '点开信息块可微调，改完就能发';
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
      Text(genreDisplayName(this.inferredGenre))
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

  private currentGenre(): Genre | undefined {
    const current: string = this.inferredGenre.length > 0 ? this.inferredGenre : this.genre;
    if (current === 'review' || current === 'pitfall' || current === 'tutorial'
      || current === 'debate' || current === 'share') {
      return current as Genre;
    }
    return undefined;
  }

  // list/steps 编辑区取值与占位：@Builder 内不允许局部变量声明，抽成方法
  private itemsTextOf(blockId: string): string {
    const block: StructuredBlock | null = this.blockById(blockId);
    return block !== null ? structuredItemsText(block) : '';
  }

  private itemsPlaceholderOf(blockId: string): string {
    const block: StructuredBlock | null = this.blockById(blockId);
    return block !== null && block.type === 'steps' ? '每行一个步骤，按执行顺序填写' : '每行一个要点';
  }

  @Builder
  private readyBody(): void {
    Column({ space: SpaceTokens.md }) {
      this.readyToolbar()
      Column({ space: SpaceTokens.sm }) {
        ForEach(this.blockIdList(), (blockId: string) => {
          this.blockCard(blockId)
        }, (blockId: string) => blockId + '_' + String(this.indexOfBlock(blockId))
          + '_x' + String(this.expandedBlockId === blockId ? 1 : 0))
        this.addBlockBar()
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
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

  @Builder
  private emptyBody(): void {
    Column({ space: SpaceTokens.md }) {
      Text('AI 暂时没能把正文拆成信息块')
        .fontSize(TypeTokens.callout.size).fontFamily(TypeTokens.fontFamily)
        .fontWeight(600)
        .fontColor(ColorTokens.primary)
      Text('选一副骨架照着填，或直接手动加块；也可以返回编辑页补充正文后重试。')
        .fontSize(TypeTokens.caption.size).fontFamily(TypeTokens.fontFamily)
        .fontColor(ColorTokens.secondary)
      this.skeletonList()
      Text('或手动加一块')
        .fontSize(TypeTokens.caption.size).fontFamily(TypeTokens.fontFamily)
        .fontColor(ColorTokens.tertiary)
      this.addBlockBar()
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  build() {
    Column() {
      Column() {
        this.topBar()
      }
      .width('100%')
      .padding({ left: SpaceTokens.md, right: SpaceTokens.md })

      Scroll() {
        Column({ space: SpaceTokens.md }) {
          if (this.phase === PHASE_LOADING) {
            this.loadingBody()
          } else if (this.phase === PHASE_READY) {
            this.readyBody()
          } else {
            this.emptyBody()
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

      Column() {
        DesignButton({
          label: this.document.blocks.length === 0 ? '确认发布（先加一个信息块）' : '确认发布',
          fillWidth: true,
          disabled: this.document.blocks.length === 0,
          action: (): void => { this.onConfirm(this.document, this.inferredGenre); },
        })
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
}
