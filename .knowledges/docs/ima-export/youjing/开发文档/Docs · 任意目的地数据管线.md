---
title: "Docs · 任意目的地数据管线.md"
id: markdown_cls1_798285c88467638f6a8dc28635ad6f33_9b963c3504e2c120e1ac2328063bf3c27526104239726721
kb: 有径-YouJing
folder: "开发文档"
media_type: 7
tags: []
source: ima
exported_at: 2026-11-23T14:52:37.917Z
---
# 任意目的地数据管线 · 调研与分阶段方案

> 日期：2026-10-30 · 切片 4 行前便捷的配套调研
> 结论先行：**端侧 Map Kit 地点检索是首选主数据源**；OSM/Photon 在中文城市覆盖不足；
> 腾讯/高德需要 key 与配额，无后端时不应把 key 放进客户端；LLM 只做展示层增强，不做事实来源。
> 本期（切片 4）不实现任意城市，只把「一句话成行程」做成内置五城可用、未支持城市诚实拒绝。

---

## 1. 为什么现在做不了任意目的地

行前管线的事实来源是本地 RDB 种子库：

| 环节 | 现在依赖 | 限制 |
|---|---|---|
| 屏4 选景点 | `PlanRepository.loadSpots(city)` → 种子 `spot` 表 | 只有 北京/上海/广州/深圳/杨凌 |
| 屏5 选住宿区 | `PlanRepository.loadAreas(city)` → 种子 `area` 表 | 同上；京都仅 mock |
| 屏6 生成 | `GeneratingPage` 必须拿到 `Spot[]` + `Area[]`，缺任一直接 4003 | 无“空数据也能生成”的降级 |
| 一句话识别 | 本地确定性解析（零 LLM、零联网） | 未内置城市会明确说“还没有内置数据”，不静默改城市 |

所以任意目的地的关键不是解析句子，而是**先有一份可消费的景点/住宿区数据**。
这份数据必须包含：稳定 id、坐标、名称、区县、可排序的热度或等价权重、可解释的来源标注。

## 2. 候选数据源

### 2.1 Map Kit 地点检索（推荐主源）

SDK 已随 DevEco 安装，端侧直接调用，无需自建后端：

`/Applications/DevEco-Studio.app/Contents/sdk/default/hms/ets/api/@hms.core.map.site.d.ts`

已确认的接口（API 11+，`SystemCapability.Map.Core`）：

| 接口 | 用途 | 关键参数/返回 |
|---|---|---|
| `site.searchByText(context, params)` | 关键字找景点/片区 | `query`、`location?`、`radius?`(1–50000m)、`poiTypes?`、`countryCodes?`、`cityId?`、`isCityLimit?`、`pageIndex?`(1–500)、`pageSize?`(1–20)；返回 `totalCount` + `Site[]` |
| `site.nearbySearch(context, params)` | 以坐标为中心找周边 POI | `location` 必填、`query?`、`radius?`(默认 1000m，最大 50000m) |
| `site.queryAutoComplete(context, params)` | 输入补全 | 返回 `Site[]`（不含 viewport/时区等扩展字段） |
| `site.geocode(context, params)` | 地址 → 坐标 | `query`、`language?`、`bounds?` |
| `site.reverseGeocode(context, params)` | 坐标 → 行政区 | `location`、`radius?`(0–1000m)、`isExtension?`；扩展信息最多 30 POI/10 AOI/3 路/1 路口 |

`Site` 可用字段：`siteId`、`name?`、`formatAddress?`、`addressComponent`（`countryCode/adminLevel1..5/locality/subLocality/neighborhoods/行政编码`）、`location?`、`viewport?`、`distance?`、`poi?`。
`Poi` 可用字段：`poiTypes?`、`phone?`、`rating?`、`websiteUrl?`、`openingHours?`、`businessStatus?`（仅详情接口）、`brand?`、`starRating?`、`childNodes?`、`description?`、`abstractText?`。

