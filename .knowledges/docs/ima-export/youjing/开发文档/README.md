---
title: "README.md"
id: markdown_cls1_798285c88467638f6a8dc28635ad6f33_a754906147e26ddfb4e63a2c545cb4007526104239726721
kb: 有径-YouJing
folder: "开发文档"
media_type: 7
tags: []
source: ima
exported_at: 2026-11-23T14:52:37.917Z
---
# 有径 · YouJing

> 本地优先的鸿蒙行程规划 App：一句话生成行程、按真实位置走完一天、回来还能看见自己走过的路。

纯 ArkTS 客户端应用，**没有自建后端**——行程、打卡、记账全部落在设备本地 RDB。
生成走 OpenAI 兼容的大模型接口（自带 Key），任意城市的景点与住宿区走华为 Map Kit。

## 三柱能力

| 柱 | 能力 | 关键实现 |
|---|---|---|
| **行前** | 一句话成行程（城市/日期/天数/人数/预算/偏好/兴趣标签，本机解析、零 LLM）、自动选点与住宿区预选、任意城市接入（未内置城市走 Map Kit）、动线总览（屏8 地图落点 ↔ 时间线行联动）、当日负载三态条、拖拽改序与跨天移动、ICS 导出、系统日历同步 | `utils/TripIntentParser` `utils/PlanAutoPick` `data/MapKitCityStore` `utils/DayLoad` `ai/` |
| **行中** | 天气行（Open-Meteo 免 Key）、三信号建议条（偏离 / 落后 / 有雨，一次一条、忽略后同类静默 30 分钟）、到站检测与带位置凭证的打卡、确认后跳过或顺延（端侧确定性排程，可撤销） | `common/weather/` `utils/ArrivalWatcher` `utils/SkipPlanner` `utils/TodayPlan` |
| **行后** | 勋章墙（不建表，全部由打卡证据派生；同名同城合并、到站升级、城市分组）、城市套章进度、旅行回顾页、海报快照分享、周年横幅 | `utils/BadgeBoard` `utils/TripReview` `data/BadgeDao` |

## 技术栈

- **HarmonyOS / API 26**（`targetSdkVersion` 与 `compatibleSdkVersion` 均为 `26.0.0`），Stage 模型，ArkTS **V1 严格模式**。
- UI 只用官方组件（ArkUI + `@kit.UIDesignKit` 的 Hds 系列），不自绘控件；玻璃面走系统材质档位。
- 数据：`@kit.ArkData` RDB（当前 `DB_VERSION = 9`，带级联清理与版本迁移）、`preferences` 存账号/同意态。
- 能力：Account Kit（华为账号，仅用于本机区分使用者）、Map Kit（地点检索 / 逆地理）、Calendar Kit、ShareKit、桌面卡片 FormKit、小艺 Skill。
- 生成：`ai/` 三层防线——提示词内嵌 Schema → `response_format` → `TripParser` 逐字段守卫；Schema、接口、守卫同源（`ai/TripSchema.ets`）。
- 测试：hypium（真机 251 例）+ 纯逻辑离线断言 + 十九把静态尺。

## 仓库结构

```
entry/src/main/ets/
  pages/        屏1–屏16 与 AppRouter（Navigation + NavPathStack，四 tab 各一条栈）
  components/   契约组件（YoujingButton / FloatingDock / 隐私同意弹窗 / 勋章弹窗 …）
  ai/           PromptBuilder · TripParser · TripSchema · LlmClient（传输抽象 + 重试）
  data/         DAO / RdbStore / PlanRepository（种子优先，缺数据回退 Map Kit）/ AccountStore
  model/        Trip / Spot / Area / PlanParams / Expense / Weather 等契约类型
  utils/        纯逻辑层（无 @kit，可离线断言）：Geo · DayLoad · PlanAutoPick · TripEnrich …
  design/       ColorTokens / TypeTokens / LayoutTokens（色值落 resources/base + resources/dark）
  common/       配置、错误码与文案、日志、权限、天气解析
entry/src/ohosTest/   hypium 用例（新文件必须注册进 List.test.ets 才会跑）
Docs/                 开发文档、架构、各方案与取证报告
tools/                十九把静态尺 + 离线断言脚本
```

## 快速开始

1. **环境**：DevEco Studio + HarmonyOS 26.0.0 SDK。命令行构建需显式指 SDK 根：

   ```bash
   export DEVECO_SDK_HOME=/Applications/DevEco-Studio.app/Contents/sdk
   ```

2. **填自己的配置**（`entry/src/main/ets/common/config/ApiConfig.ets`）：仓库版把
   `BASE_URL` / `LLM_CHAT_ENDPOINT` / `API_KEY` 留成空串以保证可编译，
   真机联调前填自己的 OpenAI 兼容端点与 Key。**这个文件不要提交密钥**——
   本地用 `git update-index --skip-worktree` 挂起，仓库里永远保持空值。
   不配 Key 也能跑：`MockConfig.USE_MOCK_DATA = true` 会走离线合成，
   完整验证「响应 → 守卫 → Trip」链路。
