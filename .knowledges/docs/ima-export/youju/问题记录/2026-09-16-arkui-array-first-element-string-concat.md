---
title: "2026-09-16-arkui-array-first-element-string-concat.md"
id: markdown_798285c88467638f6a8dc28635ad6f33_983d0145e9cdd238ec788b5971f956bd7505655250320770
kb: 有据-YouJu
folder: "问题记录"
media_type: 7
tags: []
source: ima
exported_at: 2026-11-23T15:08:35.242Z
---
---
id: 2026-09-16-arkui-array-first-element-string-concat
title: 条件渲染中数组首元素与字符串拼接前必须检查 length
category: coding-pattern
nature: pitfall
created_at: 2026-09-16T01:03:43
updated_at: 2026-09-16T01:13:55
tags: [数组越界, 字符串拼接, undefined, 条件渲染, ArkUI, 显示异常]
keywords: [array[0], undefined, 字符串拼接, length check, tags[0], 空数组, ?? operator, nullish coalescing, 条件渲染, 显示异常]
problem_patterns: [array-first-element-without-length-check, nullish-coalescing-does-not-protect-empty-array]
source_sessions: [ses_f5a5a0181ffeDQZ3eeC6mOmGcW]
project: HarmonyProject1
severity: medium
quality_score: 89
hit_count: 0
last_hit_at: null
low_quality_hit_count: 0
tier: S
related_experiences: [2026-09-16-arkui-event-touches-array-bounds-check, 2026-09-16-format-function-nan-infinity-guard]
---

# 条件渲染中数组首元素与字符串拼接前必须检查 length

## Scenario

ArkUI 条件渲染中，常需要取数组首元素与字符串拼接来显示分类标签、作者信息等。使用 `??` 操作符防 null/undefined 后直接 `[0]` 访问，当数组存在但为空时，`[0]` 返回 `undefined`，与字符串拼接会产生 `"undefined · ..."` 等异常显示。`??` 操作符只防 null/undefined，**不防空数组**。

## Key Signals

- UI 上出现 "undefined · 视频" 或 "undefined" 字样
- 代码中存在 `(arr ?? [])[0]` 或 `arr?.[0]` 后紧跟字符串拼接
- `??` 操作符给了虚假的安全感——它防止了 arr 为 null/undefined 时的崩溃，但空数组 `[0]` 返回 undefined 仍会穿透

## Essence

两个层面的问题叠加：

1. **`??` 操作符的语义局限**：`a ?? b` 只在 `a` 为 `null` 或 `undefined` 时返回 `b`。当 `a` 是空数组 `[]` 时，`a ?? [0]` 返回 `[]`（不是 `[0]`），因为空数组既不是 null 也不是 undefined。
2. **空数组索引访问返回 undefined 而非报错**：`[][0]` 返回 `undefined`，不会抛出异常。`undefined` 与字符串拼接时，JavaScript 会将 `undefined` 转为字符串 `"undefined"`，产生显示异常。

正确的防御是在访问首元素前检查 `arr.length > 0`。

## Approach

1. **数组首元素与字符串拼接前检查 length**：
   ```typescript
   // ❌ 错误：?? 不防空数组，空数组 [0] 返回 undefined
   const label = (post.tags ?? [])[0] + ' · ' + genreMeta(post.genre).label;
   // post.tags = [] → undefined + ' · 视频' → "undefined · 视频"

   // ✅ 正确：先检查 length
   const tags = post.tags ?? [];
   const label = tags.length > 0
     ? tags[0] + ' · ' + genreMeta(post.genre).label
     : genreMeta(post.genre).label;
   ```

2. **使用可选链 + 空值合并**（ArkTS 支持时）：
   ```typescript
   // ✅ 正确：可选链 + 空值合并
   const firstTag = post.tags?.[0] ?? '';
   const label = firstTag.length > 0
     ? firstTag + ' · ' + genreMeta(post.genre).label
     : genreMeta(post.genre).label;
   ```

3. **封装安全取首元素的工具函数**：
   ```typescript
   function firstOrEmpty<T>(arr: T[] | undefined | null): T | '' {
     if (!arr || arr.length === 0) { return ''; }
     return arr[0];
   }
   ```

## Faster Next Time

- 搜索 `(.*\??\[0\])` 配合字符串拼接操作符 `+`，确认每个都有 length 检查
- 特别注意 `??` 操作符后的 `[0]` 访问——`??` 给了虚假的安全感
- 审查条件渲染中的分类标签、作者信息等拼接逻辑
- 测试边界输入：空数组 `[]`、null、undefined

## Applicability Boundaries

- **适用**：所有 ArkUI/TypeScript 中数组首元素与字符串拼接的场景
- **适用**：所有使用 `??` 操作符后直接索引访问的场景
- **不适用**：数组长度由数据源保证非空的场景（如硬编码常量数组）
- **注意**：`?.[0]` 可选链在空数组时返回 undefined（不报错），但仍需 `?? ''` 兜底

## Evidence or Examples

- `DetailPage.ets` 行706：`(post.tags ?? [])[0] + ' · ' + genreMeta(post.genre).label.replace('报告', '')` — 当 `post.tags` 为空数组时显示 "undefined · ..."
- `DetailPage.ets` 行748、764：`this.images.length > 0 ? this.images[0] : ''` — 正确做法，先检查 length
- `CircleTab.ets` 行254：`this.circles.find(...) ?? this.circles[0]` — 空数组时 `circles[0]` 为 undefined，但后续 `initiallySelected?.name ?? ''` 用可选链保护了
