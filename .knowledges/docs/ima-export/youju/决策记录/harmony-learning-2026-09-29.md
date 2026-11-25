---
title: "harmony-learning-2026-09-29.md"
id: markdown_798285c88467638f6a8dc28635ad6f33_7ead393ecec97db04f5d8b8922d317de7505655250320770
kb: 有据-YouJu
folder: "决策记录"
media_type: 7
tags: []
source: ima
exported_at: 2026-11-23T14:52:37.917Z
---
# 增量学习摘要 · 2026-09-29

> 来源文档：`.trae/documents/dead-code-and-quality-plan.md`（新增，归入 IMA「开发文档」）
> 同步结果：create_media → COS PUT（ETag 3af75c85…）→ add_knowledge 至 folder_7505655426480055

## 3 条项目事实
1. 上线前全链路测试已通过：后端 `tsc` 通过、`jest` 29 套件 / 232 用例全绿、前端 `assembleHap` BUILD SUCCESSFUL、真实接口冒烟 85/0；功能层面健康，本轮目标是「不破坏可用性」前提下的质量优化。
2. 死代码判定硬标准：在全 `entry/src/main/ets` 下 grep 仅命中定义自身（0 引用证据）才可删；4 个候选符号中 `postFooter`（ProfilePage.ets:727）不删，改为接线修复「个人主页四个列表滚到底无反馈」的漏接功能。
3. 最大文件清单：前端 `PostDetailView.ets` 1617 行、`ChatView.ets` 1340 行、`HomeTab.ets` 1050 行；后端 `postService.ts` 842 行（单文件承载信息流/每日/搜索/回收站/删除多职责）——均为后续独立重构候选。

## 2 条关键决策
1. 保守默认执行：原方案就「删除尺度 / 大文件重构 / postFooter 归属」向你确认的提问被跳过，故按最小变动默认执行——只删已验证死代码、不拆大文件、postFooter 按漏接功能接线修复。印证既有心法：确认问答缺失时选最小变动，不主动加戏。
2. 后端 P2002 幂等判定收敛：新增 `backend/src/utils/prismaErrors.ts` 导出 `isUniqueViolation(e)`（判 `e?.code === 'P2002'`），将 `interactService/blockService/dislikeService/followService` 5 处逐字重复提取为单一 helper，行为完全不变，仅收敛判定。

## 1 个可复用模式 / 检查项
**死代码删除护栏（可复用检查项）**：每批改动后必须重建回归链——`tsc --noEmit` → `jest --ci` → `assembleHap` → 仓库既有守卫脚本（`scripts/verify-arkui-hooks.mjs`、`verify-login-gates.mjs`、`check-stale-overwrite.mjs`）；每步一个独立提交，全部可 `git revert`。任何「删代码」类任务都应先列「排除项（勿删）」清单（如 `*Destination`/`*View` 壳、`main_pages.json`、运维脚本、admin 接口），避免误伤设计性存在。

## SKILL 处置
无新增 SKILL：本篇为过程性质量优化方案，未出现可复用的单点 bug 模式（既有 `arkui-runtime-pitfalls` 已覆盖 ArkTS 严格模式类踩坑），故不新建冗余 SKILL。
