---
title: "2026-09-16-arkui-event-touches-array-bounds-check.md"
id: markdown_798285c88467638f6a8dc28635ad6f33_38114d8fe3e024f1152e8a2b50cca6eb7505655250320770
kb: 有据-YouJu
folder: "问题记录"
media_type: 7
tags: []
source: ima
exported_at: 2026-11-23T14:52:37.917Z
---
---
id: 2026-09-16-arkui-event-touches-array-bounds-check
title: ArkUI 事件回调中 touches/fingerList 数组访问前必须检查长度
category: coding-pattern
nature: pitfall
created_at: 2026-09-16T01:03:43
updated_at: 2026-09-16T01:23:33
tags: [ArkUI, touches, fingerList, 数组越界, 事件回调, 崩溃]
keywords: [touches, fingerList, e.touches[0], event.fingerList[0], array bounds, length check, ArkUI, GestureEvent, TouchEvent, 崩溃]
problem_patterns: [event-array-index-without-length-check]
source_sessions: [ses_f5a5a0181ffeDQZ3eeC6mOmGcW]
project: HarmonyProject1
severity: high
quality_score: 91
hit_count: 0
last_hit_at: null
low_quality_hit_count: 0
tier: S
related_experiences: [2026-09-16-arkui-array-first-element-string-concat, 2026-09-16-format-function-nan-infinity-guard]
---

# ArkUI 事件回调中 touches/fingerList 数组访问前必须检查长度

## Scenario

ArkUI 的 `TouchEvent` 和 `GestureEvent` 回调中，`touches` 和 `fingerList` 是动态数组，表示当前触摸点列表。在 `onTouch`、`onGesture` 等回调中直接使用 `e.touches[0]` 或 `event.fingerList[0]` 访问首元素时，如果事件触发时数组为空（如取消事件、系统异常回调），会得到 `undefined`，后续访问 `.globalX`、`.localX` 等属性将导致运行时崩溃。

## Key Signals

- 运行时崩溃：`Cannot read property 'globalX' of undefined` 或类似 TypeError
- 代码中存在 `e.touches[0].xxx` 或 `event.fingerList[0].xxx` 但前方无 `length > 0` 检查
- 崩溃难以复现：只在特定系统状态或边缘事件（如多点触控快速抬起）时触发

## Essence

ArkUI 事件系统中的触摸点列表是动态数组，**不保证回调触发时至少有一个元素**。`onTouch` 的 `TouchEvent.touches` 在 `TouchType.Cancel` 等场景下可能为空数组；`GestureEvent.fingerList` 在长按取消等边缘场景也可能为空。数组索引访问 `[0]` 对空数组返回 `undefined` 而非报错，但后续属性访问 `.globalX` 会抛出 TypeError。

## Approach

1. **所有 touches/fingerList 访问前检查长度**：
   ```typescript
   // ❌ 错误：直接索引访问
   .onTouch((e: TouchEvent) => {
     const x = e.touches[0].globalX;  // 可能崩溃
   })

   // ✅ 正确：先检查长度
   .onTouch((e: TouchEvent) => {
     if (e.touches.length === 0) { return; }
     const x = e.touches[0].globalX;
   })
   ```

2. **GestureEvent 同理**：
   ```typescript
   // ❌ 错误
   .gesture(LongPressGesture().onAction((e: GestureEvent) => {
     const x = e.fingerList[0].globalX;  // 可能崩溃
   }))

   // ✅ 正确
   .gesture(LongPressGesture().onAction((e: GestureEvent) => {
     if (e.fingerList.length === 0) { return; }
     const x = e.fingerList[0].globalX;
   }))
   ```

3. **提供兜底默认值**（当不希望直接 return 时）：
   ```typescript
   let gx: number = this.msgAreaGlobalX + this.msgAreaWidth / 2;
   let gy: number = this.msgAreaGlobalY + this.msgAreaHeight / 2;
   if (event.fingerList.length > 0) {
     gx = event.fingerList[0].globalX;
     gy = event.fingerList[0].globalY;
   }
   ```

## Faster Next Time

- 代码审查时搜索 `touches[0]` 和 `fingerList[0]`，确认每个前方都有 `length > 0` 或 `length === 0` 的检查
- 特别注意自定义组件中 `onTouch`、`onGesture` 回调内的数组访问
- 对比正确做法：`ChatPage.ets` 中 `event.fingerList[0]` 前有 `if (event.fingerList.length > 0)` 保护并提供兜底坐标

## Applicability Boundaries

- **适用**：所有 ArkUI `@Component` 中 `onTouch`、`onGesture`、`LongPressGesture`、`PanGesture` 等事件回调
- **不适用**：非事件回调中的数组访问（如静态数据列表，长度由数据源保证）
- **注意**：即使实测中从未触发空数组，也应加保护——系统升级或边缘场景可能引入空数组回调

## Evidence or Examples

- `SegmentedControl.ets` 行93、111：`e.touches[0]` 无长度检查，直接访问 `.globalX` — 潜在崩溃
- `BottomTabBar.ets` 行89、107：同上 — 潜在崩溃
- `ChatPage.ets` 行588-590：`if (event.fingerList.length > 0)` 后再访问 `event.fingerList[0].globalX` — 正确做法，且提供了兜底默认坐标
