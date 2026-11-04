# 结构化帖子「可核验阅读」重设计

> 日期：2026-11-05
> 状态：待用户批准（批准后进入实现计划）
> 范围：详情页结构化帖子渲染层重做 + 发布编辑器移除数字块入口。数据协议与后端零改动。

---

## 一、意图与为什么

### 1.1 竞争定位（本设计的唯一纲领）

「有据」与横向竞品（小红书/知乎/什么值得买）的差异化不在排版，而在**内容标准**：

> 主张 → 证据 → 可证伪。竞品的内容生产逻辑是流量激励（说错零成本），有据的逻辑是证据激励（可信度有回报、说错有代价）。

本次重设计的唯一目标：让结构化帖子的详情页成为这条标准的**表达**，而不是装饰。每一个 UI 元素必须回答「它表达了标准的哪一部分」，表达不了的一律砍掉。

### 1.2 三个机制与现状底子

| 机制 | 现状底子（已核对） | 本次动作 |
|---|---|---|
| 证据链 | V2 协议每块可挂最多 6 条证据（截图/出处+说明），`structuredDocument.ets:19`；当前藏在「据 N」胶囊后，阅读动线里没人用 | 提升为阅读标配：可验论点标记 + 验货层 |
| 社区校准 | `PostRatingPill` 多人真实评分，已挂在标题旁（2026-10-29 用户拍板位置） | 保留原位，不挪动、不重复 |
| 可证伪 | 举报链路已有 | 一期不做字段级证伪，记入二期 |

### 1.3 为什么砍「关键数字」

metric 块是作者自填的裸数字（`value`+`unit`），无出处、无口径、无校准。它制造的「同体裁第 N 名」是垃圾进垃圾出的幻觉排名。帖子里唯一可信的数字是社区评分（多人校准）。结论：**删除 metric 块**（详见 5.1）。

---

## 二、目标 / 非目标 / 反目标

### 目标

1. **零卡片化**：结构化区从「N 张描边底色卡」改为纯排版层次（hairline 分隔），信息一行不删，装饰层全撤。
2. **可验论点**：块挂了证据 → 论点文本带可验标记（品牌色 + 「据」角标），点击弹出验货层（出处/截图/口径）。
3. **体裁动线**：测评/避坑/教程/辩论各自有版式（判词先行、步骤即正文、对决合一），骨架外块回退通用行。
4. **删除关键数字**：编辑器移除 metric 入口，存量 metric 块渲染降级为普通行。
5. **实用出口**：步骤打卡保留、清单 chips 点击搜索、对照块扫读优化。
6. **消重**：辩论体裁的 compare 块与投票面板合一；「同体裁数字对比」入口随 metric 退场（存量帖保留）。

### 非目标（明确不做）

- 全站同体裁榜单 / 精准筛选排序（二期，依赖可信数据积累）
- 单论点「可信/存疑」反馈（二期，需新表新接口）
- 清单级收藏、字段级引用（二期）
- V1 旧字段帖（无 structuredDocument）的渲染改造——`StructuredFieldBlock` 路径原样保留
- 数据协议变更、后端接口/校验变更、数据库变更
- 发布编辑器的其他改版（仅移除 metric 入口 + 骨架文案同步）

### 反目标（出现即失败）

- 正文被结构化区推到两屏之外（现状问题，必须反转）
- 页面上出现无出处的大数字
- 用折叠/隐藏来制造「不臃肿」的假象（用户明确：多不是痛点，臃肿才是）
- 每块重复「类型名+默认标题」式的 meta 行

---

## 三、备选方案（已讨论，含取舍）

| 方案 | 内容 | 结论 |
|---|---|---|
| A1-A5 补丁 | 保留通用卡片渲染，减装饰、去重复、加交互锚点 | 否。不解决根因：渲染器对体裁无立场，块是静态终点 |
| 速览面板 | 所有块压缩为顶部 key-value 表 | 否。抹平块版式差异（回到 9-18 方案批判过的「统一两列表」），步骤打卡无处安放，与「信息不删」冲突 |
| 结构化即正文 | 取消结构化区，块按类型织入正文流 | 不独立成立。作者编排感消失、结构化「不可见」。其排版语言（无卡片、纯排版）被本方案吸收为视觉层 |
| **体裁版式 + 可核验阅读**（采纳） | 块按「类型+体裁」映射到版式槽位；全区零卡片；可验论点+验货层；判词先行 | 数据层早已按体裁分派白名单（`structuredBlockTypesForGenre`），渲染层接住即可 |

