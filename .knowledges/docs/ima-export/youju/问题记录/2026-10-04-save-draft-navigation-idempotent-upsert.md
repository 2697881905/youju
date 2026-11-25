---
title: "2026-10-04-save-draft-navigation-idempotent-upsert.md"
id: markdown_798285c88467638f6a8dc28635ad6f33_8ca429dc2ba78fc9ae17b039a4ec687c7505655250320770
kb: 有据-YouJu
folder: "问题记录"
media_type: 7
tags: []
source: ima
exported_at: 2026-11-23T14:52:37.917Z
---
---
id: 2026-10-04-save-draft-navigation-idempotent-upsert
title: 草稿「保存后返回编辑页」的导航语义与幂等 upsert：回写 activeDraftId 防止重复草稿
category: architecture
nature: decision
created_at: 2026-10-04T23:44:09
updated_at: 2026-10-04T23:44:09
tags: [draft-editor, navigation-semantics, idempotent-save, upsert, publish-flow]
keywords: [savePostDraft, activeDraftId, setActiveDraftId, router.back, 存草稿, 草稿幂等, 重复草稿, upsert, 导航语义, PublishPreviewPage, publishFlowStore, 保存草稿不跳转]
problem_patterns: [save-draft-then-re-save-creates-duplicate-draft, active-draft-id-not-written-back-after-save, save-action-navigation-semantics-mismatch-product-requirement]
source_sessions: [ses_ef87e073affeXd6HCHCPHh8o80]
project: HarmonyProject1
severity: medium
quality_score: 83
hit_count: 0
last_hit_at: null
low_quality_hit_count: 0
tier: A
related_experiences: [2026-10-04-publish-draft-three-layer-state-architecture, 2026-10-04-local-persistent-list-versioned-envelope-validation]
---

# 草稿「保存后返回编辑页」的导航语义与幂等 upsert：回写 activeDraftId 防止重复草稿

## Scenario

多页编辑器流程「编辑页 → 预览页 → 存草稿」。已有一套分层的草稿状态架构（页面局部态 / 进程内跨页 store / 持久化 store），但产品提出了一个与默认约定不同的显式需求：**用户执行「存草稿」后，页面应由预览界面自动跳转回发布编辑界面，便于继续修改**。

这正是需要权衡的决策点：既有架构经验主张「保存动作不跳转，只有提交成功才离开流程」；而本次产品要求保存后跳转。两者不是谁对谁错，而是**保存动作的导航语义由产品定义**——但一旦选择跳转，就必须同时解决跳转带来的副作用。

## Key Signals

1. 产品需求文档显式写明「存草稿后由预览界面自动跳转回发布编辑界面」——与既有「保存不跳转」经验相反。
2. 若照默认做法只写存储不跳转：不满足需求。
3. 若只在保存后加 `router.back()`：会导致「存草稿 → 返回编辑页 → 再存草稿」产生**第二条草稿**（每次保存都新建，草稿箱出现重复项）。
4. 跳转本身是二次动作（先持久化、再导航），保存失败时不能导航，需要失败分支。

## Essence

这里有两个彼此耦合、必须一起解决的决策：

1. **导航语义是产品决策，不是技术默认**。「保存是否离开当前上下文」应显式由产品定义并在代码中固化；默认建议不跳转（避免打断编辑），但当产品明确要求跳转时，跳转本身不是问题。
2. **一旦保存后要「返回并可能再次保存」，保存就变成幂等 upsert**。保存必须携带一个"当前草稿 id"作为幂等键：有 id 则覆盖同一条，无 id 才新建；且**保存成功后必须把新生成的 id 回写给编辑页**，否则编辑页不知道已存在草稿，下次保存仍会新建。跳转只是把"用户会再次保存"这一路径变得高频，从而放大这个隐藏缺陷。

关键张力：**"保存"在语义上是一次状态迁移（编辑态 → 持久化态），而"跳转"是另一次状态迁移（预览态 → 编辑态）**。两者耦合时，"持久化态"必须能反过来标识自己，跨页回写，才能支撑下一次编辑。

## Approach

1. 让保存函数以 id 为幂等键，返回保存后的实体（含最终 id）：

   ```ts
   // postDraftStore：有 activeDraftId 则覆盖同一份，否则新建
   const saved = savePostDraft(ownerId, draft, activeDraftId);
   ```

