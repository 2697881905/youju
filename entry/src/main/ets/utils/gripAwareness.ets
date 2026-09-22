import { motion } from '@kit.MultimodalAwarenessKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { hilog } from '@kit.PerformanceAnalysisKit';

// 智感握姿（系统智能感知引擎）的统一接入点。
// 职责边界：本模块只负责「订阅系统握持手信号 + 机型/权限降级」，
// 把原始状态写入 AppStorage.holdingHandStatus；
// 「派生 gripOnRight + animateTo 过渡」由消费组件（PostDetailView）在 UI 上下文里完成——
// 对齐/位移类布局变化必须包进 animateTo 才会连续滑动，util 里没有 UIContext 做不了这件事。

const TAG: string = 'GripAwareness';
const LOG_DOMAIN: number = 0x0000;

// AppStorage 键
// 原始握持手状态（数值，对应 motion.HoldingHandStatus）：1=左手 2=右手 0=未握持/不支持
export const KEY_HOLDING_HAND_STATUS: string = 'holdingHandStatus';
// 派生布局标记：true = 整组居右；由消费组件在 animateTo 内写入
export const KEY_GRIP_ON_RIGHT: string = 'gripOnRight';

// motion.HoldingHandStatus 数值（@since 20）
const HH_NOT_HELD: number = 0;
const HH_LEFT_HAND_HELD: number = 1;
const HH_RIGHT_HAND_HELD: number = 2;

let subscribed: boolean = false;

// 机型能力探测：模拟器/不支持握持检测的设备返回 false（canIUse 不抛出）
export function isGripAwarenessSupported(): boolean {
  return canIUse('SystemCapability.MultimodalAwareness.Motion');
}

// 订阅握持手状态变化。在需要跟手布局的页面 aboutToAppear 调用，
// aboutToDisappear 调 stopGripTracking() 释放（官方建议：避免多余的性能功耗开销）。
export function startGripTracking(): void {
  if (!isGripAwarenessSupported()) {
    AppStorage.setOrCreate<number>(KEY_HOLDING_HAND_STATUS, HH_NOT_HELD);
    hilog.warn(LOG_DOMAIN, TAG, 'grip awareness not supported on this device');
    return;
  }
  if (!subscribed) {
    try {
      motion.on('holdingHandChanged', onHoldingHandChanged);
      subscribed = true;
      hilog.info(LOG_DOMAIN, TAG, 'holdingHandChanged subscribed');
    } catch (err) {
      const e = err as BusinessError;
      // 801：设备不支持；201：权限被拒（系统开关关闭等）。统一降级为默认布局。
      hilog.warn(LOG_DOMAIN, TAG, 'subscribe holdingHandChanged failed code=%{public}d msg=%{public}s', e.code, e.message);
      AppStorage.setOrCreate<number>(KEY_HOLDING_HAND_STATUS, HH_NOT_HELD);
    }
  }
  // 页面进入时主动查一次「最近操作手」：holdingHandChanged 只在状态变化时触发，
  // 进页时若已握持左手且未换手，事件不会来——不查询的话消费侧永远落在默认右手布局。
  // 点击进详情的那只手的拇指就是最近操作手，是当前侧的最佳初始信号。
  queryOperatingHand();
}

// 主动查询「最近操作手」（@since 15，兼容本工程）并写入 holdingHandStatus。
// 仅单手结果写入；UNKNOWN 不动消费侧的当前布局。
export function queryOperatingHand(): void {
  if (!isGripAwarenessSupported()) {
    return;
  }
  try {
    const hand: motion.OperatingHandStatus = motion.getRecentOperatingHandStatus();
    if (hand === motion.OperatingHandStatus.LEFT_HAND_OPERATED ||
      hand === motion.OperatingHandStatus.RIGHT_HAND_OPERATED) {
      AppStorage.setOrCreate<number>(KEY_HOLDING_HAND_STATUS, Number(hand));
      hilog.info(LOG_DOMAIN, TAG, 'recent operating hand=%{public}d', Number(hand));
    }
  } catch (err) {
    const e = err as BusinessError;
    hilog.warn(LOG_DOMAIN, TAG, 'query operating hand failed code=%{public}d msg=%{public}s', e.code, e.message);
  }
}

export function stopGripTracking(): void {
  if (!subscribed) {
    return;
  }
  try {
    motion.off('holdingHandChanged', onHoldingHandChanged);
  } catch (err) {
    // 注销失败不阻断
  }
  subscribed = false;
}

const onHoldingHandChanged = (status: motion.HoldingHandStatus): void => {
  hilog.info(LOG_DOMAIN, TAG, 'holdingHand=%{public}d', Number(status));
  // 仅单手状态写入；BOTH_HANDS_HELD / NOT_HELD / UNKNOWN 不写——
  // 消费侧保持上一次布局（官方行为：离手/双手不触发迁移）
  if (status !== HH_LEFT_HAND_HELD && status !== HH_RIGHT_HAND_HELD) {
    return;
  }
  AppStorage.setOrCreate<number>(KEY_HOLDING_HAND_STATUS, Number(status));
};
