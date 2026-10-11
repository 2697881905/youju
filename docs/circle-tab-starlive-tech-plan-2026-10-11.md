# 圈子 Tab「星图 Live」技术实现方案

> 版本：v1.0 · 2026-10-11
> 上游文档：`docs/circle-tab-starlive-redesign-plan-2026-10-11.md`（产品方案）
> 原型：`design/circle-tab-redesign-prototype.html`（方案二 · 星图 Live）
> API 依据：DevEco 内置 SDK（`compatibleSdkVersion 6.0.0(20)`，target 26.0.0）本地 d.ts 核验 + 华为开发者文档

---

## 0. 选型总原则

1. **系统组件优先**：能用 ArkUI 内置组件/能力绝不自绘；自绘仅限「轨道弧线、金环脉冲」这类 Shape 级图元（仍属声明式组件，非 Canvas）；
2. **红线遵守**：动画只改 transform/opacity/scale/rotate + 属性动画，不用 width/height 布局属性；禁 WebView/Canvas 模拟；
3. **复用既有资产**：`CircleOrbitCanvas` 三环引擎、motion token、HdsNavigation 标题栏、Pressable、design tokens 全保留；
4. **深浅色**：全部走 `resources/base|dark` 的 ds_ 色对，零硬编码。

### 关键 API 核验结果（本机 SDK 实测存在）

| API | 位置 | 用途 |
|---|---|---|
| `bindSheet`（detents/shouldDismiss/onHeightDidChange） | `common.d.ts` | 深空目录半模态 |
| `keyframeAnimateTo` | `@ohos.arkui.UIContext` | 降落/点亮编舞 |
| `renderGroup(true)` | `common.d.ts` | 星图合成组性能优化 |
| `sharedTransition` / `geometryTransition` | `common.d.ts` | 行星↔降落页一镜到底 |
| `backdropBlur` | `common.d.ts` | 目录/预览卡毛玻璃 |
| `Badge` | `badge.d.ts` | 未读角标 |
| `SymbolGlyph` | `symbolglyph.d.ts` | 探索按钮/空态图标 |
| `Circle`/`Path`/`Shape` | `circle.d.ts`/`path.d.ts` | 轨道线/光晕/金环 |
| `Swiper` | `swiper.d.ts` | 降落页帖子流横滑（备选） |
| `PanGesture` + `expectedFrameRateRange` | `common.d.ts` | 引力拖拽 + 高刷适配 |
| `perspective`（rotate 参数） | `common.d.ts` | 降落俯冲 3D 感（可选） |

> HDS Kit 结论（前序已实证）：`HdsListItemCard`/`HdsListItem` 卡面不可控（内部白底、cardBackgroundColor 三种入参形态均静默无效），**本方案不再使用 HDS 卡片组件**，仅保留 `HdsNavigation` 标题栏体系。

---

## 1. 页面架构（组件安排）

```
CircleTab.ets（壳：HdsNavigation 保留）
└── Stack
    ├── StarMapPage.ets          ← 新建：星图页根容器（原 galaxy 区 + 全屏化）
    │   ├── StarFieldBackground  ← 泛光渐变 + 星尘（Column.radialGradient + 循环 Circle，现有 starDots 演进）
    │   ├── OrbitRing × 3        ← 系统组件：Circle().stroke()（现有 OrbitRingLayer 演进：虚线→实线微光）
    │   ├── PlanetNode × N       ← 新建组件：Stack{ TagIcon + Badge + 金环Shape } + PanGesture
    │   ├── CenterMe             ← 保留：头像 + 呼吸光环（Circle 动画）
    │   ├── SeedLayer            ← 新建：星子层（绝对定位 Circle + 透明度编舞）
    │   ├── ExploreButton        ← 系统：SymbolGlyph + bindSheet 触发
    │   ├── LandingOverlay       ← 新建：降落页（@State 控制显隐，非路由页）
    │   │   └── List/LazyForEach ← 帖子流（复用 PostCard 精简版）
    │   ├── SeedPreviewCard      ← 新建：星子预览卡（backdropBlur）
    │   └── GravityToast         ← 系统：promptAction.showToast 或自绘浮层（带 emoji）
    └── ExploreSheet（bindSheet 内容 Builder）
        ├── Search               ← 系统：Search 组件
        ├── List(分组) + ListItem ← 系统：目录列表
        └── CreateForm           ← 系统：TextInput + Chip 自绘(样式) + Button
```

