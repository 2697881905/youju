---
title: "Docs · superpowers · plans · 2026-10-26-skip-replan.md"
id: markdown_cls1_798285c88467638f6a8dc28635ad6f33_f9b68c26016d7e3a3cfcc06ab71b78727526104239726721
kb: 有径-YouJing
folder: "开发文档"
media_type: 7
tags: []
source: ima
exported_at: 2026-11-23T14:52:37.917Z
---
# 跳过与重排（P2）实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 在旅行中页提供「不去下一站」：把该站原地改写为空闲段，由云函数让 LLM 只做决策，端侧排程器重排当日剩余站点并落库；网络/守卫失败一律走本地兜底，全程可撤销。

**Architecture:** 纯逻辑集中在 `data/SkipPlanner`（锚点、游标、通勤、空档、23:59 溢出、本地兜底、决策守卫），可离线断言；`ai/ReplanParser` 只做类型守卫，`ai/ReplanClient` 只做 HTTP；云函数 `cloud/replanDay` 零依赖、Key 只在环境变量；UI 只负责入口、进行中提示、撤销与刷新。

**Tech Stack:** ArkTS（Stage 模型，target/compatible SDK 26.0.0）、hypium、@kit.NetworkKit、AGC 云函数（Node 18+，原生 fetch）、bundled tsc 4.9.5 + node v24（离线断言）。

**Spec:** [`Docs/实况窗方案.md`](file:///Users/itxiaobai/HarmonyProject2/Docs/实况窗方案.md) §3（数据改写）、§3.3（排程规则）、§3.4（云函数契约）、§3.5（失败矩阵与兜底）、§3.6（撤销）、§4（验收）。

## Global Constraints

- **只做 P2**：实况窗会话、按钮、深链在 Plan B；本计划不新增 `liveview/` 目录、不碰 `EntryAbility`。
- **零新列、零迁移**：被跳过的 `Activity` 原地改写，`id` 不变；打卡/费用按 `id` 挂接，落库后仍对得上。
- **纯 ArkTS**：不引入任何运行时依赖；云函数也保持零依赖（`package.json` 只用于 `node --test`）。
- **Key 不进客户端**：`ApiConfig.REPLAN_TOKEN` 仓库内保持空串；开发期真值只写本机。禁止把 token、局域网 IP、云函数真实地址提交进 git。
- **默认走兜底**：`ApiConfig.REPLAN_URL` 仓库内为空串。改它做真机联调后，提交前必须恢复空串。
- **决策与算术分离**：LLM 只返回 `keep` / `freeBlocks` / `note`，绝不返回具体时刻；所有时间算术只在 `SkipPlanner`。
- **守卫是硬边界**：`keep` 的 id 集合必须与端侧 `remainingIds` 完全一致（缺/多/重复都拒绝）；任何拒绝都走本地兜底，不阻塞主流程。
- **今日 + 下一站**：只有 `day.date === DateUtils.todayIso()` 且 `next` 可跳过时才显示入口。餐次、交通、住宿、休息、已预约（BOOKED）不可跳过。
- **溢出是显式降级**：`endTime > 23:59` 时，该项及其后保留原时间并追加「待调整」；校验只对已落位站点要求不重叠（方案 §3.3 的具体条款优先于一般约束）。
- **一个工作包一个提交**：本计划全部完成后只提交一次（Task 9 末尾），逐文件 `git add`，禁止 `git add -A`；`push` 需单独授权。
- **不要动**：`entry/src/main/ets/pages/TripInputPage.ets`（用户正在改）、`build-profile.json5`（含签名、skip-worktree）、`.ohos/config` 下任何签名材料。
- **证据先于结论**：每个 Task 末尾必须跑对应命令并看到预期输出；真机项未跑就标 `[待验证]`，不得口头宣称通过。

## File Structure

| 文件 | 责任 |
| --- | --- |
| `entry/src/main/ets/model/Replan.ets` | 重排 DTO、响应/结果类型、§3.4 的限值常量（端侧与 parser 共用） |
| `entry/src/main/ets/utils/DateUtils.ets` | 新增 `minutesOf` / `hhmmOf`（纯函数） |
| `entry/src/main/ets/data/SkipPlanner.ets` | 剩余站点、锚点、排程、空档消费、守卫、兜底、请求体、深拷贝 |
| `entry/src/main/ets/ai/ReplanParser.ets` | 云函数响应 → `ReplanDecision` 的类型守卫（2xxx 错误码） |
| `entry/src/main/ets/ai/ReplanClient.ets` | POST 云函数、鉴权头、8s 超时预算、失败返回 `null` |
| `entry/src/main/ets/common/config/ApiConfig.ets` | `REPLAN_URL` / `REPLAN_TOKEN` / 2s+6s 超时 |
| `entry/src/main/ets/pages/OnTripPage.ets` | 入口、进行中提示、撤销、落库、卡片刷新 |
| `entry/src/ohosTest/ets/test/SkipPlanner.test.ets` | 端侧回归：排程/兜底/守卫的关键路径 |
| `entry/src/ohosTest/ets/test/ReplanParser.test.ets` | 端侧回归：响应守卫 |
| `entry/src/ohosTest/ets/test/List.test.ets` | 注册两个新用例 |
| `cloud/replanDay/index.js` | 云函数：鉴权、校验、服务端重算剩余、5s LLM、响应守卫 |
| `cloud/replanDay/package.json` | 零依赖；`npm test` → `node --test`（bundled node 24 不接受目录参数） |
| `cloud/replanDay/test/replan.test.js` | 云函数单测（注入 fetch/env） |
| `cloud/replanDay/README.md` | AGC 部署、环境变量、测试事件 |
| `tools/skip_planner_check.ts` | 离线断言：排程、空档、锚点、溢出、守卫、兜底、请求体 |
| `tools/replan_parser_check.ts` | 离线断言：响应守卫 |
| `tools/verify_replan_logic.sh` | 拷贝 `.ets` → `.ts`，tsc --strict + node 跑全部断言 |
| `tools/replan_stub.js` | 真机联调用本地桩：`/replan` 合法、`/replan-invalid` 非法、`/replan-500`、`/replan-slow` |

---

### Task 1: 离线验收脚本与断言（先红）

**Files:**
- Create: `tools/verify_replan_logic.sh`
- Create: `tools/skip_planner_check.ts`
- Create: `tools/replan_parser_check.ts`

**Interfaces:**
- Produces: `SkipPlanner.remainingIds(day, skippedId, nowMin): string[]`、`SkipPlanner.isSkippable(category, status): boolean`、`SkipPlanner.isSkippedMarker(a): boolean`、`SkipPlanner.cloneDay(day): TripDay`、`SkipPlanner.buildRequest(day, skippedId, nowMin): ReplanRequest`、`SkipPlanner.plan(day, skippedId, nowMin, decision: ReplanDecision | null): ReplanOutcome`
- Produces: `ReplanParser.parseDecision(text: string): ReplanDecision`
- Produces: `DateUtils.minutesOf(hhmm: string): number`（非法 -1）、`DateUtils.hhmmOf(minutes: number): string`

- [ ] **Step 1: 写离线断言 `tools/skip_planner_check.ts`**

```ts
/**
 * SkipPlanner 离线断言：被 tools/verify_replan_logic.sh 拷进临时目录后
 * 用 bundled tsc --strict 编译、bundled node 运行。不依赖 @kit / 设备。
 */

import {
  Activity, ActivityCategory, ActivityStatus, IntensityLevel, Meal, MealType, TransportInfo, TripDay
} from '../model/Trip';
import { FreeBlock, KeepStop, ReplanDecision } from '../model/Replan';
import { SkipPlanner } from '../data/SkipPlanner';
import { DateUtils } from '../utils/DateUtils';

let cases = 0;

function ok(cond: boolean, msg: string): void {
  cases += 1;
  if (!cond) {
    throw new Error(`FAIL: ${msg}`);
  }
}

function eq(actual: string | number | boolean, expected: string | number | boolean, msg: string): void {
  cases += 1;
  if (actual !== expected) {
    throw new Error(`FAIL: ${msg}（actual=${actual} expected=${expected}）`);
  }
}

function act(id: string, time: string, endTime: string, title: string,
  category: ActivityCategory = ActivityCategory.SIGHT,
  status: ActivityStatus = ActivityStatus.NOT_BOOKED,
  transportMin: number = 0): Activity {
  const a: Activity = {
    id: id, time: time, endTime: endTime, title: title, location: 'loc', address: 'addr',
    longitude: 1, latitude: 2, status: status, category: category
  };
  if (transportMin > 0) {
    const t: TransportInfo = { mode: '步行', duration: transportMin, detail: '' };
    a.transport = t;
  }
  return a;
}

function meal(type: MealType, time?: string): Meal {
  const m: Meal = { type: type, name: 'meal', location: 'loc', estimatedCost: 0 };
  if (time !== undefined) {
    m.time = time;
  }
  return m;
}

function dayOf(acts: Activity[], meals: Meal[]): TripDay {
  const d: TripDay = {
    dayIndex: 1, date: '2026-10-26', theme: 't', intensity: IntensityLevel.LOW,
    dailyCost: 0, activities: acts, meals: meals
  };
  return d;
}

function keepOf(id: string, dwellMin: number): KeepStop {
  const k: KeepStop = { id: id, dwellMin: dwellMin };
  return k;
}

function blockOf(afterId: string, minutes: number): FreeBlock {
  const b: FreeBlock = { afterId: afterId, minutes: minutes };
  return b;
}

function decisionOf(keep: KeepStop[], blocks: FreeBlock[], note: string): ReplanDecision {
  const d: ReplanDecision = { schemaVersion: 1, keep: keep, freeBlocks: blocks, note: note };
  return d;
}

function find(day: TripDay, id: string): Activity {
  for (const a of day.activities) {
    if (a.id === id) {
      return a;
    }
  }
  throw new Error(`missing activity ${id}`);
}

/** now=14:05；a2 是可跳过的下一站；a5 是已预约锚点；两餐是餐次锚点 */
function mainDay(): TripDay {
  return dayOf([
    act('a1', '09:00', '10:00', '早饭散步'),
    act('a2', '14:00', '15:00', '清水寺'),
    act('a3', '15:30', '16:30', '二年坂', ActivityCategory.SIGHT, ActivityStatus.NOT_BOOKED, 10),
    act('a4', '16:45', '17:30', '锦市场', ActivityCategory.SHOP, ActivityStatus.NO_NEED, 5),
    act('a5', '19:00', '20:00', '夜景', ActivityCategory.SIGHT, ActivityStatus.BOOKED)
  ], [meal(MealType.LUNCH, '12:00'), meal(MealType.DINNER, '18:00')]);
}

// ---- 时间原语 ----
eq(DateUtils.minutesOf('00:00'), 0, 'minutesOf 00:00');
eq(DateUtils.minutesOf('23:59'), 1439, 'minutesOf 23:59');
eq(DateUtils.minutesOf('24:00'), -1, 'minutesOf 拒绝 24:00');
eq(DateUtils.minutesOf('9:00'), -1, 'minutesOf 拒绝非两位小时');
eq(DateUtils.hhmmOf(1439), '23:59', 'hhmmOf 23:59');
eq(DateUtils.hhmmOf(1440), '23:59', 'hhmmOf 上界夹紧');

// ---- 可跳过判定 ----
ok(SkipPlanner.isSkippable(ActivityCategory.SIGHT, ActivityStatus.NOT_BOOKED), '景点未预约可跳过');
ok(!SkipPlanner.isSkippable(ActivityCategory.SIGHT, ActivityStatus.BOOKED), '已预约不可跳过');
ok(!SkipPlanner.isSkippable(ActivityCategory.TRANSPORT, ActivityStatus.NO_NEED), '交通不可跳过');
ok(!SkipPlanner.isSkippable(ActivityCategory.HOTEL, ActivityStatus.NO_NEED), '住宿不可跳过');
ok(!SkipPlanner.isSkippable(ActivityCategory.REST, ActivityStatus.NO_NEED), '空闲不可跳过');
ok(!SkipPlanner.isSkippable(null, ActivityStatus.NO_NEED), '餐次（null）不可跳过');

// ---- 剩余站点：REST 仍是站点，只有被跳过的那个 id 排除 ----
eq(SkipPlanner.remainingIds(mainDay(), 'a2', 845).join(','), 'a3,a4',
  '剩余 = 非交通/住宿 + 非 BOOKED + 未发生 + 非 skippedId');
const restDay = dayOf([
  act('a2', '14:00', '15:00', '可跳过'),
  act('r1', '15:10', '15:40', '休息', ActivityCategory.REST, ActivityStatus.NO_NEED)
], []);
eq(SkipPlanner.remainingIds(restDay, 'a2', 845).join(','), 'r1', 'REST 不是锚点，仍在剩余里');

// ---- 合法决策：顺序可换、通勤归到达站、锚点不动 ----
const base = mainDay();
const outcome = SkipPlanner.plan(base, 'a2', 845,
  decisionOf([keepOf('a4', 40), keepOf('a3', 60)], [], '下午节奏放缓'));
ok(!outcome.usedFallback, '合法决策不走兜底');
const out = outcome.day;
eq(find(out, 'a2').category, ActivityCategory.REST, '被跳过项改为 REST');
eq(find(out, 'a2').title, '空闲', '被跳过项标题');
eq(find(out, 'a2').status, ActivityStatus.NO_NEED, '被跳过项状态');
eq(find(out, 'a2').note ?? '', '已跳过：清水寺', '被跳过项保留来源');
eq(find(out, 'a2').time, '14:00', '被跳过项保留开始时刻');
eq(find(out, 'a2').endTime, '15:00', '被跳过项保留结束时刻');
eq(find(out, 'a4').time, '15:05', '第一项也吃通勤 5 分钟');
eq(find(out, 'a4').endTime, '15:45', '第一项按 dwell 落位');
eq(find(out, 'a3').time, '15:55', '第二项吃自身通勤 10 分钟');
eq(find(out, 'a3').endTime, '16:55', '第二项按 dwell 落位');
eq(find(out, 'a5').time, '19:00', '已预约锚点不动');
eq(out.activities.map((a: Activity): string => a.id).join(','), 'a1,a2,a3,a4,a5', '活动顺序不变');
ok(outcome.note.indexOf('下午节奏放缓') >= 0, '页面提示带决策备注');

// ---- 空档：afterId 当前结束时刻被游标越过才消费；过去的空档忽略 ----
// keep 必须覆盖全部剩余站点（a3、a4），少一项就会被守卫判非法走兜底
const f1 = SkipPlanner.plan(mainDay(), 'a2', 845,
  decisionOf([keepOf('a3', 60), keepOf('a4', 40)], [blockOf('a2', 30)], ''));
eq(find(f1.day, 'a3').time, '15:40', '跳过段后的空档先加 30 分钟');
ok(!f1.usedFallback, '空档路径不触发兜底');

const f2 = SkipPlanner.plan(mainDay(), 'a2', 845,
  decisionOf([keepOf('a3', 60), keepOf('a4', 40)], [blockOf('a1', 30)], ''));
eq(find(f2.day, 'a3').time, '15:10', '已过去的 afterId 空档忽略');

const f3 = SkipPlanner.plan(mainDay(), 'a2', 845,
  decisionOf([keepOf('a3', 60), keepOf('a4', 40)], [blockOf('a3', 20)], ''));
eq(find(f3.day, 'a3').time, '15:10', '保留项先落位');
eq(find(f3.day, 'a4').time, '16:35', '保留项之后的空档在下一项前消费');
ok(!f3.usedFallback, '保留项空档路径不触发兜底');

// ---- 跨锚点：落位会跨过晚餐则移到锚点结束 ----
const crossDay = dayOf([
  act('a2', '17:00', '17:30', '可跳过'),
  act('a3', '18:30', '19:30', '下一站')
], [meal(MealType.DINNER, '18:00')]);
const cross = SkipPlanner.plan(crossDay, 'a2', 1020, decisionOf([keepOf('a3', 120)], [], ''));
eq(find(cross.day, 'a3').time, '19:00', '跨晚餐锚点时移到 19:00');

// ---- 23:59 溢出：该项及之后保留原时间 + 待调整 ----
const lateDay = dayOf([
  act('a2', '21:30', '22:00', '夜游'),
  act('a3', '22:10', '22:40', '塔'),
  act('a4', '22:50', '23:20', '桥')
], []);
const late = SkipPlanner.plan(lateDay, 'a2', 1320,
  decisionOf([keepOf('a3', 60), keepOf('a4', 60)], [], ''));
ok(!late.usedFallback, '溢出不是兜底，是决策路径的降级');
eq(find(late.day, 'a3').time, '22:00', '溢出前的站点正常落位');
eq(find(late.day, 'a4').time, '22:50', '溢出项保留原时间');
ok((find(late.day, 'a4').note ?? '').indexOf('待调整') >= 0, '溢出项 note 追加待调整');
ok(late.note.indexOf('部分站点待调整') >= 0, '页面提示带溢出后缀');

// ---- 守卫：缺项/多项/重复/越界/未知 afterId/超长 note/schema 不符 ----
const rejects: ReplanDecision[] = [
  decisionOf([keepOf('a3', 60)], [], ''),
  decisionOf([keepOf('a3', 60), keepOf('a4', 40), keepOf('a1', 30)], [], ''),
  decisionOf([keepOf('a3', 60), keepOf('a3', 60)], [], ''),
  decisionOf([keepOf('a3', 10), keepOf('a4', 40)], [], ''),
  decisionOf([keepOf('a3', 241), keepOf('a4', 40)], [], ''),
  decisionOf([keepOf('a3', 60), keepOf('a4', 40)], [blockOf('a3', 10)], ''),
  decisionOf([keepOf('a3', 60), keepOf('a4', 40)], [blockOf('zz', 30)], ''),
  decisionOf([keepOf('a3', 60), keepOf('a4', 40)], [], 'x'.repeat(201))
];
for (let i = 0; i < rejects.length; i++) {
  const r = SkipPlanner.plan(mainDay(), 'a2', 845, rejects[i]);
  ok(r.usedFallback, `非法决策 #${i} 必须走兜底`);
  eq(find(r.day, 'a2').title, '空闲', `非法决策 #${i} 仍完成跳过改写`);
}
const schema2: ReplanDecision = {
  schemaVersion: 2, keep: [keepOf('a3', 60), keepOf('a4', 40)], freeBlocks: [], note: ''
};
ok(SkipPlanner.plan(mainDay(), 'a2', 845, schema2).usedFallback, 'schemaVersion 不符走兜底');

// ---- 本地兜底：整体后移 + 锚点冲突整体再顺延 ----
const fb = SkipPlanner.plan(mainDay(), 'a2', 845, null);
ok(fb.usedFallback, '无决策走本地兜底');
eq(find(fb.day, 'a3').time, '20:00', '兜底后移并避开晚餐/已预约锚点');
eq(find(fb.day, 'a4').time, '21:15', '兜底保持相对顺序');
ok(fb.note.indexOf('离线重排') >= 0, '兜底提示文案');

