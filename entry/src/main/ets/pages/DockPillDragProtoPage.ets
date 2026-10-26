// Dock 胶囊拖拽原型页 —— 沉浸光感 tabbar 优化方案（华为开发者文章 03212848303315412，
// 本仓 docs/对沉浸光感tabbar的优化改造）的完整交互参考实现。
// 主框架 Index 的 Dock 指示器（基准 §7.6.32）已落地 tap 分支并刻意不接拖拽（整页左右滑
// 已开放 §7.6.33 + HdsTabs 收掉了逐帧回调）；本页独立验证原文的
// 「拖拽跟手 + 速度液态形变 + 近锚显影 + 半格吸附 + 边缘阻尼」手感与参数，
// 真机（Pocket 2，API 26）调参满意后再决定是否合入主框架。入口：设置页临时项。
//
// 与原文实现的差异（全部有意为之，对应文档评审结论）：
// ① 零新增依赖：原文 HdsMiniBarButton（hds_button HAR）不可得，且其价值已被真机实验
//    证伪——覆盖层挂不上 systemMaterial（§7.6.26）、hdsEffect 点光源三档无效（Index 常量
//    注释），胶囊沿用主框架自绘玻璃配方（backdropBlur + 中性半透 + 亮 rim + 落影）。
// ② 锚点全部实测：原文 BASE_POSITIONS=[8.5,85,162.5,241] 是手调魔法数字（间距 76.5/77.5/
//    78.5 互不相等），换设备/HDS 版本即错位；本页每颗页签 onAreaChange 回抛窗口矩形，
//    锚点=各槽自身中心、槽距由两端中心反算（同主框架配方，含 barBottomMargin 的 y 偏差修正）。
// ③ 无 isProgrammaticChange 门禁、无 310ms 死等：原文两处 P0（拖拽结束 310ms 窗口内点按
//    导致指示器与内容页永久失同步；setTimeout 不可取消导致中途复位错乱）在本页不存在——
//    切页统一走 pillTravelTo 单一入口（目标重定向，最新目标胜出），settle timer 先清后设，
//    changeIndex 放在 settle 到点时执行且只执行最终目标（中途被新交互打断的目标不再切页，
//    页面与胶囊必然同终态）。
// ④ 速度按 vp/s 归一：原文「vp/帧」依赖手势回调帧率，120Hz 设备形变约为 60Hz 的一半。
// ⑤ animateTo 一律走 this.getUIContext()（全局 animateTo 已废弃，工程规范）。
// ⑥ blur 改连续函数：原文 blur 0/40 二值跳变且 40 在 9fp 文本上完全不可读；本页按
//    「距最近锚点的距离」线性起雾，峰值 18，保留液感又不至于内容消失。

import { HdsTabs, HdsTabsController } from '@kit.UIDesignKit';
import { isImmersiveLightSenseSupported } from '../utils/immersiveMaterial';
import { bottomNavInset, DOCK_WIDTH_SMALL, DOCK_BOTTOM_MARGIN_BASE, DOCK_SIDE_MARGIN_MIN,
  DOCK_GRADIENT_MASK_HEIGHT, DOCK_MATERIAL_TYPE, DOCK_MATERIAL_LEVEL } from '../utils/cardTokens';
import { MotionCurves, MotionTokens } from '../design/tokens/motion';
import { GlassTokens } from '../design/tokens/GlassTokens';
import { ShadowTokens } from '../design/tokens/shadow';

// —— 参数定档（真机调参入口，全部集中于此；对照原文的推导写在每行注释里）——

