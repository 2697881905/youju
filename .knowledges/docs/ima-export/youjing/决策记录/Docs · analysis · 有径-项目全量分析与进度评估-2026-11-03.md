---
title: "Docs · analysis · 有径-项目全量分析与进度评估-2026-11-03.md"
id: markdown_cls1_798285c88467638f6a8dc28635ad6f33_8039f370e3a08b3ee6fb50e2dff36dc47526104239726721
kb: 有径-YouJing
folder: "决策记录"
media_type: 7
tags: []
source: ima
exported_at: 2026-11-23T14:52:37.917Z
---
# 有径（YouJing）项目全量分析与开发进度评估

> 分析日期：2026-11-03  
> 分析范围：`/Users/itxiaobai/HarmonyProject2` 工作区（源码、`entry/src/ohosTest`、`tools/`、`Docs/`、`bff/`、`cloud/`）  
> 分析方式：只读通读 + 静态核对 + 离线脚本实跑；未修改任何已跟踪文件，未重编译、未连接真机。  
> 重要前提：当前工作树含 **21 个已修改文件 + 未跟踪的 `bff/` 与 `Docs/商业化方案.md`**，是「本地核心功能已收口 + 商业化改造在飞」的混合状态，不是单一可发布版本。
>
> **2026-11-09 补记**：实况窗已因场景不在开放范围被 AGC 驳回，相关代码与资源已移除；
> P5 收敛为「围栏 + 本地通知」。P4 代理提醒、围栏后台唤醒仍待 AGC 审核。本文其余数字与
> 判断均为 2026-11-03 快照，不代表当前状态。

## 0. 结论摘要

**整体判断：三柱主链已经真实闭环，功能面完成度高；但「可演示」与「可发布」之间存在明显断层。** 按产品价值加权（行前 30 / 行中 20 / 行后 15 / 工程基座 15 / 质量门 10 / 商业化 10）估算，**功能面约 81%**；把真实生成、商业化安全、合规、release 签名与平台能力计入，**发布就绪度约 45–50%**。这是基于模块状态的估算，不是精确 KPI。

已经真实落地的部分：

- 屏 1–16 全部有可用实现（屏 10 / 屏 14 是 `bindSheet` 面板，屏 13 是桌面卡片，不是独立 page），主链在真机有完整走查记录。
- RDB 本地数据层完整：8 张业务表、`DB_VERSION = 10`、累积式迁移、单写通道、按账号分区、删行程级联清理。
- 行前三件真实可用：一句话本地解析（零 LLM）、自动选点/住宿区预选、任意城市 Map Kit 接入；西安有真实生成取证，成都到屏 5/5b。
- 行中三信号（偏离/落后/有雨）与 `ArrivalWatcher`、`SkipPlanner` 已接通屏 15；跳过/顺延/撤销共用快照链路；「落后 → 跳过 → 撤销」有真机画面。
- 行后情绪件全部从打卡证据派生，不建第二份真相：勋章墙、城市套章、旅行回顾、海报分享、周年横幅。
- 质量门基础扎实：14 把静态尺本次全部 `rc=0`；5 套离线断言本次全部通过（66 / 104 / 57 / 74+26 / 116）；云函数 `replanDay` 15 个 `node:test` 全过。

最重要的三条差距：

1. **真实生成通道在商业化改造中退化了。** 端侧成熟的 17 条提示词规则 + 完整 JSON Schema 仍在 `PromptBuilder`，但生产路径已切到 BFF；BFF 的 prompt 只有一句「你是旅行规划助手」，没有 Schema、没有景点/区域细节、没有节奏与天数规则，`response_format` 只有 `json_object`。端侧只剩 `TripParser` 一层守卫，所谓「三层防线」当前实际只有一层在工作。
2. **商业化闭环不可上线。** IAP 服务端校验是 `return { verified: true }` 的桩；`/v1/iap/notify` 只打日志不验签；JWT 有硬编码兜底密钥；`/v1/iap` 未挂统一鉴权中间件（`notify` 完全不验）；BFF 幂等缓存把「请求参数」当 `trip` 返回，重试必然解析失败。与此同时隐私政策仍写「没有云端存储、不上传任何服务器」，与 BFF 实传 `unionId` / `deviceId` / 行程参数 / 购买凭证直接冲突。
3. **文档与代码出现系统性漂移。** README 仍写「无自建后端 / 自带 Key / DB_VERSION=9 / 191 例 / 三层防线」；实际是 BFF + 云函数、`DB_VERSION=10`、静态计数 189 例（CHANGELOG 另一处又写 192）、三层只剩一层。`Docs/完成度评估与待办清单-2026-10-25.md` 的 12,925 行 / 71 文件 / 66 例 / v5 已整体过期。README 宣称的「跨天移动」在代码中不存在。

最重要的三条下一步：

1. 把 `PromptBuilder` 的 17 条规则与 `TripSchema` 搬回 BFF（或让端侧继续构建 prompt、BFF 只做 Key/配额代理），同时修幂等缓存、补 BFF 测试；这是一次真实模型验收的前置。
2. 对商业化做「上线 / 不上线」二选一：上线就补真实验签、notify 验签、去掉兜底密钥、更新隐私政策与 `CONSENT_VERSION`、加 BFF 删除接口；不上线就从本版本摘掉 `Pricing` 与权益门禁，避免半成品付费墙。
3. 用同一棵树重跑发布闸门：提交或隔离 21 个在飞文件 → 双 HAP 构建 → 真机 hypium → v9→v10 迁移实测，并把真实计数写回文档。

---

## 1. 项目全貌

### 1.1 定位与边界

产品的原始定位是「AI 驱动的旅游行程规划 App」：用户选城市与日期，AI 以选项式追问偏好，生成结构化逐日行程。[`Docs/有径·App开发文档.md:5-22`]

当前实现比原始文档更「本地优先」：行程、打卡、记账、勋章全部落在设备 RDB；LLM 只做生成与重排决策；任意城市用 Map Kit 现取景点/住宿区，结果只放内存、不落库。[`README.md:3-6`][`entry/src/main/ets/data/PlanRepository.ets:19-54`]

但「无后端」已经不是事实：

- `cloud/replanDay/` 是已入库的 AGC 云函数，持有 LLM Key，负责「不去」重排决策。[`cloud/replanDay/index.js:198-266`]
- `bff/` 是未入库的 Express + SQLite 后端，负责设备激活、权益/配额、LLM 代理、IAP 校验。[`bff/src/index.js:23-30`][`bff/src/db.js:9-88`]
- 端侧 `ApiConfig` 已有 `BFF_BASE_URL`、`DEV_SKIP_BFF` 等字段。[`entry/src/main/ets/common/config/ApiConfig.ets:50-66`]

因此本报告的「数据面 / 控制面」应按现状拆开：**行程内容仍在端侧，账号/配额/计费/LLM Key 已开始上云**。

### 1.2 技术栈与工程形态

| 项 | 事实 | 证据 |
|---|---|---|
| 平台 | HarmonyOS，`targetSdkVersion` / `compatibleSdkVersion` = 26.0.0 | `build-profile.json5:22-23` |
| 模型 | Stage 模型，`EntryAbility` + `EntryBackupAbility` + `FormExtensionAbility` | `entry/src/main/module.json5:74-121` |
| 语言/UI | ArkTS V1（全仓无 `@ComponentV2/@Local/@Param/@Once` 实义用法），官方 ArkUI + `@kit.UIDesignKit`（21 个文件引用 Hds） | `entry/src/main/ets/pages/Index.ets:33` 等 |
| 运行时依赖 | App 侧为空；开发依赖 `@ohos/hypium 1.0.25`、`@ohos/hamock 1.0.0` | `oh-package.json5:4-9` |
| 设备类型 | 仅 `phone` | `entry/src/main/module.json5:7-9` |
| 签名 | HEAD 为空；工作树为本地调试签名（`skip-worktree` 文件） | `git show HEAD:build-profile.json5:3`；本地 `build-profile.json5:3-17` |
| 最外层自绘 | 唯一非声明式绘制是地图 marker 的 `OffscreenCanvas`（产出 PixelMap 交给官方 `MarkerOptions.icon`），不是自绘 UI 控件 | `entry/src/main/ets/utils/NumberedPin.ets:26-62` |

