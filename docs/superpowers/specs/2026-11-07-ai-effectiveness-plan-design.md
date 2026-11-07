# AI 有效性方案：先度量、再做减法、大方向条件挂起（设计文档）

日期：2026-11-07 · 状态：待用户批准 · 范围：后端 + 鸿蒙前端（有据 com.youju.app）

## 一、意图与为什么

用户提出「AI 能力还能集成到哪些功能」，随后立了两条铁律：**秉承 AI 有效性**、**坚决不为 AI 而 AI**。据此对所有候选方向做了一轮「去掉 AI 还成立吗」的筛决，结论反直觉但诚实：

- 当前没有值得新增的 AI 调用点。已有 AI 能力（润色、拆块）是真需求，但**采用率完全不可见**——有效性无从谈起。
- 最贵的错误不是「少做一个 AI 功能」，而是「做了一个没人用的 AI 功能还维护它」。`polish-title` 孤儿接口（后端已实现+测试、前端零调用）就是现成证据。
- 所以此轮投入是：**给已有 AI 装上仪表盘（Phase 0）→ 榨干结构化数据红利而非新增 AI（Phase 1）→ 砍掉孤儿代码（Phase 1）→ 大方向挂起并写明重启条件（Phase 2）**。

**第二轮挖掘（用户便利性视角）**：用户要求进一步发掘「看不见的角落」。按「用户旅程里的体力活还没被消灭」重新扫了一遍发布/消费/检索链路，产出三项增量，全部经代码核实：①润色预览整包覆盖的采纳粒度摩擦（解法是纯 UI 分项采纳，不需要新 AI 调用）；②标签面板纯手动无推荐，而标签是检索基建（AI 从白名单挑，过审）；③搜索空结果无兜底，内容量小阶段空结果就是常态（LLM 改写查询给建议词，过审）。三项都已并入 Phase 1，且都能被 Phase 0 统计直接度量。

## 二、目标 / 非目标 / 反目标

**目标**
1. AI 调用有按接口×按日的采用数据（管理员可查），两周后能回答「润色/拆块有没有人在用」。
2. feed 双列卡片用结构化数据派生一行摘要，信息密度提升且不花一次 AI 配额。
3. `polish-title` 孤儿接口整体删除（后端+前端+测试）。
4. 润色预览支持分项采纳（仅标题/仅正文），消除「只想改标题被迫接受正文重写」的摩擦。
5. 发布页标签推荐（AI 从白名单挑 2-3 个候选）与搜索空结果救援（改写查询给建议词）——两个轻量 AI 场景，各一次调用，输出可点选可忽略。

**非目标**
- 不新增会话式/生成事实类 AI 场景；本轮新增的标签推荐与搜索救援都是「挑选/改写」类，单次调用；不改配额（20 次/日/人）与限流（6 次/分/人）。
- 不做帖子追问、语义搜索、合规预检、话题聚合（Phase 2 条件触发，本文档只记录不实现）。
- 不动详情页/对比表——`metricText` 在那里已有渲染。

**反目标（技术上跑通了也算失败）**
- 统计做成大盘/图表——本轮只要一个管理员 JSON 接口，能人肉看数即可。
- 卡片摘要行变成第二块内容区——只允许一行次要文案，视觉层级低于标题。
- 为「标题优化」保留半死不活的代码路径。

## 三、备选方案（已筛决）

