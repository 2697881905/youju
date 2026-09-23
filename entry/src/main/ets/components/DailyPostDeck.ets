import { DailyPost } from '../models/types';
import { resolveDisplayImageUrl, trackPostEvent } from '../services/api';
import { ColorTokens } from '../design/tokens/color';
import { MotionCurves, MotionTokens, MotionFrameRates } from '../design/tokens/motion';
import { RadiusTokens } from '../design/tokens/radius';
import { LayoutTokens, SpaceTokens } from '../design/tokens/space';
import { TypeTokens } from '../design/tokens/type';
import { formatCount } from '../utils/format';
import { barBottomReserve } from '../utils/cardTokens';
import { Pressable } from '../design/motion/Pressable';
import { curves } from '@kit.ArkUI';

// —— 卡堆扇位参数：实体卡堆滑入（对应原型 FAN_X/FAN_R/FAN_Y）——
const DECK_FAN_X: number = 30;          // 层间水平行程（抽出左上角，强化扇面）
const DECK_FAN_Y: number = 7;          // 层间纵向行程（收敛：右下角收拢成轴，不露出横向叠条）
const DECK_FAN_ANGLE: number = 4;       // 层间角差
const DECK_DRAG_TILT: number = 5;       // 顶卡拖拽最大倾角（原型 rotGoal = x/w * -5）
const DECK_DRAG_ROLL: number = 2.5;     // 竖直分量带来的轻微滚转（向上/向下拖也会“晃”，幅度刻意压低）
const DECK_LIFT_SCALE: number = 0.03;   // 拿起卡片的微胀（对应 GSAP 拖拽时给目标的 scale 抬升）
const DECK_RISE: number = 26;           // 入场仪式：顶卡升起行程
const DECK_RISE_SCALE: number = 0.025;  // 入场仪式：顶卡缩放（1 → 0.975 之间）
const DECK_MEDIA_RATIO: number = 4 / 3; // 卡面 4:3（原型 aspect-ratio: 4/3）
const DECK_SLOT_SCALE: number = 0.028;  // 下层逐层缩小（原型 1 - 0.028*role）
const DECK_WARM: number = 0.06;         // 顶卡抬起时下层微胀最大值（原型 warm*0.06）
const DECK_VISIBLE: number = 4;     // 四槽：顶 / 中 / 底 / 预备
// 顶/中/底/预备 恒定不透明度（全程无淡入，只做位移与旋转；入场时下层从其 30% 淡入）
const DECK_FAN_OP: number[] = [1, 0.86, 0.72, 0.45];
// 拖拽视差：下层卡随顶卡偏移的跟随系数（顶到预备逐层递减；预备层不跟随）。
// 回弹时整叠一起快速归位，跟手更“实”
const DECK_PARAX: number[] = [0, 0.16, 0.08, 0];
// 拖拽视差倾角：拖动时下层卡也随顶卡方向倾斜（顶卡最多、逐层递减），回弹时各自滞后归位
const DECK_PAR_ROT: number[] = [0, 0.30, 0.18, 0.08];
// —— 自由丢出（2D）参数：方向不预设，由「实际位移 + 松手速度」共同推导 ——
// 惯性投影时长（秒）：松手后速度还能带出的行程 = 速度 × 该值，
// 对应 GSAP Draggable 的 `inertia: true`（InertiaPlugin 用速度预测 end，再 glide 到该点）。
// 注意：投影只在「已有明确拖动意图」时生效（见 DECK_FLING_MIN_DIST），
// 否则一次快速抖动就能凭空凑出满阈值行程，卡片会被误丢出去。
const DECK_INERTIA_PROJECT: number = 0.16;
const DECK_FLING_MIN_VEL: number = 520;   // 轻甩判定速度下限（vp/s，与手势速度同量纲）
// 拖动意图门槛（卡宽比）：位移超过它才算「在拖」，才允许速度参与丢出判定。
// 它同时是轻甩路线的下限与惯性投影的开关 —— 0.12 时一次 20vp 的抖动会被速度放大成丢出
const DECK_FLING_MIN_DIST: number = 0.18;
// 各槽位弹簧（对应原型每张卡独立扇位弹簧：顶卡最弹、越往后越稳，
// 回弹/推进时按各自频率振荡 → 下层卡跟随顶卡产生自然的“摇晃”）
const DECK_SPRING: ICurve[] = [
  curves.springMotion(0.30, 0.58),  // 顶卡：响应快、回弹圆润（稍从容，尾段不抖）
  curves.springMotion(0.34, 0.64),  // 中卡
  curves.springMotion(0.40, 0.70),  // 底卡
  curves.springMotion(0.46, 0.76),  // 预备卡：最收敛
];
// 旋转专用弹簧：比位移更慢、阻尼更低 → 角度滞后于位置，形成网页那种“晃动”相位差
const DECK_ROT_SPRING: ICurve[] = [
  curves.springMotion(0.50, 0.47),  // 顶卡角度：摆动真实不夸张
  curves.springMotion(0.58, 0.54),  // 中卡
  curves.springMotion(0.64, 0.62),  // 底卡
  curves.springMotion(0.70, 0.70),  // 预备卡
];

// 单张卡：内容绑定帖子 id，深度由自身在可见序中的位置推导；深度变化即“实体前移”。
@Component
struct DeckSlotCard {
  @Prop post: DailyPost = {};
  @Prop anchor: number = 0;          // 当前顶帖下标（activeIndex），变化即驱动重渲染与实体前移
  @Prop posts: DailyPost[] = [];     // 全量列表，供查找本卡当前深度
  @Prop deckWidth: number = 0;       // 用于退场飞出距离
  @Prop dragOffsetX: number = 0;     // 顶卡跟手位移 X → 下层视差跟随
  @Prop dragOffsetY: number = 0;     // 顶卡跟手位移 Y：自由拖动，竖直方向同样跟手
  @Prop rise: number = 1;            // 入场仪式 0→1：顶卡升起 + 下层淡入
  // —— 飞行模式（旧顶卡被推进时独立抛射到屏外，对应原型 S.FL）——
  @Prop inFlight: boolean = false;   // true：本卡不再参与堆叠，仅按飞行参数渲染
  @Prop flyX: number = 0;            // 飞行卡当前位移 X（沿丢出方向）
  @Prop flyY: number = 0;            // 飞行卡当前位移 Y（沿丢出方向）
  @Prop flyRot: number = 0;          // 飞行卡抛射倾角

