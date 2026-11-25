---
title: "2026-10-04-publish-draft-three-layer-state-architecture.md"
id: markdown_798285c88467638f6a8dc28635ad6f33_4ab0c4167361008a542ca04e836f86e77505655250320770
kb: 有据-YouJu
folder: "问题记录"
media_type: 7
tags: []
source: ima
exported_at: 2026-11-23T14:52:37.917Z
---
---
id: 2026-10-04-publish-draft-three-layer-state-architecture
title: 编辑器草稿的三层状态分离架构：瞬时跨页态 / 持久化态 / 页面局部态
category: architecture
nature: decision
created_at: 2026-10-04T22:48:18
updated_at: 2026-10-05T00:39:57
tags: [state-management, draft-editor, cross-page, persistence, publish-flow]
keywords: [publishFlowStore, postDraftStore, PublishDraft, AppStorage, PersistentStorage, 进程内单例, 跨页状态, 草稿, 编辑器架构, 状态分层, completePublish, reset-intent]
problem_patterns: [cross-page-state-mixed-with-persistence, draft-mode-inferred-from-content-instead-of-stored, save-draft-triggers-unexpected-navigation]
source_sessions: [ses_ef8a5f1e1ffe6ZlDmgrucRDwMC]
project: HarmonyProject1
severity: medium
quality_score: 80
hit_count: 2
last_hit_at: 2026-10-04T23:22:05
low_quality_hit_count: 0
tier: A
related_experiences: [2026-10-04-save-draft-navigation-idempotent-upsert, 2026-10-04-local-persistent-list-versioned-envelope-validation, 2026-10-04-media-ref-vs-view-url-persistence-contract, 2026-09-26-arkui-animateto-appstorage-layout-transition]
---

# 编辑器草稿的三层状态分离架构：瞬时跨页态 / 持久化态 / 页面局部态

## Scenario
一个"编辑 → 预览 → 存草稿/发布"多页流程，且多种内容类型（图文/长文/视频）共用同一套草稿模型。草稿数据同时有四种诉求：跨页传递、按账号落盘、发布成功后清空、页面内实时编辑。若不做分层，常见做法是把整个草稿对象塞进 router 参数，或用持久化存储兼作跨页传参通道，前者耦合路由、后者把编辑态过早写盘。

## Key Signals
- 发布页与预览页是两个独立 `@Entry` 页面，数据必须跨页传递。
- 草稿要持久化并跨启动留存，还要按登录账号隔离。
- 编辑过程中大量输入态/图片选择态（标题、图片列表、上传中状态）不应写持久化。
- "存草稿"后若顺带跳转，会打断用户继续编辑；"发布成功"后才应真正离开流程。

## Essence
把"草稿状态"按生命周期拆成三层，每层单一职责，禁止跨层直接操作：

1. **页面局部态**：页面内的 `@State`（如 `images: string[]`、`title`），只服务当前页面渲染，不落盘。
2. **瞬时跨页态**：进程内单例 store（`publishFlowStore`），承载 `intent / mode / activeDraftId / previewDraft / completedDraftId`，负责页面间传参与流程编排；生命周期为进程内，不持久化。
3. **持久化态**：`postDraftStore` 把草稿序列化为 AppStorage/PersistentStorage 的 JSON 字符串，负责跨启动留存与账号隔离。

关键决策（trade-off 的核心张力）：**"保存草稿"与"提交发布"是两种不同的状态迁移**。保存草稿只写存储 + 记录 `activeDraftId`，**不跳转**；草稿的清空/回退只由发布成功的 `completePublish()` 统一触发（`intent` 置 `reset`），发布页监听后删除已发布草稿。若两者混在一起，用户点"存草稿"就会被踢出编辑页，或已发布草稿残留在草稿箱。

替代方案的取舍：
- "全部塞进 router params"：被否。路由参数不适合承载结构化大对象，且预览页刷新/回退会丢状态。
- "持久化兼作跨页传参"：被否。会把编辑态过早写盘，且多页面并发时状态不一致。
- "进程内单例只做传参 + 独立持久化模块"：采纳。职责清晰，测试与替换成本低。

