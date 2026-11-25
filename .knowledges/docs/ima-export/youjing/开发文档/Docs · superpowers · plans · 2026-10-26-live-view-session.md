---
title: "Docs · superpowers · plans · 2026-10-26-live-view-session.md"
id: markdown_cls1_798285c88467638f6a8dc28635ad6f33_9833db8eb33e0d6a5964fbccad84b4017526104239726721
kb: 有径-YouJing
folder: "开发文档"
media_type: 7
tags: []
source: ima
exported_at: 2026-11-23T14:52:37.917Z
---
# 旅行中实况窗会话（P1）实施计划

> **状态：已关闭（2026-11-09）。** AGC 驳回：旅行/景区到站不在实况窗开放场景内；
> 本计划不再执行。结论与替代路径见 `Docs/实况窗方案.md` §0。

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 在「旅行中」页手动开启一个 PROGRESS 实况窗，锁屏/通知中心显示当日行程进度、当前站与下一站；下一站可跳过时给出「前往下一站 / 不去」两个按钮，点击只拉起 App，并在 App 内复用 Plan A 的跳过/重排用例。

**Architecture:** 纯逻辑（`liveview/DayTimeline.ets`、`liveview/LiveViewSnapshot.ets`）产出时间轴与视图模型；`liveview/LiveViewSession.ets` 是唯一接触 `@kit.LiveViewKit` 的会话管理（创建/更新/结束、sequence 递增与重同步、无权益静默降级）；按钮经 `WantAgent` 拉起 `EntryAbility`，由 `EntryAbility` 把意图落到 AppStorage，`OnTripPage` 消费后复用 `performSkip` / 高亮下一站。

**Tech Stack:** ArkTS V1、HarmonyOS SDK 26.0.0、Live View Kit（`@kit.LiveViewKit`）、WantAgent（`@kit.AbilityKit`）、hypium（`entry@ohosTest`）、bundled tsc + node 离线断言。

**Spec:** `Docs/实况窗方案.md` §2（P1 基础会话）、§3.1（两个按钮与深链）、§4（验收）、§5（分期）。

**前置条件（硬门槛）：** 先完整执行并合并 `Docs/superpowers/plans/2026-10-26-skip-replan.md`（Plan A）。本计划的 Task 5 直接改写 Plan A 产出的 `reload()/performSkip()/undoSkip()/notice/isToday` 等代码；Plan A 未落地时不要开始本计划——锚点会全部对不上。

---

## Global Constraints

- **只做 P1 与 P2 的 App 内深链闭环**：云函数（`replanDay`）、AGC 云侧配置不在本计划内；Plan A 负责重排与本地兜底。
- **不改 `entry/src/main/module.json5`**：本能力不需要新增权限；Profile 的 `com.huawei.service.liveView.entry` 是权益通过后另行重签，不写进仓库。
- **不改 `entry/src/main/ets/pages/TripInputPage.ets`**（用户正在编辑）、**不改 `build-profile.json5`**（skip-worktree，含签名材料）。
- **不新增任何运行时依赖**；不引入后端。
- **不自动开启实况窗**：只在「今天」的旅行中页由用户手动打开；历史回看不提供开关。
- **同一时刻只维护一个会话**：启动前先停旧会话；`sequence` 严格递增；内容未变化不重复推送（避免触发 `1003500008` 频率限制）。
- **按钮只负责拉起 App**：`serviceButtons` 只放 `name` + `clickAction`（WantAgent）；真正的跳过/前往在 `OnTripPage` 前台执行。禁止设计后台 RPC 或锁屏静默调用云端。
- **没有后台定时器**：实况窗只在页面可见、打卡、跳过、撤销、深链回流时更新；跨站时刻变化要等下一次交互才刷新。
- **无权益必须静默降级**：`isLiveViewEnabled()` 为 false、`1003500004`、`1003500005` 只记日志并让开关回弹，不阻塞旅行中页。
- **证据优先**：每个「通过」都要有命令输出、hilog 或界面截图；未开通权益的锁屏项一律标 `[待验证]`，不得写成已验证。
- **一个工作包一个提交**：本计划全部改动合成一次提交；逐文件 `git add`，禁止 `git add -A`；不 push（push 需单独授权）。
- **不读不写凭据**：本计划不涉及 LLM Key、token、局域网地址；不向任何外部服务发请求。

---

## File Structure

| 文件 | 职责 |
|---|---|
| `entry/src/main/ets/liveview/DayTimeline.ets` | 纯逻辑：活动 ∪ 餐次时间轴、当前站、进度、跳过标记过滤 |
| `entry/src/main/ets/liveview/LiveViewSnapshot.ets` | 纯逻辑：标题/正文/胶囊/进度/按钮可用性、稳定 liveId |
| `entry/src/main/ets/liveview/LiveViewSession.ets` | 会话：start/update/stop、sequence、重同步、WantAgent、降级 |
| `entry/src/main/ets/common/constants/AppNav.ets` | 新增实况窗意图键、`APP_BUNDLE_NAME`、`isTopOnTrip()` |
| `entry/src/main/ets/entryability/EntryAbility.ets` | 解析 `act/tripId/stopId`，去重推页，按序落意图键 |
| `entry/src/main/ets/pages/Index.ets` | 运行期页签切换（`@Watch` + `changeIndex`） |
| `entry/src/main/ets/pages/OnTripPage.ets` | 开关、同步、消费意图、前往中提示、跳过/撤销后刷新实况窗 |
| `entry/src/ohosTest/ets/test/LiveViewSnapshot.test.ets` | hypium 回归：时间轴与视图模型关键路径 |
| `entry/src/ohosTest/ets/test/List.test.ets` | 注册新用例 |
| `tools/liveview_check.ts` | 离线断言（83 例） |
| `tools/verify_liveview_logic.sh` | 拷贝纯逻辑文件 → tsc --strict → node 断言 |
| `Docs/ARCHITECTURE.md` | 新增 `liveview/` 目录职责与依赖方向 |

---

### Task 1: 离线断言先红

**Files:**
- Create: `tools/liveview_check.ts`
- Create: `tools/verify_liveview_logic.sh`

**Interfaces:**
- Consumes: `../model/Trip` 的类型、`../utils/DateUtils.minutesOf`（Plan A 已加）、`../liveview/DayTimeline`、`../liveview/LiveViewSnapshot`
- Produces: `zsh tools/verify_liveview_logic.sh` 一条命令验证纯逻辑；成功输出 `LIVEVIEW_OK cases=83` + `LIVEVIEW_LOGIC_OK`

- [ ] **Step 1: 写 `tools/liveview_check.ts`**

