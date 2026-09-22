// 一镜到底转场（移植自官方 transitions-collection 的「卡片一镜到底」方案）。
//
// 范式差异（本次全量改造的核心）：
//   旧方案：独立快照覆盖层从卡片位「飞」到详情媒体位，飞完再被真内容顶一下 → 二次对位。
//   新方案：**目的地页自身参与变形**——整页从卡片帧缩放/裁切展开到全屏，
//           卡片截图顶住首帧、真实内容随后淡入。目标就是真页面，不存在二次对位。
//
// 分工（与官方一致）：
//   源页 HomeTab：截图卡片 + 量卡片帧 → 组成 LongTakeParams 随 push 传入。
//   目的地 PostDetailDestination：onReady 拿 navDestinationId 后注册自己的动画；
//           页面根容器绑定 LongTakeAnim 字段（scale/translate/clip/position/radius/opacity）。
//   框架 Index：customNavContentTransition 里按 navDestinationId 查表，把动画交给对应页。
//
// 单位约定（照官方）：getMeasuredSize 返回 px；getPositionToWindowWithTransform 返回 vp；
// 卡片帧在源页以 vp 记录，计算时统一换算。
import { hilog } from '@kit.PerformanceAnalysisKit';
import { image } from '@kit.ImageKit';
import { CardRect } from './navigationTransition';

const TAG: string = 'LongTake';

// 卡片截图的展示窗口：
//   MIN —— 无论真内容多早就绪，截图至少展示这么久（覆盖入场前半段，避免"闪一下就没"）；
//   MAX —— 上限，真内容迟迟不就绪也必须交接，避免截图长期压住媒体位。
const SNAP_MIN_MS: number = 300;
const SNAP_MAX_MS: number = 1500;

// ── 回调注册表：key = navDestinationId（目的地页在 onReady 里注册自己）──
export interface LongTakeCallback {
  timeout?: number;
  animation?: (proxy: NavigationTransitionProxy) => void;
}

const REGISTRY: Map<string, LongTakeCallback> = new Map();

export class LongTakeTransition {
  static delegate: LongTakeTransition = new LongTakeTransition();
  // 框架在 customNavContentTransition 里回填：页面动画据此判断进场/返回
  operation: NavigationOperation = NavigationOperation.PUSH;
  proxy: NavigationTransitionProxy | undefined = undefined;

  static getInstance(): LongTakeTransition {
    return LongTakeTransition.delegate;
  }

  register(name: string, timeout: number, animation: (proxy: NavigationTransitionProxy) => void): void {
    REGISTRY.set(name, { timeout, animation });
    hilog.info(0x0000, TAG, 'transition registered: %{public}s', name);
  }

  unregister(name: string): void {
    REGISTRY.delete(name);
  }

  get(name: string): LongTakeCallback {
    const hit: LongTakeCallback | undefined = REGISTRY.get(name);
    return hit !== undefined ? hit : {};
  }
}

// ── 源页 → 目的地 的转场参数 ──
export class LongTakeParams {
  // 卡片（整卡容器）组件 id：源页据此截图，首帧顶替真内容
  cardId: string = '';
  // 卡片在屏幕上的帧（vp），来自 componentUtils.getRectangleById 实测
  cardRect: CardRect = { left: 0, top: 0, width: 0, height: 0 };
  // 卡片截图（整卡，含图文）；截图失败时为 undefined，退化为纯布局变形
  snapshot: image.PixelMap | undefined = undefined;
}

// ── 可动画属性集合（@Observed：字段变化直接驱动页面重绘）──
// 命名与官方 LongTakeAnimationProperties 对齐，便于对照维护。
@Observed
export class LongTakeAnim {
  // 卡片截图：进场 1→0（真内容接管）；返回 0→1
  snapOpacity: number = 1;
  // 目的地真内容：进场 0→1
  contentOpacity: number = 0;
  scale: number = 1;
  tx: number = 0;
  ty: number = 0;
  clipWidth: Dimension = '100%';
  clipHeight: Dimension = '100%';
  radius: number = 16;
  // 内容层相对视口的偏移：把「对应节点」挪到卡片位置
  posX: number = 0;
  posY: number = 0;
  // 卡片截图在缩放容器内的落点（官方：= 对应节点位置；Y 再减去顶部避让区，
  // 因为目的地开了 expandSafeArea，坐标原点在状态栏下方）
  snapX: number = 0;
  snapY: number = 0;

