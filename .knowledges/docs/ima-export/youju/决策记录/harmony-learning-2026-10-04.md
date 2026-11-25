---
title: "harmony-learning-2026-10-04.md"
id: markdown_798285c88467638f6a8dc28635ad6f33_f7adde6e26fa5d177af15719311c6a867505655250320770
kb: 有据-YouJu
folder: "决策记录"
media_type: 7
tags: []
source: ima
exported_at: 2026-11-23T14:52:37.917Z
---
# 增量学习 · 2026-10-04

> 来源：本次新处理文档 `docs/tutorial-titlebar-immersive-light.md`（新增教程）、`docs/feature-index.md`（变更：新增「帖子详情底部栏配色微调」「登录态持久化」两节）。
> 同步目标：IMA「有据-YouJu」→ 开发文档文件夹。

## 3 条项目事实

1. **顶栏迁入标题栏 + 系统材质（uiMaterial 轨，API 26+）改造已全量落地**：首页 / 圈子 / 消息 / 我的（主 Navigation 按 Tab 分支）、搜索面板 / 圈子详情 / 帖子详情（组件自带 Navigation，router 壳与 NavDestination 壳共用一份实现）全部完成；`systemMaterial` 只在 Navigation/NavDestination 标题栏或系统底部 TabBar 生效，内容区设置完全不渲染（官方 FAQ 生效范围）。
2. **帖子详情底部互动栏（DetailActionBar）改用 GlassBlurStyle.Card 减薄一档 + GlowInput 默认配方**：底部栏不在 systemMaterial 生效范围，故未引入材质；`segmentStyle:true` 全项目仅此一处，切换零外溢；真机待验 Card 档在深色模式下是否压低输入文字对比度。
3. **登录态持久化已迁出 PersistentStorage**：改用 dataPreferences 独立文件 `youju_session`（应用级 preferences 目录），覆盖安装（`hdc install -r` / DevEco Run）冷启动 PersistentStorage 读不回旧文件 → 偶发首启黑屏挂死 + 任意一次持久化写入把默认值整份刷回磁盘 → token/用户信息被清空（「重装后账号必掉」）；Asset Store 同样被覆盖安装清空，无法兜底。

## 2 条关键决策

1. **底部互动栏不引入 systemMaterial**：位置既非标题栏也非系统 TabBar（官方 FAQ 生效范围），改成系统 TabBar / NavDestination toolbar 属产品结构重构且承载不了输入框 + 握姿换边 + 键盘联动，否决；改为 GlassBlurStyle.Card 减薄 + GlowInput 默认配方统一。包 `ImmersiveSurface` 加 HDS 双边流光的方案也明确否决（用户多次拍板去流光、底栏动态尺寸复杂收益低）。
2. **登录态持久化放弃 PersistentStorage，改用 dataPreferences 独立文件水合 AppStorage**：键名与旧 `persistent_storage` 的 `persistProp` 一致 → 消费方零改动；写入统一走 `saveSessionSnapshot()`（putSync + flushSync 即时落盘）；旧文件首启一次性迁移（token+userId 成对才迁）；token 仍异步双写 Asset Store 但不再参与冷启动恢复（覆盖安装会被系统清空）。

## 1 个可复用模式 / 检查项

- **沉浸光感改造完成自查清单（六维）可复用**：结构（顶栏边界 / 单容器根 / STANDARD 占位 / 无重复状态栏避让）→ 高度（栏高=状态栏+间距+内容、onAreaChange 回写 + 首帧估算、无"固定高度<padding"行）→ 状态（状态归属与 Builder 位置一致、交互接线清晰）→ 材质（全挂、生效时自绘模糊/边框/阴影让位、档位符合场景）→ 兼容（字面量 apiAvailable('26.0.0') 门禁在 AttributeModifier 内、低版本回退完好）→ 回归（真机各交互路径）。
- **新增检查项（覆盖安装账号丢失）**：真机报「重装后必掉登录」→ 优先怀疑 PersistentStorage / Asset Store 被覆盖安装清空，改用 dataPreferences 独立文件 + 首启迁移；勿在启动路径同步调用 Asset 同步 API（曾挂死）。
