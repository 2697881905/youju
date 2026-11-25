---
title: "harmony-learning-2026-10-14.md"
id: markdown_cls1_798285c88467638f6a8dc28635ad6f33_7ca998396655b941141e5f1e980a7f457505655250320770
kb: 有据-YouJu
folder: "决策记录"
media_type: 7
tags: []
source: ima
exported_at: 2026-11-23T14:52:37.917Z
---
# HarmonyProject1 增量学习 · 2026-10-14

> 来源：本次同步处理的新检出/变更文档（圈子 Tab 星图 Live 两篇、商店上架文案、AGC 审查两篇、教程页标题栏沉浸光）
> 用途：追加至项目工作记忆；摘要已备份 IMA「有据-YouJu / 决策记录」

## 项目事实（3）

1. **圈子 Tab 重构为「星图 Live」形态（2026-10-11，docs/circle-tab-starlive-*.md）**：三环轨道 + 行星（圈子）+ 降落页（LandingOverlay 同层覆盖）+ bindSheet 深空目录三档吸附；一期明确弃用 HDS 卡片组件（HdsListItemCard/HdsListItem 卡面不可控，cardBackgroundColor 三种入参均静默无效），仅保留 HdsNavigation 标题栏体系。
2. **星图后端接口盘子**：已有 `followTag/unfollowTag`、`listPosts({tag,sort:'latest'})`、`GET /v1/posts/daily`；新增 `POST /v1/tags/:name/weight`（UserTagPref 引力权重表，二期）、`GET /v1/tags/unread`（二期）、`POST /v1/tags` 创建（三期）；客户端只写 weight + 星图半径回显，推荐/通知消费端后端排期。
3. **提审链路文档已就绪且持续维护**：`deliverables/store-listing-youju-2026-10-01.md`（商店文案定稿底稿：一句话介绍/预览图文案/上架视频脚本底稿）+ `deliverables/agc-pre-review.md`、`youju-agc-review-2026-08-16.md`（AGC 预审清单更新版）。

## 关键决策（2）

1. **降落转场选方案 A**：同层覆盖 + `geometryTransition(id)` 共享元素 + 星图 `scale(2.8)+opacity(0.16)` 退场（650ms springSoft 同族），不做 Navigation 子页 + sharedTransition（方案 B 留二期）——理由：全 transform/opacity 合规、无路由栈污染、起飞即反向播放、改动面小。
2. **引力拖拽手势冲突治理**：行星命中区（disc+8vp）`HitTestMode.Block` 优先消费、拖拽 >8vp 才判拖不判点，空白区保留按环拨动；`gravityEnabled` AppStorage 灰度开关兜底。

## 可复用模式 / 检查项（1）

- **HTML 原型 → ArkUI 映射速查表**（tech-plan 附录）：rAF rotate → 层级 `rotate()`+反向 rotate 直立；translateY 滑入 → `TransitionEffect.move(TransitionEdge.BOTTOM)`；手写抽屉 → `bindSheet(detents)` 三档系统自带；localStorage 持久化 → 服务端表（真机天然跨设备）。任何「先 HTML 原型后落地」的功能迁移均可复用此映射，避免逐个重新发明。

## 工具链坑（同步流程自用）

- IMA create_media 返回的 COS 临时凭证上传端点是**数据万象 pic 域名**（`<bucket>.pic.<region>.myqcloud.com`），且 Authorization 必须显式带 `q-url-param-list=`（COS 端可省略、CI 端缺失报 AuthMissRequiredField）；格式串 = `put\n<path>\n\n<header_kv>\n`（header 值 RFC3986 编码，含 x-cos-security-token）。已验证配方存于本次会话上传脚本；ETag == 本地 md5 可校验。