const lateFb = SkipPlanner.plan(dayOf([
  act('a2', '22:30', '23:00', '夜游'),
  act('a3', '23:10', '23:40', '塔'),
  act('a4', '23:45', '23:59', '桥')
], []), 'a2', 1380, null);
ok(lateFb.usedFallback, '兜底溢出仍是兜底');
eq(find(lateFb.day, 'a3').time, '23:10', '兜底溢出项保留原时间');
ok((find(lateFb.day, 'a3').note ?? '').indexOf('待调整') >= 0, '兜底溢出项追加待调整');
ok(lateFb.note.indexOf('部分站点待调整') >= 0, '兜底溢出提示带后缀');

// ---- 请求体：发送重写前的整日，不信任客户端剩余列表 ----
const req = SkipPlanner.buildRequest(mainDay(), 'a2', 845);
eq(req.schemaVersion, 1, '请求 schemaVersion');
eq(req.now, '14:05', '请求 now');
eq(req.day.activities.length, 5, '请求含整日全部活动（含被跳过项）');
eq(req.day.meals.length, 2, '请求含全部餐次');
eq(req.day.activities[2].transport?.duration ?? -1, 10, '通勤时长随请求上传');
eq(req.day.meals[0].time ?? '', '12:00', '餐次时刻随请求上传');
const rawFirst = req.day.activities[0] as unknown as Record<string, Object>;
ok(rawFirst['note'] === undefined && rawFirst['reason'] === undefined, '请求不携带 note/reason');

// ---- 深拷贝：改 clone 不能回写原日 ----
const original = mainDay();
const clone = SkipPlanner.cloneDay(original);
clone.activities[2].title = '改名';
if (clone.activities[2].transport !== undefined) {
  clone.activities[2].transport.duration = 99;
}
eq(find(original, 'a3').title, '二年坂', 'cloneDay 活动标题深拷贝');
eq(find(original, 'a3').transport?.duration ?? -1, 10, 'cloneDay 通勤深拷贝');

console.log(`SKIP_PLANNER_OK cases=${cases}`);
```

- [ ] **Step 2: 写离线断言 `tools/replan_parser_check.ts`**

```ts
/** ReplanParser 离线断言：响应必须是 schemaVersion=1 的严格 JSON。 */

import { ReplanParser } from '../ai/ReplanParser';
import { ReplanDecision } from '../model/Replan';
import { AppError } from '../common/error/AppError';
import { ErrorCode } from '../common/error/ErrorCode';

let cases = 0;

function ok(cond: boolean, msg: string): void {
  cases += 1;
  if (!cond) {
    throw new Error(`FAIL: ${msg}`);
  }
}

function eq(actual: string | number, expected: string | number, msg: string): void {
  cases += 1;
  if (actual !== expected) {
    throw new Error(`FAIL: ${msg}（actual=${actual} expected=${expected}）`);
  }
}

function codeOf(fn: () => void): number {
  try {
    fn();
    return 0;
  } catch (err) {
    if (err instanceof AppError) {
      return err.code;
    }
    return -1;
  }
}

function keepOf(id: string, dwellMin: number): Record<string, Object> {
  return { 'id': id, 'dwellMin': dwellMin };
}

function textOf(root: Record<string, Object>): string {
  return JSON.stringify(root);
}

const validText = '```json\n' + textOf({
  'schemaVersion': 1,
  'keep': [keepOf('a3', 60), keepOf('a4', 45)],
  'freeBlocks': [{ 'afterId': 'a2', 'minutes': 30 }],
  'note': '下午节奏放缓'
}) + '\n```';
const d: ReplanDecision = ReplanParser.parseDecision(validText);
eq(d.schemaVersion, 1, 'schemaVersion');
eq(d.keep.length, 2, 'keep 长度');
eq(d.keep[1].id, 'a4', 'keep id');
eq(d.keep[1].dwellMin, 45, 'dwellMin');
eq(d.freeBlocks.length, 1, 'freeBlocks 长度');
eq(d.freeBlocks[0].afterId, 'a2', 'afterId');
eq(d.freeBlocks[0].minutes, 30, 'minutes');
eq(d.note, '下午节奏放缓', 'note');

const minimal = ReplanParser.parseDecision(textOf({ 'schemaVersion': 1, 'keep': [keepOf('a3', 15)] }));
eq(minimal.freeBlocks.length, 0, 'freeBlocks 可省略');
eq(minimal.note, '', 'note 可省略');
eq(minimal.keep[0].dwellMin, 15, 'dwellMin 下界 15 接受');

eq(codeOf(() => ReplanParser.parseDecision('not json at all')), ErrorCode.JSON_PARSE_FAILED, '非 JSON → 2001');
eq(codeOf(() => ReplanParser.parseDecision(textOf({ 'keep': [] }))),
  ErrorCode.SCHEMA_VALIDATION_FAILED, '缺 schemaVersion → 2002');
eq(codeOf(() => ReplanParser.parseDecision(textOf({ 'schemaVersion': 2, 'keep': [] }))),
  ErrorCode.SCHEMA_VALIDATION_FAILED, 'schemaVersion=2 → 2002');
eq(codeOf(() => ReplanParser.parseDecision(textOf({ 'schemaVersion': 1, 'keep': 'x' }))),
  ErrorCode.TYPE_GUARD_FAILED, 'keep 非数组 → 2003');
eq(codeOf(() => ReplanParser.parseDecision(textOf({ 'schemaVersion': 1 }))),
  ErrorCode.SCHEMA_VALIDATION_FAILED, '缺 keep → 2002');
eq(codeOf(() => ReplanParser.parseDecision(textOf({
  'schemaVersion': 1, 'keep': Array.from({ length: 21 }, (_, i) => keepOf(`a${i}`, 60))
}))), ErrorCode.SCHEMA_VALIDATION_FAILED, 'keep 超 20 → 2002');
eq(codeOf(() => ReplanParser.parseDecision(textOf({
  'schemaVersion': 1, 'keep': [keepOf('a3', 14)]
}))), ErrorCode.SCHEMA_VALIDATION_FAILED, 'dwellMin 14 → 2002');
eq(codeOf(() => ReplanParser.parseDecision(textOf({
  'schemaVersion': 1, 'keep': [keepOf('a3', 241)]
}))), ErrorCode.SCHEMA_VALIDATION_FAILED, 'dwellMin 241 → 2002');
eq(codeOf(() => ReplanParser.parseDecision(textOf({
  'schemaVersion': 1, 'keep': [keepOf('a3', 60.5)]
}))), ErrorCode.TYPE_GUARD_FAILED, 'dwellMin 非整数 → 2003');
eq(codeOf(() => ReplanParser.parseDecision(textOf({
  'schemaVersion': 1, 'keep': [keepOf('a3', 60), keepOf('a3', 60)]
}))), ErrorCode.TYPE_GUARD_FAILED, 'keep id 重复 → 2003');
eq(codeOf(() => ReplanParser.parseDecision(textOf({
  'schemaVersion': 1, 'keep': [], 'freeBlocks': [
    { 'afterId': 'a1', 'minutes': 30 }, { 'afterId': 'a2', 'minutes': 30 },
    { 'afterId': 'a3', 'minutes': 30 }, { 'afterId': 'a4', 'minutes': 30 }
  ]
}))), ErrorCode.SCHEMA_VALIDATION_FAILED, 'freeBlocks 超 3 → 2002');
eq(codeOf(() => ReplanParser.parseDecision(textOf({
  'schemaVersion': 1, 'keep': [], 'freeBlocks': [{ 'afterId': 'a1', 'minutes': 10 }]
}))), ErrorCode.SCHEMA_VALIDATION_FAILED, 'minutes 10 → 2002');
eq(codeOf(() => ReplanParser.parseDecision(textOf({
  'schemaVersion': 1, 'keep': [], 'note': 'x'.repeat(201)
}))), ErrorCode.SCHEMA_VALIDATION_FAILED, 'note 超 200 → 2002');
eq(codeOf(() => ReplanParser.parseDecision(textOf({
  'schemaVersion': 1, 'keep': [keepOf('', 60)]
}))), ErrorCode.TYPE_GUARD_FAILED, 'id 空串 → 2003');

const extra = ReplanParser.parseDecision(textOf({
  'schemaVersion': 1, 'keep': [keepOf('a3', 60)], 'unknown': 'ignored'
}));
eq(extra.keep.length, 1, '未知字段忽略');

console.log(`REPLAN_PARSER_OK cases=${cases}`);
```

- [ ] **Step 3: 写 `tools/verify_replan_logic.sh`**

```bash
#!/usr/bin/env bash
# 纯逻辑离线验收：把不依赖 @kit 的 .ets 拷成 .ts，bundled tsc --strict 后再用 bundled node 跑断言。
# 用法：zsh tools/verify_replan_logic.sh
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
copy entry/src/main/ets/model/Replan.ets model/Replan.ts
copy entry/src/main/ets/utils/DateUtils.ets utils/DateUtils.ts
copy entry/src/main/ets/common/error/AppError.ets common/error/AppError.ts
copy entry/src/main/ets/common/error/ErrorCode.ets common/error/ErrorCode.ts
copy entry/src/main/ets/ai/TripSchema.ets ai/TripSchema.ts
copy entry/src/main/ets/ai/TripParser.ets ai/TripParser.ts
copy entry/src/main/ets/data/SkipPlanner.ets data/SkipPlanner.ts
copy entry/src/main/ets/ai/ReplanParser.ets ai/ReplanParser.ts
copy tools/skip_planner_check.ts tools/skip_planner_check.ts
copy tools/replan_parser_check.ts tools/replan_parser_check.ts

"$TSC" --strict --noEmitOnError --target ES2020 --module commonjs --moduleResolution node \
  --lib ES2020,DOM --rootDir "$TMP" --outDir "$TMP/out" \
  "$TMP/tools/skip_planner_check.ts" "$TMP/tools/replan_parser_check.ts"

"$NODE" "$TMP/out/tools/skip_planner_check.js"
"$NODE" "$TMP/out/tools/replan_parser_check.js"
echo "REPLAN_LOGIC_OK"
```

- [ ] **Step 4: 跑脚本确认「红」**

Run: `zsh tools/verify_replan_logic.sh`
Expected: FAIL，`Cannot find module '../model/Replan'`（或 `SkipPlanner` 不存在）。这一步证明脚本确实在编译新代码，而不是空跑。

---

### Task 2: 时间原语 + 重排数据契约

**Files:**
- Modify: `entry/src/main/ets/utils/DateUtils.ets`（在 `todayIso()` 后追加）
- Create: `entry/src/main/ets/model/Replan.ets`

**Interfaces:**
- Produces: `DateUtils.minutesOf` / `DateUtils.hhmmOf`
- Produces: `KeepStop`、`FreeBlock`、`ReplanDecision`、`ReplanOutcome`、`ReplanTransport`、`ReplanRequestActivity`、`ReplanRequestMeal`、`ReplanRequestDay`、`ReplanRequest`、`REPLAN_SCHEMA_VERSION` 与 §3.4 限值常量

- [ ] **Step 1: 给 `DateUtils` 追加两个纯函数**

在 `entry/src/main/ets/utils/DateUtils.ets` 的 `todayIso()` 之后、类结束 `}` 之前插入：

```ts
  /** HH:mm → 当日分钟数；格式/范围非法返回 -1（调用方决定回退口径） */
  static minutesOf(hhmm: string): number {
    if (!/^\d{2}:\d{2}$/.test(hhmm)) {
      return -1;
    }
    const parts: string[] = hhmm.split(':');
    const h: number = Number(parts[0]);
    const m: number = Number(parts[1]);
    if (h > 23 || m > 59) {
      return -1;
    }
    return h * 60 + m;
  }

  /** 当日分钟数 → HH:mm；越界夹到 [00:00, 23:59] */
  static hhmmOf(minutes: number): string {
    const clamped: number = Math.max(0, Math.min(1439, Math.round(minutes)));
    const h: string = `${Math.floor(clamped / 60)}`.padStart(2, '0');
    const m: string = `${clamped % 60}`.padStart(2, '0');
    return `${h}:${m}`;
  }
```

- [ ] **Step 2: 新建 `entry/src/main/ets/model/Replan.ets`**

```ts
/**
 * 跳过与重排的数据契约（方案 §3.4）。
 * 客户端 ↔ 云函数只交换请求/响应两种结构；时间算术留在 data/SkipPlanner。
 */

import { ActivityCategory, ActivityStatus, MealType, TripDay } from './Trip';

export const REPLAN_SCHEMA_VERSION: number = 1;
export const REPLAN_MIN_DWELL: number = 15;
export const REPLAN_MAX_DWELL: number = 240;
export const REPLAN_MAX_KEEP: number = 20;
export const REPLAN_MAX_FREE_BLOCKS: number = 3;
export const REPLAN_MIN_FREE_MIN: number = 15;
export const REPLAN_MAX_FREE_MIN: number = 480;
export const REPLAN_MAX_NOTE: number = 200;

/** LLM 的单项决策：保留谁、停多久。 */
export interface KeepStop {
  id: string;
  dwellMin: number;
}

/** LLM 的额外空档：放在 afterId 结束之后，不写进模型。 */
export interface FreeBlock {
  afterId: string;
  minutes: number;
}

/** 云函数响应（经 ReplanParser 守卫后的内存形态）。 */
export interface ReplanDecision {
  schemaVersion: number;
  keep: KeepStop[];
  freeBlocks: FreeBlock[];
  note: string;
}

/** 端侧排程结果：day 是改写后的深拷贝；note 给页面顶部提示。 */
export interface ReplanOutcome {
  day: TripDay;
  note: string;
  usedFallback: boolean;
}

/** 请求里只带通勤时长，不带方式/详情（§3.4 示例）。 */
export interface ReplanTransport {
  duration: number;
}

export interface ReplanRequestActivity {
  id: string;
  time: string;
  endTime: string;
  title: string;
  category: ActivityCategory;
  status: ActivityStatus;
  longitude: number;
  latitude: number;
  transport?: ReplanTransport;
}

export interface ReplanRequestMeal {
  type: MealType;
  time?: string;
}

export interface ReplanRequestDay {
  date: string;
  activities: ReplanRequestActivity[];
  meals: ReplanRequestMeal[];
}

export interface ReplanRequest {
  schemaVersion: number;
  now: string;
  skippedId: string;
  day: ReplanRequestDay;
}
```

- [ ] **Step 3: 确认接口可编译**

Run: `zsh tools/verify_replan_logic.sh`
Expected: 仍 FAIL，但错误前移到 `Cannot find module '../data/SkipPlanner'`——说明 `DateUtils` 与 `Replan` 已能被 tsc 解析。

---

### Task 3: SkipPlanner（排程 / 守卫 / 兜底 / 请求体）

**Files:**
- Create: `entry/src/main/ets/data/SkipPlanner.ets`

**Interfaces:**
- Consumes: `DateUtils.minutesOf/hhmmOf`、`Replan.ets` 全部类型与限值
- Produces: `SkipPlanner.isSkippable(category: ActivityCategory | null, status: ActivityStatus | null): boolean`
- Produces: `SkipPlanner.isSkippedMarker(a: Activity): boolean`
- Produces: `SkipPlanner.cloneDay(day: TripDay): TripDay`
- Produces: `SkipPlanner.remainingIds(day: TripDay, skippedId: string, nowMin: number): string[]`
- Produces: `SkipPlanner.buildRequest(day: TripDay, skippedId: string, nowMin: number): ReplanRequest`
- Produces: `SkipPlanner.plan(day: TripDay, skippedId: string, nowMin: number, decision: ReplanDecision | null): ReplanOutcome`

- [ ] **Step 1: 实现 `SkipPlanner`**

```ts
/**
 * 跳过与重排的端侧纯逻辑（方案 §3.3 / §3.5）。
 *
 * 分工：LLM 只决定「保留谁、每站停多久、空档放哪」；时间算术全部在这里，
 * 可离线断言，不依赖 @kit / RDB / UI。
 */

import {
  Activity, ActivityCategory, ActivityStatus, Meal, TransportInfo, TripDay
} from '../model/Trip';
import {
  FreeBlock, KeepStop, ReplanDecision, ReplanOutcome, ReplanRequest, ReplanRequestActivity,
  ReplanRequestDay, ReplanRequestMeal, ReplanTransport, REPLAN_MAX_DWELL, REPLAN_MAX_FREE_BLOCKS,
  REPLAN_MAX_FREE_MIN, REPLAN_MAX_KEEP, REPLAN_MAX_NOTE, REPLAN_MIN_DWELL, REPLAN_MIN_FREE_MIN,
  REPLAN_SCHEMA_VERSION
} from '../model/Replan';
import { DateUtils } from '../utils/DateUtils';

const DAY_END: number = 1439;
const MEAL_ANCHOR_MIN: number = 60;
const DEFAULT_DWELL_MIN: number = 60;
const CARRY_MARK: string = '待调整';
const FREE_TITLE: string = '空闲';
const SKIP_NOTE_PREFIX: string = '已跳过：';
const MAX_SETTLE_LOOP: number = 32;

interface Span {
  start: number;
  end: number;
}

interface FreeState {
  afterId: string;
  minutes: number;
  used: boolean;
  expired: boolean;
}

interface ScheduleResult {
  overflow: boolean;
  overflowFrom: number;
}

interface FallbackResult {
  day: TripDay;
  overflow: boolean;
}

export class SkipPlanner {
  /** 旅行中页的「不去」入口只看这条；排程的 remaining 口径更宽（REST 仍算站点）。 */
  static isSkippable(category: ActivityCategory | null, status: ActivityStatus | null): boolean {
    if (category === null || status === null || status === ActivityStatus.BOOKED) {
      return false;
    }
    return category !== ActivityCategory.TRANSPORT && category !== ActivityCategory.HOTEL &&
      category !== ActivityCategory.REST;
  }

  /** 上一次跳过留下的空闲段：界面上不再当可打卡站点展示，但它仍是排程锚点。 */
  static isSkippedMarker(a: Activity): boolean {
    return a.category === ActivityCategory.REST && a.status === ActivityStatus.NO_NEED &&
      a.title === FREE_TITLE;
  }

  /** 深拷贝当日，供改写 / 撤销快照使用；TripDay 的字段全部显式复制。 */
  static cloneDay(day: TripDay): TripDay {
    const acts: Activity[] = [];
    for (const a of day.activities) {
      acts.push(SkipPlanner.cloneActivity(a));
    }
    const meals: Meal[] = [];
    for (const m of day.meals) {
      meals.push(SkipPlanner.cloneMeal(m));
    }
    const copy: TripDay = {
      dayIndex: day.dayIndex,
      date: day.date,
      theme: day.theme,
      intensity: day.intensity,
      dailyCost: day.dailyCost,
      activities: acts,
      meals: meals
    };
    if (day.risk !== undefined) {
      copy.risk = day.risk;
    }
    if (day.accommodation !== undefined) {
      copy.accommodation = day.accommodation;
    }
    return copy;
  }

