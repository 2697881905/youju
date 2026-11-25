---
title: "Docs · TECH_STACK.md"
id: markdown_cls1_798285c88467638f6a8dc28635ad6f33_3eef0a570a3ef2ce27a3a35f1823965c7526104239726721
kb: 有径-YouJing
folder: "开发文档"
media_type: 7
tags: []
source: ima
exported_at: 2026-11-23T14:52:37.917Z
---
# TECH_STACK.md · 有径技术栈锁定与依赖基线

> P2 产出。本文件是工具链版本与依赖变更的单一事实源：升级任何依赖或工具链前，先更新本文件并追加变更记录，再改配置。

## 1. 版本锁定表

| 条目 | 当前值 | 来源文件 |
|---|---|---|
| targetSdkVersion | 26.0.0 | `build-profile.json5` → products[default] |
| compatibleSdkVersion | 26.0.0 | `build-profile.json5` → products[default] |
| runtimeOS | HarmonyOS | `build-profile.json5` → products[default] |
| 工程 modelVersion | 26.0.0 | `oh-package.json5`（根） |
| hvigor modelVersion | 26.0.0 | `hvigor/hvigor-config.json5` |
| hvigor / hvigor-ohos-plugin | 6.26.8 | DevEco Studio 内置 `Contents/tools/hvigor/` |
| DevEco Studio | 26.0.0.851（build 261.23567.138.36.2600851） | `/Applications/DevEco-Studio.app/Contents/Resources/product-info.json` |
| DevEco 安装路径 | /Applications/DevEco-Studio.app | 本机实测 |
| DevEco 内置 Node | v24.14.1 | `Contents/tools/node` |
| ohpm | 26.0.0.630 | `Contents/tools/ohpm`（`ohpm -v` 实测） |
| HarmonyOS SDK | API 26 / 26.0.0.105（Release） | `Contents/sdk/default/sdk-pkg.json` |
| DEVECO_SDK_HOME | /Applications/DevEco-Studio.app/Contents/sdk | 本机构建实测（hvigor 直跑必需） |
| bundleName | com.youjing.app（2026-10-15 定稿，参考有据 com.youju.app 命名） | `AppScope/app.json5` |
| versionName / versionCode | 1.0.0 / 1000000 | `AppScope/app.json5` |
| 签名配置 | 无（signingConfigs 为空） | `build-profile.json5` |
| 运行时依赖 dependencies | 空 | 根与 `entry/oh-package.json5` |
| 开发依赖 devDependencies | @ohos/hypium 1.0.25、@ohos/hamock 1.0.0 | `oh-package.json5`（根） |
| lockfileVersion | 3（与 oh-package.json5 一致，`ohpm install --all` 后零 diff） | `oh-package-lock.json5` |

> **API 等级决策**：《有径·App开发文档》§2.3 未声明 API 等级，以工程实际配置 **26.0.0（API 26）** 为准。compatibleSdkVersion 同为 26.0.0，意味着不向低版本设备兼容，最低兼容范围评审列入 INIT_REPORT 待办（P7）。

## 2. 依赖管理策略

1. **运行时依赖默认为零**：功能一律用系统 API（@kit 系列）实现，不引入三方运行时包。
2. **新增依赖须四项评估**：用途 / license / 维护状态 / 替代方案，登记到本文件「变更记录」并经确认后才可安装，不得先斩后奏。
3. **版本号精确锁定**：一律写精确版本（如 `1.0.25`），禁止 `^` 与 `~` 前缀。
4. **升级先登记后动手**：升级任何依赖前，先更新本文件版本表并追加变更记录，再修改 oh-package.json5。

## 3. 变更记录

| 日期 | 内容 | 理由 |
|---|---|---|
| （暂无） | | |