**代码规模（当前工作树）**：`entry/src/main/ets` 共 **129 个 `.ets` 文件、25,635 行**。按目录：`pages/` 11,582 行、`data/` 4,581 行、`utils/` 3,555 行、`ai/` 1,177 行、`components/` 1,157 行、`design/` 677 行、`model/` 576 行、`common/` 1,093 行、`entryability/` 458 行、`widget/` 572 行、`mock/` 193 行。

### 1.3 分层与依赖

`Docs/ARCHITECTURE.md` 声明的方向是 `pages → components → model / data / ai / utils → common`，并禁止页面直接操作 RDB 或直接发起 LLM 请求。[`Docs/ARCHITECTURE.md:26-36`]

实际依赖并不完全符合表格：`pages/` 里有 **59 处** `from '../data/...'`、**2 处** `from '../ai/...'`。页面没有直接写 SQL / 直接 `http` 调 LLM，但确实直接 import DAO 与 `LlmClient`。`Docs/完成度评估与待办清单-2026-10-25.md:103` 已承认「编排逻辑在页面内」属合规但未做 `service/` 门面。这条是**文档与实现的灰区**，不是功能性缺陷，但会影响可测试性。

### 1.4 运行时主链（屏 1–16）

| 屏 | 实现 | 形态 | 关键证据 |
|---|---|---|---|
| 屏 1 | `YoujingStartPage` | 规划 tab 根页 | `pages/YoujingStartPage.ets:2` |
| 屏 2 | `TripInputPage` | 独立 page | `pages/TripInputPage.ets:2` |
| 屏 3 / 3b | `PreferenceQAPage` | 独立 page，同屏双态 | `pages/PreferenceQAPage.ets:2` |
| 屏 4 | `SpotPickPage` | 独立 page | `pages/SpotPickPage.ets:2-4` |
| 屏 5 | `StayPickPage` | 独立 page | `pages/StayPickPage.ets:2` |
| 屏 5b | `AreaMorePage` | 独立 page | `pages/AreaMorePage.ets:2` |
| 屏 6 | `GeneratingPage` | 独立 page | `pages/GeneratingPage.ets:2-6` |
| 屏 7 | `GenerateFailedPage` | 独立 page | `pages/GenerateFailedPage.ets:2` |
| 屏 8 | `ItineraryPage` | 独立 page | `pages/ItineraryPage.ets:2` |
| 屏 9 | `EditItineraryPage` | 独立 page | `pages/EditItineraryPage.ets:2-8` |
| 屏 10 | `ItineraryPage.detailSheet()` | `bindSheet` 面板 | `pages/ItineraryPage.ets:1377` |
| 屏 11 | `ExpensePage` | 独立 page | `pages/ExpensePage.ets:2` |
| 屏 12 / 12b | `TripsPage` | 独立 page | `pages/TripsPage.ets:2` |
| 屏 13 | `TodayTripCard` + `TodayTripFormAbility` | 桌面卡片 | `widget/pages/TodayTripCard.ets:2` |
| 屏 14 | `ItineraryPage.systemAccessSheet()` | `bindSheet` 面板 | `pages/ItineraryPage.ets:1367` |
| 屏 15 | `OnTripPage` | 独立 page | `pages/OnTripPage.ets:2` |
| 屏 16 | `SharePage` | 独立 page | `pages/SharePage.ets:2` |

路由表在 `pages/AppRouter.ets:51-91`，`TripInput / PreferenceQA / SpotPick / StayPick / Generating / Itinerary / GenerateFailed / EditItinerary / Expense / Trips / OnTrip / Share / AreaMore / Map / Badges / Review / Pricing` 全部有落点；未知路由落 `ComingSoonPage`。新增的 `Badges`、`Review`、`Pricing` 已超出原始 16 屏。

导航不是「四 tab」而是 **五 tab / 五条栈**：地图、行程、规划、费用、我的；`APP_NAV` 是规划主链栈。[`entry/src/main/ets/common/constants/AppNav.ets:26-57`][`pages/Index.ets:15`]

### 1.5 数据流

**行前生成：**

```text
屏2 一句话/表单
  → PlanDraft（草稿）
  → 屏3 四题偏好
  → PlanRepository.loadSpots/loadAreas
       ├─ 种子库（北京/上海/广州/深圳/杨凌）
       ├─ 京都 mock（仅 USE_MOCK_DATA 打开时）
       └─ 非内置城市 → MapKitCityStore（30min 内存缓存，不落库）
  → PlanAutoPick.pickSpots / pickArea
  → 屏4/5 人工调整
  → 屏6 LlmClient.generateTrip
       ├─ devLocal: MockLlmTransport（按参数确定性合成 Trip）
       └─ BFF: HttpLlmTransport → POST /v1/trip/generate
  → TripParser（逐字段守卫）
  → TripEnrich（坐标/地址/开放时间回填）
  → TripDao.saveTrip
  → 屏8
```

**行中：**

```text
屏15 OnTripPage
  → ArrivalWatcher（仅前台 locationChange，10s/20m）
  → WeatherStore → Open-Meteo（首站坐标 0.1°，30min 缓存）
  → TripSignals.suggest（偏离 / 落后 / 有雨，一次一条）
  → 用户确认
       ├─ 跳过：ReplanClient（云函数，可选）→ SkipPlanner.plan（本地兜底 + 排程）
       └─ 顺延：SkipPlanner.shiftRemaining（纯算术，不调模型）
  → TripDao.saveTrip + 快照 + canUndo
```

**行后：**

```text
checkin（活动打卡，v8 起带 uuid/坐标/距离/source）
  → BadgeDao.listMine / listForTrip（JOIN activity + trip）
  → BadgeBoard.buildBadgeBoard（同城同名合并、到站升级、城市分组）
  → BadgePage（勋章墙 + 城市套章）/ TripReviewPage（回顾 + 海报 + 周年）
```

### 1.6 数据层

`DB_VERSION = 10`。[`entry/src/main/ets/data/DatabaseHelper.ets:35`]

- 表：`trip / trip_day / activity / meal / spot / area / expense / checkin`，共 8 张业务表；`spot` 与 `area` 是内置资产库。[`DatabaseHelper.ets:10-19`]
- 迁移：`oldVersion === 0` 建表，随后 `oldVersion < N` 累积式逐级补列；v2（trip.user_id）、v4（expense.activity_id）、v5（spot.confidence）、v6（meal.time）、v7（trip.category_budget）、v8（checkin 凭证 6 列）、v9（孤儿清理）、v10（trip.pass_id）。[`DatabaseHelper.ets:205-265`]
- 写通道：`DatabaseHelper.write` 单 Promise 链串行 + 事务 + 回滚。[`DatabaseHelper.ets:166-186`]
- 级联：`deleteTrip` 在确认 `trip` 属于当前 uid 后，显式删 `checkin/expense/meal/activity/trip_day`。[`entry/src/main/ets/data/TripDao.ets:293-317`]
- 分区：`checkin` / `expense` 带 `user_id`；`trip` 带 `user_id` 并在读侧过滤。[`CheckinDao.ets:30-48`][`TripDao.ets:89-115`]
- 种子：北京/上海/广州/深圳各 32 景点、36 区域；杨凌 10 景点、5 区域；JSONL 全部可解析。[`entry/src/main/resources/rawfile/seed/`]

---

## 2. 模块进度矩阵

**状态定义**：完成 / 进行中 / 仅设计 / 未开始。  
**证据等级**：

- **E4 真机走通**：有真机截图/日志记录（`Docs/INIT_REPORT.md` 等），本次未复跑。
- **E3 构建/设备单测**：有 HAP 构建或真机 hypium 记录，本次未复跑。
- **E2 离线/静态**：本次实际运行的离线断言或静态尺通过。
- **E1 代码存在**：有实现，但无测试、无运行证据。
- **E0 仅文档**：只有方案/清单，无代码。

