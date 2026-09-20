import {
  Genre,
  StructuredBlock,
  StructuredBlockType,
  StructuredDocument,
} from '../models/types';
import {
  addStructuredBlock,
  duplicateStructuredBlock,
  moveStructuredBlock,
  removeStructuredBlock,
  setStructuredPrimary,
  structuredBlockTypesForGenre,
  structuredBlockTypeHint,
  structuredBlockTypeLabel,
  structuredItemsText,
  withStructuredBlockItems,
  withStructuredBlockText,
  StructuredBlockTextField,
} from '../utils/structuredDocument';
import { structuredSummaryFromDocument } from '../utils/structuredBlocks';
import { StructuredSummaryCard } from './StructuredSummaryCard';
import { Collapse } from '../design/motion/Collapse';
import { Pressable } from '../design/motion/Pressable';
import { ColorTokens } from '../design/tokens/color';
import { RadiusTokens } from '../design/tokens/radius';
import { LayoutTokens, SpaceTokens } from '../design/tokens/space';
import { TypeTokens } from '../design/tokens/type';
import {
  STRUCTURED_TEMPLATES,
  structuredDocumentFromTemplate,
  structuredTemplatesForGenre,
  StructuredTemplateMeta,
} from '../utils/structuredTemplates';

// V2 共享编辑器：发布入口只持有 document 状态，块的增删、排序与主视觉选择集中在这里。
@Component
export struct StructuredComposer {
  @Prop document: StructuredDocument;
  @Prop genreLabel: string = '';
  @Link expanded: boolean;
  onDocumentChange: (document: StructuredDocument) => void = (_document: StructuredDocument): void => {};

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
    Pressable({ visualHeight: 28, touchTargetHeight: LayoutTokens.minTouchTarget, action: action }) {
      Text(label)
        .fontSize(TypeTokens.overline.size)
        .fontFamily(TypeTokens.fontFamily)
        .fontWeight(selected ? 600 : 450)
        .fontColor(selected ? ColorTokens.brand : ColorTokens.secondary)
        .backgroundColor(selected ? ColorTokens.brandTint : ColorTokens.elevated)
        .borderRadius(RadiusTokens.pill)
        .padding({ left: SpaceTokens.sm, right: SpaceTokens.sm, top: 6, bottom: 6 })
    }
  }

  @Builder
  private titleInput(block: StructuredBlock): void {
    TextInput({ text: block.title, placeholder: '这块信息叫什么' })
      .width('100%')
      .fontSize(TypeTokens.callout.size)
      .fontFamily(TypeTokens.fontFamily)
      .fontWeight(600)
      .fontColor(ColorTokens.primary)
      .placeholderColor(ColorTokens.quaternary)
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
        .placeholderColor(ColorTokens.quaternary)
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
        .placeholderColor(ColorTokens.quaternary)
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
        .placeholderColor(ColorTokens.quaternary)
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
  private blockFields(block: StructuredBlock): void {
    if (block.type === 'metric') {
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
        .placeholderColor(ColorTokens.quaternary)
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
  private blockEditor(block: StructuredBlock, index: number): void {
    Column({ space: SpaceTokens.md }) {
      Row({ space: SpaceTokens.sm }) {
        Text(structuredBlockTypeLabel(block.type))
          .fontSize(TypeTokens.overline.size)
          .fontFamily(TypeTokens.fontFamily)
          .fontWeight(600)
          .fontColor(ColorTokens.brand)
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

      Row({ space: SpaceTokens.sm }) {
        this.miniAction(block.id === this.document.primaryBlockId ? '主视觉' : '设为主视觉', (): void => {
          this.onDocumentChange(setStructuredPrimary(this.document, block.id));
        }, block.id === this.document.primaryBlockId)
        Blank().layoutWeight(1)
        this.miniAction('↑', (): void => { this.onDocumentChange(moveStructuredBlock(this.document, block.id, -1)); }, index === 0)
        this.miniAction('↓', (): void => { this.onDocumentChange(moveStructuredBlock(this.document, block.id, 1)); }, index === this.document.blocks.length - 1)
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
    .alignItems(HorizontalAlign.Start)
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
          Pressable({
            visualHeight: 36,
            touchTargetHeight: LayoutTokens.minTouchTarget,
            disabled: this.document.blocks.length >= 8,
            action: (): void => { this.onDocumentChange(addStructuredBlock(this.document, type)); },
          }) {
            Text('+ ' + structuredBlockTypeLabel(type))
              .fontSize(TypeTokens.callout.size)
              .fontFamily(TypeTokens.fontFamily)
              .fontColor(this.document.blocks.length >= 8 ? ColorTokens.quaternary : ColorTokens.primary)
              .backgroundColor(ColorTokens.elevated)
              .borderRadius(RadiusTokens.pill)
              .border({ width: LayoutTokens.hairlineWidth, color: ColorTokens.separator, style: BorderStyle.Solid })
              .padding({ left: SpaceTokens.md, right: SpaceTokens.md, top: 8, bottom: 8 })
              .margin({ right: SpaceTokens.sm, bottom: SpaceTokens.sm })
          }
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
                .fontColor(ColorTokens.brand)
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
      Divider().height(LayoutTokens.hairlineWidth).color(ColorTokens.separator)
      Pressable({
        fillWidth: true,
        visualHeight: LayoutTokens.minTouchTarget,
        action: (): void => { this.expanded = !this.expanded; },
      }) {
        Row({ space: SpaceTokens.sm }) {
          Column({ space: SpaceTokens.inlineTight }) {
            Text('结构化信息流')
              .fontSize(TypeTokens.callout.size)
              .fontFamily(TypeTokens.fontFamily)
              .fontWeight(TypeTokens.headline.weight)
              .fontColor(ColorTokens.primary)
            Text(this.document.blocks.length === 0 ? '用视觉块组织结论，不受体裁字段限制' :
              String(this.document.blocks.length) + ' 个信息块 · 可排序 · 可设主视觉')
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
          ForEach(this.document.blocks, (block: StructuredBlock, index: number) => {
            this.blockEditor(block, index)
          }, (block: StructuredBlock) => block.id)
          this.addBlockBar()
        }
        .width('100%')
        .padding({ top: SpaceTokens.sm })
        .alignItems(HorizontalAlign.Start)
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }
}
