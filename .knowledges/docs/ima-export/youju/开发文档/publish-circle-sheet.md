---
title: "publish-circle-sheet.md"
id: markdown_798285c88467638f6a8dc28635ad6f33_474dd2b0fb5459f23a19736b3967413f7505655250320770
kb: 有据-YouJu
folder: "开发文档"
media_type: 7
tags: []
source: ima
exported_at: 2026-11-23T14:52:37.917Z
---
# 发布页"选择圈子"改为 bindSheet 底部弹层

## Summary
把发布页的"选择圈子"从**全屏覆盖面板**（视觉上像打开新页面）改为 **bindSheet 底部弹层**，保留现有"按分类多选标签（最多 3 个）+ 完成按钮"的结构。改动覆盖三个发布页（PhotoPublishPage / TextPublishPage / VideoPublishPage）及共用的 PublishTagPanel 组件。

## Current State Analysis

- **触发链**：三个发布页的 `PublishGenreSection` 中"选择圈子"按钮 → `onOpenTags()` → 页面 `showTagPanel = true` → 在根 `Stack` 中条件渲染全屏 `Column { PublishTagPanel(...) }`（带 `statusBarHeight` 顶部 padding），视觉等同打开新页面。
- **PublishTagPanel**（[PublishTagPanel.ets](file:///Users/itxiaobai/HarmonyProject1/entry/src/main/ets/components/PublishTagPanel.ets)）：全屏 `Column`（`height('100%')` + canvas 背景 + `transition`），内含 GlassPanel 标题栏（"选择圈子" + 已选 x/3 + 完成按钮）与 `Scroll`（按 category 分组展示标签、多选、`barBottomReserve()` 底部避让）。
- **数据归属**：`categoryList` / `tagsByCategory` / `selectedTags` / `toggleTag` / `MAX_SELECTED_TAGS` 均在页面层，经 props 传入 PublishTagPanel。
- **bindSheet API**（SDK 已确认）：`bindSheet(isShow: boolean, builder: CustomBuilder, options?: SheetOptions)`；`SheetOptions` 支持 `height`（SheetSize | Length）、`dragBar`、`blurStyle`、`maskColor`、`onAppear/onDisappear/onWillAppear` 等。
- 三个发布页根结构一致：`Stack({ alignContent: Alignment.Top }) { Scroll(...); PublishTopBar(...); if (showTagPanel) { 全屏面板 } }`。

## Proposed Changes

### 1. [PublishTagPanel.ets](file:///Users/itxiaobai/HarmonyProject1/entry/src/main/ets/components/PublishTagPanel.ets) — 改造为 sheet 内容
- 外层 `Column`：去掉 `backgroundColor(ColorTokens.canvas)`（sheet 自带 `blurStyle` 背景，避免双层底色）；去掉 `transition`（bindSheet 自带进出场动画）；保留 `height('100%')` 以撑满 sheet 内容区，`Scroll` 的 `layoutWeight(1)` 保持不变。
- 底部避让：`barBottomReserve()` 保留（sheet 为底部弹层，仍需避让系统导航条）。
- 其余（标题栏、分类标签、多选、完成按钮）不动。

### 2. 三个发布页（PhotoPublishPage / TextPublishPage / VideoPublishPage）
- 删除 `if (this.showTagPanel) { Column() { PublishTagPanel({...}) }.width('100%').height('100%').padding({ top: statusBarHeight }) }` 全屏块（约 [PhotoPublishPage.ets#L455-L469](file:///Users/itxiaobai/HarmonyProject1/entry/src/main/ets/pages/PhotoPublishPage.ets#L455-L469)，其余两页同构）。
- 新增 `@Builder tagSheet()`，内容 = `PublishTagPanel({ ... })`（原 props 全部保留）。
- 根 `Stack` 末尾挂 `.bindSheet(this.showTagPanel, this.tagSheet(), { ... })`，options：
  - `height: '60%'`（内容较多，给 Scroll 足够空间）
  - `dragBar: true`（可见拖拽条，提示可下滑关闭）
  - `blurStyle: BlurStyle.BACKGROUND_THICK`（沿用项目 GlassBlurStyle.Floating 同档，保证与分段栏/搜索框玻璃材质一致）
  - `maskColor: '#33000000'`
  - `onDisappear: () => { this.showTagPanel = false; }`（下滑/点遮罩/完成按钮关闭后同步状态，避免 isShow 悬空）
- `onOpenTags` 回调（置 `showTagPanel = true`）保持不变——bindSheet 的 isShow 直接消费该状态。
- 三个文件改动点完全同构（各自用本页的 `statusBarHeight` 不再需要）。

### 3. [PublishGenreSection.ets](file:///Users/itxiaobai/HarmonyProject1/entry/src/main/ets/components/PublishGenreSection.ets) — 附带统一按钮样式
- "选择圈子"按钮当前仍是旧描边样式（`Color.Transparent` + `barBorder`，[L137-L139](file:///Users/itxiaobai/HarmonyProject1/entry/src/main/ets/components/PublishGenreSection.ets#L137-L139)），与已统一为分段栏玻璃的体裁按钮不一致。
- 顺带改为与体裁按钮同款：`.backdropBlur(SEGMENT_GLASS_BLUR)` + `.backgroundColor(SEGMENT_GLASS_BG)` + `border 1px SEGMENT_GLASS_BORDER`（复用文件顶部已定义常量）。
- 仅视觉统一，不改变 `onOpenTags` 行为。

## Assumptions & Decisions
- 内容结构：保留"按分类多选标签（最多 3 个）+ 完成按钮"，不做简化（用户已确认）。
- 菜单形式：bindSheet 底部弹层（用户已确认），而非 bindPopup 下拉。
- sheet 高度取 `'60%'`：分类+标签可能较多，给 Scroll 留足空间；如需更紧凑可改 `SheetSize.MEDIUM`。
- 关闭状态同步：完成按钮 `onClose` → `showTagPanel = false`；下滑/遮罩关闭由 `onDisappear` 兜底同步。
- PublishGenreSection 按钮样式统一为附带项（符合此前"统一样式"诉求），若用户不想要可回退该步骤。

## Verification
1. 编译：`DEVECO_SDK_HOME=/Applications/DevEco-Studio.app/Contents/sdk /Applications/DevEco-Studio.app/Contents/tools/hvigor/bin/hvigorw assembleHap --mode module -p product=default -p buildMode=debug --no-daemon`，确认 `BUILD SUCCESSFUL`、无新增 ERROR/WARN。
2. 运行验证：照片/文字/视频三个发布页点击"选择圈子" → 从底部弹出玻璃弹层；分类标签可多选（最多 3 个，超限 toast）；"完成"关闭并回填已选标签胶囊；下滑/点遮罩可关闭；关闭后再次点击可正常重新弹出。
