# PRD · 关注流 feed（大蓝书 · 增量）

> 文档类型：增量 PRD（聚焦**变更部分**）——在已上线社区 App 基础上，首页新增「仅关注的人发布的帖子」信息流
> 版本：V0.1 草稿（待架构师 / 主理人拍板待确认问题）
> 作者：许清楚（产品经理）
> 关联系统：HarmonyOS NEXT 前端（ArkTS/ArkUI）· 后端 Node.js + Express + Prisma + MySQL（端口 3000）
> 增量基线：
> - 关注关系已上线（commit b84fee2）：`Follow` 表（`followerId`/`followingId`/`@@unique([followerId,followingId])`/`@@index([followingId])`）已落库，关注/取关/他人主页/关注粉丝列表/关注通知均已可用。
> - 后端 `postService.listPosts(params)`（`postService.ts:15-63`，`ListParams:5-12`）仅支持公开流（`status:1`，`tag`/`author`/`keyword`/`sort` 过滤），**无 userId 上下文、无 following 过滤**。
> - 前端 `HomeTab.ets` 顶部为「三子 Tab（热榜/最新/推荐）+ 搜索框」+ `TagNav` + 帖子网格，数据源为 `listPosts`（`api.ets:160`）。
> - 后端统一响应 `{ code, data, message }`，鉴权 `Authorization: Bearer <token>`；前端登录态由 `AppStorage['authToken']` 统一管理（`api.ets` 的 `request` 自动带 token）。

---

## 1. 变更概述（一句话）

在「大蓝书」首页顶部新增「推荐 / 关注」分段切换，其中「关注」指**仅展示当前用户关注的人发布的公开帖子**，复用已就绪的关注关系数据，是一个**必须鉴权**的独立信息流；本期只做 P0：关注流切换 + 未登录引导 + 空态。

---

## 2. 用户故事

1. **作为**已关注多人的社区成员，**我希望**在首页一键切到「关注」流，**以便**快速看到我认可的人最新发布的生活经验，而不被全站公开内容稀释。
2. **作为**未登录用户，**我希望**点「关注」时收到清晰的登录引导而非报错空屏，**以便**我先登录、登录后自动看到关注流，降低流失。
3. **作为**关注了人但对方还没发帖的用户，**我希望**「关注」流给出明确空态（区分"没关注人"和"关注的人没发帖"），**以便**我知道下一步该去关注人或耐心等待。

---

## 3. 需求池

> 优先级：**P0 = 本期必须上线**；**P1 = 重要，下期**；**P2 = 锦上添花**。
> 本期范围严格限定 **P0**：关注流切换 + 未登录引导 + 空态。其余仅记录，不排期。

### P0（本期必须）

**P0-1 后端：新增 `GET /v1/posts/following`（独立鉴权端点）**
- 描述：挂 `auth` 中间件，内部调用 `postService.listPosts({ following: true, viewerId, sort, tag, keyword, page, limit })`。
  - 先 `prisma.follow.findMany({ where:{ followerId: viewerId }, select:{ followingId:true } })` 取被关注者 id 列表；
  - 列表为空 → 直接返 `{ list: [], pagination: { page, limit, total: 0 } }`（**不查 post 表**）；
  - 非空 → `where.userId = { in: ids }`，其余 `tag`/`keyword`/`sort`/`page`/`limit` 过滤与公开流一致复用。
  - 响应结构与公开流完全一致：`{ list: Post[], pagination: { page, limit, total } }`（前端 `ListResult<Post>` 直用，零改解析）。
- **前后端改动点（后端）**：
  - `backend/src/routes/posts.ts`：新增 `router.get('/following', auth, handler)`。**⚠️ 必须注册在现有 `router.get('/:id', ...)`（`posts.ts:23`）之前**，否则 Express 会把 `/following` 当作 `:id=following` 命中详情路由，导致 401/解析错误。
  - `backend/src/services/postService.ts`：
    - `ListParams` 接口（`postService.ts:5-12`）增加 `following?: boolean; viewerId?: number;`；
    - `listPosts` 内（`postService.ts:20-63`）在组装 `where` 后、`findMany` 前插入 following 分支（见 §6 伪码）。
  - 不改造公开 `GET /v1/posts`，保持零回归。
