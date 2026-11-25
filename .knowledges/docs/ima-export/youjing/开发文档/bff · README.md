---
title: "bff · README.md"
id: markdown_cls1_798285c88467638f6a8dc28635ad6f33_af3e4b16d20d9369b42ec8c0feecf1bd7526104239726721
kb: 有径-YouJing
folder: "开发文档"
media_type: 7
tags: []
source: ima
exported_at: 2026-11-23T14:52:37.917Z
---
# 有径 BFF

设备激活、权益/配额、LLM 代理、IAP 校验。当前是开发期 BFF 原型（Express + SQLite）。

## Prompt / Schema 同源

单一事实源（SOT）在端侧，不在 BFF 手写第二份：

```
entry/src/main/ets/ai/PromptBuilder.ets   # 17 条系统规则 + userPrompt
entry/src/main/ets/ai/TripSchema.ets      # JSON Schema + 枚举
entry/src/main/ets/utils/DateUtils.ets    # 天数/日期口径
entry/src/main/ets/model/{PlanParams,Spot,Area}.ets  # 仅类型，供 tsc 解析
```

同步方式：

```bash
cd bff
npm run sync:prompt
```

脚本用 tsc 把上述 `.ets` 转成 CommonJS，写到 `src/prompt/generated/`，并生成
`manifest.json`（源文件与生成物的 sha256）。BFF 运行期只加载生成物；
`npm test` 会校验 hash，entry/ 侧 SOT 改了但没重跑同步时测试会直接失败。

> 不要手改 `src/prompt/generated/` 下的文件。要改提示词或 Schema，必须先改 entry/
> 侧 SOT，再 `npm run sync:prompt`。

## 用户消息的两种形态

- **rich**：请求带 `spots[]`（含 `suggestedDuration/longitude/latitude/booking` 等）与
  `area`（含 `priceTier/metroLines/anchorStations/airportMinutes/trainStationMinutes`）时，
  BFF 直接调用 ets `PromptBuilder.userPrompt`，与端侧同一份代码。
- **sparse**：旧客户端、或 rich 关键字段缺失时的回退。BFF 不伪造
  停留时长/坐标/预约/开放时间，用户消息里明确写出缺口，只让模型排名称与顺序。

当前端侧 `HttpLlmTransport` 已通过 `entry/src/main/ets/ai/TripRequestPayload.ets`
发 rich payload；sparse 分支只用于旧客户端/缺字段回退。

端侧改 `TripRequestPayload.ets` / `Spot.ets` / `Area.ets` 的字段后：

```bash
cd bff
npm test
```

`test/entry-payload-contract.test.js` 会逐字段比对端侧接口与 BFF rich 分支；
缺字段直接红。若同时改了 `PromptBuilder.ets` / `TripSchema.ets`，先
`npm run sync:prompt` 再跑测试。

## 结构化输出

默认：

```js
response_format: {
  type: 'json_schema',
  json_schema: { name: 'trip', strict: true, schema: <TripSchema.TRIP_JSON_SCHEMA> }
}
```

上游不支持 `json_schema` 时，显式降级：

```bash
LLM_RESPONSE_FORMAT=json_object
```

**实测判据（2026-11-03，DeepSeek 官方 `deepseek-chat`）**：`json_schema` 返回 HTTP 400，
错误文案为 `This response_format type is unavailable now`；改 `json_object` 后同一请求
HTTP 200，提示词里仍内嵌完整 Schema，BFF 仍用同一份 Schema 校验。看到 400/422 且文案
含 `response_format ... unavailable` 就应降级，不要把降级当成通过。

提示词里仍内嵌完整 Schema；BFF 收到响应后还会用同一份 Schema 做服务端校验
（`src/prompt/trip-validator.js`），不合法直接 502，不落库、不扣额度。
校验还兜底「每天至少 lunch + dinner 各一条」；缺任一条直接 502。

上游 HTTP 4xx/5xx 统一映射为 **502 `LLM_UPSTREAM_ERROR`**，客户端不会再看到误导性的 500。

## 幂等语义

有效身份 = `scopeKey(accountId, Idempotency-Key)` + `requestHash(规范化请求体)`：

| 情况 | 状态码 | 行为 |
|---|---|---|
| 首次请求 | 200 | 正常生成；成功响应体原样写入 `trip_request.response_json` |
| 同键 + 同体 + 已成功 | 200 | 原样重放首次响应体，带 `Idempotency-Replayed: true` 头 |
| 同键 + 不同体 | 422 `IDEMPOTENCY_KEY_REUSED` | 不重放、不覆盖旧行 |
| 同键 + 同体 + 进行中 | 409 `IDEMPOTENCY_IN_PROGRESS` | 提示稍后重试 |
| 同键 + 同体 + 上次失败 | 200/502 | 复用同一行重跑；配额已释放，会重新预占 |
| 已成功但 `response_json` 缺失/损坏 | 500 `IDEMPOTENCY_STATE_CORRUPT` | 拒绝拿请求参数冒充 Trip |

请求体规范化：对象键排序、数组保序、忽略 `undefined` 键；账号/设备标识参与作用域，
避免跨用户撞键。

并发认领：路由用 `ON CONFLICT ... DO UPDATE ... WHERE status='failed'` 把行抢占为
`pending`；同一 key 并发时只有第一个请求 `changes=1`，其余直接 409，不会各自调 LLM
造成双扣费/双写。