// 尺寸沿用主框架实测比例：胶囊宽 ≈ 1.22 倍槽距、高 ≈ 0.96 倍槽高
// （盖过槽位、行进中溢出 Dock 圆端；原文静止 92×54 是它自己 330 宽 4 槽的槽距 90 的 1.02 倍）。
const PILL_W_RATIO: number = 1.22;
const PILL_H_RATIO: number = 0.96;
// 亮 rim 描边宽度：玻璃"读得出来"的第一来源（主框架同款）。
const PILL_RIM_VP: number = 1.5;
// 拖拽起手/行进的鼓包：原文 92×54 → 110×74.5（约 +20）；本胶囊约 67×52，等比收到 +6。
const PILL_BULGE: number = 6;
// 速度形变上限：原文 45vp 对 92×54 的胶囊；本胶囊小一档（面积约 0.55 倍），等比 + 视觉
// 收敛取 14vp——再大会把胶囊拉出 Dock 圆端过多，玻璃的"贴"感丢失。
const SPEED_MAX_DEFORM: number = 14;
// 反方向（回拉）时宽/高的交叉形变系数：原文 0.5，保留。
const DEFORM_CROSS: number = 0.45;
// 速度归一基准（vp/s）：真机轻甩约 400-600、快甩约 1200-1800；1200 起满形变，
// 配合 sqrt 缓出让轻甩也有可感知的拉伸。
const SPEED_NORMALIZE_VP: number = 1200;
// 速度低于此值不形变（滤手抖噪声）。
const SPEED_MIN_VP: number = 120;
// 速度指数平滑因子（原文同款 0.3）。
const SPEED_SMOOTH: number = 0.3;
// 停顿判定：超过 90ms 无 200vp/s 以上的速度视为停顿，重置形变方向（原文 80ms 同量级）。
const PAUSE_MS: number = 90;
const PAUSE_SPEED_VP: number = 200;
// 近锚显影：距最近锚点超过 45% 槽距开始起雾，2 倍该距离雾到峰值
// （原文固定 28vp 阈值；改比例值适配任意槽距）。
const NEAR_RATIO: number = 0.45;
// 显雾峰值：原文 40 完全糊掉内容；18 保留"液感"且图标轮廓仍可辨。
const BLUR_MAX: number = 18;
// 边缘阻尼：首/尾槽往界外拖的跟手衰减（原文同款 0.3）。
const EDGE_DAMPING: number = 0.3;
// 行进/落定动画时长与曲线（主框架 dockPillTravel 同款，真机已验证的手感）。
const TRAVEL_MS: number = 300;
const SETTLE_MS: number = 240;
// 槽位测量重试次数（覆盖层与 TabBar 首帧先后不确定，主框架同款）。
const MEASURE_RETRIES: number = 6;

// 胶囊的一帧几何：锚点中心 + 尺寸（vp，覆盖层坐标系）。
interface PillFrame {
  cx: number;
  cy: number;
  w: number;
  h: number;
}

// 窗口坐标下的矩形（vp）。只用来算差值不参与渲染，存普通成员。
interface AreaRect {
  x: number;
  y: number;
  w: number;
  h: number;
}

// 演示页签。
interface ProtoTab {
  title: string;
  icon: Resource;
}

@Entry
@Component
struct DockPillDragProtoPage {
  // 演示页签（图标复用主框架 Dock 同款资源，观感与真机一致）。
  private protoTabs: ProtoTab[] = [
    { title: '首页', icon: $r('app.media.nav_home') },
    { title: '圈子', icon: $r('app.media.nav_circle') },
    { title: '消息', icon: $r('app.media.nav_message') },
    { title: '我的', icon: $r('app.media.nav_profile') },
  ];

  // —— 实测几何（recomputeGeometry 产出，拖拽/动画全程只读它们）——
  private anchors: number[] = [];
  private anchorCy: number = 0;
  private slotH: number = 0;
  private pitch: number = 0;

  // —— 胶囊渲染态 ——
  @State private pillReady: boolean = false;
  // 被胶囊盖住（官方份隐掉、由胶囊带清晰副本）的页签下标；-1 = 未落位。
  @State private coveredIndex: number = -1;
  @State private pillX: number = 0;
  @State private pillY: number = 0;
  @State private pillW: number = 0;
  @State private pillH: number = 0;
  // 拖拽实时偏移（translate）：拖拽中逐帧直写跟手，travel 里随 animateTo 归零插值。
  @State private dragOffsetX: number = 0;
  // 胶囊内副本显示的页签（拖拽中跟随最近锚点，雾中预切换）。
  @State private displayIndex: number = 0;
  // 副本内容雾值（vp），拖拽中按距锚距离连续计算，静止恒 0。
  @State private contentBlur: number = 0;
  // 页面当前所在页（onChange 同步），驱动自定义页签的选中染色。
  @State private currentIndex: number = 0;
  // 调参读数（速度/形变/拖距），拖拽中每帧刷新。
  @State private debugText: string = '就绪 · 按住胶囊拖动';