  // 本卡的“当前槽位”：深度 = 在可见序(activeIndex 起)中的下标；越界则为 -1（不渲染）
  private curDepth(): number {
    const idx: number = this.posts.findIndex((p: DailyPost): boolean => p.id === this.post.id);
    if (idx < this.anchor) {
      return -1;
    }
    const d: number = idx - this.anchor;
    return d < DECK_VISIBLE ? d : -1;
  }

  private hasMedia(): boolean {
    const p: DailyPost = this.post;
    return (p.videoUrl ?? '').length > 0 || (p.videoCover ?? '').length > 0 || (p.coverImage ?? '').length > 0;
  }

  private mediaUrl(): string {
    const p: DailyPost = this.post;
    if ((p.videoCover ?? '').length > 0) {
      return p.videoCover ?? '';
    }
    return p.coverImage ?? '';
  }

  private genreLabel(genre?: string): string {
    if (genre === 'review') {
      return '测评报告';
    }
    if (genre === 'pitfall') {
      return '避坑指南';
    }
    if (genre === 'tutorial') {
      return '实操教程';
    }
    if (genre === 'debate') {
      return '辩论投票';
    }
    if (genre === 'share') {
      return '经验分享';
    }
    return '今日内容';
  }

  // —— 扇位几何（transform 专用：无布局属性变化） ——

  // 拖拽量（0→1，卡宽归一）：驱动“拿起”微胀与倾角
  private dragAmount(): number {
    const x: number = this.dragOffsetX;
    const y: number = this.dragOffsetY;
    return Math.min(1, Math.sqrt(x * x + y * y) / Math.max(this.deckWidth, 1));
  }

  private offsetX(): number {
    const d: number = Math.max(this.curDepth(), 0);
    if (d === 0) {
      return this.dragOffsetX;   // 顶卡主位移：跟手滑走（与原型一致，只有顶卡被拖动）
    }
    // 下层卡仅做小幅视差跟随（错峰），不整体平移
    return -d * DECK_FAN_X + this.dragOffsetX * DECK_PARAX[d];
  }

  private offsetY(): number {
    const d: number = Math.max(this.curDepth(), 0);
    if (d === 0) {
      // 入场仪式：顶卡从下方升起 DECK_RISE 像素（弹性回位），平时为 0；
      // 叠加竖直跟手位移 → 向上/向下都能拖走（自由拖动）
      return (1 - this.rise) * DECK_RISE + this.dragOffsetY;
    }
    // 下层：固有扇位纵深 + 竖直方向同样视差跟随（与水平同一套系数，物理一致）
    return d * DECK_FAN_Y + this.dragOffsetY * DECK_PARAX[d];
  }

  private angle(): number {
    const d: number = Math.max(this.curDepth(), 0);
    // 拖拽倾角：所有层同方向倾斜，幅度随深度递减（顶卡满幅，下层视差），
    // 每层独立慢弹簧 → 回弹时整叠“上下角度晃动”逐层错峰；
    // 竖直分量再叠一道小幅滚转，让纵向拖拽也有“卡片在手里翻”的松感
    const width: number = Math.max(this.deckWidth, 1);
    const tiltX: number = Math.max(-1, Math.min(1, (this.dragOffsetX / width) * 1.6)) * (-DECK_DRAG_TILT);
    const rollY: number = Math.max(-1, Math.min(1, this.dragOffsetY / width)) * DECK_DRAG_ROLL;
    const tilt: number = tiltX + rollY;
    if (d === 0) {
      return tilt;
    }
    return -d * DECK_FAN_ANGLE + tilt * DECK_PAR_ROT[d];
  }

  private cardScale(): number {
    const d: number = Math.max(this.curDepth(), 0);
    if (d === 0) {
      // 入场仪式：顶卡从 0.975 微胀到 1；拖拽时再抬 3% → “被拎起来”的实感
      return 1 - DECK_RISE_SCALE * (1 - this.rise) + this.dragAmount() * DECK_LIFT_SCALE;
    }
    // 下层热胀：拖得越远，底层轻微放大，增强“被带起来”的实感
    const warm: number = this.dragAmount() * DECK_WARM;
    return (1 - DECK_SLOT_SCALE * d) + warm;
  }

  private cardOpacity(): number {
    const d: number = Math.max(this.curDepth(), 0);
    if (d === 0) {
      return 1;
    }
    // 入场仪式：下层从其 30% 透明度淡入到角色值
    return Math.min(this.rise, 1) * DECK_FAN_OP[d];
  }

