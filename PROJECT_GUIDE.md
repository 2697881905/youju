# 有据（YouJuApp）项目说明书

> 面向每一个人的理性内容分享社区 · HarmonyOS NEXT 原生应用
> 技术栈：**ArkTS/ArkUI（API 24, Stage 模型）+ Node.js/Express/TypeScript + Prisma + MySQL + 腾讯云 COS**
> 包名：`com.youju.app` ｜ 版本：1.0.0（1000000） ｜ Git 仓库：`github.com/2697881905/YouJuApp`

---

## 一、项目概览

```
HarmonyProject1/
├── AppScope/          # 应用级配置与图标资源（bundleName、分层图标）
├── entry/             # 前端主模块（ArkTS 源码、资源、文档、签名材料）
├── backend/           # 后端服务（Express API、Prisma、部署、测试）
├── design/            # 品牌 Logo 设计稿（历史归档 + 新方向）
├── docs/              # 架构/登录/导航设计文档
├── deliverables/      # 阶段性交付报告
├── soft_output/       # 源代码导出快照（PDF/文本）
├── landing/           # 营销落地页
├── *.json5/*.ts       # 根级构建/依赖/检查配置
└── *.sh               # 根级工具脚本
```

**整体架构**：鸿蒙 App（entry）通过 `services/api.ets` 的 HTTP 客户端访问后端（`/v1/*` REST API）；后端用 Prisma 操作 MySQL；图片走腾讯云 COS（预签名直传 + 公网 viewUrl）；华为账号登录经 Account Kit（前端授权码 → 后端换 token）；推送走 Push Kit。

---

## 二、根目录配置文件

| 文件 | 模块 | 职责 |
|---|---|---|
| `build-profile.json5` | 构建 | 应用级签名配置（release 证书/Profile）、产品 `default`、SDK 版本 `6.1.1(24)`（target/compatible）、bundleName `com.youju.app`、Push Kit 能力声明。**不入库**（本地签名配置）|
| `build-profile.json5.example` | 构建 | 无密钥模板，密码用 `${env.BBB_RELEASE_STORE_PASSWORD}` 占位 |
| `oh-package.json5` | 依赖 | 工程级依赖：模型版本 6.1.1，devDeps 仅 hypium/hamock（测试库），无三方运行时依赖（ArkTS kit 由 SDK 提供）|
| `oh-package-lock.json5` | 依赖 | 依赖锁文件 |
| `hvigorfile.ts` | 构建 | Hvigor 构建入口，使用默认 `appTasks` 插件 |
| `hvigor/hvigor-config.json5` | 构建 | 构建引擎配置（execution/logging）|
| `code-linter.json5` | 质量 | ArkTS 静态检查规则，含安全密码学规则（禁不安全 AES/RSA 等）|
| `local.properties` | IDE | DevEco Studio 本地 SDK 路径（不入库）|
| `.gitignore` | 版本控制 | 忽略构建产物/缓存/密钥类（.env/.p12/.keystore）、`entry/material/` 签名材料、`build-profile.json5`、`.workbuddy/` |
| `.github/workflows/ci.yml` | CI | 后端 CI（安装依赖 → 测试）|

---

## 三、AppScope（应用级资源）

| 文件 | 职责 |
|---|---|
| `app.json5` | 应用级配置：bundleName `com.youju.app`、vendor `youju`、versionCode/versionName、`icon: $media:layered_image`、label 引用 `string.json` 的 app_name「有据」|
| `resources/base/element/string.json` | 应用显示名 `app_name = 有据` |
| `resources/base/media/layered_image.json` | 分层图标定义（background + foreground 合成）|
| `resources/base/media/background.png` | 分层图标背景层（深蓝底色）|
| `resources/base/media/foreground.png` | 分层图标前景层（有据 v2 Logo：引文括号 + 蓝色锚点）|
| `resources/phone-{ldpi..xxxldpi}/media/app_icon.png` | 各密度桌面图标导出 |

