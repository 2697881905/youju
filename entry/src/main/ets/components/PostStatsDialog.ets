// 帖子创作数据面板（作者侧）：bindSheet 半模态内容组件。
//
// ⚠️ 实现形态：**bindSheet 半模态内容组件**（PostDetailView 根节点挂 SheetOptions）——
// 遮罩、右上角系统关闭钮、下滑拖拽关闭、点遮罩关闭、进出场全部由系统半模态承担，
// 本组件只画数据区。sheet builder 与宿主同渲染上下文，@Prop 随父组件刷新，
// 无 CustomDialog 的 @Prop 断联坑（最早 CustomDialogController builder 传 @Link 会闪退）。
//
// 内部布局（2026-11-23 定稿，原型稿 design/post-stats-panel-redesign-prototype.html
// 第四轮 ③「指标 + 基准 + 解读文案」用户拍板；回答「好不好」而不只是陈列数字）：
//   标题区（serif 帖子数据 / 仅你自己可见；右上角系统关闭钮）
//   双数字：浏览 | 互动率（互动 ÷ 浏览，质量核心指标）——浏览不再独占视觉权重
//   互动构成环：官方 DataPanel Circle 三色扇区（顶=like 红 / 收藏=bookmark 金 / 评论=
//     mention 靛，与全站互动按钮同语义色）+ 环心互动合计
//   图例：每项「数字 + ▲▼对比近 7 帖均值 + 占互动比 + 每 100 浏览带来的互动」
//   评分条：★均值（满分 5）warm 金比例条 + ▲▼对比均值
//   流量转化：transform 率 + ▲▼（基准：stats.authorBaseline 优先——服务端算作者近 7 帖
//     Σclick/Σexpose；旧后端无此字段时用父组件兜底值——前端并发拉近 7 帖 stats 汇总，
//     不依赖后端部署节奏）+ brand 比例条 + 曝光·点击口径说明。浏览 viewCount 含游客且
//     1h 去重，不进此漏斗以免比例误导（2026-11-19 定）。
//   解读块：规则派生（互动结构 + 相对近 7 帖均值最大偏差项），无基准时只写结构句。
//   庆祝烟花（2026-11-23）：数据达「优秀」标准时面板顶部叠 Canvas 粒子烟花（金色/品牌蓝
//     两波绽放 ~1.8s，见 FireworksOverlay）；标准见 isCelebrationWorthy（甲·双层闸门，
//     校准为 1.2 倍均值 / 评分≥4.5且≥2人 / 绝对通道 3%·800），每次打开重新评估，
//     数据变差即不再触发。触发方式只有数据评估一条路径（无任何手动预览入口）。
//   计数入场动画（2026-11-23）：stats 到达时全部数字从 0 递增到目标值（单 timer 推统一
//     进度 animT，1200ms easeOutCubic 同步上涨）；DataPanel 扇区/比例条不做动画（跳变）。
//
// 基准数据（avgXxx + baselineCount）：PostDetailView 用 listPosts(author=自己, latest 20)
// 排除当前帖后取近 7 帖均值传入；拉取失败静默降级为无基准态（不显示 ▲▼ / 对比句，
// 说明行文案改为「暂无历史帖可对比」以免误认为标记损坏）。
// 面板材质：让位 SheetOptions.systemMaterial（沉浸玻璃·面板档，API ≥ 26 生效）；低版本
// 回退 canvas 实色。内容侧不自绘底/边框/圆角。
import { isSystemMaterialActive } from '../utils/immersiveMaterial';
import { ColorTokens } from '../design/tokens/color';
import { RadiusTokens } from '../design/tokens/radius';
import { LayoutTokens, SpaceTokens } from '../design/tokens/space';
import { TypeTokens } from '../design/tokens/type';
import { SoftChip } from '../design/components/SoftChip';
import { FireworksOverlay } from '../design/motion/FireworksOverlay';
import { formatCount } from '../utils/format';
import { PostStats } from '../services/api';

const CELL_SERIF_SIZE: number = 26; // 双数字衬线字号（浏览/互动率）
const RING_SIZE: number = 92;       // 构成环直径
const RING_STROKE: number = 10;     // 构成环宽

