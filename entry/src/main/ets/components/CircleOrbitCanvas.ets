import { TagIcon } from './TagIcon';
import { resolveDisplayImageUrl } from '../services/api';
import { ColorTokens } from '../design/tokens/color';
import { MotionCurves, MotionTokens } from '../design/tokens/motion';
import { SpaceTokens } from '../design/tokens/space';
import { TypeTokens } from '../design/tokens/type';

export interface OrbitCircleItem {
  name: string;
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

interface StarDot {
  x: number;
  y: number;
  size: number;
  // 闪烁分组：0=不闪（锚定星） 1=A 组快闪 2=B 组慢闪
  tw: number;
}

// 帖子星子（原型 spawnSeed）：新帖化作光点在活跃行星旁浮现，寿命 15s，点击直达。
interface SeedItem {
  id: number;
  x: number;
  y: number;
  name: string;
  gold: boolean;
}

// 行星当前坐标（相对画布左上角，用于把星子投放到行星附近）。
interface SeedPos {
  x: number;
  y: number;
}

// ===== 星际深空配色（圈子页星图专用，深浅模式统一为「夜空」）=====
// 页面其他区域仍走 ColorTokens；星图是一块「看星星的窗」，底色恒为深空。
const SPACE_INK: string = '#ECE8DF';           // 星名文字（暖白）
const SPACE_RING: string = '#26FFFFFF';        // 轨道线（白 15%）
const SPACE_GLOW: string = '#2E4D9FFF';        // 泛光核心（饱和蓝 18%）
const SPACE_HALO: string = '#3D7DB8FF';        // 呼吸光环/中心泛光（蓝）
const SPACE_STAR: string = '#C8D4E8';          // 背景星点（冷白蓝）

// 背景星尘场（40 颗，百分比坐标铺满全屏画布；tw 分组驱动两档闪烁相位）。
const STAR_DOTS: StarDot[] = [
  { x: 5, y: 8, size: 2, tw: 1 }, { x: 14, y: 4, size: 1, tw: 0 }, { x: 22, y: 12, size: 2, tw: 2 },
  { x: 31, y: 6, size: 1, tw: 1 }, { x: 43, y: 3, size: 2, tw: 0 }, { x: 55, y: 9, size: 1, tw: 2 },
  { x: 66, y: 5, size: 2, tw: 1 }, { x: 77, y: 11, size: 1, tw: 0 }, { x: 88, y: 6, size: 2, tw: 2 },
  { x: 95, y: 13, size: 1, tw: 1 }, { x: 3, y: 22, size: 1, tw: 2 }, { x: 12, y: 28, size: 2, tw: 0 },
  { x: 26, y: 24, size: 1, tw: 1 }, { x: 37, y: 30, size: 2, tw: 2 }, { x: 49, y: 26, size: 1, tw: 0 },
  { x: 61, y: 31, size: 2, tw: 1 }, { x: 73, y: 25, size: 1, tw: 2 }, { x: 84, y: 29, size: 2, tw: 0 },
  { x: 94, y: 34, size: 1, tw: 1 }, { x: 7, y: 42, size: 2, tw: 2 }, { x: 18, y: 48, size: 1, tw: 0 },
  { x: 30, y: 44, size: 2, tw: 1 }, { x: 44, y: 50, size: 1, tw: 2 }, { x: 57, y: 45, size: 2, tw: 0 },
  { x: 69, y: 51, size: 1, tw: 1 }, { x: 81, y: 46, size: 2, tw: 2 }, { x: 92, y: 52, size: 1, tw: 0 },
  { x: 4, y: 60, size: 2, tw: 1 }, { x: 15, y: 67, size: 1, tw: 2 }, { x: 27, y: 62, size: 2, tw: 0 },
  { x: 40, y: 69, size: 1, tw: 1 }, { x: 53, y: 64, size: 2, tw: 2 }, { x: 65, y: 70, size: 1, tw: 0 },
  { x: 77, y: 65, size: 2, tw: 1 }, { x: 89, y: 71, size: 1, tw: 2 }, { x: 9, y: 80, size: 2, tw: 0 },
  { x: 21, y: 87, size: 1, tw: 1 }, { x: 35, y: 82, size: 2, tw: 2 }, { x: 50, y: 89, size: 1, tw: 0 },
  { x: 64, y: 84, size: 2, tw: 1 }, { x: 78, y: 91, size: 1, tw: 2 }, { x: 91, y: 86, size: 2, tw: 0 },
];

const PLANET_BOX_WIDTH: number = 64;
const PLANET_BOX_HEIGHT: number = 86;
const PLANET_ICON_HIT_SIZE: number = 40;
const CENTER_AVATAR_SIZE: number = 64;
const RIPPLE_FIRST_SIZE: number = 68;
const RIPPLE_SECOND_SIZE: number = 88;
const RIPPLE_CYCLE_DURATION: number = 920;
const RIPPLE_STAGGER: number = 180;

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
  @Prop radii: number[] = [0, 0, 0];
  @Prop circles: OrbitCircleItem[] = [];
  @Prop selectedName: string = '';
  @Prop centeredName: string = '';
  @Prop ringDragging: boolean = false;
  @Prop avatar: string = '';
  @Prop nickname: string = '';
  // Tab 切走时父页面置 false：暂停星子投放（隐藏组件不应持续触发自绘与状态刷新）
  @Prop live: boolean = true;
  onPlanet: (name: string) => void = (_name: string): void => {};
  // 星图 Live 二期：引力拖拽生命周期——start 时父页面冻结自转（行星不漂移），
  // end 回报触点距圆心距离（父页面换算档位并落库）；
  // onGravityBlocked：拖动未加入行星时回报（父页面弹加入引导）。
  onGravityStart: (name: string) => void = (_name: string): void => {};
  onGravityEnd: (name: string, distance: number) => void = (_name: string, _distance: number): void => {};
  onGravityBlocked: (name: string) => void = (_name: string): void => {};
  // 星子点击：直达该圈子最新帖
  onSeedTap: (name: string) => void = (_name: string): void => {};
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

