import { ColorTokens } from '../tokens/color';
import { IconTokens } from '../tokens/icon';
import { RadiusTokens } from '../tokens/radius';
import { SpaceTokens } from '../tokens/space';

@Component
export struct IconTile {
  @Prop icon: Resource = $r('app.media.tag_all');
  @Prop tileSize: number = 44;
  @Prop iconSize: number = IconTokens.standard;
  // 图标源分两类，这里的 fillColor 对二者的影响不同：
  //   ① 已转 fill="currentColor" 的官方图标（set_edit / notification_system 等）
  //      → 由 fillColor 按主题着色，必须保留，否则深色模式下按默认色渲染、几乎看不见。
  //   ② 仍是描边造型（fill="none" + stroke）的自绘图标（genre_* / action_bookmark / chevron_*）
  //      → fillColor 对其为无操作（官方文档：SVG 图源 fill 为 none 时 fillColor 不生效），
  //      颜色由资源内烤色 + base/dark 双份决定，不受影响。
  // 实测依据：chevron_right（fill="none" + stroke）在 SettingsPage/ProfilePage 长期挂 fillColor
  // 一直渲染正常，未出现"轮廓被补成实心"。原先"勿在此 fillColor"的注释在现行 API 下不成立。
  @Prop showBackground: boolean = true;

  build() {
    Row() {
      Image(this.icon)
        .width(this.iconSize)
        .height(this.iconSize)
        .fillColor(ColorTokens.icon)
    }
    .width(this.tileSize)
    .height(this.tileSize)
    .justifyContent(FlexAlign.Center)
    .alignItems(VerticalAlign.Center)
    .backgroundColor(this.showBackground ? ColorTokens.brandTint : Color.Transparent)
    .borderRadius(RadiusTokens.sm)
    .padding(SpaceTokens.sm)
  }
}
