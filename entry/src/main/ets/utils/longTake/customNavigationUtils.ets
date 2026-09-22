// 一镜到底转场的「回调注册表」——对齐官方 transitions-collection 的
// utils/customtransition/CustomNavigationUtils.ets（类名/成员名与官方一致，便于两份代码对照维护）。
//
// 分工：
//   目的地页（PostDetailDestination）在 onReady 里按自己的 navDestinationId 注册转场；
//   框架（pages/Index 的 customNavContentTransition）按 from/to 的 id 查表，把动画交给对应页。
import { hilog } from '@kit.PerformanceAnalysisKit';

const TAG: string = 'CustomTransition';

/* 注册项：官方同名同形
 * timeout：转场超时（ms），超时后由框架兜底结束，避免动画卡住不放行；
 * animation：动画回调，框架在转场开始时调用。
 */
export interface AnimateCallback {
  timeout?: number;
  animation?: (transitionProxy: NavigationTransitionProxy) => void;
}

const customTransitionMap: Map<string, AnimateCallback> = new Map();

export class CustomTransition {
  static delegate: CustomTransition = new CustomTransition();
  // 框架在 customNavContentTransition 里回填：页面动画据此判断走进场还是返回
  operation: NavigationOperation = NavigationOperation.PUSH;
  proxy: NavigationTransitionProxy | undefined = undefined;

  static getInstance(): CustomTransition {
    return CustomTransition.delegate;
  }

  /* 为一页注册转场动画（官方签名）
   * name：注册页面的唯一标识（NavDestination 的 navDestinationId）
   */
  registerNavParam(name: string,
    timeout: number,
    animation?: (transitionProxy: NavigationTransitionProxy) => void): void {
    const registered: AnimateCallback | undefined = customTransitionMap.get(name);
    if (registered !== undefined) {
      // 同一页二次进入：覆盖，避免残留上一次的回调
      registered.timeout = timeout;
      registered.animation = animation;
    } else {
      const params: AnimateCallback = { timeout: timeout, animation: animation };
      customTransitionMap.set(name, params);
    }
    hilog.info(0x0000, TAG, `register success: ${name}`);
  }

  // 注：官方写作 unRegisterNavParam（大写 R），此处按常规拼写
  unregisterNavParam(name: string): void {
    customTransitionMap.delete(name);
  }

  // 查表（官方同名）。未注册时返回空对象，调用方据 animation === undefined 判断走系统默认转场
  getAnimateParam(name: string): AnimateCallback {
    const registered: AnimateCallback | undefined = customTransitionMap.get(name);
    if (registered !== undefined) {
      return registered;
    }
    const empty: AnimateCallback = {};
    return empty;
  }
}
