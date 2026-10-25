import {
  Genre,
  StructuredBlock,
  StructuredBlockType,
  StructuredDocument,
  StructuredEvidence,
  StructuredMetricKind,
} from '../models/types';
import {
  addStructuredBlock,
  addStructuredEvidence,
  duplicateStructuredBlock,
  evidenceOf,
  MAX_EVIDENCE_NOTE,
  MAX_EVIDENCE_PER_BLOCK,
  MAX_EVIDENCE_SOURCE_REF,
  moveStructuredBlock,
  removeStructuredBlock,
  removeStructuredEvidence,
  setStructuredPrimary,
  structuredBlockTypesForGenre,
  structuredBlockTypeHint,
  structuredBlockTypeLabel,
  structuredItemsText,
  structuredMetricKindLabel,
  withStructuredBlockItems,
  withStructuredBlockText,
  withStructuredEvidenceNote,
  withStructuredEvidenceRef,
  withStructuredMetricKind,
  StructuredBlockTextField,
} from '../utils/structuredDocument';
import { structuredSummaryFromDocument } from '../utils/structuredBlocks';
import { StructuredSummaryCard } from './StructuredSummaryCard';
import { Collapse } from '../design/motion/Collapse';
import { ToggleChip } from '../design/components/ToggleChip';
import { SoftChip } from '../design/components/SoftChip';
import { Pressable } from '../design/motion/Pressable';
import { ColorTokens } from '../design/tokens/color';
import { RadiusTokens } from '../design/tokens/radius';
import { ShadowTokens } from '../design/tokens/shadow';
import { LayoutTokens, SpaceTokens } from '../design/tokens/space';
import { TypeTokens } from '../design/tokens/type';
import {
  structuredDocumentFromTemplate,
  structuredTemplatesForGenre,
  StructuredTemplateMeta,
} from '../utils/structuredTemplates';
import { photoAccessHelper } from '@kit.MediaLibraryKit';
import { compressImage } from '../utils/image';
import { resolveDisplayImageUrl, uploadChatMedia } from '../services/api';
import { ensureLogin } from '../utils/auth';
import { safeShowToast } from '../utils/toast';
import { User } from '../models/types';

const METRIC_KIND_OPTIONS: StructuredMetricKind[] = ['score', 'amount', 'duration', 'percent', 'count', 'plain'];

// V2 共享编辑器：发布入口只持有 document 状态，块的增删、排序与主视觉选择集中在这里。
@Component
export struct StructuredComposer {
  @Prop document: StructuredDocument;
  @Prop genreLabel: string = '';
  @Link expanded: boolean;
  @State private evidenceUploading: boolean = false;
  // 落点高亮必须是 @State：拖拽过程中要立刻换掉目标卡的描边。
  // 被拖块的 id 反而刻意不用 @State——拖拽进行中改它会重建源卡，系统会把这次拖拽取消。
  @State private dropTargetBlockId: string = '';
  private draggingBlockId: string = '';
  onDocumentChange: (document: StructuredDocument) => void = (_document: StructuredDocument): void => {};

  private blockTitleById(blockId: string): string {
    for (const block of this.document.blocks) {
      if (block.id === blockId) {
        return block.title.length > 0 ? block.title : structuredBlockTypeLabel(block.type);
      }
    }
    return '';
  }

  private indexOfBlock(blockId: string): number {
    for (let i = 0; i < this.document.blocks.length; i++) {
      if (this.document.blocks[i].id === blockId) {
        return i;
      }
    }
    return -1;
  }

  // moveStructuredBlock 的 offset 是相对位移，落点语义要自己换算成「坐到 targetIndex 上」。
  private moveBlockTo(movingId: string, targetId: string): void {
    if (movingId.length === 0 || movingId === targetId) {
      return;
    }
    const from: number = this.indexOfBlock(movingId);
    const to: number = this.indexOfBlock(targetId);
    if (from < 0 || to < 0) {
      return;
    }
    this.onDocumentChange(moveStructuredBlock(this.document, movingId, to - from));
  }

  // 证据必须按 id 回查当前 document，而不是用 @Builder 传进来的 block 快照：
  // ArkUI 给 @Builder 的参数是值快照，块对象换了快照不会换，
  // 用快照渲染证据列表会出现「加了依据但画面不动」的假死。
  private evidenceAt(blockId: string): StructuredEvidence[] {
    for (const block of this.document.blocks) {
      if (block.id === blockId) {
        return evidenceOf(block);
      }
    }
    return [];
  }