  /**
   * 方案 §3.3 的「剩余站点」：当日 activities 中
   * id ≠ skippedId、category ∉ {TRANSPORT, HOTEL}、status ≠ BOOKED、time ≥ nowMinutes。
   * 注意：REST 不是锚点，仍会出现在这里（只有本次被跳过的那个 id 排除）。
   */
  static remainingIds(day: TripDay, skippedId: string, nowMin: number): string[] {
    const ids: string[] = [];
    for (const a of day.activities) {
      if (a.id === skippedId) {
        continue;
      }
      if (a.category === ActivityCategory.TRANSPORT || a.category === ActivityCategory.HOTEL) {
        continue;
      }
      if (a.status === ActivityStatus.BOOKED) {
        continue;
      }
      if (DateUtils.minutesOf(a.time) < nowMin) {
        continue;
      }
      ids.push(a.id);
    }
    return ids;
  }

  /** 请求发送「重写前」的整日；剩余列表由云函数自行重算（§3.4）。 */
  static buildRequest(day: TripDay, skippedId: string, nowMin: number): ReplanRequest {
    const acts: ReplanRequestActivity[] = [];
    for (const a of day.activities) {
      const item: ReplanRequestActivity = {
        id: a.id,
        time: a.time,
        endTime: a.endTime,
        title: a.title,
        category: a.category,
        status: a.status,
        longitude: a.longitude,
        latitude: a.latitude
      };
      if (a.transport !== undefined) {
        const t: ReplanTransport = { duration: a.transport.duration };
        item.transport = t;
      }
      acts.push(item);
    }
    const meals: ReplanRequestMeal[] = [];
    for (const m of day.meals) {
      const item: ReplanRequestMeal = { type: m.type };
      if (m.time !== undefined) {
        item.time = m.time;
      }
      meals.push(item);
    }
    const requestDay: ReplanRequestDay = { date: day.date, activities: acts, meals: meals };
    const request: ReplanRequest = {
      schemaVersion: REPLAN_SCHEMA_VERSION,
      now: DateUtils.hhmmOf(nowMin),
      skippedId: skippedId,
      day: requestDay
    };
    return request;
  }

  /**
   * 主入口。decision 为 null 或未通过守卫 → 本地兜底。
   * 无论走哪条路，都会完成「被跳过项原地改写」。
   */
  static plan(day: TripDay, skippedId: string, nowMin: number,
    decision: ReplanDecision | null): ReplanOutcome {
    const index: number = SkipPlanner.indexOf(day, skippedId);
    if (index < 0) {
      const copy: TripDay = SkipPlanner.cloneDay(day);
      const missNote: string = '未找到要跳过的站点';
      const miss: ReplanOutcome = { day: copy, note: missNote, usedFallback: false };
      return miss;
    }
    const skipped: Activity = day.activities[index];
    const title: string = skipped.title;
    const startMin: number = SkipPlanner.startOf(skipped);
    const endMin: number = SkipPlanner.normalizedEnd(skipped, startMin);
    const remainIds: string[] = SkipPlanner.remainingIds(day, skippedId, nowMin);

    if (decision !== null && SkipPlanner.accept(day, decision, remainIds)) {
      const work: TripDay = SkipPlanner.cloneDay(day);
      SkipPlanner.rewriteSkipped(work.activities[index], startMin, endMin, title);
      const scheduled: ScheduleResult = SkipPlanner.schedule(work, skippedId, startMin, endMin,
        nowMin, decision);
      const placedIds: string[] = [];
      for (let i = 0; i < scheduled.overflowFrom; i++) {
        placedIds.push(decision.keep[i].id);
      }
      const carryIds: string[] = [];
      for (let i = scheduled.overflowFrom; i < decision.keep.length; i++) {
        carryIds.push(decision.keep[i].id);
      }
      if (SkipPlanner.valid(work, day, skippedId, nowMin, placedIds, carryIds)) {
        const note: string = SkipPlanner.noteFor(title, decision, scheduled.overflow, false);
        const okOutcome: ReplanOutcome = { day: work, note: note, usedFallback: false };
        return okOutcome;
      }
    }

    const fallback: FallbackResult = SkipPlanner.fallback(day, skippedId, index, startMin, endMin,
      nowMin, remainIds);
    const fallbackNote: string = SkipPlanner.noteFor(title, null, fallback.overflow, true);
    const outcome: ReplanOutcome = {
      day: fallback.day,
      note: fallbackNote,
      usedFallback: true
    };
    return outcome;
  }

  // ---- 守卫 ----

  private static accept(day: TripDay, decision: ReplanDecision, remainIds: string[]): boolean {
    if (decision.schemaVersion !== REPLAN_SCHEMA_VERSION) {
      return false;
    }
    if (decision.keep.length > REPLAN_MAX_KEEP || decision.keep.length !== remainIds.length) {
      return false;
    }
    const seen: string[] = [];
    for (const k of decision.keep) {
      if (k.id.length === 0 || remainIds.indexOf(k.id) < 0 || seen.indexOf(k.id) >= 0) {
        return false;
      }
      if (Math.floor(k.dwellMin) !== k.dwellMin ||
        k.dwellMin < REPLAN_MIN_DWELL || k.dwellMin > REPLAN_MAX_DWELL) {
        return false;
      }
      seen.push(k.id);
    }
    if (decision.freeBlocks.length > REPLAN_MAX_FREE_BLOCKS) {
      return false;
    }
    for (const b of decision.freeBlocks) {
      if (SkipPlanner.indexOf(day, b.afterId) < 0) {
        return false;
      }
      if (Math.floor(b.minutes) !== b.minutes ||
        b.minutes < REPLAN_MIN_FREE_MIN || b.minutes > REPLAN_MAX_FREE_MIN) {
        return false;
      }
    }
    return decision.note.length <= REPLAN_MAX_NOTE;
  }

  // ---- 排程 ----

  private static schedule(work: TripDay, skippedId: string, skippedStart: number,
    skippedEnd: number, nowMin: number, decision: ReplanDecision): ScheduleResult {
    const anchors: Span[] = SkipPlanner.anchors(work, skippedId, skippedStart, skippedEnd);
    const initialCursor: number = Math.max(nowMin, skippedEnd);
    const blocks: FreeState[] = [];
    for (const b of decision.freeBlocks) {
      const state: FreeState = {
        afterId: b.afterId,
        minutes: b.minutes,
        used: false,
        expired: SkipPlanner.endOf(work, b.afterId) < initialCursor
      };
      blocks.push(state);
    }

    let cursor: number = initialCursor;
    for (let i = 0; i < decision.keep.length; i++) {
      const keep: KeepStop = decision.keep[i];
      const act: Activity | null = SkipPlanner.activityOf(work, keep.id);
      if (act === null) {
        continue;
      }
      // 通勤表示「到达该站之前」；keep 第一项也加（方案 §3.3）。
      cursor += SkipPlanner.transportMin(act);
      let guard: number = 0;
      while (guard < MAX_SETTLE_LOOP) {
        guard += 1;
        const settled: number = SkipPlanner.settle(cursor, keep.dwellMin, anchors);
        let consumed: boolean = false;
        for (const b of blocks) {
          if (b.used || b.expired) {
            continue;
          }
          if (settled >= SkipPlanner.endOf(work, b.afterId)) {
            b.used = true;
            cursor = settled + b.minutes;
            consumed = true;
            break;
          }
        }
        if (!consumed) {
          cursor = settled;
          break;
        }
      }
      if (cursor + keep.dwellMin > DAY_END) {
        SkipPlanner.markCarry(work, decision.keep, i);
        const overflow: ScheduleResult = { overflow: true, overflowFrom: i };
        return overflow;
      }
      act.time = DateUtils.hhmmOf(cursor);
      act.endTime = DateUtils.hhmmOf(cursor + keep.dwellMin);
      cursor += keep.dwellMin;
    }
    const done: ScheduleResult = { overflow: false, overflowFrom: decision.keep.length };
    return done;
  }

  /** 把 t 推到不与任何锚点相交；一次只处理最远的冲突锚点，循环到稳定。 */
  private static settle(t: number, dwell: number, anchors: Span[]): number {
    let cursor: number = t;
    for (let guard = 0; guard < MAX_SETTLE_LOOP; guard++) {
      let hit: Span | null = null;
      for (const a of anchors) {
        if (cursor < a.end && a.start < cursor + dwell) {
          if (hit === null || a.end > hit.end) {
            hit = a;
          }
        }
      }
      if (hit === null) {
        return cursor;
      }
      cursor = hit.end;
    }
    return cursor;
  }

  private static anchors(work: TripDay, skippedId: string, skippedStart: number,
    skippedEnd: number): Span[] {
    const spans: Span[] = [];
    for (const a of work.activities) {
      if (a.id === skippedId) {
        continue;
      }
      const anchored: boolean = a.category === ActivityCategory.TRANSPORT ||
        a.category === ActivityCategory.HOTEL || a.status === ActivityStatus.BOOKED;
      if (!anchored) {
        continue;
      }
      const start: number = DateUtils.minutesOf(a.time);
      if (start < 0) {
        continue;
      }
      const end: number = SkipPlanner.normalizedEnd(a, start);
      if (end > start) {
        spans.push({ start: start, end: end });
      }
    }
    for (const m of work.meals) {
      if (m.time === undefined) {
        continue;
      }
      const start: number = DateUtils.minutesOf(m.time);
      if (start < 0) {
        continue;
      }
      const end: number = Math.min(DAY_END, start + MEAL_ANCHOR_MIN);
      if (end > start) {
        spans.push({ start: start, end: end });
      }
    }
    if (skippedEnd > skippedStart) {
      spans.push({ start: skippedStart, end: skippedEnd });
    }
    return spans;
  }

  // ---- 本地兜底 ----

  private static fallback(day: TripDay, skippedId: string, skippedIndex: number,
    skippedStart: number, skippedEnd: number, nowMin: number, remainIds: string[]): FallbackResult {
    const work: TripDay = SkipPlanner.cloneDay(day);
    const title: string = day.activities[skippedIndex].title;
    SkipPlanner.rewriteSkipped(work.activities[skippedIndex], skippedStart, skippedEnd, title);
    const shift: number = Math.max(0, skippedEnd - skippedStart);

    const tailIds: string[] = [];
    const originals: Activity[] = [];
    const tail: Activity[] = [];
    for (const id of remainIds) {
      const original: Activity | null = SkipPlanner.activityOf(day, id);
      const copy: Activity | null = SkipPlanner.activityOf(work, id);
      if (original === null || copy === null) {
        continue;
      }
      if (DateUtils.minutesOf(original.time) < skippedStart) {
        continue;
      }
      tailIds.push(id);
      originals.push(original);
      tail.push(copy);
    }

    const starts: number[] = [];
    const ends: number[] = [];
    for (const original of originals) {
      const start: number = DateUtils.minutesOf(original.time) + shift;
      const duration: number = Math.max(1,
        DateUtils.minutesOf(original.endTime) - DateUtils.minutesOf(original.time));
      starts.push(start);
      ends.push(start + duration);
    }

    // 与锚点冲突时整体再顺延；冲突由「整体移动」解决，绝不丢站。
    const anchors: Span[] = SkipPlanner.anchors(work, skippedId, skippedStart, skippedEnd);
    for (let guard = 0; guard < MAX_SETTLE_LOOP; guard++) {
      let needed: number = 0;
      for (let i = 0; i < starts.length; i++) {
        for (const anchor of anchors) {
          if (starts[i] < anchor.end && anchor.start < ends[i]) {
            needed = Math.max(needed, anchor.end - starts[i]);
          }
        }
      }
      if (needed <= 0) {
        break;
      }
      for (let i = 0; i < starts.length; i++) {
        starts[i] += needed;
        ends[i] += needed;
      }
    }

    let overflowFrom: number = starts.length;
    for (let i = 0; i < ends.length; i++) {
      if (ends[i] > DAY_END) {
        overflowFrom = i;
        break;
      }
    }
    for (let i = 0; i < overflowFrom; i++) {
      tail[i].time = DateUtils.hhmmOf(starts[i]);
      tail[i].endTime = DateUtils.hhmmOf(ends[i]);
    }
    for (let i = overflowFrom; i < tail.length; i++) {
      tail[i].note = SkipPlanner.appendCarry(tail[i].note);
    }

    const placedIds: string[] = tailIds.slice(0, overflowFrom);
    const carryIds: string[] = tailIds.slice(overflowFrom);
    if (!SkipPlanner.valid(work, day, skippedId, nowMin, placedIds, carryIds)) {
      // 兜底也过不了约束：整段恢复原时间并全部标待调整，绝不落一个更坏的结果。
      for (let i = 0; i < tail.length; i++) {
        tail[i].time = originals[i].time;
        tail[i].endTime = originals[i].endTime;
        tail[i].note = SkipPlanner.appendCarry(tail[i].note);
      }
      const degraded: FallbackResult = { day: work, overflow: true };
      return degraded;
    }
    const result: FallbackResult = { day: work, overflow: overflowFrom < tail.length };
    return result;
  }

  // ---- 校验 ----

  private static valid(work: TripDay, original: TripDay, skippedId: string, nowMin: number,
    placedIds: string[], carryIds: string[]): boolean {
    if (work.activities.length !== original.activities.length ||
      work.meals.length !== original.meals.length) {
      return false;
    }
    for (let i = 0; i < original.activities.length; i++) {
      if (work.activities[i].id !== original.activities[i].id) {
        return false;
      }
    }
    for (let i = 0; i < original.meals.length; i++) {
      if (work.meals[i].type !== original.meals[i].type ||
        work.meals[i].time !== original.meals[i].time) {
        return false;
      }
    }

    const skipped: Activity | null = SkipPlanner.activityOf(work, skippedId);
    const before: Activity | null = SkipPlanner.activityOf(original, skippedId);
    if (skipped === null || before === null) {
      return false;
    }
    if (skipped.category !== ActivityCategory.REST || skipped.status !== ActivityStatus.NO_NEED ||
      skipped.title !== FREE_TITLE || skipped.time !== before.time) {
      return false;
    }
    if (DateUtils.minutesOf(skipped.endTime) < DateUtils.minutesOf(skipped.time)) {
      return false;
    }

    for (const a of original.activities) {
      if (a.id === skippedId) {
        continue;
      }
      const anchored: boolean = a.category === ActivityCategory.TRANSPORT ||
        a.category === ActivityCategory.HOTEL || a.status === ActivityStatus.BOOKED;
      if (!anchored) {
        continue;
      }
      const now: Activity | null = SkipPlanner.activityOf(work, a.id);
      if (now === null || now.time !== a.time || now.endTime !== a.endTime) {
        return false;
      }
    }

    for (const id of carryIds) {
      const now: Activity | null = SkipPlanner.activityOf(work, id);
      const was: Activity | null = SkipPlanner.activityOf(original, id);
      if (now === null || was === null || now.time !== was.time || now.endTime !== was.endTime) {
        return false;
      }
      if (now.note === undefined || now.note.indexOf(CARRY_MARK) < 0) {
        return false;
      }
    }

    const anchors: Span[] = SkipPlanner.anchors(work, skippedId,
      DateUtils.minutesOf(skipped.time), DateUtils.minutesOf(skipped.endTime));
    const placed: Span[] = [];
    for (const id of placedIds) {
      const a: Activity | null = SkipPlanner.activityOf(work, id);
      if (a === null) {
        return false;
      }
      const start: number = DateUtils.minutesOf(a.time);
      const end: number = DateUtils.minutesOf(a.endTime);
      if (start < nowMin || end <= start || end > DAY_END) {
        return false;
      }
      for (const anchor of anchors) {
        if (start < anchor.end && anchor.start < end) {
          return false;
        }
      }
      placed.push({ start: start, end: end });
    }
    for (let i = 0; i < placed.length; i++) {
      for (let j = i + 1; j < placed.length; j++) {
        if (placed[i].start < placed[j].end && placed[j].start < placed[i].end) {
          return false;
        }
      }
    }
    return true;
  }

  // ---- 小工具 ----

  private static cloneActivity(a: Activity): Activity {
    const copy: Activity = {
      id: a.id,
      time: a.time,
      endTime: a.endTime,
      title: a.title,
      location: a.location,
      address: a.address,
      longitude: a.longitude,
      latitude: a.latitude,
      status: a.status,
      category: a.category
    };
    if (a.note !== undefined) {
      copy.note = a.note;
    }
    if (a.reason !== undefined) {
      copy.reason = a.reason;
    }
    if (a.transport !== undefined) {
      const t: TransportInfo = {
        mode: a.transport.mode,
        duration: a.transport.duration,
        detail: a.transport.detail
      };
      copy.transport = t;
    }
    return copy;
  }

  private static cloneMeal(m: Meal): Meal {
    const copy: Meal = {
      type: m.type,
      name: m.name,
      location: m.location,
      estimatedCost: m.estimatedCost
    };
    if (m.time !== undefined) {
      copy.time = m.time;
    }
    if (m.note !== undefined) {
      copy.note = m.note;
    }
    return copy;
  }

  /** 原地改写（方案 §3.2）：id 不变，其余字段按表清空/复位。 */
  private static rewriteSkipped(a: Activity, startMin: number, endMin: number, title: string): void {
    a.category = ActivityCategory.REST;
    a.title = FREE_TITLE;
    a.status = ActivityStatus.NO_NEED;
    a.note = `${SKIP_NOTE_PREFIX}${title}`;
    a.reason = undefined;
    a.transport = undefined;
    a.location = '';
    a.address = '';
    a.longitude = 0;
    a.latitude = 0;
    a.time = DateUtils.hhmmOf(startMin);
    a.endTime = DateUtils.hhmmOf(endMin);
  }

  private static markCarry(work: TripDay, keep: KeepStop[], fromIndex: number): void {
    for (let i = fromIndex; i < keep.length; i++) {
      const a: Activity | null = SkipPlanner.activityOf(work, keep[i].id);
      if (a !== null) {
        a.note = SkipPlanner.appendCarry(a.note);
      }
    }
  }

  private static appendCarry(note: string | undefined): string {
    if (note === undefined || note.length === 0) {
      return CARRY_MARK;
    }
    if (note.indexOf(CARRY_MARK) >= 0) {
      return note;
    }
    return `${note} · ${CARRY_MARK}`;
  }

  private static noteFor(title: string, decision: ReplanDecision | null, overflow: boolean,
    isFallback: boolean): string {
    let body: string = '后续行程已重排';
    if (isFallback) {
      body = '离线重排';
    } else if (decision !== null && decision.note.length > 0) {
      body = decision.note;
    }
    const suffix: string = overflow ? '（部分站点待调整）' : '';
    return `已跳过「${title}」，${body}${suffix}`;
  }

  private static startOf(a: Activity): number {
    const min: number = DateUtils.minutesOf(a.time);
    return min < 0 ? 0 : min;
  }

