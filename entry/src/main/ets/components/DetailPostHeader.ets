import { timeAgo } from '../utils/format';
import { Avatar } from '../design/components/Avatar';
import { ColorTokens } from '../design/tokens/color';
import { SpaceTokens } from '../design/tokens/space';
import { TypeTokens } from '../design/tokens/type';

// 阅读头部只负责文章元信息和作者入口；帖子请求、删除态判断仍由详情页处理。
//
// 智感握姿：PostDetailView 订阅 motion.holdingHandChanged 后把结果写入 AppStorage('gripOnRight')，
// 本组件据此镜像整个头部（标题/体裁/标签/作者行）：
// - 右手握持 → 内容贴右（拇指侧）；左手握持 → 贴左（默认布局）；离手/双手保持上一次侧别。
// - 设备不支持（canIUse=false / 801）或系统开关关闭时 gripOnRight 恒为 false，维持默认布局。
// 已知取舍：对齐与文案方向是布局属性，无法平滑插值，换边为瞬时切换；
//   如实机体验生硬，再引入分支 TransitionEffect.move 的侧边滑入方案（会与入场动画叠加，需一起调）。
@Component
export struct DetailPostHeader {
  @Prop title: string = '';
  @Prop genreLabel: string = '';
  @Prop genreIcon: Resource = $r('app.media.genre_share');
  @Prop tags: string[] = [];
  @Prop authorName: string = '';
  @Prop authorAvatar: string = '';
  @Prop createdAt: string = '';
  // true = 右手握持（内容贴右）；false = 左手/未知/不支持（默认贴左）
  @StorageProp('gripOnRight') gripOnRight: boolean = false;
  onOpenAuthor: () => void = (): void => {};

  build() {
    if (this.gripOnRight) {
      Column({ space: SpaceTokens.sm }) {
        this.headerBody(true)
      }
      .width('100%')
      .alignItems(HorizontalAlign.End)
    } else {
      Column({ space: SpaceTokens.sm }) {
        this.headerBody(false)
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
    }
  }

  // 头部内容。mirror=true：标题/体裁/标签右对齐，作者行头像换到右侧（文字列右对齐）。
  // 由 build() 的分支在握持手变化时重建，功能/状态/行为与镜像前完全一致（华为接入原则）。
  @Builder
  headerBody(mirror: boolean) {
    Text(this.title)
      .fontSize(TypeTokens.title.size).fontFamily(TypeTokens.fontFamilySerif)
      .fontWeight(700)
      .lineHeight(TypeTokens.title.lineHeight)
      .fontColor(ColorTokens.primary)
      .width('100%')
      .textAlign(mirror ? TextAlign.End : TextAlign.Start)
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

    // 作者区：位于标题与标签下方。镜像时头像与文字列互换，头像始终落在握持手侧。
    Row({ space: SpaceTokens.sm }) {
      if (mirror) {
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
        .alignItems(HorizontalAlign.End)
        Avatar({ avatar: this.authorAvatar, name: this.authorName, avatarSize: 32 })
      } else {
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
      }
    }
    .width('100%')
    .alignItems(VerticalAlign.Center)
    .onClick((): void => { this.onOpenAuthor(); })
  }
}
