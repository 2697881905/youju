# 大蓝书 前后端设计与交互审查报告

**日期**：2026-07-20
**场景**：只读架构/接口/安全/性能审查（不改动代码）
**审查范围**：`backend/`（Express + Prisma + JWT）与 `entry/src/main/ets/`（ArkTS/HarmonyOS）
**说明**：原计划以 GStack 团队（产品评审员 / 安全官 / QA）协作完成，但本运行环境未注册 `gstack-*` 子代理，三人组均未能启动。本报告由主理人（软件工坊 CEO）直接基于源码逐文件核查完成，结论均附文件:行号，未杜撰成员产出。

---

## 📌 TL;DR（执行摘要）

- 整体结论：🟡 有条件通过（核心功能可用，但存在 2 个高危/中危阻断项需在投产前修复）
- 阻断项：① JWT 硬编码回退密钥（生产若漏配即可伪造 token）；② 缺少全局错误处理 + 多路由无 try/catch（异步异常导致请求挂起/进程不稳）
- 发现统计：🔴 2 / 🟠 8 / 🟡 12 / 🟢 3
- 亮点：删除类接口走 service 层做归属校验（无 IDOR）、举报/关注/点赞幂等约束完善、admin 路由统一 `router.use(auth, adminAuth)`、列表查询已规避 N+1、分页上限已封顶。

---

## 🎯 核心结论卡片

| 项目 | 内容 |
|------|------|
| Go / No-Go | 🟡 条件 Go（修复 S1 + E1 后可上线） |
| 严重度分布 | 🔴 2 / 🟠 8 / 🟡 12 / 🟢 3 |
| 关键行动项 | 6 条（见文末行动清单，P0×2） |
| 建议负责人 | 后端 owner + 安全 review |

---

## 1. 分项审查发现

### 1.1 接口设计（API Design）

- **A1 🟡 路由前缀冗余/歧义**：`authRouter` 同时挂在 `/v1/auth` 与 `/v1/users`（`app.ts:30-31`），导致 `/v1/users/me` 与 `/v1/auth/me` 并存、`GET /v1/users/:id` 与 authRouter 共用前缀。功能可用但易引发维护期路由错配。
- **A2 🟡 搜索接口语义不一致**：`search.ts:33` `GET /hot` 要求 `auth`（热搜本应公开）；`search.ts:21/22` 历史列表 `limit` 无上限（`Number(req.query.limit)` 未封顶）。
- **A3 🟡 评论列表分页契约疑似不一致**：`comments.ts:23` 调 `commentService.listComments(postId, page)`，返回形状需确认是否与其他列表一致（`{list, pagination:{page,limit,total}}`）。若仅返回裸数组，前端无法分页。
- **A4 🟢 标签路径参数用 `:name`**：`tags.ts:16/26` 以标签名（含中文/特殊字符）作 URL 路径参数，前端须 `encodeURIComponent`，建议改用 `tagId` 或文档化编码要求。
- **正向**：举报理由枚举在前后端各定义一份（`posts.ts:30`、`comments.ts:12`、`types.ets`、`reportService`），值一致；`ModerateAction`、`PendingPost` 等类型前后端对齐。

### 1.2 数据交互（Data Interaction）

- **D1 🟡 响应体泄露 OAuth 标识**：`authService.login/getMe` 返回完整 Prisma `User`（`authService.ts:29,42,59` 的 `withIsAdmin(user)`），含 `openId`/`unionID`。前端 `User` 类型不需要这些字段，属敏感第三方标识泄露，可用于跨账号关联。
- **D2 🟡 错误码/HTTP 状态偶发不一致**：`fail(res, code, msg, httpStatus=400)`（`response.ts:20`）默认 HTTP 400；当 `code=404/403` 但未显式传 `httpStatus` 时，HTTP 状态与业务码错位（现有调用多数已显式传，存在遗漏风险）。
- **D3 🟡 前端对 401/403 无统一处置**：`api.ets:46-51` 仅 `code!==0` 抛 message，未针对 401 清空会话并跳登录。token 过期时仅 toast，用户须手动重登。
- **D4 🟢 前后端契约整体对齐**：`isAdmin`、`reports[].reporter.nickname`、`pagination` 等已在本次审核台开发中补齐，结构对应正确。

### 1.3 业务逻辑（Business Logic）

- **B1 🟠 删帖未处理级联/孤儿数据**：`Post` 与 `Comment`/`Up`/`Bookmark` 关系在 `schema.prisma:57-59` **未声明 `onDelete`**。若迁移生成的 FK 为 `RESTRICT`，`deletePost`（`postService.ts:165`）删带互动的帖子会抛 FK 异常；而 `posts.ts:101` 删除路由无 try/catch → 未捕获异常（见 E1）。若放任无约束则留孤儿行。
- **B2 🟡 自关注未显式防护**：`users.ts:14` 将 `req.params.id` 直传 `followService.followUser`，需确认 service 内是否 `if(targetId===viewerId) throw`。建议 service 层显式拦截。
- **B3 🟡 审核为"事后"模式**：`createPost` 直接 `status:1` 发布（`postService.ts:160`），仅举报达阈值才 `status=0`。sub-threshold 举报仅落 `Report` 表，审核台只看阈值命中帖，低阈值举报易被淹没；且 `/admin/reports` 需确认分页与状态过滤。
- **B4 🟡 计数非事务维护**：`upCount/commentCount/bookmarkCount` 由独立 `update` 维护，高并发可能漂移。建议事务或读取时聚合/DB 触发器。
- **B5 🟢 详情评论 `take:50` 硬编码无分页**（`postService.ts:125`），超长帖评论截断。
- **正向**：`deletePost`/`deleteComment` 均经 service 校验归属（返回 `forbidden`），无越权删帖；举报/关注/点赞均有唯一约束保证幂等。