### 2.1 总表

| 模块 | 状态 | 证据等级 | 关键证据 | 边界 / 备注 |
|---|---|---|---|---|
| 工程基座 / 设计 tokens / 14 把静态尺 | 完成 | E2（本次实跑） | `tools/audit_*.py` 14 把全 `rc=0`；`design/*.ets` | 尺绿只代表「没有违规」，不代表功能存在；见 §4 |
| RDB / DAO / 种子 / 迁移 / 级联 | 完成 | E2/E3；v10 仅 E1 | `DatabaseHelper.ets:35,205-265`；`TripDao.ets:293-317`；`DataSeeder.test` 8 例 | v10 新增 `pass_id` 未在真机旧库实测；文档仍写 v9 |
| 屏 1–9 主链 / 生成编排 | 完成 | E4 | `AppRouter.ets:51-71`；INIT_REPORT 主链 8 屏实走 | 「跨天移动」未实现（见 §3） |
| 一句话本地解析 + 自动选点/住宿区 | 完成 | E4 + E2 | `utils/TripIntentParser.ets`；`utils/PlanAutoPick.ets`；`verify_trip_intent.sh 104/104` | 解析器只覆盖常见表达，非穷尽 |
| 任意城市 Map Kit | 完成 | E4 + E2 | `PlanRepository.ets:27-32`；`MapKitCityStore.ets:38-113`；`verify_map_city.sh 66/66` | 西安完整生成；成都只到屏 5；评分/预约字段不存在 |
| ICS 导出 / 日历同步 / 分享 | 完成 | E4/E3 + E2 | `ShareExporter.ets`；`CalendarSync.ets`；`IcsBuilder.test` 9 例 | 日历写入需明示同意；导出有付费门禁 |
| 行中天气 | 完成 | E4 | `WeatherClient/WeatherParser/WeatherStore`；INIT_REPORT 真机 `19°/4°` | Open-Meteo 失败静默；跨时区未处理 |
| 行中三信号 | 完成 | E2/E3 + BEHIND E4 | `data/TripSignals.ets:82-114`；`WeatherSignals.test` 10 例；`verify_weather_logic.sh 116/116` | 偏离/有雨/顺延未真机触发，只有离线/单测 |
| 到站检测 + 凭证打卡 | 进行中 | E1/E3 | `common/location/ArrivalWatcher.ets:25-134`；`OnTripPage.ets:805-843` | 前台检测代码与权限降级完整；**真机到站打卡未验**，当前取证都是 manual |
| 跳过 / 顺延 / 撤销 | 完成 | E2/E3 + 跳过/撤销 E4 | `SkipPlanner.ets:229-297,347-414`；`OnTripPage.ets:347-479`；`SkipPlanner.test` 12 例 | 顺延端到端未拍到；云函数未配置时走本地兜底 |
| 行后勋章墙 / 套章 / 回顾 / 海报 / 周年 | 完成 | E4 + E2 | `utils/BadgeBoard.ets:57-116`；`BadgeDao.ets:18-37`；`TripReviewPage.ets:162-190`；`verify_trip_review.sh 57/57` | 周年横幅、套章集齐态、海报失败降级未真机 |
| 桌面卡片 / 小艺 Skill / Account Kit | 完成 | E4 | `widget/pages/TodayTripCard.ets`；`entry/skills/...`；`module.json5:13-22` | 平台侧「已上架」仅文档自述；卡片衬线拿不到 |
| 真实 LLM 生成（BFF） | 进行中 | E1 | `LlmClient.ets:208-333`；`bff/src/routes/trip.js:29-40,72-91` | prompt 退化、无 BFF 测试、无真实调用记录 |
| 商业化（IAP / 权益 / 付费页） | 进行中 | E1 | `EntitlementStore.ets`；`IapStore.ets`；`PricingPage.ets`；`bff/` | IAP 校验是桩；BFF 未入库；隐私文本未同步 |
| 家族 UI 契约 v2 | 进行中 | P1 部分 E2；P2/P3 E0 | `HdsChrome.ets:38,83`；`MotionTokens.ets:33-46`；`Docs/家族UI契约对齐方案-2026-11-02.md` | 顶栏 blur 值改了但 `scrolled` 无调用点；P2 家族件、P3 动效未开始 |
| 动效层 | 未开始 | E1（代码为 0） | `MotionTokens` 零消费；pages/components 中 `.animation(`/`animateTo`/`.transition(` 0 处 | 与用户「GSAP 级动效」长期偏好差距最大的一项 |
| 实况窗 / 通知 | 仅设计 | E0 | `Docs/实况窗方案.md:3` 明写「未实施」 | 无任何 LiveView/Notification 代码 |
| 地理围栏 / 后台唤醒 | 仅设计（T1 替代已实现） | E0 / T1 E4 | `Docs/围栏与后台唤醒开通清单.md`；`ArrivalWatcher` 只前台 | AGC 审核中；T2 系统围栏未做 |
| 发布 / 上架 / 合规 | 未开始 | E0 | 无 release 签名；无商店物料；隐私文本与 BFF 冲突 | 见 §4 R2 |
| 宽屏 / md 适配 | 进行中 | E1/E3 | `utils/responsive.ets`；`Responsive.test` 5 例 | README 明确「只有代码通路，无实拍证据」 |

### 2.2 行前：已闭环，但两处声明与代码不符

**真实完成的部分：**

- 屏 2 的一句话解析是**本地确定性解析**，不联网、不调模型，输出目的地/日期/天数/人数/预算/风格/住宿档/交通/节奏/兴趣标签与解释 notes。[`utils/TripIntentParser.ets:1-41`]
- 自动选点与住宿区预选共用同一套规则：节奏档 `PaceRule.dailyCap`、候选池、单日装站预算、住宿区 `rankAreas`。[`utils/PlanAutoPick.ets:29-80`]
- 屏 5「帮我选」按与所选景点的平均直线距离排序，不谎报导航里程。[`pages/StayPickPage.ets:128-140`]
- 任意城市：种子库优先，空则 Map Kit；`searchByText` 必须带 `cityId + isCityLimit`，地址归属校验用 `locality/adminLevel2/adminLevel3`，结果 30 分钟内存缓存、不写 RDB。[`data/MapKitCityStore.ets:49-113`][`utils/MapCityMapper.ets`]
- Map Kit 失败有用户可读出口：屏 4 空态 + 重试/换城市；屏 7 标题「地图数据没取到」；底图初始化失败显示「底图没出来；行程内容不受影响」。[`components/TripMapView.ets:287-315`]
- 负载三态由 `DayLoadCalc` 计算「停留 + 通勤」占用分钟，窗口 10 小时，80% 标黄、超窗标红。[`utils/DayLoad.ets:36-70`]
- 屏 9 拖拽改序、删除、替换、补选、撤销、整日回写已实现。[`pages/EditItineraryPage.ets:241-262,672-688`]

**与 README 不符的两处：**

1. **「跨天移动」不存在。** README 写「拖拽改序与跨天移动」，但 `EditItineraryPage` 的 `dayIndex` 是 `@Prop`，编辑与保存只操作当前日（`trip.days[this.dayIndex].activities`），`onItemDrop` 只做同日内 `move`；`INIT_REPORT` 自己把「拖到第 2 天 · 余量 3.5 小时」标为 `⬜ 未做`。[`README.md:13`][`pages/EditItineraryPage.ets:85-90,254,682-688`][`Docs/INIT_REPORT.md:1885`]
2. **「屏 1–屏 16 都在 pages」不准确。** 屏 10 / 14 是 `ItineraryPage` 内的两个 `bindSheet`，屏 13 是 `widget/`；`pages/` 实际 23 个文件，不是 16 个独立屏。[`README.md:28-30`][`pages/ItineraryPage.ets:1367,1377`]

### 2.3 行中：三信号与重排确实接通，但真机取证不完整

代码链路完整，不是「只设计」：

