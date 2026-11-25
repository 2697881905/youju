---
title: "harmony-learning-2026-10-06.md"
id: markdown_798285c88467638f6a8dc28635ad6f33_6ea692ee348a428b18f75db6fc05e6ef7505655250320770
kb: 有据-YouJu
folder: "决策记录"
media_type: 7
tags: []
source: ima
exported_at: 2026-11-23T14:52:37.917Z
---
# 有据文档同步 · 增量学习 2026-10-06

> 来源：本对账批次新处理文档 = 23 篇新增（2026-10-04~05 经验/反思）+ 8 篇变更（经验库演进）。
> 提取：3 事实 / 2 决策 / 1 模式。SKILL 草稿判定见文末。

## 3 事实（Facts）

1. **华为商标合规红线已明确**：应用内使用华为 Logo / 品牌标识 / "HUAWEI" 文字需书面授权，默认用自定义抽象图标替代（`2026-10-05-huawei-trademark-compliance-brand-logo.md` + `2026-10-05-huawei-trademark-compliance-restriction.md` 两篇决策级经验）。这是上架审核的前置约束，不是可选项。
2. **跨平台兼容判断需看系统级差异，而非指令集**：同指令集 ≠ 同平台；二进制转译 / 兼容层能否落地取决于系统 API、图形栈、二进制格式、生态四层差异，不能仅凭"都是 ARM"下结论（`2026-10-04-cross-platform-compat-translation-feasibility-framework.md`）。
3. **ArkUI 状态刷新边界有多处隐性坑**：① `@State` 对象嵌套属性赋值不触发跨组件刷新，须顶层替换或独立 `@State` 快照；② `@Link` 组件的 `onItemClicked` 回调不可靠，须用 `@Watch` 监听衍生状态；③ `Grid` 长按拖拽排序须双数组同序搬迁 + `reordering` 守卫，否则 `@Watch` 回调打乱顺序（`*-state-nested-property-update-no-rerender`、`*-link-component-callback-unreliable-watch-sync`、`*-grid-drag-reorder-watch-guard`）。

## 2 决策（Decisions）

1. **商标合规优先于视觉还原**：默认采用自定义抽象图标，不主动使用 HUAWEI 文字 / Logo / 品牌色，避免 AGC 上架审核风险；确需使用华为品牌资产时先走书面授权流程。
2. **组件选型与页面结构回归官方原生**：① 设置页从 `Scroll+Column+自定义卡片行` 迁移到官方 `List+ListItemGroup+ListItem`；② 自定义封装组件优先替换为官方原生组件（SegmentButton / TextInput 等），减少设计系统封装遮挡原生组件辨识的坑（`*-settings-list-itemgroup-migration`、`*-hmos-custom-to-native-component-replacement`、`*-arkui-wrapper-hides-native-component-identification`）。

## 1 模式（Pattern）

**状态所有权与稳定引用契约**：所有可变状态的写入都遵循"稳定引用 + 单向回传 + 分层隔离"三原则——
- 持久化资源存稳定 `mediaRef` 而非短时 `viewUrl`（`*-media-ref-vs-view-url-persistence-contract`）；
- 子组件 `@Prop` 拷贝语义下，本地变更必须回传父级（单一数据源 + 乐观计数校准）（`*-child-local-mutation-parent-sync-contract`）；
- 草稿编辑器分离三层状态：瞬时跨页态 / 持久化态 / 页面局部态，导航回写 `activeDraftId` 防重复草稿（`*-publish-draft-three-layer-state-architecture`、`*-save-draft-navigation-idempotent-upsert`）；
- 本机持久化列表用版本化信封 + 逐条校验 + 账号隔离（`*-local-persistent-list-versioned-envelope-validation`）。

## SKILL 草稿判定（保持减法）

- **华为商标合规（brand-logo + restriction 两篇）**：同主题在本次批次内复现，但属"合规政策"而非可复用工程技能；不新建 SKILL，记为本项目硬约束（已写入项目 MEMORY 合规红线）。
- **跨平台兼容转译框架（1 篇）**：单篇方法论，尚未复现，暂不成 SKILL。
- 既有 `arkui-runtime-pitfalls` / `arkui-shared-element-transition` 已覆盖 ArkUI 状态/转场类主题，本批次新增多项属其外延，不另起 SKILL。
- **结论：本批次不生成新 SKILL 草稿。**
