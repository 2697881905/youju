// 一镜到底的可动画属性集合——对齐官方 transitions-collection 的
// utils/customtransition/LongTakeAnimationProperties.ets。
//
// 范式：**目的地页自身参与变形**。整页从卡片帧缩放/裁切展开到全屏
// （scale/translate/clip/position/radius），卡片截图顶住首帧、真内容随后淡入。
// 因为变形目标就是真页面本身，所以不存在「飞完再被真内容顶一下」的二次对位。
//
// 与官方一致：字段名、公式、进出场时序、单位约定
// （getMeasuredSize → px、getPositionToWindowWithTransform → vp）。
// 比官方多的三处，都是本项目「详情数据异步」逼出来的，见各自注释：
//   1) 额外量「页面根」，所有落点相对页面内容原点计算（官方直接用窗口坐标）；
//   2) 真媒体首帧就绪后再与卡片截图交接（onHeroReady，官方按固定时间淡出）；
//   3) geometryValid 快速路径：量不到几何就不做空动画，直接落终态并放行。
import { hilog } from '@kit.PerformanceAnalysisKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { image } from '@kit.ImageKit';
import { CardRect } from '../navigationTransition';
import { CustomTransition } from './customNavigationUtils';

const TAG: string = 'LongTakeAnimation';

// 时序与圆角（官方同值：350ms；起始 16 → 展开 34。本项目卡面圆角为 16 → 24）
const DURATION_MS: number = 350;
const RADIUS_CARD: number = 16;
const RADIUS_EXPANDED: number = 24;
const CONTENT_FADE_DELAY_MS: number = 50;
const CONTENT_FADE_MS: number = 100;
// 卡片截图与真内容的交接窗口：
//   MIN —— 无论真内容多早就绪，截图至少展示这么久（覆盖入场前半段，避免"闪一下就没"）；
//   MAX —— 上限，真内容迟迟不就绪也必须交接，避免截图长期压住媒体位。
const SNAPSHOT_HANDOVER_MIN_MS: number = 300;
const SNAPSHOT_HANDOVER_MAX_MS: number = 1500;
const SNAPSHOT_FADE_MS: number = 180;

// 源页 → 目的地 的转场参数。
// 官方用 SnapShotImage 这个静态类持有 PixelMap 跨页传递；本项目改为随 push 参数传递，
// 类型明确、不留全局态（截图失败时 snapshot 为 undefined，退化为纯布局变形）。
export class LongTakeParams {
  // 卡片（信息流为整卡 feedCard-{id}，每日一帖卡堆为 deckCardMedia-{id}）组件 id
  cardId: string = '';
  // 卡片在屏幕上的帧（vp），由源页实测
  cardRect: CardRect = { left: 0, top: 0, width: 0, height: 0 };
  snapshot: image.PixelMap | undefined = undefined;
}

@Observed
export class LongTakeAnimationProperties {
  // ——— 绑定到目的地页面根容器的可动画属性（官方同名）———
  // 字段**初值取「安全终态」**（内容可见、截图不显示），真正的转场起始态由
  // doEnterAnimation 显式赋值。这样万一自定义转场没跑（未注册 / 委托被跳过 / 异常），
  // 页面只是少一段动画，而不会停在「内容 0 透明度 + 截图铺满屏」的坏状态（踩过）。
  snapShotOpacity: number = 0; // 卡片截图：进场 1→0（真内容接管）；返回 0→1
  postPageOpacity: number = 1; // 目的地真内容：进场 0→1
  scaleValue: number = 1;
  translateX: number = 0;
  translateY: number = 0;
  clipWidth: Dimension = '100%';
  clipHeight: Dimension = '100%';
  radius: number = RADIUS_CARD;
  positionXValue: number = 0;
  positionYValue: number = 0;
  snapShotPositionX: number = 0;
  snapShotPositionY: number = 0;

  // ——— 初值：initParams 量出后固定，进场/返回复用 ———
  private initScale: number = 1;
  private initTranslateX: number = 0;
  private initTranslateY: number = 0;
  private initClipWidth: Dimension = '100%';
  private initClipHeight: Dimension = '100%';
  private initPositionValueX: number = 0;
  private initPositionValueY: number = 0;