```ts
/**
 * 实况窗纯逻辑离线断言（方案 §4）。
 * 由 tools/verify_liveview_logic.sh 拷进临时目录后 tsc + node 执行。
 */

import {
  Activity, ActivityCategory, ActivityStatus, IntensityLevel, MealType, TransportInfo, Trip, TripDay
} from '../model/Trip';
import { DateUtils } from '../utils/DateUtils';
import { DayTimeline, DayTimelineData, TimelineKind } from '../liveview/DayTimeline';
import { LiveViewSnapshot, LiveViewSnapshotBuilder } from '../liveview/LiveViewSnapshot';

let cases: number = 0;
let failures: number = 0;

function eq(actual: unknown, expected: unknown, label: string): void {
  cases += 1;
  if (actual !== expected) {
    failures += 1;
    console.error(`FAIL ${label}: expected ${JSON.stringify(expected)}, got ${JSON.stringify(actual)}`);
  }
}

function ok(cond: boolean, label: string): void {
  eq(cond, true, label);
}

function act(id: string, time: string, endTime: string, title: string,
  category: ActivityCategory, status: ActivityStatus, transport?: TransportInfo): Activity {
  const a: Activity = {
    id: id, time: time, endTime: endTime, title: title, location: title, address: '',
    longitude: 0, latitude: 0, status: status, category: category
  };
  if (transport !== undefined) {
    a.transport = transport;
  }
  return a;
}

function makeTrip(destination: string): Trip {
  return {
    id: 't-1', destination: destination, startDate: '2026-10-24', endDate: '2026-10-28',
    people: 2, budget: 8000, style: 'culture',
    overview: { totalCost: 6000, highlights: [], summary: '' }, days: [], tips: []
  };
}

const MAIN_DAY: TripDay = {
  dayIndex: 2, date: '2026-10-26', theme: '东山线', intensity: IntensityLevel.MEDIUM, dailyCost: 0,
  activities: [
    act('a1', '09:00', '11:00', '岚山竹林', ActivityCategory.SIGHT, ActivityStatus.NO_NEED),
    act('a2', '14:00', '15:30', '清水寺', ActivityCategory.SIGHT, ActivityStatus.NO_NEED,
      { mode: '公交', duration: 20, detail: '206路' }),
    act('a3', '15:30', '16:30', '二年坂', ActivityCategory.SIGHT, ActivityStatus.NOT_BOOKED,
      { mode: '步行', duration: 10, detail: '' }),
    act('a4', '16:45', '18:00', '锦市场', ActivityCategory.SHOP, ActivityStatus.NO_NEED)
  ],
  meals: [
    { type: MealType.LUNCH, time: '12:00', name: '午餐店', location: '祇园', estimatedCost: 120 },
    { type: MealType.DINNER, time: '18:30', name: '', location: '河原町', estimatedCost: 200 },
    { type: MealType.BREAKFAST, name: '早餐店', location: '酒店', estimatedCost: 60 }
  ]
};

const TRIP: Trip = makeTrip('京都');

// A. DateUtils 口径（Plan A 已加的方法，这里防回归）
eq(DateUtils.minutesOf('00:00'), 0, 'minutesOf 00:00');
eq(DateUtils.minutesOf('24:00'), -1, 'minutesOf 拒绝 24:00');

// B. 时间轴：活动 ∪ 餐次、排序、当前站、进度
const at13: DayTimelineData = DayTimeline.build(MAIN_DAY, 13 * 60);
eq(at13.total, 7, '时间轴 7 站');
eq(at13.stops[0].key, 'meal-2-breakfast', '无时刻早餐排 08:00 槽');
eq(at13.stops[0].startMin, 480, '早餐槽 480');
eq(at13.stops[1].key, 'a1', '第二站是岚山');
eq(at13.stops[2].key, 'meal-2-lunch', '午餐 12:00');
eq(at13.stops[3].key, 'a2', '清水寺 14:00');
eq(at13.stops[6].key, 'meal-2-dinner', '晚餐收尾');
eq(at13.currentIndex, 2, '13:00 当前是午餐');
eq(at13.started, true, '已开始');
eq(at13.finished, false, '未结束');
eq(at13.progressPct, 43, '进度 3/7');
eq(at13.nowMin, 780, 'nowMin 原样');
eq(at13.stops[0].endMin, 540, '无 endTime 默认 60 分钟');
eq(at13.stops[2].endMin, 780, '餐次按 60 分钟窗口');
eq(at13.stops[3].transportMode, '公交', '通勤方式');
eq(at13.stops[3].transportMin, 20, '通勤 20 分钟');
eq(at13.stops[3].transportDetail, '206路', '通勤详情');
eq(at13.stops[0].hasTransport, false, '餐次无通勤');
eq(at13.stops[6].title, '晚餐', '空店名回落餐次标签');
eq(at13.stops[3].kind, TimelineKind.ACTIVITY, '活动类型');

// C. 未开始 / 已结束 / 最后一站在途
const at7: DayTimelineData = DayTimeline.build(MAIN_DAY, 7 * 60);
eq(at7.started, false, '07:00 未开始');
eq(at7.currentIndex, 0, '未开始时指向第一站');
eq(at7.progressPct, 0, '未开始进度 0');
const at20: DayTimelineData = DayTimeline.build(MAIN_DAY, 20 * 60);
eq(at20.finished, true, '20:00 已结束');
eq(at20.progressPct, 100, '结束进度 100');
eq(at20.currentIndex, 6, '结束后指向最后一站');
const at19: DayTimelineData = DayTimeline.build(MAIN_DAY, 19 * 60);
eq(at19.currentIndex, 6, '19:00 在最后一站');
eq(at19.progressPct, 99, '未结束封顶 99');

// D. 结束时刻兜底与 23:59 夹紧
function singleDay(a: Activity): TripDay {
  return {
    dayIndex: 1, date: '2026-10-26', theme: '', intensity: IntensityLevel.LOW, dailyCost: 0,
    activities: [a], meals: []
  };
}
const badEnd: TripDay = singleDay(act('x1', '09:00', '', '无结束', ActivityCategory.SIGHT, ActivityStatus.NO_NEED));
eq(DayTimeline.build(badEnd, 600).stops[0].endMin, 600, '无 endTime 补 60 分钟');
const earlyEnd: TripDay = singleDay(act('x2', '09:00', '08:00', '结束早于开始', ActivityCategory.SIGHT, ActivityStatus.NO_NEED));
eq(DayTimeline.build(earlyEnd, 600).stops[0].endMin, 600, 'endTime 早于 time 补 60 分钟');
const lateEnd: TripDay = singleDay(act('x3', '23:30', '', '深夜', ActivityCategory.SIGHT, ActivityStatus.NO_NEED));
eq(DayTimeline.build(lateEnd, 600).stops[0].endMin, 1439, '结束夹到 23:59');
const badTime: TripDay = singleDay(act('x4', '', '', '无时刻', ActivityCategory.SIGHT, ActivityStatus.NO_NEED));
eq(DayTimeline.build(badTime, 600).stops[0].startMin, 0, '非法时刻按 0');
eq(DayTimeline.build(badTime, 600).stops[0].endMin, 60, '非法时刻结束 60');

// E. 跳过标记隐藏、真 REST 保留、空日程
const markerDay: TripDay = {
  dayIndex: 1, date: '2026-10-26', theme: '', intensity: IntensityLevel.LOW, dailyCost: 0,
  activities: [
    act('a1', '09:00', '10:00', '岚山', ActivityCategory.SIGHT, ActivityStatus.NO_NEED),
    act('a9', '10:00', '11:00', '空闲', ActivityCategory.REST, ActivityStatus.NO_NEED),
    act('a2', '11:30', '12:30', '清水寺', ActivityCategory.SIGHT, ActivityStatus.NO_NEED)
  ],
  meals: []
};
const markerTimeline: DayTimelineData = DayTimeline.build(markerDay, 12 * 60);
eq(markerTimeline.total, 2, '跳过标记不算站点');
eq(markerTimeline.stops[1].key, 'a2', '标记后的站点接上');
const restDay: TripDay = {
  dayIndex: 1, date: '2026-10-26', theme: '', intensity: IntensityLevel.LOW, dailyCost: 0,
  activities: [
    act('a1', '09:00', '10:00', '岚山', ActivityCategory.SIGHT, ActivityStatus.NO_NEED),
    act('r1', '11:00', '12:00', '回酒店休息', ActivityCategory.REST, ActivityStatus.NO_NEED)
  ],
  meals: []
};
const restTimeline: DayTimelineData = DayTimeline.build(restDay, 11 * 60 + 30);
eq(restTimeline.total, 2, '原行程里的 REST 保留');
eq(restTimeline.stops[1].key, 'r1', 'REST 站可见');
eq(restTimeline.stops[1].title, '回酒店休息', 'REST 标题原样');
const emptyDay: TripDay = {
  dayIndex: 1, date: '2026-10-26', theme: '', intensity: IntensityLevel.LOW, dailyCost: 0,
  activities: [], meals: []
};
const emptyTimeline: DayTimelineData = DayTimeline.build(emptyDay, 700);
eq(emptyTimeline.total, 0, '空日程 0 站');
eq(emptyTimeline.currentIndex, -1, '空日程无当前站');
eq(emptyTimeline.progressPct, 0, '空日程进度 0');

// F. 视图模型：13:00 主场景
const snap: LiveViewSnapshot | null = LiveViewSnapshotBuilder.build(TRIP, MAIN_DAY, 780, 'a2');
ok(snap !== null, '快照非空');
if (snap !== null) {
  eq(snap.title, 'Day 2 · 京都', '标题');
  eq(snap.content.length, 3, '正文三行');
  eq(snap.content[0], '当前 · 12:00 午餐店', '当前站');
  eq(snap.content[1], '下一站 14:00 清水寺', '下一站');
  eq(snap.content[2], '公交 20分钟', '下一段通勤');
  eq(snap.capsuleText, '第3站 · 共7站', '胶囊进度');
  eq(snap.progressPct, 43, '快照进度');
  eq(snap.index, 2, '快照当前下标');
  eq(snap.total, 7, '快照总站数');
  eq(snap.canSkip, true, '下一站可跳过');
  eq(snap.stopId, 'a2', '按钮带下一站 id');
  eq(snap.finished, false, '未结束');
  eq(snap.started, true, '已开始');
  eq(snap.liveId, LiveViewSnapshotBuilder.stableId('t-1', '2026-10-26'), 'liveId 稳定');
}

// G. 未出发
const snap7: LiveViewSnapshot | null = LiveViewSnapshotBuilder.build(TRIP, MAIN_DAY, 420, 'a1');
if (snap7 !== null) {
  eq(snap7.content[0], '待出发 · 早餐店', '未出发文案');
  eq(snap7.content.length, 2, '无通勤时两行');
  eq(snap7.canSkip, true, '未出发也能跳过首站');
  eq(snap7.stopId, 'a1', '首站 id');
  eq(snap7.capsuleText, '待出发 · 共7站', '未出发胶囊');
  eq(snap7.progressPct, 0, '未出发进度');
} else {
  eq('non-null', 'null', '未出发快照不应为空');
}

// H. 下一站是餐次：不给「不去」
const snapLunch: LiveViewSnapshot | null = LiveViewSnapshotBuilder.build(TRIP, MAIN_DAY, 570, 'meal-2-lunch');
if (snapLunch !== null) {
  eq(snapLunch.canSkip, false, '餐次不可跳过');
  eq(snapLunch.stopId, '', '餐次无按钮 id');
  eq(snapLunch.content[1], '下一站 12:00 午餐店', '下一站是餐次');
  eq(snapLunch.content.length, 2, '餐次无通勤行');
} else {
  eq('non-null', 'null', '餐次快照不应为空');
}

// I. 已结束：不再提供入口
const snapDone: LiveViewSnapshot | null = LiveViewSnapshotBuilder.build(TRIP, MAIN_DAY, 1200, 'a4');
if (snapDone !== null) {
  eq(snapDone.content.length, 1, '结束只留一行');
  eq(snapDone.content[0], '今日行程已完成', '结束文案');
  eq(snapDone.capsuleText, '今日已完成', '结束胶囊');
  eq(snapDone.canSkip, false, '结束后不给入口');
  eq(snapDone.progressPct, 100, '结束进度满格');
  eq(snapDone.finished, true, 'finished');
} else {
  eq('non-null', 'null', '结束快照不应为空');
}

// J. 页面没算出可跳过的下一站
const snapNoSkip: LiveViewSnapshot | null = LiveViewSnapshotBuilder.build(TRIP, MAIN_DAY, 780, '');
if (snapNoSkip !== null) {
  eq(snapNoSkip.canSkip, false, '无候选不给入口');
  eq(snapNoSkip.stopId, '', '无候选无 id');
} else {
  eq('non-null', 'null', '无候选快照不应为空');
}

// K. 通勤方式为空时回落「通勤」
const noModeDay: TripDay = JSON.parse(JSON.stringify(MAIN_DAY)) as TripDay;
noModeDay.activities[1].transport = { mode: '', duration: 5, detail: '' };
const snapNoMode: LiveViewSnapshot | null = LiveViewSnapshotBuilder.build(TRIP, noModeDay, 780, 'a2');
if (snapNoMode !== null) {
  eq(snapNoMode.content[2], '通勤 5分钟', '空方式回落通勤');
} else {
  eq('non-null', 'null', '空方式快照不应为空');
}

// L. 走到最后一站
const snapLast: LiveViewSnapshot | null = LiveViewSnapshotBuilder.build(TRIP, MAIN_DAY, 1110, 'a4');
if (snapLast !== null) {
  eq(snapLast.content[1], '今日最后一站', '最后一站文案');
  eq(snapLast.canSkip, false, '最后一站不给入口');
} else {
  eq('non-null', 'null', '最后一站快照不应为空');
}

// M. 会话 id 稳定且为正
const idA: number = LiveViewSnapshotBuilder.stableId('t-1', '2026-10-26');
const idB: number = LiveViewSnapshotBuilder.stableId('t-1', '2026-10-26');
const idC: number = LiveViewSnapshotBuilder.stableId('t-1', '2026-10-27');
eq(idA, idB, 'stableId 同日稳定');
ok(idA > 0, 'stableId 为正');
ok(idA !== idC, 'stableId 跨日不同');

// N. 空日程没有快照
eq(LiveViewSnapshotBuilder.build(TRIP, emptyDay, 700, ''), null, '空日程快照为 null');

if (failures > 0) {
  throw new Error(`LIVEVIEW_FAIL cases=${cases} failures=${failures}`);
}
console.log(`LIVEVIEW_OK cases=${cases}`);
```

- [ ] **Step 2: 写 `tools/verify_liveview_logic.sh` 并加可执行位**

```bash
#!/usr/bin/env bash
# 实况窗纯逻辑离线验收：把不依赖 @kit 的 .ets 拷成 .ts，bundled tsc --strict 后再用 bundled node 跑断言。
# 用法：zsh tools/verify_liveview_logic.sh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TSC="${TSC:-/Applications/DevEco-Studio.app/Contents/tools/ohpm/node_modules/typescript/bin/tsc}"
NODE="${NODE:-/Applications/DevEco-Studio.app/Contents/tools/node/bin/node}"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

copy() {
  mkdir -p "$TMP/$(dirname "$2")"
  cp "$ROOT/$1" "$TMP/$2"
}

copy entry/src/main/ets/model/Trip.ets model/Trip.ts
copy entry/src/main/ets/utils/DateUtils.ets utils/DateUtils.ts
copy entry/src/main/ets/liveview/DayTimeline.ets liveview/DayTimeline.ts
copy entry/src/main/ets/liveview/LiveViewSnapshot.ets liveview/LiveViewSnapshot.ts
copy tools/liveview_check.ts tools/liveview_check.ts

"$TSC" --strict --noEmitOnError --target ES2020 --module commonjs --moduleResolution node \
  --lib ES2020,DOM --rootDir "$TMP" --outDir "$TMP/out" \
  "$TMP/tools/liveview_check.ts"

"$NODE" "$TMP/out/tools/liveview_check.js"
echo "LIVEVIEW_LOGIC_OK"
```

Run:
```bash
chmod +x tools/verify_liveview_logic.sh
```

- [ ] **Step 3: 跑脚本确认「红」**

