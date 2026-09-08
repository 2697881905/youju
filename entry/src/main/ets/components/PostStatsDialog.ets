// 帖子创作数据面板：展示浏览/顶/收藏/评论 + 曝光/点击/转化率（仅作者本人/管理员可见）
import { SpringPanel } from '../design/motion/SpringPanel';
import { resolveActionIcon } from '../utils/actionIcons';
import { ColorTokens } from '../design/tokens/color';
import { IconTokens } from '../design/tokens/icon';
import { RadiusTokens } from '../design/tokens/radius';
import { LayoutTokens, SpaceTokens } from '../design/tokens/space';
import { TypeTokens } from '../design/tokens/type';
import { Pressable } from '../design/motion/Pressable';
import { PostStats } from '../services/api';

interface StatsRow {
  label: string;
  value: string;
}

@CustomDialog
export struct PostStatsDialog {
  controller: CustomDialogController;
  @Prop stats: PostStats | null = null;
  loading: boolean = false;
  error: string = '';

  private rows(): StatsRow[] {
    const s = this.stats;
    if (s === null) {
      return [];
    }
    return [
      { label: '浏览', value: String(s.viewCount) },
      { label: '顶', value: String(s.upCount) },
      { label: '收藏', value: String(s.bookmarkCount) },
      { label: '评论', value: String(s.commentCount) },
      { label: '曝光', value: String(s.expose) },
      { label: '点击', value: String(s.click) },
      { label: '点击率', value: s.clickRate + '%' },
    ];
  }

  @Builder
  statCell(row: StatsRow) {
    Column({ space: SpaceTokens.xs }) {
      Text(row.value)
        .fontSize(TypeTokens.title.size).fontFamily(TypeTokens.fontFamily)
        .fontWeight(TypeTokens.title.weight)
        .fontColor(ColorTokens.primary)
      Text(row.label)
        .fontSize(TypeTokens.caption.size).fontFamily(TypeTokens.fontFamily)
        .fontColor(ColorTokens.secondary)
    }
    .layoutWeight(1)
    .alignItems(HorizontalAlign.Center)
    .padding({ top: SpaceTokens.sm, bottom: SpaceTokens.sm })
    .backgroundColor(ColorTokens.sunken)
    .borderRadius(RadiusTokens.md)
  }

  build() {
    SpringPanel({ panelWidth: 344, panelPadding: SpaceTokens.lg }) {
      Column({ space: SpaceTokens.base }) {
        Row({ space: SpaceTokens.sm }) {
          Column({ space: 2 }) {
            Text('帖子数据')
              .fontSize(TypeTokens.headline.size).fontFamily(TypeTokens.fontFamilySerif)
              .fontWeight(TypeTokens.headline.weight)
              .lineHeight(TypeTokens.headline.lineHeight)
              .fontColor(ColorTokens.primary)
            Text('仅你自己可见')
              .fontSize(TypeTokens.caption.size).fontFamily(TypeTokens.fontFamily)
              .fontColor(ColorTokens.secondary)
          }
          .layoutWeight(1)
          .alignItems(HorizontalAlign.Start)
          Pressable({
            visualHeight: IconTokens.compact,
            touchTargetHeight: LayoutTokens.minTouchTarget,
            action: (): void => { this.controller.close(); },
          }) {
            Image(resolveActionIcon('close'))
              .width(IconTokens.compact)
              .height(IconTokens.compact)
          }
        }
        .width('100%')
        .alignItems(VerticalAlign.Center)

        if (this.loading && this.stats === null) {
          Row({ space: SpaceTokens.sm }) {
            LoadingProgress().width(20).height(20)
            Text('加载中…')
              .fontSize(TypeTokens.body.size).fontFamily(TypeTokens.fontFamily)
              .fontColor(ColorTokens.secondary)
          }
          .width('100%').justifyContent(FlexAlign.Center).padding({ top: 16, bottom: 16 })
        } else if (this.stats !== null) {
          // 3 列网格分两行展示
          Grid() {
            ForEach(this.rows(), (row: StatsRow) => {
              GridItem() {
                this.statCell(row)
              }
            }, (row: StatsRow) => row.label)
          }
          .columnsTemplate('1fr 1fr 1fr')
          .columnsGap(SpaceTokens.sm)
          .rowsGap(SpaceTokens.sm)
          .width('100%')
          .height(140)
          .scrollBar(BarState.Off)
        } else {
          Text(this.error !== '' ? ('加载失败：' + this.error) : '暂无数据')
            .fontSize(TypeTokens.body.size).fontFamily(TypeTokens.fontFamily)
            .fontColor(ColorTokens.secondary)
            .width('100%').textAlign(TextAlign.Center).padding({ top: 16, bottom: 16 })
        }
      }
      .width('100%')
    }
  }
}