  private initScale: number = 1;
  private initTx: number = 0;
  private initTy: number = 0;
  private initClipW: Dimension = '100%';
  private initClipH: Dimension = '100%';
  private initPosX: number = 0;
  private initPosY: number = 0;
  private card: CardRect = { left: 0, top: 0, width: 0, height: 0 };
  private animCount: number = 0;
  // 入场开始的时刻（ms）：真内容就绪后据此保证截图的最小展示时长
  private enterStartMs: number = 0;
  // 初值是否量成功：失败时不做动画，直接落终态并立刻放行转场（否则会白等一个动画时长）
  private geometryValid: boolean = false;

  // 源页传卡片帧（vp）：只记录；真正的初值在 initParams 里算（那时目的地已布局）
  init(cardRect: CardRect): void {
    this.card = cardRect;
  }

  // 目的地布局完成后调用：量出「对应节点」（详情 hero）与「页面根」的窗口位置，算出全部初值。
  //
  // 公式与官方一致，只多一个 aX/aY 修正：官方直接用节点的**窗口**坐标做初值，隐含前提是
  // 「页面内容原点 == 窗口原点」。本项目页面是否延伸进状态栏由 expandSafeArea 决定，
  // 写死这个前提一旦不成立就会整体差一个状态栏高度。因此这里额外量出页面根的窗口位置
  // aX/aY（此时 posX/posY 还是 0，所以它就是页面内容原点），所有落点都相对它计算：
  // aX/aY 为 0 时与官方公式完全相同。
  initParams(ui: UIContext, destNodeId: string, rootNodeId: string, windowWidthPx: number): void {
    let nodeWpx: number = 0;
    let nodeXvp: number = 0;
    let nodeYvp: number = 0;
    let rootXvp: number = 0;
    let rootYvp: number = 0;
    try {
      const node: FrameNode | null = ui.getFrameNodeById(destNodeId);
      if (node !== null) {
        nodeXvp = node.getPositionToWindowWithTransform().x;
        nodeYvp = node.getPositionToWindowWithTransform().y;
        nodeWpx = node.getMeasuredSize().width;
      }
      const root: FrameNode | null = ui.getFrameNodeById(rootNodeId);
      if (root !== null) {
        rootXvp = root.getPositionToWindowWithTransform().x;
        rootYvp = root.getPositionToWindowWithTransform().y;
      }
    } catch (err) {
      hilog.error(0x0000, TAG, 'initParams measure failed: %{public}s', JSON.stringify(err));
    }

    const cardWpx: number = ui.vp2px(this.card.width);
    const cardHpx: number = ui.vp2px(this.card.height);
    const cardLpx: number = ui.vp2px(this.card.left);
    const cardTpx: number = ui.vp2px(this.card.top);
    if (nodeWpx <= 0 || cardWpx <= 0 || cardHpx <= 0) {
      hilog.warn(0x0000, TAG, 'initParams: invalid geometry, fall back to final status');
      this.setFinalStatus();
      return;
    }
    this.geometryValid = true;

    // 缩放比：整页缩放到「对应节点宽度 == 卡片宽度」
    this.initScale = cardWpx / nodeWpx;
    this.initClipW = '100%';
    const clipHpx: number = cardHpx / Math.max(this.initScale, 0.0001);
    this.initClipH = ui.px2vp(clipHpx);

    // 位移：让缩放后的可视框（宽 = 窗口宽×s，高 = 卡片高）正好落到卡片帧
    const rootXpx: number = ui.vp2px(rootXvp);
    const rootYpx: number = ui.vp2px(rootYvp);
    this.initTx = ui.px2vp(cardLpx - rootXpx - (windowWidthPx - cardWpx) / 2);
    this.initTy = ui.px2vp(cardTpx - rootYpx - (clipHpx - clipHpx * this.initScale) / 2);

    // 「对应节点」在页面内容坐标系里的位置：内层用它做定位，截图用它做落点
    // （两者必须同源，否则截图与真内容会错位）
    const nodeLocalXvp: number = nodeXvp - rootXvp;
    const nodeLocalYvp: number = nodeYvp - rootYvp;
    this.initPosX = -nodeLocalXvp;
    this.initPosY = -nodeLocalYvp;
    this.snapX = nodeLocalXvp;
    this.snapY = nodeLocalYvp;

    hilog.info(0x0000, TAG,
      'initParams s=%{public}f root=(%{public}f,%{public}f) node=(%{public}f,%{public}f) clipH=%{public}f tx=%{public}f ty=%{public}f',
      this.initScale, rootXvp, rootYvp, nodeXvp, nodeYvp, clipHpx, this.initTx, this.initTy);
  }

