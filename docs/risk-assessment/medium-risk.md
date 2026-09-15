# 中风险问题文档

> 本文档记录「有据」项目中影响用户体验一致性、功能完善度或代码可维护性的中风险问题。
> 这些问题不会导致崩溃或审核阻断，但会显著降低用户体验或增加后期维护成本。

---

## M-1: 20 处 console 调用应替换为 hilog

| 维度 | 说明 |
|------|------|
| **风险来源** | `CircleTab.ets:283`、`DetailPage.ets:779`、`ChatPage.ets:276,278,280,282,316,323,325`、`share.ets:68`、`auth.ets:243,262`、`shareCard.ets:43,90,201,219,239,244,259,261` — 共 20 处 console.info/error/warn 调用 |
| **影响范围** | 生产环境的日志可观测性；真机问题排查能力 |
| **触发条件** | release 构建时混淆规则 `-remove-log` 自动移除 console 调用；debug 构建时 console 输出到 DevEco Studio 控制台 |
| **可能后果** | release 包中所有 console 日志被移除，线上问题无法通过日志排查。项目已有 hilog 使用示例（HomeTab.ets、Index.ets、EntryAbility.ets），但 20 处 console 调用未跟进，日志体系不统一 |
| **修复建议** | 将 20 处 console 调用替换为 `hilog.info/error/warn`，保持与项目现有实践一致。hilog 在 release 包中保留，支持真机日志排查 |

---

## M-2: 6 个页面空状态未使用 EmptyState 组件

| 维度 | 说明 |
|------|------|
| **风险来源** | `MyFollowPage.ets:182-187`（`Text('这里还什么都没有')`）、`BookmarkFolderPage.ets:193-202`、`BookmarkFolderDetailPage.ets:249-257`（`Text('这个收藏夹还是空的')`）、`TrashBoxPage.ets:245-259`、`DraftBoxPage.ets:162-173`（`Text('暂无草稿')`）、`ModerationPage.ets:404-412` |
| **影响范围** | 关注列表、收藏夹、收藏夹详情、回收站、草稿箱、审核管理 6 个页面的空数据状态 |
| **触发条件** | 用户进入上述页面时对应数据列表为空 |
| **可能后果** | 空状态仅显示纯文字，无图标、无视觉引导，与项目已有的 `EmptyState` 组件（含图标和描述）风格不一致。用户体验割裂，部分页面空状态缺少重试按钮（ModerationPage），用户无法主动恢复 |
| **修复建议** | 将 6 个页面的空状态统一替换为 `EmptyState` 组件，传入对应的图标资源（`empty_inbox`/`empty_search`/`empty_guide`）和描述文本，需要时添加重试按钮 |

---

## M-3: 除 SearchResultPage 外所有列表页缺少骨架屏

| 维度 | 说明 |
|------|------|
| **风险来源** | `CircleDetailPage.ets:260-270`、`MyFollowPage.ets:176-181`、`MessagePage.ets:514-518`、`ProfilePage.ets:716-720`、`UserProfilePage.ets:644-648`、`BlocklistPage.ets:117-125`、`TrashBoxPage.ets:219-228`、`BookmarkFolderPage.ets:187-192`、`BookmarkFolderDetailPage.ets:243-248`、`ModerationPage.ets:376-386`、`ReportAdminPage.ets:488-498`、`InterestTagsPage.ets:182-189`、`PrivacySettingsPage.ets:90-94`、`DetailPage.ets:417-425`、`ChatPage.ets:200-213` — 共 15 个页面 |
| **影响范围** | 所有列表页和数据加载页的加载状态体验 |
| **触发条件** | 页面首次加载数据、网络较慢时 |
| **可能后果** | 加载过程中仅显示 `LoadingProgress` 圆圈或纯文字"加载中"，用户看到大面积空白区域，感知等待时间长。`TrashBoxPage` 甚至连 `LoadingProgress` 都没有，仅显示文字。与 `SearchResultPage` 已实现的 `Skeleton` 骨架屏体验差距明显 |
| **修复建议** | 优先为高频页面（DetailPage、MessagePage、ProfilePage、CircleDetailPage）添加骨架屏，复用 `design/motion/Skeleton.ets` 组件 |

---

## M-4: ModerationPage / MyFollowPage 错误态无重试按钮

| 维度 | 说明 |
|------|------|
| **风险来源** | `ModerationPage.ets:404-412` — 错误态仅 `Text('加载失败：' + this.error)`，无重试按钮；`MyFollowPage.ets:182-187` — 同上 |
| **影响范围** | 审核管理页面和关注列表页面 |
| **触发条件** | 网络请求失败后进入错误状态 |
| **可能后果** | 用户看到错误信息但无法主动重试，必须退出页面重新进入才能再次加载。对于临时性网络故障（如弱网切换），用户被迫重复导航操作，体验差 |
| **修复建议** | 在错误态 UI 中添加"重试"按钮，onClick 调用对应的 `loadXxx()` 方法重新发起请求 |

