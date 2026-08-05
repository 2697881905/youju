import { Genre } from '../models/types';
import { PublishGenreItem, PUBLISH_GENRES, publishGenreMeta } from '../utils/publishGenres';
import { IconTile } from '../design/components/IconTile';
import { Pressable } from '../design/motion/Pressable';
import { resolveActionIcon } from '../utils/actionIcons';
import { ColorTokens } from '../design/tokens/color';
import { IconTokens } from '../design/tokens/icon';
import { MotionCurves, MotionTokens } from '../design/tokens/motion';
import { RadiusTokens } from '../design/tokens/radius';
import { LayoutTokens, SpaceTokens } from '../design/tokens/space';
import { TypeTokens } from '../design/tokens/type';

@Component
export struct PublishGenreSection {
  @Prop genre: Genre = 'review';
  @Prop genreIndex: number = 0;
  @Link menuVisible: boolean;
  onSelectGenre: (index: number) => void = (_index: number): void => {};
  onOpenTags: () => void = (): void => {};

  private meta(): PublishGenreItem {
    return publishGenreMeta(this.genre);
  }

  @Builder
  private genreMenu(): void {
    Column({ space: SpaceTokens.none }) {
      ForEach(PUBLISH_GENRES, (item: PublishGenreItem, index: number) => {
        Pressable({
          fillWidth: true,
          visualHeight: LayoutTokens.minTouchTarget,
          action: (): void => { this.onSelectGenre(index); },
        }) {
          Row({ space: SpaceTokens.sm }) {
            Image(item.iconRes)
              .width(IconTokens.small)
              .height(IconTokens.small)
              .fillColor(index === this.genreIndex ? ColorTokens.brand : ColorTokens.primary)
            Text(item.label)
              .fontSize(TypeTokens.callout.size).fontFamily(TypeTokens.fontFamily)
              .fontWeight(index === this.genreIndex ? TypeTokens.headline.weight : TypeTokens.callout.weight)
              .lineHeight(TypeTokens.callout.lineHeight)
              .fontColor(index === this.genreIndex ? ColorTokens.brand : ColorTokens.primary)
          }
          .width('100%')
          .height(LayoutTokens.minTouchTarget)
          .padding({ left: SpaceTokens.md, right: SpaceTokens.md })
          .alignItems(VerticalAlign.Center)
          .backgroundColor(index === this.genreIndex ? ColorTokens.brandTint : Color.Transparent)
        }
      }, (item: PublishGenreItem) => item.key)
    }
    .width(128)
    .backgroundColor(ColorTokens.barSurface)
    .backdropBlur(LayoutTokens.glassBlur)
    .border({ width: LayoutTokens.glassBorderWidth, color: ColorTokens.barBorder, style: BorderStyle.Solid })
    .borderRadius(RadiusTokens.lg)
    .shadow({ radius: 12, color: ColorTokens.barShadow, offsetY: 4 })
    .clip(true)
  }

  build() {
    Row({ space: SpaceTokens.sm }) {
      IconTile({ icon: this.meta().iconRes, tileSize: 58, iconSize: 32, showBackground: false })
      Column({ space: SpaceTokens.xs }) {
        Text('开始创作!')
          .fontSize(TypeTokens.headline.size).fontFamily(TypeTokens.fontFamily)
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
        action: (): void => { this.menuVisible = !this.menuVisible; },
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
            .fillColor(ColorTokens.secondary)
            .rotate({ angle: this.menuVisible ? 180 : 0 })
            .animation({ duration: MotionTokens.fast, curve: MotionCurves.standard })
        }
        .height(LayoutTokens.segmentedHeight)
        .padding({ left: SpaceTokens.md, right: SpaceTokens.sm })
        .alignItems(VerticalAlign.Center)
        .backgroundColor(ColorTokens.barSurface)
        .backdropBlur(LayoutTokens.glassBlur)
        .border({ width: LayoutTokens.glassBorderWidth, color: ColorTokens.barBorder, style: BorderStyle.Solid })
        .borderRadius(RadiusTokens.floatingBar)
        .shadow({ radius: 12, color: ColorTokens.barShadow, offsetY: 4 })
        .bindPopup(this.menuVisible, {
          builder: this.genreMenu,
          placement: Placement.BottomRight,
          popupColor: Color.Transparent,
          enableArrow: false,
          autoCancel: true,
          onStateChange: (event) => { this.menuVisible = event.isVisible; },
        })
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
            .fillColor(ColorTokens.secondary)
        }
        .height(LayoutTokens.segmentedHeight)
        .padding({ left: SpaceTokens.md, right: SpaceTokens.sm })
        .alignItems(VerticalAlign.Center)
        .backgroundColor(ColorTokens.barSurface)
        .backdropBlur(LayoutTokens.glassBlur)
        .border({ width: LayoutTokens.glassBorderWidth, color: ColorTokens.barBorder, style: BorderStyle.Solid })
        .borderRadius(RadiusTokens.floatingBar)
        .shadow({ radius: 12, color: ColorTokens.barShadow, offsetY: 4 })
      }
    }
    .width('100%')
    .alignItems(VerticalAlign.Center)
  }
}