---

## 四、entry 前端模块

### 4.1 模块配置与依赖

| 文件 | 职责 |
|---|---|
| `oh-package.json5` | entry 模块依赖（无三方依赖）|
| `build-profile.json5` | entry 模块构建配置（stageMode、release 混淆开启）|
| `hvigorfile.ts` | 模块 Hvigor 入口 |
| `obfuscation-rules.txt` | Release 混淆规则 |
| `src/main/module.json5` | 模块配置：唯一 Ability `EntryAbility`（launcher）、备份扩展 `EntryBackupAbility`、`metadata.client_id = 6917613566723435312`（AGC 华为登录/推送）、权限仅 INTERNET + STORE_PERSISTENT_DATA、设备类型 phone |

### 4.2 应用入口

| 文件 | 职责 |
|---|---|
| `src/main/ets/entryability/EntryAbility.ets` | 应用入口：onCreate/onWindowStageCreate 首屏加载 `pages/Index`、状态栏/主题初始化 |
| `src/main/ets/entrybackupability/EntryBackupAbility.ets` | 系统备份/恢复扩展（backup 类型）|

### 4.3 页面（pages/，25 个）

| 页面 | 职责 |
|---|---|
| `Index.ets` | 主容器：底部 Tab（首页/圈子/发布/消息/我的）+ 冷启动登录兜底 + 首启隐私弹窗 |
| `LoginPage.ets` | 登录：华为账号按钮（真实 Account Kit）+ 开发桩入口（其他方式/虚拟账号）|
| `DetailPage.ets` | 帖子详情：媒体轮播、正文、互动、评论、分享（复制/系统分享/分享卡片）、辩论投票、举报 |
| `PublishPreviewPage.ets` | 发布预览：封面（与卡片一致 3:4 Cover）、文字海报样式选择、发布提交 |
| `PhotoPublishPage.ets` | 图文发布：体裁/标签/图片（上传按钮在标题上方）/标题/正文/结构化字段 |
| `TextPublishPage.ets` | 纯文字发布：文字海报样式选择 |
| `VideoPublishPage.ets` | 视频发布：视频选择/首帧封面/标题/结构化字段 |
| `ProfilePage.ets` | 我的主页：资料卡、分段（作品/我赞过/我收藏）、关注粉丝统计、分享主页 |
| `UserProfilePage.ets` | 他人主页：关注/拉黑/不喜欢、作品列表 |
| `EditProfilePage.ets` | 编辑资料（昵称/头像/简介/背景）|
| `MessagePage.ets` | 通知中心：评论/点赞/关注/系统通知、未读圆点 |
| `ChatPage.ets` | 私信：会话列表、聊天、发送、已读未读 |
| `MyFollowPage.ets` | 关注列表（我关注的用户）|
| `CircleDetailPage.ets` | 圈子（标签）详情：该标签下帖子流 |
| `SearchResultPage.ets` | 搜索结果 + 搜索历史/热搜 |
| `SettingsPage.ets` | 设置：资料、绑定、通知、隐私、深色模式、关于、退出 |
| `AboutPage.ets` | 关于页（版本、隐私政策/用户协议入口）|
| `AccountBindingPage.ets` | 华为账号绑定/解绑 |
| `BlocklistPage.ets` | 黑名单管理 |
| `NotificationSettingsPage.ets` | 通知偏好开关 |
| `PrivacyPage.ets` / `PrivacySettingsPage.ets` | 隐私政策正文 / 隐私设置（资料可见性）|
| `UserAgreementPage.ets` | 用户协议 |
| `DraftBoxPage.ets` | 草稿箱（含文字海报预览）|
| `ModerationPage.ets` | 内容审核（管理员）|
| `FoundationPreviewPage.ets` | 设计系统预览（开发用）|

### 4.4 核心组件（components/，43 个）

