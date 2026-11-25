---
title: "2026-10-04-local-persistent-list-versioned-envelope-validation.md"
id: markdown_798285c88467638f6a8dc28635ad6f33_946e9ef26fea5a56ea7dd6e7213d92877505655250320770
kb: 有据-YouJu
folder: "问题记录"
media_type: 7
tags: []
source: ima
exported_at: 2026-11-23T14:52:37.917Z
---
---
id: 2026-10-04-local-persistent-list-versioned-envelope-validation
title: 本机持久化列表的版本化信封 + 逐条校验 + 账号隔离模式
category: coding-pattern
nature: technique
created_at: 2026-10-04T22:48:18
updated_at: 2026-10-04T22:50:04
tags: [persistence, AppStorage, PersistentStorage, data-validation, multi-account]
keywords: [PersistentStorage.persistProp, AppStorage, JSON.parse, 版本化信封, version, isValidDraft, 反序列化校验, ownerId, 账号隔离, 草稿, 脏数据]
problem_patterns: [dirty-json-item-breaks-whole-list, persisted-structure-upgrade-without-version, multi-account-data-leak-in-local-storage]
source_sessions: [ses_ef8a5f1e1ffe6ZlDmgrucRDwMC]
project: HarmonyProject1
severity: medium
quality_score: 81
hit_count: 2
last_hit_at: 2026-10-04T23:22:05
low_quality_hit_count: 0
tier: A
related_experiences: [2026-10-04-publish-draft-three-layer-state-architecture]
---

# 本机持久化列表的版本化信封 + 逐条校验 + 账号隔离模式

## Scenario
用 `AppStorage` / `PersistentStorage` 以 JSON 字符串保存"本机私有列表"（草稿箱、最近浏览、离线记录等），并要跨启动留存。这类数据由客户端自己写入，格式会随版本演进，且可能来自多个登录账号。

## Key Signals
- 单条脏数据（字段缺失、类型不符、旧版本结构残留）导致整份 JSON 解析失败或渲染异常。
- 覆盖安装（`hdc install -r` / DevEco Run）后冷启动读到旧结构数据。
- 切换账号后仍能看到别的账号的未发布内容。

## Essence
把持久化值设计为带版本的"信封"，读取时逐条校验、过滤非法项，并按 `ownerId` 隔离：

- **版本化信封**：值不是裸数组，而是 `{ version, items }`。键与版本用常量声明（如 `SAVED_POST_DRAFTS_KEY = 'savedPostDrafts'`、`SAVED_POST_DRAFTS_VERSION = 2`）。没有版本号就无法在结构升级时安全迁移。
- **逐条校验**：读取时 `JSON.parse` → 遍历 → `isValidDraft(item)` 对每个字段做 `typeof` / 枚举 / `Array.isArray + every` 校验 → 只保留合法项。坏数据丢弃，而不是让整份列表失败。
- **账号隔离**：接口按 `ownerId` 过滤（`listPostDrafts(ownerId)`），写入时落 `ownerId / createdAt / updatedAt`。

这三件事是正交的：信封解决"结构升级"，校验解决"脏数据"，ownerId 解决"多账号串数据"。

## Approach
1. 定义 key 与 version 常量；初始化默认值：`PersistentStorage.persistProp(KEY, '[]')`（或先写空信封）。
2. 定义 `isValidItem`：对每个字段逐一 `typeof` 校验；枚举字段（如 `mode`）用显式集合判断，兼容 `undefined`：
   ```ts
   (draft.mode === undefined || draft.mode === 'photo' || draft.mode === 'text' || draft.mode === 'video') &&
   Array.isArray(draft.images) && draft.images.every((u: string): boolean => typeof u === 'string')
   ```
3. 读取：`try { parse } catch { return [] }` + `filter(isValidItem)`，坏项静默丢弃并计数。
4. 写入：统一 `writeDrafts()`，序列化信封（带 version）后 `AppStorage.setOrCreate<string>(KEY, JSON.stringify(payload))`，再通知订阅者刷新。
5. 所有查询按 `ownerId` 过滤；列表变更通过订阅回调驱动 UI 重载。

## Faster Next Time
- 本地列表持久化**从第一天就带 version 字段**，否则结构升级时没有迁移锚点。
- 反序列化后**永远先校验再使用**；禁止让 UI 直接消费 `JSON.parse` 结果。
- 本机私有数据一律带 `ownerId`，从源头避免多账号串数据。
- 代码审查检查点：搜索 `JSON.parse` 调用点，若其后没有 `filter` / 校验函数，即为风险点。

## Applicability Boundaries
- 适用：本机私有、非结构化、体量不大的列表数据。
- 不适用：需要复杂查询、事务或大数据量的场景——应改用关系型数据库（`relationalStore`），当前项目全局未使用 relationalStore。
- 触发重估：数据结构频繁变更、需要并发写，或需要服务端同步时。
- 关键性边界：仅适用于**非关键**本机数据。登录态、权限/付费等关键数据不应依赖 `PersistentStorage` 的隐式持久化（覆盖安装后冷启动读不回、AppStorage 回默认值），应改用 `@kit.ArkData` 的 `preferences` 或 `relationalStore`；草稿等非关键列表用本模式即可，与 `2026-10-04-publish-draft-three-layer-state-architecture` 的分层结论一致。

## Evidence or Examples
（来源：HarmonyProject1 发布流程调研）
- `entry/src/main/ets/utils/postDraftStore.ets` L5-6 key/version 常量；L9 `PersistentStorage.persistProp(SAVED_POST_DRAFTS_KEY, '[]')`；L11-16 `SavedPostDraft extends PublishDraft`（含 `id/ownerId/createdAt/updatedAt`）；L18-21 `DraftStorageEnvelope { version, drafts }`；L26-38 `isValidDraft` 逐字段校验；L75-97 `allDrafts()` 解析 + 过滤；L99-105 `writeDrafts()`；L124-168 `savePostDraft`。
- 对比：登录态/主题改用 `@kit.ArkData` 的 `preferences`（`utils/sessionStore.ets` L11/L36/L73），非关键 UI 态仍走 `PersistentStorage`（`utils/auth.ets` L26-28）。
- 相关坑：`utils/sessionStore.ets` L3-11 注释记录——覆盖安装后冷启动 `PersistentStorage` 大概率读不回旧文件，AppStorage 全部回默认值，因此关键数据不能依赖其隐式持久化。
