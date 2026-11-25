---
title: "Docs · design-v2 · README.md"
id: markdown_cls1_798285c88467638f6a8dc28635ad6f33_21b87500ba24d5011dc395b7dd1326ad7526104239726721
kb: 有径-YouJing
folder: "开发文档"
media_type: 7
tags: []
source: ima
exported_at: 2026-11-23T14:52:37.917Z
---
# design-v2 · 契约 v2 镜像快照（2026-11-02）

> 本目录是家族契约文档 **契约 v2** 的**镜像快照**（以「有据」为参考实现的对齐口径），防仓库外单点丢失。
> 按 `Docs/design-v1/README.md` 的规矩「底稿升版（v2）后另建 `design-v2/` 快照目录，不覆盖 v1」新建，
> `Docs/design-v1/` 已还原为 2026-10-26 的 v1 原文并冻结不再更新。
> 原件与后续更新仍在：`~/Pictures/有径/有径-设计底稿-v1/docs/`（底稿目录共约 9 MB，
> 含帧截图等资产，不在本快照范围内）。

| 文件 | 角色 |
|---|---|
| `DESIGN.md` | 色板 / 字阶 / 几何 / 材质等设计契约本体（v2），`tools/audit_*.py` 的对表基准 |
| `youjing-engineering-handoff.md` | 工程交接稿：§7 逐帧必改表、§12 路由表、帧清单（文档中「handoff §N」均指此文件） |
| `youjing-stitch-prompts.md` | 39 帧的生成底稿（帧哈希 7fc1cb85、1ab099b1 等的出处） |

## 本版（v2）相对 v1 的差异

- `layout.glass-blur`：`"24"` → `"50"`，正文四处规范性表述（`components.top-bar-immersive.material`、
  §5 材质表 blur 行、§Layout 吸顶日分隔、§Components Floating dock）同步为 50。
- **分段控件按成文例外钉死**：`components.segmented-control.blur` 由引用 `{layout.glass-blur}` 改为显式
  `"20"`，§5 材质表那行不再自称 "the app's only blur radius"，并明写分段控件不是第五块玻璃面、20 只是组件内数值
  （与有据 `GlassTokens.ets:11 SEGMENT_BLUR=20` 同口径）。
- **§Elevation & Depth 的封闭名单按 R11 重写**：书面 blur 半径只属于**三个栏面**（①顶栏 / ②浮动 dock /
  ③吸顶日分隔，一律 50 + 1px `glass-bar-border` + 92px 渐变遮罩）；**④sheet 与菜单是「材质面」而非
  「blur 面」**——有系统材质时由材质接管，自绘兜底就是 `components.sheet-modal` 那套实色
  （`surface-elevated` + `floating` 影 + scrim），不新造 blur 值（与 `components.sheet-modal` 无 blur 键、
  §Components「Sheet (half-modal) … `surface-elevated` … floating elevation, scrim behind」自洽）。
- prompts 屏 11 / 11b 的分段控件行文（第 200、216 行）按 R12 由 `blur(50px)` 改 `blur(20px)`（组件内例外）；
  第 148 行（屏 8）是**同一行里既有顶栏也有分段控件**的那一行：顶栏那半句 `backdrop-filter blur(50px)`
  保持 50，分段控件那半句「(`glass-segment-border`), backdrop blur(50px)」按 R12 口径改成 `blur(20px)`——
  所以该行现在同时含 50 与 20 两个值，不再是"第 148 行 = 顶栏"一句话能概括的。
- **T3 折叠的四条口径修正**（随本批代码同批落，评审裁决「不该等批次二」）：
  `DESIGN.md` §5 材质表 blur 行的计数用词「the **four** bar surfaces share this one radius」→「three」
  （与 §1062 的 v2 名单对齐；809 标题与 811 引言按评审核对未动）；handoff 的三条**规范条目**
  §5 标题（226）、自查第 9 条（606）、§10 缺陷表「实现时应为」列（634）由 v1 的「玻璃四件含分段控件 /
  弹层不是玻璃」改按 R10/R11 重写（三处栏面书面 50 + 分段控件组件内 20 例外 + sheet/菜单是材质面、
  其自绘兜底为 `components.sheet-modal` 实色且不新造 blur 值）——同文件的实测/证据列（`.status-bar`
  的 `blur(24px)`、「其余三处 24」等）逐字节未动；prompts 843 全局规则块按同一口径整体重写
  （原文「four surfaces… 含 segmented control」「A sheet is NOT glass」与 R10/R11/R12 三向冲突）。
- handoff §10 缺陷表「屏 8 / 11 / 11b 分段控件模糊离档」行的**实现时应为**列按 R13 改写为
  「v2 作废：20 已升为 `components.segmented-control` 的组件内成文例外；三处栏面统一 50（ArkTS 走材质档位）」
  ——该缺陷在 v2 口径下不再成立；同行「渲染实测 `segmented-control: blur(20px)`，其余三处 24」是实测列，
  与 v1 原文逐字节相同，保持原值。
