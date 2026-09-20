import { timeAgo } from '../utils/format';
import { Avatar } from '../design/components/Avatar';
import { ColorTokens } from '../design/tokens/color';
import { SpaceTokens } from '../design/tokens/space';
import { TypeTokens } from '../design/tokens/type';

// 阅读头部只负责文章元信息和作者入口；帖子请求、删除态判断仍由详情页处理。
//
// 智感握姿（PostDetailView 订阅 motion.holdingHandChanged → AppStorage.gripOnRight）：
// 右手握持时，仅把**作者头像**从作者行左端移动到行右端（拇指侧）；
// 标题/体裁/标签保持左对齐原位不动——不做整块镜像，避免文字方向被翻转。
// 左手/未握持/双手/设备不支持/系统开关关闭 → 头像维持默认左位。
@Component
export struct DetailPostHeader {
  @Prop title: string = '';
  @Prop genreLabel: string = '';
  @Prop genreIcon: Resource = $r('app.media.genre_share');
  @Prop tags: string[] = [];
  @Prop authorName: string = '';
  @Prop authorAvatar: string = '';
  @Prop createdAt: string = '';
  // true = 右手握持（头像移到作者行右端）；false = 左手/未知/不支持（头像在左，默认布局）
  @StorageProp('gripOnRight') gripOnRight: boolean = false;
  onOpenAuthor: () => void = (): void => {};

  build() {
    Column({ space: SpaceTokens.sm }) {
      Text(this.title)
        .fontSize(TypeTokens.title.size).fontFamily(TypeTokens.fontFamilySerif)
        .fontWeight(700)
        .lineHeight(TypeTokens.title.lineHeight)
        .fontColor(ColorTokens.primary)
        .width('100%')
      Row({ space: 4 }) {
        Image(this.genreIcon)
          .width(14)
          .height(14)
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

      // 作者区：位于标题与标签下方。右手握持时头像移到行右端（位置移动，非方向翻转）：
      // Blank 占位把头像推到行尾，名字/时间列保持左对齐原位，阅读方向不变。
      if (this.gripOnRight) {
        Row({ space: SpaceTokens.sm }) {
          this.authorMeta()
          Blank()
          Avatar({ avatar: this.authorAvatar, name: this.authorName, avatarSize: 32 })
        }
        .width('100%')
        .alignItems(VerticalAlign.Center)
        .onClick((): void => { this.onOpenAuthor(); })
      } else {
        Row({ space: SpaceTokens.sm }) {
          Avatar({ avatar: this.authorAvatar, name: this.authorName, avatarSize: 32 })
          this.authorMeta()
        }
        .width('100%')
        .alignItems(VerticalAlign.Center)
        .onClick((): void => { this.onOpenAuthor(); })
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  // 作者名字 + 时间列：两个分支共用，始终保持左对齐（文字阅读方向不随握姿变化）
  @Builder
  authorMeta(): void {
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
  }
}