  @Builder
  textPoster(): void {
    // 无封面：编辑部衬线大字海报（t-seal 体裁印章 + 衬线正文）
    Column({ space: SpaceTokens.md }) {
      Text(this.genreLabel(this.post.genre))
        .fontSize(TypeTokens.overline.size).fontFamily(TypeTokens.fontFamily)
        .fontWeight(TypeTokens.overline.weight)
        .letterSpacing(4)
        .fontColor(ColorTokens.brand)
        .border({ width: 1, color: '#578A6548', style: BorderStyle.Solid })
        .borderRadius(RadiusTokens.pill)
        .padding({ left: SpaceTokens.md, right: SpaceTokens.md, top: SpaceTokens.inlineTight, bottom: SpaceTokens.inlineTight })
      Text(this.post.title ?? this.post.content ?? '一条值得读的经验')
        .fontSize(23).fontFamily(TypeTokens.fontFamilySerif)
        .fontWeight(TypeTokens.titleSerif.weight)
        .lineHeight(36)
        .fontColor(ColorTokens.primary)
        .maxLines(3)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .textAlign(TextAlign.Center)
        .padding({ left: 22, right: 22 })
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .linearGradient({ angle: 160, colors: [['#FFFCF3', 0], ['#F3EAD8', 1]] })
    .clip(true)
  }

  // 玻璃罩：模拟卡面上覆了一层玻璃，光在其表面反射。
  //
  // 玻璃质感的关键不是「加白」而是「明暗对比」—— 只做提亮，加多少层都像蒙了层
  // 白雾。五层各管一件事，各自缺了都不像玻璃：
  //   ① 边缘晕影（径向）：中心透亮、四周因玻璃厚度而变暗。整层里唯一的「减法」，
  //      也是「怎么调都不像玻璃」的根因 —— 之前五层全是加法
  //   ② 冷调受光（线性）：顶部偏亮、底部偏暗，并整体带冷色偏移。玻璃折射不中性，
  //      纯白反光会显塑料
  //   ③ 主反射：窄而锐的镜面高光，峰值 95%。真实镜面反光接近过曝且陡起陡落，
  //      前一版 34% 又软又淡，是「力度不够」的主因
  //   ④ 对角次反射：与主反射接近垂直的弱反射，对应玻璃的双向反射
  //   ⑤ 边缘高光：四周 1px 描边，玻璃切边比中心亮
  //
  // 边缘高光层刻意不设 borderRadius：遮罩顶边落在卡片外轮廓上，会被 postFace 的
  // clip(true) 自动裁成圆角；底边在卡片内部（与信息条相接处）须保持直角，否则会
  // 多出一道弧形亮线。
  //
  // hitTestBehavior(None) 不可省：遮罩铺满整个卡面，若参与命中测试会挡掉父层
  // PanGesture，卡片将完全拖不动。与 Image.draggable(false) 是同一类坑。
  @Builder
  sheenOverlay(): void {
    Stack() {
      // ① 边缘晕影：中心透亮 → 四周冷暗（玻璃厚度）
      Column()
        .width('100%')
        .height('100%')
        .radialGradient({
          center: ['50%', '50%'],
          radius: '76%',
          colors: [
            ['#00000000', 0],
            ['#00000000', 0.55],
            ['#16202A38', 0.84],
            ['#38202A38', 1],
          ],
        })
      // ② 冷调受光：顶部偏亮、底部偏暗，带一点冷色偏移
      Column()
        .width('100%')
        .height('100%')
        .linearGradient({
          angle: 160,
          colors: [
            ['#26C8DCFF', 0],
            ['#0ADCE8FF', 0.30],
            ['#10141E28', 0.72],
            ['#1C101A24', 1],
          ],
        })
      // ③ 主反射：窄而锐的镜面高光（陡起陡落，峰值 95%）
      Column()
        .width('100%')
        .height('100%')
        .linearGradient({
          angle: 118,
          colors: [
            ['#00FFFFFF', 0],
            ['#00FFFFFF', 0.10],
            ['#59FFFFFF', 0.155],
            ['#E6FFFFFF', 0.20],
            ['#F2FFFFFF', 0.235],
            ['#8CFFFFFF', 0.275],
            ['#1FFFFFFF', 0.325],
            ['#00FFFFFF', 0.375],
            ['#00FFFFFF', 1],
          ],
        })
      // ④ 对角次反射（峰值 54%）
      Column()
        .width('100%')
        .height('100%')
        .linearGradient({
          angle: 318,
          colors: [
            ['#00FFFFFF', 0],
            ['#00FFFFFF', 0.60],
            ['#40FFFFFF', 0.70],
            ['#8AFFFFFF', 0.775],
            ['#2EFFFFFF', 0.85],
            ['#00FFFFFF', 0.93],
            ['#00FFFFFF', 1],
          ],
        })
      // ⑤ 边缘高光
      Column()
        .width('100%')
        .height('100%')
        .border({ width: 1, color: '#66FFFFFF' })
    }
    .width('100%')
    .height('100%')
    .hitTestBehavior(HitTestMode.None)
  }

  // 卡面媒体区：4:3 封面（图片 + 角标 / 文字海报）。与信息条分离，
  // 「一镜到底」只飞这块媒体区，标题/作者等文字不参与缩放变形。
  @Builder
  mediaFace(): void {
    Stack({ alignContent: Alignment.TopStart }) {
      if (this.hasMedia()) {
        Image(resolveDisplayImageUrl(this.mediaUrl()))
          .id('deckCardMedia-' + String(this.post.id ?? ''))
          .width('100%')
          .height('100%')
          .objectFit(ImageFit.Cover)
          .backgroundColor(ColorTokens.sunken)
          // Image 的 draggable 默认为 true：长按后拖动会被系统拖拽接管，
          // 父层 PanGesture 收不到 Update → 表现就是“卡住拖不动”。卡面必须关掉。
          .draggable(false)
      } else {
        this.textPoster()
      }
      if (this.hasMedia()) {
        this.sheenOverlay()
      }
      if (this.hasMedia()) {
        // 角标：今日精选 · 体裁（top 12 / left 12）
        Text('今日精选 · ' + this.genreLabel(this.post.genre))
          .fontSize(10).fontFamily(TypeTokens.fontFamily)
          .letterSpacing(2)
          .fontColor('rgba(255, 252, 243, 0.92)')
          .backgroundColor('#56161410')
          .borderRadius(RadiusTokens.pill)
          .padding({ left: SpaceTokens.sm, right: SpaceTokens.sm, top: 3, bottom: 3 })
          .margin({ left: 12, top: 12 })
      }
    }
    .width('100%')
    .aspectRatio(DECK_MEDIA_RATIO)
    .backgroundColor(ColorTokens.sunken)
  }

  @Builder
  postFace(): void {
    Column() {
      // 卡面媒体区（详情页一镜到底以 componentUtils 定位此块屏幕帧作为起点，
      // 详情整页从该帧缩放展开；id 见本文件 deckCardMedia-{id}）
      this.mediaFace()

      // —— 信息区（封面下方独立白底条）：标题/作者/阅读数 + 右侧体裁印章 ——
      Row({ space: SpaceTokens.base }) {
        Column({ space: 5 }) {
          Text(this.post.title ?? '一条值得读的经验')
            .fontSize(15).fontFamily(TypeTokens.fontFamilySerif)
            .fontWeight(TypeTokens.titleSerif.weight)
            .lineHeight(21)
            .fontColor(ColorTokens.primary)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .width('100%')
            .textAlign(TextAlign.Start)
          Row({ space: SpaceTokens.xs }) {
            if ((this.post.user?.avatar ?? '').length > 0) {
              Image(resolveDisplayImageUrl(this.post.user?.avatar ?? ''))
                .width(20)
                .height(20)
                .borderRadius(RadiusTokens.pill)
                .objectFit(ImageFit.Cover)
                // 同上：头像也是 Image（draggable 默认 true），落在信息条上会截走拖拽
                .draggable(false)
            } else {
              Text((this.post.user?.nickname ?? '有据用户').slice(0, 1))
                .fontSize(10).fontFamily(TypeTokens.fontFamilySerif)
                .fontWeight(700)
                .fontColor(ColorTokens.brand)
                .width(20)
                .height(20)
                .textAlign(TextAlign.Center)
                .backgroundColor(ColorTokens.brandTint)
                .borderRadius(RadiusTokens.pill)
            }
            Text((this.post.user?.nickname ?? '有据用户') +
              ((this.post.viewCount ?? 0) > 0 ? (' · ' + formatCount(this.post.viewCount ?? 0) + ' 人读过') : ''))
              .fontSize(11).fontFamily(TypeTokens.fontFamily)
              .fontWeight(400)
              .fontColor(ColorTokens.secondary)
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
          }
          .alignItems(VerticalAlign.Center)
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)

        // 体裁印章（editorial seal）：右侧
        Text(this.genreLabel(this.post.genre))
          .fontSize(10).fontFamily(TypeTokens.fontFamily)
          .fontWeight(600)
          .letterSpacing(2)
          .fontColor(ColorTokens.brand)
          .border({ width: 1, color: '#578A6548', style: BorderStyle.Solid })
          .borderRadius(RadiusTokens.pill)
          .padding({ left: 9, right: 9, top: 3, bottom: 3 })
      }
      .width('100%')
      .height(70)
      .padding({ left: 14, right: 14, top: SpaceTokens.md, bottom: SpaceTokens.md })
      .alignItems(VerticalAlign.Center)
      .backgroundColor(ColorTokens.elevated)
    }
    .width('100%')
    .borderRadius(RadiusTokens.md)
    .clip(true)
    // 贴地细影：对应网页 0 2px 6px rgba(46,42,32,0.08)；落地大影由外层 Stack 叠加
    .shadow({ radius: 3, color: '#142E2A20', offsetY: 2 })
  }

  build() {
    if (this.inFlight || this.curDepth() >= 0) {
      // —— 位移层：位置 / 视差 / 抛出全部走槽位弹簧（跟手 + 摇晃） ——
      Stack() {
        // —— 旋转层：独立更慢的弹簧 → 角度滞后于位置，形成网页那种“晃动”相位差 ——
        Stack() {
          this.postFace()
        }
        // 以卡片底边为轴旋转：底部锚住、上半段甩动 → 回弹/推进时是“上下角度晃动”而非纯左右平移
        .rotate({ angle: this.inFlight ? this.flyRot : this.angle(), centerX: '50%', centerY: '100%' })
        .scale({ x: this.inFlight ? 1 : this.cardScale(), y: this.inFlight ? 1 : this.cardScale() })
        // 圆角对齐卡面；阴影挂在旋转层上 → 随卡片一起旋转，不再衬出“摆正的叠层影”
        .borderRadius(RadiusTokens.md)
        .shadow({ radius: 26, color: '#302E2A1C', offsetY: 9 })
        .animation({ duration: MotionTokens.slow,
          curve: this.inFlight ? MotionCurves.springRelease
            : DECK_ROT_SPRING[Math.min(Math.max(this.curDepth(), 0), DECK_ROT_SPRING.length - 1)],
          expectedFrameRateRange: MotionFrameRates.default })
      }
      .width('88%')
      // 自由拖动：X/Y 同源跟手；飞行卡沿「丢出单位向量」在 X、Y 上并行抛射
      .translate({
        x: this.inFlight ? this.flyX : this.offsetX(),
        y: this.inFlight ? this.flyY : this.offsetY(),
      })
      .opacity(this.inFlight ? 1 : this.cardOpacity())
      .zIndex(this.inFlight ? 30 : 10 - this.curDepth())
      .animation({ duration: MotionTokens.slow,
        curve: this.inFlight ? MotionCurves.springRelease
          : DECK_SPRING[Math.min(Math.max(this.curDepth(), 0), DECK_SPRING.length - 1)],
        expectedFrameRateRange: MotionFrameRates.default })
    }
  }
}

@Component
export struct DailyPostDeck {
  @Prop @Watch('resetDeck') deckVersion: number = 0;
  // posts / activeIndex 变化都意味着「顶卡换人」，两者都触发曝光上报
  @Prop @Watch('onExposureSourceChanged') posts: DailyPost[] = [];
  @Prop loading: boolean = false;
  @Prop finished: boolean = false;
  onLoadMore?: () => void = undefined;
  onOpen?: (post: DailyPost) => void = undefined;

