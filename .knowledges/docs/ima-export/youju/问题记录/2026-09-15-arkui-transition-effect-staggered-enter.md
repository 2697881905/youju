---
title: "2026-09-15-arkui-transition-effect-staggered-enter.md"
id: markdown_798285c88467638f6a8dc28635ad6f33_d3663487d09d9f42475cbc9d8b17fc227505655250320770
kb: 有据-YouJu
folder: "问题记录"
media_type: 7
tags: []
source: ima
exported_at: 2026-11-23T14:52:37.917Z
---
---
id: 2026-09-15-arkui-transition-effect-staggered-enter
title: ArkUI TransitionEffect 分层错峰入场动画模式
category: coding-pattern
nature: technique
created_at: 2026-09-15T15:08:04
updated_at: 2026-09-15T15:25:09
tags: [ArkUI, TransitionEffect, staggered, enter-animation, transition]
keywords: [TransitionEffect, OPACITY, combine, translate, scale, animation, delay, stagger, 错峰入场, 分层进入, 转场动画, ArkUI transition]
problem_patterns: [flat-enter-animation, no-stagger, jarring-page-enter]
source_sessions: [ses_f5c27a718ffeXtJJltNE8iMaPp]
project: HarmonyProject1
severity: medium
quality_score: 80
hit_count: 0
last_hit_at: null
low_quality_hit_count: 0
tier: A
related_experiences: [2026-09-15-arkui-motion-design-token-system, 2026-09-15-arkui-shared-element-transition]
---

# ArkUI TransitionEffect 分层错峰入场动画模式

## Scenario

页面或组件入场时，如果所有元素同时以相同动画进入，视觉效果生硬且缺乏层次感。常见问题：

1. **平铺入场**：页面所有元素同时 fade in，没有视觉重点引导
2. **无错峰**：列表项同时出现，用户无法感知"从上到下"的阅读流
3. **转场打架**：页面级转场（滑入）与组件级转场（缩放）同时发生，双动效互相干扰

## Key Signals

- 页面入场时所有元素同时出现，视觉上像"闪现"而非"流入"
- 列表项无 delay 错峰，用户眼睛无法跟随阅读流
- 共享元素飞行动画与页面整体平移同时发生，产生"双滑动"的混乱感

## Essence

ArkUI 的 `TransitionEffect` API 采用 **组合式声明** 设计：基础效果（OPACITY/translate/scale）通过 `.combine()` 叠加，每个效果独立配置 `.animation()` 参数（duration/curve/delay）。关键机制：

1. **`.combine()` 是叠加而非替换**：多个 TransitionEffect 通过 combine 链式叠加，每个可以有自己的 animation 参数
2. **`.animation()` 的 delay 参数实现错峰**：同一页面的不同层通过不同 delay 值实现依次入场
3. **`.transition()` 挂在组件上触发时机**：组件挂载时触发 enter、卸载时触发 exit

核心约束：**只动 transform/opacity，不参与布局属性动画**。布局属性（width/height/margin）的动画会导致重排，性能远低于 transform/opacity。

## Approach

### 模式 1：分层错峰进入（详情页/复杂页面）

将页面内容分为媒体区、标题区、正文区、评论区等层，各层通过不同 delay 错峰入场：

```typescript
// 分层进入：每层通过 delay 参数错峰
private animLayerEnter(delay: number): TransitionEffect {
  return TransitionEffect.OPACITY
    .animation({ duration: 320, curve: MotionCurves.decelerate, delay: delay })
    .combine(TransitionEffect.translate({ y: 10 })
      .animation({ duration: 320, curve: MotionCurves.decelerate, delay: delay }));
}

// 使用：各层 delay 递增
Column() { /* 标题 */ }.transition(this.animLayerEnter(140))
Column() { /* 正文 */ }.transition(this.animLayerEnter(260))
Column() { /* 评论区 */ }.transition(this.animLayerEnter(100))
```

### 模式 2：媒体区缩放起步（与列表卡片视觉动量一致）

