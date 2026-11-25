---
title: "2026-10-05-arkui-child-local-mutation-parent-sync-contract.md"
id: markdown_798285c88467638f6a8dc28635ad6f33_d41b73a6f8c4426ce8903c6b3a7373c77505655250320770
kb: 有据-YouJu
folder: "问题记录"
media_type: 7
tags: []
source: ima
exported_at: 2026-11-23T14:52:37.917Z
---
---
id: 2026-10-05-arkui-child-local-mutation-parent-sync-contract
title: 子组件本地变更必须回传父级：@Prop 拷贝语义下的单一数据源与乐观计数校准契约
category: architecture
nature: technique
created_at: 2026-10-05T19:35:55
updated_at: 2026-10-06T00:00:55
tags: [arkui, prop-semantics, parent-child-state, single-source-of-truth, optimistic-update, state-consistency]
keywords: [@Prop 拷贝, 子组件删除, 回调链, onDeleted, 单一数据源, 已删项复活, 计数不一致, 乐观扣减, 服务器校准, CommentList, DetailCommentsSection, 父子状态同步契约]
problem_patterns: [child-local-mutation-not-propagated-to-parent, deleted-item-revives-after-parent-reload, count-drifts-from-child-list-length]
source_sessions: [ses_ef42c10b8ffe3XXihs1HCHY8Ti]
project: HarmonyProject1
severity: high
quality_score: 86
hit_count: 0
last_hit_at: null

low_quality_hit_count: 0
tier: S
related_experiences: [2026-10-05-arkui-state-nested-property-update-no-rerender, 2026-09-16-arkui-state-variable-ui-render-gap]
---

# 子组件本地变更必须回传父级：@Prop 拷贝语义下的单一数据源与乐观计数校准契约

## Scenario

列表/评论类子组件通过 `@Prop data: T[]` 接收数据，并在组件内直接对数组做结构性变更（splice/移除）后调用删除 API。删除在当前视图内看起来正确，但：

- 父级仍持有旧的完整数组与计数；
- 父级一旦重新订阅、重渲染或用旧数据重灌，**已删项"复活"**；
- 父级展示的计数（评论数/条数）与子组件实际列表长度脱节。

这是一个需要在设计阶段就拍定的**数据所有权与一致性契约**问题，而不是单个删除接口的实现细节。

## Key Signals

1. 子组件里删除后当前视图正确，但返回列表或父级重新加载后又出现该条。
2. 父级展示的总数/计数不随子组件删除变化。
3. 同一份数据同时存在于父级 `@State` 和子组件 `@Prop` 副本中，且没有写回通道。
4. 中间还隔了一层容器组件（如 CommentList → DetailCommentsSection → PostDetailView），回调链容易在某层被吞掉。

## Essence

`@Prop` 是**单向值拷贝**：子组件对 `@Prop` 数组的修改只作用于本地副本，**不会回写父级**。因此父子之间必须显式约定数据所有权。

核心张力（这也是选型点）：

| 方案 | 机制 | 优点 | 代价 / 风险 |
|------|------|------|-------------|
| A. `@Prop` 单向 + 回调上报 | 子组件变更后调 `onXxx` 交父级写权威数据 | 数据流显式、可预测；父级是单一数据源 | 需要逐层透传回调，链路长；忘记接线就静默失效 |
| B. `@Link` / `@ObjectLink` 双向绑定 | 子组件直接改绑定变量，父级自动可见 | 无需回调、代码短 | 双向绑定使数据流隐式、难追踪；且 ArkUI 中 `@Link` 组件的交互回调本身可能不可靠 |

本项目选择 **A**：父级持有权威数据（单一数据源），子组件只读展示、通过回调上报变更。理由是删除是低频写操作，显式回调链换来可预测的数据流与可测试性；而方案 B 在此项目已多次暴露「回调不可靠 / 刷新不稳」的坑。

另一个必须明确的约定是**计数的乐观策略**：UI 侧按「本次 UI 树中移除的条数」扣减（一级项连带其可见子项），服务端按「实际删除条数」扣减。两者可能因不可见层级（孙级回复、被隐藏项）而出现差额，该差额由下一次 `load()` 以服务器数据为准校准——即"乐观扣减 + 最终一致"。

## Approach