---

## 四、信息架构：体裁槽位映射

### 4.1 渲染输入

- `StructuredDocument`（V2，blocks ≤ 8，5 种类型）+ `genre`
- V1 旧帖（无 document）走现有 `StructuredFieldBlock`，不在本设计范围

### 4.2 槽位表（数组顺序即页面顺序）

槽位匹配规则：**每个体裁按表中槽位顺序扫描 blocks，每个槽位取第一个「类型匹配且有内容」的块**；同一槽位类型出现多个块时，`primaryBlockId` 指向者优先，其余与未匹配块一起进兜底行。版式顺序由体裁定义，不随 primaryBlockId 改变。

| 体裁 | 1 判词区 | 2 | 3 | 4 |
|---|---|---|---|---|
| 测评 review | insight 判词（衬线大字） | compare 优缺点对照（双列色条） | list 清单 chips（可点搜索） | 兜底行 |
| 避坑 pitfall | insight 教训 | steps 正确做法（打卡步骤流） | list 注意清单 chips | 兜底行 |
| 教程 tutorial | insight 要点 | list 物料 chips | steps 步骤（即正文：打卡+进度+大序号） | 兜底行 |
| 辩论 debate | compare 对决台（A/B + 投票合一） | insight 立场 | 兜底行 | — |
| share/无骨架 | 全部块按出现顺序走兜底行 | | | |

规则：

- **兜底行**：未进槽位的块（含存量 metric 块、未知类型）渲染为无卡片行——标题行合一（有自定义 title 显 title，否则显类型名）+ 正文 + 「据 N」链接，块间 hairline 分隔。
- **块的 helper**：阅读侧不再渲染（编辑器保留字段）。
- **标题行合一**：任何槽位不再同时出现「类型标签 + 默认标题」；判词槽只留 overline 类型字（如「结论」），块 title 舍弃（默认标题与类型语义重复；作者自定义 title 长期看应并入判词文本——本期直接舍弃，记入风险）。

### 4.3 槽位版式明细

**判词区**（insight 为 primary）：
- overline 类型字（结论/教训/要点），letterSpacing 2，accent 色（保留现有 warm/cool 主题 accent 逻辑）
- 判词文本：衬线、headline 字号、行高宽松
- 有据 → 文本后缀「据 N ↗」链接（accent 色，点击开验货层）；无据 → 素文

**对照槽**（review 的 compare）：
- 双列 + 中间竖 hairline；每列：列头 label（11px overline）+ 值（左侧 2px 色条）
- 语义色规则：label 精确等于「优点」→ success；精确等于「缺点」→ danger；其余 → brand。**不做模糊匹配、不猜左右语义**
- 侧值有据 → 该侧值带可验标记

**清单槽**（list）：
- chips 行沿用现有 `chipRow` 样式（brandPress 字 + subtle 底 + pill）
- chip 可点 → 跳转搜索该关键词（复用 `utils/nav.ts:94` 的 `openSearch(keyword)`）

**步骤槽**（steps，教程/避坑）：
- 步骤即正文：无卡片，序号球（衬线数字）+ 文本 + checkbox（`stepCheckStore` 打卡逻辑原样保留）
- 首行进度（已完成 N/M）仅当 checkInPostId > 0（预览页无 postId 不出进度，现有 `canCheckIn` 逻辑）
- 步骤块有据 → 块标题行给「据 N ↗」

