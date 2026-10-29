import { TagIcon } from './TagIcon';
import { resolveDisplayImageUrl } from '../services/api';
import { ColorTokens } from '../design/tokens/color';
import { StarDot, StarPalette, DARK_PALETTE, PAPER_PALETTE, STAR_DOTS } from '../design/tokens/starPalette';
import { MotionCurves, MotionTokens } from '../design/tokens/motion';
import { categoryHue } from '../design/tokens/category';
import { ShadowTokens } from '../design/tokens/shadow';
import { SpaceTokens } from '../design/tokens/space';
import { TypeTokens } from '../design/tokens/type';

export interface OrbitCircleItem {
  name: string;
  category: string;
  size: number;
  ring: number;
  baseAngle: number;
  // 星图 Live：joined=成员身份（金环+引力可拖），active=近7天有新帖（亮星/暗星），
  // unread=未读新帖数（角标 + 星子）
  joined: boolean;
  active: boolean;
  unread: number;
  // 星图 Live 三期：星等 0=暗星 1=常星 2=耀星（由服务端 activeScore 换算，驱动光晕与亮度）
  magnitude: number;
}

// 星子数据源：一颗星 = 一篇真实帖子（父页面从最新帖子流构造）。
// 不能靠「活跃圈」近似（useCount/activity）：这些字段在老后端恒为 0，
// 星池会塌缩成唯一一个圈子——表现为「点多少颗星都打开同一篇帖子」。
export interface OrbitSeedPost {
  postId: number;
  name: string;
  // 队列里最热的一篇 → 金色星芒
  gold: boolean;
}

// 帖子星子（原型 spawnSeed）：新帖化作光点在活跃行星旁浮现，寿命 15s，点击直达。
// 关键：行星在公转而星子若静态落点，几秒后行星会「转到星子上」——用户点看到的
// 星星实际点中了行星。故星子保存「相对行星的偏移」，渲染时跟随行星当前位置。
interface SeedItem {
  id: number;
  dx: number;
  dy: number;
  name: string;
  postId: number;
  gold: boolean;
}

// 星子渲染视图：投放时把所属行星的轨道参数解析进来，@Builder 不做查找。
interface SeedView {
  id: number;
  name: string;
  postId: number;
  dx: number;
  dy: number;
  gold: boolean;
  baseAngle: number;
  radius: number;
  ring: number;
}

const PLANET_BOX_WIDTH: number = 72;
const PLANET_BOX_HEIGHT: number = 88;
// 行星热区：从 40 提到 44（≥ 应用最小触控目标），标签跟着加宽。
const PLANET_ICON_HIT_SIZE: number = 44;
const CENTER_AVATAR_SIZE: number = 64;
const RIPPLE_FIRST_SIZE: number = 68;
const RIPPLE_SECOND_SIZE: number = 88;
const RIPPLE_CYCLE_DURATION: number = 920;
const RIPPLE_STAGGER: number = 180;

// ===== 星轨：轨道不再画「粗环 / 光带」，而是「极细引力线 + 沿轨星尘」 =====
// 内环密、外环疏；颗粒越靠外越小越淡，制造由近及远的纵深。
const RING_LINE_OPACITIES: number[] = [0.85, 0.5, 0.28];
const RING_DUST_COUNTS: number[] = [18, 24, 30];
const RING_DUST_SIZES: number[] = [2.0, 1.6, 1.2];
const RING_DUST_OPACITIES: number[] = [0.38, 0.24, 0.14];

// 星尘角度：等分 + 固定伪随机抖动（±5°），既避免机械对齐，也保证每次渲染星位一致。
function dustAnglesOf(count: number): number[] {
  const angles: number[] = [];
  for (let index: number = 0; index < count; index++) {
    const jitter: number = ((index * 37) % 11) - 5;
    angles.push(index * 360 / count + jitter);
  }
  return angles;
}

const RING_DUST_ANGLES: number[][] = [
  dustAnglesOf(RING_DUST_COUNTS[0]),
  dustAnglesOf(RING_DUST_COUNTS[1]),
  dustAnglesOf(RING_DUST_COUNTS[2]),
];

// 全屏矩形画布的星系中心：水平居中、垂直 42%（原型 cy≈40%，标题栏之下留出呼吸位）。
function canvasCenterY(height: number): number {
  return height * 0.42;
}

// 纯视图星环：父页面负责角度、惯性和暂停规则，本组件只消费计算后的轨道与行星坐标。
// 星图 Live 四期：画布升级为全屏矩形（宽=视口宽、高=视口高），星系中心落在
// (宽/2, 高×0.42)——与原型「全屏星图沉浸感」一致，泛光与星尘铺满整屏。
@Component
export struct CircleOrbitCanvas {
  @Prop galaxySize: number = 343;
  // 画布高度（全屏沉浸）；缺省与宽度一致（方形，兼容旧接线）
  @Prop galaxyHeight: number = 0;
  @Prop ringAngles: number[] = [0, 0, 0];
  @Prop @Watch('onOrbitDataChanged') radii: number[] = [0, 0, 0];
  @Prop @Watch('onOrbitDataChanged') circles: OrbitCircleItem[] = [];
  @Prop selectedName: string = '';
  @Prop centeredName: string = '';
  @Prop ringDragging: boolean = false;
  @Prop avatar: string = '';
  @Prop nickname: string = '';
  // Tab 切走时父页面置 false：暂停星子投放与常驻呼吸动画（隐藏组件不应持续触发自绘与状态刷新）
  @Prop @Watch('onLiveChanged') live: boolean = true;
  // 星子数据源：父页面按「最新帖子流」给出每颗星对应的那篇帖子（空 = 星图不出星子）。
  @Prop @Watch('onOrbitDataChanged') seedPosts: OrbitSeedPost[] = [];
  // 星图双主题：深色=墨空星图 / 浅色=纸上星图（随应用 isDarkMode 切换）
  @StorageLink('isDarkMode') darkMode: boolean = false;
  onPlanet: (name: string) => void = (_name: string): void => {};
  // 星图 Live 二期：引力拖拽生命周期——start 时父页面冻结自转（行星不漂移），
  // end 回报触点距圆心距离（父页面换算档位并落库）；
  // onGravityBlocked：拖动未加入行星时回报（父页面弹加入引导）。
  onGravityStart: (name: string) => void = (_name: string): void => {};
  onGravityEnd: (name: string, distance: number) => void = (_name: string, _distance: number): void => {};
  onGravityBlocked: (name: string) => void = (_name: string): void => {};
  // 星子点击：直达这颗星子所代表的那篇帖（postId<=0 时由父页面兜底解析）
  onSeedTap: (name: string, postId: number) => void = (_name: string, _postId: number): void => {};
  // 手势按下时回报「触点落在哪一条环」（环序号，判不出来时为 -1）：
  // 环的判定依赖半径与画布几何，因此留在本组件；父页面只消费结果。
  onPanStart: (ring: number) => void = (_ring: number): void => {};
  onPanUpdate: (event: GestureEvent) => void = (_event: GestureEvent): void => {};
  onPanEnd: () => void = (): void => {};

