---
title: "2026-10-07-fix-derived-data-needs-historical-backfill.md"
id: markdown_cls1_798285c88467638f6a8dc28635ad6f33_a880c63e299c5c2b73a7bbf0dc670a4e7505655250320770
kb: 有据-YouJu
folder: "问题记录"
media_type: 7
tags: []
source: ima
exported_at: 2026-11-23T15:08:08.827Z
---
---
id: 2026-10-07-fix-derived-data-needs-historical-backfill
title: 修复派生数据的写入路径不会回溯修正历史数据：交付必须附带幂等回填
category: workflow
nature: methodology
created_at: 2026-10-07T00:07:01
updated_at: 2026-10-07T00:44:17
tags: [derived-data, backfill, data-migration, remediation, release-checklist]
keywords: [历史数据回填, 派生数据, 冗余计数, 校准脚本, reconcile, backfill, 幂等回填, 一次性脚本, 数据漂移, 缓存一致性, materialized aggregate]
problem_patterns: [writer-fix-does-not-correct-existing-rows, stale-derivative-persists-after-code-fix, missing-historical-reconciliation-step]
source_sessions: [ses_eee10676fffekvBdVi3fmFpdGD]
project: HarmonyProject1
severity: medium
quality_score: 76
hit_count: 0
last_hit_at: null
low_quality_hit_count: 0
tier: A
related_experiences: [2026-10-07-denormalized-counter-status-transition-sync, 2026-10-07-read-time-recompute-override-stale-counter, 2026-10-07-derived-count-stale-after-delete-layered-triage, 2026-10-07-run-ops-scripts-in-slim-runtime-image, 2026-10-07-compose-v1-v2-avoid-up-use-rolling-deploy-script]
---

# 修复派生数据的写入路径不会回溯修正历史数据：交付必须附带幂等回填

## Scenario

修复了一个「冗余计数/派生数据」的写入路径缺陷（例如补上了审核下架时对计数的维护）。代码修好了、新测试通过，于是认为问题已解决。

但历史数据是在修复**之前**产生的——此前那些已下架的内容从未扣减过计数。用户更新到新版本后，旧数据的漂移依旧存在，会再次被报为同一个 bug。

适用于任何「写入端已修、但存量数据仍错误」的修复：冗余计数器、物化聚合、缓存、搜索索引、短信/推送去重表等。

## Key Signals

1. 修复方案只改了写入路径（`increment`/`decrement`/更新语句），没有任何存量数据处理动作。
2. 该字段是派生值，且此前存在已知的漂移窗口（缺陷持续期间产生的数据）。
3. 测试全绿，但测试用的是新数据；没有针对「修复前遗留的脏数据」的用例。
4. 用户复现时，若其账号/帖子是旧数据，修复后现象可能仍复现。

## Essence

代码修复只改变**未来**的行为，不改变**过去**已落库的字节。派生数据的正确性由两部分组成：

- **前进方向**：写入路径必须持续维护（由缺陷修复保证）；
- **存量方向**：已有数据必须有一次回填 / 校准（由一次性任务保证）。

二者缺一，问题就会以「明明修了却还在」的形式复现。因此「修复派生数据 bug」的交付定义里，**必须把幂等回填脚本作为交付物之一**，而不是可选项。

回填必须是**幂等的**：以权威来源重新计算并覆盖（`recompute & overwrite`），而非「再增量一次」——增量式回填在重跑或部分执行时会二次漂移。

## Approach

1. 确认该字段是否已在缺陷期间产生脏数据（缺陷存在的时长、影响的数据范围）。
2. 编写一次性校准脚本，以**权威来源重新计算**目标值并覆盖写入，而不是再次增减：
   ```
   // 对每个帖子：统计其 status=1 的可见评论数，重算 commentCount
   // 按主键/分批处理，避免大表一次性加载
   ```
3. 让脚本**可重复执行且结果收敛**（幂等）：反复运行结果一致，重复执行不放大误差。
4. 分批 + 可观测：打印处理行数、修正条数；支持分页/游标，避免长事务与内存爆量。
5. 在交付说明中显式列出：代码修复 + 回填脚本 + 运行命令 + 预期输出；并说明**执行时机**（发版后、对存量数据跑一次）。
6. 若产品需要强一致，考虑在恢复/补偿路径上也做校准，或加对账任务周期性纠偏。

## Faster Next Time

- **交付检查清单**：凡修复的是「派生/冗余/缓存类字段」，自问一句「存量数据谁来修？」，答案不能是「自动就好了」。
- **选型规则**：回填一律用「重算覆盖」，不用「补偿式增减」；增减式只能用于实时路径，用于回填必然不幂等。
- **验收规则**：修复后要能对**修复前的存量样本**验证，而不只是新造数据。
- **沟通规则**：向用户说明「历史数据需运行校准脚本回正」，并给出命令，避免用户以为装了新版就万事大吉。
- 反模式：把回填塞进应用启动流程每次执行——校准是一次性运维动作，不应变成常驻开销。

## Applicability Boundaries

- **适用**：冗余计数、物化聚合、缓存/索引等派生数据，且缺陷已运行一段时间产生了存量脏数据。
- **不适用**：缺陷尚未上线、无存量数据，或数据可实时重算无需持久化冗余列。
- **不适用**：派生数据有强实时一致性要求、且脏数据窗口极短（此时可能选择直接重建整表/索引更简单）。
- **注意**：回填脚本属于运维类一次性动作，需明确权限、执行窗口与回滚/重跑策略；本经验中的脚本仅被创建，尚未在 trace 中执行验证，落地前需在预发环境先演练。

## Evidence or Examples

HarmonyProject1，「帖子评论删除后评论数未更新」：

- 修复 `backend/src/services/reportService.ts`（审核下架/恢复时幂等维护 `post.commentCount`）并通过 42 项测试后，Agent 明确指出：「历史已下架的评论（修复前下架的）其 `commentCount` 从未减过，重新进入详情页仍会虚高」。
- 交付：新增一次性校准脚本 `backend/scripts/reconcile-comment-counts.ts`，运行方式 `cd backend && npx tsx scripts/reconcile-comment-counts.ts`，将每个帖子的 `commentCount` 重算为可见评论数。
- 证据强度说明：脚本已创建，但 trace 中未展示执行结果与校正前后的行数对比，属「待验证」状态。
- 关联的写入路径根因见 `2026-10-07-denormalized-counter-status-transition-sync`。
- 与其它手段的分工：回填修的是**存储字段本身**（列表卡片、分享、导出等所有读取点都受益）；若无法立刻执行回填、需先让接口响应当下正确，可用 `2026-10-07-read-time-recompute-override-stale-counter` 的读取侧重算兜底；两者不互斥，回填仍是根治存储的正解。判定症状属于哪一层见 `2026-10-07-derived-count-stale-after-delete-layered-triage`。
