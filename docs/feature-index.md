# 「有据」功能索引

从项目长期记忆迁出的功能清单，避免占用记忆注入额度。规则类约束仍在 `.workbuddy/memory/MEMORY.md`，排障过程在 `.workbuddy/memory/YYYY-MM-DD.md`。

## 一、设计系统（entry/src/main/ets/design）

| 目录 | 内容 |
| --- | --- |
| `tokens/` | `color`、`type`、`space`（含 `LayoutTokens`）、`radius`、`shadow`、`motion`、`icon` |
| `components/` | SegmentedControl、ChipRow / ChipItem、BaseCard、BottomTabBar / BottomTabItem、EmptyState、IconTile、StatRow、DesignButton、ImmersiveSurface、GlowInput、MessageRow |
| `motion/` | Pressable、SharedSlide、Reveal、Collapse、CountRoll、Skeleton、SpringPanel |

`design/preview/` 目录**已删除**（2026-09-15）：它是「设计系统预览」功能的残留——该功能的设置入口在 `4658a0e` 就已移除，但预览组件与两个 `@Entry` 预览页一直留着（详见 `docs/dead-code-cleanup.md`）。

⚠️ `PollBlock` / `AuthorRow` **已随预览壳一并删除**（2026-09-15）：它们曾用于真实页面 `components/PostCard.ets`，在 `257dfd6`（UI 体系调整）里被弃用后只剩预览壳在引用；预览壳删除后成为孤儿，已按「删干净」原则一并移除（git 历史可恢复）。

`DesignButton` 四个变体：`primary`（品牌实底，主级 CTA）/ `ghost`（透明 + 品牌描边）/ `glass`（`elevated` 底 + 玻璃描边，仅剩 `CircleOnboarding` 在用）/ `outlined`（透明 + `barBorder` 描边 + `pill` 圆角，2026-09-14 新增）。

主/次配比约定：**主级 CTA 用 `primary`**（`CircleOnboarding` 确认、`PublishTagPanel` 完成、`PublishPreviewPage` 确认发布）；次级用 `outlined`；破坏性操作目前也用 `outlined`（设计系统暂无 danger 变体）。

### 品牌资源

- 应用 Logo 源文件：`design/youju-logo-concepts/youju-v2-citation-anchor.png`（深墨引文括号 + 蓝核验锚点 + 白圆角方底），已用于 `AppScope` + `entry` 共 4 处；运行时资源为 `$r('app.media.logo')`（LoginPage / AboutPage 在用）。
- 早期书本 Logo 归档在 `design/logo-concepts/`。

### 图标着色体系

`resources/base/media` 共 97 个 SVG，两套机制并存：

| 机制 | 数量 | 适用 | 说明 |
| --- | --- | --- | --- |
| `stroke="currentColor"` + 使用处 `.fillColor()` | 44 | 需运行时着色 | 38 个 `tag_*`（按圈子配色）+ `video_play` + 2026-09-14 新收的 5 个（`close_x` / `chevron_right` / `publish_*_outline`） |
| 写死颜色（`#3F3A2E` / `#B9B09A`），配 `resources/dark/media/` 深色板 | 52 | 固定语义色 | `action_*` / `nav_*` / `set_*` / `status_*` / `share_*` / `genre_*` / 品牌 Logo、`close_x_white` 等 |
| 无描边 | 1 | — | `launch_placeholder` |

约定：**新增单色线条图标一律用 `currentColor`**，并在每个使用处显式 `.fillColor(token)`；只有在需要「同一图标两种固定色」时才用双份板（浮层白图标属例外）。⚠️ `utils/settingsIcons.ets` 的 `resolveSettingsIcon` fallback 指向 `chevron_right`（已转 `currentColor`），未带 `fillColor` 的调用点会失效。

`outlined` 描边规格（透明底 + 1vp `barBorder` 描边 + `RadiusTokens.lg` 圆角 + 无阴影）已在 7 处采用，兼容容器类（`SegmentedControl({ outlined: true })`）与按钮类（`DesignButton({ variant: 'outlined' })`）两种入口；完整规格、采用清单与已知风险见 `docs/home-segmented-control-style-audit.md`。

### 弹窗面板约定（`SpringPanel`）

