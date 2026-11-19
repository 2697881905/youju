// 今日圈内：圈子页底部内容 Dock。
// 星图负责“我的圈子在哪”，Dock 负责“现在有什么可读”——让用户 0 次点击读到内容。
// 数据来自 /v1/tags/overview 的 digest（服务端已按「已加入圈子优先」排序）。
import { CircleDigestItem } from '../services/api';
import { ColorTokens } from '../design/tokens/color';
import { RadiusTokens } from '../design/tokens/radius';
import { ShadowTokens } from '../design/tokens/shadow';
import { LayoutTokens, SpaceTokens } from '../design/tokens/space';
import { TypeTokens } from '../design/tokens/type';
import { immersiveCardWidth } from '../design/tokens/galaxy';
import { Pressable } from '../design/motion/Pressable';

@Component
export struct CircleDigestDock {
  @Prop items: CircleDigestItem[] = [];
  // 小屏只放 2 条，避免 Dock 压到最外环的行星标签。
  @Prop maxItems: number = 3;
  onOpen: (postId: number) => void = (_postId: number): void => {};
  @StorageProp('currentBreakpoint') currentBreakpoint: string = 'sm';

  private visibleItems(): CircleDigestItem[] {
    return this.items.slice(0, Math.max(1, this.maxItems));
  }

  @Builder
  private digestRow(item: CircleDigestItem): void {
    Pressable({
      fillWidth: true,
      fullResponseRegion: true,
      action: (): void => { this.onOpen(item.postId); },
    }) {
      Row({ space: SpaceTokens.md }) {
        Text(item.circleName)
          .fontSize(TypeTokens.overline.size).fontFamily(TypeTokens.fontFamily)
          .fontWeight(TypeTokens.headline.weight)
          // 蓝字压蓝 tint 在 11px 下只有 3.58:1（不达 AA），蓝色身份交给 tint 底承担，文字回主墨色。
          // 与 ToggleChip/CircleExploreSheet 的同一口径。
          .fontColor(ColorTokens.primary)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .constraintSize({ maxWidth: 84 })
          .padding({ left: SpaceTokens.sm, right: SpaceTokens.sm, top: 3, bottom: 3 })
          .backgroundColor(ColorTokens.brandTint)
          .borderRadius(RadiusTokens.pill)

        Column({ space: 2 }) {
          Text(item.title.length > 0 ? item.title : '无题')
            .fontSize(TypeTokens.callout.size).fontFamily(TypeTokens.fontFamily)
            .fontWeight(TypeTokens.caption.weight)
            .lineHeight(TypeTokens.callout.lineHeight)
            .fontColor(ColorTokens.primary)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
          Text('@' + item.authorName + ' · ▲ ' + item.upCount)
            .fontSize(TypeTokens.overline.size).fontFamily(TypeTokens.fontFamily)
            .fontColor(ColorTokens.secondary)
            .maxLines(1)
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)

        Text('›')
          .fontSize(TypeTokens.headline.size).fontFamily(TypeTokens.fontFamily)
          .fontColor(ColorTokens.tertiary)
      }
      .width('100%')
      .padding({ top: SpaceTokens.xs, bottom: SpaceTokens.xs })
      .alignItems(VerticalAlign.Center)
    }
  }

  build() {
    Column({ space: SpaceTokens.xs }) {
      Row({ space: SpaceTokens.xs }) {
        Text('今日圈内')
          .fontSize(TypeTokens.caption.size).fontFamily(TypeTokens.fontFamilySerif)
          .fontWeight(TypeTokens.headline.weight)
          .fontColor(ColorTokens.primary)
        Blank()
        Text(String(this.visibleItems().length) + ' 条')
          .fontSize(TypeTokens.overline.size).fontFamily(TypeTokens.fontFamily)
          .fontColor(ColorTokens.secondary)
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)

      ForEach(this.visibleItems(), (item: CircleDigestItem, index: number) => {
        Column() {
          // 行间分隔：三行原本只靠 padding 挤在一起，读起来是一团。
          if (index > 0) {
            Divider()
              .color(ColorTokens.separator)
              .strokeWidth(LayoutTokens.hairlineWidth)
          }
          this.digestRow(item)
        }
        .width('100%')
      }, (item: CircleDigestItem) => String(item.postId))
    }
    .width(immersiveCardWidth(this.currentBreakpoint))
    .padding(SpaceTokens.md)
    .backgroundColor(ColorTokens.elevated)
    .borderRadius(RadiusTokens.lg)
    .border({ width: LayoutTokens.glassBorderWidth, color: ColorTokens.separator, style: BorderStyle.Solid })
    // 贴底的常驻内容卡，不是浮层：floating 那档投影会把它推离星图，像第三方贴片。
    .shadow(ShadowTokens.cardAmbient)
    .alignItems(HorizontalAlign.Start)
  }
}