  private canvasHeight(): number {
    return this.galaxyHeight > 0 ? this.galaxyHeight : this.galaxySize;
  }

  private cx(): number {
    return this.galaxySize / 2;
  }

  private cy(): number {
    return this.canvasHeight() * 0.42;
  }

  private pal(): StarPalette {
    return this.darkMode ? DARK_PALETTE : PAPER_PALETTE;
  }

  // 背景星点透明度：深色用闪烁原值；浅色（纸上星图）整体压淡，墨点只做肌理。
  private starOpacity(dot: StarDot): number {
    if (!this.darkMode) {
      return dot.tw === 0 ? 0.16 : (dot.tw === 1 ? this.twinkleA * 0.28 : this.twinkleB * 0.28);
    }
    return dot.tw === 0 ? 0.45 : (dot.tw === 1 ? this.twinkleA : this.twinkleB);
  }

  // 中心头像呼吸双环（原型 halo breath 3.2s）：仅 transform/opacity 循环动画。
  @State haloScale1: number = 0.96;
  @State haloOpacity1: number = 0.25;
  @State haloScale2: number = 0.96;
  @State haloOpacity2: number = 0.25;
  // 背景星尘闪烁：A/B 两组反相呼吸（仅 opacity），锚定星恒亮。
  @State twinkleA: number = 0.15;
  @State twinkleB: number = 0.55;
  private haloStarted: boolean = false;
  private haloStaggerTimer: number = 0;

  private startHaloBreath(): void {
    if (!this.live || this.haloStarted) {
      return;
    }
    this.haloStarted = true;
    this.getUIContext().animateTo({ duration: 1600, curve: Curve.EaseInOut, iterations: -1, playMode: PlayMode.Alternate }, () => {
      this.haloScale1 = 1.06;
      this.haloOpacity1 = 0.9;
    });
    this.haloStaggerTimer = setTimeout((): void => {
      this.haloStaggerTimer = 0;
      this.getUIContext().animateTo({ duration: 1600, curve: Curve.EaseInOut, iterations: -1, playMode: PlayMode.Alternate }, () => {
        this.haloScale2 = 1.06;
        this.haloOpacity2 = 0.9;
      });
    }, 1400) as number;
    // 星尘闪烁：两组反相，周期 2.6s（Alternate 半程 1.3s）
    this.getUIContext().animateTo({ duration: 1300, curve: Curve.EaseInOut, iterations: -1, playMode: PlayMode.Alternate }, () => {
      this.twinkleA = 0.6;
      this.twinkleB = 0.15;
    });
  }

  // 隐藏 Tab 时把呼吸态归位：不能只停定时器，否则无限 animateTo 仍在跑。
  private stopHaloBreath(): void {
    if (this.haloStaggerTimer !== 0) {
      clearTimeout(this.haloStaggerTimer);
      this.haloStaggerTimer = 0;
    }
    if (!this.haloStarted) {
      return;
    }
    this.haloStarted = false;
    this.getUIContext().animateTo({ duration: MotionTokens.none }, () => {
      this.haloScale1 = 0.96;
      this.haloOpacity1 = 0.25;
      this.haloScale2 = 0.96;
      this.haloOpacity2 = 0.25;
      this.twinkleA = 0.15;
      this.twinkleB = 0.55;
    });
  }

  // ===== 帖子星子层（原型 spawnSeed）=====
  // 活跃行星旁定时浮现星芒（最多同屏 6 颗、寿命 15s），点击直达该圈最新帖。
  // 星子存「相对行星偏移」，渲染时叠加行星当前位置 → 随行星公转，永不被行星压住。
  @State seeds: SeedItem[] = [];
  // 星子脉动（原型 seedPulse）：所有星子共享同一呼吸相位（scale/opacity 无限交替）
  @State seedPulseScale: number = 1;
  @State seedPulseOpacity: number = 0.8;
  private seedNextId: number = 1;
  private seedSpawnTimer: number = 0;
  private seedIntervalTimer: number = 0;
  private seedTimers: number[] = [];
  private seedPulseStarted: boolean = false;
  // 本次进入星图后已被点开的帖子：不再重复投放（星子=「去读这一帖」，读过即完成）。
  private openedPostIds: number[] = [];

  aboutToAppear(): void {
    this.startSeedLoop();
  }

  aboutToDisappear(): void {
    this.stopSeedLoop(false);
    this.stopHaloBreath();
  }

  private startSeedLoop(): void {
    if (!this.live || this.seedSpawnTimer !== 0 || this.seedIntervalTimer !== 0) {
      return;
    }
    // 首颗 1.5s 后出现，之后每 3.2s 尝试投放（原型同款节奏）
    this.seedSpawnTimer = setTimeout((): void => { this.spawnSeed(); }, 1500) as number;
    this.seedIntervalTimer = setInterval((): void => { this.spawnSeed(); }, 3200);
  }

  // clearSeeds=true：切走 Tab 时一并清掉已投放星子，避免长时间离开后回来看到过期星子。
  private stopSeedLoop(clearSeeds: boolean): void {
    if (this.seedSpawnTimer !== 0) {
      clearTimeout(this.seedSpawnTimer);
      this.seedSpawnTimer = 0;
    }
    if (this.seedIntervalTimer !== 0) {
      clearInterval(this.seedIntervalTimer);
      this.seedIntervalTimer = 0;
    }
    this.seedTimers.forEach((t: number): void => { clearTimeout(t); });
    this.seedTimers = [];
    if (clearSeeds && this.seeds.length > 0) {
      this.seeds = [];
      this.seedViews = [];
    }
    if (!this.live && this.seedPulseStarted) {
      this.seedPulseStarted = false;
      this.getUIContext().animateTo({ duration: MotionTokens.none }, () => {
        this.seedPulseScale = 1;
        this.seedPulseOpacity = 0.8;
      });
    }
  }

  // Tab 可见性切换：隐藏时停掉一切常驻动画，回来时重新点火。
  onLiveChanged(): void {
    if (this.live) {
      this.startHaloBreath();
      this.startSeedLoop();
      return;
    }
    this.stopSeedLoop(true);
    this.stopHaloBreath();
  }

