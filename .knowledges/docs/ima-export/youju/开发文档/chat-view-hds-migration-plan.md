---
title: "chat-view-hds-migration-plan.md"
id: markdown_cls1_798285c88467638f6a8dc28635ad6f33_66305539a875d835d69197a65d01a0bb7505655250320770
kb: 有据-YouJu
folder: "开发文档"
media_type: 7
tags: []
source: ima
exported_at: 2026-11-23T14:52:37.917Z
---
# 私信聊天页迁移 HDS 组件方案

## 背景

聊天页（ChatView.ets，1456 行）的 UI 全部自绘。首页、消息页、圈子页顶栏已迁入华为 HDS `HdsNavigation`（渐变模糊 + 沉浸光感），聊天页仍保留自绘顶栏，风格割裂。目标：将聊天页组件逐一替换为 HDS 组件——但需先明确 HDS 能覆盖什么、不能覆盖什么。

## 现状盘点（ChatView.ets，三形态共享组件）

ChatView 被 3 种壳复用：router 壳（ChatPage.ets @Entry）、NavDestination 壳（ChatDestination.ets，`hideTitleBar(true)`）、宽屏 embedded 分栏（MessagePage.ets dmSplit 右栏）。

| 区块 | 位置 | 现状 |
|---|---|---|
| 顶栏 | L1239-1277 | 自绘 Row：BackButton + AvatarView(32) + 昵称 + 「举报」Text，下有 0.5vp Divider；非 Navigation 标题栏 |
| 消息列表 | L1279-1347 | Scroll(listScroller)+Column+ForEach，自绘气泡；消息类型：recalled / image / video / file / share(帖子卡片) / text(高亮@提及) |
| 输入栏 | L1350-1447 | 自绘：`+` 按钮、GlowInput、`☺` 按钮、「发送」Text 按钮（全带玻璃描边） |
| 浮层 | — | emojiPanel(Grid)、mediaMenu、AtMentionSuggest、msgActionSheet(长按自绘浮层)、ImageViewer |
| 反馈 | 15 处 | safeShowToast（全局封装的 promptAction） |
| 避让 | L98/L111/L1439 | KeyboardAvoidMode.RESIZE + bottomBarInsetVp + 根 padding top=statusBarHeight |

## HDS 组件能力对照（SDK d.ts 实测结论）

`@kit.UIDesignKit` 可用组件：HdsNavigation / HdsNavDestination、HdsTabs、HdsListItemCard、HdsActionBar、HdsSnackBar、HdsListItem（侧滑）、HdsSideBar/SideMenu、HdsVisualComponent（流光）、HdsColorPicker。**没有**：聊天气泡、独立按钮、输入框、下拉菜单。

| ChatView 组件 | HDS 方案 | 结论 |
|---|---|---|
| 自绘顶栏 + Divider | **HdsNavigation**（MINI + stackBuilder + GRADIENT_BLUR） | ✅ 核心替换 |
| 消息列表 Scroll | 保留（气泡无 HDS 组件），作为渐变模糊滚动驱动源 | 保留 + 接入模糊 |
| 输入栏整体 | HdsActionBar 仅 start/end/primary **按钮插槽，无输入框位置** | ❌ 不适配，保留 GlowInput |
| 发送 Text 按钮 | HDS 无独立按钮组件；系统原生 Button 有 DetailActionBar 先例 | 可选（默认保留） |
| safeShowToast ×15 | HdsSnackBar 是替代品，但 toast 为全局统一封装、各页共用 | ❌ 不建议单页替换 |
| 气泡/emoji 面板/媒体菜单/长按菜单/@提及/看图 | HDS 无对应 | 保留自绘 |

## 实施步骤

### S1 顶栏迁入 HdsNavigation（核心改动，仅 ChatView.ets）

非 embedded 分支将 build 根结构改为：

```
HdsNavigation(this.chatNavStack) {          // 独立 NavPathStack（POC 先例）
  Column { 消息区(layoutWeight 1) ; 输入栏 }  // 原内容平移
}
.mode(NavigationMode.Stack)
.hideBackButton(true)                        // 返回键自绘进 stackBuilder（需走 backAction 拦截链）
.titleBar(chatTitleBarOptions())             // 见下
.titleMode(HdsNavigationTitleMode.MINI)
.bindToScrollable([this.listScroller])       // 消息滚动驱动渐变模糊
.clip(false)
```

标题栏配置（照抄 MessagePage.ets L1137-1164 路线 B 样板）：
- `stackBuilder`：BackButton（`if (!embedded)`）+ AvatarView 32 + 昵称（点击 goPeer）+ 「举报」Text——即现顶栏内容原样搬入
- `scrollEffectOpts`：GRADIENT_BLUR，0 → 32vp（与 MessagePage 同量级）；`originalStyle` 透明起步
- `avoidLayoutSafeArea: true` + `enableComponentSafeArea: true`
- 移除：自绘 Divider、根 `.padding({ top: statusBarHeight })`（非 embedded 时）
- 穿底裁切链：HdsNavigation `.clip(false)` + 消息 Scroll `.clip(false)`

embedded 宽屏分栏分支**保留现自绘顶栏**不动（HdsNavigation 套 HdsNavigation 双层未验证，且手机真机无法验证宽屏形态）。

关键参照文件：
- MessagePage.ets L1134-1245（嵌套 HdsNavigation 路线 B 定稿样板）
- HdsNavVerifyPage.ets（全屏 HdsNavigation + 独立 stack + MINI + bindToScrollable 先例，含裁切链注释）

### S2 输入栏：确认保留（不改）

HdsActionBar 无输入框插槽，硬塞 GlowInput 进按钮槽语义错误。输入栏维持现状；本步骤仅输出结论，无代码改动。

### S3（可选，默认不做）

- 发送按钮 → 系统原生 `Button('发送')`（Capsule + 原生按压态，DetailActionBar.ets L221-227 同款先例）。注意这是系统组件非 HDS。
- toast → HdsSnackBar：因全局封装统一性，默认不做。

## 风险与真机验证清单（Pocket 2）

1. **NavDestination 内嵌套 HdsNavigation**：Tab 页内容区嵌套已有 3 处先例，NavDestination 壳内嵌套是新形态，需验证标题栏渲染/返回行为（ChatDestination `hideTitleBar(true)` 保持不变，无双重标题栏）
2. **键盘 RESIZE 共存**：键盘弹起时 HdsNavigation 栏位置、输入栏是否贴住键盘
3. **返回拦截链**：registerOverlayBackGuard（看图/长按菜单）→ backAction → 壳层 onBackPressed，逐层过一遍
4. **渐变模糊**：消息向上滚动穿入栏下模糊生效、回滚还原；不足一屏时行为正常
5. **长按菜单坐标**：msgAreaGlobalX/Y 的 onAreaChange 在新结构下定位仍准
6. **@提及 / 发送 / 图片视频 / 轮询 / dmRefreshSignal** 回归
7. **embedded 分栏不回归**（MessagePage dmSplit 右栏走旧分支）
8. bottomBarInsetVp 底部避让不变（输入栏 padding 逻辑不动）

## 验证方式

编译（hvigorw assembleHap）→ 真机 Run → 按上面 8 项清单逐项验证 → 编译告警无新增。