- `TripSignals.suggest` 先按 `currentKey` 定位当前站（由屏 15 的 `NodeOwe` 统一判定），再依次判偏离 → 落后 → 有雨；阈值分别为 1000m / 10min、30min、60% 降水。[`data/TripSignals.ets:67-114`]
- 「忽略」只静默同类 30 分钟，换类立即重判；静默态只在本页面实例内。[`pages/OnTripPage.ets:98,759-787`]
- `SkipPlanner.plan` 接收可选的云函数决策；决策不合规或未配置时走本地兜底，绝不因网络失败阻塞跳过。[`ai/ReplanClient.ets:19-75`][`data/SkipPlanner.ets:156-204`]
- `shiftRemaining` 是确定性算术：未开始、非交通/住宿、未预约、非跳过占位才移动；先 +delta，再避锚点（预约/交通/住宿/有时刻餐次/当前站剩余时段），越过 23:59 的项保留原时间并标「待调整」。[`data/SkipPlanner.ets:229-346`]
- 跳过与顺延共用快照/落库/撤销/卡片刷新：`commitDay` 写快照，`undoSkip` 写回。[`pages/OnTripPage.ets:347-479`]

真机取证的真实边界（INIT_REPORT §5ci 续 46 自述）：

- 「落后 → 跳过 → 撤销」有画面；「顺延」按钮没有端到端画面（当天已无未开始站点，信号退化为跳过）。
- 「有雨」未真机触发（当日降水 0%）。
- 「偏离」未真机触发（当前节点是晚餐无坐标，`ArrivalWatcher` 不启动）。
- 到站打卡没有真机证据：行后回顾取证时两条打卡均为 `source='manual'`。[`Docs/INIT_REPORT.md:3588-3595,3730`]

结论：**行中三信号/重排「代码完成、离线与单测覆盖、主路径真机验证部分完成」**；不能写成「三条信号全部真机验证」。

### 2.4 行后：真实、可回看，但有三个未拍到的边界

- **勋章不建表**：`BadgeDao` 从 `checkin JOIN activity JOIN trip` 取证据，餐次打卡因没有 activity 行自然落选；`BadgeBoard` 同城同名合并、到访次数累计、任一次到站即升级为到站章。[`data/BadgeDao.ets:1-37`][`utils/BadgeBoard.ets:57-116`]
- **城市套章**：以该城种子景点全集为「套」，只统计名字精确落在种子清单里的章；`total=0` 不画。[`utils/CityStamps.ets`][`pages/BadgePage.ets:158-172`]
- **回顾**：按天回放真实打卡，孤儿证据按「activity 找不到就丢弃」兜底；花费取 `ExpenseDao.totalOfTrip`；不重复统计。[`utils/TripReview.ets:1-60`]
- **海报**：`createFromBuilder` 离屏快照 320vp → JPEG 92 → `cacheDir` → ShareKit；失败才降级为文本摘要。[`pages/TripReviewPage.ets:162-190`][`data/ShareExporter.ets:64-74`]
- **周年**：按「月日」比较，支持 12-30 → 01-02 跨年；只命中已结束且跨年的行程。[`utils/TripReview.ets`][`pages/TripsPage.ets:121-128,351-400`]

真机已验证：回顾页、海报分享（1100×878 / 44.9KB）、城市套章进度、可回顾入口；未验证：周年横幅画面、套章集齐态、海报失败降级、浅色档、多城市分组、到站打卡正数分支。[`Docs/INIT_REPORT.md:3699-3732`]

### 2.5 数据层：完整，但 v10 与文档版本号未对齐

- 迁移链是累积式，不是 `=== N`；v1 老库可逐级升到 v10。[`DatabaseHelper.ets:205-265`]
- 级联删除在 `deleteTrip` 显式完成；v9 只做一次性孤儿清理。[`TripDao.ets:293-317`][`DatabaseHelper.ets:137-147`]
- 种子数据行数与 README 一致：四城各 32/36，杨凌 10/5；JSONL 全部合法。
- **问题**：`DB_VERSION = 10`（v10 加 `trip.pass_id`），但 README 仍写 9；`INIT_REPORT §5ci 续 83` 明确说「没有装这份包去动真机库」，所以 v9→v10 迁移**没有真机验证**。[`README.md:20`][`DatabaseHelper.ets:35,149-151`][`Docs/INIT_REPORT.md:5337-5340`]

### 2.6 真实生成与商业化：当前最薄的两块

**生成链路：**

- 端侧 `LlmClient.generateTrip` 仍保留「失败重试 1 次」和 401 重新激活；传输选择由 `MockConfig.USE_MOCK_DATA` 或 `DEV_SKIP_BFF && BFF_BASE_URL 为空` 决定。[`ai/LlmClient.ets:335-383`]
- 工作树 `ApiConfig` 的 `BFF_BASE_URL` 为空、`DEV_SKIP_BFF = true`，因此**当前本地构建默认走 `MockLlmTransport`**，不是真实模型。[`common/config/ApiConfig.ets:50-66`][`ai/LlmClient.ets:344-348`]
- `MockLlmTransport` 会按参数合成合法 Trip，走完整「合成 → TripParser → Trip」链路；`overview.summary` 带「离线合成」字样。[`ai/LlmClient.ets:75-157`]
- 真实路径 `HttpLlmTransport` 只把目的地/日期/人数/预算/风格/区域名/景点名发给 BFF，不再发送端侧 `PromptBuilder` 的规则与 Schema。[`ai/LlmClient.ets:221-314`]
- BFF 的 `buildSystemPrompt` 只有一句「你是旅行规划助手…JSON 格式」，`buildUserPrompt` 只拼六个字段；`response_format` 是 `json_object`，不是 `json_schema`。[`bff/src/routes/trip.js:29-40,72-91`][`bff/src/services/llm.js:10-15`]
- 端侧 `PromptBuilder.systemPrompt` 的 17 条规则（天数/日期/交通/枚举/必去/餐次/金额/入口/风险/引号/地址回填/七键/开放时段/预约/单日不拆/10 小时窗口）与 `TripSchema.TRIP_JSON_SCHEMA` 仍在，但**只被测试引用，生产路径不再 import**；`grep` 结果只有自身与注释。[`ai/PromptBuilder.ets:30-66`][`ai/TripSchema.ets:23`]

**BFF 的两个结构性问题：**

1. **幂等缓存返回错对象。** `trip_request.params_json` 存的是请求参数；命中幂等时却 `JSON.parse(existing.params_json)` 直接当 `trip` 返回。[`bff/src/middleware/idempotency.js:14-17`][`bff/src/routes/trip.js:24-27`] 客户端 `TripParser` 必然报「days 缺字段」，而重试又复用同一个 `Idempotency-Key`，形成「越重试越失败」。
2. **BFF 没有任何测试。** `bff/package.json:7-10` 只有 `start/dev/migrate`，没有 `test`；仓库内无 BFF 测试文件。与之对比，`cloud/replanDay` 有 15 个 `node:test` 且本次全过。

**商业化：**

- 端侧权益链完整：`DeviceActivator` → `/v1/device/activate` → `DeviceTokenStore` + `EntitlementStore`；`canGenerate`/`canExport` 门禁接入屏 6、屏 14、屏 16、回顾页。[`data/DeviceActivator.ets:30-104`][`data/EntitlementStore.ets:103-131`][`pages/GeneratingPage.ets:99-127`][`pages/SharePage.ets:114-119`]
- 付费页与 IAP 调用完整：通行证 `NONCONSUMABLE`、订阅 `AUTORENEWABLE`、恢复购买、`finishPurchase`。[`data/IapStore.ets:50-247`][`pages/PricingPage.ets:39-82`]
- **但服务端校验是桩**：`verifyPurchase` 无条件返回 `{ verified: true }`，`IAP_VERIFY_URL` 未使用；`/v1/iap/notify` 只打印请求体，不验签；`/v1/iap` 路由未挂 `authMiddleware`；JWT 有硬编码兜底 `youjing-bff-dev-secret`。[`bff/src/services/iap.js:1-5`][`bff/src/routes/iap.js:85-92`][`bff/src/index.js:30`][`bff/src/middleware/auth.js:3`]
- **启动竞态**：`Index.bootstrap` 不 `await` `DeviceActivator.activate` / `EntitlementStore.init`；首次联网慢时用户点生成可能读到空权益缓存，直接跳 `Pricing`。[`pages/Index.ets:101-115`][`pages/GeneratingPage.ets:99-127`]
- **定价文本与实现不符**：`PricingPage` 写「本机规则引擎生成」，但仓库内没有规则引擎生成器；`grep` 只命中这一句文案。商业化方案写「20 次/月」，BFF 实际是 `DAILY_CAP = 20` 的**每日**上限。[`pages/PricingPage.ets:120`][`Docs/商业化方案.md:19-21`][`bff/src/services/quota.js:1,18-31`]

