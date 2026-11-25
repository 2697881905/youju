---
title: "Docs · MapKit地点检索探针-2026-10-31.md"
id: markdown_cls1_798285c88467638f6a8dc28635ad6f33_0bcf8b6f9f346fb32f6b94ca54c238c17526104239726721
kb: 有径-YouJing
folder: "问题记录"
media_type: 7
tags: []
source: ima
exported_at: 2026-11-23T14:52:37.917Z
---
# Map Kit 地点检索真机探针（Stage 1）

2026-10-31 · 任意城市数据管线的第一步 · 只读探针，未接 UI、未写 RDB

## 结论

**Map Kit Site Kit 在当前签名与真机上可用**：`searchByText / geocode / nearbySearch /
searchById` 全部成功，0 个错误码。任意城市的主数据源可行，但有三条硬约束：

1. **必须传 `cityId` 且 `isCityLimit=true`**。不传 cityId 时「博物馆」会返回卢浮宫、
   大英博物馆等全球结果（实测 462 条，前 20 条只有 1 条在国内）。
2. **没有可用评分**：`poi.rating` 与 `poi.starRating` 在列表和详情里都恒为 0，
   `reliability` 未返回。热度只能按检索顺序 / 结果位置做秩，不编造评分。
3. **结果有重复与远郊混入**：西安城墙与「西安城墙·碑林历史文化景区」各一条；
   兵马俑有「秦始皇帝陵博物院」与「秦始皇兵马俑博物馆」两条；「水陆庵」在蓝田县
   （距市中心约 50km）也会进前 20。Stage 2 必须做去重与距离/区县过滤。

## 探针环境

- 真机 Pocket 2，HarmonyOS 7.0.0.109 / API 26，sm 363.5vp，深色档。
- 应用签名已含 Map Kit 能力；探针为临时 NavDestination 页，取证后已删除，未进提交。
- 调用 6 次，全部只读；零 LLM 调用、零配额报错。

## 实测记录

### 1. 西安 · 景点（带 cityId）

```
searchByText({ query:'景点', cityId:'西安', isCityLimit:true, pageIndex:1, pageSize:20, language:'zh-CN' })
→ totalCount=500  n=20
覆盖率：name=20 loc=20 admin3=20 poiTypes=20 openingHours=20 rating=20(值全 0) star=20(值全 0)
```

前 10 条：

| # | 名称 | 区县 | 坐标 | poiTypes |
|---|---|---|---|---|
| 1 | 大雁塔文化休闲景区 | 雁塔区 | 34.21905,108.96421 | TOURIST_ATTRACTION |
| 2 | 秦始皇帝陵博物院 | 临潼区 | 34.38768,109.28283 | TOURIST_ATTRACTION |
| 3 | 秦始皇兵马俑博物馆 | 临潼区 | 34.38626,109.28201 | MUSEUM |
| 4 | 西安城墙·碑林历史文化景区 | 新城区 | 34.26383,108.94830 | TOURIST_ATTRACTION |
| 5 | 西安城墙 | 新城区 | 34.26356,108.92537 | TOURIST_ATTRACTION |
| 6 | 汉城湖旅游风景区 | 未央区 | 34.30553,108.91875 | TOURIST_ATTRACTION |
| 7 | 曲江池遗址公园 | 雁塔区 | 34.20216,108.98426 | TOURIST_ATTRACTION |
| 8 | 大明宫国家遗址公园 | 新城区 | 34.29244,108.96327 | TOURIST_ATTRACTION |
| 9 | 陕西历史博物馆 | 雁塔区 | 34.22414,108.95506 | MUSEUM |
| 10 | 杜邑遗址公园 | 雁塔区 | 34.19694,109.02949 | TOURIST_ATTRACTION |

营业时间示例（`poi.openingHours.texts` 是逐周字符串，可直接展示）：

- 秦始皇帝陵博物院：`星期日: 7:30 - 14:00 … 星期六: 7:30 - 14:00`
- 秦始皇兵马俑博物馆：`8:30 - 17:00`（逐周）
- 西安城墙：`8:00 - 22:00`（逐周）
- 大雁塔文化休闲景区：空（对象存在但 texts 为空）

### 2. 不带 cityId 的对照（反证）

```
searchByText({ query:'博物馆', pageIndex:1, pageSize:20, language:'zh-CN' })
→ totalCount=462  n=20
前 20 条：宝马博物馆(慕尼黑)、卢浮宫(巴黎)、大英博物馆(卡姆登)、
新加坡国家博物馆、中国国家博物馆、上海科技馆……
```

结论：没有 cityId 的检索是**全球**检索；Stage 2 必须始终带 cityId + isCityLimit。

### 3. 成都 · 景点（带 cityId）

