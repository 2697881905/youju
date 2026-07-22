// 标签线条图标组件（Apple 风格极简线条 Logo）
// 通过 fillColor 对 SVG(currentColor stroke) 着色，支持选中态反白/分类着色。

import { resolveTagIcon } from '../utils/tagIcons';

@Component
export struct TagIcon {
  @Prop name: string = '';       // 标签名（与 tagIcons 映射一致）
  @Prop iconSize: number = 20;   // 图标边长 vp
  @Prop tint: ResourceColor = $r('app.color.text_primary'); // 着色（选中反白/默认主文色）

  build() {
    Image(resolveTagIcon(this.name))
      .width(this.iconSize)
      .height(this.iconSize)
      .fillColor(this.tint)
      .objectFit(ImageFit.Contain)
  }
}
