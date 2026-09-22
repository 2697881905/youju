// 帖子创作数据面板（作者侧）：浏览 → 互动 → 流量转化 的三段式轻数据表达。
//
// 视觉（与详情页玻璃面板同族）：去掉旧版 7 块 sunken 灰底小方块——它们与玻璃面板语言冲突，
// 且 3 列 7 格的尾行只有 1 格、视觉失衡。改为：
//   Hero   累计浏览（display 大数字，衬线体，编辑感）
//   互动   顶 / 收藏 / 评论 三列（图标 + 数字 + 标签，细分隔线分组，无底色）
//   转化   曝光 → 点击 → 浏览 三行比例条 + 「曝光→点击」转化率
// 比例条用官方 component-collection dataPanelSample 的 DataPanelType.Line +
// valueColors 双色（brand = 实际值 / sunken = 余量），不是手绘进度条。
// 数据流：loading/error 由普通成员改为 @Prop（原先不随父组件刷新）；
//         父组件在开窗前重置旧数据（防串帖）；新增 onRetry（加载失败可原地重试）。
import { SpringPanel } from '../design/motion/SpringPanel';
import { resolveActionIcon } from '../utils/actionIcons';
import { ColorTokens } from '../design/tokens/color';
import { IconTokens } from '../design/tokens/icon';
import { RadiusTokens } from '../design/tokens/radius';
import { LayoutTokens, SpaceTokens } from '../design/tokens/space';
import { TypeTokens } from '../design/tokens/type';
import { Pressable } from '../design/motion/Pressable';
import { formatCount } from '../utils/format';
import { PostStats } from '../services/api';

// 流量漏斗比例条（官方 DataPanel，Line 型）的几何参数
const FUNNEL_BAR_HEIGHT: number = 8;
const FUNNEL_LABEL_WIDTH: number = 36;
const FUNNEL_VALUE_WIDTH: number = 52;

@CustomDialog
export struct PostStatsDialog {
  controller: CustomDialogController;
  @Prop stats: PostStats | null = null;
  @Prop loading: boolean = false;
  @Prop error: string = '';
  // 加载失败重试：父组件重新拉取，不重开面板
  onRetry: () => void = (): void => {};

  // 漏斗的共用分母是曝光（漏斗顶端）；曝光为 0 时比例条为空，数值仍然可读
  private funnelMax(s: PostStats): number {
    return Math.max(s.expose, 1);
  }

  private clickRateText(): string {
    return '曝光→点击 ' + (this.stats?.clickRate ?? 0) + '%';
  }

  @Builder
  sectionHeader(title: string, trailing: string) {
    Row() {
      Text(title)
        .fontSize(TypeTokens.overline.size).fontFamily(TypeTokens.fontFamily)
        .fontWeight(TypeTokens.overline.weight)
        .fontColor(ColorTokens.secondary)
      if (trailing.length > 0) {
        Blank()
        Text(trailing)
          .fontSize(TypeTokens.caption.size).fontFamily(TypeTokens.fontFamily)
          .fontColor(ColorTokens.secondary)
      }
    }
    .width('100%')
  }

  @Builder
  hairline() {
    Row()
      .width('100%')
      .height(LayoutTokens.hairlineWidth)
      .backgroundColor(ColorTokens.separator)
  }

  @Builder
  funnelRow(label: string, value: number, max: number) {
    Row({ space: SpaceTokens.sm }) {
      Text(label)
        .fontSize(TypeTokens.callout.size).fontFamily(TypeTokens.fontFamily)
        .fontColor(ColorTokens.secondary)
        .width(FUNNEL_LABEL_WIDTH)
      DataPanel({
        values: [value, Math.max(max - value, 0)],
        max: Math.max(max, 1),
        type: DataPanelType.Line,
      })
        .layoutWeight(1)
        .height(FUNNEL_BAR_HEIGHT)
        .valueColors([ColorTokens.brand, ColorTokens.sunken])
      Text(formatCount(value))
        .fontSize(TypeTokens.callout.size).fontFamily(TypeTokens.fontFamily)
        .fontWeight(TypeTokens.headline.weight)
        .fontColor(ColorTokens.primary)
        .textAlign(TextAlign.End)
        .width(FUNNEL_VALUE_WIDTH)
    }
    .width('100%')
    .alignItems(VerticalAlign.Center)
  }