**优势**：中文 POI 覆盖好、有坐标与行政区、有评分与电话/营业时间、端侧直连、无需自建服务。
**待验证**：AGC 是否已开通 Map Kit 对应服务与配额；检索结果字段在不同城市/POI 类型下的完整度；结果缓存与展示的许可边界。

### 2.2 OSM / Photon / Overpass（备选，做海外或离线兜底）

- 优势：开源、可自建、可离线导入。
- 劣势：中国城市 POI 密度与名称质量不稳定；缺少评分/营业时间/预约信息；ODbL 有署名与衍生数据义务。
- 结论：不作为国内任意城市的主源，只保留为海外目的地或离线兜底的技术选项。

### 2.3 腾讯位置服务 / 高德开放平台（能力全，但需要后端）

- 优势：POI、路线、行政区、评分齐全，中文城市覆盖最好之一。
- 劣势：需要 key 与配额；把 key 放进端侧可被提取，必须加后端代理与签名；本项目当前无服务端。
- 结论：若未来有后端，可作为 Map Kit 的等价替换或补充；本期不引入。

### 2.4 LLM 生成景点/住宿区（只做增强，不做事实源）

- 模型能编出不存在的景点、错误的开放时间与预约规则，且每次成本非零。
- 可用范围：给已检索到的真实 POI 生成一句话简介、标签建议、建议游玩时长等**展示层字段**，并标注“AI 生成，仅供参考”。
- 不可用范围：名称、坐标、行政区、是否需预约、门票/价格等硬信息。

## 3. 字段映射草案（Map Kit Site → 现有模型）

### 3.1 Site → Spot

| Spot 字段 | 来源 | 处理 |
|---|---|---|
| `id` | `site.siteId` | 加城市前缀避免跨城碰撞，如 `mk:610100:<siteId>` |
| `name` | `site.name` | 缺失则丢弃该条 |
| `city` | 用户目的地/`addressComponent.locality` | 以用户输入为准，回填校验 |
| `tags` | `poi.poiTypes` + 名称关键词 | 只能映射到四值封闭集；映射不出的先留空，不猜 |
| `brief` | `poi.description/abstractText`，缺失则由 LLM 增强 | 必须标来源 |
| `suggestedDuration` | 无直接字段 | 按 POI 类型给保守默认（如博物馆 120 分钟），并标“估算” |
| `popularity` | `poi.rating/starRating`（若有） | 归一化到 0–100；没有评分时用检索排序，并记录“无评分” |
| `latitude/longitude` | `site.location` | 缺失直接丢弃，不能用城市质心插值 |
| `district` | `addressComponent.adminLevel3` | 缺失留空 |
| `nearestMetro` | 无直接字段 | 近似用 `nearbySearch` 找地铁站，或留空 |
| `booking` | 无可靠字段 | 一律 `requiresBooking=false` 并显示“以官方为准”，不编预约规则 |
| `provenance` | 固定 `source='MapKit'`、`updatedAt=抓取日`、`confidence='中'` | 界面可查 |

### 3.2 住宿区 → Area

Map Kit 没有“住宿区”这个实体，需要派生：

1. 以 `geocode(城市 + 区名)` 或检索结果里的 `adminLevel3` 聚合，得到区县中心与名称；
2. 用 `nearbySearch(location=区中心, query='酒店')` 判断该区是否有住宿供给；
3. `priceTier` 暂不能可靠推断，默认 `comfort` 并在界面标注“未校准”；
4. `metroLines/anchorStations` 用车地铁站检索补充，拿不到就留空；
5. 只保留有坐标的区，按到所选景点平均直线距离排序（复用 `PlanAutoPick.nearestArea`）。

## 4. 待验证问题（进入实现前必须逐条给证据）

1. **服务开通与配额**：AGC 项目是否已开通 Map Kit 地点检索？调用是否计入配额、超出如何报错？
2. **字段真实度**：在西安/成都各抽 10 个热门 POI，记录 `name/location/addressComponent/rating/openingHours` 的实际返回率。
3. **结果质量**：`searchByText(query='景点', cityId=..., isCityLimit=true)` 是否会把商场/酒店混进来；需要哪些 `poiTypes` 过滤。
4. **许可边界**：检索结果能否落本地 RDB 缓存、缓存多久、是否必须展示来源。
5. **网络与失败**：无网/弱网时的降级文案与重试策略；失败不能把用户困在生成页。
6. **住宿区派生**：按区县聚合与按商圈聚合哪种更接近用户预期；是否要人工维护一份重点城市商圈表。
7. **成本**：若引入 LLM 增强，单城抓取 + 增强的 token 成本上限与缓存命中率。