## 测试

```bash
cd bff
npm test
```

`node:test`，不依赖 express / better-sqlite3 / 网络：

- `test/prompt.test.js`：17 条规则、Schema 内嵌、rich/sparse 拼装、response_format、SOT hash
- `test/trip-validator.test.js`：合法/非法 Trip（必填、枚举、类型、空数组、天数、日期倒挂、时刻顺序、午晚各一）
- `test/idempotency.test.js`：重放、同键不同体、进行中、失败重跑、损坏响应、规范化 hash
- `test/entry-payload-contract.test.js`：端侧 `TripGeneratePayload` / `Spot` / `Area` / `SelectedSpot`
  与 BFF rich 分支逐字段比对
- `test/trip-route.integration.test.js`：真实 Express + SQLite 路由（UPSERT、配额快照、重放、
  同键不同体 422、并发 409、上游 4xx 502、校验失败 502 不扣额）

## 上线前自检与部署清单

```bash
cd bff && npm run preflight
```

把「部署到公网之前必须成立的事」做成可执行闸门。**当前退出码是 1 —— 这不是闸门坏了，
是两条阻断项还没修**；修完自然转绿，不要为了让它变绿去改它。

| 检查 | 现在 | 意味着什么 |
| --- | --- | --- |
| JWT_SECRET 非缺省/非示例 | PASS | 缺省时 `middleware/auth.js` 会退回硬编码开发密钥，任何人都能自签设备票据 |
| DEEPSEEK_API_KEY 已配 | PASS | 否则 LLM 代理直接 500 |
| IAP 校验非恒真 | PASS | 未配置校验服务时一律 fail-closed 503；配置后只认远端 `verified:true`，超时/5xx/网络错都按未通过 |
| IAP 校验服务已配置 | **FAIL** | 缺 `IAP_VERIFY_URL`/`IAP_APP_ID`/`IAP_VERIFY_TOKEN` ⇒ 所有收据 503 |
| `/v1/iap/verify` 要设备票据、`/v1/iap/notify` 验签 | PASS | notify 走 RSA-SHA256 验签；未配公钥时 fail-closed 503 |
| `IAP_NOTIFY_PUBLIC_KEY` 已配置 | **FAIL** | 未配置时华为回调一律 503 ⇒ 到期/退款不生效 |
| 设备激活验华为 idToken（D10） | PASS | 按官方 JWKS 本地验签（RS256/PS256、iss/aud/exp），unionId 只取验签后的 `sub`；请求体 unionId 不再采信 |
| `HUAWEI_CLIENT_ID` 已配置 | **FAIL** | 缺它无法校验 idToken 的 aud ⇒ 带身份的激活一律 401 |
| DB 路径可配置 | PASS | 支持 `DB_PATH` 环境变量（容器/云函数把库放到挂载卷上）；目录不存在会自动建 |
| Prompt/Schema 生成物在位 | PASS | hash 一致性由 `npm test` 校验 |

自检覆盖不到、部署时必须人工确认的三件事：**TLS 终止**、**IP 级限流**（账号级已内置，10 次/分钟/进程）、
**日志脱敏**（不要把 `Authorization` 和请求体原样落盘——请求体里有行程参数）。

## 已知边界

- DeepSeek 官方 `deepseek-chat` 当前不支持 `json_schema`，本地 `.env` 用
  `LLM_RESPONSE_FORMAT=json_object`；换到支持 `json_schema` 的模型/端点时可切回。
- 端侧已发 rich；`Spot`/`Area` 的 optional 字段缺失时 JSON 会省略，BFF 的 prompt 对应位置
  会如实显示「未获取/以官方为准」，不会补 0 或伪造。
- BFF 的收据校验已接远端服务但**从未配过真实凭证**（未配置时 fail-closed 503）；
  正式 JWT 密钥也还没换。2026-11-03 又收了四批：订阅上限改为**按月**（与商业化方案 §2 及付费页文案一致）、
  收据重放改为**幂等**（不再把 UNIQUE 约束抛成 500）、notify 改为**验签 + 到期/退款真落权益**
  （`iapNotify.js`）、`quota` 回传 `subscription`/`dailyCap` 快照（端上据此感知到期/退款）。
  仍未配的见上面「上线前自检」表。
- 当前验证：`npm test` **96/96** 全绿（含通知验签 9 例、收据 fail-closed 5 例、收据↔账号绑定 2 例、收据并发 2 例、收据边界 1 例、激活边界 3 例、idToken 验签 8 例、并发激活 2 例、生成请求边界 1 例、坏 JSON 修正 2 例、上游超时 1 例、账号限流 2 例、上游 429 透传、三档提示词档位、JSON 兜底 6 例），主 HAP + ohosTest HAP 编译通过；
  真实网络已做过 `json_schema`（400）/`json_object`（200）与真模型生成验收；
  端侧→BFF 已在真机上跑通（激活/扣额度/401/402/5xx），但**BFF 尚未部署到公网**。
- 2026-11-03 的真实 200 响应第 3 天缺晚餐；本规则加上后同类输出会被 502，需要重试。
  未再烧真实调用复验，后续真机/联网验收时应确认模型能补齐晚餐。