  // 中心头像呼吸双环（原型 halo breath 3.2s）：仅 transform/opacity 循环动画。
  @State haloScale1: number = 0.96;
  @State haloOpacity1: number = 0.25;
  @State haloScale2: number = 0.96;
  @State haloOpacity2: number = 0.25;
  // 背景星尘闪烁：A/B 两组反相呼吸（仅 opacity），锚定星恒亮。
  @State twinkleA: number = 0.15;
  @State twinkleB: number = 0.55;

  private startHaloBreath(): void {
    this.getUIContext().animateTo({ duration: 1600, curve: Curve.EaseInOut, iterations: -1, playMode: PlayMode.Alternate }, () => {
      this.haloScale1 = 1.06;
      this.haloOpacity1 = 0.9;
    });
    setTimeout((): void => {
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

  // ===== 帖子星子层（原型 spawnSeed）=====
  // 活跃行星旁定时浮现光点（最多同屏 6 颗、寿命 15s），点击直达该圈最新帖。
  // 位置在投放时刻按行星「当前」坐标 + 随机偏移锁定，此后不随自转移动（与原型一致）。
  @State seeds: SeedItem[] = [];
  // 星子脉动（原型 seedPulse）：所有星子共享同一呼吸相位（scale/opacity 无限交替）
  @State seedPulseScale: number = 1;
  @State seedPulseOpacity: number = 0.8;
  private seedNextId: number = 1;
  private seedSpawnTimer: number = 0;
  private seedIntervalTimer: number = 0;
  private seedTimers: number[] = [];
  private seedPulseStarted: boolean = false;

  aboutToAppear(): void {
    // 首颗 1.5s 后出现，之后每 3.2s 尝试投放（原型同款节奏）
    this.seedSpawnTimer = setTimeout((): void => { this.spawnSeed(); }, 1500) as number;
    this.seedIntervalTimer = setInterval((): void => { this.spawnSeed(); }, 3200);
  }

  aboutToDisappear(): void {
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
  }

  // 行星此刻在画布上的坐标（与 OrbitPlanet.left/top 同一公式）。
  private planetPos(circle: OrbitCircleItem): SeedPos {
    const ring: number = circle.ring;
    const radius: number = this.radiusFor(ring);
    const angle: number = (circle.baseAngle + this.angleFor(ring)) * Math.PI / 180;
    return {
      x: this.cx() + radius * Math.cos(angle),
      y: this.cy() + radius * Math.sin(angle),
    };
  }

  private spawnSeed(): void {
    if (!this.live || this.seeds.length >= 6) {
      return;
    }
    const pool: OrbitCircleItem[] = this.circles.filter(
      (circle: OrbitCircleItem): boolean => circle.active || circle.unread > 0);
    if (pool.length === 0) {
      return;
    }
    if (!this.seedPulseStarted) {
      this.seedPulseStarted = true;
      this.getUIContext().animateTo({ duration: 1100, curve: Curve.EaseInOut, iterations: -1, playMode: PlayMode.Alternate }, () => {
        this.seedPulseScale = 1.45;
        this.seedPulseOpacity = 1;
      });
    }
    const circle: OrbitCircleItem = pool[Math.floor(Math.random() * pool.length)];
    const pos: SeedPos = this.planetPos(circle);
    // 绕行星环形落点（44~70vp）：避开行星 40vp 命中盒与星名标签，
    // 从源头消除「点星星落在行星上」的重叠误触。
    const ang: number = Math.random() * Math.PI * 2;
    const dist: number = 44 + Math.random() * 26;
    const seed: SeedItem = {
      id: this.seedNextId++,
      x: Math.max(22, Math.min(this.galaxySize - 22, pos.x + Math.cos(ang) * dist)),
      y: Math.max(70, Math.min(this.canvasHeight() - 96, pos.y + Math.sin(ang) * dist)),
      name: circle.name,
      gold: Math.random() < 0.16,
    };
    this.seeds.push(seed);
    const life: number = setTimeout((): void => {
      this.seeds = this.seeds.filter((s: SeedItem): boolean => s.id !== seed.id);
    }, 15000) as number;
    this.seedTimers.push(life);
  }

  private tapSeed(seed: SeedItem): void {
    this.seeds = this.seeds.filter((s: SeedItem): boolean => s.id !== seed.id);
    // 记录星子点击时刻/位置：若同一触摸又触发了下层行星的 onClick（重叠双触发），
    // handlePlanetTap 据此吞掉行星点击，避免「点星星却降落进圈」。
    this.lastSeedTapX = seed.x;
    this.lastSeedTapY = seed.y;
    this.lastSeedTapAt = Date.now();
    this.onSeedTap(seed.name);
  }

  private lastSeedTapX: number = -1;
  private lastSeedTapY: number = -1;
  private lastSeedTapAt: number = 0;

  // 点击仲裁兜底：星子浮在行星之上，若一次点击同时命中两者（星子恰与行星重叠时），
  // 视觉意图是「点星星」——行星点击路径发现头顶有星子覆盖，直接转交星子处理。
  private seedCovering(x: number, y: number): SeedItem | null {
    for (let index: number = 0; index < this.seeds.length; index++) {
      const seed: SeedItem = this.seeds[index];
      if (Math.abs(seed.x - x) <= 30 && Math.abs(seed.y - y) <= 30) {
        return seed;
      }
    }
    return null;
  }

  private handlePlanetTap(name: string): void {
    const circle: OrbitCircleItem | undefined = this.circles.find(
      (item: OrbitCircleItem): boolean => item.name === name);
    if (circle !== undefined) {
      const pos: SeedPos = this.planetPos(circle);
      // 刚点过星子（350ms 内、44vp 内）→ 本次行星点击是重叠双触发的副产物，吞掉。
      if (Date.now() - this.lastSeedTapAt < 350
        && Math.abs(pos.x - this.lastSeedTapX) <= 44 && Math.abs(pos.y - this.lastSeedTapY) <= 44) {
        return;
      }
      // 行星头顶悬着星子 → 用户视觉意图是点星星，转交星子处理。
      const seed: SeedItem | null = this.seedCovering(pos.x, pos.y);
      if (seed !== null) {
        this.tapSeed(seed);
        return;
      }
    }
    this.onPlanet(name);
  }

  @Builder
  private seedLayer(): void {
    ForEach(this.seeds, (seed: SeedItem) => {
      // 星星样式（✦ 四角星芒）：金色=每日一帖级，蓝色=普通新帖。
      // 命中区放大到 44vp（原型 10px 难点），Block 阻断父层 Pan 竞争，
      // TapGesture 优先于 onClick（父 Stack 的横向 Pan 会吞掉 click）。
      Stack({ alignContent: Alignment.Center }) {
        Text('✦')
          .fontSize(seed.gold ? 20 : 16)
          .fontColor(seed.gold ? '#FFD27D' : '#7DB8FF')
          .textShadow({ radius: 12, color: seed.gold ? '#A0640088' : '#4D9FFF88', offsetY: 0 })
      }
      .width(44)
      .height(44)
      .position({ x: seed.x - 22, y: seed.y - 22 })
      .scale({ x: this.seedPulseScale, y: this.seedPulseScale })
      .opacity(this.seedPulseOpacity)
      .transition(TransitionEffect.OPACITY.animation({ duration: MotionTokens.slow }))
      .hitTestBehavior(HitTestMode.Block)
      .gesture(
        TapGesture({ count: 1 })
          .onAction((): void => { this.tapSeed(seed); })
      )
    }, (seed: SeedItem) => String(seed.id))
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
        .fill(SPACE_STAR)
        .opacity(dot.tw === 0 ? 0.45 : (dot.tw === 1 ? this.twinkleA : this.twinkleB))
        .position({ x: this.galaxySize * dot.x / 100, y: this.canvasHeight() * dot.y / 100 })
        .hitTestBehavior(HitTestMode.None)
    }, (_dot: StarDot, index: number) => 'star_' + index)
  }

  @Builder
  private orbitRing(ring: number): void {
    OrbitRingLayer({
      galaxySize: this.galaxySize,
      canvasH: this.canvasHeight(),
      radius: this.radiusFor(ring),
      ringAngle: this.angleFor(ring),
      circles: this.circlesFor(ring),
      selectedName: this.selectedName,
      centeredName: this.centeredName,
      ringDragging: this.ringDragging,
      // 行星点击走仲裁：星子悬于行星之上时让位给星子（防误触进圈）
      onPlanet: (name: string): void => { this.handlePlanetTap(name); },
      onGravityStart: (name: string): void => { this.onGravityStart(name); },
      onGravityEnd: (name: string, distance: number): void => { this.onGravityEnd(name, distance); },
      onGravityBlocked: (name: string): void => { this.onGravityBlocked(name); },
      onSeedTap: (name: string): void => { this.onSeedTap(name); },
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
        .stroke(SPACE_HALO)
        .strokeWidth(1)
        .opacity(this.haloOpacity1)
        .scale({ x: this.haloScale1, y: this.haloScale1 })
        .hitTestBehavior(HitTestMode.None)
      Circle()
        .width(86)
        .height(86)
        .fill(Color.Transparent)
        .stroke(SPACE_HALO)
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
      // 深空底色：恒为夜空（不随系统深浅色切换）——星图是一块「看星星的窗」。
      Column()
        .width('100%')
        .height('100%')
        .linearGradient({
          angle: 180,
          colors: [['#070B16', 0], ['#0B1224', 0.45], ['#0E1830', 1]],
        })
      Column()
        .width('100%')
        .height('100%')
        // 星系泛光：中心取星系中心（宽/2, 高×0.42），半径铺满画布，
        // 饱和蓝核心向外衰减至透明，营造「身处星云之中」的沉浸感。
        .radialGradient({
          center: [this.cx(), this.cy()],
          radius: Math.max(this.galaxySize, this.canvasHeight()) * 0.72,
          colors: [[SPACE_GLOW, 0], [ColorTokens.glassClear, 1]],
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
  @Prop radius: number = 0;
  @Prop ringAngle: number = 0;
  @Prop circles: OrbitCircleItem[] = [];
  @Prop selectedName: string = '';
  @Prop centeredName: string = '';
  @Prop ringDragging: boolean = false;
  // 星图 Live 四期：全屏矩形画布高度（中心=宽/2、高×0.42）
  @Prop canvasH: number = 0;
  onPlanet: (name: string) => void = (_name: string): void => {};
  onGravityStart: (name: string) => void = (_name: string): void => {};
  onGravityEnd: (name: string, distance: number) => void = (_name: string, _distance: number): void => {};
  onGravityBlocked: (name: string) => void = (_name: string): void => {};
  onSeedTap: (name: string) => void = (_name: string): void => {};

  private ch(): number {
    return this.canvasH > 0 ? this.canvasH : this.galaxySize;
  }

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      // 轨道线：深空中细白环 + 微光（原型 glowline）
      Circle()
        .width(this.radius * 2)
        .height(this.radius * 2)
        .fill(Color.Transparent)
        .stroke(SPACE_RING)
        .strokeWidth(1)
        .opacity(0.9)
        .shadow({ radius: 6, color: '#1A4D9FFF', offsetY: 0 })
        .position({ x: this.galaxySize / 2 - this.radius, y: canvasCenterY(this.ch()) - this.radius })
        .rotate({ angle: this.ringAngle, centerX: '50%', centerY: '50%' })
        .animation({ duration: this.ringDragging ? MotionTokens.instant : MotionTokens.fast, curve: MotionCurves.standard })
        .hitTestBehavior(HitTestMode.None)
      ForEach(this.circles, (circle: OrbitCircleItem) => {
        OrbitPlanet({
          name: circle.name,
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
          onPlanet: (name: string): void => { this.onPlanet(name); },
          onGravityStart: (name: string): void => { this.onGravityStart(name); },
          onGravityEnd: (name: string, distance: number): void => { this.onGravityEnd(name, distance); },
          onGravityBlocked: (name: string): void => { this.onGravityBlocked(name); },
          onSeedTap: (name: string): void => { this.onSeedTap(name); },
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
  @Prop planetSize: number = 46;
  @Prop joined: boolean = false;
  @Prop active: boolean = true;
  @Prop @Watch('onUnreadChanged') unread: number = 0;
  // 星图 Live 三期：星等 0=暗星 1=常星 2=耀星（光晕 + 亮度分级）
  @Prop @Watch('onMagnitudeChanged') magnitude: number = 1;
  @Prop selectedName: string = '';
  @Prop @Watch('onCenteredNameChanged') centeredName: string = '';
  @Prop galaxySize: number = 343;
  // 星图 Live 四期：全屏矩形画布高度（行星坐标与飞心目标按此中心计算）
  @Prop canvasH: number = 0;
  @Prop radius: number = 0;
  @Prop baseAngle: number = 0;
  @Prop ringAngle: number = 0;
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
  // 耀星光晕呼吸（原型 liveGlow 2.6s）：星等 2 的光斑明暗起伏
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
  onSeedTap: (name: string) => void = (_name: string): void => {};

  aboutToAppear(): void {
    if (this.isCentered()) {
      this.scheduleRipple();
    }
    if (this.unread > 0) {
      this.startSeedBreath();
    }
    if (this.magnitude >= 2) {
      this.startGlowBreath();
    }
  }

  aboutToDisappear(): void {
    this.stopRipple();
  }

  // 星子出现时启动脉动（原型 seedPulse：scale 1→1.45 / opacity .8→1 交替）
  private onUnreadChanged(): void {
    if (this.unread > 0 && !this.seedBreathing) {
      this.startSeedBreath();
    }
  }

  private startSeedBreath(): void {
    if (this.seedBreathing) {
      return;
    }
    this.seedBreathing = true;
    this.getUIContext().animateTo({ duration: 1100, curve: Curve.EaseInOut, iterations: -1, playMode: PlayMode.Alternate }, () => {
      this.seedScale = 1.45;
      this.seedOpacity = 1;
    });
  }

  // 耀星光晕呼吸（原型 liveGlow：box-shadow 起伏 → 用 opacity 等效，仅 transform/opacity）
  private onMagnitudeChanged(): void {
    if (this.magnitude >= 2 && !this.glowBreathing) {
      this.startGlowBreath();
    }
  }

  private startGlowBreath(): void {
    if (this.glowBreathing) {
      return;
    }
    this.glowBreathing = true;
    this.getUIContext().animateTo({ duration: 1300, curve: Curve.EaseInOut, iterations: -1, playMode: PlayMode.Alternate }, () => {
      this.glowBreath = 1;
    });
  }

  private isSelected(): boolean {
    return this.name === this.selectedName;
  }

  private isCentered(): boolean {
    return this.name === this.centeredName;
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
    if (this.isCentered()) {
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

  // 耀星光晕半径（星等 2 才有；选中额外增强）。返回 0 表示不绘制光晕。
  private glowSize(): number {
    if (this.magnitude < 2) {
      return 0;
    }
    return this.isSelected() ? PLANET_ICON_HIT_SIZE + 26 : PLANET_ICON_HIT_SIZE + 16;
  }

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      Stack({ alignContent: Alignment.Center }) {
        if (this.isCentered()) {
          Circle()
            .width(RIPPLE_SECOND_SIZE)
            .height(RIPPLE_SECOND_SIZE)
            .fill(Color.Transparent)
            .stroke('#7DB8FF')
            .strokeWidth(1)
            .opacity(this.secondRippleOpacity)
            .scale({ x: this.secondRippleScale, y: this.secondRippleScale })
            .hitTestBehavior(HitTestMode.None)
          Circle()
            .width(RIPPLE_FIRST_SIZE)
            .height(RIPPLE_FIRST_SIZE)
            .fill(Color.Transparent)
            .stroke('#7DB8FF')
            .strokeWidth(1.5)
            .opacity(this.firstRippleOpacity)
            .scale({ x: this.firstRippleScale, y: this.firstRippleScale })
            .hitTestBehavior(HitTestMode.None)
        }
        // 星盘底：深空蓝灰圆盘 + 细白边——行星「悬浮在夜空」的实体感（原型 .disc 深色模式）
        Circle()
          .width(PLANET_ICON_HIT_SIZE)
          .height(PLANET_ICON_HIT_SIZE)
          .fill('#1A2233')
          .stroke('#33FFFFFF')
          .strokeWidth(0.8)
          .shadow({ radius: 10, color: '#66000000', offsetY: 3 })
          .hitTestBehavior(HitTestMode.None)
        // 成员身份金环：已加入圈子行星外圈一道细金环（与涟漪/选中态独立叠加）
        if (this.joined) {
          Circle()
            .width(PLANET_ICON_HIT_SIZE + 8)
            .height(PLANET_ICON_HIT_SIZE + 8)
            .fill(Color.Transparent)
            .stroke('#D9A441')
            .strokeWidth(1.5)
            .opacity(0.95)
            .shadow({ radius: 6, color: '#80A06400', offsetY: 0 })
            .hitTestBehavior(HitTestMode.None)
        }
        // 星图 Live 三期：耀星星等光晕——中心亮、边缘衰减的软光斑，衬托图标。
        if (this.glowSize() > 0) {
          Column()
            .width(this.glowSize())
            .height(this.glowSize())
            .radialGradient({
              center: [this.glowSize() / 2, this.glowSize() / 2],
              radius: this.glowSize() / 2,
              colors: [['#594D9FFF', 0], [ColorTokens.glassClear, 1]],
            })
            .opacity(this.glowBreath)
            .animation({ duration: MotionTokens.base, curve: MotionCurves.standard })
            .hitTestBehavior(HitTestMode.None)
        }
        TagIcon({ name: this.name, iconSize: Math.min(28, this.planetSize * 0.46), tint: '#7DB8FF', colorful: false })
      }
      .width(PLANET_ICON_HIT_SIZE)
      .height(PLANET_ICON_HIT_SIZE)
      .position({ x: (PLANET_BOX_WIDTH - PLANET_ICON_HIT_SIZE) / 2, y: 0 })
      .scale({ x: this.isSelected() ? 1.12 : 1, y: this.isSelected() ? 1.12 : 1 })
      .animation({ duration: MotionTokens.base, curve: MotionCurves.standard })
      .translate({ x: this.focusTranslateX(), y: this.focusTranslateY() })
      .animation({ duration: MotionTokens.emphasis, curve: MotionCurves.springSoft })
      .onClick((): void => { this.onPlanet(this.name); })
      // 未读角标：行星右上角发光小星（✦+数字），点击直达该圈最新帖。
      // 仅在有未读时出现；hitTest 优先于行星 onClick（子节点先命中）。
      if (this.unread > 0) {
        Stack({ alignContent: Alignment.Center }) {
          Circle()
            .width(20)
            .height(20)
            .fill('#4D9FFF')
            .stroke('#66FFFFFF')
            .strokeWidth(0.6)
            .shadow({ radius: 8, color: '#804D9FFF', offsetY: 0 })
          Text(this.unread > 99 ? '99+' : String(this.unread))
            .fontSize(9)
            .fontWeight(FontWeight.Bold)
            .fontColor(Color.White)
        }
        .width(22)
        .height(22)
        .position({ x: PLANET_BOX_WIDTH / 2 + 2, y: 2 })
        // 星子脉动：呼吸缩放+明暗（animateTo 无限交替，见 startSeedBreath）
        .scale({ x: this.seedScale, y: this.seedScale })
        .opacity(this.seedOpacity)
        .onClick((): void => { this.onSeedTap(this.name); })
      }
      Column({ space: SpaceTokens.inlineTight }) {
        Text(this.name)
          .width(PLANET_BOX_WIDTH)
          .fontSize(9).fontFamily(TypeTokens.fontFamily)
          .fontWeight(TypeTokens.headline.weight)
          .lineHeight(TypeTokens.overline.lineHeight)
          .fontColor(this.isSelected() ? '#7DB8FF' : SPACE_INK)
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
    .opacity(this.planetOpacity())
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
