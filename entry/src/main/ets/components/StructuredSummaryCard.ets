import { StructuredSummary } from '../utils/structuredBlocks';
import { ColorTokens } from '../design/tokens/color';
import { RadiusTokens } from '../design/tokens/radius';
import { LayoutTokens, SpaceTokens } from '../design/tokens/space';
import { TypeTokens } from '../design/tokens/type';

// 信息流结构化主视觉：只展示一个主结论和最多两个辅助信息。
// 不把详情字段表缩小塞进卡片，而是用稳定的视觉语法建立内容辨识度。
@Component
export struct StructuredSummaryCard {
  @Prop summary: StructuredSummary | null = null;
  @Prop compact: boolean = false;
  // 信息流中作为卡片中段时铺满宽度；详情/预览中仍保持独立结论卡形态。
  @Prop attached: boolean = false;

  private primarySize(): number {
    return this.compact ? 22 : 28;
  }

  private surfaceColor(): ResourceColor {
    if (this.summary?.theme === 'warm') return '#FFF4E8';
    if (this.summary?.theme === 'cool') return '#EEF7F5';
    return ColorTokens.brandTint;
  }

  private accentColor(): ResourceColor {
    if (this.summary?.theme === 'warm') return '#A85D24';
    if (this.summary?.theme === 'cool') return '#2D746E';
    return ColorTokens.brand;
  }

  private displaySecondary(index: number): string {
    if (this.summary === null || index < 0 || index >= this.summary.secondary.length) {
      return '';
    }
    return this.summary.secondary[index];
  }

  @Builder
  private eyebrow(): void {
    if (this.summary !== null) {
      Row({ space: SpaceTokens.inlineTight }) {
        Text(this.summary.eyebrow.toUpperCase())
          .fontSize(TypeTokens.overline.size)
          .fontFamily(TypeTokens.fontFamily)
          .fontWeight(TypeTokens.overline.weight)
          .letterSpacing(1.2)
          .fontColor(this.accentColor())
        Text('结构化')
          .fontSize(TypeTokens.overline.size)
          .fontFamily(TypeTokens.fontFamily)
          .fontColor(ColorTokens.tertiary)
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)
    }
  }

  @Builder
  private metricBody(): void {
    if (this.summary !== null) {
      Row({ space: SpaceTokens.sm }) {
        Column({ space: 1 }) {
          Text(this.summary.primary)
            .fontSize(this.primarySize())
            .fontFamily(TypeTokens.fontFamilySerif)
            .fontWeight(TypeTokens.titleSerif.weight)
            .fontColor(ColorTokens.primary)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
          Text(this.summary.label)
            .fontSize(TypeTokens.overline.size)
            .fontFamily(TypeTokens.fontFamily)
            .fontColor(ColorTokens.secondary)
        }
        if (this.summary.helper.length > 0) {
          Text(this.summary.helper)
            .fontSize(TypeTokens.caption.size)
            .fontFamily(TypeTokens.fontFamily)
            .fontColor(ColorTokens.tertiary)
            .layoutWeight(1)
            .textAlign(TextAlign.End)
        }
      }
      .width('100%')
      .alignItems(VerticalAlign.Bottom)
    }
  }

  @Builder
  private insightBody(): void {
    if (this.summary !== null) {
      Column({ space: SpaceTokens.inlineTight }) {
        Text(this.summary.label)
          .fontSize(TypeTokens.overline.size)
          .fontFamily(TypeTokens.fontFamily)
          .fontColor(ColorTokens.secondary)
        Text(this.summary.primary)
          .fontSize(this.compact ? TypeTokens.callout.size : TypeTokens.body.size)
          .fontFamily(TypeTokens.fontFamilySerifBody)
          .fontWeight(500)
          .lineHeight(this.compact ? 20 : 24)
          .fontColor(ColorTokens.primary)
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
    }
  }

  @Builder
  private compareBody(): void {
    if (this.summary !== null) {
      Row({ space: SpaceTokens.sm }) {
        this.compareSide('A', this.summary.primary)
        Divider().vertical(true).height(30).color(ColorTokens.separator)
        this.compareSide('B', this.displaySecondary(0))
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)
    }
  }

  @Builder
  private compareSide(mark: string, value: string): void {
    Column({ space: 2 }) {
      Text(mark)
        .fontSize(TypeTokens.overline.size)
        .fontFamily(TypeTokens.fontFamily)
        .fontWeight(TypeTokens.overline.weight)
        .fontColor(this.accentColor())
      Text(value)
        .fontSize(TypeTokens.callout.size)
        .fontFamily(TypeTokens.fontFamilySerifBody)
        .fontColor(ColorTokens.primary)
        .maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
    }
    .layoutWeight(1)
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  private stepsBody(): void {
    if (this.summary !== null) {
      Row({ space: SpaceTokens.sm }) {
        Text(this.summary.primary)
          .fontSize(this.primarySize())
          .fontFamily(TypeTokens.fontFamilySerif)
          .fontWeight(TypeTokens.titleSerif.weight)
          .fontColor(ColorTokens.primary)
        Column({ space: 3 }) {
          this.stepPreview(0)
          this.stepPreview(1)
        }
        .layoutWeight(1)
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)
    }
  }

  @Builder
  private stepPreview(index: number): void {
    if (this.displaySecondary(index).length > 0) {
      Row({ space: SpaceTokens.inlineTight }) {
        Text(String(index + 1))
          .width(16)
          .height(16)
          .fontSize(9)
          .fontFamily(TypeTokens.fontFamily)
          .fontColor(this.accentColor())
          .backgroundColor(ColorTokens.elevated)
          .borderRadius(RadiusTokens.pill)
          .textAlign(TextAlign.Center)
        Text(this.displaySecondary(index))
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
  }

  @Builder
  private secondaryLine(): void {
    if (this.summary !== null && this.summary.secondary.length > 0 &&
      this.summary.mode !== 'compare' && this.summary.mode !== 'steps') {
      Row({ space: SpaceTokens.inlineTight }) {
        ForEach(this.summary.secondary, (item: string) => {
          Text(item)
            .fontSize(TypeTokens.caption.size)
            .fontFamily(TypeTokens.fontFamily)
            .fontColor(ColorTokens.secondary)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .layoutWeight(1)
        }, (item: string) => item)
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)
    }
  }

  build() {
    if (this.summary !== null) {
      Column({ space: this.compact ? SpaceTokens.xs : SpaceTokens.sm }) {
        this.eyebrow()
        if (this.summary.mode === 'metric') {
          this.metricBody()
        } else if (this.summary.mode === 'compare') {
          this.compareBody()
        } else if (this.summary.mode === 'steps') {
          this.stepsBody()
        } else {
          this.insightBody()
        }
        this.secondaryLine()
        if (this.summary.helper.length > 0 && this.summary.mode !== 'metric') {
          Text(this.summary.helper)
            .fontSize(TypeTokens.overline.size)
            .fontFamily(TypeTokens.fontFamily)
            .fontColor(ColorTokens.tertiary)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
      }
      .width('100%')
      .padding(this.compact ? SpaceTokens.sm : SpaceTokens.md)
      .backgroundColor(this.surfaceColor())
      .borderRadius(this.attached ? RadiusTokens.none : (this.compact ? RadiusTokens.sm : RadiusTokens.md))
      .border({
        width: this.attached ? 0 : LayoutTokens.hairlineWidth,
        color: ColorTokens.separator,
        style: BorderStyle.Solid,
      })
      .alignItems(HorizontalAlign.Start)
    }
  }
}