Run: `zsh tools/verify_liveview_logic.sh`

Expected: FAIL，首个报错是 `cp: ... entry/src/main/ets/liveview/DayTimeline.ets: No such file or directory`。这一步证明脚本确实在编译新文件，而不是空跑。

---

### Task 2: 时间轴与视图模型

**Files:**
- Create: `entry/src/main/ets/liveview/DayTimeline.ets`
- Create: `entry/src/main/ets/liveview/LiveViewSnapshot.ets`

**Interfaces:**
- Consumes: `model/Trip` 的类型、`utils/DateUtils.minutesOf`
- Produces: `TimelineKind`、`TimelineStop`、`DayTimelineData`、`DayTimeline.build(day, nowMin)`、`DayTimeline.isSkippedMarker(a)`
- Produces: `LiveViewSnapshot`、`LiveViewSnapshotBuilder.build(trip, day, nowMin, skippableNextId)`、`LiveViewSnapshotBuilder.stableId(tripId, date)`

- [ ] **Step 1: 写 `entry/src/main/ets/liveview/DayTimeline.ets`**

```ts
/**
 * 当日时间轴（纯逻辑，禁依赖 @kit）：
 * 活动 ∪ 餐次按时间并排，给出「当前是第几站」与进度百分比。
 * 实况窗与旅行中页共用同一口径，避免锁屏与页面各算一套。
 *
 * 跳过改写出的「空闲」块不进入时间轴：它是排程锚点，不是可打卡站点。
 */

import { Activity, ActivityCategory, ActivityStatus, Meal, MealType, TripDay } from '../model/Trip';
import { DateUtils } from '../utils/DateUtils';

export enum TimelineKind {
  ACTIVITY = 0,
  MEAL = 1
}

export interface TimelineStop {
  /** 打卡主键：活动用 Activity.id，餐次用派生 key `meal-{dayIndex}-{type}` */
  key: string;
  /** 界面显示的时刻；无时刻的餐次为 '' */
  time: string;
  startMin: number;
  endMin: number;
  title: string;
  kind: TimelineKind;
  transportMode: string;
  transportMin: number;
  transportDetail: string;
  place: string;
  hasTransport: boolean;
}

export interface DayTimelineData {
  stops: TimelineStop[];
  /** 当前那个站点的下标；空日程为 -1 */
  currentIndex: number;
  total: number;
  started: boolean;
  finished: boolean;
  nowMin: number;
  /** 0–100；完成后恒 100，未开始恒 0，进行中封顶 99 */
  progressPct: number;
}

const LAST_MINUTE: number = 23 * 60 + 59;
const DEFAULT_DWELL_MIN: number = 60;
const FREE_TITLE: string = '空闲';

export class DayTimeline {
  static build(day: TripDay, nowMin: number): DayTimelineData {
    const stops: TimelineStop[] = [];
    for (const a of day.activities) {
      if (DayTimeline.isSkippedMarker(a)) {
        continue;
      }
      stops.push(DayTimeline.activityStop(a));
    }
    for (const m of day.meals) {
      stops.push(DayTimeline.mealStop(day.dayIndex, m));
    }
    stops.sort((x: TimelineStop, y: TimelineStop): number => x.startMin - y.startMin);
    const now: number = Math.max(0, Math.min(LAST_MINUTE, Math.round(nowMin)));
    const total: number = stops.length;
    if (total === 0) {
      return {
        stops: [], currentIndex: -1, total: 0, started: false, finished: false,
        nowMin: now, progressPct: 0
      };
    }
    let currentIndex: number = 0;
    for (let i = 0; i < total; i++) {
      if (stops[i].startMin <= now) {
        currentIndex = i;
      }
    }
    const started: boolean = now >= stops[0].startMin;
    const finished: boolean = now >= stops[total - 1].endMin;
    let progressPct: number = 0;
    if (finished) {
      progressPct = 100;
    } else if (started) {
      progressPct = Math.max(1, Math.min(99, Math.round(((currentIndex + 1) / total) * 100)));
    }
    return {
      stops: stops, currentIndex: currentIndex, total: total, started: started,
      finished: finished, nowMin: now, progressPct: progressPct
    };
  }

  /** 跳过改写出的空闲块：category=REST + status=NO_NEED + title=空闲（方案 §3.2） */
  static isSkippedMarker(a: Activity): boolean {
    return a.category === ActivityCategory.REST && a.status === ActivityStatus.NO_NEED && a.title === FREE_TITLE;
  }

  private static activityStop(a: Activity): TimelineStop {
    const start: number = Math.max(0, DateUtils.minutesOf(a.time));
    const rawEnd: number = DateUtils.minutesOf(a.endTime);
    const end: number = Math.min(LAST_MINUTE, Math.max(start + 1, rawEnd > start ? rawEnd : start + DEFAULT_DWELL_MIN));
    const t = a.transport;
    return {
      key: a.id, time: a.time, startMin: start, endMin: end, title: a.title, kind: TimelineKind.ACTIVITY,
      transportMode: t === undefined ? '' : t.mode,
      transportMin: t === undefined ? 0 : t.duration,
      transportDetail: t === undefined ? '' : t.detail,
      place: a.address.length > 0 ? a.address : a.location,
      hasTransport: t !== undefined
    };
  }

  private static mealStop(dayIndex: number, m: Meal): TimelineStop {
    const shown: string = m.time === undefined ? '' : m.time;
    const start: number = shown.length > 0 ? Math.max(0, DateUtils.minutesOf(shown)) : DayTimeline.mealSlot(m.type);
    return {
      key: `meal-${dayIndex}-${m.type}`, time: shown, startMin: start,
      endMin: Math.min(LAST_MINUTE, start + DEFAULT_DWELL_MIN),
      title: m.name.length > 0 ? m.name : DayTimeline.mealLabel(m.type),
      kind: TimelineKind.MEAL, transportMode: '', transportMin: 0, transportDetail: '',
      place: m.location, hasTransport: false
    };
  }

  private static mealSlot(type: MealType): number {
    if (type === MealType.BREAKFAST) {
      return 8 * 60;
    }
    return type === MealType.LUNCH ? 12 * 60 : 18 * 60;
  }

  private static mealLabel(type: MealType): string {
    if (type === MealType.BREAKFAST) {
      return '早餐';
    }
    return type === MealType.LUNCH ? '午餐' : '晚餐';
  }
}
```

- [ ] **Step 2: 写 `entry/src/main/ets/liveview/LiveViewSnapshot.ets`**

```ts
/**
 * 实况窗视图模型（纯逻辑，禁依赖 @kit）：
 * 从 TripDay 生成标题、正文、胶囊文案、进度与「不去」按钮的可用性。
 * 只产出数据，不调任何系统 API——便于离线断言。
 */

import { Trip, TripDay } from '../model/Trip';
import { DayTimeline, DayTimelineData, TimelineKind, TimelineStop } from './DayTimeline';

export interface LiveViewSnapshot {
  /** 会话 id：同一行程同一天稳定不变 */
  liveId: number;
  tripId: string;
  title: string;
  content: string[];
  capsuleText: string;
  progressPct: number;
  /** 当前站下标（0 起） */
  index: number;
  total: number;
  started: boolean;
  finished: boolean;
  /** 是否给「不去下一站」按钮（只有下一站是可跳过活动） */
  canSkip: boolean;
  /** 按钮携带的下一站 id；canSkip=false 时为空串 */
  stopId: string;
}

export class LiveViewSnapshotBuilder {
  /**
   * skippableNextId 由调用方用 SkipPlanner 的规则算好（页面单点判定），
   * 这里只校验它确实等于时间轴上的下一站，避免页面与时间轴各算一套「下一站」。
   */
  static build(trip: Trip, day: TripDay, nowMin: number, skippableNextId: string): LiveViewSnapshot | null {
    const timeline: DayTimelineData = DayTimeline.build(day, nowMin);
    if (timeline.total === 0) {
      return null;
    }
    const current: TimelineStop = timeline.stops[timeline.currentIndex];
    const city: string = trip.destination.length > 0 ? trip.destination : '行程';
    const title: string = `Day ${day.dayIndex} · ${city}`;
    if (timeline.finished) {
      return {
        liveId: LiveViewSnapshotBuilder.stableId(trip.id, day.date), tripId: trip.id, title: title,
        content: ['今日行程已完成'], capsuleText: '今日已完成', progressPct: 100,
        index: timeline.currentIndex, total: timeline.total, started: true, finished: true,
        canSkip: false, stopId: ''
      };
    }
    const content: string[] = [];
    content.push(`${timeline.started ? '当前' : '待出发'} · ${LiveViewSnapshotBuilder.clockPrefix(current.time)}${current.title}`);
    const next: TimelineStop | null = timeline.currentIndex + 1 < timeline.total
      ? timeline.stops[timeline.currentIndex + 1] : null;
    if (next !== null) {
      content.push(`下一站 ${LiveViewSnapshotBuilder.clockPrefix(next.time)}${next.title}`);
      if (next.hasTransport) {
        content.push(`${next.transportMode.length > 0 ? next.transportMode : '通勤'} ${next.transportMin}分钟`);
      }
    } else {
      content.push('今日最后一站');
    }
    const skippable: boolean = next !== null && next.kind === TimelineKind.ACTIVITY && next.key === skippableNextId;
    return {
      liveId: LiveViewSnapshotBuilder.stableId(trip.id, day.date), tripId: trip.id, title: title, content: content,
      capsuleText: timeline.started ? `第${timeline.currentIndex + 1}站 · 共${timeline.total}站` : `待出发 · 共${timeline.total}站`,
      progressPct: timeline.progressPct, index: timeline.currentIndex, total: timeline.total,
      started: timeline.started, finished: false,
      canSkip: skippable, stopId: skippable && next !== null ? next.key : ''
    };
  }

  /**
   * 数字型会话 id（LiveView.id 是 number）。31 进制哈希后落在 int32 正区间；
   * 撞 id 只影响「另一趟行程的实况窗被当成同一个」，启动会话时会先 stop 旧会话兜底。
   */
  static stableId(tripId: string, date: string): number {
    const raw: string = `${tripId}|${date}`;
    let hash: number = 7;
    for (let i = 0; i < raw.length; i++) {
      hash = (hash * 31 + raw.charCodeAt(i)) % 2147483647;
    }
    return hash === 0 ? 1 : hash;
  }

  private static clockPrefix(hhmm: string): string {
    return hhmm.length > 0 ? `${hhmm} ` : '';
  }
}
```

- [ ] **Step 3: 跑离线断言，确认绿**

Run: `zsh tools/verify_liveview_logic.sh`

Expected:
```text
LIVEVIEW_OK cases=83
LIVEVIEW_LOGIC_OK
```

- [ ] **Step 4: 静态检查两个新文件**

用 MCP 工具 `check_ets_files`，参数：

```json
{"files": ["entry/src/main/ets/liveview/DayTimeline.ets", "entry/src/main/ets/liveview/LiveViewSnapshot.ets"]}
```

Expected: 两个文件均无诊断。若报错落到依赖文件（`Trip.ets`/`DateUtils.ets`）的缓存 AST，按工程记忆把依赖文件与 liveview 文件分开再调一次，不把缓存假错误当实现错误。

---

### Task 3: 深链入口与运行期页签切换

**Files:**
- Modify: `entry/src/main/ets/common/constants/AppNav.ets`
- Modify: `entry/src/main/ets/entryability/EntryAbility.ets`
- Modify: `entry/src/main/ets/pages/Index.ets`

