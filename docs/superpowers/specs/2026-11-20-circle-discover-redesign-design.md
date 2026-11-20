# 发现圈子重做 · 设计文档

日期：2026-11-20
状态：待批准
范围：圈子页「发现圈子」入口 + 落地独立页 + 后端概览接口的体裁聚合
修订：v2（吸收构建者评审的三处硬伤：创建入口、同城浏览、五种体裁）

---

## 1. 意图与为什么

现状是一屏「目录」：搜索框 + 创建入口 + 同城横滑 + 五个分类分组，每行「图标 / 名字 / 人数 / 加入」。它回答了「有哪些圈子」，没回答「为什么这个值得我进」。名字叫发现，做的是检索。

目标：让这一屏真的承担「发现」。用户没带目标进来，离开时至少对两三个圈子产生兴趣。

已确认的前提（对话结论）：
- 定位是**发现**，不是目录
- 内容表达走**内容橱窗**，但**不展示帖子标题与封面**
- 载体选定为**内容构成**（体裁分布）

---

## 2. 目标 / 非目标 / 反目标

**目标**
1. 首屏三张内容橱窗卡：这个圈子聊什么、产什么内容、此刻多活
2. 「已加入」从弹窗并进来，成为第二页签
3. 分类浏览退到第二屏，只做兜底

**非目标**
- 不做推荐算法，不做无限流
- 不做帖子级预览（标题/封面）
- 不改星图与「坠入宇宙」

**反目标（跑通也算失败）**
- 首屏推荐里出现已加入的圈子
- 卡片膨胀成帖子卡，与首页信息流同质
- 分类列表保留「加入」按钮，出现两套动作层级
- 删掉旧面板的同时丢掉创建圈子或同城圈子的入口

---

## 3. 约束

**平台**
- 一页只能有一个 `bindSheet` 生效（2026-11-19 事故）
- `compatibleSdk 6.0.0(20)` / `targetSdk 26`，HDS 能力有版本门禁
- ArkTS 严格模式：禁索引签名、禁无类型对象字面量、`@Builder` 内禁 `const/let`

**既有实现**
- 入口药丸在 `CircleTab.circleBrandRow()`，点击置 `exploreVisible`
- 「已加入」是 `CustomDialogController` + `JoinedCirclesDialog`
- 数据来自 `getCircleOverview(scope)`，客户端已在分组
- `Post.genre` 实为**五种**：`review | pitfall | tutorial | debate | share`
  （`publishGenres.ets:21`、`posts.ts:205` 白名单、`types.ets:2` 三处一致；`share` 是首页「生活区」的常规体裁）
- `listCircleOverview` 已查最近 120 条帖子，但 `select` 未取 `genre`

**设计**
- 承载文字的卡片必须实色 `elevated` 底
- 品牌色只给动作
- 卡片表面统一 `elevated` + 1px `separator` + 轻投影

---

## 4. 备选方案

| 方案 | 形态 | 取舍 |
|---|---|---|
| **一（选定）** | 独立页 `NavDestination` + 顶部分段（发现 / 已加入） | 空间足；两个入口合一；消除 bindSheet 单例约束。代价：新增路由与页面 |
| 二 | 半模态钉死 `LARGE` + 纵向卡片流 | 改动中等，但仍是「弹层里塞页面」，顶部永远露着星图 |
| 三 | 半模态 + 首屏三张策展卡 + 折叠分组 | 最省，天花板低，已被用户判定「区别不大」 |

选一：构成条需要横向空间；发现与已加入本该是一个页面的两个页签；`bindSheet` 单例约束随之消失。

---

## 5. 方案细节

### 5.1 信息架构

