// 卡片「一镜到底」导航转场工具：
// 用 componentUtils 读取卡片媒体块的屏幕帧，供转场计算起点
// （源页量卡片帧 → 随 push 参数传给目的地页）。
// 旧的覆盖层方案（captureCardSnapshot / coverTargetRect / transformBetween）已随方案下线删除。

// 屏幕帧（单位 vp）：与卡片媒体块 on-screen 矩形对应
export interface CardRect {
  left: number;
  top: number;
  width: number;
  height: number;
}

// 读取绑定 id 组件的屏幕矩形（统一换算为 vp；componentUtils 返回单位为 px）。
//
// getRectangleById 已废弃（since 18）→ 走 UIContext.getComponentUtils（@since 11 ✓）。
// 取 windowOffset 而非 screenOffset：与 getPositionToWindowWithTransform 的坐标系保持一致
// （本项目只有一个全屏窗口，两者数值相同，但要与目的地页的量测同源）。
//
// 缩放补偿（照官方 ComponentAttrUtils.getRectInfoById）：组件被 scale 后，
// getRectangleById 给的是**布局**矩形，视觉矩形要按缩放差内缩，否则量到的起点比实际大一圈。
export function cardRectOf(mediaId: string): CardRect | null {
  try {
    const ui: UIContext | null = getSharedUiContext();
    if (ui === null || mediaId.length === 0) {
      return null;
    }
    const rect = ui.getComponentUtils().getRectangleById(mediaId);
    if (!rect || !rect.size) {
      return null;
    }
    const sizeWidth_px: number = rect.size.width;
    const sizeHeight_px: number = rect.size.height;
    const scaleX: number = rect.scale?.x ?? 1;
    const scaleY: number = rect.scale?.y ?? 1;
    const widthScaleGap_px: number = sizeWidth_px * (1 - scaleX) / 2;
    const heightScaleGap_px: number = sizeHeight_px * (1 - scaleY) / 2;
    const left_px: number = (rect.windowOffset?.x ?? 0) + (rect.translate?.x ?? 0) + widthScaleGap_px;
    const top_px: number = (rect.windowOffset?.y ?? 0) + (rect.translate?.y ?? 0) + heightScaleGap_px;
    return {
      left: ui.px2vp(left_px),
      top: ui.px2vp(top_px),
      width: ui.px2vp(sizeWidth_px - widthScaleGap_px * 2),
      height: ui.px2vp(sizeHeight_px - heightScaleGap_px * 2),
    };
  } catch (e) {
    return null;
  }
}

// 主框架 Navigation 的 NavPathStack 共享实例：Index 组件挂载时注册，
// HomeTab（点击卡片）与 NavDestination 壳（返回/二级跳转）跨组件读取。
export let mainNavStack: NavPathStack | null = null;

export function setMainNavStack(stack: NavPathStack): void {
  mainNavStack = stack;
}

export function getMainNavStack(): NavPathStack | null {
  return mainNavStack;
}

// 全局唯一 UIContext 共享实例：Index 组件挂载时注册（与 mainNavStack 同一生命周期）。
// 用途：util 文件（auth/navigationTransition 等）没有 this.getUIContext()，
// 要把已废弃的全局 router/px2vp/componentSnapshot 换成 UIContext 形态时从这里取。
// 版本门槛（手机形态，取自 d.ts 堆叠块中**没有 @crossplatform** 的那段）：
// px2vp/vp2px = 12、getRouter = 11、getComponentUtils = 11、getComponentSnapshot = 12，
// 均 ≤ 本工程 compatibleSdkVersion 6.0.0(20)，可放心用；全局形态自 API 18 起陆续废弃。
export let sharedUiContext: UIContext | null = null;

export function setSharedUiContext(ctx: UIContext): void {
  sharedUiContext = ctx;
}

export function getSharedUiContext(): UIContext | null {
  return sharedUiContext;
}

// 「一镜到底」详情跳转参数（pushPathByName 的 param 需要显式声明的类型，禁止裸对象字面量）
export class PostDetailNavParams {
  postId: number = 0;
  intent: Object | null = null;
  // 一镜到底（官方范式）参数：整卡 id + 卡片帧 + 整卡截图
  longTake: Object | null = null;
}

// 用户主页跳转参数
export class UserProfileNavParams {
  userId: number = 0;
}

// 无参 navDestination 跳转占位（pushPathByName 的 param 需要显式类型，禁止裸字面量）
export class EmptyNavParams {};