1. **确定单一数据源**：父级持有权威 `@State data` 与 `@State count`；子组件不持久化自己的副本、不假设本地变更已生效。
2. **子组件定义变更回调**：如 `onDeleted: (item: T) => void`，在删除 API 成功后调用，附带足够定位的信息（id 等）。
3. **逐层透传**：中间容器组件原样转发（`onDeletedComment` → 父级 `onCommentDeleted`），避免任何一层吞掉回调。
4. **父级 handler**：基于服务器行为构造新数组，移除目标（及其在 UI 树中的可见子项），同步计数，并**用顶层 `@State` 替换**触发刷新（见关联经验：嵌套属性直接赋值不保证跨组件刷新）。
5. **写回 + 快照双保险**：既写回权威对象以防父级重渲染旧数据，又更新独立 `@State count` 快照以可靠刷新展示。
6. **服务器兜底校准**：在 `load()` 中以接口返回值覆盖本地乐观计数，消除差额。
7. **验证两条路径**：删除即时生效（不复活）＋ 重新加载后计数与列表一致。

## Faster Next Time

- **Checklist**：任何在子组件内修改 `@Prop` 集合的写操作（删除/新增/排序），都必须有配套回调把变更上报父级——没有回调就是缺陷。
- **早期信号**：父级展示的「总数/计数」与子组件列表长度不一致 → 几乎必然是缺回传或计数未同步。
- **静态排查**：`grep` 子组件是否只有 `@Prop data` 而缺少对应 `onXxx` 回调；`grep -n 'onDeleted\|onDeletedComment'` 确认回调链从子到父是否完整、中间层是否透传。
- **多入口警告**：同一删除逻辑出现在多个容器路径（Tab、详情、通知跳转）时，回调链要逐层装配完整，任何一条路径漏接都会复现"复活/计数漂移"。
- **口径统一**：UI 乐观扣减与服务端扣减口径不同时，必须显式登记"由 load() 校准"，避免长期漂移无人负责。

## Applicability Boundaries

- **适用**：ArkUI 中通过 `@Prop` 单向传值、且父级需要保持权威副本（尤其是计数与列表需一致）的场景。
- **不适用 / 需重新评估**：父级通过 `@Link` / `@ObjectLink` 双向绑定把整个状态交给子组件时，子组件变更可直达父级，理论上无需回调；但要注意 ArkUI `@Link` 组件的交互回调存在不触发的情况，此时应改用 `@Watch` 监听绑定变量（见相关经验），而非依赖回调。
- **不适用**：一次性、无父级复用的纯展示组件，本地变更无需回传。
- **触发重新评估的条件**：删除变为服务端批量/级联语义、或需要多端实时同步时，乐观扣减模型需改为以服务器推送/重新拉取为主。

## Evidence or Examples

HarmonyProject1，「删除帖子评论后评论数不更新」：

- 链路（修复后）：`CommentList.onDeleteComment` → `onDeleted(c)` → `DetailCommentsSection.onDeletedComment` → `PostDetailView.onCommentDeleted`。
- 修复前缺 `onDeleted` 回调（`CommentList` 只 splice 自己的 `@Prop` 拷贝），父级 `post.comments` / `commentCount` 不同步，导致计数不减、父级重灌旧数据时已删行可能复活。
- 关键注释（`CommentList.ets:29`）：「本组件只 splice 自己的 @Prop 拷贝，父级（详情页）需同步 post.comments 与 commentCount，否则计数不减、父级重灌旧数据时已删行复活」。
- 计数口径（`PostDetailView.ets:1274`）：「计数按「本次 UI 树中移除的条数」扣减：一级评论连带其可见 replies；服务端按实际删除条数扣减，差额（不可见的孙级/被隐藏回复）由下次 load() 以服务器为准校准」。
- 配套修复：新增独立 `@State commentCount` 快照做顶层替换刷新；`hvigorw assembleHap` BUILD SUCCESSFUL。

> 注：本条与 `2026-10-05-arkui-state-nested-property-update-no-rerender` 同源于一个 bug，但结论分工不同——本条解决「数据所有权与父子同步契约（为什么需要回调链）」，关联条目解决「状态刷新机制（为什么必须顶层替换）」。使用时按命中的问题侧重分别取用。
