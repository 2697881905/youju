import { BackButton } from '../design/components/BackButton';
import { ColorTokens } from '../design/tokens/color';
import { IconTokens } from '../design/tokens/icon';
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
        // 每个动作独立 44×44 命中区，图标 24vp：间距由命中区自身的居中留白承担，
        // 不再靠 Row 的 space 直接贴图标（旧版 20vp 图标 + 4vp 间距，视觉过挤且命中区不足）。
        Row() {
          Image(resolveActionIcon('share'))
            .width(IconTokens.standard)
            .height(IconTokens.standard)
            .fillColor(ColorTokens.secondary)
            .draggable(false)
        }
        .width(LayoutTokens.minTouchTarget)
        .height(LayoutTokens.minTouchTarget)
        .justifyContent(FlexAlign.Center)
        .alignItems(VerticalAlign.Center)
        .accessibilityText('分享')
        .onClick((): void => { this.onShare(); })

        Row() {
          Image(resolveActionIcon('more'))
            .width(IconTokens.standard)
            .height(IconTokens.standard)
            .fillColor(ColorTokens.secondary)
            .draggable(false)
        }
        .width(LayoutTokens.minTouchTarget)
        .height(LayoutTokens.minTouchTarget)
        .justifyContent(FlexAlign.Center)
        .alignItems(VerticalAlign.Center)
        .accessibilityText('更多操作')
        .onClick((): void => { this.onMore(); })
      }
      .height(LayoutTokens.minTouchTarget)
      .alignItems(VerticalAlign.Center)
    }
    .width('100%')
    .padding({ left: SpaceTokens.sm, right: SpaceTokens.sm, top: SpaceTokens.sm, bottom: SpaceTokens.xs })
  }
}