  // —— 非渲染态 ——
  // 胶囊当前吸附的槽下标（渲染由 pillX/W 等承载，这里只参与逻辑判断）。
  private pillIndex: number = 0;
  private hdsController: HdsTabsController = new HdsTabsController();
  private layerArea: AreaRect | null = null;
  private slotAreas: AreaRect[] = [];
  private settleTimer: number = -1;
  private measurePending: boolean = false;
  private measureRetries: number = 0;
  // 拖拽过程量（非渲染态）：上一采样点/平滑速度/初始方向/停顿检测。
  private lastGestureX: number = 0;
  private lastGestureTs: number = 0;
  private smoothedVp: number = 0;
  private initialDirection: number = 0;
  private lastActiveTs: number = 0;
  private pauseDetected: boolean = false;

  aboutToDisappear(): void {
    if (this.settleTimer >= 0) {
      clearTimeout(this.settleTimer);
      this.settleTimer = -1;
    }
  }

  // —— 几何实测（同主框架 Index 的 dockPillFrameOf 配方）——

  private recordSlotArea(index: number, area: Area): void {
    this.slotAreas[index] = {
      x: Number(area.globalPosition.x),
      y: Number(area.globalPosition.y),
      w: Number(area.width),
      h: Number(area.height),
    };
    this.scheduleRemeasure();
  }

  // 由实测矩形重算锚点组/槽高/槽距。任一环缺数据返回 false（宁可不动，不画错位胶囊）。
  private recomputeGeometry(): boolean {
    const count: number = this.protoTabs.length;
    const layer: AreaRect | null = this.layerArea;
    const first: AreaRect | undefined = this.slotAreas[0];
    const last: AreaRect | undefined = this.slotAreas[count - 1];
    if (layer === null || layer.w <= 0 || first === undefined || last === undefined
      || first.w <= 0) {
      return false;
    }
    // ⚠️ 系统把悬浮条整体上提了 barBottomMargin，而 TabBar 子树里的矩形按上提前算：
    // 槽位 globalPosition.y 多算一档 margin（真机实测差值恰等于 DOCK_BOTTOM_MARGIN_BASE
    // + bottomNavInset()，主框架同款修正）。
    const yFix: number = DOCK_BOTTOM_MARGIN_BASE + bottomNavInset();
    this.anchorCy = first.y - layer.y - yFix + first.h / 2;
    this.slotH = first.h;
    const firstCx: number = first.x - layer.x + first.w / 2;
    const lastCx: number = last.x - layer.x + last.w / 2;
    this.pitch = count > 1 ? (lastCx - firstCx) / (count - 1) : first.w;
    this.anchors = [];
    for (let i = 0; i < count; i++) {
      const slot: AreaRect | undefined = this.slotAreas[i];
      // 有实测用自身中心（槽距不均匀也准）；缺的按等距推算兜底。
      this.anchors.push(slot !== undefined && slot.w > 0
        ? slot.x - layer.x + slot.w / 2
        : firstCx + this.pitch * i);
    }
    return true;
  }

  private restFrameOf(index: number): PillFrame | null {
    if (!this.pillReady || index < 0 || index >= this.anchors.length) {
      return null;
    }
    return {
      cx: this.anchors[index],
      cy: this.anchorCy,
      w: this.pitch * PILL_W_RATIO,
      h: this.slotH * PILL_H_RATIO,
    };
  }

  // 把胶囊即时贴到 index 号槽位（无动画）。
  private pillSnap(index: number): boolean {
    const frame: PillFrame | null = this.restFrameOf(index);
    if (frame === null) {
      return false;
    }
    this.pillX = frame.cx;
    this.pillY = frame.cy;
    this.pillW = frame.w;
    this.pillH = frame.h;
    this.pillIndex = index;
    this.coveredIndex = index;
    this.displayIndex = index;
    this.pillReady = true;
    return true;
  }