- **T3 round 2 的口径收口（N-1/N-2/N-3：上一轮只按行号点名改了一半，同一节下一行还在打脸）**：
  handoff §5 表体把分段控件列为玻璃面的那一行（231）、§5 的「**弹层（sheet）不是玻璃**」整句（235）、
  §6 组件表「弹层 sheet … **不是玻璃**」（253）改按 R10/R11 口径写成「材质面 + 实色兜底」；
  prompts 主提示词第 4 条（20）、§四「生成后自查清单（每屏对一遍）」的材质行（321，**逐屏闸门**，
  照旧文本会把 v2 正确的屏判不合格）、§〇 常驻框 v2 的 Chrome 条（349）的「四处玻璃」子句同批改齐。
  三处的**实测/数值证据（`blur(20px)`、`blur(24px)`、`scrollHeight=820`、`2.67:1`、阴影串等）逐字节未动**；
  prompts `271/1088/1154/1252/1286/1306/1410/1556/1661/1676/1713` 等历史记录行按 R5/R8 不回写。
  `DESIGN.md` 本轮**零改动**（md5 未变），§5 标题 809「four surfaces, and only four」与 811 引言仍按评审核对
  保留——它数的是「材质面」集合（顶栏/dock/吸顶/sheet），与 1062 的 ①②③④ 同序，不是「四处都带 blur」的旧口径。
  `tools/audit_material.py` 的 docstring 与收尾 print 同步改称「三处栏面 blur + ④材质面」，判据行为与
  `[④材质面·sheet/菜单]` 标签一字未动；另修 `check_blur_value` 判据次序（N-5）：两态判据上移到
  「DESIGN 抓不到 glass-blur 就 return」的早退分支之前，与数值判据解耦，DESIGN 键名漂移时不再静默 rc=0。
- 新增 `layout.glass-bar-scroll-gated: "true"` 与 §Translucency 的门控口径：玻璃面由**绝对**滚动偏移
  （`scrolled ? 50 : 0`）驱动，禁止按帧增量驱动。
- 新增 `transitions:` 五键（page-enter / page-fade / feed-stagger-step / long-take / snapshot-handover），
  本批次只写进契约、尚无实现消费方。
- **历史记录与实测取证不跟随数值**：`DESIGN.md` 屏 4 状态栏 `blur(24px)` 那条违规实测记录、
  handoff §5「稿件屏 4 违规带了 `blur(24px)`」/ §9「稿件里的 `blur(24px)` 是 CSS 近似」/
  §10 缺陷表同样条目 + 「渲染实测 blur(20px)，其余三处 24」的实测列，以及 prompts 的 9 行既往
  实测 / 违规 / 缺陷记录（1081、1088、1090、1109、1252、1350、1548、1556、1661）均保持 24 ——
  帧未重切（39 帧 `code.html` 今日实测仍为 `blur(24px)`），改了就成篡改证据；1350 那条是逐字引用帧文件原文。

## 使用口径

- **审计脚本不指向本目录**：`tools/audit_colors.py` 等默认仍读原件路径
  `~/Pictures/有径/有径-设计底稿-v1/docs/DESIGN.md`（底稿搬家后传参即可）。
  快照落后于原件时不影响任何审计行为；如需比对，`diff Docs/design-v2/DESIGN.md <原件路径>`。
- 验收 grep 口径（固定）：`grep -n 'blur 24\|blur(24px)\|: 24\|统一 24'` 的命中里**只允许历史 / 实测类残留，
  规范性必须 0**。当前三份命中：`DESIGN.md:1197`（屏 4 状态栏实测违规记录）、handoff `237/627/634`
  （既往取证与实测列）、prompts 的 9 行记录，以及 prompts `973/988/999/1073/1288` 五条与模糊半径无关的
  `: 24`（节点 24px、`line-height: 24px`）——按模式属于过宽匹配，非玻璃数值。`统一 24` 命中 0。
  不以「出现次数 ≥ N」为门槛。
- **口径 grep 验收（R18，与数值 grep 并行、缺一不算验收）**：数值门槛抓不到「无数字的口径句」，所以另跑
  `grep -nE "四处|四类|exactly four|only four|不是玻璃|not glass|NOT glass"`，命中必须**逐条分类**为
  规范性 / 既往记录 / 无关用法，且**不允许有与玻璃口径相关的规范性句子仍写「四处」**。当前三份的命中分类见
  `.superpowers/sdd/2026-11-02-contract-v2-foundation/task-3-report.md` §「口径 grep 逐条分类」。
- 快照时间：2026-11-02（R11/R12/R13 最后一轮文档修正 + **T3 折叠四条口径修正** + **T3 round 2 的 N-1/N-2/N-3 口径收口与 N-5 尺子判据解耦**之后），原件 md5 见下。

  | 原件 | md5 |
  |---|---|
  | `docs/DESIGN.md` | `3fcc3a62edc7bc8ac3d782c9910d20aa`（本轮零改动，与 round 1 相同） |
  | `docs/youjing-stitch-prompts.md` | `f98d054dd272f7e3280d1f714188ff9c`（round 1：`6ea9e425…`） |
  | `docs/youjing-engineering-handoff.md` | `ad6fa4ea16a8c1a12f01a50d7b18e672`（round 1：`7139d0c4…`） |