  private spawnSeed(): void {
    if (!this.live || this.seeds.length >= 6) {
      return;
    }
    // 每颗行星同时最多一颗星子：重复投放会星子叠星子（点 A 也命中 B），观感与命中都差。
    // 本次点开过的帖子不再投放——星子代表「去读这一帖」，读过还悬着是噪音。
    const seeded: string[] = this.seeds.map((s: SeedItem): string => s.name);
    const candidates: OrbitSeedPost[] = this.seedPosts.filter(
      (post: OrbitSeedPost): boolean => this.circles.some((c: OrbitCircleItem): boolean => c.name === post.name)
        && seeded.indexOf(post.name) < 0
        && this.openedPostIds.indexOf(post.postId) < 0);
    if (candidates.length === 0) {
      return;
    }
    if (!this.seedPulseStarted) {
      this.seedPulseStarted = true;
      this.getUIContext().animateTo({ duration: 1100, curve: Curve.EaseInOut, iterations: -1, playMode: PlayMode.Alternate }, () => {
        this.seedPulseScale = 1.45;
        this.seedPulseOpacity = 1;
      });
    }
    const post: OrbitSeedPost = candidates[Math.floor(Math.random() * candidates.length)];
    // 绕行星环形偏移（60~90vp）：行星命中半径 20 + 星子命中半径 28 = 48 < 60，
    // 两盒永不相交，且星子随行星公转固定悬于一侧——彻底消除「点星星误开星球」。
    const ang: number = Math.random() * Math.PI * 2;
    const dist: number = 60 + Math.random() * 30;
    const seed: SeedItem = {
      id: this.seedNextId++,
      dx: Math.cos(ang) * dist,
      dy: Math.sin(ang) * dist,
      name: post.name,
      postId: post.postId,
      gold: post.gold,
    };
    this.seeds.push(seed);
    this.recomputeSeedViews();
    const life: number = setTimeout((): void => {
      this.seeds = this.seeds.filter((s: SeedItem): boolean => s.id !== seed.id);
      this.recomputeSeedViews();
    }, 15000) as number;
    this.seedTimers.push(life);
  }

  // SeedStar 回报点击：按 id 移除对应星子并转发父页面（直达这颗星所代表的那篇帖）。
  private tapSeedById(id: number): void {
    const hit: SeedItem | undefined = this.seeds.find((s: SeedItem): boolean => s.id === id);
    this.seeds = this.seeds.filter((s: SeedItem): boolean => s.id !== id);
    this.recomputeSeedViews();
    if (hit !== undefined) {
      if (this.openedPostIds.indexOf(hit.postId) < 0) {
        this.openedPostIds.push(hit.postId);
      }
      this.onSeedTap(hit.name, hit.postId);
    }
  }

  // 星子视图预计算：seeds 增删或 circles/radii 结构变化时重算（@Watch）。
  // 把所属行星的轨道参数解析进视图；环实时角度由 SeedStar 经 @Prop 跟随刷新。
  @State seedViews: SeedView[] = [];

  private onOrbitDataChanged(): void {
    if (this.seeds.length > 0) {
      this.recomputeSeedViews();
    }
  }

  private recomputeSeedViews(): void {
    this.seedViews = this.seeds.map((seed: SeedItem): SeedView => {
      const circle: OrbitCircleItem | undefined = this.circles.find(
        (item: OrbitCircleItem): boolean => item.name === seed.name);
      const ring: number = circle?.ring ?? -1;
      return {
        id: seed.id,
        name: seed.name,
        postId: seed.postId,
        dx: seed.dx,
        dy: seed.dy,
        gold: seed.gold,
        baseAngle: circle?.baseAngle ?? 0,
        radius: ring >= 0 ? (this.radii[ring] ?? 0) : 0,
        ring: ring,
      };
    }).filter((v: SeedView): boolean => v.ring >= 0);
  }

  @Builder
  private seedLayer(): void {
    ForEach(this.seedViews, (view: SeedView) => {
      SeedStar({
        view: view,
        ringAngle: this.angleFor(view.ring),
        galaxySize: this.galaxySize,
        canvasH: this.canvasHeight(),
        pulseScale: this.seedPulseScale,
        pulseOpacity: this.seedPulseOpacity,
        onSeedTapId: (id: number): void => { this.tapSeedById(id); },
      })
    }, (view: SeedView) => String(view.id))
  }

  private angleFor(ring: number): number {
    return this.ringAngles[ring] ?? 0;
  }

  private radiusFor(ring: number): number {
    return this.radii[ring] ?? 0;
  }

  // 触点离画布中心多远 → 最接近哪一条环带。
  // FingerInfo.localX/localY 是「相对手势宿主元素左上角」的坐标（见 SDK gesture.d.ts），
  // 本手势绑在 galaxySize × galaxySize 的画布 Stack 上，故减 galaxySize/2 即得相对圆心的偏移。
  private ringAtTouch(event: GestureEvent): number {
    const fingers: FingerInfo[] | undefined = event?.fingerList;
    if (fingers === undefined || fingers.length === 0) {
      return -1;
    }
    const dx: number = fingers[0].localX - this.cx();
    const dy: number = fingers[0].localY - this.cy();
    const distance: number = Math.sqrt(dx * dx + dy * dy);
    let best: number = -1;
    let bestGap: number = -1;
    for (let index: number = 0; index < this.radii.length; index++) {
      const gap: number = Math.abs(distance - this.radii[index]);
      if (bestGap < 0 || gap < bestGap) {
        bestGap = gap;
        best = index;
      }
    }
    return best;
  }

  private circlesFor(ring: number): OrbitCircleItem[] {
    return this.circles.filter((circle: OrbitCircleItem): boolean => circle.ring === ring);
  }

  @Builder
  private starDots(): void {
    // 背景星尘按画布宽/高百分比散布（全屏矩形）；A/B 两组反相闪烁，锚定星恒亮。
    ForEach(STAR_DOTS, (dot: StarDot, index: number) => {
      Circle()
        .width(dot.size)
        .height(dot.size)
        .fill(this.pal().star)
        .opacity(this.starOpacity(dot))
        .position({ x: this.galaxySize * dot.x / 100, y: this.canvasHeight() * dot.y / 100 })
        .hitTestBehavior(HitTestMode.None)
    }, (_dot: StarDot, index: number) => 'star_' + index)
  }