**Interfaces:**
- Produces: `APP_BUNDLE_NAME = 'com.youjing.app'`、`ONTRIP_INTENT_KEY`、`ONTRIP_INTENT_TRIP_KEY`、`ONTRIP_STOP_KEY`、`isTopOnTrip(tripId: string): boolean`
- Produces: `EntryAbility` 解析 `act=go|skip`、`tripId`、`stopId`；按 `stopId → tripId → intent` 顺序写 AppStorage
- Produces: `Index` 在运行期响应 `TAB_INDEX_KEY` 变化并 `changeIndex`

- [ ] **Step 1: `AppNav.ets` 增加常量与去重函数**

在 `export const PENDING_PARAM_KEY: string = 'pendingTabParam';` 之后插入：

```ts
/** 实况窗 WantAgent 拉起的目标包名（与 AppScope/app.json5 一致） */
export const APP_BUNDLE_NAME: string = 'com.youjing.app';
/**
 * 实况窗按钮意图：三个 AppStorage 键。
 * 写入顺序固定 stopId → tripId → intent，页面只 @Watch intent，读到 intent 时另两个键一定已就位。
 */
export const ONTRIP_INTENT_KEY: string = 'onTripIntent';
export const ONTRIP_INTENT_TRIP_KEY: string = 'onTripIntentTripId';
export const ONTRIP_STOP_KEY: string = 'onTripStopId';
```

在 `tabOfRoute()` 之后插入：

```ts
/**
 * 行程栈顶是不是同一 tripId 的旅行中页。
 * 深链先推页再写意图键；已经在同一页时不再推第二层，避免返回两下才回到列表。
 */
export function isTopOnTrip(tripId: string): boolean {
  const names: string[] = APP_NAV.getAllPathName();
  if (names.length === 0 || names[names.length - 1] !== 'OnTrip') {
    return false;
  }
  const raw: Object | undefined = APP_NAV.getParamByIndex(names.length - 1) as Object | undefined;
  return typeof raw === 'string' && (raw as string) === tripId;
}
```

- [ ] **Step 2: `EntryAbility.ets` 增加待处理意图字段**

在 `private pendingParam: string = '';` 之后插入：

```ts
  /** 实况窗按钮意图：go = 前往下一站；skip = 不去并重排 */
  private pendingAct: string = '';
  private pendingStopId: string = '';
```

- [ ] **Step 3: `EntryAbility.applyWant` 解析实况窗意图**

在 `applyWant` 里，紧跟 `route` 解析块之后、`const draft: PlanDraft = PlanDraft.get();` 之前插入：

```ts
    // 实况窗按钮：只落到旅行中页，不碰屏2 草稿、不作废小艺预填。
    // 按钮 Want 自带 route=OnTrip 与 tripId；tripId 才是权威行程 id，覆盖 param。
    const liveAct: string = EntryAbility.wantString(params, 'act');
    const liveTrip: string = EntryAbility.wantString(params, 'tripId');
    if ((liveAct === 'go' || liveAct === 'skip') && liveTrip.length > 0) {
      this.pendingRoute = 'OnTrip';
      this.pendingParam = liveTrip;
      this.pendingAct = liveAct;
      this.pendingStopId = EntryAbility.wantString(params, 'stopId');
      Logger.info('EntryAbility', `实况窗意图 act=${liveAct} trip=${liveTrip} stop=${this.pendingStopId}`);
      return true;
    }
```

- [ ] **Step 4: `EntryAbility.routeTo` 去重推页并按序落意图**

把整个 `private routeTo(name: string, param: string): void { … }` 替换为：

```ts
  private routeTo(name: string, param: string): void {
    const tab: number = tabOfRoute(name);
    AppStorage.setOrCreate(TAB_INDEX_KEY, tab);
    if (param.length > 0) {
      AppStorage.setOrCreate(ACTIVE_TRIP_KEY, param);
    }
    // 已经在同一趟的旅行中页时不再推第二层；其余落点保持原行为
    if (tab === TAB_ITINERARY && (name !== 'OnTrip' || !isTopOnTrip(param))) {
      stackOfRoute(name).pushPath({ name: name, param: param });
    }
    if (this.pendingAct.length > 0 && name === 'OnTrip') {
      // 顺序不能换：页面只 @Watch intent，intent 必须最后写
      AppStorage.setOrCreate(ONTRIP_STOP_KEY, this.pendingStopId);
      AppStorage.setOrCreate(ONTRIP_INTENT_TRIP_KEY, param);
      AppStorage.setOrCreate(ONTRIP_INTENT_KEY, this.pendingAct);
      Logger.info('EntryAbility', `实况窗意图落键 act=${this.pendingAct} trip=${param} stop=${this.pendingStopId}`);
      this.pendingAct = '';
      this.pendingStopId = '';
    }
  }
```

- [ ] **Step 5: `EntryAbility` 的 import 补齐**

把第 6 行：

```ts
import { stackOfRoute, tabOfRoute, TAB_INDEX_KEY, TAB_ITINERARY, ACTIVE_TRIP_KEY } from '../common/constants/AppNav';
```

替换为：

```ts
import {
  stackOfRoute, tabOfRoute, TAB_INDEX_KEY, TAB_ITINERARY, ACTIVE_TRIP_KEY,
  isTopOnTrip, ONTRIP_INTENT_KEY, ONTRIP_INTENT_TRIP_KEY, ONTRIP_STOP_KEY
} from '../common/constants/AppNav';
```

- [ ] **Step 6: `Index.ets` 响应运行期切页签**

把：

```ts
  /** 外部深链（小艺 / 卡片 / aa start）写这个键；作为 HdsTabs 的**初始页签**消费 */
  @StorageLink(TAB_INDEX_KEY) wantTab: number = TAB_ITINERARY;
  @State private currentTab: number = TAB_ITINERARY;
  private hdsController: HdsTabsController = new HdsTabsController();

  aboutToAppear(): void {
    this.currentTab = this.wantTab;
```

替换为：

```ts
  /** 外部深链（小艺 / 卡片 / aa start）写这个键；冷启作为初始 index，运行期走 @Watch */
  @StorageLink(TAB_INDEX_KEY) @Watch('onTabRequest') wantTab: number = TAB_ITINERARY;
  @State private currentTab: number = TAB_ITINERARY;
  private hdsController: HdsTabsController = new HdsTabsController();
  /** 已经消费到的外部请求值；只对「外部写入」切页，用户自己点页签不重复切 */
  private lastTabRequest: number = TAB_ITINERARY;

  aboutToAppear(): void {
    this.currentTab = this.wantTab;
    this.lastTabRequest = this.wantTab;
```

在 `aboutToAppear()` 结束的 `}` 之后、`@Builder tabLabel` 之前插入：

```ts
  /** 运行期切页签：App 已存活时 onNewWant 改 TAB_INDEX_KEY，冷启仍走 index 初始值 */
  private onTabRequest(): void {
    if (this.wantTab === this.lastTabRequest) {
      return;
    }
    this.lastTabRequest = this.wantTab;
    this.hdsController.changeIndex(this.wantTab);
    Logger.info(TAG, `外部请求切页签 ${this.wantTab}`);
  }
```

- [ ] **Step 7: 静态检查（三个文件分开调，避开依赖缓存假错）**

依次用 MCP `check_ets_files`，每次只传一个文件：

```json
{"files": ["entry/src/main/ets/common/constants/AppNav.ets"]}
```
```json
{"files": ["entry/src/main/ets/entryability/EntryAbility.ets"]}
```
```json
{"files": ["entry/src/main/ets/pages/Index.ets"]}
```

Expected: 三个文件均无诊断。若 `EntryAbility`/`Index` 的报错来自 `AppNav.ets` 缓存，先单独复核 `AppNav.ets` 无错，再按工程记忆把依赖与页面分两次调用。

---

### Task 4: 实况窗会话

**Files:**
- Create: `entry/src/main/ets/liveview/LiveViewSession.ets`

**Interfaces:**
- Consumes: `LiveViewSnapshot`、`APP_BUNDLE_NAME`、`Logger`、`@kit.LiveViewKit`、`@kit.AbilityKit`
- Produces: `LiveViewSession.isOn(): boolean`、`activeTrip(): string`、`start(snapshot): Promise<boolean>`、`update(snapshot): Promise<void>`、`stop(): Promise<void>`

- [ ] **Step 1: 写 `entry/src/main/ets/liveview/LiveViewSession.ets`**