  @State @Watch('onExposureSourceChanged') activeIndex: number = 0;
  @State dragOffsetX: number = 0;    // 跟手位移 X（双向：右为正、左为负）
  @State dragOffsetY: number = 0;    // 跟手位移 Y（双向：下为正、上为负）→ 不再局限于左右滑动
  @State advancing: boolean = false;
  @State deckWidth: number = 0;
  // 飞行卡（对应原型 S.FL）：被推进的旧顶卡独立抛射到屏外，全程可见
  @State flyPost: DailyPost | null = null;  // 正在飞走的旧顶帖（null = 无飞行卡）
  @State flyX: number = 0;                  // 飞行卡位移 X（沿丢出方向的水平分量）
  @State flyY: number = 0;                  // 飞行卡位移 Y（沿丢出方向的竖直分量）
  @State flyRot: number = 0;                // 飞行卡抛射倾角
  @State animRise: number = 0;       // 入场仪式：0→1（顶卡升起 + 整叠淡入）
  @State doneVisible: boolean = false;  // 完成态（读完全部）
  @State animStamp: number = 0;      // 完成态印章盖章动画
  @State countdownText: string = '--:--:--';
  // 距明日 0 点上新的倒计时计时器句柄（aboutToDisappear 时清理）
  private cdTimer: number = 0;
  // 已上报曝光的帖子 id：同会话内按 id 去重，避免回滑/重建时重复上报
  private exposedIds: Set<number> = new Set<number>();

  // 每日上新时刻：北京时间（UTC+8）0 点整 = 次日 00:00，即每日切换点
  // （与后端 dailyKey 的 Asia/Shanghai 日切口径一致）
  private static readonly DAILY_PUBLISH_HOUR: number = 0;
  // 计时/日切统一按北京时间：设备处于任意时区，倒计时目标与“今日”判定都不偏移
  private static readonly DAILY_TZ_OFFSET_MS: number = 8 * 60 * 60 * 1000;
  private static readonly DAY_MS: number = 86400000;

  // 丢出阈值：以「椭圆边界」判定（水平 38% 卡宽 / 竖直 33% 卡宽）。
  // 不用单一半径：卡片竖直方向的有效行程更短，椭圆边界让四个方向手感一致。
  // 0.30/0.26 时轻微一拖就过线，改为 0.38/0.33 后需要明确的拖动行程才丢出
  private readonly dismissRatioX: number = 0.38;
  private readonly dismissRatioY: number = 0.33;
  private readonly deckVisualScale: number = 1; // 卡堆无整体缩放（与原型一致）

  aboutToAppear(): void {
    // 当日已读持久化：同一天再次打开直接进入完成态
    PersistentStorage.persistProp<string>('youjuDailyReadDate', '');
    if (this.restoreReadState()) {
      return;
    }
    this.startRitual();
  }

  aboutToDisappear(): void {
    if (this.cdTimer !== 0) {
      clearInterval(this.cdTimer);
      this.cdTimer = 0;
    }
    // H-9：清理 advance/resetDrag 的延时回调，避免组件销毁后回调访问失效状态
    for (const t of this.pendingTimers) {
      clearTimeout(t);
    }
    this.pendingTimers = [];
  }