| 分组 | 组件 | 职责 |
|---|---|---|
| 帖子卡片 | `PostCard` `PostCardMedia` `PostCardTitle` `PostCardAuthor` | 信息流卡片：3:4 Cover 封面、标题、互动/贴主信息一体化玻璃区 |
| 标签导航 | `TagNav` `TagIcon` | 首页圈子栏：横向滚动 + 下拉网格（点击外部收回）+ 标签图标 |
| 详情区 | `DetailMediaCarousel` `ImageViewer` `VideoPlayer` `DetailActionBar` `DetailCommentsSection` `DetailPostContent` `DetailPostHeader` `DetailToolbar` | 详情页媒体轮播（宽铺满高截断）、全屏查看器（长图可滑动）、视频、互动栏、评论、正文/结构化字段、作者头、工具栏 |
| 分享 | `ShareSheet` `ProfileShareSheet` | 分享面板：分享卡片/复制链接/复制标题/系统分享；主页分享卡片 |
| 评论 | `CommentList` | 评论列表 + 顶/删除/举报 |
| 搜索 | `SearchPanel` | 首页搜索面板 |
| 媒体选择 | `ImagePicker` `VideoPicker` | 相册选图（压缩）/选视频 |
| 发布流程 | `PublishGenreSection` `PublishModeSheet` `PublishStructuredSupplement` `PublishTagPanel` `PublishTopBar` | 体裁选择、模式切换、结构化字段补充、标签面板、顶部操作栏 |
| 日推 | `DailyPostDeck` `DailyPostView` | 每日一帖卡片组 |
| 圈子 | `CircleTab` `CircleOnboarding` `CircleOrbitCanvas` `CircleSelectionCard` `JoinedCirclesDialog` | 圈子 Tab、引导、轨道画布、圈子选择卡、已加入圈子 |
| 华为登录 | `HuaweiLoginButton` `HuaweiBindButton` | 真实 `LoginWithHuaweiIDButton` 封装 |
| 个人资料 | `AvatarView` `EditableProfilePreview` `ProfileHeader` `ProfileIdentity` `ProfileStatItem` | 头像/资料预览/主页头/身份区/统计项 |
| 其他 | `HomeTab`（首页 Tab：轮播/标签/信息流）`ReportDialog`（举报）`PostCollectionState`（收藏态）`GlassPanel` 等设计组件 | — |

### 4.5 工具库（utils/）

| 文件 | 职责 |
|---|---|
| `auth.ets` | 登录态/token 管理、AppStorage 同步、用户信息 |
| `api.ets` → 见 4.6 | API 客户端 |
| `share.ets` | 分享链接构建、剪贴板、系统分享（文本+封面，沙箱下载）|
| `shareCard.ets` | 小红书式分享卡片：离屏 Canvas 绘制（封面+标题+作者+链接）→ 系统分享 |
| `textPoster.ets` | 文字海报：离屏绘制 4 风格海报 → COS 上传（含绘制工具函数导出）|
| `theme.ets` | 深色模式/系统跟随/减弱动效偏好（Preferences 持久化）|
| `structuredFields.ets` | 各体裁结构化字段读写（含 coverOnlyTextPoster 标记）|
| `publishFlowStore.ets` `publishDraft.ets` `postDraftStore.ets` | 发布流程状态机、草稿模型、草稿存取 |
| `likeStore.ets` | 点赞全局仓库（乐观更新 + 跨页同步）|
| `debateVoteStore.ets` | 辩论投票乐观更新仓库 |
| `image.ets` `video.ets` | 图片压缩/解码（fileIo）、视频宽高比归一化/缩略 |
| `actionIcons.ets` `tagIcons.ets` `settingsIcons.ets` `publishGenres.ets` | 图标名映射、标签图标、设置图标、发布体裁元数据 |
| `toast.ets` `cardTokens.ets` `nav.ets` | Toast 封装、卡片尺寸令牌、页面跳转（openUserProfile 等）|
| `breakpoint.ets` `responsive.ets` | 断点/响应式工具 |
| `format.ets` `data-source.ets` `styles.ets` `huaweiPush.ets` | 格式化、数据源、样式辅助、推送 token 上报 |

