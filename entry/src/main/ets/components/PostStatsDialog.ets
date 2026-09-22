// 帖子创作数据面板（作者侧）：浏览 → 互动 → 流量转化 的三段式轻数据表达。
//
// ⚠️ 实现形态：**页内覆盖层（父组件 if 分支渲染），不是 @CustomDialog**。
// 原因（release 实测踩过）：动态 `new CustomDialogController({builder: ...})` 的 builder 里
// 传 @Link 会直接 ReferenceError（`$postStats is not defined`）闪退；而 @Prop 在
// CustomDialog 的 builder 里 open() 后不随父组件重渲染同步（面板永远停在「正在汇总」）。
// 改为父组件 @State 驱动的 if 分支覆盖层后，@Prop 随父组件刷新，天然响应式。
//
// 面板材质：**与应用内容卡同款**（PostCard 的卡片语言）——实心 elevated 底 +
// 1px separator 描边 + lg 圆角，**无模糊、无透明、无阴影、无流光**。
// 踩坑记录：玻璃模糊（与暖纸背景不搭）、透明描边（遮罩上可视性差）都被否，
// 最终回归应用的内容卡语言。
//
// 结构（自上而下）：
//   标题区（serif 帖子数据 / 仅你自己可见 / 关闭）
//   Hero：累计浏览（display 大数字，衬线体，编辑感）
//   互动表现：顶 / 收藏 / 评论 三列（图标 + 数字 + 标签，细分隔线分组，无底色）
//   流量转化：曝光 → 点击 → 浏览 三行比例条 + 「曝光→点击」转化率
// 比例条用官方 component-collection dataPanelSample 的 DataPanelType.Line +
// valueColors 双色（brand = 实际值 / sunken = 余量），不是手绘进度条。
import { resolveActionIcon } from '../utils/actionIcons';
import { ColorTokens } from '../design/tokens/color';
import { IconTokens } from '../design/tokens/icon';
import { RadiusTokens } from '../design/tokens/radius';
import { LayoutTokens, SpaceTokens } from '../design/tokens/space';
import { TypeTokens } from '../design/tokens/type';
import { MotionCurves, MotionTokens } from '../design/tokens/motion';
import { Pressable } from '../design/motion/Pressable';
import { formatCount } from '../utils/format';
import { PostStats } from '../services/api';

// 流量漏斗比例条（官方 DataPanel，Line 型）的几何参数
const FUNNEL_BAR_HEIGHT: number = 8;
const FUNNEL_LABEL_WIDTH: number = 36;
const FUNNEL_VALUE_WIDTH: number = 52;

@Component
export struct PostStatsDialog {
  @Prop stats: PostStats | null = null;
  @Prop loading: boolean = false;
  @Prop error: string = '';
  // 遮罩/关闭键：父组件置 statsPanelShow=false 卸载覆盖层
  onClose: () => void = (): void => {};
  // 加载失败重试：父组件重新拉取，不重开面板
  onRetry: () => void = (): void => {};

  // 漏斗的共用分母是曝光（漏斗顶端）；曝光为 0 时比例条为空，数值仍然可读
  private funnelMax(): number {
    return Math.max(this.stats?.expose ?? 1, 1);
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
    // 全屏覆盖层：暗色遮罩（点空白处关闭）+ 居中卡片
    Stack({ alignContent: Alignment.Center }) {
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor('rgba(0,0,0,0.35)')
        .onClick((): void => { this.onClose(); })

      // 卡片材质与应用内容卡（PostCard）同款：实心 elevated + 1px separator + lg 圆角，
      // 无模糊/透明/阴影/流光；进出场用轻淡入 + 微缩放（与全局动效令牌一致）。
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
            action: (): void => { this.onClose(); },
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
            Text(formatCount(this.stats.viewCount))
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
            this.interactCell(resolveActionIcon('like'), this.stats.upCount, '顶')
            Divider()
              .vertical(true)
              .strokeWidth(LayoutTokens.hairlineWidth)
              .color(ColorTokens.separator)
              .height(30)
            this.interactCell(resolveActionIcon('bookmark'), this.stats.bookmarkCount, '收藏')
            Divider()
              .vertical(true)
              .strokeWidth(LayoutTokens.hairlineWidth)
              .color(ColorTokens.separator)
              .height(30)
            this.interactCell(resolveActionIcon('comment'), this.stats.commentCount, '评论')
          }
          .width('100%')
          .alignItems(VerticalAlign.Center)

          this.hairline()

          // 流量转化：曝光为漏斗顶端，三行比例条共用同一分母
          this.sectionHeader('流量转化', this.clickRateText())
          Column({ space: SpaceTokens.sm }) {
            this.funnelRow('曝光', this.stats.expose, this.funnelMax())
            this.funnelRow('点击', this.stats.click, this.funnelMax())
            this.funnelRow('浏览', this.stats.viewCount, this.funnelMax())
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
      // 弹窗宽度走应用标准 344（同收藏夹命名/分享面板）；高度内容自适应
      .width(344)
      .backgroundColor(ColorTokens.elevated)
      .border({ width: 1, color: ColorTokens.separator, style: BorderStyle.Solid })
      .borderRadius(RadiusTokens.lg)
      .transition(TransitionEffect.OPACITY
        .animation({ duration: MotionTokens.container, curve: MotionCurves.springSoft })
        .combine(TransitionEffect.scale({ x: MotionTokens.enterScale, y: MotionTokens.enterScale })
          .animation({ duration: MotionTokens.container, curve: MotionCurves.springSoft })))
    }
    .width('100%')
    .height('100%')
  }
}
