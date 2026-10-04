// 管理 / 搜索类列表共用的「首页同款」卡片双列列表。
// 单一出处：搜索结果页、废纸篓、草稿箱三处共用，避免各写一份双列布局导致观感漂移。
//
// 与 HomeTab.feedScroll 同构：Scroll + 显式双列（偶数项左列 / 奇数项右列），
// 列内间距 SpaceTokens.xs、两列间距 SpaceTokens.xs、外层 Column 间距 SpaceTokens.sm。
// 为什么用 Scroll 而不是 Grid/List：与首页同口径 —— 懒加载容器的滚动终点会被钳制在
// 底部非安全区之上，露出窗口底色横带截断末卡（首页实测结论，这里沿用）。
//
// 卡片 = PostCard(compact) + 可选状态角标 + 可选删除按钮；
// 入场过渡走 feedItemTransition（与首页同一函数，含 idx 错峰延迟）。
import { Post } from '../models/types';
import { PostCard } from './PostCard';
import { Pressable } from '../design/motion/Pressable';
import { ColorTokens } from '../design/tokens/color';
import { IconTokens } from '../design/tokens/icon';
import { RadiusTokens } from '../design/tokens/radius';
import { LayoutTokens, SpaceTokens } from '../design/tokens/space';
import { TypeTokens } from '../design/tokens/type';
import { feedItemTransition } from '../utils/feedMotion';

// 列内单元：把「稳定 key」与「列内错峰下标」在分列时一次算好，
// 避免在 ForEach 里再按过滤后下标反查原数组（原数组下标 ≠ 列内下标）。
class FeedCell {
  key: string = '';
  idx: number = 0;
  // 原数组下标：用于回查与 posts 同序的旁路字段（如 textPosterStyles）
  srcIdx: number = 0;
  post: Post = {};
}

@Component
export struct ManagedPostFeed {
  @Prop posts: Post[] = [];
  // 稳定 key（与 posts 同序）。草稿的 Post 本身没有 id，必须由调用方提供；
  // 为空数组时回退 post.id。
  @Prop itemKeys: string[] = [];
  // 状态角标文案（'' = 不显示）：废纸篓「已删除」/ 草稿箱「草稿」
  @Prop badgeText: string = '';
  // 文字海报样式 key（与 posts 同序，'' = 无）：纯文本草稿用本地渲染海报作封面
  @Prop textPosterStyles: string[] = [];
  // 列表底部预留高度（页面自行决定）
  @Prop bottomPadding: number = SpaceTokens.x3l;
  // 是否已到底（显示「没有更多了」尾注）
  @Prop finished: boolean = false;
  // 卡片是否带删除按钮（草稿箱；废纸篓与搜索结果页为 false）
  @Prop deletable: boolean = false;
  // 点击卡片：回传 Post 与该单元的稳定 key（草稿场景 Post 无 id，需靠 key 反查业务对象）
  onOpen: (post: Post, key: string) => void = (): void => {};
  // 删除回调：回传该单元的稳定 key（= itemKeys 对应值）
  onDelete: (key: string) => void = (): void => {};
  onReachEnd?: () => void = undefined;

  // 分列：parity 0 = 左列（偶数项），1 = 右列（奇数项）。列内下标用于错峰延迟。
  private columns(parity: number): FeedCell[] {
    const out: FeedCell[] = [];
    let colIdx: number = 0;
    for (let i = 0; i < this.posts.length; i++) {
      if (i % 2 === parity) {
        const cell: FeedCell = new FeedCell();
        cell.post = this.posts[i];
        cell.idx = colIdx;
        cell.srcIdx = i;
        cell.key = (i < this.itemKeys.length && this.itemKeys[i].length > 0)
          ? this.itemKeys[i] : String(this.posts[i].id ?? i);
        out.push(cell);
        colIdx++;
      }
    }
    return out;
  }

  @Builder
  badge(): void {
    Text(this.badgeText)
      .fontSize(TypeTokens.overline.size).fontFamily(TypeTokens.fontFamily)
      .fontWeight(TypeTokens.headline.weight)
      .fontColor(ColorTokens.primary)
      .padding({
        left: SpaceTokens.sm, right: SpaceTokens.sm,
        top: SpaceTokens.inlineTight, bottom: SpaceTokens.inlineTight,
      })
      .backgroundColor(Color.Transparent)
      .border({ width: LayoutTokens.glassBorderWidth, color: ColorTokens.barBorder, style: BorderStyle.Solid })
      .borderRadius(RadiusTokens.lg)
      .position({ top: SpaceTokens.sm, left: SpaceTokens.sm })
  }