  // ===== 逐卡曝光埋点 =====
  // 此前「每日一贴」只有点击与「进入每日页」两类上报，缺逐卡曝光 → 场景化曝光-点击率无法计算。
  // 语义：某卡成为顶卡（滑入）即计一次曝光；按 postId 去重，回滑不重复上报。
  private onExposureSourceChanged(): void {
    this.trackActiveExpose();
  }

  private trackActiveExpose(): void {
    const list: DailyPost[] = this.posts;
    const idx: number = this.activeIndex;
    if (idx < 0 || idx >= list.length) {
      return;
    }
    const post: DailyPost = list[idx];
    const id: number | undefined = post.id;
    if (id === undefined || this.exposedIds.has(id)) {
      return;
    }
    this.exposedIds.add(id);
    trackPostEvent(id, 'expose', 'daily');
  }

  resetDeck(): void {
    this.activeIndex = 0;
    this.dragOffsetX = 0;
    this.dragOffsetY = 0;
    this.advancing = false;
    this.flyPost = null;

    // deckVersion 会在切换 Tab 或刷新数据时变化。恢复当天已读状态，
    // 避免组件重置把「今日一帖 · 已读完」误清成未读卡堆。
    if (this.restoreReadState()) {
      return;
    }

    this.doneVisible = false;
    this.animStamp = 0;
    this.startRitual();
  }

  // 从持久化状态恢复完成态。完成态不只由 doneVisible 决定：
  // 印章的可见性由 animStamp 控制，倒计时也必须在组件重新出现后重新启动。
  private restoreReadState(): boolean {
    // 本会话内点过「重新阅读」：即使持久化写盘存在异步竞态（磁盘仍残留当日标记），
    // 也按未读处理 —— 防止切 Tab 重建后 persistProp 读回旧值误恢复「已读完」。
    // 冷启动时 AppStorage 无此键（undefined），仍按持久化正常恢复。
    const reset: boolean = AppStorage.get<boolean>('youjuDailyReadReset') === true;
    const readDate: string = (AppStorage.get<string>('youjuDailyReadDate') ?? '');
    if (reset) {
      return false;
    }
    if (readDate !== this.todayStr()) {
      return false;
    }

    this.doneVisible = true;
    this.animStamp = 1;
    this.startCountdown();
    return true;
  }

  // 当日标记（Asia/Shanghai）：与后端日切点/报头日期同口径，
  // 避免设备时区非 +8 时“今日已读”在跨零点前后误判（重复出仪式或提前清零）
  private todayStr(): string {
    const d: Date = new Date(Date.now() + DailyPostDeck.DAILY_TZ_OFFSET_MS);
    return d.getUTCFullYear() + '-' + (d.getUTCMonth() + 1) + '-' + d.getUTCDate();
  }

  // 入场仪式：顶卡升起（一档弹性）+ 整叠淡入；骨架已在 loading 态呈现
  private startRitual(): void {
    this.animRise = 0;
    this.getUIContext().animateTo({
      duration: MotionTokens.emphasis,
      curve: MotionCurves.springRelease,
      expectedFrameRateRange: MotionFrameRates.default,
    }, () => {
      this.animRise = 1;
    });
    // 仪式开始时顶卡即为可见状态 → 补报一次曝光（posts 为空时内部自动跳过）
    this.trackActiveExpose();
  }

  private visiblePosts(): DailyPost[] {
    return this.posts.slice(this.activeIndex, this.activeIndex + DECK_VISIBLE);
  }

  // 丢出进度（0→1，1 即越过椭圆边界）：把 (x,y) 投影到「归一化丢出空间」取模长，
  // 于是斜向丢出是水平/竖直两个阈值的合成，不需要为 8 个方向各写一套判定
  private outProgress(px: number, py: number): number {
    const width: number = Math.max(this.deckWidth, 1) * this.deckVisualScale;
    const nx: number = px / (width * this.dismissRatioX);
    const ny: number = py / (width * this.dismissRatioY);
    return Math.sqrt(nx * nx + ny * ny);
  }

  // 堆底影淡出（0→1）：顶卡被拖拽/推进时隐去整体厚度影，
  // 避免顶卡移开后原地露出「残留虚卡」；回弹/复位后随卡片一起恢复。
  // 拖过卡宽 30% 即完全淡出（早于丢出阈值 38%，丢出全程无残留）。
  private deckShadowFade(): number {
    const width: number = Math.max(this.deckWidth, 1);
    const drag: number = Math.sqrt(this.dragOffsetX * this.dragOffsetX + this.dragOffsetY * this.dragOffsetY);
    const dragFade: number = Math.min(1, drag / (width * 0.30));
    // 推进（顶卡飞出 + 下层滑入）期间保持淡出，新顶卡归位后再恢复
    return this.advancing ? 1 : dragFade;
  }

  // 统一登记延时回调：组件销毁时统一清理，避免回调访问已销毁的状态（H-9）
  private pendingTimers: number[] = [];

  private schedule(fn: () => void, ms: number): void {
    this.pendingTimers.push(setTimeout((): void => { fn(); }, ms) as number);
  }

  private resetDrag(vx: number, vy: number): void {
    // 未过阈值 → 松开手指。速度越快 → 惯性过冲越大 → 回弹晃动幅度越大（对应网页速度连续）
    const width: number = Math.max(this.deckWidth, 1);
    const x: number = this.dragOffsetX;
    const y: number = this.dragOffsetY;
    const len: number = Math.sqrt(x * x + y * y);
    const speed: number = Math.sqrt(vx * vx + vy * vy);
    // 过冲位移：随速度线性放大；上限放到卡宽 24%，让快速甩动有更充分的“过头再回”幅度，
    // 但仍明显低于丢出阈值（30%），不会误触发翻页
    const boost: number = Math.min(Math.max(0, speed * 0.055), width * 0.24);
    if (boost > 2 && len > 0.5) {
      // 过冲沿「松手方向」而非水平轴：竖直/斜向拖拽同样有“甩出去又弹回”的手感
      const ux: number = x / len;
      const uy: number = y / len;
      // 第一段：向拖动方向惯性滑出（快速短冲程，稍长一点让冲程更“实”）
      this.getUIContext().animateTo({
        duration: 150,
        curve: MotionCurves.decelerate,
        expectedFrameRateRange: MotionFrameRates.default,
      }, () => {
        this.dragOffsetX += boost * ux;
        this.dragOffsetY += boost * uy;
      });
      // 第二段：过冲到底交棒给各卡弹簧回弹——位移层走顶卡弹簧(0.30/0.58)圆滑归位，
      // 旋转层错峰摆动，整叠一次到位不抖尾
      this.schedule((): void => {
        this.dragOffsetX = 0;
        this.dragOffsetY = 0;
      }, 190);
    } else {
      // 慢速轻拖：直接由各卡弹簧回弹
      this.dragOffsetX = 0;
      this.dragOffsetY = 0;
    }
  }