  @Builder
  private orbitRing(ring: number): void {
    OrbitRingLayer({
      galaxySize: this.galaxySize,
      canvasH: this.canvasHeight(),
      ringIndex: ring,
      radius: this.radiusFor(ring),
      ringAngle: this.angleFor(ring),
      circles: this.circlesFor(ring),
      selectedName: this.selectedName,
      centeredName: this.centeredName,
      ringDragging: this.ringDragging,
      live: this.live,
      onPlanet: (name: string): void => { this.onPlanet(name); },
      onGravityStart: (name: string): void => { this.onGravityStart(name); },
      onGravityEnd: (name: string, distance: number): void => { this.onGravityEnd(name, distance); },
      onGravityBlocked: (name: string): void => { this.onGravityBlocked(name); },
      onSeedTap: (name: string, postId: number): void => { this.onSeedTap(name, postId); },
    })
  }

  @Builder
  private coreStar(): void {
    Stack({ alignContent: Alignment.Center }) {
      // 呼吸光环（原型 halo：70/86 两道细环，3.2s 交替呼吸）——中心头像的「活体」信号
      Circle()
        .width(70)
        .height(70)
        .fill(Color.Transparent)
        .stroke(this.pal().halo)
        .strokeWidth(1)
        .opacity(this.haloOpacity1)
        .scale({ x: this.haloScale1, y: this.haloScale1 })
        .hitTestBehavior(HitTestMode.None)
      Circle()
        .width(86)
        .height(86)
        .fill(Color.Transparent)
        .stroke(this.pal().halo)
        .strokeWidth(1)
        .opacity(this.haloOpacity2)
        .scale({ x: this.haloScale2, y: this.haloScale2 })
        .hitTestBehavior(HitTestMode.None)
      if (this.avatar.length > 0) {
        Image(resolveDisplayImageUrl(this.avatar))
          .width(CENTER_AVATAR_SIZE)
          .height(CENTER_AVATAR_SIZE)
          .borderRadius(CENTER_AVATAR_SIZE / 2)
          .objectFit(ImageFit.Cover)
          .clip(true)
          // 中心头像落在横向 PanGesture 的星系面上：Image 默认 draggable=true，
          // 长按后拖动会被系统拖拽接管 → 星系转不动
          .draggable(false)
      } else {
        // 无头像时与全局 Avatar 组件一致：用品牌默认头像，而不是首字母占位，
        // 保证星系中心看到的就是「我的」个人主页那个头像。
        Image($r('app.media.default_avatar'))
          .width(CENTER_AVATAR_SIZE)
          .height(CENTER_AVATAR_SIZE)
          .borderRadius(CENTER_AVATAR_SIZE / 2)
          .objectFit(ImageFit.Cover)
          .clip(true)
          .draggable(false)
      }
    }
    .width(CENTER_AVATAR_SIZE)
    .height(CENTER_AVATAR_SIZE)
    .borderRadius(CENTER_AVATAR_SIZE / 2)
    // 不裁剪：呼吸光环（70/86）大于头像，需要溢出显示；头像圆形由 Image 自身 borderRadius 保证。
    .position({ x: this.cx() - CENTER_AVATAR_SIZE / 2, y: this.cy() - CENTER_AVATAR_SIZE / 2 })
    .onAppear((): void => { this.startHaloBreath(); })
    .hitTestBehavior(HitTestMode.None)
  }

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      // 画布底色：深色=夜空渐变 / 浅色=纸上星图（白→暖灰微渐变），随 isDarkMode 切换。
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
        // 星系泛光：中心取星系中心（宽/2, 高×0.42），半径铺满画布，
        // 核心向外衰减至透明，营造「身处星云之中」的沉浸感。
        .radialGradient({
          center: [this.cx(), this.cy()],
          radius: Math.max(this.galaxySize, this.canvasHeight()) * 0.72,
          colors: [[this.pal().glow, 0], [ColorTokens.glassClear, 1]],
        })
      this.starDots()
      this.coreStar()
      this.orbitRing(0)
      this.orbitRing(1)
      this.orbitRing(2)
      this.seedLayer()
    }
    .width(this.galaxySize)
    .height(this.canvasHeight())
    .clip(false)
    .gesture(
      PanGesture({ direction: PanDirection.Horizontal, distance: 2 })
        .onActionStart((event: GestureEvent): void => { this.onPanStart(this.ringAtTouch(event)); })
        .onActionUpdate((event: GestureEvent): void => { this.onPanUpdate(event); })
        .onActionEnd((): void => { this.onPanEnd(); })
        .onActionCancel((): void => { this.onPanEnd(); })
    )
  }
}

// 每条圆环与所属 Logo 共享同一份圆心、半径和实时角度，作为一个运动单元渲染。
@Component
struct OrbitRingLayer {
  @Prop galaxySize: number = 343;
  // 环序（0=内/1=中/2=外）：线感与星尘密度按环递减，形成纵深
  @Prop ringIndex: number = 0;
  @Prop radius: number = 0;
  @Prop ringAngle: number = 0;
  @Prop circles: OrbitCircleItem[] = [];
  @Prop selectedName: string = '';
  @Prop centeredName: string = '';
  @Prop ringDragging: boolean = false;
  // 跟随父页面可见性：隐藏时行星不再启动呼吸/脉冲
  @Prop live: boolean = true;
  // 星图 Live 四期：全屏矩形画布高度（中心=宽/2、高×0.42）
  @Prop canvasH: number = 0;
  @StorageLink('isDarkMode') darkMode: boolean = false;
  onPlanet: (name: string) => void = (_name: string): void => {};
  onGravityStart: (name: string) => void = (_name: string): void => {};
  onGravityEnd: (name: string, distance: number) => void = (_name: string, _distance: number): void => {};
  onGravityBlocked: (name: string) => void = (_name: string): void => {};
  onSeedTap: (name: string, postId: number) => void = (_name: string, _postId: number): void => {};

  private ch(): number {
    return this.canvasH > 0 ? this.canvasH : this.galaxySize;
  }

  private pal(): StarPalette {
    return this.darkMode ? DARK_PALETTE : PAPER_PALETTE;
  }

  private lineOpacity(): number {
    return RING_LINE_OPACITIES[this.ringIndex] ?? 0.5;
  }

  private dustSize(): number {
    return RING_DUST_SIZES[this.ringIndex] ?? 1.2;
  }

  private dustOpacity(): number {
    return RING_DUST_OPACITIES[this.ringIndex] ?? 0.12;
  }

  private dustAngles(): number[] {
    return RING_DUST_ANGLES[this.ringIndex] ?? RING_DUST_ANGLES[0];
  }

  // 每 5 颗一颗锚星：尺寸 ×1.5、亮度 ×1.7。
  private dustSizeAt(index: number): number {
    return this.dustSize() * (index % 5 === 0 ? 1.5 : 1);
  }

