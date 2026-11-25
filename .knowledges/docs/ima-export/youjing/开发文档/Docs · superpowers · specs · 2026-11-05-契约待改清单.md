---
title: "Docs · superpowers · specs · 2026-11-05-契约待改清单.md"
id: markdown_cls1_798285c88467638f6a8dc28635ad6f33_cb0f482982ae4cbb4a1ecef8ac7d8f987526104239726721
kb: 有径-YouJing
folder: "开发文档"
media_type: 7
tags: []
source: ima
exported_at: 2026-11-23T14:52:37.917Z
---
# 契约待改清单 · 布局结构迁移（2026-11-05）

> 给谁：用户逐条确认。**我不改 `~/Pictures/有径/有径-设计底稿-v1/docs/DESIGN.md` 本体**，
> 只出清单；每条给「契约原文 / 迁移后实现 / 实测证据 / 建议改法 / 状态」。
> 证据全部来自本轮真机（Pocket 2，密度 3.125，屏高 2690px）与 `uitest dumpLayout` 节点真值。

## 结论先说

四条里 **两条已落地（C4、C2——C2 是 2026-11-06 续 205 补的 `barWidth` 三档）**、
一条被真机证伪（C3）、一条停在真人检查点（C1）。
所以这份清单不是"照抄有据"的流水账，
而是把「有据的哪一条在鸿蒙官方件上真的成立」逐条量过之后的结果。
**C2 还留了一条自我纠正**：初版把它判成"实现改不动、契约该跟着读数改"，
实际是漏设了 `barWidth` 这个输入——判据只验了症状（切页跳宽）没验绝对宽度，已改正。

> **2026-11-07 全量对齐：C5–C8 的「保 B（留 16 / 留 44 / 保 tint+描边 / 保 48·21）」裁决已被用户推翻**，改按有据源码全量对齐（按钮 14、brandSolid+onBrand、36+responseRegion 44、44/18）。本清单历史正文与取证读数保持不变；完成度判据见 `Docs/superpowers/specs/2026-11-07-表现层全量对齐-差异表.md`。

---

## C4 · 底部避让量按导航方式派生 —— 已落地，建议契约补一句

| 项 | 内容 |
| --- | --- |
| 契约原文 | `layout.floating-dock-bottom-margin: 28px`，注释「28px above the system nav inset」（DESIGN.md:235 / :1013） |
| 迁移前实现 | `barBottomMargin = 28 + navIndicatorHeight`（只看高度，把契约那句话当成"再加一档"） |
| 迁移后实现 | `barBottomMargin = 28 + dockNavInset`，`dockNavInset` 由 `utils/navMode` 单源发布：手势档 **0**、三键档 `栏高+1`、悬浮球档同三键（`utils/navInset` 纯几何，5 例 hypium 钉住） |
| 实测证据 | 真机 settings `float_navigation_info` 报 `showType=-1`（手势）⇒ 避让量 0，dock 板从 `[55,2340]` 下移到 `[55,2427]`（正好 −27.84vp 的垫高被撤掉）；模拟器无该键、走 avoidArea 兜底，指示条 94px=27.85vp 但底部是居中胶囊（实量 376px=111.4vp，占屏宽 28.5%）⇒ 宽度判据判成非三键、避让量 0，dock 距屏底 27.9vp=基线 28 |
| 建议改法 | 契约那句 "28px above the system nav inset" 是歧义源（读成"再加一档"就多出 27.8vp）。改成：**"28px 基线，另加系统导航栏实际占位；全面屏手势下该占位为 0"** |
| 状态 | 已落地（`61e73e4`），第 19 把尺 `tools/audit_inset_source.py` 钉住不变式 |

## C2 · dock 尺寸 —— 契约不用改，**实现要改**（本条结论已被续 205 推翻并改正）

