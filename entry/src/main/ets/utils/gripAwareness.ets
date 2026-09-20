import { motion } from '@kit.MultimodalAwarenessKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { hilog } from '@kit.PerformanceAnalysisKit';

// 智感握姿（系统智能感知引擎）的统一接入点：
// - 只订阅一次 holdingHandChanged（@since 20），状态写入 AppStorage 供组件以 @StorageProp 消费；
// - 降级链全部收敛到「默认布局」：canIUse 不支持 / 801 设备不支持 / 201 权限拒绝 /
//   系统开关（设置>系统>智感握姿）关闭时表现为无回调，不报错；
// - 防抖：BOTH_HANDS_HELD / NOT_HELD / UNKNOWN_STATUS 不触发迁移，维持上一次单手侧
//   （与华为浏览器行为一致：离手/双手保持上一手势状态）。

const TAG: string = 'GripAwareness';
const LOG_DOMAIN: number = 0x0000;

// AppStorage 键：true = 内容区贴右侧（右手握持，拇指侧），false = 贴左侧（左手/默认布局）
export const KEY_GRIP_ON_RIGHT: string = 'gripOnRight';

// motion.HoldingHandStatus 数值（@since 20）：LEFT=1 / RIGHT=2；BOTH=3、NOT_HELD=0、UNKNOWN=16 不触发迁移
const HH_LEFT_HAND_HELD: number = 1;
const HH_RIGHT_HAND_HELD: number = 2;

let subscribed: boolean = false;
let lastSideIsRight: boolean = false;

// 机型能力探测：模拟器/不支持握持检测的设备返回 false（canIUse 不抛出）
export function isGripAwarenessSupported(): boolean {
  return canIUse('SystemCapability.MultimodalAwareness.Motion');
}

// 订阅握持手状态变化。在需要跟手布局的页面 aboutToAppear 调用，
// aboutToDisappear 调 stopGripTracking() 释放（官方建议：避免多余的性能功耗开销）。
export function startGripTracking(): void {
  if (subscribed) {
    return;
  }
  if (!isGripAwarenessSupported()) {
    AppStorage.setOrCreate<boolean>(KEY_GRIP_ON_RIGHT, false);
    hilog.warn(LOG_DOMAIN, TAG, 'grip awareness not supported on this device');
    return;
  }
  try {
    motion.on('holdingHandChanged', onHoldingHandChanged);
    subscribed = true;
    hilog.info(LOG_DOMAIN, TAG, 'holdingHandChanged subscribed');
  } catch (err) {
    const e = err as BusinessError;
    // 801：设备不支持；201：权限被拒（系统开关关闭等）。统一降级为默认布局。
    hilog.warn(LOG_DOMAIN, TAG, 'subscribe holdingHandChanged failed code=%{public}d msg=%{public}s', e.code, e.message);
    AppStorage.setOrCreate<boolean>(KEY_GRIP_ON_RIGHT, false);
  }
}

export function stopGripTracking(): void {
  if (!subscribed) {
    return;
  }
  try {
    motion.off('holdingHandChanged', onHoldingHandChanged);
  } catch (err) {
    // 注销失败不阻断：下次 start 会重复订阅前先由 subscribed 标记挡住
  }
  subscribed = false;
}

const onHoldingHandChanged = (status: motion.HoldingHandStatus): void => {
  hilog.info(LOG_DOMAIN, TAG, 'holdingHand=%{public}d', Number(status));
  if (status === HH_LEFT_HAND_HELD) {
    lastSideIsRight = false;
  } else if (status === HH_RIGHT_HAND_HELD) {
    lastSideIsRight = true;
  } else {
    // BOTH_HANDS_HELD / NOT_HELD / UNKNOWN_STATUS：保持上一次布局，避免组件左右横跳
    return;
  }
  AppStorage.setOrCreate<boolean>(KEY_GRIP_ON_RIGHT, lastSideIsRight);
};
