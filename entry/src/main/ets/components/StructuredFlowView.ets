import { StructuredBlock, StructuredDocument } from '../models/types';
import { structuredBlockHasContent, structuredBlockTypeLabel } from '../utils/structuredDocument';
import { ColorTokens } from '../design/tokens/color';
import { RadiusTokens } from '../design/tokens/radius';
import { LayoutTokens, SpaceTokens } from '../design/tokens/space';
import { TypeTokens } from '../design/tokens/type';

// 详情页的完整结构化信息流。每种数据关系使用不同版式，而不是退化成统一字段表。
@Component
export struct StructuredFlowView {
  @Prop document: StructuredDocument | null = null;

  private accentColor(): ResourceColor {
    if (this.document?.theme === 'warm') return '#A85D24';
    if (this.document?.theme === 'cool') return '#2D746E';
    return ColorTokens.brand;
  }

  private surfaceColor(primary: boolean): ResourceColor {
    if (this.document?.theme === 'warm') return primary ? '#FFF1E2' : '#FFF8F1';
    if (this.document?.theme === 'cool') return primary ? '#E8F5F2' : '#F4F9F8';
    return primary ? ColorTokens.brandTint : ColorTokens.subtle;
  }

  private visibleBlocks(): StructuredBlock[] {
    if (this.document === null || this.document.schemaVersion !== 2) return [];
    const primary: StructuredBlock[] = [];
    const rest: StructuredBlock[] = [];
    for (const block of this.document.blocks) {
      if (!structuredBlockHasContent(block)) continue;
      if (block.id === this.document.primaryBlockId) primary.push(block);
      else rest.push(block);
    }
    return primary.concat(rest);
  }

  @Builder
  private blockHeading(block: StructuredBlock, primary: boolean): void {
    Row({ space: SpaceTokens.sm }) {
      Text(primary ? '主视觉' : structuredBlockTypeLabel(block.type))
        .fontSize(TypeTokens.overline.size)
        .fontFamily(TypeTokens.fontFamily)
        .fontWeight(TypeTokens.overline.weight)
        .letterSpacing(1)
        .fontColor(this.accentColor())
      Text(block.title)
        .fontSize(TypeTokens.caption.size)
        .fontFamily(TypeTokens.fontFamily)
        .fontColor(ColorTokens.secondary)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .layoutWeight(1)
    }
    .width('100%')
    .alignItems(VerticalAlign.Center)
  }

  @Builder
  private metricBody(block: StructuredBlock, primary: boolean): void {
    Row({ space: SpaceTokens.sm }) {
      Text(block.value)
        .fontSize(primary ? 38 : 28)
        .fontFamily(TypeTokens.fontFamilySerif)
        .fontWeight(700)
        .fontColor(ColorTokens.primary)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
      if (block.unit.length > 0) {
        Text(block.unit)
          .fontSize(TypeTokens.callout.size)
          .fontFamily(TypeTokens.fontFamily)
          .fontColor(ColorTokens.secondary)
          .padding({ bottom: SpaceTokens.xs })
      }
      Blank().layoutWeight(1)
    }
    .width('100%')
    .alignItems(VerticalAlign.Bottom)
  }

  @Builder
  private insightBody(block: StructuredBlock, primary: boolean): void {
    Text(block.value)
      .fontSize(primary ? TypeTokens.headline.size : TypeTokens.body.size)
      .fontFamily(TypeTokens.fontFamilySerifBody)
      .fontWeight(primary ? 600 : 500)
      .lineHeight(primary ? 30 : 26)
      .fontColor(ColorTokens.primary)
      .width('100%')
  }

  @Builder
  private listBody(block: StructuredBlock): void {
    Flex({ direction: FlexDirection.Row, wrap: FlexWrap.Wrap, justifyContent: FlexAlign.Start }) {
      ForEach(block.items, (item: string) => {
        Text(item)
          .fontSize(TypeTokens.callout.size)
          .fontFamily(TypeTokens.fontFamily)
          .fontColor(ColorTokens.primary)
          .backgroundColor(ColorTokens.elevated)
          .borderRadius(RadiusTokens.pill)
          .padding({ left: SpaceTokens.md, right: SpaceTokens.md, top: 7, bottom: 7 })
          .margin({ right: SpaceTokens.sm, bottom: SpaceTokens.sm })
      }, (item: string) => item)
    }
    .width('100%')
  }