  // 覆盖层/槽位几何一变就重贴（转屏、折叠、系统导航区回写）。延一帧再量：
  // onAreaChange 在布局阶段回调，此刻读到的还是旧几何。限次重试，量不到就一直不画。
  private scheduleRemeasure(): void {
    if (this.measurePending) {
      return;
    }
    this.measurePending = true;
    setTimeout((): void => {
      this.measurePending = false;
      if (this.recomputeGeometry()) {
        this.pillSnap(this.pillIndex);
        this.measureRetries = 0;
        return;
      }
      if (this.measureRetries < MEASURE_RETRIES) {
        this.measureRetries += 1;
        this.scheduleRemeasure();
      }
    }, 32);
  }

  // —— 切页单一入口（点按直达与拖拽松手都走这里，最新目标胜出）——
  //
  // 时序：行进（鼓包 + 位移 + 拖偏归零，TRAVEL_MS springSoft）→ settle 到点
  // （收回静止尺寸，SETTLE_MS springInteract）→ 同一批里 changeIndex 切页。
  // 中途被新目标打断时旧 timer 被清、旧目标不再 changeIndex——页面与胶囊必然同终态，
  // 这正是原文 isProgrammaticChange 门禁 + 不可取消 setTimeout 想解决而没解决的问题。
  private pillTravelTo(index: number): void {
    const frame: PillFrame | null = this.restFrameOf(index);
    if (frame === null) {
      return;
    }
    // 已吸附在目标槽且无拖拽残留：不再发动画（否则胶囊会在终点上重新鼓包一次）。
    if (this.pillIndex === index && Math.abs(this.dragOffsetX) < 0.5
      && Math.abs(this.pillX - frame.cx) < 0.5) {
      return;
    }
    if (!this.pillReady) {
      this.pillSnap(index);
      return;
    }
    if (this.settleTimer >= 0) {
      clearTimeout(this.settleTimer);
      this.settleTimer = -1;
    }
    this.pillIndex = index;
    // 行进一开始就把目标槽官方份隐掉：胶囊带着清晰副本飞过去，读作「图标被玻璃托走」；
    // 来源槽那份同时恢复，不会出现两份并存的重影（主框架同款语义）。
    this.coveredIndex = index;
    this.displayIndex = index;
    const restW: number = frame.w;
    const restH: number = frame.h;
    this.getUIContext().animateTo({
      duration: TRAVEL_MS,
      curve: MotionCurves.springSoft,
    }, () => {
      this.pillX = frame.cx;
      this.pillY = frame.cy;
      this.pillW = restW + PILL_BULGE;
      this.pillH = restH + PILL_BULGE;
      this.dragOffsetX = 0;
      this.contentBlur = 0;
    });
    this.settleTimer = setTimeout((): void => {
      this.settleTimer = -1;
      this.getUIContext().animateTo({
        duration: SETTLE_MS,
        curve: MotionCurves.springInteract,
      }, () => {
        this.pillW = restW;
        this.pillH = restH;
      });
      // 胶囊落位再切页（原文是 310ms 死等后切，这里由 timer 统一承载，先清后设无竞态）。
      if (index !== this.currentIndex) {
        this.currentIndex = index;
        this.hdsController.changeIndex(index);
      }
    }, TRAVEL_MS);
  }

  // —— 拖拽手势（原文核心交互：跟手 + 速度液态形变 + 近锚显影）——

  private handleDragStart(): void {
    // 打断在途的 settle/changeIndex：手指接管的瞬间，一切以手势为准。
    if (this.settleTimer >= 0) {
      clearTimeout(this.settleTimer);
      this.settleTimer = -1;
    }
    this.lastGestureX = 0;
    this.lastGestureTs = 0;
    this.smoothedVp = 0;
    this.initialDirection = 0;
    this.lastActiveTs = 0;
    this.pauseDetected = false;
    this.displayIndex = this.pillIndex;
    // 起手轻鼓包：从静止尺寸进入"被拿起"的状态（animateTo 短补间，不跟手指抢帧）。
    this.getUIContext().animateTo({
      duration: MotionTokens.fast,
      curve: MotionCurves.springInteract,
    }, () => {
      this.pillW = this.pitch * PILL_W_RATIO + PILL_BULGE;
      this.pillH = this.slotH * PILL_H_RATIO + PILL_BULGE;
    });
  }

