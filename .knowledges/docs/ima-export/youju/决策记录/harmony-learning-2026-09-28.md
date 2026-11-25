---
title: "harmony-learning-2026-09-28.md"
id: markdown_798285c88467638f6a8dc28635ad6f33_fb29dec00fc3e021ce232fddc238ee7d7505655250320770
kb: 有据-YouJu
folder: "决策记录"
media_type: 7
tags: []
source: ima
exported_at: 2026-11-23T14:52:37.917Z
---
# 增量学习摘要 2026-09-28（6 篇新文档）

> 来源：本次同步新上传的 6 篇文档（1 决策记录 + 3 问题记录 + 2 开发文档）。仅提炼新处理文档。

## 3 条项目事实
1. **陈旧 worktree 覆盖是「功能消失」头号成因**：2026-09-27 首页分段栏左右滑动 + 一镜到底突然消失，根因是主检出的 `HomeTab.ets` 被一份落后 121 个提交的陈旧 worktree 旧版本整文件覆盖；已清空全部陈旧 worktree（仅留主检出）并启用三道护栏（pre-commit 字节级比对 + git-doctor 体检/清理 + 手工快照）。
2. **一镜到底「圆角变直角 + 落点瞬移」根因**：飞行载体（卡片截图）自身无圆角（componentSnapshot 不保留卡片 clip 的圆角），且截图按 100% 页宽渲染（实际应是对应节点实测宽），终点整体放大 ~1.1 倍导致溢出后瞬移对齐。
3. **分段栏滑块「只整数跳变、不跟手」根因**：`SharedSlide.selectedOffset()` 数学上已支持浮点索引，但只有 `onChange`（吸附动画开始）驱动整数索引切换，拖动过程无人喂浮点 → 滑块完全不动直到松手。

## 2 条关键决策
1. **一镜到底修复方案**：截图按节点实测宽渲染（起终两端像素对齐）+ 截图自带圆角并随转场从卡片圆角过渡到媒体圆角；每日一帖卡堆恢复 `DAILY_DECK_MEDIA_RATIO`(4:3)。仅 3 个页面（HomeTab/ProfilePage/MessagePage）接 Swiper 回调，其余无 Swiper 的分段栏不动。
2. **检索通道级不可用 → 降级交付决策**：同一检索工具连续失败 2~3 次且错误一致即判定通道不可用，停止重试；基于领域知识产出分析，但必须显式声明证据受限、对每个不确定事实标 `[待核实]` 并汇总核实清单——「宁可标注不确定，也不要把推断写成结论」。

## 1 个可复用模式 / 检查项
**「功能消失」排查顺序（别盲目 checkout）**：
```
git status --short                # deletions >> insertions 即警报
git log --oneline -25             # HEAD 是否全仓库最新
git worktree list                 # 是否有第二份检出
blob=$(git hash-object <file>)
git log --all --find-object=$blob # 能在提交查到 = 旧版覆盖 → checkout HEAD 还原；任何提交都查不到 = 会话原生改动 → 别动
```
任何 agent 会话结束后跑 `node scripts/git-doctor.mjs --prune` 清理陈旧 worktree。
