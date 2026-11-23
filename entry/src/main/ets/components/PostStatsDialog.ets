// 帖子创作数据面板（作者侧）：bindSheet 半模态内容组件。
//
// ⚠️ 实现形态：**bindSheet 半模态内容组件**（PostDetailView 根节点挂 SheetOptions）——
// 遮罩、右上角系统关闭钮、下滑拖拽关闭、点遮罩关闭、进出场全部由系统半模态承担，
// 本组件只画数据区。sheet builder 与宿主同渲染上下文，@Prop 随父组件刷新，
// 无 CustomDialog 的 @Prop 断联坑（最早 CustomDialogController builder 传 @Link 会闪退）。
//
// 内部布局（2026-11-23 重设计，用户拍板「原生统计网格」方向）：
//   标题区（serif 帖子数据 / 仅你自己可见；右上角系统关闭钮）
//   统计网格：核心大格「累计浏览」+ 2×2 小格（顶/收藏/评论/社区评分）——
//     大数字 + 小标签左对齐平铺、发丝线十字分隔，系统「存储/运动健康」式数据呈现；
//     serif 大 Hero、图标三列与 DataPanel 比例条两版实测观感差，全部弃用。
//   流量转化：转化率右侧大数字 + 官方 DataPanel Line 比例条（brand=实际转化 / sunken=余量）
//     + 曝光·点击口径行。曝光/点击同为 PostEvent 埋点、口径一致（均仅登录用户）；浏览
//     viewCount 含游客且 1h 去重，不进此漏斗以免比例误导（2026-11-19 定）。
//
// 面板材质：让位 SheetOptions.systemMaterial（沉浸玻璃·面板档，API ≥ 26 生效）；低版本
// 回退 canvas 实色。内容侧不自绘底/边框/圆角。
import { isSystemMaterialActive } from '../utils/immersiveMaterial';
import { ColorTokens } from '../design/tokens/color';
import { LayoutTokens, SpaceTokens } from '../design/tokens/space';
import { TypeTokens } from '../design/tokens/type';
import { SoftChip } from '../design/components/SoftChip';
import { formatCount } from '../utils/format';
import { PostStats } from '../services/api';

const HERO_NUMBER_SIZE: number = 28; // 大格数字（累计浏览）
const CELL_NUMBER_SIZE: number = 20; // 小格数字（顶/收藏/评论/评分）

@Component
export struct PostStatsDialog {
  @Prop stats: PostStats | null = null;
  @Prop loading: boolean = false;
  @Prop error: string = '';
  // 社区评分（Post.ratingAvg/ratingCount 随帖传入；stats 接口不含评分）
  @Prop ratingAvg: number | null = null;
  @Prop ratingCount: number = 0;
  // 加载失败重试：父组件重新拉取，不重开面板
  onRetry: () => void = (): void => {};

  private hasRating(): boolean {
    return this.ratingAvg !== null && this.ratingAvg !== undefined;
  }

  // 无人打分显示「—」占位（格子不空缺，网格保持齐整）
  private ratingCellText(): string {
    return this.hasRating() ? '★' + (this.ratingAvg as number).toFixed(1) : '—';
  }

  private ratingCellLabel(): string {
    return this.hasRating() ? '社区评分·' + String(this.ratingCount) + '人' : '社区评分';
  }

  private exposureLine(): string {
    const s: PostStats | null = this.stats;
    return '曝光 ' + formatCount(s?.expose) + ' · 点击 ' + formatCount(s?.click);
  }

  // 转化率钳到 0-100（异常值不炸比例条）
  private clickRateClamped(): number {
    return Math.min(Math.max(this.stats?.clickRate ?? 0, 0), 100);
  }

  @Builder
  hairline() {
    Row()
      .width('100%')
      .height(LayoutTokens.hairlineWidth)
      .backgroundColor(ColorTokens.separator)
  }

  @Builder
  cellDivider() {
    Divider()
      .vertical(true)
      .strokeWidth(LayoutTokens.hairlineWidth)
      .color(ColorTokens.separator)
  }

  // 统计小格：大数字 + 小标签，左对齐（与系统统计页同范式）
  @Builder
  statCell(value: string, label: string) {
    Column({ space: 2 }) {
      Text(value)
        .fontSize(CELL_NUMBER_SIZE).fontFamily(TypeTokens.fontFamily)
        .fontWeight(TypeTokens.headline.weight)
        .lineHeight(24)
        .fontColor(ColorTokens.primary)
      Text(label)
        .fontSize(TypeTokens.caption.size).fontFamily(TypeTokens.fontFamily)
        .fontColor(ColorTokens.secondary)
    }
    .layoutWeight(1)
    .alignItems(HorizontalAlign.Start)
    .padding({ top: SpaceTokens.md, bottom: SpaceTokens.md, right: SpaceTokens.base })
  }