  // 删除按钮：叠在卡片**右上角**（与左上「草稿/已删除」角标成对），不占用卡片信息区 ——
  // 信息区必须与首页卡片完全一致（标题 + 互动/作者），不能塞操作行。
  @Builder
  deleteButton(cell: FeedCell): void {
    Stack({ alignContent: Alignment.Center }) {
      Pressable({
        fillWidth: true,
        visualHeight: IconTokens.small,
        touchTargetHeight: LayoutTokens.minTouchTarget,
        action: (): void => { this.onDelete(cell.key); },
      }) {
        Row() {
          Image($r('app.media.set_trash'))
            .width(IconTokens.compact)
            .height(IconTokens.compact)
            .fillColor(ColorTokens.icon)
        }
        .width(28)
        .height(IconTokens.small)
        .justifyContent(FlexAlign.Center)
        .backgroundColor(Color.Transparent)
        .border({ width: LayoutTokens.glassBorderWidth, color: ColorTokens.barBorder, style: BorderStyle.Solid })
        .borderRadius(RadiusTokens.lg)
      }
    }
    .width(LayoutTokens.minTouchTarget)
    .height(IconTokens.small)
    .position({ top: SpaceTokens.sm, right: SpaceTokens.sm })
  }

  private posterStyleOf(cell: FeedCell): string {
    return cell.srcIdx < this.textPosterStyles.length ? this.textPosterStyles[cell.srcIdx] : '';
  }

  @Builder
  cellView(cell: FeedCell): void {
    Stack() {
      // 卡片参数与首页信息流对齐：showStats / showAuthor 取默认（开），
      // 仅关闭点赞写操作（草稿无 id；废纸篓里的帖子已不可互动）。
      PostCard({
        post: cell.post,
        compact: true,
        allowLike: false,
        textPosterStyle: this.posterStyleOf(cell),
        onOpen: (): void => { this.onOpen(cell.post, cell.key); },
      });
      if (this.badgeText.length > 0) {
        this.badge()
      }
      if (this.deletable) {
        this.deleteButton(cell)
      }
    }
    .width('100%')
    .transition(feedItemTransition(cell.idx))
  }

  build() {
    Scroll() {
      Column({ space: SpaceTokens.sm }) {
        Row({ space: SpaceTokens.xs }) {
          Column({ space: SpaceTokens.xs }) {
            ForEach(this.columns(0), (cell: FeedCell) => {
              this.cellView(cell)
            }, (cell: FeedCell) => 'l-' + cell.key)
          }
          .layoutWeight(1)
          Column({ space: SpaceTokens.xs }) {
            ForEach(this.columns(1), (cell: FeedCell) => {
              this.cellView(cell)
            }, (cell: FeedCell) => 'r-' + cell.key)
          }
          .layoutWeight(1)
        }
        .width('100%')
        .alignItems(VerticalAlign.Top)

        if (this.finished) {
          // 与首页信息流尾注同款
          Text('没有更多了')
            .fontSize(TypeTokens.caption.size).fontFamily(TypeTokens.fontFamily)
            .fontWeight(TypeTokens.caption.weight)
            .lineHeight(TypeTokens.caption.lineHeight)
            .letterSpacing(TypeTokens.caption.tracking)
            .fontColor(ColorTokens.tertiary)
            .width('100%')
            .textAlign(TextAlign.Center)
            .padding(SpaceTokens.base)
        }

        // 底部预留：滚动终点与页面底边之间的呼吸 / 贴底栏避让
        Blank().width('100%').height(this.bottomPadding)
      }
      .width('100%')
      .constraintSize({ minHeight: '100%' })
      // 左右留白与首页信息流同值（SpaceTokens.sm）
      .padding({
        left: SpaceTokens.sm, right: SpaceTokens.sm,
        top: 5, bottom: SpaceTokens.md,
      })
    }
    .width('100%')
    // 用 height('100%') 而非 layoutWeight：既适配 Column 父级（废纸篓/草稿箱），
    // 也适配 Refresh 父级（搜索结果页的 Refresh 不参与 flex 权重分配）
    .height('100%')
    .scrollBar(BarState.Off)
    // 与首页同口径：滚到内容底部触发加载更多
    .onScrollEdge((edge: Edge): void => {
      if (edge === Edge.Bottom && this.onReachEnd !== undefined) {
        this.onReachEnd();
      }
    })
  }
}