**对决槽**（debate 的 compare + 投票合一）：
- A/B 两侧大字对照（左右 label + 值），中间竖 hairline
- 两侧下方各自票数条与「投票」动作。**接线方式**：`StructuredFlowView` 新增**可选** props——票数快照（planAVotes/planBVotes/myVote）与 `onVote` 回调；请求与回滚仍由 DetailPage 持有（现有职责划分不变），`DetailPostContent` 把已有的 `debateVoteStore` 投影 @State 与 `onVote` 透传给 `StructuredFlowView`。props 缺省时（发布预览页）对决槽只渲染静态对照、不出投票行——与当前预览行为一致
- `DetailPostContent` 的 `debatePanel` 收窄为**仅 V1 辩论帖**（无 structuredDocument 且 genre==='debate'）渲染，`debateValue` 为 V1 保留；V2 辩论帖由对决槽接管，方案文案只出现这一次

---

## 五、关键决策明细

### 5.1 删除关键数字（metric 块）

| 位置 | 处置 |
|---|---|
| 后端 `BLOCK_TYPES`（`structuredDocument.ts:10`） | **不动**。全局白名单保留 metric → 存量帖编辑重提仍通过校验，后端零改动 |
| 后端 metric 专项校验（L114-131） | 不动（存量兼容需要） |
| 前端编辑器 `StructuredComposer` | 移除 metric 类型入口（类型选择器 + `metricKindChips` L262/L286-311）；`structuredBlockTypesForGenre` 的 review/debate 列表去掉 'metric'；两条体裁骨架重做（去数字块）。已知取舍：发布页切体裁会触发 `filterStructuredDocumentForGenre`，metric 出白名单后被切掉的存量 metric 块会静默清除——与现状其他类型块切体裁被清的行为一致，接受 |
| 存量 metric 块渲染 | 降级为兜底行（不再大字头条）；编辑存量帖时允许保留该块（作者不主动删不强删） |
| 派生列 `metricValue/metricLabel/metricText` | 停止回填。存量帖有值 → 「同体裁数字对比」入口保留可看；新帖无值 → 入口自然不出现（`DetailPostContent` L324 条件不变，零代码删除） |
| `PostCompareSheet` | 保留（存量帖仍在用），不迭代 |

### 5.2 可验标记与验货层

- **判定粒度 = 块级**：证据挂在块上（`evidenceOf(block)`），不假装条目级。块有证据 → 该块主文本带可验标记。
- **可验标记**：论点文本用 accent 色 + 文本尾部「据 N」小角标（10-11px，pill）。**不使用虚线下划线**——ArkUI `TextDecorationType` 只有 None/Underline/Overline/LineThrough，无虚线型；降级成本高的 per-side dashed border 属于实现期核对项，默认不做，角标为定案。
- **验货层**：复用现有 `bindSheet` 半模态结构（`StructuredFlowView.evidenceSheet` 原样保留，改标题为「验一验 · {论点}」）。内容：出处条目（type=source：出处 pill + ref + note）/ 截图条目（type=image：图 + note）。验货层标题取来源块的自定义 title（为空时：对照/对决槽用「A/B 对照」，其余用类型名）。
- 长按结构化区「复制正文」菜单保留（挂在区容器，现有 `contentLongPress` 链路不动）。

### 5.3 判词区与评分的关系

- 社区评分胶囊**留在 `DetailPostHeader` 原位**（2026-10-29 拍板「放 Title 附近」），判词区不重复渲染评分。
- 判词区 = 类型字 + 判词文本 + 据链接，最多三行。

### 5.4 正文顺序

维持现状：媒体 → 结构化区（判词先行）→ 作者正文 → 评论区。判词先行是「先结论后依据」的产品调性；零卡片化后结构化区高度大幅下降，正文回到第一屏。

---

## 六、视觉规范（排版语言）

- 全区零卡片：无底色、无描边、无独立圆角；块间 `ColorTokens.separator` hairline 分隔（现有 `Divider`/1px 线）。
- 强调只用三种：accent 色（类型字/据链接/序号球/勾选）、语义色（优缺对照 success/danger）、衬线字重（判词/大字）。
- warm/cool 主题（`document.theme`）保留：作用于 accent 色与判词引文色，不再有整块底色（现有 `surfaceColor` 双主题成对资源逻辑收窄到 accent）。
- 深浅色与大字号：沿用 ColorTokens/TypeTokens，不引入写死色值；对照块色条 2px + 文字标签并存（不只靠颜色，WCAG 1.4.1）。

---

## 七、组件与文件影响面