  // 进场：从卡片帧展开到全屏；截图 50ms 后淡出，真内容同步淡入
  doEnter(ui: UIContext, proxy: NavigationTransitionProxy): void {
    if (!this.geometryValid) {
      // 量不到几何（极少数：无 hero 节点等）→ 直接落终态并放行，不做无意义的空动画
      this.setFinalStatus();
      proxy.finishTransition();
      return;
    }
    this.scale = this.initScale;
    this.tx = this.initTx;
    this.ty = this.initTy;
    this.clipWidth = this.initClipW;
    this.clipHeight = this.initClipH;
    this.posX = this.initPosX;
    this.posY = this.initPosY;

    const count: number = ++this.animCount;
    ui.animateTo({
      duration: 350,
      curve: Curve.EaseInOut,
      onFinish: () => {
        if (count === this.animCount) {
          this.radius = 0;
        }
        proxy.finishTransition();
      },
    }, () => {
      this.scale = 1;
      this.tx = 0;
      this.ty = 0;
      this.clipWidth = '100%';
      this.clipHeight = '100%';
      this.posX = 0;
      this.posY = 0;
      this.radius = 24;
    });

    ui.animateTo({ delay: 50, duration: 100, curve: Curve.Sharp }, () => {
      this.contentOpacity = 1;
    });
    // 截图不再按固定时间淡出，而是等「真媒体首帧画出来」再交接（onHeroReady）；
    // 这里只挂一个上限兜底，保证任何异常路径下截图都会退场。
    this.enterStartMs = Date.now();
    this.scheduleSnapFade(ui, SNAP_MAX_MS);
  }

  // 真媒体首帧就绪（目的地页收到 PostDetailView 的回调后调用）：
  // 截图淡出 + 真媒体同时淡入，两者锚点同源，所以是"交接"而不是"闪一下"。
  onHeroReady(ui: UIContext): void {
    if (this.enterStartMs <= 0) {
      // 极早（入场还没开始）就绪：等 doEnter 里挂的 MAX 兜底即可，不抢跑
      return;
    }
    const elapsed: number = Date.now() - this.enterStartMs;
    this.scheduleSnapFade(ui, Math.max(0, SNAP_MIN_MS - elapsed));
  }

  // 定时淡出截图：用 animCount 守卫，返回动画（doBack）一旦开始，旧的定时器即作废，
  // 否则 POP 过程中截图会被入场的残留定时器提前抹掉。
  private scheduleSnapFade(ui: UIContext, delayMs: number): void {
    const count: number = this.animCount;
    setTimeout((): void => {
      if (count !== this.animCount || this.snapOpacity === 0) {
        return;
      }
      ui.animateTo({ duration: 180, curve: Curve.Friction }, (): void => {
        this.snapOpacity = 0;
      });
    }, delayMs);
  }

  // 返回：全屏收回卡片帧（与进场对称）
  doBack(ui: UIContext, proxy: NavigationTransitionProxy): void {
    if (!this.geometryValid) {
      proxy.finishTransition();
      return;
    }
    // 入场阶段挂的截图淡出定时器由 animCount 作废（见 scheduleSnapFade）
    this.enterStartMs = 0;
    ++this.animCount;
    ui.animateTo({
      duration: 350,
      curve: Curve.EaseInOut,
      onFinish: () => {
        proxy.finishTransition();
      },
    }, () => {
      this.scale = this.initScale;
      this.tx = this.initTx;
      this.ty = this.initTy;
      this.clipWidth = this.initClipW;
      this.clipHeight = this.initClipH;
      this.posX = this.initPosX;
      this.posY = this.initPosY;
      this.radius = 16;
    });
    ui.animateTo({ duration: 50, delay: 150, curve: Curve.Friction }, () => {
      this.snapOpacity = 1;
    });
    ui.animateTo({ duration: 50, delay: 200, curve: Curve.Friction }, () => {
      this.contentOpacity = 0;
    });
  }

  // 不走自定义转场（异常 / 窗口尺寸变化）时直接落回正常终态
  setFinalStatus(): void {
    this.scale = 1;
    this.tx = 0;
    this.ty = 0;
    this.clipWidth = '100%';
    this.clipHeight = '100%';
    this.posX = 0;
    this.posY = 0;
    this.radius = 0;
    this.snapOpacity = 0;
    this.contentOpacity = 1;
  }
}