- 验收标准：
  1. 缺/过期 token → `code 401` + HTTP 401（由 `auth` 中间件统一返回）。
  2. viewerId 关注 0 人 → 返回 `{ list:[], pagination:{...,total:0} }`，HTTP 200。
  3. 关注多人 → 返回仅这些人的公开帖（含 `user` 字段，复用现有 `include`）；`total` 正确；分页正常。
  4. `tag`/`keyword`/`sort` 在关注流内叠加生效（本期默认支持，见 Q1）。

**P0-2 前端：`api.ets` 新增关注流列表封装**
- 描述：新增 `listFollowingPosts(params: { page?, limit?, sort?, tag?, keyword? })`，请求 `GET /v1/posts/following`，返回 `ListResult<Post>`。
- **前后端改动点（前端）**：`entry/src/main/ets/services/api.ets` 新增函数（复用现有 `toQuery` / `api.get`）。
- 验收标准：入参透传与 `listPosts` 对称；响应类型与 `ListResult<Post>` 一致。

**P0-3 前端：`HomeTab` 顶部「推荐 / 关注」分段切换（与三子 Tab 正交）**
- 描述：在 `HomeTab` 现有顶栏**之上**新增一行分段控件 `推荐 | 关注`（样式见 §4.1）。
  - **推荐** = 现有全站公开流（`listPosts`，三子 Tab 热榜/最新/推荐作为排序器继续生效）。
  - **关注** = 仅关注的人（`listFollowingPosts`）。
  - 两者**正交**：主分段选「信息源」，三子 Tab 选「排序」，可任意组合；`TagNav` 标签筛选对两流均生效。
  - 切换分段 → 重置 `page`、清空列表、重新拉取（同现有 `onTagChanged`/`sortIndex` 的 `refresh()` 逻辑）。
- **前后端改动点（前端）**：`entry/src/main/ets/components/HomeTab.ets`：
  - 新增 `@State feedMode: 'recommend' | 'following' = 'recommend'`；
  - 改造 `fetch(reset)`：依 `feedMode` 分支调用 `listPosts` 或 `listFollowingPosts`（其余 `sort`/`tag`/`page`/`limit` 透传不变）；
  - `aboutToAppear` 默认加载「推荐」流（公开，无需登录）。
- 验收标准：分段切换即时生效；三子 Tab/标签在两种流下均正常；「关注」流数据仅含被关注者帖子（用多账号验证）。

**P0-4 前端：`HomeTab` 未登录引导态（关注流）**
- 描述：切到「关注」且 `authToken` 为空时，**不发起请求**，展示登录引导态（见 §4.3），并提供「登录」按钮。
- **前后端改动点（前端）**：`HomeTab.ets` 照搬 `MessagePage.ets:36-52` 的 `@StorageLink('authToken') @Watch('onTokenReady')` 模式：
  - 新增 `@StorageLink('authToken') @Watch('onTokenReady') token: string = ''`；
  - 切到关注且 `token===''` → 置 `needLogin=true`、不拉数据；
  - `onTokenReady()`：若 `token!=='' && feedMode==='following' && 列表空 && 无 error` → 自动 `refresh()` 关注流；
  - 「登录」按钮：复用现有登录入口（自动登录 stub / `LoginPage`），登录成功后由 `@Watch` 触发自动加载。
- 验收标准：未登录点「关注」→ 显示引导态而非报错；登录后引导态消失、自动加载关注流；不出现 401 报错刷屏。

**P0-5 前端：`HomeTab` 关注流空态 / 错误态**
- 描述：复用现有加载中、错误+重试态；新增关注流专属空态，并**区分两种空原因**（见 §4.2）：
  - 空原因 A：**未关注任何人**（`total===0` 且 viewer 关注数为 0，前端可用 `getUserProfile(me)` 的 `followingCount` 判定，或直接按"列表空"给出通用引导）→ 文案「你还没有关注任何人，去发现有趣的人吧」+「去发现」按钮（跳圈子 Tab / 他人主页）。
  - 空原因 B：**关注了人但无人发帖**（列表空但关注数>0）→ 文案「你关注的人还没有发布内容，去催更吧」。