全项目 6 个弹窗面板实测参数与约定：

| 弹窗 | panelPadding | radius | immersive | 面板材质 |
| --- | --- | --- | --- | --- |
| FolderPickDialog / FolderNameDialog / ProfileShareSheet / PostStatsDialog | `lg`(20) | 默认 `lg`(20) | **开** | 系统玻璃 + HDS 流光 |
| PublishModeSheet（发布方式） | `lg`(20) | 默认 `lg`(20) | **关** | **毛玻璃**（模糊 + 描边 + floating 阴影） |
| JoinedCirclesDialog（已加入的圈子） | `lg`(20) | 默认 `lg`(20) | **关** | **透明**（`outlined: true`：无模糊 / 透明底 / 描边 / 无阴影） |

约定：`panelWidth: 344` + `panelPadding: SpaceTokens.lg` + 不传 `radius`（用默认 `lg`）+ 内部 `Column space: SpaceTokens.base`。

`SpringPanel` 提供两个材质档位：

- 默认（`outlined: false`）= 系统玻璃面板：`backgroundBlurStyle` 模糊 + `barBorder` 描边 + `ShadowTokens.floating` 外阴影，`immersive` 控制是否叠 HDS 流光。
- `outlined: true` = 面板也走描边规格：**无模糊、透明底、`barBorder` 1vp 描边、`ShadowTokens.none`、自动跳过流光层**。当前仅「已加入的圈子」弹窗使用。
  ⚠️ 实测结论：**大面积、承载正文的浮层不适合 `outlined`**——面板只剩一条 ~1.1:1 的描边，内容直接浮在遮罩上，对比不足。`outlined` 的适用面是「小面积、单行、控件级」。

`immersive` **刻意不一刀切**：2026-09-14 用户拍板「要最薄」，把「已加入的圈子」与「发布方式」两个弹窗都关掉 `ImmersiveSurface` 的 HDS 双边流光与 `#1EFFFFFF→#1E86CFFF` 蒙层。其余 4 个弹窗保留流光。

⚠️ 重要前提：`ImmersiveSurface` 源码记录「部分真机 `backgroundBlurStyle` 会渲染为不透明面板」。这意味着**关掉流光之后，面板在真机上可能就是一个实心块**——内部元素做透明底 + 描边也透不出任何东西。若后续仍觉得「实心」，剩下两个杠杆是 ① 面板的 `ShadowTokens.floating` 外阴影（`SpringPanel` 共享，需加 prop 才能只改这两个）② 给面板描边单独提对比度。**不要再靠内部元素的透明度去解决面板的问题。**

## 二、页面清单（entry/src/main/ets/pages）

| 分组 | 页面 |
| --- | --- |
| 骨架 | `Index`（Tab 容器：首页 / 圈子 / 发布 / 消息 / 我的） |
| 内容 | `DetailPage`、`SearchPanelPage`、`SearchResultPage` |
| 发布 | `PhotoPublishPage`、`VideoPublishPage`、`TextPublishPage`、`PublishPreviewPage`、`DraftBoxPage`、`TrashBoxPage` |
| 圈子 | `CircleDetailPage`、`InterestTagsPage` |
| 消息 | `MessagePage`、`ChatPage`、`NotificationSettingsPage` |
| 我的 | `ProfilePage`、`EditProfilePage`、`UserProfilePage`、`MyFollowPage`、`BlocklistPage`、`BookmarkFolderPage`、`BookmarkFolderDetailPage` |
| 账号 | `LoginPage`、`AccountBindingPage` |
| 设置与合规 | `SettingsPage`、`PrivacySettingsPage`、`PrivacyPage`、`UserAgreementPage`、`AboutPage` |
| 治理 | `ReportAdminPage`（举报中心 · 唯一处置台；原 `ModerationPage` 内容审核台已并入，2026-09-29 下线） |
| 设计预览 | ~~`FoundationPreviewPage`、`ParchmentPreviewPage`~~ 已删除（2026-09-15） |

## 三、功能模块

