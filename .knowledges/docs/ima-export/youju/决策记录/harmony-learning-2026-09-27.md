---
title: "harmony-learning-2026-09-27.md"
id: markdown_798285c88467638f6a8dc28635ad6f33_e97d9b57fd100d81276852126d3825797505655250320770
kb: 有据-YouJu
folder: "决策记录"
media_type: 7
tags: []
source: ima
exported_at: 2026-11-23T14:52:37.917Z
---
# 增量学习摘要 · 2026-09-27（有据文档同步自动化）

> 本次新处理文档来源：`.codeartsdoer/experience-reuse/experiences/` 下 3 篇 2026-09-26 新增经验笔记。
> 另有 3 篇 2026-09-16 笔记被迁移至 `.archived/` 子目录（内容已在历史运行沉淀，本次仅作重定位，不重复提炼）。
> 8 篇既有经验笔记内容演进（hash 变更），属历史知识库维护，不重复提炼。

## 3 条项目事实

1. 有据已接入 HarmonyOS 6 智感握姿（smart-reachability），按握持手方向自适应 UI 布局（标题/操作栏居左或居右）。接入层位于 `entry/src/main/ets/utils/gripAwareness.ets`，采用「接入层 → 消费层 → 组件层」三层分离架构。
2. 智感握姿依赖 `@ohos.multimodalAwareness.motion` 的 `holdingHandChanged`（@since 20）与 `operatingHandChanged`（@since 15）；需声明权限 `ohos.permission.DETECT_GESTURE`；`compatibleSdkVersion` 必须 ≥ 6.0.0(20) 才能使用握持手信号。
3. 一镜到底转场经实测回退确认：页面间转场（router push/pop）只能用 `sharedTransition`；`geometryTransition`（需配合 `animateTo`）仅适用于同一页面内组件切换，误替换会导致转场动画完全消失。

## 2 条关键决策

1. **系统信号消费三层分离**：接入层（util，负责订阅/退订/能力探测/降级/AppStorage 原始桥接）→ 消费层（页面 @Component，派生布局标记并 `animateTo` 驱动）→ 组件层（`@StorageProp` 响应式对齐切换）。`animateTo` 必须在拥有 `UIContext` 的 `@Component` 上下文调用，util 无 `UIContext` 无法驱动动画。
2. **共享元素转场坚持 `sharedTransition`**：其图片拉伸问题通过 hero 占位比例一致 + `holdHero` 机制 + 曲线/时长调优解决，不替换为 `geometryTransition`。

## 1 个可复用模式 / 检查项

- **系统信号 / 布局过渡降级链检查清单**：接入 `MultimodalAwareness` 等系统信号时，四路降级（`canIUse`=false、`motion.on` 抛 801 设备不支持、抛 201 权限拒绝、系统开关关闭）必须各自收敛到默认布局；`NOT_HELD`/`BOTH_HANDS` 不写入 AppStorage 以保留上次布局；页面级 `aboutToAppear` 订阅 / `aboutToDisappear` 退订；派生布局值须在 `animateTo` 闭包内写入 AppStorage 才能平滑过渡。

## 关联产出
- 新建 SKILL 草稿：`/Users/itxiaobai/HarmonyProject1/.workbuddy/skills/arkui-shared-element-transition/SKILL.md`（sharedTransition vs geometryTransition 决策 + 一镜到底优化）。
- 本摘要备份至 IMA「有据-YouJu / 决策记录」。