  private dustOpacityAt(index: number): number {
    return this.dustOpacity() * (index % 5 === 0 ? 1.7 : 1);
  }

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      // 引力线：0.8vp 极细暖白线，只作为拖拽换档的参照；越外环越淡，溶进夜空。
      Circle()
        .width(this.radius * 2)
        .height(this.radius * 2)
        .fill(Color.Transparent)
        .stroke(this.pal().ring)
        .strokeWidth(0.8)
        .opacity(this.lineOpacity())
        .position({ x: this.galaxySize / 2 - this.radius, y: canvasCenterY(this.ch()) - this.radius })
        .rotate({ angle: this.ringAngle, centerX: '50%', centerY: '50%' })
        .animation({ duration: this.ringDragging ? MotionTokens.instant : MotionTokens.fast, curve: MotionCurves.standard })
        .hitTestBehavior(HitTestMode.None)
      // 星尘轨：沿圆周铺 18/24/30 颗 1.2–2vp 微粒，随环公转；内环密而亮、外环疏而淡。
      // 整层一起 rotate（只 3 个容器动画），不逐颗重算坐标。
      Stack({ alignContent: Alignment.TopStart }) {
        ForEach(this.dustAngles(), (angle: number, index: number) => {
          // 每 5 颗挑一颗做「锚星」：更大更亮，轨道才读得出来是星轨而不是一圈噪点。
          Column()
            .width(this.dustSizeAt(index))
            .height(this.dustSizeAt(index))
            .borderRadius(this.dustSizeAt(index) / 2)
            .backgroundColor(this.pal().star)
            .opacity(this.dustOpacityAt(index))
            .position({
              x: this.radius + this.radius * Math.cos(angle * Math.PI / 180) - this.dustSizeAt(index) / 2,
              y: this.radius + this.radius * Math.sin(angle * Math.PI / 180) - this.dustSizeAt(index) / 2,
            })
        }, (angle: number) => 'ring-' + this.ringIndex + '-' + angle)
      }
      .width(this.radius * 2)
      .height(this.radius * 2)
      .position({ x: this.galaxySize / 2 - this.radius, y: canvasCenterY(this.ch()) - this.radius })
      .rotate({ angle: this.ringAngle, centerX: '50%', centerY: '50%' })
      .animation({ duration: this.ringDragging ? MotionTokens.instant : MotionTokens.fast, curve: MotionCurves.standard })
      .hitTestBehavior(HitTestMode.None)
      ForEach(this.circles, (circle: OrbitCircleItem) => {
        OrbitPlanet({
          name: circle.name,
          category: circle.category,
          planetSize: circle.size,
          joined: circle.joined,
          active: circle.active,
          unread: circle.unread,
          magnitude: circle.magnitude,
          selectedName: this.selectedName,
          centeredName: this.centeredName,
          galaxySize: this.galaxySize,
          canvasH: this.ch(),
          radius: this.radius,
          baseAngle: circle.baseAngle,
          ringAngle: this.ringAngle,
          live: this.live,
          onPlanet: (name: string): void => { this.onPlanet(name); },
          onGravityStart: (name: string): void => { this.onGravityStart(name); },
          onGravityEnd: (name: string, distance: number): void => { this.onGravityEnd(name, distance); },
          onGravityBlocked: (name: string): void => { this.onGravityBlocked(name); },
          onSeedTap: (name: string, postId: number): void => { this.onSeedTap(name, postId); },
        })
      }, (circle: OrbitCircleItem) => circle.name)
    }
    .width(this.galaxySize)
    .height(this.ch())
    .hitTestBehavior(HitTestMode.Transparent)
  }
}

// 独立组件使用标量 @Prop 和 translate 更新坐标，避免 keyed ForEach 复用静态 position。
@Component
struct OrbitPlanet {
  @Prop name: string = '';
  @Prop category: string = '';
  @Prop planetSize: number = 46;
  @Prop joined: boolean = false;
  @Prop @Watch('onActiveChanged') active: boolean = true;
  @Prop @Watch('onUnreadChanged') unread: number = 0;
  // 星图 Live 三期：星等 0=暗星 1=常星 2=耀星（亮度分级）
  @Prop magnitude: number = 1;
  @Prop selectedName: string = '';
  @Prop @Watch('onCenteredNameChanged') centeredName: string = '';
  @Prop galaxySize: number = 343;
  // 星图 Live 四期：全屏矩形画布高度（行星坐标与飞心目标按此中心计算）
  @Prop canvasH: number = 0;
  @StorageLink('isDarkMode') darkMode: boolean = false;
  @Prop radius: number = 0;
  @Prop baseAngle: number = 0;
  @Prop ringAngle: number = 0;
  // 与父页面可见性同步：隐藏 Tab 时不启动角标脉冲/光晕/涟漪
  @Prop @Watch('onLiveChanged') live: boolean = true;

  private pal(): StarPalette {
    return this.darkMode ? DARK_PALETTE : PAPER_PALETTE;
  }
  @State firstRippleScale: number = 0.72;
  @State firstRippleOpacity: number = 0;
  @State secondRippleScale: number = 0.72;
  @State secondRippleOpacity: number = 0;
  // 引力拖拽：拖动期间在行星自身 translate 上叠加的位移（松手归零并回报档位）
  @State dragX: number = 0;
  @State dragY: number = 0;
  @State gravityDragging: boolean = false;
  // 星子脉动（原型 seedPulse 2.2s）：有未读时角标呼吸缩放
  @State seedScale: number = 1;
  @State seedOpacity: number = 0.8;
  // 耀星光晕呼吸（原型 liveGlow 2.6s）：活跃星的柔光缓慢明暗起伏
  @State glowBreath: number = 0.6;
  private seedBreathing: boolean = false;
  private glowBreathing: boolean = false;
  private rippleArrivalTimer: number = 0;
  private rippleStaggerTimer: number = 0;
  private rippleCycleTimer: number = 0;
  onPlanet: (name: string) => void = (_name: string): void => {};
  onGravityStart: (name: string) => void = (_name: string): void => {};
  onGravityEnd: (name: string, distance: number) => void = (_name: string, _distance: number): void => {};
  onGravityBlocked: (name: string) => void = (_name: string): void => {};
  onSeedTap: (name: string, postId: number) => void = (_name: string, _postId: number): void => {};

  aboutToAppear(): void {
    if (this.live && this.isCentered()) {
      this.scheduleRipple();
    }
    if (this.live && this.unread > 0) {
      this.startSeedBreath();
    }
    if (this.live && this.active) {
      this.startGlowBreath();
    }
  }

