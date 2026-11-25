---
title: "2026-09-15-harmonyos-shared-transition-pattern.md"
id: markdown_798285c88467638f6a8dc28635ad6f33_48f9c557cd1826952d5246f97baf65f07505655250320770
kb: 有据-YouJu
folder: "问题记录"
media_type: 7
tags: []
source: ima
exported_at: 2026-11-23T14:52:37.917Z
---
---
id: 2026-09-15-harmonyos-shared-transition-pattern
title: ArkUI sharedTransition 共享元素"一镜到底"转场实现模式
category: coding-pattern
nature: technique
created_at: 2026-09-15T16:03:04
updated_at: 2026-09-26T15:34:47
tags: [harmonyos, arkui, shared-transition, animation, hero-placeholder, 一镜到底]
keywords: [sharedTransition, sharedTransitionOptions, MotionShared, hero占位, 一镜到底, PostDetailIntent, MotionShared, 共享元素转场, ArkUI动画, emphasized曲线, standard曲线, hero animation, shared element transition, holdHero, buildFadePageTransition]
problem_patterns: [共享元素转场卡顿, 进入退出动画不流畅, 图片拉伸变形, disjoint-page-transition, no-visual-continuity, double-motion-conflict]
source_sessions: [ses_f5c28246bffewejiliAiNvfUL6, ses_f5c27a718ffeXtJJltNE8iMaPp]
project: HarmonyProject1
severity: high
quality_score: 88
hit_count: 3
last_hit_at: 2026-09-27T02:02:48
low_quality_hit_count: 0
tier: S
related_experiences: [2026-09-15-arkui-motion-design-token-system, 2026-09-15-arkui-transition-effect-staggered-enter, 2026-09-15-arkui-v1-plain-getter-dropped, 2026-09-26-geometrytransition-vs-sharedtransition-page-navigation]
---

# ArkUI sharedTransition 共享元素"一镜到底"转场实现模式

## Scenario

用户从列表/信息流点击一张卡片进入详情页时，如果页面切换是生硬的"闪切"（列表消失 → 详情页从零出现），视觉连续性被打断。用户需要重新定位"我在看哪张卡片的内容"。

"一镜到底"（hero animation / shared element transition）的目标是：列表中的卡片媒体区"飞"到详情页的媒体区位置并放大，让用户感知到内容是从卡片"展开"出来的，而非从一个新页面"出现"的。涉及源端（卡片）、意图传递、目标端（详情页）三层协调。

## Key Signals

- 列表 → 详情页切换时视觉断裂，用户无法感知内容来源
- 共享元素转场卡顿，图片尺寸变化和拉伸不够丝滑
- 进入和退出动画都不够流畅
- `emphasized` 曲线（cubicBezier 0.16, 1, 0.3, 1）前 16% 时间几乎不动，造成"卡顿起步"感
- 退出详情页时共享元素不逆飞，只是普通渐隐（缺少退出动画）
- 页面转场 duration（220ms）与共享元素 duration（420ms）不一致，造成割裂感
- 共享元素飞入后，内容区从 4:3 比例切换到真实比例时出现"二次缩放"的生硬感
- 共享元素飞行时整页同时平移，产生"双滑动"混乱感
- 返回列表时共享元素逆飞与页面转场叠加，动画不干净

## Essence

ArkUI 的 `.sharedTransition(id, options)` API 实现"一镜到底"的核心机制：源端和目标端挂载相同 id 的 `sharedTransition`，框架在页面 push/pop 时自动计算两个元素的位置/尺寸差并执行插值动画。

关键约束：