@Component
export struct PostStatsDialog {
  @Prop @Watch('onStatsReady') stats: PostStats | null = null;
  @Prop loading: boolean = false;
  @Prop error: string = '';
  // 社区评分（Post.ratingAvg/ratingCount 随帖传入；stats 接口不含评分）
  @Prop ratingAvg: number | null = null;
  @Prop ratingCount: number = 0;
  // 基准：自己近 7 帖均值（0 / null = 无基准，不显示 ▲▼ 与对比句）
  @Prop avgView: number = 0;
  @Prop avgUp: number = 0;
  @Prop avgBookmark: number = 0;
  @Prop avgComment: number = 0;
  @Prop avgRating: number | null = null;
  @Prop baselineCount: number = 0;
  // 转化率基准兜底（旧后端 stats 无 authorBaseline 时由父组件拉近 7 帖 stats 汇总）
  @Prop fallbackClickCount: number = 0;
  @Prop fallbackClickRate: number = 0;
  // 加载失败重试：父组件重新拉取，不重开面板
  onRetry: () => void = (): void => {};

  private hasRating(): boolean {
    return this.ratingAvg !== null && this.ratingAvg !== undefined;
  }

  private hasBaseline(): boolean {
    return this.baselineCount > 0;
  }

  // 互动合计（顶+收藏+评论）：构成环分母与环心数字
  private interactionTotal(): number {
    const s: PostStats | null = this.stats;
    return (s?.upCount ?? 0) + (s?.bookmarkCount ?? 0) + (s?.commentCount ?? 0);
  }

  private interactionPct(part: number): number {
    const total: number = Math.max(this.interactionTotal(), 1);
    return Math.round(part * 100 / total);
  }

  // 互动率 = 互动 ÷ 浏览（一位小数 %）：质量核心指标
  private interactionRate(): number {
    const views: number = this.stats?.viewCount ?? 0;
    if (views <= 0) {
      return 0;
    }
    return Math.round(this.interactionTotal() * 1000 / views) / 10;
  }

  // 基准互动率：Σ互动 ÷ Σ浏览（加权口径，不是「各帖互动率的平均」）
  private avgInteractionRate(): number {
    if (this.avgView <= 0) {
      return 0;
    }
    const total: number = this.avgUp + this.avgBookmark + this.avgComment;
    return Math.round(total * 1000 / this.avgView) / 10;
  }


  // 相对均值的标记文本。⚠️ 有基准时标记区必须有输出——历史帖均值常为 0
  // （测试帖无浏览/互动），旧逻辑 avg<=0 返回空串会把全部 ▲▼ 吞掉（真机复现）；
  // 规则：均值 0 且当前 >0 → 裸 ▲（从零起步）；持平 → 「持平」（tertiary）。
  private deltaText(cur: number, avg: number): string {
    if (avg <= 0) {
      return cur > 0 ? '▲' : '';
    }
    const pct: number = Math.round((cur - avg) * 100 / avg);
    if (pct === 0) {
      return '持平';
    }
    return (pct > 0 ? '▲' : '▼') + String(Math.abs(pct)) + '%';
  }

  // 列表均值基准（浏览/顶/收藏/评论/评分，前端 listPosts 计算）
  private deltaMark(cur: number, avg: number): string {
    return this.hasBaseline() ? this.deltaText(cur, avg) : '';
  }

  // 转化率基准：服务端 authorBaseline 优先；旧后端字段缺失时用父组件兜底值
  private clickBaselineCount(): number {
    return this.stats?.authorBaseline?.postCount ?? this.fallbackClickCount;
  }

  private clickBaselineRate(): number {
    return this.stats?.authorBaseline?.clickRate ?? this.fallbackClickRate;
  }

  private clickDeltaMark(): string {
    if (this.clickBaselineCount() <= 0) {
      return '';
    }
    return this.deltaText(this.clickRateClamped(), this.clickBaselineRate());
  }

  // 转化率钳到 0-100（异常值不炸比例条）
  private clickRateClamped(): number {
    return Math.min(Math.max(this.stats?.clickRate ?? 0, 0), 100);
  }