---

## M-5: MyFollowPage 无下拉刷新和上拉加载更多

| 维度 | 说明 |
|------|------|
| **风险来源** | `MyFollowPage.ets:166-225` — 整个列表无 `Refresh` 组件包裹，`List` 也无 `onReachEnd` 上拉加载更多 |
| **影响范围** | 关注列表页面 |
| **触发条件** | 用户在关注列表页面想要刷新数据或查看更多内容 |
| **可能后果** | 用户无法下拉刷新关注列表，新关注/取消关注后列表不会更新。无上拉加载更多意味着如果关注列表超过单页数据量，用户无法查看完整列表。与 HomeTab（有 Refresh + onReachEnd）体验不一致 |
| **修复建议** | 用 `Refresh` 组件包裹 List，添加 `onRefreshing` 回调调用 `loadFollowing()`；在 List 上添加 `onReachEnd` 实现分页加载 |

---

## M-6: ReportAdminPage / ModerationPage 大量硬编码颜色，深色模式不适配

| 维度 | 说明 |
|------|------|
| **风险来源** | `ReportAdminPage.ets:335`（`'#34C759'`）、`372`（`'#E8F1FF'`）、`379`（`'#F2F2F2'`）、`398`（`'#FFE5E5'`）；`ModerationPage.ets:297`（`'#34C759'`）、`238`（`'#FFE5E5'`）、`323`（`'#FFD1D1'`）、`60`（`'#FFFFFF'`）、`356`（`'#FFFFFF'`）；`Index.ets:195-199`（Tab 颜色 `'#8A6548'`、`'#34C759'`、`'#FF9500'`、`'#AF52DE'`、`'#FF2D55'`）；`PublishPreviewPage.ets:122,130,145,336-337,354,367`；`BlocklistPage.ets:21`（`'#1AFF3B30'`）；`MyFollowPage.ets:197`（`'#fff'`） |
| **影响范围** | 举报管理、审核管理、首页 Tab、发布预览、屏蔽列表、关注列表等页面的深色模式显示 |
| **触发条件** | 用户切换到深色模式（系统级或应用级） |
| **可能后果** | 硬编码的浅色颜色值在深色模式下不会自动适配，导致文字与背景对比度不足（如白色文字在浅色背景上不可见）、按钮颜色突兀、整体视觉不协调。项目已有完整的 `dark/element/color.json` 深色资源，但这些页面绕过了资源引用 |
| **修复建议** | 将所有硬编码颜色提取到 `color.json` 资源文件中，通过 `$r('app.color.xxx')` 引用，确保深色模式自动适配。优先处理 ReportAdminPage 和 ModerationPage（管理类页面高频使用） |

---

## M-7: 所有发布页标题 TextInput 无 maxLength 限制

| 维度 | 说明 |
|------|------|
| **风险来源** | `TextPublishPage.ets:386-395`、`PhotoPublishPage.ets:344-353`、`VideoPublishPage.ets:339-348` — 标题 TextInput 均无 `maxLength` 属性 |
| **影响范围** | 文字发布、图片发布、视频发布三种发布模式 |
| **触发条件** | 用户在标题输入框中输入超长文本 |
| **可能后果** | 用户可输入无限长标题，可能导致：1. 后端拒绝超长标题（API 返回错误）；2. UI 布局异常（标题过长导致卡片/详情页排版错乱）；3. 数据库字段溢出。内容 TextArea 在 TextPublishPage 和 PhotoPublishPage 有 `maxLength(5000)`，但 VideoPublishPage 的内容 TextArea 也缺失 |
| **修复建议** | 为所有标题 TextInput 添加 `maxLength(50)` 或 `maxLength(100)`（根据后端字段限制确定）；为 VideoPublishPage 的内容 TextArea 添加 `maxLength(5000)` |

---

## M-8: format.ets 中 formatCount 未处理 Infinity，timeAgo 未处理 NaN

| 维度 | 说明 |
|------|------|
| **风险来源** | `utils/format.ets:1-9` — `formatCount(n)` 中 `Infinity >= 10000` 为 true，返回 `"Infinityw"`；`utils/format.ets:11-32` — `timeAgo(iso)` 中 `new Date(iso).getTime()` 对无效日期返回 NaN，最终 `new Date(iso).toLocaleDateString()` 返回 `"Invalid Date"` |
| **影响范围** | 所有显示点赞数、评论数、时间戳的页面和组件 |
| **触发条件** | `formatCount`：传入 Infinity（如 `1/0` 或后端返回异常数据）；`timeAgo`：传入无效日期字符串（如 `""`、`"null"`、`"undefined"` 或格式异常的时间戳） |
| **可能后果** | 用户看到 `"Infinityw"` 或 `"Invalid Date"` 字样，UI 显示异常，影响应用专业度 |
| **修复建议** | `formatCount`：在函数开头添加 `if (!isFinite(n)) return '0'`；`timeAgo`：在 `const t = new Date(iso).getTime()` 后添加 `if (isNaN(t)) return ''` |

