---
title: "2026-10-05-huawei-trademark-compliance-restriction.md"
id: markdown_798285c88467638f6a8dc28635ad6f33_09d93ddd4ebf3b0fe7f78aa087c446497505655250320770
kb: 有据-YouJu
folder: "问题记录"
media_type: 7
tags: []
source: ima
exported_at: 2026-11-23T14:52:37.917Z
---
---
id: 2026-10-05-huawei-trademark-compliance-restriction
title: HarmonyOS 应用中不得未经授权使用华为注册商标（Logo/标识/品牌名称），默认用自定义抽象图标替代
category: workflow
nature: decision
created_at: 2026-10-05T02:21:06
updated_at: 2026-10-06T00:00:55
tags: [harmonyos, trademark, compliance, huawei-logo, brand-asset, legal, svg-resource, brand-logo, account-binding, descriptive-use]
keywords: [华为商标, 华为Logo, HUAWEI文字, 商标合规, 品牌标识, 注册商标, 未经授权, 书面同意, 商标侵权, 品牌资源, HarmonyOS应用, SVG图标, 描述性使用, 商标性使用, 抽象花瓣图标, 书面授权, account-binding, brand_huawei.svg, 开发者协议]
problem_patterns: [using-registered-trademark-without-authorization, brand-logo-in-app-resource, trademark-compliance-violation, trademark-vs-descriptive-use-confusion, brand-logo-without-permission]
source_sessions: [ses_ef8786fedffeXrLc6O8a1LQsV6, ses_ef7fd4afcffe9a3EzKi2x7Ozdn]
project: HarmonyProject1
severity: high
quality_score: 89
hit_count: 0
last_hit_at: null
low_quality_hit_count: 0
tier: S
related_experiences: [2026-10-05-huawei-trademark-compliance-brand-logo]
---

# HarmonyOS 应用中不得未经授权使用华为注册商标（Logo/标识/品牌名称）

## Scenario

在 HarmonyOS 应用开发中，需要在账号绑定页或其他 UI 中展示华为账号的品牌标识（如华为花瓣 Logo + "HUAWEI" 文字）。开发者可能认为在华为生态（HarmonyOS）内使用华为品牌标识是合理且被允许的，于是直接从设计稿或官方资源中提取真实华为 Logo SVG 并放入项目资源。

典型触发条件：
- 应用中有展示第三方/系统账号品牌标识的需求（如账号绑定页、登录方式选择）
- 设计稿、用户或设计师提供真实华为 Logo 文件（SVG/PNG），或要求"换成真实华为 Logo"
- 开发者处于华为生态内，直觉认为使用华为标识无合规风险
- 项目资源目录中已有 `brand_huawei.svg` 等品牌图标占位文件

## Key Signals

1. **华为品牌政策条款**：华为明确规定"未经华为事先书面同意，您不得以任何方式、任何目的使用华为的商标、标志、标识、LOGO、公司名称及本计划的名称等"
2. **直觉误判**：开发者身处华为生态（HarmonyOS SDK、DevEco Studio、AGC），容易认为使用华为 Logo 是被默许的，或认为"已上架华为应用市场""已使用 AccountKit"就自动获得品牌标识使用权——这是错误的
3. **用户纠正信号**：用户主动指出商标合规问题，要求回退已替换的真实 Logo
4. **已有占位资源**：项目中已存在自定义抽象图标（如花瓣形状的 SVG），说明此前已考虑过合规问题并选择了非注册商标图案
5. **反向信号**：如果应用只是展示"华为账号"绑定关系，不需要使用华为注册商标图案——用文字"华为账号"或抽象图标即可

## Essence

**核心规则**：在 HarmonyOS 应用中，未经华为事先书面同意，不得以任何方式、任何目的使用华为的商标、标志、标识、LOGO、公司名称。这包括但不限于：
- 华为花瓣 Logo（注册商标图案）
- "HUAWEI" 文字商标
- 华为公司名称

**关键约束**：身处华为生态（使用 HarmonyOS SDK、发布到华为应用市场）**不构成**使用华为商标的授权。华为生态的开发者协议与华为商标使用许可是两个独立的法律范畴。

**关键区分——商标性使用 vs 描述性使用**，这决定了是否需要授权：

| 使用方式 | 类型 | 是否需要授权 |
|----------|------|-------------|
| 华为花瓣 Logo SVG | 商标性使用 | 需书面授权 |
| "HUAWEI" 品牌字样 | 商标性使用 | 需书面授权 |
| 文字"华为账号" | 描述性使用 | 不需要 |
| 自定义抽象花瓣图标（非华为注册图案） | 非商标使用 | 不需要 |
| AccountKit SDK 内置的品牌资源 | SDK 授权使用 | 由 SDK 许可覆盖 |

**替代方案**：使用自定义抽象图标（非华为注册商标图案）来标识华为账号绑定项。例如：
- 自定义花瓣形状 SVG（8 片花瓣 45° 均匀分布 + 双色分组，造型与华为 Logo 不同）
- 通用账号图标 + "华为账号"文字标签
- 通过华为 AccountKit SDK 获取的合规品牌资源包（如有）

## Approach

### 步骤 1：审查应用中所有品牌标识资源

```bash
# 搜索项目中所有品牌相关资源文件
find entry/src/main/resources -name "brand_*" -o -name "*huawei*" -o -name "*logo*"
# 搜索代码中引用品牌资源的位置
grep -rn "brand_huawei\|brandIconRes\|brandTileTint\|huawei.*logo\|HUAWEI" entry/src/main/ets/
```

### 步骤 2：判断每个品牌资源是商标性使用还是描述性使用

