---
title: "unify-moderation-console.md"
id: markdown_798285c88467638f6a8dc28635ad6f33_0761a571ee20fe846111f2e4662a8ef37505655250320770
kb: 有据-YouJu
folder: "开发文档"
media_type: 7
tags: []
source: ima
exported_at: 2026-11-23T14:52:37.917Z
---
# 合并「内容审核台」到「举报中心」实施计划

## Context（为什么做）

现在有两套管理流程，底层是同一套状态机，切面不同但边界没划清：

- **内容审核台**（`ModerationPage` + `GET /v1/admin/posts/pending` + `POST /v1/admin/posts/:id/moderate`）：只看 `Post.status=0` 的帖子，通过→1 / 驳回→2，是唯一会**通知作者审核结果与原因**的地方，也能封禁作者。
- **举报账本/举报中心**（`ReportAdminPage` + `/v1/admin/reports` 系列）：按被举报对象聚合举报记录（post/comment/user 三类），成立→举报 resolved + 内容 `status=0`；驳回→只改举报、不动内容。

核实出的四个缺口：① 同一帖子两处处置（阈值自动下架进审核台、举报仍在账本）；② 账本「驳回」不恢复内容 → 被下架帖子滞留在审核台；③ 账本路径下架**不通知作者**；④ 评论被置 0 后全项目没有任何恢复路径。

**目标**：合并为唯一处置台——举报中心。举报处置即同时决定内容状态与通知，删除独立审核台（页面 + 接口），消除双流程与静默处置。

## 关键决策（已定，如无异议按此执行）

1. **名称统一「举报中心」**：页面标题、设置页入口、消息页入口同一名称（消息页入口现名已是「举报中心」）。
2. **统一动作**：`POST /v1/admin/reports/resolve` body `{ targetType, targetId, action: 'resolved'|'dismissed'|'restore', reason? }`
   - `resolved`（成立并下架）＝ 现状语义 + **新增通知作者**「你的帖子《X》未通过审核，原因：…」；内容置 `0`（沿用现状，**不**改写为 2）。
   - `dismissed`（驳回举报）＝ 现状语义 + **新增内容恢复**（post/comment `0→1`，仅当确实处于下架态）+ 恢复时才通知作者「已通过审核」。
   - `restore`（改判/误封恢复）＝ 仅恢复内容 `0→1` + 通知作者；服务端强校验「非 user 目标 + 无 pending 举报 + 当前 status=0」，不满足返回 400；不改举报状态、不通知举报人。
   - 三种动作都排除「举报人 == 作者」的重复通知；事务后统一 `syncAdminReportCenter(false)`。
3. **只做 `0→1` 恢复；存量 `status=2` 保持隐藏**（旧审核台 reject 的产物；如需清理走一次性数据修复，单独确认）。
4. **卡片信息补全**：`listReports` 目标摘要新增 `targetStatus`（post/comment 当前 status）与作者信息（`authorId/authorNickname/authorAvatar/authorBanned`，user 目标=自身、post/comment=作者）；`targetNickname/targetBanned` 语义保持不动。前端据此显示「已下架/已发布」pill、作者行与「封禁/解封作者」（对齐原审核台能力）。
5. **删除清单**：前端 `ModerationPage.ets`（含路由与设置入口）、`api.ets` 的 `getPendingPosts/moderatePost/ModerateBody`、`types.ets` 的 `PendingPost/ReportItem/ReportReporter/ModerateAction`；后端 `/posts/pending`、`/posts/:id/moderate`、`services/moderationService.ts`。

## 实施步骤

### A. 后端（先做，前端字段依赖它）

- **A1 `backend/src/services/reportService.ts` · `listReports`**：目标批量查询补 `status`（post/comment）与 `userId`；新增一次作者批量查询（`authorIds` 为空时不发 `in: []`）；映射出 `targetStatus` 与 `author*` 四字段（user 目标填自身），保留 `targetPostId` 逻辑。
- **A2 同文件 · `resolveReportsByTarget` 重写为三动作统一入口**：签名加 `action: 'restore'` 与 `reason?`。
  - 事务内：读目标快照（post/comment 不存在 → `not_found`）→ 按 action 改举报状态与内容状态（**一律 `updateMany` + `count`** 判定是否真的发生变化，用于「是否发作者通知」「restore 是否有效」）→ `restore` 的三项校验（`invalid_target` / `has_pending` / `not_taken_down`）。
  - 事务后（`.catch(() => {})` 不阻断）：作者通知（postId 挂载：post→自身 id、comment→`comment.postId`、user→null）、举报人通知（`restore` 跳过，排除作者本人）、`syncAdminReportCenter(false)`。
