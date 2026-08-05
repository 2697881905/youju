import { timeAgo } from '../utils/format';
import { Avatar } from '../design/components/Avatar';
import { ColorTokens } from '../design/tokens/color';
import { RadiusTokens } from '../design/tokens/radius';
import { LayoutTokens, SpaceTokens } from '../design/tokens/space';
import { TypeTokens } from '../design/tokens/type';

// 阅读头部只负责文章元信息和作者入口；帖子请求、删除态判断仍由详情页处理。
@Component
export struct DetailPostHeader {
  @Prop title: string = '';
  @Prop genreLabel: string = '';
  @Prop genreIcon: Resource = $r('app.media.genre_share');
  @Prop tags: string[] = [];
  @Prop authorName: string = '';
  @Prop authorAvatar: string = '';
  @Prop createdAt: string = '';
  onOpenAuthor: () => void = (): void => {};

  build() {
    Row({ space: SpaceTokens.sm }) {
      Column({ space: SpaceTokens.sm }) {
        Text(this.title)
          .fontSize(TypeTokens.title.size).fontFamily(TypeTokens.fontFamily)
          .fontWeight(700)
          .lineHeight(TypeTokens.title.lineHeight)
          .fontColor(ColorTokens.primary)
        Row({ space: 4 }) {
          Image(this.genreIcon)
            .width(14)
            .height(14)
            .fillColor($r('app.color.brand_primary'))
          Text(this.genreLabel)
            .fontSize(12).fontFamily($r('app.string.font_family'))
            .fontColor($r('app.color.brand_primary'))
        }
        .backgroundColor($r('app.color.surface_selected'))
        .borderRadius(4)
        .padding({ left: 8, right: 8, top: 3, bottom: 3 })
        if (this.tags.length > 0) {
          Row({ space: 8 }) {
            ForEach(this.tags, (tag: string) => {
              Text(tag.startsWith('#') ? tag : ('#' + tag))
                .fontSize(13).fontFamily($r('app.string.font_family'))
                .fontColor($r('app.color.brand_primary'))
            }, (tag: string) => tag)
          }
        }
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)

      Row({ space: SpaceTokens.sm }) {
        Avatar({ avatar: this.authorAvatar, name: this.authorName, avatarSize: 32 })
        Column({ space: 1 }) {
          Text(this.authorName)
            .fontSize(TypeTokens.caption.size).fontFamily(TypeTokens.fontFamily)
            .fontWeight(TypeTokens.headline.weight)
            .fontColor(ColorTokens.primary)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
          Text(timeAgo(this.createdAt))
            .fontSize(TypeTokens.overline.size).fontFamily(TypeTokens.fontFamily)
            .fontColor(ColorTokens.tertiary)
            .maxLines(1)
        }
        .alignItems(HorizontalAlign.Start)
        .constraintSize({ maxWidth: 72 })
      }
      .height(52)
      .padding({ left: SpaceTokens.sm, right: SpaceTokens.md })
      .backgroundColor(ColorTokens.barSurface)
      .backdropBlur(LayoutTokens.glassBlur)
      .border({ width: LayoutTokens.glassBorderWidth, color: ColorTokens.barBorder, style: BorderStyle.Solid })
      .borderRadius(RadiusTokens.lg)
      .onClick((): void => { this.onOpenAuthor(); })
    }
    .width('100%')
    .alignItems(VerticalAlign.Top)
  }
}