3. **地图能力**：未内置城市的景点/住宿区检索需要一份开通了 Map Kit 的调试 Profile
   （判据：解包后 `app-services-capabilities` 里出现 `com.huawei.service.mapkit`）。
   签名材料放在 `~/.ohos/config/`，不入库。
4. **构建 / 安装**：

   ```bash
   node <DevEco>/tools/hvigor/bin/hvigorw.js --mode module -p module=entry@default \
     -p product=default -p buildMode=debug assembleHap --no-daemon
   hdc install -r entry/build/default/outputs/default/entry-default-signed.hap
   ```

## 质量闸门

| 闸门 | 命令 | 当前状态 |
|---|---|---|
| ArkTS 编译 | `hvigorw … assembleHap`（主 + `entry@ohosTest`） | 零 error，pre-commit 强制 |
| 构建并装机（**失败即不装**） | `tools/build_install.sh [default\|ohosTest]` | 断言本轮日志有 `BUILD SUCCESSFUL` 才执行 `hdc install`，并检查产物 mtime；防止"构建 FAIL 但 install 仍回 AppMod finish、装上去是上一轮产物"这种假验证（§5ci 续 193/194） |\n| 真机单测 | `hdc shell "aa test -b com.youjing.app -m entry_test -s unittest OpenHarmonyTestRunner -s timeout 300000"` | 243/243（2026-11-04 复跑） |
| 纯逻辑离线断言 | `bash tools/verify_map_city.sh` / `verify_trip_intent.sh` / `verify_trip_review.sh` / `verify_replan_logic.sh` / `verify_weather_logic.sh` | 66 / 104 / 57 / 74+26 / 116 全绿 |
| 商业化链路真实进程验收（**集成探针**，不占「十九把静态尺」计数） | `bash tools/probe_bff_commercial.sh` | import `bff/src/index.js` 起**真进程** + 真 HTTP 走「激活→扣额度→付费墙→付费→高级额度」；跑在 `mktemp -d` 副本里（**不污染开发库**）；上游 LLM 用本机桩；收据改为**测试证书链现签的 JWS**（本地验签，无远端服务可桩），**真模型/真供应商花费 0**。2026-11-04 复跑：必守行为 **24/24**、支付守卫缺陷 **1 条**（只剩 D5「换设备白拿赠送」，属产品口径；D1/D2/D3/D4 已被 fail-closed 校验关闭，D6/D7/D8/D9 已修）。**故意不进 `verify_*.sh` 通配**——它要起进程，且当前必然 rc=1（D5 未拍板），红是正确信号而不是闸门失可用 |
| BFF 上线自检（**部署闸门**，不占静态尺计数） | `cd bff && npm run preflight` | 十四项检查（JWT 密钥、API Key、**IAP 收据本地 JWS 验签结构**（x5c 链+ES256+根信任+叶子 OID）、
`IAP_APP_ID`、根证书在位、**收据环境闸门**（默认只认 `Production`，`IAP_ALLOW_SANDBOX=1` 放行沙盒并出警告）、
verify 要设备票据 / notify 收 `jwsNotification` 并验签、按 `notificationRequestId` 幂等、
**设备激活验华为 idToken（D10）**、`HUAWEI_CLIENT_ID`、DB 路径、Prompt 生成物、本机 `/health`）。
**2026-11-04 复跑：通过 14 / 警告 0 / 阻断 0**（三条原阻断的真实凭证已配进 `bff/.env`，该文件不入库）。
沙盒验收期把 `IAP_ALLOW_SANDBOX=1` 留在生产配置里，会看到警告而不是静默放行 |
| LLM 提示词真模型回归（**付费探针**，默认不发请求） | `node tools/probe_llm_rules.mjs --days 3 --yes` | 生成一次真行程，结构类断言（validator / 午晚两餐 / 用餐重复 / 活动重叠 / 住宿区域）任一不成立即 FAIL；规则 19 预算超限默认 WARN（加 `--strict` 才判失败，对应屏8「去减一站」兜底）。不带 `--yes` 只打印请求规模与预估费用。2026-11-03 3 天与 7 天各跑通一次，约 ¥0.005/次 |
| 契约↔镜像一致性（**离线断言类**，不占「十九把静态尺」计数） | `bash tools/verify_mirror.sh`（无参数；零依赖 `sh`+`cmp`+`md5`） | ① `~/Pictures/…/docs` 三份 vs `Docs/design-v2/` 逐字节 `cmp` ② `Docs/design-v1/` 四份 vs 冻结哈希（基线 `c7671d9`）。2026-11-02 首跑 rc=0；反证：镜像改一个字节即报红退 1，`design-v1` 改一个字节即哈希不符退 1。**为什么要有它**：五把读契约的尺全指原件路径，`design-v2/README:67-69` 明写「快照落后不影响审计」⇒ 镜像失同步此前是合法状态，而 `prompts` 是出稿产线（引 DESIGN 72 处），落后就批量产 v1 视觉 |
| 设计契约静态尺 | `python3 tools/audit_colors.py`（另有 type / geometry / material / fontfamily / tnum / elevation / button_width / scroll_actions / label_fit / a11y_name / layout_patterns / skip_worktree / motion / **bar_scroll** / **seed** / **self_call** / **span_source** / **inset_source**） | **十九把静态尺**；`skip_worktree` 那条真命中（§5ci 续 83 的 `ApiConfig.BFF_BASE_URL`）已由 `8229245` 闭合。`bar_scroll` 管「每个顶栏调用点必须表态 `scrolled` 或 `scrollable`」（`--selftest` 三条控制全过才出数）。`seed` 管「喂给 AI 的种子数据本身对不对」：坏行/重复 id/枚举外值/离城/撞点/离区/无坐标且不在区表——**阳性对照是它首跑在修复前的主线上抓出 5 项真错**（北京五道营离东城 51.4km、陆家嘴离浦东 62.9km、广州两点 0m 重合等），修完 0 硬失败。`span_source`（2026-11-05 新增）管「行程天数与『N天N晚』文案只能有一个来源」：R1 抓 `spanDays(草稿日期对)`
  （草稿日期默认是空串，`spanDays('','')` 取到 1，而屏2 显示「今天起算 3 天」——真机拍到过屏2 写 3天2晚、屏5 只给 4 个名额、模型被要求排 1 天），
  唯一口径是 `TripLength.days()`；R2 抓手写 `${days}天${days-1}晚`（单日端成「1天0晚」），唯一口径是 `TripSpan.text()`。
  `--selftest` 阳性 4 / 阴性 5（含`self_call`（2026-11-04 新增）管「方法体只有一条语句、没有任何分支、却在调用自己」——