```
发现圈子（NavDestination 独立页）
├─ 标题栏：衬线「发现圈子」+ 右搜索圆钮（进入搜索态）+ 返回
├─ 分段栏：发现 | 已加入                    ← ImmersiveSegmentBar
├─【发现】
│   ├─「为你挑的」3 张内容橱窗卡
│   ├─「同城圈子」城市横滑 + 该城圈子行（最多 3 条）
│   ├─「按分类逛」分组列表（5 类）
│   └─ 底部动作行「＋ 点亮一颗新星」→ 创建表单 sheet
└─【已加入】
    ├─ 汇总行：N 个圈子 · M 条未读
    ├─ 已加入列表（未读徽标）
    └─「同城」分区（已加入的同城圈）
```

搜索态：点圆钮 → 标题栏下方展开 `Search`，实时过滤**当前页签**；再点圆钮或「取消」退出。不新增页面。

### 5.2 内容橱窗卡

五层结构：

1. **身份**：图标 40 + 名字（16/600）+ 元信息（11.5 `quaternary`，例「2,481 人 · 近 7 天有新帖」）
2. **一句话**：简介 12.5 `secondary`，两行截断
3. **体裁构成**：6vp 五段条 + 图例
   - 五段：测评 `brand` / 踩坑 `warm` / 教程 `#2E7D5B` / 观点 `#8A8A90` / 分享 `#C9C9CE`
   - 宽度 = 该体裁数 / 该圈最近若干篇的总数（五段之和恒等于分母，条永远满填）
   - 图例：`● 12 测评　● 8 踩坑　● 3 教程　● 2 观点　● 5 分享`，超过 4 项自动换行
   - 总数 0 → **构成条与底部脉搏行整块隐藏**，卡片退化为紧凑形态（加入按钮从底部移回首行右侧）。
     实测预置圈子 `description` 多为空串、且 7 天内无帖，卡片不能只剩「名字 + 人数 + 一句劝退文案」
4. **分隔线**：1px `separator`
5. **活跃 + 动作**：左「近期 23 篇」；没有样本时改显示「分类 · 人数」（同一骨架，两种形态共用）

表面：`elevated` + 1px `separator` + `RadiusTokens.lg`(20) + 轻投影；卡间距 10，页边距 16。

> 「同城圈」标签只出现在同城区块，不出现在推荐卡（推荐池取 `scope=main`，本就不含未加入的同城圈）。

### 5.3 分类列表行

高 58：图标 32 / 名字 14-500 / 元信息 10.5「12 测评 · 8 踩坑 · 25 人」/ 右箭头。
**无「加入」按钮**，整行点击 `openCircleDetailViaNav`。
行间 1px `separator`；组标题 12/600 `secondary`，上 32 / 下 6。

**每组默认只露 3 行**，超出时组标题右侧显示「全部 N」（可点展开/收起）。
实施修正：24 个圈子全铺开要滑三屏才见底，等于把索引当主内容。

### 5.4 同城区块

- 城市横滑胶囊（`ToggleChip outlined`），数据 `listCities()`，进入页面时不预选
- 选中城市 → `getCircleOverview('city', cityCode)`，展示最多 3 行
- 行内「加入」文字按钮 → 复用现有 `cityJoin` 逻辑（加入成功后本地更新 + 广播 `circleMembershipVersion`）
- 未选中城市时整块只显示标题 + 胶囊，不请求
- 城市圈仍然不进主星图与主目录（沿用 `scope=main` 的排除规则）

### 5.5 创建入口

- 「发现」页签底部一行「＋ 点亮一颗新星」，点击打开本页唯一的 `bindSheet` 表单
- 字段与校验沿用现状：名字 2~8 字、分类白名单 `CIRCLE_CATEGORIES`、简介 1~24 字
- 成功后：关闭 sheet → **留在当前页，把新圈插入列表并切到「已加入」页签** → 广播 `circleMembershipVersion`
- ⚠️ 实施修正（2026-11-20）：原计划的「pop 回星图 + 降落编舞」本期未做——跨页接管编舞需要额外的一次性信号通道
  （`createFromCatalog` 后半段依赖 `CircleTag` 与 `selectPlanet`/`landingVisible` 整套星图状态）。
  当前取舍：放弃编舞，先保证功能可用与数据一致；编舞留作后续独立任务