  aboutToDisappear(): void {
    this.stopRipple();
    this.stopSeedBreath();
    this.stopGlowBreath();
  }

  // 星子出现时启动脉动（原型 seedPulse：scale 1→1.45 / opacity .8→1 交替）
  private onUnreadChanged(): void {
    if (this.live && this.unread > 0 && !this.seedBreathing) {
      this.startSeedBreath();
    }
  }

  private startSeedBreath(): void {
    if (!this.live || this.seedBreathing) {
      return;
    }
    this.seedBreathing = true;
    this.getUIContext().animateTo({ duration: 1100, curve: Curve.EaseInOut, iterations: -1, playMode: PlayMode.Alternate }, () => {
      this.seedScale = 1.45;
      this.seedOpacity = 1;
    });
  }

  private stopSeedBreath(): void {
    if (!this.seedBreathing) {
      return;
    }
    this.seedBreathing = false;
    this.getUIContext().animateTo({ duration: MotionTokens.none }, () => {
      this.seedScale = 1;
      this.seedOpacity = 0.8;
    });
  }

  // 星芒呼吸（原型 liveGlow：box-shadow 起伏 → 用 opacity 等效，仅 transform/opacity）
  private onActiveChanged(): void {
    if (this.live && this.active && !this.glowBreathing) {
      this.startGlowBreath();
    }
  }

  private startGlowBreath(): void {
    if (!this.live || this.glowBreathing) {
      return;
    }
    this.glowBreathing = true;
    this.getUIContext().animateTo({ duration: 1300, curve: Curve.EaseInOut, iterations: -1, playMode: PlayMode.Alternate }, () => {
      this.glowBreath = 1;
    });
  }

  private stopGlowBreath(): void {
    if (!this.glowBreathing) {
      return;
    }
    this.glowBreathing = false;
    this.getUIContext().animateTo({ duration: MotionTokens.none }, () => {
      this.glowBreath = 0.6;
    });
  }

  onLiveChanged(): void {
    if (this.live) {
      if (this.isCentered()) {
        this.scheduleRipple();
      }
      if (this.unread > 0) {
        this.startSeedBreath();
      }
      if (this.active) {
        this.startGlowBreath();
      }
      return;
    }
    this.stopRipple();
    this.stopSeedBreath();
    this.stopGlowBreath();
  }

  private isSelected(): boolean {
    return this.name === this.selectedName;
  }

  private isCentered(): boolean {
    return this.name === this.centeredName;
  }

  // 读屏文案：名称 + 成员身份 + 新帖数 + 选中态，替代纯视觉的金属/亮度编码。
  private a11yLabel(): string {
    let label: string = this.name;
    if (this.joined) {
      label += '，已加入';
    }
    if (this.unread > 0) {
      label += '，' + this.unread + ' 条新帖';
    }
    if (this.isSelected()) {
      label += '，已选中';
    }
    return label;
  }

  // 拖拽结束时触点距圆心的距离 = 行星轨道半径位移 + 拖拽位移的合矢量长度。
  // 用当前 ringAngle 计算行星名义位置，再叠加 drag 位移。
  private draggedDistance(): number {
    const angle: number = (this.baseAngle + this.ringAngle) * Math.PI / 180;
    const px: number = this.radius * Math.cos(angle) + this.dragX;
    const py: number = this.radius * Math.sin(angle) + this.dragY;
    return Math.sqrt(px * px + py * py);
  }

  private onGravityPanEnd(): void {
    const distance: number = this.draggedDistance();
    this.getUIContext().animateTo({ duration: MotionTokens.base, curve: MotionCurves.springSoft }, () => {
      this.dragX = 0;
      this.dragY = 0;
      this.gravityDragging = false;
    });
    if (!this.joined) {
      this.onGravityBlocked(this.name);
      return;
    }
    this.onGravityEnd(this.name, distance);
  }

  private onCenteredNameChanged(): void {
    if (this.live && this.isCentered()) {
      this.scheduleRipple();
    } else {
      this.stopRipple();
    }
  }

  private clearRippleTimers(): void {
    if (this.rippleArrivalTimer !== 0) {
      clearTimeout(this.rippleArrivalTimer);
      this.rippleArrivalTimer = 0;
    }
    if (this.rippleStaggerTimer !== 0) {
      clearTimeout(this.rippleStaggerTimer);
      this.rippleStaggerTimer = 0;
    }
    if (this.rippleCycleTimer !== 0) {
      clearTimeout(this.rippleCycleTimer);
      this.rippleCycleTimer = 0;
    }
  }

  private stopRipple(): void {
    this.clearRippleTimers();
    this.firstRippleOpacity = 0;
    this.secondRippleOpacity = 0;
  }

  private scheduleRipple(): void {
    this.stopRipple();
    this.rippleArrivalTimer = setTimeout(() => {
      this.rippleArrivalTimer = 0;
      this.playRippleCycle();
    }, MotionTokens.emphasis) as number;
  }

  private animateRipple(first: boolean): void {
    if (!this.isCentered()) {
      return;
    }
    if (first) {
      this.firstRippleScale = 0.72;
      this.firstRippleOpacity = 0.42;
      this.getUIContext().animateTo({ duration: MotionTokens.emphasis, curve: MotionCurves.decelerate }, () => {
        this.firstRippleScale = 1.62;
        this.firstRippleOpacity = 0;
      });
    } else {
      this.secondRippleScale = 0.72;
      this.secondRippleOpacity = 0.28;
      this.getUIContext().animateTo({ duration: MotionTokens.emphasis, curve: MotionCurves.decelerate }, () => {
        this.secondRippleScale = 1.46;
        this.secondRippleOpacity = 0;
      });
    }
  }

  private playRippleCycle(): void {
    if (!this.isCentered()) {
      return;
    }
    this.animateRipple(true);
    this.rippleStaggerTimer = setTimeout(() => {
      this.rippleStaggerTimer = 0;
      this.animateRipple(false);
    }, RIPPLE_STAGGER) as number;
    this.rippleCycleTimer = setTimeout(() => {
      this.rippleCycleTimer = 0;
      this.playRippleCycle();
    }, RIPPLE_CYCLE_DURATION) as number;
  }

  private left(): number {
    const angle: number = (this.baseAngle + this.ringAngle) * Math.PI / 180;
    return this.galaxySize / 2 + this.radius * Math.cos(angle) - PLANET_BOX_WIDTH / 2;
  }

  private top(): number {
    const angle: number = (this.baseAngle + this.ringAngle) * Math.PI / 180;
    return canvasCenterY(this.canvasH) + this.radius * Math.sin(angle) - PLANET_ICON_HIT_SIZE / 2;
  }

