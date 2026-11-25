---
title: "2026-09-15-arkui-motion-design-token-system.md"
id: markdown_798285c88467638f6a8dc28635ad6f33_cc6111672e3b8b39e12465e626f2edc87505655250320770
kb: 有据-YouJu
folder: "问题记录"
media_type: 7
tags: []
source: ima
exported_at: 2026-11-23T14:52:37.917Z
---
---
id: 2026-09-15-arkui-motion-design-token-system
title: ArkUI 动画设计令牌系统：集中管理动画参数以保障全局一致性
category: architecture
nature: decision
created_at: 2026-09-15T15:08:04
updated_at: 2026-09-15T15:25:09
tags: [ArkUI, design-token, animation, motion, consistency]
keywords: [MotionTokens, MotionCurves, design token, animateTo, TransitionEffect, cubicBezierCurve, springMotion, ArkUI animation, 动画令牌, 动画一致性]
problem_patterns: [animation-parameter-drift, inconsistent-motion-feel, hardcoded-duration]
source_sessions: [ses_f5c27a718ffeXtJJltNE8iMaPp]
project: HarmonyProject1
severity: medium
quality_score: 86
hit_count: 1
last_hit_at: 2026-09-15T23:08:42
low_quality_hit_count: 0
tier: S
related_experiences: [2026-09-15-arkui-shared-element-transition, 2026-09-15-arkui-spring-motion-card-deck, 2026-09-15-arkui-transition-effect-staggered-enter]
---

# ArkUI 动画设计令牌系统：集中管理动画参数以保障全局一致性

## Scenario

在 ArkUI 项目中，动画参数（时长、曲线、缩放比例等）如果分散在各页面和组件中硬编码，会导致以下问题：

1. **参数漂移**：不同开发者写出不同的"手感"——同样是"页面进入"，有的页面 200ms 有的 300ms，曲线参数也不一致。
2. **维护困难**：修改一个全局动画风格需要逐文件搜索替换，容易遗漏。
3. **缺乏语义**：`duration: 220` 无法表达这是"控件切换"还是"容器展开"的节奏。

当项目超过 10+ 页面、20+ 动画组件时，这个问题会显著放大。

## Key Signals

- 多个页面/组件中出现相似的 `animateTo({ duration: ... })` 但 duration 值不一致
- 同一语义的动画（如"页面进入"）在不同位置使用不同的曲线参数
- 修改全局动画风格时需要逐文件搜索替换
- 代码审查中发现动画参数"魔法数"泛滥

## Essence

核心张力是 **局部灵活性 vs 全局一致性**。直接在各组件中写动画参数最灵活，但会导致参数漂移；完全禁止自定义又过于僵化。

解决方案是 **两层抽象**：

1. **MotionTokens（时长+缩放令牌）**：将动画时长按语义分级（instant/fast/base/slow/enter/page/emphasis），并定义交互节奏映射（interaction→fast, control→base, container→slow, page→420ms）。页面只消费语义 token，不直接写数字。
2. **MotionCurves（曲线令牌）**：将贝塞尔曲线和弹簧曲线按语义命名（standard/decelerate/accelerate/spring/springSoft/emphasized），以及 GSAP 级弹性预设（springInteract/springRelease/springSettle/springTrack）。

关键设计决策：

- **语义分层而非数值分层**：`MotionTokens.page = 420` 比 `MotionTokens.duration420` 更有意义，因为它表达了"页面进入"这个语义。
- **交互节奏映射**：`interaction < control < container < page`，这个节奏层级比具体数值更重要。
- **弹簧曲线独立命名**：`springMotion(response, dampingFraction)` 的参数调优需要大量 trial-and-error，一旦调好应该作为预设复用。

被拒绝的替代方案：

- **方案 B：CSS 变量风格**：在 AppStorage 中存储动画参数，运行时可动态修改。拒绝原因：ArkUI 的 AppStorage 绑定会增加状态管理复杂度，且动画参数不需要运行时动态调整。
- **方案 C：各组件自行定义常量**：每个组件文件顶部定义自己的动画常量。拒绝原因：仍然无法保证跨组件一致性，只是把问题从"魔法数"变成了"局部常量"。