对每个品牌资源文件检查：
- SVG/PNG 内容是否精确复刻了华为注册商标（花瓣 Logo + "HUAWEI" 文字）？→ 商标性使用，必须替换为非注册商标图案
- 是自定义抽象图标（造型与华为注册商标不同）？→ 可保留
- 只是"华为账号"文字描述？→ 描述性使用，不需要授权（是否合规仍需单独确认）

### 步骤 3：替换不合规的品牌资源

1. 删除或覆盖真实华为 Logo SVG 文件
2. 替换为自定义抽象图标（如花瓣形状但造型与华为注册商标不同）
3. 确保浅色/深色主题各有一份资源文件（`base/media/` 和 `dark/media/`）
4. 保留品牌色彩（红色 #E8112D / #B00B20）作为视觉暗示，但不复刻注册商标图案、不附带 "HUAWEI" 文字

### 步骤 4：如需使用真实华为品牌标识

- 通过华为官方渠道申请书面授权
- 或使用华为 AccountKit 等官方 SDK 提供的合规品牌资源包
- 不要从设计稿、网页截图或第三方资源库提取华为 Logo

## Faster Next Time

- **硬性检查清单**：在添加任何品牌标识资源到项目之前，先确认该标识是否为注册商标——如果是，必须获得书面授权或使用合规替代方案
- **合规检查清单**：在应用内任何位置使用华为品牌标识前，先判断是商标性使用（Logo/品牌字样 → 需授权）还是描述性使用（"华为账号"文字 → 不需要）
- **默认策略**：账号绑定页默认使用自定义抽象图标 + 文字描述，不使用真实华为 Logo
- **早期信号**：当用户或设计师要求"换成真实品牌 Logo"时，立即触发合规审查——不要先替换再回退
- **生态内直觉陷阱**：身处华为生态不等于拥有华为商标使用权——这是最常见的误判，需要在团队内明确传达
- **替代方案捷径**：自定义 SVG 花瓣图标（8 片花瓣 45° 分布 + 双色分组）在视觉上能传达"华为"联想，但不构成商标侵权
- **反向验证**：如果项目资源中已有抽象/简化版本的品牌图标，说明此前已做过合规决策——不要因为"有真实 Logo 文件可用"就覆盖已有的合规资源

## Applicability Boundaries

**适用场景**：
- HarmonyOS 应用中展示华为账号/系统账号的品牌标识
- 任何需要品牌 Logo 作为 UI 元素的场景（账号绑定、登录方式选择、关于页等）
- 从设计稿或用户提供的素材中提取品牌资源放入项目

**不适用场景**：
- 已获得华为书面商标使用授权的项目（按授权范围使用）
- 华为官方应用或华为内部项目（自有商标）
- 使用华为官方 SDK 提供的合规品牌资源包（如 AccountKit 内置资源）
- 仅使用"华为账号"文字描述而不使用商标图案（文字描述是否合规需单独确认）

**边界提醒**：
- 本经验仅基于华为品牌政策的一般条款，具体授权范围和限制以华为官方法律文件为准
- 其他品牌（微信、苹果等）的商标使用同样受各自品牌政策约束，不可类推华为的规则
- 深色/浅色主题需各准备一份抽象图标资源（`base/media/` 与 `dark/media/`）

## Evidence or Examples

**项目实例**（HarmonyProject1 账号绑定页）：

1. 账号绑定页（`AccountBindingPage.ets`）通过 `brandIconRes()` 函数映射 provider → 品牌图标资源
2. 品牌图标资源路径：`entry/src/main/resources/base/media/brand_huawei.svg`（浅色）和 `dark/media/brand_huawei.svg`（深色）
3. 用户提供了真实华为 Logo SVG 文件（`~/Pictures/有据UI/HUAWEI 图标.svg`），包含华为花瓣 Logo + "HUAWEI" 文字商标
4. 将真实 Logo 写入项目资源后，用户指出商标合规问题："未经华为事先书面同意，您不得以任何方式、任何目的使用华为的商标、标志、标识、LOGO、公司名称及本计划的名称等"
5. 回退操作：将两个 SVG 文件恢复为自定义抽象花瓣图标（不含 "HUAWEI" 文字，花瓣造型与华为注册商标不同）
6. 浅色主题：红色花瓣（#E8112D + #B00B20）；深色主题：白色花瓣（#FFFFFF + #DFE6EE）

**回退后的抽象花瓣 SVG 示例**（非注册商标图案）：
```svg
<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" fill="none">
  <g fill="#E8112D">
    <path d="M12 12C9 9 6.5 3 12 1C17.5 3 15 9 12 12Z"/>
    <path d="M12 12C9 9 6.5 3 12 1C17.5 3 15 9 12 12Z" transform="rotate(90 12 12)"/>
    <path d="M12 12C9 9 6.5 3 12 1C17.5 3 15 9 12 12Z" transform="rotate(180 12 12)"/>
    <path d="M12 12C9 9 6.5 3 12 1C17.5 3 15 9 12 12Z" transform="rotate(270 12 12)"/>
  </g>
  <g fill="#B00B20">
    <path d="M12 12C9 9 6.5 3 12 1C17.5 3 15 9 12 12Z" transform="rotate(45 12 12)"/>
    <path d="M12 12C9 9 6.5 3 12 1C17.5 3 15 9 12 12Z" transform="rotate(135 12 12)"/>
    <path d="M12 12C9 9 6.5 3 12 1C17.5 3 15 9 12 12Z" transform="rotate(225 12 12)"/>
    <path d="M12 12C9 9 6.5 3 12 1C17.5 3 15 9 12 12Z" transform="rotate(315 12 12)"/>
  </g>
</svg>
```

**关键区分**：此 SVG 是自定义抽象花瓣图案（非华为注册商标的精确复制），8 片花瓣 45° 均匀分布 + 双色分组（红/深红），传达花瓣视觉联想但不构成商标侵权。
