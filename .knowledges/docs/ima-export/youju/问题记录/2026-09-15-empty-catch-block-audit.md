---
title: "2026-09-15-empty-catch-block-audit.md"
id: markdown_798285c88467638f6a8dc28635ad6f33_147cd1fb8c3b69e042d92ea18886ad957505655250320770
kb: 有据-YouJu
folder: "问题记录"
media_type: 7
tags: []
source: ima
exported_at: 2026-11-23T14:52:37.917Z
---
---
id: 2026-09-15-empty-catch-block-audit
title: 代码审查中系统性识别空 catch 块和 fire-and-forget async 调用的方法
category: coding-pattern
nature: methodology
created_at: 2026-09-15T23:54:39
updated_at: 2026-09-15T23:54:39
tags: [catch, fire-and-forget, 错误处理, 代码审查, hilog]
keywords: [catch, empty-catch, fire-and-forget, .catch(() => {}), hilog, try-catch, async-await, rejection, 未处理, 静默吞错, 日志记录]
problem_patterns: [empty-catch-block-no-logging, fire-and-forget-async-without-catch]
source_sessions: [ses_f5a627b65ffe6opSeGv6RTJBCT]
project: HarmonyProject1
severity: low
quality_score: 72
hit_count: 1
last_hit_at: 2026-09-16T00:58:50
low_quality_hit_count: 0
tier: A
related_experiences: []
---

# 代码审查中系统性识别空 catch 块和 fire-and-forget async 调用的方法

## Scenario

大型项目中普遍存在两类错误处理隐患：① 空 catch 块（`catch (e) { }` 或 `catch (_) { /* ignore */ }`）完全吞掉异常且无日志记录；② async 函数被 fire-and-forget 调用（`this.someAsync()` 不 await 也不 .catch()），内部 try-catch 之外的异常会成为未处理 rejection。这两类问题在功能正常时不可见，但在排查"偶发异常"或"用户反馈无法复现的问题"时会成为盲区。

## Key Signals

- 搜索 `catch (e) {` 或 `catch (_) {` 后紧跟 `}` 或仅注释的行 — 空 catch 块
- 搜索 `.catch(() => {})` 或 `.catch((): void => {})` — Promise 链末尾的静默吞错
- 搜索 async 函数调用但不在 `await` 表达式中、也不在 `.then()/.catch()` 链中 — fire-and-forget
- 用户反馈"偶发异常"但日志中无任何相关记录 — 可能是被空 catch 吞掉的异常

## Essence

空 catch 块和 fire-and-forget 调用的问题不在于"忽略了错误"（某些场景下忽略是合理的），而在于"忽略了错误且不留痕迹"。正确的做法是：即使决定不向用户展示错误，也至少应通过 `hilog.warn` 或 `hilog.error` 记录日志，以便后续排查。

fire-and-forget 的隐患更微妙：即使 async 函数内部有 try-catch，如果 catch 块本身抛异常（如访问已销毁的 `@State` 属性），或者 try-catch 覆盖范围不完整，就会产生未处理 rejection。

## Approach

1. **系统性搜索空 catch 块**：
   ```
   grep -rn "catch (e) {" --include="*.ets" | 检查后续1-2行是否为空或仅注释
   grep -rn "catch (_) {" --include="*.ets" | 同上
   grep -rn ".catch(() => {})" --include="*.ets"
   grep -rn ".catch((): void => {})" --include="*.ets"
   ```

2. **系统性搜索 fire-and-forget async 调用**：
   ```
   grep -rn "this\.\w*()" --include="*.ets" | 过滤出 async 函数调用但不在 await 表达式中
   ```

3. **对每个空 catch 块的修复策略**：
   ```typescript
   // 修复前
   } catch (e) { /* ignore */ }

   // 修复后
   } catch (e) {
     hilog.warn(0x0000, 'ComponentName', 'operation failed: %{public}s', JSON.stringify(e));
   }
   ```

4. **对每个 fire-and-forget 的修复策略**：
   ```typescript
   // 修复前
   this.syncSelfAvatar();  // 无 await，无 .catch()

   // 修复后（方案A：await）
   await this.syncSelfAvatar();

   // 修复后（方案B：.catch）
   this.syncSelfAvatar().catch((e: Error) => {
     hilog.warn(0x0000, 'ComponentName', 'syncSelfAvatar failed: %{public}s', e.message);
   });
   ```

5. **审查优先级**：
   - 高优先级：涉及用户可见功能的 catch（如未读计数、隐私同意记录、会话校验）
   - 中优先级：涉及导航/路由的 catch（如 router.pushUrl 失败）
   - 低优先级：fire-and-forget 埋点/统计类 catch（可保留空 catch 但加注释说明）

## Faster Next Time

- 代码审查时先执行上述 grep 搜索，快速定位所有空 catch 和 fire-and-forget
- 新增 try-catch 时，将 `hilog.warn` 作为 catch 块的默认模板
- 新增 async 函数调用时，默认使用 await；如果故意 fire-and-forget，必须附加 `.catch()`
- 对于"确实需要忽略"的 catch（如清理资源的 finally 中），加注释 `// intentionally ignored: <reason>` 并记录 hilog

## Applicability Boundaries

- **适用**：所有 TypeScript/ArkTS 项目的代码审查
- **不适用**：性能敏感的热路径中确实需要零开销的 catch（罕见）
- **注意**：fire-and-forget 在某些场景是合理设计（如埋点上报），但即使如此也应 `.catch(() => { hilog.warn(...) })` 而非完全空 catch

## Evidence or Examples

- HarmonyProject1 `Index.ets` 行408-411：`catch (_) { // 校验失败不阻断启动 }` — 无日志
- HarmonyProject1 `Index.ets` 行425, 437, 451, 454：4处 `.catch(() => {})` — 涉及隐私同意、未读计数等用户可见功能
- HarmonyProject1 `auth.ets` 行117：`catch (_) { /* ignore */ }` — router.pushUrl 失败静默忽略
- HarmonyProject1 `ChatPage.ets` 行172-174：轮询失败静默 — 持续失败时无任何日志
- HarmonyProject1 `CircleTab.ets` 行243：`this.syncSelfAvatar()` fire-and-forget — 无 await 无 .catch
- HarmonyProject1 `HomeTab.ets` 行365：`this.loadFollowingCount()` fire-and-forget — 无 await 无 .catch