  // 评分钳到 0-5（比例条 max 5）
  private ratingClamped(): number {
    return Math.min(Math.max(this.ratingAvg ?? 0, 0), 5);
  }

  // 优秀判定（2026-11-23 用户定稿「甲·双层闸门」并校准可达性：原 1.5 倍/3 人评分
  // 在真实小社区数据下几乎不可触发；每次数据到达重新评估，数据变差后不再放烟花）：
  //   ① 跑赢日常：互动率 ≥ 自身近 7 帖均值 × 1.2 且 浏览 ≥ 自身均值（均值 >0 才有效；
  //      均值易被个别高互动帖拉高，倍数过高会长期不可达）
  //   ② 口碑突出：评分 ≥ 4.5 且 评分人数 ≥ 2
  //   ③ 绝对通道（不限基准场景）：互动率 ≥ 3% 且 浏览 ≥ 800（小样本防虚高）
  private isCelebrationWorthy(): boolean {
    if (this.stats === null) {
      return false;
    }
    const rate: number = this.interactionRate();
    const views: number = this.stats.viewCount ?? 0;
    if (this.hasRating() && this.ratingClamped() >= 4.5 && this.ratingCount >= 2) {
      return true;
    }
    if (rate >= 3 && views >= 800) {
      return true;
    }
    if (this.hasBaseline() && this.avgView > 0 && this.avgInteractionRate() > 0) {
      // 「浏览 ≥ 自身均值」拦小流量虚高；均值互动率为 0 时倍数无意义，落 ③
      return rate >= this.avgInteractionRate() * 1.2 && views >= this.avgView;
    }
    return false;
  }

  // ── 计数入场动画（2026-11-23 用户要求）：stats 到达时全部数字从 0 递增到目标值。
  // 单个 timer 推统一进度 animT（0→1，1200ms，easeOutCubic），所有数字即时乘进度——
  // 比每个 Text 各起一个定时器轻，且各数字同步上涨。进入时只跑一次；重试（stats 回
  // null 再到达）会重放。DataPanel 环扇区/比例条不做动画（逐帧改 values 会跳变）。
  @State animT: number = 0;
  // 「作品优秀」庆祝：每次打开/重试重新评估，烟花播完置回 false
  @State celebrateActive: boolean = false;
  private animTimer: number = 0;
  private animStarted: boolean = false;

  aboutToDisappear(): void {
    this.stopAnim();
  }

  private onStatsReady(): void {
    if (this.stats === null) {
      // 重试/重开：回起点，等数据再次到达时重放
      this.animStarted = false;
      this.animT = 0;
      this.celebrateActive = false;
      this.stopAnim();
      return;
    }
    // 优秀评估每次数据到达都重算：数据变差（低于标准）后不再放烟花
    this.celebrateActive = this.isCelebrationWorthy();
    if (this.animStarted) {
      return;
    }
    this.animStarted = true;
    this.stopAnim();
    const startedAt: number = Date.now();
    const duration: number = 1200;
    this.animTimer = setInterval((): void => {
      const p: number = Math.min((Date.now() - startedAt) / duration, 1);
      this.animT = 1 - Math.pow(1 - p, 3);
      if (p >= 1) {
        this.animT = 1;
        this.stopAnim();
      }
    }, 33) as number;
  }

  private stopAnim(): void {
    if (this.animTimer !== 0) {
      clearInterval(this.animTimer);
      this.animTimer = 0;
    }
  }

  // 动画中的显示值：整数口径走 formatCount（≥1w 自然缩写）；比率一位小数
  private shownCount(target: number): string {
    return formatCount(Math.round(target * this.animT));
  }

  private shownRate(target: number): string {
    return (target * this.animT).toFixed(1);
  }

  private shownPct(count: number): string {
    return String(Math.round(this.interactionPct(count) * this.animT)) + '%';
  }

  private shownPerView(count: number): string {
    const views: number = this.stats?.viewCount ?? 0;
    if (views <= 0) {
      return '—';
    }
    return ((Math.round(count * 1000 / views) / 10) * this.animT).toFixed(1) + '%';
  }