```ts
/**
 * 实况窗会话（唯一接触 @kit.LiveViewKit 的文件）。
 *
 * 约束（实况窗方案 §1/§2）：
 * - 同一时刻只维护一个会话，event 固定 PROGRESS，布局 ProgressLayout；
 * - sequence 必须严格递增；服务端把无版本会话回报为 4294967295，此时改成「不带 sequence」；
 * - 没有权益 / 系统开关关闭只记日志并返回 false，不抛给页面；
 * - 没有后台定时器：只在页面可见、打卡、跳过、撤销、深链回流时推更新。
 */

import { Want, WantAgent, wantAgent } from '@kit.AbilityKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { liveViewManager } from '@kit.LiveViewKit';
import { APP_BUNDLE_NAME } from '../common/constants/AppNav';
import { Logger } from '../common/logger/Logger';
import { LiveViewSnapshot } from './LiveViewSnapshot';

const TAG: string = 'LiveView';
const ERR_DISABLED: number = 1003500004;
const ERR_NO_RIGHT: number = 1003500005;
const ERR_EXISTS: number = 1003500006;
const ERR_NOT_EXIST: number = 1003500009;
const ERR_ENDED: number = 1003500010;
const ERR_SEQUENCE: number = 1003500011;
/** getActiveLiveView 对无版本会话返回的无效 sequence */
const INVALID_SEQUENCE: number = 4294967295;
/** 单次会话最长 8 小时（方案 §1） */
const ALIVE_SECONDS: number = 28800;

export class LiveViewSession {
  private static activeTripId: string = '';
  private static liveId: number = 0;
  private static sequence: number = 0;
  /** false = 该会话创建时没带 sequence，后续更新/结束也不带 */
  private static versioned: boolean = true;
  private static lastKey: string = '';
  private static last: LiveViewSnapshot | null = null;

  static isOn(): boolean {
    return LiveViewSession.activeTripId.length > 0;
  }

  static activeTrip(): string {
    return LiveViewSession.activeTripId;
  }

  static async start(snapshot: LiveViewSnapshot): Promise<boolean> {
    let enabled: boolean = false;
    try {
      enabled = await liveViewManager.isLiveViewEnabled();
    } catch (err) {
      const e: BusinessError = err as BusinessError;
      Logger.warn(TAG, `isLiveViewEnabled 失败 code=${e.code} ${e.message}`);
      return false;
    }
    if (!enabled) {
      Logger.info(TAG, '实况窗未开启（系统开关或权益），静默降级');
      return false;
    }
    if (LiveViewSession.activeTripId.length > 0 && LiveViewSession.activeTripId !== snapshot.tripId) {
      await LiveViewSession.stop();
    }
    LiveViewSession.activeTripId = snapshot.tripId;
    LiveViewSession.liveId = snapshot.liveId;
    LiveViewSession.sequence = 0;
    LiveViewSession.versioned = true;
    LiveViewSession.lastKey = '';
    LiveViewSession.last = snapshot;
    const ok: boolean = await LiveViewSession.create(snapshot);
    if (!ok) {
      LiveViewSession.reset();
    }
    return ok;
  }

  static async update(snapshot: LiveViewSnapshot): Promise<void> {
    if (LiveViewSession.activeTripId !== snapshot.tripId || LiveViewSession.liveId !== snapshot.liveId) {
      return;
    }
    const key: string = LiveViewSession.keyOf(snapshot);
    if (key === LiveViewSession.lastKey) {
      return;
    }
    for (let attempt = 0; attempt < 2; attempt++) {
      if (LiveViewSession.versioned) {
        LiveViewSession.sequence += 1;
      }
      const view: liveViewManager.LiveView = await LiveViewSession.liveViewOf(
        snapshot, LiveViewSession.sequence, LiveViewSession.versioned, false);
      try {
        const result: liveViewManager.LiveViewResult = await liveViewManager.updateLiveView(view);
        if (LiveViewSession.accept('update', result)) {
          LiveViewSession.lastKey = key;
          LiveViewSession.last = snapshot;
        }
        return;
      } catch (err) {
        const e: BusinessError = err as BusinessError;
        Logger.warn(TAG, `updateLiveView 失败 code=${e.code} ${e.message}`);
        if (attempt === 0 && e.code === ERR_SEQUENCE) {
          await LiveViewSession.resync(snapshot.liveId);
          continue;
        }
        if (e.code === ERR_NOT_EXIST || e.code === ERR_ENDED) {
          await LiveViewSession.create(snapshot);
          return;
        }
        if (e.code === ERR_NO_RIGHT || e.code === ERR_DISABLED) {
          Logger.info(TAG, '实况窗权限/开关不可用，停止会话');
          LiveViewSession.reset();
        }
        return;
      }
    }
  }

  static async stop(): Promise<void> {
    const snapshot: LiveViewSnapshot | null = LiveViewSession.last;
    if (snapshot === null || LiveViewSession.activeTripId.length === 0) {
      LiveViewSession.reset();
      return;
    }
    if (LiveViewSession.versioned) {
      LiveViewSession.sequence += 1;
    }
    const view: liveViewManager.LiveView = await LiveViewSession.liveViewOf(
      snapshot, LiveViewSession.sequence, LiveViewSession.versioned, true);
    try {
      await liveViewManager.stopLiveView(view);
    } catch (err) {
      const e: BusinessError = err as BusinessError;
      if (e.code !== ERR_NOT_EXIST && e.code !== ERR_ENDED && e.code !== ERR_SEQUENCE) {
        Logger.warn(TAG, `stopLiveView 失败 code=${e.code} ${e.message}`);
      }
    }
    LiveViewSession.reset();
  }

  private static async create(snapshot: LiveViewSnapshot): Promise<boolean> {
    for (let attempt = 0; attempt < 2; attempt++) {
      if (attempt === 0) {
        LiveViewSession.sequence = 1;
      }
      const view: liveViewManager.LiveView = await LiveViewSession.liveViewOf(
        snapshot, LiveViewSession.sequence, LiveViewSession.versioned, false);
      try {
        const result: liveViewManager.LiveViewResult = await liveViewManager.startLiveView(view);
        const ok: boolean = LiveViewSession.accept('start', result);
        if (ok) {
          LiveViewSession.lastKey = LiveViewSession.keyOf(snapshot);
          LiveViewSession.last = snapshot;
        }
        return ok;
      } catch (err) {
        const e: BusinessError = err as BusinessError;
        Logger.warn(TAG, `startLiveView 失败 code=${e.code} ${e.message}`);
        if (attempt === 0 && e.code === ERR_EXISTS) {
          await LiveViewSession.clearExisting(snapshot);
          continue;
        }
        if (attempt === 0 && e.code === ERR_SEQUENCE) {
          await LiveViewSession.resync(snapshot.liveId);
          continue;
        }
        return false;
      }
    }
    return false;
  }

  private static async clearExisting(snapshot: LiveViewSnapshot): Promise<void> {
    try {
      const active: liveViewManager.LiveView = await liveViewManager.getActiveLiveView(snapshot.liveId);
      const seq: number | undefined = active.sequence;
      const versioned: boolean = seq !== undefined && seq >= 0 && seq !== INVALID_SEQUENCE;
      const view: liveViewManager.LiveView = await LiveViewSession.liveViewOf(
        snapshot, versioned ? (seq as number) + 1 : 1, versioned, true);
      await liveViewManager.stopLiveView(view);
    } catch (err) {
      const e: BusinessError = err as BusinessError;
      Logger.warn(TAG, `清理旧会话失败 code=${e.code} ${e.message}`);
    }
  }

  private static async resync(liveId: number): Promise<void> {
    try {
      const active: liveViewManager.LiveView = await liveViewManager.getActiveLiveView(liveId);
      const seq: number | undefined = active.sequence;
      if (seq !== undefined && seq >= 0 && seq !== INVALID_SEQUENCE) {
        LiveViewSession.sequence = seq + 1;
        LiveViewSession.versioned = true;
      } else {
        LiveViewSession.versioned = false;
        LiveViewSession.sequence = 0;
      }
    } catch (err) {
      const e: BusinessError = err as BusinessError;
      Logger.warn(TAG, `getActiveLiveView 失败 code=${e.code} ${e.message}`);
    }
  }

  private static async liveViewOf(snapshot: LiveViewSnapshot, sequence: number,
    versioned: boolean, ended: boolean): Promise<liveViewManager.LiveView> {
    const texts: liveViewManager.RichText[] = [];
    for (const line of snapshot.content) {
      const item: liveViewManager.RichText = { text: line };
      texts.push(item);
    }
    const layout: liveViewManager.ProgressLayout = {
      layoutType: liveViewManager.LayoutType.LAYOUT_TYPE_PROGRESS,
      progress: ended ? 100 : snapshot.progressPct
    };
    if (!ended && snapshot.canSkip) {
      const go: WantAgent | undefined = await LiveViewSession.agent(snapshot.tripId, 'go', '');
      const skip: WantAgent | undefined = await LiveViewSession.agent(snapshot.tripId, 'skip', snapshot.stopId);
      if (go !== undefined && skip !== undefined) {
        const b1: liveViewManager.ServiceButton = { name: '前往下一站', clickAction: go };
        const b2: liveViewManager.ServiceButton = { name: '不去', clickAction: skip };
        layout.serviceButtons = [b1, b2];
        layout.isServiceButtonsDisplayed = true;
      }
    }
    const primary: liveViewManager.PrimaryData = {
      title: snapshot.title,
      content: texts,
      aliveTime: ALIVE_SECONDS,
      layoutData: layout
    };
    const open: WantAgent | undefined = await LiveViewSession.openAgent(snapshot.tripId);
    if (open !== undefined) {
      primary.clickAction = open;
    }
    // 胶囊两行分别对齐方案 §2：「Day N · 城市」+「第k站/共M站」
    const capsule: liveViewManager.TextCapsule = {
      type: liveViewManager.CapsuleType.CAPSULE_TYPE_TEXT,
      status: ended ? -1 : 1,
      title: snapshot.title,
      content: snapshot.capsuleText
    };
    const data: liveViewManager.LiveViewData = { primary: primary, capsule: capsule };
    const view: liveViewManager.LiveView = {
      id: snapshot.liveId,
      event: 'PROGRESS',
      isMute: true,
      lifeCycleMode: liveViewManager.LifeCycleMode.AUTO_STOP_WHEN_APP_TERMINATE,
      liveViewData: data
    };
    if (versioned) {
      view.sequence = sequence;
    }
    return view;
  }

  private static async agent(tripId: string, act: string, stopId: string): Promise<WantAgent | undefined> {
    const params: Record<string, Object> = {};
    params['route'] = 'OnTrip';
    params['tripId'] = tripId;
    params['act'] = act;
    if (stopId.length > 0) {
      params['stopId'] = stopId;
    }
    return await LiveViewSession.getAgent(params, act === 'go' ? 1002 : 1003);
  }

  private static async openAgent(tripId: string): Promise<WantAgent | undefined> {
    const params: Record<string, Object> = {};
    params['route'] = 'OnTrip';
    params['tripId'] = tripId;
    return await LiveViewSession.getAgent(params, 1001);
  }

  /** 构造普通 WantAgent（点击只拉起 App，业务动作在端内执行） */
  private static async getAgent(params: Record<string, Object>,
    requestCode: number): Promise<WantAgent | undefined> {
    const want: Want = {
      bundleName: APP_BUNDLE_NAME,
      abilityName: 'EntryAbility',
      parameters: params
    };
    const info: wantAgent.WantAgentInfo = {
      wants: [want],
      actionType: wantAgent.OperationType.START_ABILITY,
      requestCode: requestCode,
      actionFlags: [wantAgent.WantAgentFlags.UPDATE_PRESENT_FLAG]
    };
    try {
      return await wantAgent.getWantAgent(info);
    } catch (err) {
      const e: BusinessError = err as BusinessError;
      Logger.warn(TAG, `WantAgent 构造失败 code=${e.code} ${e.message}`);
      return undefined;
    }
  }

  /** 内容指纹：标题/正文/胶囊/进度/按钮任一变化才推更新 */
  private static keyOf(s: LiveViewSnapshot): string {
    return `${s.liveId}|${s.title}|${s.finished ? 1 : 0}|${s.progressPct}|${s.canSkip ? 1 : 0}|${s.stopId}|${s.capsuleText}|${s.content.join('|')}`;
  }

  private static accept(label: string, result: liveViewManager.LiveViewResult): boolean {
    if (result.resultCode === 0) {
      return true;
    }
    const msg: string = result.message === undefined ? '' : result.message;
    Logger.warn(TAG, `${label} 部分区域失败 code=${result.resultCode} ${msg}`);
    // 1–5 是固定区/辅助区/扩展区/胶囊/外屏的单区失败，会话仍在，不视为整体失败
    return result.resultCode >= 1 && result.resultCode <= 5;
  }

  private static reset(): void {
    LiveViewSession.activeTripId = '';
    LiveViewSession.liveId = 0;
    LiveViewSession.sequence = 0;
    LiveViewSession.versioned = true;
    LiveViewSession.lastKey = '';
    LiveViewSession.last = null;
  }
}
```

- [ ] **Step 2: 静态检查**

```json
{"files": ["entry/src/main/ets/liveview/LiveViewSession.ets"]}
```

Expected: 无诊断。若报 `LifeCycleMode`/`aliveTime`/`serviceButtons` 不存在，先确认 `build-profile.json5` 的 `compileSdkVersion` 是 26.0.0（只读核对，不改文件）；这些字段分别自 API 26.0.0 / 24 / 19 起提供。

---

### Task 5: 旅行中页接入开关、同步与意图

**Files:**
- Modify: `entry/src/main/ets/pages/OnTripPage.ets`

**Interfaces:**
- Consumes: Plan A 的 `reload()`、`performSkip(expectedStopId)`、`refreshWidget()`、`isToday`、`next`、`day`
- Consumes: `LiveViewSession.*`、`LiveViewSnapshotBuilder.build`、`SkipPlanner.isSkippable`、`isTopOnTrip`
- Produces: `reloadAndSync(forceIntent)`、`syncLiveView()`、`toggleLive(on)`、`stopLive()`、`consumeIntent(force)`、`markHeadingTo(stopId)`、`isHeadingTo()`

- [ ] **Step 1: 补 import**

把页面现有的 AppNav import（Plan A 未改动这一行）：

```ts
import { ACTIVE_TRIP_KEY, APP_NAV } from '../common/constants/AppNav';
```

替换为：