**删除**：`CircleSelectionCard.ets`（功能并入 LandingOverlay）。
**演进**：`CircleOrbitCanvas.ets` → `StarMapPage` + `PlanetNode`（手势骨架、三环角度、惯性、自转 tick 逻辑原样迁移，不重写）。

---

## 2. 逐机制技术实现

### 2.1 星图底盘

| 元素 | 实现 | 选型理由 |
|---|---|---|
| 轨道线 | `Circle().fill(None).stroke(色).strokeWidth(1)`，深色加 `.shadow({radius, color})` 微光 | 系统图元，现有代码仅改 dash→实线 |
| 行星 | `Stack{ TagIcon(现有SVG) + 金环 + Badge }`，`.position()` 极坐标 | 复用现有 OrbitPlanet 组件结构 |
| 暗星 | `.opacity(0.42).grayscale(0.45)`（属性动画过渡） | 纯属性，合规 |
| 活跃光晕 | `.shadow()` + `.animation(呼吸)` 或外层 Circle scale 脉冲 | shadow 静态、scale 动画合规；避免 filter 动画 |
| 金环（已加入） | 外层 `Circle().stroke(ds_warm).strokeWidth(1)`，`.scale/.opacity` 入场 | 系统图元 |
| 未读角标 | 系统 `Badge({count, position})` | 原生角标 |
| 公转 | 保留：每层 `planetLayer.rotate({angle})` + 行星反向 rotate 保持直立 | 现有引擎，16ms tick |
| 性能 | 星图根 Stack `.renderGroup(true)`；行星层 `expectedFrameRateRange {min:30, expected:60, max:120}` | SDK 已核验 |

### 2.2 降落 LANDING（一期核心）

**转场方案（推荐 A，备选 B）**：

- **方案 A · 同层覆盖 + geometryTransition（一镜到底）**：
  行星与降落页头部圈子图标设同一 `geometryTransition(id)`，降落时行星组件 `visibility` 切换 + 降落层 `TransitionEffect.move(TransitionEdge.BOTTOM)` 入场；星图整体 `scale(2.8, {centerX:行星坐标}) + opacity(0.16)` 退场（650ms，`MotionCurves.springSoft` 同族曲线）。
  ✅ 全 transform/opacity；无路由栈污染；起飞=反向播放。
- **方案 B · Navigation 子页 + sharedTransition**：把降落页做成 `pages/CircleLanding` 注册进现有 Navigation（项目已用 HdsNavigation/NavDestination 体系），`sharedTransition(circleId)` 做行星↔页头共享元素。
  ✅ 转场更「系统级」；⚠️ 需处理返回手势与 Tab 切换的状态清理。

**一期先 A**（改动小、可控），二期视体验升级 B。

**帖子流「点灯」编舞**：`keyframeAnimateTo` 对每张卡片 stagger 90ms：`opacity 0→1 + translateY 14→0`（曲线 `MotionCurves.emphasized`）。数据：`listPosts({tag, sort:'latest', limit:6})`（现有 API）。

**加入按钮**：复用 `CircleDetailView` 的 follow/unfollow 逻辑（`followTag/unfollowTag` + 登录门禁 + `circleMembershipVersion` 广播），抽成 `useCircleMembership` 工具或在 Landing 内联调用同一 api 层。

**加入编舞**：成功后 `PlanetNode.playIgnite()`：`keyframeAnimateTo` 行星 scale 0.55→1.38→1 + 金环 opacity/scale 入场；顶部计数 `CountRoll`（现组件复用）。

### 2.3 引力调节（二期）

