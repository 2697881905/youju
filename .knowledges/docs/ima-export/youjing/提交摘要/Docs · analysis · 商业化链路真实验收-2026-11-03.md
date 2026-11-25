---
title: "Docs · analysis · 商业化链路真实验收-2026-11-03.md"
id: markdown_cls1_798285c88467638f6a8dc28635ad6f33_706fc70401ce281d83d95fa1a78e3d0f7526104239726721
kb: 有径-YouJing
folder: "提交摘要"
media_type: 7
tags: []
source: ima
exported_at: 2026-11-23T14:52:37.917Z
---
# 商业化链路真实验收（BFF 首次作为进程启动）— 2026-11-03

探针：`bash tools/probe_bff_commercial.sh`（启动器 `tools/probe_bff_commercial.sh` + 断言 `tools/bff_commercial_probe.mjs`）
隔离方式：把 `bff/` 拷进 `mktemp -d` 副本、符号链接 `node_modules`、`data/` 建在副本里。
**原因**：`bff/src/db.js:7` 的 `DB_PATH` 是硬编码 `../data/youjing.db`、无环境变量入口，直接在仓库里起服务会往另一会话正在用的开发库写测试账号。
成本：**上游 LLM 由本机 stub 顶替，8 次调用全走桩，真模型花费 0**。

## 0. 为什么需要这份验收

`grep -rn "iap" bff/test/` **零命中** —— 付费路径一行测试都没有。
`bff/test/trip-route.integration.test.js` 用 `initDb(':memory:')` + in-process express 装配，
**`src/index.js` 从未作为真实进程启动过**，所以「路由挂载顺序」这一层此前无人验过
（例如 `/v1/entitlement` 与 `/v1/trip` 挂了 `authMiddleware`，`/v1/iap` 没挂，见 `src/index.js:27-30`）。

## 1. 已证成立的部分（13/14 必守行为）

| 行为 | 实测读数 |
| --- | --- |
| 真实进程可启动 | `[db] SQLite initialized` + `[bff] listening on :47811` + `/health` 200 |
| 匿名设备激活 | `POST /v1/device/activate` → 200，拿到 `deviceToken`，`giftRemaining=3` |
| 鉴权中间件在守（正对照） | 无票据 `GET /v1/entitlement` → **401 TOKEN_INVALID** |
| 额度真实扣减 | 首次生成 `source=gift`，`giftRemaining 3→2` |
| 幂等重放不双扣 | 同键第二次带 `Idempotency-Replayed: true`，**上游调用数 1→1、额度仍为 2** |
| 赠送用尽 | 三次后 `giftRemaining=0` |
| 付费墙可诚实到达 | 第四次 → **402 QUOTA_EXHAUSTED** |
| 同一路由的干净账号前提校验 | 账号 C 烧光 3 次后同样 402 |

记账逻辑（`reserveQuota/commitQuota/releaseQuota` + 先 `succeeded` 后读权益的注释）在真 HTTP 上是对得上的，这部分不用返工。

## 2. 缺陷清单（7 条支付守卫 + 1 条 500）

按「会不会漏钱 / 会不会把主路径打死」排序。