| 项 | 内容 |
| --- | --- |
| 契约原文 | `Floating dock 300 × 64px`（DESIGN.md:234 / :1013 / :1106），`floating-dock-side-margin: 16px` |
| 迁移前实测 | dock 板 `[55,2427][1081,2602]` ÷ 3.125 = **328.3 × 56vp**，左右各离边 17.6vp |
| 2026-11-06 续 205 实测 | 补 `barWidth` 三档后 `[99,2427][1037,2602]` = **300.2 × 56vp**，与有据逐像素相同 |
| 当初写错的话 | 「这个尺寸不是 token 算出来的，是官方件自己排的，`floatingDockWidth: 300` 全仓零消费点、只是契约镜像，改 `barSideMargin` 只会挪中心」——**错在把"没设输入"当成了"没有输入"**。`barFloatingStyle.barWidth` 就是入口，有据一直用它（`Index.ets:2007` `smallWidth: DOCK_WIDTH_SMALL`），所以它的板是 300.2vp 而不是 328.3vp |
| 建议改法 | 契约**不改**（300 是对的，是我们没实现到）。已按有据补三档：`smallWidth: floatingDockWidth(300)`、`mediumWidth: bp==='sm' ? 420 : 560`、`largeWidth: 560`，两个新档位值进 `LayoutTokens.floatingDockMediumWidth / floatingDockWideWidth` 并注明理由 |
| 状态 | 手机档已落地并逐像素核对（续 205）；**md 档未量**（设备被真人接走），表达式与有据逐字相同 |
| 附带纠正 | 有据侧高度也是 56vp 而非契约的 64px（两边同由官方件产出，非差异项）；`floatingDockWidth` 这个 token 从"镜像读数"回到**输入值** |

## C3 · 状态栏带子归谁 —— 真机证伪，契约保持原样

| 项 | 内容 |
| --- | --- |
| 契约原文 | 顶栏是四处玻璃面之一，系统栏不参与材质（DESIGN.md:1067 要求材质激活时"zero out its own background, border, and shadow"） |
| 迁移尝试 | 按 spec 的「无带子概念」：`ChromeSpec` 加 `barBackground`，撤掉 `pages/Index` 根 Column 那道按页签涂色 |
| 实测证据（同机位、每行中位灰阶） | 批准基线：0..281px 全程 **L=55/56**；改动后：**50/48/43/41/36/26** 的透底图渐变；回退后复拍：**54/56/54/55/56** 回到基线。机制在 dump 里——`barBackground` 给实心色时 `TitleBar` 节点仍是 `#00000000`，`HdsNavigationBackgroundStyle.backgroundColor` 没落成不透明层；地图 `XComponent` 从 y=281 起排，106..281 这段以前正是被壳层那道不透明涂色盖住的 |
| 结论 | **壳层涂色不是多余的第二个图层，它就是顶边基色的实现点。** 带子色"移交栏体"在官方 HDS 栏上做不出来 |
| 建议改法 | 契约**不改**。可以在契约里补一句实现约束："顶边基色由视图层的一层不透明底实现（本仓为 `pages/Index` 根容器按页签涂 canvas/map_strip_base），栏体保持透明" |
| 状态 | 功能改动已回退；证伪写进 `HdsChrome` 与 `pages/Index` 的注释 + `Docs/INIT_REPORT.md` §5ci 续 198（`6c750b0`） |

## C1 · 顶栏跟手收起 —— 停在真人检查点，未合入

| 项 | 内容 |
| --- | --- |
| 契约原文 | 顶栏常驻 + 两态磨砂（`scrolled ? blur 50 : 0`，按**绝对偏移**门控，DESIGN.md:1067） |
| 有据行为 | `dynamicHideTitleBar({ mode: SCROLL_UP_TO })` 跟手收起 |
| 为什么没做 | ① 前提与 C3 撞车：`dynamicHideTitleBar` 必须配 `enableComponentSafeArea=false` 才不会让内容跑 2.2 倍速（真机踩过，`hideRatio` 治不了），而 `false` 就是"穿底"形态，动的正是 C3 刚证伪的那块顶边几何；② 这一层脚本无法自证——注入 fling 不触发 HDS 滚动特效，脚本复拍只会得到"两态一样"的假绿 |
| 要真人跑的一格 | 五格各滚到底再回顶：顶栏收起有无跳变、内容位置是否抖、地图格顶边是否退回渐变；深色/浅色各一遍（夜间自动深色会让走查悄悄只覆盖一档） |
| 建议改法 | **等这一格验过再谈契约**。如果穿底代价是 C3 那条硬台阶回来，就不该改契约，而是承认"有径的顶栏常驻"是官方件约束下的正确形态 |
| 状态 | 未执行（任务 #26），计划 Task 8 的执行结论已记（`1f53115`） |


