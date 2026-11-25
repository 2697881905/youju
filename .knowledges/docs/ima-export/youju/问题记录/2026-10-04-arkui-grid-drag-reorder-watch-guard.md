---
title: "2026-10-04-arkui-grid-drag-reorder-watch-guard.md"
id: markdown_798285c88467638f6a8dc28635ad6f33_adf48ee1c357b6c88ad1cb2783d69c637505655250320770
kb: 有据-YouJu
folder: "问题记录"
media_type: 7
tags: []
source: ima
exported_at: 2026-11-23T14:52:37.917Z
---
---
id: 2026-10-04-arkui-grid-drag-reorder-watch-guard
title: ArkUI Grid 长按拖拽排序：双数组同序搬迁 + reordering 守卫避免 @Watch 回调打乱顺序
category: coding-pattern
nature: technique
created_at: 2026-10-04T23:31:06
updated_at: 2026-10-04T23:42:44
tags: [arkui, grid, drag-sort, watch, harmonyos]
keywords: [Grid, editMode, onItemDragStart, onItemDrop, 拖拽排序, 长按拖拽, @Watch, @Link, 响应式回流, reordering, 并行数组, HarmonyOS, ArkUI]
problem_patterns: [watch-callback-rebuilds-items-during-programmatic-reorder, display-array-and-submit-array-out-of-sync, onItemDrop-insertIndex-out-of-bounds]
source_sessions: [ses_ef87df3e5ffecHZOqyP7T9X2kR]
project: HarmonyProject1
severity: medium
quality_score: 86
hit_count: 0
last_hit_at: null
low_quality_hit_count: 0
tier: S
related_experiences: [2026-10-04-arkui-image-draggable-gesture-conflict, 2026-09-16-arkui-state-variable-ui-render-gap]
---

# ArkUI Grid 长按拖拽排序：双数组同序搬迁 + reordering 守卫避免 @Watch 回调打乱顺序

## Scenario

在 ArkUI（ArkTS）中用 `Grid` 渲染「可排序的图片/条目列表」，需要长按拖动重排。典型场景是发布编辑器的多图选择网格：显示用的 `items`（含本地 `PixelMap` 预览、上传中态）与提交用的 `selected`（远端 URL 列表）是两份并行的数组，通过下标一一对应，要求拖动后两份数组顺序始终一致。

## Key Signals

1. 只重排显示数组后，提交用的对外数组顺序没跟着变，最终发布顺序与用户看到的顺序不一致。
2. 给对外数组绑了 `@Watch`，重排后回调被触发，按该数组从零重建显示数组，把刚拖好的顺序打回原样（或被过滤掉）——现象是「拖完一松手顺序就跳回去」。
3. 拖拽结果偶发错位：`onItemDrop` 的 `insertIndex` 在末尾/越界时把元素放到非法位置。
4. 使用了 Grid 自带 `editMode`，但缺少 `onItemDrop` 收尾时位置不更新。

## Essence

ArkUI `Grid` 自带 `editMode(true)` + `onItemDragStart` / `onItemDrop` 即可实现长按（约 170ms）拖拽排序，**不需要手写 `LongPressGesture`**。真正的坑有两类：

1. **两份并行数组必须同序搬迁**。只搬一份会让「显示顺序」与「提交顺序」脱节，且不会报错，属于静默不一致。
2. **程序化重排会触发 `@Watch` 回流重建**。`selected` 上若有 `@Watch('onSelectedChange')`，重排时对 `selected` 的赋值会触发回调；回调按 `selected` 重建 `items`，覆盖刚搬好的顺序。必须用一个 `reordering` 布尔守卫在重排期间跳过重建（或在回调里识别自触发）。这是「响应式监听」与「程序化就地修改」之间的经典竞争。

## Approach

1. Grid 开启拖拽编辑模式并绑定起止回调，先做下标校验与越界钳制：

   ```ts
   Grid() { ForEach(this.items, (item) => { GridItem() { /* ... */ } }) }
     .columnsTemplate('1fr 1fr 1fr')
     .editMode(true) // 长按进入编辑模式，由系统提供拖拽浮层
     .onItemDragStart((_e: ItemDragInfo, index: number) => {
       if (index < 0 || index >= this.items.length) return;
       this.dragIndex = index;
       return this.dragOverlay; // @Builder 拖拽浮层
     })
     .onItemDrop((_e: ItemDragInfo, itemIndex: number, insertIndex: number, isSuccess: boolean) => {
       if (!isSuccess || itemIndex < 0 || itemIndex >= this.items.length) return;
       let target: number = insertIndex;
       if (target > this.items.length - 1) target = this.items.length - 1; // 收尾越界钳制
       this.moveItem(itemIndex, target);
     })
   ```