  // 源页/目的地约定的组件 id 与卡片帧，init 时一次性记录
  private clickedCardId: string = '';
  private destNodeId: string = '';
  // 对应节点的**回退 id**（加载壳里的占位）：详情数据异步，转场开始那一刻
  // 页面上往往只有壳，量不到真实 hero 时就量壳占位（几何与真实 hero 一致）。
  private destNodeFallbackId: string = '';
  private rootNodeId: string = '';
  private cardItemInfo_vp: CardRect = { left: 0, top: 0, width: 0, height: 0 };

  private animationCount: number = 0;
  // 入场开始时刻（ms）：真内容就绪后据此保证截图的最小展示时长
  private enterStartMs: number = 0;
  // 初值是否量成功：失败时不做动画，直接落终态并立刻放行（否则会白等一个动画时长）
  private geometryValid: boolean = false;

  /* 目的地页注册转场前调用
   * cardItemInfo_vp：源页实测的卡片屏幕帧（vp）
   * destNodeId：详情页里充当「卡片对应节点」的组件 id（整页缩放到「该节点宽 == 卡片宽」）
   * destNodeFallbackId：对应节点的回退 id（加载壳占位，几何与真实 hero 一致）
   * rootNodeId：页面根组件 id（用来量出页面内容原点，见 initParams 注释）
   */
  init(cardItemInfo_vp: CardRect, destNodeId: string,
    destNodeFallbackId: string, rootNodeId: string, clickedCardId: string): void {
    this.cardItemInfo_vp = cardItemInfo_vp;
    this.destNodeId = destNodeId;
    this.destNodeFallbackId = destNodeFallbackId;
    this.rootNodeId = rootNodeId;
    this.clickedCardId = clickedCardId;
  }

  // 框架在转场开始时调用（官方同名的单一入口）：PUSH 走进场、POP 走返回
  doAnimation(ui: UIContext, transitionProxy: NavigationTransitionProxy): void {
    const operation: NavigationOperation = CustomTransition.getInstance().operation;
    if (operation === NavigationOperation.PUSH) {
      this.initParams(ui);
      this.doEnterAnimation(ui, transitionProxy);
    } else if (operation === NavigationOperation.POP) {
      this.doBackAnimation(ui, transitionProxy);
    } else {
      // 其它 operation（未来新增取值等）：不做动画，落终态并立刻放行 ——
      // 不能落到 else 就当 POP 处理，否则会走语义相反的反向动画。
      this.setFinalStatus();
      transitionProxy.finishTransition();
    }
  }

