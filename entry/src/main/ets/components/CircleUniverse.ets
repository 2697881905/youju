// 圈子宇宙（星图 Live 五期）：点圈子星球后坠入的「该圈子专属宇宙」。
// 这里没有行星——圈子本体是中央的恒星（TagIcon 圆盘 + 呼吸光环，泛光染上圈子主题色），
// 圈子的帖子化作大小不一的星星散布在轨道带上：热度越高星越亮，最热帖是金色星芒。
// 点星星弹出帖子预览卡（标题/作者/热度），「看全文」直达帖子详情。
// 交互语义：点星图行星 = 逛圈子入口；进入宇宙后点帖子星 = 读那一帖。
import { Post } from '../models/types';
import { listPosts, followTag, unfollowTag } from '../services/api';
import { getToken } from '../utils/auth';
import { safeShowToast } from '../utils/toast';
import { openPostDetail } from '../utils/nav';
import { getMainNavStack, PostDetailNavParams } from '../utils/navigationTransition';
import { TagIcon } from './TagIcon';
import { ColorTokens } from '../design/tokens/color';
import { StarPalette, DARK_PALETTE, PAPER_PALETTE, StarDot, STAR_DOTS } from '../design/tokens/starPalette';
import { MotionCurves, MotionTokens } from '../design/tokens/motion';
import { RadiusTokens } from '../design/tokens/radius';
import { LayoutTokens, SpaceTokens } from '../design/tokens/space';
import { TypeTokens } from '../design/tokens/type';

// 帖子星星渲染模型：坐标为画布内绝对 vp（布局时按测得区域计算，确定性可复现）。
interface UniverseStar {
  postId: number;
  title: string;
  author: string;
  ups: number;
  time: string;
  x: number;
  y: number;
  size: number;
  gold: boolean;
}

// 帖子星散布参数（相对画布）： header 之下、底栏之上留白，绕核心三圈黄金角散布。
const STAR_AREA_TOP_RATIO: number = 0.20;   // 星星顶界（避开头部）
const STAR_AREA_BOTTOM_RATIO: number = 0.90; // 星星底界（避开提示区）
const STAR_RING_BASE: number = 0.17;        // 第一圈半径（占短边比）
const STAR_RING_GAP: number = 0.115;        // 圈间距
const STAR_MIN_DIST: number = 56;           // 星星间最小间距（vp，含命中盒）
const CARD_WIDTH: number = 268;

@Component
export struct CircleUniverse {
  @Prop circleName: string = '';
  @Prop description: string = '';
  @Prop category: string = '';
  @Prop memberCount: number = 0;
  // 圈子主题色（CIRCLE_META color）：宇宙泛光/核心光环染上该圈专属色，一圆一宇宙
  @Prop accentColor: string = '#2D7CFF';
  @Prop joined: boolean = false;
  @Prop @Watch('onVisibleChanged') visible: boolean = false;
  @StorageLink('isDarkMode') darkMode: boolean = false;
  @StorageLink('statusBarHeight') statusBarHeight: number = 0;
  // 底部悬浮 Dock 的避让：LayoutTokens.floatingBarReserve + 系统导航条高度。
  // 必须走 StorageLink 建立响应式绑定，三键导航切换时才能即时重排。
  @StorageLink('navBarHeight') navBarHeight: number = 0;
  onTakeoff: () => void = (): void => {};
  onOpenFull: () => void = (): void => {};
  onJoinChanged: (joined: boolean) => void = (_joined: boolean): void => {};

  @State stars: UniverseStar[] = [];
  @State loading: boolean = false;
  @State error: string = '';
  @State joining: boolean = false;
  @State joinedNow: boolean = false;
  // 选中预览的帖子 id（-1=无）；点星星弹出预览卡，点卡「看全文」进详情
  @State selectedId: number = -1;
  // 画布尺寸（onAreaChange 测量）：星星布局与预览卡定位依赖
  @State areaW: number = 0;
  @State areaH: number = 0;
  // 中央恒星呼吸光环 + 加入点亮编舞
  @State coreHaloScale: number = 0.96;
  @State coreHaloOpacity: number = 0.25;
  @State coreScale: number = 1;
  @State coreHaloRunning: boolean = false;
  private rawPosts: Post[] = [];
  private listVersion: number = 0;

