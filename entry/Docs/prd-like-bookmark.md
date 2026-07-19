# PRD：点赞 & 收藏闭环（简单版）

> 角色：产品经理「许清楚」｜项目：大蓝书（男性生活经验社区）
> 平台：HarmonyOS NEXT 原生（ArkTS + ArkUI，API 24，ArkTS V1 严格模式）+ Node.js/Express/TS/Prisma/MySQL
> 文档类型：简单 PRD（无竞品分析 / 无象限图）
> 编写日期：2025-07-19

---

## 0. 代码勘察结论（关键：与初版 Brief 的差异）

初版 Brief 标注为「已确认事实」的多数结论与实际代码不符。经逐文件核对，**「点赞 & 收藏闭环」已基本端到端实现**，重复建设会被浪费。下表为真实状态：

| 初版 Brief 论断 | 实际代码状态 | 结论 |
|---|---|---|
| 路由前缀是 `/v1/interact` | `app.ts` → `app.use('/v1', interactRouter)`，真实前缀为 **`/v1`**，接口 `/v1/posts/:id/up`、`/v1/posts/:id/bookmark` | Brief 错误；但前端 api.ets 已按 `/v1/...` 封装，无需改动 |
| Post 字段为 `likeCount` | 实际为 **`upCount`**（业务用词「顶/up」）、`bookmarkCount`、`commentCount` | 字段名以 `upCount` 为准 |
| api.ets「没有」like/bookmark 封装 | 已存在 `upPost`/`cancelUpPost`/`bookmarkPost`/`cancelBookmarkPost` + `listMyBookmarks` | 无需新增 |
| DetailPage「没有」点赞/收藏按钮 | 已含 `onUp`/`onBookmark`（**乐观更新+失败回滚**）+ 底部操作栏「顶/抄作业/评论/分享」 | 已实现 |
| 需新增后端收藏列表端点 | `auth.ts:54` 已有 `GET /v1/auth/me/bookmarks?page=&limit=` | 无需新增 |
| 需新增前端「我的收藏」页 | `ProfilePage`（底部 Tab「我的」）已含「我发布/我收藏」双子 Tab，复用 `listMyBookmarks` | 已存在 |
| 点赞数格式化（万级）属 P2 | `formatCount` 已实现 `x.xw` 万级格式化 | 已做 |

**真正仍缺失 / 待修复的缺口（重新定级见 §3）：**
1. `PostCard` 点赞区为**只读文本**，无点击、无乐观更新、无高亮态。
2. 后端列表/详情接口**未返回**「当前用户是否已顶/已收藏」标记，导致 `DetailPage` 初始 `uped=false`——对已点赞帖子再次点「顶」会重复 `upPost`，后端 `upsert` 幂等但 `upCount` 无条件 +1，**计数膨胀 / 取消错乱**（真实 bug）。
3. 「我的收藏」入口仅 ProfilePage 子 Tab，入口深度待确认。

---

## 1. 项目信息

- **Language**：中文
- **Programming Language / 技术栈**：前端 HarmonyOS ArkTS + ArkUI（API 24，V1 严格模式）；后端 Node.js + Express + TypeScript + Prisma + MySQL
- **Project Name**：`like_bookmark_loop`
- **原始需求复述**：补全核心互动闭环（发帖 → 看帖 → 点赞/收藏 → 评论），让用户在信息流即可一键点赞、在详情页可点赞/收藏、在「我的」可回看收藏，提升社区活跃与留存。

---

## 2. 产品定义

### Product Goals（3 个，正交）
1. **闭环可用**：用户在信息流、详情、个人页三处均可完成点赞/收藏及其反向操作，状态一致、计数准确。
2. **即时反馈**：所有互动操作本地乐观更新、失败回滚，点击到状态变化 < 100ms 体感。
3. **可回看**：收藏内容可在「我的收藏」稳定浏览、分页、空态/错误态清晰，沉淀用户价值。

### User Stories
- **US-1 点赞（信息流）**：As a 浏览者，I want 在 PostCard 直接点 ⭐ 点赞 so that 不用进详情就能表达认同。
- **US-2 点赞/收藏（详情）**：As a 读者，I want 在详情页底部一键顶/抄作业并即时看到高亮态 so that 知道自己的互动状态。
- **US-3 取消互动**：As a 用户，I want 再次点击可取消赞/收藏且计数回滚 so that 操作可纠错、数据准确。
- **US-4 查看我的收藏**：As a 用户，I want 在「我的」页切到「我收藏」Tab 看全部收藏 so that 回头找「抄作业」的内容。

---

## 3. 需求池（重新定级，对齐真实代码）

### P0（Must have）
- **P0-1 修复计数膨胀 bug（后端+前端）**：后端在 `getPost` 与列表接口（`/v1/posts`、`/v1/posts/following`、`/v1/auth/me/bookmarks`）返回 `myUp: boolean`、`myBookmark: boolean`（基于当前登录用户）。前端 `DetailPage` 用其初始化 `uped`/`bookmarked`，杜绝重复 `upPost` 导致的 `upCount` 膨胀。
  - *验收*：已点赞帖子进入详情，初始显示「已顶」高亮；点击「顶」触发取消而非二次计数。
