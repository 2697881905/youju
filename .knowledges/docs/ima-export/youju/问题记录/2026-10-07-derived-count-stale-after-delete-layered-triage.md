---
title: "2026-10-07-derived-count-stale-after-delete-layered-triage.md"
id: markdown_cls1_798285c88467638f6a8dc28635ad6f33_2c4916e7f96037e3882fe583d1b07c2e7505655250320770
kb: 有据-YouJu
folder: "问题记录"
media_type: 7
tags: []
source: ima
exported_at: 2026-11-23T14:52:37.917Z
---
---
id: 2026-10-07-derived-count-stale-after-delete-layered-triage
title: 派生计数「删除后不变」分层定位法：先分清展示层刷新与服务端计数漂移
category: debugging
nature: methodology
created_at: 2026-10-07T00:17:01
updated_at: 2026-10-07T00:43:01
tags: [layered-triage, derived-data, counter-consistency, state-refresh, debugging]
keywords: [删除后计数不变, 评论数不更新, 分层定位, 展示层刷新, 服务端计数漂移, 冗余计数, 反规范化计数, ArkUI @Prop, 审核下架, 多根因, 只修一层, 重新拉取探针]
problem_patterns: [same-symptom-two-independent-root-causes, ui-refresh-fix-hides-backend-counter-drift, single-layer-fix-incomplete-for-counter-stale]
source_sessions: [ses_ef42f4035ffekN6vk5fZoDuUMc]
project: HarmonyProject1
severity: high
quality_score: 84
hit_count: 0
last_hit_at: null
low_quality_hit_count: 0
tier: A
related_experiences: [2026-10-07-denormalized-counter-status-transition-sync, 2026-10-07-read-time-recompute-override-stale-counter, 2026-10-05-arkui-state-nested-property-update-no-rerender, 2026-10-05-arkui-child-local-mutation-parent-sync-contract, 2026-10-07-fix-derived-data-needs-historical-backfill]
---

# 派生计数「删除后不变」分层定位法：先分清展示层刷新与服务端计数漂移

## Scenario

用户报「删除某条内容后，页面上的计数没变」（评论数、点赞数、收藏数、未读数、文件数……）。这类现象看似单一 bug，实际上常常同时叠着至少两条互相独立的缺陷路径：

1. **展示层**：状态变更未触发跨组件刷新（如 ArkUI V1 就地改 `@State` 对象的嵌套属性、子组件只改自己的 `@Prop` 副本而未回传父级）；
2. **数据层**：服务端冗余计数字段与实际可见集合不同步（如审核下架只翻转 `status`，忘了维护计数）。

两条路径的表现完全相同——「内容行消失/新增，但计数纹丝不动」。只修其中一条，用户会继续报「修了还在」。适用于任何「UI 显示一个由集合派生的计数，且集合成员可被删除、隐藏或审核下架」的系统。

## Key Signals

1. 内容条目本身已从界面消失（说明删除 API 生效、数据确实变了），唯独计数不变。
2. **不同删除入口表现不一致**：自己删除生效、被举报/审核下架不生效（或反之）——强烈提示存在多条改变可见性的写路径。
3. 代码里出现直接改 `this.state.obj.field` 这类嵌套属性赋值，或子组件只改自己的 `@Prop` 副本、缺少回传回调——展示层可疑。
4. 服务端存在多条修改「可见性字段」的写路径，只有一部分顺带增减计数——数据层可疑。
5. 首次修复后用户仍复现、且作用面略有不同（如先说「详情评论区」、后补「列表卡片」）——说明还有未被覆盖的一层。

## Essence

「计数不变」是**症状**，不是根因。它至少可以来自两个层次，且二者互不排斥：

- **展示层根因**：新值已算出并写进状态对象，但没有跨组件传播到渲染，UI 用的是旧快照（典型：ArkUI V1 嵌套属性就地赋值、`@Prop` 单向拷贝未回传）。
- **数据层根因**：冗余计数本就是**派生值**，某条改变可见集合的写路径（尤其审核下架/恢复这类非 DELETE 的软状态翻转）没有维护它，于是权威数据本身已经错了；此时前端无论怎么刷新都对不上。

关键判据：**「内容行是否变化」区分不出这两个层次**——两层里行都会正确消失。必须用独立的探针分别验证：展示层看「组件内新值是否已产出、是否跨边界传播」；数据层看「服务端按同一过滤条件 `count` 出的行数是否等于计数字段」。只做一层就下结论，是这类 bug 反复复现的根源。

## Approach

1. **先分层，不要先改**。对症状提两个可独立判断的问题：
   - 展示层：写入方算出的新值是否已到达渲染？是否「子组件内部 UI 变了、父级派生展示没变」？
   - 数据层：把「按可见性过滤 `count` 出的行数」与「计数字段的值」对照，是否一致？
