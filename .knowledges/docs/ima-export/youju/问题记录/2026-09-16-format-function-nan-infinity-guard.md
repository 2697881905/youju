---
title: "2026-09-16-format-function-nan-infinity-guard.md"
id: markdown_798285c88467638f6a8dc28635ad6f33_f98cd50ce00f5ab2f4be54e64fb7360a7505655250320770
kb: 有据-YouJu
folder: "问题记录"
media_type: 7
tags: []
source: ima
exported_at: 2026-11-23T14:52:37.917Z
---
---
id: 2026-09-16-format-function-nan-infinity-guard
title: 数字/时间格式化函数必须处理 NaN 和 Infinity 边界值
category: coding-pattern
nature: pitfall
created_at: 2026-09-16T01:03:43
updated_at: 2026-09-16T01:13:55
tags: [NaN, Infinity, 格式化, formatCount, timeAgo, 边界值, 显示异常]
keywords: [NaN, Infinity, isFinite, isNaN, formatCount, timeAgo, formatNumber, formatDate, Number, parseInt, parseFloat, 边界值, 显示异常, Invalid Date]
problem_patterns: [nan-passes-through-numeric-comparisons, infinity-passes-through-range-checks]
source_sessions: [ses_f5a5a0181ffeDQZ3eeC6mOmGcW]
project: HarmonyProject1
severity: medium
quality_score: 95
hit_count: 1
last_hit_at: 2026-09-21T00:50:26
low_quality_hit_count: 0
tier: S
related_experiences: [2026-09-16-arkui-array-first-element-string-concat, 2026-09-16-arkui-event-touches-array-bounds-check]
---

# 数字/时间格式化函数必须处理 NaN 和 Infinity 边界值

## Scenario

项目中常见的数字格式化函数（如 `formatCount`、`formatNumber`）和时间格式化函数（如 `timeAgo`、`formatDate`）接收外部输入，当输入为 `NaN` 或 `Infinity` 时，这些值会穿透常规的条件判断和范围检查，导致显示 "Infinityw"、"Invalid Date" 等异常文本。这类问题在后端返回 null/undefined 字段、JSON.parse 解析异常、或 Number() 转换非数字字符串时产生。

## Key Signals

- UI 上显示 "Infinityw"、"NaNw"、"Invalid Date" 等异常文本
- `formatCount(n)` 中 `if (!n)` 对 NaN 返回 true（因为 `!NaN === true`），但对 Infinity 返回 false（因为 `!Infinity === false`）
- `timeAgo(iso)` 中 `new Date(invalidString).getTime()` 返回 NaN，`NaN < 1` 为 false，所有范围判断都被跳过，最终执行 `toLocaleDateString()` 显示 "Invalid Date"
- `Number(undefined)` = NaN，`Number(null)` = 0，`Number('abc')` = NaN，`Number('')` = 0

## Essence

JavaScript/ArkTS 中 NaN 和 Infinity 的特殊行为导致它们穿透常规条件判断：

1. **NaN 与任何数比较都返回 false**：`NaN < 1` → false，`NaN >= 10000` → false，`NaN === NaN` → false。所以 `if (n >= 10000)` 对 NaN 不成立，会跳到下一个分支。
2. **Infinity 穿透数值范围检查**：`!Infinity === false`，`Infinity >= 10000` → true。所以 `if (!n)` 不拦截 Infinity，`if (n >= 10000)` 让 Infinity 进入格式化分支，产生 `"Infinityw"`。
3. **NaN 在 Math.floor/算术运算中传播**：`Math.floor(NaN / 60000)` = NaN，NaN 继续穿透后续所有比较。

正确的防御方式是使用 `isNaN()` 和 `isFinite()` 在函数入口处拦截。

## Approach

