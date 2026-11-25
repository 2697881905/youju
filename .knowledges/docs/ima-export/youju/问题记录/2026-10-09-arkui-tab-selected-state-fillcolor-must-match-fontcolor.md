---
title: "2026-10-09-arkui-tab-selected-state-fillcolor-must-match-fontcolor.md"
id: markdown_cls1_798285c88467638f6a8dc28635ad6f33_a9d5fa4f33545b1edc5f6d5f886789f67505655250320770
kb: 有据-YouJu
folder: "问题记录"
media_type: 7
tags: []
source: ima
exported_at: 2026-11-23T14:52:37.917Z
---
---
id: 2026-10-09-arkui-tab-selected-state-fillcolor-must-match-fontcolor
title: ArkUI TabBar 选中态图标 fillColor 必须与文字 fontColor 共用同一条件表达式
category: coding-pattern
nature: pitfall
created_at: 2026-10-09T01:46:24
updated_at: 2026-10-09T01:46:24
tags: [harmonyos, arkui, fillcolor, tabbar, selected-state]
keywords: [fillColor, fontColor, 选中态, TabBar, BottomTabBar, tabBarBuilder, SVG图标, fillColor遗漏, 图标文字不一致, brand token]
problem_patterns: [tab-selected-state-fillcolor-copy-miss, dual-branch-tabbar-inconsistent-selected-state]
source_sessions: [ses_ee36905beffeeSftxx5Gy8IakE]
project: HarmonyProject1
severity: medium
quality_score: 89
hit_count: 0
last_hit_at: null
low_quality_hit_count: 0
tier: S
related_experiences: [2026-10-05-hmos-tab-component-selection-api-version-adaptation, 2026-09-16-arkui-dark-mode-hardcoded-color-pitfall]
---

# ArkUI TabBar 选中态图标 fillColor 必须与文字 fontColor 共用同一条件表达式

## Scenario

自定义底栏（自绘 `BottomTabBar`）或自定义 `tabBarBuilder` 页签中，Tab 项同时渲染图标（`Image` + `.fillColor()`）与文字（`Text` + `.fontColor()`），选中态通过 `currentIndex === index` 条件判断变色。典型触发条件：

- 用户反馈「切到某 Tab 后文字变蓝了，但图标还是白色（未选中色）」，同一 Tab 项图标与文字选中态不一致
- 底栏为双分支架构：API 23+ 真机走 `HdsTabs` + `tabBarBuilder`，API 20-22/模拟器走自绘 `BottomTabBar`，两处各自渲染图标
- 图标资源为 SVG（`fill="currentColor"`），`fillColor` 对其生效

## Key Signals

1. **静默失败**：无编译错误、无运行时异常，纯视觉不一致——只能靠真机/模拟器实测或截图发现
2. 代码层面：文字 `fontColor` 有 `currentIndex === index ? brand : icon` 条件判断，而图标 `fillColor` 在选中/未选中两个分支写成了**相同值**（复制粘贴遗漏），或干脆写成固定值 `fillColor($r('app.color.ds_icon'))` 无任何判断
3. 深色模式下更易误判：`ds_icon` 深色值为 `#FFFFFF`，用户看到的「白色图标」就是未选中 token 的深色态，与「图标没吃到品牌蓝」是同一个问题

## Essence

根因不是状态管理或渲染机制问题，而是**图标与文字的选中态颜色判断没有共享同一条件表达式**：文字走了条件判断，图标的 `fillColor` 因复制粘贴/遗漏停留在固定值。`Image.fillColor()` 对 SVG 图标生效，属于 API 契约保证的行为；问题出在颜色值的选择逻辑上，而非 `fillColor` 失效。修正是让图标 `fillColor` 复用与文字 `fontColor` 完全相同的条件表达式，选中态取 brand token，未选中态取 icon token，深浅色模式自动适配。

## Approach

错误用法（图标 fillColor 固定，与文字条件判断脱节）：

```typescript
Image(item.icon)
  .fillColor($r('app.color.ds_icon'))   // 永远未选中色
Text(item.title)
  .fontColor(this.currentIndex === index ? $r('app.color.ds_brand') : $r('app.color.ds_icon'))
```

正确用法（图标与文字共用同一条件表达式）：

```typescript
Image(item.icon)
  .fillColor(this.currentIndex === index ? $r('app.color.ds_brand') : $r('app.color.ds_icon'))
Text(item.title)
  .fontColor(this.currentIndex === index ? $r('app.color.ds_brand') : $r('app.color.ds_icon'))
```

执行步骤：

1. 定位所有渲染 Tab 项图标的代码路径（双分支架构下不止一处：`tabBarBuilder` 与自绘底栏组件都要查，用 grep 搜 `fillColor` + `tabBar` 定位）
2. 确认图标资源为 SVG（`fillColor` 生效）；若是位图（PNG）需改用选中/未选中两套资源
3. 将图标 `fillColor` 改为与文字 `fontColor` 相同的条件表达式，选中态统一走 brand token
4. 检查选中分支与未选中分支的 `fillColor` 值是否已不同（自绘底栏常写成 if/else 两分支渲染，两分支曾复制成同值）
5. 编译 + 模拟器实测各 Tab 切换验证（方法见 debugging 经验：UI 树 fillColor/fontColor 解析 + dumpLayout 坐标点击）

## Faster Next Time

- 代码评审检查点：**任何写选中态 `fontColor` 条件表达式的 Tab 项，必须同屏检查同项图标的 `fillColor` 是否使用了同一表达式**
- 双分支底栏架构（HdsTabs + 自绘底栏）下，修一处必须 grep 确认另一处是否存在同样逻辑，两处同步修改
- 静态检查（ArkTS-Check）无法发现此类纯视觉不一致，不要因「检查通过」跳过 UI 实测
- 选中态颜色一律走 token（`ColorTokens.brand` / `$r('app.color.ds_brand')`），不要硬编码，深浅色模式自动适配

## Applicability Boundaries

- 适用于：自绘底栏组件、自定义 `tabBarBuilder`、任何「图标 + 文字 + 条件变色」的组合渲染场景（导航栏、分段选择、列表项等）
- 不适用于：使用官方组件自带 tabBar 样式（由组件内部管理选中态）的场景；图标为位图资源的场景（应改用两套资源切换而非 `fillColor`）
- 前提：SVG 图标源码使用 `fill="currentColor"`，否则 `fillColor` 不生效

## Evidence or Examples

- 来源会话：修复 TabBar 选中态图标与文字颜色不一致（HarmonyProject1）
- 项目中两处问题点：`Index.ets` `tabBarBuilder` 内两处 `fillColor($r('app.color.ds_icon'))` 固定值（Badge 包裹分支与普通分支）；`BottomTabBar.ets` 自绘底栏选中/未选中分支 `fillColor(ColorTokens.icon)` 完全相同
- 资源定义：`ds_icon` base `#3C3C43` / dark `#FFFFFF`；`ds_brand` base `#0066CC` / dark `#0A84FF`——深色模式下未选中图标显示为白色即用户所见现象
- 修复后 UI 实测（Mate 90 Pro Max 模拟器 + UI 树数据）：选中项图标与文字均 `#FF0066CC`，未选中项均 `#FF3C3C43` 且一致；首页→消息→我的切换全部正确跟随
- ArkTS 静态检查：修改位置无新诊断（既有警告均为 `barFloatingStyle` 版本分支等无关项）；编译 BUILD SUCCESSFUL
