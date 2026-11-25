---
title: "post-shared-transition-plan.md"
id: markdown_798285c88467638f6a8dc28635ad6f33_330f0e2d8fb4300c6418b1cf0b113da67505655250320770
kb: 有据-YouJu
folder: "开发文档"
media_type: 7
tags: []
source: ima
exported_at: 2026-11-23T14:52:37.917Z
---
# 点击进入帖子「一镜到底」动画 — 开发计划

## 1. Summary

为目标：点击卡片进入帖子详情页时，卡片视觉**无缝放大变为详情页媒体区**，返回时自动反向缩回（一镜到底）。

- **机制**：ArkUI 原生 `sharedTransition` 共享元素转场（用户已确认），API 24（targetSdk 6.1.1）原生支持，无需 WebView/Canvas/快照。
- **范围**：每日一帖卡堆（`DailyPostDeck`）+ 推荐/关注流（`PostCard`）两种入口（用户已确认）。
- **原理**：源页（卡片媒体区）与目标页（详情页媒体区）挂**同一 shared id**，pushUrl/pop 时框架自动把源元素位置/尺寸插值到目标元素位置/尺寸；仅动 transform/opacity，符合工程「只动 transform/opacity 类属性」的硬约束。
- **无媒体（纯文字卡片）**：不挂 shared id，回退现页转场（不做强行映射）。

## 2. 现状分析（Phase 1 已探索）

| 文件 | 现状 | 与本任务的关系 |
|---|---|---|
| `entry/src/main/ets/pages/DetailPage.ets` | `loading` 态显示居中转圈；加载后渲染 工具栏 → Scroll[`DetailPostHeader` → 媒体(`DetailMediaCarousel`/`VideoPlayer`) → 内容 → 评论]；根节点 `.transition(buildPageTransition())`（透明+X12 位移动画） | 详情页 = 共享元素**目标页**；需提供「loading 期间的媒体占位」承载目标元素 |
| `entry/src/main/ets/components/DailyPostDeck.ets` | `DeckSlotCard` 卡面 `postFace()`（媒体区 4:3 + 底部信息条），外层位移/旋转层用各槽位弹簧；`curDepth()===0` 为顶卡；`inFlight` 为被推开的飞行卡；`hasMedia()`= videoCover/coverImage 任一非空 | 每日一帖**源元素**：仅顶卡、非飞行、有媒体时挂 shared id |
| `entry/src/main/ets/components/PostCard.ets` + `PostCardMedia.ets` | 双列信息流卡片；`PostCardMedia` 以 `aspectRatio=cardMediaAspectRatio(0.75)` Cover 展示封面/视频封面 | 推荐/关注流**源元素**：`PostCardMedia`（有图/视频时）挂 shared id |
| `entry/src/main/ets/utils/nav.ts` | `openPostDetail(id)` → 模块级变量 `detailPostId` → `takePostDetailId()`，详情页读取后清空 | 扩展为携带 `PostDetailIntent`（封面/标题/作者等），供详情页 loading 态即时渲染真实头部+媒体占位，**保证目标帧稳定不跳位** |
| `entry/src/main/ets/components/HomeTab.ets` | 每日一帖与推荐流 `onOpen` 都在此集中：`openPostDetail(id)+pushUrl('pages/DetailPage')` | 在此组装 intent（帖子对象齐全） |
| `entry/src/main/ets/utils/styles.ets` | `buildPageTransition()` = opacity + translate x 12 | 共享转场路径下详情页根改 fade-only，避免「整页平移 × 卡片放大」双动效打架 |
| `entry/src/main/ets/components/DetailMediaCarousel.ets` | 外层 Stack：width100% + `RadiusTokens.lg` + `.clip(true)`；高度随真实图片比例（默认 0.75） | 目标元素落点之一，需在其挂载 shared id |
| `entry/src/main/ets/components/VideoPlayer.ets`（使用处） | 详情页视频块：`Column.width('100%').aspectRatio(videoAspectRatio).borderRadius(12).clip(true)` | 目标元素落点之二，同挂 shared id |
| `design/tokens/motion.ets` | `MotionCurves.springRelease = springMotion(0.5,0.75)`；`MotionTokens.emphasis=460 / page=420` | sharedTransition 曲线/时长复用令牌 |

**关键事实**：
- 详情页布局顺序固定为「头部 → 媒体区」。loading 态用 intent 数据渲染**真实头部 + 媒体占位**，与加载完成后的头部/媒体帧完全一致 → 媒体区位置零跳变（详见 §4-A 帧稳定性设计）。
- 每日卡面媒体 4:3（`DECK_MEDIA_RATIO`）→ 详情媒体区默认 0.75：共享元素飞行中会发生「裁切随容器缩放」的自然拉伸（同 URL、同 Cover 模式），属预期的一镜到底观感，非缺陷。
- 同一帖子在每日/推荐流不同时出现在同一屏幕，且 id 统一为 `card-expand-{postId}`，源/目标两侧一致，无需区分来源。