| # | 缺陷 | 实测证据 | 落点 | 修法（一句话） |
| --- | --- | --- | --- | --- |
| **D1** | ~~**伪造收据即可拿到订阅**~~ **已修（2026-11-03）** | 改前 `POST /v1/iap/verify {purchaseToken:"totally-forged-receipt-123", productType:"subscription"}` → 200 `verified:true`，`subscription={"status":"active",...}` | `bff/src/services/iap.js` | `verifyPurchase()` 改为 **fail-closed**：未配置 `IAP_VERIFY_URL`/`IAP_APP_ID`/`IAP_VERIFY_TOKEN` 一律拒绝（路由 503），配置后只认远端 `verified:true`，超时/5xx/网络错都按未通过。回归见 `bff/test/iap-verify.test.js`（5 例，含正对照）；探针在真实进程上验「伪造收据拒绝 + 真收据通过」两半 |
| **D2** | ~~**D1 兑换成真额度（利用链闭合）**~~ **已随 D1 关闭** | 探针复跑：伪造收据被拒后同一账号生成仍 **402 QUOTA_EXHAUSTED**；真收据账号则 200 `source=subscription` | `bff/src/routes/trip.js:20` | — |
| **D3** | ~~**伪造收据即可拿到行程通行证**~~ **已随 D1 关闭** | 探针复跑：`productType:"pass"` 的伪造收据 → `verified:false`，不落 `trip_pass` | 同 D1 | — |
| **D4** | ~~**伪造通行证买到「无限生成」**~~ **已随 D1 关闭** | 探针复跑：干净账号 C 烧光赠送→402，伪造 pass 被拒后仍 **402** | 同 D1 | — |
| **D5** | **赠送额度可按设备白拿** | 换 `deviceId=probe-device-b` 再次 `giftRemaining=3` | `bff/src/routes/device.js:8-46`（无 `unionId` 就建 `anon-<deviceId>`）+ 端侧 `DeviceTokenStore.ensureDeviceId()` 本地随机 UUID | 赠送到账必须以**真实 unionId** 为键；游客只给 0 次或 1 次，登录时再补发 |
| **D6** | ~~**上限口径与方案差 30 倍**~~ **已修（2026-11-03）** | 改前 `entitlement.dailyCap=20`、`usedToday` 按**今天**数 | `bff/src/services/quota.js` | 口径改为**按月**（`start of month` + `MONTHLY_CAP=20`），与方案 §2 和付费页「每月 20 次」一致；响应字段名 `usedToday`/`dailyCap` 沿用端侧契约，只改口径不改名。回归见 `bff/test/quota-window.test.js`（上月行与失败行都不计、月中用满退到赠送档）。**剩余成本敞口**：赠送额度仍可换设备白拿（D5） |
| **D7** | ~~**华为续费/退款回调是黑洞**~~ **已修（2026-11-03）** | 改前 `POST /v1/iap/notify` 只 `console.log` 后回 `200 {}`，权益读数前后**逐字相同** | `bff/src/routes/iap.js` + 新增 `bff/src/services/iapNotify.js` | 落地为真事件处理：RSA-SHA256 验签（`IAP_NOTIFY_PUBLIC_KEY` 未配置时 fail-closed 回 503）、`EXPIRED`→`status='expired'`、`RENEWED`→从较晚者起算续期、`REFUND`→订单退款 + 订阅置 refunded + 通行证按购买时绑定的 `order_id` 撤销、`eventId` 幂等。回归见 `bff/test/iap-notify.test.js`（9 例，本地密钥对签真签名）；探针在真实进程上用真签名验通「EXPIRED → 订阅失效」。**未验**：华为真实回调的字段名与枚举值，要第一封真通知对表 |
| **D8** | ~~**同一收据重复提交把服务打成 500**~~ **已修（2026-11-03）** | 改前第二次用同一 `purchaseToken` → `500 SQLITE_CONSTRAINT_UNIQUE` | `bff/src/routes/iap.js` | 收据是唯一凭据，重放改为**幂等**：先查 `subscription`/`order` 里有没有这张收据，有就不再记账，照常返回当前权益。回归见 `bff/test/iap-idempotency.test.js`（订阅与通行证各一例：两次都 200、只落一行订阅与一单） |

### D9（**读码推断，非探针实测**）端侧对「订阅到期/退款」完全无感知 —— **已修（2026-11-03）**

链路：`bff/src/routes/trip.js:105-110` 的 `quota` 只含 `source/remainingToday/giftRemaining/passes`，
**不含 subscription**；端侧 `ai/LlmClient.ets:279-288` 因此把 `subscription` 与 `dailyCap`
从本地缓存**原样结转**（该处注释已写明「BFF 返回的 remainingToday 实为 usedToday」，
说明形状差异是**已知并刻意绕过**的，不是漏写）。而 `data/EntitlementStore.ets:23` 的
`CACHE_TTL_MS = 5 分钟`由 `update()` 每次刷新（`:134-135`）——
只要用户生成间隔小于 5 分钟，缓存就不过期、`subscription.status` 就永远是旧值。
叠加 D7（`/v1/iap/notify` 空转），**到期与退款在端上没有任何生效路径**。

**修法（已落地）**：`quota` 回传 `subscription` 与 `dailyCap` 快照；端侧把合并语义收进
`EntitlementStore.mergeQuotaSnapshot()`——服务端**明确返回 null 就清掉本地订阅**、
字段缺省（旧版 BFF）才沿用旧值、`dailyCap` 也以服务端为准。
回归：`bff/test/trip-route.integration.test.js` 的「quota 回传 subscription 快照」一例
（订阅在期→回 active；改成过期后→回 null 且额度退回赠送档）、
`entry/src/ohosTest/ets/test/EntitlementMerge.test.ets` 4 例；真机 hypium **208/208**。
**未验**：端到端联调（本机 BFF + 真机）没有跑「订阅过期→端上 UI 变化」这一幕。

> 反向确认：这条差点被我登记成「端侧没接 subscription 字段」的响应形状缺陷。
> 读了 `LlmClient.ets:279-288` 才确认形状差异已被刻意处理——
> 与「否定判断先读消费方」是同一条规矩，所以这里报的是**结转导致的不失效**，不是字段缺失。

### D10 ~~（**未修，部署阻断**）~~ **已修（2026-11-03，真机真 JWKS 端到端通过）** 设备激活信任客户端自报的 unionId —— 账号可被冒用

- 证据（改前）：`bff/src/routes/device.js` 直接取 `req.body.unionId`，存在则按它建/取账号，
  随后签发设备票据并返回该账号权益；端侧 `data/DeviceActivator.ets` 把登录后的 unionId 放进请求体。
  知道他人 unionId 即可换到对方的票据与权益（订阅/通行证/额度消耗）。