  // 规则派生解读：互动结构句 + 相对近 7 帖均值偏差最大的项（无基准只写结构句）
  private insightText(): string {
    const total: number = this.interactionTotal();
    if (total <= 0) {
      return '本帖暂无互动数据。';
    }
    const up: number = this.stats?.upCount ?? 0;
    const bk: number = this.stats?.bookmarkCount ?? 0;
    const cm: number = this.stats?.commentCount ?? 0;
    const maxV: number = Math.max(up, bk, cm);
    const maxName: string = maxV === up ? '顶' : (maxV === bk ? '收藏' : '评论');
    const maxPct: number = Math.round(maxV * 100 / total);
    const structure: string = maxPct >= 55
      ? ('互动以' + maxName + '为主（' + String(maxPct) + '%）')
      : '互动构成较均衡';
    if (!this.hasBaseline()) {
      return structure + '。';
    }
    const names: string[] = ['浏览', '顶', '收藏', '评论'];
    const curs: number[] = [this.stats?.viewCount ?? 0, up, bk, cm];
    const avgs: number[] = [this.avgView, this.avgUp, this.avgBookmark, this.avgComment];
    if (this.hasRating() && this.avgRating !== null && this.avgRating > 0) {
      names.push('评分');
      curs.push(this.ratingClamped());
      avgs.push(this.avgRating);
    }
    let bestIdx: number = -1;
    let bestAbs: number = 0;
    for (let i: number = 0; i < names.length; i++) {
      const avg: number = avgs[i];
      if (avg <= 0) {
        continue;
      }
      const absPct: number = Math.abs(Math.round((curs[i] - avg) * 100 / avg));
      if (absPct > bestAbs) {
        bestAbs = absPct;
        bestIdx = i;
      }
    }
    if (bestIdx < 0 || bestAbs === 0) {
      return structure + '；各指标与近 7 帖均值持平。';
    }
    const pct: number = Math.round((curs[bestIdx] - avgs[bestIdx]) * 100 / avgs[bestIdx]);
    const dir: string = pct > 0 ? '高于' : '低于';
    return structure + '；' + names[bestIdx] + dir + '近 7 帖均值 '
      + String(Math.abs(pct)) + '%。';
  }

  @Builder
  hairline() {
    Row()
      .width('100%')
      .height(LayoutTokens.hairlineWidth)
      .backgroundColor(ColorTokens.separator)
  }

  // ⚠️ ▲▼ 标记必须内联条件渲染（if + Text 直写调用处）。
  // 真机实测（2026-11-23）：@Builder 内用根级 if 包裹 Text 的写法不产出任何节点——
  // 基准已拉到、deltaMark 返回「▼50%」时图例/评分/互动率旁仍全部空白（uitest dump 证实）。

  // 双数字：浏览 | 互动率 同级（浏览不再独占视觉权重）
  @Builder
  duoRow() {
    Row() {
      Column({ space: 2 }) {
        Text(this.shownCount(this.stats?.viewCount ?? 0))
          .fontSize(CELL_SERIF_SIZE).fontFamily(TypeTokens.fontFamilySerif)
          .fontWeight(700)
          .lineHeight(30)
          .fontColor(ColorTokens.primary)
          .fontFeature(TypeTokens.tabularFeature)
        Text('浏览')
          .fontSize(11).fontFamily(TypeTokens.fontFamily)
          .fontColor(ColorTokens.secondary)
      }
      .alignItems(HorizontalAlign.Start)
      Blank()
      Column({ space: 2 }) {
        Row() {
          Text(this.shownRate(this.interactionRate()) + '%')
            .fontSize(CELL_SERIF_SIZE).fontFamily(TypeTokens.fontFamilySerif)
            .fontWeight(700)
            .lineHeight(30)
            .fontColor(ColorTokens.primary)
            .fontFeature(TypeTokens.tabularFeature)
          if (this.deltaMark(this.interactionRate(), this.avgInteractionRate()).length > 0) {
            Text(this.deltaMark(this.interactionRate(), this.avgInteractionRate()))
              .fontSize(11).fontFamily(TypeTokens.fontFamily)
              .fontWeight(600)
              .fontColor(this.deltaMark(this.interactionRate(), this.avgInteractionRate()) === '持平'
                ? ColorTokens.tertiary
                : (this.interactionRate() >= this.avgInteractionRate()
                  ? ColorTokens.success : ColorTokens.danger))
              .fontFeature(TypeTokens.tabularFeature)
              .margin({ left: SpaceTokens.xs })
          }
        }
        .alignItems(VerticalAlign.Center)
        Text('互动率 · ' + this.shownCount(this.interactionTotal()) + ' / '
          + this.shownCount(this.stats?.viewCount ?? 0))
          .fontSize(11).fontFamily(TypeTokens.fontFamily)
          .fontColor(ColorTokens.secondary)
      }
      .alignItems(HorizontalAlign.End)
    }
    .width('100%')
    .alignItems(VerticalAlign.Center)
    .padding({ top: SpaceTokens.sm, bottom: SpaceTokens.md })
  }