- **手势**：`PlanetNode` 上挂 `PanGesture({distance:4})`；`onActionStart` 冻结全局自转（现有 `autoOrbitEnabled` 机制扩展 `freezeAll`），`onActionUpdate` 把触点坐标换算为**相对星图中心的极坐标 (r, θ)** → 更新行星 `position` + 该环 `ringAngle` 同步（行星"骑"在环上走）；`onActionEnd` 按 r 吸附最近轨道（88/165/238 对应现有 `radiusForRing`），`animateTo` 弹性回位（`MotionCurves.springSettle`）。
- **冲突处理**：行星 Pan 与环拨动 Pan 同宿主——行星命中区（disc+8vp）优先消费（`HitTestMode.Block`），空白区仍走现有按环拨动；拖拽中 `onClick` 不触发（跟手 >8vp 判定，原型同款）。
- **未加入**：吸附回原轨道 + 弹引导（`promptAction.openCustomDialog` 或自绘浮层）→「去加入」触发降落。
- **数据**：`UserTagPref{userId,tagName,weight,updatedAt}` 新表 + `POST /v1/tags/:name/weight`；`listFollowedTags` 返回改为 `[{name, weight}]`（兼容旧结构）。
- **消费端**：首页推荐权重与通知策略读取 weight（后端排期，客户端仅写入 + 星图半径回显）。

### 2.4 星子（二期）

- **数据**：一期简化 = 进页面时 `listPosts({limit:12, sort:'latest'})` 取最新帖，映射到所属行星；三期接推送/轮询。
- **渲染**：`SeedLayer` 维护 `@State seeds: SeedItem[]`（id/极坐标/寿命），每个星子 = 10vp `Circle` + `.shadow` 光晕 + `opacity/scale` 呼吸（keyframe 循环）；上限 6 颗、单圈 1 颗、15s 自灭（`setTimeout` 清理，参照现有涟漪定时器模式，`aboutToDisappear` 全清）。
- **点击**：预览卡 = `Stack` 浮层 + `backdropBlur(20)` + `TransitionEffect.OPACITY.combine(scale)`；「看全文」进 LandingOverlay 的 READ 模式（复用帖子详情渲染 `DetailPostContent` 或跳 `PostDetailView`——一期跳现有详情页，零新轮子）。
- **金色星子（每日一帖）**：`GET /v1/posts/daily`（现有），`SymbolGlyph` ✦ 标识。

### 2.5 深空目录（一期）

- **容器**：`bindSheet($$this.showExplore, this.ExploreSheetBuilder(), { detents:[SheetSize.MEDIUM, SheetSize.LARGE, 0.84*vh], dragBar:true, blurStyle: BlurStyle.COMPONENT_THICK, showClose:true })` —— 三档吸附、毛玻璃、拖拽条**全部系统自带**，比原型手写的更稳。
- **搜索**：系统 `Search` 组件（`search.d.ts`），`onSubmit/onDidChange` 过滤目录。
- **列表**：`List` + `ListItemGroup`（按分类分组，系统分组头样式）+ `ListItem`（emoji + 名 + 简介 + 加入 Button）。数据：`GET /v1/tags?all=1`（后端改造项）。
- **加入**：目录内按钮直接 `followTag` → 关 sheet → 星图 `addPlanet`（点亮编舞）。
- **创建**（三期）：`TextInput` × 2 + 分类 chips（`Button` 组自绘样式）→ `POST /v1/tags`。

### 2.6 探索入口按钮

`SymbolGlyph($r('sys.symbol.sparkles'))` + 药丸容器（现有 `Pressable` + glass 样式），`onClick` 置 `showExplore=true`。

---

## 3. 状态与数据流

```
CircleTab
  @State circles: CircleTag[]        // 现有：CIRCLE_META × 服务端 Tag 合并
  @State weights: Map<name, 1|2|3>   // 二期：来自 listFollowedTags 扩展
  @State unread: Map<name, number>   // 二期：GET /v1/tags/unread
  @State landingCircle: CircleTag|null  // 降落态（null=星图）
  @State seeds: SeedItem[]           // 二期
  @State showExplore: boolean        // bindSheet
  // 派生：行星显示集 = joined ∪ active ∪ TopN（星图≠全量）
```