```ts
import {
  ACTIVE_TRIP_KEY, APP_NAV, isTopOnTrip, ONTRIP_INTENT_KEY,
  ONTRIP_INTENT_TRIP_KEY, ONTRIP_STOP_KEY
} from '../common/constants/AppNav';
```

在 `import { WidgetSync } from '../widget/TodayCard';` 之后插入：

```ts
import { LiveViewSession } from '../liveview/LiveViewSession';
import { LiveViewSnapshot, LiveViewSnapshotBuilder } from '../liveview/LiveViewSnapshot';
```

- [ ] **Step 2: 增加页面状态**

在 Plan A 的字段块末尾：

```ts
  private skipSnapshotTripId: string = '';
  private skipSnapshotDayIndex: number = 0;
```

之后插入：

```ts
  /** 实况窗开关的真实状态（以 LiveViewSession 为准，失败会回弹） */
  @State private liveOn: boolean = false;
  /** 「前往下一站」高亮的站点 id；为空或与当前 next 不一致时不显示 */
  @State private headingStopId: string = '';
  /** 实况窗按钮意图：只 Watch intent 键，另两个键在 consumeIntent 里直读 */
  @StorageProp(ONTRIP_INTENT_KEY) @Watch('onLiveIntent') private liveIntent: string = '';
```

- [ ] **Step 3: 替换 `aboutToAppear`**

把：

```ts
  aboutToAppear(): void {
    this.reload();
  }
```

替换为：

```ts
  aboutToAppear(): void {
    Logger.info('Ui.OnTrip', `进入旅行中 tripId=${this.tripId}`);
    this.reloadAndSync(true);
  }
```

> `forceIntent=true`：新页面必须先把已经写好的意图吃掉；`isTopOnTrip` 在推页前可能还没看到本页。

- [ ] **Step 4: 打卡后同步实况窗**

把 `toggleCheckin()` 里的：

```ts
      this.checkedIn = target;
      this.reload();
```

替换为：

```ts
      this.checkedIn = target;
      this.reloadAndSync(false);
```

- [ ] **Step 5: 在 `refreshWidget()` 之后增加同步/意图方法**

在 Plan A 的 `refreshWidget()` 结束 `}` 之后、`buildStops` 之前插入：

```ts
  /** 重载当日并同步实况窗；forceIntent=true 用于新页面先吃意图 */
  private async reloadAndSync(forceIntent: boolean): Promise<void> {
    await this.reload();
    const sessionOn: boolean = LiveViewSession.isOn() && LiveViewSession.activeTrip() === this.tripId;
    this.liveOn = sessionOn;
    if (sessionOn) {
      await this.syncLiveView();
    }
    await this.consumeIntent(forceIntent);
  }

  /** 由页面状态生成快照；「可跳过」仍由 SkipPlanner 单点判定 */
  private buildSnapshot(): LiveViewSnapshot | null {
    const trip: Trip | null = this.trip;
    const day: TripDay | null = this.day;
    if (trip === null || day === null) {
      return null;
    }
    const next: DayStop | null = this.next;
    const skippableId: string = next !== null && !next.isMeal && this.isToday &&
      SkipPlanner.isSkippable(next.category, next.status) ? next.key : '';
    return LiveViewSnapshotBuilder.build(trip, day, DateUtils.minutesOf(clockNow()), skippableId);
  }

  /** 只在开关开着时推更新；非今天/已完成直接结束会话 */
  private async syncLiveView(): Promise<void> {
    if (!this.liveOn) {
      return;
    }
    if (!this.isToday) {
      await this.stopLive();
      return;
    }
    const snapshot: LiveViewSnapshot | null = this.buildSnapshot();
    if (snapshot === null || snapshot.finished) {
      await this.stopLive();
      return;
    }
    await LiveViewSession.update(snapshot);
    this.liveOn = LiveViewSession.isOn();
  }

  private async toggleLive(on: boolean): Promise<void> {
    if (!on) {
      await this.stopLive();
      return;
    }
    const snapshot: LiveViewSnapshot | null = this.buildSnapshot();
    if (snapshot === null) {
      this.liveOn = false;
      this.toast('今日没有可展示的行程');
      return;
    }
    const ok: boolean = await LiveViewSession.start(snapshot);
    this.liveOn = ok;
    this.toast(ok ? '实况窗已开启' : '实况窗不可用（未开通权益或系统开关关闭）');
  }

  private async stopLive(): Promise<void> {
    this.liveOn = false;
    await LiveViewSession.stop();
  }

  private isHeadingTo(): boolean {
    const next: DayStop | null = this.next;
    return next !== null && this.headingStopId.length > 0 && this.headingStopId === next.key;
  }

  /** intent 键变化即重载；清键写空串也会触发，这里挡掉 */
  private onLiveIntent(): void {
    if (this.liveIntent.length === 0) {
      return;
    }
    this.reloadAndSync(false);
  }

  private async consumeIntent(force: boolean): Promise<void> {
    const act: string = AppStorage.get<string>(ONTRIP_INTENT_KEY) ?? '';
    if (act.length === 0) {
      return;
    }
    const intentTrip: string = AppStorage.get<string>(ONTRIP_INTENT_TRIP_KEY) ?? '';
    if (intentTrip !== this.tripId) {
      return;
    }
    if (!force && !isTopOnTrip(this.tripId)) {
      return;
    }
    const stopId: string = AppStorage.get<string>(ONTRIP_STOP_KEY) ?? '';
    this.clearIntent();
    if (act === 'skip') {
      await this.performSkip(stopId);
      return;
    }
    if (act === 'go') {
      this.markHeadingTo(stopId);
    }
  }

  private clearIntent(): void {
    AppStorage.setOrCreate(ONTRIP_STOP_KEY, '');
    AppStorage.setOrCreate(ONTRIP_INTENT_TRIP_KEY, '');
    AppStorage.setOrCreate(ONTRIP_INTENT_KEY, '');
  }

  /** 前往下一站：不改数据，只高亮下一站并给一条提示 */
  private markHeadingTo(stopId: string): void {
    const next: DayStop | null = this.next;
    if (next === null) {
      this.toast('今日已无下一站');
      return;
    }
    if (stopId.length > 0 && stopId !== next.key) {
      this.toast('下一站已变化，请以当前行程为准');
      return;
    }
    this.headingStopId = next.key;
    this.notice = `正在前往 ${next.title}${this.nextLeg.length > 0 ? ` · ${this.nextLeg}` : ''}`;
    this.toast(`前往 ${next.title}`);
  }
```

- [ ] **Step 6: 跳过成功后清高亮并刷新实况窗**

把 Plan A `performSkip` 尾部的：

```ts
    this.canUndo = true;
    await this.reload();
    this.refreshWidget();
  }
```

替换为：

```ts
    this.canUndo = true;
    this.headingStopId = '';
    await this.reload();
    this.refreshWidget();
    await this.syncLiveView();
  }
```

把 Plan A `undoSkip` 尾部的：

```ts
    this.notice = '已撤销重排';
    await this.reload();
    this.refreshWidget();
  }
```

替换为：

```ts
    this.notice = '已撤销重排';
    await this.reload();
    this.refreshWidget();
    await this.syncLiveView();
  }
```

- [ ] **Step 7: hero 区增加开关**

把：

```ts
                Text('打卡与记账只存本机，不上传服务器')
                  .fontSize(TypeTokens.overline.size)
                  .fontWeight(450)
                  .fontColor(ColorTokens.muted)
                  .margin({ top: SpaceTokens.sm })
```

替换为：

```ts
                if (this.isToday) {
                  Row({ space: SpaceTokens.sm }) {
                    Text('锁屏实况窗')
                      .fontSize(TypeTokens.caption.size)
                      .fontWeight(450)
                      .fontColor(ColorTokens.body)
                      .layoutWeight(1)
                    Toggle({ type: ToggleType.Switch, isOn: this.liveOn })
                      .selectedColor(ColorTokens.primary)
                      .onChange((on: boolean): void => {
                        this.toggleLive(on);
                      })
                  }
                  .width('100%')
                  .margin({ top: SpaceTokens.md })
                }
                Text('打卡与记账只存本机，不上传服务器')
                  .fontSize(TypeTokens.overline.size)
                  .fontWeight(450)
                  .fontColor(ColorTokens.muted)
                  .margin({ top: this.isToday ? SpaceTokens.xs : SpaceTokens.sm })
```

- [ ] **Step 8: 下一站卡片增加「前往中」高亮**

在 `if (this.nextNeedsBooking()) { … }` 的结束 `}` 之后、`.layoutWeight(1)` 之前插入：

```ts
                  if (this.isHeadingTo()) {
                    Text('前往中')
                      .fontSize(TypeTokens.overline.size)
                      .fontWeight(600)
                      .fontColor(ColorTokens.onPrimary)
                      .height(18)
                      .padding({ left: SpaceTokens.xs, right: SpaceTokens.xs })
                      .borderRadius(RadiusTokens.pill)
                      .backgroundColor(ColorTokens.primary)
                  }
```

- [ ] **Step 9: 页面重新可见时也同步**

把：

```ts
    .onShown((): void => {
      this.reload();
    })
```

替换为：

```ts
    .onShown((): void => {
      this.reloadAndSync(false);
    })
```

- [ ] **Step 10: 静态检查**

```json
{"files": ["entry/src/main/ets/pages/OnTripPage.ets"]}
```

Expected: 无诊断。若报错落在 `LiveViewSession.ets` / `LiveViewSnapshot.ets` / `SkipPlanner.ets` 的缓存 AST，按工程记忆把依赖文件与页面分两次调用复核；不改实现期望值来迁就假错误。

---

### Task 6: hypium 回归

**Files:**
- Create: `entry/src/ohosTest/ets/test/LiveViewSnapshot.test.ets`
- Modify: `entry/src/ohosTest/ets/test/List.test.ets`

**Interfaces:**
- Consumes: `DayTimeline`、`LiveViewSnapshotBuilder`
- Produces: 9 个 `it`，随 `entry@ohosTest` 构建并在真机 `aa test` 中执行

- [ ] **Step 1: 写 `entry/src/ohosTest/ets/test/LiveViewSnapshot.test.ets`**