  // 图例行：色块 + 名称 | 数字 + ▲▼ | 占互动比 | 每 100 浏览
  @Builder
  legendRow(color: ResourceColor, name: string, count: number, avgCount: number) {
    Row() {
      Row({ space: 6 }) {
        Row()
          .width(8)
          .height(8)
          .borderRadius(2)
          .backgroundColor(color)
        Text(name)
          .fontSize(13).fontFamily(TypeTokens.fontFamily)
          .fontColor(ColorTokens.secondary)
      }
      .alignItems(VerticalAlign.Center)
      Blank()
      Text(this.shownCount(count))
        .fontSize(17).fontFamily(TypeTokens.fontFamily)
        .fontWeight(600)
        .fontColor(ColorTokens.primary)
        .fontFeature(TypeTokens.tabularFeature)
      // ▲▼ + 占互动比 成组：组内紧贴（百分比不再用固定宽左留白，之前 width(34)+End
      // 会在文字左侧空出 ~16vp，mark 贴着容器缘就是「有间距」的观感）；整组右对齐，
      // 右缘锚在固定宽 rate 列左侧 → 各行百分比右缘天然对齐
      Row() {
        if (this.deltaMark(count, avgCount).length > 0) {
          Text(this.deltaMark(count, avgCount))
            .fontSize(11).fontFamily(TypeTokens.fontFamily)
            .fontWeight(600)
            .fontColor(this.deltaMark(count, avgCount) === '持平' ? ColorTokens.tertiary
              : (count >= avgCount ? ColorTokens.success : ColorTokens.danger))
            .fontFeature(TypeTokens.tabularFeature)
            .margin({ right: 2 })
        }
        Text(this.shownPct(count))
          .fontSize(11).fontFamily(TypeTokens.fontFamily)
          .fontColor(ColorTokens.tertiary)
      }
      .justifyContent(FlexAlign.End)
      .margin({ left: SpaceTokens.xs, right: SpaceTokens.xs })
      Text(this.shownPerView(count))
        .fontSize(11).fontFamily(TypeTokens.fontFamily)
        .fontColor(ColorTokens.secondary)
        .fontWeight(600)
        .width(44)
        .textAlign(TextAlign.End)
        .fontFeature(TypeTokens.tabularFeature)
    }
    .width('100%')
    .alignItems(VerticalAlign.Center)
    .padding({ top: SpaceTokens.xs, bottom: SpaceTokens.xs })
  }

