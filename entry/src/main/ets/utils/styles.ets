// 公共 UI 样式工具：页面转场、动画参数等，供全局复用
// 用途：统一视觉体验，消除 14 个页面重复的 .transition() 代码

// 页面级转场：轻量右侧滑入 + 渐显
// 用法：.transition(buildPageTransition())
export function buildPageTransition(): TransitionEffect {
  return TransitionEffect.OPACITY
    .animation({ duration: 300, curve: Curve.EaseOut })
    .combine(TransitionEffect.translate({ x: 50 })
      .animation({ duration: 350, curve: Curve.EaseOut }));
}