2. `moveItem(from, to)` 同时搬移两份数组，并在整个搬移期间置 `reordering = true`：

   ```ts
   private reordering: boolean = false;
   private moveItem(from: number, to: number): void {
     if (from === to) return;
     this.reordering = true;                        // 抑制 @Watch 回流
     const [it] = this.items.splice(from, 1);  this.items.splice(to, 0, it);
     const [url] = this.selected.splice(from, 1); this.selected.splice(to, 0, url);
     this.reordering = false;
   }
   ```

3. 在 `@Watch` 回调最前面判断守卫，重排期间的变更直接 return，不重建 `items`：

   ```ts
   @Link @Watch('onSelectedChange') selected: string[];
   private onSelectedChange(): void {
     if (this.reordering) return; // 自触发的重排变更，跳过重建
     // ... 正常按 selected 重建 items（外部恢复草稿 / 删除单项时）
   }
   ```

4. 删除单项时同样保持两份数组同序：`items.splice(idx, 1)` 与 `selected.splice(idx, 1)` 一起做。
5. 验证：拖动后 `selected` 顺序 == 界面顺序；用 `selected` 生成的最终结果与拖拽顺序一致。

## Faster Next Time

- 看到「`@Watch` 监听的数组在程序内被再次赋值」就立刻想到回流重建风险，先加 guard flag 再改数组。
- 设计可排序列表前先问：「显示数据与提交数据是不是两份数组」；若是，搬迁逻辑只写一次且同时操作两份。
- `onItemDrop` 的 `insertIndex` 一律先做 `[0, len-1]` 钳制再使用；`onItemDragStart` 先做 `[0, len)` 校验。
- 不要手写 `LongPressGesture`——Grid 的 `editMode(true)` 已覆盖长按拖拽；手写反而要自己处理浮层与落点。

## Applicability Boundaries

- 适用：ArkUI `Grid` 需要长按拖拽重排，且存在「显示数组 + 语义数组」并行结构的场景。
- 不适用：列表不需要重排；或使用 `List` 的拖拽回调（机制类似，但落点回调签名与 Grid 不同，需按 List 适配）。
- 与 `Image` 默认 `draggable=true` 的手势劫持是**不同问题**：本模式是主动开启 Grid 拖拽；若拖拽区域内的 `Image` 同时处于 Swiper / PanGesture 容器，仍需参考 `2026-10-04-arkui-image-draggable-gesture-conflict` 显式 `.draggable(false)`，两类问题可能叠加。
- `reordering` 守卫依赖「`@Watch` 回调同步触发」这一 ArkUI 状态机制；若未来状态更新改为异步批量，需重新评估守卫时机。

## Evidence or Examples

（来源：HarmonyProject1 发布流程探索会话，未在本次会话独立复现；证据为仓库中已固化的实现）

- `entry/src/main/ets/components/ImagePicker.ets`：
  - L14-19 `interface PickedImage { id; preview?: PixelMap; remoteUrl?; uploading }` 与 L23 `@Link @Watch('onSelectedChange') selected: string[]` 构成并行数组。
  - L30-33 `private dragIndex: number = -1`、`private reordering: boolean = false`；注释明确「重排期间置位：selected 变更会触发 @Watch，跳过重建以避免打乱刚排好的 items 顺序」。
  - L36-45 `onSelectedChange()` 首行 `if (this.reordering) { return; }`。
  - L158-161 `removeAt(idx)` 同时移除 `items` 与 `selected`。
  - L165-184 `moveItem(from, to)` 同序搬移两份数组。
  - L187-206 `dragOverlay()` 拖拽浮层 `@Builder`。
  - L269 `columnsTemplate('1fr 1fr 1fr')`；L273-293 `Grid.editMode(true)` + `.onItemDragStart` + `.onItemDrop`，注释「长按 170ms 进入编辑模式拖拽」。
- 该组件被 `entry/src/main/ets/pages/PhotoPublishPage.ets` L45、L333-338 以 `ImagePicker({ selected: $images, maxCount: 9 })` 引用。
