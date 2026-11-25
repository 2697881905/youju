---
title: "2026-10-07-unit-test-mock-sync-on-orm-call-and-shape-change.md"
id: markdown_cls1_798285c88467638f6a8dc28635ad6f33_dce82f4c893c94f615200b2711c2a32b7505655250320770
kb: 有据-YouJu
folder: "问题记录"
media_type: 7
tags: []
source: ima
exported_at: 2026-11-23T15:08:03.628Z
---
---
id: 2026-10-07-unit-test-mock-sync-on-orm-call-and-shape-change
title: 改 service 的 ORM 调用或返回结构后必须同步更新单测的 mock 与断言：否则报 not a function / toEqual 差异
category: testing
nature: pitfall
created_at: 2026-10-07T01:12:01
updated_at: 2026-10-07T01:33:47
tags: [unit-test, mocking, jest, orm, test-contract]
keywords: [prisma mock, jest.fn, not a function, TypeError, toEqual 差异, 全量断言, 返回结构变化, spread 新字段, 测试契约, mock 同步, 受影响测试套件, 幂等用例, service 改动]
problem_patterns: [service-adds-orm-call-but-mock-missing-method, returning-new-field-breaks-toEqual-full-object-assertion, code-contract-changed-but-test-contract-not-followed]
source_sessions: [ses_eedd3752fffetKbN8bZbsXcX0H]
project: HarmonyProject1
severity: medium
quality_score: 82
hit_count: 0
last_hit_at: null
low_quality_hit_count: 0
tier: A
related_experiences: [2026-10-07-denormalized-counter-status-transition-sync, 2026-10-07-derived-count-stale-after-delete-layered-triage]
---

# 改 service 的 ORM 调用或返回结构后必须同步更新单测的 mock 与断言：否则报 not a function / toEqual 差异

## Scenario

使用「mock 替代数据访问层」的单元测试（jest + 手写 prisma mock、Mockito 等）。为修一个 bug，在 service 里做了一处看似局部的改动：新增一次 ORM 调用（如 `prisma.comment.count(...)`），或改变了返回对象结构（如用对象展开多带出一个计算字段）。旧测试随即以**看似与业务无关**的方式失败，让人误以为业务逻辑改坏了。

任何「service 依赖被 mock 的仓储/客户端，且测试用手写 mock + 全量断言」的项目都会遇到。

## Key Signals

1. `TypeError: prisma_1.prisma.comment.count is not a function`（`Cannot read properties of undefined` 同理）—— mock 对象里没有这个方法。
2. `expect(received).toEqual(expected)` 的差异**只多/少了一个字段**（如 `+ "commentCount": 0`）—— 全量对象断言未随返回结构更新。
3. 失败测试的业务断言其实仍然正确，报错只指向 mock 或对象结构本身。
4. 本次改动只碰了 service 源码，没有同步改任何测试文件。
5. 改动点与被失败测试分属不同文件（如改了 `postService.ts`，挂的是 `posts.test.ts` 与 `postService.test.ts`）—— 容易漏跑。

## Essence

mock 是**契约的影子**：service 对数据层的每一个新依赖调用，都是 mock 契约的新增项；返回对象的结构变化，都会破坏基于 `toEqual` 的全量比对。这类失败不是「被测逻辑错」，而是**代码契约变了、测试契约没跟上**。

因此，修 bug 时对 service 的改动与它对测试契约的影响是一次改动的两面：漏掉后者，就会出现「业务修好了，却因测试红了而被误判为回归」。把 mock / 断言更新与 service 改动放进**同一个提交**，并在改完后跑**受影响的整个测试套件**（而非只跑自以为相关的那一个），是正确做法。

## Approach

1. 修改 service 后，先跑受影响的整个测试套件（`jest <受影响目录/文件>`），不要只跑单个文件。可用 `jest --findRelatedTests <改动的源文件路径>` 自动定位受影响的测试文件，避免凭记忆遗漏。
2. 为**新增的 ORM 方法**在 mock 工厂里补 `jest.fn()`，并给合理默认返回值（如 `mockResolvedValue(0)` / `mockResolvedValue([])` / `mockResolvedValue({ count: 1 })`），使其余用例不受影响。
3. 若**返回结构新增字段**：更新使用 `toEqual` 全量比对的断言；要么显式补上新字段，要么把断言收敛为只校验关心字段的 `toMatchObject`，避免每次加字段都被迫改一堆断言。
4. 为**新增行为**补边界/幂等用例（如条件更新命中 0 时不重复扣减、恢复时补回）。
5. 全绿后再提交；mock 与断言更新和 service 改动同提交、同说明。

## Faster Next Time

- 把「新增/改变 ORM 调用 → 同步 mock」「改返回结构 → 同步断言」写成改动 checklist 的固定项。
- 见到 `xxx is not a function` / `Cannot read properties of undefined`，第一反应是「mock 里缺这个 `jest.fn()`」，而不是怀疑业务逻辑。
- 见到 `toEqual` 只差一个字段，优先怀疑返回对象 `spread` 了新字段，先看 service 的返回值再改断言。
- 用 `toMatchObject` 替代对大对象的 `toEqual`，可显著降低「加字段就红一片」的维护成本。
- 改完 service 后用 `jest --findRelatedTests <源文件>` 一次性找到所有受影响测试，比手动猜测更可靠。

## Applicability Boundaries

- **适用**：以 mock/stub 注入替代真实依赖的单元测试（jest + 手写 mock、Mockito、gomock 等）。
- **不适用**：真实数据库的集成测试（无 mock 契约，改 service 后应验证真实行为）。
- **不适用**：mock 框架自身的环境/版本配置问题（属 `build-env`，非测试策略）。
- **前提约束**：仅当测试确实通过 mock 隔离了数据层时，本经验成立；若测试直接连库，失败含义不同。

## Evidence or Examples

HarmonyProject1 后端（Express + TypeScript + Prisma，jest + 手写 prisma mock）：

- 场景一（新增 ORM 调用）：详情接口改为实时 `prisma.comment.count({ where: { postId: id, status: 1 } })` 后，`posts.test.ts` / `postService.test.ts` 报 `TypeError: prisma_1.prisma.comment.count is not a function`。修复：mock 的 `comment` 对象补 `count: jest.fn()`；随后一个用例因返回多出 `commentCount` 触发 `toEqual` 差异（`+ "commentCount": 0`），同步更新断言。最终 `Test Suites: 30 passed`、`Tests: 266 passed`。
- 场景二（新增条件更新）：举报服务新增 `comment.updateMany({ where: { id, status: 期望旧值 } })` 后，同步在 `reportService.test.ts` 的 tx mock 中补 `updateMany: jest.fn().mockResolvedValue({ count: 1 })`，并新增「已被阈值下架不重复扣减」「恢复补回」用例。
- 关联：上述两次 service 改动的业务背景分别见 `2026-10-07-denormalized-counter-status-transition-sync` 与 `2026-10-07-derived-count-stale-after-delete-layered-triage`。