- 为什么用 seq：同值写入不派发 `@Watch`，连续创建两个圈子时第二个会丢（项目既有约定）

**载荷必须带完整圈子元信息，不能只传 name。** 原 `createFromCatalog` 第一步就用 `createTag` 返回的 `Tag`
构造 `CircleTag`，它带着 `id / creatorId / emoji / description / followCount`。只传 name 会导致：

- `canDeleteLanding()` 判 `creatorId === uid` 失败 → 刚创建的圈子没有「删除圈子」入口
- 降落页简介为空、人数为 0、泛光色退化成 fallback
- 行星标签丢 emoji

所以信号载荷声明为显式 class：

```ts
export class CircleCreatedPayload {
  seq: number = 0;
  name: string = '';
  emoji: string = '';
  category: string = '';
  description: string = '';
  memberCount: number = 0;
  creatorId: number = 0;
}
```

`CircleTab` 收到后直接构造 `CircleTag` 编舞，不补请求、不处理异步失败分支。

### 5.6 推荐位规则（我的决定）

- 候选：`joined === false && cityCode === null`
- 排序：`active7d` 为真的排前面，其余按后端返回顺序补足，取前 3
- **不硬凑已加入的**，但允许用「安静圈子」补位
- 纯客户端筛选，不新增推荐接口

> 实施修正（2026-11-20）：原规则强制 `active7d === true`，实测线上 24 个圈子**全部** `active7d=false`
> （7 天内没有新帖），首屏会只剩分类列表、退回「目录」。改为活跃优先 + 安静补位 3 张。

### 5.7 数据契约

后端 `CircleOverviewItem` 增加：

```ts
contentMix: { review: number; pitfall: number; tutorial: number; debate: number; share: number };
recentPostCount: number;
```

**不能复用现有 120 条窗口。** 那段查询（`tagService.ts:426`）是「全站按 `createdAt desc` 截断 120 条」，
既不是按圈、也没有时间下界：站内 7 天帖超过 120 时单圈会被截断（数字系统性偏低），不足 120 时又混进 7 天前的帖。
用它算不出「该圈最近若干篇」。

做法：单独取一次**全站最近 600 篇**候选池（不设时间下界），按圈分桶、每圈最多 50 篇，
`contentMix` 与 `recentPostCount` 由这一份样本同源派生；`active7d` 仍走 7 天窗口，两者解耦。

> 口径两次修正的关键证据（2026-11-20 实测线上库）：
> 帖子集中在 10-14 ~ 10-20（100 篇，全部带圈子），之后长期停产，11-16 仅 1 篇且 `tags` 为空。
> 今天 11-20 —— 7 天窗口抓 0 篇，30 天窗口同样抓 0 篇（最后一批刚好在 31 天前）。
> 固定时间窗口会让「内容构成」在停产期永久归零，故改为按篇数取样本。

```ts
const recent7d = await prisma.post.findMany({
  where: { status: 1, deletedAt: null, user: { status: 1, deletedAt: null },
           createdAt: { gte: new Date(activeEdge) } },
  select: { tags: true, genre: true },
});
```

- `Post.tags` 是 Json 数组，Prisma 无法按标签过滤 → 只能拉近 7 天全量再内存分桶（与现有 `postsByTag` 同法）
- 配套加索引：`Post @@index([createdAt])`（migration 与新代码必须同批上线）
- 口径：`contentMix` 五值之和 == `postCount7d` == 该圈近 7 天帖子数
- 文案禁用「全部 / 累计」，只说「近 7 天」
- 客户端 `api.ets` 同步加字段并给缺省值：`contentMix` 缺失按全 0（卡片隐藏构成条），`postCount7d` 缺失按 0

### 5.8 登录态（评审补充，现状是漏洞）