| 候选 | 去 AI 测试结论 | 判决 |
|------|----------------|------|
| 标题优化挂 UI | polishDraft 已联合润色标题，再挂按钮=重复功能 | ❌ 砍接口（用户拍板） |
| feed 卡摘要 | 块数据已在列表返回，纯代码派生 | ✅ Phase 1a |
| 帖子追问 | AI 不可替代但时机未到：内容量小、配额模型撑不起会话、AI 幻觉答「依据」伤害有据核心承诺 | ⏸ 条件挂起 |
| 语义搜索/推荐 | 早期几百帖，关键词索引够用；上游 /embeddings 未验证 | ⏸ 条件挂起 |
| 合规预检 | 敏感词库做八成；AI 误报伤早期创作者 | ⏸ AGC 上架后重评 |
| 话题聚合 | 内容量不足 | ⏸ YAGNI |
| AI 起标题（第二轮） | polishDraft 已覆盖空标题生成，缺口在「整包覆盖」的采纳粒度 | ✅ 转纯 UI：润色预览分项采纳（零 AI 调用） |
| AI 推荐标签（第二轮） | 纯手动挑标签是真实体力活；从白名单挑=零幻觉 | ✅ Phase 1d |
| 搜索空结果救援（第二轮） | 空结果在内容量小阶段是常态；改写查询不需 embeddings | ✅ Phase 1e |

Phase 0 的统计存储二选一：内存 Map（复用配额 Map 模式，零迁移，但**每次部署清零**，跨两周度量不可靠）→ 否；**专用小表**（走既有 upgrade/downgrade SQL 手写对模式）→ 采纳。

## 四、已定的怎么做

### Phase 0 · AI 调用统计

**数据模型**（`backend/prisma/schema.prisma` + SQL 对，仿 `upgrade-add-post-metric.sql` 模式）：

```
model AiCallStat {
  id        Int      @id @default(autoincrement())
  endpoint  String   @db.VarChar(32)   // polish-draft | structure-draft | suggest-tags | search-rescue（未来新 AI 接口在此追加）
  day       String   @db.Char(10)      // UTC 日期 YYYY-MM-DD，与配额 usage Map 同口径
  userId    Int                        // 触发调用的用户；管理员调用也记录，查询侧过滤
  createdAt DateTime @default(now())
  @@index([endpoint, day])
}
```

配套 `prisma/upgrade-add-ai-call-stat.sql`（CREATE TABLE + 索引）与 `downgrade-add-ai-call-stat.sql`（DROP）。表名/列名与 schema.prisma 一致（本项目 prisma 不跑 migrate，DDL 靠手写 SQL 对，generate 只出客户端类型）。

**写入**（`backend/src/services/aiService.ts`）：新增 `recordAiCall(endpoint: string, userId: number): void`——insert 一行，失败静默吞掉（统计永不影响主流程）。调用点：`polishDraft`、`structureDraft`、`suggestTags`（1d 新增）、`searchRescue`（1e 新增）**成功返回前**各一行（只记成功=只记真实拿到的价值；配额拒绝/上游失败不记）。

**读取**（`backend/src/routes/admin.ts` 追加，天然继承文件头 `router.use(auth, adminAuth)`）：

- `GET /v1/admin/ai-stats?days=14`：`aiCallStat.groupBy(['endpoint','day'])`，`where.day >= 今日-13天 且 userId notIn env.adminUserIds`（管理员测试不污染采用率），`_count._all` 计数、`_count` distinct userId 由 prisma `_count: { userId: true }` 配合 groupBy 不支持 distinct——改为查窗口内全行在内存按 endpoint+day 聚合（调用量级：20 次/日/人，两周千行内，内存聚合无压力）。响应 `{ list: [{ endpoint, day, calls, users }], totals: [{ endpoint, calls, users }] }`。

**部署顺序**（服务器手动步骤，写进 PR 描述）：
1. 先应用 DDL：`docker exec -i youju-mysql mysql -u<user> -p<pass> <库名> < prisma/upgrade-add-ai-call-stat.sql`（凭据取服务器 backend/.env，与既往 upgrade SQL 同法）
2. `git pull && cd backend && bash deploy.sh`（Dockerfile 的 `npx prisma generate` 会带上新模型）
3. 带管理员 token 调 `/v1/admin/ai-stats` 验证返回空列表而非 500。

### Phase 1a · feed 卡结构化摘要行（纯客户端）

**结论前提**：`postService.listPosts` 返回全字段（含 `structuredDocument` JSON、`structuredSearchText` 展平列与 `metricText` 列），**后端零改动**。构建者审查已核实：首页 feed（HomeTab）即 `compact: true`，摘要行的首要目标场景就是它，故**不按 compact 区分**，所有 PostCard 形态统一渲染规则。

