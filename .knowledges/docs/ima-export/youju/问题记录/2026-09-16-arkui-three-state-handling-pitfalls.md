---
title: "2026-09-16-arkui-three-state-handling-pitfalls.md"
id: markdown_798285c88467638f6a8dc28635ad6f33_623c660adbb5d14b08a6d78c32a8658f7505655250320770
kb: 有据-YouJu
folder: "问题记录"
media_type: 7
tags: []
source: ima
exported_at: 2026-11-23T15:08:19.508Z
---
---
id: 2026-09-16-arkui-three-state-handling-pitfalls
title: ArkUI 三态处理（空/加载/错误）常见缺失模式与修复
category: coding-pattern
nature: pitfall
created_at: 2026-09-16T01:23:33
updated_at: 2026-09-26T15:00:35
tags: [ArkUI, 三态处理, 空状态, 加载状态, 错误状态, EmptyState, Skeleton]
keywords: [ArkUI, 三态处理, EmptyState, Skeleton, LoadingProgress, 错误状态, 重试按钮, 空数据, 加载中, 骨架屏, build分支, catch块, safeShowToast]
problem_patterns: [状态变量存在但build中无对应渲染分支, catch块仅toast无UI错误态, 空状态用Text替代EmptyState组件]
source_sessions: [ses_f5a5a3ed2ffeyaFWKEgDGNNa1A]
project: HarmonyProject1
severity: high
quality_score: 82
hit_count: 0
last_hit_at: null
low_quality_hit_count: 0
tier: A
related_experiences: [2026-09-16-arkui-state-variable-ui-render-gap]
---

> **归档说明**：此文件已合并入 `2026-09-16-arkui-state-variable-ui-render-gap.md`（主文件），因两者来自同一 session、覆盖同一状态变量与渲染分支遗漏问题，相似度 ≥ 0.76。主文件 quality_score 更高（92→93），tier S，已合并三态修复代码模式和 build() 分支完整性检查清单。归档于 2026-09-26T15:00:35。

# ArkUI 三态处理（空/加载/错误）常见缺失模式与修复

## Scenario

ArkUI 列表页或详情页在数据加载时需要处理三种状态：空状态（数据为空）、加载状态（数据加载中）、错误状态（加载失败）。这三种状态的处理直接影响用户体验，但在实际开发中最容易被忽略——开发者通常只关注"数据加载成功"的正常路径。

## Key Signals

三态处理缺失的典型信号：
1. **空状态**：列表页数据为空时显示空白或仅一行 `Text('暂无数据')`，无图标、无引导操作
2. **加载状态**：仅显示 `LoadingProgress` 圆圈，无骨架屏占位，用户不知道正在加载什么内容
3. **错误状态**：`@State error: string = ''` 变量存在，但 `build()` 中无对应的条件渲染分支；或 `catch` 块仅调用 `safeShowToast`，页面无可见的错误提示和重试按钮

## Essence

三态处理的核心问题不是"不知道要处理"，而是"以为已经处理了但实际没有"。具体表现为三种陷阱：

### 陷阱1：状态变量存在但 build() 中无渲染分支
开发者声明了 `@State error: string = ''`，在 `catch` 块中设置了 `this.error = ...`，但 `build()` 中只有 `loading` 和 `data` 两个条件分支，`error` 分支被遗漏。用户看到的是永久 loading 或空白。

### 陷阱2：catch 块仅 toast 无页面级错误态
`catch` 块中调用 `safeShowToast(this.getUIContext(), { message: ... })` 就认为错误处理完成了。但 toast 是瞬时的，用户如果没看到就消失了，页面停留在空白或 loading 状态，无法重试。

### 陷阱3：空状态用 Text 替代 EmptyState 组件
直接写 `Text('这里还什么都没有')` 而不使用项目统一的 `EmptyState` 组件，导致空状态没有图标、没有操作按钮、视觉风格不一致。

## Approach

### 正确的三态处理模式

```typescript
// 1. 空状态：使用统一的 EmptyState 组件
if (this.list.length === 0 && this.ready) {
  EmptyState({
    icon: $r('app.media.empty_search'),
    title: '暂无内容',
    message: '这里还没有任何帖子',
    actionLabel: '刷新看看',
    onAction: () => { this.refresh(); }
  })
}

// 2. 加载状态：优先使用 Skeleton 骨架屏
if (this.loading && this.list.length === 0) {
  // 首次加载用骨架屏
  this.skeletonView()
} else if (this.loading) {
  // 非首次加载用 LoadingProgress（不替换已有内容）
  LoadingProgress().width(24).height(24)
}

// 3. 错误状态：页面级错误展示 + 重试按钮
if (this.error.length > 0 && this.list.length === 0) {
  Column({ space: 16 }) {
    Text('加载失败：' + this.error)
      .fontColor(ColorTokens.danger)
    Button('重试')
      .onClick(() => { this.refresh(); })
  }
}
```

### build() 分支完整性检查
对每个有 `@State loading`、`@State error` 的页面，检查 build() 中是否包含：
1. `if (this.loading)` 分支 — 加载态
2. `if (this.error.length > 0)` 分支 — 错误态
3. `if (this.list.length === 0 && !this.loading && this.error.length === 0)` 分支 — 空态
4. 正常数据渲染分支

## Faster Next Time

- **grep 快速定位**：`grep -n '@State error' pages/*.ets` 找到所有声明了 error 状态的页面，再 `grep -n 'this.error' pages/*.ets` 检查 build() 中是否有对应渲染分支
- **检查 catch 块**：`grep -A3 'catch' pages/*.ets` 查看 catch 块内容，如果只有 `safeShowToast` 而没有 `this.error = ...`，说明错误态 UI 缺失
- **EmptyState 使用率**：`grep -c 'EmptyState' pages/*.ets` 快速统计哪些页面用了、哪些没用

## Applicability Boundaries

- **适用**：所有 ArkUI 列表页、详情页、设置页等有数据加载的页面
- **不适用**：纯静态页面（如 AboutPage、PrivacyPage）不需要三态处理
- **注意**：`LoadingProgress` 在非首次加载（已有数据）时不应替换已有内容，应作为底部加载指示器或不显示

## Evidence or Examples

在 HarmonyProject1 项目中发现的具体缺失：
- **ChatPage.ets**：`@State error` 变量存在（第108行设置），但 build() 中只有 loading 和 messages 两个分支，无 error 渲染分支——用户遇到错误时看到空白或永久 loading
- **ModerationPage.ets**：错误态仅 `Text('加载失败：' + this.error)`，无重试按钮（第404-412行）
- **UserProfilePage.ets**：`loadProfile` 失败时 `catch` 块为空（第154-160行），用户看不到任何错误提示
- **6 个页面**空状态未使用 `EmptyState` 组件：MyFollowPage、BookmarkFolderPage、BookmarkFolderDetailPage、TrashBoxPage、DraftBoxPage、ModerationPage
- **15 个页面**加载状态仅用 `LoadingProgress`，无 `Skeleton` 骨架屏（仅 SearchResultPage 使用了 Skeleton）
