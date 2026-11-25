---
title: "nav-card-one-shot-transition-plan.md"
id: markdown_798285c88467638f6a8dc28635ad6f33_3d60c81c2ebc28583e6090d626a293327505655250320770
kb: 有据-YouJu
folder: "开发文档"
media_type: 7
tags: []
source: ima
exported_at: 2026-11-23T14:52:37.917Z
---
# 首页卡片「一镜到底」重构：Navigation + customNavContentTransition（教程原版）

## 1. Context（为什么做）

现状：首页（推荐/关注流 `PostCard`、每日一帖 `DailyPostDeck`）→ 帖子详情走 router 页面 + `sharedTransition` 共享元素。该体系经多轮修补仍存在脆弱点（图例拉伸、退出逆飞变形、getter 编译丢失、目标帧与真实比例内容不一致等）。

用户要求按鸿蒙开发者社区「多模态页面转场动效」教程**重构卡片一镜到底**：将首页入口迁入 **Navigation**，使用 **`customNavContentTransition` 自定义导航转场** + **`componentSnapshot` 截图**避免转场白屏，实现从卡片到详情无缝放大/缩回。

架构边界（用户已确认）：**首页迁 Navigation（教程原版）**；其它 8 个 router 入口（搜索/圈子/他人主页/我的/废纸篓/收藏夹/聊天分享/管理页）保持 router 体系不变。

## 2. 现状分析（已探明）

- 工程是 router 页面体系：`Index.ets` 为 `@Entry`（根 Stack，内 HdsTabs/Tabs 五 Tab，**无 Navigation**）；`main_pages.json` 仅 `pages/Index`、`pages/DetailPage`。
- 详情入口共 9 处 pushUrl `pages/DetailPage`：HomeTab（feedPost + DailyPostDeck）、ProfilePage、UserProfilePage、CircleDetailPage、SearchResultPage、ChatPage、TrashBoxPage、BookmarkFolderDetailPage、ReportAdminPage。
- `DetailPage.ets` 内直接使用 `getRouter()`：push UserProfilePage（作者）、back（工具栏/删除后）。
- 详情/卡片共享元素现状：`DeckSlotCard.sharedId()/mediaFace()/postFace()`、`PostCardMedia.coverFaceShared()`、`DetailPage`（intent/sharedId/sharedAspect/holdHero/hero/mediaSlot/pageEnterTransition/HERO_HOLD_MS）、`MotionShared`、`nav.ts` 的 `PostDetailIntent`。
- 工程内无 Navigation/NavDestination/geometryTransition 现有用法；`componentSnapshot` 无现有用法（新增）。
- `customNavContentTransition`（API 11+）、`componentSnapshot`、`componentUtils.getRectangleById`（API 12+）在工程 SDK 24（API 6.1.1）均可用。

## 3. 方案总览

采用「**主框架 Navigation 根 + 详情链双壳（router 壳保留旧 sharedTransition / nav 壳走新一镜到底）**」策略：

1. **Index 根 = Navigation**：把现有主框架（Tabs 树 + 悬浮底栏）作为 Navigation 首页内容；全屏 Navigation 容器挂 `customNavContentTransition` + 提供 `NavPathStack`。其它 Tab/页面行为不变。
2. **首页两卡片入口改走 Navigation**：点击卡片 → 记录卡片媒体帧（`componentUtils.getRectangleById`，提前给媒体块绑 `id()`）→ 截卡面图（`componentSnapshot.get`）→ `navStack.pushPathByName('PostDetail', 参数)`。
3. **详情主体抽公共组件 `PostDetailView`**，两壳复用：
   - router 壳 `pages/DetailPage.ets`（8 个旧入口）：保留现有 sharedTransition 一镜到底，行为零变化；
   - nav 壳 `pages/PostDetailDestination.ets`（NavDestination）：承接首页卡片，跑**新一镜到底**（截图/帧插值 + 真实内容淡入接管；返回反向缩回）。
4. **详情链二级跳转 nav 化闭环**（防止"从 Navigation 内 push router 页导致返回链断裂"）：`UserProfile`、`CircleDetail`、`ChatPage`、`MyFollow`、`Login` 五个页面各做「主体抽公共组件 + router 壳(保留) + nav 壳(新增)」。详情(nav)/用户主页(nav) 内二级跳统一走 Navigation `pushPathByName`。
5. 其余 router 页面（发布流/设置/搜索面板/收藏等）不迁移：它们只从主框架（Navigation 首页）或其 router 子页进入，返回链天然正确。

