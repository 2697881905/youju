// 烟花特效覆盖层：数据面板「作品优秀」庆祝用 Canvas 粒子引擎（v15 · 全表情 emoji）。
//
// v24（2026-11-24 用户要求「更弹一点」）：左右反弹 0.5→0.68、落地弹跳衰减 0.38→0.52、
//   弹跳上限 5→7、触发阈值 0.8→0.6、触地摩擦 0.7→0.75、挤压幅度 14%→18%
// v23（2026-11-24 用户要求「碰撞更自然」）：①碰撞挤压回弹——撞到左右/底部瞬间横向
//   压扁 14%、纵向拉伸 6%，约 170ms 恢复（squash & stretch，卡通但自然）；②弹跳衰减
//   0.45→0.38、上限 5 次、触发阈值 1.0→0.8——能量自然递减到静止；③碰撞角度 ±8% 随机
//   抖动（打破机械对称）；④判定半径改为字号 0.42 倍——贴合 emoji 字形可见边界
// v22（2026-11-24 用户要求）：🚀 增加尾焰粒子（金橙色小火花从喷口向后喷流、快速消散）；
//   🚀 上升速度再 +30%（初速 -20.563、加速度 -0.554）；炸开加速度再 +50%（0.686→1.029）；
//   爆炸强度再 +40%（球壳 16.6-27.3、环形 15.5-16.7）
// v21（2026-11-24 用户要求）：🚀 上升速度再 +30%（初速 -15.818、加速度 -0.426）；
//   炸开加速度再 +30%（0.528→0.686）；爆炸强度再 +30%（球壳 11.8-19.5、环形 11.1-12.0）
// v20（2026-11-24 用户要求）：🚀 上升速度再 +20%（初速 -12.168、加速度 -0.328）；
//   炸开加速度再 +30%（0.406→0.528）；爆炸强度再 +30%（球壳 9.1-15、环形 8.5-9.2，
//   速度分布加宽）；新增出场延迟 0-140ms——同一次爆炸错落展开，观感更自然
// v19（2026-11-24 用户要求）：炸开加速度再 +30%（0.312→0.406）；🚀 上升速度再 +30%
//   （初速 -7.8→-10.14、加速度 -0.21→-0.273）
// v18（2026-11-24 用户要求）：🚀 上升速度 +50%（初速 -5.2→-7.8、加速度 -0.14→-0.21）；
//   Emoji 炸开加速度 +30%（基础重力 0.24→0.312）；数量保持不变（主粒 6-8 / 余晖 2）；
//   表情池丰富 3 个：新增 😆 😎 🥰（共 7 个表情脸）
// v17（2026-11-23 用户反馈「加速度太低 / 炸开全垂直下落 / 触底没反弹 / 爆炸强度要大」）：
//   ① 爆炸强度：球壳初速 7-10（原 4.2-6.2）、环形 6.5-7.1——直接横向四散炸开
//   ② 消除「全垂直下落」：取消前段强阻力（0.94），全程弱阻力 0.99——横向速度维持更久
//   ③ 加速度：基础重力 0.24、递增尺度 700ms（末期 3-4×），下坠越来越猛
//   ④ 触底反弹可见：弹跳衰减 0.22→0.45、次数上限 3——落地能弹起明显高度再滑行静止
// v16（2026-11-23 用户反馈「炸开后就渐隐 / 加速度再高 / 碰屏幕后再渐隐 / 底部也要碰撞」）：
//   ① 寿命与碰撞解耦：未碰撞前不淡出（寿命冻结）——必飞到碰壁或落地；左右/底部碰撞后
//      才开始渐隐计时；落地静止后停留 1.4s 再淡出（散落一地留影保留）
//   ② 加速度再加大：基础重力 0.12→0.20，递增尺度 900→650ms（末期约 3×）
//   ③ 底部碰撞落地：小弹跳→摩擦滑行→静止停留渐隐；落点 = 画布底部 = 屏幕底部
// v15（2026-11-23 用户四条反馈）：
//   ① 数量再减：主粒每波 6-8 个（原 10-14）、余晖 2 个——画面克制不拥挤
//   ② 散落真实化：落地不再瞬间吸住——先小弹跳（速度够大时最多弹 2 次、衰减 0.22），
//      再贴地横向摩擦滑行（0.86/帧），速度低于阈值才静止落定——「掉在地上滚两下」的真实感
//   ③ 落点=屏幕底部：Canvas 高度改为撑满面板全高（面板 FIT_CONTENT 贴底，
//      其底部即屏幕底部）；爆炸中心仍封顶在 180（视觉上位于顶部区域）
//   ④ 碰撞：左右边缘反弹（系数 0.5）+ 底部小弹跳/摩擦/静止，判定半径均为 emoji 自身字号
// 保留：全 emoji（😊🤩😍😄 主粒、🥳 中心、🚀 升空）、密度换算字号、球壳/环形交替、
// 三段阻力、递增重力、30fps、无衬底蒙层。
const FRAME_INTERVAL: number = 33;                 // 帧间隔（30fps）
const LAUNCH_TIMES: number[] = [300, 1150, 2000, 2850, 3700];
const ROCKET_ACCEL: number = -0.554;               // v22：火箭加速度再 +30%
const ROCKET_INIT_VY: number = -20.563;            // v22：火箭初速再 +30%
const PARTICLE_GRAVITY: number = 1.029;            // 基础重力（v22：再 +50%）
const FLAME_COLORS: string[] = ['#FFD93B', '#FF9F43', '#FFF3DC']; // 🚀 尾焰色（v22）
const GRAVITY_RAMP_MS: number = 700;               // 重力随存活时间递增（末期约 3-4×）
const LAND_HOLD_MS: number = 1400;                 // 落定后停留渐隐时长
const FLIGHT_TOP: number = 180;                    // 爆点中心距画布顶部上限（保持顶部区域）
const BURST_CENTER_MIN: number = 0.42;
const BURST_CENTER_MAX: number = 0.58;
const EDGE_CULL: number = 10;
const END_PAD: number = 3200;                      // 末波后的收尾窗口（落定 emoji 停留约 2.5s）
const FLASH_MS: number = 180;
const FLASH_START_PX: number = 32;
const FLASH_GROW_PX: number = 56;
const SIDE_RESTITUTION: number = 0.68;             // 左右边缘反弹系数（v24：更弹）
const GROUND_BOUNCE_MAX: number = 7;               // 落地弹跳次数上限（v24：弹更多次）
const GROUND_BOUNCE_FACTOR: number = 0.52;         // 落地弹跳衰减（v24：每次弹更高）
const COLLIDE_JITTER: number = 0.08;               // 碰撞角度随机抖动幅度（v23）
const GROUND_FRICTION: number = 0.75;              // 触地瞬间横向摩擦（v24：略滑，弹得更远）
const SLIDE_FRICTION: number = 0.86;               // 贴地滑行摩擦
const LAND_VX_STOP: number = 0.25;                 // 静止阈值（横向）
const LAND_VY_STOP: number = 0.6;                  // 静止阈值（纵向）
const EMOJI_RADIUS_RATIO: number = 0.42;           // 碰撞判定半径 = 字号 × 该比例（v23）