### 2.7 平台能力与设计系统

- **Account Kit**：`AccountStore.login` 取 UnionID，失败不抛错、退回游客分区；游客数据归户有 `adoptGuestData`。[`data/AccountStore.ets`][`data/TripDao.ets:232-249`]
- **小艺 Skill**：`module.json5` 注册 `youjing-plan-trip`；`entry/skills/youjing-plan-trip/SKILL.md` 与 `PlanTripSkill.ets` 入库；`EntryAbility` 启动时打印注册数量。[`entry/src/main/module.json5:13-22`][`entry/src/main/ets/entryability/EntryAbility.ets:367-370`]
- **日历 / 分享 / 卡片**：均走官方 Kit；卡片 `FormExtensionAbility` 与 2×2/2×4 同组件自适应。[`data/CalendarSync.ets`][`data/ShareExporter.ets`][`widget/TodayTripFormAbility.ets`]
- **设计系统**：8 个 token 文件；14 把静态尺本次全 `rc=0`。但：
  - `HdsChrome` 的 `blurRadius` 已是 `scrolled === true ? 50 : 0`，但**全仓没有任何调用点传 `scrolled`**；且 `scrollEffectStyle` 默认已在滚动时启用，所以顶栏模糊实际恒为 0。[`design/HdsChrome.ets:38,55,83`] 这与 `Docs/家族UI契约对齐方案-2026-11-02.md:34` 的判断一致，CHANGELOG 也自认「T4 16 个页面没有一个传 `scrolled`，像素证据为零」。[`CHANGELOG.md:22-26`]
  - `ShadowTokens` 仍保留 4 处 `this.isDark ? { radius: 0 } : ...` 的深色归零分支；契约 v2 计划反转这条判据，但 P1 批次一未包含 T2。[`pages/EditItineraryPage.ets:328`][`pages/MapPage.ets:416`][`pages/StayPickPage.ets:363`][`pages/TripsPage.ets:327`]
  - `SpaceTokens` 仍是旧命名（`xs/sm/md/lg/xl/twoXl/...`），未按契约 v2 改名；`Docs/家族UI契约对齐方案-2026-11-02.md` 把这项列为最贵的批次二工作。
  - **P2 家族件库（`BaseCard`/`Pressable`/`EmptyState`/`Skeleton`/`SeparatorLine`/`Avatar`）一个文件都没有**；P3 的 `longTake/`、`buildPageTransition`、`navDestinationId` 全仓 0 处。[`components/` 目录清单][`grep` 结果]
  - **动效为 0**：`pages/` + `components/` 中 `.animation(` / `animateTo(` / `.transition(` 合计 0 处；`MotionTokens` 消费点 0 处。静态尺「0 违规」是因为没有用法，不是做完了。

### 2.8 测试与质量门

**本次实际执行并通过：**

| 脚本 | 结果 |
|---|---|
| `tools/verify_map_city.sh` | `PASS 66/66` |
| `tools/verify_trip_intent.sh` | `PASS 104/104` |
| `tools/verify_trip_review.sh` | `PASS 57/57` |
| `tools/verify_replan_logic.sh` | `SKIP_PLANNER_OK cases=74` + `REPLAN_PARSER_OK cases=26` |
| `tools/verify_weather_logic.sh` | `WEATHER_SIGNALS_OK cases=116` |
| `cloud/replanDay` `node --test` | `tests 15 / pass 15 / fail 0` |
| 14 把静态尺 | 全部 `rc=0`；`audit_type` 仅报 `PricingPage.ets:195` 一处 14px 图标待裁决 |
| `audit_motion --selftest` | 30 条 PASS |
| `audit_contrast --selftest` | 4 条 PASS |
| `audit_skip_worktree --selftest` | 4 条 PASS |

**本次未能执行：**

- `assembleHap` / test HAP 构建：未重编译（只读分析，不写构建产物）。
- 真机 hypium：无设备；源码静态计数 `ohosTest` 189 个 `it(...)`，`entry/src/test` 另有 1 个模板用例；与 README 的 191、CHANGELOG 某处的 192 不一致。真实通过数必须以真机复跑为准。
- `audit_contrast.py` 真机两档、`verify_scroll_clearance.py`、`verify_dock_tabs.sh`：都需要设备/dump/截图。
- BFF 集成、IAP 真机购买、MapKit 空白 profile 降级：无环境/无凭证。

**测试覆盖的结构性盲区：**

- `ohosTest` 只有 28 个模块且全部注册进 `List.test.ets`；但 `Account.test.ets:7-14` 明说 RDB/preferences 在该进程不可用，所以 `DatabaseHelper`、`TripDao`、`CheckinDao`、`ExpenseDao`、`BadgeDao`、`EntitlementStore`、`IapStore` 的行为**没有自动化用例**，只能靠真机 App 内验收。
- BFF 无测试；`HttpLlmTransport` 无测试；IAP/权益无测试；`MapKitCityStore` 的真实网络路径无测试（只有纯映射 `MapCityMapper` 的 6 例）。
- `LlmPipeline.test.ets` 仍 import `PromptBuilder` 与 `MockTrip`，测试的是旧端侧路径，不覆盖当前 BFF 传输。[`entry/src/ohosTest/ets/test/LlmPipeline.test.ets:7-14`]

---

## 3. 文档与代码偏差表

按影响从高到低排列。「文档」列给出具体条目，「代码事实」列给出证据。