### 首页（`components/HomeTab.ets`）
- **顶栏已整体迁入 Navigation 标题栏**（2026-10-03）：品牌块（有据 / SUBSTANTIATE / 标语）+ 搜索按钮 + 分段栏 + 圈子 chip 全部驻留标题栏，统一挂系统材质（沉浸光感，见下方专节）。
- 分段栏「推荐 / 关注 / 每日一帖」（`FEED_SEGMENTS`，`outlined` 规格 + `useSystemMaterial`）。
- 圈子 `TagNav` 拆为两形态：chip 在标题栏（可挂材质），下拉面板 + 点外关闭遮罩在内容区顶部（`panelOnly`），靠共享 `dropdownVisible` 同步。
- 顶栏状态由 `Index` 持有、本组件 `@Link` 共用；标题栏写入 `feedIndex` 由 `@Watch('onFeedIndexChanged')` 承接信息源加载。
- 关注流未登录走 `EmptyState` 登录引导；列表全部用 `Scroll`（沉浸全屏下的约定）。
- 会话缓存 `feedSessionCache`（key = `feedMode|tag|sort`，每日一帖不缓存）。

### 沉浸光感 · 顶栏迁入 Navigation 标题栏（2026-10-03）
- `uiMaterial` 轨（通用属性 `systemMaterial`）**只在 Navigation/NavDestination 标题栏或系统底部 TabBar 生效**，内容区设置完全不渲染（官方 FAQ 生效范围）。
- **已完成改造**：首页 / 圈子 / 消息 / 我的（主 Navigation 按 Tab 分支）、搜索面板与圈子详情、帖子详情、他人主页（后四者组件自带 Navigation，router 壳与 NavDestination 壳共用一份实现）。
- 顶栏整体驻留标题栏（`BarStyle.STANDARD` 占位 + 画布底色）；材质生效时**撤掉自绘兜底**（`backdropBlur` / `backgroundBlurStyle` / 自绘边框 / 自绘 `shadow`），否则遮挡或叠成实心毛玻璃、双圈描边。
- 低版本（API < 26）经 `deviceInfo.apiAvailable('26.0.0')` **字面量 if 门禁**自动回退描边/玻璃样式；统一入口 `utils/immersiveMaterial.ets`（`TopButtonMaterialModifier` / `isSystemMaterialActive()`）。
- 组件侧统一 `useSystemMaterial` 范式（`SegmentedControl` / `TagNav` / `DesignButton`）；尾随闭包组件（`Pressable`）材质挂内层表面节点；标题栏内联原生表面（圈子「已加入」药丸）按 `isSystemMaterialActive()` 让位（底/描边/阴影归零）。
- 帖子详情（2026-10-03）：`PostDetailView` 组件自带 Navigation，原 `DetailToolbar`（返回/分享/更多）内联进标题栏 Builder 后按「删干净」原则删除；分享/更多为原生 Row 表面，`attributeModifier` 直挂 44×44 节点 + lg 圆角定形，BackButton 交由 enable 自动材质。三个全屏覆盖层（看图/分享卡/数据面板）必须盖过标题栏 → 移到 Navigation 之外的 Stack 兄弟层，并各自补回状态栏偏移。栏高固定（token 直算）。底部互动栏未动（不在 `systemMaterial` 生效范围，优化方案见下方小节）。
- 他人主页（2026-10-03）：`UserProfileView` 组件自带 Navigation，标题栏 = 导航行（返回/昵称/⋯菜单）+ 资料区整体（ProfileIdentity/统计/关注私信按钮，含背景图 16:10 卡片变体与入场动效，与「我的」页 hero 驻留同款）；资料区高度内容驱动 → `onAreaChange` 实测回写 `titleBarProfileHeight` + 同源估算兜底（ProfileIdentity 固定 146）。关注/私信按钮材质生效时让位（blur→NONE、描边/阴影归零），低版本保留 HDS 玻璃；bindMenu 系统菜单全页面生效可直接驻留。内容区仅剩未就绪三分支 + 帖子网格。⚠️ 坑：`pushPathByName('PostDetail', params)` 必须显式赋 `postId`——`PostDetailNavParams.postId` 默认 0（非 undefined），目的地 onReady 曾用 `typeof` 守卫对 0 放行并用 `openPostDetail(String(0))` 覆盖意图通道里的正确 id（点帖子报「帖子不存在」的根因，2026-10-03 修复：调用方显式赋值 + 目的地对 `postId <= 0` 提前返回不再覆盖）。
- 栏高：固定内容用 token 计算；内容驱动（我的页资料区、圈子详情三行顶栏）用 `onAreaChange` 实测回写 + 首帧估算兜底。状态栏避让只出现在标题栏一处。
- **教程（可复用方法论 + 模板 + 自查清单）**：`docs/tutorial-titlebar-immersive-light.md`；踩坑记录见 `docs/immersive-light-integration.md`。