2. 保存成功后**立即把 id 回写到跨页 store**，供编辑页后续保存复用：

   ```ts
   publishFlowStore.setActiveDraftId(saved.id); // 编辑页据此持有最新草稿 id
   ```

3. 跳转方向由页面栈决定：预览页由编辑页 `pushUrl` 打开，保存后应 `back()` 回到编辑页，而不是再 `pushUrl` 新建一个编辑页（否则页面栈层层堆叠）：

   ```ts
   this.getUIContext().getRouter().back();
   ```

4. 用 `try/catch` 包住"持久化 + 回写 + 跳转"，**只有持久化成功才跳转**，失败给用户 toast，停留在预览页：

   ```ts
   try {
     const saved = savePostDraft(getUserId(), this.currentDraft(), activeDraftId);
     publishFlowStore.setActiveDraftId(saved.id);
     safeShowToast(ui, { message: '草稿已保存' });
     this.getUIContext().getRouter().back();
   } catch (e) { safeShowToast(ui, { message: '草稿保存失败：' + msg }); }
   ```

5. 与既有架构经验对齐：默认「保存不跳转」仍成立；本模式的适用前提是**产品显式要求保存后跳转**，且必须配套 id 回写。

## Faster Next Time

- 看到需求要求"保存后跳转/返回"，立刻反问一句：**这份数据再存一次，会不会变成第二条？** 若有此风险，先补 id 幂等键与回写，再实现跳转。
- 快速自检：`grep` 搜索 `save*` 函数体里是否出现 `router.back()/pushUrl`。出现即说明"保存"与"导航"被耦合，需检查是否有 id 回写与失败分支。
- 判断跳转方式：子页面用 `back()` 回父页；只有确实要进入新上下文时才 `pushUrl`。
- 若发现既有经验写着"保存不跳转"，不要直接当教条——先确认当前产品是否有相反的显式要求，再看是否配套了幂等保存。

## Applicability Boundaries

- 适用：多页「编辑-预览-保存」流程、草稿可被反复保存、产品可能要求保存后返回编辑页。
- 不适用：单页无导航的自动保存；草稿只允许保存一次的流程（此时 id 幂等键无必要）。
- 触发重估：当草稿 id 改由服务端生成、保存改为调用 upsert API 时，幂等键与回写逻辑应迁移到服务端 id/接口语义，本机 store 只做缓存。
- 与 `2026-10-04-publish-draft-three-layer-state-architecture` 的关系：该经验给出"保存默认不跳转"的基线决策；本经验是其**边界补充/例外分支**，处理"产品显式要求跳转"的情况，两者应配合阅读而非互相否定。

## Evidence or Examples

（来源：HarmonyProject1 发布页优化会话，`ses_ef87e073affeXd6HCHCPHh8o80`；两需求重新实现后 `hvigor BUILD SUCCESSFUL`，改动集中在 2 个文件）

- `entry/src/main/ets/pages/PublishPreviewPage.ets` `saveCurrentDraft()`（约 L302-320）：
  - L309 读取 `publishFlowStore.getSession().activeDraftId`；
  - L310 `savePostDraft(getUserId(), this.currentDraft(), activeDraftId)` —— 以 id 为幂等键的 upsert；
  - L311-312 注释「intent='sync'：编辑页据此持有最新草稿 id，避免『存草稿 → 返回 → 再存』产出重复草稿」；`publishFlowStore.setActiveDraftId(saved.id)`；
  - L314-315 注释「需求：执行存草稿后，由预览页自动跳转回发布编辑界面（预览页由编辑页 pushUrl 打开，back 即返回）」，`this.getUIContext().getRouter().back()`；
  - L316-319 `catch` 分支 toast 保存失败。
- 产品需求原文：「保存草稿：用户执行『存草稿』操作后，页面应由预览界面自动跳转回发布编辑界面。」
- 对照来源：`architecture/2026-10-04-publish-draft-three-layer-state-architecture.md` 的 `problem_patterns` 含 `save-draft-triggers-unexpected-navigation`（保存默认不跳转）；本经验记录其例外与配套要求。
