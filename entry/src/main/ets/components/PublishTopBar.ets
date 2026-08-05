import { DesignButton } from '../design/components/DesignButton';
import { ColorTokens } from '../design/tokens/color';
import { SpaceTokens } from '../design/tokens/space';
import { TypeTokens } from '../design/tokens/type';

@Component
export struct PublishTopBar {
  @Prop progressText: string = '';
  @Prop previewDisabled: boolean = false;
  onClear: () => void = (): void => {};
  onPreview: () => void = (): void => {};

  build() {
    Row({ space: SpaceTokens.sm }) {
      DesignButton({ label: '清空', variant: 'glass', action: (): void => { this.onClear(); } })
      Column({ space: SpaceTokens.xs }) {
        Text('发布内容')
          .fontSize(TypeTokens.headline.size).fontFamily(TypeTokens.fontFamily)
          .fontWeight(TypeTokens.headline.weight)
          .lineHeight(TypeTokens.headline.lineHeight)
          .letterSpacing(TypeTokens.headline.tracking)
          .fontColor(ColorTokens.primary)
          .textAlign(TextAlign.Center)
        Text(this.progressText)
          .fontSize(TypeTokens.caption.size).fontFamily(TypeTokens.fontFamily)
          .fontWeight(TypeTokens.caption.weight)
          .lineHeight(TypeTokens.caption.lineHeight)
          .fontColor(ColorTokens.secondary)
          .textAlign(TextAlign.Center)
      }
      .layoutWeight(1)
      DesignButton({ label: '预览', variant: 'glass', disabled: this.previewDisabled, action: (): void => { this.onPreview(); } })
    }
    .width('100%')
    .alignItems(VerticalAlign.Center)
  }
}