| # | 文档声明 | 代码事实 | 影响 |
|---|---|---|---|
| 1 | README：**「纯 ArkTS 客户端，没有自建后端」「生成走 OpenAI 兼容接口（自带 Key）」** [`README.md:5-6`] | `bff/`（未跟踪）+ `cloud/replanDay/`（已跟踪）真实存在；端侧已切 BFF 中转，Key 在 BFF/云函数环境变量；`ApiConfig` 有 `BFF_BASE_URL`。[`bff/src/index.js:23-30`][`cloud/replanDay/index.js:228-266`][`common/config/ApiConfig.ets:50-66`] | 架构叙事错误；隐私/运维/成本判断都会跟着错 |
| 2 | README：**「ai/ 三层防线：提示词内嵌 Schema → response_format → TripParser」** [`README.md:22`] | 端侧只剩 `TripParser` 在生产路径；`PromptBuilder` 不再被 `LlmClient` import；BFF prompt 无 Schema、`response_format` 仅 `json_object`。[`ai/LlmClient.ets:18-32,208-333`][`bff/src/routes/trip.js:72-91`][`bff/src/services/llm.js:10-15`] | 真实生成质量/稳定性被高估；这是最大功能风险 |
| 2b | LLM 方案：**「HttpLlmTransport 直连」「当前默认 MockLlmTransport」「Key 在 ApiConfig / 上架前迁 HUKS」** [`Docs/LLM接入方案-2026-10-26.md:9-36`] | 当前传输是 BFF 中转，不再是 OpenAI 兼容直连；prompt 在 BFF 构建；Key 在 BFF/云函数环境变量；`ApiConfig` 只剩调试位。[`ai/LlmClient.ets:203-333`][`bff/src/services/llm.js:1-3`][`cloud/replanDay/index.js:228-245`] | 该方案已被商业化改造超越；路线 A/B/C 的决策记录不再对应代码 |
| 3 | README / 文档：**「DB_VERSION = 9」** [`README.md:20`] | `DatabaseHelper.ets:35` 是 **10**，v10 加 `trip.pass_id`；v9 是孤儿清理。[`DatabaseHelper.ets:137-151`] | 迁移验证口径错误；旧库升级风险被低估 |
| 4 | README：**「真机 191 例」**；CHANGELOG 另处写 **192/192** [`README.md:23,72`][`CHANGELOG.md:57`] | 静态计数 `ohosTest` 为 **189** 个 `it(...)`，`entry/src/test` 另有 1 个模板用例；28 个测试模块全部注册，无漏注册。[`entry/src/ohosTest/ets/test/List.test.ets:30-58`] | 质量基线不可信；发布验收无法对账 |
| 5 | README：**「MockConfig.USE_MOCK_DATA = true 会走离线合成」** [`README.md:55`] | 仓库默认 `USE_MOCK_DATA = false`；当前工作树实际靠 `DEV_SKIP_BFF = true && BFF 空` 才走 `MockLlmTransport`。[`common/config/MockConfig.ets:13-15`][`ai/LlmClient.ets:344-348`] | 读者会误判「打开一个开关就能 mock」；实际路径不同 |
| 6 | README：**「拖拽改序与跨天移动」** [`README.md:13`] | 只有同日 `move`；`dayIndex` 固定，保存只改当前日；`INIT_REPORT` 自己把「拖到第 2 天」标 `⬜ 未做`。[`pages/EditItineraryPage.ets:85-90,254,682-688`][`Docs/INIT_REPORT.md:1885`] | 宣称了不存在的核心交互 |
| 7 | README：**「pages/ 屏 1–屏 16」** [`README.md:28-30`] | 屏 10/14 是 `bindSheet` 面板，屏 13 是 widget；`pages/` 实际 23 个文件。[`pages/ItineraryPage.ets:1367,1377`][`widget/pages/TodayTripCard.ets:2`] | 目录说明与代码结构不符，误导新读者 |
| 8 | 隐私政策：**「本应用没有云端存储」「不上传任何服务器」「UnionID 只用于本机分区」** [`common/constants/LegalDocs.ets:27-44`] | BFF `/v1/device/activate` 实传 `deviceId` + `unionId`，服务端 `account` 表持久化；`/v1/trip/generate` 传目的地/日期/人数/预算/风格/景点名并落 `trip_request.params_json`；IAP 传 `purchaseToken` 并落订单表。[`data/DeviceActivator.ets:45-65`][`bff/src/db.js:9-88`][`bff/src/routes/trip.js:24-27`][`data/IapStore.ets:177-227`] | **合规事故级偏差**；上架/监管风险 |
| 9 | 商业化方案：**「免费档 = 本机规则引擎生成（零成本）」** [`Docs/商业化方案.md:19`] | 无规则引擎生成器；`grep` 只命中 `PricingPage` 的一句文案；真实路径是 mock 或 BFF LLM。[`pages/PricingPage.ets:120`] | 付费产品承诺无法兑现 |
| 10 | 商业化方案：**「订阅 20 次/月」**；`/v1/auth/login`、`/v1/iap/notify` 必须验签 [`Docs/商业化方案.md:21,113,181`] | BFF 是 `DAILY_CAP = 20` 的每日上限；无 `/v1/auth/login` 路由；`/v1/iap/notify` 只 `console.log`。[`bff/src/services/quota.js:1,18-31`][`bff/src/index.js:27-30`][`bff/src/routes/iap.js:85-92`] | 计费模型与契约不一致；服务端安全缺口 |
| 11 | 完成度评估：**「12,925 行 / 71 文件 / 66 例 / v5」**，结论「十阶段功能面全部落地」 [`Docs/完成度评估与待办清单-2026-10-25.md:5,29`] | 当前 25,635 行 / 129 文件 / 189 例 / v10；且此后又加了行中、行后、MapKit、商业化等切片。 | 该文档是历史快照；不能作为当前进度依据 |
| 12 | 行中方案：**「落后 = 最后一次打卡之后第一个未打卡站」**、离线断言 **102 条** [`Docs/行中智能方案.md:59-63,105`] | 代码已改为「当前节点由屏 15 统一判定后传 `currentKey`」；天气离线断言实际 **116** 条。[`data/TripSignals.ets:31-51,82-114`][`tools/verify_weather_logic.sh` 输出] | 方案文档落后于实现 |
| 13 | 任意城市方案：`verify_map_city.sh` **63 条** [`Docs/任意城市接入方案.md:85`] | 实际 **66** 条。 | 验收基线漂移 |
| 14 | 家族 UI 方案：**「下一步出 P1 实施计划」「未写一行 UI 代码」** [`Docs/家族UI契约对齐方案-2026-11-02.md:3`] | P1 批次一已提交：契约 blur 50、`MotionTokens`、`audit_motion`、`audit_fontfamily` 真解析；但 T4 页面接线、T2 阴影反转、T6 间距改名未做。[`CHANGELOG.md:9-80`][`design/HdsChrome.ets:38`] | 文档状态落后于 git；不过「像素证据为零」的自述是准确的 |
| 15 | README：`verify_mirror.sh` **2026-11-02 首跑 rc=0** [`README.md:74`] | 本次 `bash tools/verify_mirror.sh` **rc=1**：bash 3.2 + `set -u` 把全角右括号并入变量名，报 `SRC_DIR�: unbound variable`；`zsh` 下 `md5` 命令在函数内找不到。手工 `/sbin/md5` 复核：`design-v2` 三份逐字节相同，`design-v1` 四个哈希全部匹配冻结值。[`tools/verify_mirror.sh:60`] | 闸门本身不可执行；镜像内容其实是好的 |
| 16 | TECH_STACK：**「签名配置 无（signingConfigs 为空）」** [`Docs/TECH_STACK.md:23`] | HEAD 确为空；工作树因 `skip-worktree` 有本地调试签名与 `ApiConfig` 真值。 | 文档描述的是仓库版，不是当前机器状态 |
| 17 | ARCHITECTURE：**「pages 禁止 data/ai 直连」** [`Docs/ARCHITECTURE.md:13-14`] | `pages/` 有 59 处 data import、2 处 ai import；页面没有直接 SQL/HTTP，但仍直接依赖 DAO/LlmClient。 | 分层契约与实际灰区；影响可测试性 |
| 18 | 实况窗方案：**「未实施」**；围栏清单：**「T1 前台降级」** [`Docs/实况窗方案.md:3`][`Docs/围栏与后台唤醒开通清单.md:21-22`] | 代码中无 LiveView/Notification；`ArrivalWatcher` 只订阅前台 `locationChange`。 | 这两条是**诚实声明**，不是偏差；列在此处以正视听 |

---

## 4. 风险与缺口清单（按影响排序）

### R1 · 真实生成通道退化（Critical）

**为什么重要**：产品的核心卖点是「一句话成行程」。当前生产路径的 prompt 没有 Schema、没有景点/区域/节奏规则，模型输出与 `TripParser` 的严格契约（七键、枚举、`endTime > time`、天数一致）很容易不匹配；再加上幂等缓存 bug，失败重试几乎必然失败。

**证据强度：强。** 代码可直接证明：`PromptBuilder` 未被生产 import；BFF prompt 仅一句话；`response_format` 仅 `json_object`；幂等返回 `params_json` 当 `trip`。缺的是「真实端到端失败率」的实测数据。

### R2 · 商业化安全与合规不可上线（Critical）

**为什么重要**：IAP 服务端校验恒真、notify 不验签、JWT 有兜底密钥、`/v1/iap` 未挂统一鉴权（notify 完全不验），等于把付费权益交给客户端；同时隐私政策与 BFF 实际传输/存储直接冲突，属于上架阻断项。

