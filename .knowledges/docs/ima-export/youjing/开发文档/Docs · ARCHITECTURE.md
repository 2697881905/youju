---
title: "Docs · ARCHITECTURE.md"
id: markdown_cls1_798285c88467638f6a8dc28635ad6f33_992077dd7b776183eaaf6d001693411a7526104239726721
kb: 有径-YouJing
folder: "开发文档"
media_type: 7
tags: []
source: ima
exported_at: 2026-11-23T14:52:37.917Z
---
# ARCHITECTURE.md · 有径工程架构契约

> 依据 `Docs/有径·App开发文档.md` §5.4 落地，P1 产出。本文件是目录职责与依赖方向的单一事实源，任何结构变更须先更新本文件。

## 1. 目录职责表

代码根目录：`entry/src/main/ets/`

| 目录 | 职责 | 允许依赖 | 禁止依赖 |
|---|---|---|---|
| `entryability/` | 应用入口 UIAbility，生命周期、窗口、未捕获异常日志接入 | pages、common | components、model、data、ai、mock |
| `entrybackupability/` | 系统备份扩展入口 | common | 其余全部业务目录 |
| `pages/` | 页面级 @Entry 组件，路由与页面状态编排 | components、design、common | data、ai、model 的写操作直连（须经 data/、ai/ 层）、mock |
| `components/` | 可复用 UI 组件（DayCard、ActivityItem、SpotCard、AreaCard、OptionButton 等） | model（仅类型）、design、common | pages、data、ai、mock |
| `model/` | 业务数据模型与类型定义（Trip、Spot、Area、PlanParams） | common | pages、components、data、ai、mock、design |
| `data/` | RDB 建库建表、版本迁移、DAO（TripDao/SpotDao/AreaDao/DatabaseHelper） | model、mock（USE_MOCK_DATA 数据路由）、common | pages、components、ai、design |
| `ai/` | Prompt 构造、JSON Schema 常量、类型守卫解析、LLM 调用（PromptBuilder/TripSchema/TripParser/LlmClient） | model、common | pages、components、data、mock、design |
| `mock/` | Mock 数据（MockTrip），供开发期数据路由 | model、common | pages、components、data、ai、design |
| `utils/` | 纯函数工具（GeoUtils 距离计算、DateUtils 日期） | common | pages、components、model、data、ai、mock、design |
| `design/` | 设计 tokens（ColorTokens/TypeTokens/SpaceTokens/RadiusTokens/LayoutTokens/ShadowTokens/MotionTokens + HdsChrome），视觉常量单一事实源 | common | 其余全部业务目录 |
| `common/config/` | 网络与环境配置单点（ApiConfig、MockConfig） | 无 | 其余全部目录 |
| `common/constants/` | 构建开关与全局常量（BuildConfig） | 无 | 其余全部目录 |
| `common/error/` | AppError、ErrorCode 错误码区段表 | common/constants | 其余全部目录 |
| `common/logger/` | Logger 统一日志出口（hilog 封装，YouJing. 前缀，debug 受 IS_DEBUG 门控） | common/constants | 其余全部目录 |

## 2. 依赖方向规则

```
pages → components → model / data / ai / utils → common
                ↘ design ↗
```

- 依赖只允许沿箭头方向单向流动，禁止反向引用（如 common 引 model、model 引 components）。
- 禁止跨层直连：**页面不得直接操作 RDB，不得直接发起 LLM 请求**，必须分别经 `data/`、`ai/` 层。
- `design/` 与 `common/` 同属底层，可被 pages/components 引用；`design/` 不得引用任何业务目录。
- `mock/` 仅被 `data/` 在 `MockConfig.USE_MOCK_DATA` 开启时作为数据路由读取，UI 层不得直接引用 mock。

## 3. 与《有径·App开发文档》§5.4 的差异说明

§5.4 原结构为 pages / components / model / data / ai / mock / utils 七目录，本工程新增两处：

| 新增 | 理由 |
|---|---|
| `common/`（config / error / constants） | 配置单点收敛：URL、环境开关、阈值、错误码只在此定义，防止「有据」项目 BASE_URL 散落硬编码、改动漏重编的教训重演 |
| `design/` | 视觉常量统一：色值、间距、字号、动效以 token 为单一事实源，禁止裸样式值，防止风格约定散乱 |

## 4. 命名与标识规范

- 组件 / 类 / 枚举：UpperCamelCase（如 `SpotCard`、`TripDay`、`ActivityStatus`）。
- 变量 / 函数：lowerCamelCase（如 `parseTrip`、`dailyCost`）。
- 数组类型：一律 `T[]` 风格（如 `TripDay[]`），不用 `Array<T>`。
- 源码文件：一律 `.ets`。
- 组件 testKey / id：统一「模块前缀-语义 id」格式（如 `spot-card-{spotId}`、`area-card-{areaId}`），禁止裸数字 id，防止「有据」项目 `cardMedia-{id}` 类冲突。
- @State / @Prop 等状态变量名避开组件保留成员名（`tabIndex`、`width`、`height` 等）。

## 5. UI 约定（P5 增补）

- **禁止裸样式值**：pages/、components/ 中禁止裸写色值（#RRGGBB）、字号、间距数值，一律引用 `design/` 下对应 token（ColorTokens / TypeTokens / SpaceTokens / RadiusTokens / LayoutTokens）。字号字重走 `TypeTokens` 的**角色档**（display/title/headline/body/small/caption/overline/navLabel/time），不按「sizeXxx + weightXxx」的自由组合。
- **token 先行**：新增视觉常量必须先进 token 文件（语义化命名）再使用，禁止页面内先写死再"回头收口"。
- **豁免类**：布局百分比（'100%'）、动画 spring 参数、边框宽度等结构性数值不强制走 token，但同类数值出现第二处时必须收口。
- **组件标识**：testKey / id 按第 4 节「模块前缀-语义 id」规范执行（如 `spot-card-{spotId}`），禁止裸数字 id。