  private pal(): StarPalette {
    return this.darkMode ? DARK_PALETTE : PAPER_PALETTE;
  }

  // 点星星读帖：优先主 Navigation 栈，未就绪才回退 router 整页。
  private openPost(postId: number): void {
    if (postId <= 0) {
      return;
    }
    openPostDetail(String(postId));
    const nav: NavPathStack | null = getMainNavStack();
    if (nav !== null) {
      const params: PostDetailNavParams = new PostDetailNavParams();
      params.postId = postId;
      nav.pushPathByName('PostDetail', params);
      return;
    }
    this.getUIContext().getRouter().pushUrl({ url: 'pages/DetailPage' });
  }

  // 圈子主题色 + 透明度 → ARGB（accentColor 形如 '#RRGGBB'）
  private accent(alpha: string): string {
    const hex: string = this.accentColor.startsWith('#') ? this.accentColor.slice(1) : '2D7CFF';
    return '#' + alpha + hex;
  }

  aboutToAppear(): void {
    this.joinedNow = this.joined;
    if (this.visible && this.circleName.length > 0) {
      this.refresh();
    }
  }

  onVisibleChanged(): void {
    if (this.visible) {
      this.joinedNow = this.joined;
      this.selectedId = -1;
      this.refresh();
      this.startCoreBreath();
    }
  }

  // 帖子列表：热榜口径（宇宙里最亮的星是圈子里最好的内容）
  private async refresh(): Promise<void> {
    const version: number = this.listVersion + 1;
    this.listVersion = version;
    this.loading = true;
    this.error = '';
    try {
      const result = await listPosts({ page: 1, limit: 12, sort: 'hot', tag: this.circleName });
      if (version !== this.listVersion) {
        return;
      }
      this.rawPosts = result.list;
      this.layoutStars();
    } catch (e) {
      if (version === this.listVersion) {
        this.error = (e as Error).message;
      }
    } finally {
      if (version === this.listVersion) {
        this.loading = false;
      }
    }
  }

  // 帖子 → 星星布局：黄金角绕核心三圈散布（确定性：角度由序号+帖子 id 哈希微调），
  // 热度定星等（upCount 越高星越大越亮，最高热为金星），并做最小间距避让。
  private layoutStars(): void {
    const w: number = this.areaW;
    const h: number = this.areaH;
    if (w <= 0 || h <= 0 || this.rawPosts.length === 0) {
      this.stars = [];
      return;
    }
    const minDim: number = Math.min(w, h);
    const cx: number = w / 2;
    const cy: number = h * 0.46;
    const top: number = h * STAR_AREA_TOP_RATIO;
    const bottom: number = h * STAR_AREA_BOTTOM_RATIO - 30;
    // 热度峰值 → 金星
    let maxUps: number = 0;
    this.rawPosts.forEach((p: Post): void => {
      if ((p.upCount ?? 0) > maxUps) {
        maxUps = p.upCount ?? 0;
      }
    });
    const placed: UniverseStar[] = [];
    this.rawPosts.forEach((post: Post, index: number): void => {
      const idSeed: number = (post.id ?? index) % 997;
      const ring: number = index % 3;
      const baseR: number = minDim * (STAR_RING_BASE + ring * STAR_RING_GAP);
      const angle: number = index * 137.5 + (idSeed % 26) - 13;
      const rad: number = angle * Math.PI / 180;
      let x: number = cx + baseR * Math.cos(rad);
      let y: number = cy + baseR * Math.sin(rad) * 0.94;
      x = Math.max(44, Math.min(w - 44, x));
      y = Math.max(top, Math.min(bottom, y));
      const ups: number = post.upCount ?? 0;
      const size: number = maxUps > 0 && ups === maxUps ? 24 : (ups >= 20 ? 20 : 16);
      const star: UniverseStar = {
        postId: post.id ?? 0,
        title: post.title ?? '',
        author: post.user?.nickname ?? '匿名',
        ups: ups,
        time: this.timeAgo(post.createdAt),
        x: x,
        y: y,
        size: size,
        gold: maxUps > 0 && ups === maxUps,
      };
      // 最小间距避让：与已放置星星太近时沿切向轻推，最多 8 次仍近则接受
      for (let attempt: number = 0; attempt < 8; attempt++) {
        let tooClose: boolean = false;
        for (const other of placed) {
          const dx: number = star.x - other.x;
          const dy: number = star.y - other.y;
          if (Math.sqrt(dx * dx + dy * dy) < STAR_MIN_DIST) {
            tooClose = true;
            break;
          }
        }
        if (!tooClose) {
          break;
        }
        star.x = Math.max(44, Math.min(w - 44, star.x + (attempt % 2 === 0 ? 34 : -34)));
        star.y = Math.max(top, Math.min(bottom, star.y + (attempt < 4 ? 26 : -26)));
      }
      placed.push(star);
    });
    this.stars = placed;
  }