**证据强度：强。** 桩函数与路由挂载是代码事实；隐私文本与 `DeviceActivator`/`db.js` 的字段可逐条对上。缺的是「是否真的准备在本版本收费」的产品决策。

### R3 · 在飞改动 + v10 未真机验证（High）

**为什么重要**：当前工作树 21 个修改文件 + 未跟踪 `bff/`，不是可复现版本；`DB_VERSION` 10 的迁移没有真机旧库验证；本次也没有重编译/真机单测。任何「全绿」结论都无法直接套到当前树上。

**证据强度：强（状态事实）+ 中（行为未验）。** `git status`/`git diff` 与 `INIT_REPORT §5ci 83` 都能证明。

### R4 · 宣称了不存在的「跨天移动」（High）

**为什么重要**：这是 README 三柱表里的行前能力，也是屏 9 的核心价值之一；用户按文档验收会直接判失败。

**证据强度：强。** `EditItineraryPage` 只操作当前日；INIT_REPORT 自己标 `⬜ 未做`。

### R5 · 文档系统性失真（High）

**为什么重要**：README、完成度评估、LLM 方案、商业化方案、家族 UI 方案各自描述不同年代的状态；测试数 189/191/192、DB 9/10、三层防线、20 次/月 vs 20 次/日，都会让后续决策与验收对错表。

**证据强度：强。** 逐条已在 §3 对照。

### R6 · 动效与家族 UI P2/P3 空缺（Medium-High）

**为什么重要**：`MotionTokens` 零消费、页面 0 个 `.animation`/`.transition`；顶栏磨砂值改了但门控没接线；P2 家族件库不存在。对「视觉完成度」和用户长期偏好的 GSAP 级体验，这是最大落差。

**证据强度：强（代码计数）。** 但这是设计系统/体验层，不是核心行程功能，故排在 R1–R5 之后。

### R7 · 平台侧能力只完成 T1（Medium-High）

**为什么重要**：实况窗、通知、系统地理围栏是「行中陪伴」的差异化；当前只有前台 `locationChange`，退后台/锁屏没有提醒。AGC 审核是外部阻塞，但产品叙事不能把它算作已完成。

**证据强度：强。** 代码中无 LiveView/Notification；`ArrivalWatcher` 头注释明确只前台；文档也自述未实施。

### R8 · MapKit 数据质量与未开通降级（Medium）

**为什么重要**：任意城市是行前扩张的关键，但 Map Kit 无评分、无预约、开放时间只展示「各天一致单时段」、远郊住宿区排序仍可能出错；未开通 Map Kit 的 profile 下，任意城市只能走 1004 失败出口，底图只能显示「底图没出来」。

**证据强度：中-强。** 探针报告与真机西安/成都取证充分；但「无 profile 的设备」没有实测。

### R9 · 测试盲区与计数漂移（Medium）

**为什么重要**：RDB/DAO/权益/IAP/BFF 没有自动化用例；`Account.test` 明说 ohosTest 进程无法用 RDB/preferences。核心数据层只能靠真机手测，回归成本高。

**证据强度：强。** 测试文件清单与注释可直接证明；189/191/192 的差异也已量化。

### R10 · 质量门可移植性（Medium-Low）

**为什么重要**：`verify_mirror.sh` 在当前 bash 3.2 下不可执行，README 却写 rc=0；`verify_dock_tabs`/`audit_contrast`/`verify_scroll_clearance` 依赖设备。把「脚本存在」当「闸门已跑」会制造假绿。

**证据强度：强。** 本次实跑 rc=1；手工 md5 复核内容正确。

### R11 · 发布物料与签名（Medium-Low，但阻断上架）

**为什么重要**：无 release 证书/商店物料/隐私合规复核；`build-profile.json5` 只有本地调试签名。功能做完也发不出去。

**证据强度：强。** HEAD 签名空；文档也未做 release 清单。

---

## 5. 下一步建议（按价值/成本排序）

### 1）先修真实生成：把「三层防线」搬回 BFF（P0，1–2 天）

**做什么：**

1. 在 BFF 复用端侧 `PromptBuilder.systemPrompt()` 的 17 条规则与 `TripSchema.TRIP_JSON_SCHEMA`；`buildUserPrompt` 补齐 `pace`、`stayTier`、`transit`、景点 priority/时长/标签/预约/开放时间/坐标、住宿区档位与通勤字段。
2. 把 `bff/src/services/llm.js` 的 `response_format` 从 `json_object` 升级为 `json_schema {strict:true}`（上游不支持时，至少保留 `json_object` + 服务端 `TripParser` 等价校验）。
3. 修 `idempotency.js:14-17`：新增 `trip_json` 列，成功时写入 `JSON.stringify(trip)`，命中时返回 `trip_json`；或直接返回上一次的完整响应体。同步修 `trip.js` 的 INSERT/UPDATE。
4. 给 BFF 加 `node:test`（不引新框架）：覆盖 200 正常、402 配额、401 票据、409 幂等、上游 5xx、幂等命中返回 trip。

**验收：**

- `curl` 一次真实 DeepSeek 生成，端侧 `TripParser` 一次通过；连续两次同 `Idempotency-Key` 第二次返回同一 trip。
- 保留 mock 默认，真实端点只在本地 `ApiConfig` 打开；`DEV_SKIP_BFF` 不进发布包。

**为什么排第一**：这是产品核心价值；成本低（主要是搬代码 + 一个测试文件），收益最大。

### 2）商业化二选一：上线补齐 / 不上线摘除（P0，0.5–3 天）

**上线路线：**

- `bff/src/services/iap.js` 接真实华为 IAP 校验（`IAP_VERIFY_URL` + `purchaseToken` + `productId`），校验订单归属与商品类型；失败返回 `verified:false`。
- `/v1/iap/notify` 加华为签名校验、幂等、订单状态机（续订/退款/撤单）。
- `auth.js` 去掉兜底 `JWT_SECRET`，启动时缺环境变量直接 `exit(1)`；`index.js` 给 `/v1/iap` 挂 `authMiddleware`。
- `LegalDocs` 增加「BFF / 设备标识 / UnionID / 购买凭证 / 云端保留期限 / 删除请求」条目；`CONSENT_VERSION` 抬到 v3；补 BFF 账号删除接口。
- 修 `Index.bootstrap` 的权益初始化竞态：`await` 激活/权益，或在 `canGenerate` 前做一次同步兜底。

**不上线路线：**

- 本版本隐藏 `Pricing` 入口与 `canGenerate/canExport` 门禁；`DEV_SKIP_BFF` 保持 `true` 只用于本地；README/商业化方案明确「本期不收费」。

**验收：** 上线路线用一次真机购买 + 一次恢复购买 + 一次退款/续订通知；不上线路线确认所有付费入口不可达、隐私文本与代码一致。

**为什么排第二**：它决定能不能发版；不做决策会持续产生半成品代码与合规风险。

### 3）同一棵树重跑发布闸门并回写真实数字（P1，0.5–1 天）

**做什么：**

1. 先处理 21 个在飞文件：能提交的按主题提交，暂不能提交的 `git stash` 或移到独立 worktree；确保分析/验收对象是同一棵树。
2. `DEVECO_SDK_HOME=/Applications/DevEco-Studio.app/Contents/sdk` 跑主 HAP + `entry@ohosTest` 双构建。
3. 真机跑 hypium，记录真实 `Tests run / Pass`；同时做一次 v9 旧库 → v10 的安装升级，确认 `pass_id` 列、孤儿清理、种子幂等。
4. 把 README/CHANGELOG 的 191/192、DB 9、`verify_mirror rc=0` 改成实测值；`verify_mirror.sh:60` 改 `${SRC_DIR}` 并把 `md5` 调用改成 `"$MD5"`。

**验收：** 一份带时间戳的验收记录：双 HAP BUILD SUCCESSFUL、真机测试全绿、v10 迁移日志、14 把尺 + 5 套离线输出。

**为什么排第三**：没有这一步，后面所有「已完成」都只是文档自述。

### 4）补齐/撤回「跨天移动」与顶栏磨砂两条可见承诺（P1，1–2 天）

