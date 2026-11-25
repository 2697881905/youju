---
title: "Docs · 行后情绪方案.md"
id: markdown_cls1_798285c88467638f6a8dc28635ad6f33_4979111bfaad0086a32e923aae01a4797526104239726721
kb: 有径-YouJing
folder: "决策记录"
media_type: 7
tags: []
source: ima
exported_at: 2026-11-23T14:52:37.917Z
---
# 行后情绪方案（切片 5）

2026-10-31 · 已实施并真机取证（提交见 INIT_REPORT §5ci 续 48）

## 目标与范围

行后是产品三柱之一：让旅行结束后的证据变成可回看、可分享、可收集的情绪价值。
本轮做四件：

| 件 | 落点 | 一句话 |
|---|---|---|
| 回顾 | 新页 `TripReviewPage`（路由 `Review`） | 按天回放真实打卡、统计与新章，提供完整行程入口 |
| 城市套章 | 「我的勋章」城市组头 | 该城种子景点全集的收集进度，集齐点亮 |
| 海报 | 回顾页「分享海报」 | 本机离屏快照成 JPEG，走系统分享面板 |
| 周年 | 「我的行程」顶部横幅 | 今天月日落在某条跨年历史行程区间时出现 |

明确不做：通知/实况窗推送（受 AGC 审核与通知权限约束）、相册权限与存图、
后台任务、服务器同步、新建勋章表。

## 数据口径（不建表，不写第二份真相）

- **回顾**：`TripDao.loadTrip` 的聚合根 + `BadgeDao.listMine` 的活动打卡证据
  + `ExpenseDao.totalOfTrip` 的实记费用。餐次打卡（派生主键 `meal-{day}-{type}`）
  没有 activity 行，与勋章同口径**不进回顾**；活动已被从行程删除的孤儿打卡也丢弃。
- **本次新章**：`buildBadgeBoard` 合并后 `firstTripId === 本行程` 且首次打卡节点仍在
  行程里的章；同景点重复到访不重复计。
- **城市套章**：「套」= 该城种子景点全集（北京/上海/广州/深圳各 32，杨凌 10）。
  进度只统计名字精确落在种子清单里的景点章（去首尾空格、归一空格）；
  非种子节点、AI 改写过的标题仍留在勋章墙，但不计入套章。`total=0` 的城市不画进度。
  没有使用「必去」子集：深圳必去 0 个、各城 0–7 个，规则不统一。
- **周年**：比较月日而非平移整年，天然支持 12-30 → 01-02 的跨年环绕；
  只命中**已结束且跨年**的行程，结束日 ≥ 今天不算。文案按实际年份：
  一年前说「去年的今天」，更早说「2024 年的今天」；跨年行程按今天落在的那一段年份算。

## 交互

### 回顾入口

「我的行程」中**已结束且有活动打卡**的行程卡改落回顾，进度行文案变「已结束 · 可回顾」；
未出发、旅行中、已结束但无打卡的卡保持原落点（详情/旅行中）。回顾页顶部提供
「完整行程」，仍可回到屏 8。深链 `route=Review&param=<tripId>` 可达；无打卡的行程
给空态「这趟还没有可回顾的打卡」+ 完整行程出口。

### 回顾页

自上而下：海报式头卡（城市衬线字、日期、天数人数、打卡/新章/记账三格）→
「分享海报 / 完整行程」两枚动作 → 时间与凭证卡（到站次数、首次/末次打卡）→
逐日打卡时间线（只列真实打卡节点，未打卡的天如实写「这天没有打卡记录」）→
本次收下的章 → 行程总览（复用已存的 summary/highlights）→ 本机生成声明。
统计数字不在同屏重复：三格只出现在海报（它也是分享件），下面的卡片补时间与凭证口径。

### 海报

`getUIContext().getComponentSnapshot().createFromBuilder()` 离屏渲染固定 320vp 的
海报（外垫 16vp 画布色，避免 JPEG 把圆角外透明区压成白角）→ `image.ImagePacker.packToData`
JPEG 92 → 写 `cacheDir/youjing-review-<tripId>.jpg` → `ShareKit` 以 `general.image` 拉起
系统分享面板。图已生成但分享面板打不开/被取消时只提示，不再二次弹文本面板；
只有**生成不出图**才降级为 `shareSummary` 行程文本，并如实说明。不申请相册权限、
不存相册、不上传。

### 城市套章

勋章墙每个城市组头右侧从「N 枚」变为「已收 / 总数 枚」，下面一条官方 `Progress`；
集齐时进度变 success 色并出现「已集齐城市套章」。没有种子数据的城市退回「N 枚」，
不画进度。数据由 `BadgeDao.listMine` + `SpotDao.loadByCity` 现算，无写库。

### 周年

「我的行程」列表顶部（搜索框上方）在命中时出现一条 `primaryTint` 卡片：
「去年的今天，你在 X」/「2024 年的今天，你在 X」+「点开看看那趟旅程的回顾」，
点进回顾。无命中不占位。不做推送：通知权限与实况窗承载层未就绪。

## 代码清单

| 层 | 文件 | 要点 |
|---|---|---|
| 纯逻辑 | `utils/TripReview.ets` | `buildReview` / `reviewTimeText` / `findAnniversary` / `anniversaryText`，零 `@kit` |
| 纯逻辑 | `utils/CityStamps.ets` | `buildCityStamps` / `stampOf` / `stampPercent` / `stampMeta` |
| 数据 | `data/TripDao.ets` | `TripSummary.checkinCount`（活动打卡子查询） |
| 数据 | `data/BadgeDao.ets` | `listForTrip` + 共用读取器 |
| 数据 | `data/ShareExporter.ets` | `shareImage`（IMAGE + cache file URI） |
| 页面 | `pages/TripReviewPage.ets` | 回顾、离屏海报、降级 |
| 页面 | `pages/TripsPage.ets` | 卡片落点、可回顾文案、周年横幅 |
| 页面 | `pages/BadgePage.ets` | 城市套章进度 |
| 路由 | `pages/AppRouter.ets` | `Review` |
| 用例 | `ohosTest/.../TripReview.test.ets` + `List.test.ets` | 6 例 |
| 离线 | `tools/verify_trip_review.sh` + `tools/trip_review_check.ts` | 57 条断言 |

## 验收口径

离线断言 + hypium + 双 HAP + 十二把静态尺 + 对比度尺 + 真机走查。
真机证据与未验边界逐条记在 `Docs/INIT_REPORT.md` §5ci 续 48。
