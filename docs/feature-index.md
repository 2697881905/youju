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
- 首页(0) / 我的(4) 的整块顶栏驻留标题栏（`BarStyle.STANDARD` 占位 + 画布底色）；材质生效时**撤掉自绘兜底**（`backdropBlur` / `backgroundBlurStyle` / 自绘 `shadow`），否则遮挡或叠加。
- 低版本（API < 26）经 `deviceInfo.apiAvailable('26.0.0')` **字面量 if 门禁**自动回退描边/玻璃样式；统一入口 `utils/immersiveMaterial.ets`（`TopButtonMaterialModifier` / `isSystemMaterialActive()`）。
- 我的页：分享/设置、编辑资料、草稿箱/废纸篓、主分段栏同源材质；资料区高度 `onAreaChange` 实测回写栏高。
- 完整实践与踩坑记录（生效范围、兼容保护、兜底让位、状态上移、栏高与状态栏避让、语法坑自查清单）：见 `docs/immersive-light-integration.md`。

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