  // 丢出（任意方向）：px/py 为「位移 + 速度投影」的合成向量，
  // 单位化后即为旧顶卡的抛射方向 —— 方向由用户手势决定，代码不预设左右
  private throwOut(px: number, py: number): void {
    if (this.advancing || this.activeIndex >= this.posts.length) {
      return;
    }
    this.advancing = true;
    const width: number = Math.max(this.deckWidth, 1);
    // 卡高 = 88% 卡宽 × 4:3 媒体 + 70 信息条（与 DeckSlotCard 的布局一致）
    const cardHeight: number = width * 0.88 * 0.75 + 70;
    const len: number = Math.sqrt(px * px + py * py);
    // 兜底：位移与速度都近似为 0 时退回水平方向，保证一定能出屏
    const ux: number = len > 0.5 ? px / len : 1;
    const uy: number = len > 0.5 ? py / len : 0;
    // 抛射行程须能完全盖住屏幕：取「卡宽 / 卡高」较大者为基准
    const travel: number = Math.max(width, cardHeight) * 1.6 + 240;
    const top: DailyPost | undefined = this.posts[this.activeIndex];
    if (top !== undefined) {
      // —— 发射飞行卡：旧顶卡从当前跟手位置带速度抛射到屏外（对应原型 S.FL）——
      // 起点继承当前跟手位移与倾角，全程保持不透明度，出屏后才由父层销毁。
      this.flyPost = top;
      this.flyX = this.dragOffsetX;
      this.flyY = this.dragOffsetY;
      this.flyRot = Math.max(-1, Math.min(1, (this.dragOffsetX / width) * 1.6)) * (-DECK_DRAG_TILT);
      this.getUIContext().animateTo({
        duration: MotionTokens.slow,
        curve: MotionCurves.springRelease,
        expectedFrameRateRange: MotionFrameRates.default,
      }, () => {
        // 沿单位向量飞到屏外远端：水平丢与竖直丢走同一条物理路径，只差方向
        this.flyX = ux * travel;
        this.flyY = uy * travel;
        // 抛射倾角由方向决定：纯水平丢满幅滚转，纯竖直丢几乎不转
        this.flyRot = ux * -14;
      });
      this.schedule((): void => { this.flyPost = null; }, 460);
    } else {
      this.flyPost = null;
    }
    // 推进：activeIndex 前移 + 顶卡跟手位移清零，不包统一曲线 ——
    // 各卡按自身槽位弹簧回正（下层带旋转错峰滑入），飞行卡并行抛射
    this.activeIndex += 1;
    this.dragOffsetX = 0;
    this.dragOffsetY = 0;
    if (this.activeIndex + 1 >= this.posts.length - DECK_VISIBLE + 1 && !this.finished) {
      this.onLoadMore?.();
    }
    // 读完最后一张 → 完成仪式。
    // 语义：activeIndex 从 0 起推进，推掉第 N 张后 activeIndex=N；
    // 只有推进到 activeIndex >= posts.length（最后一张也已被推出）才完成，
    // 否则仍差一张时（如 2 张读完第 1 张）就误入完成态。
    if (this.activeIndex >= this.posts.length) {
      this.schedule((): void => { this.showDone(); }, 560);
    }
    // 推进闸门再收紧：新顶卡弹簧（response 0.30s）约 90% 就位时即可解锁下一张，
    // 飞行卡仍按 460ms 独立抛射销毁（不改动）。
    this.schedule((): void => { this.advancing = false; }, 400);
  }

  private onTopPanUpdate(event: GestureEvent): void {
    if (this.advancing || this.doneVisible) {
      return;
    }
    // 双向跟手：X 右正左负、Y 下正上负（对应原型 S.x 可正可负）——四个方向都跟手
    this.dragOffsetX = event.offsetX;
    this.dragOffsetY = event.offsetY;
  }

  private onTopPanEnd(event?: GestureEvent): void {
    if (this.advancing || this.doneVisible) {
      return;
    }
    const width: number = Math.max(this.deckWidth, 1);
    const vx: number = event?.velocityX ?? 0;
    const vy: number = event?.velocityY ?? 0;
    const x: number = this.dragOffsetX;
    const y: number = this.dragOffsetY;
    const real: number = Math.sqrt(x * x + y * y);
    const speed: number = Math.sqrt(vx * vx + vy * vy);
    // 「拖动意图」门槛：位移不够就只是一次抖动，速度不参与判定 ——
    // 否则 px = x + vx*0.16 会凭空凑出满阈值行程，卡片被误丢出去
    const committed: boolean = real > width * DECK_FLING_MIN_DIST;
    // 惯性投影：松手后速度还会带出一段行程（对应 GSAP Draggable 的 inertia: true，
    // InertiaPlugin 用速度预测终点 end 再 glide 过去）—— 所以“快速小距离甩”也能丢出去
    const px: number = x + (committed ? vx * DECK_INERTIA_PROJECT : 0);
    const py: number = y + (committed ? vy * DECK_INERTIA_PROJECT : 0);
    // 轻甩：速度够大且已有明确拖动 → 不等阈值直接丢出
    const fling: boolean = speed > DECK_FLING_MIN_VEL && committed;
    if (this.outProgress(px, py) >= 1 || fling) {
      this.throwOut(px, py);
      return;
    }
    // 未过阈值：按松手速度回弹——速度越快过冲越大、晃动越明显
    this.resetDrag(vx, vy);
  }

  private openActivePost(): void {
    const activePost = this.posts[this.activeIndex];
    if (!this.advancing && !this.doneVisible && activePost !== undefined) {
      this.onOpen?.(activePost);
    }
  }

  // —— 入场仪式：顶卡升起 / 下层淡入的几何见 DeckSlotCard ——
  // —— 完成态 ——
  private showDone(): void {
    if (this.doneVisible) {
      return;
    }
    this.doneVisible = true;
    // 真正读完才落盘当日标记，并清除「会话内已重新阅读」标记
    AppStorage.setOrCreate<boolean>('youjuDailyReadReset', false);
    AppStorage.setOrCreate<string>('youjuDailyReadDate', this.todayStr());
    this.animateStamp();
    this.startCountdown();
  }