  private focusTranslateX(): number {
    if (!this.isCentered()) {
      return 0;
    }
    return this.galaxySize / 2 - (this.left() + PLANET_BOX_WIDTH / 2);
  }

  private focusTranslateY(): number {
    if (!this.isCentered()) {
      return 0;
    }
    return canvasCenterY(this.canvasH) - (this.top() + PLANET_ICON_HIT_SIZE / 2);
  }

  private planetOpacity(): number {
    if (this.isSelected()) {
      return 1;
    }
    // 星图 Live 三期：亮度由星等三档驱动（2=耀星 1=常星 0=暗星）。
    // 服务端星等缺位时（历史数据/未刷新）退回 active 近似。
    if (this.magnitude >= 2) {
      return 1;
    }
    if (this.magnitude === 1) {
      return 0.82;
    }
    return 0.5;
  }

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      Stack({ alignContent: Alignment.Center }) {
        if (this.isCentered()) {
          Circle()
            .width(RIPPLE_SECOND_SIZE)
            .height(RIPPLE_SECOND_SIZE)
            .fill(Color.Transparent)
            .stroke(this.pal().icon)
            .strokeWidth(1)
            .opacity(this.secondRippleOpacity)
            .scale({ x: this.secondRippleScale, y: this.secondRippleScale })
            .hitTestBehavior(HitTestMode.None)
          Circle()
            .width(RIPPLE_FIRST_SIZE)
            .height(RIPPLE_FIRST_SIZE)
            .fill(Color.Transparent)
            .stroke(this.pal().icon)
            .strokeWidth(1.5)
            .opacity(this.firstRippleOpacity)
            .scale({ x: this.firstRippleScale, y: this.firstRippleScale })
            .hitTestBehavior(HitTestMode.None)
        }
        // 星盘底：深色=深空蓝灰圆盘+细白边（悬浮夜空）/ 浅色=白盘+浅灰边（纸上星球）
        // 圆形改用「容器 + 半宽圆角」：Circle 形状挂 shadow 时阴影按外接矩形投影，
        // 真机上每个星球外会多出一圈方框（2026-10-29 反馈）；圆角容器的阴影跟随圆角。
        Stack()
          .width(PLANET_ICON_HIT_SIZE)
          .height(PLANET_ICON_HIT_SIZE)
          .backgroundColor(this.pal().discFill)
          .border({ width: 0.8, color: this.pal().discStroke, style: BorderStyle.Solid })
          .borderRadius(PLANET_ICON_HIT_SIZE / 2)
          .shadow(this.darkMode ? ShadowTokens.pillFloat : ShadowTokens.cardContact)
          .hitTestBehavior(HitTestMode.None)
        // 成员身份金环：已加入圈子行星外圈一道细金环（与涟漪/选中态独立叠加）。
        // 金环柔光同样不能用形状 shadow（会投出金色方框），深色用一圈低透明度粗描边近似。
        if (this.joined) {
          if (this.darkMode) {
            Circle()
              .width(PLANET_ICON_HIT_SIZE + 20)
              .height(PLANET_ICON_HIT_SIZE + 20)
              .fill(Color.Transparent)
              .stroke(this.pal().gold)
              .strokeWidth(6)
              .opacity(0.16)
              .hitTestBehavior(HitTestMode.None)
          }
          Circle()
            .width(PLANET_ICON_HIT_SIZE + 8)
            .height(PLANET_ICON_HIT_SIZE + 8)
            .fill(Color.Transparent)
            .stroke(this.pal().gold)
            .strokeWidth(1.5)
            .opacity(0.95)
            .hitTestBehavior(HitTestMode.None)
        }
        // 星芒：近 7 天有新帖的圈子带一圈「分类色」柔光（中心亮 → 边缘透明），
        // 让活跃行星在夜空里发光；颜色取分类色板，不再统一压成金色。
        if (this.active) {
          Column()
            .width(PLANET_ICON_HIT_SIZE + 26)
            .height(PLANET_ICON_HIT_SIZE + 26)
            .radialGradient({
              center: [(PLANET_ICON_HIT_SIZE + 26) / 2, (PLANET_ICON_HIT_SIZE + 26) / 2],
              radius: (PLANET_ICON_HIT_SIZE + 26) / 2,
              colors: [[categoryHue(this.category, this.darkMode) + '3D', 0], [ColorTokens.glassClear, 1]],
            })
            .opacity(this.glowBreath)
            .animation({ duration: MotionTokens.base, curve: MotionCurves.standard })
            .hitTestBehavior(HitTestMode.None)
        }
        TagIcon({
          name: this.name,
          category: this.category,
          iconSize: Math.min(28, this.planetSize * 0.46),
          tint: this.pal().icon,
          colorful: false,
        })
      }
      .width(PLANET_ICON_HIT_SIZE)
      .height(PLANET_ICON_HIT_SIZE)
      .position({ x: (PLANET_BOX_WIDTH - PLANET_ICON_HIT_SIZE) / 2, y: 0 })
      // 亮度只压图标本体，不压名称标签：暗星态的 9px 灰字曾低到不可读。
      .opacity(this.planetOpacity())
      .scale({ x: this.isSelected() ? 1.12 : 1, y: this.isSelected() ? 1.12 : 1 })
      .animation({ duration: MotionTokens.base, curve: MotionCurves.standard })
      .translate({ x: this.focusTranslateX(), y: this.focusTranslateY() })
      .animation({ duration: MotionTokens.emphasis, curve: MotionCurves.springSoft })
      .accessibilityGroup(true)
      .accessibilityText(this.a11yLabel())
      .onClick((): void => { this.onPlanet(this.name); })
      // 未读角标：行星右上角红底数字，点击直达该圈最新帖。
      // 仅在有未读时出现；hitTest 优先于行星 onClick（子节点先命中）。
      if (this.unread > 0) {
        Stack({ alignContent: Alignment.Center }) {
          // 圆形靠「容器 + 半宽圆角」保证：Circle 形状叠加 shadow 时，
          // 阴影按形状的外接矩形投影，真机上会在红点外透出一圈方框（2026-10-28 反馈）。
          // 改用带 borderRadius 的容器，阴影跟随圆角，圆点外不再有矩形边。
          Column()
            .width(20)
            .height(20)
            .backgroundColor(this.pal().badge)
            .borderRadius(10)
            .border({
              width: 0.6,
              color: this.darkMode ? '#66FFFFFF' : '#33FFFFFF',
              style: BorderStyle.Solid,
            })
            .shadow({ radius: 8, color: this.pal().seedBlue + (this.darkMode ? '80' : '40'), offsetY: 0 })
          Text(this.unread > 99 ? '99+' : String(this.unread))
            .fontSize(10)
            .fontWeight(FontWeight.Bold)
            // 未读角标统一红底白字：深/浅两套色板下都满足对比度。
            .fontColor(Color.White)
        }
        .width(22)
        .height(22)
        .position({ x: PLANET_BOX_WIDTH / 2 + 2, y: 2 })
        // 星子脉动：呼吸缩放+明暗（animateTo 无限交替，见 startSeedBreath）
        .scale({ x: this.seedScale, y: this.seedScale })
        .opacity(this.seedOpacity)
        // 视觉 22vp，但响应区补到 44vp，避免小角标不可点。
        .responseRegion({ x: -11, y: -11, width: 44, height: 44 })
        .accessibilityGroup(true)
        .accessibilityText(this.name + '，' + this.unread + ' 条新帖，点击查看最新帖')
        // 未读角标 = 该圈最新一帖（无帖子 id，postId 传 0 由父页面解析）
        .onClick((): void => { this.onSeedTap(this.name, 0); })
      }
      Column({ space: SpaceTokens.inlineTight }) {
        Text(this.name)
          .width(PLANET_BOX_WIDTH)
          .fontSize(TypeTokens.overline.size).fontFamily(TypeTokens.fontFamily)
          .fontWeight(TypeTokens.headline.weight)
          .lineHeight(TypeTokens.overline.lineHeight)
          .fontColor(this.isSelected() ? this.pal().icon : this.pal().ink)
          .textAlign(TextAlign.Center)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .width(PLANET_BOX_WIDTH)
      .position({ x: 0, y: PLANET_ICON_HIT_SIZE + SpaceTokens.xs })
      .hitTestBehavior(HitTestMode.None)
    }
    .width(PLANET_BOX_WIDTH)
    .height(PLANET_BOX_HEIGHT)
    .hitTestBehavior(HitTestMode.Transparent)
    .animation({ duration: MotionTokens.base, curve: MotionCurves.standard })
    .position({ x: 0, y: 0 })
    .translate({ x: this.left() + this.dragX, y: this.top() + this.dragY })
    // 引力拖拽：全向 Pan，拖动时叠加位移（不挂 .animation，跟手即时）；
    // 松手在 onGravityPanEnd 里用 animateTo 回弹并换算档位。飞心态禁用拖拽。
    .gesture(
      PanGesture({ direction: PanDirection.All, distance: 6 })
        .onActionStart((): void => {
          if (this.isCentered()) {
            return;
          }
          this.gravityDragging = true;
          this.onGravityStart(this.name);
        })
        .onActionUpdate((event: GestureEvent): void => {
          if (this.isCentered()) {
            return;
          }
          this.dragX = event.offsetX;
          this.dragY = event.offsetY;
        })
        .onActionEnd((): void => {
          if (this.gravityDragging) {
            this.onGravityPanEnd();
          }
        })
        .onActionCancel((): void => {
          if (this.gravityDragging) {
            this.getUIContext().animateTo({ duration: MotionTokens.base, curve: MotionCurves.springSoft }, () => {
              this.dragX = 0;
              this.dragY = 0;
              this.gravityDragging = false;
            });
          }
        })
    )
  }
}