  // 行内容同样按位置回查，@Builder 只接 blockId/index 这类标量参数。
  private evidenceItem(blockId: string, index: number): StructuredEvidence | null {
    const list: StructuredEvidence[] = this.evidenceAt(blockId);
    if (index < 0 || index >= list.length) {
      return null;
    }
    return list[index];
  }

  private async addImageEvidence(blockId: string): Promise<void> {
    if (this.evidenceUploading) {
      return;
    }
    this.evidenceUploading = true;
    try {
      const user: User | null = await ensureLogin();
      if (user === null) {
        return;
      }
      const picker = new photoAccessHelper.PhotoViewPicker();
      const result = await picker.select({
        MIMEType: photoAccessHelper.PhotoViewMIMETypes.IMAGE_TYPE,
        maxSelectNumber: 1,
      });
      const uris: string[] = result.photoUris ?? [];
      if (uris.length === 0) {
        return;
      }
      const compressed = await compressImage(uris[0]);
      const mediaRef: string = await uploadChatMedia('image/jpeg', 'posts', compressed.bytes);
      this.onDocumentChange(addStructuredEvidence(this.document, blockId, 'image', mediaRef, ''));
    } catch (e) {
      // 用户取消选图同样走这里，与真失败混在一起会让「取消」变成一次报错弹窗
      const message: string = (e as Error).message ?? '';
      if (message.length > 0 && !message.includes('Cancel')) {
        safeShowToast(this.getUIContext(), { message: '证据图片上传失败：' + message });
      }
    } finally {
      this.evidenceUploading = false;
    }
  }

  private currentGenre(): Genre | undefined {
    switch (this.genreLabel) {
      case 'review': return 'review';
      case 'pitfall': return 'pitfall';
      case 'tutorial': return 'tutorial';
      case 'debate': return 'debate';
      case 'share': return 'share';
      default: return undefined;
    }
  }

  private availableBlockTypes(): StructuredBlockType[] {
    return structuredBlockTypesForGenre(this.currentGenre());
  }

  private updateText(blockId: string, field: StructuredBlockTextField, value: string): void {
    this.onDocumentChange(withStructuredBlockText(this.document, blockId, field, value));
  }

  @Builder
  private miniAction(label: string, action: () => void, selected: boolean = false): void {
    ToggleChip({ label: label, selected: selected, action: action })
  }

  @Builder
  private titleInput(block: StructuredBlock): void {
    TextInput({ text: block.title, placeholder: '这块信息叫什么' })
      .width('100%')
      .fontSize(TypeTokens.callout.size)
      .fontFamily(TypeTokens.fontFamily)
      .fontWeight(600)
      .fontColor(ColorTokens.primary)
      .placeholderColor(ColorTokens.tertiary)
      .backgroundColor(Color.Transparent)
      .maxLength(30)
      .onChange((value: string): void => { this.updateText(block.id, 'title', value); })
  }

  @Builder
  private standardInput(block: StructuredBlock, field: StructuredBlockTextField, placeholder: string,
    multiline: boolean = false, maxLength: number = 240): void {
    if (multiline) {
      TextArea({ text: field === 'value' ? block.value : block.helper, placeholder: placeholder })
        .width('100%')
        .height(82)
        .fontSize(TypeTokens.callout.size)
        .fontFamily(TypeTokens.fontFamily)
        .lineHeight(TypeTokens.callout.lineHeight)
        .fontColor(ColorTokens.primary)
        .placeholderColor(ColorTokens.tertiary)
        .backgroundColor(ColorTokens.elevated)
        .borderRadius(RadiusTokens.sm)
        .padding(SpaceTokens.md)
        .maxLength(maxLength)
        .onChange((value: string): void => { this.updateText(block.id, field, value); })
    } else {
      TextInput({ text: field === 'value' ? block.value : (field === 'unit' ? block.unit : block.helper), placeholder: placeholder })
        .width('100%')
        .fontSize(TypeTokens.callout.size)
        .fontFamily(TypeTokens.fontFamily)
        .fontColor(ColorTokens.primary)
        .placeholderColor(ColorTokens.tertiary)
        .backgroundColor(ColorTokens.elevated)
        .borderRadius(RadiusTokens.sm)
        .padding({ left: SpaceTokens.md, right: SpaceTokens.md })
        .maxLength(maxLength)
        .onChange((value: string): void => { this.updateText(block.id, field, value); })
    }
  }

