---
title: "gsap-level-interaction-animations.md"
id: markdown_798285c88467638f6a8dc28635ad6f33_42aad4898280c58fc78e04bbb21cf2bb7505655250320770
kb: 有据-YouJu
folder: "开发文档"
media_type: 7
tags: []
source: ima
exported_at: 2026-11-23T14:52:37.917Z
---
# 「有据」GSAP 级交互动画改造计划

## 摘要

在鸿蒙 ArkUI 原生动画体系内，为社交 App「有据」实现 GSAP 级别的交互动画手感，覆盖四个核心场景：

- **场景A 内容卡片流**：首屏卡片流错位入场（Stagger）、每日一帖堆叠卡片的跟手/离手弹性升级
- **场景B 点赞/收藏反馈**：图标弹性缩放脉冲（弹性弹跳 + 往返 Yoyo）
- **场景C 列表增删**：收藏夹/草稿箱/废纸篓列表项的出现/消失过渡
- **场景D 页面转场**：详情页「共享动势 + 分层进入」转场

已与用户确认两项关键决策：
1. **跨页转场**：项目所有页面均为 `router.pushUrl`（无 Navigation），geometryTransition 跨页不可用 → 采用「共享动势 + 分层进入」方案，保持路由与导航逻辑零改动。
2. **飘心效果**：不纳入，仅做弹性缩放脉冲，零 UI 结构改动。

---

## 一、现状分析（基于代码勘察）