| 文件 | 动作 |
|---|---|
| `components/StructuredFlowView.ets` | 重构内部：`blockCard` 卡片制 → 槽位分派（判词/对照/清单/步骤/对决/兜底）+ 验货层。**新增可选 props**（票数快照 + `onVote`，缺省不出投票行），原 `document` / `checkInPostId` props 不变；`PublishPreviewPage.ets:599` 复用自动跟随（预览无 postId → 无打卡进度、无投票行，现有 `canCheckIn` 已处理） |
| `components/DetailPostContent.ets` | `debatePanel`/`debateValue` 收窄为仅 V1 辩论帖渲染（V2 对决槽接管）；`compareEntry` 条件不变；V1 分支其余不动 |
| `components/StructuredComposer.ets` | 移除 metric 入口与 metricKindChips；review/debate 骨架重做 |
| `utils/structuredDocument.ets` | `structuredBlockTypesForGenre` 去 metric；其余不动 |
| `utils/stepCheckStore.ets` / `debateVoteStore.ets` | 原样复用，不改动 |
| 后端 | **零改动** |

预览页（`PublishPreviewPage`）不需要独立改动（组件级复用），验收时纳入回归。

---

## 八、边界与错误处理

| 场景 | 行为 |
|---|---|
| blocks 全空 / schemaVersion < 2 | 不渲染结构化区（现有 `visibleBlocks` 逻辑保留） |
| primaryBlockId 缺失或指向空块 | 按 4.2 槽位规则兜底：每槽位取第一个「类型匹配且有内容」的块，primary 仅在同类型多块时决定优先 |
| evidence 截图 URL 失效 | Image 加载失败占位（现有 Image 组件默认行为），出处文字仍在 |
| debate 无票 | 票数条 0 宽度 + 「投票」可点（迁移自现有 voteRow 行为） |
| 存量帖含 metric 块 | 兜底行渲染；作者编辑时保留该块，重提后端校验通过（白名单未删） |
| 骨架外自由组合（作者手动加了非骨架类型块） | 一律兜底行，不报错 |
| 分享体裁 | 无结构化区，行为不变 |

---

## 九、测试与验收

- 后端 jest 全绿（零改动确认）；`npx tsc --noEmit` 过（如现有脚本门禁含它）。
- 前端 `assembleHap` 构建成功（交付门禁，不可只跑既有测试）。
- 真机验收清单（Pocket 2，深浅色各过一遍）：
  1. 测评帖：判词先行、优缺点对照色、chips 可点搜索、正文在第一屏可见
  2. 教程帖：步骤即正文、打卡勾选与进度持久、预览页无进度条
  3. 辩论帖：对决台投票一次成功、票数即时反映、无重复方案文案
  4. 避坑帖：教训判词 + 步骤正确做法动线
  5. 存量 metric 帖：数字降级为普通行、对比入口仍可看（有值时）
  6. 无据帖：全区无可验标记、无「据」入口
  7. V1 旧字段帖：渲染与改版前一致
  8. 长按结构化区 → 复制正文菜单正常

---

## 十、二期记账（本期不做，防止范围蔓延）

1. 全站同体裁榜单（帖子变数据行的网络效应）
2. 单论点「可信/存疑」反馈（需新表 + 接口 + 审核面）
3. 清单级收藏 / 字段级引用
4. 分享海报带判词卡（复用文字海报链路，单独方案）
5. metric 派生列的彻底清理（数据迁移脚本）

---

## 风险

| 风险 | 对冲 |
|---|---|
| 判词槽舍弃块 title：作者认真写的自定义标题会丢显示 | 判词槽以 insight.value 为主文本；若实现期发现存量帖 title 与 value 明显分工（title 短句、value 长文），兜底行规则已覆盖非 primary 块；primary 的 title 可作判词下方小字副题，验收时真机定 |
| 证据覆盖率低 → 可验标记稀疏，钩子感知弱 | 编辑器侧的软校验与模板引导属后续迭代；一期先把「有据就显著」做对 |
| 骨架重做影响发布转化 | 骨架只删数字块、字段提示文案不动，改动面小 |
| ArkTS 严格模式（禁解构、具名 interface） | 实现期沿用工程既有写法，构建门禁把关 |