现状 `joinFromCatalog` / `createFromCatalog` 未登录只 toast「请先登录」，**不给登录入口**。
新页面统一按 `CircleDetailView.toggleJoin` 的既有范式处理：

```ts
if (getToken() === '') {
  const nav = getMainNavStack();
  if (nav !== null) { nav.pushPathByName('Login', new EmptyNavParams()); return; }
  this.getUIContext().getRouter().pushUrl({ url: 'pages/LoginPage' });
  return;
}
```

### 5.9 空态与边界

| 场景 | 表现 |
|---|---|
| 一个圈子都没有 | 空态 + 「＋ 点亮一颗新星」 |
| 推荐池为空（都加入了） | 「你已加入所有活跃圈子」+「按分类逛」引导 |
| 分类分组为空 | 不渲染该组标题 |
| 城市未选 | 同城区块只显示胶囊 |
| 该城无圈子 | 「这座城市还没有圈子」 |
| 已加入为空 | 「还没加入圈子」+「去发现」切页签 |
| 搜索无结果 | `EmptyState` + 关键词回显 |
| 接口失败 | `EmptyState`（错误态带重试） |

### 5.10 刷新与状态同步

- 进入页面拉一次；从详情页返回不重拉（用 5 秒节流避免抖动）
- 加入成功 → 本地状态更新 + 若该圈在推荐池则移出 + 广播 `circleMembershipVersion`
- 创建成功 → 回星图，由 `CircleTab` 接管编舞与本地列表
- 搜索态与页签滚动位置：切页签时各自保留（`Scroller` 各自持有）

### 5.11 入口改造（两颗药丸都要落地）

星图标题栏有两颗药丸，文档不能只删弹窗不管入口：

| 药丸 | 现在 | 改后 |
|---|---|---|
| 发现圈子 | `exploreVisible = true`（开面板） | `openCircleDiscoverViaNav({ initialTab: 0 })` |
| 已加入 N 个 | `circleJoinedSeq += 1` → `@Watch` 开 `CustomDialog` | `openCircleDiscoverViaNav({ initialTab: 1 })`，落在「已加入」页签 |

为此需要：

- `CircleDiscoverNavParams { initialTab: number }`（显式 class，ArkTS 禁无类型字面量）
- `Index.pageMap` 的 `'CircleDiscover'` 分支读参并传给页面 `@Prop initialTab`
- `CircleTab.onJoinedEntryRequested`（`circleJoinedSeq` 的 `@Watch`）从「开弹窗」改为「带参跳转」
- `Index` 的 `circleJoinedCount` / `circleJoinedSeq` 保留：药丸仍要显示计数，只是动作变了

### 5.12 路由与文件

| 文件 | 动作 |
|---|---|
| `pages/CircleDiscoverDestination.ets` | 新增：`NavDestination` 壳，`hideTitleBar(true)` |
| `pages/CircleDiscoverPage.ets` | 新增：标题栏 + 分段 + 两页签 + 搜索态 + 创建 sheet |
| `components/CircleShowcaseCard.ets` | 新增：内容橱窗卡 |
| `components/CircleContentMixBar.ets` | 新增：五段构成条 + 图例 |
| `components/CircleCreateSheet.ets` | 新增：创建表单（从 `CircleExploreSheet` 迁出表单片段） |
| `Index.ets` `pageMap` | 增加 `'CircleDiscover'`，读 `CircleDiscoverNavParams` 的 `initialTab` |
| `utils/navigationTransition.ets` | 增加 `CircleDiscoverNavParams` + `openCircleDiscoverViaNav(params)` |
| `CircleTab.circleBrandRow()` | 两颗药丸改为带参跳转（见 §5.11） |
| `CircleTab` | 移除 `exploreVisible`/`exploreSheet()`/`bindSheet`/`joinedDialogController`；`joinFromCatalog`/`cityJoin`/`createFromCatalog`/`catalogGroups` 迁出；`onJoinedEntryRequested` 改为跳转 |
| `backend/prisma/schema.prisma` | `Post` 加 `@@index([createdAt])`（与新查询同批上线） |
| `CircleExploreSheet.ets` | 删除（表单片段迁入 `CircleCreateSheet`） |
| `JoinedCirclesDialog.ets` | 删除（列表并入已加入页签） |

