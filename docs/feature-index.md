# 「有据」功能索引

从项目长期记忆迁出的功能清单，避免占用记忆注入额度。规则类约束仍在 `.workbuddy/memory/MEMORY.md`，排障过程在 `.workbuddy/memory/YYYY-MM-DD.md`。

## 一、设计系统（entry/src/main/ets/design）

| 目录 | 内容 |
| --- | --- |
| `tokens/` | `color`、`type`、`space`（含 `LayoutTokens`）、`radius`、`shadow`、`motion`、`icon` |
| `components/` | SegmentedControl、ChipRow / ChipItem、BaseCard、BottomTabBar / BottomTabItem、EmptyState、IconTile、PollBlock、StatRow、AuthorRow、DesignButton、ImmersiveSurface、GlowInput、MessageRow |
| `motion/` | Pressable、SharedSlide、Reveal、Collapse、CountRoll、Skeleton、SpringPanel |
| `preview/` | FoundationPreview、ParchmentPreview |

`DesignButton` 四个变体：`primary`（品牌实底）/ `ghost`（透明 + 品牌描边）/ `glass`（`elevated` 底 + 玻璃描边）/ `outlined`（透明 + `barBorder` 描边 + lg 圆角，2026-09-14 新增）。

`outlined` 描边规格（透明底 + 1vp `barBorder` 描边 + `RadiusTokens.lg` 圆角 + 无阴影）已在 7 处采用，兼容容器类（`SegmentedControl({ outlined: true })`）与按钮类（`DesignButton({ variant: 'outlined' })`）两种入口；完整规格、采用清单与已知风险见 `docs/home-segmented-control-style-audit.md`。

### 弹窗面板约定（`SpringPanel`）

全项目 6 个弹窗面板实测参数与约定：

| 弹窗 | panelPadding | radius | immersive | 内部 space |
| --- | --- | --- | --- | --- |
| FolderPickDialog / FolderNameDialog / ProfileShareSheet / PostStatsDialog | `lg`(20) | 默认 `lg`(20) | **开** | `base`(16) |
| JoinedCirclesDialog（已加入的圈子） | `lg`(20) | 默认 `lg`(20) | **关** | `base`(16) |
| PublishModeSheet（发布方式） | `lg`(20) | 默认 `lg`(20) | **关**（且 `outlined: true`） | `base`(16) |

约定：`panelWidth: 344` + `panelPadding: SpaceTokens.lg` + 不传 `radius`（用默认 `lg`）+ 内部 `Column space: SpaceTokens.base`。

`SpringPanel` 提供两个材质档位：

- 默认（`outlined: false`）= 系统玻璃面板：`backgroundBlurStyle` 模糊 + `barBorder` 描边 + `ShadowTokens.floating` 外阴影，`immersive` 控制是否叠 HDS 流光。
- `outlined: true` = 面板也走描边规格：**无模糊、透明底、`barBorder` 1vp 描边、`ShadowTokens.none`、自动跳过流光层**。当前仅「发布方式」弹窗使用，让它与首页分段栏同语言。

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
| 治理 | `ModerationPage`、`ReportAdminPage` |
| 设计预览 | `FoundationPreviewPage`、`ParchmentPreviewPage` |

## 三、功能模块

### 首页（`components/HomeTab.ets`）
- 海报式编辑部头部：品牌块（有据 / SUBSTANTIATE / 标语）+ 搜索按钮（跳 `SearchPanelPage`）。
- 分段栏「推荐 / 关注 / 每日一帖」（`FEED_SEGMENTS`，`outlined` 规格）。
- 推荐流右侧叠挂 `TagNav`（`compact + dropdownOnly`）圈子下拉按钮，两者共用同一行 `Stack`（`zIndex` 3 vs 2）。
- 关注流未登录走 `EmptyState` 登录引导；列表全部用 `Scroll`（沉浸全屏下的约定）。
- 会话缓存 `feedSessionCache`（key = `feedMode|tag|sort`，每日一帖不缓存）。

### 每日一帖
- `HomeTab` 第三分段，`DAILY_PICK_LIMIT = 10` 一次拉齐、读完即完成态；禁用下拉刷新（与卡牌拖拽冲突）。
- `components/DailyPostDeck.ets`：卡堆拖拽 + 逐卡曝光上报 + 完成态覆盖层。
- 报头 `dailyMasthead`：日期 / 星期 / 刊期 `No.NNN`；`DAILY_ISSUE_ORIGIN = 2026-09-11` 为首期，按北京时间（UTC+8）自然日递推。
- 埋点：`trackDailyOpen()`（页面级进入）、`trackPostEvent(id, 'click', 'daily')`。

### 圈子（`components/CircleTab.ets`）
- 顶部 `topBar`：「圈子」标题 + 「已加入 N 个」入口（`JoinedCirclesDialog`）。
- 中部 `CircleOrbitCanvas`：三层星环，可拖拽旋转（`ringPan` 手势），行星点击选圈。
- 底部 `CircleSelectionCard`：选中圈资料卡（名称 / 简介 / 加入数 / 今日活跃 / 分类 + 「进入」按钮）。

### 互动治理
- 拉黑 / 不喜欢：`Blocklist` / `Dislike` 表 + `blockService` / `dislikeService`，路由 `/v1/me/block|dislike[/:id|list]`，`accessControl` 双向过滤。
- 流差异化：`recommend` 的 excluded = 拉黑 ∪ dislike；`latest` / `following` 仅拉黑。
- 入口：`UserProfilePage` 顶栏 ⋯ 菜单。

### 内容形态
- 视频：`Post.videoUrl` / `videoCover`（与 `images` 互斥），强制走 COS、≤50MB 服务端兜底；`PostCardMedia` 封面 + 三角角标；`DetailPage` 用 `VideoPlayer`。
- 发布三分页共享 `publishFlowStore` / `PublishDraft`；`Index.openPublish` 按 mode 跳转；`DraftBoxPage` 按类型分流。

### 品牌与合规
- 品牌 Logo 三件套（手绘彩色 SVG）：`brand_harmony`（#1677FF / #5AA5FF）、`brand_huawei`（#E8112D / #B00B20）、`brand_wechat`（#07C160 / #2FCB79）；`utils/brandIcons.ets` 提供 `brandIconRes` / `brandTileTint`，`AccountBindingPage` 用 `providerTile`。
- 合规页：`PrivacyPage`、`UserAgreementPage`、`PrivacySettingsPage`（个性化推荐开关）、`InterestTagsPage`（查看 / 删除用于推荐的兴趣标签）。
- `EntryAbility`：状态栏 / 导航栏内容色随应用主题；`utils/dataExport.ets` 数据导出（分段错误标记 + hilog）。
