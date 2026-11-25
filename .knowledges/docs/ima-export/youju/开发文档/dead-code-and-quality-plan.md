---
title: "dead-code-and-quality-plan.md"
id: markdown_798285c88467638f6a8dc28635ad6f33_c8f26f2a301b53251982d0a6442e31bd7505655250320770
kb: 有据-YouJu
folder: "开发文档"
media_type: 7
tags: []
source: ima
exported_at: 2026-11-23T14:52:37.917Z
---
# 死代码清理与代码质量优化方案

## Context（为什么做这件事）

项目刚通过一次完整的上线前全链路测试（后端 `tsc` 通过、`jest` 29 套件/232 用例全绿、前端 `assembleHap` BUILD SUCCESSFUL、真实接口冒烟 85/0 通过），功能层面是健康的。本轮目标是在**不破坏可用性**的前提下做三件事：

1. 删除**有 0 引用证据**的冗余/停用代码；
2. 收敛少量**已被证实重复**的逻辑；
3. 输出**代码质量分析**，把真正的大文件重构留作独立任务。

**风险控制原则**：只删「全仓 grep 仅命中定义自身」的项；每批改动后必须重建回归；高风险的大文件拆分**本轮不做**，只出报告。

> 说明：原计划就删除尺度 / 大文件重构 / `postFooter` 归属向你确认，问题被跳过，故本方案按**保守默认**执行：只删已验证死代码、不拆大文件、`postFooter` 按「漏接功能」接线修复。

---

## 一、删除已验证的死代码（低风险）

每项均为「全 `entry/src/main/ets` grep 仅命中定义行自身」：

| 项 | 位置 | 证据 | 处理 |
| --- | --- | --- | --- |
| `isReduceMotion()` | `entry/src/main/ets/utils/theme.ets:151-153` | grep 全前端仅 1 处（定义自身）。各组件用自己的 `shouldReduceMotion()`，未调用它 | 删除函数 |
| `loginByHuaweiResult()` | `entry/src/main/ets/utils/auth.ets:204` | grep 全前端仅 1 处（定义自身）；登录页已改走 `setSession` | 删除函数，并清理随之无用的 import |
| `@Builder toggleRow` | `entry/src/main/ets/pages/SettingsPage.ets:198` | grep 仅定义自身；同文件已内联实现（注释写明「因 @Builder 值快照不刷新改为内联」） | 删除 builder |
| `@Builder postFooter` | `entry/src/main/ets/pages/ProfilePage.ets:727-749` | grep 仅定义自身 | **不删，改为接线**（见第三节） |

排除项（**不是死代码，勿删**）：
- `pages/*Destination.ets` / `*View.ets`（如 `PostDetailDestination`、`ChatView`、`MyFollowView`）：Navigation `NavDestination` 壳，被 `Index` 的 `pageMap` 引用，`main_pages.json` 不注册是**设计如此**。
- `ProfilePage` / `MessagePage`：`Index` 的 TabContent 子页，非路由注册。
- 后端 ops/admin 接口（`ban`/`unban`/`recompute-hot`/`reports/resolve`）、`routes/push.ts`、`huaweiPush.ts`：前者为运维入口，后者为 v1.1 计划接线，均保留。
- `backend/scripts/` 下一次性运维脚本（`e2e-qa.mts`、`diag-images.ts`、`fix-images-localhost.ts`、`wipe-*`）：可能被手动运维使用，本轮保留。
- `utils/theme.ets` 的 `isReduceMotion` 之外，`setReduceMotion` 等仍有引用，勿连带删。

---

## 二、后端重复逻辑收敛（低风险）

**问题**：Prisma 唯一约束冲突（P2002）幂等处理在 5 处逐字重复：
`interactService.ts:14`、`interactService.ts:42`、`blockService.ts:20`、`dislikeService.ts:21`、`followService.ts:59`。

**改法**：
- 新增 `backend/src/utils/prismaErrors.ts`，导出 `isUniqueViolation(e: unknown): boolean`（判断 `e?.code === 'P2002'`）。
- 上述 5 处替换为 `if (isUniqueViolation(e)) { ... }`，**行为完全不变**（仅提取判定，不动各自分支语义）。
- 复用点：这些文件已有 jest 覆盖（`blockService.test.ts` 等），回归有保障。

---

## 三、修复漏接的功能：个人主页「没有更多了」