- **前后端改动点（前端）**：`HomeTab.ets` 列表区空态分支增加 `feedMode==='following'` 的专属文案与「去发现」跳转；错误态复用现有「⚠️ + 加载失败 + 重试」。
- 验收标准：两空态文案区分正确；「去发现」可达；错误态重试可用；关注流与推荐流的加载/错误态不互相污染。

### P1（重要，下期，仅记录不排期）

**P1-1 「圈子」Tab 增加「我关注的人的帖子」入口**：将关注流能力从首页扩展/联动到圈子 Tab（避免入口孤岛）。需确认是否复用同一端点或独立展示（见 Q2）。
**P1-2 关注流「新动态」红点 / 已读游标**：关注流新增内容时首页「关注」分段上红点提示；需要后端返回"上次查看时间后的新增数"或前端本地游标。属增量，非本期。
**P1-3 关注流排序「关注时间」维度**：在三子 Tab 之外增加"最新关注的人优先"等社交排序（依赖 `Follow.createdAt`）。

### P2（锦上添花，仅记录）

**P2-1 关注流智能推荐降权/提权**：基于互动（点赞/评论）对关注流做轻排序优化。
**P2-2 多人 IN 查询性能保护**：关注人数极大时（如 >500），`userId in [...]` 的查询性能与游标分页优化（参考原 PRD P2-2 冗余计数思路）。

---

## 4. UI 设计稿（文字描述）

> 设计语言继承产品规范：Apple 极简风、深色优先、卡片圆角 12pt、主品牌色 `#0A84FF`、次要文字 `#8E8E93`、分割线 `#38383A`、最小点击区 44pt。与已落地关注功能（design-follow-profile.md）视觉一致。

### 4.1 首页顶部「推荐 / 关注」分段控件（HomeTab 新增最顶行）

- **位置**：`HomeTab` 现有顶栏（三子 Tab + 搜索框）**之上**、Tab 栏之内新增一行，全宽。
- **样式**：分段控件（`Segmented` 风格），两端等宽胶囊，左「推荐」右「关注」；选中态品牌色实心底白字，未选中态透明底 + 次要色字；高度约 32pt，左右边距 16pt，与下方三子 Tab 之间留 8pt 间距。
- **语义**：选「推荐」→ 下方三子 Tab（热榜/最新/推荐）作为**全站公开流排序器**；选「关注」→ 下方三子 Tab 作为**关注流排序器**（正交叠加）。搜索框在两种流下都保留（搜索走现有结果页，不受分段影响）。

```
┌──────────────────────────────────────────────┐
│  [ 推荐 | 关注 ]   ← 新增分段控件（最顶行，全宽） │
├──────────────────────────────────────────────┤
│  热榜  最新  推荐          🔍 搜索   ← 现有顶栏 │
│  ──                              (三子Tab+搜索) │
├──────────────────────────────────────────────┤
│  🔥全部  数码  健身  ……          ← TagNav 标签栏 │
├──────────────────────────────────────────────┤
│  ┌────┐ ┌────┐                                │
│  │post│ │post│   ← 帖子网格（关注流=仅关注的人）│
│  └────┘ └────┘                                │
└──────────────────────────────────────────────┘
```

### 4.2 关注流列表区：加载 / 空态 / 错误态

- **加载中**（首屏且列表空）：复用现有 `LoadingProgress` + 「加载中…」居中（同 `HomeTab.ets:207-214` / `MessagePage`）。
- **错误态**（请求失败）：复用现有 `⚠️ + 加载失败：<msg> + 重试按钮`（同 `HomeTab.ets:217-230`）；关注流 401 不应出现（未登录已被 P0-4 引导态拦截）。
- **空态（关注流专属，需区分两因）**：

