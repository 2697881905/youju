import { BackButton } from '../design/components/BackButton';
import { ColorTokens } from '../design/tokens/color';
import { RadiusTokens } from '../design/tokens/radius';
import { LayoutTokens, SpaceTokens } from '../design/tokens/space';
import { TypeTokens } from '../design/tokens/type';
import { resolveActionIcon } from '../utils/actionIcons';

// 详情页固定操作层不读取帖子状态，避免工具栏和详情数据加载彼此耦合。
@Component
export struct DetailToolbar {
  @Prop title: string = '';
  onBack: () => void = (): void => {};
  onMore: () => void = (): void => {};
  onShare: () => void = (): void => {};

  build() {
    Row({ space: SpaceTokens.sm }) {
      BackButton({ action: (): void => { this.onBack(); } })
      Text(this.title)
        .fontSize(TypeTokens.callout.size).fontFamily(TypeTokens.fontFamily)
        .fontWeight(TypeTokens.headline.weight)
        .fontColor(ColorTokens.secondary)
        .layoutWeight(1)
        .textAlign(TextAlign.Center)
      Row({ space: SpaceTokens.xs }) {
        Image(resolveActionIcon('share'))
          .width(20)
          .height(20)
          .opacity(0.82)
          .onClick((): void => { this.onShare(); })
          .fillColor(ColorTokens.secondary)
        Image(resolveActionIcon('more'))
          .width(20)
          .height(20)
          .opacity(0.82)
          .onClick((): void => { this.onMore(); })
          .fillColor(ColorTokens.secondary)
      }
      .width(LayoutTokens.minTouchTarget * 2 + SpaceTokens.xs)
      .height(LayoutTokens.minTouchTarget)
      .justifyContent(FlexAlign.Center)
      .alignItems(VerticalAlign.Center)
      .accessibilityText('分享和更多操作')
    }
    .width('100%')
    .padding({ left: SpaceTokens.sm, right: SpaceTokens.sm, top: SpaceTokens.sm, bottom: SpaceTokens.xs })
  }
}
