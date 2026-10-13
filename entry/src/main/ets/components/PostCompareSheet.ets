import { ComparePostsParams, comparePosts, PostCompareResult, PostMetricRow } from '../services/api';
import { Genre } from '../models/types';
import { ColorTokens } from '../design/tokens/color';
import { RadiusTokens } from '../design/tokens/radius';
import { LayoutTokens, SpaceTokens } from '../design/tokens/space';
import { TypeTokens } from '../design/tokens/type';
import { SegmentedControl, SegmentedItem } from '../design/components/SegmentedControl';
import { Pressable } from '../design/motion/Pressable';
import { structuredMetricKindLabel } from '../utils/structuredDocument';
import { PUBLISH_GENRES, publishGenreMeta } from '../utils/publishGenres';
import { openPostDetail } from '../utils/nav';
import { formatCount } from '../utils/format';

// 跨帖对比表：把同体裁帖子的「主数字」并排，让结构化帖子从「一篇一篇读」变成「横向比着看」。
// 数据来自后端 metricValue 派生列（GET /v1/posts/compare），排序口径交给读者自己翻面——
// 评分越高越好、到手价与耗时越低越好，服务端不替体裁预设「谁更优」。

const ORDER_SEGMENTS: SegmentedItem[] = [
  { key: 'desc', label: '从高到低' },
  { key: 'asc', label: '从低到高' },
];

const COMPARE_LIMIT: number = 20;

@Component
export struct PostCompareSheet {
  @Prop genre: string = 'review';
  // 本帖在表里高亮标出：读者是从这篇点进来的，得先认出自己看的是哪一行
  @Prop highlightPostId: number = 0;
  @Prop metricLabel: string = '';
  onClose: () => void = (): void => {};
  @State private rows: PostMetricRow[] = [];
  @State private total: number = 0;
  @State private orderIndex: number = 0;
  @State private loading: boolean = true;
  @State private loadError: string = '';
  // 请求序号不参与渲染，只用于丢弃过期回包（连点排序时旧请求可能后到）
  private requestSeq: number = 0;

  aboutToAppear(): void {
    this.load();
  }

  // 宿主 DetailPostContent 的 genre 是宽松 string（历史帖可能带脏值），而查询参数要 Genre：
  // 在边界处认一次表，认不出来就不发请求，而不是硬塞一个体裁去查错数据。
  private genreKey(): Genre | null {
    for (const item of PUBLISH_GENRES) {
      if (item.key === this.genre) {
        return item.key;
      }
    }
    return null;
  }

  private genreLabel(): string {
    const key: Genre | null = this.genreKey();
    return key === null ? '同体裁' : publishGenreMeta(key).label;
  }

  private load(): void {
    const key: Genre | null = this.genreKey();
    if (key === null) {
      this.loading = false;
      this.loadError = '这篇帖子的体裁暂不支持对比';
      return;
    }
    this.requestSeq += 1;
    const seq: number = this.requestSeq;
    this.loading = true;
    this.loadError = '';
    const params: ComparePostsParams = {
      genre: key,
      order: this.orderIndex === 1 ? 'asc' : 'desc',
      limit: COMPARE_LIMIT,
    };
    comparePosts(params).then((res: PostCompareResult): void => {
      if (this.requestSeq !== seq) {
        return;
      }
      this.rows = res.rows ?? [];
      this.total = res.total ?? 0;
      this.loading = false;
    }).catch((e: Error): void => {
      if (this.requestSeq !== seq) {
        return;
      }
      this.rows = [];
      this.total = 0;
      this.loadError = e.message;
      this.loading = false;
    });
  }

  // 条形长度只表达量级相对最大值的比例，不表达好坏——好坏由排序方向自己判。
  private barRatio(row: PostMetricRow): number {
    let max: number = 0;
    for (const item of this.rows) {
      const value: number = Math.abs(item.metricValue ?? 0);
      if (value > max) {
        max = value;
      }
    }
    if (max <= 0) {
      return 0;
    }
    const ratio: number = Math.abs(row.metricValue ?? 0) / max * 100;
    return ratio < 2 ? 2 : Math.round(ratio);
  }

