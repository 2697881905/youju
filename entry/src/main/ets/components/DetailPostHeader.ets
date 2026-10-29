import { timeAgo } from '../utils/format';
import { Avatar } from '../design/components/Avatar';
import { ColorTokens } from '../design/tokens/color';
import { SpaceTokens } from '../design/tokens/space';
import { TypeTokens } from '../design/tokens/type';
import { PostRatingPill } from './PostRatingPill';

// 阅读头部只负责文章元信息和作者入口；帖子请求、删除态判断仍由详情页处理。
//
// 智感握姿（PostDetailView 订阅 motion.holdingHandChanged → animateTo 写 AppStorage.gripOnRight）：
// 标题/体裁/标签/作者行（头像+名字作为整体）随握持手**整组居右或居左**；
// 行内顺序、文字方向均不变（不做镜像）。换边过渡由 PostDetailView 的 animateTo 驱动。
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
  // 社区评分（Title 附近胶囊，2026-10-29 替代作者主观推荐指数主视觉）
  @Prop postId: number = 0;
  @Prop ratingAvg: number | null = null;
  @Prop ratingCount: number = 0;
  @Prop myRating: number = 0;
  onRatingUpdated: (avg: number, count: number, my: number) => void = (): void => {};
  // 展开打分条前询问宿主：已登录 true / 未登录宿主拉登录并 false
  onExpandRequest: () => boolean = (): boolean => true;
  // true = 右手握持（整组居右）；false = 左手/未知/不支持（默认居左）
  @StorageProp('gripOnRight') gripOnRight: boolean = false;
  onOpenAuthor: () => void = (): void => {};

  build() {
    Column({ space: SpaceTokens.sm }) {
      Text(this.title)
        .fontSize(TypeTokens.title.size).fontFamily(TypeTokens.fontFamilySerif)
        .fontWeight(700)
        .lineHeight(TypeTokens.title.lineHeight)
        .fontColor(ColorTokens.primary)
        // 内容自适应宽度（≤父宽）：短标题随根对齐与标签/作者行一起连续滑动；
        // textAlign 是瞬变属性无法插值——长标题折行占满父宽时换边会跳变，属已知取舍。
        .constraintSize({ maxWidth: '100%' })
        .textAlign(this.gripOnRight ? TextAlign.End : TextAlign.Start)
        // 长按标题 → 系统文本选择，可选字复制/全选。官方文档：copyOption 设为
        // InApp/LocalDevice 时「长按文本，会弹出文本选择菜单，可选中文本并进行复制、全选操作」。
        // 选中底色用品牌暖色 token（selectedBackgroundColor，API 14+），贴合主题。
        .copyOption(CopyOptions.LocalDevice)
        .selectedBackgroundColor(ColorTokens.brandTint)
      // 体裁 chip + 社区评分胶囊同行（2026-10-29）：⚠️ Blank 必须在这一行的 Row 内部
      // 才是横向推开——放在根 Column 里 layoutWeight 是纵向权重，会把胶囊/标签/作者行
      // 全部推到页面底部（真机事故实证）。握持手镜像不翻转此行（评分固定右缘锚点）。
      Row() {
        Row({ space: 4 }) {
          Image(this.genreIcon)
            .width(14)
            .height(14)
          Text(this.genreLabel)
            .fontSize(12).fontFamily($r('app.string.font_family'))
            // brand 字压 brandTint 底深色只有 3.58:1（12px 不达 AA）：字回 primary 墨（深 11.68:1），
            // 体裁的蓝色身份交给 tint 底与前面的体裁图标。
            .fontColor(ColorTokens.primary)
        }
        .backgroundColor(ColorTokens.brandTint)
        .borderRadius(4)
        .padding({ left: 8, right: 8, top: 3, bottom: 3 })

        Blank().layoutWeight(1)

        // 社区评分胶囊：Title 正下方第一行右缘（用户拍板「放 Title 附近、不用大卡片」）
        PostRatingPill({
          postId: this.postId,
          ratingAvg: this.ratingAvg,
          ratingCount: this.ratingCount,
          myRating: this.myRating,
          onUpdated: (avg: number, count: number, my: number): void => {
            this.onRatingUpdated(avg, count, my);
          },
          onExpandRequest: (): boolean => { return this.onExpandRequest(); },
        })
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)
      if (this.tags.length > 0) {
        Row({ space: 8 }) {
          ForEach(this.tags, (tag: string) => {
            Text(tag.startsWith('#') ? tag : ('#' + tag))
              .fontSize(13).fontFamily($r('app.string.font_family'))
              .fontColor(ColorTokens.brand)
          }, (tag: string) => tag)
        }
      }

      // 作者区：位于标题与标签下方。头像与名字/时间作为**一个整体**随握持手整组居右/居左。
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
      .justifyContent(this.gripOnRight ? FlexAlign.End : FlexAlign.Start)
      .onClick((): void => { this.onOpenAuthor(); })
    }
    .width('100%')
    .alignItems(this.gripOnRight ? HorizontalAlign.End : HorizontalAlign.Start)
  }
}
