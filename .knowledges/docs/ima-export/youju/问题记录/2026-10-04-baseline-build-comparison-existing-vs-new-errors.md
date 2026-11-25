---
title: "2026-10-04-baseline-build-comparison-existing-vs-new-errors.md"
id: markdown_798285c88467638f6a8dc28635ad6f33_85e9231c92a91f2b996ff740d1f349f37505655250320770
kb: 有据-YouJu
folder: "问题记录"
media_type: 7
tags: []
source: ima
exported_at: 2026-11-23T14:52:37.917Z
---
---
id: 2026-10-04-baseline-build-comparison-existing-vs-new-errors
title: 无法构建通过时用基线对比区分「既有错误」与「本次引入错误」，临时修复验证后必须还原
category: workflow
nature: methodology
created_at: 2026-10-04T23:42:00
updated_at: 2026-10-04T23:42:00
tags: [build-verification, git-stash, baseline-diff, delivery-boundary]
keywords: [基线对比, git stash, 既有错误, 新引入错误, 编译错误归属, 回归验证, 临时修复还原, git checkout, diff --stat, BUILD SUCCESSFUL, 交付边界]
problem_patterns: [cannot-tell-if-build-error-is-mine, pre-existing-compile-error-blocks-verification, temp-fix-leaked-into-deliverable]
source_sessions: [ses_ef878f020ffeJQdEElwoaUEijp]
project: HarmonyProject1
severity: medium
quality_score: 86
hit_count: 0
last_hit_at: null
low_quality_hit_count: 0
tier: S
related_experiences: [2026-10-04-arkui-wrapper-hides-native-component-identification, 2026-09-15-arkts-strict-mode-constraints]
---

# 无法构建通过时用基线对比区分「既有错误」与「本次引入错误」，临时修复验证后必须还原

## Scenario

在一个**本身就不能干净编译**的仓库里修改代码（历史遗留编译错误、他人未提交的半成品、本次任务范围外的坏文件）。你需要证明「我的改动没错」，但全量构建会因无关文件报错而 FAIL，无法直接得出「我的改动是好的」这一结论。典型场景：改完 2 个文件后跑构建，报错行落在你**没碰过**的文件上。

## Key Signals

1. 构建失败，但报错文件的路径**不在本次 diff 范围内**。
2. 你无法确定该错误是「一直就有」还是「被自己的改动间接触发」。
3. 报错计数稳定出现（如 `COMPILE RESULT:FAIL {ERROR:2 WARN:136}`），但错误行指向无关文件。

## Essence

「构建失败」不等于「本次改动有问题」。要判定错误归属，唯一可靠的做法是**在同一套环境、同一条命令下比较两个版本**：带改动的版本 vs 干净基线（HEAD）。若错误集合完全一致，则错误是既有的、与本次改动无关。

若既有错误阻塞了「我的改动能否编译通过」这一验证，可以**临时修复**它跑通一次构建；但临时修复属于验证脚手架，**验证后必须还原，绝不进入交付 diff**。这是区分「验证手段」与「交付内容」的纪律问题。

## Approach

1. **暂存自己的改动**，确保基线干净：

   ```bash
   git stash push -u -m "wip-my-change"   # 或只提交到临时分支
   git status                              # 确认工作区已无本次改动
   ```

2. **在基线上跑与之前完全相同的构建命令**，保存错误输出：

   ```bash
   <build-cmd> 2>&1 | tee /tmp/baseline-build.log
   grep -E "ERROR|COMPILE RESULT" /tmp/baseline-build.log
   ```

3. **对比两版错误集合与计数**：若基线错误与带改动版本**逐条一致**（文件、行号、计数），判定为既有错误，与本次改动无关。
4. **恢复自己的改动**：

   ```bash
   git stash pop
   ```

5. **（可选）临时修复既有错误以跑通验证**：只改到能编译为止，执行构建，看到 `BUILD SUCCESSFUL` 即证明自己的改动无编译错误。
6. **还原临时修复**，只保留本次任务内的改动：

   ```bash
   git checkout -- <临时修改的无关文件>
   git diff --stat                        # 最终核对：只应包含本次任务的文件
   ```

7. **交付时明确声明**：本次构建在「临时修复了既有错误 X 的前提下通过」，既有错误 X 未纳入本次改动，并把它作为独立待办交还用户。

## Faster Next Time

- 看到构建报错文件不在自己 diff 里，**第一反应不是改那个文件**，而是先做基线对比。
- 判定口诀：**同环境、同命令、比错误集合；一致即既有，新增才归我**。
- 只跑「带改动的构建」一次就下结论是错的：没有基线就没有归属判据。
- 交付前必跑 `git diff --stat` / `git status`，确认没有把「为验证而临时改的无关文件」一起交出去。
- 若仓库长期存在阻塞性既有错误，把它登记为独立工单，而不是每次任务都私下临时修复。

## Applicability Boundaries

- 适用：任何「仓库无法干净构建、需要在既有噪声中验证自身改动」的场景（编译型语言、lint、类型检查、测试套件同理）。
- 适用工具：git 的 stash/checkout/diff；非 git 仓库可用「备份-还原」等价操作。
- 不适用：仓库本就能干净构建（此时直接构建即可，无需基线对比）。
- 边界提醒：基线对比只能证明「错误归属」，不能证明「功能正确」；运行期行为仍需功能验证或设备自测。
- 风险点：`git stash pop` 可能冲突；建议先 stash 为具名条目并确认无未预期覆盖。

## Evidence or Examples

（来源：HarmonyProject1 发布页重做会话）

- 本次改动仅涉及 `entry/src/main/ets/components/ImagePicker.ets` 与 `entry/src/main/ets/pages/PublishPreviewPage.ets`。
- 首次构建失败：`ArkTS Compiler Error ... Object is possibly 'null'. At File: .../PostDetailView.ets:1084:39`，`COMPILE RESULT:FAIL {ERROR:2 WARN:136}`——报错文件不在改动范围内。
- `git stash` 后对基线构建，得到完全相同的 `ERROR:2 WARN:136` 与同一行号，证明为既有错误。
- `git checkout -- PostDetailView.ets`（临时修复后还原）与 `git stash pop` 后，`git diff --stat` 仅剩本次 2 个文件，构建 `BUILD SUCCESSFUL` 证明改动本身可编译。
- 同一既有错误与 `DEVECO_SDK_HOME` 问题也曾作为旁证出现在 `2026-10-04-arkui-wrapper-hides-native-component-identification` 的证据小节中。