## 5. 分阶段落地

### Stage 0（本期已完成）

- 城市定义单点化：`common/constants/Cities.ets`，DataSeeder / 屏2 城市列表 / 一句话解析读同一份。
- 一句话解析对未支持城市明确拒绝，不静默改城市。
- 自动选点/住宿区规则抽成纯模块，内置五城与未来任意城市共用同一套规则。

### Stage 1：Map Kit 真机探针（下一步，独立切片）

- 在真机上对一个未内置城市（建议西安）调用 `searchByText` 与 `nearbySearch`，把原始字段落日志/临时文件；
- 只做只读探针，不接 UI、不落正式 RDB；
- 产出：字段返回率表、POI 类型过滤建议、配额与错误码记录。

### Stage 2：任意城市只读接入（功能开关控制）

- 新增 `SpotSource` 抽象：`SeedSource`（现有五城）与 `MapKitSource`（任意城市）；
- 检索结果映射为 `Spot[]`，坐标缺失即丢弃；热度缺失时按检索排序并标注；
- 屏4/屏5 复用现有 UI，但顶部显示“数据来自地图服务，开放时间/预约以官方为准”；
- 生成页对“无住宿区”给明确出口，不再只报 4003。

### Stage 3：住宿区派生与质量校准

- 区县/商圈聚合 + 酒店供给检查；
- 人工抽检 3–5 个城市，校准 `priceTier` 与 `suggestedDuration` 默认值；
- 增加“数据纠错”入口（用户可报告错误 POI）。

### Stage 4：可选增强与缓存

- LLM 只补 `brief`/标签建议，逐条标“AI 生成”；
- 本地缓存与过期策略按许可结论执行；
- 监控：检索失败率、空结果率、生成完成率、用户改选率。

## 6. 验收口径（Stage 1/2）

- 未开通/无网络：界面必须说明原因并保留手动路径，不能白屏或死循环。
- 任一 POI 缺坐标：不得进入候选，不得用城市质心代替。
- 任一硬信息（预约、开放时间、门票）没有可靠来源：不展示为事实，统一“以官方为准”。
- 内置五城行为不回归：种子库路径、已有行程、离线可用性保持不变。
- 自动化：映射纯函数可离线断言；页面用 hypium + 真机走查；不把“接口能返回”当成“功能可用”。

## 7. 非目标

- 本期不做任意城市实现、不引入后端、不接第三方 key。
- 不为了“看起来支持”把未验证的 POI 塞进生成管线。
- 不用 LLM 编造景点或预约规则来填充空数据。

---

## 8. 2026-10-31 更新：Stage 1 / Stage 2 已落地

- **Stage 1 真机探针已完成**：Site Kit 可用、6 次只读调用 0 错误；`cityId + isCityLimit`
  是硬门槛；名称/坐标/区县/类型/营业时间可用，**评分恒 0、预约字段没有**；结果有重复与
  远郊混入。完整记录见 `Docs/MapKit地点检索探针-2026-10-31.md`。
- **Stage 2 已实施**：`MapKitCityStore` + `MapCityMapper`，种子库为空时回退 Map Kit，
  结果**只放内存（30min TTL）、不写 RDB**；屏2 一句话与「其他城市」输入都可进入；
  屏4/屏5/屏5b/屏6 已加来源、未校准与失败出口；无效城市会按地址归属校验拒绝。
  方案与代码清单见 `Docs/任意城市接入方案.md`。
- 仍开放：Map Kit 配额与检索结果缓存/展示许可；区县住宿档与通勤校准；远郊县过滤策略；
  md/浅色档验收。内置五城继续走种子库，不受影响。