```ts
/**
 * 实况窗纯逻辑回归：时间轴排序/当前站/进度，视图模型的文案、跳过门禁与稳定 id。
 * 这是「锁屏和页面各算一套站点」的唯一防线。
 */

import { describe, it, expect, TestType, Size, Level } from '@ohos/hypium';
import {
  Activity, ActivityCategory, ActivityStatus, IntensityLevel, MealType, TransportInfo, Trip, TripDay
} from '../../../main/ets/model/Trip';
import { DayTimeline, DayTimelineData } from '../../../main/ets/liveview/DayTimeline';
import { LiveViewSnapshot, LiveViewSnapshotBuilder } from '../../../main/ets/liveview/LiveViewSnapshot';

function act(id: string, time: string, endTime: string, title: string,
  category: ActivityCategory, status: ActivityStatus, transport?: TransportInfo): Activity {
  const a: Activity = {
    id: id, time: time, endTime: endTime, title: title, location: title, address: '',
    longitude: 0, latitude: 0, status: status, category: category
  };
  if (transport !== undefined) {
    a.transport = transport;
  }
  return a;
}

const DAY: TripDay = {
  dayIndex: 2, date: '2026-10-26', theme: '东山线', intensity: IntensityLevel.MEDIUM, dailyCost: 0,
  activities: [
    act('a1', '09:00', '11:00', '岚山竹林', ActivityCategory.SIGHT, ActivityStatus.NO_NEED),
    act('a2', '14:00', '15:30', '清水寺', ActivityCategory.SIGHT, ActivityStatus.NO_NEED,
      { mode: '公交', duration: 20, detail: '206路' }),
    act('a3', '15:30', '16:30', '二年坂', ActivityCategory.SIGHT, ActivityStatus.NOT_BOOKED)
  ],
  meals: [
    { type: MealType.LUNCH, time: '12:00', name: '午餐店', location: '祇园', estimatedCost: 120 },
    { type: MealType.DINNER, time: '18:30', name: '晚餐店', location: '河原町', estimatedCost: 200 },
    { type: MealType.BREAKFAST, name: '早餐店', location: '酒店', estimatedCost: 60 }
  ]
};

const TRIP: Trip = {
  id: 't-1', destination: '京都', startDate: '2026-10-24', endDate: '2026-10-28',
  people: 2, budget: 8000, style: 'culture',
  overview: { totalCost: 6000, highlights: [], summary: '' }, days: [], tips: []
};

function emptyDay(): TripDay {
  return {
    dayIndex: 1, date: '2026-10-26', theme: '', intensity: IntensityLevel.LOW, dailyCost: 0,
    activities: [], meals: []
  };
}

export default function liveViewSnapshotTest(): void {
  describe('LiveViewSnapshot', () => {
    it('timeline_merges_meals_and_sorts', TestType.FUNCTION | Size.SMALLTEST | Level.LEVEL0, () => {
      const t: DayTimelineData = DayTimeline.build(DAY, 13 * 60);
      expect(t.total).assertEqual(6);
      expect(t.stops[0].key).assertEqual('meal-2-breakfast');
      expect(t.stops[1].key).assertEqual('a1');
      expect(t.stops[2].key).assertEqual('meal-2-lunch');
      expect(t.currentIndex).assertEqual(2);
      expect(t.progressPct).assertEqual(50);
    });

    it('skip_marker_hidden_but_rest_stop_visible', TestType.FUNCTION | Size.SMALLTEST | Level.LEVEL0, () => {
      const day: TripDay = {
        dayIndex: 1, date: '2026-10-26', theme: '', intensity: IntensityLevel.LOW, dailyCost: 0,
        activities: [
          act('a1', '09:00', '10:00', '岚山', ActivityCategory.SIGHT, ActivityStatus.NO_NEED),
          act('a9', '10:00', '11:00', '空闲', ActivityCategory.REST, ActivityStatus.NO_NEED),
          act('r1', '11:00', '12:00', '回酒店休息', ActivityCategory.REST, ActivityStatus.NO_NEED)
        ],
        meals: []
      };
      const t: DayTimelineData = DayTimeline.build(day, 11 * 60 + 30);
      expect(t.total).assertEqual(2);
      expect(t.stops[1].key).assertEqual('r1');
    });

    it('timeline_finished_and_caps_at_99', TestType.FUNCTION | Size.SMALLTEST | Level.LEVEL0, () => {
      const last: DayTimelineData = DayTimeline.build(DAY, 19 * 60);
      expect(last.progressPct).assertEqual(99);
      expect(last.finished).assertFalse();
      const done: DayTimelineData = DayTimeline.build(DAY, 20 * 60);
      expect(done.progressPct).assertEqual(100);
      expect(done.finished).assertTrue();
    });

    it('snapshot_current_next_and_transport', TestType.FUNCTION | Size.SMALLTEST | Level.LEVEL0, () => {
      const s: LiveViewSnapshot | null = LiveViewSnapshotBuilder.build(TRIP, DAY, 780, 'a2');
      expect(s === null).assertFalse();
      if (s !== null) {
        expect(s.title).assertEqual('Day 2 · 京都');
        expect(s.content[0]).assertEqual('当前 · 12:00 午餐店');
        expect(s.content[1]).assertEqual('下一站 14:00 清水寺');
        expect(s.content[2]).assertEqual('公交 20分钟');
        expect(s.capsuleText).assertEqual('第3站 · 共6站');
        expect(s.canSkip).assertTrue();
        expect(s.stopId).assertEqual('a2');
        expect(s.progressPct).assertEqual(50);
      }
    });

    it('snapshot_not_started', TestType.FUNCTION | Size.SMALLTEST | Level.LEVEL0, () => {
      const s: LiveViewSnapshot | null = LiveViewSnapshotBuilder.build(TRIP, DAY, 420, 'a1');
      expect(s === null).assertFalse();
      if (s !== null) {
        expect(s.content[0]).assertEqual('待出发 · 早餐店');
        expect(s.capsuleText).assertEqual('待出发 · 共6站');
        expect(s.canSkip).assertTrue();
        expect(s.stopId).assertEqual('a1');
      }
    });

    it('snapshot_meal_next_blocks_skip', TestType.FUNCTION | Size.SMALLTEST | Level.LEVEL0, () => {
      const s: LiveViewSnapshot | null = LiveViewSnapshotBuilder.build(TRIP, DAY, 570, 'meal-2-lunch');
      expect(s === null).assertFalse();
      if (s !== null) {
        expect(s.content[1]).assertEqual('下一站 12:00 午餐店');
        expect(s.content.length).assertEqual(2);
        expect(s.canSkip).assertFalse();
        expect(s.stopId).assertEqual('');
      }
    });

    it('snapshot_finished_hides_skip', TestType.FUNCTION | Size.SMALLTEST | Level.LEVEL0, () => {
      const s: LiveViewSnapshot | null = LiveViewSnapshotBuilder.build(TRIP, DAY, 1200, 'a3');
      expect(s === null).assertFalse();
      if (s !== null) {
        expect(s.content.length).assertEqual(1);
        expect(s.content[0]).assertEqual('今日行程已完成');
        expect(s.capsuleText).assertEqual('今日已完成');
        expect(s.canSkip).assertFalse();
        expect(s.finished).assertTrue();
      }
    });

    it('snapshot_empty_day_returns_null', TestType.FUNCTION | Size.SMALLTEST | Level.LEVEL0, () => {
      expect(LiveViewSnapshotBuilder.build(TRIP, emptyDay(), 700, '')).assertNull();
    });

    it('stable_id_stable_and_positive', TestType.FUNCTION | Size.SMALLTEST | Level.LEVEL0, () => {
      const a: number = LiveViewSnapshotBuilder.stableId('t-1', '2026-10-26');
      const b: number = LiveViewSnapshotBuilder.stableId('t-1', '2026-10-26');
      const c: number = LiveViewSnapshotBuilder.stableId('t-1', '2026-10-27');
      expect(a).assertEqual(b);
      expect(a > 0).assertTrue();
      expect(a === c).assertFalse();
    });
  });
}
```

- [ ] **Step 2: 注册到 `List.test.ets`**

在 `import promptContractTest from './PromptContract.test';` 之后插入：

```ts
import liveViewSnapshotTest from './LiveViewSnapshot.test';
```

在 `testsuite()` 末尾的：

```ts
  promptContractTest();
}
```

替换为：

```ts
  promptContractTest();
  liveViewSnapshotTest();
}
```

- [ ] **Step 3: 构建 ohosTest HAP**

Run:
```bash
DEVECO_SDK_HOME=/Applications/DevEco-Studio.app/Contents/sdk \
  /Applications/DevEco-Studio.app/Contents/tools/node/bin/node \
  /Applications/DevEco-Studio.app/Contents/tools/hvigor/bin/hvigorw.js \
  --mode module -p module=entry@ohosTest -p product=default assembleHap \
  --analyze=normal
```

Expected: `BUILD SUCCESSFUL`。若测试构建失败，先修测试文件；不要改实现期望值。

- [ ] **Step 4: 真机跑 hypium**

先确认设备空闲（真人正在用手机时不要安装/注入）：

```bash
HDC=/Applications/DevEco-Studio.app/Contents/sdk/default/openharmony/toolchains/hdc
$HDC -t 192.168.3.2:46077 install -r entry/build/default/outputs/ohosTest/entry-ohosTest-signed.hap
$HDC -t 192.168.3.2:46077 shell aa test -b com.youjing.app -m entry_test \
  -s unittest OpenHarmonyTestRunner -s timeout 120000
```

Expected: 输出 `OK`，失败项 0；`LiveViewSnapshot` 的 9 个 `it` 全部通过。

若锁屏导致 `10106102`：不要尝试绕过锁屏，记录未验边界并请真人解锁后再跑（工程记忆：hdc 锁屏会卡死）。

---

### Task 7: 架构契约补目录

**Files:**
- Modify: `Docs/ARCHITECTURE.md`

- [ ] **Step 1: 目录职责表增加 `liveview/`**

在 `pages/` 行之后插入：

```markdown
| `liveview/` | 实况窗时间轴、视图模型与会话（DayTimeline/LiveViewSnapshot/LiveViewSession）；唯一接触 LiveViewKit 的层 | model（仅类型）、utils、common、@kit LiveViewKit/AbilityKit | pages、components、data、ai、mock、design |
```

把 `pages/` 行的「允许依赖」由 `components、design、common` 改为：

```markdown
| `pages/` | 页面级 @Entry 组件，路由与页面状态编排 | components、design、liveview、common | data、ai、model 的写操作直连（须经 data/、ai/ 层）、mock |
```

- [ ] **Step 2: 依赖方向图增加 liveview**

把：

```text
pages → components → model / data / ai / utils → common
                ↘ design ↗
```

替换为：

```text
pages → components → model / data / ai / utils → common
   ↘ liveview → model / utils / common
                ↘ design ↗
```

- [ ] **Step 3: 依赖规则补一条**

在「`design/` 与 `common/` 同属底层…」那条之后插入：

```markdown
- `liveview/` 只允许依赖 `model/`（仅类型）、`utils/`、`common/`；禁止引用 pages/components/data/ai/mock/design。实况窗内容必须能离线断言，不得在纯逻辑文件里 import `@kit.LiveViewKit`（只有 `LiveViewSession.ets` 例外）。
```

- [ ] **Step 4: 差异说明改为三处**

把 `## 3. 与《有径·App开发文档》§5.4 的差异说明` 下的「本工程新增两处」改为「本工程新增三处」，并在表格末尾追加：

```markdown
| `liveview/` | 实况窗内容与会话独立于页面与数据层：时间轴/视图模型纯逻辑可离线断言，Travel 页与锁屏共用同一口径，系统 API 只收口在一个会话文件 |
```

---

### Task 8: 构建、真机验收与提交

**Files:**
- 无源码改动（本任务只构建、验收、提交）

**Interfaces:**
- Consumes: Task 1–7 的全部产物
- Produces: 一次可回滚的提交 + 真机证据（hilog / 界面截图 / 测试输出）

- [ ] **Step 1: 离线门禁**

Run: `zsh tools/verify_liveview_logic.sh`

Expected:
```text
LIVEVIEW_OK cases=83
LIVEVIEW_LOGIC_OK
```

- [ ] **Step 2: 构建主 HAP**

Run:
```bash
DEVECO_SDK_HOME=/Applications/DevEco-Studio.app/Contents/sdk \
  /Applications/DevEco-Studio.app/Contents/tools/node/bin/node \
  /Applications/DevEco-Studio.app/Contents/tools/hvigor/bin/hvigorw.js \
  --mode module -p module=entry@default -p product=default assembleHap \
  --analyze=normal --parallel
```

Expected: `BUILD SUCCESSFUL`。若有 ArkTS 错误，按报错修实现，不放宽断言。

