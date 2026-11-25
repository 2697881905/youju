---
title: "2026-09-15-agc-review-config-checklist_261014112658.md"
id: markdown_cls1_798285c88467638f6a8dc28635ad6f33_f459d8cfc601ab52eb94cb0b4c1a3e1a7505655250320770
kb: 有据-YouJu
folder: "问题记录"
media_type: 7
tags: []
source: ima
exported_at: 2026-11-23T14:52:37.917Z
---
---
id: 2026-09-15-agc-review-config-checklist
title: HarmonyOS 应用 AGC 审核前配置文件完整性检查清单
category: workflow
nature: methodology
created_at: 2026-09-15T23:37:17
updated_at: 2026-09-15T23:43:13
tags: [AGC审核, 配置文件检查, HarmonyOS发布, 审核阻断项, 上架前检查]
keywords: [AGC, 审核配置, module.json5, app.json5, build-profile.json5, requestPermissions, reason字段, signingConfig, 隐私政策, 用户协议, AGC审核阻断, HarmonyOS上架]
problem_patterns: [AGC审核被拒, 配置文件不完整, 权限声明缺失reason, 签名配置错误]
source_sessions: [ses_f5a62de61ffesSrzC0fSfoi5u7]
project: HarmonyProject1
severity: high
quality_score: 86
hit_count: 11
last_hit_at: 2026-10-09T01:22:42
low_quality_hit_count: 0
tier: S
related_experiences: [2026-09-15-arkts-strict-mode-constraints, 2026-09-15-harmonyos-permission-reason-field]
---

# HarmonyOS 应用 AGC 审核前配置文件完整性检查清单

## Scenario

HarmonyOS 应用提交 AGC（AppGallery Connect）审核前，需要对所有配置文件进行完整性审查。AGC 审核有严格的配置要求，常见阻断项包括权限声明不完整、签名配置错误、隐私政策缺失等。若在审核提交后才发现问题，需要反复修改重新提交，周期长、成本高。

## Key Signals

审核被拒的常见信号：
- `requestPermissions` 中权限缺少 `reason` 字段 → AGC 要求每个权限必须说明用途
- `default` product 使用 `debug` 签名 → 发布版本签名不正确
- 隐私政策与用户协议日期不一致 → 审核可能要求文档同步更新
- `vendor` 字段与运营主体不一致 → 审核核对主体一致性
- 缺少隐私政策/用户协议页面 → AGC 审核必需文件
- `startWindowIcon` 使用全透明图 → 审核可能对"冷启动无图标"提出疑问

## Essence

AGC 审核的核心要求是：**每个权限有理由、每个签名配置正确、合规文档齐全且一致**。配置文件审查应按优先级分层进行：先修复审核阻断项（P0），再处理提升通过率项（P1），最后处理信息性提示（P2）。

## Approach

### 1. module.json5 检查（最高优先级）

- [ ] `requestPermissions` 中每个权限是否包含 `reason` 字段（引用 `$string:xxx`）
- [ ] `requestPermissions` 中每个权限是否包含 `usedScene` 字段（如 `["ability"]`）
- [ ] `abilities` 配置是否完整（name、srcEntry、icon、label、startWindowIcon、startWindowBackground、exported、skills）
- [ ] `extensionAbilities` 配置是否完整（backup 类型需 metadata 指向 backup_config）
- [ ] `metadata` 中 `client_id` 是否与 agconnect-services.json 中的 `app_id` 一致
- [ ] `deviceTypes` 是否覆盖目标设备形态

### 2. app.json5 检查

- [ ] `bundleName` 是否与 agconnect-services.json 中 `package_name` 一致
- [ ] `versionCode` 和 `versionName` 是否正确
- [ ] `vendor` 字段是否与隐私政策中运营主体一致
- [ ] 是否声明 `minAPIVersion`（推荐与 compatibleSdkVersion 对应）

### 3. build-profile.json5 检查

- [ ] `default` product 的 `signingConfig` 是否使用 `release`（而非 `debug`）
- [ ] `compatibleSdkVersion` 在 debug 和 release product 中是否一致（或确认差异有意）
- [ ] `targetSdkVersion` 是否设置正确
- [ ] 签名材料路径是否有效（certpath、keyAlias、profile、storeFile）

### 4. AGC 合规文件检查

- [ ] `agconnect-services.json` 是否存在于 `rawfile/` 目录
- [ ] `agconnect-services.json` 中 `app_id` 与 module.json5 metadata `client_id` 是否一致
- [ ] `agconnect-services.json` 中 `package_name` 与 app.json5 `bundleName` 是否一致
- [ ] 隐私政策页面是否存在且内容完整（信息收集、使用、存储、第三方SDK、未成年人保护、联系方式）
- [ ] 用户协议页面是否存在且内容完整
- [ ] 关于页面是否包含 ICP 备案信息
- [ ] 隐私政策与用户协议的更新日期是否一致或接近
- [ ] 第三方 SDK 使用是否已在 AGC 平台报备

### 5. 资源文件检查

- [ ] `string.json` 中是否定义了所有 `reason` 字段引用的权限说明字符串
- [ ] `color.json` 中 `start_window_background` 是否定义（base 和 dark 模式）
- [ ] `main_pages.json` 中是否注册了隐私政策、用户协议、关于页面路由
- [ ] `layered_image.json` 引用的 background.png 和 foreground.png 是否存在
- [ ] `float.json` 中字体尺寸和间距是否完整

## Faster Next Time

- **权限 reason 字段是最常见的 AGC 审核阻断项**：在编写 `requestPermissions` 时同步添加 `reason` 和 `usedScene`，并在 `string.json` 中定义对应字符串，避免事后补漏
- **签名配置检查顺序**：先看 `default` product 的 `signingConfig` 值，再验证签名材料文件是否存在
- **一致性检查捷径**：对比 `agconnect-services.json` 的 `app_id`/`package_name` 与 `module.json5`/`app.json5` 的对应字段，一处不一致即可定位配置错误
- **合规文档日期同步**：更新隐私政策时同步更新用户协议日期，避免审核时被指出不一致

## Applicability Boundaries

- **适用**：HarmonyOS NEXT（API 20+）应用提交 AGC 审核前的配置文件审查
- **适用**：元服务（Atomic Service）提交审核前的配置检查（需额外检查元服务特有配置）
- **不适用**：非 HarmonyOS 平台的应用审核
- **不适用**：已通过审核的应用的日常配置维护（除非有重大版本更新）

## Evidence or Examples

项目 HarmonyProject1（bundleName: com.youju.app）的审查实例：

**P0 阻断项**：
- `module.json5` 中 `ohos.permission.INTERNET` 缺少 `reason` 字段 → 需添加 `"reason": "$string:permission_internet_reason"` 并在 `string.json` 中定义
- `string.json` 缺少 `permission_internet_reason` 字符串定义

**P1 建议修复**：
- `default` product 使用 `signingConfig: "debug"` → 应改为 `"release"`
- `app.json5` 缺少 `minAPIVersion` 字段
- 隐私政策日期（2026-09-11）与用户协议日期（2026-08-14）不一致

**配置一致性验证通过**：
- `agconnect-services.json` 的 `app_id: 6917613566723435312` 与 `module.json5` metadata `client_id` 一致
- `agconnect-services.json` 的 `package_name: com.youju.app` 与 `app.json5` `bundleName` 一致
- 深浅色模式 `color.json` 各 47 个颜色定义一一对应