  /* 量出「对应节点」（详情 hero）与「页面根」的窗口位置/尺寸，算出全部初值。
   *
   * 官方公式：整页缩放到「节点宽 == 卡片宽」（initScale），再把该节点挪到卡片位置，
   * 裁切高度按缩放比换算回未缩放坐标系，作为展开动画的起始可视高。
   *
   * 本项目额外量「页面根」：官方直接用节点的**窗口**坐标做初值，隐含前提是
   * 「页面内容原点 == 窗口原点」；而本项目页面是否延伸进状态栏由 expandSafeArea 决定，
   * 写死这个前提一旦不成立就会整体差一个状态栏高度。这里量出页面根的窗口位置
   * （此时 positionXValue/positionYValue 还是 0，所以它就是页面内容原点），
   * 所有落点都相对它计算；页面原点为 0 时与官方公式完全相同。
   * 窗口宽也取自页面根，不再依赖 display，旋转后依然正确。
   */
  private initParams(ui: UIContext): void {
    let nodeWidth_px: number = 0;
    let nodePositionX_vp: number = 0;
    let nodePositionY_vp: number = 0;
    let rootPositionX_vp: number = 0;
    let rootPositionY_vp: number = 0;
    let rootWidth_px: number = 0;
    try {
      let heroNode: FrameNode | null = ui.getFrameNodeById(this.destNodeId);
      if ((heroNode === null || heroNode.getMeasuredSize().width <= 0) && this.destNodeFallbackId.length > 0) {
        // 详情数据异步：转场开始那一刻页面上往往只有加载壳（真实 hero 还不存在），
        // 回退量壳里的占位——它的宽高由 intent.aspect 决定，与真实 hero 一致。
        heroNode = ui.getFrameNodeById(this.destNodeFallbackId);
      }
      if (heroNode !== null) {
        nodePositionX_vp = heroNode.getPositionToWindowWithTransform().x;
        nodePositionY_vp = heroNode.getPositionToWindowWithTransform().y;
        nodeWidth_px = heroNode.getMeasuredSize().width;
      }
      const rootNode: FrameNode | null = ui.getFrameNodeById(this.rootNodeId);
      if (rootNode !== null) {
        rootPositionX_vp = rootNode.getPositionToWindowWithTransform().x;
        rootPositionY_vp = rootNode.getPositionToWindowWithTransform().y;
        rootWidth_px = rootNode.getMeasuredSize().width;
      }
    } catch (error) {
      const err = error as BusinessError;
      hilog.error(0x0000, TAG, `initParams measure failed. code=${err.code}, message=${err.message}`);
    }

    const cardWidth_px: number = ui.vp2px(this.cardItemInfo_vp.width);
    const cardHeight_px: number = ui.vp2px(this.cardItemInfo_vp.height);
    const cardLeft_px: number = ui.vp2px(this.cardItemInfo_vp.left);
    const cardTop_px: number = ui.vp2px(this.cardItemInfo_vp.top);
    if (nodeWidth_px <= 0 || rootWidth_px <= 0 || cardWidth_px <= 0 || cardHeight_px <= 0) {
      hilog.warn(0x0000, TAG, `initParams: invalid geometry(cardId=${this.clickedCardId}), fall back to final status`);
      this.setFinalStatus();
      return;
    }
    this.geometryValid = true;

    this.initScale = cardWidth_px / nodeWidth_px;
    this.initClipWidth = '100%';
    const clipHeight_px: number = cardHeight_px / Math.max(this.initScale, 0.0001);
    this.initClipHeight = ui.px2vp(clipHeight_px);

    const rootPositionX_px: number = ui.vp2px(rootPositionX_vp);
    const rootPositionY_px: number = ui.vp2px(rootPositionY_vp);
    this.initTranslateX = ui.px2vp(cardLeft_px - rootPositionX_px - (rootWidth_px - cardWidth_px) / 2);
    this.initTranslateY =
      ui.px2vp(cardTop_px - rootPositionY_px - (clipHeight_px - clipHeight_px * this.initScale) / 2);

    // 「对应节点」在页面内容坐标系里的位置：内层用它做定位，截图用它做落点。
    // 两者必须同源（都减去页面原点），否则截图与真内容会错位。
    const nodeLocalX_vp: number = nodePositionX_vp - rootPositionX_vp;
    const nodeLocalY_vp: number = nodePositionY_vp - rootPositionY_vp;
    this.initPositionValueX = -nodeLocalX_vp;
    this.initPositionValueY = -nodeLocalY_vp;
    this.snapShotPositionX = nodeLocalX_vp;
    this.snapShotPositionY = nodeLocalY_vp;

    hilog.info(0x0000, TAG, `initParams scale=${this.initScale} root=(${rootPositionX_vp},${rootPositionY_vp}) `
      + `node=(${nodePositionX_vp},${nodePositionY_vp}) cardId=${this.clickedCardId}`);
  }