  // 互动构成环 + 图例：三色扇区即三项占比，环心叠互动合计
  @Builder
  ringRow() {
    Row({ space: SpaceTokens.base }) {
      Stack() {
        DataPanel({
          values: [this.stats?.upCount ?? 0, this.stats?.bookmarkCount ?? 0, this.stats?.commentCount ?? 0],
          max: Math.max(this.interactionTotal(), 1),
          type: DataPanelType.Circle,
        })
          .width(RING_SIZE)
          .height(RING_SIZE)
          .strokeWidth(RING_STROKE)
          .valueColors([ColorTokens.like, ColorTokens.bookmark, ColorTokens.mention])
        Column({ space: 1 }) {
          Text(this.shownCount(this.interactionTotal()))
            .fontSize(22).fontFamily(TypeTokens.fontFamilySerif)
            .fontWeight(700)
            .fontColor(ColorTokens.primary)
            .fontFeature(TypeTokens.tabularFeature)
          Text('互动')
            .fontSize(10).fontFamily(TypeTokens.fontFamily)
            .fontColor(ColorTokens.secondary)
        }
        .alignItems(HorizontalAlign.Center)
      }

      Column() {
        this.legendRow(ColorTokens.like, '顶', this.stats?.upCount ?? 0, this.avgUp)
        Row()
          .width('100%')
          .height(LayoutTokens.hairlineWidth)
          .backgroundColor(ColorTokens.separator)
        this.legendRow(ColorTokens.bookmark, '收藏', this.stats?.bookmarkCount ?? 0, this.avgBookmark)
        Row()
          .width('100%')
          .height(LayoutTokens.hairlineWidth)
          .backgroundColor(ColorTokens.separator)
        this.legendRow(ColorTokens.mention, '评论', this.stats?.commentCount ?? 0, this.avgComment)
      }
      .layoutWeight(1)
    }
    .width('100%')
    .alignItems(VerticalAlign.Center)
    .padding({ top: SpaceTokens.sm, bottom: SpaceTokens.sm })
  }

  // 节行：左标签 + 右数值 + 说明（备用；流量转化节因带 ▲▼ 已内联）
  @Builder
  sectionRow(label: string, value: string, note: string) {
    Row() {
      Text(label)
        .fontSize(TypeTokens.overline.size).fontFamily(TypeTokens.fontFamily)
        .fontWeight(TypeTokens.overline.weight)
        .fontColor(ColorTokens.secondary)
      Blank()
      Text(value)
        .fontSize(TypeTokens.headline.size).fontFamily(TypeTokens.fontFamily)
        .fontWeight(TypeTokens.headline.weight)
        .fontColor(ColorTokens.primary)
        .fontFeature(TypeTokens.tabularFeature)
      if (note.length > 0) {
        Text(note)
          .fontSize(10).fontFamily(TypeTokens.fontFamily)
          .fontColor(ColorTokens.tertiary)
          .margin({ left: SpaceTokens.sm })
      }
    }
    .width('100%')
    .alignItems(VerticalAlign.Center)
  }

