---
title: "2026-09-15-arkui-shared-element-transition.md"
id: markdown_798285c88467638f6a8dc28635ad6f33_e7a98a65c6dea07c62111268ba117f737505655250320770
kb: 有据-YouJu
folder: "问题记录"
media_type: 7
tags: []
source: ima
exported_at: 2026-11-23T14:52:37.917Z
---
---
id: 2026-09-15-arkui-shared-element-transition
title: ArkUI 共享元素"一镜到底"转场实现模式
category: coding-pattern
nature: technique
created_at: 2026-09-15T15:08:04
updated_at: 2026-09-15T23:43:13
tags: [ArkUI, sharedTransition, shared-element, hero-animation, 一镜到底]
keywords: [sharedTransition, sharedTransitionOptions, MotionShared, hero, 一镜到底, 共享元素转场, PostCardMedia, DetailPage, ArkUI shared transition]
problem_patterns: [disjoint-page-transition, no-visual-continuity, double-motion-conflict]
source_sessions: [ses_f5c27a718ffeXtJJltNE8iMaPp]
project: HarmonyProject1
severity: medium
quality_score: 82
hit_count: 0
last_hit_at: null
low_quality_hit_count: 0
tier: A
related_experiences: [2026-09-15-harmonyos-shared-transition-pattern]
---

> **归档说明**：本文档已合并到 `2026-09-15-harmonyos-shared-transition-pattern`（主文件）中。两者描述同一共享元素转场模式，相似度 >= 0.75，主文件 quality_score 更高（88 vs 82）、tier 更高（S vs A）、且有检索命中记录。本文档的独特内容（MotionShared 定义、pageEnterTransition 区分逻辑、holdHero 机制解释、页面栈 id 唯一性约束）已全部并入主文件。

# ArkUI 共享元素"一镜到底"转场实现模式

## Scenario

用户从列表/信息流点击一张卡片进入详情页时，如果页面切换是生硬的"闪切"（列表消失 → 详情页从零出现），视觉连续性被打断。用户需要重新定位"我在看哪张卡片的内容"。

"一镜到底"（hero animation / shared element transition）的目标是：列表中的卡片媒体区"飞"到详情页的媒体区位置并放大，让用户感知到内容是从卡片"展开"出来的，而非从一个新页面"出现"的。

## Key Signals

- 列表 → 详情页切换时视觉断裂，用户无法感知内容来源
- 共享元素飞行时整页同时平移，产生"双滑动"混乱感
- 共享元素飞入后，内容区从 4:3 比例切换到真实比例时出现"二次缩放"的生硬感
- 返回列表时共享元素逆飞与页面转场叠加，动画不干净

## Essence

ArkUI 的 `.sharedTransition(id, options)` API 实现"一镜到底"的核心机制：

1. **共享 ID 匹配**：源页面和目标页面的组件挂载相同的 `sharedTransition` id，ArkUI 框架自动计算两个组件的位置/尺寸差异并执行飞行动画
2. **id 唯一性**：同一时间只有一对组件共享同一 id；列表中每张卡片用 `card-expand-{postId}` 确保唯一
3. **飞行参数统一**：通过 `MotionShared.transition` 集中定义 duration/curve/zIndex

关键设计约束：

- **共享 id 只挂在"loading / holdHero 期间的同比 hero"上**——进入动画 + 转场窗口内快速返回的逆飞都走 hero（与源卡同比 → 无拉伸）；holdHero 结束后内容区用真实比例展示（无共享 id）→ 停留阅读后的返回是干净普通页面转场，避免 4:3↔真实比例的非等比插值拉伸
- **共享元素路径的页面级转场必须改为纯渐显**——如果整页同时平移，共享元素的飞行会与页面平移"打架"

## Approach

### 步骤 1：定义共享转场参数

```typescript
export class MotionShared {
  static readonly transition: sharedTransitionOptions = {
    duration: 420,           // MotionTokens.page
    curve: MotionCurves.emphasized,  // cubicBezierCurve(0.16, 1, 0.3, 1)
    zIndex: 45,
  };
}
```

### 步骤 2：源端（列表卡片）挂载共享 id

