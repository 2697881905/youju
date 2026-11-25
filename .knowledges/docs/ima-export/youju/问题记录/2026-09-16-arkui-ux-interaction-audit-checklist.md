---
title: "2026-09-16-arkui-ux-interaction-audit-checklist.md"
id: markdown_798285c88467638f6a8dc28635ad6f33_eec00e2e85a26fe8af0332f5ff161ddc7505655250320770
kb: 有据-YouJu
folder: "问题记录"
media_type: 7
tags: []
source: ima
exported_at: 2026-11-23T14:52:37.917Z
---
---
id: 2026-09-16-arkui-ux-interaction-audit-checklist
title: ArkUI 项目 UI/UX 交互完整性审查清单（10 维度）
category: workflow
nature: methodology
created_at: 2026-09-16T01:23:33
updated_at: 2026-09-26T15:00:35
tags: [ArkUI, UI审查, 交互完整性, 审查清单, HarmonyOS]
keywords: [ArkUI, UI/UX审查, 交互完整性, 空状态, 加载状态, 错误状态, 下拉刷新, 返回按钮, Toast, 深色模式, 无障碍, 输入校验, 按压反馈, EmptyState, Skeleton, safeShowToast, accessibilityText, Refresh, BackButton, maxLength, stateStyles]
problem_patterns: [UI交互缺失, 状态处理不完整, 交互反馈不一致]
source_sessions: [ses_f5a5a3ed2ffeyaFWKEgDGNNa1A]
project: HarmonyProject1
severity: medium
quality_score: 87
hit_count: 0
last_hit_at: null
low_quality_hit_count: 0
tier: S
related_experiences: [2026-09-16-arkui-ui-ux-interaction-audit-checklist]
---

> **归档说明**：此文件已合并入 `2026-09-16-arkui-ui-ux-interaction-audit-checklist.md`（主文件），因两者来自同一 session、覆盖同一 10 维度审查清单，相似度 ≥ 0.91。主文件 quality_score 更高（93→94），evidence 更全面，已合并表格格式和并行扫描策略。归档于 2026-09-26T15:00:35。

# ArkUI 项目 UI/UX 交互完整性审查清单（10 维度）

## Scenario

在 HarmonyOS ArkUI 项目开发中，页面数量增长后容易出现交互完整性缺失：某些页面有空状态处理，某些没有；部分页面接入了下拉刷新，部分没有。这种不一致性在功能测试中不易暴露，但在审核和用户实际使用中会被发现。需要一个系统化的审查清单来确保所有页面的交互完整性。

适用场景：项目功能基本完成后、提交审核前、或定期质量检查时。

## Key Signals

触发审查的信号：
1. 审核反馈指出某些页面缺少空状态或错误处理
2. 用户报告"页面白屏"或"卡在加载中"的问题
3. 深色模式下某些页面出现不可读的颜色
4. 不同页面的交互行为不一致（有的有下拉刷新，有的没有）

## Essence

ArkUI 项目的交互完整性可以通过 10 个维度系统化审查，每个维度都有明确的检查标准和常见缺失模式。使用 `explore` subagent 配合 `glob`/`read`/`grep` 工具可以高效完成全项目审查。

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

## Faster Next Time

- **先 grep 后 read**：用 `grep` 批量扫描关键 API（`EmptyState`、`Skeleton`、`Refresh`、`BackButton`、`safeShowToast`、`accessibilityText`、`maxLength`、`Pressable`、`stateStyles`），5 分钟内即可定位所有缺失页面，再逐个 `read` 确认细节
- **按维度并行扫描**：10 个维度的 grep 互相独立，可以并行执行
- **关注 build() 分支完整性**：对于有 `@State error` 或 `@State loading` 的页面，必须检查 build() 中是否有对应的条件渲染分支，而非仅检查状态变量是否存在
- **硬编码颜色检测**：用 `grep -n '#[0-9A-Fa-f]\{6\}'` 可以快速找到所有硬编码颜色

## Applicability Boundaries

- **适用**：HarmonyOS ArkUI（ArkTS）项目，页面数 ≥ 5 的中小型项目
- **不适用**：纯静态页面（无数据加载）的项目；非 ArkUI 框架的项目
- **限制**：此清单覆盖交互完整性，不覆盖性能优化、安全审查或功能正确性

## Evidence or Examples

在 HarmonyProject1 项目（约 30 个页面）的审查中发现：
- 6 个页面空状态未使用 `EmptyState` 组件
- 仅 1 个页面（SearchResultPage）使用了 `Skeleton` 骨架屏，其他 15 个列表页仅用 `LoadingProgress`
- 6 个页面错误状态缺少重试按钮
- 9 个列表页缺少 `Refresh` 下拉刷新
- 1 处直接调用 `showToast` 未使用 `safeShowToast`（DetailPostContent.ets:100）
- ReportAdminPage 和 ModerationPage 有大量硬编码颜色值（`'#34C759'`、`'#FFE5E5'`、`'#FFFFFF'` 等）
- 全项目仅 13 处 `accessibilityText`，绝大多数交互元素缺失无障碍属性
- 3 个发布页的标题 `TextInput` 无 `maxLength` 限制