## 3. 技术难度分析

| 难度项 | 等级 | 说明与对策 |
|---|---|---|
| A. intent 数据链路扩展（nav.ts → HomeTab → DetailPage） | 低 | 纯参数传递，可选参数向后兼容，现有调用方无需改动 |
| B. 源元素条件挂载 shared id（防重 id） | 中低 | `DeckSlotCard` 有 4 槽 + 飞行卡同时渲染，必须仅在 `curDepth()===0 && !inFlight && hasMedia()` 时挂 id；用 `if(cond) 加载带 id 的 builder，else 加载普通 builder` 二选一渲染，杜绝同一 id 多元素 |
| C. 目标帧稳定性（loading 占位 → 真实媒体同帧切换） | 中 | 核心难点。解法：intent 携带标题/作者/体裁等 → loading 态直接渲染**真实 DetailPostHeader**（非骨架）+ hero 媒体占位；数据到达后同一帧位换为 Carousel/VideoPlayer，共享 id 挂在外层容器，hero→真实媒体无位移跳变 |
| D. sharedTransition × 卡片祖先 transform 叠加 | 中低 | 每日卡外层有 translate/rotate/scale 弹簧。'静止点击'时均为恒等变换，框架按窗口坐标取源帧；若个别机型取到的是布局帧，起点会有 ≤几 px 偏差，可接受。飞行卡(inFlight)已排除，不受影响 |
| E. 页级转场与共享元素同时播放 | 低 | 详情页根 `.transition` 在共享路径换 fade-only（无 X 平移），单独 `.transition` 计算 |
| F. 返回反向还原 | 中低 | `TransitionType.Exchange` 自动反向；每日卡在静止点击后仍为顶卡原位 → 能落回；推荐流卡片仍在 Scroll 树中（ForEach 非懒加载）→ 元素存在。用户返回前滚走卡片的极端情况：共享元素仍飞回其布局位（可接受，有余量优化） |
| G. 空媒体回退 | 低 | 纯文字卡不挂 id，走原 `buildPageTransition()`，零回归 |
| H. curve 兼容性 | 低 | `sharedTransition` options.curve 支持 `ICurve`(springMotion)；若个别版本不接受 spring 则回退 `MotionCurves.emphasized`（cubicBezier），方案里已标注 |

**风险清单**：
1. 同页多个相同 shared id → 运行警告/动效异常：已用「条件 builder 二选一」规避（难度 B）。
2. 详情页 loading 媒体占位与加载后真实媒体帧不一致 → 闪跳：intent 数据渲染真实头部 + 统一默认 0.75 占位（难度 C 对策）。
3. 每日卡 4:3 → 0.75 飞行中的裁切变化：预期观感，非 bug（§2 关键事实）。
4. 老版本对 `springMotion` 注入 support：降级 `emphasized`（难度 H）。

## 4. 拟定变更

### 4-A `entry/src/main/ets/utils/nav.ts` — intent 传递
- 新增 `export interface PostDetailIntent { cover: string; title: string; genre: string; tags: string[]; authorName: string; authorAvatar: string; createdAt: string; }`（`cover` 为 `resolveDisplayImageUrl` 后的展示 URL，空 = 无媒体走原转场）。
- 模块级 `let postDetailIntent: PostDetailIntent | null = null;`
- 重载 `openPostDetail(id: string, intent?: PostDetailIntent)`（保留旧签名兼容所有现调用方）；新增 `takePostDetailIntent(): PostDetailIntent | null`（取后置 null，同 `takePostDetailId` 消费即清语义）。

### 4-B `entry/src/main/ets/components/HomeTab.ets` — 组装 intent
两处 `onOpen` 均新增 intent 组装（帖子对象齐全）：
- 每日一帖：`cover = videoCover !== '' ? videoCover : coverImage`（与 `DeckSlotCard.mediaUrl()` 同一取值口径），`title/genre/tags/user?.nickname/user?.avatar/createdAt`。
- 推荐/关注流：`cover = videoUrl!=='' ? (videoCover||coverImage) : coverImage`（与 `PostCardMedia` 展示口径一致）；文案字段同上。
- `openPostDetail(post.id.toString(), intent)`；无媒体时传 `cover: ''`（或整个 intent 置 null）。

### 4-C `entry/src/main/ets/components/DailyPostDeck.ets` — 源元素（每日）
- `DeckSlotCard` 增 `sharedId()`：仅当 `post.id !== undefined && curDepth()===0 && !inFlight && hasMedia()` 返回 `'card-expand-' + post.id`，否则 `''`。
- 卡面渲染改为二选一 builder：`if (this.sharedId() !== '') { this.sharedFace() } else { this.postFace() }`；`sharedFace()` = 与 postFace 同构的外层 Stack 追加 `.sharedTransition(id, { duration: MotionTokens.emphasis, curve: MotionCurves.springRelease, zIndex: 45 })`。
- 飞行卡/下层槽位不满足条件 → 自然走普通分支，**无重复 id**。

