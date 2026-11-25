---
title: "Docs · 行中智能方案.md"
id: markdown_cls1_798285c88467638f6a8dc28635ad6f33_c48cc6f909a70adfeb184927d1a8f78a7526104239726721
kb: 有径-YouJing
folder: "决策记录"
media_type: 7
tags: []
source: ima
exported_at: 2026-11-23T14:52:37.917Z
---
# 行中智能（切片 3）方案

> 状态：2026-10-30 设计定稿，按 T1 → T2 → T3 实施。
> 关联：`Docs/实况窗方案.md` §3（跳过与重排）、`Docs/INIT_REPORT.md` §5ci 续 44/45。

## 1. 目标与边界

行中段要解决的是「按位置、前往下一站的意愿、天气给下一步建议与重排」，
但**只有用户确认后才改行程**（路线图第 4 条）。本切片交付三层：

| 层 | 内容 | 是否改行程 |
| --- | --- | --- |
| T1 天气 | 当日概览 + 降水窗口，屏15 hero 一行 | 否 |
| T2 建议条 | 偏离 / 落后 / 有雨 三信号，一次只出一条 | 否 |
| T3 确认后重排 | 「顺延」把未开始站点整体后移；「跳过」复用既有链路 | 是，可撤销 |

明确不做：云函数/LLM 顺延（确定性算术不需要模型）、后台围栏（AGC 审核中）、
行前天气、天气进桌面卡片、跨时区换算（全 App 目前都不处理时区）。

## 2. 天气数据源与隐私

- 端点：Open-Meteo `https://api.open-meteo.com/v1/forecast`，免 Key、免登录。
  取 `hourly=precipitation_probability,weather_code,temperature_2m` 与
  `daily=weather_code,temperature_2m_max,temperature_2m_min,precipitation_probability_max`，
  `timezone=auto&forecast_days=2`。
- **只发当日首站坐标四舍五入到 0.1°（约 11km）**，不发实时定位、不发账号、不发行程内容。
- 失败静默：请求/解析任一失败都不出天气行，不阻塞页面。
- 缓存：内存 + preferences（`weather` / `weatherCache`）双层，TTL 30 分钟；
  屏15 每次打卡都会 reload，缓存挡住重复请求。
- 隐私政策新增「今日天气」条，`CONSENT_VERSION` 由 `v1` 抬到 `v2`，老用户重问一次。
- `ApiConfig.WEATHER_URL` 是公开地址（无密钥），仓库内保留真值；提交仍走 skip-worktree 双版本流程。

## 3. 数据契约

### 3.1 Weather（`model/Weather.ets`）

```ts
interface WeatherHour { startMin: number; code: number; tempC: number; rainProb: number; }
interface WeatherDay { date: string; code: number; tempMax: number; tempMin: number;
  rainMax: number; hours: WeatherHour[]; }
interface WeatherBrief { text: string; advice: string; }
```

- `startMin` 是目的地当地当日分钟数；`rainProb` 为 -1 表示该小时缺测。
- 解析器 `common/weather/WeatherParser.ets` 做 ArkTS 类型守卫，失败抛 `AppError`。
- 客户端 `common/weather/WeatherClient.ets` 连接 3s / 读取 4s，失败返回 `null`。

### 3.2 建议信号（`data/TripSignals.ets`）

```ts
interface SignalContext { isToday: boolean; nowMin: number; fix: GeoPoint | null;
  checkedIds: string[]; weather: WeatherDay | null; }
interface TripSuggestion { key: string; kind: SignalKind; title: string; detail: string;
  action: SignalAction; targetId: string; deltaMin: number; actionLabel: string; }
```

阈值（全部是纯函数入参，可离线断言）：

| 信号 | 触发条件 | 动作 |
| --- | --- | --- |
| 偏离（优先级 1） | 前台定位距当前站 >1000m，已过开始 ≥10 分钟，当前站未打卡且可跳过 | 跳过当前站 |
| 落后（优先级 2） | 最近一个已开始未打卡的站已晚 ≥30 分钟 | 顺延；没有可顺延站时改为跳过 |
| 有雨（优先级 3） | 前方第一处可跳过的室外站在其时段内降水概率 ≥60% | 跳过该站 |

