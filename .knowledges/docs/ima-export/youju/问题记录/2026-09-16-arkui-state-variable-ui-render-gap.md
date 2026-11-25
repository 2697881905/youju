---
title: "2026-09-16-arkui-state-variable-ui-render-gap.md"
id: markdown_798285c88467638f6a8dc28635ad6f33_1962f654a5b363079f5831fea2aca6067505655250320770
kb: 有据-YouJu
folder: "问题记录"
media_type: 7
tags: []
source: ima
exported_at: 2026-11-23T14:52:37.917Z
---
---
id: 2026-09-16-arkui-state-variable-ui-render-gap
title: ArkUI 状态变量定义与 build() 渲染分支遗漏模式
category: coding-pattern
nature: pitfall
created_at: 2026-09-16T00:02:01
updated_at: 2026-09-26T15:00:35
tags: [state-management, build-render, error-state, loading-state, harmonyos, arkui, three-state, EmptyState, Skeleton]
keywords: [@State error, build() 条件渲染, 状态变量遗漏, ChatPage error, UserProfilePage 静默catch, ProfilePage 自动重试, loading/error/empty 三态, 条件渲染分支缺失, EmptyState, Skeleton, LoadingProgress, 重试按钮, 骨架屏, catch块, safeShowToast]
problem_patterns: [state-variable-without-render-branch, silent-catch-swallow, error-state-invisible, 状态变量存在但build中无对应渲染分支, catch块仅toast无UI错误态, 空状态用Text替代EmptyState组件]
source_sessions: [ses_f5a5a3ed2ffeyaFWKEgDGNNa1A]
project: HarmonyProject1
severity: high
quality_score: 93
hit_count: 0
last_hit_at: null
low_quality_hit_count: 0
tier: S
related_experiences: [2026-09-16-arkui-ui-ux-interaction-audit-checklist, 2026-09-15-empty-catch-block-audit]
---

# ArkUI 状态变量定义与 build() 渲染分支遗漏模式

## Scenario

在 ArkUI 开发中，开发者经常在 `@State` 中定义了 `error`、`loading` 等状态变量并在异步方法中正确赋值，但在 `build()` 方法中却遗漏了对应的条件渲染分支。这导致用户在网络请求失败时看到空白页面或永久 loading，无法感知错误也无法触发重试。

## Key Signals

- 页面在网络请求失败后显示空白或永久 loading 状态
- `@State error: string = ''` 变量在 `catch` 块中被赋值，但 `build()` 中没有 `if (this.error)` 分支
- `catch` 块为空或仅 `console.error`，用户侧无任何反馈
- `loading` 状态变量在 `finally` 中被设为 `false`，但 `build()` 中 loading 分支之后没有 error 分支

## Essence

ArkUI 的 `build()` 方法是声明式 UI 的核心——**只有 `build()` 中有条件渲染分支的状态变量才会对用户可见**。在 `@State` 中定义变量并在异步方法中赋值是不够的，必须在 `build()` 中为每个有意义的状态变量提供对应的渲染分支。

三种常见遗漏模式：

1. **完全遗漏渲染分支**：`@State error` 有定义和赋值，但 `build()` 中只有 `loading` 和 `data` 两个分支，没有 `error` 分支
2. **静默 catch**：`catch` 块为空或仅 `console.error`，`error` 状态变量从未被赋值，用户看不到任何错误提示
3. **自动重试掩盖错误**：错误态有自动重试逻辑，但非网络类错误（如 403、500）也会触发重试，用户看不到错误提示且重试无效

## Approach

1. **审查每个 @State 变量**：对页面中每个 `@State` 变量，确认它在 `build()` 中有对应的条件渲染分支
2. **三态渲染检查**：每个数据驱动页面在 `build()` 中应包含三个条件分支：`loading` → `error` → `data/empty`
3. **catch 块审查**：所有 `catch` 块必须将错误信息赋值给 `@State error` 变量，不能为空或仅 `console.error`
4. **重试按钮**：`error` 渲染分支中必须包含重试按钮（调用 `load()` 或 `refresh()` 方法）
5. **自动重试边界**：自动重试仅适用于网络连接类错误，其他错误类型应展示错误信息让用户决定是否重试