  // 加入/退出圈子：乐观更新 + 点亮编舞 + 回报父页面（复用降落页语义）。
  private async toggleJoin(): Promise<void> {
    if (this.joining || this.circleName.length === 0) {
      return;
    }
    if (getToken() === '') {
      safeShowToast(this.getUIContext(), { message: '请先登录后再加入圈子' });
      return;
    }
    const wasJoined: boolean = this.joinedNow;
    this.joining = true;
    this.joinedNow = !wasJoined;
    try {
      if (wasJoined) {
        await unfollowTag(this.circleName);
      } else {
        await followTag(this.circleName);
        this.playIgnite();
      }
      this.onJoinChanged(!wasJoined);
      safeShowToast(this.getUIContext(), { message: wasJoined ? '已退出圈子' : '已加入圈子 · 新星已点亮' });
    } catch (e) {
      this.joinedNow = wasJoined;
      safeShowToast(this.getUIContext(), { message: '操作失败：' + (e as Error).message });
    } finally {
      this.joining = false;
    }
  }

  // 加入点亮：中央恒星 scale 0.55→1.38→1（仅 transform）
  private playIgnite(): void {
    this.getUIContext().keyframeAnimateTo({ iterations: 1 }, [
      { duration: MotionTokens.fast, curve: MotionCurves.accelerate, event: (): void => { this.coreScale = 0.55; } },
      { duration: MotionTokens.base, curve: MotionCurves.spring, event: (): void => { this.coreScale = 1.38; } },
      { duration: MotionTokens.slow, curve: MotionCurves.springSoft, event: (): void => { this.coreScale = 1; } },
    ]);
  }

  // 中央恒星呼吸（进入宇宙时启动，Alternate 无限交替）
  private startCoreBreath(): void {
    if (this.coreHaloRunning) {
      return;
    }
    this.coreHaloRunning = true;
    this.getUIContext().animateTo({ duration: 1600, curve: Curve.EaseInOut, iterations: -1, playMode: PlayMode.Alternate }, () => {
      this.coreHaloScale = 1.1;
      this.coreHaloOpacity = 0.85;
    });
  }

  private timeAgo(iso?: string): string {
    if (iso === undefined || iso.length === 0) {
      return '';
    }
    const t: number = Date.parse(iso);
    if (isNaN(t)) {
      return '';
    }
    const diff: number = Date.now() - t;
    const days: number = Math.floor(diff / 86400000);
    if (days > 0) {
      return days + ' 天前';
    }
    const hours: number = Math.floor(diff / 3600000);
    if (hours > 0) {
      return hours + ' 小时前';
    }
    return '刚刚';
  }

  // 预览卡定位：贴在星星下方，越界则翻到上方，左右夹紧
  private cardX(star: UniverseStar): number {
    return Math.max(12, Math.min(this.areaW - CARD_WIDTH - 12, star.x - CARD_WIDTH / 2));
  }

  private cardY(star: UniverseStar): number {
    const below: number = star.y + 34;
    if (below + 156 > this.areaH - 20) {
      return Math.max(this.statusBarHeight + 96, star.y - 176);
    }
    return below;
  }

