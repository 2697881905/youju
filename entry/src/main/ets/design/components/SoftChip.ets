// SoftChip —— soft chip（家族唯一样式源）
//
// 实色软底小胶囊动作件：「+ 加块 / 重试 / 取消拉黑」同款。新增小型实色动作 chip
// 一律引用本组件，按 tone 选档，禁止再手写底色字色。
// 三档：
// - neutral：elevated 底 + primary 字 + 发丝描边（加块这类次级补充动作）
// - brand：  brand 底 + onBrand 字（重试这类主动作）
// - danger： dangerTint 底 + danger 字（取消拉黑这类危险动作；tint 底是危险按钮的
//            全应用规范——实色 danger 底过重，tint + danger 字既示警又不抢层级）
import { Pressable } from '../motion/Pressable';
import { ColorTokens } from '../tokens/color';
import { RadiusTokens } from '../tokens/radius';
import { LayoutTokens, SpaceTokens } from '../tokens/space';
import { TypeTokens } from '../tokens/type';

export type SoftChipTone = 'neutral' | 'brand' | 'danger';

@Component
export struct SoftChip {
  @Prop label: string = '';
  @Prop tone: SoftChipTone = 'neutral';
  // 标准 30 高；特殊场景可传（28=紧凑、36=加块）
  @Prop visualHeight: number = 30;
  @Prop disabled: boolean = false;
  action: () => void = (): void => {};

  private bg(): ResourceColor {
    if (this.tone === 'brand') {
      return ColorTokens.brandSolid;
    }
    if (this.tone === 'danger') {
      return ColorTokens.dangerTint;
    }
    return ColorTokens.elevated;
  }

  private fg(): ResourceColor {
    if (this.disabled) {
      return ColorTokens.quaternary;
    }
    if (this.tone === 'brand') {
      return ColorTokens.onBrand;
    }
    if (this.tone === 'danger') {
      return ColorTokens.danger;
    }
    return ColorTokens.primary;
  }

  build() {
    Pressable({
      disabled: this.disabled,
      visualHeight: this.visualHeight,
      touchTargetHeight: LayoutTokens.minTouchTarget,
      action: this.action,
    }) {
      Text(this.label)
        .fontSize(TypeTokens.caption.size)
        .fontFamily(TypeTokens.fontFamily)
        .fontWeight(TypeTokens.callout.weight)
        .lineHeight(TypeTokens.caption.lineHeight)
        .fontColor(this.fg())
        .textAlign(TextAlign.Center)
        .height(this.visualHeight)
        .padding({ left: SpaceTokens.base, right: SpaceTokens.base })
        .backgroundColor(this.bg())
        .border({
          width: this.tone === 'neutral' ? LayoutTokens.hairlineWidth : 0,
          color: ColorTokens.separator,
          style: BorderStyle.Solid,
        })
        .borderRadius(RadiusTokens.pill)
        .opacity(this.disabled ? 0.45 : 1)
    }
  }
}