**阳性对照是它首跑就在 HEAD 里抓出真崩溃**：`4116bf4` 把 `MinePage.refreshMembership()` 写成了
`this.refreshMembership();`，hvigor 绿、hypium 237 绿、其余 16 把尺绿，真机一进「我的」就栈溢出。
`--selftest` 阳性 4 / 阴性 6（有守卫的递归、委托到同名他类方法都不能报）|
| 避让量单源尺 | `python3 tools/audit_inset_source.py`（`--selftest` 阳性 3 / 阴性 3） | R1 禁止页面把 `statusBarHeight` / `navIndicatorHeight` / `navBarHeight` 写进 `padding` / `margin` / `height` 表达式；R2 底部 dock 边距必须读 `bottomNavInsetVp`（`utils/navMode` 单源发布）。**阳性对照是 2026-11-05 真机那条缺陷**：壳层 `.padding({ top: this.statusBarHeight })` 和栏体 `avoidLayoutSafeArea` 把同一件让位写了两遍，带子归壳层涂、沉浸遮罩归栏体，滚动时量到「带子 L=18 / 栏体 L=11」的硬台阶。豁免只有发布点三处（`navMode` / `navInset` / `EntryAbility`） |
| 导航栈唯一绑定（`layout_patterns` 第 6 条） | `python3 tools/audit_layout_patterns.py --rule R6`（`--self-test` 阳性 R3/R4/R6 各 1 处） | 一个 `NavPathStack` 只能被一个 `Navigation` 持有，绑两处则后绑者抢走栈。现仓 6 个绑定点 = 宿主 `HOST_NAV`×1 + 五格各自 `this.pathStack`×5（这条正好反证「五格同构」成立）。踩点是 L2 计划原文写 `Navigation(APP_NAV)`，那会让向导链从「页签内」变成「盖住 dock 的全屏」 |
| 动效契约尺 | `python3 tools/audit_motion.py`（`--selftest` 30 条：阳性 13 类 / 阴性 13 类 / 键位点名 / 文档数字对表） | 判据：裸时长、`Curve` 枚举曲线、`.animation` 与 `.stateStyles` 顺序；**不做无声豁免**，W1–W5 白名单站点逐条打印 `file:line`；契约五档 + `ICurve` 自定义贝塞尔已真机坐实。跨仓取证跑在姊妹仓 197 个 `.ets` 上（HEAD 尺独有 11 条假红、新尺独有 0 条） |
| 真机对比度 | `python3 tools/audit_contrast.py <dump.json> <screenshot>`（`--selftest` 零设备复算遮挡判定） | 17 屏 + 2026-11-04 深色复测 3 屏（我的 27 节点 / 付费页 34 节点 / 向导首屏 27 节点）两档：浅色 0 低；深色唯一低项是 **dock 选中蓝 4.10–4.75:1**（用户 2026-10-26 拍板维持 `#0A84FF`，§5ci 续 82 已把地图格从 3.05 抬到 4.10 与其他四格同档）；被遮住的框按**节点树**判，不靠像素猜 |
| 真机滚到底净空（+滚动区出屏） | `python3 tools/verify_scroll_clearance.py`（`--selftest` 零设备复算判据 5；**一次只跑一份**，两份同抢真机会互相甩离目标屏） | 17 屏全 pass；行程格 −48.3vp → −0.3vp（贴平） |