- [ ] **Step 3: 核对产物不是旧包**

Run:
```bash
ls -l entry/build/default/outputs/default/entry-default-signed.hap
md5 entry/build/default/outputs/default/entry-default-signed.hap
```

Expected: mtime 是本次构建时间；把 md5 记进验收证据。hvigor 的 UP-TO-DATE 会复用旧产物（工程记忆），mtime/md5 不对就 `clean` 后重编。

- [ ] **Step 4: 安装主 HAP**

```bash
HDC=/Applications/DevEco-Studio.app/Contents/sdk/default/openharmony/toolchains/hdc
$HDC -t 192.168.3.2:46077 shell power-shell wakeup
$HDC -t 192.168.3.2:46077 install -r entry/build/default/outputs/default/entry-default-signed.hap
```

Expected: `install success`。若设备锁屏，请真人解锁后再继续；不要绕过锁屏。

- [ ] **Step 5: 真机走查 A —— 无权益静默降级**

前置：设备上有一段覆盖今天的行程；若没有，用 UI 生成一段（生成日期选今天；不改 `TripInputPage.ets`）。

1. 行程列表 → 进入「旅行中」。
2. hero 底部出现「锁屏实况窗」开关（只有今天显示；回看历史日不显示——负例）。
3. 打开开关：
   - 若权益未通过：Toast `实况窗不可用（未开通权益或系统开关关闭）`，开关回弹为关；
   - 页面其余功能正常，不崩、不阻塞。
4. 用 MCP `get_hilog_or_faultlog_recent` 查 `keyword: "YouJing.LiveView"`：
   - 预期看到 `实况窗未开启` 或 `startLiveView 失败 code=1003500005`。
5. 截图/记录开关回弹与 Toast。

Expected: 降级路径完整；把 hilog 关键行记进证据。

- [ ] **Step 6: 真机走查 B —— `go` 意图与「前往中」**

先拿到今天那趟行程的 tripId：进入旅行中页后查 hilog 里的 `进入旅行中 tripId=`。

保持 App 在前台，执行：

```bash
HDC=/Applications/DevEco-Studio.app/Contents/sdk/default/openharmony/toolchains/hdc
$HDC -t 192.168.3.2:46077 shell aa start -a EntryAbility -b com.youjing.app \
  --ps route OnTrip --ps tripId <tripId> --ps act go
```

Expected:
- 仍停在同一个旅行中页（不出现第二层 OnTrip）；
- 下一站卡片出现「前往中」胶囊；顶部提示 `正在前往 <站名> · …`；
- 数据没有被改动（时间、站点、打卡记录都不变）；
- hilog 有 `实况窗意图 act=go trip=<tripId>` 与 `实况窗意图落键 act=go …`。

再执行一次同一条命令，确认 hilog 只有一条 `进入旅行中 tripId=`（没有重复推页）。

- [ ] **Step 7: 真机走查 C —— 陈旧 stopId 被拒**

```bash
$HDC -t 192.168.3.2:46077 shell aa start -a EntryAbility -b com.youjing.app \
  --ps route OnTrip --ps tripId <tripId> --ps act skip --ps stopId not-a-real-stop
```

Expected:
- 页面重载；
- Toast `下一站已变化，请重试`；
- 没有任何重排、没有写库、没有「撤销」；hilog 无 `已跳过` 相关的落库日志。

- [ ] **Step 8: 真机走查 D —— `skip` 意图走 Plan A 的本地兜底**

```bash
$HDC -t 192.168.3.2:46077 shell aa start -a EntryAbility -b com.youjing.app \
  --ps route OnTrip --ps tripId <tripId> --ps act skip
```

前置：`ApiConfig.REPLAN_URL` 为空（仓库默认，Plan A 的口径）。Expected:
- 顶部先出现 `正在重排今日剩余行程…`；
- 随后变成 `已跳过「<站名>」，离线重排`；
- 被跳过项不再出现在列表；后续站点整体后移且不压晚餐/已预约锚点；
- 「撤销」出现；点撤销后恢复，提示 `已撤销重排`；
- 若实况窗此刻开着（有权益时）会被同步更新；无权益时只有页面变化。

- [ ] **Step 9: 真机走查 E —— 运行期切页签**

保持 App 存活，执行：

```bash
$HDC -t 192.168.3.2:46077 shell aa start -a EntryAbility -b com.youjing.app \
  --ps route Map --ps param <tripId>
```

Expected:
- 底部页签切到「地图」（不是只改 AppStorage）；
- hilog 有 `外部请求切页签 1`；
- 再执行 `--ps route OnTrip --ps tripId <tripId>` 能切回行程 tab 并停在旅行中页。

若仍停在原页签：这是 `HdsTabsController.changeIndex` 运行期切换失败的证据，按工程记忆把 `[待验证]` 写清楚；不要为了绕开它去重建整个 Tabs。真机证据（dumpLayout 的选中态）记进验收。

- [ ] **Step 10: 真机走查 F —— 冷启带意图**

```bash
$HDC -t 192.168.3.2:46077 shell aa force-stop com.youjing.app
$HDC -t 192.168.3.2:46077 shell aa start -a EntryAbility -b com.youjing.app \
  --ps route OnTrip --ps tripId <tripId> --ps act go
```

Expected:
- App 冷启直接落在行程 tab 的旅行中页（不是首页）；
- 「前往中」胶囊出现；
- hilog 有 `实况窗意图 act=go`。
- 冷启时 `Index` 的初始 index 生效（不是 `changeIndex`）。

- [ ] **Step 11: 权益门禁项（未开通时只记录，不勾选）**

以下全部是 `[待验证]`，等 AGC「开发调测」权益通过、重签含 `com.huawei.service.liveView.entry` 的 Profile（保留 `com.huawei.service.mapkit`）并重装后再验：

- [ ] 打开开关 → 状态栏胶囊出现：标题 `Day N · 城市`，内容 `第k站 · 共M站` 或 `待出发 · 共M站`。
- [ ] 锁屏/通知中心卡片：标题 `Day N · 城市`，正文当前站 + 下一站 + 通勤，进度条随站点推进。
- [ ] 下一站可跳过时卡片出现「前往下一站 / 不去」两个按钮；下一站是餐次/交通/住宿/已预约时不出现。
- [ ] 点「前往下一站」→ 拉起 App 到旅行中页，「前往中」高亮，数据不变。
- [ ] 点「不去」→ 拉起 App 并重排，重排后实况窗进度/胶囊更新；撤销后更新回原状。
- [ ] 打卡不改变正文（内容去重），hilog 无 `1003500011`。
- [ ] `aa force-stop` 后实况窗自动结束（`AUTO_STOP_WHEN_APP_TERMINATE`）。
- [ ] 会话超过 8 小时自然结束（`aliveTime=28800`）。
- [ ] 若某次更新出现 `resultCode=1..5`，hilog 有 `部分区域失败`，会话继续可用。

Expected: 权益未通过时以上一律不勾；在验收表里标 `[待验证]`，不写成「已实现即可用」。

- [ ] **Step 12: 配置与仓库洁净检查**

Run:
```bash
git status --short
grep -n "REPLAN_URL\|REPLAN_TOKEN" entry/src/main/ets/common/config/ApiConfig.ets
git check-ignore -v entry/build-profile.json5 2>/dev/null || true
```

Expected:
- `git status` 里只有本计划的 12 个文件；
- `ApiConfig.REPLAN_URL` 与 `ApiConfig.REPLAN_TOKEN` 仍是空串（本计划不碰它们）；
- `entry/src/main/ets/pages/TripInputPage.ets` 与 `build-profile.json5` 不在改动列表里。

- [ ] **Step 13: 提交（逐文件 add，不 push）**

```bash
git add entry/src/main/ets/liveview/DayTimeline.ets
git add entry/src/main/ets/liveview/LiveViewSnapshot.ets
git add entry/src/main/ets/liveview/LiveViewSession.ets
git add entry/src/main/ets/common/constants/AppNav.ets
git add entry/src/main/ets/entryability/EntryAbility.ets
git add entry/src/main/ets/pages/Index.ets
git add entry/src/main/ets/pages/OnTripPage.ets
git add entry/src/ohosTest/ets/test/LiveViewSnapshot.test.ets
git add entry/src/ohosTest/ets/test/List.test.ets
git add tools/liveview_check.ts
git add tools/verify_liveview_logic.sh
git add Docs/ARCHITECTURE.md
git commit -m "feat(liveview): 旅行中实况窗会话与两个按钮的深链回流"
git status --short
```

Expected: 提交成功，工作区干净；不执行 `git push`。

- [ ] **Step 14: 证据回填**

把以下内容记进验收证据（提交说明之外，可写进任务/会话记录）：

- `LIVEVIEW_OK cases=83` 与 `LIVEVIEW_LOGIC_OK` 输出；
- 主 HAP 的 md5 与 mtime；
- hypium 的 `OK` 与 9 个 `it` 名单；
- 走查 A–F 的 hilog 关键行与界面截图；
- 权益门禁项的 `[待验证]` 清单。

---

## 验收矩阵

| 层 | 方式 | 判定 |
|---|---|---|
| 时间轴/视图模型（纯逻辑） | `zsh tools/verify_liveview_logic.sh` | `LIVEVIEW_OK cases=83` + `LIVEVIEW_LOGIC_OK` |
| ArkTS 编译 | `check_ets_files` 分层复核 + 主 HAP 构建 | 无诊断 / `BUILD SUCCESSFUL` |
| 端侧回归 | `entry@ohosTest` + `aa test` | `OK`，9 个 `it` 全过 |
| 无权益降级 | 走查 A | 开关回弹 + 日志，主流程不崩 |
| 深链 | 走查 B/C/D/F | go 高亮不改数据；陈旧 stopId 被拒；skip 走 Plan A 兜底；冷启落点正确 |
| 页签运行期切换 | 走查 E | 地图 tab 真切换；失败则记 `[待验证]` |
| 实况窗真机 | 走查 `[待验证]` 清单 | 权益通过后逐项勾，未通过不勾 |

## 已知边界

- **无权益时无法验证锁屏/胶囊/按钮**；本计划只保证代码路径、降级与 App 内深链可验。
- **没有后台定时器**：时间跨站不会自动刷新实况窗；下一次打卡/跳过/撤销/回到页面/深链回流才更新。这是 Live View Kit 的硬约束，不是缺陷。
- **打卡不改正文**：打卡只影响页面按钮状态，快照内容不变，`keyOf` 去重后不推更新；因此不会为了「打卡必须 update」而制造无意义的 sequence 增长。
- **会话状态只在进程内**：`LiveViewSession` 的静态字段跨页面跳转有效，进程重启后清空；`AUTO_STOP_WHEN_APP_TERMINATE` 负责结束旧会话。
- **跨零点不自动续会**：`liveId` 含日期，过了 0 点页面若仍开着，`update` 会因 liveId 不匹配静默不推；旧会话由 8 小时上限/杀进程结束，需要用户在新的一天重新打开开关。
- **部分区域失败**（`resultCode=1..5`）按成功处理并记日志；若胶囊单独失败，页面仍可继续更新。
- **`Index` 的运行期 `changeIndex`** 在本机曾有冷启失败的旧证据；本次只把它用于运行期切换，并以走查 E 的真机结果为准。若运行期也不成立，实况窗按钮从其他 tab 拉起时可能停在原 tab——此时如实记 `[待验证]`，不扩大改动面。
