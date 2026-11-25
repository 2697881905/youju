---
title: "disable-hdstabs-swipe-page-switch.md"
id: markdown_798285c88467638f6a8dc28635ad6f33_e36106a3b17c66cf15291896d4bb6de17505655250320770
kb: 有据-YouJu
folder: "开发文档"
media_type: 7
tags: []
source: ima
exported_at: 2026-11-23T14:52:37.917Z
---
# 禁用页面主体左右滑动切换 Tab

<br />

<br />

<br />

## Summary
在 `Index.ets` 的主框架中，`HdsTabs` 悬浮页签默认允许**页面主体任意位置左右滑动**来切换底部 Tab（首页/圈子/消息/我的）。用户希望去掉这个手势——页面上左右滑动不应切换页面，仅保留点击底部 tabBar 切换。

## Current State Analysis
- 文件：`entry/src/main/ets/pages/Index.ets`（build() 内 HdsTabs 部分，line 492-526）
- 现状：`HdsTabs({...})` 配置了 `barOverlap/barPosition/vertical/barFloatingStyle/onTabBarClick/onChange`，**未设置 `scrollable`**，故继承默认值 `true` → 页面主体左右滑动可切换 tab。
- SDK 依据：`@hms.hds.hdsBaseComponent.d.ets` line 5409-5417，`scrollable(value: boolean)` 注释明确："judging whether page switching can be performed by sliding left and right. Default value is true."
- 排查确认：项目中其他 `.scrollable(...)` 均为 `ScrollDirection`（内容滚动方向，非页面切换语义），`Swiper` 属于详情页图片轮播/发布预览（内容交互，非切换主页面）。**均不需要改动**。用户所述"页面上左右滑动切换页面"仅来自 Index 的 HdsTabs。

## Proposed Changes
### 文件：`entry/src/main/ets/pages/Index.ets`
- 位置：`HdsTabs({ controller: this.hdsController })` 链式属性处（`barFloatingStyle(...)` 之后、`onTabBarClick(...)` 之前或之后均可）
- 改动：新增一行 `.scrollable(false)`
- 语义：
  - 页面主体左右滑动不再切换 tab（禁用滑动切页）
  - 底部 tabBar 点击切换不受影响（`onTabBarClick`/`onChange` 逻辑不变）
  - 发布占位页（index=2）的回跳防御不受影响
  - 页面内部内容（如首页瀑布流纵向滚动、详情轮播）不受影响——只禁 HdsTabs 的页面切换滑动

```typescript
.barFloatingStyle({
  // ...原配置不动
})
.scrollable(false)   // 禁止页面主体左右滑动切换 Tab，仅点击底部页签切换
.onTabBarClick((index: number): void => { this.handleTabBarClick(index); })
```

## Assumptions & Decisions
- 只禁用**页面切换**滑动；不触碰任何内容区域自身的滚动/轮播（HomeTab 纵向滚动、DetailMediaCarousel 轮播等保持原样）。
- 不修改 CircleTab 星环拖动、不修改其他文件的 `.scrollable(ScrollDirection.*)`。
- 底部栏自身（bottom bar）无独立滑动切换需求，无需额外处理。

## Verification
1. 构建：`cd /Users/itxiaobai/HarmonyProject1 && export DEVECO_SDK_HOME="/Applications/DevEco-Studio.app/Contents/sdk" && /Applications/DevEco-Studio.app/Contents/tools/hvigor/bin/hvigorw --mode module -p product=default -p module=entry@default -p buildMode=debug assembleHap --no-daemon 2>&1 | grep -iE "ERROR|BUILD|FAILED" | tail -8` → 期望 BUILD SUCCESSFUL。
2. 部署真机（Pocket2 LEM-AL00）：`hdc install .../entry-default-signed.hap` 后启动。
3. 真机手测：
   - 在首页内容区域**左右滑动** → 页面不切换（本次改动核心验证）
   - 点击底部"圈子"/"消息"/"我的" tab → 正常切换
   - 首页纵向滚动、帖子详情图片横滑轮播 → 仍正常
   - 点"发布" tab → 仍弹发布方式弹窗且回跳