  // 进场：从卡片帧展开到全屏；截图与真内容错峰交接
  doEnterAnimation(ui: UIContext, transitionProxy: NavigationTransitionProxy): void {
    if (!this.geometryValid) {
      // 量不到几何（无 hero 节点 / 尺寸为 0）→ 不做无意义的空动画，落终态并立刻放行
      this.setFinalStatus();
      transitionProxy.finishTransition();
      return;
    }
    this.scaleValue = this.initScale;
    this.translateX = this.initTranslateX;
    this.translateY = this.initTranslateY;
    this.clipWidth = this.initClipWidth;
    this.clipHeight = this.initClipHeight;
    this.positionXValue = this.initPositionValueX;
    this.positionYValue = this.initPositionValueY;
    // 起始不透明度**显式赋值**（不依赖字段初值，见字段处注释）：
    // 截图先顶住首帧，真内容从 0 淡入
    this.postPageOpacity = 0;
    this.snapShotOpacity = 1;

    const animationCount: number = ++this.animationCount;
    ui.animateTo({
      duration: DURATION_MS,
      curve: Curve.EaseInOut,
      onFinish: () => {
        if (animationCount === this.animationCount) {
          this.radius = 0;
        }
        transitionProxy.finishTransition();
      }
    }, () => {
      this.scaleValue = 1;
      this.translateX = 0;
      this.translateY = 0;
      this.clipWidth = '100%';
      this.clipHeight = '100%';
      this.positionXValue = 0;
      this.positionYValue = 0;
      this.radius = RADIUS_EXPANDED;
    });

    ui.animateTo({ delay: CONTENT_FADE_DELAY_MS, duration: CONTENT_FADE_MS, curve: Curve.Sharp }, () => {
      this.postPageOpacity = 1;
    });

    // 官方在这里固定 50ms 后淡出截图；本项目详情数据是异步的，改为等真媒体首帧
    // 画出来再交接（onHeroReady），此处只挂上限兜底，保证任何异常路径下截图都会退场。
    this.enterStartMs = Date.now();
    this.scheduleSnapshotFade(ui, SNAPSHOT_HANDOVER_MAX_MS);
  }

  /* 真媒体首帧就绪（目的地页收到 PostDetailView 的 onHeroReady 回调后调用）
   * 截图淡出与真媒体淡入同刻发生、锚点同源，所以是"交接"而不是"闪一下"。
   */
  onHeroReady(ui: UIContext): void {
    if (this.enterStartMs <= 0) {
      // 极早（入场还没开始）就绪：交给 doEnterAnimation 里挂的上限兜底，不抢跑
      return;
    }
    const elapsed_ms: number = Date.now() - this.enterStartMs;
    this.scheduleSnapshotFade(ui, Math.max(0, SNAPSHOT_HANDOVER_MIN_MS - elapsed_ms));
  }

  // 定时淡出截图：用 animationCount 守卫，返回动画（doBackAnimation）一旦开始，
  // 入场阶段挂的定时器即作废，否则 POP 过程中截图会被提前抹掉。
  private scheduleSnapshotFade(ui: UIContext, delay_ms: number): void {
    const animationCount: number = this.animationCount;
    setTimeout((): void => {
      if (animationCount !== this.animationCount || this.snapShotOpacity === 0) {
        return;
      }
      ui.animateTo({ duration: SNAPSHOT_FADE_MS, curve: Curve.Friction }, (): void => {
        this.snapShotOpacity = 0;
      });
    }, delay_ms);
  }

  // 返回：全屏收回卡片帧（与进场对称）
  doBackAnimation(ui: UIContext, transitionProxy: NavigationTransitionProxy): void {
    if (!this.geometryValid) {
      transitionProxy.finishTransition();
      return;
    }
    this.enterStartMs = 0;
    ++this.animationCount;

    ui.animateTo({
      duration: DURATION_MS,
      curve: Curve.EaseInOut,
      onFinish: () => {
        transitionProxy.finishTransition();
      }
    }, () => {
      this.scaleValue = this.initScale;
      this.translateX = this.initTranslateX;
      this.translateY = this.initTranslateY;
      this.clipWidth = this.initClipWidth;
      this.clipHeight = this.initClipHeight;
      this.positionXValue = this.initPositionValueX;
      this.positionYValue = this.initPositionValueY;
      this.radius = RADIUS_CARD;
    });

    ui.animateTo({ duration: 50, delay: 150, curve: Curve.Friction }, () => {
      this.snapShotOpacity = 1;
    });
    ui.animateTo({ duration: 50, delay: 200, curve: Curve.Friction }, () => {
      this.postPageOpacity = 0;
    });
  }

  // 不走自定义转场（几何量不到 / 窗口尺寸变化）时直接落回正常终态
  setFinalStatus(): void {
    this.scaleValue = 1;
    this.translateX = 0;
    this.translateY = 0;
    this.clipWidth = '100%';
    this.clipHeight = '100%';
    this.positionXValue = 0;
    this.positionYValue = 0;
    this.radius = 0;
    this.snapShotOpacity = 0;
    this.postPageOpacity = 1;
  }

  // 几何是否可用：目的地页在窗口尺寸变化时据此决定是否退系统默认转场
  isGeometryValid(): boolean {
    return this.geometryValid;
  }
}
