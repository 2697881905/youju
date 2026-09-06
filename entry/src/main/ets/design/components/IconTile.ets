import { ColorTokens } from '../tokens/color';
import { IconTokens } from '../tokens/icon';
import { RadiusTokens } from '../tokens/radius';
import { SpaceTokens } from '../tokens/space';

@Component
export struct IconTile {
  @Prop icon: Resource = $r('app.media.tag_all');
  @Prop tileSize: number = 44;
  @Prop iconSize: number = IconTokens.standard;
  // 图标源为功能线条（SVG 内已烤主题线色）时无需 fillColor；若为 currentColor 圈子 Logo
  // 需要着色，请改走 TagIcon 组件（勿在此对线条 fillColor，会把 fill="none" 补成实心）。
  @Prop tint: ResourceColor = ColorTokens.brand;
  @Prop selected: boolean = false;
  // 发布器等密集表单场景可仅保留 Logo，避免重复的彩色图标底块。
  @Prop showBackground: boolean = true;

  build() {
    Row() {
      Image(this.icon)
        .width(this.iconSize)
        .height(this.iconSize)
    }
    .width(this.tileSize)
    .height(this.tileSize)
    .justifyContent(FlexAlign.Center)
    .alignItems(VerticalAlign.Center)
    .backgroundColor(this.showBackground
      ? (this.selected ? ColorTokens.brandTint : ColorTokens.brandTint)
      : Color.Transparent)
    .borderRadius(RadiusTokens.sm)
    .padding(SpaceTokens.sm)
  }
}