- 修法（已落地）：端侧静默取 Account Kit `idToken`（`AccountStore.refreshIdToken`，不改登录态、
  不清权益缓存），激活只交 idToken；BFF 新增 `services/huaweiIdToken.js`，按官方口径本地验签
  （官方 JWKS、RS256/PS256、`iss=https://accounts.huawei.com`、`aud=HUAWEI_CLIENT_ID`、`exp`），
  **`sub` 即 unionId**；请求体 `unionId` 不再采信（只带 unionId 的请求按游客建 `anon-*`）。
  已登录却取不到 idToken 时跳过激活、不降级游客。
- 回归：`device-idtoken.test.js` 5 例（正对照两种算法、篡改/错 aud/过期/alg=none 全 401、
  自报 unionId 落 anon、非字符串 400），`bff npm test` 82/82。
- **真机端到端（Pocket 2，2026-11-03）**：本机 BFF 用 AGC Client ID `6917619826312400726` +
  **官方真实 JWKS**，设备临时指向 Mac：第一次 Account Kit `1001502005 Network error`（守卫跳过激活），
  第二次冷启 `设备激活成功 token=213字符`、BFF `activate account=1 kind=huawei`、
  库中 `union_id=AABKND_p4xEcf6kVFclUBMOcPk05U`（真实 unionId，非 anon）。验后已还原配置。
- 部署仍需：`HUAWEI_CLIENT_ID` 填 AGC 的值（`preflight` 现在会检查）。
- **未验**：idToken 自然过期后的刷新链条（本轮只覆盖「首次网络失败→下次重试成功」）。

## 3. 探针自身的两条反证（避免把「没抓到」读成「安全」）

1. **正对照**：`无票据读权益被 401 拦下` 这条必须先绿，才说明鉴权中间件确实在链上、
   D1 的「`/v1/iap` 无中间件」是路由挂载差异而不是探针打不到。
2. **修掉一处假绿**：第一版把「伪造 pass 换生成额度」放在账号 1 上跑，读出 `PASS`。
   根因是账号 1 此时已有（伪造来的）订阅，`determineQuotaSource` 优先返回 `subscription`，
   整条 `pass` 分支被盖掉。换干净账号 C 后同一断言立刻变成 **D4 DEFECT**。
   —— 与项目里「检测器报 0 前先反证它抓得到」是同一条规矩。

## 4. 上架前必须收口的顺序（建议）

**P0（§5）先解**，否则 D1-D8 都无从在真机上验。
D1 → （D2/D3/D4 随之闭合）→ D8 → D7 → D5 → D6。
D1 是唯一的「现在就能被任意客户端利用」；D5/D6 是成本敞口，不阻塞联调但阻塞定价发布。

## 5. P0 · 干净检出的主路径不可达（逐跳读消费方得出，非探针结论）——**已修，见 §8**

| 跳 | 位置 | 行为 |
| --- | --- | --- |
| 1 | `common/config/ApiConfig.ets`（**仓库版**，`git show HEAD:` 第 93/94 行） | `BFF_BASE_URL: ''` + `DEV_SKIP_BFF: false` |
| 2 | `data/DeviceActivator.ets:39-42` | URL 空 → `return false`，**设备永不激活** |
| 3 | `data/EntitlementStore.ets:117-131` | 无票据 ⇒ 缓存从没被填过 ⇒ `isCacheValid()` 假 ⇒ `canGenerate()` **恒 false** |
| 4 | `pages/GeneratingPage.ets:99-101 → 126-128` | 抛 `CLOUD_QUOTA_EXHAUSTED` ⇒ `replacePath('Pricing')` |
| 5 | `pages/PricingPage.ets` → `data/IapStore.ets` | 购买又要打同一个不存在的 BFF |

⇒ **任何干净检出 / 提审构建：点「生成行程」100% 跳付费页，且付费页也走不通。**

方案 §2 承诺的「免费 = 本机规则引擎生成（零成本）」在 release 形态下**没有出口**：
本地合成挂在 `ai/LlmClient.ets:326-328` 的 `DEV_SKIP_BFF` 之后（仓库版恒 false），
`ai/` 下也没有独立的离线规划器。要走免费档，得把本地合成从「开发旁路」升成真正的产品形态。

这条属产品决定（部署 BFF / 把本地规则引擎做成真免费档 / 两者组合），**没替用户拍**。
开发机能跑是因为本机 `common/config/ApiConfig.ets:65` 写着 `DEV_SKIP_BFF: true`（同一文件第 51 行
`BFF_BASE_URL: ''`；该文件 skip-worktree，仓库版第 93/94 行分别是 `''` 与 `false`）——
所以这个死锁在开发机上**看不见**。

## 8. §5 的 P0 已修（2026-11-03 轮 94，提交 `5d9526f`）——单变量前后对拍