### 导航与转场现状
- 所有页面跳转一律 `this.getUIContext().getRouter().pushUrl(...)`，参数经 [nav.ts](file:///Users/itxiaobai/HarmonyProject1/entry/src/main/ets/utils/nav.ts) 进程内意图传递（如 `openPostDetail` / `takePostDetailId`）。
- 全局页面转场仅 [styles.ets](file:///Users/itxiaobai/HarmonyProject1/entry/src/main/ets/utils/styles.ets) 的 `buildPageTransition()`：OPACITY + translate x 12，已被 15 个页面复用（含 `DetailPage`，见 [DetailPage.ets L1165](file:///Users/itxiaobai/HarmonyProject1/entry/src/main/ets/pages/DetailPage.ets#L1165)）。
- 全项目**无** `geometryTransition`、`chainAnimation`、`springMotion/responsiveSpringMotion`、`expectedFrameRateRange` 使用先例。

### 动效基础设施
- [motion.ets](file:///Users/itxiaobai/HarmonyProject1/entry/src/main/ets/design/tokens/motion.ets)：`MotionTokens`（时长/缩放参数）+ `MotionCurves`（全部为 cubic-bezier）。
- [Pressable.ets](file:///Users/itxiaobai/HarmonyProject1/entry/src/main/ets/design/motion/Pressable.ets)：通用按压反馈（stateStyles 透明度 + 缩放 0.97），已被卡片、按钮广泛复用。
- [CountRoll.ets](file:///Users/itxiaobai/HarmonyProject1/entry/src/main/ets/design/motion/CountRoll.ets)：数字滚动（内部已有 `getUIContext().animateTo`）。
- [DailyPostDeck.ets](file:///Users/itxiaobai/HarmonyProject1/entry/src/main/ets/components/DailyPostDeck.ets)：「每日一帖」堆叠卡片已实现 Stack + 索引深度计算 scale/opacity/translate + 拖拽/飞出/复位动画（3 处 `getUIContext().animateTo`，曲线均为三次贝塞尔）。**这正是场景A「卡片堆叠滑动」的现成载体**。

### 四个场景的具体落点
| 场景 | 落点 | 现状 |
|---|---|---|
| A 卡片流 | [HomeTab.ets](file:///Users/itxiaobai/HarmonyProject1/entry/src/main/ets/components/HomeTab.ets) `feedScroll()` L419-470（Scroll + 偶/奇双列 ForEach 渲染 PostCard），`feedPost()` builder L393-412 | 无任何入场动画 |
| A 堆叠卡 | DailyPostDeck.ets | 已有拖拽/飞出/回弹，曲线未用 springMotion |
| B 点赞 | [StatRow.ets](file:///Users/itxiaobai/HarmonyProject1/entry/src/main/ets/design/components/StatRow.ets)（信息流卡片点赞钮）；[DetailActionBar.ets](file:///Users/itxiaobai/HarmonyProject1/entry/src/main/ets/components/DetailActionBar.ets) `DetailActionButton` `onFeedbackChanged` L37-49 | StatRow 无缩放反馈；DetailActionButton 已有 `confirmationScale=1.045` 脉冲（隐式 .animation + spring 贝塞尔），可升级为 springMotion |
| C 列表增删 | [TrashBoxPage.ets](file:///Users/itxiaobai/HarmonyProject1/entry/src/main/ets/pages/TrashBoxPage.ets#L253-L267) / [DraftBoxPage.ets](file:///Users/itxiaobai/HarmonyProject1/entry/src/main/ets/pages/DraftBoxPage.ets#L167-L181) / [BookmarkFolderPage.ets](file:///Users/itxiaobai/HarmonyProject1/entry/src/main/ets/pages/BookmarkFolderPage.ets#L203) 均为 Grid + ForEach，**key 稳定**（post.id / draft.id） | 无出现/消失过渡（稳定 key 保证删除时只为被删项单独播放退场，不抖动整表） |
| D 详情页转场 | DetailPage.ets build 尾部 L1060-1166：媒体区（VideoPlayer / DetailMediaCarousel 分支 L1070-1088）、DetailPostContent L1090、DetailCommentsSection L1102、DetailActionBar L1133 | 仅根节点 `buildPageTransition()`，无分层 |

---

## 二、修改范围约束（严格遵循）

- **允许**：动画调用（`animateTo` / `animation` / `transition` / `playMode` / `expectedFrameRateRange`）、动画曲线参数、`anim*` 前缀的动画专用 `@State`、动画直接用到的 transform/opacity 样式、动画触发条件（仅 UI 交互）。
- **禁止**：一切业务/后端/服务层代码；组件树层级与布局结构；非动画样式与文案；路由与导航逻辑；文件新增/删除/重命名。
- 新动画专用变量一律以 `anim` 开头；`motion.ets` 仅做**增补**（新增导出），不改动既有 token 取值。

---

## 三、逐文件修改方案

### 1. `entry/src/main/ets/design/tokens/motion.ets`（增补，不改既有值）

**为什么**：全项目首次引入 springMotion 与帧率适配，需要统一预设，避免各组件写出手感不一致的散乱参数（对应「曲线」分层与交互归一原则）。

**改什么**：
```ts
// 追加到 MotionCurves —— GSAP 级弹性预设（cubic-bezier 之外的 springMotion 系列）
static readonly springInteract: ICurve = curves.springMotion(0.6, 0.85);   // 柔和弹性（点赞按钮通用）
static readonly springBounce: ICurve = curves.springMotion(0.4, 0.7);     // 明显回弹（成功脉冲）
static readonly springRelease: ICurve = curves.springMotion(0.5, 0.75);   // 离手回稳/飞出

// 追加：60/120Hz 适配
export class MotionFrameRates {
  static readonly default: ExpectedFrameRateRange = { min: 30, max: 120, expected: 60 };
}
```

### 2. `entry/src/main/ets/components/HomeTab.ets`（场景A：卡片流错位入场）

**为什么**：`feedScroll()` 是 Scroll 而非 List，`chainAnimation` 不适用 → 按规格「手动通过索引计算延迟」实现 Stagger。

**改什么**：
- `feedPost()` builder 增加索引形参（`feedPost(post: Post, idx: number)`），双列 ForEach 处传入该项在其分列内的下标。
- 在 PostCard 调用链上追加过渡（仅动画代码，不动卡片内部结构）：
```ts
.transition(
  TransitionEffect.OPACITY
    .animation({ duration: MotionTokens.slow, curve: MotionCurves.decelerate,
                 delay: Math.min(idx, 6) * MotionTokens.stagger })
    .combine(TransitionEffect.translate({ y: 14 })
      .animation({ duration: MotionTokens.slow, curve: MotionCurves.decelerate,
                   delay: Math.min(idx, 6) * MotionTokens.stagger }))
)
```
- 说明：ForEach key 稳定（`feed-even-{id}`），首屏加载逐项滑入；切换流/标签时仅新增项入场，旧项不重复动画；错位上限截断至 6 项（6×40=240ms），避免末屏项累积延迟。

### 3. `entry/src/main/ets/design/components/StatRow.ets`（场景B：点赞弹性脉冲）

**为什么**：信息流卡片点赞目前数字会滚动（CountRoll）但图标无反馈；补上 GSAP 式「弹性缩放到 1.045 → 弹回」的 Yoyo 脉冲。

**改什么**（全部新增，不动既有布局）：
- 新增 `@State animLikePulse: number = 1;`
- `liked` 改为 `@Prop @Watch('onLikedChanged') liked: boolean`（@Prop + @Watch 在 V1 合法）。
- 新增 `onLikedChanged()`：`reduceMotion` 或 `liked=false` 时不触发；否则用**往返播放（Yoyo）**一次闸内完成缩进→弹出：
```ts
private onLikedChanged(): void {
  if (!this.liked || this.reduceMotion()) { return; }
  this.getUIContext().animateTo({
    duration: MotionTokens.base,
    curve: MotionCurves.springBounce,          // 明显回弹
    playMode: PlayMode.Alternate,              // 往返播放（GSAP Yoyo 映射）
    iterations: 2,                             // 1 → 1.045 → 1
    expectedFrameRateRange: MotionFrameRates.default,
  }, () => { this.animLikePulse = MotionTokens.successScale; });
}
```
- 点赞图标 Image 加 `.scale({ x: this.animLikePulse, y: this.animLikePulse })`（transform-only 属性 ✓）。
- 新增 `@StorageLink('reduceMotion')` / `@StorageLink('systemReduceMotion')` 守卫（与 DetailActionButton 同款）。

### 4. `entry/src/main/ets/components/DetailActionBar.ets`（场景B：详情页反馈升级）

**为什么**：`DetailActionButton.onFeedbackChanged` 已有脉冲，但曲线为贝塞尔且未做帧率适配；将其对齐 springMotion 预设，手感与信息流一致。

**改什么**：
- 隐式 `.animation()`（L75-78）的 `curve: MotionCurves.spring` → `curve: MotionCurves.springBounce`（springMotion），并补 `expectedFrameRateRange: MotionFrameRates.default`。
- `confirmationScale` 复位改为同样走隐式动画（动画参数由上述 .animation 统一接管），保持现有 setTimeout 复位节奏（`MotionTokens.control`），**不改动触发时机与业务回调**。

### 5. `entry/src/main/ets/pages/DetailPage.ets`（场景D：共享动势 + 分层进入）

**为什么**：router 跨页无法共享元素，按已确认方案用「共享动势」替代——媒体区以与卡片同感的缩放起步，标题/正文/评论区延迟错峰进入，形成分层叙事（呼应「跨层转场 + 错峰」）。

**改什么**（每处仅追加 `.transition(...)`，保持根节点 `buildPageTransition()` 不变）：
- 媒体区（VideoPlayer 分支与 DetailMediaCarousel 分支，L1070-1088）：缩放 + 淡入，无延迟（先到）：
```ts
.transition(
  TransitionEffect.OPACITY
    .animation({ duration: MotionTokens.slow, curve: MotionCurves.decelerate })
    .combine(TransitionEffect.scale({ x: 0.975, y: 0.975 })
      .animation({ duration: MotionTokens.slow, curve: MotionCurves.decelerate }))
)
```
- `DetailPostContent`（L1090）：OPACITY + translate y 10，延迟 100ms。
- `DetailCommentsSection`（L1102）：同上延迟 160ms。
- `DetailActionBar`（L1133）：同上延迟 100ms。

### 6. `pages/TrashBoxPage.ets` / `pages/DraftBoxPage.ets` / `pages/BookmarkFolderPage.ets`（场景C：列表增删过渡）

**为什么**：Grid + ForEach 且 key 稳定（post.id / draft.id / folder id），给项根节点加 `.transition()` 即自动获得「该被删项淡出上移、新项淡入」的过渡；因 key 稳定，`reload()` 整体替换数组**不会**触发全表重播。

**改什么**：三处 `GridItem()` 内的卡片/条目根节点各追加（延迟 0，保证删除立即触发）：
```ts
.transition(
  TransitionEffect.OPACITY
    .animation({ duration: MotionTokens.slow, curve: MotionCurves.decelerate })
    .combine(TransitionEffect.translate({ y: 16 })
      .animation({ duration: MotionTokens.slow, curve: MotionCurves.decelerate }))
)
```

### 7. `entry/src/main/ets/components/DailyPostDeck.ets`（场景A：堆叠卡离手弹性）

**为什么**：该组件已是「Stack + 动态 scale/opacity/translate + 拖拽」的规格载体；按规格将离手回稳/飞出对齐 springMotion，并全局补帧率适配。

**改什么**（仅动动画参数）：
- `resetDrag()`（L113）：`MotionCurves.springSoft` → `MotionCurves.springRelease`（离手回弹，springMotion(0.5,0.75)）；补 `expectedFrameRateRange`。
- `advance()` 飞出段（L123）：保持 `accelerate` 曲线（飞出宜快出），补 `expectedFrameRateRange`。
- `advance()` 回稳段（L134）：`MotionCurves.springSoft` → `MotionCurves.springRelease`；补 `expectedFrameRateRange`。
- 拖拽跟手段（`onTopPanUpdate` 直接写 `dragOffsetX`）保持不动——直接跟随手指，天然"跟手"。

### 明确不做的事
- 不引入/不模拟 geometryTransition、WebView、Canvas 动画；不重构路由为 Navigation。
- `PostCard`、`Index`、`CircleTab`（星系 Canvas 区）、`buildPageTransition()` 均不修改。
- `likeStore` / `postDeletionStore` / `api` / `nav` 等服务与逻辑代码零接触。

---

## 四、假设与决策

| # | 决策 / 假设 | 依据 |
|---|---|---|
| 1 | 跨页用「共享动势 + 分层进入」，不用 geometryTransition | router 跨页不支持共享元素；已获用户确认 |
| 2 | 点赞反馈仅弹性缩放脉冲，不做飘心 | 已获用户确认 |
| 3 | HomeTab 的 `feedPost` builder 新增 `idx` 形参用于错位延迟 | 规格「手动通过索引计算延迟」；Scroll 无 chainAnimation |
| 4 | `TransitionEffect.animation({delay})` 的出现/消失共用延迟 | V1 简化处理；错位上限截断 ≤240ms，删除延迟可忽略 |
| 5 | `motion.ets` 仅增补 springMotion 预设与 `MotionFrameRates` | 保证参数一致性，零回归 |
| 6 | 列表页依赖稳定 ForEach key 保证单删项过渡 | 三个页面 key 均已稳定（id） |
| 7 | 全程无需业务层配合 | 所有触发均基于已有状态流（likeStore 广播、reload、路由 push） |

## 五、验证步骤

1. **构建**：项目根目录执行 `./hvigorw --mode module -p product=default assembleHap --no-daemon`，确认 `BUILD SUCCESSFUL`。
2. **真机/模拟器手测**：
   - 首页首刷：卡片逐项错位滑入；切流/切标签不重播旧卡；触底加载新卡同样错位。
   - 点赞：信息流卡片与详情页点赞钮「弹出→弹回」，数字滚动正常；快速连点时动画可打断、最终态正确。
   - 详情页：进入时媒体先到（缩放淡入），标题/正文/评论 100/160ms 延迟错峰淡入。
   - 废纸篓/草稿箱/收藏夹：删一项仅该项淡出，其余不动；新增项淡入。
   - 每日一帖：拖拽跟手、过阈值飞出/未过回弹，速度衔接无断层。
3. **自检清单**（规格逐条核对）：
   - [ ] 动画均由明确状态变化触发（posts 装载 / liked 翻转 / feedbackVersion / 删除）
   - [ ] 动画结束后业务状态与视觉一致（animation 收于终态 1；Yoyo 收于 1）
   - [ ] 快速连续操作可打断衔接（animateTo 自动接管）
   - [ ] 仅动 transform/opacity，未动布局属性
   - [ ] springMotion 参数均在推荐范围（0.4–0.6 / 0.7–0.85）
   - [ ] `anim*` 命名约束（新增变量仅 `animLikePulse`）
4. **交付声明**（实现完成后在回复末尾附上）：本次修改文件、修改代码块摘要、是否触碰业务/后端、是否需要业务层配合（预计：**否**）。
