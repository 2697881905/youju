---
title: "2026-10-04-confirm-intent-before-rewriting-existing-feature.md"
id: markdown_798285c88467638f6a8dc28635ad6f33_c550f8ba11923498378a8c0b6f8ff11f7505655250320770
kb: 有据-YouJu
folder: "问题记录"
media_type: 7
tags: []
source: ima
exported_at: 2026-11-23T14:52:37.917Z
---
---
id: 2026-10-04-confirm-intent-before-rewriting-existing-feature
title: 需求疑似「已实现」时先核实并向用户确认意图，再决定修复/优化/重做
category: agent-ops
nature: methodology
created_at: 2026-10-04T23:44:09
updated_at: 2026-10-04T23:44:09
tags: [intent-confirmation, existing-implementation, avoid-rework, code-exploration, agent-workflow]
keywords: [需求已实现, 重复实现, git log, 意图确认, 修复还是重做, 擅自改写, 已验证代码, 探索先行, 避免返工, 并行会话]
problem_patterns: [rewrite-already-working-code-without-confirmation, stop-at-feature-already-exists-without-delivering, user-intent-mismatch-fix-vs-rebuild]
source_sessions: [ses_ef87e073affeXd6HCHCPHh8o80]
project: HarmonyProject1
severity: medium
quality_score: 79
hit_count: 0
last_hit_at: null
low_quality_hit_count: 0
tier: A
related_experiences: [2026-10-04-baseline-build-comparison-existing-vs-new-errors, 2026-10-04-arkui-grid-drag-reorder-watch-guard, 2026-10-04-arkui-image-draggable-gesture-conflict]
---

# 需求疑似「已实现」时先核实并向用户确认意图，再决定修复/优化/重做

## Scenario

用户以需求描述发起功能开发（如「发布页新增长按拖拽排序图片」「存草稿后返回编辑页」）。Agent 进入探索阶段后，发现仓库里**似乎已有对应实现**——最近一次提交的标题、代码中的关键 API/注释都指向该功能。

此时存在三个都可能有错的方向：
- 直接把「已存在」当结论停下，不交付任何改动；
- 认定「已有实现必然有问题」，擅自改写他人/并行会话已验证的代码；
- 忽略现状，从头重做并删除既有实现。

## Key Signals

- `git log --oneline` 最近一条提交标题恰好命中需求关键词（如 `feat(发布): ImagePicker 长按拖拽排序图片 + 发布/存草稿交互优化`）。
- `git status` 工作区干净（说明实现已提交，非未保存草稿）。
- `grep` 在目标文件命中需求涉及的实现点（如 `Grid.editMode(true)`、`onItemDragStart`、`router.back()`）。
- Agent 观察到提交说明标注「并行会话产出，已审查后接入」之类的团队协作痕迹。

## Essence

「已实现」既不等于「无需处理」，也不等于「可以随意改写」。同一句需求描述，用户可能想要三种不同结果：

1. **修复**：现有实现有缺陷，要求改对；
2. **优化/调整**：现有效果不满足预期，要求改进；
3. **重做**：明确不认可现有实现，要求从头再来。

Agent 无权替用户在这三者间做选择，尤其在多会话/多人并行、代码已被他人验证的场景下：擅自改写会破坏别人成果并引入回归。正解是**先用可核验的证据陈述现状，把选择权交还用户**，再按选择执行。

同时，重做 ≠ 从零抛弃：既有实现是重要的「经验来源」，其中已验证的边界修正（如组件必须 `.draggable(false)`）应被继承，而不是随删除一起丢掉。

## Approach

1. **探索先行，别急着写**：接到需求先做最小核实——`git log --oneline` 看近期提交、`git status` 看工作区、在相关文件 `grep` 需求关键词。
2. **若命中已有实现，不擅自改也不沉默终止**：向用户给出「现状 + 证据 + 选项」：
   - 现状：该功能已在提交 `<hash>` 中实现；
   - 证据：具体文件与行号（如 `ImagePicker.ets:274` Grid `editMode`、`PublishPreviewPage.ets:315` `router.back()`）；
   - 选项：修复现有缺陷 / 优化调整 / 忽略现有实现从头重做。
3. **按用户选择执行**；若用户选「重做」，先把旧实现复盘一次，提取其中独立验证过的坑与判断（若旧实现缺陷独立可证，也可顺带记录）。
4. **重做后仍要走完整验证**（构建/测试），并区分"既有失败"与"本次引入失败"（可参考基线对比经验）。
5. 交付时说明"未提交/已提交"的边界，由用户决定是否提交。

## Faster Next Time

- 需求到手第一步固定加一条：`git log --oneline -n 20`（或全库搜需求关键词），先判断是否已被近期实现——在多 agent 并行项目里这一步尤其省事。
- 发现"已实现"时，输出模板固定为「现状（含提交号）→ 证据（文件:行号）→ 三个选项」，避免独断也避免沉默。
- 重做时把旧实现当"经验来源"而非"要删的代码"：先通读，记下它踩过的坑，再开写。
- 用户明确选"重做"后，不要反复劝退；按新方案实现，但保留独立验证结论。

## Applicability Boundaries

- 适用：需求描述与实际实现重叠、多会话/多人并行开发、已有代码被他人验证过的场景。
- 不适用：需求明确是全新功能且仓库无对应实现；或已有实现明显有 bug 且用户已明确要求修复（此时可直接修）。
- 平台：通用 Agent 协作模式，不限于特定 IDE / Agent 平台。
- 边界：本经验约束的是"是否重写"的判断流程，不改变对既有实现正确性的独立验证要求——重做后仍需自行验证。

## Evidence or Examples

（来源：HarmonyProject1 发布页优化会话，`ses_ef87e073affeXd6HCHCPHh8o80`）

- 探索证据：`git log` 显示提交 `512a0ad feat(发布): ImagePicker 长按拖拽排序图片 + 发布/存草稿交互优化`，`git status` 工作区干净。
- 代码证据：`entry/src/main/ets/components/ImagePicker.ets:274` `Grid.editMode(true)` + `onItemDragStart/onItemDrop`；`entry/src/main/ets/pages/PublishPreviewPage.ets:315` `router.back()`。
- 用户决策：Agent 向用户确认后，用户选择「重新实现这两个功能 —— 忽略现有实现，从头重做」。
- 执行结果：重做后 `hvigor BUILD SUCCESSFUL`，改动集中在 `ImagePicker.ets` 与 `PublishPreviewPage.ets` 两个文件；重做中继承了既有经验中"Image 必须 `.draggable(false)` 否则系统拖拽劫持长按"的边界修正。
- 相关既有经验：`2026-10-04-arkui-grid-drag-reorder-watch-guard`、`2026-10-04-arkui-image-draggable-gesture-conflict` 均来源于并行探索会话，佐证"已实现代码本身即经验来源"。