  private replay(): void {
    this.doneVisible = false;
    // 读完时 activeIndex 已推进到 posts.length，visiblePosts() 会返回空数组；
    // 必须复位卡堆状态，否则覆盖层消失后露出的是空白卡堆。
    this.activeIndex = 0;
    this.dragOffsetX = 0;
    this.dragOffsetY = 0;
    this.advancing = false;
    this.flyPost = null;
    // 会话内标记：此后（直到真正读完）任何重建都不再恢复「已读完」，
    // 兜底持久化异步写盘的竞态（详见 restoreReadState）。
    AppStorage.setOrCreate<boolean>('youjuDailyReadReset', true);
    // 清除当日已读持久化标记：重新阅读后，切 Tab/组件重建触发 resetDeck →
    // restoreReadState 不得再把「已读完」恢复回来（否则一篇未读也会直接显示完成态）。
    // 只有真正读完（showDone）才重新写入。
    AppStorage.setOrCreate<string>('youjuDailyReadDate', '');
    this.startRitual();
  }

  private animateStamp(): void {
    this.animStamp = 0;
    this.getUIContext().animateTo({
      duration: 620,
      curve: MotionCurves.spring,
      expectedFrameRateRange: MotionFrameRates.default,
    }, () => {
      this.animStamp = 1;
    });
  }

  private startCountdown(): void {
    if (this.cdTimer !== 0) {
      return;
    }
    this.tickCountdown();
    this.cdTimer = setInterval((): void => {
      this.tickCountdown();
    }, 1000) as number;
  }

  private tickCountdown(): void {
    // 目标 = 北京时间次日 00:00 整（与后端日切点一致）。
    // 用「北京时间戳 / 一天」取整定位当日零点，避免设备时区非 +8 时把目标算成当地 0 点
    // （那会与内容真实切换时刻错开数小时，看起来像“每日 9 点刷新”）。
    const beijingMs: number = Date.now() + DailyPostDeck.DAILY_TZ_OFFSET_MS;
    const nextPublishMs: number =
      (Math.floor(beijingMs / DailyPostDeck.DAY_MS) + 1) * DailyPostDeck.DAY_MS +
      DailyPostDeck.DAILY_PUBLISH_HOUR * 3600000;
    let s: number = Math.max(0, Math.floor((nextPublishMs - beijingMs) / 1000));
    const h: string = String(Math.floor(s / 3600)).padStart(2, '0');
    const m: string = String(Math.floor((s % 3600) / 60)).padStart(2, '0');
    s = s % 60;
    this.countdownText = h + ':' + m + ':' + String(s).padStart(2, '0');
  }

  // 骨架（数据未到）：半透明占位卡呼吸（结构与实体卡一致：4:3 封面 + 信息条）
  @Builder
  skeletonCard(index: number): void {
    Column() {
      Column()
        .width('100%')
        .aspectRatio(DECK_MEDIA_RATIO)
        .linearGradient({ angle: 110, colors: [['#EDE5CF', 0.3], ['#F7F1E4', 0.42], ['#EDE5CF', 0.54]] })
      Column({ space: SpaceTokens.xs }) {
        Row().width('70%').height(16).borderRadius(4).backgroundColor(ColorTokens.skeletonBase)
        Row().width('45%').height(10).borderRadius(4).backgroundColor(ColorTokens.skeletonBase)
      }
      .width('100%')
      .height(70)
      .padding({ left: 14, right: 14, top: SpaceTokens.md, bottom: SpaceTokens.md })
      .alignItems(HorizontalAlign.Start)
      .backgroundColor(ColorTokens.elevated)
    }
    .width('100%')
    .borderRadius(RadiusTokens.md)
    .clip(true)
    .opacity(0.86 - index * 0.14)
  }

