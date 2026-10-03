import { Genre } from '../models/types';
import { PublishGenreItem, PUBLISH_GENRES, publishGenreMeta } from '../utils/publishGenres';
import { IconTile } from '../design/components/IconTile';
import { Pressable } from '../design/motion/Pressable';
import { resolveActionIcon } from '../utils/actionIcons';
import { ColorTokens } from '../design/tokens/color';
import { IconTokens } from '../design/tokens/icon';
import { RadiusTokens } from '../design/tokens/radius';
import { LayoutTokens, SpaceTokens } from '../design/tokens/space';
import { TypeTokens } from '../design/tokens/type';

// —— 应用整体浮层材质（暖纸色系，与底部栏/浮层面板同语言）——
// 背景用 barSurface 暖米半透明 + backdropBlur（暖玻璃感），描边用 barBorder 暖色细线，
// 阴影用 barShadow 暖棕——与 SpringPanel/GlassPanel 保持一致，而非分段栏组件的纯白玻璃。
const SEGMENT_GLASS_BG: ResourceColor = ColorTokens.barSurface;
const SEGMENT_GLASS_BLUR: number = 20;
const SEGMENT_GLASS_BORDER: ResourceColor = ColorTokens.barBorder;

@Component
export struct PublishGenreSection {
  @Prop genre: Genre = 'review';
  @Prop genreIndex: number = 0;
  onSelectGenre: (index: number) => void = (_index: number): void => {};
  onOpenTags: () => void = (): void => {};

  private meta(): PublishGenreItem {
    return publishGenreMeta(this.genre);
  }

  // 体裁选择：系统原生文本选择器弹窗（滚轮 + 系统材质），替代自绘下拉菜单
  private openGenrePicker(): void {
    const labels: string[] = PUBLISH_GENRES.map((item: PublishGenreItem): string => item.label);
    this.getUIContext().showTextPickerDialog({
      range: labels,
      selected: this.genreIndex,
      defaultPickerItemHeight: 36,
      canLoop: true,
      onAccept: (value: TextPickerResult) => {
        const index: number = typeof value.index === 'number' ? value.index : value.index[0];
        this.onSelectGenre(index);
      },
    });
  }

  build() {
    Row({ space: SpaceTokens.sm }) {
      IconTile({ icon: this.meta().iconRes, tileSize: 58, iconSize: 32, showBackground: false })
      Column({ space: SpaceTokens.xs }) {
        Text('开始创作!')
          .fontSize(TypeTokens.headline.size).fontFamily(TypeTokens.fontFamilySerif)
          .fontWeight(TypeTokens.headline.weight)
          .lineHeight(TypeTokens.headline.lineHeight)
          .letterSpacing(TypeTokens.headline.tracking)
          .fontColor(ColorTokens.primary)
        Text(this.meta().hint)
          .fontSize(TypeTokens.callout.size).fontFamily(TypeTokens.fontFamily)
          .fontWeight(TypeTokens.callout.weight)
          .lineHeight(TypeTokens.callout.lineHeight)
          .letterSpacing(TypeTokens.callout.tracking)
          .fontColor(ColorTokens.secondary)
          .maxLines(2)
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
      Pressable({
        visualHeight: LayoutTokens.segmentedHeight,
        touchTargetHeight: LayoutTokens.minTouchTarget,
        action: (): void => { this.openGenrePicker(); },
      }) {
        Row({ space: SpaceTokens.xs }) {
          Text(this.meta().label)
            .fontSize(TypeTokens.callout.size).fontFamily(TypeTokens.fontFamily)
            .fontWeight(TypeTokens.headline.weight)
            .lineHeight(TypeTokens.callout.lineHeight)
            .fontColor(ColorTokens.primary)
          Image(resolveActionIcon('chevronDown'))
            .width(IconTokens.compact)
            .height(IconTokens.compact)
            .fillColor(ColorTokens.icon)
        }
        .height(LayoutTokens.segmentedHeight)
        .padding({ left: SpaceTokens.md, right: SpaceTokens.sm })
        .alignItems(VerticalAlign.Center)
        // 应用整体浮层风格（暖纸色系）：barSurface 暖米玻璃底 + backdropBlur + barBorder 暖描边 + lg 圆角
        .backdropBlur(SEGMENT_GLASS_BLUR)
        .backgroundColor(SEGMENT_GLASS_BG)
        .border({ width: 1, color: SEGMENT_GLASS_BORDER, style: BorderStyle.Solid })
        .borderRadius(RadiusTokens.lg)
      }
      Pressable({
        visualHeight: LayoutTokens.segmentedHeight,
        touchTargetHeight: LayoutTokens.minTouchTarget,
        action: (): void => { this.onOpenTags(); },
      }) {
        Row({ space: SpaceTokens.xs }) {
          Text('选择圈子')
            .fontSize(TypeTokens.callout.size).fontFamily(TypeTokens.fontFamily)
            .fontWeight(TypeTokens.headline.weight)
            .lineHeight(TypeTokens.callout.lineHeight)
            .fontColor(ColorTokens.primary)
          Image(resolveActionIcon('chevronDown'))
            .width(IconTokens.compact)
            .height(IconTokens.compact)
            .fillColor(ColorTokens.icon)
        }
        .height(LayoutTokens.segmentedHeight)
        .padding({ left: SpaceTokens.md, right: SpaceTokens.sm })
        .alignItems(VerticalAlign.Center)
        // 与体裁按钮同款应用浮层风格（暖纸色系）：barSurface 暖米玻璃底 + backdropBlur + barBorder 暖描边
        .backdropBlur(SEGMENT_GLASS_BLUR)
        .backgroundColor(SEGMENT_GLASS_BG)
        .border({ width: 1, color: SEGMENT_GLASS_BORDER, style: BorderStyle.Solid })
        .borderRadius(RadiusTokens.lg)
      }
    }
    .width('100%')
    .alignItems(VerticalAlign.Center)
  }
}
