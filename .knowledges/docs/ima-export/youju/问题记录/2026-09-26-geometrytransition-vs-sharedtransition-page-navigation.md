---
title: "2026-09-26-geometrytransition-vs-sharedtransition-page-navigation.md"
id: markdown_798285c88467638f6a8dc28635ad6f33_496cbf3ed77d9d29cb1ace337b87e57d7505655250320770
kb: 有据-YouJu
folder: "问题记录"
media_type: 7
tags: []
source: ima
exported_at: 2026-11-23T15:08:27.408Z
---
---
id: 2026-09-26-geometrytransition-vs-sharedtransition-page-navigation
title: ArkUI 页面转场中 geometryTransition 不能替代 sharedTransition
category: coding-pattern
nature: pitfall
created_at: 2026-09-26T15:20:35
updated_at: 2026-09-26T15:25:37
tags: [harmonyos, arkui, geometrytransition, sharedtransition, page-transition, router, animateto]
keywords: [geometryTransition, sharedTransition, router.pushUrl, animateTo, GeometryTransitionOptions, sharedTransitionOptions, 页面转场, 共享元素, 一镜到底, follow, ArkUI动画, API 12]
problem_patterns: [geometrytransition-no-animation-effect, page-transition-shared-element-not-working, wrong-transition-api-for-router-navigation]
source_sessions: [ses_f5c28246bffewejiliAiNvfUL6]
project: HarmonyProject1
severity: high
quality_score: 94
hit_count: 0
last_hit_at: null
low_quality_hit_count: 0
tier: S
related_experiences: [2026-09-15-harmonyos-shared-transition-pattern, 2026-09-26-arkui-animateto-appstorage-layout-transition]
---

# ArkUI 页面转场中 geometryTransition 不能替代 sharedTransition

## Scenario

在 HarmonyOS ArkUI 项目中，需要实现列表卡片 → 详情页的"一镜到底"共享元素转场动画（卡片封面图从列表位置"飞"到详情页位置并平滑拉伸尺寸）。现有实现使用 `sharedTransition`，但 `sharedTransition` 使用视觉快照缩放机制，`objectFit: Cover` 在不同尺寸下裁切区域不同，导致飞行过程中图片内容扭曲/拉伸。

开发者考虑用 `geometryTransition` 替代 `sharedTransition`，因为 `geometryTransition` 跟踪组件实际几何属性（frame、position），目标组件从源组件的位置/尺寸开始渲染并平滑拉伸到目标位置/尺寸，图片内容全程按当前尺寸实时正确裁切，理论上不会出现快照缩放扭曲。

## Key Signals

- 将 `.sharedTransition(id, options)` 替换为 `.geometryTransition(id)` 后，构建通过但**页面转场时共享元素动画完全消失**——卡片点击后直接闪切到详情页，没有任何飞行/拉伸过渡效果
- 用户反馈："一镜到底的动画没了"
- 查阅官方文档确认：`geometryTransition` 的描述是"必须配合 `animateTo` 使用才有动画效果，动效时长、曲线跟随 `animateTo` 中的配置"
- `GeometryTransitionOptions` 只有 `follow` 一个属性，没有 `duration`/`curve`/`zIndex`（`sharedTransitionOptions` 有这些属性）
- `router.pushUrl` / `router.back` 页面转场不会为 `geometryTransition` 提供 `animateTo` 上下文

## Essence

**`geometryTransition` 和 `sharedTransition` 适用于完全不同的动画场景：**

| API | 设计场景 | 动画驱动机制 | 页面转场支持 |
|-----|----------|-------------|-------------|
| `sharedTransition` | **页面间**转场（router push/pop） | 与 router 转场系统天然集成，框架自动计算源/目标位置差并执行插值 | ✅ 原生支持 |
| `geometryTransition` | **组件内**视图切换（同一页面内条件渲染替换） | 必须配合 `animateTo` 显式驱动，动效时长/曲线跟随 `animateTo` 配置 | ❌ 不支持 |

核心约束：

1. **`geometryTransition` 必须配合 `animateTo`**：它本身不产生动画，只是声明了 in/out 组件的几何关联关系。动画效果完全依赖外层 `animateTo` 调用提供时长和曲线。`router.pushUrl` 页面转场不会为 `geometryTransition` 提供 `animateTo` 上下文，因此替换后动画完全消失。

2. **`sharedTransition` 与 router 转场系统集成**：框架在检测到页面 push/pop 时，自动查找源页面和目标页面中匹配相同 id 的 `sharedTransition` 组件，计算位置/尺寸差并执行飞行动画。不需要开发者手动调用 `animateTo`。