### 1.4 安全性（Security）

- **S1 🔴 JWT 硬编码回退密钥**：`env.ts:8` `jwtSecret: process.env.JWT_SECRET ?? 'dev-secret-change-me'`。生产若漏配 `JWT_SECRET`，任何人都可用公开密钥伪造任意用户/管理员 token，完全绕过鉴权。
- **S2 🟡 OAuth 标识泄露**：见 D1（`openId`/`unionID` 入响应）。
- **S3 🟡 通配 CORS**：`app.ts:18` `app.use(cors())` 默认 `Access-Control-Allow-Origin: *`。原生 App 影响小，但若将来有 Web 管理台或带凭证场景则危险。
- **S4 🟠 无速率限制**：举报/关注/点赞/登录均无频控。举报无限制可被用来批量打压他人内容；登录无防爆破。
- **S5 🟡 JWT 算法未锁定**：`middleware/auth.ts:17` `jwt.verify` 未传 `algorithms:['HS256']`，防御性不足（当前字符串密钥使 `alg:none` 不可行，仍建议显式锁定）。
- **S6 🟡 敏感词检测范围不全**：`postService.createPost:146` 仅拼 `title+content`，`tags`/`structuredData` 未检测。
- **S7 🟢 兜底错误回显**：`account.ts:71` 等兜底返回 `err.message`，若含内部信息会泄露（当前 Prisma 错误较安全，建议统一通用文案）。
- **正向**：admin 路由统一 `router.use(auth, adminAuth)`（`admin.ts:15`）；删除/绑定类接口强制以 `req.userId` 过滤（`account.ts`、`users.ts` 经 service 校验），无 IDOR。

### 1.5 错误处理 / 性能 / 可扩展性

- **E1 🔴 无全局错误处理中间件 + 多路由无 try/catch**：`app.ts` 末尾无 4 参数 error handler；以下路由异步异常将变为未捕获 Promise rejection，客户端请求挂起：`posts.ts` GET `/`、`/following`、`/:id`；`comments.ts` GET comments；`interact.ts` 全部 4 个；`search.ts` 全部；`tags.ts`；`notifications.ts` 多个；`admin.ts`。
- **E2 🟠 `interact.ts` 零 try/catch**：取消未点赞/对不存在帖子点赞抛 Prisma 异常 → 挂起（`interact.ts:10-31`）。
- **P1 🟠 `Post` 缺索引**：feed 查询 `where{status:1}` + `orderBy createdAt/upCount` + `userId`/`tags` 过滤无复合索引（`schema.prisma:38`）。建议 `@@index([status, createdAt])`、`@@index([status, upCount])`、`@@index([userId])`。
- **P2 🟠 `Comment` 缺 `@@index([postId])`**：`getPost` 与 `listComments` 按 postId 查会全表扫描（`schema.prisma:63`）。
- **P3 🟠 `Follow` 索引不对称**：仅有 `@@index([followingId])`（`schema.prisma:179`），但关注流与"我关注列表"用 `followerId` 查 → 缺 `@@index([followerId])`。
- **P4 🟡 Json 列 `tags` 过滤慢**：MySQL 对 Json `array_contains` 索引支持有限，热标签建议改关系表 `PostTag`。
- **P5 🟢 N+1 已规避**：`postService.listPosts` 用批量 `in` 查询打标 `myUp/myBookmark`，设计良好。
- **P6 🟡 无请求体大小限制**：`express.json()` 未设 `limit`，超大 content/images JSON 可被接受（DoS 风险低但应设限）。

---

## 2. 综合发现表（按严重度）