```
searchByText({ query:'景点', cityId:'成都', isCityLimit:true, pageIndex:1, pageSize:20 })
→ totalCount=500  n=20
前 6 条：宽窄巷子景区(青羊区)、成都动物园(成华区)、成都大熊猫繁育研究基地(成华区)、
桃花故里景区(龙泉驿区)、成都武侯祠博物馆(武侯区)、平乐古镇(邛崃市)
```

与西安同一模式：POI 类型覆盖 TOURIST_ATTRACTION / MUSEUM / ZOO / PARK / TEMPLE /
PLACE_OF_WORSHIP / TOWER，足以映射到现有四值标签的一小部分。

### 4. 城市中心

```
geocode({ query:'西安', language:'zh-CN' })
→ n=10
#1 西安市 34.33365,108.81960
#2 西安市中心 34.34208,108.94080
#3 西安市政协 34.34193,108.95628
```

`geocode` 能用，但第一条不一定是市中心；Stage 2 取「西安市中心」或对多条结果取中位数，
不要盲取第一条。

### 5. 住宿供给

```
nearbySearch({ location:大雁塔, query:'酒店', radius:3000 })
→ totalCount=486  n=20
距离：146.3m（嘉佰乐酒店）… 851.34m（西安大雁塔美居酒店）
```

酒店检索可用，带 `distance`，可作为「该区有没有住宿供给」的判据；价格档位仍无字段。

### 6. 详情补充

```
searchById({ siteId:大雁塔文化休闲景区, isChildren:false })
→ phone=有  website=无  description=546字  abstractText=52字  openingHours=空
abstractText：唐代玄奘为保存佛经主持修建的七层方形砖塔，世界文化遗产，展现盛唐佛教艺术与建筑精髓，夜间灯光秀尤为壮观。
```

详情能补简介，适合做 `brief`（标来源 MapKit）；但预约/门票/评分仍不可得。

## 字段覆盖与映射建议（Site → Spot）

| Spot 字段 | 实测来源 | 结论 |
|---|---|---|
| id | `site.siteId` | 加城市前缀，如 `mk:610100:<siteId>` |
| name | `site.name` | 20/20；空则丢弃 |
| city | 用户目的地（cityId 校验） | 以用户输入为准 |
| tags | `poi.poiTypes` | 只映射高置信类型（ZOO/PARK→family，MUSEUM→classic），其余留空 |
| brief | `poi.abstractText` / `description` | 详情可得；没有就留空，不用 LLM 编 |
| suggestedDuration | 无字段 | 按类型给保守默认，标注「估算」 |
| popularity | 无评分 | 用检索顺序做秩（第 1 名 100 → 第 20 名 5），不伪造评分 |
| lat/lng | `site.location` | 20/20；缺失即丢弃，不用城市质心 |
| district | `addressComponent.adminLevel3` | 20/20；作为区县与 Area 聚合键 |
| nearestMetro | 无字段 | 留空或另查地铁，不猜 |
| booking | 无字段 | `requiresBooking=false` + 「以官方为准」 |
| openingHours | `poi.openingHours.texts` | 多数可得，可展示，但必须标来源/以官方为准；空值不显示 |
| provenance | 固定 `MapKit` + 抓取日 + `confidence='中'` | 界面可查 |

## 对 Stage 2 的约束（进入实现前）

1. **不落 RDB**：许可边界未确认前，检索结果只放内存/会话缓存，不写 `spot`/`area` 表；
   内置五城继续走种子库，两条通路互不影响。
2. **分页上限**：`totalCount` 实测封顶 500，`pageSize` 最大 20；抓 3 页（60 条）足够屏4
   候选，排序用检索顺序 + 距离过滤。
3. **去重**：同城同名/近名 + 距离 < 300m 视为同一 POI；至少处理西安城墙、兵马俑这类
   实测重复。
4. **距离过滤**：`adminLevel3` 属于远郊（如蓝田县）且距市中心 > 40km 的 POI 不进默认候选，
   可作为「周边」另列。
5. **Area 派生**：`geocode(city)` 取市中心 → 按 `adminLevel3` 聚合 → `nearbySearch('酒店')`
   判断供给 → 取到所选景点平均距离最近的区；`priceTier` 固定 `comfort` 并标「未校准」。
6. **失败不困住用户**：无网/无结果/配额报错时，屏4 显示「地图服务没有返回结果」+ 重试 +
   返回修改目的地；生成页不得只报 4003。
7. **开放问题**：配额与计费口径；缓存/展示的许可；非标准城市名与 cityId 的匹配；
   去重阈值；Area 质量抽检；LLM 增强的单城成本上限。

## 非目标

- 本轮不实现 Stage 2、不写任意城市数据、不改生成链路、不落库、不接 UI。
- 不把 Map Kit 没有的评分/预约/门票伪装成事实。
- 不用 LLM 补名称、坐标、行政区或预约规则。