## Approach
1. 定义唯一的草稿数据结构 `PublishDraft`（`mode/title/content/genre/tags/images/video...`），三层共用同一 shape；跨层传递时用 `clonePublishDraft` 深拷贝，避免引用共享。
2. 用进程内单例维护跨页 session：新建 `startNew(mode)`、编辑草稿 `editSavedDraft(id)`、进入预览 `beginPreview(draft, editingSavedDraftId)`。
3. 发布成功路径统一走 `completePublish()`：递增全局刷新版本（触发信息流刷新）→ `intent` 置 `reset` → 发布页监听后调用 `removePostDraft`。
4. 持久化单独封装为 `savePostDraft / listPostDrafts / removePostDraft`，页面只调用这些函数，不直接读写 AppStorage 键。
5. **入口类型 `mode` 必须显式存储**，不要从内容反推。

## Faster Next Time
- 跨页传参优先用进程内 store；不要塞 router params，也不要用持久化当传参通道。
- 保存动作默认不跳转；任何"离开当前编辑上下文"的行为都绑定到提交成功，而不是保存。
- 凡是"从内容反推类型"的兜底函数都是坑：无图的图文帖会被反推成长文帖。入口类型必须显式落库（`mode` 字段），旧数据用一次性 fallback 兼容。
- 快速自检：搜索是否存在 `router.back()` / `pushUrl` 被 `save*` 函数调用——有则说明"保存"与"提交"的边界被打破。

## Applicability Boundaries
- 适用：多页"编辑-预览-提交"流程、需要草稿/自动保存的编辑器。
- 不适用：单页内即可完成、无需跨启动留存的简单表单。
- 触发重估：当草稿需要服务端同步/多端一致时，进程内单例与本地持久化两层都应被后端草稿模型替换，仅保留页面局部态。
- 持久化层选型边界：草稿属「非关键本机数据」，用 `PersistentStorage` 可接受；但登录态等关键数据不能依赖其隐式持久化（覆盖安装后冷启动可能读不回、AppStorage 回默认值），须改用 `@kit.ArkData` 的 `preferences` 或 `relationalStore`——见 `2026-10-04-local-persistent-list-versioned-envelope-validation` 的「关键性边界」。
- **例外分支**：当产品显式要求「保存草稿后跳转回编辑页」时，本经验的「保存默认不跳转」基线被覆盖——此时必须配套 id 幂等键与回写，见 `2026-10-04-save-draft-navigation-idempotent-upsert`。

## Evidence or Examples
（来源：HarmonyProject1 发布流程调研）
- `entry/src/main/ets/utils/publishFlowStore.ets` L17-24 `PublishSession` 结构；L50-56 `startNew`；L74-78 `completePublish`。
- `entry/src/main/ets/utils/postDraftStore.ets` L11-16 `SavedPostDraft`；L124-168 `savePostDraft`；L107 注释明确"持久化只由本模块负责"的边界。
- `entry/src/main/ets/utils/publishDraft.ets` L6-21 `PublishDraft`；L23-45 `clonePublishDraft`。
- `entry/src/main/ets/pages/PublishPreviewPage.ets` L302-311 `saveCurrentDraft`（写存储 + 更新 activeDraftId + Toast，**无 router 调用**）；L291-293 发布成功分支（`completePublish()` + Toast 帖子ID + `router.back()`）。
- `entry/src/main/ets/pages/PhotoPublishPage.ets` L45 `@State images`；L222-234 打包草稿；L280-285 监听 reset 后 `removePostDraft`。
- `entry/src/main/ets/utils/publishFlowStore.ets` L7-15 `modeOfDraft` 的 fallback：`images.length === 0 ? 'text' : 'photo'`——无图图文帖被反推为长文帖的根因，故新增 `mode` 字段规避。