  @Builder
  interactCell(icon: Resource, value: number, label: string) {
    Column({ space: 2 }) {
      Image(icon)
        .width(18)
        .height(18)
        .fillColor(ColorTokens.secondary)
      Text(formatCount(value))
        .fontSize(17).fontFamily(TypeTokens.fontFamily)
        .fontWeight(TypeTokens.headline.weight)
        .fontColor(ColorTokens.primary)
      Text(label)
        .fontSize(TypeTokens.caption.size).fontFamily(TypeTokens.fontFamily)
        .fontColor(ColorTokens.secondary)
    }
    .layoutWeight(1)
    .alignItems(HorizontalAlign.Center)
  }

  build() {
    SpringPanel({ panelWidth: 344, panelPadding: SpaceTokens.lg }) {
      Column({ space: SpaceTokens.base }) {
        // 标题区（与同族弹窗同构：衬线标题 + 关闭）
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
              .fillColor(ColorTokens.secondary)
          }
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
          // Hero：累计浏览
          Column({ space: 2 }) {
            Text(formatCount(this.stats?.viewCount))
              .fontSize(TypeTokens.display.size).fontFamily(TypeTokens.fontFamilySerif)
              .fontWeight(TypeTokens.display.weight)
              .lineHeight(TypeTokens.display.lineHeight)
              .fontColor(ColorTokens.primary)
            Text('累计浏览')
              .fontSize(TypeTokens.caption.size).fontFamily(TypeTokens.fontFamily)
              .fontColor(ColorTokens.secondary)
          }
          .width('100%')
          .alignItems(HorizontalAlign.Center)

          this.hairline()

          // 互动表现：三列 + 竖向细分隔线
          this.sectionHeader('互动表现', '')
          Row() {
            this.interactCell(resolveActionIcon('like'), this.stats?.upCount ?? 0, '顶')
            Divider()
              .vertical(true)
              .strokeWidth(LayoutTokens.hairlineWidth)
              .color(ColorTokens.separator)
              .height(30)
            this.interactCell(resolveActionIcon('bookmark'), this.stats?.bookmarkCount ?? 0, '收藏')
            Divider()
              .vertical(true)
              .strokeWidth(LayoutTokens.hairlineWidth)
              .color(ColorTokens.separator)
              .height(30)
            this.interactCell(resolveActionIcon('comment'), this.stats?.commentCount ?? 0, '评论')
          }
          .width('100%')
          .alignItems(VerticalAlign.Center)

          this.hairline()

          // 流量转化：曝光为漏斗顶端，三行比例条共用同一分母
          this.sectionHeader('流量转化', this.clickRateText())
          Column({ space: SpaceTokens.sm }) {
            this.funnelRow('曝光', this.stats?.expose ?? 0, this.funnelMax(this.stats))
            this.funnelRow('点击', this.stats?.click ?? 0, this.funnelMax(this.stats))
            this.funnelRow('浏览', this.stats?.viewCount ?? 0, this.funnelMax(this.stats))
          }
          .width('100%')
        } else {
          // 错误 / 空态
          Column({ space: SpaceTokens.base }) {
            Text(this.error !== '' ? ('加载失败：' + this.error) : '暂无数据')
              .fontSize(TypeTokens.body.size).fontFamily(TypeTokens.fontFamily)
              .fontColor(ColorTokens.secondary)
              .textAlign(TextAlign.Center)
            if (this.error !== '') {
              Pressable({
                visualHeight: 30,
                touchTargetHeight: LayoutTokens.minTouchTarget,
                action: (): void => { this.onRetry(); },
              }) {
                Text('重试')
                  .fontSize(TypeTokens.callout.size).fontFamily(TypeTokens.fontFamily)
                  .fontWeight(TypeTokens.headline.weight)
                  .fontColor(ColorTokens.onBrand)
                  .backgroundColor(ColorTokens.brand)
                  .borderRadius(RadiusTokens.pill)
                  .padding({ left: SpaceTokens.md, right: SpaceTokens.md, top: 6, bottom: 6 })
              }
            }
          }
          .width('100%')
          .alignItems(HorizontalAlign.Center)
          .padding({ top: SpaceTokens.sm, bottom: SpaceTokens.sm })
        }
      }
      .width('100%')
    }
  }
}