const KIND_FLASH: number = 0;   // 🥳 中心闪光
const KIND_EMOJI: number = 1;   // 表情脸粒子
const KIND_FLAME: number = 2;   // 🚀 尾焰火花（v22）

const EMOJI_FACES: string[] = ['😊', '🤩', '😍', '😄', '😆', '😎', '🥰']; // v18：表情丰富至 7 个

interface FwParticle {
  kind: number;
  x: number;
  y: number;
  vx: number;
  vy: number;
  z: number;        // 深度 [-1,1]：1 = 近端（大/快）
  life: number;
  maxLife: number;
  fontSize: number; // 字号（vp，绘制时 × fontScale）
  emoji: string;
  landed: boolean;  // 已落定：静止留在底部，停留计时后渐隐
  bounces: number;  // 已发生的地面弹跳次数
  collided: boolean; // 已发生过左右/底部碰撞（碰撞后才开始渐隐计时）
  spawnDelay: number; // 出场延迟 ms（同一次爆炸错落展开，v20）
  size: number;     // 尾焰火花半径（v22；emoji 粒子为 0）
  color: string;    // 尾焰火花颜色（v22）
  squash: number;   // 碰撞挤压量 1→0（v23：撞壁瞬间压扁回弹）
}

interface FwRocket {
  x: number;
  y: number;
  vy: number;
  burstY: number;
  alive: boolean;
  isRing: boolean;
}