**改动**（`entry/src/main/ets/components/PostCard.ets`）：标题下方加一行次要文案，数据优先级：

1. `post.metricText`（服务端已抽列，零解析）——如「4.6 分」「1,299 元」
2. 无主数字但 `post.structuredSearchText` 非空：取其 trim 后前 48 字符（服务端发布时已把块标题/值/证据说明展平为真实正文，见 `utils/structuredSearchText.ts`，**不做逐块类型解析**——构建者审查指出块 `title` 字段在手建块上是模板兜底词、AI 块上恒为空，按块取标题会渲染出样板串）
3. 都没有：不渲染该行，卡片维持现状

**作用域与已知取舍**：仅对 `metricText` 或 `structuredSearchText` 非空的结构化帖生效。无图海报帖（share 短帖）通常无这两个字段，天然不重叠；海报在 feed 上已上传为 `coverImage`，**无可靠信号识别海报封面**，若出现重叠帖则接受一行轻微重复。展平串前 48 字符可能以首个块的标题开头（手建块为「核心结论」等模板词），真机验收时观察，观感差再收紧为「跳过首块标题」。单行 ellipsis，`TypeTokens` 次要字号、`ColorTokens.secondary`，视觉层级明确低于 `PostCardTitle`。

### Phase 1b · 删除 polish-title 孤儿接口

- 后端：`routes/ai.ts` 删 `/polish-title` 路由与 import；`services/aiService.ts` 删 `polishTitle` 函数（约 144-168 行段）；`routes/ai.test.ts` 删该 describe 块（128 行起），**配额测试（323-336 行段）改用 `structure-draft` 端点**（quota 语义不变，mock fetch 路径随测试基建走）。
- 前端：`services/api.ets` 删 `AiTitleResult`（1342）、`AiTitleRequest`（1354）、`aiPolishTitle`（1388-1391）。全仓无其他引用（已 grep 验证）。
- 无数据库影响。

### Phase 1c · 润色预览分项采纳（纯 UI，零 AI 调用）

**现状摩擦**（已核实 `aiService.ts:289-340`）：polishDraft 返回 `{title, content}` 整包，空标题也会强制生成新标题（即 AI 起标题能力已存在）；但前端确认预览是标题+正文整包覆盖——用户只想改标题时被迫接受正文重写。

**改动**：
- `entry/src/main/ets/components/AiPolishPreviewSheet.ets`：采纳动作改为两项勾选（「替换标题」「替换正文」，默认按新旧差异预勾选：标题变了勾标题、正文变了勾正文），确认按钮应用所选项，未选项输入框保持原样。
- 三个发布页（`TextPublishPage`/`PhotoPublishPage`/`VideoPublishPage`）：标题输入框为空且正文非空时，标题框提示文案引导「写完正文了？AI 润色可顺带起标题」（复用现有 draftHint/提示机制，不新增组件）。

### Phase 1d · AI 推荐标签

**现状**（已核实 `PublishTagPanel.ets:24-28`）：标签纯手动从分类树挑，无推荐机制；标签是检索基建（搜索 `tags array_contains`）。

**后端**：新增 `POST /v1/ai/suggest-tags`（auth + aiLimiter），body `{ content, genre? }` → `{ tags: string[] }`：
- `aiService.suggestTags(userId, content, genre)`：consumeQuota + recordAiCall('suggest-tags')；prompt 输入 = 正文（截 2000 字）+ **现有标签白名单**（与 tags 路由 listTags 同一数据源，含分类归属）；要求 LLM 只从白名单挑选 2-3 个。
- 服务端兜底：返回 tags 与白名单取交集并按白名单顺序输出；交集为空视为 AiUnavailableError（宁可不给，不给编造标签）。
- 敏感词检查不需要（输出是白名单子集）。