  @Builder
  private compareInput(block: StructuredBlock, left: boolean): void {
    Column({ space: SpaceTokens.sm }) {
      TextInput({
        text: left ? block.leftLabel : block.rightLabel,
        placeholder: left ? 'A 标签' : 'B 标签',
      })
        .fontSize(TypeTokens.overline.size)
        .fontFamily(TypeTokens.fontFamily)
        .fontColor(ColorTokens.brand)
        .backgroundColor(Color.Transparent)
        .maxLength(12)
        .onChange((value: string): void => {
          this.updateText(block.id, left ? 'leftLabel' : 'rightLabel', value);
        })
      TextArea({
        text: left ? block.leftValue : block.rightValue,
        placeholder: left ? '第一种选择' : '第二种选择',
      })
        .width('100%')
        .height(72)
        .fontSize(TypeTokens.callout.size)
        .fontFamily(TypeTokens.fontFamily)
        .fontColor(ColorTokens.primary)
        .placeholderColor(ColorTokens.tertiary)
        .backgroundColor(ColorTokens.elevated)
        .borderRadius(RadiusTokens.sm)
        .padding(SpaceTokens.sm)
        .maxLength(180)
        .onChange((value: string): void => {
          this.updateText(block.id, left ? 'leftValue' : 'rightValue', value);
        })
    }
    .layoutWeight(1)
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  private metricKindChips(block: StructuredBlock): void {
    // kind 决定详情页大数字的读法（4.8 是评分还是金额），也是 M3 跨帖对比的排序键；
    // 协议里有类型、编辑器里没有入口，作者就只能发出一条「没人知道单位」的数字。
    Row({ space: SpaceTokens.sm }) {
      Text('数字类型')
        .fontSize(TypeTokens.overline.size)
        .fontFamily(TypeTokens.fontFamily)
        .fontColor(ColorTokens.tertiary)
    }
    Flex({ direction: FlexDirection.Row, wrap: FlexWrap.Wrap }) {
      ForEach(METRIC_KIND_OPTIONS, (kind: StructuredMetricKind) => {
        Column() {
          this.miniAction(structuredMetricKindLabel(kind), (): void => {
            this.onDocumentChange(withStructuredMetricKind(this.document, block.id, kind));
          }, block.kind === kind)
        }
        .margin({ right: SpaceTokens.sm, bottom: SpaceTokens.xs })
      }, (kind: StructuredMetricKind) => 'kind_' + kind)
    }
    .width('100%')
  }

  @Builder
  private blockFields(block: StructuredBlock): void {
    if (block.type === 'metric') {
      Column({ space: SpaceTokens.sm }) {
        Row({ space: SpaceTokens.sm }) {
          TextInput({ text: block.value, placeholder: '例如 4.8' })
            .layoutWeight(1)
            .fontSize(TypeTokens.headline.size)
            .fontFamily(TypeTokens.fontFamilySerif)
            .fontColor(ColorTokens.primary)
            .backgroundColor(ColorTokens.elevated)
            .borderRadius(RadiusTokens.sm)
            .padding({ left: SpaceTokens.md, right: SpaceTokens.md })
            .maxLength(30)
            .onChange((value: string): void => { this.updateText(block.id, 'value', value); })
          TextInput({ text: block.unit, placeholder: '单位' })
            .width(88)
            .fontSize(TypeTokens.callout.size)
            .fontFamily(TypeTokens.fontFamily)
            .fontColor(ColorTokens.secondary)
            .backgroundColor(ColorTokens.elevated)
            .borderRadius(RadiusTokens.sm)
            .padding({ left: SpaceTokens.sm, right: SpaceTokens.sm })
            .maxLength(16)
            .onChange((value: string): void => { this.updateText(block.id, 'unit', value); })
        }
        .width('100%')
        this.metricKindChips(block)
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
    } else if (block.type === 'insight') {
      this.standardInput(block, 'value', '一句话写清你的判断，不要先铺垫', true, 300)
    } else if (block.type === 'list' || block.type === 'steps') {
      TextArea({
        text: structuredItemsText(block),
        placeholder: block.type === 'steps' ? '每行一个步骤，按执行顺序填写' : '每行一个要点，适合人群、工具、条件都可以',
      })
        .width('100%')
        .height(104)
        .fontSize(TypeTokens.callout.size)
        .fontFamily(TypeTokens.fontFamily)
        .lineHeight(TypeTokens.callout.lineHeight)
        .fontColor(ColorTokens.primary)
        .placeholderColor(ColorTokens.tertiary)
        .backgroundColor(ColorTokens.elevated)
        .borderRadius(RadiusTokens.sm)
        .padding(SpaceTokens.md)
        .maxLength(800)
        .onChange((value: string): void => {
          this.onDocumentChange(withStructuredBlockItems(this.document, block.id, value));
        })
    } else {
      Row({ space: SpaceTokens.sm }) {
        this.compareInput(block, true)
        this.compareInput(block, false)
      }
      .width('100%')
      .alignItems(VerticalAlign.Top)
    }
  }

  @Builder
  private evidenceNoteInput(blockId: string, index: number): void {
    // 出处和实测图共用说明槽：协议里 note 对两种类型都有效，只给图片渲染输入框
    // 就等于宣布「出处只能是一条 URL」，详情页那句说明永远等不到内容。
    TextInput({ text: this.evidenceItem(blockId, index)?.note ?? '', placeholder: '这条证据证明了什么' })
      .width('100%')
      .fontSize(TypeTokens.caption.size)
      .fontFamily(TypeTokens.fontFamily)
      .fontColor(ColorTokens.primary)
      .placeholderColor(ColorTokens.tertiary)
      .backgroundColor(ColorTokens.elevated)
      .borderRadius(RadiusTokens.sm)
      .padding({ left: SpaceTokens.md, right: SpaceTokens.md })
      .maxLength(MAX_EVIDENCE_NOTE)
      .onChange((value: string): void => {
        this.onDocumentChange(withStructuredEvidenceNote(this.document, blockId, index, value));
      })
  }

  @Builder
  private evidenceRow(blockId: string, index: number): void {
    // item 从 this.document 回查，不用 @Builder 传进来的快照
    if (this.evidenceItem(blockId, index) !== null) {
      Row({ space: SpaceTokens.sm }) {
        if (this.evidenceItem(blockId, index)?.type === 'image') {
          Image(resolveDisplayImageUrl(this.evidenceItem(blockId, index)?.ref ?? ''))
            .width(44)
            .height(44)
            .objectFit(ImageFit.Cover)
            .borderRadius(RadiusTokens.sm)
        }
        Column({ space: SpaceTokens.xs }) {
          if (this.evidenceItem(blockId, index)?.type !== 'image') {
            Row({ space: SpaceTokens.sm }) {
              Text('出处')
                .fontSize(TypeTokens.overline.size)
                .fontFamily(TypeTokens.fontFamily)
                .fontWeight(600)
                .fontColor(ColorTokens.secondary)
                .backgroundColor(ColorTokens.sunken)
                .borderRadius(RadiusTokens.pill)
                .padding({ left: SpaceTokens.sm, right: SpaceTokens.sm, top: 6, bottom: 6 })
              TextInput({ text: this.evidenceItem(blockId, index)?.ref ?? '', placeholder: '官方规格页 / 京东订单 / 实测记录' })
                .layoutWeight(1)
                .fontSize(TypeTokens.caption.size)
                .fontFamily(TypeTokens.fontFamily)
                .fontColor(ColorTokens.primary)
                .placeholderColor(ColorTokens.tertiary)
                .backgroundColor(ColorTokens.elevated)
                .borderRadius(RadiusTokens.sm)
                .padding({ left: SpaceTokens.md, right: SpaceTokens.md })
                .maxLength(MAX_EVIDENCE_SOURCE_REF)
                .onChange((value: string): void => {
                  this.onDocumentChange(withStructuredEvidenceRef(this.document, blockId, index, value));
                })
            }
            .width('100%')
            .alignItems(VerticalAlign.Center)
          }
          this.evidenceNoteInput(blockId, index)
        }
        .layoutWeight(1)
        Pressable({
          visualHeight: 32,
          touchTargetHeight: LayoutTokens.minTouchTarget,
          action: (): void => {
            this.onDocumentChange(removeStructuredEvidence(this.document, blockId, index));
          },
        }) {
          Text('×')
            .fontSize(TypeTokens.body.size)
            .fontFamily(TypeTokens.fontFamily)
            .fontColor(ColorTokens.secondary)
            .width(28)
            .height(28)
            .textAlign(TextAlign.Center)
            .backgroundColor(ColorTokens.elevated)
            .borderRadius(RadiusTokens.pill)
        }
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)
    }
  }

  @Builder
  private evidenceSection(block: StructuredBlock): void {
    Column({ space: SpaceTokens.sm }) {
      Row({ space: SpaceTokens.sm }) {
        Text('依据')
          .fontSize(TypeTokens.caption.size)
          .fontFamily(TypeTokens.fontFamily)
          .fontWeight(600)
          .fontColor(ColorTokens.secondary)
        Text(String(this.evidenceAt(block.id).length) + '/' + String(MAX_EVIDENCE_PER_BLOCK))
          .fontSize(TypeTokens.caption.size)
          .fontFamily(TypeTokens.fontFamily)
          .fontColor(ColorTokens.tertiary)
        Blank().layoutWeight(1)
        if (this.evidenceUploading) {
          LoadingProgress()
            .width(18)
            .height(18)
            .color(ColorTokens.brand)
          Text('上传中')
            .fontSize(TypeTokens.caption.size)
            .fontFamily(TypeTokens.fontFamily)
            .fontColor(ColorTokens.tertiary)
        } else if (this.evidenceAt(block.id).length < MAX_EVIDENCE_PER_BLOCK) {
          this.miniAction('实测图', (): void => { this.addImageEvidence(block.id); })
          this.miniAction('出处', (): void => {
            this.onDocumentChange(addStructuredEvidence(this.document, block.id, 'source', '', ''));
          })
        }
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)

      ForEach(this.evidenceAt(block.id), (_evidence: StructuredEvidence, index: number) => {
        this.evidenceRow(block.id, index)
      }, (_keyEvidence: StructuredEvidence, index: number) => 'ev_' + String(index))
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  private blockDragPreview(title: string): void {
    Row({ space: SpaceTokens.sm }) {
      Text('⠿')
        .fontSize(TypeTokens.callout.size)
        .fontFamily(TypeTokens.fontFamily)
        .fontColor(ColorTokens.brand)
      Text(title)
        .fontSize(TypeTokens.callout.size)
        .fontFamily(TypeTokens.fontFamily)
        .fontWeight(600)
        .fontColor(ColorTokens.primary)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
    }
    .constraintSize({ maxWidth: 260 })
    .padding({ left: SpaceTokens.md, right: SpaceTokens.md, top: SpaceTokens.sm, bottom: SpaceTokens.sm })
    .backgroundColor(ColorTokens.elevated)
    .borderRadius(RadiusTokens.pill)
    .border({ width: 1, color: ColorTokens.brand, style: BorderStyle.Solid })
    .shadow(ShadowTokens.cardAmbient)
    .alignItems(VerticalAlign.Center)
  }

  @Builder
  private dragHandle(blockId: string): void {
    // 把手单独可拖，而不是整卡 draggable：整卡挂拖拽手势会和 TextInput 的长按选词、
    // 光标定位抢手势，作者会在改正文时把块拖飞。
    Text('⠿')
      .fontSize(TypeTokens.headline.size)
      .fontFamily(TypeTokens.fontFamily)
      .fontColor(ColorTokens.tertiary)
      .width(28)
      .height(28)
      .textAlign(TextAlign.Center)
      .draggable(true)
      .onDragStart((_event: DragEvent, _extraParams?: string): DragItemInfo => {
        this.draggingBlockId = blockId;
        return { builder: (): void => { this.blockDragPreview(this.blockTitleById(blockId)); } };
      })
      .onDragEnd((event: DragEvent, _extraParams?: string): void => {
        const movingId: string = this.draggingBlockId;
        const targetId: string = this.dropTargetBlockId;
        this.draggingBlockId = '';
        this.dropTargetBlockId = '';
        // 松手在子级 TextInput 上时，drop 会被文本组件自己吃掉，卡片收不到 onDrop。
        // 所以这里用最后一次 hover 到的卡片兜底提交；onDrop 已提交过就会留下空 target，不重复移动。
        if (event.getResult() !== DragResult.DRAG_CANCELED) {
          this.moveBlockTo(movingId, targetId);
        }
      })
  }

  @Builder
  private blockEditor(block: StructuredBlock): void {
    Column({ space: SpaceTokens.md }) {
      Row({ space: SpaceTokens.sm }) {
        this.dragHandle(block.id)
        Text(structuredBlockTypeLabel(block.type))
          .fontSize(TypeTokens.overline.size)
          .fontFamily(TypeTokens.fontFamily)
          .fontWeight(600)
          // tint 底 + 墨字：brand 字压 brandTint 深色 3.58:1，11px 不达 AA
          .fontColor(ColorTokens.primary)
          .backgroundColor(ColorTokens.brandTint)
          .borderRadius(RadiusTokens.pill)
          .padding({ left: SpaceTokens.sm, right: SpaceTokens.sm, top: 5, bottom: 5 })
        this.titleInput(block)
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)

      Text(structuredBlockTypeHint(block.type))
        .fontSize(TypeTokens.caption.size)
        .fontFamily(TypeTokens.fontFamily)
        .fontColor(ColorTokens.tertiary)
        .width('100%')

      this.blockFields(block)
      this.standardInput(block, 'helper', '补充说明（可选）', false, 80)
      this.evidenceSection(block)

      Row({ space: SpaceTokens.sm }) {
        this.miniAction(block.id === this.document.primaryBlockId ? '主视觉' : '设为主视觉', (): void => {
          this.onDocumentChange(setStructuredPrimary(this.document, block.id));
        }, block.id === this.document.primaryBlockId)
        Blank().layoutWeight(1)
        this.miniAction('复制', (): void => { this.onDocumentChange(duplicateStructuredBlock(this.document, block.id)); })
        this.miniAction('删除', (): void => { this.onDocumentChange(removeStructuredBlock(this.document, block.id)); })
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)
    }
    .width('100%')
    .padding(SpaceTokens.base)
    .backgroundColor(ColorTokens.subtle)
    .borderRadius(RadiusTokens.md)
    .border({
      width: this.dropTargetBlockId === block.id ? 2 : 0,
      color: ColorTokens.brand,
      style: BorderStyle.Solid,
    })
    .alignItems(HorizontalAlign.Start)
    .onDragEnter((_event: DragEvent, _extraParams?: string): void => {
      // 起点就落在自己卡内，不门控会让被拖的块先给自己亮起落点高亮。
      if (block.id !== this.draggingBlockId) {
        this.dropTargetBlockId = block.id;
      }
    })
    .onDragLeave((_event: DragEvent, _extraParams?: string): void => {
      if (this.dropTargetBlockId === block.id) {
        this.dropTargetBlockId = '';
      }
    })
    .onDrop((_event: DragEvent, _extraParams?: string): void => {
      this.moveBlockTo(this.draggingBlockId, block.id);
      this.dropTargetBlockId = '';
    })
  }

  @Builder
  private addBlockBar(): void {
    Column({ space: SpaceTokens.sm }) {
      Text(this.document.blocks.length === 0 ? '先选一种信息关系' : '继续添加信息块')
        .fontSize(TypeTokens.caption.size)
        .fontFamily(TypeTokens.fontFamily)
        .fontWeight(600)
        .fontColor(ColorTokens.secondary)
      Flex({ direction: FlexDirection.Row, wrap: FlexWrap.Wrap }) {
        ForEach(this.availableBlockTypes(), (type: StructuredBlockType) => {
          Column() {
            SoftChip({
              label: '+ ' + structuredBlockTypeLabel(type),
              tone: 'neutral',
              visualHeight: 36,
              disabled: this.document.blocks.length >= 8,
              action: (): void => { this.onDocumentChange(addStructuredBlock(this.document, type)); },
            })
          }
          .margin({ right: SpaceTokens.sm, bottom: SpaceTokens.sm })
        }, (type: StructuredBlockType) => type)
      }
      .width('100%')
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  private templatePicker(): void {
    if (this.document.blocks.length === 0) {
      Column({ space: SpaceTokens.sm }) {
        Text('从视觉骨架开始')
          .fontSize(TypeTokens.caption.size)
          .fontFamily(TypeTokens.fontFamily)
          .fontWeight(600)
          .fontColor(ColorTokens.secondary)
        Text('模板只负责起步，选完仍可自由增删、排序和换主视觉。')
          .fontSize(TypeTokens.caption.size)
          .fontFamily(TypeTokens.fontFamily)
          .fontColor(ColorTokens.tertiary)
        ForEach(structuredTemplatesForGenre(this.currentGenre()), (template: StructuredTemplateMeta) => {
          Pressable({
            fillWidth: true,
            fullResponseRegion: true,
            action: (): void => { this.onDocumentChange(structuredDocumentFromTemplate(template.key)); },
          }) {
            Row({ space: SpaceTokens.md }) {
              Column({ space: SpaceTokens.inlineTight }) {
                Text(template.title)
                  .fontSize(TypeTokens.callout.size)
                  .fontFamily(TypeTokens.fontFamilySerif)
                  .fontWeight(600)
                  .fontColor(ColorTokens.primary)
                Text(template.description)
                  .fontSize(TypeTokens.caption.size)
                  .fontFamily(TypeTokens.fontFamily)
                  .fontColor(ColorTokens.secondary)
              }
              .layoutWeight(1)
              .alignItems(HorizontalAlign.Start)
              Text('选择')
                .fontSize(TypeTokens.caption.size)
                .fontFamily(TypeTokens.fontFamily)
                // 12px 蓝字压 subtle 灰底深色 4.30:1 不达 AA → brandPress（5.47:1）
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
  }

  build() {
    Column({ space: SpaceTokens.sm }) {
      Pressable({
        fillWidth: true,
        visualHeight: LayoutTokens.minTouchTarget,
        action: (): void => { this.expanded = !this.expanded; },
      }) {
        Row({ space: SpaceTokens.sm }) {
          Column({ space: SpaceTokens.inlineTight }) {
            Text('结构化信息流')
              .fontSize(TypeTokens.headline.size)
              .fontFamily(TypeTokens.fontFamilySerif)
              .fontWeight(TypeTokens.headline.weight)
              .lineHeight(TypeTokens.headline.lineHeight)
              .fontColor(ColorTokens.primary)
            Text(this.document.blocks.length === 0 ? '选一条体裁骨架，改词就能发' :
              String(this.document.blocks.length) + ' 个信息块 · 长按 ⠿ 拖动排序 · 可设主视觉')
              .fontSize(TypeTokens.caption.size)
              .fontFamily(TypeTokens.fontFamily)
              .fontColor(ColorTokens.secondary)
          }
          .layoutWeight(1)
          .alignItems(HorizontalAlign.Start)
          Text(this.expanded ? '收起' : '编辑')
            .fontSize(TypeTokens.caption.size)
            .fontFamily(TypeTokens.fontFamily)
            .fontColor(ColorTokens.brand)
        }
        .width('100%')
        .alignItems(VerticalAlign.Center)
      }
      Collapse({ expanded: this.expanded }) {
        Column({ space: SpaceTokens.base }) {
          if (this.document.blocks.length > 0) {
            Column({ space: SpaceTokens.sm }) {
              Text('实时信息流预览')
                .fontSize(TypeTokens.overline.size)
                .fontFamily(TypeTokens.fontFamily)
                .fontWeight(600)
                .letterSpacing(1)
                .fontColor(ColorTokens.tertiary)
              StructuredSummaryCard({
                summary: structuredSummaryFromDocument(this.document, this.genreLabel),
                compact: false,
              })
            }
            .width('100%')
            .alignItems(HorizontalAlign.Start)
          }
          this.templatePicker()
          ForEach(this.document.blocks, (block: StructuredBlock) => {
            this.blockEditor(block)
          }, (block: StructuredBlock) => block.id + '_' + block.type
            + '_e' + String(evidenceOf(block).length) + '_k' + (block.kind ?? ''))
          // key 带上证据数和数值类型：ForEach 的 key 不含会变的状态时，加了依据、换了类型画面也不重建。
          // 文本编辑不动这两个值，所以打字过程中不会被重建、光标不跳。
          this.addBlockBar()
        }
        .width('100%')
        .padding({ top: SpaceTokens.sm })
        .alignItems(HorizontalAlign.Start)
      }
    }
    .width('100%')
    .padding(SpaceTokens.item)
    .backgroundColor(ColorTokens.elevated)
    .borderRadius(RadiusTokens.lg)
    .border({ width: 1, color: ColorTokens.separator, style: BorderStyle.Solid })
    .shadow(ShadowTokens.cardAmbient)
    .alignItems(HorizontalAlign.Start)
  }
}