  @Builder
  private starField(): void {
    ForEach(this.stars, (star: UniverseStar, index: number) => {
      Stack({ alignContent: Alignment.Center }) {
        Text('✦')
          .fontSize(star.size)
          .fontColor(star.gold ? this.pal().seedGold : this.pal().seedBlue)
          .textShadow({
            radius: this.darkMode ? 12 : 7,
            color: star.gold
              ? (this.darkMode ? '#A0640088' : '#40A06400')
              : (this.darkMode ? '#4D9FFF88' : '#300066CC'),
            offsetY: 0,
          })
          .scale({
            x: this.selectedId === star.postId ? 1.35 : 1,
            y: this.selectedId === star.postId ? 1.35 : 1,
          })
          .animation({ duration: MotionTokens.base, curve: MotionCurves.spring })
      }
      .width(52)
      .height(52)
      .position({ x: star.x - 26, y: star.y - 26 })
      .opacity(this.loading ? 0 : 1)
      // 入场：逐颗点亮（延迟随序号递增）
      .transition(TransitionEffect.OPACITY
        .animation({ duration: MotionTokens.slow, curve: MotionCurves.decelerate, delay: index * 55 }))
      .hitTestBehavior(HitTestMode.Block)
      .gesture(
        TapGesture({ count: 1 })
          .onAction((): void => { this.selectedId = star.postId; })
      )
    }, (star: UniverseStar) => String(star.postId))
  }

  // 帖子预览卡（原型 seed-card）：点星星弹出，「看全文」进详情
  @Builder
  private previewCard(): void {
    ForEach(this.stars, (star: UniverseStar) => {
      if (this.selectedId === star.postId) {
        Column({ space: 6 }) {
          Text(star.title.length > 0 ? star.title : '无题')
            .fontSize(TypeTokens.callout.size).fontFamily(TypeTokens.fontFamily)
            .fontWeight(TypeTokens.headline.weight)
            .lineHeight(20)
            .fontColor(this.darkMode ? '#ECE8DF' : '#1A1A1A')
            .maxLines(2)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
          Text('@' + star.author + ' · ▲ ' + String(star.ups) + (star.time.length > 0 ? ' · ' + star.time : ''))
            .fontSize(TypeTokens.overline.size).fontFamily(TypeTokens.fontFamily)
            .fontColor(this.darkMode ? '#9AA3B5' : '#5A5A60')
            .maxLines(1)
          Row() {
            Blank()
            Text('看全文 ▸')
              .fontSize(TypeTokens.caption.size).fontFamily(TypeTokens.fontFamily)
              .fontWeight(TypeTokens.headline.weight)
              .fontColor(this.pal().icon)
              .onClick((): void => { this.openPost(star.postId); })
          }
          .width('100%')
        }
        .width(CARD_WIDTH)
        .alignItems(HorizontalAlign.Start)
        .padding({ left: SpaceTokens.md, right: SpaceTokens.md, top: SpaceTokens.sm, bottom: SpaceTokens.sm })
        .backgroundColor(this.darkMode ? '#F2182033' : '#F8FFFFFF')
        .border({ width: 1, color: this.darkMode ? '#40FFFFFF' : ColorTokens.separator, style: BorderStyle.Solid })
        .borderRadius(RadiusTokens.md)
        .shadow({ radius: 24, color: this.darkMode ? '#66000000' : '#1A000000', offsetY: 8 })
        .position({ x: this.cardX(star), y: this.cardY(star) })
        .transition(TransitionEffect.asymmetric(
          TransitionEffect.scale({ x: 0.92, y: 0.92 })
            .combine(TransitionEffect.OPACITY)
            .animation({ duration: MotionTokens.fast, curve: MotionCurves.spring }),
          TransitionEffect.OPACITY.animation({ duration: MotionTokens.fast })
        ))
        .gesture(
          TapGesture({ count: 1 })
            .onAction((): void => { this.openPost(star.postId); })
        )
      }
    }, (star: UniverseStar) => 'card_' + String(star.postId))
  }

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      // —— 宇宙底色：深色=夜空渐变 / 浅色=纸白星图，泛光染上圈子主题色 ——
      Column()
        .width('100%')
        .height('100%')
        .linearGradient({
          angle: 180,
          colors: [[this.pal().bgTop, 0], [this.pal().bgMid, 0.45], [this.pal().bgBottom, 1]],
        })
      Column()
        .width('100%')
        .height('100%')
        .radialGradient({
          center: [this.areaW / 2, this.areaH * 0.46],
          radius: Math.max(this.areaW, this.areaH) * 0.66,
          colors: [[this.accent(this.darkMode ? '38' : '24'), 0], [ColorTokens.glassClear, 1]],
        })
      // 点空白处收起预览卡（星星 Block 优先命中，不会误清）
      Column()
        .width('100%')
        .height('100%')
        .onClick((): void => { this.selectedId = -1; })
      // —— 背景星尘 ——
      ForEach(STAR_DOTS, (dot: StarDot, index: number) => {
        Circle()
          .width(dot.size)
          .height(dot.size)
          .fill(this.pal().star)
          .opacity(this.darkMode ? (dot.tw === 0 ? 0.45 : 0.3) : (dot.tw === 0 ? 0.16 : 0.1))
          .position({ x: this.areaW * dot.x / 100, y: this.areaH * dot.y / 100 })
          .hitTestBehavior(HitTestMode.None)
      }, (_dot: StarDot, index: number) => 'dust_' + index)

