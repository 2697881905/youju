---
title: "2026-09-16-arkui-ui-ux-interaction-audit-checklist_260928020758.md"
id: markdown_798285c88467638f6a8dc28635ad6f33_49aaa043fe0b25547711af311e51bc5a7505655250320770
kb: 有据-YouJu
folder: "问题记录"
media_type: 7
tags: []
source: ima
exported_at: 2026-11-23T14:52:37.917Z
---
---
id: 2026-09-16-arkui-ui-ux-interaction-audit-checklist
title: HarmonyOS ArkUI 应用 UI/UX 交互完整性审查清单
category: workflow
nature: methodology
created_at: 2026-09-16T00:02:01
updated_at: 2026-09-26T15:00:35
tags: [ui-ux-audit, interaction-completeness, harmonyos, arkui, checklist]
keywords: [空状态, 加载状态, 错误状态, 下拉刷新, 返回按钮, Toast统一, 深色模式, 无障碍, 输入校验, 按压反馈, EmptyState, Skeleton, accessibilityText, maxLength, Refresh, BackButton, safeShowToast, stateStyles, Pressable]
problem_patterns: [interaction-state-missing, inconsistent-ui-pattern, accessibility-gap, UI交互缺失, 状态处理不完整, 交互反馈不一致]
source_sessions: [ses_f5a5a3ed2ffeyaFWKEgDGNNa1A]
project: HarmonyProject1
severity: high
quality_score: 94
hit_count: 1
last_hit_at: 2026-09-28T00:15:46
low_quality_hit_count: 0
tier: S
related_experiences: [2026-09-16-arkui-dark-mode-hardcoded-color-pitfall, 2026-09-16-arkui-input-maxlength-validation-gap, 2026-09-16-arkui-state-variable-ui-render-gap]
---

# HarmonyOS ArkUI 应用 UI/UX 交互完整性审查清单

## Scenario

在 HarmonyOS ArkUI 应用开发中，页面数量增长后容易出现交互状态处理不一致的问题。开发者在实现新页面时往往关注主流程（数据展示、核心操作），而忽略了边缘状态（空数据、加载中、错误、无障碍等）的系统性覆盖。当应用进入审核或用户测试阶段时，这些遗漏才被发现，修复成本高且容易遗漏。

## Key Signals

以下信号表明 UI/UX 交互完整性存在问题：
- 页面数据为空时显示空白或仅一行纯文本，无图标无引导
- 数据加载中仅显示 `LoadingProgress` 圆圈，无骨架屏占位
- 网络请求失败后页面无错误提示或重试入口
- 列表页无下拉刷新或上拉加载更多
- 非首页缺少返回按钮
- Toast 调用未统一走 `safeShowToast` 封装
- 深色模式下部分页面颜色不可见（硬编码颜色值）
- 交互元素无 `accessibilityText`，屏幕阅读器无法识别
- 输入框无 `maxLength` 限制
- 列表项点击无按压反馈（`stateStyles` 或 `Pressable`）

## Essence

UI/UX 交互完整性审查应覆盖 10 个维度，每个维度都有明确的检查方法和常见遗漏模式。核心原则是：**每个数据驱动的页面都必须完整处理 空态/加载态/错误态 三种状态，每个交互元素都必须有反馈和可访问性**。

## Approach

### 审查前准备

1. 用 `glob` 列出所有页面文件（`pages/*.ets`）和组件文件（`components/*.ets`）
2. 用 `grep` 预扫描关键 API 使用情况，快速定位缺失项

### 10 维度审查清单