  // 完成态覆盖层：已读印章 + 副题 + 明日上新倒计时 + 重新阅读
  @Builder
  doneOverlay(): void {
    Column({ space: SpaceTokens.base }) {
      Stack({ alignContent: Alignment.Center }) {
        Column()
          .width(92).height(92)
          .borderRadius(RadiusTokens.pill)
          .border({ width: 2, color: '#998A6548', style: BorderStyle.Solid })
          .scale({ x: this.animStamp, y: this.animStamp })
          .opacity(this.animStamp)
        Text('已 读')
          .fontSize(18).fontFamily(TypeTokens.fontFamilySerif)
          .fontWeight(TypeTokens.titleSerif.weight)
          .letterSpacing(4)
          .fontColor(ColorTokens.brand)
          .rotate({ angle: -8 })
          .scale({ x: this.animStamp, y: this.animStamp })
          .opacity(this.animStamp)
      }
      .width(110).height(110)

      Text('今日一帖 · 已读完')
        .fontSize(24).fontFamily(TypeTokens.fontFamilySerif)
        .fontWeight(TypeTokens.titleSerif.weight)
        .letterSpacing(4)
        .fontColor(ColorTokens.primary)
      Text('一期一会 · 有据编辑部')
        .fontSize(TypeTokens.caption.size).fontFamily(TypeTokens.fontFamily)
        .fontWeight(TypeTokens.caption.weight)
        .letterSpacing(3)
        .fontColor(ColorTokens.tertiary)
      // 上新倒计时：与顶部「推荐/关注」分段栏同款（outlined 描边风格）
      // 规格对齐 SegmentedControl.outlined 分支：透明底 + barBorder 细描边（glassBorderWidth）
      // + RadiusTokens.lg 圆角 + 无背景模糊 + 无阴影（与右上角搜索按钮同一描边语言）；
      // 高度同 segmentedHeight，文字走 callout 令牌层级（选中项：primary + headline 字重）
      Row({ space: SpaceTokens.sm }) {
        Text('距明日 00:00 上新')
          .fontSize(TypeTokens.callout.size).fontFamily(TypeTokens.fontFamily)
          .fontWeight(TypeTokens.callout.weight)
          .lineHeight(TypeTokens.callout.lineHeight)
          .letterSpacing(TypeTokens.callout.tracking)
          .fontColor(ColorTokens.secondary)
        Text(this.countdownText)
          .fontSize(TypeTokens.callout.size).fontFamily(TypeTokens.fontFamily)
          .fontWeight(TypeTokens.headline.weight)
          .lineHeight(TypeTokens.callout.lineHeight)
          .letterSpacing(TypeTokens.callout.tracking)
          .fontColor(ColorTokens.primary)
          .fontFeature(TypeTokens.tabularFeature)
      }
      .height(LayoutTokens.segmentedHeight)
      .padding({ left: SpaceTokens.md, right: SpaceTokens.md })
      .alignItems(VerticalAlign.Center)
      .backgroundColor(Color.Transparent)
      .borderRadius(RadiusTokens.lg)
      .border({ width: LayoutTokens.glassBorderWidth, color: ColorTokens.barBorder, style: BorderStyle.Solid })
      .clip(true)

      Pressable({
        visualHeight: TypeTokens.caption.lineHeight,
        action: (): void => { this.replay(); },
      }) {
        Text('重新阅读今天的仪式')
          .fontSize(TypeTokens.caption.size).fontFamily(TypeTokens.fontFamily)
          .letterSpacing(2)
          .fontColor(ColorTokens.brand)
      }
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .backgroundColor(ColorTokens.canvas)
    .borderRadius(RadiusTokens.xl)
    .transition(TransitionEffect.OPACITY.animation({ duration: 550, curve: MotionCurves.decelerate }))
  }

  build() {
    Stack({ alignContent: Alignment.Center }) {
      Column() {
        if (this.posts.length === 0 && this.loading) {
          // 骨架：四层占位呼吸（时刻占据舞台，避免布局跳动）
          Column({ space: SpaceTokens.sm }) {
            ForEach([0, 1, 2, 3], (i: number) => {
              this.skeletonCard(i)
            })
          }
          .width('88%')
          .height('100%')
        } else {
          // 舞台：跟手位移/微倾直绑（每张卡均不挂动画 → 拖拽即时跟手）；回稳/推进由 animateTo 驱动。
          // 骨架 / 完成态 / 追加加载 均在此范围内布局。
          Stack({ alignContent: Alignment.Center }) {
            // —— 卡堆整体厚度影：贴地投影，模拟整叠卡的实体厚度 ——
            // 载体为极淡暖纸色（约 5%，几乎不可见），仅提供阴影形状；
            // 阴影（34/16）比单卡（26/9）更深更厚 → 整叠卡立在桌面上的实感。
            // 静止不跟随拖拽：顶卡被拿起/丢出时堆影留在原位。
            // 结构与实体卡一致（4:3 媒体区 + 70 信息条），尺寸随布局自适应。
            Column() {
              Column()
                .width('100%')
                .aspectRatio(DECK_MEDIA_RATIO)
                .backgroundColor('#0DFFFCF3')
              Column()
                .width('100%')
                .height(70)
                .backgroundColor('#0DFFFCF3')
            }
            .width('88%')
            .borderRadius(RadiusTokens.md)
            .clip(true)
            .shadow({ radius: 34, color: '#452E2A20', offsetY: 16 })
            .zIndex(0)
            .opacity(this.animRise * (1 - this.deckShadowFade()))

            ForEach(this.visiblePosts(), (post: DailyPost) => {
              DeckSlotCard({
                post: post,
                anchor: this.activeIndex,
                posts: this.posts,
                deckWidth: this.deckWidth,
                dragOffsetX: this.dragOffsetX,
                dragOffsetY: this.dragOffsetY,
                rise: this.animRise,
              })
            }, (post: DailyPost) => String(post.id ?? 'deck-' + post.title?.slice(0, 12)))

            // 飞行卡（对应原型 S.FL）：旧顶卡被推进时独立抛射到屏外，全程可见
            if (this.flyPost !== null) {
              DeckSlotCard({
                post: this.flyPost,
                anchor: this.activeIndex,
                posts: this.posts,
                deckWidth: this.deckWidth,
                dragOffsetX: this.dragOffsetX,
                dragOffsetY: this.dragOffsetY,
                rise: 1,
                inFlight: true,
                flyX: this.flyX,
                flyY: this.flyY,
                flyRot: this.flyRot,
              })
            }
          }
          .width('100%')
          .layoutWeight(1)
          .gesture(
            // 自由拖动：取消方向约束（原为 PanDirection.Horizontal），四个方向都可拖、可丢。
            // 每日一帖所在容器是无滚动 Column，且已禁用下拉刷新 → 竖直手势不会与任何父级滚动竞争。
            PanGesture({ direction: PanDirection.All, distance: 4 })
              .onActionUpdate((event: GestureEvent): void => { this.onTopPanUpdate(event); })
              .onActionEnd((event: GestureEvent): void => { this.onTopPanEnd(event); })
              .onActionCancel((event: GestureEvent): void => { this.onTopPanEnd(event); })
          )
          .onClick((): void => { this.openActivePost(); })

          // 读到末尾仍在追加时：轻量加载态
          if (this.activeIndex >= this.posts.length && this.loading) {
            Column() {
              LoadingProgress().width(36).height(36)
            }
            .width('100%')
            .height('100%')
            .justifyContent(FlexAlign.Center)
          }

          // 底部：进度 + 拖拽提示（对应原型 deck-foot：完成态隐藏提示，仅留进度）
          Column({ space: SpaceTokens.inlineTight }) {
            Text(this.pagStr())
              .fontSize(11).fontFamily(TypeTokens.fontFamily)
              .letterSpacing(3)
              .fontColor(ColorTokens.tertiary)
              .fontFeature(TypeTokens.tabularFeature)
            if (!this.doneVisible) {
              Text('随手拖 · 任意方向丢出换下一张')
                .fontSize(10).fontFamily(TypeTokens.fontFamily)
                .letterSpacing(2)
                .fontColor(ColorTokens.tertiary)
                .border({ width: 1, color: ColorTokens.separator, style: BorderStyle.Solid })
                .borderRadius(RadiusTokens.pill)
                .padding({ left: SpaceTokens.md, right: SpaceTokens.md, top: SpaceTokens.inlineTight, bottom: SpaceTokens.inlineTight })
                .backgroundColor('#CCFFFCF3')
            }
          }
          .width('100%')
          .alignItems(HorizontalAlign.Center)
          .padding({ top: SpaceTokens.sm, bottom: SpaceTokens.base })
        }
      }
      .width('100%')
      .height('100%')

      // 完成态覆盖层（盖住整个每日一帖区域，含底部提示）
      if (this.doneVisible) {
        this.doneOverlay()
      }
    }
    .width('100%')
    .height('100%')
    // 收紧横向留白让卡堆更饱满（原 lg=20 → md=12）；底部预留悬浮 Dock 高度
    .padding({ left: SpaceTokens.md, right: SpaceTokens.md, top: SpaceTokens.sm, bottom: barBottomReserve() })
    .onAreaChange((_old: Area, next: Area) => {
      this.deckWidth = next.width as number;
    })
  }

  private pagStr(): string {
    // 总数 = 实际拉取到的精选条数（后端有多少条就显示多少，不做虚假填充）；
    // 前后端语义一致：每日精选固定上限 DAILY_PICK_LIMIT=10，数据不足时按实际显示。
    const total: number = Math.max(1, this.posts.length);
    return String(Math.min(this.activeIndex + 1, total)).padStart(2, '0') + ' / ' + String(total).padStart(2, '0');
  }
}