### 正确的三态处理模式

```typescript
// 1. 空状态：使用统一的 EmptyState 组件（而非纯 Text）
if (this.list.length === 0 && this.ready) {
  EmptyState({
    icon: $r('app.media.empty_search'),
    title: '暂无内容',
    message: '这里还没有任何帖子',
    actionLabel: '刷新看看',
    onAction: () => { this.refresh(); }
  })
}

// 2. 加载状态：优先使用 Skeleton 骨架屏（而非仅 LoadingProgress）
if (this.loading && this.list.length === 0) {
  this.skeletonView()  // 首次加载用骨架屏
} else if (this.loading) {
  LoadingProgress().width(24).height(24)  // 非首次加载不替换已有内容
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

### 正确用法 vs 错误用法

```typescript
// ❌ 错误：error 变量有赋值但 build() 中无渲染分支
@State error: string = '';
async load() {
  try { /* ... */ }
  catch (e) { this.error = (e as Error).message; }
}
build() {
  if (this.loading) { /* loading UI */ }
  // 缺少 if (this.error) 分支！
  // 正常内容...
}

// ❌ 错误：catch 块仅 safeShowToast，页面无可见错误态
catch (e) {
  safeShowToast(this.getUIContext(), { message: '加载失败' });
  // 页面停留在空白或 loading 状态，无法重试
}

// ✅ 正确：三态完整渲染
build() {
  if (this.loading) { /* loading UI */ }
  if (this.error) {
    Column() {
      Text('加载失败：' + this.error)
      Button('重试').onClick(() => this.load())
    }
  }
  // 正常内容...
}
```

## Faster Next Time

- 在代码 review 中，对每个 `@State error` / `@State loading` 变量执行 `build()` 渲染分支检查
- 使用 `grep` 搜索 `@State error` 定义，然后确认每个定义在 `build()` 中有对应的 `if (this.error)` 分支
- 搜索空 `catch` 块（`catch (e) {}` 或 `catch {}`）——这些是静默吞错的信号
- **检查 catch 块内容**：`grep -A3 'catch' pages/*.ets` 查看 catch 块内容，如果只有 `safeShowToast` 而没有 `this.error = ...`，说明错误态 UI 缺失
- **EmptyState 使用率**：`grep -c 'EmptyState' pages/*.ets` 快速统计哪些页面用了、哪些没用
- ChatPage 类型的页面（消息/聊天）最容易遗漏 error 渲染分支，因为开发者倾向于只处理 loading 和 messages 两种状态
- **LoadingProgress 在非首次加载时不应替换已有内容**，应作为底部加载指示器或不显示

## Applicability Boundaries

- 适用于：所有包含异步数据加载的 ArkUI 页面
- 不适用于：纯静态页面（如关于页、隐私政策页）——这类页面无异步加载，不需要 error/loading 状态
- 注意：`@StorageLink` 变量也需要在 `build()` 中有对应的渲染处理，但这类变量通常不涉及 error 状态

## Evidence or Examples

HarmonyProject1 项目中发现 6 个页面存在此问题：

| 文件 | 问题类型 | 详情 |
|------|----------|------|
| ChatPage.ets | 完全遗漏渲染分支 | `@State error` 有定义和赋值，但 `build()` 中只有 loading 和 messages 两个分支 |
| UserProfilePage.ets | 静默 catch | `loadProfile` 的 `catch` 块为空，用户看不到任何错误提示 |
| ProfilePage.ets | 自动重试掩盖错误 | 错误态有自动重试，但非网络错误用户看不到提示 |
| ModerationPage.ets | 无重试按钮 | 错误态仅 `Text('加载失败：' + this.error)`，无重试按钮 |
| MyFollowPage.ets | 无重试按钮 | 错误态仅 `Text('加载失败：' + this.error)`，无重试按钮 |
| AccountBindingPage.ets | 仅 toast 提示 | 加载失败仅 `safeShowToast` 提示，页面无错误态展示和重试入口 |
