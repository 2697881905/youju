---
title: "harmony-learning-2026-10-03.md"
id: markdown_798285c88467638f6a8dc28635ad6f33_fe0ed108a722ff4b28fa58b9034ee9c47505655250320770
kb: 有据-YouJu
folder: "决策记录"
media_type: 7
tags: []
source: ima
exported_at: 2026-11-23T14:52:37.917Z
---
# 增量学习 · 2026-10-03（有据同步自动化）

来源：本次新处理 2 篇开发文档
- `.trae/documents/home-search-entry-title-bar-immersive.md`（首页搜索入口迁入 Navigation 标题栏，沉浸光感正式落地）
- `docs/immersive-light-integration.md`（沉浸光感 Immersive Light 接入实践与踩坑记录）

## 3 条项目事实
1. `systemMaterial`（uiMaterial 轨，通用属性）**只在 Navigation/NavDestination 标题栏或系统底部 TabBar 生效**，内容区设置完全不渲染、且不报错不警告（官方 FAQ「组件不在沉浸光感生效范围」）。这是「有據」接入沉浸光感的决定性架构约束——位置不对就先别调样式。
2. 工程 `compatibleSdkVersion=6.0.0(20)`，但 `systemMaterial` 是 `@since 26.0.0` 的 API。低版本设备必须用 `AttributeModifier.applyNormalAttribute` 内 `deviceInfo.apiAvailable('26.0.0')` **字面量 if** 门禁保护，否则运行期崩溃；ets-loader 编译期把 `apiAvailable` 降级为 `__mockApiAvailable`（纯本地版本比较，不发起新 API 调用），低版本天然安全。
3. 首页(0)/我的(4) 的整块顶栏（品牌块 + 搜索按钮 + 分段栏 + 圈子 chip）已整体迁入 Navigation 标题栏（`BarStyle.STANDARD` 占位 + 画布底色）；材质生效时必须撤掉自绘兜底（`backgroundBlurStyle` / `backdropBlur` / 自绘 `shadow`），否则遮挡或叠加。顶栏相关状态上移到 `Index`，子页面用 `@Link` 共用。

## 2 条关键决策
1. 顶栏统一迁入 Navigation 标题栏、采用 `BarStyle.STANDARD` 占位（内容从栏下开始，观感与原头部一致）；仅首页(0)/我的(4) 显示，其它 Tab 动态 `hideTitleBar` 隐藏，从根上规避 STACK 悬浮层对顶部交互（分段栏/头像/设置入口）的触摸拦截。
2. 材质档位场景化（顶部悬浮 `ULTRA_THIN` / 底部 `THIN` / 弹出 `THICK` / 半模态 `ULTRA_THICK`），且**大面积承载正文的浮层不适合 `outlined` 描边规格**（只剩 ~1.1:1 描边，对比不足）——`outlined` 只适用于小面积控件级。

## 1 个可复用模式 / 检查项
**「新增一处沉浸光感」自查清单**（接入前逐条核对，见 `docs/immersive-light-integration.md` §7）：
- 控件是否在 Navigation/NavDestination 标题栏（或底部 TabBar）？不在就先迁移或放弃材质。
- 材质调用是否包在 `applyNormalAttribute` 的 `apiAvailable('26.0.0')` **字面量 if** 门禁内（变量传参/三元/逻辑复合都不受保护）？
- 档位是否按场景选对（ULTRA_THIN/THIN/THICK/ULTRA_THICK）？
- 原 `backgroundBlurStyle` / `backdropBlur` 是否在材质生效时关掉（否则遮挡）？
- 原 `shadow` 是否归零（否则与材质阴影叠加）？
- 低版本（API < 26）视觉是否与改造前完全一致？
- 栏高是否精确等于内容？**状态栏避让是否只有一处**（STANDARD 栏高已含状态栏，内容区不能再补 `statusBarHeight`）？
- 需向下溢出的浮层（如圈子下拉）是否已拆到内容区渲染（标题栏触摸只命中父节点区域内子节点）？
- 构建产物里 `apiAvailable` 是否被降级为 `__mockApiAvailable`？
- 真机上是否随系统「沉浸光感」强度档位联动？