  /** endTime 缺失/不晚于 time 时取 time+60，并夹到 23:59（方案 §3.2）。 */
  private static normalizedEnd(a: Activity, startMin: number): number {
    const end: number = DateUtils.minutesOf(a.endTime);
    const candidate: number = end < 0 || end <= startMin ? startMin + DEFAULT_DWELL_MIN : end;
    return Math.min(DAY_END, candidate);
  }

  private static endOf(work: TripDay, id: string): number {
    const a: Activity | null = SkipPlanner.activityOf(work, id);
    if (a === null) {
      return -1;
    }
    const start: number = DateUtils.minutesOf(a.time);
    if (start < 0) {
      return -1;
    }
    return SkipPlanner.normalizedEnd(a, start);
  }

  private static transportMin(a: Activity): number {
    if (a.transport === undefined) {
      return 0;
    }
    return a.transport.duration > 0 ? Math.floor(a.transport.duration) : 0;
  }

  private static indexOf(day: TripDay, id: string): number {
    for (let i = 0; i < day.activities.length; i++) {
      if (day.activities[i].id === id) {
        return i;
      }
    }
    return -1;
  }

  private static activityOf(day: TripDay, id: string): Activity | null {
    const index: number = SkipPlanner.indexOf(day, id);
    return index < 0 ? null : day.activities[index];
  }
}
```

- [ ] **Step 2: 暂不跑整脚本**

`ReplanParser.ets` 要到 Task 4 才存在，`tools/verify_replan_logic.sh` 现在必然在拷贝阶段失败；这一步跳过，用 Step 3 做局部确认。

- [ ] **Step 3: 只编译 SkipPlanner 做局部确认**

Run:
```bash
TMP=$(mktemp -d); mkdir -p "$TMP/model" "$TMP/utils" "$TMP/data" "$TMP/tools"
cp entry/src/main/ets/model/Trip.ets "$TMP/model/Trip.ts"
cp entry/src/main/ets/model/Replan.ets "$TMP/model/Replan.ts"
cp entry/src/main/ets/utils/DateUtils.ets "$TMP/utils/DateUtils.ts"
cp entry/src/main/ets/data/SkipPlanner.ets "$TMP/data/SkipPlanner.ts"
cp tools/skip_planner_check.ts "$TMP/tools/skip_planner_check.ts"
/Applications/DevEco-Studio.app/Contents/tools/ohpm/node_modules/typescript/bin/tsc --strict --noEmitOnError --target ES2020 --module commonjs --moduleResolution node --lib ES2020,DOM --rootDir "$TMP" --outDir "$TMP/out" "$TMP/tools/skip_planner_check.ts"
/Applications/DevEco-Studio.app/Contents/tools/node/bin/node "$TMP/out/tools/skip_planner_check.js"
rm -rf "$TMP"
```
Expected: `SKIP_PLANNER_OK cases=74`，无 `FAIL:`。

---

### Task 4: ReplanParser（响应类型守卫）

**Files:**
- Create: `entry/src/main/ets/ai/ReplanParser.ets`

**Interfaces:**
- Consumes: `TripParser.extractJson`、`AppError`、`ErrorCode`、`Replan.ets` 类型与限值
- Produces: `ReplanParser.parseDecision(text: string): ReplanDecision`；非法响应抛 `AppError`（2001/2002/2003）

- [ ] **Step 1: 实现 `ReplanParser`**

```ts
/**
 * ReplanParser：云函数响应 → ReplanDecision 的 ArkTS 类型守卫（方案 §3.4）。
 * 只做结构校验；集合一致性、时间算术在 data/SkipPlanner。
 */

import { TripParser } from './TripParser';
import { AppError } from '../common/error/AppError';
import { ErrorCode } from '../common/error/ErrorCode';
import {
  FreeBlock, KeepStop, ReplanDecision, REPLAN_MAX_DWELL, REPLAN_MAX_FREE_BLOCKS, REPLAN_MAX_FREE_MIN,
  REPLAN_MAX_KEEP, REPLAN_MAX_NOTE, REPLAN_MIN_DWELL, REPLAN_MIN_FREE_MIN, REPLAN_SCHEMA_VERSION
} from '../model/Replan';

type Obj = Record<string, Object>;

export class ReplanParser {
  static parseDecision(text: string): ReplanDecision {
    let raw: Object | null = null;
    try {
      raw = JSON.parse(TripParser.extractJson(text)) as Object;
    } catch (err) {
      if (err instanceof AppError) {
        throw err;
      }
      throw new AppError(ErrorCode.JSON_PARSE_FAILED, `JSON 解析失败: ${(err as Error).message}`);
    }
    const root: Obj = ReplanParser.asObj(raw, '$');
    const version: number = ReplanParser.reqInt(root['schemaVersion'], 'schemaVersion');
    if (version !== REPLAN_SCHEMA_VERSION) {
      throw new AppError(ErrorCode.SCHEMA_VALIDATION_FAILED,
        `schemaVersion=${version} 不受支持（只接受 ${REPLAN_SCHEMA_VERSION}）`);
    }

    const keepArr: Object[] = ReplanParser.reqArray(root['keep'], 'keep');
    if (keepArr.length > REPLAN_MAX_KEEP) {
      throw new AppError(ErrorCode.SCHEMA_VALIDATION_FAILED,
        `keep 超上限 ${REPLAN_MAX_KEEP}（${keepArr.length}）`);
    }
    const keep: KeepStop[] = [];
    const seen: string[] = [];
    for (let i = 0; i < keepArr.length; i++) {
      const o: Obj = ReplanParser.asObj(keepArr[i], `keep[${i}]`);
      const id: string = ReplanParser.reqStr(o['id'], `keep[${i}].id`);
      const dwell: number = ReplanParser.reqInt(o['dwellMin'], `keep[${i}].dwellMin`);
      if (dwell < REPLAN_MIN_DWELL || dwell > REPLAN_MAX_DWELL) {
        throw new AppError(ErrorCode.SCHEMA_VALIDATION_FAILED,
          `keep[${i}].dwellMin=${dwell} 越界 [${REPLAN_MIN_DWELL},${REPLAN_MAX_DWELL}]`);
      }
      if (seen.indexOf(id) >= 0) {
        throw new AppError(ErrorCode.TYPE_GUARD_FAILED, `keep[${i}].id=${id} 重复`);
      }
      seen.push(id);
      const item: KeepStop = { id: id, dwellMin: dwell };
      keep.push(item);
    }

    const freeBlocks: FreeBlock[] = [];
    const blocksRaw: Object | undefined | null = root['freeBlocks'];
    if (blocksRaw !== undefined && blocksRaw !== null) {
      const arr: Object[] = ReplanParser.asArray(blocksRaw, 'freeBlocks');
      if (arr.length > REPLAN_MAX_FREE_BLOCKS) {
        throw new AppError(ErrorCode.SCHEMA_VALIDATION_FAILED,
          `freeBlocks 超上限 ${REPLAN_MAX_FREE_BLOCKS}（${arr.length}）`);
      }
      for (let i = 0; i < arr.length; i++) {
        const o: Obj = ReplanParser.asObj(arr[i], `freeBlocks[${i}]`);
        const afterId: string = ReplanParser.reqStr(o['afterId'], `freeBlocks[${i}].afterId`);
        const minutes: number = ReplanParser.reqInt(o['minutes'], `freeBlocks[${i}].minutes`);
        if (minutes < REPLAN_MIN_FREE_MIN || minutes > REPLAN_MAX_FREE_MIN) {
          throw new AppError(ErrorCode.SCHEMA_VALIDATION_FAILED,
            `freeBlocks[${i}].minutes=${minutes} 越界 ` +
              `[${REPLAN_MIN_FREE_MIN},${REPLAN_MAX_FREE_MIN}]`);
        }
        const block: FreeBlock = { afterId: afterId, minutes: minutes };
        freeBlocks.push(block);
      }
    }

    const note: string = ReplanParser.optStr(root['note'], 'note') ?? '';
    if (note.length > REPLAN_MAX_NOTE) {
      throw new AppError(ErrorCode.SCHEMA_VALIDATION_FAILED, `note 超上限 ${REPLAN_MAX_NOTE} 字`);
    }
    const decision: ReplanDecision = {
      schemaVersion: version,
      keep: keep,
      freeBlocks: freeBlocks,
      note: note
    };
    return decision;
  }

  // ---- 收口原语（与 TripParser 同口径） ----

  private static asObj(v: Object | undefined | null, p: string): Obj {
    if (typeof v === 'object' && v !== null && !Array.isArray(v)) {
      return v as Obj;
    }
    throw new AppError(ErrorCode.TYPE_GUARD_FAILED, `${p}: 期望 object`);
  }

  private static asArray(v: Object | undefined | null, p: string): Object[] {
    if (Array.isArray(v)) {
      return v as Object[];
    }
    throw new AppError(ErrorCode.TYPE_GUARD_FAILED, `${p}: 期望 array`);
  }

  private static reqArray(v: Object | undefined, p: string): Object[] {
    if (v === undefined) {
      throw new AppError(ErrorCode.SCHEMA_VALIDATION_FAILED, `${p}: 缺字段`);
    }
    return ReplanParser.asArray(v, p);
  }

  private static reqStr(v: Object | undefined, p: string): string {
    if (v === undefined) {
      throw new AppError(ErrorCode.SCHEMA_VALIDATION_FAILED, `${p}: 缺字段`);
    }
    if (typeof v !== 'string' || (v as string).length === 0) {
      throw new AppError(ErrorCode.TYPE_GUARD_FAILED, `${p}: 期望非空 string`);
    }
    return v as string;
  }

  private static optStr(v: Object | undefined, p: string): string | undefined {
    if (v === undefined || v === null) {
      return undefined;
    }
    if (typeof v !== 'string') {
      throw new AppError(ErrorCode.TYPE_GUARD_FAILED, `${p}: 期望 string`);
    }
    return (v as string).length > 0 ? v as string : undefined;
  }

  private static reqNum(v: Object | undefined, p: string): number {
    if (v === undefined) {
      throw new AppError(ErrorCode.SCHEMA_VALIDATION_FAILED, `${p}: 缺字段`);
    }
    if (typeof v !== 'number') {
      throw new AppError(ErrorCode.TYPE_GUARD_FAILED, `${p}: 期望 number`);
    }
    return v as number;
  }

  private static reqInt(v: Object | undefined, p: string): number {
    const n: number = ReplanParser.reqNum(v, p);
    if (!Number.isInteger(n)) {
      throw new AppError(ErrorCode.TYPE_GUARD_FAILED, `${p}: 期望整数`);
    }
    return n;
  }
}
```

- [ ] **Step 2: 跑完整离线验收**

Run: `zsh tools/verify_replan_logic.sh`
Expected:
```text
SKIP_PLANNER_OK cases=74
REPLAN_PARSER_OK cases=26
REPLAN_LOGIC_OK
```
若任何 `FAIL:` 出现，先修实现，不要改断言期望值来迁就代码。

---

### Task 5: ReplanClient + ApiConfig

**Files:**
- Modify: `entry/src/main/ets/common/config/ApiConfig.ets`
- Create: `entry/src/main/ets/ai/ReplanClient.ets`

**Interfaces:**
- Consumes: `SkipPlanner.buildRequest`、`ReplanParser.parseDecision`、`ApiConfig.REPLAN_*`
- Produces: `ReplanClient.requestDecision(day: TripDay, skippedId: string, nowMin: number): Promise<ReplanDecision | null>`（任何失败返回 `null`，绝不抛）

- [ ] **Step 1: 给 `ApiConfig` 增加四项**

在 `ApiConfigType` 接口里、`READ_TIMEOUT_MS` 之后追加：

```ts
  /** 重排云函数地址。空串 = 不请求，直接走本地兜底（仓库默认值）。 */
  REPLAN_URL: string;
  /**
   * 云函数鉴权头 x-youjing-token 的值，必须等于云函数环境变量 YOUJING_REPLAN_TOKEN。
   * 开发期真值只写本机（skip-worktree 防误提交）；为空时不带该头，云函数回 401 → 本地兜底。
   */
  REPLAN_TOKEN: string;
  /** 重排客户端超时预算：连接 2 秒（方案 §3.5）。 */
  REPLAN_CONNECT_TIMEOUT_MS: number;
  /** 重排客户端超时预算：读取 6 秒（方案 §3.5）。 */
  REPLAN_READ_TIMEOUT_MS: number;
```

在 `ApiConfig` 对象里追加：

```ts
  REPLAN_URL: '',
  REPLAN_TOKEN: '',
  REPLAN_CONNECT_TIMEOUT_MS: 2000,
  REPLAN_READ_TIMEOUT_MS: 6000
```

- [ ] **Step 2: 新建 `ReplanClient`**

```ts
/**
 * 重排云函数客户端（方案 §3.4 / §3.5）。
 * 任何失败（未配置 / 网络 / 非 2xx / 守卫拒绝 / 超时）一律返回 null，
 * 由 OnTripPage 交给 SkipPlanner 走本地兜底；绝不让网络问题阻塞跳过。
 */

import { http } from '@kit.NetworkKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { ApiConfig } from '../common/config/ApiConfig';
import { Logger } from '../common/logger/Logger';
import { AppError } from '../common/error/AppError';
import { ReplanDecision, ReplanRequest } from '../model/Replan';
import { TripDay } from '../model/Trip';
import { SkipPlanner } from '../data/SkipPlanner';
import { ReplanParser } from './ReplanParser';

const TAG: string = 'Ai.ReplanClient';

export class ReplanClient {
  static async requestDecision(day: TripDay, skippedId: string,
    nowMin: number): Promise<ReplanDecision | null> {
    if (ApiConfig.REPLAN_URL.length === 0) {
      Logger.warn(TAG, 'Replan 云函数未配置（ApiConfig.REPLAN_URL 为空），走本地兜底');
      return null;
    }
    const request: ReplanRequest = SkipPlanner.buildRequest(day, skippedId, nowMin);
    const reqHandle = http.createHttp();
    try {
      const headers: Record<string, string> = {};
      headers['Content-Type'] = 'application/json';
      let tokenHeader: string = '';
      if (ApiConfig.REPLAN_TOKEN.length > 0) {
        headers['x-youjing-token'] = ApiConfig.REPLAN_TOKEN;
        tokenHeader = '已带';
      } else {
        Logger.warn(TAG, 'REPLAN_TOKEN 未配置，云函数将按 401 拒绝并走本地兜底');
        tokenHeader = '未带';
      }
      const resp: http.HttpResponse = await reqHandle.request(ApiConfig.REPLAN_URL, {
        method: http.RequestMethod.POST,
        header: headers,
        extraData: JSON.stringify(request),
        expectDataType: http.HttpDataType.STRING,
        connectTimeout: ApiConfig.REPLAN_CONNECT_TIMEOUT_MS,
        readTimeout: ApiConfig.REPLAN_READ_TIMEOUT_MS
      });
      if (resp.responseCode < 200 || resp.responseCode >= 300) {
        Logger.warn(TAG, `replan HTTP ${resp.responseCode}（token ${tokenHeader}），走本地兜底`);
        return null;
      }
      const text: string = typeof resp.result === 'string' ? resp.result as string : '';
      if (text.length === 0) {
        Logger.warn(TAG, 'replan 响应为空，走本地兜底');
        return null;
      }
      const decision: ReplanDecision = ReplanParser.parseDecision(text);
      Logger.info(TAG, `replan 决策 keep=${decision.keep.length} blocks=${decision.freeBlocks.length}`);
      return decision;
    } catch (err) {
      if (err instanceof AppError) {
        Logger.warn(TAG, `replan 守卫拒绝: ${err.message}，走本地兜底`);
        return null;
      }
      const be: BusinessError = err as BusinessError;
      const platformCode: number = typeof be.code === 'number' ? be.code : 0;
      if (platformCode === 2300025) {
        Logger.warn(TAG, `replan 超时（readTimeout=${ApiConfig.REPLAN_READ_TIMEOUT_MS}ms），走本地兜底`);
      } else {
        Logger.warn(TAG, `replan 请求失败: ${(err as Error).message}，走本地兜底`);
      }
      return null;
    } finally {
      reqHandle.destroy();
    }
  }
}
```

- [ ] **Step 3: 核对配置默认值，防止把真值带进提交**

Run:
```bash
grep -n "REPLAN" entry/src/main/ets/common/config/ApiConfig.ets
grep -rn "x-youjing-token" entry/src/main/ets
```
Expected:
- `REPLAN_URL: ''`、`REPLAN_TOKEN: ''`、`2000`、`6000`。
- `x-youjing-token` 只出现在 `ReplanClient.ets`。

---

### Task 6: 云函数 `replanDay` + 本地桩

**Files:**
- Create: `cloud/replanDay/index.js`
- Create: `cloud/replanDay/package.json`
- Create: `cloud/replanDay/test/replan.test.js`
- Create: `cloud/replanDay/README.md`
- Create: `tools/replan_stub.js`

**Interfaces:**
- Consumes: HTTP trigger 事件（`headers`、`body`、`isBase64Encoded`）、环境变量 `YOUJING_REPLAN_TOKEN` / `LLM_CHAT_URL` / `LLM_API_KEY` / `LLM_MODEL`
- Produces: `200 {schemaVersion:1, keep, freeBlocks, note}`；`401/400/422/500/502` 错误体 `{code,message}`
- Produces: `handler(event, context, deps)`，`deps.fetch` / `deps.env` 可注入

- [ ] **Step 1: 写 `cloud/replanDay/index.js`**

```js
'use strict';

/**
 * 有径 · 当日行程重排云函数（方案 §3.4）。
 * 只做：鉴权 → 校验请求 → 服务端重算剩余 → 调 LLM 决策 → 守卫响应。
 * 不做时间算术：具体时刻由端侧 SkipPlanner 计算。
 */

const SCHEMA_VERSION = 1;
const MAX_KEEP = 20;
const MIN_DWELL = 15;
const MAX_DWELL = 240;
const MAX_FREE_BLOCKS = 3;
const MIN_FREE_MIN = 15;
const MAX_FREE_MIN = 480;
const MAX_NOTE = 200;
const MAX_BODY_BYTES = 64 * 1024;
const MAX_ACTIVITIES = 100;
const MAX_MEALS = 10;
const UPSTREAM_TIMEOUT_MS = 5000;
const ANCHOR_CATEGORIES = ['transport', 'hotel'];
const CATEGORIES = ['transport', 'sight', 'food', 'shop', 'rest', 'hotel', 'other'];
const STATUSES = ['booked', 'not_booked', 'full', 'pending', 'no_need'];
const MEAL_TYPES = ['breakfast', 'lunch', 'dinner'];

function respond(statusCode, body) {
  return {
    statusCode: statusCode,
    headers: { 'Content-Type': 'application/json; charset=utf-8' },
    body: JSON.stringify(body)
  };
}

function fail(statusCode, code, message) {
  return respond(statusCode, { code: code, message: message });
}