---

## 第二批待确认（C5–C8）· 2026-11-06 续 212/213：有据与有径的**契约**互相不同意

这四条并排放看得出来，但**不是 有径 没实现**——是 有径 的 DESIGN.md 把值钉死了。
逐条请用户拍：**(A) 有据赢**（我改实现 + 同笔改契约 + 逐屏复拍）或
**(B) 这是 有径 的品牌表达**（我在覆盖对表标「有意偏离」，不再当欠账挂着）。

### C5 · 按钮标签字档：有据 14，有径 16

| 项 | 内容 |
| --- | --- |
| 有据 | `design/components/DesignButton.ets:91` = `TypeTokens.callout.size` **14** + `headline.weight` 600 |
| 有径 | `components/YoujingButton.ets:54` = `TypeTokens.body.size` **16** |
| 钉住有径的原文 | DESIGN.md:922 `body / sans / 16 / 400 / 24 → Option labels, descriptions, input text, **buttons**`；:809 另按「a 16px semibold label does not qualify as WCAG large text」论证过实心主钮的文字对比度（白字 3.65:1 会挂，所以走 `#121212`） |
| 影响面 | 全 App 每一颗按钮；改 14 等于几十屏同时变，且 :809 那段对比度论证要重算 |
| 我的倾向 | **保 B（留 16）**：契约里有对比度论证在前，不是随手写的值 |

### C6 · 选中胶囊的表面：有据实心品牌色，有径淡底 + 描边

| 项 | 内容 |
| --- | --- |
| 有据 | `design/components/ChipRow.ets:80` 选中 = `brandSolid` + `onBrand` 白字；未选 `:81` `sunken` |
| 有径 | `pages/TripInputPage.ets:561` 选中 = `primaryTint` + `ink` 字 + `:562-565` 1px `primary` 描边（`components/OptionCard.ets:67` 同配方） |
| 钉住有径的原文 | DESIGN.md:440-444 `selectedBackgroundColor: primary-tint` / `selectedTextColor: ink` / `selectedBorder: 1px solid primary` |
| 可见后果 | 有径的「当前选中」重量明显更轻，扫读时更容易以为没选中——**四条里唯一我觉得值得重看的** |
| 我的倾向 | **待用户亲眼比**（同屏看筛选行即可判，不需要装机） |

### C7 · 胶囊高度：有据 36，有径 44

| 项 | 内容 |
| --- | --- |
| 有据 | `ChipRow.ets:23` = `LayoutTokens.segmentedHeight` **36**，横向 `item`=12，圆角 `sm`=10（方片） |
| 有径 | `TripInputPage.ets:557` = `LayoutTokens.minTouchTarget` **44**，`ButtonType.Capsule` 全胶囊 |
| 钉住有径的原文 | DESIGN.md「Min touch target 44 × 4px — even when the drawn glyph is 12px」 |
| 我的倾向 | **保 B（留 44）**：收到 36 会破命中区，这是无障碍硬线 |

### C8 · 空态规格与「件写了没接」

| 项 | 内容 |
| --- | --- |
| 有据 | `design/components/EmptyState.ets:30/36` 图形 `IconTokens.empty` **44** + 标题 `headline` 18 serif + 均等 12；被 **12 个文件**消费 |
| 有径 | `components/EmptyState.ets:82/86` 图形 `IconSizes.display` **48** + 标题 `title` 21 serif；**`EmptyState(` 消费方 0**，各页内联（如 `TripsPage.ets:603`） |
| 钉住有径的原文 | 有径图形档封闭为 **22/48**，44 是命中盒不是图形档（`EmptyState.ets:29-30` 写明） |
| 两件事要分开 | ① 48/21 vs 44/18 是档名冲突（倾向保 B）；② **件写了没接**是有径自己的问题：各屏内联会各自漂移。接件对 TripsPage 是像素中性（件与它同规格），对其他屏要逐屏复拍 |

### C9 · 卡面内缩（有径内部不一致，已做成尺）