@Component
export struct FireworksOverlay {
  onFinish: () => void = (): void => {};
  private settings: RenderingContextSettings = new RenderingContextSettings(true);
  private ctx: CanvasRenderingContext2D = new CanvasRenderingContext2D(this.settings);
  private particles: FwParticle[] = [];
  private rockets: FwRocket[] = [];
  private timer: number = 0;
  private startedAt: number = 0;
  private nextLaunchIdx: number = 0;
  private wind: number = 0;
  // 屏幕密度：Canvas font 的 px 为物理像素，vp 数值需 × density 才是目标视觉大小
  private fontScale: number = 1;

  aboutToAppear(): void {
    this.startedAt = Date.now();
    this.wind = (Math.random() - 0.5) * 0.02;
    this.fontScale = this.getUIContext().vp2px(1);
    this.timer = setInterval((): void => {
      this.tick();
    }, FRAME_INTERVAL) as number;
  }

  aboutToDisappear(): void {
    this.stop();
  }

  private stop(): void {
    if (this.timer !== 0) {
      clearInterval(this.timer);
      this.timer = 0;
    }
  }

  private pushEmoji(x: number, y: number, vx: number, vy: number,
    z: number, life: number, fontSize: number, emoji: string): void {
    const p: FwParticle = {
      kind: KIND_EMOJI,
      x: x,
      y: y,
      vx: vx,
      vy: vy,
      z: z,
      life: life,
      maxLife: life,
      fontSize: fontSize,
      emoji: emoji,
      landed: false,
      bounces: 0,
      collided: false,
      spawnDelay: Math.random() * 140,
      size: 0,
      color: '',
      squash: 0,
    };
    this.particles.push(p);
  }

  private pushFlash(x: number, y: number): void {
    const p: FwParticle = {
      kind: KIND_FLASH,
      x: x,
      y: y,
      vx: 0,
      vy: 0,
      z: 1,
      life: FLASH_MS,
      maxLife: FLASH_MS,
      fontSize: FLASH_START_PX,
      emoji: '🥳',
      landed: false,
      bounces: 0,
      collided: false,
      spawnDelay: 0,
      size: 0,
      color: '',
      squash: 0,
    };
    this.particles.push(p);
  }

  // 🚀 尾焰火花（v22）：金橙色小圆点，从喷口向后下方喷出，短寿命快速消散
  private pushFlame(x: number, y: number): void {
    const p: FwParticle = {
      kind: KIND_FLAME,
      x: x,
      y: y,
      vx: (Math.random() - 0.5) * 3,
      vy: 4 + Math.random() * 5,
      z: 1,
      life: 150 + Math.random() * 170,
      maxLife: 320,
      fontSize: 0,
      emoji: '',
      landed: false,
      bounces: 0,
      collided: false,
      spawnDelay: 0,
      size: 2 + Math.random() * 2.6,
      color: FLAME_COLORS[Math.floor(Math.random() * FLAME_COLORS.length)],
      squash: 0,
    };
    this.particles.push(p);
  }

  private spawnRocket(isFinal: boolean, isRing: boolean): void {
    const w: number = this.ctx.width;
    const h: number = this.ctx.height;
    // 爆炸中心封顶 180vp：Canvas 撑满面板全高后，烟花仍在顶部区域炸开
    const ratio: number = isFinal
      ? 0.56
      : BURST_CENTER_MIN + Math.random() * (BURST_CENTER_MAX - BURST_CENTER_MIN - 0.06);
    const r: FwRocket = {
      x: w * (0.22 + Math.random() * 0.56),
      y: h + 8,
      vy: ROCKET_INIT_VY - Math.random() * 1.4,
      burstY: Math.min(h * ratio, FLIGHT_TOP),
      alive: true,
      isRing: isRing,
    };
    this.rockets.push(r);
  }

