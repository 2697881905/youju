// ToggleChip —— 迷你 toggle chip（家族唯一样式源）
//
// 结构化创作 miniAction 同款：28 高小胶囊，选中/未选中双态。
// 「选中」的身份由 tint 底 + 加粗 + 墨字承担——brand 字压 brandTint 深色只有 3.58:1
// （11px 不达 AA），不用 brand 字色。新增可选中迷你 chip 一律引用本组件。
import { Pressable } from '../motion/Pressable';
import { ColorTokens } from '../tokens/color';
import { RadiusTokens } from '../tokens/radius';
import { LayoutTokens, SpaceTokens } from '../tokens/space';
import { TypeTokens } from '../tokens/type';

@Component
export struct ToggleChip {
  @Prop label: string = '';
  @Prop selected: boolean = false;
  action: () => void = (): void => {};

  build() {
    Pressable({
      visualHeight: 28,
      touchTargetHeight: LayoutTokens.minTouchTarget,
      action: this.action,
    }) {
      Text(this.label)
        .fontSize(TypeTokens.overline.size)
        .fontFamily(TypeTokens.fontFamily)
        .fontWeight(this.selected ? 600 : 450)
        .fontColor(this.selected ? ColorTokens.primary : ColorTokens.secondary)
        .backgroundColor(this.selected ? ColorTokens.brandTint : ColorTokens.elevated)
        .borderRadius(RadiusTokens.pill)
        .padding({ left: SpaceTokens.sm, right: SpaceTokens.sm, top: 6, bottom: 6 })
    }
  }
}
