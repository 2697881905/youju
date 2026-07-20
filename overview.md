# 内容审核 & 举报系统 - 交付概览

**项目**：大蓝书 HarmonyOS NEXT 应用
**日期**：2026-07-19
**团队**：software-content-moderation + software-bugfix-route-catch
**commit**：`9020fca`（已推送 main）
**SOP 流程**：PM PRD → 架构师设计 → 工程师实现 → QA 第 1 轮发现 P0 Bug → 工程师修复 → QA 第 2 轮 PASS

## TL;DR

完整落地「敏感词前置过滤 + 用户举报 + 开发者审核」三道防线，满足 UGC 社交应用上架合规要求。32 个文件 +3862/-38 行，jest 85/85 全绿，assembleHap BUILD SUCCESSFUL，prisma db push 已同步。

## 交付概览

| 项 | 状态 |
|----|------|
| 交付状态 | ✅ 已交付（推送 main） |
| 编译验证 | ✅ assembleHap BUILD SUCCESSFUL |
| 后端测试 | ✅ jest 85/85 全绿（既有 75 + 新增 10） |
| QA 验证 | ✅ 第 2 轮 PASS（第 1 轮发现 P0 Bug 已修复） |
| 已知问题 | 0 |
| 改动文件 | 32 个（17 新增 + 15 修改） |

## 核心功能

### 1. 敏感词前置过滤（第一道防线）
- **Trie 树自实现**（`sensitiveWordService.ts`，~60 行，无外部依赖）
- 启动时加载词库到内存单例（`backend/data/sensitive-words.txt` 50 词 + `gender-war-words.txt` 20 词）
- `checkText(text): boolean` O(n×L) 检测，大小写不敏感
- 发帖（title + content）和评论（content）前置检测，命中返回 400 + "内容含敏感词，请修改后重试"

### 2. 用户举报（第三道防线）
- **Report 表**（`@@unique([reporterId, targetType, targetId])` DB 级幂等）
- 7 个举报理由：political / pornographic / personal_attack / gender_war / advertisement / spam / other
- 帖子举报 + 评论举报入口（DetailPage ⋯菜单 + CommentList ⋯菜单）
- ReportDialog 弹窗：理由单选 + 补充说明（"其他"必填）+ 提交
- 重复举报返回 409 "你已举报过该内容"
- 举报阈值触发自动下架：`reportCount >= env.reportThreshold`（默认 3）→ status=0 + notifySystem 通知作者"正在审核中"

### 3. 开发者审核（第二道防线）
- **adminAuth 中间件**（env `ADMIN_USER_IDS` 逗号分隔，校验 req.userId）
- `GET /v1/admin/posts/pending` — 待审帖子列表（status=0）
- `POST /v1/admin/posts/:id/moderate` — 审核帖子
  - `approve` → status=1 + 通知作者"已通过审核" + 通知举报人"你的举报已处理"
  - `reject` → status=2 + 通知作者"未通过审核，原因：xxx" + 通知举报人"你的举报已处理"
  - 通知举报人不透露具体结果（保护被举报者隐私，Q7 决策）

### 4. 系统通知
- `notifySystem(userId, content, postId?)` 函数（actorId=null, type='system'）
- MessagePage 系统通知样式：品牌色圆 + 📢 图标，与普通通知区分

## 关键技术决策

| 决策点 | 方案 |
|--------|------|
| 敏感词检测 | 自实现 Trie 树（~60 行），非外部包，O(n×L) |
| 错误类型 | SensitiveWordError class（extends Error + reason 字段 + Object.setPrototypeOf 修复 instanceof 原型链） |
| 举报幂等 | Prisma `@@unique` DB 级保证 |
| admin 鉴权 | env `ADMIN_USER_IDS` 环境变量 |
| 举报阈值 | env `REPORT_THRESHOLD` 默认 3 |
| 通知策略 | 审核结果通知作者；举报处理仅通知举报人"已处理"不透露结果 |
| Comment.status | 新增 `@default(1)`，prisma db push 自动迁移 |
| ActionSheet | `showActionMenu` 本 SDK 不存在 → 降级 `showAlertDialog` 用 primaryButton/secondaryButton |
| request 函数 | 修改为先解析 body {code,message}，非 0 抛 new Error(message)，已验证无回归 |

## MVP 决策（PM + 主理人拍板）

- ❌ MVP 不强制人工前置审核（敏感词通过即 status=1 发布）
- ❌ 评论不前置审核（仅敏感词 + 举报触发）
- ❌ 被拒帖子不可修改重发（保持 status=2）
- ✅ 被下架帖子作者可见 + DetailPage 显示待审核横幅
- ✅ 举报处理通知不透露具体结果（保护被举报者隐私）

## P0 Bug 教训

**根因**：工程师自测时只跑了既有 75 个测试（全绿），但既有测试未覆盖 createPost/createComment 路由的敏感词拒绝路径，所以 bug 未被发现。

