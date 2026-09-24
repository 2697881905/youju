import { BackButton } from '../design/components/BackButton';
import { ColorTokens } from '../design/tokens/color';
import { IconTokens } from '../design/tokens/icon';
import { RadiusTokens } from '../design/tokens/radius';
import { LayoutTokens, SpaceTokens } from '../design/tokens/space';
import { resolveActionIcon } from '../utils/actionIcons';

// 详情页固定操作层不读取帖子状态，避免工具栏和详情数据加载彼此耦合。
@Component
export struct DetailToolbar {
  onBack: () => void = (): void => {};
  onMore: () => void = (): void => {};
  onShare: () => void = (): void => {};

  build() {
    Row({ space: SpaceTokens.sm }) {
      BackButton({ action: (): void => { this.onBack(); } })
      // 居中标题位保留为纯撑开空间：详情页顶部不再显示体裁标签（原先显示「经验分享」等）。
      // 用 Blank 而非删掉该位，是为了让右侧动作组继续贴右边缘。
      Blank()
      Row({ space: SpaceTokens.xs }) {
        // 每个动作独立 44×44 命中区，图标 24vp：间距由命中区自身的居中留白承担，
        // 不再靠 Row 的 space 直接贴图标（旧版 20vp 图标 + 4vp 间距，视觉过挤且命中区不足）。
        Row() {
          Image(resolveActionIcon('share'))
            .width(IconTokens.standard)
            .height(IconTokens.standard)
            .fillColor(ColorTokens.icon)
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
            .fillColor(ColorTokens.icon)
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