  @Builder
  private stepsBody(block: StructuredBlock): void {
    Column({ space: SpaceTokens.md }) {
      ForEach(block.items, (item: string, index: number) => {
        Row({ space: SpaceTokens.md }) {
          Text(String(index + 1))
            .width(24)
            .height(24)
            .fontSize(TypeTokens.caption.size)
            .fontFamily(TypeTokens.fontFamily)
            .fontWeight(600)
            .fontColor(this.accentColor())
            .backgroundColor(ColorTokens.elevated)
            .borderRadius(RadiusTokens.pill)
            .textAlign(TextAlign.Center)
          Text(item)
            .fontSize(TypeTokens.callout.size)
            .fontFamily(TypeTokens.fontFamily)
            .lineHeight(TypeTokens.callout.lineHeight)
            .fontColor(ColorTokens.primary)
            .layoutWeight(1)
        }
        .width('100%')
        .alignItems(VerticalAlign.Center)
      }, (item: string, index: number) => String(index) + ':' + item)
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  private compareSide(label: string, value: string): void {
    Column({ space: SpaceTokens.sm }) {
      Text(label)
        .fontSize(TypeTokens.overline.size)
        .fontFamily(TypeTokens.fontFamily)
        .fontWeight(600)
        .fontColor(this.accentColor())
      Text(value)
        .fontSize(TypeTokens.body.size)
        .fontFamily(TypeTokens.fontFamilySerifBody)
        .fontWeight(500)
        .lineHeight(TypeTokens.body.lineHeight)
        .fontColor(ColorTokens.primary)
    }
    .layoutWeight(1)
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  private compareBody(block: StructuredBlock): void {
    Row({ space: SpaceTokens.md }) {
      this.compareSide(block.leftLabel.length > 0 ? block.leftLabel : 'A', block.leftValue)
      Divider().vertical(true).height(64).color(ColorTokens.separator)
      this.compareSide(block.rightLabel.length > 0 ? block.rightLabel : 'B', block.rightValue)
    }
    .width('100%')
    .alignItems(VerticalAlign.Top)
  }

  @Builder
  private blockCard(block: StructuredBlock, primary: boolean): void {
    Column({ space: primary ? SpaceTokens.base : SpaceTokens.md }) {
      this.blockHeading(block, primary)
      if (block.type === 'metric') {
        this.metricBody(block, primary)
      } else if (block.type === 'insight') {
        this.insightBody(block, primary)
      } else if (block.type === 'list') {
        this.listBody(block)
      } else if (block.type === 'steps') {
        this.stepsBody(block)
      } else {
        this.compareBody(block)
      }
      if (block.helper.length > 0) {
        Text(block.helper)
          .fontSize(TypeTokens.caption.size)
          .fontFamily(TypeTokens.fontFamily)
          .fontColor(ColorTokens.tertiary)
          .width('100%')
      }
    }
    .width('100%')
    .padding(primary ? SpaceTokens.lg : SpaceTokens.base)
    .backgroundColor(this.surfaceColor(primary))
    .borderRadius(primary ? RadiusTokens.lg : RadiusTokens.md)
    .border({ width: primary ? 0 : LayoutTokens.hairlineWidth, color: ColorTokens.separator, style: BorderStyle.Solid })
    .alignItems(HorizontalAlign.Start)
  }

  build() {
    if (this.visibleBlocks().length > 0) {
      Column({ space: SpaceTokens.md }) {
        ForEach(this.visibleBlocks(), (block: StructuredBlock, index: number) => {
          this.blockCard(block, index === 0 && block.id === this.document?.primaryBlockId)
        }, (block: StructuredBlock) => block.id)
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
    }
  }
}
