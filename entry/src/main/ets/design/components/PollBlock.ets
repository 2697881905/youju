import { ColorTokens } from '../tokens/color';
import { IconTokens } from '../tokens/icon';
import { RadiusTokens } from '../tokens/radius';
import { SpaceTokens } from '../tokens/space';
import { TypeTokens } from '../tokens/type';

@Component
export struct PollBlock {
  @Prop planA: string = '';
  @Prop planB: string = '';
  @Prop compact: boolean = false;

  private safePlanA(): string {
    return this.planA ?? '';
  }

  private safePlanB(): string {
    return this.planB ?? '';
  }

  @Builder
  optionBadge(label: string, color: ResourceColor): void {
    Text(label)
      .width(this.compact ? IconTokens.compact : IconTokens.small)
      .height(this.compact ? IconTokens.compact : IconTokens.small)
      .borderRadius(RadiusTokens.pill)
      .fontSize(this.compact ? TypeTokens.overline.size : TypeTokens.caption.size).fontFamily(TypeTokens.fontFamily)
      .fontWeight(TypeTokens.headline.weight)
      .fontColor(ColorTokens.onBrand)
      .backgroundColor(color)
      .textAlign(TextAlign.Center)
  }

  build() {
    Column({ space: this.compact ? SpaceTokens.inlineTight : SpaceTokens.inline }) {
      if (this.safePlanA().length > 0) {
        Row({ space: this.compact ? SpaceTokens.inlineTight : SpaceTokens.inline }) {
          this.optionBadge('A', ColorTokens.brand)
          Text(this.safePlanA())
            .fontSize(this.compact ? TypeTokens.caption.size : TypeTokens.callout.size).fontFamily(TypeTokens.fontFamily)
            .fontWeight(TypeTokens.callout.weight)
            .lineHeight(TypeTokens.callout.lineHeight)
            .letterSpacing(TypeTokens.callout.tracking)
            .fontColor(ColorTokens.primary)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .layoutWeight(1)
        }
        .width('100%')
        .padding(this.compact ? SpaceTokens.inlineTight : SpaceTokens.inline)
        .backgroundColor(ColorTokens.brandTint)
        .borderRadius(RadiusTokens.xs)
      }
      if (this.safePlanB().length > 0) {
        Row({ space: this.compact ? SpaceTokens.inlineTight : SpaceTokens.inline }) {
          this.optionBadge('B', ColorTokens.warm)
          Text(this.safePlanB())
            .fontSize(this.compact ? TypeTokens.caption.size : TypeTokens.callout.size).fontFamily(TypeTokens.fontFamily)
            .fontWeight(TypeTokens.callout.weight)
            .lineHeight(TypeTokens.callout.lineHeight)
            .letterSpacing(TypeTokens.callout.tracking)
            .fontColor(ColorTokens.primary)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .layoutWeight(1)
        }
        .width('100%')
        .padding(this.compact ? SpaceTokens.inlineTight : SpaceTokens.inline)
        .backgroundColor(ColorTokens.subtle)
        .borderRadius(RadiusTokens.xs)
      }
    }
    .width('100%')
  }
}
