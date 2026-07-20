// 公共 UI 样式工具：页面转场、动画参数等，供全局复用
// 用途：统一视觉体验，消除 14 个页面重复的 .transition() 代码

// 页面级转场：Apple 风格弹性滑入 + 渐显
// FastOutSlowIn 模拟 iOS 系统默认 ease-in-out — 先快后缓收，接近弹簧手感
// 用法：.transition(buildPageTransition())
export function buildPageTransition(): TransitionEffect {
  return TransitionEffect.OPACITY
    .animation({ duration: 360, curve: Curve.FastOutSlowIn })
    .combine(TransitionEffect.translate({ x: 24 })
      .animation({ duration: 380, curve: Curve.FastOutSlowIn }));
}
