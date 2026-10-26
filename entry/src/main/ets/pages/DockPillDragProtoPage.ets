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
//    注释），胶囊自绘：透明 tint + 亮 rim + 落影（初版曾带 backdropBlur 真磨砂，
//    后按用户拍板 2026-10-26 去磨砂改全透明，见⑥⑦）。
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
// ⑥ 图标不跟胶囊跑（用户拍板 2026-10-26，对原文的又一处偏离）：胶囊是纯光标，飞行/拖拽中
//    官方页签全部留在原地显示。原文的「近锚显影」是图标跟跑的伴生特性，随之一并删除。
// ⑦ 胶囊透明化（用户拍板 2026-10-26：透明的，不要模糊的）：去掉 backdropBlur 真磨砂，
//    图标全程透过胶囊清晰可见，副本/接管机制整套删除；玻璃感由淡 tint + 亮 rim + 落影
//    承载。弹动同步加强：鼓包 6→10、速度形变 14→22、交叉系数 0.45→0.5、落定回弹换
//    springBounce（overshoot 自带果冻感）。
// ⑧ 穿底演示内容（用户反馈「tabbar 栏不是玻璃」）：材质参数与主框架同源（IMMERSIVE +
//    EXQUISITE）却看不出玻璃，根因是原型页 Dock 背后是纯色空背景——沉浸光感材质要
//    折射/模糊背后的内容，无内容可采样就只是一块平淡半透板。TabContent 改为滚动色块
//    列表铺到底部，色块穿过 Dock 底下时玻璃折射立现。
// ⑨ 胶囊尺寸收敛 + Y 定位改锚栏体几何中心（用户反馈「静止时溢出 tabbar 栏」）：溢出主因
//    是 Y 偏下（槽位上报 y 的 barBottomMargin 偏差在本页结构上修正不足），Y 改由
//    barBottomMargin + DOCK_BAR_HEIGHT_VP 直接推栏体中心，零上报依赖；尺寸定中档
//    宽 1.10×槽距、高 0.92×槽高。
// ⑩ 结构对齐原文（用户指出漏了包裹层）：根 Stack → HdsNavigation 包裹 HdsTabs，覆盖层
//    与 HdsNavigation 同级、声明在后（层级更高）。原顶部说明覆盖层删除：操作指引挪进
//    标题栏 subTitle，调参读数挪进各演示页内容顶部。

import { HdsNavigation, HdsNavigationTitleMode, HdsTabs, HdsTabsController } from '@kit.UIDesignKit';
import type { HdsNavigationTitleBarOptions } from '@kit.UIDesignKit';
import { isImmersiveLightSenseSupported } from '../utils/immersiveMaterial';
import { bottomNavInset, DOCK_WIDTH_SMALL, DOCK_BOTTOM_MARGIN_BASE, DOCK_SIDE_MARGIN_MIN,
  DOCK_GRADIENT_MASK_HEIGHT, DOCK_MATERIAL_TYPE, DOCK_MATERIAL_LEVEL,
  DOCK_BAR_HEIGHT_VP } from '../utils/cardTokens';
import { MotionCurves, MotionTokens } from '../design/tokens/motion';
import { ShadowTokens } from '../design/tokens/shadow';

// —— 参数定档（真机调参入口，全部集中于此；对照原文的推导写在每行注释里）——

