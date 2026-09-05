import { resolveActionIcon } from '../../utils/actionIcons';
import { Pressable } from '../motion/Pressable';
import { ColorTokens } from '../tokens/color';
import { IconTokens } from '../tokens/icon';
import { LayoutTokens } from '../tokens/space';

// 所有二级页面共用的返回入口：44vp 触控面积，纯图标无玻璃背景。
@Component
export struct BackButton {
  action: () => void = (): void => {};

  build() {
    Pressable({
      visualHeight: LayoutTokens.minTouchTarget,
      touchTargetHeight: LayoutTokens.minTouchTarget,
      action: this.action,
    }) {
      Row() {
        Image(resolveActionIcon('back'))
          .width(IconTokens.small)
          .height(IconTokens.small)
          .fillColor(ColorTokens.primary)
      }
      .width(LayoutTokens.minTouchTarget)
      .height(LayoutTokens.minTouchTarget)
      .justifyContent(FlexAlign.Center)
      .accessibilityText('返回')
    }
  }
}