  private handleDragUpdate(event: GestureEvent): void {
    if (!this.pillReady || this.anchors.length < this.protoTabs.length) {
      return;
    }
    const x: number = event.offsetX;
    const now: number = Date.now();
    // 速度按 vp/s 归一（原文按帧间位移，120Hz 上形变减半），指数平滑滤抖。
    if (this.lastGestureTs > 0) {
      const dt: number = Math.max(now - this.lastGestureTs, 1);
      const instVp: number = (x - this.lastGestureX) / dt * 1000;
      this.smoothedVp = this.smoothedVp * (1 - SPEED_SMOOTH) + instVp * SPEED_SMOOTH;
    }
    this.lastGestureX = x;
    this.lastGestureTs = now;

    // 停顿检测：短促停顿后视为新一轮甩动，重置形变方向（原文同款逻辑）。
    if (Math.abs(this.smoothedVp) >= PAUSE_SPEED_VP) {
      this.lastActiveTs = now;
    }
    if (this.lastActiveTs > 0 && Math.abs(this.smoothedVp) < PAUSE_SPEED_VP
      && now - this.lastActiveTs >= PAUSE_MS) {
      this.pauseDetected = true;
      this.initialDirection = 0;
      this.lastActiveTs = 0;
    }

    // 速度 → 形变：sqrt 缓动让轻甩也有可感知拉伸，同向拉宽缩高、反向收宽涨高。
    const absV: number = Math.abs(this.smoothedVp);
    let deformW: number = 0;
    let deformH: number = 0;
    if (absV >= SPEED_MIN_VP) {
      if (this.initialDirection === 0 || this.pauseDetected) {
        this.initialDirection = this.smoothedVp > 0 ? 1 : -1;
        this.pauseDetected = false;
      }
      const eased: number = Math.sqrt(Math.min(absV / SPEED_NORMALIZE_VP, 1));
      const deform: number = eased * SPEED_MAX_DEFORM;
      const sameDir: boolean = (this.smoothedVp > 0 ? 1 : -1) === this.initialDirection;
      if (sameDir) {
        deformW = deform;
        deformH = -deform * DEFORM_CROSS;
      } else {
        deformW = -deform * DEFORM_CROSS;
        deformH = deform;
      }
    }
    this.pillW = this.pitch * PILL_W_RATIO + PILL_BULGE + deformW;
    this.pillH = this.slotH * PILL_H_RATIO + PILL_BULGE + deformH;

    // 边缘阻尼：首槽往左/尾槽往右拖时跟手衰减（原文同款 0.3，rubber-band 手感）。
    const lastIndex: number = this.protoTabs.length - 1;
    if ((this.pillIndex === 0 && x < 0) || (this.pillIndex === lastIndex && x > 0)) {
      this.dragOffsetX = x * EDGE_DAMPING;
    } else {
      this.dragOffsetX = x;
    }

    // 近锚显影：找最近锚点，雾值随距离线性上升；副本内容在雾中预切换。
    const currentX: number = this.anchors[this.pillIndex] + this.dragOffsetX;
    let nearestIndex: number = this.pillIndex;
    let nearestDist: number = Number.MAX_VALUE;
    for (let i = 0; i < this.anchors.length; i++) {
      const dist: number = Math.abs(currentX - this.anchors[i]);
      if (dist < nearestDist) {
        nearestDist = dist;
        nearestIndex = i;
      }
    }
    this.displayIndex = nearestIndex;
    this.coveredIndex = nearestIndex;
    const nearRange: number = Math.max(this.pitch * NEAR_RATIO, 1);
    this.contentBlur = Math.min(Math.max((nearestDist - nearRange) / nearRange, 0), 1) * BLUR_MAX;

    this.debugText = `v=${Math.round(this.smoothedVp)}vp/s · Δw=${deformW.toFixed(1)} Δh=${deformH.toFixed(1)} · dx=${this.dragOffsetX.toFixed(0)}`;
  }