- 优先级从高到低只出一条；同类建议被「忽略」后 30 分钟内不再弹，换类立即重判。
- 「当前站」= 时间轴上最后一个已开始的活动；交通/住宿/跳过占位不参与。
- 「落后」从最后一次打卡之后的第一个未打卡站算起，避免跨过已打卡站误报。

### 3.3 顺延（`SkipPlanner.shiftRemaining`）

```ts
static shiftRemaining(day: TripDay, nowMin: number, deltaMin: number): ReplanOutcome
```

- 目标：`nowMin` 之后尚未开始、非交通/住宿、未预约、非跳过占位的活动。
- 锚点：预约/交通/住宿活动、有时刻的餐次、**当前站的剩余时段**（`now → endTime`）。
- 每站先加 `delta`，再 `settle` 避开锚点；越过 23:59 的项及其后保持原时间并追加「待调整」。
- `delta` = 落后分钟向上取 15 的倍数，夹到 15–120。
- 校验：活动/餐次数量与 id 顺序不变、锚点时刻不变、已移动项互不重叠且不压锚点、待调整项时刻不变。
- 不调 LLM、不调云函数；快照/撤销/落库/卡片刷新复用跳过链路。

## 4. 屏15 呈现

- 天气行：hero 内、到站行之后，`今日 6°/20° 晴间多云 · 降水 0%`（有建议时追加 `· 15:00 后降水 70%`）。
  只在「今天」且取到天气时出现；数值走 tnum。
- 建议条：hero 之上的独立卡片（与 noticeBar 同形，标题用 `ColorTokens.warning`）：
  - 标题：`比计划晚 45 分钟`
  - 说明：`「博物馆」还没打卡，后续按原时间排`
  - 按钮：主按钮 `顺延 45 分钟`（或 `跳过这一站`）+ 文字按钮 `忽略`
- 动作：顺延走 `performShift`（快照 + 落库 + `canUndo`）；跳过走既有 `performSkip`
  （放宽为「任意可跳过站点」，不再限定必须是下一站）。
- 结果提示复用 `noticeBar`：「已顺延 45 分钟，后续行程整体后移」，可撤销。

## 5. 任务拆解

1. **T1 天气**：`model/Weather`、`common/weather/WeatherParser|WeatherClient`、
   `data/WeatherStore|WeatherAdvisor`、`ApiConfig.WEATHER_URL`、隐私条 + `CONSENT_VERSION v2`。
2. **T2 建议条**：`data/TripSignals`、屏15 天气行与建议条、忽略态、定位回调重算。
3. **T3 顺延**：`model/Replan.ReplanOutcome.changed?`、`SkipPlanner.isShiftTarget|shiftRemaining`、
   屏15 `performShift`、`performSkip` 放宽。
4. **验证与收尾**：离线断言、hypium、10 把尺、HAP、真机取证、INIT_REPORT、提交装机。

## 6. 验收

- 离线：`tools/verify_weather_logic.sh`（bundled tsc `--strict` + node 断言）
  覆盖 WMO 映射、天气简报、雨窗、三信号阈值与优先级、顺延锚点/溢出/非法输入。
- hypium：`WeatherAdvisor` / `TripSignals` / `ShiftPlanner`（顺延部分），注册进 `List.test.ets`。
- 静态尺：`audit_tnum`（气温/分钟）、`audit_button_width`（建议条两枚按钮）、
  `audit_colors` / `audit_type` / `audit_geometry` 等 10 把全绿。
- 真机：天气行（真网络）、当天测试行程触发「落后」建议条、顺延后时刻变化、撤销复原、
  建议条「忽略」30 分钟内不再弹。
- 已知边界：当日降水 0%，「有雨」建议无法真机触发；「偏离」需 >1km 实际位移——
  两者用离线断言 + hypium 取证，真机只验同一卡片的渲染与动作通路。

## 7. 风险

- 隐私版本抬档会让所有老用户重看一次同意弹窗，这是政策文本变更的预期副作用。
- `ApiConfig` 是 skip-worktree 文件，提交必须走「仓库版字段齐全、密钥为空」的双版本流程，
  暂存后 grep `sk-` 复核。
- 天气按目的地当地日期取数；设备与目的地跨时区时，itinerary 时刻与天气小时会错位（全 App 既有问题）。