- **P0-2 PostCard 点赞按钮可交互（前端）**：将现有只读 `⭐ upCount` 文本改为可点击 Row，实现乐观更新（`uped` + 计数 ±1）与失败回滚（对齐 `DetailPage.onUp`）。「我的收藏」网格中的 PostCard 同步支持点击取消收藏。
  - *验收*：信息流点 ⭐ 立即 +1 并高亮；断网/未登录时回滚并 toast 提示。
- **P0-3 联调验证（已有能力）**：确认 4 个互动接口 + `GET /v1/auth/me/bookmarks` + `api.ets` 封装 + `ProfilePage` 收藏子 Tab **联调通过**（这些初版列为 P0 的项已存在，本 PRD 不再要求新建，仅验收）。

### P1（Should have）
- **P1-1 已赞/已藏高亮态**：基于 P0-1 的 `myUp`/`myBookmark`，PostCard 与 DetailPage 统一视觉语言（⭐ 实心品牌色 vs 空心灰；📥 同理）。
- **P1-2 收藏列表错误态重试**：`ProfilePage` 收藏 Tab 现仅展示错误文案，增加「重试」按钮（复用 `refresh()`）。
- **P1-3 收藏列表项与详情状态同步**：在收藏 Tab 取消收藏后，该项即时从网格移除或计数更新。

### P2（Nice to have）
- **P2-1 双击图片点赞**：DetailPage 图片区支持双击手势（`Gesture`/`onTouch`）触发顶，带轻微动效。
- **P2-2 计数格式统一**：确认 `upCount`/`bookmarkCount` 均经 `formatCount` 万级格式化（已做，仅回归）。
- **P2-3（建议不做）UserProfilePage 展示他人收藏**：隐私考量，不做。

---

## 4. UI 设计稿描述

### 4.1 PostCard 点赞区（信息流 / 收藏网格复用）
现状：底部一行 `⭐ {upCount}   💬 {commentCount}`（只读）。
目标：⭐ 区改为可点击按钮，点击触发乐观更新。

```
┌─────────────────────────────────────┐
│ [封面图 可选]                         │
│ 标题（最多 2 行）                     │
│ 👤 作者昵称                           │
│ ┌──────────────┐  ┌──────────────┐   │
│ │ ⭐ 1.2w  (可点)│  │ 💬 328       │   │
│ └──────────────┘  └──────────────┘   │
│   ↑ 已赞态：⭐ 变品牌色实心 + 数字+1   │
└─────────────────────────────────────┘
```
- 点击 ⭐：本地 `uped` 翻转 + 计数 ±1（乐观）；请求失败回滚 + toast「操作失败，请先登录」。

### 4.2 DetailPage 底部操作栏（已存在，标注高亮态）
```
┌─────────────────────────────────────┐
│ 👍 顶 1.2w   │ 📥 抄作业 328 │ 💬 评论 │ 🔗 分享 │
│  (已顶=品牌色)  (已藏=品牌色)    (灰)   (灰) │
└─────────────────────────────────────┘
```
- 四等分 `layoutWeight(1)`，点击分别 `onUp` / `onBookmark` / 展开评论框 / 分享（开发中）。

### 4.3 「我的收藏」页（ProfilePage 子 Tab「我收藏」）
入口：底部 Tab「我的」→ 顶部子 Tab「我收藏」。
```
我的                       [设置]
👤 头像   昵称
  128 关注   64 粉丝
[我发布]  [我收藏●]
┌─────────┐ ┌─────────┐
│ PostCard│ │ PostCard│   ← 2 列网格，复用 PostCard
└─────────┘ └─────────┘
（下拉刷新 / 上拉加载更多 / 底部「没有更多了」）
空态：还没有收藏过帖子
错误：加载失败：xxx  [重试]
```
- 数据：`listMyBookmarks(page, 20)`，分页 20；空态/错误态/分页均已具备，补「重试」按钮（P1-2）。

---

## 5. 待确认问题（需主理人/用户拍板）

1. **`myUp`/`myBookmark` 字段是否本期由后端在列表/详情接口返回？**（影响 P0-1 与 P1-1）。若不返回，前端只能用本地存储记忆已互动帖子（跨设备/换机丢失，且不权威）——**建议后端返回**。
2. **「我的收藏」入口是否保持现状（ProfilePage 子 Tab）？** 还是要在「我的」页顶部或 Settings 增加独立快捷入口？入口深度影响收藏回访率。
3. **信息流 PostCard 是否同时加「收藏」按钮？** 现状仅点赞。建议：信息流只点赞、收藏仅放详情页（避免卡片过载）；请确认。
4. **收藏列表分页大小**：现状 `limit` 默认 20，与信息流一致。是否维持 20，还是调大到 30？

---

## 附：术语对照
- 业务「顶 / 点赞」= 后端 `up` 表 / `upCount` / 接口 `up`；前端显示 ⭐。
- 业务「抄作业 / 收藏」= 后端 `bookmark` 表 / `bookmarkCount`；前端显示 📥。
- 路由前缀以 `/v1` 为准（非 `/v1/interact`）。
