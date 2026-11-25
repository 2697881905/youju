---
title: "2026-09-16-arkui-dark-mode-hardcoded-colors.md"
id: markdown_798285c88467638f6a8dc28635ad6f33_d2c0982bb3a1877696bf40abe8d179407505655250320770
kb: 有据-YouJu
folder: "问题记录"
media_type: 7
tags: []
source: ima
exported_at: 2026-11-23T15:08:16.759Z
---
---
id: 2026-09-16-arkui-dark-mode-hardcoded-colors
title: ArkUI 深色模式适配：硬编码颜色值陷阱与检测
category: coding-pattern
nature: pitfall
created_at: 2026-09-16T01:23:33
updated_at: 2026-09-26T15:00:35
tags: [ArkUI, 深色模式, 硬编码颜色, ColorTokens, 主题适配]
keywords: [ArkUI, 深色模式, dark mode, 硬编码颜色, ColorTokens, hex color, #FFFFFF, #34C759, 背景色, 文字色, 边框色, 主题切换, setColorMode, $r app.color]
problem_patterns: [页面内硬编码hex颜色值, 颜色未通过ColorTokens或$r引用, 管理后台页面深色模式未适配]
source_sessions: [ses_f5a5a3ed2ffeyaFWKEgDGNNa1A]
project: HarmonyProject1
severity: medium
quality_score: 81
hit_count: 0
last_hit_at: null
low_quality_hit_count: 0
tier: A
related_experiences: [2026-09-16-arkui-dark-mode-hardcoded-color-pitfall]
---

> **归档说明**：此文件已合并入 `2026-09-16-arkui-dark-mode-hardcoded-color-pitfall.md`（主文件），因两者来自同一 session、覆盖同一问题模式，相似度 ≥ 0.87。主文件 quality_score 更高（86→88），tier S，结构更清晰。归档于 2026-09-26T15:00:35。

# ArkUI 深色模式适配：硬编码颜色值陷阱与检测

## Scenario

ArkUI 项目使用 design token 系统（`ColorTokens`）和资源引用（`$r('app.color.xxx')`）来实现深色/浅色模式自动适配。但在实际开发中，开发者经常在页面内直接硬编码 hex 颜色值（如 `'#34C759'`、`'#FFFFFF'`），这些颜色在深色模式下不会自动切换，导致文字不可读、按钮不可见、背景色与内容色冲突。

管理后台页面（admin pages）是重灾区——因为通常由不同开发者编写，且测试时往往只关注功能正确性，忽略深色模式适配。

## Key Signals

深色模式适配缺失的信号：
1. 审核反馈"深色模式下某些页面不可读"
2. `grep '#[0-9A-Fa-f]'` 在页面文件中发现大量硬编码颜色值
3. 管理后台页面（ModerationPage、ReportAdminPage）使用绿色/红色/灰色硬编码值来表示状态
4. 发布预览页使用硬编码颜色来模拟纹理效果（牛皮纸、胶片孔等）

## Essence

ArkUI 的深色模式适配机制有两种正确路径：
1. **资源引用**：`$r('app.color.text_primary')` — 系统根据当前颜色模式自动选择 `dark/` 或 `light/` 下的资源
2. **Design Token**：`ColorTokens.primary`、`ColorTokens.canvas` 等 — 在 token 层面定义深浅色值，页面统一引用

硬编码 hex 值（`'#34C759'`）绕过了这两种机制，颜色在深色模式下保持不变，导致：
- `'#FFFFFF'` 白色文字在白色背景上不可见（浅色模式）
- `'#34C759'` 绿色按钮在深色背景下对比度不足
- `'#FFE5E5'` 浅红底色在深色模式下显得刺眼

### 特殊情况：纹理/装饰效果
某些视觉效果（如牛皮纸纹理、胶片孔颜色）使用硬编码颜色是合理的，因为这些效果本身不随主题切换。但需要明确标注为"主题无关的装饰色"。

## Approach

### 检测方法
```bash
# 搜索所有 .ets 文件中的硬编码 hex 颜色值
grep -rn '#[0-9A-Fa-f]\{6\}' entry/src/main/ets/pages/
grep -rn '#[0-9A-Fa-f]\{8\}' entry/src/main/ets/pages/  # 含 alpha 通道
```

### 修复策略
1. **状态色**（通过/驳回/封禁等）：在 `ColorTokens` 中定义 `success`、`danger`、`warning` 等 token，深浅色各一套值
2. **标签底色**（如 `'#E8F1FF'`、`'#F2F2F2'`）：改为 `$r('app.color.tag_bg')` 或 `ColorTokens.tagBg`
3. **文字色**（`'#FFFFFF'`）：改为 `ColorTokens.onPrimary` 或 `$r('app.color.text_on_primary')`
4. **装饰纹理色**：保留硬编码但添加注释标注 `// theme-independent decorative color`

### 不应修复的情况
- `'#1AFF3B30'` 这种带 alpha 的 tint 色（如 DANGER_TINT），如果底色 `#FF3B30` 本身已通过 token 定义，tint 色可以保留
- 纹理/装饰效果中的颜色（牛皮纸、胶片孔等），这些是视觉设计的一部分，不随主题切换

## Faster Next Time

- **开发时**：在页面中需要使用颜色时，先搜索 `ColorTokens` 是否已有对应 token，没有则先在 token 层定义再使用
- **审查时**：`grep -rn '#[0-9A-Fa-f]\{6\}' entry/src/main/ets/` 一条命令即可找出所有硬编码颜色，按文件分类后优先处理管理后台页面
- **代码审查检查点**：PR 审查时检查新增代码是否引入了硬编码颜色值

## Applicability Boundaries

- **适用**：所有需要深色/浅色模式适配的 ArkUI 页面和组件
- **不适用**：纯装饰性视觉效果（纹理、胶片效果等）中的颜色，这些颜色本身不随主题切换
- **注意**：带 alpha 通道的 tint 色（如 `'#1AFF3B30'`）需要根据底色是否已 token 化来判断是否需要修复

## Evidence or Examples

在 HarmonyProject1 项目中发现的具体硬编码颜色：
- **ReportAdminPage.ets**：`'#34C759'`（通过按钮绿色，第335行）、`'#E8F1FF'`（类型标签底色，第372行）、`'#F2F2F2'`（状态标签底色，第379行）、`'#FFE5E5'`（理由标签底色，第398行）
- **ModerationPage.ets**：`'#34C759'`（通过按钮，第297行）、`'#FFE5E5'`（举报数标签，第238行）、`'#FFD1D1'`（封禁按钮边框，第323行）、`'#FFFFFF'`（按钮文字色，第60/356行）
- **Index.ets**：Tab 颜色 `'#8A6548'`、`'#34C759'`、`'#FF9500'`、`'#AF52DE'`、`'#FF2D55'`（第195-199行）
- **PublishPreviewPage.ets**：多处装饰性颜色（`'#8C000000'`、`'#50FFFFFF'`、`'#FAF7EF'`、`'#CC202832'`、`'#552E1E'`、`'#A8FFFFFF'`）——这些是纹理效果，可保留
- **BlocklistPage.ets**：`'#1AFF3B30'`（DANGER_TINT 常量，第21行）——带 alpha 的 tint 色，底色 `#FF3B30` 需确认是否已 token 化