有据通用卡钉 16（`BaseCard.ets:12`；注意它自己的 `cardTokens.CARD_PADDING` 是 0 消费点、
`PublishSection.ets:23` 又覆盖成 12，所以**别照抄它的实现，只对齐到 16 这个值**）。
有径同一个 `RadiusTokens.card`(20) 配了多档内缩：**23 处 sm(12) + 1 处 xs(8) + 6 处无具名 = 30 处偏离 base(16)**。
这条与「跟不跟有据」无关，是有径自己同一种卡两屏跳 4vp。
判据已钉进第 20 把尺 `tools/audit_card_inset.py`（自测阳性 2 / 阴性 4，含 `.padding(0)` 满铺豁免样本），
收口 = 该尺归 0，见任务 #34。**2026-11-06 续 214 已按契约改完 23 处**（18 处单参 + 5 处对象式，sm(12)→base(16)），尺读数 **30 → 5**；剩 5 处要逐处读（`EditItineraryPage:424` xs=8、`ItineraryPage:1297` 字面量、`TripMapView:319`/`ItineraryPage:735`/`SpotPickPage:547` 内缩在子级）。另给尺补了两条例证式豁免：按钮链（`.buttonStyle(`/`.type(ButtonType`）与面板 (`sheetPanelPadding`=20)。**逐屏 bounds 复拍仍未做**（模拟器已停、手机在真人手里），只有静态护栏（label-fit/geometry/button-width/a11y/scroll-actions 全 0）+ 构建闸；复拍若不合适就 revert 那一笔。

---

## 顺带发现的契约外欠账（不属于本次迁移，登记）

1. ~~`Bottom scroll reserve 94px + nav inset`（DESIGN.md:1014）与实现里的 `bottomScrollReserve: 94`
   同样有 C4 那句歧义的坑，但只有 2 处消费点（TripInput / PreferenceQA），影响面小。~~
   **已结案（2026-11-06 续 204）**：两处都改成 `bottomScrollReserve + this.dockNavInset`
   （`@StorageLink` 单源键、build 内直读），第 19 把尺扩 **R3** 钉住这条不变式
   （先跑红抓到那两处裸 94，改完转绿）。手势档下 94+0 与旧值恒等，所以本机像素不变；
   三键档补回 27.84vp，末行不再藏进 dock 底下 18vp。其余 26 处
   `floatingDockClearance: 112` 是最大档上界，任何档都盖得住，不属本尺范围。
2. `floatingDockClearance: 112` 是"最大档上界"，不是按档派生。按档派生需要 24 处消费点
   都能直读 `dockNavInset`，那是独立一轮（现在按 84 钉会在三键档把末行压进 dock 底下 28.8vp，
   这是算术）。
   **2026-11-06 续 204 复查澄清**：上面那句「现在按 84 钉…」把**假设**写成了现状，读起来像
   当前实现差 28.8vp；实际当前 112 = 28(`barBottomMargin`) + 27.84(三键避让) + 56(栏高)，
   也就是**三键档零余量**（末行正好顶在 dock 上沿，缺呼吸位），手势档反而多 28vp。
   **有据的写法是按档派生 + 一个间距档**：
   `PublishModePanel.ets:139` = `DOCK_BAR_HEIGHT_VP + DOCK_BOTTOM_MARGIN_BASE + bottomNavInset() + SpaceTokens.xl`
   ⇒ 手势档 108、三键档 135.84。**移植提醒**：有据的 `SpaceTokens.xl` = 24，在有径对应的是 `SpaceTokens.lg` = 24——两 App 的间距档名差一格（见 §5ci 续 210 对照表），照字面写成有径的 `xl` 会多 8vp。对照有径恒 112：手势档比有据松 4vp（像素级看不出），
   三键档比有据紧 23.84vp（末行贴玻璃、无呼吸）。
   **为什么不随手改**：26 个消费点每处都要挂 `@StorageLink` 并在 build 内直读，且会把**用户手上
   这台手势档**的每一屏底部收 4vp——这属于"改完必须逐屏量 bounds 反证"的批量布局改动，
   而真人现在不在、走查闭环断了（见 [[verify-batch-edits-by-measuring]]、[[feedback-green-rulers-not-ui-quality]]）。
   等下一次可以逐屏实拍时连同 #27 观感一起收，公式与两处对照读数已经在这儿。
3. `tab_glow_size`（帧写 180 环境光晕，实现按单格 68×56）与 `question-progress-dot`
   两条仍在 `audit_geometry.py` 的"显式不进 token"清单里挂着待裁决。
