# 实现计划：结构化帖子「可核验阅读」

> 依据：docs/superpowers/specs/2026-11-05-structured-post-verifiable-reading-design.md（已批准）
> 范围：纯前端展示层 + 编辑器 metric 入口移除。后端零改动。

## T1 体裁白名单去 metric
- 文件：`entry/src/main/ets/utils/structuredDocument.ets`
- 改动：`structuredBlockTypesForGenre` review → `['insight','compare','list']`；debate → `['compare','insight']`
- 验证：编译通过；编辑器 review/debate 不再出现「+ 数字」入口

## T2 骨架重做（去数字块）
- 文件：`entry/src/main/ets/utils/structuredTemplates.ets`
- 改动：`review_score` = insight(一句话结论/primary) + compare(优点/缺点) + list(适合谁)；`debate_side` = compare(正反对照/primary) + insight(我的立场)；文案同步
- 验证：发布页选骨架后无 metric 块

## T3 编辑器移除 metric 入口
- 文件：`entry/src/main/ets/components/StructuredComposer.ets`
- 改动：删 `METRIC_KIND_OPTIONS`/`metricKindChips`/blockFields 的 metric 分支；为存量 metric 块保留 value+unit 最小编辑分支（无 kind chips）；清理失效 import
- 验证：新建帖无「+ 数字」；编辑存量 metric 帖不崩、可改值

## T4 StructuredFlowView 槽位化重写（核心）
- 文件：`entry/src/main/ets/components/StructuredFlowView.ets`
- 改动：blockCard 卡片制 → 槽位分派（verdict/compare/list/steps/duel/generic），零卡片、hairline 分隔、证据「据 N ↗」+ 验货层标题改「验一验」；新增可选 props（planAVotes/planBVotes/myVote/onVote/debateInteractive）；清单 chips 接 `openSearch`（utils/nav.ts:94）；保留 stepCheckStore 打卡与 evidenceSheet 结构；删 surfaceColor/块卡/块标题三件套/helper 渲染
- 验证：四体裁真机截图对照规格 mockup；预览页（PublishPreviewPage:599）静态渲染不出投票行/打卡进度

## T5 DetailPostContent 装配调整
- 文件：`entry/src/main/ets/components/DetailPostContent.ets`
- 改动：`hasStructuredFlow()` 判定复用；V2 辩论帖投 Wiring：透传票数 @State 与 onVote；`debatePanel` 收窄为仅 V1（无 V2 流）渲染；`debateValue` 为 V1 保留
- 验证：V2 辩论帖方案文案只出现一次、投票即时反映；V1 辩论帖投票面板不变

## T6 构建与提交门禁
- assembleHap 成功（DEVECO_SDK_HOME + 提权沙箱，worktree 缺 oh_modules 时从主仓拷）
- 后端 jest 全绿（零改动确认）
- git commit + push origin HEAD:main；worktree 会话收尾不清理（用户仍在会话中）

## 明确不做（防蔓延）
榜单/可信存疑/清单收藏/海报判词卡（规格二期记账）；V1 字段路径改造；后端任何文件。