### 4-D `entry/src/main/ets/components/PostCardMedia.ets` — 源元素（推荐/关注流）
- 卡片有图或视频（`imageUrl/videoUrl/videoCover` 任一非空）且 `post.id` 存在时：媒体 Image 追加 `.sharedTransition('card-expand-' + id, { duration: MotionTokens.emphasis, curve: MotionCurves.springRelease, zIndex: 45 })`。
- 纯文字卡不挂。
- 注意：`PostCardMedia` 无 `post`，需新增 `@Prop sharedId: string = ''`，由 `PostCard`（其有 `postId()`）注入；`PostCard` 内 `hasCover()` 判断有媒体才传。

### 4-E `entry/src/main/ets/pages/DetailPage.ets` — 目标元素 + loading 占位
1. `aboutToAppear` 读取 `this.intent = takePostDetailIntent()`（`@State`），`pid` 已知后在 `post.isLoaded` 前即可构造 `sharedId = intent && intent.cover !== '' ? 'card-expand-' + this.pid : ''`。
2. **loading 分支**：`intent.cover !== ''` 时不再渲染居中转圈，改为：
   - `DetailPostHeader`：直接用 intent 文案（title/genreLabel=genreMeta(intent.genre).label/tags/authorName/authorAvatar/createdAt，`onOpenAuthor` loading 期空操作）——与加载后**同数据同帧**；
   - `DetailHeroMedia`（新组件，见 4-F）：Image(intent.cover) + `width('100%').aspectRatio(cardMediaAspectRatio 0.75).backgroundColor(sunken).borderRadius(RadiusTokens.lg).clip(true)` + `.sharedTransition(sharedId, 同 opts)`；
   - 下方保留加载提示/骨架（轻量）。
   - 其余情况（无 intent）维持原居中转圈。
3. **加载完成分支**：媒体区三态统一挂 `sharedTransition(sharedId…)`：
   - 有视频：现有 VideoPlayer 外层 Column 追加；
   - 有图：`DetailMediaCarousel` 外层 Stack 追加；
   - 无媒体：不挂。
   - 同一时刻只渲染其一 → 无重复 id。
4. **根节点转场**：`.transition(sharedId !== '' ? 新建 fade-only TransitionEffect : buildPageTransition())`，避免整页 X 平移与卡面放大叠加。

### 4-F 新增 `entry/src/main/ets/components/DetailHeroMedia.ets`
轻量展示组件：`@Prop url: string; @Prop sharedId: string = '';` 渲染幅宽封面（0.75、`RadiusTokens.lg`、clip、黑底），有 sharedId 时挂 `.sharedTransition`。是 loading 期目标元素的唯一载体。

### 4-G `entry/src/main/ets/utils/styles.ets`
新增 `export function buildFadePageTransition(): TransitionEffect`（纯 opacity，约 220ms `Curve.FastOutSlowIn`），供 4-E 根节点切换。不改动 `buildPageTransition`（其他页面继续使用）。

## 5. 决策与假设
- 每日卡面 4:3 → 详情媒体 0.75 的飞行中裁切变化，视为一镜到底预期观感，不做额外等比约束。
- `sharedTransition` 曲线用 `MotionCurves.springRelease`（与卡堆飞出同一弹性语言）；若运行时发现 spring 不被共享转场接受 → 替换为 `MotionCurves.emphasized`。
- 目标帧定位维持现布局「头部 → 媒体区」，hero 位于头部下方；loading 与加载后头部同数据 → 媒体区垂直位置稳定。
- 纯文字卡、无媒体帖、外部链接落地详情：均回退原转场，零行为变更。
- intent 仅内存态（同 `takePostDetailId` 消费即清），不落盘。

## 6. 验证步骤
1. `hvigor` 或 DevEco Studio 编译通过（无 `sharedTransition` 重复 id / 类型告警）。
2. 模拟器手测——每日一帖：点击有媒体顶卡 → 卡面放大连贯进入详情媒体区、无闪屏/跳位；内容到达后 hero 原位切换为轮播；返回 → 媒体区缩回原卡。
3. 推荐/关注流：点击带封面卡片同样生效；纯文字卡仍为原转场。
4. 快速路径：点击后立刻返回（载入中 pop）不报错、不闪白。
5. 每日卡连读（滑走/飞行卡）后再进详情：飞行卡不挂 id，无动效冲突。
6. 回归：搜索/圈子/收藏夹等其它 `openPostDetail` 入口不受影响（无 intent 走原路径）。
