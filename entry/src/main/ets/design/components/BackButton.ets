import { resolveActionIcon } from '../../utils/actionIcons';
import { Pressable } from '../motion/Pressable';
import { ColorTokens } from '../tokens/color';
import { IconTokens } from '../tokens/icon';
import { RadiusTokens } from '../tokens/radius';
import { LayoutTokens } from '../tokens/space';

// 所有二级页面共用的返回入口：44vp 触控面积与底部栏相同的玻璃层级。
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
      }
      .width(LayoutTokens.minTouchTarget)
      .height(LayoutTokens.minTouchTarget)
      .justifyContent(FlexAlign.Center)
      .backgroundColor(ColorTokens.elevated)
      .border({ width: 1, color: ColorTokens.separator, style: BorderStyle.Solid })
      .borderRadius(RadiusTokens.lg)
      .shadow({ radius: 6, color: ColorTokens.barShadow, offsetY: 2 })
      .accessibilityText('返回')
    }
  }
}