### 全链路代码审查（2026-10-05，客户端 8 项 + 后端 12 项修复）
客户端（列表竞态与状态同步为主）：SearchResultPage / UserProfileView / MessagePage 补齐 HomeTab 同款 fetchSeq 竞态防护（loadMore 在途时刷新被静默丢弃 → 结果重复/页码跳页）；HomeTab / MyFollowView / ReportAdminPage / SearchResultPage / UserProfileView loadMore 失败页码回滚（否则失败页被静默跳过）；MyFollowView ForEach key 补 isFollowing（否则关注/回关乐观更新 UI 不生效）；HomeTab onAccountSwitch 清 feedSessionCache（跨账号残留上一账号首屏）；CommentList 删除评论新增 onDeleted 回调链同步父级 comments/commentCount；ChatView 死 onPageShow（@Component 上不生效）改为双壳信号接线（ChatPage.onPageShow / ChatDestination.onShown → chatRefreshSignal）；push.ets readPushRoute 对 type 做白名单（本地恶意应用可伪造 dm 深链钓鱼）；api.del 支持自定义 header。
后端：upload 预签名视频 size 必填 + 图片 20MB 上限（原 size 缺省跳过校验 → 任意大文件直传 COS）；辩论改票加乐观锁（并发双击票数双扣）；举报 dismissed 仅在「关闭了 pending 且从未被 resolved 裁决」时恢复内容（否则驳回新举报可复活已裁决下架内容）；分享落地页复用 canViewerSeeAuthorPosts + 用户页封禁 404（SSR 曾绕过全部可见性规则）；posts create/update mentions ≤20 + updatePost 仅对新增提及发通知（通知/推送轰炸）；deleteComment 递归级联全部后代（含孙级与 status=0 隐藏评论，防 commentCount 虚高）+ 帖主可删评论；评论点赞并发双击 P2002 幂等兜底；followUser 拒绝封禁/注销账号；tags 路由 tagName ≤20 且必须存在；push token 解绑改 X-Push-Token 头（query 落访问日志）；会话未读 groupBy 补 recalledAt: null 与全局未读同口径；Tag.useCount 发布 +1 / 编辑增减（此前从未写入，标签排序信号失效）；搜索联想加独立限流。
**未修复留档**（需要产品决策/独立立项）：无——原留档四项已全部落地（per-user 限流、埋点口径见上节；token 落盘加固与媒体 URL 白名单见下节）。

### Token 落盘加固 + 媒体 URL 白名单（2026-10-05，原留档两项落地）
- **Token 落盘加固**（`utils/sessionStore.ets`）：prefs 不再存明文 token，改为 `authTokenEnc` = token 与「设备 **ODID** + 每次写入的 12 字节随机 nonce」绑定的 SHA-256 keystream 异或遮蔽（同步实现，冷启动水合零时序风险）。安全边界：跨设备提取/还原备份防住（ODID 不同解不开）；同设备 root **不设防**（内存明文同样暴露，遮蔽无意义）——硬件级加固由 auth.ets 的 Asset Store 副本互补。**为什么不用 Asset 做恢复源**：实测覆盖安装会清空 Asset，恢复链路依赖 prefs 才能保住「覆盖安装不掉账号」；恢复路径必须同步完成（水合早于首帧）。兼容链路：旧版本明文键读取后立即转存密文并删除；更早的 persistent_storage 迁移路径不变；恢复出厂（ODID 重置）→ 解密失败 → 静默登出（合理降级）。
- **媒体 URL 白名单**（`backend/src/utils/mediaRef.ts` + 测试）：帖图/封面/视频/私信媒体/资料背景的**写路径**只接受本系统上传体系引用——`cos://<key>`（过 uploadService 目录白名单+防穿越）与 `/uploads/` 相对路径；带主机绝对 URL 仅接受 localhost/局域网主机（与 rateLimit 同口径）并归一化为相对路径；任意外链（跟踪打点向量）与路径穿越拒绝。接线点：postService create/update（images/coverImage/videoUrl/videoCover）、messageService sendMessage（image/video content 外链拒绝；share 卡 coverImage 非法时剥离不拒信）、auth 路由 PUT /me（avatar/profileBackground）。**历史数据零改动**（只约束新写入）；客户端 resolveDisplayImageUrl 补 `/uploads/` 相对路径分支（归一化引用回 BASE_URL）；登录态华为头像由服务端从华为接口回填、不经此路径，不受影响。