  // 高空爆裂：🥳 中心 + 表情脸主粒（6-8，数量克制）+ 2 个大号余晖表情脸
  private explode(x: number, y: number, isFinal: boolean, isRing: boolean): void {
    this.pushFlash(x, y);
    const emojiCount: number = 6 + Math.floor(Math.random() * 3);
    for (let i: number = 0; i < emojiCount; i++) {
      let ang: number;
      let spd: number;
      let depth: number;
      let planar: number;
      if (isRing) {
        ang = (i / emojiCount) * Math.PI * 2 + Math.random() * 0.05;
        spd = 15.47 + Math.random() * 1.27;
        depth = 0;
        planar = 1;
      } else {
        depth = Math.random() * 2 - 1;
        planar = Math.sqrt(1 - depth * depth);
        ang = Math.random() * Math.PI * 2;
        // 爆炸强度再 +40%（球壳 16.6-27.3，v22）
        spd = (16.56 + Math.random() * 10.74) * (0.65 + (depth + 1) * 0.22);
      }
      const life: number = (isFinal ? 1050 : 950) + Math.random() * 500;
      const fontSize: number = (36 + Math.random() * 20) * (0.8 + (depth + 1) * 0.2);
      this.pushEmoji(x, y,
        Math.cos(ang) * planar * spd,
        Math.sin(ang) * planar * spd,
        depth, life, fontSize, EMOJI_FACES[i % EMOJI_FACES.length]);
    }
    // 余晖：2 个大号慢速表情脸
    for (let i: number = 0; i < 2; i++) {
      const ang: number = Math.random() * Math.PI * 2;
      const spd: number = 0.7 + Math.random() * 1.3;
      this.pushEmoji(x, y,
        Math.cos(ang) * spd, Math.sin(ang) * spd,
        0.2 + Math.random() * 0.3,
        1700 + Math.random() * 400,
        40 + Math.random() * 16,
        EMOJI_FACES[i % EMOJI_FACES.length]);
    }
  }