3. **API 参数差异印证设计意图**：`sharedTransitionOptions` 包含 `duration`/`curve`/`zIndex`，因为框架需要这些参数来执行自动动画；`GeometryTransitionOptions` 只有 `follow`，因为动画参数由外层 `animateTo` 提供。

## Approach

### 判断流程：何时用哪个 API

```
是否是页面间转场（router.pushUrl / router.back）？
├── 是 → 使用 sharedTransition（与 router 转场系统集成）
│        └── 源端和目标端挂载相同 id 的 .sharedTransition(id, options)
│        └── 框架自动计算位置差并执行飞行/缩放动画
│
└── 否（同一页面内组件切换）→ 使用 geometryTransition
         └── 源组件和目标组件挂载相同 id 的 .geometryTransition(id)
         └── 必须在 animateTo({ duration, curve }, () => { ... }) 内触发状态变更
         └── 动效时长/曲线跟随 animateTo 配置
```

### 如果需要改善 sharedTransition 的图片拉伸问题

不要替换为 `geometryTransition`。在 `sharedTransition` 框架内优化：

1. **确保源端和目标端 `aspectRatio` 一致**：hero 占位图用与源卡相同的比例，避免非等比插值
2. **用 `holdHero` 机制隔离飞行期和阅读期**：飞行期间用同比 hero 占位，holdHero 释放后切换为真实比例内容（移除共享 id），避免停留后返回时的比例不匹配
3. **曲线选择**：持续运动场景用 `standard`（cubicBezier 0.2, 0.8, 0.2, 1）而非 `emphasized`，避免前 16% 时间几乎不动的"卡顿起步"感
4. **页面转场与共享元素协调**：共享元素路径的页面级转场改为纯渐显（无位移），duration 与共享元素对齐

## Faster Next Time

- **看到 `geometryTransition` 替换 `sharedTransition` 的提议时，立即否决**——它们适用于不同场景，替换会导致页面转场动画完全消失
- **判断标准**：如果动画发生在 `router.pushUrl` / `router.back` 之间，必须用 `sharedTransition`；如果动画发生在同一页面内的条件渲染切换，用 `geometryTransition` + `animateTo`
- **`GeometryTransitionOptions` 只有 `follow` 属性**——如果你看到有人试图往里面传 `duration`/`curve`，说明混淆了两个 API
- **官方文档关键词**：`geometryTransition` 文档描述"组件内隐式共享元素转场"，"组件内"是关键——它不是页面间转场 API
- **如果 `sharedTransition` 的图片拉伸效果不理想**，优化方向是 hero 占位策略 + 比例一致性 + 曲线/时长调优，而非替换 API

## Applicability Boundaries

- **适用**：HarmonyOS ArkUI（API 12+，`geometryTransition` 从 API 12 起可用）
- **适用**：`sharedTransition` 用于页面间转场（router push/pop），`geometryTransition` 用于组件内视图切换
- **不适用**：`geometryTransition` 不能用于 `router.pushUrl` / `router.back` 页面间转场——它需要 `animateTo` 上下文，router 转场不提供
- **不适用**：`sharedTransition` 不能用于同一页面内的组件切换——它是页面级转场 API
- **注意**：`geometryTransition` 配合 `transition` 使用以保证组件离场时不被立即析构，从而正常呈现共享元素转场动画
- **注意**：未来 HarmonyOS 版本可能增强 `geometryTransition` 对页面转场的支持，需关注版本变更

## Evidence or Examples

项目 HarmonyProject1 中的实际经历：

1. **尝试替换**：将 `PostCardMedia.ets`、`DailyPostDeck.ets`、`DetailHeroMedia.ets` 中的 `.sharedTransition(id, MotionShared.transition)` 替换为 `.geometryTransition(id)`，构建通过
2. **结果**：用户反馈"一镜到底的动画没了"——页面转场时没有任何共享元素飞行/拉伸效果，直接闪切
3. **查阅文档**：通过 `harmony-doc-view` 读取官方文档，确认 `geometryTransition` "必须配合 `animateTo` 使用才有动画效果"
4. **回退**：将所有 `.geometryTransition(id)` 回退为 `.sharedTransition(id, MotionShared.transition)`，恢复 `MotionShared` 导入，构建通过，动画恢复正常
5. **关键细节**：`GeometryTransitionOptions` 接口只有 `{ follow?: boolean }` 一个属性，不包含 `duration`/`curve`/`zIndex`；而 `sharedTransitionOptions` 包含 `{ duration, curve, zIndex }`——参数差异印证了两者设计场景的不同