function isTime(value) {
  if (typeof value !== 'string' || !/^\d{2}:\d{2}$/.test(value)) {
    return false;
  }
  const h = Number(value.slice(0, 2));
  const m = Number(value.slice(3, 5));
  return h <= 23 && m <= 59;
}

function minutesOf(hhmm) {
  return Number(hhmm.slice(0, 2)) * 60 + Number(hhmm.slice(3, 5));
}

function hhmm(minutes) {
  const clamped = Math.max(0, Math.min(1439, Math.round(minutes)));
  return `${String(Math.floor(clamped / 60)).padStart(2, '0')}:${String(clamped % 60).padStart(2, '0')}`;
}

function headerOf(event, name) {
  const headers = (event && event.headers) || {};
  const wanted = name.toLowerCase();
  for (const key of Object.keys(headers)) {
    if (key.toLowerCase() === wanted) {
      return String(headers[key]);
    }
  }
  return '';
}

function parseBody(event) {
  const raw = event && event.body;
  if (raw === undefined || raw === null) {
    return null;
  }
  if (typeof raw === 'object') {
    return raw;
  }
  if (typeof raw !== 'string') {
    return null;
  }
  let text = raw;
  if (event.isBase64Encoded) {
    text = Buffer.from(raw, 'base64').toString('utf8');
  }
  if (Buffer.byteLength(text, 'utf8') > MAX_BODY_BYTES) {
    return null;
  }
  try {
    return JSON.parse(text);
  } catch (err) {
    return null;
  }
}

function normalizeRequest(body) {
  if (!body || body.schemaVersion !== SCHEMA_VERSION) {
    return null;
  }
  if (!isTime(body.now)) {
    return null;
  }
  if (typeof body.skippedId !== 'string' || body.skippedId.length === 0) {
    return null;
  }
  const day = body.day;
  if (!day || typeof day.date !== 'string' || !Array.isArray(day.activities) ||
      !Array.isArray(day.meals)) {
    return null;
  }
  if (day.activities.length > MAX_ACTIVITIES || day.meals.length > MAX_MEALS) {
    return null;
  }
  const ids = new Set();
  const activities = [];
  for (const a of day.activities) {
    if (!a || typeof a.id !== 'string' || a.id.length === 0 || ids.has(a.id)) {
      return null;
    }
    if (!isTime(a.time) || !isTime(a.endTime)) {
      return null;
    }
    if (typeof a.title !== 'string' || a.title.length > 200) {
      return null;
    }
    if (CATEGORIES.indexOf(a.category) < 0 || STATUSES.indexOf(a.status) < 0) {
      return null;
    }
    ids.add(a.id);
    let transport = 0;
    if (a.transport !== undefined && a.transport !== null) {
      if (typeof a.transport.duration !== 'number' || !Number.isFinite(a.transport.duration)) {
        return null;
      }
      transport = Math.max(0, Math.floor(a.transport.duration));
    }
    activities.push({
      id: a.id,
      time: a.time,
      endTime: a.endTime,
      title: a.title,
      category: a.category,
      status: a.status,
      transport: transport
    });
  }
  const skipped = activities.find((a) => a.id === body.skippedId);
  if (!skipped) {
    return null;
  }
  if (ANCHOR_CATEGORIES.indexOf(skipped.category) >= 0 ||
      skipped.category === 'rest' || skipped.status === 'booked') {
    return null;
  }
  const meals = [];
  for (const m of day.meals) {
    if (!m || MEAL_TYPES.indexOf(m.type) < 0) {
      return null;
    }
    meals.push({ type: m.type, time: isTime(m.time) ? m.time : undefined });
  }
  return {
    now: body.now,
    skippedId: body.skippedId,
    day: { date: day.date, activities: activities, meals: meals }
  };
}

function remainingOf(request) {
  const nowMin = minutesOf(request.now);
  return request.day.activities
    .filter((a) => a.id !== request.skippedId &&
      ANCHOR_CATEGORIES.indexOf(a.category) < 0 &&
      a.status !== 'booked' &&
      minutesOf(a.time) >= nowMin)
    .sort((x, y) => minutesOf(x.time) - minutesOf(y.time));
}

function anchorsOf(request) {
  const skipped = request.day.activities.find((a) => a.id === request.skippedId);
  const spans = [];
  for (const a of request.day.activities) {
    if (a.id === request.skippedId) {
      continue;
    }
    if (ANCHOR_CATEGORIES.indexOf(a.category) < 0 && a.status !== 'booked') {
      continue;
    }
    spans.push({ label: a.title, start: a.time, end: a.endTime });
  }
  for (const m of request.day.meals) {
    if (!m.time) {
      continue;
    }
    const start = minutesOf(m.time);
    spans.push({ label: `餐次 ${m.type}`, start: m.time, end: hhmm(Math.min(1439, start + 60)) });
  }
  spans.push({ label: '本次空闲段', start: skipped.time, end: skipped.endTime });
  return spans;
}

function promptFor(request, remaining) {
  const skipped = request.day.activities.find((a) => a.id === request.skippedId);
  const system = [
    '你是有径 App 的行程重排助手。用户放弃了下一站，需要你对当日剩余站点重新排序并给出停留时长。',
    '你只做决策，不做时间算术：不要输出任何具体开始/结束时刻。',
    '必须遵守：',
    '1. keep 必须恰好包含 remaining 里的每个 id 一次，不得新增、遗漏或重复；',
    '2. 每个 dwellMin 是 15–240 的整数分钟；',
    '3. freeBlocks 最多 3 块，afterId 必须是 activities 里已存在的 id，minutes 是 15–480 的整数；',
    '4. note 不超过 200 字，给用户一句中文说明；',
    '5. 只输出 JSON，不要 Markdown 围栏或解释。',
    '输出格式：{"schemaVersion":1,"keep":[{"id":"...","dwellMin":60}],"freeBlocks":[],"note":"..."}'
  ].join('\n');
  const user = JSON.stringify({
    now: request.now,
    date: request.day.date,
    skipped: { id: skipped.id, title: skipped.title, time: skipped.time, endTime: skipped.endTime },
    remaining: remaining.map((a) => ({
      id: a.id,
      title: a.title,
      time: a.time,
      endTime: a.endTime,
      category: a.category
    })),
    anchors: anchorsOf(request),
    meals: request.day.meals
  });
  return { system: system, user: user };
}

async function callLlm(request, remaining, fetchImpl, env) {
  const url = env.LLM_CHAT_URL;
  const apiKey = env.LLM_API_KEY;
  const model = env.LLM_MODEL;
  if (!url || !apiKey || !model) {
    throw new Error('LLM env missing (LLM_CHAT_URL / LLM_API_KEY / LLM_MODEL)');
  }
  const prompt = promptFor(request, remaining);
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), UPSTREAM_TIMEOUT_MS);
  try {
    const resp = await fetchImpl(url, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', 'Authorization': `Bearer ${apiKey}` },
      body: JSON.stringify({
        model: model,
        temperature: 0.2,
        response_format: { type: 'json_object' },
        messages: [
          { role: 'system', content: prompt.system },
          { role: 'user', content: prompt.user }
        ]
      }),
      signal: controller.signal
    });
    if (!resp || !resp.ok) {
      throw new Error(`upstream HTTP ${resp ? resp.status : 'no response'}`);
    }
    const data = await resp.json();
    const content = data && data.choices && data.choices[0] && data.choices[0].message &&
      data.choices[0].message.content;
    if (typeof content !== 'string' || content.length === 0) {
      throw new Error('upstream content missing');
    }
    return content;
  } finally {
    clearTimeout(timer);
  }
}

function extractJson(text) {
  const start = text.indexOf('{');
  const end = text.lastIndexOf('}');
  if (start < 0 || end <= start) {
    throw new Error('response has no JSON body');
  }
  return text.slice(start, end + 1);
}

function guardDecision(raw, request, remaining) {
  if (!raw || raw.schemaVersion !== SCHEMA_VERSION) {
    throw new Error('schemaVersion mismatch');
  }
  if (!Array.isArray(raw.keep) || raw.keep.length > MAX_KEEP) {
    throw new Error('keep missing or too long');
  }
  if (raw.keep.length !== remaining.length) {
    throw new Error('keep must include every remaining id exactly once');
  }
  const allowed = new Set(remaining.map((a) => a.id));
  const seen = new Set();
  const keep = [];
  for (const item of raw.keep) {
    if (!item || typeof item.id !== 'string' || !allowed.has(item.id)) {
      throw new Error('keep contains unknown id');
    }
    if (seen.has(item.id)) {
      throw new Error('keep contains duplicate id');
    }
    if (!Number.isInteger(item.dwellMin) || item.dwellMin < MIN_DWELL || item.dwellMin > MAX_DWELL) {
      throw new Error('dwellMin out of range');
    }
    seen.add(item.id);
    keep.push({ id: item.id, dwellMin: item.dwellMin });
  }
  const rawBlocks = raw.freeBlocks === undefined || raw.freeBlocks === null ? [] : raw.freeBlocks;
  if (!Array.isArray(rawBlocks) || rawBlocks.length > MAX_FREE_BLOCKS) {
    throw new Error('freeBlocks invalid');
  }
  const allIds = new Set(request.day.activities.map((a) => a.id));
  const freeBlocks = [];
  for (const block of rawBlocks) {
    if (!block || typeof block.afterId !== 'string' || !allIds.has(block.afterId)) {
      throw new Error('freeBlocks.afterId unknown');
    }
    if (!Number.isInteger(block.minutes) ||
        block.minutes < MIN_FREE_MIN || block.minutes > MAX_FREE_MIN) {
      throw new Error('freeBlocks.minutes out of range');
    }
    freeBlocks.push({ afterId: block.afterId, minutes: block.minutes });
  }
  const note = typeof raw.note === 'string' ? raw.note : '';
  if (note.length > MAX_NOTE) {
    throw new Error('note too long');
  }
  return { schemaVersion: SCHEMA_VERSION, keep: keep, freeBlocks: freeBlocks, note: note };
}

async function handler(event, context, deps) {
  const env = (deps && deps.env) || process.env;
  const fetchImpl = (deps && deps.fetch) || globalThis.fetch;
  const expected = env.YOUJING_REPLAN_TOKEN;
  if (!expected) {
    return fail(500, 'SERVER_MISCONFIGURED', 'YOUJING_REPLAN_TOKEN 未配置');
  }
  if (headerOf(event, 'x-youjing-token') !== expected) {
    return fail(401, 'UNAUTHORIZED', 'token 不匹配');
  }
  const body = parseBody(event);
  if (!body) {
    return fail(400, 'BAD_REQUEST', '请求体不是合法 JSON');
  }
  const request = normalizeRequest(body);
  if (!request) {
    return fail(422, 'INVALID_REQUEST', '请求字段不合法');
  }
  const remaining = remainingOf(request);
  if (remaining.length === 0) {
    return respond(200, { schemaVersion: SCHEMA_VERSION, keep: [], freeBlocks: [], note: '' });
  }
  let content;
  try {
    content = await callLlm(request, remaining, fetchImpl, env);
  } catch (err) {
    return fail(502, 'UPSTREAM_FAILED', String(err && err.message ? err.message : err));
  }
  try {
    const decision = guardDecision(JSON.parse(extractJson(content)), request, remaining);
    return respond(200, decision);
  } catch (err) {
    return fail(422, 'DECISION_REJECTED', String(err && err.message ? err.message : err));
  }
}

module.exports = {
  handler: handler,
  _test: {
    normalizeRequest: normalizeRequest,
    remainingOf: remainingOf,
    guardDecision: guardDecision,
    promptFor: promptFor,
    parseBody: parseBody,
    headerOf: headerOf
  }
};
```

- [ ] **Step 2: 写 `cloud/replanDay/package.json`**

```json
{
  "name": "replan-day",
  "version": "0.1.0",
  "private": true,
  "description": "有径 · 当日行程重排云函数（AGC Node 运行时）",
  "main": "index.js",
  "scripts": {
    "test": "node --test"
  },
  "engines": {
    "node": ">=18"
  }
}
```

- [ ] **Step 3: 写 `cloud/replanDay/test/replan.test.js`**

```js
'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');
const { handler, _test } = require('../index.js');

const ENV = {
  YOUJING_REPLAN_TOKEN: 'secret',
  LLM_CHAT_URL: 'https://llm.example/v1/chat/completions',
  LLM_API_KEY: 'k',
  LLM_MODEL: 'm'
};

function bodyOf() {
  return {
    schemaVersion: 1,
    now: '14:05',
    skippedId: 'a2',
    day: {
      date: '2026-10-26',
      activities: [
        { id: 'a1', time: '09:00', endTime: '10:00', title: 'past', category: 'sight', status: 'no_need' },
        { id: 'a2', time: '14:00', endTime: '15:00', title: 'skip', category: 'sight', status: 'not_booked' },
        { id: 'a3', time: '15:30', endTime: '16:30', title: 'next1', category: 'sight', status: 'not_booked', transport: { duration: 8 } },
        { id: 'a4', time: '16:45', endTime: '17:30', title: 'next2', category: 'shop', status: 'no_need' },
        { id: 'a5', time: '19:00', endTime: '20:00', title: 'booked', category: 'sight', status: 'booked' }
      ],
      meals: [{ type: 'lunch', time: '12:00' }, { type: 'dinner', time: '18:00' }]
    }
  };
}

function eventOf(body, token) {
  return {
    headers: { 'X-Youjing-Token': token === undefined ? 'secret' : token },
    body: JSON.stringify(body)
  };
}

function llmReturning(payload) {
  return async () => ({
    ok: true,
    status: 200,
    json: async () => ({ choices: [{ message: { content: JSON.stringify(payload) } }] })
  });
}

test('401 when token mismatches', async () => {
  const res = await handler(eventOf(bodyOf(), 'wrong'), {}, { env: ENV, fetch: llmReturning({}) });
  assert.equal(res.statusCode, 401);
});

test('500 when server token is not configured', async () => {
  const res = await handler(eventOf(bodyOf()), {}, { env: {}, fetch: llmReturning({}) });
  assert.equal(res.statusCode, 500);
});

test('422 when skippedId is unknown', async () => {
  const body = bodyOf();
  body.skippedId = 'nope';
  const res = await handler(eventOf(body), {}, { env: ENV, fetch: llmReturning({}) });
  assert.equal(res.statusCode, 422);
});

test('422 when skipped item is booked', async () => {
  const body = bodyOf();
  body.skippedId = 'a5';
  const res = await handler(eventOf(body), {}, { env: ENV, fetch: llmReturning({}) });
  assert.equal(res.statusCode, 422);
});

test('empty remaining returns empty keep without calling the LLM', async () => {
  const body = bodyOf();
  body.day.activities = body.day.activities.filter((a) => a.id === 'a1' || a.id === 'a2');
  const res = await handler(eventOf(body), {}, {
    env: ENV,
    fetch: async () => {
      throw new Error('should not be called');
    }
  });
  assert.equal(res.statusCode, 200);
  assert.deepEqual(JSON.parse(res.body).keep, []);
});

test('happy path accepts any permutation and freeBlocks', async () => {
  const decision = {
    schemaVersion: 1,
    keep: [{ id: 'a4', dwellMin: 45 }, { id: 'a3', dwellMin: 60 }],
    freeBlocks: [{ afterId: 'a2', minutes: 30 }],
    note: '放慢'
  };
  const res = await handler(eventOf(bodyOf()), {}, { env: ENV, fetch: llmReturning(decision) });
  assert.equal(res.statusCode, 200);
  const out = JSON.parse(res.body);
  assert.deepEqual(out.keep.map((k) => k.id).sort(), ['a3', 'a4']);
  assert.equal(out.freeBlocks[0].minutes, 30);
});

test('accepts an object body (AGC may pass parsed JSON)', async () => {
  const decision = {
    schemaVersion: 1,
    keep: [{ id: 'a3', dwellMin: 60 }, { id: 'a4', dwellMin: 45 }],
    freeBlocks: [],
    note: ''
  };
  const res = await handler({ headers: { 'x-youjing-token': 'secret' }, body: bodyOf() }, {},
    { env: ENV, fetch: llmReturning(decision) });
  assert.equal(res.statusCode, 200);
});

test('422 when keep misses an id', async () => {
  const decision = {
    schemaVersion: 1, keep: [{ id: 'a3', dwellMin: 60 }], freeBlocks: [], note: ''
  };
  const res = await handler(eventOf(bodyOf()), {}, { env: ENV, fetch: llmReturning(decision) });
  assert.equal(res.statusCode, 422);
});

test('422 when keep has a duplicate', async () => {
  const decision = {
    schemaVersion: 1,
    keep: [{ id: 'a3', dwellMin: 60 }, { id: 'a3', dwellMin: 60 }],
    freeBlocks: [],
    note: ''
  };
  const res = await handler(eventOf(bodyOf()), {}, { env: ENV, fetch: llmReturning(decision) });
  assert.equal(res.statusCode, 422);
});

test('422 when keep has an extra id', async () => {
  const decision = {
    schemaVersion: 1,
    keep: [{ id: 'a3', dwellMin: 60 }, { id: 'a4', dwellMin: 45 }, { id: 'a1', dwellMin: 30 }],
    freeBlocks: [],
    note: ''
  };
  const res = await handler(eventOf(bodyOf()), {}, { env: ENV, fetch: llmReturning(decision) });
  assert.equal(res.statusCode, 422);
});

test('422 when dwell or freeBlock is out of range', async () => {
  const badDwell = {
    schemaVersion: 1,
    keep: [{ id: 'a3', dwellMin: 14 }, { id: 'a4', dwellMin: 45 }],
    freeBlocks: [],
    note: ''
  };
  const res1 = await handler(eventOf(bodyOf()), {}, { env: ENV, fetch: llmReturning(badDwell) });
  assert.equal(res1.statusCode, 422);
  const badBlock = {
    schemaVersion: 1,
    keep: [{ id: 'a3', dwellMin: 60 }, { id: 'a4', dwellMin: 45 }],
    freeBlocks: [{ afterId: 'a2', minutes: 10 }],
    note: ''
  };
  const res2 = await handler(eventOf(bodyOf()), {}, { env: ENV, fetch: llmReturning(badBlock) });
  assert.equal(res2.statusCode, 422);
});

test('422 when afterId is unknown', async () => {
  const decision = {
    schemaVersion: 1,
    keep: [{ id: 'a3', dwellMin: 60 }, { id: 'a4', dwellMin: 45 }],
    freeBlocks: [{ afterId: 'zz', minutes: 30 }],
    note: ''
  };
  const res = await handler(eventOf(bodyOf()), {}, { env: ENV, fetch: llmReturning(decision) });
  assert.equal(res.statusCode, 422);
});

test('502 when upstream is non-2xx', async () => {
  const res = await handler(eventOf(bodyOf()), {}, {
    env: ENV,
    fetch: async () => ({ ok: false, status: 500, json: async () => ({}) })
  });
  assert.equal(res.statusCode, 502);
});