  build() {
    // 半模态内容区：材质生效时透明（表面由 SheetOptions.systemMaterial 承载），
    // 低版本回退 canvas 实色；遮罩/关闭钮/拖拽/进出场不再自绘（系统半模态全包）。
    Column({ space: SpaceTokens.base }) {
      // 标题区：右上角留空给系统 showClose 钮（标题左置，不与之重叠）
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
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)

      if (this.loading && this.stats === null) {
        Column({ space: SpaceTokens.sm }) {
          LoadingProgress().width(22).height(22).color(ColorTokens.brand)
          Text('正在汇总这篇帖子的数据…')
            .fontSize(TypeTokens.callout.size).fontFamily(TypeTokens.fontFamily)
            .fontColor(ColorTokens.secondary)
        }
        .width('100%')
        .alignItems(HorizontalAlign.Center)
        .padding({ top: SpaceTokens.lg, bottom: SpaceTokens.lg })
      } else if (this.stats !== null) {
        // 统计网格：核心大格（浏览）+ 2×2 小格，发丝线十字分隔
        Column({ space: SpaceTokens.none }) {
          Column({ space: 2 }) {
            Text('累计浏览')
              .fontSize(TypeTokens.caption.size).fontFamily(TypeTokens.fontFamily)
              .fontColor(ColorTokens.secondary)
            Text(formatCount(this.stats.viewCount))
              .fontSize(HERO_NUMBER_SIZE).fontFamily(TypeTokens.fontFamily)
              .fontWeight(TypeTokens.headline.weight)
              .lineHeight(34)
              .fontColor(ColorTokens.primary)
          }
          .width('100%')
          .alignItems(HorizontalAlign.Start)
          .padding({ top: SpaceTokens.xs, bottom: SpaceTokens.md })

          this.hairline()

          Row() {
            this.statCell(formatCount(this.stats.upCount), '顶')
            this.cellDivider()
            this.statCell(formatCount(this.stats.bookmarkCount), '收藏')
          }
          .width('100%')
          .alignItems(VerticalAlign.Center)

          this.hairline()

          Row() {
            this.statCell(formatCount(this.stats.commentCount), '评论')
            this.cellDivider()
            this.statCell(this.ratingCellText(), this.ratingCellLabel())
          }
          .width('100%')
          .alignItems(VerticalAlign.Center)
        }
        .width('100%')

        // 流量转化可视化（2026-11-23 用户拍板「加进度条直观一点」）：
        // 标签行 + 右侧转化率数字 → DataPanel 比例条 → 曝光·点击口径行。
        Row() {
          Text('流量转化')
            .fontSize(TypeTokens.overline.size).fontFamily(TypeTokens.fontFamily)
            .fontWeight(TypeTokens.overline.weight)
            .fontColor(ColorTokens.secondary)
          Blank()
          Text(String(this.clickRateClamped()) + '%')
            .fontSize(TypeTokens.headline.size).fontFamily(TypeTokens.fontFamily)
            .fontWeight(TypeTokens.headline.weight)
            .fontColor(ColorTokens.primary)
            .fontFeature(TypeTokens.tabularFeature)
        }
        .width('100%')
        .alignItems(VerticalAlign.Center)

        DataPanel({
          values: [this.clickRateClamped(), Math.max(100 - this.clickRateClamped(), 0)],
          max: 100,
          type: DataPanelType.Line,
        })
          .width('100%')
          .height(6)
          .valueColors([ColorTokens.brand, ColorTokens.sunken])
          .margin({ top: SpaceTokens.sm })

        Text(this.exposureLine())
          .fontSize(TypeTokens.caption.size).fontFamily(TypeTokens.fontFamily)
          .fontColor(ColorTokens.tertiary)
          .margin({ top: SpaceTokens.sm })
          .width('100%')
      } else {
        // 错误 / 空态
        Column({ space: SpaceTokens.base }) {
          Text(this.error !== '' ? ('加载失败：' + this.error) : '暂无数据')
            .fontSize(TypeTokens.body.size).fontFamily(TypeTokens.fontFamily)
            .fontColor(ColorTokens.secondary)
            .textAlign(TextAlign.Center)
          if (this.error !== '') {
            SoftChip({
              label: '重试',
              tone: 'brand',
              action: (): void => { this.onRetry(); },
            })
          }
        }
        .width('100%')
        .alignItems(HorizontalAlign.Center)
        .padding({ top: SpaceTokens.sm, bottom: SpaceTokens.sm })
      }
    }
    .width('100%')
    .padding(SpaceTokens.lg)
    .backgroundColor(isSystemMaterialActive() ? Color.Transparent : ColorTokens.canvas)
  }
}