### 4.6 API 服务（services/api.ets）

核心客户端 + 约 70 个函数：帖子/评论/标签 CRUD、登录与华为 code 交换、关注与用户主页、点赞/收藏、搜索历史/热词、通知与未读、私信、举报审核、账号绑定、隐私、屏蔽/不喜欢、数据导出、辩论投票、推送 token、上传签名（COS 预签名/本地）。同时导出 `resolveDisplayImageUrl`（图片 URL 归一化）、`resolveUploadPutUrl`（直传 host 改写，local 模式走 127.0.0.1 rport）。

### 4.7 模型（models/types.ets）

Post/User/Comment/Tag/Genre/StructuredData/Message 等全部接口类型。

### 4.8 设计系统（design/）

- `tokens/`：color/icon/motion/radius/shadow/space/type（设计令牌，全局统一）
- `components/`：AuthorRow/Avatar/BackButton/BaseCard/BottomTabBar/ChipRow/DesignButton/EmptyState/GlassPanel/IconTile/MessageRow/PollBlock/SegmentedControl/StatRow
- `motion/`：Collapse/CountRoll/Pressable/Reveal/SharedSlide/Skeleton/SpringPanel（动效封装）
- `preview/FoundationPreview.ts`：设计令牌预览

### 4.9 资源与配置（resources/）

| 路径 | 职责 |
|---|---|
| `base/element/{color,float,string}.json` | 颜色/尺寸/文案（app 名、字体）|
| `dark/element/color.json` | 深色模式配色 |
| `base/media/*.svg/png` | 图标库（action_/nav_/set_/tag_/genre_/empty_ 等）、logo.png、layered_image、startIcon |
| `base/profile/main_pages.json` | 页面路由表（@Entry 页面注册）|
| `base/profile/backup_config.json` | 备份范围配置 |
| `base/media/rawfile/agconnect-services.json` | AGC 云服务配置（华为登录/推送）|

### 4.10 文档与签名（Docs/、material/）

- `Docs/`：`有据.md`（总览）、`产品文档.md`、`技术文档.md`、`接口契约.md`（V1 冻结）、`RELEASE_CHECKLIST.md`（上架审查）、`AGC_STORE_COPY.md`（上架文案）、`design-*.md` ×6（功能设计）、`prd-*.md` ×7（PRD）、`class-diagram.mermaid`/`sequence-diagram.mermaid`
- `material/`：AGC 签名材料（p12/p7b/cer/csr，**不入库**）
- `build/`：hvigor 构建产物（可忽略，重新构建刷新）

---

## 五、backend 后端服务

### 5.1 入口与装配

| 文件 | 职责 |
|---|---|
| `src/index.ts` | 启动入口：安全 fail-fast（生产缺 JWT_SECRET/CORS_ORIGIN 拒绝启动）、监听 0.0.0.0:3000、打印 COS 存储模式自检 |
| `src/app.ts` | Express 装配：helmet、全局限流、CORS、`/health`、`/uploads` 静态服务、敏感词加载、挂载 18 个路由、错误处理 |
| `src/prisma.ts` | `PrismaClient` 单例 |

### 5.2 路由（routes/，18 个）

| 路由 | 职责 |
|---|---|
| `auth.ts` | 登录（openId 仅开发 / huawei/exchange 换 token）、我的资料、注销、隐私同意、收藏/赞/评论/关注标签 |
| `posts.ts` | 帖子列表/关注流/每日一帖/详情/发布/删除/编辑/辩论投票/举报 |
| `comments.ts` `interact.ts` `tags.ts` | 评论、顶帖/收藏、标签列表/关注 |
| `upload.ts` | 上传预签名（COS 直传）+ 本地落盘（仅开发）|
| `search.ts` `account.ts` `messages.ts` | 搜索历史/热搜、账号绑定、私信会话 |
| `notifications.ts` `users.ts` | 通知列表/未读、关注/取关/资料/粉丝 |
| `admin.ts` | 待审帖/审核/举报列表/封禁（auth + adminAuth）|
| `notificationPrefs.ts` `block.ts` `dislike.ts` `privacy.ts` `export.ts` `push.ts` | 通知偏好、拉黑、不喜欢、隐私设置、数据导出、推送 token 注册 |