### 内容生产限流与埋点口径（2026-10-05，原「未修复留档」前两项落地）
- **per-user 限流**（`middleware/rateLimit.ts` 新增三档，挂在 auth 之后按 `req.userId` 计数，换 IP 无效；`NODE_ENV=test` 自动跳过防测试误伤，保留 `skipLocal` 开发豁免）：私信 `dmLimiter` 30 条/分钟（挂 POST /v1/messages）、发帖 `postCreateLimiter` 5 条/分钟（挂 POST /v1/posts）、评论 `commentLimiter` 10 条/分钟（挂 POST /v1/posts/:id/comments）。行为已用真实限流器冒烟验证（`scripts/smoke-user-limiter.mts`：用户 A 31 连发第 31 次 429、用户 B 不受影响）。
- **匿名埋点收口**（产品口径定案）：`POST /v1/metrics/post-event` 从软鉴权改为**强制登录**（auth 中间件）。理由：该端点全部消费方都是账号维度（作者数据面板的曝光/点击/转化率），匿名写入的唯一效果是无需账号即可刷量污染作者面板；`viewCount`（游客浏览）由 getPost 服务端写入且带 1 小时去重，**不受影响**。客户端 `trackPostEvent`/`trackDailyOpen` 未登录时静默不发（避免 401 噪音）。**口径变化：作者面板曝光/点击从「含游客」变为「仅登录用户」**。

### 沉浸光感 · 帖子详情底部栏（DetailActionBar）配色微调（2026-10-03 已实施）
- **不可行路径（结论保留）**：`systemMaterial`（uiMaterial 轨）在此位置**不渲染**——底部互动栏既非 Navigation/NavDestination 标题栏也非系统底部 TabBar（官方 FAQ 生效范围）；改成系统 TabBar / NavDestination toolbar 属产品结构重构且承载不了输入框 + 握姿换边 + 键盘联动，不建议。
- **已实施微调 ①（栏体减薄一档）**：`backgroundBlurStyle` 从 `GlassBlurStyle.Floating`(BACKGROUND_THICK) 改为 `GlassBlurStyle.Card`(BACKGROUND_REGULAR)——向「最薄」既定偏好靠拢，官方定位即「保留文字可读性」；API 23+ 透明底 / 低版本 `barSurface` 兜底、1vp `barBorder` 描边（与主 TabBar 同 token）、三键避让均不动。
- **已实施微调 ②（输入框配方统一）**：`GlowInput` 从 `segmentStyle: true`（分段栏深灰玻璃 + 自带 backdropBlur，在底栏玻璃上叠第二层模糊发浊）切为默认配方（系统玻璃 + `barSurface` 半透明白底 + `barBorder` 描边，与聊天输入同款）。`segmentStyle:true` 全项目仅此一处调用，切换零外溢；附带修正 segment 分支强制 lg 圆角、无视传入 `radius(sm)` 的隐藏行为。
- **真机待验**：Card 档比 THICK 透出更多内容，深色模式下亮色内容透过底栏可能压低输入文字对比度——不满意一行回退 `GlassBlurStyle.Floating`。
- **可选 C（不建议，留档）**：包 `ImmersiveSurface` 加 HDS 双边流光。用户近期已多次拍板移除流光（ChatView emoji 面板、VideoViewer、两个弹窗「要最薄」）；且底栏全宽 + 动态高度（聚焦展开/握姿换边/@提及候选），流光测尺寸需 `explicitWidth/Height` 兜底，复杂度高收益低。