test('502 when upstream aborts', async () => {
  const res = await handler(eventOf(bodyOf()), {}, {
    env: ENV,
    fetch: async () => {
      const err = new Error('aborted');
      err.name = 'AbortError';
      throw err;
    }
  });
  assert.equal(res.statusCode, 502);
});

test('server recomputes remaining from the raw day', () => {
  const request = _test.normalizeRequest(bodyOf());
  const remaining = _test.remainingOf(request);
  assert.deepEqual(remaining.map((a) => a.id), ['a3', 'a4']);
  const prompt = _test.promptFor(request, remaining);
  assert.ok(prompt.system.includes('不得新增、遗漏或重复'));
  assert.ok(prompt.user.includes('a3'));
  assert.ok(prompt.user.includes('本次空闲段'));
});
```

- [ ] **Step 4: 写 `cloud/replanDay/README.md`**

```md
# replanDay 云函数

有径「不去下一站」的重排决策函数。契约见 `Docs/实况窗方案.md` §3.4。

## AGC 部署

1. AGC 控制台 → 云函数 → 创建函数，函数名 `replanDay`，运行时 Node 18/20，超时 10 秒。
2. 入口文件用本目录 `index.js`（零依赖，不需要安装 node_modules）。
3. 触发器选 HTTP，记下 URL，填进客户端 `ApiConfig.REPLAN_URL`（该值不提交仓库）。
4. 环境变量：
   - `YOUJING_REPLAN_TOKEN`：客户端 `ApiConfig.REPLAN_TOKEN` 必须与它一致；未配置时函数返回 500。
   - `LLM_CHAT_URL`：OpenAI 兼容的 `chat/completions` 地址。
   - `LLM_API_KEY`：只存在云函数环境变量，绝不进客户端。
   - `LLM_MODEL`：模型名。
5. 用控制台测试事件复制 `test/replan.test.js` 里的 `bodyOf()`，请求头带 `x-youjing-token`。

## 本地测试

```bash
cd cloud/replanDay
/Applications/DevEco-Studio.app/Contents/tools/node/bin/node --test
```

零依赖；上游用注入的 `deps.fetch` 假实现，不发真实请求。

## 失败口径

- 401：token 不匹配；400：body 不是 JSON；422：请求或决策不合法；500：函数没配 token；502：上游超时/非 2xx/内容缺失。
- 客户端对所有非 2xx 一视同仁：返回 `null`，走本地兜底。
```

- [ ] **Step 5: 写 `tools/replan_stub.js`（真机联调桩）**

```js
#!/usr/bin/env node
'use strict';

/**
 * 真机联调桩（仅开发用，不部署）：
 *   /replan          合法决策（remaining 全量、倒序、每站 45 分钟）
 *   /replan-invalid  未知 id → 端侧守卫拒绝 → 本地兜底
 *   /replan-500      非 2xx → 本地兜底
 *   /replan-slow     9 秒后回 → 客户端 6 秒读超时 → 本地兜底
 *
 * 用法：node tools/replan_stub.js
 * 手机侧：hdc -t <dev> rport tcp:8787 tcp:8787
 * App 侧：临时把 ApiConfig.REPLAN_URL 设成 http://127.0.0.1:8787/replan
 * 注意：桩不校验 token；联调完把 REPLAN_URL / REPLAN_TOKEN 恢复为空串。
 */

const http = require('node:http');

const PORT = Number(process.env.PORT || 8787);

function isTime(value) {
  return typeof value === 'string' && /^\d{2}:\d{2}$/.test(value);
}

function minutesOf(value) {
  return Number(value.slice(0, 2)) * 60 + Number(value.slice(3, 5));
}

function remainingOf(body) {
  const nowMin = minutesOf(body.now);
  return body.day.activities.filter((a) =>
    a.id !== body.skippedId &&
    a.category !== 'transport' && a.category !== 'hotel' &&
    a.status !== 'booked' &&
    minutesOf(a.time) >= nowMin);
}

const server = http.createServer((req, res) => {
  let raw = '';
  req.on('data', (chunk) => {
    raw += chunk;
  });
  req.on('end', () => {
    res.setHeader('Content-Type', 'application/json; charset=utf-8');
    const send = (payload) => res.end(JSON.stringify(payload));
    if (req.url === '/replan-slow') {
      setTimeout(() => send({ schemaVersion: 1, keep: [], freeBlocks: [], note: 'slow' }), 9000);
      return;
    }
    if (req.url === '/replan-500') {
      res.statusCode = 500;
      send({ code: 'STUB', message: 'forced 500' });
      return;
    }
    if (req.url === '/replan-invalid') {
      send({ schemaVersion: 1, keep: [{ id: 'not-exist', dwellMin: 60 }], freeBlocks: [], note: '' });
      return;
    }
    let body = null;
    try {
      body = JSON.parse(raw);
    } catch (err) {
      res.statusCode = 400;
      send({ code: 'BAD_REQUEST', message: 'bad json' });
      return;
    }
    if (!isTime(body.now) || !body.day || !Array.isArray(body.day.activities)) {
      res.statusCode = 422;
      send({ code: 'INVALID_REQUEST', message: 'bad shape' });
      return;
    }
    const remaining = remainingOf(body);
    const keep = remaining.map((a) => ({ id: a.id, dwellMin: 45 })).reverse();
    send({ schemaVersion: 1, keep: keep, freeBlocks: [], note: 'stub 重排' });
  });
});

server.listen(PORT, '0.0.0.0', () => {
  console.log(`replan stub listening on http://127.0.0.1:${PORT}`);
});
```

- [ ] **Step 6: 跑云函数单测**

Run:
```bash
cd cloud/replanDay
/Applications/DevEco-Studio.app/Contents/tools/node/bin/node --test
```
Expected: `pass 15`、`fail 0`。

- [ ] **Step 7: 本地冒烟桩**

Run（另开一个终端）:
```bash
/Applications/DevEco-Studio.app/Contents/tools/node/bin/node tools/replan_stub.js
```
再跑：
```bash
curl -s -X POST http://127.0.0.1:8787/replan -H 'Content-Type: application/json' -d '{"schemaVersion":1,"now":"14:05","skippedId":"a2","day":{"date":"2026-10-26","activities":[{"id":"a2","time":"14:00","endTime":"15:00","title":"skip","category":"sight","status":"not_booked"},{"id":"a3","time":"15:30","endTime":"16:30","title":"next","category":"sight","status":"not_booked"}],"meals":[]}}'
curl -s -X POST http://127.0.0.1:8787/replan-invalid -H 'Content-Type: application/json' -d '{}'
```
Expected:
```json
{"schemaVersion":1,"keep":[{"id":"a3","dwellMin":45}],"freeBlocks":[],"note":"stub 重排"}
{"schemaVersion":1,"keep":[{"id":"not-exist","dwellMin":60}],"freeBlocks":[],"note":""}
```
冒烟后 `Ctrl-C` 停桩。

---

### Task 7: hypium 回归（SkipPlanner / ReplanParser）

**Files:**
- Create: `entry/src/ohosTest/ets/test/SkipPlanner.test.ets`
- Create: `entry/src/ohosTest/ets/test/ReplanParser.test.ets`
- Modify: `entry/src/ohosTest/ets/test/List.test.ets`

**Interfaces:**
- Consumes: `SkipPlanner.*`、`ReplanParser.parseDecision`、`Replan` 类型、`DateUtils.minutesOf/hhmmOf`
- Produces: `skipPlannerTest(): void`、`replanParserTest(): void`（注册进 `List.test.ets` 默认套件）

- [ ] **Step 1: 写 `entry/src/ohosTest/ets/test/SkipPlanner.test.ets`**

```ts
/**
 * 跳过/重排纯逻辑回归（方案 §3.3 / §3.5）。
 * 与 tools/skip_planner_check.ts 同源；这里跑真机 hypium 侧，不碰 @kit / RDB。
 */

import { describe, it, expect, TestType, Size, Level } from '@ohos/hypium';
import {
  Activity, ActivityCategory, ActivityStatus, IntensityLevel, Meal, MealType, TransportInfo, TripDay
} from '../../../main/ets/model/Trip';
import {
  FreeBlock, KeepStop, ReplanDecision, ReplanOutcome, ReplanRequest
} from '../../../main/ets/model/Replan';
import { SkipPlanner } from '../../../main/ets/data/SkipPlanner';
import { DateUtils } from '../../../main/ets/utils/DateUtils';

function act(id: string, time: string, endTime: string, title: string,
  category: ActivityCategory = ActivityCategory.SIGHT,
  status: ActivityStatus = ActivityStatus.NOT_BOOKED,
  transportMin: number = 0): Activity {
  const a: Activity = {
    id: id, time: time, endTime: endTime, title: title, location: 'loc', address: 'addr',
    longitude: 1, latitude: 2, status: status, category: category
  };
  if (transportMin > 0) {
    const t: TransportInfo = { mode: '步行', duration: transportMin, detail: '' };
    a.transport = t;
  }
  return a;
}

function meal(type: MealType, time?: string): Meal {
  const m: Meal = { type: type, name: 'meal', location: 'loc', estimatedCost: 0 };
  if (time !== undefined) {
    m.time = time;
  }
  return m;
}

function dayOf(acts: Activity[], meals: Meal[]): TripDay {
  const d: TripDay = {
    dayIndex: 1, date: '2026-10-26', theme: 't', intensity: IntensityLevel.LOW,
    dailyCost: 0, activities: acts, meals: meals
  };
  return d;
}

function keepOf(id: string, dwellMin: number): KeepStop {
  const k: KeepStop = { id: id, dwellMin: dwellMin };
  return k;
}

function blockOf(afterId: string, minutes: number): FreeBlock {
  const b: FreeBlock = { afterId: afterId, minutes: minutes };
  return b;
}

function decisionOf(keep: KeepStop[], blocks: FreeBlock[], note: string): ReplanDecision {
  const d: ReplanDecision = { schemaVersion: 1, keep: keep, freeBlocks: blocks, note: note };
  return d;
}

function find(day: TripDay, id: string): Activity {
  for (const a of day.activities) {
    if (a.id === id) {
      return a;
    }
  }
  throw new Error(`missing activity ${id}`);
}

/** now=14:05；a2 是可跳过的下一站；a5 是已预约锚点；两餐是餐次锚点 */
function mainDay(): TripDay {
  return dayOf([
    act('a1', '09:00', '10:00', '早饭散步'),
    act('a2', '14:00', '15:00', '清水寺'),
    act('a3', '15:30', '16:30', '二年坂', ActivityCategory.SIGHT, ActivityStatus.NOT_BOOKED, 10),
    act('a4', '16:45', '17:30', '锦市场', ActivityCategory.SHOP, ActivityStatus.NO_NEED, 5),
    act('a5', '19:00', '20:00', '夜景', ActivityCategory.SIGHT, ActivityStatus.BOOKED)
  ], [meal(MealType.LUNCH, '12:00'), meal(MealType.DINNER, '18:00')]);
}

export default function skipPlannerTest(): void {
  describe('SkipPlanner', () => {
    it('date_time_primitives', TestType.FUNCTION | Size.SMALLTEST | Level.LEVEL1, () => {
      expect(DateUtils.minutesOf('00:00')).assertEqual(0);
      expect(DateUtils.minutesOf('23:59')).assertEqual(1439);
      expect(DateUtils.minutesOf('24:00')).assertEqual(-1);
      expect(DateUtils.minutesOf('9:00')).assertEqual(-1);
      expect(DateUtils.hhmmOf(1439)).assertEqual('23:59');
      expect(DateUtils.hhmmOf(1440)).assertEqual('23:59');
    });

    it('skippable_gate', TestType.FUNCTION | Size.SMALLTEST | Level.LEVEL1, () => {
      expect(SkipPlanner.isSkippable(ActivityCategory.SIGHT, ActivityStatus.NOT_BOOKED)).assertTrue();
      expect(SkipPlanner.isSkippable(ActivityCategory.SIGHT, ActivityStatus.BOOKED)).assertFalse();
      expect(SkipPlanner.isSkippable(ActivityCategory.TRANSPORT, ActivityStatus.NO_NEED)).assertFalse();
      expect(SkipPlanner.isSkippable(ActivityCategory.HOTEL, ActivityStatus.NO_NEED)).assertFalse();
      expect(SkipPlanner.isSkippable(ActivityCategory.REST, ActivityStatus.NO_NEED)).assertFalse();
      expect(SkipPlanner.isSkippable(null, ActivityStatus.NO_NEED)).assertFalse();
    });

    it('remaining_includes_rest', TestType.FUNCTION | Size.SMALLTEST | Level.LEVEL1, () => {
      expect(SkipPlanner.remainingIds(mainDay(), 'a2', 845).join(',')).assertEqual('a3,a4');
      const restDay: TripDay = dayOf([
        act('a2', '14:00', '15:00', '可跳过'),
        act('r1', '15:10', '15:40', '休息', ActivityCategory.REST, ActivityStatus.NO_NEED)
      ], []);
      expect(SkipPlanner.remainingIds(restDay, 'a2', 845).join(',')).assertEqual('r1');
    });

    it('valid_decision_reorders_and_keeps_anchors',
      TestType.FUNCTION | Size.SMALLTEST | Level.LEVEL1, () => {
        const outcome: ReplanOutcome = SkipPlanner.plan(mainDay(), 'a2', 845,
          decisionOf([keepOf('a4', 40), keepOf('a3', 60)], [], '下午节奏放缓'));
        expect(outcome.usedFallback).assertFalse();
        const out: TripDay = outcome.day;
        expect(find(out, 'a2').category).assertEqual(ActivityCategory.REST);
        expect(find(out, 'a2').title).assertEqual('空闲');
        expect(find(out, 'a2').status).assertEqual(ActivityStatus.NO_NEED);
        expect(find(out, 'a2').note ?? '').assertEqual('已跳过：清水寺');
        expect(find(out, 'a2').time).assertEqual('14:00');
        expect(find(out, 'a2').endTime).assertEqual('15:00');
        expect(find(out, 'a4').time).assertEqual('15:05');
        expect(find(out, 'a4').endTime).assertEqual('15:45');
        expect(find(out, 'a3').time).assertEqual('15:55');
        expect(find(out, 'a3').endTime).assertEqual('16:55');
        expect(find(out, 'a5').time).assertEqual('19:00');
        expect(out.activities.map((a: Activity): string => a.id).join(',')).assertEqual('a1,a2,a3,a4,a5');
        expect(outcome.note.indexOf('下午节奏放缓') >= 0).assertTrue();
      });

    // keep 必须覆盖全部剩余站点（a3、a4），少一项会被守卫判非法走兜底
    it('free_block_after_skipped_applies', TestType.FUNCTION | Size.SMALLTEST | Level.LEVEL1, () => {
      const r: ReplanOutcome = SkipPlanner.plan(mainDay(), 'a2', 845,
        decisionOf([keepOf('a3', 60), keepOf('a4', 40)], [blockOf('a2', 30)], ''));
      expect(r.usedFallback).assertFalse();
      expect(find(r.day, 'a3').time).assertEqual('15:40');
    });

    it('free_block_already_passed_ignored', TestType.FUNCTION | Size.SMALLTEST | Level.LEVEL1, () => {
      const r: ReplanOutcome = SkipPlanner.plan(mainDay(), 'a2', 845,
        decisionOf([keepOf('a3', 60), keepOf('a4', 40)], [blockOf('a1', 30)], ''));
      expect(find(r.day, 'a3').time).assertEqual('15:10');
    });

    it('free_block_after_kept_stop_applies', TestType.FUNCTION | Size.SMALLTEST | Level.LEVEL1, () => {
      const r: ReplanOutcome = SkipPlanner.plan(mainDay(), 'a2', 845,
        decisionOf([keepOf('a3', 60), keepOf('a4', 40)], [blockOf('a3', 20)], ''));
      expect(r.usedFallback).assertFalse();
      expect(find(r.day, 'a3').time).assertEqual('15:10');
      expect(find(r.day, 'a4').time).assertEqual('16:35');
    });

    it('anchor_crossing_moves_to_anchor_end', TestType.FUNCTION | Size.SMALLTEST | Level.LEVEL1, () => {
      const crossDay: TripDay = dayOf([
        act('a2', '17:00', '17:30', '可跳过'),
        act('a3', '18:30', '19:30', '下一站')
      ], [meal(MealType.DINNER, '18:00')]);
      const r: ReplanOutcome = SkipPlanner.plan(crossDay, 'a2', 1020,
        decisionOf([keepOf('a3', 120)], [], ''));
      expect(find(r.day, 'a3').time).assertEqual('19:00');
    });

    it('overflow_marks_carry_stops', TestType.FUNCTION | Size.SMALLTEST | Level.LEVEL1, () => {
      const lateDay: TripDay = dayOf([
        act('a2', '21:30', '22:00', '夜游'),
        act('a3', '22:10', '22:40', '塔'),
        act('a4', '22:50', '23:20', '桥')
      ], []);
      const r: ReplanOutcome = SkipPlanner.plan(lateDay, 'a2', 1320,
        decisionOf([keepOf('a3', 60), keepOf('a4', 60)], [], ''));
      expect(r.usedFallback).assertFalse();
      expect(find(r.day, 'a3').time).assertEqual('22:00');
      expect(find(r.day, 'a4').time).assertEqual('22:50');
      expect((find(r.day, 'a4').note ?? '').indexOf('待调整') >= 0).assertTrue();
      expect(r.note.indexOf('部分站点待调整') >= 0).assertTrue();
    });

    it('invalid_decision_falls_back', TestType.FUNCTION | Size.SMALLTEST | Level.LEVEL1, () => {
      const rejects: ReplanDecision[] = [
        decisionOf([keepOf('a3', 60)], [], ''),
        decisionOf([keepOf('a3', 60), keepOf('a4', 40), keepOf('a1', 30)], [], ''),
        decisionOf([keepOf('a3', 60), keepOf('a3', 60)], [], ''),
        decisionOf([keepOf('a3', 10), keepOf('a4', 40)], [], ''),
        decisionOf([keepOf('a3', 241), keepOf('a4', 40)], [], ''),
        decisionOf([keepOf('a3', 60), keepOf('a4', 40)], [blockOf('a3', 10)], ''),
        decisionOf([keepOf('a3', 60), keepOf('a4', 40)], [blockOf('zz', 30)], ''),
        decisionOf([keepOf('a3', 60), keepOf('a4', 40)], [], 'x'.repeat(201))
      ];
      for (let i = 0; i < rejects.length; i++) {
        const r: ReplanOutcome = SkipPlanner.plan(mainDay(), 'a2', 845, rejects[i]);
        expect(r.usedFallback).assertTrue();
        expect(find(r.day, 'a2').title).assertEqual('空闲');
      }
      const schema2: ReplanDecision = {
        schemaVersion: 2, keep: [keepOf('a3', 60), keepOf('a4', 40)], freeBlocks: [], note: ''
      };
      expect(SkipPlanner.plan(mainDay(), 'a2', 845, schema2).usedFallback).assertTrue();
    });

    it('local_fallback_shifts_past_anchors', TestType.FUNCTION | Size.SMALLTEST | Level.LEVEL1, () => {
      const r: ReplanOutcome = SkipPlanner.plan(mainDay(), 'a2', 845, null);
      expect(r.usedFallback).assertTrue();
      expect(find(r.day, 'a3').time).assertEqual('20:00');
      expect(find(r.day, 'a4').time).assertEqual('21:15');
      expect(r.note.indexOf('离线重排') >= 0).assertTrue();

      const lateFb: ReplanOutcome = SkipPlanner.plan(dayOf([
        act('a2', '22:30', '23:00', '夜游'),
        act('a3', '23:10', '23:40', '塔'),
        act('a4', '23:45', '23:59', '桥')
      ], []), 'a2', 1380, null);
      expect(lateFb.usedFallback).assertTrue();
      expect(find(lateFb.day, 'a3').time).assertEqual('23:10');
      expect((find(lateFb.day, 'a3').note ?? '').indexOf('待调整') >= 0).assertTrue();
      expect(lateFb.note.indexOf('部分站点待调整') >= 0).assertTrue();
    });

    it('request_whole_day_and_clone_deep', TestType.FUNCTION | Size.SMALLTEST | Level.LEVEL1, () => {
      const req: ReplanRequest = SkipPlanner.buildRequest(mainDay(), 'a2', 845);
      expect(req.schemaVersion).assertEqual(1);
      expect(req.now).assertEqual('14:05');
      expect(req.day.activities.length).assertEqual(5);
      expect(req.day.meals.length).assertEqual(2);
      expect(req.day.activities[2].transport?.duration ?? -1).assertEqual(10);
      expect(req.day.meals[0].time ?? '').assertEqual('12:00');
      const rawFirst: Record<string, Object> =
        req.day.activities[0] as unknown as Record<string, Object>;
      expect(rawFirst['note'] === undefined && rawFirst['reason'] === undefined).assertTrue();

      const original: TripDay = mainDay();
      const clone: TripDay = SkipPlanner.cloneDay(original);
      clone.activities[2].title = '改名';
      if (clone.activities[2].transport !== undefined) {
        clone.activities[2].transport.duration = 99;
      }
      expect(find(original, 'a3').title).assertEqual('二年坂');
      expect(find(original, 'a3').transport?.duration ?? -1).assertEqual(10);
    });
  });
}
```

- [ ] **Step 2: 写 `entry/src/ohosTest/ets/test/ReplanParser.test.ets`**

```ts
/**
 * ReplanParser 回归：响应必须是 schemaVersion=1 的严格 JSON。
 * 上限/越界/重复的拒绝码与 TripParser 同口径（2001/2002/2003）。
 */

