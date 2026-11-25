---
title: "harmony-learning-2026-11-06.md"
id: markdown_cls1_798285c88467638f6a8dc28635ad6f33_d936d831c8e5c96c6bc10730d232e9e57505655250320770
kb: 有据-YouJu
folder: "决策记录"
media_type: 7
tags: []
source: ima
exported_at: 2026-11-23T14:52:37.917Z
---
# 增量学习摘要 · 2026-11-06（据 sync 新增 2 篇）

> 来源：`docs/superpowers/specs/2026-11-05-structured-post-verifiable-reading-design.md`、`docs/superpowers/plans/2026-11-05-structured-post-verifiable-reading-plan.md`（均归「开发文档」，已上传 IMA「有据-YouJu」开发文档文件夹）
> 主题：结构化帖子详情页「可核验阅读」重设计（superpowers 工作流产出，2026-11-05 批准）

## 3 条项目事实

1. **「可核验阅读」重设计落地形态**：结构化区从「N 张描边底色卡」改为**零卡片纯排版**（块间 `ColorTokens.separator` hairline 分隔），证据链从藏在「据 N」胶囊后升级为阅读标配——块挂证据 → 论点文本带可验标记（accent 色 + 「据 N ↗」角标），点击开「验一验」验货层（出处/截图/口径）。
2. **关键数字（metric 块）被判定删除但后端不动**：metric 是作者自填裸数字（无出处/无口径/无校准），制造「同体裁第 N 名」幻觉排名，故前端移除入口、存量块降级为普通兜底行；但后端 `BLOCK_TYPES` 白名单与 metric 专项校验**刻意保留**（存量帖切体裁仍可重提通过校验），整特性**后端零改动**。
3. **体裁版式由既有数据层结构承接**：渲染层按「体裁 × 类型」映射到槽位（判词 insight / 对照 compare / 清单 list / 步骤 steps / 对决 compare+投票 / 兜底），数据层白名单 `structuredBlockTypesForGenre` 早已按体裁分派，渲染层接住即可；V1 旧字段帖（`StructuredFieldBlock` 路径）原样保留不在范围。

## 2 条关键决策

1. **删除关键数字（metric）决策**：理由=自填裸数字产幻觉排名、与「可信度有回报、说错有代价」的内容标准冲突；结论=前端删入口+存量降级，**后端白名单不删**以保存量帖可编辑重提。取舍点：发布页切体裁会把 metric 出白名单的存量块静默清除，与现状其他类型切体裁被清一致，接受。
2. **可验标记用 accent 角标而非虚线下划线**：ArkUI `TextDecorationType` 仅 None/Underline/Overline/LineThrough 无虚线型，per-side dashed border 降级成本高 → 角标（`据 N ↗` 10–11px pill）为定案；证据判定粒度=**块级**（挂在块上，不假装条目级）。

## 1 个可复用模式 / 检查项

**「零卡片化」结构化区重构检查清单**（下次动结构化渲染必查）：
- ① 块间一律 hairline 分隔，**不画任何卡片**（无底色/描边/独立圆角）；
- ② 强调只用三件套——accent 色（类型字/据链接/序号球/勾选）、语义色（优缺对照 success/danger）、衬线字重（判词/大字），**不引入写死色值**（沿用 ColorTokens/TypeTokens）；
- ③ 对照块色条 2px + 文字标签**并存**（不只靠颜色，满足 WCAG 1.4.1；语义色规则精确等于「优点/缺点」才命中，不做模糊匹配）；
- ④ 预览页（无 postId）组件级复用必须自动收起打卡进度/投票行（`canCheckIn` 逻辑守住），避免发布预览泄漏交互态。

> 说明：本次为单点新特性设计，无重复单点 bug，按减法原则不新建 SKILL 草稿（结构化帖子相关既有 `arkui-shared-element-transition` 等不冲突）。