### 5.3 服务（services/，22 个）

| 服务 | 职责 |
|---|---|
| `postService` `commentService` `tagService` | 帖子 CRUD/列表/每日一帖、评论、标签 |
| `accessControl` `blockService` `dislikeService` `followService` | 可见性守卫（拉黑/隐私/不喜欢）、拉黑、不喜欢、关注 |
| `authService` `huaweiAuth` `huaweiPush` | 登录/注销、华为换 token/拉资料（真实 Account Kit）、华为推送（凭证缺失降级 no-op）|
| `notificationService` `notificationPrefService` `privacyService` | 通知落库+推送、偏好开关、隐私设置 |
| `sensitiveWordService` `reportService` `moderationService` | Aho-Corasick 敏感词单例、举报+阈值自动下架、审核 |
| `searchService` `exportService` `uploadService` | 搜索历史/热搜、数据导出、COS/本地预签名 |
| `interactService` `messageService` `accountBindingService` | 顶/收藏、私信+权限、账号绑定/解绑 |

### 5.4 中间件 / 配置 / 工具

- `middleware/`：`auth`（JWT 软/硬鉴权）、`adminAuth`、`asyncHandler`、`errorHandler`、`rateLimit`（全站/登录/上传专项限流）
- `config/env.ts`：集中解析全部环境变量 + 生产安全校验（https 强制等）
- `utils/`：`errors.ts`（SensitiveWordError/ValidationError）、`response.ts`（统一 code/data/message）、`userView.ts`（用户脱敏视图）

### 5.5 Prisma 与数据

- `prisma/schema.prisma`：21 个模型——User/Post/Comment/CommentUp/Up/Bookmark/Tag/UserFollowTag/SearchHistory/UserBinding/Notification/PushToken/Follow/Report/NotificationPreference/Blocklist/Dislike/PrivacySettings/DebateVote/Message
- `prisma/seed.ts`：30 个话题标签种子；`seed-post.ts`：示例帖子+作者+评论
- `prisma/*.sql`：升级/回滚 SQL（隐私同意、主页背景、PushToken 索引）

### 5.6 脚本 / 部署 / 测试 / 数据

- `scripts/`：`migrate-cos.ts`（COS 旧桶→新桶 19k 对象迁移）、`cos-probe.ts`（COS 连通诊断）、`diag-images.ts`（DB 图片 URL 诊断）、`fix-images-localhost.ts`
- `deploy/`：`docker-compose.production.yml`（mysql+api+nginx）、`Dockerfile`、`nginx/default.conf.template`（TLS 反代）、`scripts/backup-mysql.sh`（mysqldump 备份留 14 天）、`.env.production.example`、`README.md`
- `tests/`：jest + ts-jest，19 个 `*.test.ts` 覆盖发帖/评论/关注/绑定/通知/审核/华为登录/敏感词/拉黑/举报/日推/隐私/导出/auth 中间件
- `data/`：`sensitive-words.txt`（519 行通用敏感词）、`gender-war-words.txt`（性别对立词库）
- 根配置：`package.json`（scripts：dev/build/start/test/prisma:generate/prisma:db-push/seed:tags）、`tsconfig.json`、`jest.config.cjs`、`docker-compose.yml`、`backup.sh`、`start.sh`（一键启动 + hdc 端口转发）、`DEPLOY.md`、`env.prod.example`、`.env.example`
- `nginx-static/privacy/index.html`：隐私政策静态页
- `uploads/`：本地图片落盘（开发模式）
- `.env`（不入库）：环境变量见下表