```
关注流空态 A：未关注任何人
┌──────────────────────────────────────┐
│           （插画/图标占位）            │
│   你还没有关注任何人                  │
│   去发现有趣的人，关注后这里就有内容   │
│        [ 去发现 ]   ← 跳圈子/他人主页  │
└──────────────────────────────────────┘

关注流空态 B：关注了人但无人发帖
┌──────────────────────────────────────┐
│           （插画/图标占位）            │
│   你关注的人还没有发布内容            │
│   去他们的主页催更吧～                │
└──────────────────────────────────────┘
```
- 判定：空态 A vs B 由「viewer 关注数」区分（前端调用已存在的 `getUserProfile(me).followingCount`，或关注流 `total===0` 时结合一个轻量计数；若无计数接口则统一用空态 A 文案 + 去发现，避免额外依赖——见 Q3）。
- 「去发现」按钮：跳 `router.pushUrl({ url: 'pages/CircleTab' 或他人主页 })`（具体目标页由前端按现有导航定，不阻塞本期）。

### 4.3 未登录引导态（关注流，P0-4）

- **触发**：`feedMode==='following'` 且 `authToken===''`。
- **样式**：占据列表区，`Column` 居中，含图标/插画 + 文案「登录后查看你关注的人发布的帖子」+ 主按钮「登录」。

```
未登录 · 关注流引导态
┌──────────────────────────────────────┐
│           （登录图标占位）             │
│   登录后查看你关注的人                │
│   关注的人发了什么，这里第一时间看到   │
│        [ 登录 ]   ← 触发登录入口      │
└──────────────────────────────────────┘
```
- **登录按钮行为**：复用现有登录能力（自动登录 stub / `LoginPage`）。登录成功 → `PersistentStorage` 回写 `authToken` → `@Watch('onTokenReady')` 触发 → 引导态消失、自动 `refresh()` 关注流。期间不发起任何 `/following` 请求，避免 401 刷屏。
- 此模式与 `MessagePage.ets:36-52` 完全同构，仅把"列表加载"替换为"关注流加载"，零新机制。

### 4.4 关键交互流程（Mermaid）

**切换关注流（含未登录引导）**

```mermaid
flowchart TD
    A[HomeTab 默认 推荐流加载 公开帖] --> B[用户点 关注 分段]
    B --> C{authToken 非空?}
    C -- 否 --> D[展示 未登录引导态 不请求]
    D --> E[点 登录 → 登录成功]
    E --> F[@Watch onTokenReady 触发]
    F --> G[refresh 关注流]
    C -- 是 --> G
    G --> H{GET /v1/posts/following}
    H -- 关注0人 total=0 --> I[空态A 去发现]
    H -- 关注>0 但无帖 --> J[空态B 催更]
    H -- 有帖 --> K[渲染关注流网格]
    H -- 失败 --> L[错误态 重试]
```

**关注流数据来源（后端）**

```mermaid
flowchart TD
    R[GET /v1/posts/following auth] --> S[listPosts following:true viewerId]
    S --> T[prisma.follow.findMany followerId=viewerId select followingId]
    T --> U{ids 空?}
    U -- 是 --> V[return list:[] total:0]
    U -- 否 --> W[where.userId in ids + tag/keyword/sort]
    W --> X[prisma.post.findMany + count]
    X --> Y[{list, pagination}]
```

---

## 5. 待确认问题（仅剩真正要拍板的）

> 以下功能/决策本期已按推荐项直接设计，仅列供主理人最终确认；如需调整请明确。

### Q1 关注流是否支持「标签 / 排序 / 关键词」叠加筛选？
- **现状**：公开流已支持 `tag`/`sort`/`keyword`；关注流端点沿用同一 `listPosts`，技术上叠加零成本。
- **推荐**：**支持叠加**。`sort`（热榜/最新/推荐）默认生效（与三子 Tab 正交）；`tag` 标签栏默认生效；`keyword` 走搜索结果页（不在首页流内）。即关注流 = 公开流过滤器 + `userId in 关注集合`。
- **请拍板**：是否确认关注流继承全部现有过滤器（推荐是）？还是首版只保留 `sort`、暂不做 `tag` 叠加（更简单）？

