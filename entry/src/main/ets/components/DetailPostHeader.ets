import { curves } from '@kit.ArkUI';
import { timeAgo } from '../utils/format';
import { Avatar } from '../design/components/Avatar';
import { ColorTokens } from '../design/tokens/color';
import { SpaceTokens } from '../design/tokens/space';
import { TypeTokens } from '../design/tokens/type';

// 阅读头部只负责文章元信息和作者入口；帖子请求、删除态判断仍由详情页处理。
//
// 智感握姿（PostDetailView 订阅 motion.holdingHandChanged → AppStorage.gripOnRight）：
// 标题/体裁/标签/作者行（头像+名字作为整体）随握持手**整组居右或居左**；
// 行内顺序、文字方向均不变（不做镜像）。
// 换边过渡：分支重建时挂 TransitionEffect.move 侧边滑入滑出（官方样例同款，
// interpolatingSpring(0,1,170,17)）；首次挂载用 IDENTITY，避免与一镜到底入场动画叠加。
// 左手/未握持/双手/设备不支持/系统开关关闭 → 默认居左。
@Component
export struct DetailPostHeader {
  @Prop title: string = '';
  @Prop genreLabel: string = '';
  @Prop genreIcon: Resource = $r('app.media.genre_share');
  @Prop tags: string[] = [];
  @Prop authorName: string = '';
  @Prop authorAvatar: string = '';
  @Prop createdAt: string = '';
  // true = 右手握持（整组居右）；false = 左手/未知/不支持（默认居左）
  @StorageProp('gripOnRight') gripOnRight: boolean = false;
  // 首次挂载不播过渡（IDENTITY），之后每次换边才播侧边滑入滑出
  @State private headerAppeared: boolean = false;
  onOpenAuthor: () => void = (): void => {};

  build() {
    if (this.gripOnRight) {
      Column({ space: SpaceTokens.sm }) {
        this.headerBody(true)
      }
      .width('100%')
      .alignItems(HorizontalAlign.End)
      .onAppear(() => { this.headerAppeared = true; })
      .transition(this.headerAppeared
        ? TransitionEffect.move(TransitionEdge.END)
          .animation({ curve: curves.interpolatingSpring(0, 1, 170, 17) })
        : TransitionEffect.IDENTITY)
    } else {
      Column({ space: SpaceTokens.sm }) {
        this.headerBody(false)
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
      .onAppear(() => { this.headerAppeared = true; })
      .transition(this.headerAppeared
        ? TransitionEffect.move(TransitionEdge.START)
          .animation({ curve: curves.interpolatingSpring(0, 1, 170, 17) })
        : TransitionEffect.IDENTITY)
    }
  }

  // 头部内容。mirror=true：标题/体裁/标签右对齐，作者行整组贴右（行内顺序不变）。
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

    // 作者区：头像与名字/时间作为**一个整体**随握持手整组居右/居左。
    // 行内顺序（头像在前）与文字方向不变——移动的是整组位置，不是镜像。
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
    }
    .width('100%')
    .alignItems(VerticalAlign.Center)
    .justifyContent(mirror ? FlexAlign.End : FlexAlign.Start)
    .onClick((): void => { this.onOpenAuthor(); })
  }
}
