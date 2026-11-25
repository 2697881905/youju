---
title: "2026-10-09-hmos-emulator-ui-color-verify-dump-and-dumplayout.md"
id: markdown_cls1_798285c88467638f6a8dc28635ad6f33_dd92b03ebec8e3e9ee8bc00859c6d4647505655250320770
kb: 有据-YouJu
folder: "问题记录"
media_type: 7
tags: []
source: ima
exported_at: 2026-11-23T15:08:14.161Z
---
---
id: 2026-10-09-hmos-emulator-ui-color-verify-dump-and-dumplayout
title: 鸿蒙模拟器 UI 选中态颜色验证：UI 树 fillColor/fontColor 解析 + dumpLayout 真实坐标点击
category: debugging
nature: methodology
created_at: 2026-10-09T01:46:24
updated_at: 2026-10-09T01:46:24
tags: [harmonyos, ui-testing, uitest, fillColor, verification]
keywords: [fillColor, fontColor, UI树, full dump, dumpLayout, uitest, 模拟器验证, 坐标点击, 选中态验证, deveco-mcp, 截图坐标不可靠]
problem_patterns: [ui-color-state-verification-via-ui-tree, screenshot-coordinate-unreliable-for-click, layout-bounds-derived-click-coordinates]
source_sessions: [ses_ee36905beffeeSftxx5Gy8IakE]
project: HarmonyProject1
severity: medium
quality_score: 90
hit_count: 0
last_hit_at: null
low_quality_hit_count: 0
tier: S
related_experiences: [2026-10-09-arkui-tab-selected-state-fillcolor-must-match-fontcolor, 2026-10-07-agent-shell-search-command-guardrails]
---

# 鸿蒙模拟器 UI 选中态颜色验证：UI 树 fillColor/fontColor 解析 + dumpLayout 真实坐标点击

## Scenario

需要验证鸿蒙应用在模拟器/真机上的 UI 颜色状态实际渲染值（如 Tab 选中态图标 `fillColor` 与文字 `fontColor` 是否一致、深浅色是否生效），并通过点击切换 UI 状态做跟随性验证。典型触发条件：

- 纯视觉修复（无编译错误、无日志）完成后需要实测验证
- 需要程序化断言颜色值而非人眼/视觉模型看截图
- 需要精确点击某个 UI 元素（Tab 项、按钮）触发状态切换

## Key Signals

1. `deveco-mcp_get_app_ui_tree` 的 **full dump** JSON 中，`Image` 节点含 `fillColor` 属性、`Text` 节点含 `fontColor` 属性——颜色验证不必依赖截图，直接解析树数据即可得到精确渲染值（如 `#FF0066CC`）
2. **full dump UI 树不含绝对坐标**——节点属性里没有可点击位置，不能用于定位点击坐标
3. **截图 + 视觉模型分析给出的坐标不可靠**：分析报告的坐标可能有误（本次「我的」中心坐标 1260 超出 1320 屏宽的合理范围），按其坐标点击未生效
4. `uitest dumpLayout` 导出的布局树含 `bounds="[x1,y1][x2,y2]"`，是唯一可靠的坐标来源
5. 模拟器实际渲染分支可通过特征属性识别（如 Tab 项 `fontSize=10.00fp` + `objectFit=Contain` + 24x24 图标 → HdsTabs 分支；`fontSize=12.00fp` + `ImageFit.Cover` → 其他分支）

## Essence

根因链：截图分析坐标不可靠 → 按截图坐标点击落在错误位置（甚至误触内容区元素进入详情页）→ 误以为点击未生效。可靠路径是**双工具分工**：`get_app_ui_tree` full dump 负责「验证颜色/状态渲染值」（有 `fillColor`/`fontColor`，无坐标），`hdc shell uitest dumpLayout` 负责「定位可点击元素坐标」（有 `bounds`，取中心点击）。两者数据互补，缺一不可。

## Approach

排查/验证决策序列：

1. **验证颜色渲染值**：`deveco-mcp_get_app_ui_tree`（mode=full）导出 UI 树 JSON → Python 脚本递归遍历，按文本内容锚定目标节点（如 Text `content='首页'`），提取同项 `fontColor` 与兄弟 `Image` 的 `fillColor`，逐 Tab 断言
2. **识别运行分支**：从树中特征属性（fontSize/objectFit/尺寸）判断设备实际走哪个 UI 分支，明确验证覆盖范围
3. **定位点击坐标**：`hdc shell uitest dumpLayout -p /data/local/tmp/layout.json` + `hdc file recv` 导出 → 解析 `attributes.bounds`（格式 `[x1,y1][x2,y2]`），计算 `center=((x1+x2)/2, (y1+y2)/2)`
4. **点击切换**：`uitest uiInput click <x> <y>` → 重新 dump UI 树 → 断言选中态跟随（新选中项变色、旧项恢复）
5. **失败回退**：若点击后状态未变，先怀疑坐标错位（而非应用 bug）：重新 dumpLayout 确认目标 bounds，检查是否误触了内容区可点击元素（误入子页面时先 `keyEvent Back` 返回主页面再重试）

## Faster Next Time

- 颜色验证**跳过截图**：直接解析 full dump 的 `fillColor`/`fontColor`，精确到色值且可程序化断言，视觉模型只用于无法从树中获取的信息
- 点击坐标**只信 dumpLayout 的 bounds**，不信截图分析的估算坐标；拿到 bounds 后取中心点
- 点击前先确认当前处于预期页面（避免在子页面/弹窗上点错）；误触进入子页面时 `uitest uiInput keyEvent Back` 返回
- 验证完成后清理临时 dump 文件（full dump JSON 约 10MB/次，多轮验证累积可观）
- `deveco-mcp_get_hilog_or_faultlog_recent` 的 `keyword` 正则参数经 shell 传递易被解析失败（表现为 `/bin/sh: xxx: inaccessible or not found`），优先检查应用代码中是否有日志打点，无打点时不要在 hilog 上消耗轮次

## Applicability Boundaries

- 适用于：deveco-mcp + 模拟器/真机环境下验证 UI 颜色、选中态、渲染分支；需要程序化坐标点击的场景
- 不适用于：无 deveco-mcp/hdc 工具链的环境；验证动画中间帧或需连续采样的场景（dump 是瞬时快照）；非颜色/状态类的 UI 断言（如滚动位置）需另行设计
- 注意：UI 树/布局树均为瞬时快照，点击后需等待状态稳定再 dump；full dump 文件较大，注意清理

## Evidence or Examples

- 来源会话：修复 TabBar 选中态图标与文字颜色不一致（HarmonyProject1）
- 误触反例：按截图分析坐标 `(1008, 2470)` 点击「消息」Tab 未生效（连续两次），随后按内容区估算坐标点击 `(794, 2540)` 误触帖子卡片进入详情页（底部出现「发送」按钮），需 Back 返回；dumpLayout 后得到 Tab 项真实坐标（图标 y≈2643、文字 y≈2720），点击 `(845, 2643)` 一次成功
- 分支识别证据：Tab 项 `fontSize=10.00fp`、图标 `24x24`、`objectFit=Contain` → 模拟器走 HdsTabs 分支（自绘底栏分支 fontSize=12.00fp、ImageFit.Cover）
- 验证结果示例：首页选中时首页项图标+文字均 `#FF0066CC`、其余项均 `#FF3C3C43`；点击「消息」「我的」后选中态正确跟随，全部 Tab 断言通过
- 临时文件：full dump 存于项目 tmp 目录（如 `full_dump_app_*.json`，约 10MB），验证后已清理