2. **数据层探针（最省事）**：绕过前端直接读服务端，或重新进入页面重新拉取一次。重新拉取后计数仍不对 → 数据层缺陷；重新拉取后正确 → 展示层（或前端本地缓存）缺陷。
   - 注意：重新进入页面会掩盖「本地乐观扣减未生效」的展示层问题，需与步骤 3 交叉验证。
3. **展示层探针**：确认删除后父级持有的权威对象/计数是否被顶层更新；检查是否存在「就地改嵌套属性」「子组件只改 `@Prop` 副本、无回传回调」。
4. **枚举所有写路径**：`grep` 所有会改变该集合成员资格的位置（物理删除、软删除 `deletedAt`、审核 `status` 翻转及阈值自动下架），逐一核对是否维护计数；用条件更新（`where: { 状态字段: 期望旧值 }` + 命中行数判断）保证幂等。
5. **两层都修，分别验证**：
   - 展示层：编译通过 + 手动走一遍删除路径，确认当帧刷新；
   - 数据层：跑该服务的单元测试，覆盖「正常下架扣减」「重复下架不重复扣」「恢复补回」。
6. **交付时附带存量回填**：数据层缺陷若已运行一段时间，历史数据仍是错的，需幂等「重算覆盖」脚本。

## Faster Next Time

- **默认假设「可能是两层」**：遇到「删除后计数不变」，先把定位拆成「展示层刷新」与「服务端计数一致性」两条线，而不是沿着第一条线索一路深入。
- **最快的分流动作**：重新进入/重新拉取一次。计数恢复正确 → 先查展示层；计数依旧错 → 先查数据层（也可能两层都有）。
- **多入口一致性检查**：把「自己删除」与「审核/举报下架」并列对比。若只有其中一个入口有问题，几乎可以锁定对应写路径缺失维护。
- **静态排查**：`grep -n 'status:'` 与 `grep -n 'Count.*increment\|Count.*decrement'` 交叉比对，找出「改了可见性却没改计数」的位置。
- **作用面确认**：同一 bug 描述可能指不同 UI 层面（详情页内、列表卡片、服务端口径）。修复前先与用户确认「具体是哪个界面的哪个数字」，否则易只修一层。
- **反模式**：只改前端让数字「看起来对」，而服务端计数继续漂移——换个入口进入就又不一致。

## Applicability Boundaries

- **适用**：UI 上存在由集合派生的计数/统计量，且集合成员可被删除或通过状态字段隐藏（含审核下架）的场景；前后端分层架构。
- **不适用**：计数由 UI 直接实时聚合（无冗余存储、无跨组件派生展示）——此时只有单一层次。
- **不适用**：内容为物理删除且唯一入口、无软删除/审核路径，且展示走全量重渲染——常规维护即可。
- **前提约束**：步骤 2 的「重新拉取」探针在多端实时同步场景下可能被服务端推送掩盖，需结合服务端日志判定。

## Evidence or Examples

HarmonyProject1，「帖子评论删除后评论数未更新」（session `ses_ef42f4035ffekN6vk5fZoDuUMc`）：

- 现象：删除评论后评论行消失，但评论区「评论 N」不变；用户澄清场景包含「自己删除」与「被举报删除」两种。
- **第一层（展示层）**：`PostDetailView.onCommentDeleted` 直接改 `@State post` 的嵌套属性 `post.commentCount`，`DetailCommentsSection` 的 `@Prop commentCount` 未重同步。修复：新增独立 `@State commentCount` 快照 + 顶层替换（中间尝试的对象展开 `{...post}` 因项目约定「逐字段构造」而放弃）；`hvigorw assembleHap` **BUILD SUCCESSFUL**。
- **第二层（数据层）**：`backend/src/services/reportService.ts` 的审核路径（阈值自动下架、管理员 `resolved` 下架、`dismissed`/`restore` 恢复）只翻转 `Comment.status`，从不更新 `Post.commentCount`；而详情接口按 `where: { postId: id, status: 1 }` 过滤评论。修复：状态转换处改用 `updateMany({ where: { id, status: 期望旧值 } })` + 命中行数判断，幂等增减计数；`npx jest src/services/reportService.test.ts src/routes/comments.test.ts src/routes/admin.test.ts` → **42 passed**。
- **结论印证**：同一现象、两层独立根因——只修展示层时数据层仍漂移，只修数据层时展示层仍不刷新。
- 关联经验：数据层机制见 `2026-10-07-denormalized-counter-status-transition-sync`，展示层机制见 `2026-10-05-arkui-state-nested-property-update-no-rerender` 与 `2026-10-05-arkui-child-local-mutation-parent-sync-contract`，存量回填见 `2026-10-07-fix-derived-data-needs-historical-backfill`，读取侧重算兜底见 `2026-10-07-read-time-recompute-override-stale-counter`（本文只负责「先分清是哪一层」，修复手段各自见对应经验）。
