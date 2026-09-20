// 卡片「一镜到底」导航转场工具（Navigation 教程原版）：
// 1) 用 componentSnapshot 对卡面媒体块截图，避免转场期间目标页白屏；
// 2) 用 componentUtils 读取卡片媒体块的屏幕帧，计算"快照层"从源帧到目标帧的
//    纯 transform（translate/scale，不动布局）插值，跨页面实现无缝放大/缩回。
import { componentSnapshot, componentUtils } from '@kit.ArkUI';
import { image } from '@kit.ImageKit';

// 屏幕帧（单位 vp）：与卡片媒体块 on-screen 矩形对应
export interface CardRect {
  left: number;
  top: number;
  width: number;
  height: number;
}

// cardMedia-{postId} / deckCardMedia-{postId} 组件截图回调
export function captureCardSnapshot(mediaId: string, cb: (pixelMap: image.PixelMap | null) => void): void {
  try {
    componentSnapshot.get(mediaId, (err, pixelMap) => {
      if (err || !pixelMap) {
        cb(null);
        return;
      }
      cb(pixelMap);
    });
  } catch (e) {
    cb(null);
  }
}

// 读取绑定 id 组件的屏幕矩形（统一换算为 vp；componentUtils 返回单位为 px）
// getRectangleById 已废弃（since 18）→ 走 UIContext.getComponentUtils（@since 11 ✓）；
// px2vp 的 UIContext 形态 @since 22 > 工程下限 20，故保持全局形态（已废弃但可用）。
export function cardRectOf(mediaId: string): CardRect | null {
  try {
    const ui = getSharedUiContext();
    if (ui === null) {
      return null;
    }
    const rect = ui.getComponentUtils().getRectangleById(mediaId);
    if (!rect || !rect.size) {
      return null;
    }
    return {
      left: px2vp(rect.windowOffset?.x ?? 0),
      top: px2vp(rect.windowOffset?.y ?? 0),
      width: px2vp(rect.size.width),
      height: px2vp(rect.size.height),
    };
  } catch (e) {
    return null;
  }
}

// 目标帧内等比缩放（Cover 语义：宽高比不同时按源帧等比放进，不做拉伸）
export function coverTargetRect(src: CardRect, target: CardRect): CardRect {
  const scale = Math.min(target.width / src.width, target.height / src.height);
  const w = src.width * scale;
  const h = src.height * scale;
  return {
    left: target.left + (target.width - w) / 2,
    top: target.top + (target.height - h) / 2,
    width: w,
    height: h,
  };
}

// 从 from 帧变换到 to 帧所需的纯 transform（translate/scale，锚点左上角）
export interface SnapshotTransform {
  translateX: number;
  translateY: number;
  scaleX: number;
  scaleY: number;
}

export function transformBetween(from: CardRect, to: CardRect): SnapshotTransform {
  return {
    scaleX: to.width / Math.max(from.width, 1),
    scaleY: to.height / Math.max(from.height, 1),
    translateX: to.left - from.left,
    translateY: to.top - from.top,
  };
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
// 要把已废弃的全局 router/px2vp 换成 UIContext 形态时从这里取。
// 注意（版本门槛）：UIContext.px2vp / ComponentSnapshot.get 均 @since 22，而本工程
// compatibleSdkVersion = 6.0.0(20) —— 这两个 API 保持全局形态不变；
// 只有 @since ≤ 20 的（getRouter/getComponentUtils/getFont）才允许走 UIContext 形态。
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
  src: CardRect | null = null;
  snapshot: image.PixelMap | null = null;
}

// 用户主页跳转参数
export class UserProfileNavParams {
  userId: number = 0;
}

// 无参 navDestination 跳转占位（pushPathByName 的 param 需要显式类型，禁止裸字面量）
export class EmptyNavParams {};