**跨天移动（二选一）：**

- 实现：在屏 9 增加「移到 Day N」入口（长按拖到日头或详情面板选择目标日），复用 `TripDay` 的 `activities` 重排 + 时间槽重算；或者
- 撤回：把 README:13 的「跨天移动」删掉，避免验收对不上。

**顶栏磨砂：**

- 给 `ChromeSpec.scrolled` 接线：在 16 个 push 页 + Index 4 个 tab 的根滚动容器上，用 `onDidScroll`/`currentOffset` 的**绝对偏移**驱动 `scrolled = offset > 0`，再传给 `HdsChrome.bar`；或
- 如果本期不做，明确把「顶栏 blur 50」标为「值已对齐、门控未接」，不要让静态尺的绿掩盖像素为零。

**验收：** 屏 9 跨天移动后另一天的站数/时刻正确；顶栏滚动前后同机位截图能看到模糊差异。

### 5）把「行中到站」补成真机闭环（P1–P2，0.5–1 天）

**做什么：**

- 选一条今天、首站有坐标的行程；前台授予定位；走到 >1km 外再靠近站点，确认 `Arrived` 行出现、`evidenceNow` 返回非空、`source='arrival'` 落库、勋章显示「到站打卡」。
- 同时补一条「有雨」信号的可控触发：在 `WeatherStore` 的缓存/测试注入里造 70% 降水，验证建议条文案与「跳过」动作；「偏离」用 `lastFix` 注入模拟坐标。
- 把这三条加入 `WeatherSignals.test` 或新增 `OnTripArrival.test`（纯逻辑可测部分）。

**验收：** 真机截图 + `checkin` 表 `source` 查询 + 建议条动作日志。

**为什么排第五**：它不阻塞发版，但决定「行中三信号」能否从「代码完成」升级为「产品可信」。

---

## 6. 本次执行的验证与未验证

### 6.1 已执行

| 项 | 结果 |
|---|---|
| 结构盘点 | 129 个 `.ets` / 25,635 行；23 个 page、10 个 component、25 个 data、25 个 utils、9 个 model、8 个 design |
| 种子数据 | 四城 32 景点/36 区域；杨凌 10/5；10 个 JSONL 全部合法 |
| 5 套离线断言 | 66 / 104 / 57 / 74+26 / 116 全绿 |
| 云函数单测 | 15/15 通过 |
| 14 把静态尺 | 全部 `rc=0`；`audit_type` 1 条待裁决（`PricingPage.ets:195`） |
| 3 个尺自检 | `audit_motion` 30、`audit_contrast` 4、`audit_skip_worktree` 4 全 PASS |
| 镜像一致性 | `design-v2` 三份逐字节相同；`design-v1` 四个 md5 与冻结值一致（手工复核） |
| 文档/代码对照 | 19 条偏差已列表 |

### 6.2 未执行 / 未验证

| 项 | 原因 | 结论 |
|---|---|---|
| `assembleHap` 主包/测试包 | 只读分析，不写构建产物 | **ArkTS 零 error 未独立复核**，仅能引用 README/CHANGELOG |
| 真机 hypium | 无设备 | **189/191/192 的真实通过数未复核** |
| v9→v10 迁移 | 无真机旧库 | **v10 迁移未验证**（代码层是增列 + 幂等） |
| `audit_contrast` 17 屏 | 需 dump + 截图 | 未复跑 |
| `verify_scroll_clearance` | 需设备 | 未复跑 |
| `verify_dock_tabs.sh` | 需设备/产物 | 未复跑，脚本首行即提示设备离线 |
| BFF 真实生成 | 无 BFF 部署/Key | 未验证 |
| IAP 购买/恢复/通知 | 无 AGC 商品/凭证 | 未验证；且服务端是桩 |
| Map Kit 无 profile 降级 | 无空白签名环境 | 未实测；代码有 1004/底图失败出口 |
| md/宽屏实拍 | 本机 sm | 未验证 |

---

## 附录 A. `ohosTest` 用例清单（28 个模块，全部注册）

| 文件 | `it(...)` 数 | 主要覆盖 |
|---|---:|---|
| `TripParser.test.ets` | 15 | 三层防线第三层：逐字段/枚举/天数/日期/时间 |
| `TodayPlan.test.ets` | 12 | 今日行程取数、日期窗口、卡片数据 |
| `SkipPlanner.test.ets` | 12 | 跳过/顺延/锚点/溢出/撤销快照 |
| `IcsBuilder.test.ets` | 12 | ICS 事件、转义、文本摘要 |
| `WeatherSignals.test.ets` | 10 | 天气解析、三信号阈值、顺延 |
| `BadgeBoard.test.ets` | 10 | 勋章合并/到站升级/城市分组 |
| `TripIntent.test.ets` | 9 | 一句话解析、日期/人数/预算/别名 |
| `DataSeeder.test.ets` | 9 | 种子解析、坏行、枚举白名单 |
| `Geo.test.ets` | 8 | 距离、可用坐标、到站半径 |
| `DisplayText.test.ets` | 8 | 文案格式化/截断 |
| `DayLoad.test.ets` | 7 | 负载三态 |
| `MapStops.test.ets` | 7 | 地图落点装配/分组/连线 |
| `NavStackRouting.test.ets` | 7 | 五 tab/五栈/深链归属不变量 |
| `MapCityMapper.test.ets` | 6 | 任意城市映射/去重/区县/归属 |
| `LlmPipeline.test.ets` | 6 | 旧端侧 Prompt + Mock 闭环 + 重试耗尽 |
| `StyleConfig.test.ets` | 6 | 选项值/默认值/枚举同源 |
| `TripReview.test.ets` | 6 | 回顾计数/孤儿/周年/套章 |
| `PromptContract.test.ets` | 5 | Prompt/Schema/模型枚举同源（**测的是已不用于生产路径的 PromptBuilder**） |
| `ReplanParser.test.ets` | 5 | 云函数决策守卫 |
| `Responsive.test.ets` | 5 | 断点/宽度 |
| `TripEnrich.test.ets` | 5 | 地址/坐标/开放时间回填 |
| `CategoryBudget.test.ets` | 4 | 分类预算 |
| `FailureCopy.test.ets` | 4 | 错误码文案 |
| `TodayCard.test.ets` | 4 | 桌面卡片数据 |
| `TransitSymbol.test.ets` | 4 | 通勤图标 |
| `PlanDraft.test.ets` | 3 | 草稿默认值/过期日期 |
| `YanglingSeed.test.ets` | 3 | 杨凌种子 |
| `Account.test.ets` | 1 | 游客兜底（**不含 RDB/preferences**） |

合计 **189** 个 `it(...)`；`entry/src/test/LocalUnit.test.ets` 另有 1 个模板用例。`List.test.ets:30-58` 逐个调用 28 个模块，无漏注册。

## 附录 B. 证据路径速查

| 主题 | 文件 |
|---|---|
| 架构/技术栈 | `Docs/ARCHITECTURE.md` / `Docs/TECH_STACK.md` |
| 原始需求/16 屏 | `Docs/有径·App开发文档.md` |
| 历史完成度 | `Docs/完成度评估与待办清单-2026-10-25.md` / `Docs/验收说明-2026-10-25.md` |
| 逐轮真机日志 | `Docs/INIT_REPORT.md`（§5ci 续 44–84） |
| 行中方案 | `Docs/行中智能方案.md` |
| 行后方案 | `Docs/行后情绪方案.md` |
| 任意城市 | `Docs/任意城市接入方案.md` / `Docs/MapKit地点检索探针-2026-10-31.md` |
| LLM | `Docs/LLM接入方案-2026-10-26.md`（已被 BFF 改造超越） |
| 家族 UI | `Docs/家族UI契约对齐方案-2026-11-02.md` |
| 商业化 | `Docs/商业化方案.md`（未跟踪） |
| 平台开通 | `Docs/围栏与后台唤醒开通清单.md` / `Docs/小艺Skill接入清单.md` / `Docs/实况窗方案.md` |
