// IconButton —— 图标珠 / 纯图标动作件（家族唯一样式源）
//
// 弹窗 close、清空历史等同款。新增图标动作钮一律引用本组件，禁止再手搓 Pressable+Image。
// 两档表面：
// - bead=false：纯图标无表面（触控 44vp，弹窗标题行关闭等）
// - bead=true：glassWhite 浅玻璃圆珠（地图悬浮关闭等）——玻璃珠上的图标用**固定深墨**：
//   glassWhite 是常量浅底不随主题翻转，主题 icon 色在深色模式下是浅色、压白珠不可读
//   （地图选城关闭钮实证 2026-10-26）。
import { Pressable } from '../motion/Pressable';
import { ColorTokens } from '../tokens/color';
import { IconTokens } from '../tokens/icon';
import { RadiusTokens } from '../tokens/radius';
import { LayoutTokens } from '../tokens/space';
import { resolveActionIcon } from '../../utils/actionIcons';

// 浅玻璃珠上的固定墨色（不随深浅模式翻转）
const BEAD_INK: string = '#2B2B2B';

@Component
export struct IconButton {
  // ACTION_ICONS 名（back/close/trash…），默认 close
  @Prop icon: string = 'close';
  @Prop bead: boolean = false;
  @Prop a11yText: string = '';
  action: () => void = (): void => {};

  build() {
    Pressable({
      visualHeight: this.bead ? 36 : LayoutTokens.minTouchTarget,
      touchTargetHeight: LayoutTokens.minTouchTarget,
      action: this.action,
    }) {
      Row() {
        Image(resolveActionIcon(this.icon))
          .width(IconTokens.compact)
          .height(IconTokens.compact)
          .fillColor(this.bead ? BEAD_INK : ColorTokens.icon)
      }
      .width(this.bead ? 36 : LayoutTokens.minTouchTarget)
      .height(this.bead ? 36 : LayoutTokens.minTouchTarget)
      .justifyContent(FlexAlign.Center)
      .alignItems(VerticalAlign.Center)
      .backgroundColor(this.bead ? ColorTokens.glassWhite : Color.Transparent)
      .borderRadius(RadiusTokens.pill)
      .accessibilityText(this.a11yText)
    }
  }
}