// 帖子星子（随所属行星公转）：与 OrbitPlanet 同款「标量 @Prop + translate」模式，
// 每帧按行星实时轨道角换算自身位置——星子永远悬在行星固定一侧 60~90vp 处，
// 与行星命中盒（半径 20）几何不相交（星子命中半径 28，间距 ≥12vp），
// 从根上消除「点星星误开星球」：不存在重叠，也就不需要触点仲裁。
// 实时角度必须是「本星所属环」的标量 @Prop：数组 @Prop 在 keyed ForEach 的子组件里
// 不随父刷新（真机实测：传 ringAngles 数组时星子冻结在生成位置，行星转过去后
// 点星星命中的是路过的行星）。
@Component
struct SeedStar {
  @Prop view: SeedView = { id: 0, name: '', postId: 0, dx: 0, dy: 0, gold: false, baseAngle: 0, radius: 0, ring: -1 };
  @Prop ringAngle: number = 0;
  @Prop galaxySize: number = 343;
  @Prop canvasH: number = 0;
  @Prop pulseScale: number = 1;
  @Prop pulseOpacity: number = 0.8;
  @StorageLink('isDarkMode') darkMode: boolean = false;
  onSeedTapId: (id: number) => void = (_id: number): void => {};

  private pal(): StarPalette {
    return this.darkMode ? DARK_PALETTE : PAPER_PALETTE;
  }

  // 星子中心在画布上的当前坐标（与行星 left/top 同一公式 + 相对偏移）。
  private seedX(): number {
    const angle: number = (this.view.baseAngle + this.ringAngle) * Math.PI / 180;
    return this.galaxySize / 2 + this.view.radius * Math.cos(angle) + this.view.dx;
  }

  private seedY(): number {
    const angle: number = (this.view.baseAngle + this.ringAngle) * Math.PI / 180;
    return canvasCenterY(this.canvasH) + this.view.radius * Math.sin(angle) + this.view.dy;
  }

  build() {
    Stack({ alignContent: Alignment.Center }) {
      Text('✦')
        .fontSize(this.view.gold ? 20 : 16)
        .fontColor(this.view.gold ? this.pal().seedGold : this.pal().seedBlue)
        // 辉光分档：深色=夜空霓虹（大半径高透明）；浅色=纸上微光（小半径低透明）
        .textShadow({
          radius: this.darkMode ? 12 : 7,
          color: this.view.gold
            ? this.pal().seedGold + (this.darkMode ? '88' : '40')
            : this.pal().seedBlue + (this.darkMode ? '88' : '30'),
          offsetY: 0,
        })
        .scale({ x: this.pulseScale, y: this.pulseScale })
    }
    .width(56)
    .height(56)
    .position({ x: 0, y: 0 })
    .translate({ x: this.seedX() - 28, y: this.seedY() - 28 })
    .opacity(this.pulseOpacity)
    .transition(TransitionEffect.OPACITY.animation({ duration: MotionTokens.slow }))
    .hitTestBehavior(HitTestMode.Block)
    .accessibilityGroup(true)
    .accessibilityText('新帖，来自' + this.view.name + '，点击阅读')
    .gesture(
      TapGesture({ count: 1 })
        .onAction((): void => { this.onSeedTapId(this.view.id); })
    )
  }
}
