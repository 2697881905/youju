// 公共 UI 样式工具：页面转场、动画参数等，供全局复用
// 用途：统一视觉体验，消除 14 个页面重复的 .transition() 代码

// 页面级转场：短距离滑入 + 渐显，避免慢速大位移造成残影。
// 用法：.transition(buildPageTransition())
export function buildPageTransition(): TransitionEffect {
  return TransitionEffect.OPACITY
    .animation({ duration: 220, curve: Curve.FastOutSlowIn })
    .combine(TransitionEffect.translate({ x: 12 })
      .animation({ duration: 240, curve: Curve.FastOutSlowIn }));
}
