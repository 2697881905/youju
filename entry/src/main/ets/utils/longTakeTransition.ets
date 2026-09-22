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

  private initScale: number = 1;
  private initTx: number = 0;
  private initTy: number = 0;
  private initClipW: Dimension = '100%';
  private initClipH: Dimension = '100%';
  private initPosX: number = 0;
  private initPosY: number = 0;
  private card: CardRect = { left: 0, top: 0, width: 0, height: 0 };
  private animCount: number = 0;

  // 源页传卡片帧（vp）：只记录；真正的初值在 initParams 里算（那时目的地已布局）
  init(cardRect: CardRect): void {
    this.card = cardRect;
  }

  // 目的地布局完成后调用：量出「对应节点」（详情 hero）位置与尺寸，算出全部初值。
  // 官方公式：整页缩放到「对应节点宽度 == 卡片宽度」，再把该节点挪到卡片位置，
  // 裁切高度按缩放比换算回未缩放坐标系，作为展开动画的起始可视高。
  initParams(ui: UIContext, destNodeId: string, windowWidthPx: number): void {
    let nodeWpx: number = 0;
    let nodeXvp: number = 0;
    let nodeYvp: number = 0;
    try {
      const node: FrameNode | null = ui.getFrameNodeById(destNodeId);
      if (node !== null) {
        nodeXvp = node.getPositionToWindowWithTransform().x;
        nodeYvp = node.getPositionToWindowWithTransform().y;
        nodeWpx = node.getMeasuredSize().width;
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

    this.initScale = cardWpx / nodeWpx;
    this.initClipW = '100%';
    this.initClipH = ui.px2vp(cardHpx / Math.max(this.initScale, 0.0001));
    const clipHpx: number = ui.vp2px(this.initClipH);
    this.initTx = ui.px2vp(cardLpx - (windowWidthPx - cardWpx) / 2);
    this.initTy = ui.px2vp(cardTpx - ((clipHpx - clipHpx * this.initScale) / 2));
    this.initPosX = -nodeXvp;
    this.initPosY = -nodeYvp;
    hilog.info(0x0000, TAG,
      'initParams scale=%{public}f pos=(%{public}f,%{public}f) clipH=%{public}f tx=%{public}f ty=%{public}f',
      this.initScale, this.initPosX, this.initPosY, clipHpx, this.initTx, this.initTy);
  }

  // 进场：从卡片帧展开到全屏；截图 50ms 后淡出，真内容同步淡入
  doEnter(ui: UIContext, proxy: NavigationTransitionProxy): void {
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
      this.snapOpacity = 0;
    });
    ui.animateTo({ duration: 100, curve: Curve.Sharp }, () => {
      this.contentOpacity = 1;
    });
  }

  // 返回：全屏收回卡片帧（与进场对称）
  doBack(ui: UIContext, proxy: NavigationTransitionProxy): void {
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