1. **共享 ID 匹配与唯一性**：源页面和目标页面的组件挂载相同的 `sharedTransition` id，ArkUI 框架自动计算两个组件的位置/尺寸差异并执行飞行动画。同一时间只有一对组件共享同一 id；列表中每张卡片用 `card-expand-{postId}` 确保唯一。
2. **比例一致性**：源端和目标端必须使用相同的宽高比（`aspectRatio`），否则飞行过程中图片会被拉伸/压缩。
3. **Hero 占位策略**：目标端数据加载完成前，需要用 intent 中携带的 cover URL 渲染一张与源卡同比的占位图（hero），让共享元素有正确的落点；数据到达后切换为真实内容。
4. **HERO_HOLD_MS > 转场 duration**：hero 占位时间必须大于共享转场时长，否则真实比例内容会在飞行途中接管，造成"先放大再缩小"的跳变。
5. **holdHero 机制——避免比例切换的二次缩放**：进入动画 + 转场窗口内快速返回的逆飞都走 hero（与源卡同比 → 无拉伸）；holdHero 结束后内容区用真实比例展示（无共享 id）→ 停留阅读后的返回是干净普通页面转场，避免 4:3↔真实比例的非等比插值拉伸。
6. **退出逆飞需要重新挂载 hero**：阅读停留后 holdHero 已释放，共享 id 不再挂在任何元素上；退出时需先重新设 holdHero=true 恢复共享 id，等一帧（16ms）让 hero 渲染完成后再 router.back()，框架才能检测到共享元素并执行逆飞。
7. **页面转场与共享元素协调**：共享元素路径的页面级转场必须改为纯渐显（无位移），避免"整页滑动 × 卡面放大"双动效打架；duration 应与共享元素 duration 对齐。
8. **飞行参数统一**：通过 `MotionShared.transition` 集中定义 duration/curve/zIndex。

## Approach

### 步骤 1：定义共享转场参数

```typescript
export class MotionShared {
  static readonly transition: sharedTransitionOptions = {
    duration: MotionTokens.page,           // 420ms
    curve: MotionCurves.emphasized,        // cubicBezierCurve(0.16, 1, 0.3, 1)
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
    .aspectRatio(LayoutTokens.cardMediaAspectRatio)  // 3:4 = 0.75
    .objectFit(ImageFit.Cover)
    .sharedTransition(this.sharedId, MotionShared.transition)  // 挂载共享 id
}
// sharedId 由 PostCard 注入：'card-expand-{postId}'，空串 = 纯文字卡不挂
```

仅在有封面图且 id 可解析时挂载。

### 步骤 3：意图传递

通过模块级变量传递 `PostDetailIntent`（包含 cover URL、aspect 比例、isVideo 标志），避免 router params 在 API 24 不稳定。

```typescript
// nav.ts
export interface PostDetailIntent {
  cover: string;
  aspect: number;
  isVideo: boolean;
}
export function openPostDetail(id: string, intent: PostDetailIntent): void { ... }
export function takePostDetailIntent(): PostDetailIntent | null { ... }
```

### 步骤 4：目标端（详情页）挂载同比 hero

```typescript
// DetailHeroMedia.ets
build() {
  if (this.sharedId.length > 0) {
    Stack() {
      this.heroFace() // 与源卡同比的 Image
    }
    .sharedTransition(this.sharedId, MotionShared.transition)
  } else {
    this.heroFace()
  }
}
```

详情页 `aboutToAppear` 时 `takePostDetailIntent()` 读取并清除意图。

### 步骤 5：共享 id 计算

目标端 `sharedId()` 方法返回 `'card-expand-' + postId`，与源端格式一致；视频帖和纯文字卡返回空串（不启用共享）。

> **注意**：`sharedId()` 必须写成普通方法而非 getter——ArkUI V1 编译器会丢弃组件上未绑定 @State/@Prop 的 plain getter，导致运行时 `this.sharedId` 为 `undefined` 直接崩溃。详见 [arkui-v1-plain-getter-dropped] 经验。

### 步骤 6：区分共享/非共享路径的页面转场

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

### 步骤 7：退出逆飞

自定义 `navigateBack()` 方法，退出前重新设 `holdHero = true`，延迟 16ms 后 `router.back()`：

```typescript
private navigateBack(): void {
  if (this.sharedId().length > 0 && !this.holdHero) {
    this.holdHero = true;
    setTimeout((): void => {
      this.getUIContext().getRouter().back();
    }, 16);
  } else {
    this.getUIContext().getRouter().back();
  }
}
```

### 步骤 8：曲线选择