## 4. 新一镜到底转场机制（customNavContentTransition + 截图）

进入（首页卡片 → 详情）：
1. 卡片点击时（`HomeTab.onOpen`）：`componentUtils.getRectangleById(mediaId)` 取卡片媒体块屏幕帧 `srcFrame`（vp）；`componentSnapshot.get(mediaId, cb)` 得到 `PixelMap`。
2. `navStack.pushPathByName('PostDetail', { postId, intent, srcFrame, snapshot })`。
3. `PostDetailDestination` 首帧渲染「快照层」：`Image(pixelMap)` 从 `srcFrame` 做 `translate/scale`（纯 transform，用 `.translate({x,y}).scale({x,y})` 计算使图片视觉对齐 srcFrame），随后 `animateTo(emphasized)` 复位到详情媒体目标帧；真实内容（复用 hero/媒体）在其下加载，加载完成后快照层仅透明度淡出 → 无白屏、无跳变。
4. 转场由 `customNavContentTransition` 的 `NavigationAnimatedTransition.transition` 托管（contentAppear/contentDisappear 时序），返回（pop）反向执行：对当前详情媒体区截图 → 动画缩回 `srcFrame` → 完成 pop。

工具：新增 `utils/navigationTransition.ets`：
- `CustomNavigationUtil`（借鉴教程 CustomNavigationUtil）：Map 管理各页面 CustomTransition 对象，页面注册/注销；
- 提供「快照一镜到底」转场对象：持有 `srcFramePixelMap/操作`，在 `transition` 回调中驱动属性动画；
- 复运动效令牌：时长 `MotionTokens.page`，曲线 `MotionCurves.emphasized`（无过冲丝滑进入）。

## 5. 关键文件与改动

### 5.1 框架层
- `entry/src/main/ets/pages/Index.ets`：根 Stack 内容包一层 `Navigation(this.pageStack) { 原主框架 }`；`hideTitleBar(true)`；挂 `.customNavContentTransition(...)` + `.id('mainNav')`；`privacyAgreed !== '1'` 分支照旧不渲染。提供 `navPathStack` 实例。
- 新增 `entry/src/main/ets/utils/navigationTransition.ets`：转场工具类 + `NavigationAnimatedTransition` 实现 + 快照 `PixelMap` 管理。

### 5.2 卡片源（首页两条入口）
- `entry/src/main/ets/components/PostCardMedia.ets`：媒体块绑定 `<Image>.id('cardMedia-' + postId)`（仅画面组件），供取帧/截图。
- `entry/src/main/ets/components/DailyPostDeck.ets`：`DeckSlotCard` 媒体块绑定 `.id('deckCardMedia-' + post.id)`（`mediaFace` 内 Image）。
- `entry/src/main/ets/components/HomeTab.ets`：
  - `feedPost` onOpen 与 DailyPostDeck `onOpen`：改为「取帧+截图 → `getUIContext().getNavigation('mainNav').pushPathByName('PostDetail', {...})`」；`PostDetailIntent` 组装逻辑保留复用。
  - 截图失败/无媒体：降级为直接 push（详情仍能正常渲染，仅丢失快照层）。

### 5.3 详情抽壳与双壳
- 新增 `entry/src/main/ets/components/PostDetailView.ets`：从 `DetailPage.ets` 迁移主体（状态、load、build、动作回调），去掉 `@Entry` 依赖；导航类副作用改造为注入式回调：
  - `onBack?: () => void`（router 壳=router.back；nav 壳=navStack.pop）；
  - `onOpenUserProfile?: (userId) => void`（router 壳=router.pushUrl('pages/UserProfilePage')；nav 壳=pushPathByName('UserProfile', {...})）；
  - 其余 `getRouter()` 用途统一收敛到这两个回调 + intent 参数（模块级 `openPostDetail`/`takePostDetailIntent` 机制对 nav 壳继续可用或改用 nav 参数）。