**前端**：`PublishTagPanel` 顶部加「AI 推荐」入口（手动触发，尊重配额；不自动调用），加载态短暂、失败静默（推荐是增益不是依赖）；推荐结果渲染为可点选 chips（点击=选中，与现有标签选中态同构）；已有选中标签时请求带上，让 LLM 避免重复推荐。

### Phase 1e · 搜索空结果救援

**现状**（已核实 `searchService.ts`）：空结果无任何兜底，空态干巴巴。

**后端**：新增 `POST /v1/ai/search-rescue`（auth + aiLimiter），body `{ keyword }` → `{ suggestions: string[] }`（2-3 个改写词）：
- `aiService.searchRescue(userId, keyword)`：consumeQuota + recordAiCall('search-rescue')；prompt 输入 = 原查询 + 标签白名单；要求输出「库里搜得到内容的短词」（标签词或常见名词改写），禁止编造产品型号/事实。
- 服务端钳制：每词 ≤ 20 字、≤ 3 个、过 `sensitiveWordService.checkText`，失败/空建议静默降级为无建议。

**前端**（构建者审查修正落点）：`SearchPanel.ets` 是搜索探索页（最近搜索/热词/输入联想），**不执行搜索、没有空结果态**——空结果态在 `SearchResultPage.ets`（`EmptyState '暂时没有相关内容'`，约 396-407 行）。改动全部落在 `SearchResultPage`：

- 触发：`fetch(reset=true)` 完成且 `searchList.length === 0 && error === ''` 时自动调用一次（用户已受挫，不加二次点击）。
- 建议词渲染为可点选 chips（空态区内），点击 = 以该词走现成的 `doSearch(raw)` 重新搜索。
- **同关键词不重复调用**的缓存放**模块级 Map**（key=关键词，值=建议词；App 冷启动即清）——该页是 `@Entry` 路由页，每次进入都是新实例，组件级 `@State` 跨不了会话，退化为「本页实例内不重复」没有意义。
- 失败静默，空态维持现有文案；状态命名避开探索页的输入联想语义（如 `rescueWords`）。

### Phase 2 · 条件触发（只记录，不排期）

| 方向 | 重启条件 | 届时第一步 |
|------|----------|-----------|
| 帖子追问 lite（单轮问答） | 周活作者 ≥ 30 且拆块采用率稳住 | 先写 prompt 与配额影响评估，不做会话 |
| 语义搜索 spike | 帖子总量 ≥ 1000 | 半天验证上游 /embeddings 可用性 |
| 合规预检 | AGC 上架后出现真实审核摩擦 | 敏感词库先行，AI 只补语境 |
| 话题聚合 | 同语义搜索 | — |

## 五、测试与验证

- 后端 jest：admin ai-stats（管理员 200 / 普通用户 403 / 聚合口径正确 / 管理员自身调用被排除）；删除 polish-title 后 AI 路由测试相应减少、新增 suggest-tags（白名单交集过滤：LLM 返回白名单外的 tag 被剔除、全被剔时 503 语义 / 401 / 配额）与 search-rescue（长度钳制 / 敏感词拦截 / 空建议降级 / 401 / 配额）各 3-5 例；全量保持绿。
- 前端：`hvigorw assembleHap` 通过；真机抽查：①三种卡片形态（有主数字 / 无主数字有展平列 / share 海报帖应无摘要行）；②润色预览分项采纳（只勾标题→正文不变）；③标签推荐 chips 点选即选中、失败静默；④搜索空结果出现建议词、点击重新搜索、同词不重复请求。
- 度量验收：发布一篇帖子走一次润色+一次拆块+一次标签推荐 → `/v1/admin/ai-stats` 出现三个 endpoint 的计数（当天即可见）。

## 六、留给构建者的部分

- 卡片摘要行的具体字号/行高 token 选择（在 `TypeTokens` 既有档位里挑）。
- ai-stats 内存聚合的窗口边界取值（UTC 日界与配额一致即可）。
- 测试文件里 mock fetch 的具体改挂端点。
- `recordAiCall` 用 prisma 直插还是并入现有 service 导出风格——跟随文件内既有模式。
