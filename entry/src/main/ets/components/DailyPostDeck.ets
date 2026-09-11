import { DailyPost } from '../models/types';
import { resolveDisplayImageUrl } from '../services/api';
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
const DECK_RISE: number = 26;           // 入场仪式：顶卡升起行程
const DECK_RISE_SCALE: number = 0.025;  // 入场仪式：顶卡缩放（1 → 0.975 之间）
const DECK_MEDIA_RATIO: number = 4 / 3; // 卡面 4:3（原型 aspect-ratio: 4/3）
const DECK_SLOT_SCALE: number = 0.028;  // 下层逐层缩小（原型 1 - 0.028*role）
const DECK_WARM: number = 0.06;         // 顶卡抬起时下层微胀最大值（原型 warm*0.06）
const DECK_VISIBLE: number = 4;     // 四槽：顶 / 中 / 底 / 预备
// 顶/中/底/预备 恒定不透明度（全程无淡入，只做位移与旋转；入场时下层从其 30% 淡入）
const DECK_FAN_OP: number[] = [1, 0.86, 0.72, 0.45];
// 拖拽视差：下层卡随顶卡偏移的跟随系数（顶到预备逐层递减；预备层不跟随）
const DECK_PARAX: number[] = [0, 0.13, 0.06, 0];
// 拖拽视差倾角：拖动时下层卡也随顶卡方向倾斜（顶卡最多、逐层递减），回弹时各自滞后归位
const DECK_PAR_ROT: number[] = [0, 0.30, 0.18, 0.08];
// 各槽位弹簧（对应原型每张卡独立扇位弹簧：顶卡最弹、越往后越稳，
// 回弹/推进时按各自频率振荡 → 下层卡跟随顶卡产生自然的“摇晃”）
const DECK_SPRING: ICurve[] = [
  curves.springMotion(0.28, 0.58),  // 顶卡：响应最快、回弹最明显
  curves.springMotion(0.34, 0.64),  // 中卡
  curves.springMotion(0.40, 0.70),  // 底卡
  curves.springMotion(0.46, 0.76),  // 预备卡：最收敛
];
// 旋转专用弹簧：比位移更慢、阻尼更低 → 角度滞后于位置，形成网页那种“晃动”相位差
const DECK_ROT_SPRING: ICurve[] = [
  curves.springMotion(0.52, 0.48),  // 顶卡角度：最易摆
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
  @Prop dragOffsetX: number = 0;     // 顶卡跟手位移 → 下层视差跟随
  @Prop dragDir: number = 1;         // 拖拽方向 ±1：决定飞出朝向与抛射旋转方向（对应原型 dir=±1）
  @Prop rise: number = 1;            // 入场仪式 0→1：顶卡升起 + 下层淡入
  // —— 飞行模式（旧顶卡被推进时独立抛射到屏外，对应原型 S.FL）——
  @Prop inFlight: boolean = false;   // true：本卡不再参与堆叠，仅按飞行参数渲染
  @Prop flyX: number = 0;            // 飞行卡当前水平位移（弹簧甩出）
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
      // 入场仪式：顶卡从下方升起 DECK_RISE 像素（弹性回位），平时为 0
      return (1 - this.rise) * DECK_RISE;
    }
    return d * DECK_FAN_Y;
  }

  private angle(): number {
    const d: number = Math.max(this.curDepth(), 0);
    // 拖拽倾角：所有层同方向倾斜，幅度随深度递减（顶卡满幅，下层视差），
    // 每层独立慢弹簧 → 回弹时整叠“上下角度晃动”逐层错峰
    const width: number = Math.max(this.deckWidth, 1);
    const tilt: number = Math.max(-1, Math.min(1, (this.dragOffsetX / width) * 1.6)) * (-DECK_DRAG_TILT);
    if (d === 0) {
      return tilt;
    }
    return -d * DECK_FAN_ANGLE + tilt * DECK_PAR_ROT[d];
  }

  private cardScale(): number {
    const d: number = Math.max(this.curDepth(), 0);
    if (d === 0) {
      // 入场仪式：顶卡从 0.975 微胀到 1
      return 1 - DECK_RISE_SCALE * (1 - this.rise);
    }
    // 下层热胀：拖得越远，底层轻微放大，增强“被带起来”的实感
    const warm: number = Math.min(Math.abs(this.dragOffsetX) / Math.max(this.deckWidth, 1), 1) * DECK_WARM;
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

  @Builder
  postFace(): void {
    Column() {
      // —— 卡面：4:3（图片 + 角标 / 文字海报）——
      Stack({ alignContent: Alignment.TopStart }) {
        if (this.hasMedia()) {
          Image(resolveDisplayImageUrl(this.mediaUrl()))
            .width('100%')
            .height('100%')
            .objectFit(ImageFit.Cover)
            .backgroundColor(ColorTokens.sunken)
        } else {
          this.textPoster()
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
      .translate({ x: this.inFlight ? this.flyX : this.offsetX(), y: this.inFlight ? 0 : this.offsetY() })
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
  @Prop posts: DailyPost[] = [];
  @Prop loading: boolean = false;
  @Prop finished: boolean = false;
  onLoadMore?: () => void = undefined;
  onOpen?: (post: DailyPost) => void = undefined;

  @State activeIndex: number = 0;
  @State dragOffsetX: number = 0;    // 跟手位移（双向：向右为正、向左为负）
  @State dragDir: number = 1;        // 拖拽方向：+1 右 / -1 左（决定飞出朝向）
  @State advancing: boolean = false;
  @State deckWidth: number = 0;
  // 飞行卡（对应原型 S.FL）：被推进的旧顶卡独立抛射到屏外，全程可见
  @State flyPost: DailyPost | null = null;  // 正在飞走的旧顶帖（null = 无飞行卡）
  @State flyX: number = 0;                  // 飞行卡当前水平位移
  @State flyRot: number = 0;                // 飞行卡抛射倾角
  @State animRise: number = 0;       // 入场仪式：0→1（顶卡升起 + 整叠淡入）
  @State doneVisible: boolean = false;  // 完成态（读完全部）
  @State animStamp: number = 0;      // 完成态印章盖章动画
  @State countdownText: string = '--:--:--';
  // 距明日 0 点上新的倒计时计时器句柄（aboutToDisappear 时清理）
  private cdTimer: number = 0;

  // 每日上新时刻：北京时间（UTC+8）0 点整 = 次日 00:00，即每日切换点
  // （与后端 dailyKey 的 Asia/Shanghai 日切口径一致）
  private static readonly DAILY_PUBLISH_HOUR: number = 0;
  // 计时/日切统一按北京时间：设备处于任意时区，倒计时目标与“今日”判定都不偏移
  private static readonly DAILY_TZ_OFFSET_MS: number = 8 * 60 * 60 * 1000;
  private static readonly DAY_MS: number = 86400000;

  private readonly dismissRatio: number = 0.3;
  private readonly deckVisualScale: number = 1; // 卡堆无整体缩放（与原型一致）

  aboutToAppear(): void {
    // 当日已读持久化：同一天再次打开直接进入完成态
    PersistentStorage.persistProp<string>('youjuDailyReadDate', '');
    const readDate: string = (AppStorage.get<string>('youjuDailyReadDate') ?? '');
    if (readDate === this.todayStr()) {
      this.doneVisible = true;
      return;
    }
    this.startRitual();
  }

  aboutToDisappear(): void {
    if (this.cdTimer !== 0) {
      clearInterval(this.cdTimer);
      this.cdTimer = 0;
    }
  }

  resetDeck(): void {
    this.activeIndex = 0;
    this.dragOffsetX = 0;
    this.advancing = false;
    this.flyPost = null;
    this.doneVisible = false;
    this.startRitual();
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
  }

  private visiblePosts(): DailyPost[] {
    return this.posts.slice(this.activeIndex, this.activeIndex + DECK_VISIBLE);
  }

  private dismissDistance(): number {
    return Math.max(this.deckWidth, 1) * this.deckVisualScale * this.dismissRatio;
  }

  private resetDrag(vel: number): void {
    // 未过阈值 → 松开手指。速度越快 → 惯性过冲越大 → 回弹晃动幅度越大（对应网页速度连续）
    const width: number = Math.max(this.deckWidth, 1);
    // 过冲位移：随速度线性放大，但钳制在翻页阈值内（约 60% 阈值），避免误触发翻页
    const boost: number = Math.min(Math.max(0, vel * 0.035), width * 0.18);
    if (boost > 3) {
      // 第一段：向拖动方向惯性滑出（快速短冲程），制造“甩出去又弹回”的过冲
      this.getUIContext().animateTo({
        duration: 120,
        curve: MotionCurves.decelerate,
        expectedFrameRateRange: MotionFrameRates.default,
      }, () => {
        this.dragOffsetX += boost;
      });
      // 第二段：从过冲点交给各卡自己的弹簧振荡回弹（分层错峰，幅度随 boost 增大）
      setTimeout((): void => { this.dragOffsetX = 0; }, 140);
    } else {
      // 慢速轻拖：直接由各卡弹簧回弹
      this.dragOffsetX = 0;
    }
  }

  private advance(): void {
    if (this.advancing || this.activeIndex >= this.posts.length) {
      return;
    }
    this.advancing = true;
    const top: DailyPost | undefined = this.posts[this.activeIndex];
    if (top !== undefined) {
      // —— 发射飞行卡：旧顶卡从当前跟手位置带速度抛射到屏外（对应原型 S.FL）——
      // 起点继承当前跟手位移与倾角，抛射行程须能完全盖住屏幕（约 2.3 倍卡宽），
      // 全程保持不透明度，出屏后才由父层销毁。
      this.flyPost = top;
      this.flyX = this.dragOffsetX;
      this.flyRot = this.dragDir * -DECK_DRAG_TILT;
      this.getUIContext().animateTo({
        duration: MotionTokens.slow,
        curve: MotionCurves.springRelease,
        expectedFrameRateRange: MotionFrameRates.default,
      }, () => {
        // 从「抬手位置」飞到「屏外远端」：带量级行程，落地前不淡出
        this.flyX = this.dragDir * (this.deckWidth * 1.6 + 200);
        this.flyRot = this.dragDir * -9;
      });
      setTimeout((): void => { this.flyPost = null; }, 460);
    } else {
      this.flyPost = null;
    }
    // 推进：activeIndex 前移 + 顶卡跟手位移清零，不包统一曲线 ——
    // 各卡按自身槽位弹簧回正（下层带旋转错峰滑入），飞行卡并行抛射
    this.activeIndex += 1;
    this.dragOffsetX = 0;
    if (this.activeIndex + 1 >= this.posts.length - DECK_VISIBLE + 1 && !this.finished) {
      this.onLoadMore?.();
    }
    // 读完最后一张 → 完成仪式。
    // 语义：activeIndex 从 0 起推进，推掉第 N 张后 activeIndex=N；
    // 只有推进到 activeIndex >= posts.length（最后一张也已被推出）才完成，
    // 否则仍差一张时（如 2 张读完第 1 张）就误入完成态。
    if (this.activeIndex >= this.posts.length) {
      setTimeout((): void => { this.showDone(); }, 560);
    }
    // 弹簧/抛射约 0.45~0.6s 内完成，期间闸住重复推进（避免连推重叠）
    setTimeout((): void => { this.advancing = false; }, 620);
  }

  private onTopPanUpdate(event: GestureEvent): void {
    if (this.advancing || this.doneVisible) {
      return;
    }
    // 双向跟手：向右为正、向左为负（对应原型 S.x 可正可负）
    this.dragOffsetX = event.offsetX;
    if (this.dragOffsetX < 0) {
      this.dragDir = -1;
    } else if (this.dragOffsetX > 0) {
      this.dragDir = 1;
    }
  }

  private onTopPanEnd(event?: GestureEvent): void {
    if (this.advancing || this.doneVisible) {
      return;
    }
    const width: number = Math.max(this.deckWidth, 1);
    const vel: number = event?.velocityX ?? 0;
    // 过位移阈值，或“轻甩”速度够大（|位移|>卡宽 12% 即可）：惯性甩出下一页
    const fling: boolean = Math.abs(vel) > 520 &&
      Math.abs(this.dragOffsetX) > width * 0.12;
    if (Math.abs(this.dragOffsetX) >= this.dismissDistance() || fling) {
      this.advance();
      return;
    }
    // 未过阈值：按松手速度回弹——速度越快过冲越大、晃动越明显
    this.resetDrag(vel);
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
    AppStorage.setOrCreate<string>('youjuDailyReadDate', this.todayStr());
    this.animateStamp();
    this.startCountdown();
  }

  private replay(): void {
    this.doneVisible = false;
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
      Row({ space: SpaceTokens.sm }) {
        // 明确刷新时刻（每日 00:00 整），右侧为距该时刻的剩余时长（非刷新钟点，避免歧义）
        Text('距明日 00:00 上新')
          .fontSize(11).fontFamily(TypeTokens.fontFamily)
          .letterSpacing(2)
          .fontColor(ColorTokens.tertiary)
        Text(this.countdownText)
          .fontSize(17).fontFamily(TypeTokens.fontFamilySerif)
          .fontWeight(TypeTokens.titleSerif.weight)
          .fontColor(ColorTokens.brand)
          .fontFeature(TypeTokens.tabularFeature)
      }
      .border({ width: 1, color: ColorTokens.separator, style: BorderStyle.Solid })
      .borderRadius(RadiusTokens.pill)
      .padding({ left: SpaceTokens.base, right: SpaceTokens.base, top: SpaceTokens.sm, bottom: SpaceTokens.sm })

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
            ForEach(this.visiblePosts(), (post: DailyPost) => {
              DeckSlotCard({
                post: post,
                anchor: this.activeIndex,
                posts: this.posts,
                deckWidth: this.deckWidth,
                dragOffsetX: this.dragOffsetX,
                dragDir: this.dragDir,
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
                dragDir: this.dragDir,
                rise: 1,
                inFlight: true,
                flyX: this.flyX,
                flyRot: this.flyRot,
              })
            }
          }
          .width('100%')
          .layoutWeight(1)
          .gesture(
            PanGesture({ direction: PanDirection.Horizontal, distance: 4 })
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
              Text('轻拖卡片 · 阅读今日精选')
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