  private handleDragEnd(): void {
    // 按槽距取整：过半格吸附（原文用写死的 slotWidth=90，与它自己的锚点间距 77 对不上；
    // 这里用实测 pitch，同一次拖拽里"拖了几个槽"与"落在哪个锚点"天然一致）。
    const slots: number = this.pitch > 0 ? Math.round(this.dragOffsetX / this.pitch) : 0;
    const lastIndex: number = this.protoTabs.length - 1;
    const target: number = Math.max(0, Math.min(lastIndex, this.pillIndex + slots));
    this.debugText = slots === 0 ? '回弹（未过半格）' : `吸附 → ${this.protoTabs[target].title}`;
    this.pillTravelTo(target);
  }

  // —— 渲染 ——

  // 页签内容：官方槽位与胶囊副本共用同一 builder（抄两份必然逐像素漂移）。
  // withBlur 只有胶囊副本为 true：雾值由拖拽距离连续驱动，官方份恒清晰。
  @Builder
  tabItemContent(index: number, withBlur: boolean) {
    Column({ space: 3 }) {
      Image(this.protoTabs[index].icon)
        .width(24)
        .height(24)
        .objectFit(ImageFit.Contain)
        .fillColor(this.currentIndex === index ? $r('app.color.ds_brand') : $r('app.color.ds_icon'))
        .blur(withBlur ? this.contentBlur : 0)
      Text(this.protoTabs[index].title)
        .fontSize(10)
        .fontColor(this.currentIndex === index ? $r('app.color.ds_brand') : $r('app.color.ds_icon'))
        .blur(withBlur ? this.contentBlur : 0)
    }
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
  }

  // 官方 HdsTabs 页签：onAreaChange 回抛窗口矩形供锚点实测；
  // 被胶囊盖住的那颗整份隐掉（真磨砂会把官方图标糊成光晕，清晰副本由胶囊自带）。
  @Builder
  tabBarBuilder(index: number) {
    Stack({ alignContent: Alignment.Center }) {
      this.tabItemContent(index, false)
    }
    .width(64)
    .height(54)
    .opacity(this.coveredIndex === index ? 0 : 1)
    .onAreaChange((_old: Area, area: Area): void => {
      this.recordSlotArea(index, area);
    })
  }