1. **数字格式化函数入口检查 NaN 和 Infinity**：
   ```typescript
   // ❌ 错误：NaN 穿透 !n 检查，Infinity 穿透范围检查
   export function formatCount(n?: number): string {
     if (!n) { return '0'; }
     if (n >= 10000) { return (n / 10000).toFixed(1) + 'w'; }
     return n.toString();
   }
   // formatCount(Infinity) → "Infinityw"
   // formatCount(NaN) → "0"（侥幸通过，但逻辑不正确）

   // ✅ 正确：入口处用 isFinite 拦截
   export function formatCount(n?: number): string {
     if (n === undefined || n === null || !isFinite(n)) { return '0'; }
     if (n >= 10000) { return (n / 10000).toFixed(1) + 'w'; }
     return n.toString();
   }
   ```

2. **时间格式化函数入口检查 NaN**：
   ```typescript
   // ❌ 错误：NaN 穿透所有范围判断
   export function timeAgo(iso?: string): string {
     if (!iso) { return ''; }
     const diff = Date.now() - new Date(iso).getTime();
     // diff = NaN 时，所有 if 判断都为 false，最终执行 toLocaleDateString()
     const m = Math.floor(diff / 60000);
     if (m < 1) { return '刚刚'; }
     // ...
   }
   // timeAgo('invalid') → "Invalid Date"

   // ✅ 正确：检查 getTime() 结果
   export function timeAgo(iso?: string): string {
     if (!iso) { return ''; }
     const t = new Date(iso).getTime();
     if (isNaN(t)) { return ''; }
     const diff = Date.now() - t;
     // ...
   }
   ```

3. **通用模式：所有接收外部数值的函数都应在入口检查**：
   ```typescript
   function safeNumber(v: unknown): number {
     const n = Number(v);
     return isFinite(n) ? n : 0;
   }
   ```

## Faster Next Time

- 审查格式化函数时，测试三个边界输入：`NaN`、`Infinity`、`undefined`
- 搜索 `format`、`formatCount`、`timeAgo`、`formatDate` 等函数，确认入口有 `isFinite` / `isNaN` 检查
- 搜索 `Number(` 转换，确认转换后有 `isNaN` 检查（`Number('abc')` = NaN）
- 搜索 `parseInt`、`parseFloat`，确认有 `isNaN` 检查
- 对比正确做法：`video.ets` 的 `normalizeVideoAspectRatio` 使用 `if (!isFinite(ratio) || ratio <= 0)` 正确拦截了 NaN 和 Infinity

## Applicability Boundaries

- **适用**：所有接收外部输入（API 响应、用户输入、JSON.parse 结果）的数字/时间格式化函数
- **适用**：所有使用 `Number()`、`parseInt()`、`parseFloat()` 转换字符串为数字的场景
- **不适用**：内部计算中已保证数值合法的场景（如常量运算）
- **注意**：`!n` 对 NaN 返回 true 是巧合而非设计——不要依赖此行为，应显式使用 `isNaN()`

## Evidence or Examples

- `format.ets` 行1-9 `formatCount`：`!n` 对 NaN 返回 true（巧合正确），但 Infinity 穿透到 `n >= 10000` 分支返回 `"Infinityw"`
- `format.ets` 行11-32 `timeAgo`：`new Date(iso).getTime()` 对无效日期返回 NaN，NaN 穿透所有 `if` 判断，最终 `toLocaleDateString()` 显示 "Invalid Date"
- `video.ets` 行17-28 `normalizeVideoAspectRatio`：`!isFinite(ratio) || ratio <= 0` 正确拦截 NaN 和 Infinity — 正确做法
- `ChatPage.ets` 行362-368 `formatChatTime`：`if (!iso) return ''` + `if (isNaN(t)) return ''` — 正确做法
- `DetailPage.ets` 行421-426：`parseInt(raw, 10)` 后检查 `isNaN(idNum)` — 正确做法
- `BookmarkFolderDetailPage.ets` 行41：`!(this.folderId > 0)` 使用 `!(x > 0)` 而非 `x <= 0`，NaN > 0 为 false 所以 !(NaN > 0) = true — 正确处理了 NaN