  private tick(): void {
    // Canvas 尚未完成尺寸布局（onReady 前 width 为 0）时跳过
    if (this.ctx.width <= 0 || this.ctx.height <= 0) {
      return;
    }
    const now: number = Date.now() - this.startedAt;
    // 波次调度：第 2、5 波为环形形态
    while (this.nextLaunchIdx < LAUNCH_TIMES.length && now >= LAUNCH_TIMES[this.nextLaunchIdx]) {
      this.spawnRocket(this.nextLaunchIdx === LAUNCH_TIMES.length - 1,
        this.nextLaunchIdx % 3 === 1);
      this.nextLaunchIdx += 1;
    }
    // 火箭：爬升 + 尾焰喷流 → 爆点爆裂
    for (let i: number = 0; i < this.rockets.length; i++) {
      const r: FwRocket = this.rockets[i];
      r.vy += ROCKET_ACCEL;
      r.y += r.vy;
      // 🚀 尾焰：每帧从喷口向后喷 2-3 颗金橙火花（v22）
      const flameCount: number = 2 + Math.floor(Math.random() * 2);
      for (let f: number = 0; f < flameCount; f++) {
        this.pushFlame(r.x + (Math.random() - 0.5) * 4, r.y + 10);
      }
      if (r.y <= r.burstY || r.vy >= 0) {
        this.explode(r.x, r.y, this.nextLaunchIdx >= LAUNCH_TIMES.length, r.isRing);
        r.alive = false;
      }
    }
    this.rockets = this.rockets.filter((r: FwRocket): boolean => r.alive);
    const w: number = this.ctx.width;
    const h: number = this.ctx.height;
    // 粒子：落定者冻结静止；其余表情脸三段阻力 + 递增重力 + 碰撞/落地
    const next: FwParticle[] = [];
    for (let i: number = 0; i < this.particles.length; i++) {
      const p: FwParticle = this.particles[i];
      if (p.landed) {
        // 落定：静止在底部，停留计时（1.4s）内可见，随后淡出散场
        p.life -= FRAME_INTERVAL;
        if (p.life > 0) {
          next.push(p);
        }
        continue;
      }
      if (p.spawnDelay > 0) {
        // 出场延迟（0-140ms 随机）：同一次爆炸错落展开，观感更自然（v20）
        p.spawnDelay -= FRAME_INTERVAL;
        next.push(p);
        continue;
      }
      if (p.kind === KIND_FLASH) {
        p.life -= FRAME_INTERVAL;
        if (p.life > 0) {
          next.push(p);
        }
        continue;
      }
      // 尾焰火花（v22）：无条件衰减 + 轻阻力 + 微重力，短寿命自然消散
      if (p.kind === KIND_FLAME) {
        p.life -= FRAME_INTERVAL;
        if (p.life <= 0) {
          continue;
        }
        p.vx *= 0.96;
        p.vy += 0.25;
        p.x += p.vx;
        p.y += p.vy;
        next.push(p);
        continue;
      }
      // 未碰撞前不淡出（寿命冻结）——必飞到碰壁或落地后才开始渐隐
      if (p.collided) {
        p.life -= FRAME_INTERVAL;
        if (p.life <= 0) {
          continue;
        }
      }
      // 全程弱阻力：保持爆炸瞬间的四散横向速度，避免快速「垂直下落」（v17）
      const drag: number = 0.99;
      p.vx *= drag;
      p.vy *= drag;
      p.vx += this.wind;
      // 加速度：重力随存活时间递增——爆炸后越来越快地坠落
      const age: number = p.maxLife - p.life;
      p.vy += PARTICLE_GRAVITY * (1 + age / GRAVITY_RAMP_MS);
      p.x += p.vx;
      p.y += p.vy;
      const half: number = p.fontSize * EMOJI_RADIUS_RATIO;
      // 左右边缘：夹紧 + 反弹（切向摩擦 + 角度随机抖动，v23；顶部不碰撞，飞出即裁）
      if (p.x < half) {
        p.x = half;
        p.vx = Math.abs(p.vx) * SIDE_RESTITUTION * (1 + (Math.random() - 0.5) * COLLIDE_JITTER * 2);
        p.vy *= 0.92;
        p.squash = 1;
        p.collided = true;
      } else if (p.x > w - half) {
        p.x = w - half;
        p.vx = -Math.abs(p.vx) * SIDE_RESTITUTION * (1 + (Math.random() - 0.5) * COLLIDE_JITTER * 2);
        p.vy *= 0.92;
        p.squash = 1;
        p.collided = true;
      }
      // 地面（画布底部 = 面板底部 = 屏幕底部）：能量自然递减的弹跳（v23）
      if (p.y >= h - half) {
        p.y = h - half;
        p.collided = true;
        if (Math.abs(p.vy) > 0.6 && p.bounces < GROUND_BOUNCE_MAX) {
          p.vy = -Math.abs(p.vy) * GROUND_BOUNCE_FACTOR * (1 + (Math.random() - 0.5) * 0.12);
          p.bounces += 1;
          p.squash = 1;
        } else {
          p.vy = 0;
        }
        p.vx *= GROUND_FRICTION;
      }
      // 贴地滑行与静止判定
      if (p.y >= h - half - 0.5) {
        p.vx *= SLIDE_FRICTION;
        if (Math.abs(p.vx) < LAND_VX_STOP && Math.abs(p.vy) < LAND_VY_STOP) {
          p.vx = 0;
          p.vy = 0;
          p.landed = true;
          p.squash = 0;
          // 落地停留：重置寿命为停留时长（渐隐同源：alpha 随 life 递减）
          p.life = LAND_HOLD_MS;
        }
      }
      // 挤压量逐帧衰减（约 170ms 恢复，v23）
      if (p.squash > 0) {
        p.squash = Math.max(p.squash - 0.18, 0);
      }
      next.push(p);
    }
    this.particles = next;
    this.render();
    const endAt: number = LAUNCH_TIMES[LAUNCH_TIMES.length - 1] + END_PAD;
    if (now >= endAt && this.rockets.length === 0 && this.particles.length === 0) {
      this.stop();
      this.onFinish();
    }
  }