用户拍板走 **B→A**。改法：生成通道判据收进 `utils/GenerationChannel.ets`，
门禁（`pages/GeneratingPage.ets`）与传输选择（`ai/LlmClient.ets`）同读一把尺——
**BFF 未配置即走端侧规则引擎（免费档、零 token 成本），只有真要打 BFF 才问额度**。
不再要求 `DEV_SKIP_BFF` 参与传输选择（旧口径下「BFF 空」必须同时配 dev 开关才走本地，
而仓库版 dev 开关恒 false ⇒ 主路径死）。

对拍做法（同一台 Pocket 2、同一份发布形态配置，只换那两个调用点）：
本机 `ApiConfig` 临时改成 `DEV_SKIP_BFF: false`（skip-worktree，不入库），
`git checkout 5d9526f^ -- GeneratingPage.ets LlmClient.ets` 装改前产物 →
一句话「北京 3天2晚 2人」→ 识别 → 直接生成行程 → **落付费页**
（帧 `~/Pictures/有径/走查帧-2026-11-03/P0改前-发布形态落付费页.jpeg`，屏上「购买行程通行证 ¥9.9」「订阅会员」「解锁完整行程」）；
还原成改后产物复跑同一条链 → **落屏8 真行程**
（帧 `…/P0改后-发布形态落屏8.jpeg`：Day 1 · 11月03日 / 故宫博物院 09:00 需预约 /
「为什么排在这里」理由件 / 地铁 22分钟·2 站 / 八达岭长城 13:15 / Day 1-3 分段栏）。
该次生成走端侧合成，**零 LLM 花费**。验完把本机 `ApiConfig` 还原成改前的 `true`、
重装与源码一致的产物。

顺带被这帧证实的两件事：
- 付费页自己的文案就写着「本机规则引擎生成 ¥0 免费体验」「生成免费，导出与无限重排需解锁」——
  即**改前的门禁连产品自己声明的免费档都不放行**，修法与产品口径同向，不是新发明。
- 付费页写「每月 20 次生成上限」，而 `quota.js` 是 `DAILY_CAP=20` 按天 ⇒ **D6 现在是用户可见的自相矛盾**，
  不再只是代码与方案文档之间的偏差。

## 9. 本轮新登记的两条

**D10 · 免费档默认产出超载日（真机帧证据，未修）**
改后那帧屏8 顶部：`今日 13.7h · 超建议 3.7h` + 负载条满格变红。
根因方向：单日收口 `PlanAutoPick.pickSpotsForSingleDay` 只在**1 天行程**上按 480min 预算收口，
多天行程按节奏档「每天 4 站」直排，而种子库的 `建议停留` 是 4h/5h —— 4 站 × 长停留必然突破
`DayLoadCalc.WINDOW_MINUTES=600`。此前这条被 dev 开关挡在开发机里、且大家主要用真 LLM 生成；
**B 落地后它变成默认体验**，优先级随之上升。修法是把单日收口的预算判据推广到每一天（同一套 `DayLoad`），
不是新增第三种算法。

**D11 · 云端其实落了行程骨架，与方案 §1 的承诺冲突（读码，非探针实测）**
`bff/src/routes/trip.js:32,43` 把整个请求体存进 `trip_request.params_json`，
而请求体 `ai/TripRequestPayload.ets` 含目的地城市、起止日期、人数、预算、**选中景点名称与片区**。
方案 §1 写的是「行程内容永不上传。云端只看到随机 UUID（`localTripId`）和时间戳」。
⇒ 上架前要么按承诺只存 `localTripId + 摘要哈希`，要么把方案与隐私政策的措辞改口，
两者都行但**不能一个说一套一个做一套**。

## 10. 探针/脚本自身的两条教训（写给下一位）

1. 断言落点的词必须**不可能出现在对照页**：第一版用 `完整行程` 当"到屏8"的判据，
   结果付费页的「解锁完整行程」也命中，改前那一跑被误判成 `行程结果=True`。
   换成 `Day 1 ·` / `去减一站` / `为什么排在这里` 之后两跑读数才互相排斥。
2. 守卫类断言要先证明它抓得到（§3 那条 pass 假绿同源）。

## 11. 同批其他观察

- 端侧→BFF 那一段仍未在真机跑过一次（本探针只证明服务端一侧；§8 证明的是端侧本地档那一侧）。
- 契约 v2 的 T4（16 页滚动门控）/ T6（间距契约名迁移）/ T9（批次收尾）在 2026-11-03 用户确认
  在飞文件可动后已解除前置，转入本仓库推进；顶栏模糊至今**没有像素证据**（`Docs/INIT_REPORT.md` 边界段已记）。

## 7. 「免费档」现形与方案不一致——这决定了 P0 该往哪解