**Bug**：`posts.ts POST /` 和 `comments.ts POST /posts/:id/comments` 路由缺 try-catch，导致 service throw 变 unhandled rejection，客户端超时收不到 400 JSON。

**修复**：service 层 throw 改用 SensitiveWordError class，路由层 try-catch + instanceof 精确捕获，补充 10 个测试（含 2 个 P0 回归测试）。

**教训**：
1. async 路由必须 try-catch 包裹 service 调用（Express 4 不自动捕获 async rejection）
2. 自测不能只跑既有测试，要为新路径补测试

## 文件清单

### 新增 17 个文件

**后端服务层**：
- `backend/src/services/sensitiveWordService.ts` — Trie 树敏感词检测单例
- `backend/src/services/reportService.ts` — 举报服务（含阈值触发自动下架）
- `backend/src/services/moderationService.ts` — 审核服务（含通知触发）
- `backend/src/utils/errors.ts` — SensitiveWordError 自定义错误类

**后端中间件/路由**：
- `backend/src/middleware/adminAuth.ts` — admin 鉴权中间件
- `backend/src/routes/admin.ts` — admin 路由

**后端数据**：
- `backend/data/sensitive-words.txt` — 50 个通用敏感词
- `backend/data/gender-war-words.txt` — 20 个男女对立引战词

**后端测试**：
- `backend/src/services/sensitiveWordService.test.ts` — 5 测试
- `backend/src/services/reportService.test.ts` — 10 测试
- `backend/src/routes/admin.test.ts` — 8 测试
- `backend/src/routes/posts.test.ts` — 5 测试（含 P0 回归）
- `backend/src/routes/comments.test.ts` — 5 测试（含 P0 回归）

**前端**：
- `entry/src/main/ets/components/ReportDialog.ets` — 举报弹窗组件

**文档**：
- `entry/Docs/prd-content-moderation.md` — PRD（459 行）
- `entry/Docs/design-content-moderation.md` — 架构设计
- `overview.md` — 本概览

### 修改 15 个文件

**后端**：
- `backend/prisma/schema.prisma` — 新增 Report 模型 + Post.reportCount + Comment.status/reportCount
- `backend/src/config/env.ts` — 新增 adminUserIds、reportThreshold
- `backend/.env.example` — 新增 ADMIN_USER_IDS、REPORT_THRESHOLD
- `backend/src/services/notificationService.ts` — 新增 notifySystem 函数
- `backend/src/services/postService.ts` — createPost 前置敏感词 + 改用 SensitiveWordError
- `backend/src/services/commentService.ts` — createComment 前置敏感词 + 改用 SensitiveWordError
- `backend/src/routes/posts.ts` — POST / 加 try-catch + 新增 POST /:id/report
- `backend/src/routes/comments.ts` — POST /posts/:id/comments 加 try-catch + 新增 POST /comments/:id/report
- `backend/src/app.ts` — 注册 admin 路由 + 启动加载敏感词库
- `backend/package.json` — 新增 "test": "jest" 脚本

**前端**：
- `entry/src/main/ets/models/types.ets` — 新增 ReportReason + ReportBody + ReportTargetType
- `entry/src/main/ets/services/api.ets` — 新增 reportPost/reportComment + request 函数修改（透传 message）
- `entry/src/main/ets/pages/DetailPage.ets` — 顶部 ⋯菜单 + 待审核横幅 + 敏感词 Toast + ReportDialog 集成
- `entry/src/main/ets/components/CommentList.ets` — 每条评论 ⋯菜单 + 举报回调
- `entry/src/main/ets/pages/MessagePage.ets` — system 类型通知样式

## 数据库变更

- 新增 Report 表（id/reporterId/targetType/targetId/reason/description/status/createdAt/resolvedAt + @@unique + 2 个 @@index）
- Post 新增 `reportCount Int @default(0)`
- Comment 新增 `status Int @default(1)` + `reportCount Int @default(0)`

## 用户下一步建议

1. **环境变量配置**：在 `backend/.env` 中设置 `ADMIN_USER_IDS=1`（你的 userId）和 `REPORT_THRESHOLD=3`
2. **真机验证**：
   - 发帖命中敏感词 → 应 Toast "内容含敏感词，请修改后重试"
   - 详情页点 ⋯ → 举报该帖子 → 选理由 + 提交 → Toast "举报已提交"
   - 用 curl 调 `GET /v1/admin/posts/pending`（带 admin token）查看待审帖子
   - 用 curl 调 `POST /v1/admin/posts/:id/moderate {action:"approve"}` 审核帖子
3. **词库扩充**：上线前需扩充 `backend/data/sensitive-words.txt` 至完整 ToolGood.Words 词库（约 5000-20000 词）
4. **审核流程演练**：模拟 3 个用户举报同一帖子 → 验证自动下架 + 通知 + 审核流转
5. **后续迭代**（P1/P2）：发布器敏感词预览、前端审核界面、第三方 AI 内容识别、用户信用体系
