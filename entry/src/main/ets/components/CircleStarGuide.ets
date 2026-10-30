// 星图首次图例：只出现一次，解释「金环 / 亮度 / 红点」与三个手势。
// 用一张贴底卡片替代一长句黑话提示，减少理解成本，也不长期占据星图。
import { ColorTokens } from '../design/tokens/color';
import { RadiusTokens } from '../design/tokens/radius';
import { ShadowTokens } from '../design/tokens/shadow';
import { SpaceTokens } from '../design/tokens/space';
import { TypeTokens } from '../design/tokens/type';
import { DesignButton } from '../design/components/DesignButton';

@Component
export struct CircleStarGuide {
  onDismiss: () => void = (): void => {};
  @StorageProp('currentBreakpoint') currentBreakpoint: string = 'sm';

  // 图例是竖排三行短文，展开屏满幅 707vp 会留出一半死白；按断点限宽后由外层居中。
  private cardWidth(): Length {
    if (this.currentBreakpoint === 'lg') {
      return 600;
    }
    if (this.currentBreakpoint === 'md') {
      return 520;
    }
    return '100%';
  }

  @Builder
  private legendRow(marker: string, markerColor: ResourceColor, label: string, detail: string): void {
    Row({ space: SpaceTokens.sm }) {
      Text(marker)
        .width(28)
        .height(28)
        .textAlign(TextAlign.Center)
        .fontSize(TypeTokens.caption.size)
        .fontWeight(FontWeight.Bold)
        .fontColor(markerColor)
        .border({ width: 1.5, color: markerColor, style: BorderStyle.Solid })
        .borderRadius(RadiusTokens.pill)
      Column({ space: 1 }) {
        Text(label)
          .fontSize(TypeTokens.caption.size).fontFamily(TypeTokens.fontFamily)
          .fontWeight(TypeTokens.headline.weight)
          .fontColor(ColorTokens.primary)
        Text(detail)
          .fontSize(TypeTokens.overline.size).fontFamily(TypeTokens.fontFamily)
          .fontColor(ColorTokens.secondary)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
    }
    .width('100%')
    .alignItems(VerticalAlign.Center)
  }

  build() {
    Column({ space: SpaceTokens.sm }) {
      Row({ space: SpaceTokens.xs }) {
        Text('星图怎么看')
          .fontSize(TypeTokens.headline.size).fontFamily(TypeTokens.fontFamilySerif)
          .fontWeight(TypeTokens.headline.weight)
          .fontColor(ColorTokens.primary)
        Blank()
        Text('只看这一次')
          .fontSize(TypeTokens.overline.size).fontFamily(TypeTokens.fontFamily)
          .fontColor(ColorTokens.tertiary)
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)

      this.legendRow('环', ColorTokens.warm, '金环 = 已加入', '有金环的圈子，你已经关注')
      this.legendRow('亮', ColorTokens.brand, '亮 = 近 7 天有新帖', '暗一些的圈子近期比较安静')
      this.legendRow('3', ColorTokens.danger, '红点 = 未读新帖', '点红点直接读最新一帖')

      Text('点行星进圈 · 拖行星调关注 · 点 ✦ 看新帖')
        .width('100%')
        .fontSize(TypeTokens.overline.size).fontFamily(TypeTokens.fontFamily)
        .fontColor(ColorTokens.secondary)
        .padding({ top: SpaceTokens.xs })

      DesignButton({
        label: '知道了',
        variant: 'primary',
        action: (): void => { this.onDismiss(); },
      })
        .width('100%')
    }
    .width(this.cardWidth())
    .padding(SpaceTokens.md)
    .backgroundColor(ColorTokens.elevated)
    .border({ width: 1, color: ColorTokens.separator, style: BorderStyle.Solid })
    .borderRadius(RadiusTokens.lg)
    .shadow(ShadowTokens.floating)
    .alignItems(HorizontalAlign.Start)
  }
}