  private openRow(row: PostMetricRow): void {
    this.onClose();
    openPostDetail(String(row.id));
  }

  @Builder
  private header(): void {
    Column({ space: SpaceTokens.xs }) {
      Text(this.genreLabel() + ' · 数字对比')
        .fontSize(TypeTokens.headline.size)
        .fontFamily(TypeTokens.fontFamily)
        .fontWeight(TypeTokens.headline.weight)
        .fontColor(ColorTokens.primary)
        .width('100%')
      Text(this.metricLabel.length > 0
        ? '在比的是「' + this.metricLabel + '」· 共 ' + String(this.total) + ' 篇可比'
        : '同体裁下有可比数字的帖子 · 共 ' + String(this.total) + ' 篇')
        .fontSize(TypeTokens.caption.size)
        .fontFamily(TypeTokens.fontFamily)
        .fontColor(ColorTokens.secondary)
        .width('100%')
    }
    // 表头与右侧排序分段栏抢宽度：这里必须让位（layoutWeight），否则 Blank 永远拿到 0
    .layoutWeight(1)
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  private metricCell(row: PostMetricRow): void {
    Column({ space: SpaceTokens.xs }) {
      Text(row.metricText ?? String(row.metricValue ?? 0))
        .fontSize(TypeTokens.title.size)
        .fontFamily(TypeTokens.fontFamily)
        .fontWeight(600)
          // 本篇行底是 brandTint：21px 数字若继续用 brand 字，深色只有 3.58:1；
        // 压成 brandPress（4.56:1 起）既保留「这是本篇」的蓝，又达 AA。
        .fontColor(row.id === this.highlightPostId ? ColorTokens.brandPress : ColorTokens.primary)
        .maxLines(1)
      Text(structuredMetricKindLabel(row.metricKind ?? undefined))
        .fontSize(TypeTokens.overline.size)
        .fontFamily(TypeTokens.fontFamily)
        .fontColor(ColorTokens.tertiary)
    }
    .alignItems(HorizontalAlign.End)
  }

  @Builder
  private rankCell(rank: number): void {
    Text(String(rank))
      .fontSize(TypeTokens.caption.size)
      .fontFamily(TypeTokens.fontFamily)
      .fontWeight(600)
      // 前 3 名序号球：tint 底保留名次高亮，字回 primary（brand 字压 tint 深色 3.58 不达 AA）
      .fontColor(rank <= 3 ? ColorTokens.primary : ColorTokens.tertiary)
      .width(22)
      .height(22)
      .textAlign(TextAlign.Center)
      .backgroundColor(rank <= 3 ? ColorTokens.brandTint : ColorTokens.elevated)
      .borderRadius(RadiusTokens.pill)
  }

  @Builder
  private rowItem(row: PostMetricRow, index: number): void {
    ListItem() {
      Row({ space: SpaceTokens.md }) {
        this.rankCell(index + 1)
        Column({ space: SpaceTokens.xs }) {
          Text(row.title)
            .fontSize(TypeTokens.callout.size)
            .fontFamily(TypeTokens.fontFamily)
            .fontColor(ColorTokens.primary)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .width('100%')
          Row({ space: SpaceTokens.xs }) {
            Text(row.user?.nickname ?? '')
              .fontSize(TypeTokens.caption.size)
              .fontFamily(TypeTokens.fontFamily)
              .fontColor(ColorTokens.tertiary)
              .maxLines(1)
            if (row.id === this.highlightPostId) {
              Text('本篇')
                .fontSize(TypeTokens.overline.size)
                .fontFamily(TypeTokens.fontFamily)
                .fontWeight(600)
                .fontColor(ColorTokens.primary)
                .backgroundColor(ColorTokens.brandTint)
                .borderRadius(RadiusTokens.pill)
                .padding({ left: SpaceTokens.sm, right: SpaceTokens.sm, top: 2, bottom: 2 })
            }
            Text(formatCount(row.upCount) + ' 赞')
              .fontSize(TypeTokens.caption.size)
              .fontFamily(TypeTokens.fontFamily)
              .fontColor(ColorTokens.tertiary)
          }
          .width('100%')
          .alignItems(VerticalAlign.Center)

          Progress({ value: this.barRatio(row), total: 100, type: ProgressType.Linear })
            .color(row.id === this.highlightPostId ? ColorTokens.brand : ColorTokens.secondary)
            .style({ strokeWidth: 4, strokeRadius: 2, enableSmoothEffect: true })
            .width('100%')
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)

        this.metricCell(row)
      }
      .width('100%')
      .padding({ left: SpaceTokens.base, right: SpaceTokens.base, top: SpaceTokens.md, bottom: SpaceTokens.md })
      .alignItems(VerticalAlign.Center)
      .backgroundColor(row.id === this.highlightPostId ? ColorTokens.brandTint : ColorTokens.canvas)
      .borderRadius(RadiusTokens.md)
      .border({ width: row.id === this.highlightPostId ? LayoutTokens.hairlineWidth : 0, color: ColorTokens.brand, style: BorderStyle.Solid })
      .onClick((): void => { this.openRow(row); })
    }
  }

  @Builder
  private statusText(message: string): void {
    Text(message)
      .fontSize(TypeTokens.callout.size)
      .fontFamily(TypeTokens.fontFamily)
      .fontColor(ColorTokens.secondary)
      .width('100%')
      .textAlign(TextAlign.Center)
      .padding({ top: SpaceTokens.x2l, bottom: SpaceTokens.x2l })
  }

  build() {
    Column({ space: SpaceTokens.base }) {
      Row() {
        this.header()
        Blank()
        SegmentedControl({
          items: ORDER_SEGMENTS,
          selectedIndex: $orderIndex,
          itemWidth: 78,
          fillWidth: false,
          glowEnabled: false,
          onSelect: (_index: number): void => { this.load(); },
        })
        // bindSheet 的 showClose 是关掉的（与证据清单弹层同款），面板内必须自己给一个出口
        Pressable({
          visualHeight: 32,
          touchTargetHeight: LayoutTokens.minTouchTarget,
          action: (): void => { this.onClose(); },
        }) {
          Text('关闭')
            .fontSize(TypeTokens.caption.size)
            .fontFamily(TypeTokens.fontFamily)
            .fontColor(ColorTokens.brand)
            .padding({ left: SpaceTokens.sm, right: SpaceTokens.sm, top: 6, bottom: 6 })
        }
      }
      .width('100%')
      .alignItems(VerticalAlign.Top)

      if (this.loading) {
        this.statusText('正在汇总同体裁的数字')
      } else if (this.loadError.length > 0) {
        this.statusText(this.loadError)
      } else if (this.rows.length === 0) {
        this.statusText('还没有同体裁的帖子带可比数字')
      } else {
        List({ space: SpaceTokens.sm }) {
          ForEach(this.rows, (row: PostMetricRow, index: number) => {
            this.rowItem(row, index)
          }, (row: PostMetricRow, index: number) => String(row.id) + '#' + String(index) + ':'
            + String(row.metricValue) + (row.id === this.highlightPostId ? '_me' : ''))
        }
        .width('100%')
        .layoutWeight(1)
        .scrollBar(BarState.Off)
        .edgeEffect(EdgeEffect.Spring)
      }
    }
    .width('100%')
    .height('100%')
    .padding({ left: SpaceTokens.base, right: SpaceTokens.base, top: SpaceTokens.sm })
  }
}
