---
title: "harmony-learning-2026-10-29.md"
id: markdown_cls1_798285c88467638f6a8dc28635ad6f33_b3e48c86e6033580387cf657213a1f2e7505655250320770
kb: 有据-YouJu
folder: "决策记录"
media_type: 7
tags: []
source: ima
exported_at: 2026-11-23T14:52:37.917Z
---
# 增量学习 · 2026-10-29（5 篇新增交付文档）

> 本次新处理文档（均归入 IMA「开发文档」文件夹）：
> - deliverables/product-strategy/mau-ledger.md
> - deliverables/product-strategy/growth-400mau-youju-2026-10-28.md
> - deliverables/product-strategy/growth-channel-assets-youju-2026-10-28.md
> - deliverables/growth/guest-convert-bar-patch.md
> - deliverables/content/editorial-2026-11-dual11.md

## 3 条项目事实

1. **「有据」400 有效月活作战方案（冷启动 v2，2026-10-28 收口）**：实测基线为登录侧行为月活 46 / 设备出口 ~211 / 可推送 36 / 商店评分 1 条（硬条件 ≥10 未达标）/ 召回链路已 15 天零发送；目标为有效月活（去重活跃设备）≥400，考核窗口至 2027-01-31。代码与内容已全部提交（35 个），工作区仅剩并行设计会话文件；后端 tsc=0、349 例测试通过；生产库仅跑过只读查询（可复核）。
2. **月活台账机制落地**：`deliverables/product-strategy/mau-ledger.md` 由 `scripts/daily-ledger.sh [YYYY-MM]` 自动追加，与 `scripts/agc-active-devices.mjs`（AGC 官方活跃设备数）、`scripts/src-report.sh`（渠道点击）配合，构成可自证的**下界**；真值以激励计划后台为准。
3. **游客引导条已合入主分支**：`GuestConvertBar.ets` 于 2026-10-28 合入 `HomeTab.ets`，ArkTS 检查 no diagnostics、0 Error（仅 4 条既有类别 Warning）；源码暂存 `deliverables/growth/GuestConvertBar.ets.txt`（改名避免被 hvigor 当源码编译）。§3 的 6 项真机验收因圈子页施工未完成而暂缓，留待收口后做。

## 2 条关键决策

1. **运营红线「不刷量」不可让步**：机器/人工互助刷量被华为风控一票否决，剔除的不止 3000 元激励；内容侧设「每日一帖推送默认关闭 + 不推伪造亲历」闸门。冷启动 v2 取代旧 `incentive-3000-youju-2026-08-15.md` 方案（其「月活窗口截至 2026-10-31」已被华为官方规则更新作废）。
2. **对外文案严格事实约束**：只承诺 App 现有能力（结构化体验帖 4 体裁、标签星图圈子、每日一帖、顶/藏/评/私信、@提及、搜索、举报中心、华为账号一键登录、华为推送、智感握姿、沉浸光感材质、液态玻璃 Dock、站外分享卡片与深链 App Linking）；绝不提未上线的「碰一碰分享引导」「邀请码」「积分商城」「打赏」「帖子置顶」。双 11 内容全部给出处、不伪装个人经历（主数字用可比量 + 法规条文号）。

## 1 个可复用模式 / 检查项

**月活/增长达标自证三件套**：任何「月活/增长达标」汇报前，先跑
`./scripts/daily-ledger.sh <YYYY-MM>`（追加 ledger）+ `node scripts/agc-active-devices.mjs`（官方活跃设备数）+ `./scripts/src-report.sh 168h`（渠道点击），
把三件套原始输出附在结论后；ledger 只是可自证下界，真值以激励计划后台为准。
→ **检查项**：达标结论若无三件套原始输出支撑，一律视为未证实，不得写入对外汇报。

> SKILL 处置：本批为增长/运营文档，无重复单点工程 bug；`GuestConvertBar` 冷启动 AppStorage 未水合 → `@StorageProp` 取值滞后需用 `aboutToAppear` 内 `getToken()` 兜底 + `guestBarReady` 门控，此 ArkUI 陷阱已由既有 `arkui-runtime-pitfalls` SKILL 覆盖，不新建冗余 SKILL（保持减法）。