      // —— 中央恒星：圈子本体（一圆一宇宙的灵魂）——
      Stack({ alignContent: Alignment.Center }) {
        Circle()
          .width(96)
          .height(96)
          .fill(Color.Transparent)
          .stroke(this.accent(this.darkMode ? '66' : '40'))
          .strokeWidth(1)
          .opacity(this.coreHaloOpacity)
          .scale({ x: this.coreHaloScale, y: this.coreHaloScale })
          .hitTestBehavior(HitTestMode.None)
        Column({ space: SpaceTokens.xs }) {
          TagIcon({ name: this.circleName, iconSize: 30, tint: this.pal().icon, colorful: false })
        }
        .width(58)
        .height(58)
        .backgroundColor(this.pal().discFill)
        .border({ width: 0.8, color: this.pal().discStroke, style: BorderStyle.Solid })
        .borderRadius(29)
        .shadow({ radius: this.darkMode ? 14 : 8, color: this.darkMode ? '#66000000' : '#1A000000', offsetY: 3 })
        .justifyContent(FlexAlign.Center)
        .alignItems(HorizontalAlign.Center)
        .scale({ x: this.coreScale, y: this.coreScale })
      }
      .position({ x: this.areaW / 2 - 48, y: this.areaH * 0.46 - 48 })
      .width(96)
      .height(96)
      .hitTestBehavior(HitTestMode.None)