  build() {
    // 半模态内容区：材质生效时透明（表面由 SheetOptions.systemMaterial 承载），
    // 低版本回退 canvas 实色；遮罩/关闭钮/拖拽/进出场不再自绘（系统半模态全包）。
    // 烟花层叠在 Column 之上并撑满面板全高——落点 = 面板底部 = 屏幕底部。
    Stack() {
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
        this.duoRow()

        this.hairline()

        this.ringRow()

        this.hairline()

        // 评分节：★ 金色与数值分色 + ▲▼ 对比均值；无人打分数值位「—」、条空
        Row() {
          Text('社区评分')
            .fontSize(TypeTokens.overline.size).fontFamily(TypeTokens.fontFamily)
            .fontWeight(TypeTokens.overline.weight)
            .fontColor(ColorTokens.secondary)
          Blank()
          if (this.hasRating()) {
            Text() {
              Span('★')
                .fontColor(ColorTokens.warm)
              Span((this.ratingClamped() * this.animT).toFixed(1))
              Span('（' + this.shownCount(this.ratingCount) + '人）')
                .fontSize(11)
                .fontColor(ColorTokens.tertiary)
            }
            .fontSize(TypeTokens.headline.size).fontFamily(TypeTokens.fontFamily)
            .fontWeight(TypeTokens.headline.weight)
            .fontColor(ColorTokens.primary)
            .fontFeature(TypeTokens.tabularFeature)
            if (this.deltaMark(this.ratingClamped(), this.avgRating ?? 0).length > 0) {
              Text(this.deltaMark(this.ratingClamped(), this.avgRating ?? 0))
                .fontSize(11).fontFamily(TypeTokens.fontFamily)
                .fontWeight(600)
                .fontColor(this.deltaMark(this.ratingClamped(), this.avgRating ?? 0) === '持平'
                  ? ColorTokens.tertiary
                  : (this.ratingClamped() >= (this.avgRating ?? 0)
                    ? ColorTokens.success : ColorTokens.danger))
                .fontFeature(TypeTokens.tabularFeature)
                .margin({ left: SpaceTokens.xs })
            }
          } else {
            Text('—')
              .fontSize(TypeTokens.headline.size).fontFamily(TypeTokens.fontFamily)
              .fontWeight(TypeTokens.headline.weight)
              .fontColor(ColorTokens.primary)
          }
          Text('满分 5')
            .fontSize(10).fontFamily(TypeTokens.fontFamily)
            .fontColor(ColorTokens.tertiary)
            .margin({ left: SpaceTokens.sm })
        }
        .width('100%')
        .alignItems(VerticalAlign.Center)

        DataPanel({
          values: [this.ratingClamped(), Math.max(5 - this.ratingClamped(), 0)],
          max: 5,
          type: DataPanelType.Line,
        })
          .width('100%')
          .height(6)
          .valueColors([ColorTokens.warm, ColorTokens.sunken])
          .margin({ top: SpaceTokens.sm })

        // 流量转化节：转化率 ▲▼ 用服务端 authorBaseline（作者近 7 帖 Σclick/Σexpose）
        Row() {
          Text('流量转化')
            .fontSize(TypeTokens.overline.size).fontFamily(TypeTokens.fontFamily)
            .fontWeight(TypeTokens.overline.weight)
            .fontColor(ColorTokens.secondary)
          Blank()
          Text(this.shownRate(this.clickRateClamped()) + '%')
            .fontSize(TypeTokens.headline.size).fontFamily(TypeTokens.fontFamily)
            .fontWeight(TypeTokens.headline.weight)
            .fontColor(ColorTokens.primary)
            .fontFeature(TypeTokens.tabularFeature)
          if (this.clickDeltaMark().length > 0) {
            Text(this.clickDeltaMark())
              .fontSize(11).fontFamily(TypeTokens.fontFamily)
              .fontWeight(600)
              .fontColor(this.clickDeltaMark() === '持平' ? ColorTokens.tertiary
                : (this.clickRateClamped() >= this.clickBaselineRate()
                  ? ColorTokens.success : ColorTokens.danger))
              .fontFeature(TypeTokens.tabularFeature)
              .margin({ left: SpaceTokens.xs })
          }
          Text('曝光 ' + this.shownCount(this.stats.expose) + ' · 点击 ' + this.shownCount(this.stats.click))
            .fontSize(10).fontFamily(TypeTokens.fontFamily)
            .fontColor(ColorTokens.tertiary)
            .margin({ left: SpaceTokens.sm })
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

        // 基准说明：始终显示一行——有基准讲 ▲▼ 口径；无基准明确告知原因，
        // 避免被误认为标记损坏（新账号只有当前一帖时是预期降级态）
        Text(this.hasBaseline()
          ? '▲▼ = 对比自己近 7 帖均值'
          : '暂无历史帖可对比 · 发布第 2 帖后显示 ▲▼')
          .fontSize(10).fontFamily(TypeTokens.fontFamily)
          .fontColor(ColorTokens.tertiary)
          .textAlign(TextAlign.End)
          .width('100%')

        // 解读块：规则派生（结构 + 最大偏差项），无基准只写结构句
        Column({ space: SpaceTokens.xs }) {
          Text('📌 解读')
            .fontSize(11).fontFamily(TypeTokens.fontFamily)
            .fontWeight(700)
            .fontColor(ColorTokens.primary)
          Text(this.insightText())
            .fontSize(12).fontFamily(TypeTokens.fontFamily)
            .lineHeight(20)
            .fontColor(ColorTokens.secondary)
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)
        .padding(SpaceTokens.md)
        .borderRadius(RadiusTokens.sm)
        .backgroundColor(ColorTokens.elevated)
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

      if (this.celebrateActive) {
        FireworksOverlay({
          onFinish: (): void => {
            this.celebrateActive = false;
          },
        })
      }
    }
    .width('100%')
    .alignContent(Alignment.Top)
    .backgroundColor(isSystemMaterialActive() ? Color.Transparent : ColorTokens.canvas)
  }
}