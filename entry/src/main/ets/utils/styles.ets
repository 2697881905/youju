// 公共 UI 样式工具：页面转场、动画参数等，供全局复用
// 用途：统一视觉体验，消除 14 个页面重复的 .transition() 代码

import { MotionCurves } from '../design/tokens/motion';

// 页面级转场：短距离滑入 + 渐显，避免慢速大位移造成残影。
// 用法：.transition(buildPageTransition())
export function buildPageTransition(): TransitionEffect {
  return TransitionEffect.OPACITY
    .animation({ duration: 220, curve: Curve.FastOutSlowIn })
    .combine(TransitionEffect.translate({ x: 12 })
      .animation({ duration: 240, curve: Curve.FastOutSlowIn }));
}

// 「一镜到底」共享元素转场专用页级转场：纯渐显（无横向位移）。
// 共享元素飞行时整页不参与平移，避免「整页滑动 × 卡面放大」双动效打架。
// duration 与 MotionShared 的 380ms 对齐，避免页面先于共享元素完成渐显造成割裂感；
// delay 60ms 让共享元素先启动飞行，页面背景随后渐显跟上，视觉层次更连贯。
// 用法：共享元素路径下 .transition(buildFadePageTransition())
export function buildFadePageTransition(): TransitionEffect {
  return TransitionEffect.OPACITY
    .animation({ duration: 380, curve: MotionCurves.decelerate, delay: 60 });
}
