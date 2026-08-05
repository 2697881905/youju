import { BackButton } from '../design/components/BackButton';
import { ColorTokens } from '../design/tokens/color';
import { RadiusTokens } from '../design/tokens/radius';
import { LayoutTokens, SpaceTokens } from '../design/tokens/space';
import { TypeTokens } from '../design/tokens/type';

// 详情页固定操作层不读取帖子状态，避免工具栏和详情数据加载彼此耦合。
@Component
export struct DetailToolbar {
  @Prop title: string = '';
  onBack: () => void = (): void => {};
  onMore: () => void = (): void => {};

  build() {
    Row({ space: SpaceTokens.sm }) {
      BackButton({ action: (): void => { this.onBack(); } })
      Text(this.title)
        .fontSize(TypeTokens.callout.size).fontFamily(TypeTokens.fontFamily)
        .fontWeight(TypeTokens.headline.weight)
        .fontColor(ColorTokens.secondary)
        .layoutWeight(1)
        .textAlign(TextAlign.Center)
      Text('...')
        .fontSize(TypeTokens.headline.size).fontFamily(TypeTokens.fontFamily)
        .fontWeight(TypeTokens.headline.weight)
        .fontColor(ColorTokens.primary)
        .width(LayoutTokens.minTouchTarget)
        .height(LayoutTokens.minTouchTarget)
        .textAlign(TextAlign.Center)
        .backgroundColor(ColorTokens.barSurface)
        .backdropBlur(LayoutTokens.glassBlur)
        .border({ width: LayoutTokens.glassBorderWidth, color: ColorTokens.barBorder, style: BorderStyle.Solid })
        .borderRadius(RadiusTokens.lg)
        .onClick((): void => { this.onMore(); })
    }
    .width('100%')
    .padding({ left: SpaceTokens.sm, right: SpaceTokens.sm, top: SpaceTokens.sm, bottom: SpaceTokens.xs })
  }
}
