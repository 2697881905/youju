# AI 有效性方案 · 实现计划

规格：`docs/superpowers/specs/2026-11-07-ai-effectiveness-plan-design.md`（已批准 2026-11-07）
约定：每步完成即验证；后端以 jest 全绿为准，前端以 assembleHap SUCCESS 为准；不做超出规格的事。

## A · 后端（先跑通统计与两个新端点）

| # | 任务 | 文件 | 验证 |
|---|------|------|------|
| A1 | AiCallStat 模型 + upgrade/downgrade SQL 对 | `backend/prisma/schema.prisma`、`backend/prisma/upgrade-add-ai-call-stat.sql`、`downgrade-add-ai-call-stat.sql` | `npx prisma generate` 通过 |
| A2 | `recordAiCall(endpoint, userId)`（失败静默）；polishDraft/structureDraft 成功返回前挂调用 | `backend/src/services/aiService.ts` | 编译通过 |
| A3 | 删 `polishTitle`（service 函数 + `/polish-title` 路由 + import） | `aiService.ts`、`routes/ai.ts` | 全仓 grep 无 polishTitle 残留 |
| A4 | `suggestTags(userId, content, genre)`：prompt 只许从 `tagService.listTags()` 白名单挑 2-3 个；服务端交集过滤、空交集抛 AiUnavailableError；敏感词不需查（白名单子集） | `aiService.ts`、`tagService.ts`(只读复用) | A7 测试 |
| A5 | `searchRescue(userId, keyword)`：改写查询给 2-3 个建议词，每词 ≤20 字、过 sensitiveWordService、空建议抛 AiUnavailableError | `aiService.ts` | A7 测试 |
| A6 | 路由：`POST /v1/ai/suggest-tags`、`POST /v1/ai/search-rescue`（auth + aiLimiter，与既有三端点同构） | `routes/ai.ts` | A7 测试 |
| A7 | 测试：删 polish-title describe；配额测试（323-336 段）改挂 structure-draft；新增 suggest-tags（白名单外 tag 被剔 / 全剔时 503 / 401 / 配额计数）与 search-rescue（超长钳制 / 敏感词 503 / 401 / 配额）各 3-5 例 | `routes/ai.test.ts` | 本文件 jest 全绿 |
| A8 | `GET /v1/admin/ai-stats?days=14`：窗口内行（day ≥ N-1、userId notIn adminUserIds）内存聚合 → `{list:[{endpoint,day,calls,users}], totals:[{endpoint,calls,users}]}` | `routes/admin.ts` | A9 测试 |
| A9 | admin ai-stats 测试：管理员 200 / 普通用户 403 / 聚合口径 / 管理员调用被排除 | `routes/admin.test.ts`（无则新建，跟随既有 admin 测试基建） | jest 全绿 |

## B · 前端

| # | 任务 | 文件 | 验证 |
|---|------|------|------|
| B1 | api 层：删 `AiTitleResult`/`AiTitleRequest`/`aiPolishTitle`；增 `AiSuggestTagsResult`+`aiSuggestTags(content, genre, excludeTags)`、`AiSearchRescueResult`+`aiSearchRescue(keyword)` | `entry/src/main/ets/services/api.ets` | grep 无 polishTitle 残留；编译通过 |
| B2 | PostCard 摘要行：`metricText` → `structuredSearchText` trim 截 48 字 → 不渲染；单行 ellipsis，secondary 字色，低于标题层级；compact 同规则（feed 即主场景）。`models/types.ets` 的 Post 接口若无 `structuredSearchText` 字段则补可选字段 | `components/PostCard.ets`、`models/types.ets` | B6 编译 + 真机抽查 |
| B3 | 润色分项采纳：`onApply` 改 `(applyTitle, applyContent) => void`，弹层内两项勾选（默认按新旧差异预勾），确认应用所选项；三发布页 handler 按旗标回填 | `components/AiPolishPreviewSheet.ets`、`pages/TextPublishPage.ets`、`PhotoPublishPage.ets`、`VideoPublishPage.ets` | B6 编译 + 真机抽查 |
| B4 | 空标题引导：标题空且正文非空且 AI 可用时，标题输入框 placeholder 提示「写完正文了？AI 润色可顺带起标题」 | 三发布页 | B6 编译 |
| B5 | 标签推荐：`PublishTagPanel` 增 `@Prop content/genre/aiEnabled` + 顶部「AI 推荐」入口（手动触发、失败静默、loading 短暂）；结果渲染为可点选 chips（与既有选中态同构、去重已选）；请求带 excludeTags；三发布页向面板传参 | `components/PublishTagPanel.ets`、三发布页 | B6 编译 + 真机抽查 |
| B6 | 搜索救援：`SearchResultPage` 空结果态（`searchList.length===0 && error===''`）自动调 `aiSearchRescue(keyword)` 一次；模块级 `Map<string, string[]>` 缓存（同词不重复）；建议词 chips 点击走 `doSearch(raw)`；失败静默维持现有空态文案；状态命名避开联想语义（`rescueWords`） | `pages/SearchResultPage.ets` | B6 编译 + 真机抽查 |
| B7 | 构建验证：`DEVECO_SDK_HOME=/Applications/DevEco-Studio.app/Contents/sdk hvigorw assembleHap`（沙箱内若被拦，提权重跑） | — | SUCCESS |

## C · 收尾

| # | 任务 | 说明 |
|---|------|------|
| C1 | 规格状态改「已批准」+ 记忆日志 | spec 文档头部 |
| C2 | commit + push（`HEAD:main`） | 分两笔：docs 计划、feat 实现（或按模块拆小笔） |
| C3 | 服务器部署指引交用户执行：① 先 `docker exec -i youju-mysql mysql ... < prisma/upgrade-add-ai-call-stat.sql` ② git pull（失败走 bundle）→ `bash deploy.sh` ③ 管理员 token 调 `/v1/admin/ai-stats` 应返回空列表非 500 ④ 真机抽查 B2-B6 四个面 | 凭据取服务器 backend/.env |

## 边界备忘

- 配额/限流不动：新端点共用 20/日 + 6/分，管理员豁免自动生效。
- recordAiCall 只记成功（含管理员调用）；查询侧聚合排除管理员。
- 不做：追问、语义搜索、合规预检、话题聚合（Phase 2 条件挂起）。