  // 演示页内容：只做最小说明，聚焦胶囊交互本身。
  @Builder
  demoPageContent(index: number) {
    Column({ space: 12 }) {
      Image(this.protoTabs[index].icon)
        .width(56)
        .height(56)
        .objectFit(ImageFit.Contain)
        .fillColor($r('app.color.ds_brand'))
      Text(this.protoTabs[index].title)
        .fontSize(22)
        .fontWeight(FontWeight.Medium)
      Text(`第 ${index + 1} 页 · 按住底部胶囊左右拖，松手按半格吸附`)
        .fontSize(13)
        .fontColor($r('app.color.text_secondary'))
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
  }

  // Dock 之上的覆盖式胶囊。整层 hitTestBehavior=None：不吃点击（页签命中归官方 TabBar），
  // 胶囊本体 Transparent：自己收手势、同时把命中透给下层。
  @Builder
  dockPillLayer() {
    Stack({ alignContent: Alignment.TopStart }) {
      if (this.pillReady) {
        // 玻璃配方三件套（主框架同款，缺一退化为色块贴片）：
        // 透底磨砂 + 中性半透面 + 亮 rim/近距落影。
        Column() {
          // ⚠️ @Builder 参数是值快照：用 key 随 displayIndex 变化的单元素 ForEach 强制重建
          // 副本（主框架真机实证：直接传变量落位后内容不刷新）。
          ForEach([this.displayIndex], (i: number) => {
            this.tabItemContent(i, true)
          }, (i: number): string => `pill${i}`)
        }
        .width(this.pillW)
        .height(this.pillH)
        // 副本与官方份逐像素重合：官方份被 Stack(Center) 居中，这里必须显式居中。
        .justifyContent(FlexAlign.Center)
        .alignItems(HorizontalAlign.Center)
        .borderRadius(this.pillH / 2)
        .backdropBlur(GlassTokens.SEGMENT_BLUR)
        .backgroundColor($r('app.color.glass_pill_fill'))
        .border({ width: PILL_RIM_VP, color: $r('app.color.glass_pill_rim') })
        .shadow(ShadowTokens.pillFloat)
        .position({ x: this.pillX - this.pillW / 2, y: this.pillY - this.pillH / 2 })
        // 拖拽跟手与 travel 归零插值都走这一个 translate。
        .translate({ x: this.dragOffsetX })
        .hitTestBehavior(HitTestMode.Transparent)
        .gesture(
          PanGesture({ direction: PanDirection.Horizontal, fingers: 1, distance: 5 })
            .onActionStart((): void => {
              this.handleDragStart();
            })
            .onActionUpdate((event: GestureEvent): void => {
              this.handleDragUpdate(event);
            })
            .onActionEnd((): void => {
              this.handleDragEnd();
            })
        )
      }
    }
    .width('100%')
    .height('100%')
    .hitTestBehavior(HitTestMode.None)
    .onAreaChange((_old: Area, area: Area): void => {
      this.layerArea = {
        x: Number(area.globalPosition.x),
        y: Number(area.globalPosition.y),
        w: Number(area.width),
        h: Number(area.height),
      };
      this.scheduleRemeasure();
    })
  }

  build() {
    Stack({ alignContent: Alignment.Bottom }) {
      if (isImmersiveLightSenseSupported()) {
        HdsTabs({ controller: this.hdsController }) {
          ForEach(this.protoTabs, (tab: ProtoTab, index: number) => {
            TabContent() {
              this.demoPageContent(index)
            }
            .tabBar(this.tabBarBuilder(index))
          }, (tab: ProtoTab): string => tab.title)
        }
        .width('100%')
        .height('100%')
        .barOverlap(true)
        .barPosition(BarPosition.End)
        .vertical(false)
        .barFloatingStyle({
          barWidth: {
            smallWidth: DOCK_WIDTH_SMALL,
            mediumWidth: DOCK_WIDTH_SMALL,
            largeWidth: DOCK_WIDTH_SMALL,
          },
          barSideMargin: DOCK_SIDE_MARGIN_MIN,
          barBottomMargin: DOCK_BOTTOM_MARGIN_BASE + bottomNavInset(),
          gradientMask: { maskColor: $r('app.color.bar_gradient_mask'), maskHeight: DOCK_GRADIENT_MASK_HEIGHT },
          systemMaterialEffect: {
            materialType: DOCK_MATERIAL_TYPE,
            materialLevel: DOCK_MATERIAL_LEVEL,
          },
        })
        // 原文同款：页面滑动与原生动画全关，切页与动效完全由胶囊驱动。
        .scrollable(false)
        .animationDuration(0)
        .onTabBarClick((index: number): void => {
          this.pillTravelTo(index);
        })
        .onChange((index: number): void => {
          // changeIndex 回环：胶囊动画已在 pillTravelTo 里发起，这里只同步染色。
          this.currentIndex = index;
        })

        this.dockPillLayer()

        // 顶部说明 + 调参读数（原型页本职：让参数在真机上可读）。
        Column({ space: 4 }) {
          Text('Dock 胶囊拖拽原型')
            .fontSize(16)
            .fontWeight(FontWeight.Medium)
          Text('按住玻璃胶囊左右拖：快甩拉长、回拉收窄，近锚点显影，松手过半格吸附')
            .fontSize(12)
            .fontColor($r('app.color.text_secondary'))
            .textAlign(TextAlign.Center)
          Text(this.debugText)
            .fontSize(11)
            .fontColor($r('app.color.text_tertiary'))
        }
        .width('100%')
        .height('100%')
        .justifyContent(FlexAlign.Start)
        .alignItems(HorizontalAlign.Center)
        .padding({ top: 24, left: 24, right: 24 })
        .hitTestBehavior(HitTestMode.None)
      } else {
        Text('本机不支持 HdsTabs 悬浮条（需 HarmonyOS 6.1 / API 23+ 且具备 HDS 系统能力）')
          .fontSize(14)
          .fontColor($r('app.color.text_secondary'))
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.bg_primary'))
  }
}