> 迁移而非丢弃：加入/创建/同城三条链路的业务逻辑（含编舞、广播、错误处理）逐段搬到新位置，逐条验收。

### 5.12 视觉规格

- 标题 `titleSerif` 21/700；页签 `ImmersiveSegmentBar`
- 卡片标题 16/600；正文 12.5；元信息 11.5；图例 11
- 间距基线 4；卡片外边距 16；卡内 14~16；分组上 32
- 深色：五段色需真机校色，`#2E7D5B` 在深底偏暗，提亮到 `#4CAF87` 一档

---

## 6. 留给构建者

- 构成条某段为 0 时的最小宽度与 gap（建议 0 段不渲染，gap 2→1）
- 搜索展开/收起曲线（建议 `MotionCurves.standard` 240ms）
- 已加入空态图形
- 深色五段色最终取值
- 卡片在长名字/长简介下的最小高度

---

## 7. 实施顺序与验收

**阶段 1：后端聚合 + 索引**
`Post @@index([createdAt])` migration；`listCircleOverview` 新增「全站近 7 天」查询，
`contentMix`（五键）/ `postCount7d` / `active7d` 三个值同源派生；补 `tags.overview.test.ts`
（断言含 share、含 0 值、五值之和 == `postCount7d`；现有 mock 只覆盖一次 `post.findMany`，需支持两次）。
验收：`npm test` 通过；用 SQL 手工统计某圈近 7 天体裁分布，与接口返回逐项一致；
**迁移与新代码同批上线**（`/health` 不碰数据库，必须跑一次真实查询验证）。

**阶段 2：独立页骨架 + 入口切换**
路由壳、页面、分段、搜索态；入口改跳转；旧弹层暂留。
验收：真机进入/返回正常；两页签可切；搜索能过滤；未登录点加入跳登录页。

**阶段 3：内容橱窗卡 + 同城 + 创建**
三个新区块接入真实数据。
验收：三张卡数据正确、构成条比例与图例一致；同城选城市能加载并加入；创建后回星图有降落编舞。

**阶段 4：清理**
删除旧组件与 controller，跑全量构建与回归。
验收：`bracecheck` 全 0；`assembleHap` BUILD SUCCESSFUL；真机回归星图/药丸/已加入/发现/详情/创建/同城七条链路。

---

## 8. 风险

| 风险 | 处置 |
|---|---|
| 删旧面板丢功能 | 阶段 4 才删，且三条链路（加入/创建/同城）在阶段 3 单独验收 |
| `contentMix` 口径被误读 | 字段注释标明窗口；UI 只说「近 7 天」；五值和恒等于 `postCount7d` |
| 跨页创建编舞丢信号 | 用带 seq 的 AppStorage 信号（项目既有约定），不用裸布尔 |
| 独立页返回手势与星图冲突 | 沿用 `CircleDetailDestination` 的 `getMainNavStack().pop()` |
| 长文案溢出 | 名字单行省略、简介两行截断、卡片最小高 |
| 深色下构成条看不清 | 阶段 3 真机专项校色，不靠推测 |
| 全站近 7 天查询随帖子量增长变慢 | 先加 `@@index([createdAt])`；量级上来后改为按圈预聚合的物化表，接口契约不变 |
| 两颗药丸只改了一颗 | 阶段 2 验收专项：发现→发现页签、已加入→已加入页签，两个落点都要验 |
| 创建信号只带 name 导致删除入口失效 | 载荷声明为 `CircleCreatedPayload` 显式 class，含 `creatorId`/`emoji`/`description` |