| # | 维度 | 检查方法 | 常见缺失 |
|---|------|----------|----------|
| 1 | 空状态处理 | `grep EmptyState` 找到使用的页面，对比未使用的列表页 | 列表页用纯 `Text` 替代 `EmptyState` 组件 |
| 2 | 加载状态处理 | `grep Skeleton` 检查骨架屏使用；`grep LoadingProgress` 检查加载指示器 | 仅用 `LoadingProgress` 圆圈，无骨架屏占位 |
| 3 | 错误状态处理 | 检查 `catch` 块是否有 UI 渲染分支；检查 build() 中是否有 `error` 条件分支 | `catch` 块仅 `safeShowToast`，页面无错误态展示和重试入口 |
| 4 | 下拉刷新 | `grep Refresh` 检查哪些列表页有 `Refresh` 组件包裹 | 列表页 `List` 直接渲染，无 `Refresh` 包裹 |
| 5 | 返回按钮 | 检查每个非首页 `@Entry` 页面是否有 `BackButton` 组件 | 页面依赖自定义顶栏返回，无统一 `BackButton` |
| 6 | Toast 统一 | `grep showToast` 找到直接调用点，确认是否都通过 `safeShowToast` | 直接调用 `getUIContext().getPromptAction().showToast()` |
| 7 | 深色模式 | `grep '#[0-9A-Fa-f]'` 搜索硬编码颜色值 | 页面内硬编码 `'#34C759'`、`'#FFFFFF'` 等颜色，深色模式不适配 |
| 8 | 无障碍 | `grep accessibilityText` 检查覆盖率 | 仅 `BackButton` 等少数组件有 `accessibilityText`，大部分交互元素缺失 |
| 9 | 输入校验 | `grep maxLength` 检查输入框限制；检查 `inputType` 使用 | 标题 `TextInput` 无 `maxLength`，聊天输入框无限制 |
| 10 | 按压反馈 | `grep Pressable` 和 `grep stateStyles` 检查列表项 | `ListItem` 内 `Row` 直接 `.onClick`，无 `Pressable` 或 `stateStyles` |

### 审查执行策略

1. 先用 `grep` 批量扫描，快速定位"有"和"没有"的页面
2. 对"没有"的页面逐个 `read` 确认具体缺失位置和行号
3. 按优先级排序：错误状态缺失 > 交互功能缺失 > 视觉一致性缺失
4. 10 个维度的 grep 互相独立，可以并行执行

## Faster Next Time

- 将 10 项检查清单纳入 PR review 流程，每次新增页面必须逐项确认
- **先 grep 后 read**：用 `grep` 批量扫描关键 API，5 分钟内即可定位所有缺失页面，再逐个 `read` 确认细节
- **按维度并行扫描**：10 个维度的 grep 互相独立，可以并行执行
- 优先检查 `@State error` 变量在 `build()` 中的渲染——这是最容易遗漏且用户影响最大的问题
- admin/管理类页面是重灾区（硬编码颜色、无 EmptyState、无骨架屏），应作为审查重点

## Applicability Boundaries

- 适用于：HarmonyOS ArkUI（ArkTS）应用的所有页面和组件
- 不适用于：纯静态页面（如关于页、隐私政策页）的空态/加载态/错误态检查（但仍需检查返回按钮和深色模式）
- 不适用于：非 ArkUI 框架的 HarmonyOS 应用（如 Java UI 框架）

## Evidence or Examples

在 HarmonyProject1 项目中审查 33 个页面文件后发现：

- **7 个页面**空状态未使用 `EmptyState` 组件（MyFollowPage、BookmarkFolderPage、BookmarkFolderDetailPage、TrashBoxPage、DraftBoxPage、ModerationPage、AccountBindingPage）
- **15 个页面**加载状态仅用 `LoadingProgress`，仅 `SearchResultPage` 使用了 `Skeleton` 骨架屏
- **6 个页面**错误状态无重试按钮或错误提示不可见（ModerationPage、MyFollowPage、AccountBindingPage、ChatPage、UserProfilePage、ProfilePage）
- **9 个列表页**缺少 `Refresh` 下拉刷新
- **4 个页面**返回按钮使用自定义组件而非统一 `BackButton`
- **1 处** `showToast` 未走 `safeShowToast`（DetailPostContent.ets:100）
- **18+ 处**硬编码颜色值分布在 ReportAdminPage、ModerationPage、Index、PublishPreviewPage、BlocklistPage、MyFollowPage
- **全项目仅 13 处** `accessibilityText`，绝大多数交互元素缺失
- **6 处** `TextInput`/`TextArea` 无 `maxLength`（3 个发布页标题、VideoPublishPage 内容、ChatPage 输入框、ModerationPage 驳回理由）
- **12+ 个列表页**列表项点击无按压反馈效果