媒体区以缩放起步，模拟"从卡片展开"的视觉动量：

```typescript
private animMediaEnter(): TransitionEffect {
  return TransitionEffect.OPACITY
    .animation({ duration: 320, curve: MotionCurves.decelerate })
    .combine(TransitionEffect.scale({ x: 0.975, y: 0.975 })
      .animation({ duration: 320, curve: MotionCurves.decelerate }));
}
```

### 模式 3：列表项错峰 Stagger 入场

列表中每个 item 通过 `index * stagger` 计算 delay，实现从上到下依次入场：

```typescript
PostCard({ post: post })
  .transition(
    TransitionEffect.OPACITY
      .animation({ duration: 320, curve: MotionCurves.decelerate,
        delay: Math.min(idx, 6) * 40 })  // 最多错峰 6 项，避免长列表末尾等待过久
      .combine(TransitionEffect.translate({ y: 14 })
        .animation({ duration: 320, curve: MotionCurves.decelerate,
          delay: Math.min(idx, 6) * 40 }))
  )
```

### 模式 4：页面级转场工具函数（消除 14 个页面重复代码）

```typescript
// 标准页面转场：短距离滑入 + 渐显
export function buildPageTransition(): TransitionEffect {
  return TransitionEffect.OPACITY
    .animation({ duration: 220, curve: Curve.FastOutSlowIn })
    .combine(TransitionEffect.translate({ x: 12 })
      .animation({ duration: 240, curve: Curve.FastOutSlowIn }));
}

// 共享元素路径专用：纯渐显（无横向位移，避免与共享元素飞行打架）
export function buildFadePageTransition(): TransitionEffect {
  return TransitionEffect.OPACITY
    .animation({ duration: 220, curve: Curve.FastOutSlowIn });
}
```

## Faster Next Time

- **错峰上限**：列表 stagger 最多错峰 6-8 项（`Math.min(idx, 6) * stagger`），避免长列表末尾等待过久
- **共享元素路径用纯渐显**：当页面存在共享元素飞行动画时，页面级转场必须改为纯渐显（无位移），避免"整页滑动 × 卡面放大"双动效打架
- **delay 值建议**：第一层 0ms（媒体先到）、第二层 100-140ms、第三层 260ms，间隔约 120-140ms
- **代码审查检查点**：任何 `.transition()` 调用中如果动画了布局属性（width/height/margin），应改为 transform/opacity

## Applicability Boundaries

- **适用**：详情页、复杂页面需要分层引导视觉重点
- **适用**：列表/信息流需要错峰入场增强阅读流感知
- **适用**：14+ 页面项目需要统一转场工具函数消除重复
- **不适用**：简单页面只有单一内容块，无需分层
- **不适用**：性能敏感的快速切换场景（如 Tab 切换），错峰 delay 会增加感知延迟
- **注意**：`TransitionEffect` 的 `.animation()` 参数（duration/curve/delay）与 `.animation()` 修饰符的参数语法相同但作用域不同——前者只作用于该 TransitionEffect，后者作用于组件的所有属性变化

## Evidence or Examples

HarmonyProject1 项目中的实际应用：

- `DetailPage.ets`：定义了 `animLayerEnter(delay)`、`animMediaEnter()`、`animMediaEnterQuiet()`、`pageEnterTransition()` 四个 TransitionEffect 工厂方法，详情页 10+ 个区域通过不同 delay 错峰入场
- `HomeTab.ets`：推荐流单卡通过 `Math.min(idx, 6) * MotionTokens.stagger` 实现 stagger 入场；每日一帖报头通过 `TransitionEffect.OPACITY.combine(translate({ y: -8 }))` 从上方落入
- `styles.ets`：`buildPageTransition()` 和 `buildFadePageTransition()` 被 14 个页面复用，消除了重复的 `.transition()` 代码
- `CircleSelectionCard.ets`：星环选中态资料卡使用 OPACITY + scale(0.8) + translate 三合一组合入场