### 每日一帖
- `HomeTab` 第三分段，`DAILY_PICK_LIMIT = 10` 一次拉齐、读完即完成态；禁用下拉刷新（与卡牌拖拽冲突）。
- `components/DailyPostDeck.ets`：卡堆拖拽 + 逐卡曝光上报 + 完成态覆盖层。
- 报头 `dailyMasthead`：日期 / 星期 / 刊期 `No.NNN`；`DAILY_ISSUE_ORIGIN = 2026-09-11` 为首期，按北京时间（UTC+8）自然日递推。
- 埋点：`trackDailyOpen()`（页面级进入）、`trackPostEvent(id, 'click', 'daily')`。

### 圈子（`components/CircleTab.ets`）
- **顶栏已迁入 Navigation 标题栏**（2026-10-03）：「圈子」标题 + 「已加入 N 个」药丸由 `Index.circleTitleBar` 承载（按 Tab 索引分支）；计数由 CircleTab 加载后经 `@Link circleJoinedCount` 回写（`joinedNames` 挂 `@Watch` 统一同步），点击药丸经 `circleJoinedSeq` 递增信号由 CircleTab `@Watch` 打开 `JoinedCirclesDialog`（profileShareSeq 同款接线）。
- 中部 `CircleOrbitCanvas`：三层星环，可拖拽旋转（`ringPan` 手势），行星点击选圈。
- 底部 `CircleSelectionCard`：选中圈资料卡（名称 / 简介 / 加入数 / 今日活跃 / 分类 + 「进入」按钮）。

### 互动治理
- 拉黑 / 不喜欢：`Blocklist` / `Dislike` 表 + `blockService` / `dislikeService`，路由 `/v1/me/block|dislike[/:id|list]`，`accessControl` 双向过滤。
- 流差异化：`recommend` 的 excluded = 拉黑 ∪ dislike；`latest` / `following` 仅拉黑。
- 入口：`UserProfilePage` 顶栏 ⋯ 菜单。

### 内容形态
- 视频：`Post.videoUrl` / `videoCover`（与 `images` 互斥），强制走 COS、≤50MB 服务端兜底；`PostCardMedia` 封面 + 三角角标；`DetailPage` 用 `VideoPlayer`。
- 发布三分页共享 `publishFlowStore` / `PublishDraft`；`Index.openPublish` 按 mode 跳转；`DraftBoxPage` 按类型分流。

### 华为推送（Push Kit）

链路：`createNotification`（notificationService）→ `pushToUser`（services/huaweiPush）→ Push Kit v3 REST + 设备 Token（PushToken 表）+ 审计（PushLog 表）。

| 环节 | 位置 | 说明 |
| --- | --- | --- |
| Token 上报 | `POST /v1/push/register` | 客户端 `pushService.getToken()` 后上报；同 token 换号会自动迁移归属 |
| Token 解绑 | `DELETE /v1/push/token?token=` | 登出/注销前调用，参数走 query（http DELETE 带 body 不稳定） |
| 下发 | `services/huaweiPush.ts` | v3 `/v3/{projectId}/messages:send` + 服务账号 JWT（PS256） |
| 点击跳转 | `EntryAbility.onCreate/onNewWant` → `utils/push.ets` → `Index` | `clickAction.data` 平铺进 `want.parameters`，含 `type/postId/commentId/nid`（私信另带 `peerId/peerName`） |
| 私信下发 | `messageService.pushDmNotification` | 落库后 fire-and-forget；`type=dm` → 前端直开 `ChatPage` |
| 前端上报时机 | `Index.initPushCapabilities` | 登录后：先申请通知权限，再上报 Token |

⚠️ 协议口径（踩过的坑）：**别用 Android HMS Push 那套**（`v1/{appId}` + OAuth client_credentials + `android.notification.click_action`）—— HarmonyOS 5 起已废弃 OAuth 2.0 开放鉴权，且消息体结构是 `payload/target/pushOptions`。

配置（`backend/.env` + 服务账号凭据文件，后者放服务器本地、**禁止入库**）：

