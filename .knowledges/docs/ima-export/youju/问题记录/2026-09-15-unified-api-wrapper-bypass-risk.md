---
title: "2026-09-15-unified-api-wrapper-bypass-risk.md"
id: markdown_798285c88467638f6a8dc28635ad6f33_9b84f331fab7f7860ffbf01a9f0e7e8c7505655250320770
kb: 有据-YouJu
folder: "问题记录"
media_type: 7
tags: []
source: ima
exported_at: 2026-11-23T14:52:37.917Z
---
---
id: 2026-09-15-unified-api-wrapper-bypass-risk
title: 绕过统一网络请求封装的旁路调用会丢失全局错误处理和认证拦截
category: architecture
nature: pitfall
created_at: 2026-09-15T23:54:39
updated_at: 2026-09-15T23:54:39
tags: [API封装, 错误处理, 401拦截, 旁路调用, 网络请求]
keywords: [request, uploadChatMedia, http.createHttp, 401, markAuthExpired, isNetworkConnectionError, ApiResult, bypass, 旁路, 绕过, 统一封装, 错误码解析]
problem_patterns: [bypass-unified-wrapper-loss-of-global-protection, upload-function-direct-http-call]
source_sessions: [ses_f5a627b65ffe6opSeGv6RTJBCT]
project: HarmonyProject1
severity: high
quality_score: 80
hit_count: 0
last_hit_at: null
low_quality_hit_count: 0
tier: A
related_experiences: []
---

# 绕过统一网络请求封装的旁路调用会丢失全局错误处理和认证拦截

## Scenario

项目有一个统一的 `request<T>()` 函数封装了所有网络请求的横切逻辑：401 登录态过期拦截（`markAuthExpired`）、网络连接错误识别（`isNetworkConnectionError`）、业务错误码解析（`ApiResult.code`）、友好错误消息构造。但当新增特殊请求（如文件上传 `uploadChatMedia`）时，开发者直接使用了 `http.createHttp()` 发起 PUT 请求，绕过了 `request()` 封装，导致上述所有全局保护机制失效。

## Key Signals

- `uploadChatMedia` 函数中 token 过期不会触发全局 `markAuthExpired()`，用户不会被引导到登录页
- 上传时网络连接失败（ECONNREFUSED）用户看到原始技术错误信息而非"网络连接失败，请检查网络后重试"
- 后端返回 `{code: 401, message: "登录已过期"}` 但 HTTP 状态码为 200 时，`uploadChatMedia` 不识别为错误
- `uploadChatMedia` 只检查 HTTP 状态码 200-299，不解析响应体中的 `ApiResult.code`

## Essence

统一封装函数的价值在于横切关注点的集中管理（认证、错误处理、日志、重试）。任何旁路调用（bypass）都会形成"保护盲区"。当新功能需要特殊请求模式（上传、流式、WebSocket）时，有两种策略：

**策略 A（推荐）**：扩展统一封装以支持新模式，保持所有请求经过同一入口。
**策略 B**：旁路调用但手动补齐等价的横切逻辑（401 拦截、错误码解析、网络错误识别）。

**策略 C（危险）**：旁路调用且不补齐任何横切逻辑 — 这是当前 `uploadChatMedia` 的问题。

## Approach

1. **识别所有旁路调用**：搜索项目中直接使用 `http.createHttp()` 或 `http.request()` 的位置，确认是否绕过了统一封装。

2. **为旁路调用补齐等价逻辑**：
   ```typescript
   // 旁路调用前：检查 token 并设置 header
   const token = getToken();
   if (token === '') { throw new Error('请先登录'); }
   headers['Authorization'] = 'Bearer ' + token;

   // 旁路调用后：解析响应
   if (resp.responseCode === 401) {
     markAuthExpired();  // 触发全局登录引导
     throw new Error('登录已过期，请重新登录');
   }
   const result = resp.result as ApiResult<T>;
   if (result && typeof result.code === 'number' && result.code !== 0) {
     throw new Error(result.message ?? '请求失败');
   }
   ```

3. **长期方案：扩展统一封装**：在 `request()` 中增加对 `multipart/form-data` 和 PUT 上传的支持，让上传也走统一入口。

4. **代码审查检查清单**：每次新增 API 函数时，确认是否通过 `request()` 发起；如果不是，确认是否补齐了 401 拦截、错误码解析、网络错误识别。

## Faster Next Time

- 新增任何网络请求函数时，默认走 `request()` 封装；只有当 `request()` 无法满足需求时才考虑旁路
- 旁路调用时，对照 `request()` 函数的横切逻辑清单逐一补齐
- 定期用 `grep -rn "http.createHttp\|http.request" --include="*.ets"` 搜索旁路调用

## Applicability Boundaries

- **适用**：所有有统一 API 请求封装的项目，特别是包含认证拦截和错误码解析的项目
- **不适用**：无统一封装的项目（此时应先建立封装）
- **关键阈值**：当旁路调用数量超过 1 个时，应考虑扩展统一封装而非继续补齐个别旁路

## Evidence or Examples

- HarmonyProject1 `services/api.ets`：`request()` 函数（行81-137）包含完整的 401 拦截、网络错误识别、业务错误码解析
- `uploadChatMedia`（行974-997）直接使用 `http.createHttp()`，不经过 `request()`，缺失所有横切保护
- 对比：`request()` 中 401 处理会调用 `markAuthExpired()` 并抛出友好错误；`uploadChatMedia` 中 401 仅表现为 HTTP 状态码非 200-299，抛出原始错误