// 尺寸取中档（用户反馈 2026-10-26：溢出的主因是 Y 定位偏下，位置修正后放宽一档）：
// 宽 = 1.10×槽距、高 = 0.92×槽高，介于「嫌大」与「液态盖过槽位」之间；嫌大/嫌小改这两个数。
const PILL_W_RATIO: number = 1.1;
const PILL_H_RATIO: number = 0.92;
// 亮 rim 描边宽度：玻璃"读得出来"的第一来源（主框架同款）。
const PILL_RIM_VP: number = 1.5;
// 拖拽起手/行进的鼓包：用户要求弹动更明显（2026-10-26），6 → 10。
const PILL_BULGE: number = 10;
// 速度形变上限：用户要求弹动更明显，14 → 22（接近 45 的等比上限，甩动的拉扯感拉满）。
const SPEED_MAX_DEFORM: number = 22;
// 反方向（回拉）时宽/高的交叉形变系数：回到原文同款 0.5。
const DEFORM_CROSS: number = 0.5;
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
// 边缘阻尼：首/尾槽往界外拖的跟手衰减（原文同款 0.3）。
const EDGE_DAMPING: number = 0.3;
// 行进/落定动画：行进保持 springSoft（位移要稳，太弹会晃）；落定换 springBounce——
// 用户要求弹动更明显（2026-10-26）。springMotion 系时长由曲线物理决定，duration 仅占位。
const TRAVEL_MS: number = 300;
const SETTLE_MS: number = 400;
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

  // 穿底演示色块：交替品牌色与系统色，铺到 Dock 底下给玻璃材质采样。
  private demoBlocks: string[] = [
    '#34C759', '#0A84FF', '#FF9500', '#AF52DE', '#FF2D55',
    '#30B0C7', '#5E5CE6', '#FF375F', '#32ADE6', '#8E8E93',
  ];

  // —— 实测几何（recomputeGeometry 产出，拖拽/动画全程只读它们）——
  private anchors: number[] = [];
  private anchorCy: number = 0;
  private slotH: number = 0;
  private pitch: number = 0;

  // —— 胶囊渲染态 ——
  @State private pillReady: boolean = false;
  @State private pillX: number = 0;
  @State private pillY: number = 0;
  @State private pillW: number = 0;
  @State private pillH: number = 0;
  // 拖拽实时偏移（translate）：拖拽中逐帧直写跟手，travel 里随 animateTo 归零插值。
  @State private dragOffsetX: number = 0;
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
    this.slotH = first.h;
    // ⚠️ Y 一律不取槽位上报值：其 globalPosition 相对真实位置带一档 barBottomMargin 偏差，
    // 主框架按它的结构实测扣 28vp，但本页真机仍见胶囊偏下（之前"溢出栏沿"的真正原因，
    // 用户反馈 2026-10-26）。改锚 Dock 栏体几何中心——barBottomMargin 与栏高
    // （DOCK_BAR_HEIGHT_VP）都是本页传给系统的已知量，零上报依赖，天然垂直居中。
    // X 不受该偏差影响，仍用各槽实测中心。
    this.anchorCy = layer.h - (DOCK_BOTTOM_MARGIN_BASE + bottomNavInset()) - DOCK_BAR_HEIGHT_VP / 2;
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
    // 只看实测数据是否就位（anchors 由 recomputeGeometry 填充）。
    // ⚠️ 不能加 !this.pillReady 门禁：pillReady 由 pillSnap 成功后才置位，而 pillSnap
    // 本身要先过这里取几何——加门禁即死锁，胶囊永不出现（真机已踩：Dock 正常、指示器消失）。
    if (index < 0 || index >= this.anchors.length) {
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
  // （收回静止尺寸，SETTLE_MS springBounce）→ 同一批里 changeIndex 切页。
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
    });
    this.settleTimer = setTimeout((): void => {
      this.settleTimer = -1;
      // 落定回弹：宽度从鼓包弹回静止尺寸，springBounce 的 overshoot 会先压扁再弹开，
      // 自带果冻感；透明胶囊下图标全程在槽位里，无需任何接管动作。
      this.getUIContext().animateTo({
        duration: SETTLE_MS,
        curve: MotionCurves.springBounce,
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
    // 起手鼓包：从静止尺寸"被拿起"，springBounce 给一记明显的轻弹。
    this.getUIContext().animateTo({
      duration: MotionTokens.fast,
      curve: MotionCurves.springBounce,
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

  // 页签内容：只有官方槽位使用（胶囊透明化后图标全程原位可见，无需副本）。
  @Builder
  tabItemContent(index: number) {
    Column({ space: 3 }) {
      Image(this.protoTabs[index].icon)
        .width(24)
        .height(24)
        .objectFit(ImageFit.Contain)
        .fillColor(this.currentIndex === index ? $r('app.color.ds_brand') : $r('app.color.ds_icon'))
      Text(this.protoTabs[index].title)
        .fontSize(10)
        .fontColor(this.currentIndex === index ? $r('app.color.ds_brand') : $r('app.color.ds_icon'))
    }
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
  }

  // 官方 HdsTabs 页签：onAreaChange 回抛窗口矩形供锚点实测。
  // 胶囊透明化后图标全程原位显示，无需隐藏/接管逻辑。
  @Builder
  tabBarBuilder(index: number) {
    Stack({ alignContent: Alignment.Center }) {
      this.tabItemContent(index)
    }
    .width(64)
    .height(54)
    .onAreaChange((_old: Area, area: Area): void => {
      this.recordSlotArea(index, area);
    })
  }

  // 演示页内容：滚动色块铺到 Dock 底下。沉浸光感材质要折射/模糊背后的内容，
  // 纯色空背景上玻璃无东西可采样（「tabbar 不是玻璃」的根因）；色块穿过 Dock
  // 底部时玻璃折射/模糊立现。
  @Builder
  demoPageContent(index: number) {
    Scroll() {
      Column({ space: 12 }) {
        Text(this.protoTabs[index].title)
          .fontSize(22)
          .fontWeight(FontWeight.Medium)
        Text(`第 ${index + 1} 页 · 上下滚动，看色块穿过 Dock 时的玻璃折射；按住胶囊拖动切页`)
          .fontSize(13)
          .fontColor($r('app.color.text_secondary'))
          .textAlign(TextAlign.Center)
        Text(this.debugText)
          .fontSize(11)
          .fontColor($r('app.color.text_tertiary'))
        ForEach(this.demoBlocks, (color: string, i: number) => {
          Row() {
            Text(`色块 ${i + 1}`)
              .fontSize(14)
              .fontColor('#FFFFFF')
          }
          .width('100%')
          .height(120)
          .borderRadius(16)
          .backgroundColor(color)
          .justifyContent(FlexAlign.Center)
        }, (color: string, i: number): string => `${index}-${i}`)
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 12, bottom: 120 })
    }
    .width('100%')
    .height('100%')
    .align(Alignment.Top)
    .scrollBar(BarState.Off)
    .edgeEffect(EdgeEffect.Spring)
  }

  // Dock 之上的覆盖式胶囊。整层 hitTestBehavior=None：不吃点击（页签命中归官方 TabBar），
  // 胶囊本体 Transparent：自己收手势、同时把命中透给下层。
  @Builder
  dockPillLayer() {
    Stack({ alignContent: Alignment.TopStart }) {
      if (this.pillReady) {
        // 透明液态光标（用户拍板 2026-10-26：透明的，不要模糊的）：无 backdropBlur，
        // 图标全程透过胶囊清晰可见；玻璃感由淡 tint（8% 黑）+ 亮 rim（65% 白）
        // + 近距落影三件承载，缺 rim/影则只剩一块看不见的空圈。
        Column()
          .width(this.pillW)
          .height(this.pillH)
          .borderRadius(this.pillH / 2)
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

  // 标题栏：MINI 双行（标题 + 操作指引），栏体挂沉浸光感（数值同 Dock，避免 import
  // hdsMaterial——API 22 上不存在，工程铁律）。hideBackButton(true) 是工程惯例：
  // 官方返回钮在本 app 从未渲染过，返回靠系统侧滑。
  private protoTitleBarOptions(): HdsNavigationTitleBarOptions {
    const options: HdsNavigationTitleBarOptions = {
      content: {
        title: {
          mainTitle: 'Dock 胶囊拖拽原型',
          subTitle: '按住胶囊左右拖 · 快甩拉长回拉收窄 · 松手过半格吸附',
        },
      },
      style: {
        systemMaterialEffect: {
          materialType: DOCK_MATERIAL_TYPE,
          materialLevel: DOCK_MATERIAL_LEVEL,
        },
      },
    };
    return options;
  }

  build() {
    // 结构对齐原文：根 Stack → HdsNavigation 包裹 HdsTabs（悬浮导航栏样式），覆盖层与
    // HdsNavigation 同级、声明在后（层级更高），落在悬浮导航栏区域充当液态指示器。
    Stack({ alignContent: Alignment.Bottom }) {
      if (isImmersiveLightSenseSupported()) {
        HdsNavigation() {
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
        }
        .width('100%')
        .height('100%')
        .titleMode(HdsNavigationTitleMode.MINI)
        .hideBackButton(true)
        .titleBar(this.protoTitleBarOptions())
        // 原文同款：忽略系统上下安全区——内容区延伸到屏幕底，barBottomMargin 才是
        // 从屏幕底起算的真实语义，覆盖层的栏体中心公式（anchorCy）与之自洽。
        .ignoreLayoutSafeArea([LayoutSafeAreaType.SYSTEM],
          [LayoutSafeAreaEdge.TOP, LayoutSafeAreaEdge.BOTTOM])

        this.dockPillLayer()
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