      // —— 圈子铭牌：名字 + 一句话简介（恒星正下方）——
      Column({ space: 2 }) {
        Text(this.circleName)
          .fontSize(TypeTokens.titleSerif.size).fontFamily(TypeTokens.fontFamilySerif)
          .fontWeight(TypeTokens.titleSerif.weight)
          .fontColor(this.pal().ink)
          .textAlign(TextAlign.Center)
        if (this.description.length > 0) {
          Text(this.description)
            .fontSize(TypeTokens.caption.size).fontFamily(TypeTokens.fontFamily)
            .fontColor(this.darkMode ? '#9AA3B5' : '#5A5A60')
            .textAlign(TextAlign.Center)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
      }
      .width('70%')
      .position({ x: this.areaW * 0.15, y: this.areaH * 0.46 + 58 })
      .hitTestBehavior(HitTestMode.None)

      // —— 帖子星星 ——
      this.starField()

      // —— 头部：返回 + 铭牌 + 加入 ——
      Row({ space: SpaceTokens.sm }) {
        Text('‹ 返回星图')
          .fontSize(TypeTokens.caption.size).fontFamily(TypeTokens.fontFamily)
          .fontWeight(TypeTokens.headline.weight)
          .fontColor(this.pal().icon)
          .padding({ left: SpaceTokens.md, right: SpaceTokens.md, top: SpaceTokens.sm, bottom: SpaceTokens.sm })
          .onClick((): void => { this.onTakeoff(); })
        Blank()
        Button(this.joinedNow ? '✓ 已加入' : '＋ 加入圈子')
          .buttonStyle(ButtonStyleMode.NORMAL)
          .type(ButtonType.Capsule)
          .controlSize(ControlSize.SMALL)
          .fontSize(TypeTokens.caption.size)
          .fontColor(this.joinedNow ? this.pal().gold : ColorTokens.onBrand)
          .backgroundColor(this.joinedNow ? Color.Transparent : this.pal().icon)
          .borderWidth(this.joinedNow ? 1 : 0)
          .borderColor(this.pal().gold)
          .enabled(!this.joining)
          .margin({ right: SpaceTokens.md })
          .onClick((): void => { this.toggleJoin(); })
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)
      // 宇宙画布从窗口原点铺开（圈子页顶栏不占内容区），头部要自己让开
      // 「状态栏 + 悬浮品牌行」，否则「返回星图」会压在「圈子」标题那一条上。
      .margin({ top: this.statusBarHeight + LayoutTokens.titleBarHeight + SpaceTokens.xs })
      .hitTestBehavior(HitTestMode.Transparent)

      // —— 底部提示 + 完整圈子页入口 ——
      Column({ space: SpaceTokens.xs }) {
        Text('进入完整圈子页 ▸')
          .fontSize(TypeTokens.caption.size).fontFamily(TypeTokens.fontFamily)
          .fontColor(this.darkMode ? '#9AA3B5' : '#5A5A60')
          .padding({ top: SpaceTokens.xs, bottom: SpaceTokens.xs })
          .onClick((): void => { this.onOpenFull(); })
        Text('点星星读帖 · 点空白收起')
          .fontSize(TypeTokens.overline.size).fontFamily(TypeTokens.fontFamily)
          .fontColor(this.darkMode ? '#6B7280' : '#8E8E96')
      }
      .width('100%')
      .alignItems(HorizontalAlign.Center)
      // 贴底 + 让开悬浮 Dock 与系统导航条：原来固定 areaH-86 会被 Dock 盖住。
      .position({ x: 0, y: '100%' })
      .markAnchor({ y: '100%' })
      .padding({ bottom: LayoutTokens.floatingBarReserve + this.navBarHeight + SpaceTokens.sm })
      .hitTestBehavior(HitTestMode.Transparent)

      // —— 预览卡 ——
      this.previewCard()

      // —— 加载 / 错误 / 空态 ——
      if (this.loading && this.stars.length === 0) {
        Column({ space: SpaceTokens.sm }) {
          LoadingProgress().width(36).height(36).color(this.pal().icon)
          Text('坠入「' + this.circleName + '」…')
            .fontSize(TypeTokens.caption.size).fontFamily(TypeTokens.fontFamily)
            .fontColor(this.darkMode ? '#9AA3B5' : '#5A5A60')
        }
        .width('100%')
        .position({ x: 0, y: this.areaH * 0.4 })
        .hitTestBehavior(HitTestMode.None)
      } else if (this.error.length > 0 && this.stars.length === 0) {
        Text('宇宙信号丢失：' + this.error)
          .fontSize(TypeTokens.caption.size).fontFamily(TypeTokens.fontFamily)
          .fontColor(this.darkMode ? '#9AA3B5' : '#5A5A60')
          .width('80%')
          .textAlign(TextAlign.Center)
          .position({ x: this.areaW * 0.1, y: this.areaH * 0.4 })
          .hitTestBehavior(HitTestMode.None)
      } else if (!this.loading && this.stars.length === 0) {
        Column({ space: SpaceTokens.sm }) {
          Text('🌙').fontSize(28)
          Text('这颗新星还没有帖子\n去发第一帖，点亮它的第一盏灯')
            .fontSize(TypeTokens.caption.size).fontFamily(TypeTokens.fontFamily)
            .fontColor(this.darkMode ? '#9AA3B5' : '#5A5A60')
            .textAlign(TextAlign.Center)
            .lineHeight(20)
        }
        .width('100%')
        .position({ x: 0, y: this.areaH * 0.38 })
        .hitTestBehavior(HitTestMode.None)
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.darkMode ? '#0B1224' : '#FAFAFB')
    .transition(TransitionEffect.move(TransitionEdge.BOTTOM)
      .animation({ duration: MotionTokens.page, curve: MotionCurves.emphasized }))
    .onAreaChange((_old: Area, area: Area) => {
      const rawW: number = area.width as number;
      const rawH: number = area.height as number;
      const w: number = rawW > 1200 ? this.getUIContext().px2vp(rawW) : rawW;
      const h: number = rawH > 1200 ? this.getUIContext().px2vp(rawH) : rawH;
      if (w !== this.areaW || h !== this.areaH) {
        this.areaW = w;
        this.areaH = h;
        // 尺寸就绪/变化后重排星星（首次测量完成前 rawPosts 已就位则此处补排）
        this.layoutStars();
      }
    })
  }
}