- **A3 `backend/src/routes/admin.ts`**：删 `/posts/pending`、`/posts/:id/moderate` 与 `moderationService` import；改写 `/reports/resolve`：`action ∈ ['resolved','dismissed','restore']`、`reason` 截断 200；错误映射 `not_found→404`、`has_pending→400「该内容仍有待处理举报，请先处置举报」`、`not_taken_down→400「该内容当前未下架，无需恢复」`、`invalid_target→400「用户举报不支持该操作」`；**删掉路由里的举报人通知循环（已下沉 service，防止双通知）**。
- **A4 删除 `backend/src/services/moderationService.ts`**（全仓引用仅 `admin.ts` 与测试），同步 `backend/src/app.ts` 顶部注释里的 pending/moderate 字样。
- **A5 测试**：
  - `backend/src/routes/admin.test.ts`：mock 补 `post.updateMany/comment.updateMany/comment.findUnique`；鉴权用例改打 `/v1/admin/reports`；删除 pending describe，改为「旧接口已下线 → 404」护栏；moderate describe 重写为 resolve 三动作 + 负例（非法 action/有 pending 时 restore）。
  - `backend/src/services/reportService.test.ts`：顶层 mock 补 `post.updateMany/comment.updateMany`；resolve describe 的 tx 换新结构；新增用例：resolved（下架 + 作者通知含原因 + 举报人通知 + 举报中心同步）、dismissed 恢复（0→1 + 作者「已通过审核」）、dismissed 未下架不发作者通知、restore 成功/有 pending 拒绝/不改举报状态、user 类型不碰内容、举报人=作者只收一条。

### B. 前端

- **B1 `entry/src/main/ets/models/types.ets`**：删 `PendingPost/ReportItem/ReportReporter/ModerateAction`；`AdminReportItem` 增 `targetStatus?: number|null`、`authorId/authorNickname/authorAvatar?: ...`、`authorBanned?: boolean|null`；新增 `export type ReportAction = 'resolved'|'dismissed'|'restore';`
- **B2 `entry/src/main/ets/services/api.ets`**：删 `getPendingPosts/moderatePost/ModerateBody`；`resolveTargetReports(targetType, targetId, action: ReportAction, reason?)`（reason 为空不带字段）。
- **B3 `entry/src/main/ets/pages/ReportAdminPage.ets`**：
  - 标题改「举报中心」（`topBar`），文件头注释更新为「唯一处置台」。
  - `ReportGroup` 增 `targetStatus/authorId/authorNickname/authorAvatar`；`newGroup/mergeReport/copyReport` 三处**显式全字段**（ArkTS 禁展开）。
  - `@State bannedAuthorIds: number[]`（load 后按 `authorId + authorBanned` 重建，ban/unban 后就地维护）→ `isAuthorBanned(g)`；封禁按钮对所有类型渲染（user 用「封禁/解封」、post/comment 用「封禁作者/解封作者」）。
  - 判定抽成 private 方法（build 内不声明局部变量）：`isTakenDown / canRestore / contentStatusLabel`。
  - 新 Builder：`contentStatusPill`（已下架=danger 圆点+primary 文字 / 已发布=brand 圆点）、`authorRow`（Avatar+昵称+已封禁 chip，整行可点进主页）。
  - 动作行：`pendingCount > 0` → `[驳回举报][成立并下架]`；已成立且可恢复 → `已处置 · 已成立` + 次级 `[恢复展示]`；处理中显示「处理中…」。
  - 新增 `ResolveReasonDialog`（从 `ModerationPage` 的 `RejectDialog` 搬入，标题「成立理由」，全部 design tokens）；`confirmResolve` → 范围确认 → 理由弹窗 → `doResolve(g,'resolved',reason)`。
  - `doResolve` 支持三动作：调 API → 就地 patch `status` 与 `targetStatus`（resolved→0；dismissed/restore→1；user 保持 null）→ `bumpReportCenterRefresh()` → toast（已成立并下架 / 已驳回举报 / 已恢复展示）。
  - **ForEach key 必须含** `status + targetStatus + 封禁态`（否则状态/封禁变化不刷新）。