import { describe, it, expect, TestType, Size, Level } from '@ohos/hypium';
import { ReplanParser } from '../../../main/ets/ai/ReplanParser';
import { ReplanDecision } from '../../../main/ets/model/Replan';
import { AppError } from '../../../main/ets/common/error/AppError';
import { ErrorCode } from '../../../main/ets/common/error/ErrorCode';

function keepOf(id: string, dwellMin: number): Record<string, Object> {
  const o: Record<string, Object> = { 'id': id, 'dwellMin': dwellMin };
  return o;
}

function textOf(root: Record<string, Object>): string {
  return JSON.stringify(root);
}

function codeOf(fn: () => void): number {
  try {
    fn();
    return 0;
  } catch (err) {
    if (err instanceof AppError) {
      return err.code;
    }
    return -1;
  }
}

export default function replanParserTest(): void {
  describe('ReplanParser', () => {
    it('parse_valid_decision', TestType.FUNCTION | Size.SMALLTEST | Level.LEVEL1, () => {
      const text: string = '```json\n' + textOf({
        'schemaVersion': 1,
        'keep': [keepOf('a3', 60), keepOf('a4', 45)],
        'freeBlocks': [{ 'afterId': 'a2', 'minutes': 30 }],
        'note': '下午节奏放缓'
      }) + '\n```';
      const d: ReplanDecision = ReplanParser.parseDecision(text);
      expect(d.schemaVersion).assertEqual(1);
      expect(d.keep.length).assertEqual(2);
      expect(d.keep[1].id).assertEqual('a4');
      expect(d.keep[1].dwellMin).assertEqual(45);
      expect(d.freeBlocks.length).assertEqual(1);
      expect(d.freeBlocks[0].afterId).assertEqual('a2');
      expect(d.freeBlocks[0].minutes).assertEqual(30);
      expect(d.note).assertEqual('下午节奏放缓');
    });

    it('optional_fields_default', TestType.FUNCTION | Size.SMALLTEST | Level.LEVEL1, () => {
      const d: ReplanDecision = ReplanParser.parseDecision(
        textOf({ 'schemaVersion': 1, 'keep': [keepOf('a3', 15)] }));
      expect(d.freeBlocks.length).assertEqual(0);
      expect(d.note).assertEqual('');
      expect(d.keep[0].dwellMin).assertEqual(15);

      const extra: ReplanDecision = ReplanParser.parseDecision(textOf({
        'schemaVersion': 1, 'keep': [keepOf('a3', 60)], 'unknown': 'ignored'
      }));
      expect(extra.keep.length).assertEqual(1);
    });

    it('reject_bad_json_and_schema', TestType.FUNCTION | Size.SMALLTEST | Level.LEVEL1, () => {
      expect(codeOf((): void => {
        ReplanParser.parseDecision('not json at all');
      })).assertEqual(ErrorCode.JSON_PARSE_FAILED);
      expect(codeOf((): void => {
        ReplanParser.parseDecision(textOf({ 'keep': [] }));
      })).assertEqual(ErrorCode.SCHEMA_VALIDATION_FAILED);
      expect(codeOf((): void => {
        ReplanParser.parseDecision(textOf({ 'schemaVersion': 2, 'keep': [] }));
      })).assertEqual(ErrorCode.SCHEMA_VALIDATION_FAILED);
      expect(codeOf((): void => {
        ReplanParser.parseDecision(textOf({ 'schemaVersion': 1, 'keep': 'x' }));
      })).assertEqual(ErrorCode.TYPE_GUARD_FAILED);
      expect(codeOf((): void => {
        ReplanParser.parseDecision(textOf({ 'schemaVersion': 1 }));
      })).assertEqual(ErrorCode.SCHEMA_VALIDATION_FAILED);
    });

    it('reject_keep_limits', TestType.FUNCTION | Size.SMALLTEST | Level.LEVEL1, () => {
      const many: Record<string, Object>[] = [];
      for (let i = 0; i < 21; i++) {
        many.push(keepOf(`a${i}`, 60));
      }
      expect(codeOf((): void => {
        ReplanParser.parseDecision(textOf({ 'schemaVersion': 1, 'keep': many }));
      })).assertEqual(ErrorCode.SCHEMA_VALIDATION_FAILED);
      expect(codeOf((): void => {
        ReplanParser.parseDecision(textOf({ 'schemaVersion': 1, 'keep': [keepOf('a3', 14)] }));
      })).assertEqual(ErrorCode.SCHEMA_VALIDATION_FAILED);
      expect(codeOf((): void => {
        ReplanParser.parseDecision(textOf({ 'schemaVersion': 1, 'keep': [keepOf('a3', 241)] }));
      })).assertEqual(ErrorCode.SCHEMA_VALIDATION_FAILED);
      expect(codeOf((): void => {
        ReplanParser.parseDecision(textOf({ 'schemaVersion': 1, 'keep': [keepOf('a3', 60.5)] }));
      })).assertEqual(ErrorCode.TYPE_GUARD_FAILED);
      expect(codeOf((): void => {
        ReplanParser.parseDecision(textOf({
          'schemaVersion': 1, 'keep': [keepOf('a3', 60), keepOf('a3', 60)]
        }));
      })).assertEqual(ErrorCode.TYPE_GUARD_FAILED);
      expect(codeOf((): void => {
        ReplanParser.parseDecision(textOf({ 'schemaVersion': 1, 'keep': [keepOf('', 60)] }));
      })).assertEqual(ErrorCode.TYPE_GUARD_FAILED);
    });

    it('reject_free_block_and_note_limits', TestType.FUNCTION | Size.SMALLTEST | Level.LEVEL1, () => {
      expect(codeOf((): void => {
        ReplanParser.parseDecision(textOf({
          'schemaVersion': 1, 'keep': [], 'freeBlocks': [
            { 'afterId': 'a1', 'minutes': 30 }, { 'afterId': 'a2', 'minutes': 30 },
            { 'afterId': 'a3', 'minutes': 30 }, { 'afterId': 'a4', 'minutes': 30 }
          ]
        }));
      })).assertEqual(ErrorCode.SCHEMA_VALIDATION_FAILED);
      expect(codeOf((): void => {
        ReplanParser.parseDecision(textOf({
          'schemaVersion': 1, 'keep': [], 'freeBlocks': [{ 'afterId': 'a1', 'minutes': 10 }]
        }));
      })).assertEqual(ErrorCode.SCHEMA_VALIDATION_FAILED);
      expect(codeOf((): void => {
        ReplanParser.parseDecision(textOf({
          'schemaVersion': 1, 'keep': [], 'note': 'x'.repeat(201)
        }));
      })).assertEqual(ErrorCode.SCHEMA_VALIDATION_FAILED);
    });
  });
}
```

- [ ] **Step 3: 注册进 `List.test.ets`**

在 import 区末尾追加：

```ts
import skipPlannerTest from './SkipPlanner.test';
import replanParserTest from './ReplanParser.test';
```

在 `promptContractTest();` 之后追加：

```ts
  skipPlannerTest();
  replanParserTest();
```

- [ ] **Step 4: 编译校验留给测试构建**

本步不单独跑 `check_ets_files`：它面向主模块，测试文件在 Task 9 随 `entry@ohosTest` 一起编译。若 Task 9 的测试构建失败，按报错修测试文件，不改实现期望值。

---

### Task 8: OnTripPage 接入「不去下一站」与撤销

**Files:**
- Modify: `entry/src/main/ets/pages/OnTripPage.ets`

**Interfaces:**
- Consumes: `SkipPlanner.isSkippable/isSkippedMarker/cloneDay/plan`、`ReplanClient.requestDecision`、`ReplanOutcome/ReplanDecision`、`WidgetSync.refreshAll`、`DateUtils.minutesOf`
- Produces: 页面内 `performSkip(expectedStopId: string): Promise<void>`、`undoSkip(): Promise<void>`、`canSkipNext(): boolean`（P1 实况窗深链会复用 `performSkip`，入口参数 `act=skip&stopId` 对 `expectedStopId` 做陈旧校验）

- [ ] **Step 1: 补 import**

把第 19–23 行这五行：

```ts
import { Activity, ActivityStatus, MealType, Trip, TripDay } from '../model/Trip';
import { TripDao } from '../data/TripDao';
import { CheckinDao } from '../data/CheckinDao';
import { ExpenseDao } from '../data/ExpenseDao';
import { DateUtils } from '../utils/DateUtils';
```

替换为：

```ts
import { Activity, ActivityCategory, ActivityStatus, MealType, Trip, TripDay } from '../model/Trip';
import { ReplanDecision, ReplanOutcome } from '../model/Replan';
import { TripDao } from '../data/TripDao';
import { SkipPlanner } from '../data/SkipPlanner';
import { CheckinDao } from '../data/CheckinDao';
import { ExpenseDao } from '../data/ExpenseDao';
import { ReplanClient } from '../ai/ReplanClient';
import { DateUtils } from '../utils/DateUtils';
import { WidgetSync } from '../widget/TodayCard';
```

- [ ] **Step 2: `DayStop` 增加 `category`**

在 `interface DayStop` 的 `isMeal: boolean;` 之后插入：

```ts
  /** 活动分类；餐次为 null——「不去」入口按它和 status 判定 */
  category: ActivityCategory | null;
```

- [ ] **Step 3: 删除页内 `minutesOf`，`hoursText` 改用 `DateUtils`**

删除这整段（原第 64–70 行）：

```ts
function minutesOf(hhmm: string): number {
  const parts: string[] = hhmm.split(':');
  if (parts.length < 2) {
    return 0;
  }
  return Number(parts[0]) * 60 + Number(parts[1]);
}
```

把 `hoursText` 整段替换为：

```ts
function hoursText(start: string, end: string): string {
  const mins: number = Math.max(0, DateUtils.minutesOf(end) - DateUtils.minutesOf(start));
  return `${Math.round(mins / 6) / 10}`;
}
```

> 页内旧函数对非法时刻返回 0；`DateUtils.minutesOf` 返回 -1。下面 `reload` 与 `buildStops` 的替换已把两处时刻入口改成「`Math.max(0, …)` 兜底」或「先判空」，不会有第三处残留引用。

- [ ] **Step 4: 增加状态与私有字段**

在 `private trip: Trip | null = null;` 之后插入：

```ts
  @State private replanning: boolean = false;
  /** 顶部提示：正在重排 / 重排结果 / 失败原因 */
  @State private notice: string = '';
  @State private canUndo: boolean = false;
  /** 「不去」只在今天提供；回看历史日不出现 */
  @State private isToday: boolean = false;
  /** 当前展示的整日；跳过/撤销都以它为输入 */
  private day: TripDay | null = null;
  /** 跳过前的深拷贝（只在本进程有效，方案 §3.6） */
  private skipSnapshot: TripDay | null = null;
  private skipSnapshotTripId: string = '';
  private skipSnapshotDayIndex: number = 0;
```

- [ ] **Step 5: 用 async 版替换整个 `reload()`**

把 `private reload(): void { … }` 整段（原第 107–164 行，从 `private reload(): void {` 到对应 `}`）替换为：

```ts
  private async reload(): Promise<void> {
    if (this.tripId.length === 0) {
      Logger.warn('Ui.OnTrip', '无 tripId，旅行中页保持空态');
      return;
    }
    const context: common.Context = this.ctx();
    const now: string = clockNow();
    this.clock = now;
    try {
      const trip: Trip | null = await TripDao.loadTrip(context, this.tripId);
      if (trip === null) {
        this.trip = null;
        this.day = null;
        this.current = null;
        this.next = null;
        this.rows = [];
        this.checkedIn = false;
        this.isToday = false;
        this.clearSkipState();
        this.notice = '';
        return;
      }
      this.trip = trip;
      AppStorage.setOrCreate(ACTIVE_TRIP_KEY, trip.id);
      if (this.skipSnapshotTripId.length > 0 && this.skipSnapshotTripId !== trip.id) {
        this.clearSkipState();
        this.notice = '';
      }
      const day: TripDay | null = this.pickDay(trip);
      this.day = day;
      const stops: DayStop[] = day === null ? [] : this.buildStops(day);
      if (day === null || day.activities.length === 0 || stops.length === 0) {
        this.dayLabel = '旅行中';
        this.current = null;
        this.next = null;
        this.totalMin = 0;
        this.elapsedMin = 0;
        this.nextLeg = '';
        this.checkedIn = false;
        this.isToday = false;
        this.canUndo = false;
        const emptyMarks: Record<string, number> = await CheckinDao.listForTrip(context, trip.id);
        await this.buildRows(emptyMarks);
        return;
      }
      this.isToday = day.date === DateUtils.todayIso();
      this.canUndo = this.skipSnapshot !== null && this.skipSnapshotTripId === trip.id &&
        this.skipSnapshotDayIndex === day.dayIndex;
      this.dayLabel = `进行中 · Day ${day.dayIndex}`;
      let cur: number = -1;
      for (let i = 0; i < stops.length; i++) {
        if (stops[i].sortMin <= DateUtils.minutesOf(now)) {
          cur = i;
        }
      }
      if (cur < 0) {
        cur = 0;
      }
      const curStop: DayStop = stops[cur];
      this.current = curStop;
      this.next = cur + 1 < stops.length ? stops[cur + 1] : null;
      // 进度条只在"这一站有结束时刻"时给：餐次没有 endTime，不拿一小时假装它的窗口
      if (!curStop.isMeal && curStop.endTime.length > 0) {
        const start: number = curStop.sortMin;
        const end: number = Math.max(start + 1, DateUtils.minutesOf(curStop.endTime));
        this.totalMin = end - start;
        this.elapsedMin = Math.max(0, Math.min(this.totalMin, DateUtils.minutesOf(now) - start));
      } else {
        this.totalMin = 0;
        this.elapsedMin = 0;
      }
      const nx: DayStop | null = this.next;
      this.nextLeg = nx !== null && nx.hasTransport
        ? `${nx.transportMode} ${nx.transportMin}分钟${nx.transportDetail.length > 0 ? ` · ${nx.transportDetail}` : ''}`
        : '';
      const marks: Record<string, number> = await CheckinDao.listForTrip(context, trip.id);
      this.checkedIn = marks[curStop.key] !== undefined;
      await this.buildRows(marks);
    } catch (err) {
      Logger.error('Ui.OnTrip', `加载失败: ${(err as Error).message}`);
    }
  }