**问题**：`ProfilePage.postFooter()`（`:727`）是唯一渲染「没有更多了」的地方，却 0 调用 → 「我发布/我收藏/我赞过/我评论」四个列表滚到底**没有任何反馈**，与 `CircleDetailPage` 等页不一致。

**改法（最小改动）**：`ProfilePage.ets:874-877` 目前是内联的
```
Column() { Blank().width('100%').height(barBottomReserve()) }.width('100%')
```
而 `postFooter()` 恰好渲染「`finished` 时显示『没有更多了』」+ **同一段 `barBottomReserve()` 占位**。因此直接把它替换为 `this.postFooter()` 即可：既补上到底提示，又保留原有底部避让，视觉与滚动行为不变。

---

## 四、代码质量分析（只输出结论，不改代码）

**规模最大的文件（重构候选）**
- 前端：`pages/PostDetailView.ets` 1617、`pages/ChatView.ets` 1340、`components/DailyPostDeck.ets` 1086、`pages/ProfilePage.ets` 1085、`components/HomeTab.ets` 1050、`services/api.ets` 1034、`pages/ReportAdminPage.ets` 977、`pages/MessagePage.ets` 878。
- 后端：`services/postService.ts` 842（单文件承载信息流/每日/搜索/回收站/删除等多职责）。

**已知重复（本轮不动，需单独评估）**
- `shouldReduceMotion()` 在 **18 个文件**重复实现（共 118 处），逻辑都是 `reduceMotion || systemReduceMotion`。统一会牵涉 ArkUI 的 `@StorageProp` 响应式语义，属高风险改动，**建议独立任务**并逐个真机验证。
- 好的一面：格式化工具已收敛（`utils/format.ets` 的 `formatCount` 为单一实现），图片 URL 解析已收敛（`services/api.ets` 的 `resolveDisplayImageUrl`）。

**建议的大文件拆分顺序（后续独立任务）**
1. `postService.ts`（后端、有 jest 兜底，风险最低）→ 按 信息流 / 每日一帖 / 回收站 / 删除 拆分。
2. `ProfilePage.ets` → 抽「资料头部」「收藏夹区」「双列列表」子组件。
3. `PostDetailView.ets` / `ChatView.ets`（前端无自动化测试，风险最高，最后做，且需真机回归）。

---

## 五、明确不动（避免误伤）

- 不改路由注册表 `main_pages.json`。
- 不删除任何 `*Destination` / `*View` 壳与其导入。
- 不动 `backend/scripts/` 运维脚本、`routes/push.ts`、`huaweiPush.ts`、admin 运维接口。
- 不做大文件拆分（见第四节，留作独立任务）。
- 不动此前已提交的上线修复（分页/404/Prisma 映射/CI 冒烟）。

---

## 六、验证方式

每批改动后依次执行：

1. **后端**：`npx tsc -p tsconfig.json --noEmit` → `npx jest --ci`（预期仍 29 套件 / 232 用例全通过）。
2. **前端**：`hvigorw assembleHap --mode module -p module=entry@default -p product=default --no-daemon`（预期 BUILD SUCCESSFUL）。
3. **守卫脚本**（仓库既有护栏）：
   - `node scripts/verify-arkui-hooks.mjs`
   - `node scripts/verify-login-gates.mjs`
   - `node scripts/check-stale-overwrite.mjs`（pre-commit 钩子同一脚本）
4. **接口冒烟（可选）**：独立端口起后端（避免占用环境自带的 3000 端口），`BASE=http://127.0.0.1:3100/v1 node scripts/full-chain-check.mjs`，预期 0 失败。

---

## 七、执行顺序与提交粒度

1. **死代码删除**（第一节 3 个符号）→ 回归 → 提交 `chore(deadcode): 删除 0 引用的 isReduceMotion/loginByHuaweiResult/toggleRow`
2. **后端 P2002 helper**（第二节）→ 回归 → 提交 `refactor(backend): 抽取 isUniqueViolation 收敛 5 处 P2002 幂等判定`
3. **postFooter 接线**（第三节）→ 前端构建 + 守卫脚本 → 提交 `fix(profile): 个人主页列表补上「没有更多了」到底提示`
4. 最后附上第四节的**代码质量分析**作为交付说明（不产生代码改动）。

> 全部改动可独立回滚（每步一个提交）；死代码删除项均可通过 `git revert` 恢复。
