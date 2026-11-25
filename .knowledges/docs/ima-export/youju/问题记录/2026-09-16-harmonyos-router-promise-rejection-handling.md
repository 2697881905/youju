---
title: "2026-09-16-harmonyos-router-promise-rejection-handling.md"
id: markdown_798285c88467638f6a8dc28635ad6f33_a6ecd1dce747f4948224e794b721997b7505655250320770
kb: 有据-YouJu
folder: "问题记录"
media_type: 7
tags: []
source: ima
exported_at: 2026-11-23T14:52:37.917Z
---
---
id: 2026-09-16-harmonyos-router-promise-rejection-handling
title: HarmonyOS router.pushUrl/router.back 返回 Promise 必须处理 rejection
category: coding-pattern
nature: pitfall
created_at: 2026-09-16T01:03:43
updated_at: 2026-09-16T01:03:43
tags: [router, pushUrl, back, Promise, rejection, 导航, 错误处理]
keywords: [router.pushUrl, router.back, Promise, rejection, .catch, try-catch, getRouter, pushUrl, 页面栈, navigation, HarmonyOS, ArkUI]
problem_patterns: [router-promise-rejection-unhandled, try-catch-cannot-catch-promise-rejection]
source_sessions: [ses_f5a5a0181ffeDQZ3eeC6mOmGcW]
project: HarmonyProject1
severity: medium
quality_score: 88
hit_count: 0
last_hit_at: null
low_quality_hit_count: 0
tier: S
related_experiences: [2026-09-15-empty-catch-block-audit]
---

# HarmonyOS router.pushUrl/router.back 返回 Promise 必须处理 rejection

## Scenario

HarmonyOS ArkUI 中 `router.pushUrl()` 和 `router.back()` 是异步 API，返回 `Promise<void>`。开发者常将其放在 `try-catch` 中或直接调用，不加 `.catch()`。但 `try-catch` 只能捕获同步异常，**不能捕获 Promise rejection**。当页面栈已满（默认32层）、目标页面不存在、或路由系统未就绪时，`pushUrl` 的 Promise 会被 reject，产生未处理的 Promise rejection 警告或异常。

## Key Signals

- 代码中 `router.pushUrl({ url: 'pages/XXX' })` 没有 `.catch()` 或 `await`
- `try { router.pushUrl(...) } catch (e) {}` — try-catch 无法捕获 Promise rejection
- 运行时日志出现 "Unhandled Promise rejection" 警告
- 深层页面栈跳转失败但无任何用户反馈

## Essence

`router.pushUrl()` 返回 `Promise<void>`，是异步操作。JavaScript/ArkTS 的 `try-catch` **只能捕获同步抛出的异常**，不能捕获 Promise 的 rejection。要捕获 Promise rejection，必须使用以下方式之一：
1. `await router.pushUrl(...)` 在 async 函数的 try-catch 中
2. `router.pushUrl(...).catch((e: Error) => { ... })`
3. `router.pushUrl(...).then(() => {}).catch((e: Error) => { ... })`

`router.back()` 同理，虽然在多数实现中 back 的 rejection 概率较低（页面栈为空时 back 可能静默无效），但仍应处理。

## Approach

1. **router.pushUrl 必须附加 .catch()**：
   ```typescript
   // ❌ 错误：Promise rejection 未处理
   router.pushUrl({ url: 'pages/LoginPage' });

   // ❌ 错误：try-catch 不能捕获 Promise rejection
   try {
     router.pushUrl({ url: 'pages/LoginPage' });
   } catch (e) { /* 不会到达这里 */ }

   // ✅ 正确：使用 .catch()
   router.pushUrl({ url: 'pages/LoginPage' })
     .catch((e: Error) => {
       console.error('[nav] pushUrl failed: ' + e.message);
     });

   // ✅ 正确：在 async 函数中 await + try-catch
   async function navigate(): Promise<void> {
     try {
       await router.pushUrl({ url: 'pages/LoginPage' });
     } catch (e) {
       console.error('[nav] pushUrl failed: ' + (e as Error).message);
     }
   }
   ```

2. **router.back 同样需要处理**：
   ```typescript
   // ✅ 正确
   this.getUIContext().getRouter().back();
   // back() 虽不返回 Promise，但在页面栈为空时可能无效，
   // 建议在调用前检查页面栈深度或使用安全包装
   ```

3. **通过 UIContext 调用时同理**：
   ```typescript
   // ❌ 错误
   this.getUIContext().getRouter().pushUrl({ url: 'pages/DetailPage' });

   // ✅ 正确
   this.getUIContext().getRouter().pushUrl({ url: 'pages/DetailPage' })
     .catch((e: Error) => {
       console.error('[nav] pushUrl failed: ' + e.message);
     });
   ```

## Faster Next Time

- 代码审查时搜索 `router.pushUrl` 和 `getRouter().pushUrl`，确认每个调用都有 `.catch()` 或在 `await` + `try-catch` 中
- 搜索 `router.back` 和 `getRouter().back`，确认调用安全
- 特别注意 `utils/auth.ets` 等非组件代码中的 router 调用——这些地方最容易遗漏
- 新增 router 调用时，默认附加 `.catch((e: Error) => { console.error(...) })`

## Applicability Boundaries

- **适用**：所有 HarmonyOS ArkUI 项目中使用 `router.pushUrl`/`router.back` 的场景
- **不适用**：`router.replaceUrl`（同样返回 Promise，但替换当前页面不会增加栈深度，rejection 概率更低——但仍建议处理）
- **注意**：`router.back()` 在 ArkUI 中不返回 Promise（同步调用），但在页面栈为空时调用是 no-op，不会报错

## Evidence or Examples

- `auth.ets` 行111、116：`router.pushUrl({ url: 'pages/LoginPage' })` 在 try-catch 中但无 `.catch()` — try-catch 无法捕获 Promise rejection
- `DetailPage.ets` 行234：`this.getUIContext().getRouter().pushUrl({ url: 'pages/UserProfilePage' })` — 无 `.catch()`
- `DetailPage.ets` 行245、248、840：`router.back()` 调用 — 无错误处理
- `ChatPage.ets` 行949：`this.getUIContext().getRouter().pushUrl({ url: 'pages/DetailPage' })` — 无 `.catch()`
- `LoginPage.ets` 行194、208：跳转隐私政策/用户协议页面 — 无 `.catch()`
- 对比正确做法：`DetailPage.ets` 的 `navigateBack()` 方法中 `router.back()` 在 `setTimeout` 回调内，组件可能已销毁 — 需要额外保护
