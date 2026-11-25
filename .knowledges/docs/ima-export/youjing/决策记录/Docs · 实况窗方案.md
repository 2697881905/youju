---
title: "Docs · 实况窗方案.md"
id: markdown_cls1_798285c88467638f6a8dc28635ad6f33_f6f6aa8690a8c819ca0c05764e8ab9f87526104239726721
kb: 有径-YouJing
folder: "决策记录"
media_type: 7
tags: []
source: ima
exported_at: 2026-11-23T14:52:37.917Z
---
# 实况窗方案（有径）

> 状态：**2026-11-09 AGC 驳回，方案停止实施，代码已移除**（git 历史可查）。
> 驳回原因：实况窗仅支持固定场景，行程/景区到站不在已开放范围；
> 官方场景表明确把「景区推荐/打卡」列为 `CHECK_IN` 的不适用案例。
> 此前「用 PROGRESS 统一承载」的设计属于场景不符，不得再申请或复验。
> P5 收敛为「系统围栏事件 + 本地通知」，见 `Docs/围栏与后台唤醒开通清单.md`。

## 0. 驳回结论（2026-11-09）

| 项 | 内容 |
| --- | --- |
| 官方开放场景 | 打车、即时配送、航班、高铁/火车、排队、取餐、赛事比分、共享租赁、计时、订阅计时、运动、导航、打卡、快递、进度、金融交易 |
| 明确不适用 | `CHECK_IN` 不适用「景区推荐/打卡」；`PROGRESS` 只适用手动上传/下载、AI 任务等工具类进度 |
| 本应用场景 | 旅行行程、景区到站、下一站引导——不在开放范围 |
| 处理 | 不申请、不复验；删除 `TripLiveView` / `LiveViewConfig` / `liveview_pickup.png` 及运行入口 |
| 替代 | 围栏 ENTER → `ArrivalNotice` 本地通知；围栏后台唤醒仍在 AGC 审核 |

## 1. 硬约束

| 约束 | 事实 | 影响 |
| --- | --- | --- |
| 无旅行类事件场景 | Live View Kit 只认固定 event（TAXI…TRADE），没有旅行/行程 | 曾计划用 `PROGRESS` 规避，但 AGC 按真实场景驳回；不得套用不相符的 event |
| 按钮不能后台执行 | `LayoutData.serviceButtons` 每项只有 `name` + `clickAction`（WantAgent），点击只能拉起应用 | 「不去」必须落到 App 内处理，无法在锁屏静默调用云端 |
| 端侧无后台定时 | 实况窗只在 App 存活时由 `updateLiveView` 刷新 | 按钮常驻，不做「到点才出现」 |
| 单次时长上限 | `aliveTime` ≤ 28800 秒 | 以「当日行程」为一个会话，超时自然结束 |
| 原「纯本地无后端」作废 | 本次引入 AGC 云函数持有 LLM Key | Key 不进客户端；客户端只调云函数 |

## 2. P1 · 实况窗基础会话（已关闭，不再实施）

- 触发：用户在「旅行中」页开启当日行程，端侧 `startLiveView`，event 固定 `PROGRESS`。
- 内容：胶囊态 `Day N · 城市` + 进度 `第k站/共M站`；卡片态当前站、下一站与通勤、进度条。
- 更新：到站打卡、切换站点、跳过时 `updateLiveView`，`sequence` 严格递增。
- 结束：走完最后一站或手动结束，`stopLiveView`；`lifeCycleMode = AUTO_STOP_WHEN_APP_TERMINATE`。
- 无权益时静默降级：`startLiveView` 返回 1003500005 只记日志，不影响行程页。

## 3. P2 · 「不去」与当日重排

### 3.1 交互链路

- 实况窗卡片在**存在可跳过的下一站**时显示两个 `serviceButtons`：`前往下一站`、`不去`。
  - `前往下一站` → WantAgent 拉起 `EntryAbility`，参数 `route=OnTrip&tripId=…&act=go`，落到旅行中页并高亮下一站，不改数据。
  - `不去` → WantAgent 拉起 `EntryAbility`，参数 `route=OnTrip&tripId=…&act=skip&stopId=…`，旅行中页顶部显示「正在重排…」，随后自动落库并刷新实况窗。
