---
title: "2026-09-15-harmonyos-permission-reason-field.md"
id: markdown_798285c88467638f6a8dc28635ad6f33_01a2ba15730ce7ea001d03459ae54c057505655250320770
kb: 有据-YouJu
folder: "问题记录"
media_type: 7
tags: []
source: ima
exported_at: 2026-11-23T14:52:37.917Z
---
---
id: 2026-09-15-harmonyos-permission-reason-field
title: HarmonyOS module.json5 权限声明必须包含 reason 字段以通过 AGC 审核
category: build-env
nature: pitfall
created_at: 2026-09-15T23:37:17
updated_at: 2026-09-15T23:37:17
tags: [权限声明, AGC审核, module.json5, requestPermissions, reason字段]
keywords: [requestPermissions, reason, usedScene, ohos.permission.INTERNET, module.json5, AGC审核, 权限说明, string.json, HarmonyOS权限配置]
problem_patterns: [AGC审核被拒-权限缺少reason, 权限声明不完整]
source_sessions: [ses_f5a62de61ffesSrzC0fSfoi5u7]
project: HarmonyProject1
severity: high
quality_score: 84
hit_count: 0
last_hit_at: null
low_quality_hit_count: 0
tier: A
related_experiences: [2026-09-15-agc-review-config-checklist]
---

# HarmonyOS module.json5 权限声明必须包含 reason 字段以通过 AGC 审核

## Scenario

在 HarmonyOS 应用的 `module.json5` 中声明 `requestPermissions` 时，如果权限条目仅包含 `name` 字段而缺少 `reason` 字段，AGC 审核将大概率拒绝该应用上架。这是 AGC 审核最常见的配置阻断项之一。

## Key Signals

- `module.json5` 中 `requestPermissions` 配置如下（缺少 reason）：
  ```json5
  "requestPermissions": [
    { "name": "ohos.permission.INTERNET" }
  ]
  ```
- AGC 审核反馈：权限声明缺少使用说明
- `string.json` 中没有对应的权限说明字符串定义

## Essence

AGC 审核要求**每个声明的权限必须提供 `reason` 字段说明用途**，且 `reason` 值必须引用 `$string:xxx` 资源（不能直接写字符串字面量）。同时建议添加 `usedScene` 字段标明使用场景。缺少 `reason` 是审核高频阻断项。

## Approach

### 修复步骤

1. 在 `module.json5` 的 `requestPermissions` 中为每个权限添加 `reason` 和 `usedScene`：
   ```json5
   "requestPermissions": [
     {
       "name": "ohos.permission.INTERNET",
       "reason": "$string:permission_internet_reason",
       "usedScene": ["ability"]
     }
   ]
   ```

2. 在 `entry/src/main/resources/base/element/string.json` 中添加对应的字符串定义：
   ```json
   {
     "name": "permission_internet_reason",
     "value": "用于网络通信以获取服务数据"
   }
   ```

3. 如果应用支持多语言，在对应语言的 `string.json` 中也添加翻译版本

### 验证方法

- 检查 `module.json5` 中每个 `requestPermissions` 条目是否都包含 `reason` 字段
- 检查 `reason` 引用的 `$string:xxx` 是否在 `string.json` 中有对应定义
- 构建应用确认无资源引用错误

## Faster Next Time

- **编写权限声明时同步添加 reason**：不要先写 `requestPermissions` 再事后补 reason，应在添加权限的同时编写 reason 字符串
- **reason 字符串命名规范**：使用 `permission_<权限名简写>_reason` 命名，如 `permission_internet_reason`、`permission_camera_reason`
- **reason 内容要求**：简明说明权限用途，如"用于网络通信以获取服务数据"，避免笼统描述

## Applicability Boundaries

- **适用**：所有 HarmonyOS 应用（API 20+）提交 AGC 审核前的权限声明配置
- **适用**：所有 `requestPermissions` 中声明的系统权限
- **不适用**：`extensionAbilities` 内部的权限配置（遵循不同规则）
- **版本约束**：HarmonyOS NEXT（API 20+），Stage 模型

## Evidence or Examples

项目 HarmonyProject1 中发现的问题：

原始配置（`entry/src/main/module.json5`）：
```json5
"requestPermissions": [
  { "name": "ohos.permission.INTERNET" }
]
```

修复后配置：
```json5
"requestPermissions": [
  {
    "name": "ohos.permission.INTERNET",
    "reason": "$string:permission_internet_reason",
    "usedScene": ["ability"]
  }
]
```

需在 `string.json` 中添加：
```json
{ "name": "permission_internet_reason", "value": "用于网络通信以获取服务数据" }
```
