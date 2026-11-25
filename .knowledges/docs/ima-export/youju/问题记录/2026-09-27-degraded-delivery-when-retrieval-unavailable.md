---
title: "2026-09-27-degraded-delivery-when-retrieval-unavailable.md"
id: markdown_798285c88467638f6a8dc28635ad6f33_88eb250f7a4e5d52b3dc8eb2458b72917505655250320770
kb: 有据-YouJu
folder: "问题记录"
media_type: 7
tags: []
source: ima
exported_at: 2026-11-23T14:52:37.917Z
---
---
id: 2026-09-27-degraded-delivery-when-retrieval-unavailable
title: 检索工具全线不可用时的降级交付策略（标注证据受限而非阻塞任务）
category: agent-ops
nature: methodology
created_at: 2026-09-27T02:39:51
updated_at: 2026-09-27T02:45:59
tags: [检索降级, 证据受限, webfetch失败, 知识库不可用, 交付不阻塞]
keywords: [webfetch aborted, operation was aborted, Wiki documents not found, No relevant content found, 知识库不可用, 联网失败, 降级交付, 待核实标注, 证据受限声明, 领域知识兜底]
problem_patterns: [联网检索连续失败导致任务阻塞, 检索通道全不可用时如何继续交付, 不确定事实被写成结论]
source_sessions: [ses_f21031a16ffeP6M1eugJaHubzE]
project: HarmonyProject1
severity: medium
quality_score: 86
hit_count: 0
last_hit_at: null
low_quality_hit_count: 0
tier: S
related_experiences: [2026-09-27-validate-analogy-premise-before-feasibility-analysis]
---

# 检索工具全线不可用时的降级交付策略（标注证据受限而非阻塞任务）

## Scenario

任务要求"查阅资料/核实事实"后再产出分析或方案文档，但运行时环境同时阻断了所有外部检索通道：网络抓取（webfetch）返回中断错误，本地知识库（Knowledge / RagSearch）返回"无文档/无相关内容"。此时检索是手段而非目标，若持续重试会耗尽执行预算并把任务拖入未完成状态。

## Key Signals

- 网络工具反复返回同类错误：`Error calling tool "webfetch": The operation was aborted.` / `error: The operation was aborted.`
- 本地知识库明确无数据：`Wiki documents not found in this project.`、`No relevant content found in knowledge base.`
- 对同一工具连续多次尝试，错误信息完全一致（说明是通道级不可用，不是查询词问题）。
- 交付物本身（分析/方案文档）并不强依赖实时数据，只是"最好有资料支撑"。

## Essence

检索失败不等于任务失败。判定"通道级不可用"后应立即停止重试，切换到**降级交付**：用领域知识完成分析，同时把证据强度的下降显式暴露给用户——在交付物开头声明证据受限，对每个不确定事实标注 `[待核实]`，并汇总成"关键前置核实清单"。这样交付物仍可用、可评审，且不会被误当成已核实结论。核心原则是：**宁可标注不确定，也不要把推断写成结论。**

## Approach

1. **判定通道状态**：同一检索工具连续失败 2~3 次且错误一致时，判定为通道级不可用，停止继续重试同一工具。
2. **穷举替代通道并各探测一次**：依次尝试本地知识库、项目内文档/README、已有经验库等；每个通道只探测一次，避免重复消耗。
3. **进入降级模式**：若全部替代通道也不可用，改为基于领域知识产出，但不得放弃交付。
4. **显式声明**：在交付物开头用一句话说明"本次运行环境无法联网、本地知识库不可用，资料核实受限"。
5. **逐条标注**：对每个不确定的事实点标注 `[待核实]`，区分"确定事实"与"需核实事实"。
6. **收口核实清单**：在结尾给出待核实项汇总（P0/P1 优先级），明确哪些结论会因核实结果而改变。
7. **不编造来源**：禁止虚构引用、链接或数据；宁可写"缺乏依据"。

## Faster Next Time

- 开工前先用一次最轻量的探测确认检索能力（而非写完一半才发现不可用），据此决定是否需要外部资料。
- 把"证据受限声明 + 待核实清单"作为分析类交付物的标准组成部分，而不是失败后的补救。
- 看到 `operation was aborted` 且连续复现时，直接判定通道不可用，不要逐条换查询词试探。

## Applicability Boundaries

- 适用于：需求分析、技术可行性调研、方案评审等"检索是辅助手段"的文档类任务。
- 不适用于：结论必须依赖实时/权威数据才能成立的任务（如价格、版本号、合规条文），此时应明确升级或求助，而不是用领域知识兜底。
- 不适用于：代码实现、构建、测试类任务——这些应通过实际执行获得证据。
- 降级交付的前提是结论具有可解释的推理链；纯猜测不构成降级交付的正当理由。

## Evidence or Examples

- 本次会话（ses_f21031a16ffeP6M1eugJaHubzE）：任务为"鸿蒙电脑 Win 易通转译 Windows 软件可行性分析"，明确要求"查阅资料"。
- 实际执行：webfetch 连续 6 次返回 `The operation was aborted.`；`Knowledge` 返回 `Wiki documents not found in this project.`；`RagSearch` 返回 `No relevant content found in knowledge base.`。
- 处置结果：助手停止重试，基于领域知识产出方案文档，并在交付说明中显式声明"本次运行环境无法联网（webfetch 与本地知识库均不可用），资料核实受限，文档中对不确定事实均标注了 `[待核实]`"，最终交付文档成功写入 `output/Solution-WinYiTong-HarmonyOS-Windows-Compat-202609270206.md`。
