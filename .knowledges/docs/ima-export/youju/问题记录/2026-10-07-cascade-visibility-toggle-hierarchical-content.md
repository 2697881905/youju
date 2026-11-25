---
title: "2026-10-07-cascade-visibility-toggle-hierarchical-content.md"
id: markdown_cls1_798285c88467638f6a8dc28635ad6f33_87a3c3cf9e44e3f8315e8e7cae793cc27505655250320770
kb: 有据-YouJu
folder: "问题记录"
media_type: 7
tags: []
source: ima
exported_at: 2026-11-23T15:08:11.610Z
---
---
id: 2026-10-07-cascade-visibility-toggle-hierarchical-content
title: 层级内容软下架/恢复必须级联整棵子树：否则产生「计入聚合数、却从树视图消失」的孤儿节点
category: coding-pattern
nature: pitfall
created_at: 2026-10-07T01:12:01
updated_at: 2026-10-07T01:54:57
tags: [hierarchical-content, cascade-visibility, soft-delete, orphan-node, counter-consistency]
keywords: [级联下架, 孤儿节点, 楼中楼, buildCommentTree, 软删除语义, 计数与展示不一致, 递归子树收集, self-join 探针, parentId 链, cascade takedown]
problem_patterns: [soft-visibility-toggle-not-cascaded-to-descendants, hierarchical-rows-become-orphans-and-inflate-aggregate, physical-delete-cascades-but-soft-hide-does-not]
source_sessions: [ses_eedd3752fffetKbN8bZbsXcX0H, ses_ef42f4035ffekN6vk5fZoDuUMc]
project: HarmonyProject1
severity: high
quality_score: 91
hit_count: 0
last_hit_at: null
low_quality_hit_count: 0
tier: S
related_experiences: [2026-10-07-denormalized-counter-status-transition-sync, 2026-10-07-derived-count-stale-after-delete-layered-triage, 2026-10-07-read-time-recompute-override-stale-counter, 2026-10-05-arkui-child-local-mutation-parent-sync-contract]
---

# 层级内容软下架/恢复必须级联整棵子树：否则产生「计入聚合数、却从树视图消失」的孤儿节点

## Scenario

内容带父子层级（楼中楼评论、嵌套回复、目录、任务子项），可见性用状态字段（如 `status: 1` 可见 / `0` 下架）而非物理删除。查询侧先按可见性过滤行，再把扁平行按 `parentId` 组装成树展示；同时用冗余聚合计数（如 `post.commentCount`）做角标/统计。

当「下架父节点」只翻转父这一行时，其后代仍留在可见集合里。于是一个**孤儿**出现：按过滤条件计数时它被算进去，而按父链组装树时它因为父不在结果集里而挂不上、被丢弃——用户看到「计数比实际可见条目多」或「评论区空了却仍显示评论 N」。

任何「层级内容 + 软可见性 + 面向用户的聚合/树视图」的组合都会重现同类问题。

## Key Signals

1. 聚合计数与实际可见的树节点数不符，常差 1 或几条，且**只在层级子项上出现**。
2. 用户报「评论区已空仍显示评论 N」「评论 N 比能看到的条目多」。
3. 物理删除路径是级联的（如 `deleteMany({ where: { id: { in: ids } } })` 加上对子树的遍历），而软下架路径只翻转单行——两种「删除」语义不一致。
4. 树构建函数在「父不在返回窗口」时既没有提升为一级也没有显式兜底，而是悄悄丢弃该节点。

## Essence

层级内容的可见性本质是一个**闭包语义**：父不可见 ⇒ 其后代也不应出现在面向用户的树/列表里。

- **物理删除天然满足闭包**：删除的是整棵子树的 id 集合，后代一并消失。
- **软下架默认不满足**：只翻转被操作那一行，后代行仍留在 `status=1` 的可见集合中。它们的行还在、还会被 `count(status=1)` 统计，但按父链组装时挂不上父节点，从而在展示层「消失」。

这就是「计数算它、界面看不到」的根因：**过滤集合（计数依据）与树视图（展示依据）对同一批孤儿行给出了不同结论**。

修复方向有两条，必须先确认产品语义，二选一、不可混用：

1. **级联隐藏**（与物理删除一致）：下架父节点时把整棵子树一起 `1 → 0`，计数按实际受影响条数扣减；恢复时对称回补。
2. **提升孤儿**：保留后代可见，只在树构建侧把「父不可见/缺失」的节点提升为一级根，计数也相应按可见集合口径。

## Approach

1. **先用一条探针 SQL 定位孤儿，别猜**（父不可见或缺失、但自身可见的行）：
   ```sql
   SELECT c.id, c.postId, c.parentId, c.status, p.status AS parentStatus
   FROM Comment c LEFT JOIN Comment p ON c.parentId = p.id
   WHERE c.status = 1 AND c.parentId IS NOT NULL AND (p.id IS NULL OR p.status <> 1);
   ```
   有输出即证实存在孤儿，且这些行正是「计数多出来」的部分。
2. **对齐删除语义**：确认物理删除路径的级联范围（通常递归整棵子树），让软下架覆盖同一 id 集合。
3. **递归收集子树 id**：沿 `parentId` 向下做 BFS/DFS 收集整棵子树 id（含跨层）：
   ```typescript
   // 递归收集评论的全部后代 id（不含自身）
   async function collectCommentSubtreeIds(tx, commentId: number): Promise<number[]> {
     const children = await tx.comment.findMany({
       where: { parentId: commentId },
       select: { id: true },
     });
     const ids: number[] = [];
     for (const child of children) {
       ids.push(child.id);
       ids.push(...await collectCommentSubtreeIds(tx, child.id));
     }
     return ids;
   }
   ```