- 旅行中页提供同一入口，调用同一个 `skip` 用例；因此 P2 不依赖实况窗权益即可完成与验收。
- 只有「当天 + 下一站」可跳过；所选日不是今天时不提供入口。
- 可跳过 = 非餐次的活动，且 `category ∉ {TRANSPORT, HOTEL, REST}`、`status ≠ BOOKED`。
- 不提供「不去」的情况：下一站是餐次、住宿、交通段、已预约（`BOOKED`）或既有空闲块（`REST`）。

### 3.2 数据表示（零新列）

被跳过的 `Activity` 原地改写：

| 字段 | 新值 |
| --- | --- |
| `category` | `REST` |
| `title` | `空闲` |
| `status` | `NO_NEED` |
| `note` | `已跳过：<原标题>` |
| `reason` | 清空（原排期理由已不成立） |
| `transport` | 清空（不再前往该地点） |
| `time` | 保留原值 |
| `endTime` | 保留原值；缺失/早于 `time` 时取 `time + 60min`，并夹紧到当日 23:59 |
| `location` / `address` / 经纬度 | 清空 / 置 0 |

`id` 不变，保证 `Activity` 身份与 undo 快照可按 id 对齐。空闲段时长 = `endTime - time`（夹紧后可能不足 60min 或为 0）。

### 3.3 端侧排程规则

输入：`day: TripDay`、`skippedId`、`nowMinutes`、`keep: Array<{id, dwellMin}>`。

`keep` 是**当日剩余全部非锚点站点的一个排列**（只改顺序与停留时长，不增不减；增删站点见 §3.7）。

- **剩余站点**：当日 `activities` 中 `id ≠ skippedId`、`category ∉ {TRANSPORT, HOTEL}`、`status ≠ BOOKED`、`time ≥ nowMinutes` 的活动。`REST` 不是锚点，但本次空闲段按 `id` 排除。`keep` 只含活动；餐次没有 `id`，永不进入 `keep`。
- **锚点集合**：所有带 `time` 的餐次、`category ∈ {TRANSPORT, HOTEL}` 的活动、`status = BOOKED` 的活动、以及本次生成的空闲段。锚点时间不动。带 `time` 的餐次占 `[time, time + 60min]`；无 `time` 的餐次不参与排程。
- **游标**：`t = max(nowMinutes, 空闲段.endTime)`。
- **通勤归属**：`transport` 表示「到达该站之前」的通勤。逐项落位前先给 `t` 加该项的 `transport.duration`（无通勤按 0），再避锚点、再落位；`keep` 第一项也加。
- 按 `keep` 顺序逐项落位：`time = t`，`endTime = t + dwellMin`，随后 `t = endTime`。
- `freeBlocks` 是额外空档：游标越过 `afterId` 的结束时刻后，先加 `minutes` 再排下一站点；不写入模型，只体现为时间间隙。游标越过锚点时才应用该锚点的空档；游标已经过去的 `afterId` 空档忽略。
- 若落位会跨过下一个锚点，则把游标移到该锚点结束时刻重试，不丢弃站点。
- 顺延后 `endTime > 23:59` 时：从这一项起、其后所有 `keep` 站点保留原 `time`/`endTime`，`note` 追加 `待调整`，不再继续落位；`note` 已含该标记时不重复追加。
- 输出仅改写 `time` / `endTime`（必要时 `note`），其余字段与顺序不变；输出必须满足：不早于 `nowMinutes`、相邻不重叠、锚点未变。

### 3.4 云函数契约

`replanDay`（AGC 云函数，Node 运行时），Key 只存在云函数环境变量。

请求：

```json
{
  "schemaVersion": 1,
  "now": "14:05",
  "skippedId": "a2",
  "day": {
    "date": "2026-10-26",
    "activities": [
      { "id": "a3", "time": "10:30", "endTime": "11:30", "title": "二年坂",
        "category": "sight", "status": "no_need",
        "longitude": 135.78, "latitude": 34.99,
        "transport": { "duration": 8 } }
    ],
    "meals": [{ "type": "lunch", "time": "12:00" }]
  }
}
```

- `day.activities` 为该日**全部活动**（含已发生、锚点、被跳过项），客户端发送**重写前**的 `day`；云函数自行按 §3.3 的「剩余站点」口径判定，不信任客户端传入的剩余列表。
- `day.meals` 含全部餐次；`time` 可省略。
- 请求头 `x-youjing-token` 必须等于云函数环境变量 `YOUJING_REPLAN_TOKEN`，否则 401。
- 云函数上游 LLM 超时 5s；超时/非 2xx 一律 502，由客户端走本地兜底。