- `entry/src/main/ets/pages/DetailPage.ets` 收窄为 router 薄壳：`@Entry { PostDetailView({ onBack, onOpenUserProfile: router 实现 }) }`，**保留全部现有 sharedTransition 逻辑（把现有 sharedId/hero/holdHero 等留在此壳或 PostDetailView 内按 isNav 分支）**——为降低交付风险，router 壳走「旧 sharedTransition 路径」，nav 壳走「新快照路径」，两个模式由壳注入 `transitionMode: 'shared' | 'snapshot'` 在 PostDetailView 内分别渲染。
- 新增 `entry/src/main/ets/pages/PostDetailDestination.ets`：`NavDestination` 包裹 `PostDetailView`（`transitionMode:'snapshot'`），负责快照层渲染与转场时序；注册到 `CustomNavigationUtil`。

### 5.4 详情链二级闭环（nav 双壳）
模式统一为「主体抽公共组件 `components/XxxView.ets`（去 @Entry，内部导航走注入回调）+ router 薄壳 `pages/Xxx.ets`（保持 main_pages 路径不变）+ nav 壳 `pages/XxxDestination.ets`」：
- `UserProfilePage` → `UserProfileView` + `UserProfileDestination`
- `CircleDetailPage` → `CircleDetailView` + `CircleDetailDestination`
- `ChatPage` → `ChatView` + `ChatDestination`
- `MyFollowPage` → `MyFollowView` + `MyFollowDestination`
- `LoginPage` → `LoginView` + `LoginDestination`
- nav 壳内的二级跳转统一 `pushPathByName`；router 壳保持原 router 调用。`nav.ts` intent 机制继续供两套使用。

### 5.5 清理与兼容
- 不动 `main_pages.json`（`pages/DetailPage` 等 router 路径全部保留）。
- 首页卡片入口切换到 Navigation 后，`sharedTransition` 逻辑在 deck/PostCardMedia 上**继续保留**（router 壳详情仍依赖同一 id 源），避免双体系互踢；详情 nav 壳不启用 sharedTransition。

## 6. 实施顺序（阶段化）

- **P1 框架 + 主链**：navigationTransition.ets 工具 → Index Navigation 根 → 卡片入口（取帧/截图/pushPath）→ PostDetailView 抽取 + 双壳 + 快照一镜到底（进入/返回）。
- **P2 二级闭环**：UserProfile / CircleDetail / Chat / MyFollow / Login 五页面抽壳 + nav 壳 + 跳转回调化。
- **P3 收尾验证**：编译、真机回归详情链二级跳转返回路径、老 router 入口（搜索/圈子/我的等）回归。

## 7. 风险与降级

| 风险 | 对策 |
|---|---|
| `componentSnapshot.get` 对 Image 组件异步/失败 | 截图回调失败 → 走无快照降级（详情仍可正常渲染），不影响功能 |
| `getRectangleById` 帧与视觉帧差（滚动中点击） | 点击瞬间取帧；卡片静止态取帧；误差 ≤ 数 vp 不影响观感 |
| Navigation 容器拦截主框架点击（透明首页） | 首页即主框架本身（无叠加层）；Navigation 首页承载 Tabs，无触摸穿透问题 |
| 双壳两套转场并存复杂度 | router 壳零改动（旧路径原样）；nav 壳独立实现，隔离测试 |
| 工程无 Navigation 先例 | 按官方文档 API 11+ 用法实现，P1 先行小步验证编译 |

## 8. 验证

1. `hvigorw assembleHap --mode module -p buildMode=release` 编译通过、无新告警。
2. 真机主链：首页推荐流/每日一帖点击带封面卡 → 卡片截图从原帧无缝放大进详情、无白屏/无拉伸；返回缩回原位。视频/纯文字卡 → 降级路径平滑进入。
3. 详情链二级：详情 → 作者主页 →（发消息/关注列表 → 返回逐层回详情）；详情 → 正文圈子 → 返回；登录引导返回原页。
4. 老入口回归：搜索/圈子详情/我的/收藏/废纸篓/管理/聊天分享进详情仍为旧动画且返回正常；发布流/设置等 router 页面不受影响。
5. 快速路径：进入详情立即返回、滚动后返回、切前后台后返回，无崩溃/白屏/错位。

*注：所涉「我选的两个前端插件（frontend-design / uicraft）」为 web 向技能，不映射 ArkUI .ets，本方案全部采用工程既有 design/tokens 体系实现。*