4. **事务内幂等下架**：
   ```typescript
   const ids = await collectSubtreeIds(tx, targetId); // 含自身与所有后代
   const takenDown = await tx.comment.updateMany({
     where: { id: { in: ids }, status: 1 },
     data: { status: 0 },
   });
   if (takenDown.count > 0) {
     await tx.post.update({ where: { id: postId }, data: { commentCount: { decrement: takenDown.count } } });
   }
   ```
   用「条件更新命中行数」而非固定 `-1`，保证幂等（阈值自动下架 + 管理员裁决可能先后触发同一目标）。
5. **恢复对称**：`status: 0 → 1` 批量整棵子树，并按命中行数把计数补回。
6. **若产品选「保留子回复」**：改在树构建侧把孤儿提升为一级根，且把计数口径改为「过滤后行数」而非「成功挂树的节点数」。
7. **纳入同一事务**：子树收集 + 状态翻转 + 计数增减放在一个 `$transaction` 内。
8. **回归断言**：构造「父+子+孙」三层树，不变式写成「聚合计数 == 按可见性过滤后、且能被正确组装的节点数」，覆盖「下架父连带子」「恢复父连带子」「重复下架不重复扣」。
9. **历史孤儿数据清理**：递归 SQL 将所有「父不可见的可见子节点」级联隐藏，再重算计数字段。

## Faster Next Time

- 遇到「删除后计数不变」，先问三件事：删除是**物理**还是**软可见性**翻转？内容是**层级**的吗？物理删除级联了、软下架有没有级联？——语义缺口多源于此。
- 一行 self-join 探针 SQL 就能确认孤儿，比反复读代码快得多。
- 代码审查规则：看到 `deleteMany({ where: { id: { in: ids } } })` 这类**级联删除**，立刻检查对应的**软下架/软删除路径**是否处理了同一 id 集合。
- **树构建器防御**：即使选择了级联隐藏，树构建器也应防御性处理孤儿（找不到父时提升为一级或显式跳过并记日志），而非静默丢弃——静默丢弃会让问题以「计数虚高」的形式间接暴露，增加定位难度。
- **注释与实现一致性**：树构建器注释说「父链断裂时视作一级」但实际丢弃——这类注释与实现不一致是隐性 bug 的温床，发现时必须修正一方。
- 冗余计数与树视图必须共用同一「可见集合」口径；把计数改成「读时按过滤条件重算」可临时兜底，但级联语义仍需在写入侧补齐。

## Applicability Boundaries

- **适用**：父子/树形内容 + 软删除或可见性状态字段；面向用户的聚合计数或树视图由过滤后的集合派生。
- **适用**：物理删除有级联语义但软隐藏没有的系统——这是最常见的遗漏点。
- **不适用**：扁平内容（无后代），单行状态翻转即等价于集合成员变更，不存在孤儿。
- **不适用**：删除即物理级联且无软下架分支时，常规 create/delete 维护即可。
- **不适用**：树构建器已正确处理孤儿（提升为一级展示）且计数口径与展示一致——此时不需要级联隐藏，但需确认计数口径是否包含提升后的孤儿。
- **前提约束**：必须由产品明确「父不可见时后代是否可见」，否则两条实现都无法判定对错；此外需限制树深，避免递归收集子树在深树/环状数据下失控。
- **策略选择前提**：级联隐藏 vs 提升为一级是产品决策，需与产品语义对齐（论坛通常保留子回复、社交评论通常级联隐藏）。本经验默认级联隐藏，因为它与物理删除的级联语义一致。

## Evidence or Examples

HarmonyProject1，「帖子评论删除后评论数未更新」的最后一层根因（楼中楼评论）：

- 现象链：用户先说评论区计数不变 → 修复写入/读取侧后，用户报「评论2变成评论1了」（评论区只剩 1 条却仍有 1 条对不上）。
- 探针 SQL 输出实锤：`id=34, postId=41, parentId=21, status=1, parentStatus=0` —— 父评论 `21` 已被下架（`status=0`），子回复 `34` 仍是 `status=1`，即孤儿。
- 根因：`deleteComment`（`backend/src/services/commentService.ts`）按 id 集合**级联删除**并 `decrement: ids.length`；而审核下架（`backend/src/services/reportService.ts` 的阈值自动下架 / 管理员 `resolved` / `dismissed` / `restore`）只翻转**单行** `status`。`buildCommentTree` 在父不在返回窗口时无法把子回复挂到树上，节点被丢弃，但 `count(status=1)` 仍统计它。
- 修复：在 `reportService.ts` 增加递归收集子树的工具函数 `collectCommentSubtreeIds`，下架/恢复时对整个子树 `updateMany` 并按命中行数同步 `post.commentCount`；同步更新 `reportService.test.ts` 的 mock 与断言。
- 验证：`npx jest` 全后端 **266 passed**，含新增的「级联下架/恢复」测试用例。
- 同源正交经验：写入侧同步见 `2026-10-07-denormalized-counter-status-transition-sync`，读时重算兜底见 `2026-10-07-read-time-recompute-override-stale-counter`，「是展示层还是数据层」的分层定位见 `2026-10-07-derived-count-stale-after-delete-layered-triage`，ArkUI 子节点局部变更与父同步契约见 `2026-10-05-arkui-child-local-mutation-parent-sync-contract`。