```

- [ ] **Step 6: 增加跳过/撤销方法**

紧跟在上面 `reload()` 的结束 `}` 之后、`mealKey` 之前插入：

```ts
  /** 「不去」只对「今天 + 可跳过的下一站」显示；餐次/交通/住宿/已预约/空闲一律不给 */
  private canSkipNext(): boolean {
    const next: DayStop | null = this.next;
    return this.isToday && !this.replanning && next !== null && !next.isMeal &&
      SkipPlanner.isSkippable(next.category, next.status);
  }

  /**
   * 跳过下一站：云函数决策 → 端侧排程 → 落库 → 刷新页面。
   * expectedStopId 来自实况窗按钮，用于拒绝「按钮已陈旧」的点击；页面内入口传 ''。
   */
  private async performSkip(expectedStopId: string): Promise<void> {
    const trip: Trip | null = this.trip;
    const day: TripDay | null = this.day;
    const next: DayStop | null = this.next;
    if (trip === null || day === null || next === null) {
      this.toast('没有可跳过的下一站');
      return;
    }
    if (this.replanning) {
      return;
    }
    if (!this.isToday) {
      this.toast('只能跳过今天的站点');
      return;
    }
    if (expectedStopId.length > 0 && expectedStopId !== next.key) {
      this.toast('下一站已变化，请重试');
      return;
    }
    if (next.isMeal || !SkipPlanner.isSkippable(next.category, next.status)) {
      this.toast('这一站不能跳过');
      return;
    }
    const skippedId: string = next.key;
    const nowMin: number = DateUtils.minutesOf(clockNow());
    const snapshot: TripDay = SkipPlanner.cloneDay(day);
    this.replanning = true;
    this.notice = '正在重排今日剩余行程…';
    let outcome: ReplanOutcome | null = null;
    try {
      const decision: ReplanDecision | null =
        await ReplanClient.requestDecision(day, skippedId, nowMin);
      outcome = SkipPlanner.plan(day, skippedId, nowMin, decision);
    } catch (err) {
      this.replanning = false;
      this.notice = '重排失败，行程未改动';
      Logger.error('Ui.OnTrip', `重排失败: ${(err as Error).message}`);
      return;
    }
    if (outcome === null) {
      this.replanning = false;
      this.notice = '重排失败，行程未改动';
      return;
    }
    const updated: Trip = this.replaceDay(trip, outcome.day);
    try {
      await TripDao.saveTrip(this.ctx(), updated);
    } catch (err) {
      this.replanning = false;
      this.notice = '保存失败，行程未改动';
      Logger.error('Ui.OnTrip', `保存重排失败: ${(err as Error).message}`);
      return;
    }
    this.skipSnapshot = snapshot;
    this.skipSnapshotTripId = trip.id;
    this.skipSnapshotDayIndex = outcome.day.dayIndex;
    this.trip = updated;
    this.replanning = false;
    this.notice = outcome.note;
    this.canUndo = true;
    await this.reload();
    this.refreshWidget();
  }

  /** 撤销 = 把跳过前快照写回该日并落库；快照只在本进程、只保留一层 */
  private async undoSkip(): Promise<void> {
    const trip: Trip | null = this.trip;
    const snapshot: TripDay | null = this.skipSnapshot;
    if (trip === null || snapshot === null || this.skipSnapshotTripId !== trip.id) {
      this.toast('没有可撤销的重排');
      return;
    }
    if (this.replanning) {
      return;
    }
    this.replanning = true;
    this.notice = '正在撤销…';
    const updated: Trip = this.replaceDay(trip, SkipPlanner.cloneDay(snapshot));
    try {
      await TripDao.saveTrip(this.ctx(), updated);
    } catch (err) {
      this.replanning = false;
      this.notice = '撤销失败，行程未改动';
      Logger.error('Ui.OnTrip', `撤销失败: ${(err as Error).message}`);
      return;
    }
    this.trip = updated;
    this.clearSkipState();
    this.replanning = false;
    this.notice = '已撤销重排';
    await this.reload();
    this.refreshWidget();
  }

  /** 用改写后的整天替换 trip.days 的同一 dayIndex；其余天原引用不动 */
  private replaceDay(trip: Trip, day: TripDay): Trip {
    const days: TripDay[] = [];
    for (const d of trip.days) {
      days.push(d.dayIndex === day.dayIndex ? day : d);
    }
    const updated: Trip = {
      id: trip.id, destination: trip.destination, startDate: trip.startDate, endDate: trip.endDate,
      people: trip.people, budget: trip.budget, style: trip.style, overview: trip.overview,
      days: days, tips: trip.tips
    };
    return updated;
  }

  private clearSkipState(): void {
    this.skipSnapshot = null;
    this.skipSnapshotTripId = '';
    this.skipSnapshotDayIndex = 0;
    this.canUndo = false;
  }

  private refreshWidget(): void {
    WidgetSync.refreshAll(this.ctx()).catch((err: Error): void => {
      Logger.warn('Ui.OnTrip', `卡片刷新失败: ${err.message}`);
    });
  }
```

- [ ] **Step 7: `buildStops` 隐藏跳过产生的空闲块，并带上 `category`**

把整个 `private buildStops(day: TripDay): DayStop[] { … }` 替换为：

```ts
  private buildStops(day: TripDay): DayStop[] {
    const stops: DayStop[] = [];
    for (const a of day.activities) {
      // 跳过改写出的「空闲」不是可打卡站点；它仍是排程锚点（SkipPlanner 读原 day）
      if (SkipPlanner.isSkippedMarker(a)) {
        continue;
      }
      const t = a.transport;
      stops.push({
        key: a.id, time: a.time, sortMin: Math.max(0, DateUtils.minutesOf(a.time)), title: a.title,
        endTime: a.endTime, note: a.note === undefined ? '' : a.note,
        place: a.address.length > 0 ? a.address : a.location, isMeal: false, kind: '', cost: 0,
        category: a.category,
        status: a.status, transportMode: t === undefined ? '' : t.mode,
        transportMin: t === undefined ? 0 : t.duration,
        transportDetail: t === undefined ? '' : t.detail, hasTransport: t !== undefined
      });
    }
    for (const m of day.meals) {
      const shown: string = m.time === undefined ? '' : m.time;
      stops.push({
        key: this.mealKey(day.dayIndex, m.type), time: shown,
        sortMin: shown.length > 0 ? Math.max(0, DateUtils.minutesOf(shown)) : this.mealSlot(m.type),
        title: m.name.length > 0 ? m.name : this.mealLabel(m.type),
        kind: this.mealLabel(m.type), endTime: '', note: '',
        place: m.location, isMeal: true, cost: m.estimatedCost,
        category: null,
        status: null, transportMode: '', transportMin: 0, transportDetail: '',
        hasTransport: false
      });
    }
    stops.sort((x: DayStop, y: DayStop): number => x.sortMin - y.sortMin);
    return stops;
  }
```

- [ ] **Step 8: 增加顶部提示条 builder**

在 `@Builder groupHeader()` 之前插入：

```ts
  @Builder
  noticeBar() {
    Row({ space: SpaceTokens.sm }) {
      Text(this.notice)
        .fontSize(TypeTokens.caption.size)
        .fontWeight(450)
        .fontColor(ColorTokens.body)
        .layoutWeight(1)
      if (this.canUndo && !this.replanning) {
        YoujingButton({
          variant: YoujingButtonVariant.TEXT,
          label: '撤销',
          buttonWidth: 72,
          onAction: (): void => {
            this.undoSkip();
          }
        })
      }
    }
    .width('100%')
    .padding(SpaceTokens.md)
    .borderRadius(RadiusTokens.card)
    .backgroundColor(ColorTokens.surfaceElevated)
  }
```

- [ ] **Step 9: 在列表顶部渲染提示条**

在 `List({ space: SpaceTokens.lg }) {` 之后、hero 的 `ListItem()` 之前插入：

```ts
        if (this.notice.length > 0) {
          ListItem() {
            this.noticeBar()
          }
        }
```

- [ ] **Step 10: 下一站卡片加「不去下一站」入口**

把：

```ts
              Text(this.nextMeta())
                .fontSize(TypeTokens.caption.size)
                .fontWeight(450)
                .fontColor(ColorTokens.muted)
                .fontFeature("'tnum' on")
                .margin({ left: LayoutTokens.itineraryTimeGutter + SpaceTokens.sm })
                .alignSelf(ItemAlign.Start)
```

替换为：

```ts
              Row({ space: SpaceTokens.sm }) {
                Text(this.nextMeta())
                  .fontSize(TypeTokens.caption.size)
                  .fontWeight(450)
                  .fontColor(ColorTokens.muted)
                  .fontFeature("'tnum' on")
                  .layoutWeight(1)
                if (this.canSkipNext()) {
                  YoujingButton({
                    variant: YoujingButtonVariant.TEXT,
                    label: '不去下一站',
                    buttonWidth: 108,
                    onAction: (): void => {
                      this.performSkip(this.next === null ? '' : this.next.key);
                    }
                  })
                }
              }
              .width('100%')
              .padding({ left: LayoutTokens.itineraryTimeGutter + SpaceTokens.sm })
```

- [ ] **Step 11: 静态检查**

用 MCP 工具 `check_ets_files`，参数：

```json
{"files": ["entry/src/main/ets/pages/OnTripPage.ets"]}
```

Expected: `OnTripPage.ets` 无诊断。若报错落在 `SkipPlanner.ets` / `ReplanClient.ets` 等依赖文件，按记忆中的口径把依赖文件与页面分两次调用复核，不把依赖缓存 AST 的假错误当页面错误。

---

### Task 9: 构建、真机验收与提交

**Files:**
- 无源码改动（本任务只构建、验收、提交）

**Interfaces:**
- Consumes: Task 1–8 的全部产物
- Produces: 一次可回滚的提交 + 真机证据（hilog / 界面截图 / 测试输出）

- [ ] **Step 1: 离线与云函数门禁**

Run:
```bash
zsh tools/verify_replan_logic.sh
```
Expected:
```text
SKIP_PLANNER_OK cases=74
REPLAN_PARSER_OK cases=26
REPLAN_LOGIC_OK
```

Run:
```bash
cd cloud/replanDay && node --test
```
Expected: `pass 15`、`fail 0`。跑完回到仓库根目录。

- [ ] **Step 2: 构建主 HAP**

Run:
```bash
DEVECO_SDK_HOME=/Applications/DevEco-Studio.app/Contents/sdk \
  /Applications/DevEco-Studio.app/Contents/tools/node/bin/node \
  /Applications/DevEco-Studio.app/Contents/tools/hvigor/bin/hvigorw.js \
  --mode module -p module=entry@default -p product=default assembleHap \
  --analyze=normal --parallel
```
Expected: `BUILD SUCCESSFUL`。若 `entry` 有 ArkTS 错误，按报错修实现，不放宽 Test。

- [ ] **Step 3: 构建 ohosTest HAP**

Run:
```bash
DEVECO_SDK_HOME=/Applications/DevEco-Studio.app/Contents/sdk \
  /Applications/DevEco-Studio.app/Contents/tools/node/bin/node \
  /Applications/DevEco-Studio.app/Contents/tools/hvigor/bin/hvigorw.js \
  --mode module -p module=entry@ohosTest -p product=default assembleHap \
  --analyze=normal
```
Expected: `BUILD SUCCESSFUL`。

- [ ] **Step 4: 核对产物不是旧包**

Run:
```bash
ls -l entry/build/default/outputs/default/entry-default-signed.hap \
      entry/build/default/outputs/ohosTest/entry-ohosTest-signed.hap
md5 entry/build/default/outputs/default/entry-default-signed.hap \
    entry/build/default/outputs/ohosTest/entry-ohosTest-signed.hap
```
Expected: 两个文件的 mtime 都是本次构建时间（hvigor 的 UP-TO-DATE 会复用旧产物，见工程记忆）；把两条 md5 记进验收证据。

- [ ] **Step 5: 安装并跑 hypium**

先确认设备空闲（真人在用手机时不要注入点击/安装）：

```bash
HDC=/Applications/DevEco-Studio.app/Contents/sdk/default/openharmony/toolchains/hdc
$HDC -t 192.168.3.2:46077 shell power-shell wakeup
$HDC -t 192.168.3.2:46077 install -r entry/build/default/outputs/default/entry-default-signed.hap
$HDC -t 192.168.3.2:46077 install -r entry/build/default/outputs/ohosTest/entry-ohosTest-signed.hap
$HDC -t 192.168.3.2:46077 shell aa test -b com.youjing.app -m entry_test \
  -s unittest OpenHarmonyTestRunner -s timeout 120000
```
Expected: 输出 `OK`，失败项 0；`SkipPlanner` 的 12 个 `it` 与 `ReplanParser` 的 5 个 `it` 全部通过。

若锁屏导致 `10106102`：不要尝试绕过锁屏，记录未验边界后请真人解锁再跑（工程记忆：hdc 锁屏会卡死）。

- [ ] **Step 6: 真机走查 A —— 默认配置（REPLAN_URL 为空）**

前置：设备上有一段覆盖今天的行程（`MockConfig.USE_MOCK_DATA=true` 下用 UI 生成即可，生成日期选今天；不改 `TripInputPage.ets`）。

1. 行程列表 → 进入「旅行中」。
2. 找到「下一站」卡片：下一站是景点/购物/餐饮且未预约时，卡片右下出现「不去下一站」；是餐次/交通/住宿/已预约时不出现（负例）。
3. 点「不去下一站」：
   - 顶部先出现「正在重排今日剩余行程…」；
   - 随后变成 `已跳过「<站名>」，离线重排`（REPLAN_URL 为空，预期走本地兜底）；
   - 被跳过项不再出现在列表；后续站点的时刻整体后移且不与晚餐/已预约锚点重叠；顶部出现「撤销」。
4. 点「撤销」：顶部变 `已撤销重排`，所有时刻恢复；「撤销」消失。
5. 再跳过一次，然后 `hdc shell aa force-stop com.youjing.app`，重新冷启动回到该行程：重排后的时刻仍在，且没有「撤销」（快照不跨进程）。
6. 若当前下一站是餐次：等它过去或换一段下一站为景点的行程再验；「餐次不出现入口」本身要截图留证。

Expected: 上述全部符合；把每步界面文字与关键时刻记进证据。

- [ ] **Step 7: 真机走查 B —— 本地桩（成功 / 非法 / 500 / 慢响应）**

先在仓库根目录起桩（另开终端，保持运行）：

```bash
/Applications/DevEco-Studio.app/Contents/tools/node/bin/node tools/replan_stub.js
```

把 `entry/src/main/ets/common/config/ApiConfig.ets` 的 `REPLAN_URL` 临时改成：

```ts
  REPLAN_URL: 'http://127.0.0.1:8787/replan',
```

**全量重编**（ApiConfig 头注释：改网络配置必须全量重编）并安装：

```bash
DEVECO_SDK_HOME=/Applications/DevEco-Studio.app/Contents/sdk \
  /Applications/DevEco-Studio.app/Contents/tools/node/bin/node \
  /Applications/DevEco-Studio.app/Contents/tools/hvigor/bin/hvigorw.js \
  --mode module -p module=entry@default -p product=default clean assembleHap \
  --analyze=normal --parallel
HDC=/Applications/DevEco-Studio.app/Contents/sdk/default/openharmony/toolchains/hdc
$HDC -t 192.168.3.2:46077 rport tcp:8787 tcp:8787
$HDC -t 192.168.3.2:46077 install -r entry/build/default/outputs/default/entry-default-signed.hap
```

逐项验：

| 桩路径 | 改 `REPLAN_URL` 为 | 预期 |
| --- | --- | --- |
| 合法决策 | `/replan` | 顶部提示含 `stub 重排`（不是「离线重排」）；站点顺序按桩的 `keep`（逆序）落位；可撤销 |
| 非法决策 | `/replan-invalid` | 守卫拒绝 → `离线重排`；行程仍然完成跳过、不崩 |
| 上游 500 | `/replan-500` | 非 2xx → `离线重排` |
| 慢响应 | `/replan-slow` | 约 6s（readTimeout）后 `离线重排`，期间按钮不可重复触发 |

每次改 `REPLAN_URL` 都要重新全量构建 + 安装；HTTP 明文若被系统策略拦截，记录为 `[待验证]`（网络通路），不要为测试改放行配置。桩的启动输出与请求日志一并留证。

- [ ] **Step 8: 恢复配置，确认不把本地地址带进仓库**

把 `REPLAN_URL` 与 `REPLAN_TOKEN` 都改回 `''`，然后：

```bash
grep -n "REPLAN" entry/src/main/ets/common/config/ApiConfig.ets
grep -rn "127.0.0.1\|192.168\|x-youjing-token" entry/src/main/ets
```
Expected:
- `REPLAN_URL: ''`、`REPLAN_TOKEN: ''`、`REPLAN_CONNECT_TIMEOUT_MS: 2000`、`REPLAN_READ_TIMEOUT_MS: 6000`；
- 第二条只命中 `ReplanClient.ets` 里的 `x-youjing-token`（请求头名），没有任何 IP。

再全量重编一次主 HAP 并安装，保证设备上跑的是「默认空配置」版本。

- [ ] **Step 9: 提交（逐文件 add，不 push）**

```bash
git status --short
git add entry/src/main/ets/utils/DateUtils.ets
git add entry/src/main/ets/model/Replan.ets
git add entry/src/main/ets/data/SkipPlanner.ets
git add entry/src/main/ets/ai/ReplanParser.ets
git add entry/src/main/ets/ai/ReplanClient.ets
git add entry/src/main/ets/common/config/ApiConfig.ets
git add entry/src/main/ets/pages/OnTripPage.ets
git add entry/src/ohosTest/ets/test/SkipPlanner.test.ets
git add entry/src/ohosTest/ets/test/ReplanParser.test.ets
git add entry/src/ohosTest/ets/test/List.test.ets
git add cloud/replanDay/index.js
git add cloud/replanDay/package.json
git add cloud/replanDay/test/replan.test.js
git add cloud/replanDay/README.md
git add tools/replan_stub.js
git add tools/skip_planner_check.ts
git add tools/replan_parser_check.ts
git add tools/verify_replan_logic.sh
git status --short
git commit -m "$(cat <<'EOF'
feat(on-trip): 跳过下一站与当日重排——云函数决策、端侧排程、本地兜底与撤销

- 纯逻辑 SkipPlanner：剩余集合/锚点/通勤归属/23:59 溢出/兜底顺延，离线可断言
- 云函数 replanDay：令牌鉴权、服务端重算剩余、LLM 5s 超时与严格守卫
- OnTripPage：下一站「不去」入口、正在重排提示、自动落库、单层撤销
- ApiConfig 默认空地址，未配置/失败一律本地兜底，Key 不进客户端
EOF
)"
git log -1 --stat
```

Expected: 提交只含上面 18 个文件；`entry/src/main/ets/pages/TripInputPage.ets` 与 `build-profile.json5` 不在其中。**不要 push**（push 需单独授权）。

- [ ] **Step 10: 回填证据**

把以下内容写进本轮交付说明（不是新建文档）：

- `zsh tools/verify_replan_logic.sh` 的两行 `cases=`
- `node --test` 的 `pass/fail`
- 两个 HAP 的 md5 与 mtime
- hypium 的 `OK` 与用例数
- 真机走查 A/B 的界面文字截图与关键时刻
- 未验项：真机实网 LLM（无 Key）、实况窗按钮（P1 + 权益）、BOOKED 负例（Mock 造不出，单测已覆盖）

---

## 验收矩阵（对应方案 §4）

| 方案 §4 验收项 | 证据 | 状态 |
| --- | --- | --- |
| 纯逻辑：剩余集合（REST 仍算）、锚点不动、不重叠、不早于现在、跨锚点顺延、23:59 边界、缺项/多项/重复拒绝 | Task 1 离线断言 + Task 7 hypium | 可实现即验 |
| 云函数：401、400、422、502、空剩余不调 LLM、5s 超时 | Task 6 `node --test` 15 例 | 可实现即验 |
| 客户端守卫：非法 `keep` 集合 / 越界 / 未知 afterId / 超长 note → 兜底 | Task 1 离线断言 + 真机桩 `/replan-invalid` | 可实现即验 |
| 超时 8s 预算 → 兜底 | Task 7 桩 `/replan-slow` 约 6s | 需真机确认 |
| 跳过落库、重启后仍在 | Task 9 走查 A 第 5 步 | 需真机确认 |
| 撤销恢复且不跨进程 | Task 9 走查 A 第 4/5 步 | 需真机确认 |
| 餐次/交通/住宿/已预约/空闲不给入口 | Task 1 `isSkippable` 断言 + 走查 A 第 2 步 | BOOKED 仅单测（Mock 无 BOOKED） |
| 实况窗两个按钮与重排后刷新 | P1 计划 | `[待验证]`（权益审批中） |
| 真实 LLM 重排 | 云函数单测注入 fetch；真值需部署后验 | `[待验证]`（无 Key，未部署） |