  private render(): void {
    const w: number = this.ctx.width;
    const h: number = this.ctx.height;
    this.ctx.clearRect(0, 0, w, h);
    // 火箭：🚀 emoji 本体（字形默认朝右上 45°，逆时针转正朝上）
    this.ctx.font = Math.round(24 * this.fontScale) + 'px';
    this.ctx.textAlign = 'center';
    this.ctx.textBaseline = 'middle';
    for (let i: number = 0; i < this.rockets.length; i++) {
      const r: FwRocket = this.rockets[i];
      if (r.y >= h + EDGE_CULL) {
        continue;
      }
      this.ctx.globalAlpha = 1;
      this.ctx.save();
      this.ctx.translate(r.x, r.y);
      this.ctx.rotate(-Math.PI / 4);
      this.ctx.fillText('🚀', 0, 0);
      this.ctx.restore();
    }
    // 先画 🚀 尾焰火花（底层圆点，v22），再画表情脸，最后 🥳 中心闪光
    for (let i: number = 0; i < this.particles.length; i++) {
      const p: FwParticle = this.particles[i];
      if (p.kind !== KIND_FLAME) {
        continue;
      }
      const flameAlpha: number = Math.min(Math.max(p.life / p.maxLife, 0), 1);
      this.ctx.fillStyle = p.color;
      this.ctx.globalAlpha = flameAlpha * 0.22;
      this.ctx.beginPath();
      this.ctx.arc(p.x, p.y, p.size * 2.2, 0, Math.PI * 2);
      this.ctx.fill();
      this.ctx.globalAlpha = flameAlpha;
      this.ctx.beginPath();
      this.ctx.arc(p.x, p.y, p.size * 0.7, 0, Math.PI * 2);
      this.ctx.fill();
    }
    // 表情脸；🥳 中心闪光最后画（保证覆盖在上层）
    this.ctx.textAlign = 'center';
    this.ctx.textBaseline = 'middle';
    for (let i: number = 0; i < this.particles.length; i++) {
      const p: FwParticle = this.particles[i];
      if (p.kind !== KIND_EMOJI) {
        continue;
      }
      if (p.spawnDelay > 0) {
        continue; // 延迟出场期间不绘制
      }
      if (p.x < -EDGE_CULL || p.x > w + EDGE_CULL
        || p.y < -EDGE_CULL || p.y > h + EDGE_CULL) {
        continue;
      }
      const alpha: number = Math.min(Math.max(p.life / p.maxLife, 0), 1);
      const size: number = p.fontSize * (0.9 + alpha * 0.1);
      this.ctx.font = Math.round(size * this.fontScale) + 'px';
      this.ctx.globalAlpha = Math.min(alpha * 1.1, 1);
      if (p.squash > 0.01) {
        // 碰撞挤压：横向压扁、纵向拉伸，随 squash 衰减恢复（v23）
        this.ctx.save();
        this.ctx.translate(p.x, p.y);
        this.ctx.scale(1 - p.squash * 0.18, 1 + p.squash * 0.08);
        this.ctx.fillText(p.emoji, 0, 0);
        this.ctx.restore();
      } else {
        this.ctx.fillText(p.emoji, p.x, p.y);
      }
    }
    for (let i: number = 0; i < this.particles.length; i++) {
      const p: FwParticle = this.particles[i];
      if (p.kind !== KIND_FLASH) {
        continue;
      }
      const prog: number = 1 - Math.max(p.life / p.maxLife, 0);
      const alpha: number = Math.max(p.life / p.maxLife, 0);
      this.ctx.font = Math.round((FLASH_START_PX + prog * FLASH_GROW_PX) * this.fontScale) + 'px';
      this.ctx.globalAlpha = alpha * 0.95;
      this.ctx.fillText(p.emoji, p.x, p.y);
    }
    this.ctx.globalAlpha = 1;
  }

  build() {
    // 高度撑满父 Stack（= 面板内容全高；面板贴底，故画布底部即屏幕底部）
    Canvas(this.ctx)
      .width('100%')
      .height('100%')
      .hitTestBehavior(HitTestMode.None) // 不拦截面板的关闭/下滑/点击
  }
}