- 加入/退出/权重变更统一走 `circleMembershipVersion` AppStorage 广播（现有机制），保证详情页与星图一致；
- 页面切走：停自转/星子定时器（现有 `onActiveTab` 扩展）。

## 4. 后端接口清单（客户端视角）

| 接口 | 状态 | 客户端调用点 |
|---|---|---|
| `GET /v1/tags?all=1&keyword=` | 改造 | 目录/搜索 |
| `POST /v1/tags/:name/follow` / `DELETE` | 已有 | 降落页/目录 |
| `GET /v1/posts?tag=&sort=latest&limit=6` | 已有 | 降落页帖子流 |
| `GET /v1/posts/daily` | 已有 | 金色星子 |
| `POST /v1/tags/:name/weight` | **新增** | 引力吸附后 |
| `GET /v1/tags/unread` | **新增**（二期） | 角标/星子 |
| `POST /v1/tags`（创建） | **新增**（三期） | 创建表单 |

## 5. 分期与工作量（客户端）

| 期 | 内容 | 主要文件 |
|---|---|---|
| **一期** | 星图全屏化 + 底盘视觉（实线弧/暗星/金环/Badge 占位）+ LandingOverlay（方案A转场+帖子流+加入编舞）+ bindSheet 目录 + 删 CircleSelectionCard | `StarMapPage.ets` `PlanetNode.ets` `LandingOverlay.ets` `ExploreSheet.ets` `CircleTab.ets` |
| **二期** | 引力拖拽 + weight 读写 + 星子系统 + 未读角标 + READ 浮层 | `PlanetNode.ets`(手势) `SeedLayer.ets` api 层 |
| **三期** | 创建圈子 + activeScore 星等 + 探索点亮 | `ExploreSheet.ets`(表单) |

## 6. 风险与降级

| 风险 | 对策 |
|---|---|
| bindSheet 与 HdsNavigation 标题栏手势冲突 | 目录期间禁标题栏滚动联动（`bindToScrollable` 已有开关模式）；真机回归 |
| geometryTransition 在 TabContent 内表现不稳 | 降级为纯 TransitionEffect 入场（无共享元素），视觉损失小 |
| 24+ 行星 renderGroup 后仍掉帧（低端机） | 行星显示数 TopN 收敛（默认 ≤18）；自转 tick 在 `ringDragging/landing` 时停 |
| 拖行星误触环拨动 | 命中区 Block + 8vp 阈值；灰度开关 `gravityEnabled`（AppStorage 设置项） |
| 未登录用户 | 星图可看（公开数据），引力/加入触发登录引导（复用现有门禁） |

## 7. 验收（对齐产品方案 §10，补技术项）

- [ ] 60fps：星图自转 + 12 行星 + 降落转场帧率采样（SmartPerf/HiDumper）
- [ ] 深浅色 × 375vp/平板/字体放大 三档走查
- [ ] bindSheet 三档拖拽与 detents 吸附正常
- [ ] 加入/退出三端一致（星图/详情页/已加入计数）
- [ ] 定时器/动画在 Tab 切走与页面销毁时零泄漏（现有 aboutToDisappear 清单扩展）
- [ ] 无 Canvas/WebView；动画属性白名单审查通过

---

## 附：原型 → ArkUI 映射速查

| 原型（HTML） | ArkUI |
|---|---|
| `.planet` 绝对定位 + rAF rotate | `position()` + 层 `rotate()`（现有引擎） |
| `#s2seeds` 光点 + seedPulse | `Circle` + `keyframeAnimateTo` 循环 |
| `.land` translateY 滑入 + holder scale(2.8) | `TransitionEffect.move` + `scale({centerX/Y})` |
| `.explore` 抽屉 | `bindSheet`（系统三档） |
| `.jring` 金环 | `Circle().stroke(ds_warm)` |
| `.star-seed.gold` 每日一帖 | 同上 + `SymbolGlyph` |
| `.grav-toast` | `promptAction.showToast`（或自绘浮层带 emoji 前缀） |
| localStorage 持久化 | 服务端 `userFollowTag`/`UserTagPref`（真机天然跨设备） |