| # | 严重度 | 类别 | 位置 | 问题描述 | 建议 |
|---|--------|------|------|---------|------|
| S1 | 🔴 | 安全 | env.ts:8 | JWT 硬编码回退密钥，漏配即伪造 token | 缺失即启动失败 / 读密钥管理，禁止默认值 |
| E1 | 🔴 | 错误处理 | app.ts / posts.ts / interact.ts / search.ts 等 | 无全局 error handler + 多路由无 try/catch，异步异常挂起 | 加全局 500 handler + asyncHandler 包裹 |
| B1 | 🟠 | 业务 | schema.prisma:57-59 / postService.ts:165 | 删帖无 onDelete，FK 冲突或留孤儿 + 路由无 catch | 显式 onDelete:Cascade 或事务清理 |
| E2 | 🟠 | 错误处理 | interact.ts:10-31 | up/cancelUp/bookmark 无 try/catch，异常挂起 | service 返回结构化结果并包裹 |
| S4 | 🟠 | 安全 | 全局 | 举报/关注/登录无速率限制 | 加滑动窗口限流（redis/内存） |
| P1 | 🟠 | 性能 | schema.prisma:38 | Post 缺 status/createdAt/upCount/userId 复合索引 | 加 @@index |
| P2 | 🟠 | 性能 | schema.prisma:63 | Comment 缺 postId 索引 | @@index([postId]) |
| P3 | 🟠 | 性能 | schema.prisma:179 | Follow 缺 followerId 索引 | @@index([followerId]) |
| D1/S2 | 🟡 | 安全/数据 | authService.ts:29,42,59 | 响应泄露 openId/unionID | select 排除敏感字段 |
| D2 | 🟡 | 数据 | response.ts:20 | fail 默认 HTTP 400 与业务码偶发不一致 | httpStatus 默认跟随 code |
| D3 | 🟡 | 数据 | api.ets:46-51 | 401 无统一登出/跳登录 | 401→清会话跳登录 |
| A1 | 🟡 | 接口 | app.ts:30-31 | authRouter 双前缀冗余 | 单前缀 |
| A2 | 🟡 | 接口 | search.ts:21,33 | /hot 需 auth、limit 无上限 | /hot 改公开、limit 封顶 |
| A3 | 🟡 | 接口 | comments.ts:23 | 评论列表分页契约疑似不一致 | 统一分页形状 |
| B2 | 🟡 | 业务 | users.ts:14 | 自关注防护待确认 | service 内拦截 |
| B3 | 🟡 | 业务 | postService.ts:160 | 审核纯事后模式，低阈值举报淹没 | 明确策略 + reports 分页过滤 |
| B4 | 🟡 | 业务 | 计数字段 | 计数非事务维护，可能漂移 | 事务/聚合 |
| S3 | 🟡 | 安全 | app.ts:18 | 通配 CORS | 按需白名单 |
| S5 | 🟡 | 安全 | middleware/auth.ts:17 | JWT 算法未锁定 | algorithms:['HS256'] |
| S6 | 🟡 | 安全 | postService.ts:146 | 敏感词漏检 tags/structuredData | 扩展检测 |
| P4 | 🟡 | 性能 | schema.prisma:47 | Json tags 过滤慢 | 改关系表 |
| P6 | 🟡 | 性能 | app.ts:19 | 无请求体大小限制 | express.json({limit}) |
| A4 | 🟢 | 接口 | tags.ts:16,26 | :name 路径参数编码隐患 | 用 tagId |
| B5 | 🟢 | 业务 | postService.ts:125 | 详情评论无分页 | 独立分页接口 |
| S7 | 🟢 | 安全 | account.ts:71 等 | 兜底回显 err.message | 统一通用文案 |

---

## ✅ 行动清单

| # | 行动 | 负责方 | 紧急度 | 期望完成 |
|---|------|--------|--------|---------|
| 1 | `env.ts` 去除 JWT 硬编码默认值，缺失即启动失败；密钥走环境变量/密钥管理 | 后端 | P0 | 上线前 |
| 2 | 新增全局错误中间件 `app.use((err,req,res,next)=>...)` 统一返回 500；并用 asyncHandler 包裹无 catch 的路由 | 后端 | P0 | 上线前 |
| 3 | `interact.ts` 4 个路由加 try/catch（或 service 返回 {ok,reason}） | 后端 | P1 | 本周 |
| 4 | `Post/Comment/Follow` 补索引（status+createdAt、postId、followerId） | 后端 | P1 | 本周 |
| 5 | `authService` 登录/getMe 用 `select` 排除 openId/unionID；`fail` 的 httpStatus 默认跟随 code | 后端 | P1 | 本周 |
| 6 | 举报/关注/登录接入速率限制；`deletePost` 声明 `onDelete:Cascade` 或事务清理关联 | 后端 | P2 | 下迭代 |

---

## ⚠️ 待完善 / 已知局限

- 本审查未运行后端（仅静态读码）；索引缺失的实际影响需结合数据量压测确认。
- `commentService.listComments` / `followService.followUser`（自关注防护）/ `admin.ts` 内部实现未逐行展开，相关结论（A3/B2）以接口契约与路由层推断，建议实现层二次确认。
- 未涉及前端 UI 层（仅审查 `api.ets`/`auth.ets`/`types.ets` 与后端契约面）。
- GStack 三人组（产品评审员/安全官/QA）因运行环境未注册子代理未能并行产出，本报告为单一主理人直接审查结果。

---

## 📚 成员产出索引

- gstack-product-reviewer（产品评审员）：未能启动（环境未注册子代理）
- gstack-security-officer（安全官）：未能启动（环境未注册子代理）
- gstack-qa-lead（质量门神）：未能启动（环境未注册子代理）
- 实际产出：主理人直接审查（见上文）

---

> 本报告由软件工坊 AI 协作生成，关键决策请由工程负责人复核。