用 `standard`（cubicBezier 0.2, 0.8, 0.2, 1）替代 `emphasized`，缓入缓出中间快，飞行全程匀速感最强。`emphasized` 适合静止→运动→静止场景（入场），持续运动场景用 `standard`。

## Faster Next Time

- **共享 id 命名规范**：使用 `card-expand-{postId}` 格式，确保列表中每张卡片 id 唯一
- **纯文字卡不挂共享 id**：只有有媒体区的卡片才挂 `sharedTransition`，纯文字卡用 `sharedId = ''` 跳过
- **共享元素路径页面转场必须改为纯渐显**：这是最容易遗漏的约束——如果页面同时平移和飞行，视觉效果会非常混乱
- **共享元素转场 duration 与页面转场 duration 必须对齐**（差值不超过 60ms），否则会有割裂感
- **`emphasized` 曲线不适合持续运动场景**（飞行），适合静止→运动→静止场景（入场）；持续运动用 `standard`
- **退出时如果不重新挂载 hero，共享元素无法逆飞**——这是最容易遗漏的环节
- **HERO_HOLD_MS 设为转场 duration + 80ms 缓冲即可**，过长会增加等待感
- **视频帖不做共享转场**：卡面为裁切比例（3:4 或 4:3），视频真实比例不同，共享受扭/拉伸
- **页面转场用 `buildFadePageTransition()`**（纯渐显 + delay 60ms），让共享元素先启动飞行，页面背景随后跟上
- **holdHero 时机**：共享元素飞行完成后（约 duration + 100ms 缓冲），切换为真实比例内容区并移除共享 id
- **返回时不需要共享元素逆飞**：如果用户在详情页停留超过 holdHero 时间，返回时走普通页面转场即可，不需要逆飞
- **`sharedTransition` 的 id 在页面栈中必须唯一**——如果同一 postId 的卡片同时出现在两个页面（如首页和个人页），需要确保只有一个页面的组件挂载了该 id

## Applicability Boundaries

- **适用**：列表 → 详情页的场景，源端和目标端有视觉对应的媒体区
- **适用**：源端和目标端的媒体区宽高比相同（如同为 3:4 或同为 4:3）
- **适用**：HarmonyOS ArkUI V1（`@Component struct` 模式），V2 的 `@ComponentV2` 可能行为不同
- **不适用**：源端和目标端宽高比差异大（如列表 3:4 → 详情页 16:9），非等比插值会产生拉伸变形
- **不适用**：视频帖（裁切比例与真实比例不一致）
- **不适用**：纯文字卡（无封面图）不挂共享 id，走普通转场
- **不适用**：快速浏览场景（用户快速滑动列表点入又返回），holdHero 机制会增加复杂度
- **注意**：`sharedTransition` 的 id 在同一页面内必须唯一，卡堆下层卡和飞行卡不能与顶卡共享同一 id
- **注意**：意图传递用模块级变量（非 router params），因为 `router.getParams()` 在 API 24 不稳定

## Evidence or Examples

项目 HarmonyProject1 中的实现：

- **源端**：`PostCardMedia.ets` 的 `coverFaceShared` Builder 挂载 `sharedTransition`，由 PostCard 通过 `sharedId` prop 控制是否启用
- **意图**：`nav.ts` 的 `PostDetailIntent` 接口 + `openPostDetail(id, intent)` / `takePostDetailIntent()`
- **目标端**：`DetailHeroMedia.ets` 接收 sharedId + `DetailPage.ets` 的 hero 占位策略
- **转场参数**：`motion.ets` 的 `MotionShared.transition = { duration: 380ms, curve: standard, zIndex: 45 }`
- **页面转场**：`styles.ets` 的 `buildFadePageTransition()` = `OPACITY + delay 60ms + duration 380ms`
- **退出逆飞**：`DetailPage.ets` 的 `navigateBack()` 方法
- **卡堆场景**：`DailyPostDeck.ets` 中 `DeckSlotCard` 仅顶卡（depth=0）挂载 sharedId
- **`pageEnterTransition()`**：根据 `sharedId()` 是否为空选择不同转场策略（共享路径纯渐显 vs 非共享路径渐显+微缩放）