取证约定：**结论要能被复现**。UI 问题必须同机位实拍复拍，布局争议用 `uitest dumpLayout`
读真实 bounds，颜色争议用像素量化，不接受「看代码应该没问题」。

## 调试入口

- 深链直达：`hdc shell "aa start -b com.youjing.app -a EntryAbility --ps route <页面名>"`
  （如 `GenerateFailed` 直接看屏7 降级页）。
- 色档探针（仅 debug 版）：`--ps darkprobe 1` / `--ps lightprobe 1` 把本 App 分别钉进深色或浅色档，
  系统主题不动；探针有没有真生效，用 dump 的 `backgroundColor` 判（浅色冷启后画布应为 `#FFFFFFFF`）。
  浅色档走查用的是临时加的对称探针（`lightprobe` / `loginprobe` / `consentprobe`），
  取证完即撤、不入库——见 `Docs/INIT_REPORT.md` §5ci 续 59。
- 日志：`hdc shell "hilog -x"`，LLM 每次调用的 token 用量与生成尝试次数都会落日志。

## 数据与隐私

- 行程 / 打卡 / 记账 / 勋章全部只写本机 RDB；换设备即丢，不上传服务器。
- 华为账号仅用于在本机区分不同使用者的数据分区；未登录可用「本机游客空间」。
- 首次进入有明示同意闸门（隐私政策 / 用户协议），未同意不放行主界面。
- 权限与用途：`INTERNET`（模型生成、地图检索、天气）、`LOCATION` / `APPROXIMATELY_LOCATION`
  （到站判定与前往下一站的建议）、`READ/WRITE_CALENDAR`（用户主动开启的行程写入）。
  定位只在前台订阅，后台持续定位与地理围栏受平台审核限制，未做。
- 天气请求只发送首站坐标且精确到 0.1°。

## 已知边界

- **宽屏 / md 档适配未验**：本机是竖折折叠屏（展开 363.5vp 仍是 sm 档），模拟器默认端口被占、
  自定义端口下文件传输与安装挂死，所以 md/大屏只有代码通路，没有实拍证据。
- **通知与实况窗**：能力已在 AGC 提交申请，审核未过前不实施。
- **任意城市数据质量**：Map Kit 无评分字段（热度只能按检索秩）、无预约信息（一律标「未获取，
  以官方为准」）、开放时间只展示各天一致的单一时段；远郊住宿区的排序口径还在取证中，
  丽江这类「古城 + 远郊雪山」双簇城市可能选错片区。
- 勋章防伪、多设备同步、云端账号体系：刻意不做，先验证产品价值。

## 文档

| 文件 | 内容 |
|---|---|
| `Docs/有径·App开发文档.md` | 产品与屏1–屏16 的原始需求书、阶段计划 |
| `Docs/ARCHITECTURE.md` / `TECH_STACK.md` | 分层与依赖、技术选型 |
| `Docs/INIT_REPORT.md` | 逐轮工程日志与真机取证（§5ci 续 N），问题—证据—修法—边界 |
| `Docs/LLM接入方案-2026-10-26.md` | 三层防线、传输抽象、成本口径 |
| `Docs/任意城市接入方案.md` · `Docs/MapKit地点检索探针-2026-10-31.md` | Map Kit 接入与探针实测 |
| `Docs/行中智能方案.md` · `Docs/行后情绪方案.md` | 天气/建议条/重排、回顾/勋章/海报 |
| `Docs/CONTRIBUTING.md` | 提交规范与 pre-commit 门禁（hooks 不随仓库分发，需手动启用） |
| `CHANGELOG.md` | 变更流水 |

## 协作约定

- 提交信息用中文 conventional commits（`feat(行前): …` / `fix(llm): …` / `chore(行前): …`），
  一轮工作打成一个提交。
- `git push` 需要单独授权，不在「改完就提交」的默认范围里。
- 真机操作前必须重新断言前台是自己；设备被真人使用时立即停手，不解锁、不绕过。

## 许可

专有软件，**保留所有权利**，见 `LICENSE`。第三方组件（如 Noto Serif SC 字体，
SIL Open Font License 1.1）各自沿用原始许可证。