| 侧 | 现状证据 | 含义 |
| --- | --- | --- |
| 方案 §2 | 「免费 = 0 元 = **本机规则引擎生成（零成本）** + 注册赠 3 次 LLM」 | 免费用户不应产生 token 花费 |
| 端侧 | `ai/LlmClient.ets:231` 把 `freeTier` 传成 `!EntitlementStore.hasSubscription()` | 「没订阅」=freeTier，**赠送额度的付费前用户也算 freeTier** |
| 服务端 | `bff/src/prompt/index.js:234-238` freeTier 只多叠一句「输出尽量精简」；`routes/trip.js:61` 只把 `maxTokens` 从 16384 降到 8192 | **freeTier 仍然真调 LLM**，只是少给 token —— 不是零成本 |
| 端侧本地引擎 | `ai/LlmClient.ets:5` 头注释「MockLlmTransport：离线闭环（当前默认，用户拍板）」、`:327-331` 选择传输、`:343` 走**同一个** `TripParser.parseTrip(raw, expect)` + `:345-346` 同一套地址/开放时间回填 | 本地合成**已经是一等生产者**，不是丢弃用的桩；今天只被 `DEV_SKIP_BFF` 这个开发开关挡在 release 之外 |

⇒ 两条走法的真实代价：

**A · 部署 BFF（把 §5 的死锁用服务端解掉）**
主路径立刻可达，但**方案承诺的零成本免费档没有实现**：免费用户照样烧 token。
按 `[[llm-billing-and-model-config]]` 的实测单价（1 天 ≈¥0.003、7 天高峰 ≈¥0.016）与 D6
的「20 次/**天**」口径，单个被滥用账号的月度敞口可达 600 次量级（≈¥1.8–9.6）。
另需把 Express + better-sqlite3 原型迁到方案的华为云函数/CloudDB（`DB_PATH` 硬编码、
本地文件库在云函数上不可用，见 §0 的隔离原因）。

**B · 把本地合成升成真免费档（与方案 §2 对齐）**
产品语义改动最小：免费 = 本机规则引擎（¥0），LLM 只服务付费与赠送额度。
需要动的只有**门禁与传输选择的次序**——`pages/GeneratingPage.ets:99` 现在无条件先问
`EntitlementStore.canGenerate()`，而「传输会走本地」这条路本不该被 BFF 权益拦。
补丁草案（**已应用**：用户拍板 B→A 后落地为提交 `5d9526f`，判据收在 `utils/GenerationChannel.ets`，
门禁与传输选择同读它；真机单变量前后对拍见 INIT_REPORT §5ci 续 86）：
代价与前提：免费档拿不到 LLM 的质量（`TripParser` 之外还有 `PlanAutoPick` 的名额/单日收口口径要复用过），
且导出墙 `canExport()` 仍必须有真权益来源 ⇒ **B 解掉「能不能生成」，不解掉「能不能付费」**；
D1/D5/D7 属 BFF 侧，走 B 也得修。
两条不互斥：**B 让产品今天就能用，A 让付费与质量控制成立**，建议按 B→A 顺序推。

## 12. 本轮收口后的状态（2026-11-03 终盘，供决策）

### 已验证（有可复跑的证据）

| 项 | 证据 | 复跑方式 |
| --- | --- | --- |
| 免费档主路径可达（发布形态） | 单变量前后对拍：改前落付费页、改后落屏8 真行程 | `git checkout 5d9526f^` 后按 §8 步骤 |
| 生成的每天都在负载窗口内 | 真机三天 8.0/8.4/8.4h；hypium `offline_preselected_plan_fits_window` | `aa test … OpenHarmonyTestRunner` |
| 预选数量 = 实排数量（无静默丢弃） | 日志 `预选10站 → spots=10`、无「排不下」行 | 屏2 一句话「北京 3天2晚 2人」 |
| 通勤按真实距离 | 屏8「打车 40分钟 · 约 13.4km」「步行 9分钟 · 约 0.6km」 | 同上 |
| 地图城市不再说「无需预约」 | `map_city_never_claims_no_booking_needed`（西安/北京对照） | hypium |
| 收据重放幂等 / 上限按月 | `bff/test/{iap-idempotency,quota-window}.test.js` | `cd bff && npm test`（46 例） |
| 扣费与幂等记账 | 探针 15/15 必守行为 | `bash tools/probe_bff_commercial.sh` |
| 顶栏磨砂（4 页） | 栏带 Δ≈−9.5，人眼看过帧 | `/tmp/blur_pages.py`（重启即丢，需重建） |
| 深色卡面有边界 | 卡面 L=30 / 画布 18；对比度 57 节点 0 低 | `bash tools/audit_contrast.py <dump> <jpeg>` |
| 间距档更名为契约名 | A/B 同屏 61 节点坐标全同、像素差均值 0.000 | 需要重做 A/B（脚本未入库） |
| **端侧→BFF 真机往返** | 激活 `token=213字符`、rich 载荷、生成成功、扣额度 | 本机 LAN BFF + 桩上游（INIT_REPORT §5ci 续 103） |
| **401 / 402 / 5xx 三条错误路径** | 401 清票据恢复、每次冷启刷新权益（`gift=2/1/0`）、用尽 `code=6002` 落付费页、5xx → `code=1003` 屏7「连不上行程服务」 | 同上，续 104/105 |
| **行程主键不与既有行程撞车** | 连续两次生成 id 不同、拉库两条都在 | hypium + 真机（续 103） |
| **BFF 上线自检** | `npm run preflight`：通过8/警告0/阻断3 | `cd bff && npm run preflight` |

### 卡在你这边（我做了会验不了 / 属你的决定）

1. **BFF 部署**（A 走法）：不部署，付费与"AI 质量"整条不成立；部署后才有真实端到端。
   现在只剩两道闸：`npm run preflight` 的两条支付阻断。
2. **只剩 D5 一条支付守卫缺陷（产品口径）**：换设备白拿 3 次赠送。
   修它要定「游客给不给赠送、以什么为键」——这是定价/风控决定，不是工程缺陷。
   D1/D2/D3/D4 已由 fail-closed 收据校验关闭（伪造一律拒绝、真收据正对照通过），
   D6（按月上限）、D8（收据幂等）、D7（通知验签与到期/退款落权益）、D9（quota 回传订阅快照）
   均已修。**部署前只剩两项配置**：`IAP_VERIFY_URL`/`IAP_APP_ID`/`IAP_VERIFY_TOKEN`
   与 `IAP_NOTIFY_PUBLIC_KEY`；收据校验的请求体是与校验服务之间的契约，接华为官方 API 时要对表。
3. **单日行程要不要为少坐车放弃最热的那一站**：离线断言已钉住"热度优先"，改它是产品取舍。
4. **费用/分享/勋章/我的四页要不要也做成沉浸式**（内容从顶栏下过）：现状栏带逐像素不变，
   磨砂在那四页看不见；改会动页头与首屏观感。
5. **401 之后要不要"同会话内自动重试"**：现在清票据后退到付费页、靠下次冷启恢复；
   要免重启得在失败分支接 `reactivate` 重试，属行为增强。

### 仍未验（别当已覆盖）

- 深色档：`EditItinerary`（要 `{tripId,dayIndex}` 对象）与 `Review`（要已结束+有打卡）两屏**没有画面**。
- 顶栏磨砂：上述四页之外，`SpotPick/StayPick/Pricing/EditItinerary/OnTrip/Badges` 等未逐页复测
  （机制在两页已证通，含跨组件那条最难的路径）。
- ~~app↔BFF 的真机往返：一次都没跑过~~ **2026-11-03 已跑通**（激活/rich 载荷/生成/扣额度/401/402/5xx 全链路，
  见 INIT_REPORT §5ci 续 103–105）；未验的是**真实 DeepSeek 上游**（联调一直用桩，为的是零花费）。
- v9→v10 迁移：终态已核（设备库 `user_version=10`、打卡六列齐、孤儿 0），
  但**升级过程没有观测**（没在迁移前抓一次版本号）。

## 13. 收尾验收快照（2026-11-03 末，最后一次审计 15:13）

| 闸门 | 读数 |
| --- | --- |
| 静态尺 | **16 把全部 rc=0**（colors/type/geometry/material/fontfamily/tnum/elevation/button_width/scroll_actions/label_fit/a11y_name/layout_patterns/skip_worktree/motion/bar_scroll/**seed**） |
| 离线断言 | **6 套全 PASS**（mirror / map_city / replan / trip_intent / trip_review / weather）；真机 dock 六项脚本另跑（含 hypium） |
| 真机 hypium | **237 / 237**（双 HAP 全新构建后安装；含会员卡/限流/编辑 id 等新用例） |
| BFF 单测 | **96 / 96**（含 SOT hash/20 条规则、收据幂等/绑定/并发、通知验签、idToken 验签、坏 JSON 修正、超时与账号限流） |
| 商业化探针 | **必守 23 / 23**、支付守卫缺陷 **1 条**（只剩 D5 换设备白拿；D1–D4、D6–D9 已关） |
| 上线自检 | **通过 8 / 警告 0 / 阻断 3**（IAP 校验服务未配置 + `IAP_NOTIFY_PUBLIC_KEY` 未配置 + `HUAWEI_CLIENT_ID` 未配置；填齐后期望 通过 11 / 阻断 0） |
| 真实模型 | 本会话 9 次真实调用（1/3/7 天、付费/免费档、MapKit 形态），合计约 **¥0.05**；规则 19 不稳定（505/570min 样本），长行程坏 JSON 已有修正重问 |

**一条容易踩的坑（本轮实证）**：`ai/PromptBuilder.ets` 是**提示词 SOT，但 App 运行时并不引用它**
（只有注释提到）。所以——
- 改提示词后**必须** `cd bff && npm run sync:prompt`，否则 BFF 用的是旧生成物；
- **"App 编译过"不代表提示词生效**。反过来，用 `strings modules.abc | grep <中文串>` 也验不了提示词
  （中文串不在 abc 的明文里；用一条已知老规则做对照同样是 0）。要验就直接「HTTP 打 BFF + 看真模型输出」。

## 14. 下一步：按你拍板的顺序（每步都有可执行命令）

### ① 若决定「部署 BFF」（P0 的最后一道门）
```bash
cd bff
# 1) 代码侧已收口：收据校验 fail-closed、notify 验签与到期/退款、quota 回传订阅快照、
#    设备激活 idToken 验签都已落地。部署前只剩三项配置：
#      IAP_VERIFY_URL + IAP_APP_ID + IAP_VERIFY_TOKEN
#      IAP_NOTIFY_PUBLIC_KEY
#      HUAWEI_CLIENT_ID（= AGC 的 Client ID，6917619826312400726）
# 2) 配生产环境：JWT_SECRET / DEEPSEEK_API_KEY / DB_PATH（挂载卷）/ PORT
npm run preflight        # 期望 通过11 / 阻断0（三项配置齐全后）
npm test                 # 91/91
npm start
# 3) 端侧：把 BFF_BASE_URL 填成正式地址（该文件是 skip-worktree，只改本机）
#    → 重编重装 → 断言三件事：设备激活 token、一次真实生成、额度扣减
```
端侧回归脚本：`bash tools/probe_bff_commercial.sh`（必守 23/23；D5 未拍板前进程退出码仍为 1，红是真话）。

### ② 若决定「先让付费档与免费档同源」（产品口径）
- `DayLoad` 只算活动+通勤、不算活动空档 ⇒ 徽章可能与"一天多长"不一致（§5ci 续 111 有实测：活动 335min、实际在场 11.5h）。
  **文案侧已改口**（续 113：屏8 现在写「活动 Xh · 建议 ≤10h」，不再说「今日」）；
  剩余决定是**判据**要不要改成按真实在场时长（会动所有既有行程读数）。
- 单日"热度优先 vs 少坐车"：离线断言 `TripIntent.test` 已钉住热度优先，改它会连带改 4 条断言。

### ③ 若决定「四页也做沉浸式」（费用/分享/勋章/我的）
现状：栏带逐像素不变（内容不过栏）。改会动页头与首屏观感，需逐屏复拍。

### ④ 与本次会话无关但仍在账上的
- AGC：实况窗/通知/地理围栏（见项目记忆）。
- 发布物料：签名、隐私政策法务复核（`LegalDocs.ets` 文件头写明须复核）。

## 2026-11-04 增补：IAP 对表官方——JWS 本地验签替代校验服务契约

本文档正文写的 `IAP_VERIFY_URL`/`IAP_VERIFY_TOKEN`/`IAP_NOTIFY_PUBLIC_KEY` 契约**已作废**。
按华为官方文档（2026-09 版）对表后改为本地 JWS 验签，理由：
- 官方 order/lookup 按交易号查询、需 AGC 密钥私钥现签 JWT（ES256+kid，约 1h 失效），
  **且不支持沙盒订单**——真机沙盒验收根本走不通；
- HarmonyOS NEXT 的购买数据本身就是 JWS，官方权益发放指南明确建议
  「客户端将 purchaseData 发送至应用服务器，在应用服务器执行解码验签」。

**新契约**（`bff/src/services/iapJws.js`，官方「对返回结果验签」）：
- JWS 三段式，`alg=ES256` 固定、`x5c` 证书链（叶子→中间→根）；
- 信任锚 = Huawei CBG Root CA G2（`bff/certs/RootCaG2Ecdsa.cer`，官方 pki 地址下载）；
- 叶子证书必须含 OID `1.3.6.1.4.1.2011.2.415.1.1`；ES256 验签用叶子公钥；
- 业务校验：applicationId=IAP_APP_ID、productId/productType 与请求一致（防低买高报）、
  订单未被撤销、订阅 status='1'；入库幂等键只用 JWS 权威 purchaseToken。
- 通知（D7）：官方 v3 通知体是 `{ jwsNotification }`，同一套验签；幂等键
  `notificationRequestId`；classify 六类（renew/expire/refund/renew_status/renew_time/test）。
- 旧 `IAP_NOTIFY_PUBLIC_KEY`（Authorization RSA 头）与「静态 Bearer + {verified:true}」契约全部下线。

**端侧**（`IapStore.ets`）：createPurchase 后用 purchaseToken 去 queryPurchases(UNFINISHED)
找对应 JWS，把 `jwsPurchaseOrder`/`jwsSubscriptionStatus` 原文上报 BFF；校验成功才
finishPurchase；restore 从 CURRENT_ENTITLEMENT 逐条解 JWS 取 developerPayload（localTripId）。

**闸门复跑（2026-11-04）**：BFF npm test **102/102**（新增 JWS 正对照/坏签名/无 OID/
根不匹配/跨应用/撤销/非生效中等拦截）；preflight **通过 12 / 警告 0 / 阻断 0**；
商业探针必守 **24/24**（支付守卫缺陷仍只剩 D5）；hvigor assembleHap 绿；
契约尺 16 把 + 离线断言 6 套全绿（顺手修掉 3 个脚本 bash 3.2 对「$VAR+全角字符」的解析隐患）。

## 2026-11-04 二轮承接：对上面这批改动的复核与三处收口

复核结论：**方向对、可以留**。信任锚是真货（`bff/certs/RootCaG2Ecdsa.cer` 的 subject
`CN=Huawei CBG Root CA G2`、有效期 2020-03-16~2049-03-16，与官方公开根证书一致；
测试链 `iap-test-root.cer` 的公钥指纹与它不同，不存在"测试根混进生产信任"）；
入库幂等键改取 JWS 权威 `purchaseToken`，客户端裸传的 92 位令牌不再算凭据——这是比
前一版（远端校验桩契约）更贴近官方的收口。以下是我复跑后补的三处，均已带测试/正负对照：

**① 非生产收据默认拒收（钱袋子）**
Trae 版对 `environment=SANDBOX` 一律放行（注释写明"真机验收走沙盒"）。沙盒单不花钱，
生产开着这道等于**任何人拿沙盒收据都能换到真订阅**。现改为：默认只认 `Production`
（缺 `environment` 也按非处理，fail-closed 方向是拒真），真机沙盒验收要显式
`IAP_ALLOW_SANDBOX=1`；preflight 在放行态出**警告**，开着它就不算可以对外。
测试：三张非生产/缺字段 JWS 全拒且不落账 + 开关闭环正对照（同一张沙盒 JWS 放行后必须过）。
fixtures 默认形态随之改成 `Production`。

**② 测试链私钥不入库，但干净检出仍能跑测**
`bff/test/fixtures/*.key`（测试 CA 私钥）与 `*.srl` 原本既没入库也没被忽略——按 pathspec
提交会漏掉它们，别人干净检出后 `npm test` 直接挂在读文件。现在 `.gitignore` 明确排除私钥
与流水，新增 `gen-test-certs.sh`（openssl 现生成同构三级链，叶子带 OID
`1.3.6.1.4.1.2011.2.415.1.1`），`jws.js` 在缺材料时自动调用它。
并行锁是必要的：`node --test` 多进程同时发现缺材料会交错落盘（根来自 A、叶子来自 B），
`verifyJws` 就随机报 BAD_CHAIN。实测删光材料后 `npm test` **103/103** 全绿，
脚本自己打印"1 次生成 + 2 次跳过"。公开的 `.cer` 仍随仓库走（白名单只放 `certs/` 与
`test/fixtures/` 两个目录的证书，不放任何私钥）。

**③ 新尺：无守卫自递归（这把尺欠的那条命）**
`4116bf4`（上一轮我自己提交的"会员卡随权益变更即时刷新"）把 `MinePage.refreshMembership()`
的方法体写成了 `this.refreshMembership();`——**编译通过、hypium 237 例全绿、16 把尺全绿，
真机上一进「我的」就栈溢出**。它不是类型错误也不是契约违规，静态判据只能靠结构：
方法体只有一条语句、没有任何分支、却在调用自己。
`tools/audit_self_call.py` 就按这条判据扫（有守卫的递归/委托到同名他类方法都不报），
`--selftest` 阳性 4 阴性 6 全过；拿 HEAD 里那份 `MinePage.ets` 当阳性样本命中
`:91 refreshMembership()`，当前树 0 命中。这把尺的教训记账：**绿闸门证明不了界面起得来**，
承接别人的改动必须真跑一次目标页面，见 README「静态尺」表第 17 把。

**闸门复跑（本轮收口后）**：BFF npm test **103/103**；preflight **通过 14 / 警告 0 / 阻断 0**；
商业探针必守 **24/24**（缺陷仍只剩 D5）；静态尺 **17 把**全绿；端侧改动已由
`loader_out/.../modules.abc`（构建时间晚于改动）内含 `findOrderJws`/`decodeJwsPayload`/
`isSandboxActivated`/`toggleSelectAll` 等符号证实编译进产物。
`environment` 枚举的真实大小写仍未与真机收据对表，故比较做成大小写不敏感。

**仍未验**（部署/真机轮次）：
1. 真机沙盒端到端：购买→UNFINISHED 拿 JWS→BFF 验签→finishPurchase 的完整链路
   （现在还要额外在 `bff/.env` 里临时开 `IAP_ALLOW_SANDBOX=1`）；
   官方 SDK 注释另有一条坑：**沙盒环境下已发货的非消耗型商品不会被 `queryPurchases` 返回**，
   沙盒恢复通行证这条路可能天然走不通，真机要单独验；
2. 第一封真实 v3 通知（AGC 配好通知地址后）字段对表——classify 词表可能要微调；
3. AGC 侧：开通支付服务、配沙盒商品（youjing_pass/youjing_sub_monthly/youjing_sub_yearly）、

   配置通知接收地址（HTTPS+商用证书，v3）。