| 项 | 取值 |
| --- | --- |
| `HUAWEI_PUSH_PROJECT_ID` | AGC → 项目设置 → 项目 ID |
| `HUAWEI_PUSH_SERVICE_ACCOUNT_PATH` | 容器内 `/app/agc-service-account.json`（宿主机只读挂载） |
| `HUAWEI_PUSH_CATEGORY` | **仅兜底**：未被 `CATEGORY_BY_NOTIFY_TYPE` 覆盖的类型用它，默认 `MARKETING` |
| `HUAWEI_PUSH_TEST_MESSAGE` | 调测期 `true`（每项目每日 1000 条、不触发频控）；**上线必须 `false`** |

**category 按通知类型区分**（写在 `services/huaweiPush.ts` 的 `CATEGORY_BY_NOTIFY_TYPE`，不要改成全局单一值）：私信 → `IM`（权益已通过）；评论 / 赞 / 收藏 / @提及 / 关注 → `SUBSCRIPTION`（权益审核中，未通过前会被华为降级成 MARKETING、单设备每日 2 条）；其余落兜底。改这张表前先去 AGC → 推送服务 → 自分类权益 确认状态。

⚠️ 传一个 AGC **未**授予权益的 category 不报错，华为会静默降级归到资讯营销类（单设备每日 2 条）——表现为「部分通知收不到」但没有任何失败记录，很难查。新增分类前先在 AGC 确认权益已批。

**推送文案 ≠ 通知中心文案**（`notificationService.toPushBody`）：站内保持中性措辞，推送侧加社交前缀（`好友 …` / `新粉丝 …`），以满足华为「订阅·社交动态类」分类要求并与 AGC 提交的申请的示例口径一致。改文案前先看这条，别顺手统一成一套。

上线前自检：`node scripts/check-push.mjs`（校验凭据 → PS256 签名 → v3 试发，三步全绿才说明服务端配对了）。

部署注意：`agc-service-account.json` 经 `.dockerignore` 排除，`docker-compose.prod.yml` 与 `deploy-backend.sh` 各自只读挂载，不存在时会打印提示并静默降级。

### 品牌与合规
- 品牌 Logo 三件套（手绘彩色 SVG）：`brand_harmony`（#1677FF / #5AA5FF）、`brand_huawei`（#E8112D / #B00B20）、`brand_wechat`（#07C160 / #2FCB79）；`utils/brandIcons.ets` 提供 `brandIconRes` / `brandTileTint`，`AccountBindingPage` 用 `providerTile`。
- 合规页：`PrivacyPage`、`UserAgreementPage`、`PrivacySettingsPage`（个性化推荐开关）、`InterestTagsPage`（查看 / 删除用于推荐的兴趣标签）。
- `EntryAbility`：状态栏 / 导航栏内容色随应用主题；`utils/dataExport.ets` 数据导出（分段错误标记 + hilog）。

### 登录态持久化（`utils/sessionStore.ets`，2026-10-03）

会话（token + 用户资料 + `privacyAgreed`）**不走 PersistentStorage**，改存 dataPreferences 独立文件 `youju_session`（应用级 preferences 目录）。真机实测（Mate70，2026-10-03）：覆盖安装（`hdc install -r` / DevEco Run）后的冷启动，PersistentStorage 读不回旧 `persistent_storage` 文件（AppStorage 全回默认值，偶发首启黑屏挂死），用户随后任意一次持久化键写入（如重新同意隐私弹窗）会把默认值整份刷回磁盘 → token/用户信息被清空（「重装后账号必掉」）；Asset Store 同样被覆盖安装清空，无法兜底。机制：

- `EntryAbility.onCreate` 最先 `initSessionStore`：同步读文件水合 AppStorage（键名与旧 persistProp 一致，消费方零改动）；会话键此后只是普通 AppStorage 键。
- 写入统一走 `saveSessionSnapshot()`（putSync + flushSync 即时落盘）：`setSession` / `clearSession` / `setPrivacyAgreed` / CircleTab 头像回写（`persistSessionSnapshot`）。
- 旧 `persistent_storage` 文件首启一次性迁移（token+userId 成对才迁，XML 解析在 sessionStore 内）。
- token 仍异步双写 Asset Store（安全加固副本），但不再参与冷启动恢复（覆盖安装会被系统清空，且单 token 无 userId 成不了会话）；Asset 同步 API 曾在启动路径挂死，已全部改异步。
- 未读红点 / 圈子引导标记仍留 PersistentStorage（丢失无碍，重新拉取即可）。