```typescript
// PostCardMedia.ets - 信息流卡片媒体区
@Builder
coverFaceShared(url: string): void {
  Image(resolveDisplayImageUrl(url))
    .width('100%')
    .aspectRatio(LayoutTokens.cardMediaAspectRatio)  // 3:4
    .objectFit(ImageFit.Cover)
    .sharedTransition(this.sharedId, MotionShared.transition)  // 挂载共享 id
}

// sharedId 由 PostCard 注入：'card-expand-{postId}'，空串 = 纯文字卡不挂
```

### 步骤 3：目标端（详情页）挂载同比 hero

```typescript
// DetailPage.ets - 详情页 hero 媒体区
@Builder
videoFace(): void {
  Column() {
    VideoPlayer({ src: this.videoUrl, poster: this.videoCover })
  }
  .width('100%')
  .aspectRatio(this.videoAspect)  // 与源卡同比，避免非等比拉伸
  .sharedTransition(this.sharedId(), MotionShared.transition)  // 同一共享 id
}
```

### 步骤 4：区分共享/非共享路径的页面转场

```typescript
// 共享元素路径：纯渐显（无横向位移，避免与飞行打架）
export function buildFadePageTransition(): TransitionEffect {
  return TransitionEffect.OPACITY
    .animation({ duration: 220, curve: Curve.FastOutSlowIn });
}

// 详情页根据入口类型选择转场策略
private pageEnterTransition(): TransitionEffect {
  if (this.sharedId().length > 0) {
    return buildFadePageTransition();  // 共享路径：纯渐显
  }
  // 非共享路径：渐显 + 微缩放（模拟卡片展开感）
  return buildFadePageTransition()
    .combine(TransitionEffect.scale({ x: 0.985, y: 0.985 })
      .animation({ duration: 300, curve: MotionCurves.decelerate }));
}
```

### 步骤 5：holdHero 机制——避免比例切换的二次缩放

```typescript
// 进入动画 + 转场窗口内快速返回的逆飞都走 hero（与源卡同比 → 无拉伸）
// holdHero 结束后内容区切换为真实比例展示（videoFace / carouselFace，无共享 id）
// → 停留阅读后的返回是干净普通页面转场
```

## Faster Next Time

- **共享 id 命名规范**：使用 `card-expand-{postId}` 格式，确保列表中每张卡片 id 唯一
- **纯文字卡不挂共享 id**：只有有媒体区的卡片才挂 `sharedTransition`，纯文字卡用 `sharedId = ''` 跳过
- **共享元素路径页面转场必须改为纯渐显**：这是最容易遗漏的约束——如果页面同时平移和飞行，视觉效果会非常混乱
- **holdHero 时机**：共享元素飞行完成后（约 duration + 100ms 缓冲），切换为真实比例内容区并移除共享 id
- **返回时不需要共享元素逆飞**：如果用户在详情页停留超过 holdHero 时间，返回时走普通页面转场即可，不需要逆飞

## Applicability Boundaries

- **适用**：列表 → 详情页的场景，源端和目标端有视觉对应的媒体区
- **适用**：源端和目标端的媒体区宽高比相同（如同为 3:4 或同为 4:3）
- **不适用**：源端和目标端宽高比差异大（如列表 3:4 → 详情页 16:9），非等比插值会产生拉伸变形
- **不适用**：快速浏览场景（用户快速滑动列表点入又返回），holdHero 机制会增加复杂度
- **注意**：`sharedTransition` 的 id 在页面栈中必须唯一——如果同一 postId 的卡片同时出现在两个页面（如首页和个人页），需要确保只有一个页面的组件挂载了该 id

## Evidence or Examples

HarmonyProject1 项目中的实际应用：

- `PostCardMedia.ets`：定义了 `coverFace` 和 `coverFaceShared` 两个 Builder，后者追加 `.sharedTransition(this.sharedId, MotionShared.transition)`，由 PostCard 通过 `sharedId` prop 控制是否启用
- `DetailPage.ets`：`videoFace()` Builder 挂载 `.sharedTransition(this.sharedId(), MotionShared.transition)`，与列表卡片同比；`pageEnterTransition()` 方法根据 `sharedId()` 是否为空选择不同转场策略
- `styles.ets`：`buildFadePageTransition()` 专为共享元素路径设计——纯渐显无位移，避免与飞行打架
- `MotionShared`（在 `motion.ets` 中）：集中定义 `duration: 420ms, curve: emphasized, zIndex: 45`
