// 信息流卡片入场过渡：单一出处。
// 首页（HomeTab.feedPost）与管理/搜索类列表（ManagedPostFeed）共用同一口径 ——
// duration/curve/位移三处完全一致，避免各列表各写一份渐变参数导致观感漂移。
// idx = 卡片在其所在列内的下标；延迟按 idx 阶梯递增并截断上限（6），
// 避免长列表末项累积出可观的首屏延迟。
import { MotionCurves, MotionTokens } from '../design/tokens/motion';

export function feedItemTransition(idx: number): TransitionEffect {
  const delay: number = Math.min(idx, 6) * MotionTokens.stagger;
  return TransitionEffect.OPACITY
    .animation({ duration: MotionTokens.slow, curve: MotionCurves.decelerate, delay: delay })
    .combine(TransitionEffect.translate({ y: 14 })
      .animation({ duration: MotionTokens.slow, curve: MotionCurves.decelerate, delay: delay }));
}