---

## M-9: 多处 router.pushUrl / router.back 无 .catch()

| 维度 | 说明 |
|------|------|
| **风险来源** | `auth.ets:111,116`、`DetailPage.ets:234,245,248,840`、`DetailPostContent.ets:87`、`ChatPage.ets:949`、`LoginPage.ets:194,208` — 共约 10 处 router 导航调用无 `.catch()` |
| **影响范围** | 登录跳转、详情页跳转、用户主页跳转、聊天页跳转、协议页面跳转 |
| **触发条件** | 页面栈已满（默认最大 32 页）、目标页面路由不存在、路由参数格式错误 |
| **可能后果** | `router.pushUrl` 返回的 Promise 被 reject 时，产生未处理的 Promise rejection。ArkUI 运行时可能记录警告但不崩溃，然而在某些设备上可能导致应用异常终止。`auth.ets` 中的 `try-catch` 只能捕获同步异常，不能捕获 Promise rejection |
| **修复建议** | 为所有 `router.pushUrl` / `router.back` 调用添加 `.catch((e: Error) => { hilog.error(...) })`，至少记录错误日志 |

---

## M-10: request() 函数本身不包含重试逻辑

| 维度 | 说明 |
|------|------|
| **风险来源** | `services/api.ets:81-137` — 统一 `request()` 函数无内置重试机制。重试逻辑分散在 HomeTab（3次）、DetailPage（2次）、ProfilePage（自动重试）等各页面中 |
| **影响范围** | 所有 API 调用的网络健壮性 |
| **触发条件** | 网络抖动、临时性连接失败、DNS 解析超时 |
| **可能后果** | 大部分页面（MessagePage、ChatPage、BookmarkFolderDetailPage 等）的 API 调用无自动重试，网络抖动时直接进入错误态。重试逻辑分散导致实现不一致（有的3次、有的2次、有的没有），维护成本高 |
| **修复建议** | 在 `request()` 函数中内置指数退避重试机制（最多 3 次，间隔 1s/2s/4s），移除各页面分散的重试逻辑。对 GET 请求自动重试，对 POST/PUT/DELETE 请求默认不重试（避免重复提交） |

---

## M-11: 信息流缓存仅内存级，无持久化离线缓存

| 维度 | 说明 |
|------|------|
| **风险来源** | `components/HomeTab.ets:57-64` — `feedSessionCache` 是 `Map<string, FeedCacheEntry>`，仅存在于内存中，TTL 120 秒 |
| **影响范围** | 首页信息流（推荐/关注/每日一帖）的冷启动体验 |
| **触发条件** | 应用冷启动、用户杀进程后重新打开、网络不可用时打开应用 |
| **可能后果** | 冷启动时信息流完全空白，必须等待网络请求完成才能展示内容。网络不可用时无法展示任何历史数据，用户感知"应用不可用"。对于社交内容平台，离线浏览能力是基本期望 |
| **修复建议** | 基于 `PersistentStorage` 或 `Preferences` 添加持久化缓存层，至少缓存首屏数据（每个 Tab 的第一页帖子列表），冷启动时先展示缓存数据再后台刷新 |

---

## M-12: 无障碍（Accessibility）支持几乎缺失

| 维度 | 说明 |
|------|------|
| **风险来源** | 全项目仅 `BackButton`（`accessibilityText('返回')`）和 `EmptyState`（`accessibilityGroup(true)`）等少数共享组件内置了无障碍属性。所有列表项、图标按钮、设置行、输入区域、排序控件等均无 `accessibilityText` / `accessibilityDescription` |
| **影响范围** | 视障用户的使用体验；AGC 审核的无障碍合规要求 |
| **触发条件** | 视障用户使用 TalkBack/屏幕阅读器操作应用时；AGC 审核员检查无障碍支持时 |
| **可能后果** | 视障用户无法有效操作应用（屏幕阅读器无法朗读按钮含义）；AGC 审核可能要求基本无障碍支持，否则可能被判定为"应用可访问性不达标"。华为应用市场对无障碍支持有逐年提高的趋势 |
| **修复建议** | 优先为关键交互元素（底部 Tab、发布按钮、搜索按钮、点赞/评论/分享按钮、设置项）添加 `accessibilityText` 属性，确保屏幕阅读器能正确朗读功能含义 |