### 5.7 环境变量（.env）

| 变量 | 用途 |
|---|---|
| `PORT` / `DATABASE_URL` | 端口 / MySQL 连接串（mysql://youju:youju@localhost:3306/youju）|
| `JWT_SECRET` / `JWT_EXPIRES_IN` | JWT 密钥 / 有效期 |
| `BACKEND_PUBLIC_URL` / `CORS_ORIGIN` | 对外图片直链前缀 / 跨域白名单（生产必配）|
| `COS_SECRET_ID/KEY/BUCKET/REGION/CDN_BASE` | 腾讯云 COS（图片直传，桶 `youju-1440002925`）|
| `OSS_*` / `CDN_BASE` | 兼容 OSS 备用项（留空）|
| `HUAWEI_CLIENT_ID/SECRET/REDIRECT_URI` | 华为登录 Account Kit（client_id = 6917613566723435312）|
| `HUAWEI_PUSH_APP_ID/APP_SECRET/TOKEN_URL/API_URL` | 华为推送 Push Kit（未配置则静默降级）|

---

## 六、设计资产（design/）

| 目录 | 职责 |
|---|---|
| `logo-concepts/` | **历史归档**：早期大蓝书书本方向（bbb-mark v4-6、archive-*），不再使用 |
| `youju-logo-concepts/` | **当前品牌**：v1-proof-frame / v2-citation-anchor（已应用）/ v3-verified-quote，含 signature/character/material 方向与多尺寸 PNG |

---

## 七、文档、交付物与导出

| 目录 | 内容 |
|---|---|
| `docs/` | `system_design.md`（帖子搜索）、`huawei_login_design.md`（Account Kit 登录）、`nav-migration-design.md`（跨 Tab 跳转）+ 4 个 mermaid |
| `soft_output/` | 源代码导出快照（前/后 1500 行、30 页分页 txt + 60 页 PDF，供评审）|

---

## 八、静态与营销文件

| 文件 | 职责 |
|---|---|
| `README.md` | 项目一句话简介 |
| `overview.md` | 内容审核 & 举报系统交付概览 |
| `VERSION.md` / `CHANGELOG.md` | 版本信息（0.1.0 内测）/ 0.1.0 安全合规改动 |
| `LICENSE` | 开源许可 |
| `privacy-policy.html` | 隐私政策（上架必需，后端也托管一份）|
| `landing/index.html` | 营销落地页「理性生活经验社区」|

---

## 九、工具脚本

| 脚本 | 职责 |
|---|---|
| `extract_soft_work.sh` | 收集全部 ets/ts 去空行，导出前后各 1500 行 + 分页文件 |
| `convert_docs.sh` | 合并文档分页并转 PDF（cupsfilter）|

---

## 十、开发辅助目录

| 目录 | 说明 |
|---|---|
| `.github/workflows/` | 后端 CI |
| `.hvigor/ .idea/ .vscode/ .appanalyzer/ .arts/` | IDE/构建缓存（不入库）|
| `.workbuddy/memory/` | Agent 工作记忆（不入库）|

---

## 附：核心链路速查

1. **登录**：`LoginPage` → `HuaweiLoginButton`（Account Kit 授权码）→ `POST /v1/auth/huawei/exchange` → `huaweiAuth` 换 token → JWT 回写 `auth.ets`
2. **信息流**：`HomeTab` → `api.ets listPosts` → `/v1/posts` → `postService`（accessControl 过滤拉黑/隐私/不喜欢）
3. **发图**：`PhotoPublishPage` → `getUploadSignature`（COS 预签名）→ 直传 COS → 发布保存 viewUrl
4. **文字封面**：`textPoster` 离屏绘制 → 上传 COS → 存 coverImage
5. **分享卡片**：`shareCard` 离屏绘制 → 写沙箱 → `systemShare` 面板（图片）
6. **图片展示**：后端存 viewUrl（COS GET 预签名）→ 前端 `resolveDisplayImageUrl` 归一化
