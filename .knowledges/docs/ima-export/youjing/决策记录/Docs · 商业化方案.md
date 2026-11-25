---
title: "Docs · 商业化方案.md"
id: markdown_cls1_798285c88467638f6a8dc28635ad6f33_b2085a465385fe2ef276aa01b1ec19457526104239726721
kb: 有径-YouJing
folder: "决策记录"
media_type: 7
tags: []
source: ima
exported_at: 2026-11-23T15:09:07.300Z
---
# 商业化方案与 BFF 契约

> 定稿日期：2026-11-01
> 状态：已确认，进入实施

## 1. 架构边界

| 面 | 内容 | 位置 |
|---|---|---|
| 控制面（云） | 账号、订阅权益、额度、计费、LLM Key 代理、模型路由、POI 快照、埋点 | BFF（华为云函数 / CloudDB） |
| 数据面（端） | 行程、打卡、账本、勋章 | 设备 RDB（不上传） |

行程内容永不上传。云端只看到随机 UUID（`localTripId`）和时间戳。

## 2. 定价结构

| 档位 | 价格 | 权益 | 面向 |
|---|---|---|---|
| 免费 | 0 | 本机规则引擎生成（零成本）+ 注册赠 3 次 LLM（终身不重置） | 全部新用户 |
| 行程通行证 | 9.9 元 / 单个行程 | 该行程无限生成与重排 + 导出（ICS/PDF/海报）+ 优先队列 | 低频旅行者 |
| 订阅 | 19.9 元/月 · 98 元/年 | 20 次/月上限 + 全部高级能力 + 历史无限保存 | 高频/商务出行 |

- 扣减顺序：订阅日额度 → 赠送次数（次数包放第二版）
- 20 次/月是防滥用上限，不是卖点
- 付费墙位置：生成与查看免费，导出收费
- 次数包放第二版

## 3. 云端数据表 DDL

```sql
CREATE TABLE account (
  id BIGINT PRIMARY KEY AUTO_INCREMENT,
  union_id VARCHAR(64) UNIQUE NOT NULL,
  device_id VARCHAR(64),
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  last_seen_at DATETIME,
  risk_flags INT NOT NULL DEFAULT 0
);

CREATE TABLE subscription (
  id BIGINT PRIMARY KEY AUTO_INCREMENT,
  account_id BIGINT NOT NULL,
  product_id VARCHAR(32) NOT NULL,  -- monthly / yearly
  status VARCHAR(16) NOT NULL,      -- active / grace / expired / revoked
  period_start DATETIME NOT NULL,
  period_end DATETIME NOT NULL,
  auto_renew BOOLEAN NOT NULL DEFAULT TRUE,
  purchase_token VARCHAR(255) UNIQUE NOT NULL,
  updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  INDEX idx_sub_account (account_id)
);

CREATE TABLE trip_pass (
  id BIGINT PRIMARY KEY AUTO_INCREMENT,
  account_id BIGINT NOT NULL,
  local_trip_id VARCHAR(64) NOT NULL,  -- 端上 UUID，不含行程内容
  status VARCHAR(16) NOT NULL,         -- active / expired / refunded
  expires_at DATETIME,                 -- NULL = 永不过期
  order_id BIGINT,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  UNIQUE KEY uk_pass (account_id, local_trip_id),
  INDEX idx_pass_account (account_id)
);

CREATE TABLE quota_ledger (
  id BIGINT PRIMARY KEY AUTO_INCREMENT,
  account_id BIGINT NOT NULL,
  delta INT NOT NULL,                 -- +N / -1
  source VARCHAR(16) NOT NULL,        -- gift / subscription / pass / refund / admin
  ref_type VARCHAR(16),               -- order / pass / trip_request
  ref_id BIGINT,
  state VARCHAR(16) NOT NULL,         -- reserved / committed / released
  idempotency_key VARCHAR(64) UNIQUE NOT NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  settled_at DATETIME,
  INDEX idx_ledger_account (account_id)
);

CREATE TABLE trip_request (
  id BIGINT PRIMARY KEY AUTO_INCREMENT,
  account_id BIGINT NOT NULL,
  idempotency_key VARCHAR(64) UNIQUE NOT NULL,
  params_json TEXT,                   -- 仅存生成参数（目的地/天数等），不存行程内容
  status VARCHAR(16) NOT NULL,        -- pending / succeeded / failed
  prompt_tokens INT,
  completion_tokens INT,
  model VARCHAR(64),
  cost_micros BIGINT,
  started_at DATETIME NOT NULL,
  finished_at DATETIME,
  error_code INT,
  INDEX idx_req_account (account_id)
);

CREATE TABLE `order` (
  id BIGINT PRIMARY KEY AUTO_INCREMENT,
  account_id BIGINT NOT NULL,
  product_type VARCHAR(16) NOT NULL,  -- subscription / pass
  product_id VARCHAR(32) NOT NULL,
  amount_cents INT NOT NULL,
  currency VARCHAR(8) NOT NULL DEFAULT 'CNY',
  huawei_order_id VARCHAR(128) UNIQUE,
  purchase_token VARCHAR(255),
  status VARCHAR(16) NOT NULL,        -- pending / paid / refunded / revoked
  paid_at DATETIME,
  refunded_at DATETIME,
  INDEX idx_order_account (account_id)
);
```