## Approach

1. 创建 `design/tokens/motion.ets`，定义 `MotionTokens` 和 `MotionCurves` 两个静态类：

```typescript
import { curves } from '@kit.ArkUI';

export class MotionTokens {
  static readonly instant: number = 100;
  static readonly fast: number = 140;
  static readonly base: number = 220;
  static readonly slow: number = 320;
  static readonly enter: number = 360;
  static readonly page: number = 420;
  static readonly emphasis: number = 460;
  static readonly stagger: number = 40;
  // 交互节奏语义映射
  static readonly interaction: number = MotionTokens.fast;
  static readonly control: number = MotionTokens.base;
  static readonly container: number = MotionTokens.slow;
  // 缩放参数
  static readonly pressScale: number = 0.97;
  static readonly enterScale: number = 0.975;
}

export class MotionCurves {
  static readonly standard: ICurve = curves.cubicBezierCurve(0.2, 0.8, 0.2, 1);
  static readonly decelerate: ICurve = curves.cubicBezierCurve(0, 0, 0.2, 1);
  static readonly spring: ICurve = curves.cubicBezierCurve(0.34, 1.56, 0.64, 1);
  static readonly emphasized: ICurve = curves.cubicBezierCurve(0.16, 1, 0.3, 1);
  // 弹簧物理预设
  static readonly springInteract: ICurve = curves.springMotion(0.6, 0.85);
  static readonly springRelease: ICurve = curves.springMotion(0.5, 0.75);
}
```

2. 所有页面和组件消费语义 token，不直接写数值：

```typescript
// 正确用法
this.getUIContext().animateTo({ duration: MotionTokens.page, curve: MotionCurves.emphasized }, () => { ... });
.animation({ duration: MotionTokens.fast, curve: MotionCurves.standard })

// 错误用法（魔法数）
this.getUIContext().animateTo({ duration: 420, curve: curves.cubicBezierCurve(0.16, 1, 0.3, 1) }, () => { ... });
```

3. 对于共享元素转场等需要组合参数的场景，定义 `MotionShared` 类：

```typescript
export class MotionShared {
  static readonly transition: sharedTransitionOptions = {
    duration: MotionTokens.page,
    curve: MotionCurves.emphasized,
    zIndex: 45,
  };
}
```

## Faster Next Time

- 在项目初期就建立 motion design tokens，避免后期 retrofit 的大量搜索替换工作
- 代码审查中检查：任何 `animateTo` 或 `.animation()` 调用中出现的裸数字都应替换为语义 token
- 建立一条规则：新增动画参数必须先在 MotionTokens/MotionCurves 中定义语义名称，然后才能在组件中使用
- 弹簧曲线参数（response, dampingFraction）的调优经验非常宝贵，一旦确定应立即固化为 MotionCurves 的预设

## Applicability Boundaries

- **适用**：中大型 ArkUI 项目（10+ 页面/组件），需要全局动画一致性
- **适用**：团队协作场景，多人开发需要统一的动画"手感"标准
- **不适用**：小型 demo 或原型项目，过度抽象增加不必要的复杂度
- **不适用**：需要运行时动态调整动画参数的场景（应使用 AppStorage 绑定方案）
- **重新评估条件**：当项目需要支持主题切换（如暗色模式下的动画风格变化）时，可能需要将部分 token 改为动态绑定

## Evidence or Examples

HarmonyProject1 项目中 `entry/src/main/ets/design/tokens/motion.ets` 的实际实现：

- MotionTokens 定义了 12 个时长 token + 4 个缩放 token，覆盖了从按压反馈（140ms）到页面进入（420ms）的全节奏范围
- MotionCurves 定义了 7 条贝塞尔曲线 + 4 条弹簧物理曲线，包括标准、减速、加速、弹性、强调等语义
- 项目中 16+ 处 `animateTo` 调用、43+ 处 `.transition()` 调用、70+ 处 `.animation()` 调用全部消费语义 token
- 14 个页面通过 `buildPageTransition()` 工具函数复用统一的页面转场效果，消除了重复代码