响应：

```json
{
  "schemaVersion": 1,
  "keep": [{ "id": "a3", "dwellMin": 60 }],
  "freeBlocks": [{ "afterId": "a2", "minutes": 90 }],
  "note": "下午节奏放缓，提前回酒店"
}
```

守卫（不满足一律走兜底）：

- `keep` 的 `id` 集合必须与当日剩余非锚点站点的 `id` 集合**完全一致**：缺项、多项、重复项一律拒绝（不增不减）。
- 每项 `dwellMin` 为 15–240 的整数；`keep` 最多 20 项。
- `freeBlocks` 可空（最多 3 块）；`afterId` 必须是当日已存在的活动 id，`minutes` 为 15–480。
- `note` 不超过 200 字。

### 3.4.1 扩展动作（P2/P3，2026-11-09）

- **加一站**：请求带 `addStopId`（端侧已把新站以临时时刻放进 `day.activities`），
  云函数按 §3.3 口径重排 `keep`；端侧再跑 480min 预算与 `DayLoad` 复核，
  超预算按屏8「去减一站」口径兜底，不静默裁剪。
- **换一站**：请求带 `replaceStopId`，云函数不做 LLM 决策，直接返回空 `keep`；
  端侧保留原槽时间与通勤，只替换站点并清空旧理由。
- **对话式**：请求带 `intentText`（与 `skippedId`/`addStopId`/`replaceStopId` 互斥），
  云函数把意愿映射为 `skip | shift | add | replace`，返回
  `action / targetId / newStopId / shiftMinutes / skipRemaining`；
  端侧先预览，用户确认后才落库，结果可撤销。

### 3.5 失败矩阵与兜底

| 情况 | 判定 | 处理 |
| --- | --- | --- |
| 无网 / 云函数不可达 / 5xx | 调用异常 | 本地兜底 |
| 超过 8 秒 | 超时 | 本地兜底 |
| 响应非 JSON 或缺字段 | 解析失败 | 本地兜底 |
| `keep` 集合与剩余站点不一致（缺/多/重复）或 `dwellMin` / `freeBlocks` 越界 | 守卫拒绝 | 本地兜底 |
| 通过 | — | 自动落库 |

> 客户端超时预算 8s：连接 2s + 读取 8s；云函数上游 LLM 5s 超时、函数超时 8s，保证正常路径在预算内返回。

**本地兜底算法**：设 `shift = 空闲段时长`。空闲段之后的每个非锚点站点整体后移 `shift`；若与下一个锚点重叠，则整体移到该锚点结束之后继续后移，保持相对顺序，不丢弃站点。结束后再跑一次 §3.3 的约束检查。

### 3.6 撤销

重排前深拷贝当日 `TripDay` 存内存（`skipSnapshot`）。成功后旅行中页顶部给「撤销」，恢复快照并 `updateLiveView`。撤销 = 把快照写回该日并落库；快照只在本进程有效，页面内跳转仍可撤销，App 重启后不可撤销。

### 3.7 范围外

多日重排、真实订票/支付、后台定时刷新、离线队列重试（增删站点已于 2026-11-09 纳入 §3.4.1）。

## 4. 验收

| 层 | 方式 |
| --- | --- |
| 排程器 / 补丁构造（纯逻辑） | 拷成 `.ts` 用 `tsc --strict` + `tsx` 跑断言：锚点不动、不重叠、不早于 now、跨锚点顺延、23:59 边界、keep 缺项/多项/重复拒绝 |
| 云端 | AGC 云函数控制台测试事件 + 一次真实模型调用 |
| 真机（LEM-AL00 / API 26） | 旅行中页点击跳过 → 重排 → 落库 → 实况窗刷新；断网走兜底；注入非法响应走守卫拒绝；撤销恢复 |
| 实况窗按钮 | 权益通过后：点亮屏卡片两个按钮，分别验证 `act=go` 与 `act=skip` 拉起落地 |

## 5. 分期

1. P0 权益：等 AGC 审核；通过后重签含 `com.huawei.service.liveView.entry` 的 Profile。
2. P1 基础会话：`liveview/DayTimeline`、`LiveViewSession`，端侧创建/更新/结束。
3. P2 跳过与重排：本文 §3；先做 App 内闭环，再接云函数，最后接实况窗按钮。
4. P3 正式权益：上架且月活达标后按《申请实况窗正式权限》提交方案评审。