### Q2 「关注流」入口是否还放进「圈子」Tab？
- **现状**：本期仅首页顶部「推荐/关注」分段。圈子 Tab 当前为标签/圈子维度。
- **推荐**：**本期仅首页入口**，圈子 Tab 不动（避免范围蔓延）；下期 P1-1 再评估是否在圈子 Tab 内增设「我关注的人」子视图。
- **请拍板**：确认本期只做首页入口？（推荐是）

### Q3 空态 A/B 的区分是否需要额外计数接口？
- **现状**：区分"未关注任何人" vs "关注了但没发帖"需知 viewer 的 `followingCount`。该值 `GET /v1/users/:id` 已返回（含 `me`），前端可复用 `getUserProfile(me).followingCount`。
- **推荐**：**复用现有 `getUserProfile(me).followingCount`**（零新接口）。若团队认为为"空态判定"多调一次接口不值，则**统一用空态 A 文案 + 去发现**（不区分 B）。两种均不影响本期上线。
- **请拍板**：① 复用 `getUserProfile(me)` 区分 A/B（推荐）；② 还是统一空态 A 不区分？

### Q4 「关注」分段默认选中项 / 记忆？
- **现状**：`HomeTab` 每次 `aboutToAppear` 默认推荐流。
- **推荐**：默认「推荐」，不跨会话记忆（简单、符合预期）；如需记忆上次选择可下期加 `AppStorage` 持久化。
- **请拍板**：默认推荐、不记忆（推荐）？还是记忆上次分段？

---

## 6. 核心结论速览（给架构师 / 主理人）

- **数据复用**：完全复用已上线的 `Follow` 表与关注关系数据，**零新表、零新字段、零迁移**。
- **后端接口（新增 1 个，不改造公开流）**：
  - `GET /v1/posts/following`（挂 `auth`）→ 内部 `listPosts({ following:true, viewerId, sort, tag, keyword, page, limit })`，先取 `follow` id 列表、空则直返空、非空则 `where.userId in ids`。
  - ⚠️ **路由顺序坑**：`posts.ts` 的 `GET /following` **必须写在 `GET /:id` 之前**，否则被 `:id` 拦截。
- **后端文件改动点**：
  - `backend/src/services/postService.ts`：`ListParams` 增 `following?`/`viewerId?`；`listPosts` 增 following 分支（伪码）：
    ```ts
    if (params.following && params.viewerId) {
      const follows = await prisma.follow.findMany({
        where: { followerId: params.viewerId },
        select: { followingId: true },
      });
      const ids = follows.map((f) => f.followingId);
      if (ids.length === 0) {
        return { list: [], pagination: { page, limit, total: 0 } };
      }
      where.userId = { in: ids };
    }
    ```
  - `backend/src/routes/posts.ts`：新增 `router.get('/following', auth, ...)`（位置在 `/:id` 前）；`import { auth }` 已存在于该文件（`posts.ts:3`）。
- **前端改动点**：
  - `entry/src/main/ets/services/api.ets`：新增 `listFollowingPosts(params)`（`GET /v1/posts/following`，返 `ListResult<Post>`）。
  - `entry/src/main/ets/components/HomeTab.ets`：新增 `feedMode` 分段状态 + 顶部分段控件；`fetch` 按 `feedMode` 分支；`@StorageLink('authToken') @Watch` 登录引导；关注流专属空态/去发现/未登录引导态。
  - 复用：`TagNav`、`PostCard`、现有加载/错误态、`getUserProfile(me)`（空态区分可选）、`MessagePage` 登录态监听模式。
- **零新依赖**：后端仅 Prisma 原生 `follow.findMany`；前端仅 ArkUI 内置（`@StorageLink`/`@Watch`/`Segmented`/条件渲染）。
- **本期范围**：仅 P0（关注流切换 + 未登录引导 + 空态）。P1（圈子入口/红点）、P2（排序优化/性能）仅记录。
- **关键待拍板**：Q1 过滤器叠加范围、Q2 是否仅首页入口、Q3 空态 A/B 区分方式、Q4 默认分段与记忆。
```