- **B4 删除与入口合并**：删 `entry/src/main/ets/pages/ModerationPage.ets`；`resources/base/profile/main_pages.json` 摘 `pages/ModerationPage`；`SettingsPage.ets` 两个 admin 行合并为一行「举报中心」→ `pages/ReportAdminPage`；`MessagePage.ets` 注释措辞同步。

### C. 脚本与文档

- **C1 `scripts/verify-login-gates.mjs`**：`GATED_PAGES` 删 `'ModerationPage.ets'`（否则脚本报「文件不存在」）。
- **C2 `backend/scripts/e2e-qa.mts`**：`adminPhase` 中 `/v1/admin/posts/pending` 的 200/403 断言改打 `/v1/admin/reports`；可选加一条 `resolve(user, dismissed)` 冒烟。
- **C3 文档（可选）**：`docs/feature-index.md` 治理行只留 `ReportAdminPage`；`docs/risk-assessment/*`、`entry/Docs/*`、`deliverables/*` 中关于审核台/待审接口的描述标注已下线（不影响构建）。

## 风险与回归点

1. **存量数据**：上线前只读核查（Prisma 默认表名 Post/Comment/Report）——`status=0` 且无举报的帖子/评论数量、`status=2` 的帖子数量。>0 表示有「无人可处置」或永久隐藏的存量，需要一次性数据修复（另行确认）。
2. **`dismissed` 会让内容立刻重新公开**（本需求要修的滞留问题）：若 `reportCount` 仍 ≥ 阈值，下一条新举报会再次自动下架——属预期，审核员需知晓。
3. **双通知**：通知从路由下沉 service 时务必删掉 `admin.ts` 里原有举报人通知循环。
4. **测试 mock 缺口**：两个测试文件的 prisma mock 缺 `post.updateMany/comment.updateMany`，不先补会 `TypeError`。
5. **ArkTS 约束**：`ReportGroup` 字段多，三处构造必须全字段显式；`build()` 内不可声明局部变量；样式只用 design tokens。
6. **前端聚合分页偏差**：`pendingCount` 只统计已加载页，超大举报量目标的 `restore` 可能被后端 400 拦截 → 原样 toast 即可。
7. **验收以「全绿」为准**：用例总数会因删/改用例而变化。

## 验证

1. `cd backend && npx tsc --noEmit` → 0 错误（无 moderationService 残留）。
2. `cd backend && npx jest` → 全部通过（含新 resolve 用例）。
3. `node scripts/verify-login-gates.mjs` → `[通过] 15 个需登录页面…`。
4. 前端构建：`export PATH="/Applications/DevEco-Studio.app/Contents/tools/node/bin:$PATH" && export DEVECO_SDK_HOME=/Applications/DevEco-Studio.app/Contents/sdk && /Applications/DevEco-Studio.app/Contents/tools/hvigor/bin/hvigorw assembleHap --mode module -p module=entry@default -p product=default --no-daemon` → BUILD SUCCESSFUL。
5. 接口手测（本地后端 + admin token）：`GET /v1/admin/reports?status=pending` 含新字段；`resolve` 三动作各自成功；负例：有 pending 的 restore→400、user 的 restore→400、`action=approve`→400、旧 `/v1/admin/posts/pending`→404、无 token→401。
6. `cd backend && npx tsx scripts/e2e-qa.mts admin` → admin 阶段全 PASS。
7. 前端手测：设置页只剩「举报中心」；待处理卡 `[驳回举报]/[成立并下架]`；已成立且下架卡出现 `[恢复展示]`；post/comment 卡有作者行与封禁按钮且封禁后同作者卡片同步变化；user 卡行为不变；处置后消息页「举报中心」入口文案即时刷新。

## 上线注意

- 后端接口语义变更 → **需部署后端**；前端需重新安装 HAP。
- 存量 `status=2`（旧拒绝）内容在新 UI 中无恢复入口，保持隐藏；如需恢复请单独提一次性数据修复。
