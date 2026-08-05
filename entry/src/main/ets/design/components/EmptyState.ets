import { Pressable } from '../motion/Pressable';
import { ColorTokens } from '../tokens/color';
import { IconTokens } from '../tokens/icon';
import { RadiusTokens } from '../tokens/radius';
import { LayoutTokens, SpaceTokens } from '../tokens/space';
import { TypeTokens } from '../tokens/type';

@Component
export struct EmptyState {
  @Prop icon: Resource = $r('app.media.empty_search');
  @Prop title: string = '';
  @Prop message: string = '';
  @Prop actionLabel: string = '';
  @Prop reduceMotion: boolean = false;
  onAction: () => void = () => {};

  private safeTitle(): string {
    return this.title ?? '';
  }

  private safeMessage(): string {
    return this.message ?? '';
  }

  private safeActionLabel(): string {
    return this.actionLabel ?? '';
  }

  build() {
    Column({ space: SpaceTokens.item }) {
      Image(this.icon)
        .width(IconTokens.empty)
        .height(IconTokens.empty)
        .fillColor(ColorTokens.tertiary)

      Text(this.safeTitle())
        .fontSize(TypeTokens.headline.size).fontFamily(TypeTokens.fontFamily)
        .fontWeight(TypeTokens.headline.weight)
        .lineHeight(TypeTokens.headline.lineHeight)
        .letterSpacing(TypeTokens.headline.tracking)
        .fontColor(ColorTokens.primary)
        .textAlign(TextAlign.Center)

      if (this.safeMessage().length > 0) {
        Text(this.safeMessage())
          .fontSize(TypeTokens.callout.size).fontFamily(TypeTokens.fontFamily)
          .fontWeight(TypeTokens.callout.weight)
          .lineHeight(TypeTokens.callout.lineHeight)
          .letterSpacing(TypeTokens.callout.tracking)
          .fontColor(ColorTokens.secondary)
          .textAlign(TextAlign.Center)
      }

      if (this.safeActionLabel().length > 0) {
        Pressable({ reduceMotion: this.reduceMotion, action: this.onAction }) {
          Row() {
            Text(this.safeActionLabel())
              .fontSize(TypeTokens.callout.size).fontFamily(TypeTokens.fontFamily)
              .fontWeight(TypeTokens.headline.weight)
              .fontColor(ColorTokens.onBrand)
          }
          .constraintSize({ minWidth: LayoutTokens.minTouchTarget })
          .height(LayoutTokens.minTouchTarget)
          .padding({ left: SpaceTokens.base, right: SpaceTokens.base })
          .justifyContent(FlexAlign.Center)
          .backgroundColor(ColorTokens.brand)
          .borderRadius(RadiusTokens.md)
        }
      }
    }
    .width('100%')
    .padding({ left: SpaceTokens.xl, right: SpaceTokens.xl })
    .alignItems(HorizontalAlign.Center)
    .accessibilityGroup(true)
  }
}
