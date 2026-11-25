---
title: "harmony-learning-2026-09-25.md"
id: markdown_798285c88467638f6a8dc28635ad6f33_f0afd9ce2ebb48123e0b1afcb441fa437505655250320770
kb: 有据-YouJu
folder: "决策记录"
media_type: 7
tags: []
source: ima
exported_at: 2026-11-23T14:52:37.917Z
---
# 有据 IMA 同步增量学习 · 2026-09-25

> 本文件由 harmony_sync 自动化对本次新处理文档提炼（3 事实 / 2 决策 / 1 模式），供后续会话检索复用。

## 项目事实（Facts）
1. **登录单一化已落地**：v1 仅用华为账号(unionID)，`/v1/auth/login` 与鸿蒙 openId 绑定已下线；绑定页无入口，重绑/解绑 huawei 分别返回 400/403。账号绑定 PRD/设计（prd-account-binding、design-account-binding、plan-sess_8dfa33c3）确认该决策，兜底登录仅 debug 可用。
2. **ArkTS 严格模式高频坑清单已沉淀**：`.codeartsdoer/experience-reuse` 收录 15+ 条编码模式——@Prop 函数禁用、索引签名/无类型对象字面量禁用、`obj[key]`→Map/switch、对象展开/解构禁用、@Builder 内 const/let 禁用、@Builder 参数仅单对象字面量按引用刷新、内联 getter 丢响应式、深色模式必须走 ColorTokens 资源色不硬编码、列表项抽独立 @Component+标量 @Prop、装饰遮罩层 hitTestBehavior(None)。
3. **IMA 知识库写入链**：`create_media`→STS 凭证 PUT 到 COS→`add_knowledge` 入库。`create_media` 在本环境是 **deferred 工具**，必须经 ToolSearch 加载后用 DeferExecuteTool 调用，不能直接当普通工具调（否则报 not found in agent cli）。STS 凭证绑定单 cos_key，不可复用，每文件单独 create_media。

## 关键决策（Decisions）
1. **不做多 provider 绑定页**：v1 登录即绑定华为账号，降低 unionID 串号/丢号风险；新增/切换 provider 需新建 Provider 枚举项而非复用 huawei 入口。
2. **文档分类口径固化**：`.codeartsdoer/experience-reuse`→问题记录，`.trae/documents`→开发文档，`.codebuddy`→提交摘要，`deliverables/retrospective`→决策记录；`.mermaid` 架构/时序/类图归开发文档（关键词"sequence/diagram"不再误判为问题记录）。

## 可复用模式（Pattern）
**ArkUI 交互完整性自检清单**：ForEach 列表项→独立 @Component + 标量 @Prop；属性变化→@Observed+@ObjectLink；纯装饰遮罩层→`hitTestBehavior(HitTestMode.None)` 防挡手势；圆角必落在有 bg 的元素；深色模式全部走 ColorTokens 资源色，禁硬编码灰。该清单可固化为提审前 Code Review 必检项。

## SKILL 处置说明
深色模式硬编码色重复出现（hardcoded-colors 与 hardcoded-color-pitfall 两篇），属重复问题；但已有技能 `harmonyos-arkts-v1-strict` 已覆盖 ArkTS 严格模式坑，故不新建冗余 SKILL。本次新增的可复用点（create_media 为 deferred 工具、COS STS 单 key 不可复用）已回写 `ima-kb-upload` SKILL.md。