## 4. 接口契约

### 4.1 POST /v1/auth/login

华为 `authCode` → `unionId`，把匿名赠送次数迁移到账号。

```
请求: { authCode: string, deviceId: string }
响应: {
  unionId: string,
  entitlement: {
    subscription: { status: string, periodEnd: string } | null,
    giftRemaining: number,
    usedToday: number,
    dailyCap: number
  }
}
```

### 4.2 GET /v1/entitlement

```
请求头: Authorization: Bearer <deviceToken>
响应: {
  subscription: { status: string, periodEnd: string } | null,
  passes: [{ localTripId: string, status: string, expiresAt: string | null }],
  giftRemaining: number,
  usedToday: number,
  dailyCap: number
}
```

### 4.3 POST /v1/trip/generate

```
请求头:
  Authorization: Bearer <deviceToken>
  Idempotency-Key: <uuid>
请求: {
  destination: string, startDate: string, endDate: string,
  people: number, budget: number, style: string,
  selectedSpots: string[], selectedArea: string,
  passId: string | null,  // 行程通行证绑定的 localTripId
  freeTier: boolean       // true = 用更短 Prompt 压低成本
}
响应 200: {
  trip: { ... },  // 完整 Trip JSON（与现有 TripParser 输出同构）
  quota: {
    source: string,        // subscription / gift / pass
    remainingToday: number,
    giftRemaining: number,
    passes: [{ localTripId: string, remaining: number }]
  }
}
响应 402: { error: "QUOTA_EXHAUSTED", message: string }
响应 401: { error: "TOKEN_INVALID", message: string }
响应 429: { error: "RATE_LIMITED", message: string, retryAfterMs: number }
```

### 4.4 POST /v1/iap/verify

```
请求: { purchaseToken: string, productType: string, localTripId: string | null }
响应: {
  verified: boolean,
  entitlement: { ... },  // 同 /v1/entitlement
  passId: string | null  // 通行证购买时返回
}
```

### 4.5 POST /v1/iap/notify

华为服务端续订/退款/撤单 webhook。**必须验签**。

```
请求: 华为 IAP 通知原始体
响应: 200 OK（空）
```

## 5. 错误码表（云端区段 6xxx）

| 码值 | 名称 | 含义 | 端侧处理 |
|---|---|---|---|
| 6001 | TOKEN_INVALID | 票据失效或未激活 | 重新调 /v1/device/activate |
| 6002 | QUOTA_EXHAUSTED | 额度用尽 | 跳 PricingPage |
| 6003 | RATE_LIMITED | 频率超限 | 提示稍后重试，不跳页 |
| 6004 | IDEMPOTENCY_CONFLICT | 幂等键冲突 | 直接用上次结果（不应重试） |
| 6005 | PASS_NOT_FOUND | 通行证不存在或不属于该账号 | 跳 PricingPage |
| 6006 | IAP_VERIFY_FAILED | IAP 校验失败 | 提示联系客服 |

## 6. 端侧改造清单

| 文件 | 改动 | 优先级 |
|---|---|---|
| `data/DatabaseHelper.ets` | 修 executeSql await + 重复列 + 加 v10（trip.pass_id） | P0 |
| `pages/Index.ets` | 同意前不构建 mainTabs、不调 AccountStore.init/DAO | P0 |
| `common/config/ApiConfig.ets` | 删明文 Key，改 BFF_BASE_URL + 票据字段 | P1 |
| `ai/LlmClient.ets` | 加鉴权头 + Idempotency-Key + 401/402/429 区分 | P1 |
| `common/error/ErrorCode.ets` | 新增 6xxx 云端错误码 | P1 |
| `data/EntitlementStore.ets` | 新建：权益缓存 + 导出校验 | P1 |
| `pages/PricingPage.ets` | 新建：付费引导页 | P2 |
| `pages/GeneratingPage.ets` | 接 402 分支跳 PricingPage | P2 |

## 7. 落地顺序

1. **P0**：修 DatabaseHelper 迁移链 + Index 隐私闸门（不依赖后端）
2. **P1**：改 ApiConfig + LlmClient + ErrorCode + EntitlementStore（后端就绪后接线）
3. **P2**：PricingPage + GeneratingPage 402 分支（UI 层最后接）

## 8. 关键设计约束

- 幂等：同一 Idempotency-Key 重试不重复扣费；401/402 不重试，429/5xx 可重试
- 预扣 → 结算 → 回滚：生成成功 committed（扣），上游失败 released（不扣），客户端取消且请求已发出 committed（扣）
- 免费档绑定华为账号，设备+账号双维度去重
- 免费请求用更短 Prompt（max_tokens 8192）压低成本
- 导出（ICS/PDF/海报）是付费墙：无权益时弹 PricingPage
