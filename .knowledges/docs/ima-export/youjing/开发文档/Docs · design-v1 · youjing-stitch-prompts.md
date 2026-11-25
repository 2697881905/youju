---
title: "Docs · design-v1 · youjing-stitch-prompts.md"
id: markdown_cls1_798285c88467638f6a8dc28635ad6f33_46b4bbd6e7d6ccce54c595153dfb7a547526104239726721
kb: 有径-YouJing
folder: "开发文档"
media_type: 7
tags: []
source: ima
exported_at: 2026-11-23T14:52:37.917Z
---
# 有径 · Stitch 提示词包

用法：`Design` 面板里，**一条提示词生成一屏**（Stitch 每次只稳定产出一到两屏）。顺序：先贴「主提示词」建立项目基调并生成第 1 屏，之后每屏只贴「分屏提示词」那一行，并保留 `Additional instructions` 里的硬约束不变。

---

## 一、主提示词（项目基调 + 第 1 屏）

```
Project: 有径 (Youjing) — an AI-driven travel itinerary planner for HarmonyOS NEXT. The attached DESIGN.md is a hard contract, not inspiration: every color, radius, spacing, type size, elevation and duration must be taken from its tokens. Invent no values, add no hue, add no letter-spacing.

Core product idea the UI must express: AI is the analysis engine, not the data source. Attractions and lodging areas come from a curated on-device database; the AI only filters, prioritises, routes and explains. So nothing may look like a chatbot improvising. Every recommendation shows its reason, its duration and its booking status as visible first-class data. The reference feeling is "a well-edited itinerary page", not "an AI output".

Platform: HarmonyOS NEXT phone, portrait, 360vp artboard width, 780vp tall. Light mode first. Status bar visible, bottom nav indicator reserved. Realistic Chinese content — a 5-day 京都 trip with actual temple, shrine and café names, plausible walk times and yen prices. No lorem ipsum.

Four signatures that must be present and consistent across every screen:
1. Route trace: a 2px #0066CC line with a soft 35% halo under it, threading numbered nodes (24px circle, white fill, #17171A ring, 10px inner dot tinted by activity type) over faint hairline contours on a white→#F1F2F5 paper gradient. No map screenshots, no stock photography.
2. Itinerary spine: 52px right-aligned tabular time gutter, one 2px vertical spine, nodes centred on it, stop rows ≥76px, 44px dashed transit legs that always show BOTH time and distance ("步行 18分钟 · 1.2km").
3. Option-based interview: a serif question, a muted helper line, then a stack of 56px selectable cards (20px radius, never pills). Selected = rgba(0, 102, 204, 0.10) tint fill + 1px #0066CC border + blue check, with the LABEL remaining near-black #17171A (never blue text on blue tint — it measures 4.49:1 and misses AA). Progress shown as 6px dots and an 11px "第 2/4 步" eyebrow. Absolutely no chat bubbles, no AI avatar, no typing indicator, no sparkle motifs.
4. Material discipline: blur/glass on exactly four surfaces — top bar, floating dock, sticky day header, sheets. Cards, timeline rows, option chips, reason blocks and widgets are flat opaque; separation comes from the surface ladder (#FFFFFF → #F7F7F8 → #F2F2F4 → #EFEFF2) and whitespace, never borders or shadows.

Color law: one action hue only (#0066CC, dark #0A84FF). Activity types reuse a closed five-hue set (景点 blue / 餐饮 #9A6206 ochre / 住宿 #5856D6 indigo / 交通 #3C3C43 graphite / 休整 #9E9EA3 grey). Text polarity flips by theme: light = white labels on deep fills; dark = #121212 ink on bright fills. #9E9EA3 is for disabled and placeholder text only (2.67:1 — it is below even the 3:1 graphic floor); a chevron that means "this opens" is #69696E.

Type law: Noto Serif SC (only 400 and 700 exist — no serif 500/600) for destination names, day labels, questions, section titles and long-form notes. HarmonyOS Sans for every operable or scannable string including all stop names. Letter-spacing 0 everywhere. Tabular figures for every number.

Screen to generate now — 1. 首启与静默登录 (first-run + silent Huawei login):
Full-bleed white canvas. Top area: the serif wordmark 有径 at 32/700, an 11px overline latin subtitle "TRACEABLE ROUTES", and a 14px tagline in #5A5A60 — "有迹可循，有径可行". Below it a single 20px-radius panel (#F7F7F8, 16px padding, 6px nested photo corner radius per the concentric rule) containing a 3-line preview of what a finished day looks like: 09:30 清水寺 / 10:45 二年坂 / 12:10 一番街 午餐 — each 12px tabular time in a 52px gutter against a 2px spine with small nodes, so the value proposition is shown as real structure rather than marketing copy. Bottom: one solid #0066CC pill CTA 44px "华为账号一键登录" with a white Huawei-id glyph, and beneath it an 12px #69696E legal line about UnionID and local-only storage. No secondary button, no carousel, no illustration.
```

---

## 二、`Additional instructions` 常驻框（每条生成都带着，不要改）

```
Hard constraints for every frame in this project:
- Phone portrait, 360vp artboard. Light mode. All spacing on a 4px baseline: 4 / 8 / 12 / 16 / 20 / 24 / 32 / 48. Page padding 16. Touch targets ≥44×44.
- Radius: cards 20, nested-in-card 6, chips/inputs 10, reason blocks 14, hero 28, dock + segmented 30, buttons + badges + avatars pill 999. Buttons are ALWAYS pill.
- Buttons: exactly one solid #0066CC primary CTA per screen, 44px tall; everything else is transparent with a 1px rgba(196, 196, 202, 0.40) outline. Never a second blue button on the same screen. Press = scale 0.97, 140ms.
- Chrome: title bar 60px; floating dock 300×64 centred, 30px radius, 28px above the nav inset; content reserves 94px + nav inset at the bottom.
- Type: 32/700/44 serif display · 21/700/32 serif title · 21/650/28 sans · 18/600/24 headline (all stop names) · 16/400/24 body · 14/400/20 · 12/450/16 caption · 12/600 itinerary-time · 11/600 overline · 10/400 dock label. Serif is never used on a control.
- Color format: CSS only. NEVER write an 8-digit hex — ArkTS `#AARRGGBB` (alpha first) is not CSS `#RRGGBBAA` (alpha last); the 8-digit literal 1A 00 66 CC read as CSS is a solid indigo block, not a 10% blue tint. All translucency is `rgba()`, taken from the DESIGN.md translucency ledger.
- Contrast: labels ≥4.5:1; icons, dots, route strokes ≥3:1. Never blue text on a blue tint fill. Never white text on a dark-mode bright fill.
- Dividers are 0.5px and only between like rows. Cards are separated by whitespace, not lines.
- Motion is described, not shown: press 140 / control 220 / container 320 / page 420 / route draw 460 / stagger 40 / skeleton shimmer 1200.
- Every AI output screen must visibly answer three questions: why this stop, how long it takes, does it need booking.
```

---

## 三、分屏提示词（按流程顺序，逐条粘贴）

### 2. 基础输入 · 一次成型

```
Screen 2 — 行程基础输入 (city + dates + party + budget). White canvas, no hero image.
Chrome: 60px title bar — a 44px back chevron at the left and the wordmark 有径 beside it in **HarmonyOS Sans 16/600/24 #17171A**. Nothing else in the bar; the page title lives in the content column.
Top of content: serif 21/700/32 page title 开启一次有迹可循的旅程, then a 14/400 #5A5A60 subtitle 设定出行基础参数，AI 将基于本地精选数据库构建动线, then a vertical stack of four field rows. Each field row: #F7F7F8 surface, 20px radius, 64px tall, 16px padding — left column has an 11px #69696E overline label and a 18/600 #17171A value, right side a 12px #69696E chevron inside a 44px hit box.
Fields in order: 目的地 (value 京都 · 日本, **sans** — it is a tappable field value, and the 前置块 rule "serif never on a control" outranks "serif for place names"); 出行日期 (value 6月10日 – 6月14日, sans, tabular, with 5天4晚 in 12px #69696E underneath); 同行人数 (value 2 位成人, plus three quick-picks 1 / 2 / 4 — each 44×44 hit box with a 24px visible pill inside, radius 999 allowed only because it is a badge-scale control, #F2F2F4 fill with #17171A text, the selected one rgba(0, 102, 204, 0.10) tint + 1px #0066CC border and near-black label); 预算档位 (value ¥8,000 / 人, and directly under the field a thin 4px horizontal budget track on #E9E9EC with a #0066CC filled segment, flanked by 11px #69696E endpoints 经济 and 舒适).
Bottom, floating above the dock area: one solid #0066CC pill CTA 开始规划. No other button. Everything is type-on-white; the only graphic on the page is the budget track.
```

### 3. AI 追问 · 状态机四题（风格 / 住宿 / 交通 / 节奏）

```
Screen 3 — 偏好追问状态机 (question 2 of the four-question interview, single-select). ONE frame only — the multi-select variant is its own send (3b). This is an in-app state machine, one question at a time, driven by buttons only; no chat affordances.
Chrome: 60px title bar — left 11px/600 #69696E overline 第 2/4 步, right 12px/450 #17171A 偏好追问; under the bar a 4px progress track filled 2/4 with #0066CC on #E9E9EC. The track is the only progress affordance on this screen: no dot row below the options.
Body: serif 21/700/32 question "这趟想怎么过？" plus 14/400 #5A5A60 helper "只影响推荐排序，随时可改". Below, five single-select option rows at 8px gaps: 休闲 / 暴走 / 亲子 / 美食 / 文化. Each row is #F7F7F8, 20px radius, min-height 56px, 16px padding, 16/400 #17171A label plus a 12px #69696E consequence sub-line ("一天 2–3 处，午后能坐下喝茶"). Unselected rows are flat and borderless. The 美食 row is selected and uses exactly one contract pattern — rgba(0, 102, 204, 0.10) wash + 1px #0066CC border + a 20px #0066CC check icon top-right, label stays #17171A; that border belongs to the wash pattern, it is not a decorative card outline.
Footer: the screen's single solid #0066CC pill 下一题 (44px tall, radius 999), and beside it two secondary buttons — 上一题 (transparent, 1px rgba(196, 196, 202, 0.40) outline, 14px #17171A) and 帮我选 (transparent, no border, 14px #5A5A60, 44×44 hit box, accepts the AI default for this question). The solid CTA is the only filled blue control on this screen, so no secondary button carries a blue label.

### 3b. AI 追问 · 节奏偏好（多选变体，第 4/4 题）

2026-10-14 发送前预检改了五处：① **`20px #0066CC check` 造了第三档图标**（两档口径之后第 5 处同类自伤）→ 22×22、viewBox 24、stroke-width 2。② `12px #A06400` 警告没钉底色 → 明写落在选项行自己的 `#F7F7F8` 上（实测 **4.54:1** 勉强过 AA），并禁落 `#EFEFF2`（4.24 不合格）。③ **底栏材质整段缺失**（屏 8/9/10 的老洞，变体屏更容易漏，因为正文只写「same footer law as screen 3」——**Stitch 看不见屏 3 的 CSS**）→ 配方就地写全。④ 顶栏玻璃与进度条补字面值与字重。⑤ 阴影按屏 11/16 口径声明「一条都不需要」。

```
Screen 3b — 偏好追问 · 多选变体 (question 4 of 4, 节奏偏好). ONE frame.
Chrome: 60px title bar on rgba(255, 255, 255, 0.44) with backdrop-filter blur(24px) and a 1px rgba(196, 196, 202, 0.40) bottom border — at the left an 11/600 #69696E overline 第 4/4 步, at the right 12/450 #17171A 偏好追问; below it a 4px progress track on #E9E9EC filled 4/4 with #0066CC.
Body: serif 21/700/32 #17171A 每天想排多满？, then 14/400 #5A5A60 可多选 · 选得越满，冲突越多.
Three multi-select rows at 8px gaps, each #F7F7F8 at radius 20 with `min-height: 56px` and `padding: 16px`: 每天 3 个活动 / 每天 4–5 个 / 每天 6+ 个, each carrying an 11/600 #69696E overline tag 轻松 / 标准 / 紧凑. The first two are selected with the single wash pattern — `rgba(0, 102, 204, 0.10)` fill, `1px solid #0066CC`, and a **22×22 check glyph in #0066CC** (viewBox 24, stroke-width 2, fill none) at the right; labels 16/600 #17171A. The third is unselected: flat #F7F7F8, no border, no check.
Under the third row's label sits 12/600 #A06400 可能偏紧，建议留白 — **on that row's own #F7F7F8 fill, where it measures 4.54:1**; never on #EFEFF2 (4.24:1 fails). Warnings are muted-earth, never red, because nothing has failed.
Bottom action bar: **flat opaque #FFFFFF, no translucency and no blur**, `padding: 12px 16px calc(16px + env(safe-area-inset-bottom, 12px)) 16px`, holding outline 上一题 (transparent, 1px solid rgba(196, 196, 202, 0.40), 16/600 #17171A) beside **this screen's only solid #0066CC pill** 生成行程 (44px, radius 999, #FFFFFF 16/600, press 140ms scale 0.97 onto #0055BB) — equal-width flex columns with `gap: 12px`. Scroll content reserves `calc(94px + env(safe-area-inset-bottom, 12px))`.
Of the six closed-set shadows this screen uses **none** — no shadow on the option rows, the check glyphs or the footer. Selection is carried by the wash + border + check; **no square checkbox control** (a square would read as a tag in this system, and a ninth control shape is not in the contract).
```
```

### 4. AI 追问第一轮 · 景点挑选与优先级

2026-10-14 发送前预检改过两处：整屏没定义底部 CTA（模型会自己补第二个蓝按钮），以及横幅、理由件的边条口径没写清。**当天稍后追述**：原稿那句 2px 蓝色左边条**不是**自伤，它正是 DESIGN.md `reason-block.leftRule` 要求的契约件；当时把它删掉是引用了前置块自查第 7 条的旧误判，该条已就地翻案（见 11.7）。下面这版正文里横幅**不带**左条，是一块已知偏差，等清理轮重生成补回。

```
Screen 4 — 景点选择 (attraction picker with priority marking). ONE frame only. This screen reads a curated on-device database; the AI only sorts and annotates.
Chrome: 60px title bar on the rgba(255, 255, 255, 0.44) glass — a 44px back chevron at the left, page name 选想去的地方 in HarmonyOS Sans 18px / 600 / line-height 24px #17171A, and at the right one text action 推荐更多 in 12px #0066CC inside a 44px × 44px hit box: transparent, no fill and no outline, it is not a second primary button. No step overline and no interview progress track on this screen; the capacity strip below is the only progress affordance.
Under the bar: a sticky 44px summary strip, flat opaque #EFEFF2 with no blur, carrying 12px/450 #5A5A60 "已选 7 / 可用 4.2 天 · 建议上限 16 个" in tabular numerals, and under that copy a 4px capacity track filled to 44% with #0066CC on #E9E9EC.
Then ONE advisory banner, because the days are tight: a #EFEFF2 panel at radius 14, 11px/600 #69696E overline 时间偏紧, 14/400 #5A5A60 copy 按现在的节奏，建议给景点标优先级，行程会自动取舍. Its fill is the only signal — no accent edge of any width or colour. Never red on this banner: it is advice, not an error.
Body: three tag sections, each opened by an 11px/600 #69696E overline (文化 · 4 / 美食 · 3 / 自然 · 2). Each row is a 76px list item on flat #FFFFFF, separated only from its sibling rows by a 0.5px rgba(60, 60, 67, 0.20) divider: a 3:4 thumbnail placeholder at radius 6 on #E9E9EC (no photo, no gradient), the name in HarmonyOS Sans 18/600/24 #17171A single-line with nowrap plus ellipsis, and beneath it 12/450 #69696E meta 东山区 · 建议停留 1小时30分钟. Exactly one row (二年坂) also carries a 需预约 badge: solid #A06400 fill, #FFFFFF label, 12/600, radius 999. At the right of every row a 44px × 44px hit box draws a 24px circle at radius 999 — unselected: transparent with a 1px rgba(196, 196, 202, 0.40) outline; selected: solid #9A6206 with a #FFFFFF 必 glyph at 12px. 清水寺 shows the selected state.
Footer: this screen's single solid #0066CC pill 确认选择 (44px tall, radius 999, press #0055BB with scale 0.97) beside 跳过选择 (transparent, 1px rgba(196, 196, 202, 0.40) outline, 14px #17171A, 44px × 44px hit box). The bar is a flat opaque #FFFFFF strip sitting at calc(16px + env(safe-area-inset-bottom, 12px)) — no translucent white, no blur, it is not one of the four glass surfaces — and scroll content reserves calc(94px + env(safe-area-inset-bottom)), so no button edge touches the 780vp bottom.
360px × 780px .device-frame, light mode, letter-spacing 0, and no `box-shadow` at all on this screen — none of the six closed-set shadows is needed here, so add none.
```

### 5. AI 追问第二轮 · 住宿区域精选与通勤分析

2026-10-14 重写（11.7 的翻案在这里落地）：理由件的 2px 蓝左条**留**，它是契约件；补齐选动态式（wash + 1px 蓝边 + 20px 蓝勾，与屏 3 同一条）、把次级键的蓝字改成墨字（一屏只有一个蓝控件）、地图色板写成 DESIGN.md 字面量并预告「这不是坏色」、三列数据改等宽 flex 列（原来的 72–84px 区间会诱导 space-between）、底栏钉成实心 #FFFFFF 零 blur。

```
Screen 5 — 住宿区域选择 (the AI shortlists 2 areas from 8–12 on-device candidates and shows the commute math). ONE frame only.
Chrome: 60px title bar on the rgba(255, 255, 255, 0.44) top-bar glass material — a 44px back chevron at the left, page name 住哪一片 in HarmonyOS Sans 18px / 600 / line-height 24px #17171A, and at the right one text action 查看更多区域 in 12px/600 #0066CC inside a 44px × 44px hit box, transparent, no fill and no outline.
Body top: a 200px map panel at radius 20, drawn from the contract's route-paper tokens rather than a tile screenshot, and with no pin icons: background gradient #FFFFFF → #F1F2F5, contour hairlines rgba(26, 26, 26, 0.15), water #EAF2FA, and a 2px #0066CC route trace over its rgba(0, 102, 204, 0.35) soft path (that halo is the `route-paper-path-soft` ledger token, not a shadow). Three candidate areas sit on it, and **only the recommended one gets a fill**: rgba(0, 102, 204, 0.10) (`primary-tint`) closed by a 1px dashed rgba(0, 102, 204, 0.35) stroke; the other two carry no fill and no new alpha — just a 1px dashed rgba(60, 60, 67, 0.20) (`separator`) outline. No alpha outside those three steps appears anywhere on this screen, the lodging indigo #5856D6 stays a solid dot/word and never becomes a translucent wash, and each region's corner radius is a token (14 or 20, never 16). Each region is labelled by 12/450 #17171A text on a 6px-radius #FFFFFF surface chip. rgba(26, 26, 26, 0.15) and #EAF2FA are DESIGN.md tokens (route-paper-contour, route-paper-water) — they are contract, not off-ladder hues, do not correct them. Every padding and gap on this screen sits on the 4px baseline (4 / 8 / 12 / 16 / 20 / 24 / 32 / 48) — badge padding 4px 8px, never 3px; no 2px or 6px gap.
Then two recommended-area cards, radius 20, #F7F7F8, 16px padding, stacked with a 12px gap, flat and shadowless. Card row 1: the area name 祇园 · 东山 in HarmonyOS Sans 18/600/24 #17171A, plus a 11/600 badge AI 精选 1 on solid #9A6206 with a #FFFFFF label at radius 999. Card row 2 is the reason block: #EFEFF2 at radius 14 carrying border-left: 2px solid #0066CC, an 11/600 #69696E overline 为什么是这里, and 14/400 #5A5A60 copy 早上 7 点前能空着走进清水寺，避开旅行团. Card row 3 is a commute row of three equal flex columns with an explicit 12px gap and no dividers — each column stacks an 18/600 #17171A tabular value over a 12/450 #69696E label: 步行 12分钟 over 到首个景点, 34分钟 over 日均通勤, 9 家 over 舒适型房源.
The first card is selected and uses exactly one contract pattern — rgba(0, 102, 204, 0.10) fill + 1px #0066CC border + a 20px #0066CC check icon at its top-right, with every label staying #17171A. That border belongs to the wash pattern and is not a decorative card outline; only the selected card gets it. The second card (河原町 · 三条) stays plain #F7F7F8 and keeps its own reason block with the same 2px left rule.
Footer: this screen's single solid #0066CC pill 就住这里 (44px tall, radius 999, press #0055BB with scale 0.97) beside 帮我选（按通勤最短） (transparent, 1px rgba(196, 196, 202, 0.40) outline, 14px #17171A, 44px × 44px hit box) — the solid CTA is the only blue control in the footer, so the secondary label is ink, not blue. The bar is a flat opaque #FFFFFF strip sitting at calc(16px + env(safe-area-inset-bottom, 12px)) with no translucency and no blur, and scroll content reserves calc(94px + env(safe-area-inset-bottom)).
360px × 780px .device-frame, light mode, letter-spacing 0, and no `box-shadow` at all on this screen — none of the six closed-set shadows is needed here, so add none.
```

### 6. 生成中 · 真实步骤与骨架

2026-10-14 发送前预检改三处：原稿 `Chrome: 60px title bar, no dock.` 没写页名和材质（模型会自己补，屏 4/5 都是靠正文钉死的）；`12px #0066CC 30% spinner arc` 的「30%」有歧义，可能被读成 alpha 而不是弧度占比，改成实心 `#0066CC`、`stroke-width 2`、覆盖 108°；Footer 只说了内容没说底栏材质与安全区，补上实心 `#FFFFFF` + 零 blur + 两处 `env()` 算式，这是前置块第 8 条的第二个数据点。**本屏不该有任何 rgba 出现在加载件上**，审计时按 11.8 的归一化差集命令复核。

```
Screen 6 — 行程生成中 (the only screen allowed to shimmer). No spinner alone, no fake percentage, no sparkle motif.
Chrome: 60px title bar on the rgba(255, 255, 255, 0.44) top-bar glass material — a 44px back chevron at the left and page name 生成行程 in HarmonyOS Sans 18/600/24 #17171A. No dock.
Body: serif 21/700 headline 正在为你规划 5 天行程, then 14px #69696E "已选好 16 个景点 · 2 个住宿区域".
Then a four-step checklist revealed one line at a time on a 40ms stagger, each row 44px: 筛选景点 ✓ / 排布每日动线 ✓ / 校验开放时间与预约 ✓ / 估算步行耗时 (in progress) — completed rows show a 16px blue check and 14px #17171A label, the active row shows 14px #17171A with a 12px arc of **solid** #0066CC, stroke-width 2, covering 108° of the circle (one third of it — this is geometry, not an alpha; no rgba appears on this arc), unreached rows are 14px #9E9EA3. Above it a 4px progress bar #0066CC on #E9E9EC at 75%.
Below: two skeleton day cards that mirror the real layout exactly — a 44px day-header block, then three 76px rows each with a 52px×12px time block, a 24px circle, and a 160px + 56px pair of 12px lines, all #E8E8EC with a #F8F8FA highlight sweeping at 1200ms, 20px outer radius / 14px block radius.
Footer: a 12px #69696E line "全程在本机生成，无需等待网络" and an outline 取消 — the bar is a flat opaque #FFFFFF strip at calc(16px + env(safe-area-inset-bottom, 12px)) with no translucency and no blur, 取消 is 44px tall at radius 999, transparent with a 1px rgba(196, 196, 202, 0.40) outline and 14px #17171A label, and scroll content reserves calc(94px + env(safe-area-inset-bottom)).
```

### 7. 校验未通过 · 降级与重试

2026-10-14 发送前预检改四处，其中**两处是我自己写进去的硬缺陷**：① 状态图标原稿 `a 48px 12px #9E9EA3 line icon` 既没有 48px 图标这一档（契约图标只有 22×22 / viewBox 24 / stroke 2），`#9E9EA3` 压在 `#FFFFFF` 上实测 **2.67:1**、不达契约「icons, dots, route strokes ≥3:1」——改 22×22 + `#69696E`（5.46:1）。② 理由件里的 chevron 用 `#9E9EA3` 压 `#EFEFF2` 只有 **2.32:1**，同色文字压 tint 正是已上线 UI 那四条对比度缺陷的老路径——chevron 改 `#69696E`（4.76:1），行内说明文字改 `#5A5A60`（5.97:1），标签 `#17171A` 压面板 15.59:1。③ `60px title bar` 没写材质与页名（屏 5/6 的教训：不写模型就自己补）→ 补顶栏玻璃 + 页名 生成受阻。④ 原稿 `a full-width outline 换一天 / 去掉这个景点` 用斜杠把两个控件写成一个标签，会被渲染成一行文字 → 拆成两只各自 44px 的整宽描边键，并钉死底栏实心 `#FFFFFF` + 两处 `env()`。`#A06400` overline 压白底 4.86:1，合格、保留。

**由此定出一条发送前必做步骤（写进第 3 关）**：正文里每一个「前景色 × 背景色」配对都要算 WCAG 对比度再发——文字 ≥4.5、图标与描边 ≥3.0；算式见 11.9 末尾的一行命令。**我对 Stitch 的度量已经纠过四轮（左条、底栏、alpha、对比度），全都出自我自己的判据或我自己的字面量，不是模型的。**

```
Screen 7 — 生成失败的诚实态 (type-guard validation failed after one retry; degrade or ask). The product's premise is traceability, so the failure names the failing step.
ONE frame only. Chrome: 60px title bar on the rgba(255, 255, 255, 0.44) top-bar glass material — a 44px back chevron at the left and page name 生成受阻 in HarmonyOS Sans 18/600/24 #17171A. No dock, no right-side text action.
White canvas, content centred in the column (max-width 328px), not a full-screen modal: a 22×22 line icon (a route line with one node broken open), viewBox 24, stroke-width 2, stroke #69696E, fill none — measured: #9E9EA3 on #FFFFFF is 2.67:1 and fails the contract's 3:1 floor for icons, so the faint step grey is NOT allowed as the only stroke colour here; serif 21/700/32 #17171A "第 3 天没排通", then 14/400 #5A5A60 "伏见稻荷大社 与 宇治平等院 之间的步行时间超过 90 分钟，无法安排在同一天。"
Then the reason panel — #EFEFF2 at radius 14 with border-left: 2px solid #0066CC (contract `reason-block.leftRule`; this panel explains why the plan failed and what resolves it, so the left rule is required, not decorative), 12px padding, an 11/600 #69696E overline 两条可行修法, and inside it two option rows of 44px each with a 22×22 right chevron in **#69696E** (stroke-width 2, viewBox 24 — #9E9EA3 on #EFEFF2 measures 2.32:1 and fails the 3:1 icon floor; on #69696E the same pair is 4.76:1) and no divider between them: row 1 label 把宇治移到第 4 天 (14/400 #17171A, 15.59:1 over the panel) over 12/450 #5A5A60 "第 4 天还有 3.5 小时空档"; row 2 label 宇治改为打车 42分钟 · ¥3,200 over 12/450 #5A5A60 "预算 +¥3,200".
Above the panel an 11/600 #A06400 overline 需要决定 — that amber is 4.86:1 on white, so it passes as a label; there is **no** red error styling and no danger banner anywhere on this screen, because this is a solvable constraint, not a fault.
Bottom: this screen's single solid #0066CC pill 按建议修复 (44px tall, radius 999, white label 16/600, press #0055BB with scale 0.97), and beneath it two stacked full-width outline buttons, each 44px tall at radius 999, transparent with a 1px rgba(196, 196, 202, 0.40) outline and a 14px #17171A ink label: 换一天 and 去掉这个景点 — three labels, three separate controls, and only the first one is blue. The bar is a flat opaque #FFFFFF strip at calc(16px + env(safe-area-inset-bottom, 12px)) with no translucency and no blur, and scroll content reserves calc(94px + env(safe-area-inset-bottom)).
360px × 780px .device-frame, light mode, letter-spacing 0, and no `box-shadow` at all on this screen — none of the six closed-set shadows is needed here, so add none.
```

### 8. 行程时间线 · 主视图（Day 1）

2026-10-14 发送前预检改了七处，逐条：① `44px share icon + 44px more icon` → **44×44 热区套 22×22 图标**，契约没有第二档图标尺寸，写 44 就会被画成 44 的图形。② `two transit legs at 44px on #F2F2F4 with 10px radius` → **透明、无填充、无圆角 + 2px dashed `rgba(60, 60, 67, 0.20)`**：原稿这条**正面违反前置块自查第 3 条**（「solid #F2F2F4 pill is wrong」），是本项目第二次「我的正文和我的自检块打架」（第一次是屏 2 的 serif 值 + 32px pill）。③ `32px 6px-radius photo thumb` → **36×48 radius 6 on `#E9E9EC`**，契约媒体件是 3:4。④ `a 18px blue glow spot` → **~180px 的 `rgba(0, 102, 204, 0.10)` 径向斑**（DESIGN.md 1090 行 + `pressGlow = {colors.primary-tint}`）。⑤ `18% border`、`18% blue shadow` 两处含糊 → 写成字面量 `1px solid rgba(60, 60, 67, 0.18)`（`glass-segment-border`）与 `0px 0px 8px 0px rgba(0, 102, 204, 0.18)`（`glass-selection-shadow`，全屏唯一一条彩色阴影）。⑥ 顶栏只写 `60px title bar` → 补玻璃材质 + 1px 描边（不写模型就自己补，屏 5/6 同一课）。⑦ dock 的 elevation 在 DESIGN.md 364 行被写成一条**颜色** token（`{colors.glass-bar-shadow}`）而不是几何，闭集里没有对应几何 → 本屏取 `floating` 那一条 `0px 6px 16px 0px rgba(0, 0, 0, 0.09)`，并在正文里钉死「除此之外别造第七条」。**这屏零实心蓝控件**（分段选中与按下的 dock 项都只是换色），所以正文里明写出来，免得模型为凑「一屏一个主按钮」补一颗蓝胶囊。

```
Screen 8 — 行程时间线主视图. The spine IS the product. ONE frame.
Chrome: 60px title bar on rgba(255, 255, 255, 0.44) with backdrop-filter blur(24px) and a 1px rgba(196, 196, 202, 0.40) bottom border; sans 18/600/24 #17171A 京都 · 5天4晚 at the left; at the right a 44×44 hit box holding a 22×22 share icon and a second 44×44 hit box holding a 22×22 more icon — stroke #3C3C43 (contract `colors.icon`), viewBox 24, stroke-width 2, fill none. 44px is the hit box, never the glyph: 22×22 is the only icon size in this system. Below it a 36px segmented control at radius 30 — track rgba(60, 60, 67, 0.10) (`glass-segment-bg`), 1px solid rgba(60, 60, 67, 0.18) (`glass-segment-border`), backdrop blur(24px) — with Day 1 / Day 2 / Day 3, the selected pill rgba(239, 239, 242, 0.60) (`glass-selection-surface`) carrying this screen's only coloured shadow: `box-shadow: 0px 0px 8px 0px rgba(0, 102, 204, 0.18)` (`glass-selection-shadow`). Selected label 14/600 #17171A, unselected 14/400 #5A5A60.
Then a compact 200px route map at radius 20, drawn from the route-paper tokens, no pin icons: gradient #FFFFFF → #F1F2F5, contour hairlines rgba(26, 26, 26, 0.15) (`route-paper-contour`), water #EAF2FA (`route-paper-water`), a 2px #0066CC path laid over its own rgba(0, 102, 204, 0.35) wide soft stroke (`route-paper-path-soft` — a drawn halo, not a box-shadow, do not convert it into one), four 24px numbered nodes on the path with 10px activity-tinted dots, a #A06400 ring on the 必去 node 伏见稻荷大社, and a 12/450 #17171A caption 步行 6.4km · 打车 1 段 on a 6px-radius #FFFFFF chip inset 16px.
Then a sticky day header, 44px tall — serif 21/700/32 #17171A Day 1 · 6月10日 周二 left, 12/450 #69696E 东山 · 清水 right — on rgba(255, 255, 255, 0.44) with blur(24px). That is the third glass surface; the bottom of this screen is the dock, not a bar, and nothing else gets blur.
Then the spine: a 52px right-aligned tabular time gutter, a 2px #E9E9EC spine whose current-stop segment is #0066CC, 24px nodes with 10px activity-tinted dots, five stop rows at `min-height: 76px`. Each row: 18/600 #17171A stop name on nowrap/ellipsis, 12/450 #69696E 建议停留 2小时 · 枫日谷, a 需预约 badge (solid #A06400, #FFFFFF 11/600, radius 999) on exactly one row, and a 36px × 48px photo thumb at radius 6 on #E9E9EC — contract media is 3:4, so no square thumb. TWO of the five rows are expanded under the row into a reason block: #EFEFF2 at radius 14 with `border-left: 2px solid #0066CC`, an 11/600 #69696E overline 为什么排在这里 and 14/400 #5A5A60 06:30 前进入，能避开 9 点后的团队客流.
Between rows, two transit legs at 44px: **transparent, no background fill and no radius** (self-check 3 — a solid #F2F2F4 pill is the known break), a 2px dashed rgba(60, 60, 67, 0.20) connector, and 12/450 #5A5A60 copy showing both numbers: 步行 18分钟 · 1.2km and 打车 25分钟 · ¥2,800.
Bottom: the 300×64 floating dock at radius 30 on rgba(255, 255, 255, 0.44) with blur(24px), a 1px rgba(196, 196, 202, 0.40) border and `box-shadow: 0px 6px 16px 0px rgba(0, 0, 0, 0.09)` (`floating` from the closed set — DESIGN.md gives the dock a colour token here rather than a geometry, so use this one literal and invent no other), floating 28px above the nav inset. Four items 行程 / 地图 / 费用 / 我的, each a 22×22 icon in #3C3C43 over a 10/400 #69696E label; the pressed item (行程) turns #0066CC icon and label with a ~180px radial glow of rgba(0, 102, 204, 0.10) behind it (`primary-tint` = pressGlow) — that is a colour change, not a filled button, so this screen carries **zero** solid #0066CC controls. The scroll area reserves `calc(94px + env(safe-area-inset-bottom, 12px))`.
```

### 9. 行程编辑 · 拖动调整与替换

**已发（2026-10-14 两轮）**：第一轮回复完成但**没成帧**，第二轮才落地 → `有径 - 行程时间线编辑态` / md5 `ebe57eac` / 20,686 B，四闸门 0/0/0/2、阴影 3 条零违规、底栏零透明，过程与残留见 **11.12**。

2026-10-14 发送前预检（承接 11.11 的两档图标口径与阴影闭集）改五处：① `20px swap icon / 20px minus icon` → **22×22 套 44×44 热区**，契约没有 20 这一档。② `six dots, #9E9EA3` → **`#69696E`**：把手点色是 affordance，`#9E9EA3` 压白 2.67:1 不过 3:1 底线，而 DESIGN.md 855 行本就把 `faint` 关在 disabled/placeholder 里。③ `rows lift … with the card shadow` / `the 16px floating shadow` 两处含糊 → 写成闭集字面量 `0px 3px 10px 0px rgba(0, 0, 0, 0.07)` 与 `0px 6px 16px 0px rgba(0, 0, 0, 0.09)`（这是 11.10 翻案后**第二批**必须落地的阴影：旧第 6 条会把拖动态画成贴平，编辑态就没了「拿起来」的层级）。④ 顶栏只写 `a sans 18/600/24 编辑中 label in the title bar`，没材质、没页名 → 补玻璃 + 页名 编辑行程，并钉死「完成」是**蓝色文字动作不是实心键**，免得和底栏那颗 `保存修改` 抢「全屏唯一实心蓝」。⑤ 底栏从 `a 64px action bar` 补成 **实心 #FFFFFF + `calc(16px + env(...))` + 滚动预留 `calc(94px + env(...))`**，警告行明确落在白画布上并写清「不许放 `#EFEFF2` 面板」（DESIGN.md 857 行：`#A06400` 压面板只有 4.24:1）。

```
Screen 9 — 编辑态 of the same timeline. Show drag affordance explicitly. ONE frame.
Same spine. Chrome: the 60px title bar keeps the rgba(255, 255, 255, 0.44) + blur(24px) glass with its 1px rgba(196, 196, 202, 0.40) bottom border, page name 编辑行程 in sans 18/600/24 #17171A on the left; on the right the 44×44 hit box now carries a 22×22 check glyph in #0066CC with a 12/600 #0066CC 完成 label beside it — a **text** action, not a filled button, because this screen's single solid #0066CC control is the 保存修改 pill in the footer. Every stop row grows a 24px-wide drag-handle column on its LEFT, outside the time gutter — the glyph inside it is a **22×22** six-dot handle, viewBox 24, stroke-width 2, fill #69696E (the dots are an affordance, so `faint` `#9E9EA3` is barred: 2.67:1 on #FFFFFF against a 3:1 floor) — and rows lift to #F7F7F8 with `box-shadow: 0px 3px 10px 0px rgba(0, 0, 0, 0.07)` (the closed-set `card`).
One row is mid-drag: it is scaled 1.02, has a #FFFFFF surface with `box-shadow: 0px 6px 16px 0px rgba(0, 0, 0, 0.09)` (the closed-set `floating`), a 1px #0066CC border, and is displaced 8px off the spine; the spine shows a 2px #0066CC insertion gap between two nodes, and the row being vacated collapses to 40% opacity — that vacated ghost is the only opacity use on this screen and it is not a control. A 12px #69696E caption near the gap reads "拖到第 2 天 · 余量 3.5 小时".
Per-row trailing actions are visible only in this mode: a 44×44 hit box holding a 22×22 swap icon and a second 44×44 hit box holding a 22×22 minus icon, both stroke #3C3C43 (contract `colors.icon`), viewBox 24, stroke-width 2 — there is no 20px glyph tier.
Bottom: instead of the dock, a **flat opaque #FFFFFF** action bar at `padding: 12px 16px calc(16px + env(safe-area-inset-bottom, 12px))` — no translucency, no blur — holding two 44px-tall radius-999 buttons side by side in equal flex columns with a 12px gap: 撤销 (transparent, 1px rgba(196, 196, 202, 0.40) outline, 14px #17171A label) and 保存修改 (solid #0066CC, #FFFFFF 16/600 label, press #0055BB + scale 0.97). Above the bar, on the white canvas (never on a #EFEFF2 panel, where #A06400 drops to 4.24:1), a 12/450 #A06400 warning row that appears when a move breaks a constraint: 移走后第 1 天空 2.5 小时，可补一个可选景点 with a 12/600 #0066CC 补一个 text action beside it. Scroll content reserves `calc(94px + env(safe-area-inset-bottom, 12px))`.
```

### 10. 节点详情 · 预约、冲突与耗时

**已发（2026-10-14，第一次 Return 静默失败、重发才落地）**：`有径 - 单个活动节点详情` / md5 `471fcea9` / 12,984 B（v7 最小一屏）。四闸门 0/0/0/2、**阴影 0 条零违规**、**台账外 alpha 0 种**、理由块左条 1 命中、底栏扁平 + 两条 `env()`、内容图标全在档；过程与 audit.sh 的两条假绿见 **11.13**。

2026-10-14 发送前预检改了九处：① **全出血 3:4 hero 删掉**——360 宽的 3:4 就是 480px 高，780 画板装不下后面七个内容块，这是我写的几何缺陷，不是 Stitch 的；换成 96×128 内嵌 3:4 缩略位。② `a 44px chevron row` → **44×44 热区套 22×22**（屏 7 那个 `48px 12px icon` 的同款自伤）。③ 理由块只写了底色没写前景 → 补 overline `11/600 #69696E`（4.76）与正文 `14/400 #5A5A60`（5.97）。④ `12px #A06400` 提示行没钉底色 → 明写**必须落在 `#FFFFFF`（4.86），不许落 `#EFEFF2`（4.24 不合格）**。⑤ 底栏完全没写材质 → 补扁平 `#FFFFFF` + 两条 `env()` calc + 零 blur（屏 8/9 已两连击的地方，这屏提前挡）。⑥ 删 `免费入内` 中性徽章（和 `门票 ¥0` 说的是同一件事，且第三枚金色会和两枚金色挤成一堆读不出层级）。⑦ 明写「宋体这处是**页面标题档**，不是时间线站名档」，防止它把站名也带上宋体。⑧ 阴影按屏 4/5/7 的写法声明「这屏六条闭集一条都不需要，一条都别加」。⑨ 顶栏玻璃 + 图标 `#3C3C43` 点名（四件授权表面之一），外链节点序号色从 `#69696E`/`#E9E9EC`（实测 4.51 压线）改 `#5A5A60`（5.65）。**正文里所有对比度数字事后用 python3 独立复算过一遍**：白字压 `#9A6206` 5.09、压 `#A06400` 4.86、`#69696E` 压白 5.46 / 压 `#EFEFF2` 4.76、`#5A5A60` 压 `#EFEFF2` 5.97、`#A06400` 压白 4.86 而压 `#EFEFF2` **4.24 不合格**（所以那条提示行必须钉在白底）、白压 `#0066CC` 5.57、`#17171A` 压白 17.89。

```
Screen 10 — 单个活动节点详情. ONE frame. This screen answers the three contract questions in visible data: why this stop, how long, does it need booking.
Chrome: the standard 60px title bar on rgba(255, 255, 255, 0.44) with backdrop-filter blur(24px) and a 1px rgba(196, 196, 202, 0.40) bottom border; at the left a 44×44 hit box holding a 22×22 back chevron, at the right a 44×44 hit box holding a 22×22 share icon — stroke #3C3C43, viewBox 24, stroke-width 2, fill none. 44px is the hit box, never the glyph.
No full-bleed hero: this product has no photography budget, and a 3:4 full-bleed placeholder would eat 480px of the 780px artboard. Media is one inset 3:4 thumbnail — **96px wide × 128px tall, radius 6, on #E9E9EC** — with a 12/450 #69696E caption 景点照片位 under it.
Header beside the thumbnail: serif 21/700/32 #17171A 伏见稻荷大社. That is the page-title serif role, **not** the timeline stop-name role: every other stop name on this screen (上一站 / 下一站) stays 18/600 sans. Under it 12/450 #69696E 京都市伏見区深芝藪町 68 · 山脚入口, nowrap + ellipsis.
Badge row, exactly two chips at 8px gap: 必去 solid #9A6206 with #FFFFFF 11/600 label (white on #9A6206 measures 5.09:1) and 需预约 solid #A06400 with #FFFFFF 11/600 label (4.86:1). No third chip — 免费入内 is already said by the 门票 ¥0 stat.
Stat strip: four equal flex columns with an explicit 12px gap, no dividers — each a tabular 18/600 #17171A number over a 12/450 #69696E label: 停留 2.5小时 / 到达 07:40 / 步行 12分钟 / 门票 ¥0.
Open-hours block, two rows: 12/450 #69696E label over 14/400 #17171A value — 开放时间 全天（24小时）, 建议时段 06:30–08:00 · 人少. Then one advisory line 12/600 #A06400 **on the page's own #FFFFFF** (4.86:1): 红叶季周末 09:00 后山道拥挤. Do not move this advisory onto a #EFEFF2 panel — #A06400 on #EFEFF2 measures 4.24:1 and fails the 4.5 floor.
Reason block: #EFEFF2 at radius 14 with `border-left: 2px solid #0066CC` (contract `reason-block.leftRule`; a fill-only panel with no left rule is the known break), 11/600 #69696E overline 为什么排在这里 (4.76:1 on #EFEFF2) and 14/400 #5A5A60 body (5.97:1): 排在第 1 天最早，是因为它在山脚，后续三点可一路步行上山，省掉两段打车。
Then the mini route strip: a 2px #0066CC horizontal line carrying three 24px nodes — the outer two on #E9E9EC with 12/600 #5A5A60 tabular numbers (5.65:1), the centre node solid #0066CC — labelled 上一站 06:50 一条 and 下一站 10:20 东福寺, neighbour names 14/400 #17171A, the rest 12/450 #69696E.
Bottom action bar: **flat opaque #FFFFFF, no translucency and no blur**, `padding: 12px 16px calc(16px + env(safe-area-inset-bottom, 12px))`, holding two equal-width pills at 44px with `gap: 12px`: outline 换一个时间 (transparent, 1px solid rgba(196, 196, 202, 0.40), 16/600 #17171A) and this screen's only solid #0066CC control 加入日历提醒 (#FFFFFF 16/600, radius 999, press 140ms scale 0.97 onto #0055BB). Scroll content reserves `calc(94px + env(safe-area-inset-bottom, 12px))`.
This screen needs **none** of the six closed-set shadows — the surface ladder (#FFFFFF page, #E9E9EC media, #EFEFF2 reason block) plus whitespace does the separation, so add no `box-shadow` at all.
```

### 11. 费用 · 预算对账与随手记账

**已发（2026-10-14，一次发送成功）**：`有径 - 费用视图` / md5 `1ab099b1` / 16,574 B。四闸门 0/0/0/2、**阴影 2 条零违规**（正好是正文点名的分段胶囊 + dock）、**台账外 alpha 0 种**、**CSS 里零 serif 使用**（32/700 sans 的 display-numeral 新条款第一屏兑现）、**六只图标全 22×22**、**CSS 区零实心蓝按钮**；正文账目矛盾重算与 audit.sh 的两条新假绿见 **11.14**。

2026-10-14 发送前预检改了十处，逐条：① **`32/700 sans` 原本在字阶上是非法的**——32 档只有 serif，而「数字一律 sans」又禁了 serif 数字，两条正面相撞，前置块 TYPE 已补「display numeral」合法条款。② 前置块残留的「an icon glyph may sit at 20px」与两档图标口径矛盾，已删（**这是第 4 处比正文更严/更松的自相残杀**）。③ overline 从 `12px` 改回 **11/600** 档。④ 四行分类的点色没点名 → 逐行钉死 `交通 #3C3C43 / 餐饮 #9A6206 / 门票 #0066CC / 住宿 #5856D6`，并规定 4px 比例条的填色**等于同行点色**、轨底 `#E9E9EC`。⑤ 分隔线只写 `0.5px` 没给值 → 补 `rgba(60, 60, 67, 0.20)`。⑥ 金额两档（分类 14/600、记账 16/600）→ **统一 14/600**，大小层级只由 hero 那一颗承担。⑦ 原文写「Floating above the dock」却**从没定义 dock** → 补齐 300×64 浮动 dock（屏 8 同款配方 + `floating` 闭集阴影），`记一笔` 改成内容流末尾的一枚 outline 胶囊，不再"浮"。⑧ 分段控件只写了名字 → 补玻璃轨 + 选中胶囊 + 那一条唯一合法的彩色阴影。⑨ **账目本身自相矛盾（本轮最该记的）**：`预算 ¥8,000 / 人 · 共 2 人` + `已花 ¥6,420` + `4px 进度条 80%` 三者打架（8,000×2=16,000，6,420 只占 40%），分类四项求和也凑不回任何一条 → 整套数字重算成自洽的一套，见正文。⑩ **780 画板逐段列预算**（合计 754px），防止 hero 被撑大挤掉记账列表。

```
Screen 11 — 费用视图. Numbers are the content, so every digit is tabular. ONE frame — the over-budget variant is its own send (11b).
Vertical budget on the 780px artboard, do not inflate any band: title bar 60 + segmented 36 with one 16 margin + hero panel 116 + section label 20 + four category rows 4×44 + section label 20 + three receipt rows 3×44 + 记一笔 pill 44 + its 16 margin + dock reserve 94 = **730px**, leaving 50px of slack for inter-section gaps.
Chrome: 60px title bar on rgba(255, 255, 255, 0.44) with backdrop-filter blur(24px) and a 1px rgba(196, 196, 202, 0.40) bottom border; sans 18/600/24 #17171A 费用 at the left; at the right a 44×44 hit box holding a 22×22 more icon, stroke #3C3C43, viewBox 24, stroke-width 2, fill none.
Below the title bar, a 36px segmented control at radius 30 — track rgba(60, 60, 67, 0.10), 1px solid rgba(60, 60, 67, 0.18), backdrop blur(24px) — with 预算 / 实际; the selected pill is rgba(239, 239, 242, 0.60) and carries this screen's only coloured shadow, `box-shadow: 0px 0px 8px 0px rgba(0, 102, 204, 0.18)`. Selected label 14/600 #17171A, unselected 14/400 #5A5A60.
Hero panel: #F7F7F8 at radius 28, `padding: 16px`, **no box-shadow**. Inside, top to bottom: an 11/600 #69696E overline 预算 ¥16,000 · 2 人 · 5 天 (5.10:1 on #F7F7F8); the figure line — **32/700/44 sans #17171A ¥12,840** followed inline by 14/400 #5A5A60 已花 (6.40:1); a 4px progress track on #E9E9EC filled to 80% with #0066CC (4.59:1 against #E9E9EC, and it is a graphic so the 3:1 floor applies); then 12/450 #69696E 剩 ¥3,160 · 还剩 2 天. **The arithmetic must stay consistent: 16,000 − 12,840 = 3,160, and 12,840 / 16,000 = 80%.**
Section label 11/600 #69696E 分类支出, then four category rows at 44px each. Each row: a 10px dot, 16/400 #17171A label, a 4px proportional bar on an #E9E9EC track whose fill is **the same colour as that row's dot**, and a right-aligned tabular 14/600 #17171A amount. Dot colours are prescribed, no new hue: 住宿 #5856D6 ¥6,400 (bar 100%), 交通 #3C3C43 ¥2,800 (bar 44%), 餐饮 #9A6206 ¥2,640 (bar 41%), 门票 #0066CC ¥1,000 (bar 16%). The four amounts sum to the hero figure — 6,400 + 2,800 + 2,640 + 1,000 = 12,840. Amounts and labels never share a colour; only the numbers are bold, and every amount on this screen sits at 14/600.
Section label 11/600 #69696E 最近记账, then three receipt rows at 44px separated by `border-top: 0.5px solid rgba(60, 60, 67, 0.20)` — 07:40 抹茶 ¥500, 09:15 清水寺参观券 ¥400, 12:30 午餐 ¥1,800. Time is 12/450 tabular #69696E, the item name 14/400 #17171A, the amount right-aligned 14/600 #17171A. Receipts are a subset of the categories, so no receipt line may exceed its category total.
Then the last content row: one outline pill 记一笔 — 44px tall, radius 999, transparent fill, 1px solid rgba(196, 196, 202, 0.40), 16/600 #17171A label, a 22×22 plus glyph in #3C3C43 inside the same 44px height. **This screen has zero solid #0066CC buttons**: the only solid blue on it is the 80% progress fill and the pressed dock item, neither of which is a button.
Bottom: the 300×64 floating dock at radius 30 on rgba(255, 255, 255, 0.44) with blur(24px), a 1px rgba(196, 196, 202, 0.40) border and `box-shadow: 0px 6px 16px 0px rgba(0, 0, 0, 0.09)` (closed set `floating`), sitting 28px above the inset. Four items 行程 / 地图 / 费用 / 我的, each a 22×22 icon over a 10/400 label; 费用 is the pressed item — #0066CC icon and label with a ~180px radial glow of rgba(0, 102, 204, 0.10) behind it, which is a colour change, not a filled button. Scroll content reserves `calc(94px + env(safe-area-inset-bottom, 12px))`.
Of the six closed-set shadows this screen uses exactly two, both named above (the segmented selected pill and the dock). No shadow on the hero panel, the category rows, the receipt rows or the 记一笔 pill.
```

### 11b. 费用 · 超支态（同一屏的第二种数据）

2026-10-14 与屏 11 同步重算：原文只把 hero 换成 ¥8,320、住宿换成 ¥2,000，**分类求和根本对不上新的已花数**，而且沿用了屏 11 那套自相矛盾的预算。现在四个金额一起改，求和恰好等于 hero，超支额等于差额。**另外补一处变体屏的通病**：原稿通篇「same chrome / same hero / same dock as screen 11」——**Stitch 看不见屏 11 的 CSS，跨帧引用等于没写**（屏 3b 同条已修），所以材质、圆角、阴影、内距全部就地写全，只让数字不同。

```
Screen 11b — 费用视图 · 超支态. Identical geometry, colours and strings to screen 11; **only the numerals change**, so the audit is a diff, not a new design. ONE frame.
Chrome: 60px title bar on rgba(255, 255, 255, 0.44) with backdrop-filter blur(24px) and a 1px rgba(196, 196, 202, 0.40) bottom border; sans 18/600/24 #17171A 费用 at the left; a 44×44 hit box holding a 22×22 more icon (stroke #3C3C43, viewBox 24, stroke-width 2, fill none) at the right.
Below it a 36px segmented control at radius 30 — track rgba(60, 60, 67, 0.10), 1px solid rgba(60, 60, 67, 0.18), backdrop blur(24px) — with 预算 / 实际; the selected pill is rgba(239, 239, 242, 0.60) carrying `box-shadow: 0px 0px 8px 0px rgba(0, 102, 204, 0.18)`. Selected label 14/600 #17171A, unselected 14/400 #5A5A60.
Hero: #F7F7F8 at radius 28, `padding: 16px`, **no box-shadow**. Inside: 11/600 #69696E overline 预算 ¥16,000 · 2 人 · 5 天; **32/700/44 sans #17171A ¥16,840** with 14/400 #5A5A60 已花 inline; a 4px progress track on #E9E9EC filled **100%** with #0066CC; then the balance line 11/600 #C0392B 超支 ¥840 · 还剩 2 天 — **that line is the ONLY red on the screen**, and #C0392B on #F7F7F8 measures 5.08:1, so it stays 11/600 and never drops to 10px.
Category rows (11/600 #69696E label 分类支出, four 44px rows, each a 10px dot + 16/400 #17171A label + a 4px bar on #E9E9EC filled in the row's own dot colour + a right-aligned 14/600 tabular #17171A amount): 住宿 #5856D6 ¥8,800 (bar 100%), 餐饮 #9A6206 ¥3,840 (bar 44%), 交通 #3C3C43 ¥3,200 (bar 36%), 门票 #0066CC ¥1,000 (bar 11%). **They must sum to the hero figure: 8,800 + 3,840 + 3,200 + 1,000 = 16,840.**
最近记账 (11/600 #69696E label, three 44px rows with `border-top: 0.5px solid rgba(60, 60, 67, 0.20)`) is unchanged from screen 11: 07:40 抹茶 ¥500 / 09:15 清水寺参观券 ¥400 / 12:30 午餐 ¥1,800 — 12/450 tabular #69696E time, 14/400 #17171A item, 14/600 tabular #17171A amount right-aligned.
Then one outline pill 记一笔 (44px, radius 999, transparent, 1px solid rgba(196, 196, 202, 0.40), 16/600 #17171A, a 22×22 plus glyph in #3C3C43).
Bottom: the 300×64 floating dock at radius 30 on rgba(255, 255, 255, 0.44) with blur(24px), a 1px rgba(196, 196, 202, 0.40) border and `box-shadow: 0px 6px 16px 0px rgba(0, 0, 0, 0.09)`, sitting `calc(28px + env(safe-area-inset-bottom, 12px))` above the edge; four items 行程 / 地图 / 费用 / 我的 at 22×22 over 10/400, **费用 pressed** (#0066CC icon and label, ~180px radial glow of rgba(0, 102, 204, 0.10)). Scroll content reserves `calc(94px + env(safe-area-inset-bottom, 12px))`.
Two closed-set shadows only (the segmented pill and the dock). **Zero solid #0066CC buttons on this screen.** No red bars, no red amounts, no warning banner, no new surface — the over-budget state is one line of data, not an alarm.
```

### 12. 我的行程列表与空状态

**已发（2026-10-14，一次发送成功）**：`有径 - 我的行程` / md5 `f037b5c4` / 16,353 B。四闸门 0/0/0/2、**阴影 2 条零违规（`.trip-card` 吃 `card`——翻案第一屏兑现）**、**零实心蓝按钮**、**内容图标零离档**、**禁 opacity 表达完成态被完整执行**（全帧唯一一处 opacity 在 `.home-indicator` 设备件上）；本轮发送前抓到的第 4 处「我写的正文与 DESIGN.md 打架」（原稿把行程卡写成 flat 无阴影，而 `itinerary-summary-card` 明写 `elevation: {elevation.card}`）见 **11.15**。

2026-10-14 发送前预检改了十处，逐条：① `a 44px search icon` → **44×44 热区套 22×22**（屏 7/9/10 同款自伤的第四次）。② **「Cards … flat — no shadow」直接违反 DESIGN.md**：`itinerary-summary-card`（569–580 行）明写 `elevation: "{elevation.card}"`，并且 `backgroundColor: surface-elevated` `#F7F7F8`、`titleFont: serif`、`statTypography: headline`(18/600)、`statLabelColor: muted`、`rounded: lg`(20)、`padding: 16px`、`statGap: 12px`、`numeralFeature: tnum` 全都有主——**这是第 4 处我写的比契约更严的收紧条款，和 11.10 那次「box-shadow 一处都不许出现」同族**，已改成逐字引用闭集里的 `card` 那条。③ `at 72–84px each` 是个区间（＝不确定）→ 钉成契约的 `spacing.profile_stat_width: 72px` + 三条等分 flex + `gap: 12px`（statGap），并按契约「兄弟标签行要等分列 + 显式 gap，不能只靠 space-between」。④ 「the 必去 one **in gold**」二义——`#9A6206` 必去 与 `#A06400` 需预约 都是金色，已钉 `#9A6206`，并把五枚节点的画法逐件写死（24px 圆 / `#F2F2F4` 底 / `#5A5A60` 11/600 序号 / 2px `#E9E9EC` 连线 / 必去那枚加 1px `#9A6206` 环）。⑤ 所有 `12px` 补字重（12/450 caption 档）。⑥ 状态行的 4px 进度轨没给色 → 钉 `#E9E9EC` 轨 + `#0066CC` 填充，与屏 11 同一条配方。⑦ 「已完成卡 everything desaturated to `#69696E`」→ **补一条禁 opacity**：卡片仍然可点，完成态只靠颜色与去掉进度条表达，**绝不用透明度弱化**（对齐已上线那条「可操作图标禁 opacity 弱化」）。⑧ `Bottom dock present.` 一句话 → 补全 dock 配方（300×64 / r30 / `rgba(255, 255, 255, 0.44)` + blur 24 / 1px `rgba(196, 196, 202, 0.40)` / 闭集 `floating` 阴影 / `calc(28px + env(safe-area-inset-bottom, 12px))` / 四项 22×22 + 10/400 / 当前项「我的」带 180px 光斑）。⑨ **卡的数量没定 → 必然溢出**：单卡实测高约 **236px**（16+32+12+16+12+44+12+40+12+16+4+4+16），可滚区只有 `780 − 60 − 94 = 626px` → 明写**「两张完整 + 第三张被裁」**，并把「旅行中」「已完成」两种状态都放进完整区。⑩ `an 11px badge` → 11/600，白字压 `#A06400` 复算 4.86:1。

```
Screen 12 — 我的行程 list. ONE frame — the empty state is its own send (12b).
Vertical budget: the title bar is 60px and the scroll area reserves `calc(94px + env(safe-area-inset-bottom, 12px))`, so about **626px of cards are visible**. A trip card is **236px tall** (16 padding + 32 serif title + 12 gap + 16 date line + 12 gap + 44 mini strip + 12 gap + 40 stat row + 12 gap + 16 status line + 4 gap + 4 track + 16 padding). **Emit exactly three cards: two fully visible, the third cropped by the dock reserve.** The first two carry the 旅行中 and 已完成 states so both are shown whole.
Chrome: 60px title bar on rgba(255, 255, 255, 0.44) with backdrop-filter blur(24px) and a 1px rgba(196, 196, 202, 0.40) bottom border; sans 18/600/24 #17171A 我的行程 at the left; at the right a 44×44 hit box holding a 22×22 search glyph (magnifier, viewBox 24, stroke-width 2, stroke #3C3C43, fill none). 44px is the hit box, never the glyph.
Cards sit on #FFFFFF with 16px page padding and a 12px gap between them. Each card is **contract `itinerary-summary-card`**: #F7F7F8 (`surface-elevated`), radius 20 (`rounded.lg`), `padding: 16px`, inner `gap: 12px`, and it **carries the closed-set card shadow — `box-shadow: 0px 3px 10px 0px rgba(0, 0, 0, 0.07)`**. Do not flatten this card and do not invent another shadow value; DESIGN.md gives this component `elevation: {elevation.card}`.
Card content, top to bottom: serif 21/700/32 #17171A 京都 (place name = serif role); 12/450 #69696E tabular 6月10日 – 6月14日 · 5天4晚; then a 44px-high mini route strip — a 2px #E9E9EC line carrying **five 24px nodes**, each #F2F2F4 with an 11/600 tabular #5A5A60 number (6.13:1), and the 必去 node wearing a **1px #9A6206 ring** (that gold, not #A06400 — 必去 and 需预约 are different tokens); then the stat row — three equal flex columns with an explicit `gap: 12px`, each column 72px wide (`spacing.profile_stat_width`), an 18/600 tabular #17171A number over a 12/450 #69696E label: 景点 16 / 步行 24.6km / 需预约 3. The 需预约 value carries an 11/600 badge on solid #A06400 with a #FFFFFF label (4.86:1). Then the status line 12/450 #69696E 旅行中 · 第 2 天 over a 4px progress track on #E9E9EC filled to 40% with #0066CC (4.59:1 against #E9E9EC; a graphic, so the 3:1 floor applies).
Card two is the 已完成 state: same structure, status line 12/450 #69696E 已完成 · 去年 11 月, **no progress track at all**, and its labels sit at #69696E. **Never express this state with `opacity`** — the card is still tappable, so weakening it with alpha is the known break; the state is carried by colour and by the missing track only.
Bottom: the 300×64 floating dock at radius 30 on rgba(255, 255, 255, 0.44) with blur(24px), a 1px rgba(196, 196, 202, 0.40) border and `box-shadow: 0px 6px 16px 0px rgba(0, 0, 0, 0.09)` (closed set `floating`), sitting `calc(28px + env(safe-area-inset-bottom, 12px))` above the bottom edge. Four items 行程 / 地图 / 费用 / 我的, each a 22×22 icon in #3C3C43 over a 10/400 #69696E label; **我的 is the pressed item** — #0066CC icon and label with a ~180px radial glow of rgba(0, 102, 204, 0.10) behind it, which is a colour change, not a filled button.
Of the six closed-set shadows this screen uses exactly two: `card` on each trip card (three cards, same declaration) and `floating` on the dock. No shadow on the title bar, the mini nodes, the badges or the progress tracks. **This screen has zero solid #0066CC buttons** — the only solid blue on it is the 40% progress fill and the pressed dock item.
```

### 12b. 我的行程 · 空状态

2026-10-14 发送前预检改了四处：① 承接屏 12 的 `44px search icon` → **44×44 热区套 22×22**。② dock 从「floating dock 300×64」一句 → 指回屏 12 已写死的完整配方（含 `floating` 闭集阴影与 `calc(28px + env(...))`），变体屏不许自己重述配方。③ 补一句**空状态没有卡，所以 `card` 阴影在这屏一条都不许出现**，全帧只允许 dock 那一条 `floating`。④ 明写居中区间：垂直居中发生在**顶栏下沿与 dock 净空上沿之间**，不是整块 780 画板正中——否则内容会被 dock 压住半截。

```
Screen 12b — 我的行程 empty state. ONE frame, **identical chrome to screen 12**: the 60px title bar on rgba(255, 255, 255, 0.44) with blur(24px) and a 1px rgba(196, 196, 202, 0.40) bottom border, sans 18/600/24 #17171A 我的行程 at the left, a 44×44 hit box holding a 22×22 search glyph (stroke #3C3C43, viewBox 24, stroke-width 2, fill none) at the right, and the same 300×64 radius-30 floating dock with its 1px rgba(196, 196, 202, 0.40) border and `box-shadow: 0px 6px 16px 0px rgba(0, 0, 0, 0.09)`, 我的 pressed.
Centred column, nothing else on the canvas — **the centring happens between the bottom edge of the title bar and the top edge of the `calc(94px + env(safe-area-inset-bottom, 12px))` scroll reserve, not the middle of the 780px artboard**, otherwise the dock overlaps it.
The glyph is a **48×48 display glyph** — the one size above the 22×22 control tier, DESIGN.md §Empty state + `spacing.xxl` — a route with two nodes, viewBox 24, stroke-width 2 (**the stroke does NOT scale with the box**), stroke **#69696E** `muted`, fill none. `faint` `#9E9EA3` is barred even though the contract's older wording says "faint": it measures 2.67:1 on #FFFFFF and fails the 3:1 graphic floor, and §8 restricts `faint` to disabled and placeholder text.
Then serif 21/700/32 #17171A 还没有行程, then 14/400 #5A5A60 「选一座城市，四道题就能拿到一份能直接走的行程」 capped at 240px so it sets on two lines, then this screen's single solid #0066CC pill 规划新行程 (44px tall, radius 999, #FFFFFF 16/600, press 140ms scale 0.97 onto #0055BB) 24px below the copy.
No illustration, no mascot, no card — and therefore **no `card` shadow on this frame**: the dock's `floating` declaration is the only `box-shadow` present. No second glyph size, no second solid blue control.
```

### 13. 万能卡片 · 桌面今日行程

2026-10-14 发送前预检改了七处：① **正文里出现 `Frame A` / `Frame B` 字样**——前置块 GEOMETRY 明令 `no frame labels like "Frame 1"`，这是第 5 处正文与前置块当面对撞，改成 `Widget A/B/C` 并写明「三枚控件在同一块 360×780 画板里，桌面就是页面内容」。② **`photo wallpaper` 违反「无摄影预算」**，而且一张照片必然带进台账外的色相 → 桌面底改成契约面 `#E9E9EC`（DESIGN.md 1053 行说控件靠「实色面 + 1px 发丝边」在**任意**壁纸上站得住，中灰底正是这屏要证的）。③ `10px activity dot` 没点名 → 逐行钉死 `景点 #0066CC / 餐饮 #9A6206 / 住宿 #5856D6`。④ `one gold ring` 二义 → `#9A6206`。⑤ 深色实例只写了 `#1E1E1E` 没写前景与蓝档 → 补 `#FFFFFF` 16.67 / `#E9E9EC` 13.76 / 深色蓝 **`#0A84FF`** 4.57，并写明「亮底上不许压白字」。⑥ 控件内距与字阶全部回指 `widget-card` 的 token（`padding2x2 12px` / `padding2x4 16px` / `minTextSize 11px`）。⑦ 阴影一栏按屏 11 口径声明「这屏一条都不需要」。

```
Screen 13 — 万能卡片 (FormAbility widgets) on a simulated launcher, to prove wallpaper legibility. ONE 360×780 artboard — the launcher IS the page content, and the three widget instances are labelled **Widget A / Widget B / Widget C**, never "Frame"; there is no second artboard and nothing side by side.
No photograph and no gradient image anywhere: this product has no photography budget and an image would import a hue the ledger does not carry. The launcher field is a flat #E9E9EC surface with a 44px-tall search pill on #F2F2F4 at the top and a 300×64 dock silhouette at the bottom. A mid-tone is the point — DESIGN.md line 1053 says a widget stays legible against **any** wallpaper using only a solid surface plus a 1px hairline border.
Widget law (DESIGN.md `widget-card`, line 580): solid #F7F7F8 surface (dark variant #1E1E1E), `rounded.lg` 20px radius, **1px solid #E5E5EA hairline border, no blur, no shadow, no translucency**, text floor 11px (`layout.widget-min-text`), `padding2x2: 12px`, `padding2x4: 16px`.
Widget A — 2×2, 12px padding: 11/600 #69696E overline 有径 · 今日 (5.10:1 on #F7F7F8); serif 21/700/32 #17171A Day 2 · 6月11日; then three rows, each a 12/600 tabular #5A5A60 time, a 10px activity dot in its **prescribed** colour (景点 #0066CC · 餐饮 #9A6206 · 住宿 #5856D6) and 14/400 #17171A copy — 09:00 岚山竹林 / 11:30 天龙寺 / 13:00 午餐 · 岚面. Footer 11/400 #69696E 还有 1 个需预约节点 · 14:20 前.
Widget B — 2×4, 16px padding: the same header, plus a 40px route strip — a 2px #0066CC line with **four 24px nodes** (#F2F2F4 fill, 11/600 tabular #5A5A60 numbers, 6.13:1), the 必去 node wearing a **1px #9A6206 ring** (that gold, not #A06400), the current node filled #0066CC; right-aligned 12/450 #5A5A60 步行 5.2km · 还剩 2 站.
Widget C — Widget A's dark variant at the same geometry: #1E1E1E surface, 1px rgba(69, 69, 75, 0.32) border (`dark-glass-bar-border`, ledger), #FFFFFF title (16.67:1), #E9E9EC meta (13.76:1), and the route line in **dark-mode blue #0A84FF** (4.57:1 on #1E1E1E). **Never white text on a bright fill** — no #0A84FF or #5856D6 block sits under white copy in this frame.
Of the six closed-set shadows this screen uses **none**: no shadow may reach the wallpaper, and each widget's own 1px hairline is the only separation. No widget is interactive beyond a 44×44 hit region.
The launcher keeps the safe area: the search pill sits `calc(16px + env(safe-area-inset-top, 0px))` below the artboard top, the dock silhouette is inset `calc(28px + env(safe-area-inset-bottom, 12px))` from the bottom edge, and **this frame has zero solid #0066CC controls of any kind** — the only blue on it is the 2px route line and the current node fill, neither of which is a button.
```

### 14. 系统触达 · 日历写入与卡片授权

2026-10-14 发送前预检改了六处：① **抽屉不是玻璃**——前置块原来把 sheets 列进「四处玻璃表面」，而 DESIGN.md `sheet-modal`（367 行）与 Sheet 组件注（1092 行）写的是 **实色 `surface-elevated` + `elevation.floating` + 后面一层遮罩**，**我写进前置块的第五处过严/失真条款**，已把 sheets 从玻璃清单里删掉、玻璃改三件。② **契约根本没有 scrim token**（1092 行说 "scrim behind" 却没给值）→ 新增 `modal-scrim rgba(23, 23, 26, 0.32)`（ArkTS `52 17 17 1A`）进 colors 与透明度台账，正文引用它，**不许 Stitch 自己发明遮罩浓度**。③ 开关没有契约件 → 定死轨道 44×24 / ON `#0066CC` + 20px 白旋钮 / OFF `#E5E5EA` + `#69696E` 旋钮，并声明**开关是系统控件、不算主 CTA**（否则两个 ON 开关会被「一屏一颗实心蓝」判据误杀）。④ **默认值就是同意**：原稿 `日历同步 ON` 与它自己那句「destructive-by-default 不许预选」打架 → 写入类的日历与提醒一律 **OFF**，只展示的行程卡片 ON。⑤ 预览面板只写了底色没写圆角与前景 → 补 radius 14、overline `11/600 #69696E`（4.76）、正文 `14/400 #5A5A60`。⑥ 分隔线与底部安全区补齐契约字面值。

```
Screen 14 — 持久化与系统触达 settings sheet (bottom half-modal). This is where the app asks to write calendar events and place a widget, so it must read as data, not marketing. ONE frame.
Scrim: the page behind is dimmed by exactly one layer of **`modal-scrim` rgba(23, 23, 26, 0.32)** — no blur on the page, no second scrim value, no darker alternative.
Sheet (DESIGN.md `sheet-modal`): **opaque #F7F7F8**, 344px wide, radius 20, `padding: 20px`, 16px internal gaps, `box-shadow: 0px 6px 16px 0px rgba(0, 0, 0, 0.09)` (`floating` — the sheet's own elevation), and bottom padding `calc(20px + env(safe-area-inset-bottom, 12px))`. **A sheet is not a glass surface: zero `backdrop-filter` on it.**
Header: serif 21/700/32 #17171A 让行程走到系统里, then 12/450 #5A5A60 行程数据只存在本机，写入系统应用由你决定 (6.40:1).
Three 64px rows separated by `border-top: 0.5px solid rgba(60, 60, 67, 0.20)`. Each row: 14/600 #17171A title, 12/450 #69696E consequence line, and a switch at the right — **track 44×24 at radius 999, ON filled #0066CC with a 20px #FFFFFF knob, OFF track #E5E5EA with a #69696E knob**; the 64px row is the touch target. **Switches are system controls, not call-to-action buttons — they are not counted against the one solid blue button rule.**
Default states are consent, not decoration: 日历同步 (写入 3 个预约节点 + 5 天行程) **OFF**, 行程卡片 (桌面常驻今日节点，每 15 分钟刷新) ON because it only displays, 提醒 (需预约节点提前 1 天提醒) **OFF**. Nothing that writes into another app arrives pre-checked.
Then the payload preview: a #EFEFF2 panel at **radius 14** with `border-left: 2px solid #0066CC`, an 11/600 #69696E overline 写入内容预览 (4.76:1) and 14/400 #5A5A60 tabular rows — 6月11日 09:00–11:00 / 伏见稻荷大社 · 需预约 / 地址 京都市伏見区深芝藪町 68 / 备注 行程第 2 天 · 步行 12分钟. Informed consent shows the literal payload, not a promise.
Bottom of the sheet: outline 仅本机保存 (transparent, 1px solid rgba(196, 196, 202, 0.40), 16/600 #17171A) beside the sheet's only solid #0066CC button 同意并写入 (44px, radius 999, #FFFFFF 16/600, press 140ms scale 0.97 onto #0055BB) — equal-width flex columns with `gap: 12px`.
The sheet's `floating` declaration is the **only** `box-shadow` on this frame. No icon is required here; if one is drawn it is 22×22 inside a 44×44 hit box, stroke #3C3C43.
```

### 15. 旅行中 · 当前节点与打卡记费用

2026-10-14 发送前预检改了八处：① **`serif 21/700 岚山竹林` 是站名**——自查第 1 条与 TYPE 都规定站名一律 18/600 sans，这处会被 Stitch 顺着复制到下面的行程行上 → 保留 hero 的宋体（它是**页面地名标题档**）并明写「往下每一站都回 sans 18/600」。② **hero 要 `card` 阴影与屏 11 的「hero 一条都不加」自相矛盾**（跨屏漂移）→ 统一成「hero 面板一律无阴影，靠色阶分层」，屏 11 已按此落地。③ `✓` **是文本字符不是图标**——契约的图标只有 22×22 线稿一档 → 改成 22×22 SVG 勾、色用 `已确认 #1C7440`（5.80:1），并禁 emoji。④ transit leg 没重申「透明无填充」（自查第 3 条的已知破口）→ 补回。⑤ `0.5px rules` 没给值 → `rgba(60, 60, 67, 0.20)`。⑥ `Bottom glass dock` 一句话（屏 12 同款漏洞）→ 补全配方与当前项。⑦ 所有字号补字重（12/450、12/600）。⑧ 12px 提示行钉死白底（`#A06400` 压 `#EFEFF2` 只有 4.24）。

```
Screen 15 — 旅行中模式 (in-trip state, day 2, 09:12). Everything answers "where am I now, what's next, how did it go". ONE frame.
Chrome: 60px title bar on rgba(255, 255, 255, 0.44) with backdrop-filter blur(24px) and a 1px rgba(196, 196, 202, 0.40) bottom border; sans 18/600/24 #17171A 进行中 · Day 2 at the left; 12/600 tabular #69696E 09:12 at the right.
Hero panel: #F7F7F8 at radius 28, `padding: 16px`, **no box-shadow** — the same rule as screen 11's hero: the surface ladder does the separation, and a shadow here would drift against that frame. Inside: 11/600 #69696E overline 当前节点; then **serif 21/700/32 #17171A 岚山竹林** — that is the page's place-name title role, **not** the stop-name role: every stop row below stays 18/600 sans; then 12/450 tabular #5A5A60 09:00 开始 · 建议 1.5小时 · 已过 12分钟; a 4px elapsed track on #E9E9EC filled to 13% with #0066CC; and 12/600 #A06400 周一人少，10:00 后团队到达 **on the white canvas, never on a #EFEFF2 panel** (4.86:1 against 4.24:1).
Two actions side by side as equal flex columns with `gap: 12px`, both 44px pills: outline 完成打卡 (transparent, 1px solid rgba(196, 196, 202, 0.40), 16/600 #17171A) and **this screen's only solid #0066CC button** 记一笔费用 (#FFFFFF 16/600, radius 999, press 140ms scale 0.97 onto #0055BB). Below them 12/450 #69696E 打卡会同步到日历和卡片.
Then 下一站: a 44px transit leg — **transparent, no background fill and no radius** (self-check 3), a 2px dashed rgba(60, 60, 67, 0.20) connector, 12/450 #5A5A60 打车 18分钟 · 4.2km · ¥1,900 showing both time and distance. Then one stop row at `min-height: 76px`: 12/600 tabular #5A5A60 11:30, **18/600 sans #17171A 天龙寺**, 12/450 #69696E 建议停留 1小时 · 嵯峨野, and a 需预约 badge (solid #A06400, #FFFFFF 11/600, radius 999).
Then an 11/600 #69696E section label 今日已打卡 and three 44px rows with `border-top: 0.5px solid rgba(60, 60, 67, 0.20)`: 07:40 早餐 ¥900 已打卡 / 08:30 渡月桥 已打卡 / 09:00 竹林 进行中. Times 12/600 tabular #5A5A60, names 14/400 #17171A, amounts 14/600 tabular #17171A right-aligned. A completed row carries a **22×22 SVG check glyph stroked in #1C7440** (5.80:1) — viewBox 24, stroke-width 2, fill none; **never a text ✓ and never an emoji**. The 进行中 row is marked by a 2px #0066CC spine segment on its left edge.
Bottom: the 300×64 floating dock at radius 30 on rgba(255, 255, 255, 0.44) with blur(24px), a 1px rgba(196, 196, 202, 0.40) border and `box-shadow: 0px 6px 16px 0px rgba(0, 0, 0, 0.09)` (closed set `floating`), sitting `calc(28px + env(safe-area-inset-bottom, 12px))` above the bottom edge. Four items 行程 / 地图 / 费用 / 我的, each a 22×22 icon over a 10/400 label, **行程 pressed** — #0066CC icon and label with a ~180px radial glow of rgba(0, 102, 204, 0.10) behind it (a colour change, not a filled button). Scroll content reserves `calc(94px + env(safe-area-inset-bottom, 12px))`.
Of the six closed-set shadows this frame uses **exactly one**: the dock's `floating`. The hero, the leg, the stop row and the checklist carry none. No confetti, no celebration graphic, no new hue — a check glyph and a luminance step are enough.
```

### 16. 分享与导出

2026-10-14 发送前预检改了六处：① **底栏材质整段缺失**（屏 8/9/10 三连击的老洞）→ 补扁平 `#FFFFFF` + `env()` 两条 calc + 零 blur + 滚动预留。② `each an icon in #3C3C43` 没给尺寸 → 44×44 热区套 22×22，并点名图形语义（链接件 / 日历件，**路线不许画成时钟**）。③ 三枚统计数字没给字阶与列宽 → `18/600 tabular` + 契约 `profile_stat_width: 72px` + `gap: 12px`。④ mini route 的五枚节点没画法 → 24px 圆 / `#F2F2F4` 底 / `11/600 #5A5A60` 序号 / 当天实心 `#0066CC`；并把 `rgba(0,102,204,0.35)` 光晕写明是**画出来的描边、不是 box-shadow**（屏 8 同条防误判）。⑤ 这屏**有没有 dock** 原稿没说 → 明写结果页无 dock、由扁平底栏替代（否则 Stitch 会补一颗 dock，玻璃面数就超了）。⑥ 阴影按屏 11 口径声明「一条都不需要」。

```
Screen 16 — 分享结果页. ONE frame; the two export outcomes live inside it as two rows, not two artboards.
Chrome: 60px title bar on rgba(255, 255, 255, 0.44) with backdrop-filter blur(24px) and a 1px rgba(196, 196, 202, 0.40) bottom border; at the left a 44×44 hit box holding a 22×22 back chevron (stroke #3C3C43, viewBox 24, stroke-width 2, fill none); sans 18/600/24 #17171A 分享与导出.
Body: serif 21/700/32 #17171A 分享这份行程, then 14/400 #5A5A60 京都 5天4晚 · 16 个景点 · 步行 24.6km.
Export preview card: #F7F7F8 at radius 20, `padding: 16px`, **no box-shadow**. Inside it a 96px-tall route canvas on the paper palette — gradient #FFFFFF → #F1F2F5, contour hairlines rgba(26, 26, 26, 0.15), water #EAF2FA, and a 2px #0066CC path laid over its own rgba(0, 102, 204, 0.35) wide soft stroke (**a drawn halo, not a box-shadow — do not convert it into one**), carrying **five 24px day nodes** (#F2F2F4 fill, 11/600 tabular #5A5A60 numbers, the current day filled #0066CC). Beneath the route, three equal flex columns with `gap: 12px`, each 72px wide (`spacing.profile_stat_width`): 18/600 tabular #17171A numbers over 12/450 #69696E labels — 天 5 / 站 16 / 步行 24.6km.
Then two option rows at 64px, separated by `border-top: 0.5px solid rgba(60, 60, 67, 0.20)`. Each row: a 44×44 hit box holding a 22×22 glyph in #3C3C43 — a link glyph for the first, a calendar for the second, semantically correct (a route is never drawn as a clock); then 18/600 #17171A title and a 12/450 #69696E consequence line: 分享链接 · 对方打开即看行程，不含你的账号信息 / 导出日历文件 (.ics) · 含 3 个需预约提醒，可导入任意日历应用.
Bottom action bar: **flat opaque #FFFFFF, no translucency and no blur**, `padding: 12px 16px calc(16px + env(safe-area-inset-bottom, 12px)) 16px`, two equal-width pills at 44px with `gap: 12px`: outline 导出 .ics (transparent, 1px solid rgba(196, 196, 202, 0.40), 16/600 #17171A) and **this screen's only solid #0066CC button** 复制链接 (#FFFFFF 16/600, radius 999, press 140ms scale 0.97 onto #0055BB). Inside the bar under the buttons, 12/450 #69696E 链接 7 天内有效. Scroll content reserves `calc(94px + env(safe-area-inset-bottom, 12px))`.
**No dock on this screen** — it is a result page and the flat footer replaces it, so only one glass surface exists here (the title bar). Of the six closed-set shadows this frame uses **none**. No social grid, no row of third-party logos, no new hue.
```

---

## 四、生成后自查清单（每屏对一遍）

| 检查 | 通过标准 |
| --- | --- |
| 颜色 | 无规范外色相；动作色只有 `#0066CC`；深色亮底压 `#121212` 墨字；蓝字未压在蓝 tint 上 |
| 材质 | 玻璃只在顶栏 / Dock / 吸顶日头 / 弹层四处；卡片、时间线行、选项卡、理由块、卡片全是实心 |
| 字体 | 衬线只出现在地名/日头/提问/板块标题；活动名一律无衬线 18/600；无 500/600 衬线；字距 0；数字等宽 |
| 栅格 | 全部间距是 4 的倍数；页面左右 16；触控目标 ≥44；底部留 94 + 导航条 |
| 圆角 | 按钮一律胶囊；卡片 20；卡内嵌套 6（=20−16 同心公式） |
| 语义 | 每个状态都有「词」：需预约 / 已确认 / 必去 / 冲突；禁止只靠颜色传达 |
| AI 观感 | 无对话气泡、无 AI 头像、无打字指示器、无闪光图标；每屏能看到「为什么 + 多久 + 要不要预约」 |
| 兜底 | 每道追问都有「帮我选」；失败态点名失败环节；默认值能一路走完 |
| **设计系统** | `grep -l 'tailwind.config=' */code.html` 命中数为 0；命中即该屏是在 Stitch 自建的 `有据与有径`（primary `#004e9f` + M3 色板 + Plus Jakarta Sans）下生成的，契约未生效，必须切回契约重画 |
| **色值审计** | 不能只数文档里的 raw hex——66 个 M3 token 里通常只有 2～6 个真被 class 消费。要把 `tailwind.config` 解析出来，只看 `bg-*` / `text-*` / `ring-*` 实际引用的键值，再和契约色集比对 |

---

## 五、第二轮返修提示词（9 屏：常驻框 v2 + 5 色坏屏重做 + 4 缺失屏）

> 来源：第一轮审查后在对话里交付的 9 条提示词，此处回填以保持本文件为唯一来源。
> 注：其中 5 屏（_22/day_1_2/_23  lineage）在第三轮又各返修一次，见第六、七章。

### 〇、`Additional instructions` 常驻框 v2（整框替换旧的）

```
Hard constraints for every frame in this project:
- Phone portrait, 360vp artboard. Light mode. All spacing on a 4px baseline: 4 / 8 / 12 / 16 / 20 / 24 / 32 / 48. Page padding 16. Touch targets ≥44×44.
- COLOR FORMAT: CSS only. NEVER write an 8-digit hex. ArkTS #AARRGGBB (alpha FIRST) is not CSS #RRGGBBAA (alpha LAST) — the 8-digit literal 1A 00 66 CC read as CSS is a solid indigo block, not a 10% blue tint. All translucency is rgba(); the DESIGN.md translucency ledger has both spellings.
- CLOSED GREY SCALE. Surfaces: #FFFFFF #F7F7F8 #F2F2F4 #EFEFF2 #E9E9EC #E8E8EC #E5E5EA. Text/icons: #17171A #5A5A60 #69696E #9E9EA3 #3C3C43. Banned (they appeared last round): #F0F2F5 #F2F2F5 #E2E4E8 #E5E7EB #E5E5EB #EEF0F3 #FAFAFC #C4C4CA #D1D1D6 #1C1C1E #EAF7EE #E5F0FA #FFF8EB #FFF4E5 #FFE8BF.
- BADGE / CHIP FILL LAW: either a solid semantic fill (#9A6206 / #A06400 / #1C7440 / #C0392B / #0066CC) with a #FFFFFF label, or a neutral #F2F2F4 / #EFEFF2 fill with a #5A5A60 / #17171A label, or a 10% blue wash rgba(0, 102, 204, 0.10) with a #17171A label and a 1px #0066CC border. Pastel cream/mint tints are not in this system.
- Type: 32/700/44 serif display · 21/700/32 serif title · 21/650/28 sans · 18/600/24 headline (all stop names, SANS) · 16/400/24 body · 14/400/20 · 12/450/16 caption · 12/600 itinerary-time · 11/600 overline · 10/400 dock label. Allowed sizes ONLY: 10 11 12 14 16 18 21 32 — 13/15/17/19/20 do not exist here. Serif never on a control, never on a stop name. Letter-spacing 0. Every numeral tabular.
- Radius: cards 20, nested-in-card 6, chips/inputs 10, reason blocks 14, hero 28, dock + segmented 30, buttons + badges + avatars pill 999. Buttons are ALWAYS pill.
- Buttons: exactly one solid #0066CC primary CTA per screen, 44px tall; everything else transparent with a 1px rgba(196, 196, 202, 0.40) outline. Never a second blue button. Press = scale 0.97, 140ms.
- Chrome: title bar 60px; floating dock 300×64 centred, 30px radius, 28px above the nav inset; content reserves 94px + nav inset. Glass on exactly four surfaces: top bar rgba(255, 255, 255, 0.44), dock, sticky day header, sheets.
- Timeline geometry: the time gutter is a 52px RIGHT-aligned tabular column, then a 2px spine with nodes centred on it, then the row. Stop rows ≥76px. Transit legs 44px showing BOTH time and distance.
- Contrast: labels ≥4.5:1; icons, dots, route strokes ≥3:1. Never blue text on a blue wash. Never white text on a dark-mode bright fill.
- Dividers 0.5px, only between like rows. Cards separated by whitespace, not lines.
- Motion described, not shown: press 140 / control 220 / container 320 / page 420 / route draw 460 / stagger 40 / shimmer 1200.
- Every AI output screen answers three questions in visible data: why this stop, how long, does it need booking.
```

### 一、首启与静默登录（替代 _2 / _7 / _10 三份重复）

```
Regenerate 有径's first-run screen as ONE frame (last round produced three near-identical copies). White canvas, no hero image, no illustration.
Top block: serif 32/700 wordmark 有径, an 11/600 #69696E overline "TRACEABLE ROUTES" under it with 0 letter-spacing, then a 14/400 #5A5A60 tagline 有迹可循，有径可行.
Middle: one 20px-radius panel on #F7F7F8, 16px padding, card shadow — inside it a real 3-row day preview so the value proposition is structure, not copy: a 52px RIGHT-aligned tabular time column (07:30 / 09:50 / 12:10 in 12/600 #17171A), a 2px #E9E9EC spine with three 16px nodes (10px inner dot: 景点 #0066CC, 景点 #0066CC, 餐饮 #9A6206), and stop names in SANS 18/600 #17171A — 伏见稻荷大社 / 清水寺 / 午餐 · 一番街. One row carries a 需预约 badge: solid #A06400 fill, #FFFFFF 11/600 label. No cream or mint badge tints anywhere.
Bottom: exactly one solid #0066CC pill CTA, 44px, 16/600 #FFFFFF label 华为账号一键登录 with a white Huawei-id glyph; beneath it a 12/450 #69696E legal line, two lines max: 使用华为账号 UnionID 登录 · 行程数据只保存在本机. No carousel, no secondary button, no social proof row.
Fix list for this frame: the previous indigo selected/feature blocks came from reading the literal 1A 00 66 CC as CSS — if you need a blue wash, write rgba(0, 102, 204, 0.10).
```

### 二、行程时间线主视图 · Day 1（修 _1）

```
Regenerate 有径's main timeline (Day 1). Three specific defects to fix from the previous frame.
Chrome: 60px title bar — SANS 18/600 京都 · 5天4晚 on the left (this is a trip name on a control bar, not a place title, so it is sans), a 已规划 neutral chip (#F2F2F4 fill, #5A5A60 11/600 label), then two 44px icon buttons (share, more) in #3C3C43.
Under the bar: a 36px segmented control, 30px radius, track rgba(60, 60, 67, 0.10) with a 1px rgba(60, 60, 67, 0.18) border, 20px blur. Items Day 1 / Day 2 / Day 3 / +2. DEFECT 1: the selected pill must be rgba(239, 239, 242, 0.60) — a near-white 60% panel grey with a 1px rgba(196, 196, 202, 0.40) border and a soft rgba(0, 102, 204, 0.18) shadow. It is NOT cyan; the literal 99 EF EF F2 read as CSS is cyan, do not use it. Selected label 14/600 #17171A, unselected 14/400 #69696E.
Route map: 200px tall, 20px radius, paper palette — gradient #FFFFFF → #F1F2F5, contour hairlines rgba(26, 26, 26, 0.15), water #EAF2FA, a 2px #0066CC path with a 6px rgba(0, 102, 204, 0.35) halo beneath it, four 24px numbered nodes (white fill, 1px #17171A ring, 10px activity dot), node 1 ringed in #A06400 with a small ★ for 必去. Overlay a 12px caption chip on #FFFFFF at 6px radius: 步行 6.4km · 打车 1 段.
Sticky day header 44px on rgba(255, 255, 255, 0.44) glass with blur 24: serif 21/700 Day 1 · 6月10日 周二 left, 12/450 #69696E 东山 · 清水 right.
The spine, DEFECT 2: the time gutter is a 52px RIGHT-aligned tabular column — 07:30 over a 11/600 #9E9EA3 清晨, then the 2px spine with nodes centred on it, then the row. Stop names are SANS 18/600 #17171A (DEFECT 3: they were serif last round; a serif list row makes a plan read like an article), meta 12/450 #69696E 建议停留 2小时 · 稻荷山麓, a 必去 badge on solid #9A6206 with #FFFFFF label, and a 32px photo thumb at 6px radius on #E9E9EC.
Two of the five rows expanded with a reason block: #EFEFF2, 14px radius, 2px #0066CC left rule, 11/600 #69696E overline 为什么排在这里, 14/400 #5A5A60 body.
Transit legs between rows: 44px, #F2F2F4 fill, 10px radius, 2px dashed #C4C4CA-free connector in #9E9EA3, 12/450 #5A5A60 with tabular: 步行 18分钟 · 1.2km / 打车 25分钟 · ¥2,800.
Bottom: 300×64 glass dock, 30px radius, four items 行程 / 地图 / 费用 / 我的 at 10/400, active #0066CC with an 18px rgba(0, 102, 204, 0.18) glow. Content reserves 94px + nav inset.
```

### 三、偏好追问状态机（修 _12 的靛紫选项卡）

```
Regenerate the four-question interview, two frames, no chat affordances.
Frame 1 — 核心偏好（第 2/4 步）: 60px title bar with 11/600 #69696E 第 2/4 步 left, 12/450 #17171A 偏好追问 right, plus a 4px track #3/4 filled #0066CC on #E9E9EC. Body: serif 21/700/32 question 这趟想怎么过？, 14/400 #5A5A60 helper 只影响推荐排序，随时可改. Then five option cards, 8px gaps: 休闲 / 暴走 / 亲子 / 美食 / 文化. Each card min 56px, #F7F7F8, 20px radius, 16px padding, 16/400 #17171A label + 12/450 #69696E consequence line.
THE SELECTED CARD IS THE FIX: 美食 selected = fill rgba(0, 102, 204, 0.10) (a 10% blue wash over the white canvas, i.e. a very pale blue-grey), 1px #0066CC border, a 20px #0066CC check top-right, label STILL #17171A and sub-line STILL #69696E. Last round it rendered as a solid indigo block with washed-out grey text — that is the CSS-vs-ArkTS hex bug; an opaque #1A0066 fill is banned outright, and no label may go below 4.5:1.
Below: four 6px dots (three #0066CC, one #E9E9EC), then outline 上一题 and ghost 帮我选.
Frame 2 — 节奏偏好（第 3/4 步）: three cards 每天 3 个活动 / 每天 4–5 个 / 每天 6+ 个, each with an 11/600 neutral tag 轻松 / 标准 / 紧凑 (#F2F2F4 fill, #5A5A60 label). The middle one selected with the same wash+border+ink treatment. The third carries an inline 12/450 #A06400 advisory with a 4px leading dot: 可能偏紧，建议留白 — ochre, never red, and it sits on the white canvas, not on a #EFEFF2 panel.
```

### 四、行程基础输入（修 _5 / _11 / _15 / _17 四份重复）

```
Regenerate 有径's trip-input screen as ONE frame. White canvas, no hero.
Serif 21/700 page title 规划一趟行程, then four field rows stacked at 12px: each #F7F7F8, 20px radius, 64px tall, 16px padding — left column 11/600 #69696E overline label over an 18/600 #17171A value, right a 44px hit box holding a 20px chevron in #69696E (not #9E9EA3, which is 2.67:1 and invisible as an affordance).
Rows: 目的地 → 京都 · 日本 (serif, it names a place); 出行日期 → 6月10日 – 6月14日 (sans, tabular) with 5天4晚 in 12/450 #69696E beneath; 同行人数 → 2 位成人 plus three 32px pill quick-picks 1 / 2 / 4 — unselected #F2F2F4 with #17171A, selected rgba(0, 102, 204, 0.10) + 1px #0066CC border + #17171A label; 预算档位 → ¥8,000 / 人 (tabular).
Under the budget row only: a 4px track on #E9E9EC with a #0066CC filled segment to 55%, flanked by 11/600 #69696E endpoints 经济 and 舒适.
Bottom: exactly one solid #0066CC pill CTA 开始规划. The only graphic on the page is the budget track.
```

### 五、住宿区域精选与通勤分析（修 _8 / _9）

```
Regenerate the lodging-area screen, one frame (two near-identical copies exist).
60px title bar: sans 18/600/24 住哪一片 left, 12/450 #0066CC text action 查看更多区域 in a 44px hit box right.
Top: a 200px map card, 20px radius, paper palette (gradient #FFFFFF → #F1F2F5, contours rgba(26, 26, 26, 0.15), water #EAF2FA). THREE candidate zones as soft washes rgba(0, 102, 204, 0.10) with a 1px #0066CC outline, each labelled with a 12/450 #17171A caption on a 6px-radius #FFFFFF chip; a 2px #0066CC route trace with rgba(0, 102, 204, 0.35) halo connecting four numbered sight nodes. No map tiles, no pins.
Then two area cards, #F7F7F8, 20px radius, 16px padding, 12px apart. Row 1: 18/600 #17171A 祇园 · 东山 + an 11/600 badge "AI 精选 1" on solid #9A6206 with #FFFFFF label. Row 2: a reason block #EFEFF2, 14px radius, 2px #0066CC left rule, 11/600 #69696E overline 为什么是这里, 14/400 #5A5A60 text 早上 7 点前能空着走进清水寺，避开旅行团. Row 3: a three-stat commute row — numbers 18/600 #17171A tabular, labels 12/450 #69696E, 72–84px per stat, no dividers: 到首个景点 步行 12分钟 / 日均通勤 34分钟 / 舒适型房源 9 家.
Selected card: 1px #0066CC border + 20px blue check + rgba(0, 102, 204, 0.10) wash, label stays #17171A. Do not fill the card with an opaque indigo.
Bottom: solid #0066CC pill 就住这里, and a full-width ghost 帮我选（按通勤最短） in 14/400 #0066CC beneath it.
```

### 六、景点挑选与优先级（缺失屏）

```
New screen — 景点选择. Reads a curated on-device database; the AI only sorts and annotates.
60px title bar: sans 18/600/24 选想去的地方 left, 12/450 #0066CC text action 推荐更多 right.
Sticky 44px summary strip on #EFEFF2: 12/450 #5A5A60 已选 7 / 可用 4.2 天 · 建议上限 16 个 (tabular), plus a 4px capacity track #0066CC at 44% on #E9E9EC.
One advisory banner only: #EFEFF2 panel, 14px radius, 2px #0066CC left rule, 11/600 #69696E overline 时间偏紧, 14/400 #5A5A60 按现在的节奏，建议给景点标优先级，行程会自动取舍. Ochre/blue, never red — this is advice, not failure.
Grouped list with 11/600 #69696E overline section headers carrying counts: 文化 · 4 / 美食 · 3 / 自然 · 2. Each row 76px minimum: a 24px include toggle at the left edge (#0066CC check when on), a 6px-radius 3:4 thumb on #E9E9EC (placeholder, no photo), SANS 18/600 #17171A name 清水寺, 12/450 #69696E meta 建议停留 2小时 · 东山区, and on the right a booking badge — 需预约 solid #A06400 + #FFFFFF, 免费入内 neutral #F2F2F4 + #5A5A60, 已确认 solid #1C7440 + #FFFFFF.
Priority control: three small pills 必去 / 想去 / 可选 in a 44px row. Unselected #F2F2F4 with #5A5A60; 必去 selected = solid #9A6206 fill + #FFFFFF label; 想去 selected = rgba(0, 102, 204, 0.10) + 1px #0066CC border + #17171A label; 可选 selected = #EFEFF2 + #17171A. Every state also carries its word — colour never carries meaning alone.
Bottom: solid #0066CC pill 下一步 · 选住宿, with a ghost 查看全部景点 to its left.
```

### 七、行程编辑态 · 拖动调整（缺失屏）

```
New screen — the same Day 1 timeline in edit mode. Show the drag affordance explicitly.
Title bar: sans 18/600/24 编辑中 left, 12/450 #0066CC 完成 text action right.
Every stop row grows a 24px drag-handle column (six 3px dots in #69696E) on its LEFT, outside the 52px time gutter, and rows lift from #FFFFFF to #F7F7F8 with the 10px card shadow.
One row is mid-drag: scale 1.02, #FFFFFF fill, 16px floating shadow, 1px #0066CC border, displaced 8px off the spine. The spine shows a 2px #0066CC insertion gap between two nodes; the vacated row collapses to 40% opacity. A 12/450 #69696E caption beside the gap reads 拖到第 2 天 · 余量 3.5 小时 (tabular).
Trailing per-row actions visible only in this mode: a 20px swap icon and a 20px minus icon in #3C3C43, each inside a 44px hit box.
Constraint warning when a move breaks the plan: 12/450 #A06400 text on the white canvas (never on a #EFEFF2 panel, where it measures 4.24:1) — 移走后第 1 天空 2.5 小时，可补一个可选景点 — with a 12/450 #0066CC 补一个 text action.
Bottom: the dock is replaced by a 64px bar, outline 撤销 left and solid #0066CC 保存修改 right, 16px page padding.
```

### 八、节点详情 · 预约、冲突与耗时（缺失屏）

```
New screen — one activity node's detail page.
Full-bleed 3:4 image placeholder on #E9E9EC at the top, inner corners 6px per the concentric rule, title bar floating over it with a 44px back button in #17171A and a 92px gradient fade rgba(255, 255, 255, 0.44) → transparent.
Header: serif 21/700 伏见稻荷大社, then a badge row — 必去 solid #9A6206 + #FFFFFF, 需预约 solid #A06400 + #FFFFFF, 免费入内 neutral #F2F2F4 + #5A5A60. Every badge has a word.
Stat strip: four tabular 18/600 #17171A numbers over 12/450 #69696E labels, 72–84px each, no dividers: 停留 2.5小时 / 到达 07:40 / 步行 12分钟 / 门票 ¥0.
Open-hours block as a two-column table at 14/400: 开放时间 → 全天（24 小时）, 建议时段 → 06:30–08:00 · 人少 in #17171A; then one 12/450 #A06400 advisory on the canvas: 红叶季周末 09:00 后山道拥挤.
Reason block: #EFEFF2, 14px radius, 2px #0066CC left rule, 11/600 #69696E overline 为什么排在这里, 14/400 #5A5A60 排在第 1 天最早，是因为它在山脚，后续三点可一路步行上山，省掉两段打车.
A 2px #0066CC mini route strip placing this node between its neighbours, labelled 上一站 06:50 一条 and 下一站 10:20 东福寺 in 12/450 #69696E with tabular times.
Location row: 16/400 #17171A 京都市伏見区深芝藪町 68 with a 44px chevron in #69696E. No map screenshot.
Bottom: outline 换一个时间 left, solid #0066CC 加入日历提醒 right.
```

### 九、分享与导出（缺失屏）

```
New screen — 分享结果页, one screen, two described outcomes.
60px title bar with sans 18/600/24 分享 back into 行程.
Body: serif 21/700 分享这份行程, then 14/400 #5A5A60 京都 5天4晚 · 16 个景点 · 步行 24.6km (tabular).
An export preview card: #F7F7F8, 20px radius, 16px padding, containing a 96px-tall horizontal mini route strip on the paper palette (gradient #FFFFFF → #F1F2F5, contours rgba(26, 26, 26, 0.15), 2px #0066CC path with rgba(0, 102, 204, 0.35) halo, five numbered day nodes, the 必去 day ringed #A06400), then three tabular stats with 12/450 #69696E labels: 5 天 / 16 景点 / 3 需预约.
Two option rows at 64px separated by 0.5px rules, each a 24px icon in #3C3C43, an 18/600 #17171A title and a 12/450 #69696E consequence line: 分享链接 → 对方打开即看行程，不含你的账号信息; 导出日历文件 .ics → 含 3 个需预约提醒，可导入任意日历应用.
Bottom: solid #0066CC 复制链接, outline 导出 .ics, and a 12/450 #69696E note under the CTA: 链接 7 天内有效.
No social-grid of six platform logos — two explicit outcomes with stated consequences.
```

## 六、第三轮返修提示词（3 屏：_22 节点详情 / day_1_2 编辑态 / _23 景点选择）

前置：Stitch 项目里的设计系统必须切到我们的 `DESIGN.md`（8 位 hex 已归零的那版），不要选 Stitch 自己压缩出来的 `youju_family_design_language` / `youju_youjing` 两份——它们带 Material 3 的 `surface-container-*` 紫灰系，_22 与 day_1_2 上一轮就是被它们污染的。

### 22r. 节点详情 · 预约、冲突与耗时

```
Redraw ONE phone screen (360vp wide, portrait, light mode) — 有径's single activity-node detail page.
DEFECTS TO FIX from the previous frame: it was rendered as a desktop web page (a top nav bar with 有径 Youjing / 节点详情 / 行程编排 / 全局预览) — remove all browser chrome, phone frame only; the surfaces used a lavender-tinted Material grey (#FCF8FC / #E4E1E6 / #AAC7FF are banned, the canvas is #FFFFFF and the ladder is #F7F7F8 / #F2F2F4 / #EFEFF2 / #E9E9EC); a sparkle glyph and a fabricated "人流减少 70%" statistic appeared — no invented percentages, no sparkle motif; a stock photograph with legible painted kanji appeared — use a flat placeholder instead.
Top: a full-bleed 3:4 media block on #E9E9EC with inner corners 6px, no photo content, and a 44px back button in #17171A floating over it; a 92px gradient fade rgba(255, 255, 255, 0.44) → transparent carries it into the title bar.
Header: serif 21/700 #17171A 伏见稻荷大社. Then a badge row, each 11/600 with a word: 必去 solid #9A6206 fill + #FFFFFF label; 需预约 solid #A06400 fill + #FFFFFF label; 免费入内 neutral #F2F2F4 fill + #5A5A60 label. Pill radius 999.
Stat strip: four tabular 18/600 #17171A numbers over 12/450 #69696E labels, 72–84px per stat, no dividers, no card behind them: 停留 2.5小时 / 到达 07:40 / 步行 12分钟 / 门票 ¥0.
Open-hours block: two-column rows at 14/400 — 开放时间 → 全天（24 小时）, 建议时段 → 06:30–08:00 · 人少, labels #69696E and values #17171A, separated by 0.5px rules. Beneath it one 12/450 #A06400 advisory on the white canvas with a 4px leading ochre dot: 红叶季周末 09:00 后山道拥挤.
Reason block: #EFEFF2 fill, 14px radius, 2px #0066CC left rule, 11/600 #69696E overline 为什么排在这里, 14/400 #5A5A60 text 排在第 1 天最早，是因为它在山脚，后续三点可一路步行上山，省掉两段打车.
Route position strip: a 2px #0066CC line with a 6px rgba(0, 102, 204, 0.35) halo, three nodes — neighbours 16px with 1px #17171A ring, this node 24px with a #0066CC fill — labelled 上一站 06:50 一条 / 伏见稻荷 07:40 / 下一站 10:20 东福寺 in 12/450 #69696E with tabular times.
Location row: 64px, #F7F7F8, 20px radius, 16px padding — 16/400 #17171A 京都市伏見区深芝藪町 68, 12/450 #69696E JR 奈良线 稻荷站 出口向东步行 2分钟, a 20px chevron in #69696E inside a 44px hit box. No map tile.
Bottom bar: outline 换一个时间 (transparent, 1px rgba(196, 196, 202, 0.40)) and solid #0066CC 加入日历提醒, both pill, 44px.
Type sizes allowed: 10 / 11 / 12 / 14 / 16 / 18 / 21 / 32 only. Letter-spacing 0. Every numeral tabular.
```

### day_1_2r. 行程编辑 · 拖动调整

```
Redraw ONE phone screen — 有径's Day 1 timeline in edit mode, 360vp portrait, light mode.
DEFECTS TO FIX: the previous frame painted several solid indigo shapes (a 编辑模式 pill, a time-slot block, a drag-handle block) — those are the CSS-vs-ArkTS hex bug; an opaque #1A0066 fill is banned in this project, and the only blue wash allowed is rgba(0, 102, 204, 0.10). It also set stop names in serif and truncated meta lines with an ellipsis — names are sans, and every string must fit.
Title bar 60px: SANS 18/600 #17171A 编辑中 on the left with a 12/450 #69696E sub-line Day 1 · 拖拽调整顺序或跨天移动, and a 12/450 #0066CC 完成 text action in a 44px hit box on the right. No badge next to the title.
Constraint advisory directly under the bar: 12/450 #A06400 on the white canvas with a 4px leading ochre dot — 移走后第 1 天空 2.5 小时，可补一个可选景点 — plus a 12/450 #0066CC 补一个 text action at the right edge.
Every stop row: a 24px drag handle of six 3px dots in #69696E at the far left (outside the gutter, never a filled block), then a 52px RIGHT-aligned tabular time column (12/600 #17171A over an 11/600 #9E9EA3 清晨 / 上午 / 午后 / 傍晚), then a 2px #E9E9EC spine with a 24px node (white fill, 1px #17171A ring, 10px activity dot), then the row card: #F7F7F8, 20px radius, 16px padding, min-height 76px, 10px card shadow. Row content: SANS 18/600 #17171A stop name, 12/450 #69696E meta written in full (建议停留 2小时 · 稻荷山麓, no ellipsis), a 必去 badge on solid #9A6206 with #FFFFFF label where applicable, and at the trailing edge a 20px swap icon and a 20px minus icon in #3C3C43, each inside a 44px hit box.
One row is mid-drag (二年坂 · 三年坂): scale 1.02, #FFFFFF fill, 16px floating shadow, 1px #0066CC border, displaced 8px off the spine, its node enlarged to 28px with a rgba(0, 102, 204, 0.18) glow.
The spine at the drop position shows a 2px #0066CC insertion gap 40px tall with a small pill label 插入点 — solid #0066CC fill, #FFFFFF 11/600 label — and a 12/450 #69696E caption beside it: 可移至第 2 天 · 余量 3.5 小时 (tabular).
The vacated row (12:30) collapses to 40% opacity with a 2px dashed #C4C4CA-free outline in #E9E9EC; keep its time and name legible at that opacity.
Bottom: the dock is replaced by a 64px action bar — outline 撤销 left, solid #0066CC 保存修改 right, both pill 44px, 16px page padding.
Spacing on the 4px grid; type sizes 10 / 11 / 12 / 14 / 16 / 18 / 21 / 32 only; letter-spacing 0.
```

### 23r. 景点挑选与优先级

```
Redraw ONE phone screen — 有径's attraction picker, 360vp portrait, light mode. It reads a curated on-device database; the AI only sorts and annotates.
DEFECT TO FIX: the sticky summary strip's text overlapped the 4px capacity track and the trailing 个 was clipped. Give the strip an explicit two-row grid — text line on top, track below, no absolute positioning, no overlap — and make the sentence short enough to fit one line at 12px.
Title bar 60px: serif 18/700 #17171A 选想去的地方 left, 12/450 #0066CC 推荐更多 text action in a 44px hit box right.
Sticky summary strip, 60px tall total, #EFEFF2 fill, 16px horizontal padding, 12px vertical: row A = 12/450 #5A5A60 已选 7 个 · 可用 4.2 天 · 上限 16 个 (tabular, single line, no wrap); row B = a 4px track on #E9E9EC filled to 44% with #0066CC. Nothing overlaps; the strip sticks under the title bar.
Advisory banner, one only: #EFEFF2 panel, 14px radius, 2px #0066CC left rule, 11/600 #69696E overline 时间偏紧 with a 4px leading #A06400 dot, 14/400 #5A5A60 body 按现在的节奏，建议给景点标优先级，行程会自动取舍. Ochre and blue only — never red, this is advice, not failure.
Grouped list with 11/600 #69696E section headers carrying counts: 文化 · 4 / 美食 · 3 / 自然 · 2. Each row is one card, #F7F7F8, 20px radius, 16px padding, min-height 76px, 12px apart: a 24px include toggle at the left edge (#0066CC fill with a white check when on, #F2F2F4 with no fill when off), a 6px-radius 3:4 thumb on #E9E9EC (flat placeholder, no photograph), SANS 18/600 #17171A name 清水寺, 12/450 #69696E meta 建议停留 2小时 · 东山区 written in full, and at the trailing edge a booking badge — 需预约 solid #A06400 + #FFFFFF, 免费入内 neutral #F2F2F4 + #5A5A60, 已确认 solid #1C7440 + #FFFFFF.
Under the name, a priority control on its own line: an 11/600 #69696E label 优先级 then three pill segments 必去 / 想去 / 可选. Unselected = #F2F2F4 fill with #5A5A60 label. 必去 selected = solid #9A6206 fill + #FFFFFF label. 想去 selected = rgba(0, 102, 204, 0.10) fill + 1px #0066CC border + #17171A label. 可选 selected = #EFEFF2 fill + #17171A label. Every state keeps its word — colour never carries meaning alone. No indigo, no cream or mint tints.
Bottom: solid #0066CC pill 下一步 · 选住宿 with a ghost 查看全部景点 (14/400 #0066CC) to its left. Exactly one solid blue control on the screen.
Type sizes allowed: 10 / 11 / 12 / 14 / 16 / 18 / 21 / 32 only. Letter-spacing 0. Tabular numerals throughout.
```
---

## 七、第四轮返修提示词（2 屏重做 + 5 屏遗留色坏）

### 前置：先把 Stitch 的设计系统问题解决掉，否则重画无效

第三轮导出包里同时存在两份设计系统，证据如下（导出目录 `stitch_youjing_travel_itinerary_planner/`）：

| 文件 | 大小 | 身份 | 处置 |
| --- | --- | --- | --- |
| `DESIGN.md` | 6,914 B | Stitch 自己压缩出的 `有据与有径`：60 色、纯 Material 3 键名、`primary: #004e9f`、`secondary: #4c4aca` | **删除或在项目里停用** |
| `design.md_3.md` | 68,257 B / 1157 行 | md5 `42a4a517e7a21231ac60047ff540f787`，与 `~/Documents/StitchDesign/DESIGN.md` 逐字节相同 | 保留，作为唯一设计系统 |

判定机制（已验证）：42 个 `code.html` 里只有 `_25`、`day_1_2`、`day_1_3` 三屏被注入了 `tailwind.config=` 色板 blob，这三屏的 `primary` 全是 `#004E9F`、12 个字体角色全是 `Plus Jakarta Sans`——即它们是在 `有据与有径` 下生成的，契约没生效；同批的 `_26` 没有 blob，因此 18/18 色值全部在契约内。

所以每轮导出后先跑这一条自查，命中数必须为 0：

```
grep -l 'tailwind.config=' */code.html
```

### 常驻框 v3 增补条款（追加到第二章整框末尾）

```
- NO DESIGN-SYSTEM INJECTION: do not emit a `tailwind.config` block, a `:root` custom-property palette, or any Material 3 token name (surface-container-low / on-surface-variant / outline-variant / surface-tint / primary-container / tertiary-container). Every color is written literally at the point of use, either as a contract 6-digit hex or as rgba(). If a color would need alpha, write rgba() — never an 8-digit hex.
- FONTS: only "Noto Serif SC" (400/700, place and day titles and question titles only) and "HarmonyOS Sans" (everything operable, every stop name, every numeral). No Plus Jakarta Sans, no Inter, no Roboto.
- GEOMETRY: radii are exactly the contract's eight `rounded` tokens — 0 / 6 / 10 / 14 / 20 / 28 / 30 / 999 (6 media and nested, 10 chips and inputs, 14 reason blocks, 20 cards and sheets, 28 hero panels, 30 dock and segmented, 999 every button and badge). Type sizes only 10 / 11 / 12 / 14 / 16 / 18 / 21 / 32 — an icon glyph may sit at 20px, nothing else.
```

### 25r2. 节点详情（重做 `_25`）

```
Redraw ONE phone screen (360vp, portrait, light mode) — 有径's activity-node detail page. Same content as before; fix four specific regressions.
DEFECTS TO FIX: (1) the "本站" node carries a focus ring declared as ring-primary-tint whose token value was the 8-digit literal 1A 00 66 CC — ArkTS alpha-first read as CSS alpha-last, so it rendered as a solid indigo halo. Write the ring as rgba(0, 102, 204, 0.10) instead, and emit no token palette at all. (2) Every text role resolves to Plus Jakarta Sans; the page title 伏见稻荷大社 must be Noto Serif SC 700 and everything else HarmonyOS Sans. (3) Off-ladder sizes 13px and 22px and a 14px radius appeared — sizes only 10/11/12/14/16/18/21/32, radii only 6/20/999. (4) text-on-surface #1B1B1E is not a contract ink; the only dark text colors are #17171A, #5A5A60, #69696E, #9E9EA3, #3C3C43.
Layout, unchanged: full-bleed 3:4 media block on #E9E9EC with 6px inner corners and a flat placeholder (no photograph, no painted kanji), 44px back button in #17171A over it, 92px fade rgba(255, 255, 255, 0.44) → transparent.
Header 伏见稻荷大社 in Noto Serif SC 21/700 #17171A. Badge row: 必去 solid #9A6206 + #FFFFFF label, 需预约 solid #A06400 + #FFFFFF label, 免费入内 #F2F2F4 + #5A5A60 label, all 11/600 pill 999.
Stat strip, no card and no dividers: 停留 2.5小时 / 到达 07:40 / 步行 12分钟 / 门票 ¥0 — numerals 18/600 #17171A tabular, unit and label 12/450 #69696E.
Rows: 开放时间 → 全天（24 小时）, 建议时段 → 06:30–08:00 · 人少, 14/400, label #69696E value #17171A, 0.5px rgba(60, 60, 67, 0.20) rules. Beneath, one 12/450 #A06400 advisory on white canvas with a 4px ochre leading dot: 红叶季周末 09:00 后山道拥挤.
Reason block: #EFEFF2 fill, 20px radius, 2px #0066CC left rule, overline 为什么排在这里 11/600 #69696E, body 14/400 #5A5A60.
Route position strip: 2px #0066CC line with a 6px rgba(0, 102, 204, 0.35) halo; neighbours 16px circles with 1px #17171A ring on #FFFFFF, this node 24px #0066CC fill with a rgba(0, 102, 204, 0.10) ring; labels 12/450 #69696E with tabular times 上一站 06:50 一条 / 本站 07:40 伏见稻荷 / 下一站 10:20 东福寺.
Location row 64px #F7F7F8 radius 20 padding 16: 16/400 #17171A 京都市伏見区深芝藪町 68, 12/450 #69696E JR 奈良线「稻荷站」出口向东步行 2分钟, 20px chevron #69696E in a 44px hit box. No map tile.
Bottom bar: outline 换一个时间 (transparent, 1px rgba(196, 196, 202, 0.40)) + solid #0066CC 加入日历提醒, both pill 999, 44px tall, 16px page padding.
Letter-spacing 0. Nothing truncates — every string must fit at its own size.
```

### day_1_3r2. 行程编辑态（重做 `day_1_3`）

```
Redraw ONE phone screen (360vp, portrait, light mode) — 有径's itinerary edit mode on Day 1. Same five-stop list; fix five regressions.
DEFECTS TO FIX: (1) The palette came from an injected design system where primary = #004E9F; that value is banned. The only action blue is #0066CC (pressed #0055BB). 完成, 补一个, the 13:10 dragged timestamp, the active card ring, and the 保存修改 fill must all be #0066CC. (2) One route dot rendered as #4C4ACA (M3 secondary) — a violet dot on a blue app. Every node dot is either #0066CC, #17171A outline, or #9E9EA3 for an empty slot; no other hue. (3) #AF4900 appeared — the only warm colors allowed are #9A6206, #A06400, #1C7440, #C0392B. (4) Stop names are truncated with ellipsis (伏见稻荷大…) — truncation is banned on stop names; shorten the copy to 伏见稻荷 or let the name wrap to two lines, and never clip the row. (5) The dragged card runs past the right edge so its remove button is clipped: the card must stay inside 16px page padding at all times, including while lifted.
Also: no tailwind.config or :root palette, no Material token names, HarmonyOS Sans for every string in this frame (edit mode is all-operable, so no serif), sizes only 10/11/12/14/16/18/21/32 except 20px icon glyphs.
Layout: title row 编辑中 21/700 #17171A over Day 1 · 拖动调整顺序或跨天移动 12/450 #69696E, right-aligned 完成 14/600 #0066CC in a 44px hit box. Below, one 12/450 #A06400 advisory on white canvas with a 4px ochre dot: 移走后第 1 天空 2.5 小时，可补一个可选景点, right-aligned 补一个 12/600 #0066CC.
Timeline column: 52px right-aligned gutter, tabular numerals — time 14/600 #17171A over daypart 10/450 #69696E; a 1px #E5E5EA rail; a 10px node dot per stop.
Stop card: #F7F7F8, radius 20, padding 16, min-height 76, row = 24px drag handle #9E9EA3 in a 44px hit box, name 16/600 #17171A, 必去 badge solid #9A6206 + #FFFFFF 11/600, meta 12/450 #69696E 建议停留 2小时 · 稻荷山麓, then reorder 20px #3C3C43 and remove 20px #3C3C43 icons each in a 44px hit box.
Empty slot: same card at #FFFFFF with 1px #E5E5EA border, name #9E9EA3, meta 原停留 1.5 小时 · 空档位 #9E9EA3, a 20px history icon #9E9EA3.
Lifted card (13:10 二年坂 · 三年坂): #FFFFFF, 1px #0066CC ring, shadow 0 6px 16px rgba(0, 0, 0, 0.09), moved 8px right of the rail, 24px move icon #0066CC.
Insertion point: a 24px solid #0066CC pill 插入点 with 11/600 #FFFFFF label sitting on the rail, 12/450 #69696E to its right 可移至第 2 天 · 余量 3.5 小时.
Bottom bar: outline 撤销 (transparent, 1px rgba(196, 196, 202, 0.40), #17171A label) + solid #0066CC 保存修改 (#FFFFFF label), both pill 999, 44px, 16px page padding, scroll reserve 94px + nav inset.
```

### 遗留色坏 5 屏（第一轮判坏、此后从未重画，包里仍是坏帧）

这 5 屏的缺陷都是同一个编码陷阱的残留：ArkTS 的 `#AARRGGBB` 被 CSS 按 `#RRGGBBAA` 读。已确认**真实进入渲染**的位置：

| 屏 | 页面 | 坏声明 | 实渲 |
| --- | --- | --- | --- |
| `_12` | 偏好追问状态机 | `_12/code.html:243` `background-color: var(--primary-tint)` ← `1A 00 66 CC` | 靛紫实心选中卡 `rgb(26,0,102)`，文字压成灰字；且这屏是两台手机并排的桌面排布 |
| `_6` | 行程生成中 | `background-color: var(--primary-tint)` / `border: 1px solid var(--glass-bar-border)` ← `66 C4 C4 CA` | 靛紫进度底 + 青色描边 |
| `_16` | 生成失败诚实态 | `border border-[66 C4 C4 CA]` | 输入框青色边框（应为 `rgba(196, 196, 202, 0.40)` 灰） |
| `_1` | 时间线主视图 | `bg-[99 EF EF F2]` 选中段 | 青色药丸（应为 `rgba(239, 239, 242, 0.60)`） |
| `day_1_1` | 时间线主视图 | 同上 `bg-[99 EF EF F2]` | 同上 |

对这 5 屏统一发这一条（逐屏替换页面名，其余照抄）：

```
Redraw ONE phone screen (360vp, portrait, light mode) — 有径's <PAGE>. Keep the previous content and layout; this is a color-format repair, not a redesign.
DEFECTS TO FIX: this frame used ArkTS alpha-first hex inside CSS. Replace every 8-digit hex with rgba(): the blue tint is rgba(0, 102, 204, 0.10), the segmented selected pill is rgba(239, 239, 242, 0.60) with shadow 0 0 8px rgba(0, 102, 204, 0.18), the glass border is rgba(196, 196, 202, 0.40), the separator rule is rgba(60, 60, 67, 0.20), the glass bar fill is rgba(255, 255, 255, 0.44). No 8-digit hex may appear anywhere in the output.
Emit no tailwind.config, no :root custom-property palette, no Material 3 token names. Colors are literal at point of use.
Track behind the selected pill: #3C3C43 at 10% → rgba(60, 60, 67, 0.10). Selected label #17171A, unselected label #69696E, segmented control 36px tall, radius 999.
One phone per frame, 360vp wide, no browser chrome, no side-by-side frames, no frame labels like "Frame 1".
Fonts: HarmonyOS Sans for all operable text, Noto Serif SC 700 only for place/day titles. Sizes only 10/11/12/14/16/18/21/32. Radii only 6/20/999. Page padding 16, touch targets ≥44, 4px baseline grid.
Ink scale is closed: #17171A / #5A5A60 / #69696E / #9E9EA3 / #3C3C43. Action blue #0066CC, pressed #0055BB. Warm/semantic: #9A6206 / #A06400 / #1C7440 / #C0392B. Nothing truncates; letter-spacing 0; all numerals tabular.
```

---

## 八、第五轮返修提示词（真缺陷 5 条：版式 4 + 活体 ARGB 1）

第四轮 6 屏的颜色/字号/字体/blob 全部通过，`grep -l 'tailwind.config=' */code.html` 为 0。本轮**不再动色**，只修 5 条：1 条全局画板缺陷、3 条单屏版式缺陷、1 条图标语义、1 处活体 ARGB 污染。

**撤回两条误判（2026-10-13 复核契约后）**。本稿早先版本还列了「`1r2` 的 12:45 节点不该是琥珀色」和「`10px`/`14px` 是离梯圆角」两条，都不成立：

- 契约 §3 的活动类型分配是**封闭且明文**的（DESIGN.md:772-776）：景点 `{colors.primary}` 蓝 / 餐饮 `{colors.bookmark}` `#9A6206` / 住宿 `{colors.accent-mention}` `#5856D6` / 交通 `{colors.icon}` `#3C3C43` / 休整 `{colors.faint}` 灰。`.spine-dot-food` 用 `#9A6206` 是**照章办事**。
- 契约 `rounded` 是八档（DESIGN.md:197-205）：`0 / 6 / 10 / 14 / 20 / 28 / 30 / 999`。`10px` = `rounded.sm`（chips/inputs）、`14px` = `rounded.md`（reason blocks），都在梯上。

根因是我自己在 DESIGN.md §0.1 写了「暖色与状态色只有四个」「radii only 6/20/999」这类**比契约更严**的收紧条款，与 §1/§3 打架，Stitch 两头只能顾一头。§0.1 已改写为「一个色相只有在**本文件所有表里都不出现**时才算缺陷，判之前先查 §1、§3 与透明度台账」，并补了几何封闭条款。第七章 v3 增补的 GEOMETRY 行也已同步。

### 证据表（全部为第四轮新帧，行号可查）

| # | 屏 | 现象 | 证据 |
|---|---|---|---|
| 1 | 全部 6 屏 | 底部操作条被画板下沿裁切：`25r2` 的「加入日历提醒」按钮下半截出框、`6r2` 的「取消」、`12r2` 的「下一步」贴死框底 | `.phone-artboard { min-height:780px; overflow:hidden }` 25r2/code.html:34-42；`.bottom-bar { position:fixed; bottom:24px }` 25r2/code.html:361-369；`.floating-dock { position:fixed; bottom:28px }` 1r2/code.html:295-303；6 屏 `env(safe-area-inset-bottom)` 命中数 **0** |
| 2 | `25r2` | 三段时间标签互相压字，读成「一条本站 07:40 伏见稻荷下一站」 | `.route-labels-row { display:flex; justify-content:space-between; font-size:12px }` 无 `gap`，三条标签各约 116px、可用宽 312px |
| 3 | `day_1_3r2` | 站名被断成「二年坂 ·／三年坂」两行，`必去` 徽标孤悬第一行；meta 行也折行；拖动态把手与静止态不同轴；`插入点` 胶囊落在内容列里、离开了时间轴轨道 | 拖动卡 title 无 `nowrap`；`.drag-handle` 仅在拖动态居中；插入点行左偏移未对齐节点圆点 |
| 4 | `1r2` | Dock 三个图标语义全错：`行程` 是终端提示符 `>_`、`地图` 是时钟、`我的` 是圆内向上箭头 | 1r2/code.html:475（`polyline 4 17 10 11 4 5` + `line 12 19 20 19`）、:481（`circle r10` + `12,8→12,12` + 点）、:487（`circle` + `M16 12l-4-4-4 4M12 16V9`） |
| 5 | 当前编号 `_4`（原 `_3`）| 唯一还在渲染的 8 位 hex：`divide-[` + 33 3C 3C 43 + `]/20`，CSS 读成 rgb(51,60,67) 再套 20% → 分隔线偏黑 | 该缺陷原记在 `_3/code.html:140`，第五轮导出后漂到 `_4`（目录名不可信，认内容）。其余 31 个文件的 8 位 hex 全是死声明（`var()` 引用数 0），不渲染 |

### 全局补丁（一次贴给 Stitch，作用于全部屏）

```
Fix the phone frame geometry. Applies to every screen in this set; change nothing else — colors, type scale and fonts are already correct and must stay byte-identical.

1. The artboard is currently min-height:780px with overflow:hidden, and the bottom action bar / floating dock is position:fixed at bottom:24px or 28px. Result: the bar's lower half is clipped by the frame edge on the node detail, progress and preference screens.
2. Make the artboard exactly 360x780px, overflow:hidden kept.
3. The scrollable content column must end with padding-bottom equal to 94px plus the home-indicator inset, expressed as calc(94px + env(safe-area-inset-bottom)).
4. The bottom bar and the floating dock must sit above the home indicator, not under it: bottom = calc(16px + env(safe-area-inset-bottom)) for the bar, calc(28px + env(safe-area-inset-bottom)) for the dock. Give the bar height 64px plus the same inset as its own padding-bottom.
5. Every button inside the bar keeps 44px minimum touch height and must be fully inside the 780px frame with its own bottom edge at least 16px above the frame's bottom edge.
6. Verify by measurement, not by eye: on each of the node detail, itinerary progress, preference, input, conflict and edit screens, report the y-coordinate of the lowest button's bottom edge and confirm it is <= 764.
```

### 25r3. 节点详情 · 时间轴标签防碰撞

```
Screen: node detail (Fushimi Inari). Only fix the three-label row under the timeline slider; every color, size and font stays byte-identical.

Current: .route-labels-row is display:flex with justify-content:space-between, font-size 12px, no gap. The three labels are ~116px each against 312px of usable width, so they collide and read as "一条本站 07:40 伏见稻荷下一站".

Required:
1. Three equal columns: flex:1 each, gap 8px, remove justify-content:space-between.
2. Column 1 left-aligned, column 2 centered, column 3 right-aligned.
3. Each column is two lines: line 1 = the station name at 11px #9E9EA3, line 2 = the time at 12px #17171A tabular numerals. The middle column's line 1 is the current station and uses #0066CC.
4. Station names get white-space:nowrap, overflow:hidden, text-overflow:ellipsis at max-width 96px. Never let a name run into its neighbour.
5. Row height 32px, 4px baseline aligned.
```

### day_1_3r3. 行程编辑态 · 断行与轨道对齐

```
Screen: itinerary edit / drag state. Only fix layout; colors, sizes and fonts are approved and must stay byte-identical.

1. Stop name must never break mid-name. Currently "二年坂 · 三年坂" wraps to two lines and the 必去 badge is stranded on line 1. Title: white-space:nowrap, overflow:hidden, text-overflow:ellipsis, and the badge sits outside the text block in its own fixed-width slot, never inline in the wrapping flow.
2. Meta line ("建议停留 2小时 · 稻荷山麓") is one line only: nowrap + ellipsis. All cards in the list therefore have identical height; today the wrap makes two cards taller and knocks the timeline dots out of the 4px rhythm.
3. Drag handle: one fixed 24px column at the card's left edge, vertically centered, identical position in resting, ghost and dragging states. Today the dragging card's handle sits at a different x than the resting cards'.
4. Insert-point pill must live on the timeline rail, not in the content column. Its left edge aligns to the node-dot centerline (time column width + rail offset), and it replaces a node dot rather than floating between columns.
5. The dragging card keeps a 1px #0066CC outline and a 4% blue wash; the vacated slot stays a dashed 1px #E9E9EC placeholder with grey text. Keep both, only fix their geometry.
6. Nothing may truncate with a visible mid-word break; if a name cannot fit, ellipsize it.
```

### 1r3. 行程时间线主视图 · 图标语义

```
Screen: Day 1 itinerary timeline. Fix the three dock icons only; all other values stay byte-identical.

1. The floating dock's three icons are the wrong glyphs. Replace:
   - 行程 currently renders a terminal prompt (chevron plus underscore). Replace with a route glyph: a path with two nodes, or a signpost.
   - 地图 currently renders a clock (circle with hands). Replace with a location pin, or a folded map.
   - 我的 currently renders an up-arrow inside a circle. Replace with a person glyph: head circle plus shoulders.
   All three: 22x22 viewBox 24, stroke-width 2, stroke currentColor, fill none, geometric line style, no filled blobs.
2. Do not touch the node dot colors. The ochre dot at 12:45 is correct: the contract's closed activity-type allocation puts 餐饮 on {colors.bookmark} #9A6206.
```

### 已删除：离梯圆角

本小节早先要求把 `1r2 .transit-leg` `6r2 .shimmer-thumb` `16r2 .decision-chip` 的 10px 和 `16r2 .conflict-item` 的 14px 改成 6px。这是误判，**不要发这条提示词**：`rounded.sm` 就是 10px、`rounded.md` 就是 14px，四个值全在契约梯上。

### 持久化与系统触达 · 单点修色（整包唯一活体 ARGB 污染）

```
Screen: 有径 - 持久化与系统触达 (persistence and system reach), the frame whose row list uses a Tailwind divide utility carrying an 8-digit hex.

The divider class currently embeds the 8-digit literal 33 3C 3C 43 with a /20 opacity modifier. Browsers read 8-digit hex as RRGGBBAA, so this renders as rgb(51,60,67) at 20% — a near-black hairline, not the intended grey.

Replace that whole divide utility with an explicit rgba border on the children: border-bottom 0.5px solid rgba(60, 60, 67, 0.20), last child has no border. Emit no 8-digit hex anywhere in the frame.
```

### 第五轮自查（生成后本地跑）

```
cd /Users/itxiaobai/Downloads/stitch_youjing_travel_itinerary_planner && grep -c 'safe-area-inset-bottom' 1r2/code.html 6r2/code.html 12r2/code.html 16r2/code.html 25r2/code.html day_1_3r2/code.html
```

六行全部 ≥1 才算过。**第六轮实测这六帧全是 2 次命中——安全区补丁已经生效。**

> 判据本身有个坑，别踩：帧里写的是 `env(safe-area-inset-bottom, 0px)`，带兜底值，所以闭合括号永远不紧跟在变量名后面。用 `'env(safe-area-inset-bottom)'` 当模式会恒为 0，把已经修好的帧判成没修。模式只取 `'safe-area-inset-bottom'`。第六轮 48 帧按错模式是 0/48，按对模式是 7/48，且那 7 帧正好就是发过返修提示词的 7 帧。

```
cd /Users/itxiaobai/Downloads/stitch_youjing_travel_itinerary_planner && grep -n 'border-radius: *[0-9]*px' 1r2/code.html 6r2/code.html 16r2/code.html 25r2/code.html day_1_3r2/code.html | grep -vE 'radius: (0|6|10|14|20|28|30|999)px'
```

期望输出为空（八档圆角：0 / 6 / 10 / 14 / 20 / 28 / 30 / 999）。

```
cd /Users/itxiaobai/Downloads/stitch_youjing_travel_itinerary_planner && grep -l 'tailwind.config=' */code.html | wc -l && grep -lE '#[0-9A-Fa-f]{8}' */code.html | wc -l
```

期望 `0` 和 `31`（32 个里只有「持久化与系统触达」那 1 处是活体，修完就剩 31 个死声明，`var()` 引用数全为 0，可以留）。

---

## 九、云端清库（第六轮实测：只能手动，提示词无效）

> **本章第 1～3 关已被第十章作废。** 2026-10-14 实测 Stitch 根本没有文档管理器，「删旧契约副本 / 删派生设计系统 / 按 md5 删帧」这三个动作在 UI 里都不存在，唯一可行的清场是**新建干净项目 + 只上传一份**（第十章第 1 步）。本章留着是因为 9.0 的污染源定位（union 派生、frontmatter 才是载体）仍然成立，且它解释了为什么必须走新项目。

### 9.0 为什么改成手动 + 污染源已定位

第九版提示词块（原 9.2）在 2026-10-14 的第六轮导出里**一条都没生效**：帧数 48→48（零删除）、blob 帧仍 4、`env(safe-area-inset-bottom)` 仍 0，而设计系统从 3 份变成 4 份——Stitch 反而又派生了一份**同名** `youju-family-design-language`。结论：项目级文档与设计系统的增删不是生成代理能执行的动作，**这一段必须在 Stitch UI 里手点，不要再发提示词**。

活体 ARGB 之所以 32/48 帧复发，链路已经查到行号级：

| 环节 | 证据 |
|---|---|
| 旧契约副本 `design.md_5.md`（md5 `ac1755bb`）frontmatter 仍写 ArkTS 字面量 | `:21 primary-tint: "#1A0066CC"`、`:30 separator: "#333C3C43"`、`:32-42` 全部 glass-* 也是 8 位 hex（共 30 个） |
| 现行契约 `design.md_6.md`（md5 `96aef039`）同一行已改对 | `:21 primary-tint: "rgba(0, 102, 204, 0.1)"` |
| Stitch 把项目里**所有**设计文档取并集压缩 → `youju_family_design_language_1/DESIGN.md` | `:21 primary-tint: '#1A0066CC'` 与 `_5:21` 逐字符相同；同一份文档 `:32-36` 又并进了 M3 的 `surface-container-*` |
| 派生 token 下发到帧的 `:root` | 32 帧声明 `--primary-tint: #1A0066CC`；另有 `#333C3C43`×4、`#66C4C4CA`×3、`#99EFEFF2`×2、#70FFFFFF×1 |
| 真正**被渲染消费**的两帧（其余是死元数据） | `_10` 行程生成中：`background-color: var(--primary-tint)` + `--glass-bar-border: #66C4C4CA`；`_18` 偏好追问状态机：`background-color: var(--primary-tint)` |

`_19`/`_2`/`day_1_2`/`_6` 的 glass-* 都是正确的 `rgba()`，证明**新契约本身在被消费**——问题是 `_4`/`_5` 还在场上。所以修法是**删旧副本，不是停契约**。

### 9.1 手动操作清单（按顺序做，每步都有完成判据）

**第 1 关 · 删旧契约副本。** 项目 Documents/设计文档列表里，按下表把 5 份划掉，只留 `96aef039` 那份（标题《有据产品家族设计语言》）。认文档看字节数别看标题——五份的标题都可能一样。

| 删 | md5 前 8 位 | 字节 | 留 |
|---|---|---|---|
| ✂ | `604be72f`（有两份，都删） | 旧契约 | |
| ✂ | `42a4a517` | 68,257 B / 1157 行 | |
| ✂ | `30dedbba` | 内含 30 个 8 位 hex | |
| ✂ | `ac1755bb` | **内含 `primary-tint: "#1A0066CC"`，本次污染源** | |
| | | | ✅ `96aef039` · 70,730 B / 1165 行 · 8hex=0 |

完成判据：文档列表只剩 1 份契约 + 1 份 `app_store_assets.md`。

**第 2 关 · 解绑并删除 4 个设计系统。** 注意有两个**同名** `youju-family-design-language`，靠行数/字节区分，别只点名字：

| 删 | 识别特征 |
|---|---|
| ✂ | `Youju` · 7,284 B · 纯 M3 |
| ✂ | `Youju & Youjing` · 8,296 B · 纯 M3 |
| ✂ | `youju-family-design-language` · **3,684 B / 153 行**（这是被压缩坏的契约 hybrid，含 `#1A0066CC`） |
| ✂ | `youju-family-design-language` · **9,805 B / 235 行**（`surface: '#f9f9ff'`、`surface-dim: '#d8d9e2'`） |

**删完这 4 份之后，再把 `96aef039` 那一份契约重新挂成项目唯一的设计系统**（第十章第 1 步）。不要停在「无设计系统」状态：本轮 `_19`/`_2`/`day_1_2`/`_6` 的 glass-* 全是正确的 `rgba()`，证明新契约确实在被消费——坏的是并进了 `_5`。所以修法是**先清场、再单挂**。

**第 3 关 · 删帧：24 张。** 认帧看 `<title>` + `code.html` 的 md5 前 8 位，`_N` 目录名每轮重排、不可用作标识。保留帧的 md5 已在下表右列给出，直接对照本地导出包勾选云端帧。

| 屏标题 | 保留（md5） | 删除（md5 · 份数 · 坏在哪） |
|---|---|---|
| 首启与静默登录 | `e08d6e7f` | `cfe42609` ×12（逐字节全同）、`c7726650`、`094e9289` → 删 14 |
| 行程时间线主视图 | `32e3f0d8` (`1r2`) | `6bc8f8e8`、`7564f2d8` → 删 2 |
| 行程时间线编辑态 | `5051edbe` (`day_1_3r2`) | `0ab40e6c`（无标题 · blob）→ 删 1 |
| 行程生成中 | `b259b5a9` (`6r2`) | `b1c83262`（**活体 ARGB**：`var(--primary-tint)` + `#66C4C4CA`）→ 删 1 |
| 偏好追问状态机 | `d3bcee95` (`12r2`) | `337f5e6f`（**活体 ARGB**）、`b2a0f13e`（双帧对比排布）→ 删 2 |
| 生成失败的诚实态 | `ec7a8b7b` (`16r2`) | `5d7ba065` → 删 1 |
| 单个活动节点详情 | `a9ea7389` (`25r2`) | `a2ea61db`（无标题 · blob）→ 删 1 |
| 行程基础输入 | `62b4cbf0` (`_9`) | `64ffccd1`、`a843a951`、`4c9adc51`、`7adccca1` → 删 4 |
| 住宿区域选择 | `956fb4e9`（标题带「单帧规范版」） | `70dbd1be`、`c17a9828` → 删 2 |
| 景点选择 | `21eea6cf` | `aa906ddf`（标题是「景点选择与优先级标定」）→ 删 1 |
| 网页展示壳（顶栏 节点详情/行程编排/全局预览 + HarmonyOS NEXT 脚注，无 app 屏标题） | — | `12c92623`（blob · 42 处离契约消费）→ 删 1 |
| 分享结果页 `848bb2e9` / 我的行程与空状态 `c6239982` / 持久化与系统触达 `beed1827` / 旅行中模式 `2c6b3e31` / 费用视图 `36141ca0` / 桌面万能卡片 `4374fa94` | 各自唯一 | 不动。后两份各含 1 个 8 位 hex，走第八章「单点修色」，不走删除 |

营销物料 8 份（`youjing_html` `49a5134d` + 7 个 `role_senior_*`）**不在本关范围内**，不要删。

**第 4 关 · 逐屏返修（第八、十章的提示词照常发）。** 这一关是提示词唯一还有用的地方：给已保留的帧改属性可以，删项目资产不行。

### 9.2 第七轮导出后必查的一条：派生物有没有复发

挂载契约后 Stitch 一定会再生成一份压缩版设计系统——这不可避免，要查的是它有没有把坏值重新造出来：

```
cd /Users/itxiaobai/Downloads/stitch_youjing_travel_itinerary_planner && for d in $(ls -1d */ | grep -vE '^_|untitled|day_1|1r2|6r2|12r2|16r2|25r2|formability|role_|youjing_html'); do printf "%-44s 8hex:%s M3token:%s\n" "$d" "$(grep -cE '#[0-9A-Fa-f]{8}\b' $d/DESIGN.md)" "$(grep -cE 'surface-container|on-surface|outline-variant|surface-variant' $d/DESIGN.md)"; done
```

两份都必须是 0。只要派生物里再出现 8 位 hex 或 M3 token，说明「单挂一份」这条路也被证伪，启用回退路线：把 `DESIGN.md` 从项目里彻底移出，云端不留任何设计文档，契约 100% 只活常驻框和提示词。代价：Stitch 拿不到 §1/§3 的完整 token 表和对照表，需要靠第十章常驻框独自扛色板——所以只在实测复发时才走。

### 9.3 每关做完立刻本地校验

```
cd /Users/itxiaobai/Downloads/stitch_youjing_travel_itinerary_planner && echo "docs:" && for f in *.md; do printf "%s %s 8hex:%s\n" "$(md5 -q $f|cut -c1-8)" "$f" "$(grep -cE '#[0-9A-Fa-f]{8}\b' $f)"; done && echo "systems:" && ls -1d */ | grep -vE '^_|untitled|day_1|1r2|6r2|12r2|16r2|25r2|formability|role_|youjing_html' && echo "frames:" && ls -1 */code.html | wc -l && grep -l 'tailwind.config=' */code.html | wc -l && grep -lE '#[0-9A-Fa-f]{8}\b' */code.html | wc -l && grep -l 'safe-area-inset-bottom' */code.html | wc -l
```

第七轮期望值：`.md` 只有 `96aef039`（8hex:0）和 `b25cf612`；派生设计系统按 9.2 查，8hex 与 M3 token 均为 **0**；含 `code.html` 的帧目录 **24**（16 app 屏 + 8 营销）；blob **0**；8 位 hex 帧 **≤2**（`我的行程与空状态`、`持久化与系统触达` 允许，走单点修色）；`safe-area-inset-bottom` **≥16**（这一项从 0 抬起是第八章全局补丁是否生效的唯一判据；模式别写成 `env(safe-area-inset-bottom)`，见第五章末的坑注）。

---

## 十、标准作业流程 · 新项目版（2026-10-14 起，取代旧 SOP 与第九章第 1～3 关）

### 第 1 步：新建空白项目，只传一份文件

1. Stitch 首页 → **Blank project**（不要 Start with your design，那条路会先长出一套自建设计系统）。
2. 项目建好第一件事：左上项目名 → 铅笔 → 改名 **`有径 Youjing · 契约 v7`**，改名后按 Escape 或点画布空白提交（按 Return 会掉进页内查找条）。
3. 输入框左侧 `+` → **Upload Files** → 选 `~/Documents/StitchDesign/DESIGN.md`。macOS 那个沙盒文件面板**不吃合成点击也不吃合成按键**（`super+shift+g` 无反应），Computer Use 到这一步只能停，最后四下由人手点。
4. 本地核对传的是这一份：

```
md5 -q /Users/itxiaobai/Documents/StitchDesign/DESIGN.md && wc -lc /Users/itxiaobai/Documents/StitchDesign/DESIGN.md
```

指纹 = **`96aef039be0097437f1db5aa3abc9d42` / 70,730 字节 / 1,165 行 / 8 位 hex 0 处**（这是**已上传到 Stitch 的那一份**，后来只在本地改过一处：空状态图标从 faint 改成 muted，本地现为 `fd1daa6641641ecd0e6712eca8a50150` / 70,962 字节 / 同为 1,165 行。Stitch 端仍是旧指纹，所以行 1098 的 faint 口径还会随附件流进来——前置块第 2 档图标条款是它的对冲，别指望附件自己变对）。

**第 1 步完成判据（两条，缺一不发提示词）**：项目里设计文档只有这一份；派生设计系统 **0 个**（新项目初始就是 0，传完再看一眼有没有长出来）。这两条在老项目里是清不掉的，所以只能新建。

### 第 2 步：前置块——**粘在每一条提示词最前面**，没有常驻框

2026-10-14 实测：Stitch **没有 `Additional instructions` 常驻框**，也没有任何项目级指令入口（汉堡菜单只有 Share / Download Project / Duplicate / Edit / Settings / Delete / ⌘K / Send Feedback，Settings 是账号级）。所以这段文本必须**逐条拼在每条提示词开头**，漏发一条那一屏就失守。

```
Hard constraints for every frame in this project. The attached DESIGN.md is a hard contract, not inspiration.

PALETTE SOURCE
- Emit every color literally at the point of use: a 6-digit contract hex, or rgba(). No tailwind.config block, no :root custom-property palette, no Material 3 token names (surface-container, surface-variant, on-surface, on-surface-variant, outline, outline-variant, primary-container, tertiary-container, inverse-primary, anything ending in -fixed). A frame that carries an injected palette is a failed frame.
- COLOR FORMAT: CSS only. NEVER write an 8-digit hex. ArkTS #AARRGGBB (alpha FIRST) is not CSS #RRGGBBAA (alpha LAST) — the 8-digit literal 1A 00 66 CC read as CSS is a solid indigo block, not a 10% blue tint. All translucency is rgba(); the DESIGN.md translucency ledger has both spellings.
- CLOSED GREY SCALE. Surfaces: #FFFFFF #F7F7F8 #F2F2F4 #EFEFF2 #E9E9EC #E5E5EA. Auxiliary named surfaces: #E8E8EC skeleton base, #F1F2F5 canvas-gradient foot. Text/icons: #17171A #5A5A60 #69696E #9E9EA3 #3C3C43.
- SEMANTICS ARE FIVE, NOT FOUR. Action blue #0066CC (press #0055BB, dark #0A84FF). Status: #9A6206 必去/招牌 · #A06400 需预约/警告 · #1C7440 已确认 · #C0392B 冲突/危险. Lodging indigo #5856D6 (dark #7D7AFF) is contract, not contamination.
- ACTIVITY-TYPE DOT COLORS ARE PRESCRIBED, do not "fix" them: 景点 #0066CC · 餐饮 #9A6206 · 住宿 #5856D6 · 交通 #3C3C43 · 休整 #9E9EA3. A sixth type is expressed by an icon or a word, never a new hue.
- BADGE / CHIP FILL LAW: either a solid semantic fill (#9A6206 / #A06400 / #1C7440 / #C0392B / #0066CC) with a #FFFFFF label, or a neutral #F2F2F4 / #EFEFF2 fill with a #5A5A60 / #17171A label, or a 10% blue wash rgba(0, 102, 204, 0.10) with a #17171A label and a 1px #0066CC border. Pastel cream/mint tints are not in this system.
- Before calling any color a defect, check §1, §3 and the translucency ledger of DESIGN.md. A hue that appears in none of them is a defect; a hue you simply did not expect is not.

TYPE
- Fonts: only "Noto Serif SC" (400 and 700 exist — no serif 500/600; place names, day labels, question titles, section titles) and "HarmonyOS Sans" (everything operable, every stop name, every numeral). No Plus Jakarta Sans, no Inter, no Roboto, no system-ui.
- Scale: 32/700/44 serif display · 21/700/32 serif title · 21/650/28 sans · 18/600/24 headline (all stop names, SANS) · 16/400/24 body · 14/400/20 · 12/450/16 caption · 12/600 itinerary-time · 11/600 overline · 10/400 dock label. Allowed sizes ONLY: 10 11 12 14 16 18 21 32 — 13/15/17/19/20 do not exist here. **Icon sizes come from CONTROLS' two tiers (22×22 control, 48×48 display) and nowhere on this type scale** — the old "an icon may sit at 20px" allowance is retired, because a 20px glyph is a third tier nothing else uses. Serif never on a control, never on a stop name, **never on a numeral**. Letter-spacing 0. Every numeral tabular. **A display numeral (the money hero, a big count) takes the 32/700/44 display tier in SANS** — 32px exists on this scale only as serif, and serif is barred on numerals, so the numeral-display role is the one sanctioned non-serif use of 32px; it does not license serif on any other numeral.

GEOMETRY
- Radii are exactly the contract's eight rounded tokens: 0 / 6 / 10 / 14 / 20 / 28 / 30 / 999 — 6 media and nested-in-card, 10 chips and inputs, 14 reason blocks, 20 cards and sheets, 28 hero panels, 30 dock and segmented, 999 every button, badge and avatar. Buttons are ALWAYS pill.
- All spacing on a 4px baseline: 4 / 8 / 12 / 16 / 20 / 24 / 32 / 48. Page padding 16. Touch targets ≥44×44.
- Phone portrait, 360vp artboard, exactly 780vp tall, light mode. One phone per frame — no browser chrome, no desktop canvas, no side-by-side frames, no frame labels like "Frame 1".
- SAFE AREA IS MANDATORY: the artboard clips at 780vp, so a bottom bar must never touch that edge. Scroll content reserves calc(94px + env(safe-area-inset-bottom)); the bottom action bar sits at calc(16px + env(safe-area-inset-bottom)) and the floating dock at calc(28px + env(safe-area-inset-bottom)). Every button's bottom edge must be at least 16px above the frame's bottom edge.
- Chrome: title bar 60px; floating dock 300×64 centred, 30px radius.
- Timeline geometry: the time gutter is a 52px RIGHT-aligned tabular column, then a 2px spine with nodes centred on it, then the row. Stop rows ≥76px. Transit legs 44px showing BOTH time and distance ("步行 18分钟 · 1.2km").
- Text never breaks mid-name. Any single-line string gets white-space:nowrap + overflow:hidden + text-overflow:ellipsis and a max-width; a row of sibling labels gets equal flex columns with an explicit gap, never justify-content:space-between alone.

CONTROLS
- Exactly one solid #0066CC primary CTA per screen, 44px tall; everything else transparent with a 1px rgba(196, 196, 202, 0.40) outline. Never a second blue button on the same screen. Press = scale 0.97, 140ms.
- Glass/blur on exactly **four** surfaces, always at `blur(24px)` (`layout.glass-blur`) — top bar rgba(255, 255, 255, 0.44), **segmented control**, floating dock, sticky day header. DESIGN.md states this in its own words: "blur, and only in four places". **A sheet is NOT glass**: DESIGN.md `sheet-modal` (line 367) and the Sheet component note (line 1092) define it as opaque #F7F7F8 (`surface-elevated`) + radius 20 + `elevation.floating` + `modal-scrim` rgba(23, 23, 26, 0.32) behind it — no blur, no translucency, and never a second scrim value. Cards, timeline rows, option chips, reason blocks, widgets and the **bottom action bar** are flat opaque: the footer CTA strip is solid #FFFFFF (or #F7F7F8 when it must read off the canvas), never a translucent white and never blur — an alpha like 0.92 belongs to press opacity, not to a surface. Separation comes from the surface ladder and whitespace, never decorative borders; shadows exist only from the six-token closed set in self-check 6, never as an invented value. The only border a panel is required to carry is the reason block's 2px #0066CC left rule (DESIGN.md `reason-block.leftRule`) — that accent is contract, not a card outline, and never gets dropped to satisfy a no-borders reading.
- Dividers 0.5px rgba(60, 60, 67, 0.20), only between like rows. Cards separated by whitespace, not lines.
- Icons are geometric line glyphs, 22×22 viewBox 24, stroke-width 2, stroke currentColor, fill none, sitting inside a 44×44 hit box when they are tappable — **44 is the hit box, never the glyph**. There is exactly one other glyph size in the system: the **48×48 display glyph** a full-page empty state or failure state centres on the canvas (DESIGN.md §Empty state, `spacing.xxl`), same viewBox 24 and stroke-width 2, drawn in `muted` `#69696E`. No intermediate size exists: 16/20/24/32px glyphs are inventions and so is scaling the stroke with the box. And no glyph is ever `faint` `#9E9EA3` — that token measures 2.67:1 on #FFFFFF, fails the 3:1 graphic floor, and is restricted to disabled and placeholder text. Each icon must be semantically correct for its label — an itinerary icon is a route or signpost, not a terminal prompt; a map icon is a pin or folded map, not a clock.

CONTRAST AND MOTION
- Labels ≥4.5:1; icons, dots, route strokes ≥3:1. Never blue text on a blue wash. Never white text on a dark-mode bright fill. Never weaken an actionable icon with opacity.
- Motion described, not shown: press 140 / control 220 / container 320 / page 420 / route draw 460 / stagger 40 / shimmer 1200.

CONTENT
- Realistic Chinese content: a 5-day 京都 trip with actual temple, shrine and café names, plausible walk times and yen prices. No lorem ipsum.
- Every AI output screen answers three questions in visible data: why this stop, how long, does it need booking.

PRE-EMIT SELF-CHECK — these eight are this model's measured failure modes on this project, from the v7 first-run frame plus screens 2 and 4. Emit, then re-read your own CSS and correct any that is false; do not reply that it is already correct unless you checked the rule:
1. A stop name is `font-size: 18px` / 600 sans. 16px is the body role, not the stop role.
2. `.timeline-row` (or whatever you call a stop row) is `min-height: 76px`. 52px is the transit-leg-adjacent gutter height, not the row height.
3. A transit leg is 44px tall, dashed, **no background fill**. A solid #F2F2F4 pill is wrong.
4. A spine node is a 24px circle with a 10px inner dot. 20px/8px and a 1.5px ring are wrong.
5. A serif string is either 32/700 or 21/700. 18px serif 700 does not exist in the scale.
6. Every `box-shadow` in the frame is one of the six allowed declarations and is on the component that owns it. The closed set: `0px 0px 1px 0px rgba(0, 0, 0, 0.03)` (contact), `0px 3px 10px 0px rgba(0, 0, 0, 0.07)` (card — itinerary and summary cards only), `0px 6px 16px 0px rgba(0, 0, 0, 0.09)` (floating — the dock, a half-modal sheet, and a row caught mid-drag), `0px 0px 8px 0px rgba(0, 0, 0, 0.06)` (segmented), `0px 0px 8px 0px rgba(0, 0, 0, 0.07)` (popover/menu), and the single permitted coloured one: the selected pill of the 36px segmented control at `0px 0px 8px 0px rgba(0, 102, 204, 0.18)` (DESIGN.md `glass-selection-shadow`). A seventh shadow value, or any shadow on a button, badge, chip, reason block, widget or the route canvas, is the break — a blue drop under a CTA is this model's most common invention. A screen that uses none of these is correct too: do not add a shadow to fill this check.
7. A reason block — the #EFEFF2 panel at radius 14 that carries an 11/600 overline plus the AI's reasoning — **must** draw `border-left: 2px solid #0066CC`. A fill-only panel with no left rule is the break: this model drops the rule whenever it over-reads the no-borders clause, and DESIGN.md's `reason-block.leftRule` asks for it on every screen that explains a recommendation.
8. The bottom action bar is a solid opaque strip with **no** translucency and **no** blur. Measured twice on this project: an alpha meant for press-opacity migrating into a surface, plus a backdrop-filter copied off the top bar.
```

### 第 3 步：发送顺序——一次一条，一条一屏，每条都自带前置块

| 序 | 发什么 | 出处 | 发完立刻验 |
|---|---|---|---|
| 1 | 前置块（含 PRE-EMIT SELF-CHECK 八条）+ 主提示词（末尾点名「Screen to generate now — 1. 首启与静默登录」） | 第 2 步 + 第一章 | 按第 4 步**认帧**后导出，跑四条闸门 + 八条逐条对 |
| 2 | 仅当第 1 步那块仍有偏差时才发：前置块 + 偏差清单（打包发，不必逐条） | 第十一章 | 重新**认帧**导出，逐条对；台账里没有的新 md5 才算新帧 |
| 3…21 | 前置块 + 第 2～16 屏分屏提示词，按流程顺序；**3b / 11b / 12b 三个变体屏各发一条** | 第三章 | 每屏发完认帧 → 导出 → 跑第 4 步 |

**一条提示词只许一块帧。** 前置块 GEOMETRY 写着 no side-by-side frames，正文里任何「再画一块变体」的写法都会和它当面对撞，Stitch 会照正文办、留给你两块同名帧，认帧和导出全乱。v7 已把屏 3 / 11 / 12 的三段变体拆成 **3b（节奏偏好多选）/ 11b（费用超支态）/ 12b（我的行程空状态）** 独立发送，正文里只留 `ONE frame` 字样。

第 2 行是**条件步**。v7 实测：前置块带上 PRE-EMIT SELF-CHECK 之后，整屏重生成一次就把七条全挡住（`77ed8d08…`），不需要逐条返修；而七条打包返修同样一次生效（`ffaca4fd…`）。所以别一上来就排返修轮，也别把返修拆成一条一句——两种打包粒度都能落地，真正的分界是**首次生成有没有带上自检块**。

**拼接用这条命令**（前置块 9,107 字 + 分屏正文，直接从本文件取，别手抄；前置块今天四次变长：6,579 → 6,797 给底部动作条补扁平条款，6,797 → 7,565 是 11.7 翻案后理由件左条转正、自查从七条变八条，7,565 → 8,489 是 11.10 的第 6 条翻案——「box-shadow 一处都不许出现」是我写的第三条比正文更严的收紧条款，DESIGN.md `elevation` 段（269–273 行）明明有 contact/card/floating/segmented/popover 五档，`glass-selection-shadow` 还是一条合法的蓝色阴影，而屏 8/9/14/15 的正文点名要 card 与 floating 投影；再照旧发出去就是让 Stitch 在两条自相矛盾的指令里挑一条。**8,489 → 9,107 是 11.11 之后这一轮**：第 6 条把六条声明逐条写全、CONTROLS 的图标条补成两档口径、再把那句引用错的「five-token」改成 six-token——**同一份文档里的计数引用要跟着被引用的那条一起改**）：

```
node -e '
const fs=require("node:fs");
const src=fs.readFileSync("/Users/itxiaobai/Documents/StitchDesign/youjing-stitch-prompts.md","utf8");
function fenceAfter(h){const i=src.indexOf(h);const a=src.indexOf("```",i);const b=src.indexOf("```",a+3);
  return src.slice(a+3,b).replace(/^\n/,"").replace(/\s+$/,"");}
const pre=fenceAfter("### 第 2 步"), body=fenceAfter(process.argv[1]||"## 一、主提示词");
fs.writeFileSync("/tmp/stitch_prompt.txt", pre+"\n\n"+body+"\n");
console.log(pre.length+" + "+body.length+" = "+(pre.length+body.length+2)+" 字，8hex:"+(body.match(/#[0-9A-Fa-f]{8}\b/g)||[]).length);
' '### 2. 基础输入 · 一次成型'
```

输出末尾的 `8hex:` 必须是 **0**；不为 0 说明这条提示词里带了可复制的坏值，先回去改本文件再发。拼好的正文在 `/tmp/stitch_prompt.txt`，`pbcopy < /tmp/stitch_prompt.txt` 直接进剪贴板再粘进输入框。

**发送本身也要复核（2026-10-14 屏 10 加）**：Return 之后当次返回的状态**不能当成交付证明**——屏 10 第一次 Return 后 composer 复位了、树里 `Screen 10` 字样命中 3 次，全是 **composer 自己还没清掉的文本节点**，实际一个字都没发出去，我白等了 5 分钟。等 **≥30 秒**再查两条：① `Screen N` 的字样**还在不在**（不在＝没发出去，直接重发同一条，安全：Stitch 每轮新建帧，不会污染旧帧）；② 聊天**最后一条 user 气泡**是不是它——**先按 Escape 取消选中帧**，否则左栏会钉在选中帧那条旧消息上，看着像"没有新消息"。

**每屏发完必须等画布上真的出现新帧再发下一条**；发下一条前先确认输入框里上一条的上下文 chip 已经清空，否则 Stitch 会把旧帧当参考物抄进新帧。清 chip 的办法是点它右侧的「Remove」按钮（无障碍树里就叫 `按钮 Remove`），别用退格——**这个按钮实测经常点一次不生效，清完要复查一次 `chipLeft: []` 再粘下一条**。

**「新帧出现」只有一条硬判据（2026-10-14 屏 9 用一条假成功换来的）**：数无障碍树里 **`HTML 内容 有径 - <标题>` 的条数**，或者等一个**从没出现过的标题**冒出来。屏 9 第一次发送：聊天回复流完了（末句停在「tabular-nums。」）、composer 复位了、`Screen 9` 字样在树里能搜到——**画布上一块新帧都没有**，那 11,478 字全空转。树里挂着 `Generating Screen...` 标签的帧是**上一轮没改名的死帧**（屏 9 那两次导出证明：一块 `<title>` 是「有径 - 景点选择」= 屏 4 纠偏轮的 fork，一块装屏 8 内容），别把它当成本轮成果。**配套两条**：① 判定死帧的办法是**导出看 `<title>` + md5**，不是看尺寸牌——`1280 x 800` 与 `1280 x 780` 都只是画布牌，新帧也可能是 1280 宽；② **画布上还挂着 `Generating Screen...` 就不许按「重新加载」**，帧的 srcdoc 是异步补的，刷新有掐断回写的嫌疑（屏 9 那次因果未证实，但禁令先立）。

**发之前先做一次「正文 vs 前置块」对撞**（v7 屏 2 的教训）：前置块已经把这些定成闭集——字阶 10/11/12/14/16/18/21/32、圆角 0/6/10/14/20/28/30/999、触控 ≥44×44、宋体不上控件、chip 圆角 10、一屏一个实心主按钮。分屏正文里只要出现与这些相抵触的数值，Stitch 会**照正文执行**而不是照前置块，于是产出"忠实于提示词的缺陷"。屏 2 实测两处都是我自己写进去的：`serif value because it names a place`（目的地值用了宋体）和 `three 32px pill quick-picks`（32×32 触控不足 + 圆角 999）。导出件查下来零 Stitch 偏差，全在正文里。**所以判任何一条缺陷之前，先 grep 本文件的分屏正文**：

```
grep -n '关键词' /Users/itxiaobai/Documents/StitchDesign/youjing-stitch-prompts.md
```

命中在正文里 = 是我要求的，改正文再重发；没命中才轮到 Stitch 背锅。

**同一趟预检还要算两件（2026-10-14 屏 7 起，都是我自己写进正文的硬缺陷）**：

1. **每一个「前景色 × 背景色」配对比 WCAG 再发**：文字 ≥4.5、图标与描边 ≥3.0。屏 7 原稿两处不合格——状态图标 `#9E9EA3` 压 `#FFFFFF` **2.67:1**、理由件里的 chevron `#9E9EA3` 压 `#EFEFF2` **2.32:1**；两处都改 `#69696E`（5.46 / 4.76）。算式用 11.9 末尾那条 python3 一行命令，别靠肉眼。
2. **图标只有两档（2026-10-14 屏 7/8 之后从一档改成两档）**：控制图标 **22×22**、viewBox 24、stroke-width 2，套在 44×44 热区里；展示图标（空状态、失败态）**48×48**，同一张 viewBox 24 的线图标、**描边不随盒子放大**，颜色 `muted` `#69696E`。屏 7 原稿写 `a 48px 12px … line icon`（既造了 48px 这一档、又把描边写成 12px），根因是 DESIGN.md 自己 1098 行「faint icon at 48px」和 855 行「faint 不许出现在图形上」互斥，Stitch 在两条互斥规则之间取了中点（见 11.11）。**没有第三档**：正文里出现 14/16/20/24px 的象形件就是我在造档，先 grep 自己的正文。**唯一的豁免是机身 chrome**：状态栏模拟件（`09:41` 旁的 wifi / cloud / battery，14×14、16×12，stroke `#17171A`，类名 `.status-icon-svg`）不吃这两档口径。**分法看 stroke 色与所在容器，别只看尺寸**——屏 8 的 `.transit-icon` 14×14、屏 9 的 12×12 插入件是内容图标（算违规），屏 10 那三只离档 svg 全是状态栏（不算）。

**审计侧的对应规矩（第 4 步）**：所有声明级 grep **先剥 CSS/HTML 注释**，`box-shadow` 还要排除 `box-shadow: none` 这种防御性重置。本项目已两次因裸 grep 命中注释而误判：屏 6 的注释「零 box-shadow」被报成违反第 6 条；屏 1 的注释 `strictly NO border-left` 被报成左条活着、实际规则体是 `border: none`（见 11.9）。现成工具：`bash ~/Downloads/stitch_v7_ledger/audit.sh <帧目录>/code.html`，一次出四闸门 / 补丁通道 / **阴影六条闭集（违规条数 + 逐条原文）** / 字号 / serif / 圆角 / 4px 基准越界 / 台账外 alpha（与 DESIGN.md 透明度台账做**数值归一化差集**，别用字符串白名单）/ 第 7 条 / 第 8 条（含**「底栏规则块抓到几段」**）/ 图标尺寸（**svg 属性与 `… svg {}` 规则两条都查**，状态栏 chrome 另判）/ 实心蓝归属（**只扫 `</style>` 之前的 CSS 区，并打印「CSS 区行数」自证**）。**判据本身也在改，规矩只有一条**：任何"目标串可能不存在"的 grep 都会恒空假绿，所以**每栏都要能打"我到底抓到了几段"**——屏 10 的 `.bottom-action-bar`、屏 11 的 CSS 定尺寸 svg 与内联实心蓝，三次都是 0 命中看起来像合规、其实是判据没跑（见 11.13、11.14）。阴影一栏按 DESIGN.md `elevation` 段的闭集判，注意数值归一化：`rgba(0,0,0,.07)` 与 `rgba(0, 0, 0, 0.07)` 是同一个阴影，字符串比对会漏。

### 第 4 步：导出 + 四条闸门（每屏一次）

**导出操作**（2026-10-14 新项目实测）：

1. **先确认在 Edit 模式，再找 Export**（2026-10-14 屏 12b 撞的）：生成结束后 Stitch **可能自己跳到 Preview 模式**，此时整条工具栏变成 `单选按钮 Preview / Edit` + Share + Account Menu，**`按钮 Export` 根本不在树里**——按上一屏记下的元素索引点下去，拿到的是别的控件。判据两条：`单选按钮 Edit, Value: 1` 必须在树里出现；`按钮 Export` 要**按名字现取索引，绝不复用旧索引**（元素索引在两次快照之间一定会漂移，屏 12 那次 50 还是 Export，屏 12b 同一位置已经不是）。
2. 画布上**只点选那一帧**。选区里只要混进 `DESIGN.md` 文档产物，Export 对话框整排格式就会 `(disabled)`、只剩 AI Studio 可选；清空选区、只选帧，`.zip` / Figma / MCP / Code to Clipboard 全部解锁。**`super+a` 全选会把 DESIGN.md 一起选进去，别用它。**
   - **返修/重生成之后必须重新认帧**：Stitch 每跑一轮都在画布上**新建一块帧**，旧帧原地不动，而画布无障碍树只展开当前选中那块的内容，其余帧连标题 label 都不露。新帧排在**最右**（Prototype 之前）；选中正确时顶部会浮出尺寸牌（`1280 x 780` = 旧帧，`390 x 780` = 新帧），composer 上方出现该屏的 context chip。
   - 认帧用**坐标点击**，不要用 `elementIndex`——`elementIndex` 只指向 AX 已展开的那块，会反复选中同一块旧帧。先截图量一次缩放系数（显示宽 800 → 点击空间 1312，系数 1.64），点帧标题而不是手机内容区。
   - 这一条救过我一次误判：连续三次导出拿到同一个 md5，我据此判定「Stitch 回复的『已完成 7 项纠偏』是撒谎、打包返修无效」；换到新帧才发现七条早就改干净了（详见 11.1 台账）。
3. Export → Format 选 `.zip` → 点底部出现的「Export」确认按钮。
4. 十几秒后页面会短暂白屏（导出流程会重载 SPA），重新加载即可，项目数据在服务端不丢。Chrome 工具栏「下载内容」变成「有新下载好的内容」= 完成。
5. 落盘 `~/Downloads/<项目名>.zip`，里面就是 `code.html` + `screen.png`（v7 首屏：13,234 B / 205,419 B）。

**闸门四条**：

```
cd ~/Downloads/stitch_youjing_v7 && for p in 'tailwind.config=' '#[0-9A-Fa-f]{8}\b' 'surface-container|surface-variant|on-surface|outline-variant|-fixed\b' 'safe-area-inset-bottom'; do printf "%-58s %s\n" "$p" "$(grep -cE "$p" code.html)"; done
```

前三条期望 **0**，第四条期望 **≥1**。第四条的模式**只能写到变量名**：帧里写的是 `env(safe-area-inset-bottom, 0px)`，带兜底值，闭合括号永远不紧跟变量名——把 `env(...)` 整个当模式会恒为 0，这条错判让我把早已生效的补丁判成 0/48（详见第五章末那条坑注）。

**色值台账（第五步，逐条回契约查）**：

```
cd ~/Downloads/stitch_youjing_v7 && grep -oE 'rgba?\([^)]*\)|#[0-9A-Fa-f]{3,8}\b' code.html | sort | uniq -c | sort -rn
```

命中值只有在本文件的**所有表里都不出现**时才算缺陷；没预料到不等于坏。v7 首屏基线是 14 个值、全部在梯内，最重的三个是 `#17171A ×15`、`#0066CC ×9`、`#FFFFFF ×6`。

**攒够多帧后统一追踪时，认帧只认内容，不认目录名**：

```
cd <导出目录> && for d in */; do [ -f "$d/code.html" ] || continue; printf "%s  %-28s %s\n" "$(md5 -q $d/code.html | cut -c1-8)" "$(grep -o '<title>[^<]*' $d/code.html | head -1 | sed 's/<title>//')" "$d"; done | sort
```

目录编号每轮重排（同一个 divide 缺陷从 `_3` 漂到 `_4`，青色选中段从 `_1` 漂到 `_2`），只有 md5 + title 能跨轮追踪。

**v7 首屏 md5 台账（2026-10-14，同一 title `首启与静默登录 - 有径` 下四块帧）**：

| md5 | code.html | 来源 | 判定 |
|---|---|---|---|
| `370a098fc24957b511e49e7b2637ec1e` | 13,234 B | 首次生成 | 七条度量偏差全在，**废弃** |
| `7a01af33bddc80f8f4824c3df00e63da` | 13,684 B | 单条短返修 | 内联 DOM 补丁，规则块未改，**废弃** |
| `ffaca4fdec1109931d96e38e452e1d96` | 14,568 B | 7 条打包返修 | 七条全绿、零内联补丁，画板仍 1280×780，**备选** |
| **`77ed8d082f958d12401d29634436cd09`** | 12,654 B | 带 PRE-EMIT SELF-CHECK 的前置块整屏重生成 | 七条全绿、画板 390×780、`.device-frame` 360×780，**第 1 屏以此为准** |

导出件的 md5 不在台账里 = 这是一块新帧，登记进去再判；和台账里某块相同 = 你选中的是那块旧帧，回去重做第 1 步的认帧。

## 十一、第七轮返修提示词（v7 首屏 7 条度量偏差）

闸门四条全过（blob 0 / 8hex 0 / M3 token 0 / 14 个色值全在梯内），**色彩这一仗已经打赢，本轮只修度量**。发法同第十章：前置块 + 下面这段。

```
Frame "首启与静默登录" passes every colour gate — no injected palette, no 8-digit hex, no off-ladder hue. Keep every colour literal exactly where it is. Fix only these seven measured geometry and type deviations, and nothing else:

1. .stop-name is 16px/600. Stop names are the 18/600/24 headline role, HarmonyOS Sans. Raise it.
2. .timeline-row has min-height 52px. Contract: a stop row is at least 76px tall.
3. .transit-leg is 36px tall and a solid #F2F2F4 pill. Contract: a transit leg is 44px, dashed, no fill. Keep the text exactly as it is — "步行 12分钟 · 750m" and "步行 18分钟 · 1.2km" already carry BOTH time and distance, that part passes.
4. .spine-node is 20px with a 1.5px ring and an 8px inner dot. Contract: 24px circle, white fill, #17171A ring, 10px inner dot tinted by activity type.
5. .preview-day-title is 18px serif at weight 700. 18/700 serif does not exist in the scale — a day label is either 21/700/32 serif or 18/600/24 sans. Pick one, do not invent a third.
6. .btn-primary carries box-shadow 0 2px 6px rgba(0, 102, 204, 0.2). The contract bans shadows as a separation device. Delete the shadow; that rgba value then disappears from the frame entirely.
7. .preview-foot has border-left 2px solid #0066CC. A reason block is flat opaque with no border. Drop the border and let the #EFEFF2 fill do the work.
   （**2026-10-14 追述：这条是误判，别再照发。**DESIGN.md 的 `reason-block` 组件表明文 `leftRule: 2px solid {colors.primary}`，2px 蓝左条是契约件。**但它确实生效了、而且是我唯一一次完全听从那条返修的地方**——屏 1 的 `.preview-foot` 现在写着 `border: none`，注释还留着 `strictly NO border-left`，理由件因此丢了左条；我最初把这条记成「屏 1 反而是对的」，是裸 grep 命中注释造成的误读，剥注释后已纠正（见 11.7 表格与 11.9）。屏 1 因此进清理轮。）

Do not change: the global letter-spacing 0, tabular numerals, the 360px × 780px .device-frame, the calc(16px + env(safe-area-inset-bottom, 12px)) bottom padding, the single solid #0066CC pill CTA at 44px with scale 0.97 / 140ms press, the 0.5px rgba(60, 60, 67, 0.20) divider, the 11px "TRACEABLE ROUTES" overline, or the 14 colour literals — all of them are contract.
```

发完验三条（逐条对，别只看整体）：

```
cd ~/Downloads/stitch_youjing_v7 && grep -oE 'min-height: *[0-9]+px|height: *(36|44|76|20|24)px|font-size: *(16|18|21)px|box-shadow[^;]*;|border-left[^;]*;' code.html | sort | uniq -c
```

期望：不再出现 `box-shadow`、不再出现 `border-left`、出现 `min-height: 76px`（或更大）、`height: 44px` 的 transit 腿、`height: 24px` 的 node、站名 `font-size: 18px`。

### 11.1 本轮实测：七条打包返修**生效了**，但我差点判它失败（2026-10-14）

这段发出去后 Stitch 回复「已严格按照《DESIGN.md》契约标准……完成了全部 7 项几何与字阶规范的纠偏与重构」。我随后三次导出对账，拿到的 `code.html` 都是 md5 `370a098f…` / 13,234 B —— 与返修前一字不差，于是写下过一条错误结论：「Stitch 撒谎、打包返修这条路不通」。

**那条结论是错的，错在我导错了帧。** 完整台账（同一屏、四个 md5）：

| md5 | 大小 | 来源 | 落地形态 |
|---|---|---|---|
| `370a098f…` | 13,234 B | 首次生成 | 七条偏差全在，画板 1280×780 |
| `7a01af33…` | 13,684 B | 105 字单条返修（只改 `.stop-name`） | **DOM 内联补丁**：三个 `<span class="stop-name">` 各挂 `style="font-size: 18px; line-height: 24px; font-weight: 600;"`，`.stop-name` 规则块仍写 16px |
| `ffaca4fd…` | 14,568 B | **上面这段 7 条打包返修** | 七条全改在样式表里，零内联补丁，画板仍 1280×780 |
| `77ed8d08…` | 12,654 B | 带 PRE-EMIT SELF-CHECK 的前置块整屏重生成 | 七条同样全绿，更小更干净，画板 390×780、`.device-frame` 360×780 |

`ffaca4fd` 的复查证据：`min-height: 76px`、`box-shadow: none !important`、无 `border-left`、无 `height: 36px`、`.transit-leg { height: 44px; background-color: transparent; border: 2px dashed rgba(60, 60, 67, 0.20); }`、`.spine-node` 24px/2px #17171A、`.node-dot` 10px、日标题 21px 宋体；四条闸门全 0 命中，色值台账 13 项全在契约内，字体只有 HarmonyOS Sans 与 Noto Serif SC。

**根因**：Stitch 的整屏重生成与多条打包返修**不是就地编辑——每一轮都会在画布上新建一块帧，旧帧原地不动**。而画布无障碍树只展开当前选中那块的内容，其余帧连 label 都不露，所以"我到底选了哪块"在 AX 树里看不出来。我前三次点的是最早那块。

### 11.2 由此定下的三条硬规矩

1. **导出前认帧**：新帧排在画布最右（Prototype 之前）。选中后顶部浮出尺寸牌、composer 上方出现该屏的 context chip——**chip 的标题才是身份，尺寸牌不是**。尺寸牌只说明 Stitch 这次建的是桌面画板还是手机画板：屏 1 的重生成块是 `390 x 780`（PNG 780×1560），屏 2 的首次生成块是 `1280 x 780`（PNG 2560×1560），屏 3 是 `1280 x 841`（PNG 2560×1682），而三块导出的 `code.html` 里 `.device-frame` 一律 `width: 360px; height: 780px`，**画板宽窄不是代码缺陷**，别拿它当新旧判据（我一度拿 `1280=旧 / 390=新` 当判据，删帧前先按标题核过一遍才没删错）。认帧用**坐标点击帧标题**比 `elementIndex` 可靠——`elementIndex` 只指向 AX 已展开的那块，容易反复选中同一块旧帧。
2. **对账只比 md5**，并且把 `md5 + <title> + 尺寸牌` 记进台账。zip 字节数会因截图重编码而变（205,419 → 208,077 而代码一字未动），回复文字更不作数。判"渲染有没有变"用行带高度探针，不人眼猜。桌面画板的 `screen.png` 是 2560 宽、手机居中，两侧是留白——量色差先按 360 宽裁切（`x0=W/2-360*W/1280/2`），别拿整图比。
3. **验收 grep 要连内联 style 一起扫**：`grep -o 'style="[^"]*"' code.html`。短提示词走的是 DOM 补丁通道，只看样式表会误判成没改。

纯噪声一条，别写进缺陷清单：导出管线会往 `<head>` 注入 `<link rel="stylesheet" href="…fonts.googleapis.com/css2?family=Noto+Serif+SC:wght@700…" data-snapdom="injected-import">`，那是截图器的产物，不是契约违规。

### 11.3 两条路都通，选哪条

打包返修（`ffaca4fd`）与整屏重生成（`77ed8d08`）都把七条修干净了，但重生成那块**更小、零内联补丁、画板是贴手机边框的 `390 x 780`（返修块仍是 1280 宽桌面画板）**，所以第 1 屏以 `77ed8d08` 为准。

对后面各屏的含义：前置块里的 PRE-EMIT SELF-CHECK 已经证明能挡住这七条，**首次生成就带上它**，比事后返修省一到两轮；真出现偏差时，七条以内打包发一次即可，不必逐条发。

### 11.4 屏 2 的两条自伤纠偏（2026-10-14，`e86474fd` 实测）

屏 2 四条闸门全过、色板 14 个全在梯内，但 `code.html` 里躺着两条**我自己旧正文要求的**缺陷，不是 Stitch 的自由发挥：`.field-value-serif` 把 `京都 · 日本` 写成 18px **serif 700**（一条规则撞两回——控件不许 serif，且 18/700 serif 根本不在字阶里），`.party-chip` 是 **32×32 的 button**（撞 ≥44×44 触底）。第三章正文已就地改口径，这段负责把画布上那块旧帧拉齐。发法同前：前置块 + 下面这段，选中屏 2 的帧再发。

```
Frame "有径 - 行程基础输入" passes every colour gate — no injected palette, no 8-digit hex, no off-ladder hue. Keep every colour literal, every radius, the 44px .nav-back-btn / .chevron-action and the calc(16px + env(safe-area-inset-bottom, 12px)) footer padding exactly where they are. Fix only these two items, and nothing else:

1. `.field-value-serif` renders 京都 · 日本 in 'Noto Serif SC' at 18px / weight 700. One rule, two contract breaks: a field value is a tappable control and serif never sits on a control; and 18/700 serif does not exist in the scale — serif is only ever 32/700 or 21/700. Delete the `.field-value-serif` rule and let that span carry the existing `.field-value` class (HarmonyOS Sans 18/600/24 #17171A). Do not reintroduce serif for any place name inside a field, chip, button or row label; serif stays only on the 21/700/32 page title and on day / question titles.
2. `.party-chip` is 32px × 32px, under the 44×44 touch floor for a button. Make the hit box 44px × 44px and keep the visible pill at 24px: the button gets width 44 / height 44 and transparent background, and an inner element (or ::before) draws the 24px circle at radius 999 — the #F2F2F4 fill, the rgba(0, 102, 204, 0.10) selected fill and the 1px #0066CC selected border all move onto that inner circle. Label stays 14/600 #17171A tabular, the 8px gap between chips and the row height stay as they are.

Do not change: the 360px × 780px .device-frame, the single solid #0066CC 44px pill .btn-primary with #0055BB + scale 0.97 press, the 64px .field-card at 20px radius on #F7F7F8, the 11/600 #69696E .field-label, the 12/450 #69696E tabular .field-meta, the 4px budget track on #E9E9EC with its 11px 经济 / 舒适 endpoints, letter-spacing 0, tabular numerals, or any colour literal.
```

发完验三条（短提示词走内联补丁通道，`style=` 也要扫）：

```
cd ~/Downloads/stitch_v7_ledger && d=$(ls -dt 屏2_*/ | head -1) && echo "$d" && grep -oE "font-family: *'Noto Serif SC'[^;]*|class=\"[^\"]*serif[^\"]*\"|width: *(24|32|44)px|height: *(24|32|44)px|style=\"[^\"]*\"" "$d/code.html" | sort | uniq -c
```

`ls -dt` 按修改时间取最新那块，别按名字排（md5 前缀排序会挑错目录）。

期望：`Noto Serif SC` 只剩页标题一处、`field-value-serif` 这个类名消失、`.party-chip` 外框 44px 且内圈 24px、无新增色值。

**实测结果（同日，`5c69ef4c…`，就地修正、未 fork 新帧）**：两条闸门级修复都生效了——`京都 · 日本` 改挂 `class="field-value"`（HarmonyOS Sans 18/600/24），三个 quick-pick 变成 `<button class="party-chip" style="width:44px;height:44px…">` 套 24px 内圈 `<span style="…">`，选中圈 `rgba(0, 102, 204, 0.10) + 1px #0066CC`，`:active scale 0.97` 保留。四条闸门仍全过，色值 11 个全在梯内，无回归。

**短提示词确实走内联通道，留下三处交接地雷**（渲染正确，但照 CSS 抄代码的人会抄回坏值）：样式表里 `.party-chip { width: 32px; height: 32px }` 仍在（被内联压住）、`.field-value-serif { 18px serif 700 }` 成了无人引用的死规则、HTML 注释仍写着 `three 32px pill quick-picks`。**下一轮整屏重生成时把这三处一起清掉，不要为它们单发一条**——单发只会再打一层内联补丁。

**这轮新量出来的一条**：屏 2 顶栏品牌字 `.brand-subtle` 是 **16px / 700 serif**，同样撞「serif 只有 32/700 与 21/700」。屏 1 的对应件是 `.brand-title` 32/700（合法，那是首屏 display），屏 3 顶栏不放品牌字。屏 2 归队做法：`.brand-subtle` 改 **sans 16/600/24 #17171A**，或直接删掉品牌字、顶栏只留 `21/700/32 serif` 页标题。

### 11.5 屏 2 顶栏品牌字（2026-10-14，接 11.4 之后单发的一条）

11.4 量出的那条单独发。屏 2 顶栏的 `有径` 走 `.brand-subtle` = Noto Serif SC **16px / 700**——16/700 一样不在字阶里（serif 只有 32/700 与 21/700），而且紧挨返回箭头的品牌字属于 chrome，本来就该是 sans。第三章屏 2 正文已补上 Chrome 一行，这段把画布上那块帧拉齐。发法同 11.4：选中屏 2 的帧、留着 context chip，前置块 + 下面这段。

```
Frame "有径 - 行程基础输入" — one item only, and it is a type-scale break, not a colour one. Keep every colour literal, every radius, the 44px hit boxes and the inline-styled 24px party pills exactly as they are now.

`.brand-subtle` renders the wordmark 有径 in the 60px title bar as 'Noto Serif SC' 16px / weight 700. 16/700 serif does not exist in the scale — serif is only ever 32/700/44 or 21/700/32 — and a wordmark sitting in a bar beside a back chevron is chrome, so it belongs to the sans family anyway. Change `.brand-subtle` to HarmonyOS Sans 16px / 600 / line-height 24px, colour #17171A, letter-spacing 0. Keep the element, its position and the bar's 60px height untouched.

Do not change: the 21/700/32 serif .page-title 开启一次有迹可循的旅程 and its 14/400 #5A5A60 subtitle, the .field-value rows, the party chips and their inline styles, the 4px budget track, the single solid #0066CC 44px pill CTA, the 360px × 780px .device-frame, or any colour literal.
```

发完验一条（死规则允许仍在，见 11.4 的交接地雷）：

```
cd ~/Downloads/stitch_v7_ledger && d=$(ls -dt 屏2_*/ | head -1) && echo "$d" && python3 -c "
import re,sys;h=open(sys.argv[1]+'/code.html',encoding='utf8').read()
print(' '.join(re.search(r'\.brand-subtle[^{]*\{([^}]*)\}',h).group(1).split()))
print('serif rules:',[ ' '.join(s.split()) for s,b in re.findall(r'([^{}]+)\{([^}]*)\}',h) if 'Noto Serif' in b ])" "$d"
```

期望（两条都算过）：① **活着的**字标是 sans——`.brand-subtle` 规则本身改了，或 `<span class="brand-subtle">` 挂了 sans 内联；② 无新增色值、`box-shadow` 仍为 0。**只看样式表会把合格帧判成失败**，见下。

**实测结果（同日，`5c69ef4c → 7d2eafa8`，又是就地修正、未 fork）**：逐行 diff 整份 `code.html` 只有**一处**变化——`<span class="brand-subtle">有径</span>` 变成 `<span class="brand-subtle" style="font-family: &quot;HarmonyOS Sans&quot;, ui-sans-serif, system-ui, sans-serif; font-size: 16px; font-weight: 600; line-height: 24px; color: rgb(23, 23, 26); letter-spacing: 0px;">有径</span>`（外加两个尾随空行）。渲染层已合规，样式表第 88 行的 `.brand-subtle { 'Noto Serif SC'; 16px; 700 }` **原封未动**，于是变成第 4 处交接地雷。四条闸门全过（`tailwind.config=` 0、8 位 hex 0、M3 token 0、`safe-area-inset-bottom` 1），`box-shadow` 0，内联 `style=` 9 个，12 个色值全在梯内（`rgb(23, 23, 26)` = `#17171A` 的 rgb 拼法，合法）。

屏 2 到此收口。**四处地雷（死 `.field-value-serif` 规则、`.party-chip {32px}`、`three 32px pill quick-picks` 注释、`.brand-subtle` serif 规则）不再单发清理**——单发只会再叠一层内联补丁，全部留给下一轮整屏重生成。台账：`屏2_有径 - 行程基础输入_7d2eafa8`（`e86474fd`、`5c69ef4c` 两版留作历史）。

### 11.6 屏 4 首生全绿，只坏在底栏材质（2026-10-14，`7df4d288` 实测）

屏 4 用带 PRE-EMIT SELF-CHECK 的前置块整屏生成，**一条返修没欠**：四条闸门全过（`tailwind.config=` 0、8 位 hex 0、M3 token 0、`safe-area-inset-bottom` 2），`box-shadow` **0**，内联 `style=` **0**，字号只出现 11/12/14/16/18、serif 规则 0 条，16 个色值全在梯内。度量逐条对上：`.device-frame` 360×780、状态栏 44、标题栏 60、`.nav-btn` 44×44 透明、`.page-title` sans 18/600/24 `#17171A`、`.action-recommend` 12/600 `#0066CC` 透明无边、摘要条 44px 扁平 `#EFEFF2` 零 blur、轨道 4px 44% `#0066CC`/`#E9E9EC`、横幅 `#EFEFF2` radius 14 **没边条**（自查第 7 条被听进去了——**当天稍后判定：这条恰恰听错了**，横幅是理由件，DESIGN.md 要求它带 2px 蓝左条，见 11.7）、`.attraction-row` `min-height: 76px` × 9、缩略图 36×48 radius 6 `#E9E9EC`、名称 18/600 sans + nowrap/ellipsis、`#A06400` + `#FFFFFF` 的 需预约 徽章恰好 1 枚落在二年坂、优先级 44×44 热区套 24px 圈（未选 `rgba(196, 196, 202, 0.40)` 描边、选中 `#9A6206` + 白 必）恰好 1 选 8 未选、分隔线 0.5px 恰好 **6** 条 = 分节内 (4-1)+(3-1)+(2-1)、滚动区 `calc(94px + env(safe-area-inset-bottom))`、底栏 `calc(16px + env(safe-area-inset-bottom))`。内容也是真京都：清水寺 / 二年坂 / 伏见稻荷大社 / 金阁寺 / 锦市场 / 鸭川纳凉床 / 宇治抹茶街 / 岚山竹林小径 / 哲学之道。

**唯一一条缺陷是材质**：`.bottom-bar` 写了 `background-color: rgba(255, 255, 255, 0.92)` + `backdrop-filter: blur(24px)`。对照 DESIGN.md 的组件表，带 blur 的只有 `top-bar-immersive`、`segmented-control`、`floating-dock`、`sticky day header`、`sheet-modal` 五处，**底部动作条不在名单上**；屏 2、屏 3 的同一条都是实心 `#FFFFFF`（整份文件 `backdrop-filter` 出现 0 次）。`0.92` 这个数还是从契约的 `press-opacity` 串门过来的。标题栏那处 `rgba(255, 255, 255, 0.44)` + blur 是合法的 `top-bar-immersive`，**不动**。

根因先堵再返修：前置块 CONTROLS 的 glass 一条已补上「bottom action bar 也在扁平名单里，实心 `#FFFFFF`；0.92 是按压透明度不是面透明度」，第三章屏 4 正文的 Footer 行同步钉死扁平。**这条改动对后面 12 屏都生效**——底栏是每屏必件，不堵就要每屏返修一次。

```
Frame "有径 - 景点选择" — one item, and it is a material break, not a colour or metric one. This frame passed the contract audit everywhere else (9 rows at 76px, sections 4 / 3 / 2, one 需预约 badge, one selected priority circle, 6 in-section dividers, zero box-shadow, zero inline style attributes). Fix the footer surface and nothing else, and edit the stylesheet rule — do not solve it by hanging an inline style on the element, this frame is clean and must stay clean.

`.bottom-bar` declares background-color: rgba(255, 255, 255, 0.92) together with backdrop-filter: blur(24px) and its -webkit- twin. A footer CTA strip is not one of the contract's glass surfaces (top bar, segmented control, floating dock, sticky day header — DESIGN.md counts exactly four) — 0.92 is this system's press opacity, not a surface alpha, and the shipped sibling frames 行程基础输入 and 偏好追问状态机 both draw their action strip as solid #FFFFFF. In the `.bottom-bar` rule: set background-color to #FFFFFF and delete both backdrop-filter declarations. Keep position: absolute, bottom: 0, the padding calc(16px + env(safe-area-inset-bottom, 12px)), the 12px gap and the z-index.

Do not change: the title bar and its rgba(255, 255, 255, 0.44) + blur(24px) top-bar material, the 44px flat #EFEFF2 summary strip, the 4px capacity track, the #EFEFF2 radius-14 advisory banner (it has no accent edge — keep it that way), the 36px × 48px radius-6 thumbnails, the 18/600 sans names, the #A06400 badge, the 44px × 44px priority hit boxes with their 24px circles, the single solid #0066CC 44px pill, or any colour literal.
```

发完验三条（这条要求走样式表，内联数必须仍是 0）：

```
cd ~/Downloads/stitch_v7_ledger && d=$(ls -dt 屏4_*/ | head -1) && echo "$d" && python3 -c "
import re,sys;h=open(sys.argv[1]+'/code.html',encoding='utf8').read()
css='\n'.join(re.findall(r'<style[^>]*>(.*?)</style>',h,re.S))
for s,b in re.findall(r'([^{}]+)\{([^}]*)\}',css):
    s=' '.join(s.split())
    if 'bottom-bar' in s or 'title-bar' in s: print(s[:34],'=>',' '.join(b.split())[:190])
print('inline style=:',len(re.findall(r'style=\"',h)),'| backdrop-filter:',re.findall(r'backdrop-filter:\s*blur\([^)]*\)',css),'| box-shadow:',h.count('box-shadow'))" "$d"
```

期望：`.bottom-bar` 变成 `background-color: #FFFFFF` 且**两个 backdrop-filter 声明消失**，`.title-bar` 的 `rgba(255, 255, 255, 0.44)` + blur 原样留着，内联 `style=` 仍为 0。**这是第一次要求短纠偏走样式表而不是内联**——如果它还是打内联补丁，就记下这条结论：内联通道不是提示词能改变的，短纠偏一律按「渲染对、样式表留死值」交付。

台账：`_superseded/屏4_有径 - 景点选择_7df4d288`（返修前的全绿版）、`屏4_有径 - 景点选择_7d6e58d6`（返修后）。

**实测结果（同日，`7df4d288 → 7d6e58d6`，就地修正、未 fork，帧数仍 4）**：渲染层修好了——`<div class="bottom-bar" style="background-color: rgb(255, 255, 255); backdrop-filter: none;">`；样式表那条 `.bottom-bar { … rgba(255, 255, 255, 0.92) … blur(24px) }` **一个字没改**。提示词里那句「do not solve it by hanging an inline style on the element，this frame is clean and must stay clean」**被完全无视**。

> **这条把 11.4 悬着的问句关掉了：内联通道不是措辞能改的。** ≤2 条的短纠偏一律走 DOM 内联补丁，样式表原地留死值；写「必须改样式表」只会多花一轮而拿不到干净 CSS。**所以：短纠偏只用于"渲染必须对"的闸门级缺陷，凡是清理死规则都要靠整屏重生成。** 屏 4 现在也进了屏 2 那一类——出生全绿、带 1 处内联补丁 + 1 条死规则，家族累计 5 处残留（屏 2 四处 + 屏 4 一处），统一留给最后一轮逐屏重生成，不再单发。

副产物一条（旧版没记过）：补丁轮会把 HTML **重新序列化**，diff 里会出现 `<html style="">`、`crossorigin=""`、`&amp;`、`<path/></path>` 拆成 `<path>…</path>`、尾部多空行这类噪声。**认帧与改动对账要按"有意义的差集"读**，别把重序列化当成回归；判回归仍看这四样：闸门 4 条、色值台账、`box-shadow`、内联 `style=` 计数。返修后复检数字：闸门全过，`box-shadow` 0，8 位 hex 0，字号 {11,12,14,16,18}，serif 规则 0 条，17 个色值全在梯内（`rgb(255, 255, 255)` = `#FFFFFF`），`backdrop-filter` 从 3 处规则降到 **仍 3 处**（状态栏 + 顶栏合法玻璃、底栏死规则被内联压住）。

### 11.7 我把契约件当缺陷删了：理由块的 2px 蓝左条（2026-10-14，屏 5 预检时撞出来）

给屏 5 做发送前预检时，我按前置块自查第 7 条把正文里的 `2px #0066CC left rule` 判成自伤缺陷——**这条判据本身是错的**。DESIGN.md 组件表写得很清楚：

```
reason-block:
  backgroundColor: "{colors.surface-panel}"   # EFEFF2
  rounded: "{rounded.md}"                     # 14
  leftRule: "2px solid {colors.primary}"      # 0066CC
```

同文件第 1116 行的散文再确认一遍：「The "why" is a `reason-block`: `surface-panel` with a 2px `primary` left rule … this is the product's honesty device and must never be hidden behind a tap。」第 1145 行禁的是玻璃/模糊/渐变上理由件，**不是禁这条左条**。所以「扁平不透明 + 2px 蓝左条」两句同时成立，我从前置块里那句笼统的 never borders 推出了「任何边都不许」，越界了。

**污染源与传播路径**：第十章第 3 关第 7 条（`.preview-foot has border-left … Drop the border`）是一次误诊，我把它抄成前置块自查第 7 条，于是每条提示词都自带它。已就地标注追述，别再照发那条老返修。

**受损面实测**（`grep -c border-left` 逐帧）——**2026-10-14 二次修正，见 11.9**：这张表最初是裸 grep 出来的，而 `border-left` 这个词也会出现在注释里，于是屏 1 那行**读反了**。剥注释后的真相：

| 帧 | 有理由件？ | 左条规则行 | 判定 |
|---|---|---|---|
| 屏1 `77ed8d08` | 有 `.preview-foot`（#EFEFF2 + 14 + label/desc） | **0**，且写着 `border: none`，上一行注释 `Correction 7: … strictly NO border-left` | **真受损，且比屏 4 更糟**：模型明确照办了我那条错条款。最初记成「左条活着、反而是对的」是判据误读 |
| 屏2 `7d2eafa8` | 无（`#EFEFF2` 0 次） | 0 | N/A，不受影响 |
| 屏3 `b6b3126b` | 无（`#EFEFF2` 0 次） | 0 | N/A |
| 屏4 `7d6e58d6` | 有 `.advisory-banner` | 0（从未声明过边，静默缺失） | **真受损** |
| 屏5 `1cd06e03` | 有 `.reason-block` ×2 | **1** | **全绿**：翻案后的第 7 条首生即生效 |
| 屏6 `35c7d3b4` | 无 | 0 | N/A |

所以实际受损是**两屏（屏 1、屏 4）**，不是三屏；屏 1 从「无需处理」变成清理轮必改项。

第三章待发的正文里有 **5 屏**明写这条左条（屏 5、7、8、10、14），全会与旧的第 7 条对撞——不发预检也会撞，因为前置块每条都带。

**已做的两处根因修改**（都在前置块，对后面每一屏生效）：CONTROLS 的 glass/边框那条补上「系统里唯一被要求存在的边就是理由件的 2px `#0066CC` 左条，它是契约不是卡片描边，不许为满足 no-borders 而删」；自查从七条变**八条**——第 7 条翻案成「理由件**必须**画左条，漏了才算缺陷」，新增第 8 条把屏 4 实测的底栏材质漂移（按压透明度串成面透明度 + 顶栏 blur 抄到 CTA 条）钉住。条款里不写被禁字面量，遵循第九章那条老规矩。

**清理轮（攒着，不单发）**：屏 4 现在欠两处——底栏样式表里的死规则 `rgba(255,255,255,0.92)` + blur，和横幅缺失的 2px 左条；屏 2 欠四处（见 11.4/11.5）。按 11.6 的结论，这些只能靠**整屏重生成**清，短纠偏只会再叠内联补丁。所以：16 屏全发完、全审完，再用现在这版前置块对屏 2、屏 4 各发一条整屏重生成，一次拿到零内联、左条齐、底栏实心的交付帧；届时旧帧删除仍需你点头。

### 11.8 屏 5 首生：两条翻案条款当场生效，但我差点把契约 token 报成缺陷（2026-10-14，`1cd06e03` 实测）

屏 5（住宿区域选择）用改过的前置块一次生成，**md5 `1cd06e030e7e0b2d98e327bbe92a56d3`、17,299 B、549 行**，导出包内 `code.html` + `screen.png`（262,937 B）两件齐全。结论先说：**11.7 翻案的第 7 条和新增的第 8 条，首生即守住，一条返修没欠。**

- `.reason-block` 样式表第 263 行实打实写着 `border-left: 2px solid #0066CC`，两张卡各用一次，`grep -c border-left` = 3（1 条规则 + 2 处注释）。上一版前置块把这条判成自伤、屏 4 因此丢了左条；这版反过来要求它，模型照做了。**翻案是对的，条款是可执行的。**
- `.bottom-bar` = `background-color: #FFFFFF` + `padding: 12px 16px calc(16px + env(safe-area-inset-bottom, 12px)) 16px`，全文件 `backdrop-filter` 只出现在第 82–83 行的 `.title-bar`（契约四处玻璃之一）。屏 4 那两个坏值一个都没复发。
- 四闸门 0 / 0 / 0 / 2；`box-shadow` 0；内联 `style=` **6**——逐条看过：3 条是地图浮层 `top/left` 定位，3 条是 `.chip-dot` 的 `background-color`，取值分别是 `#0066CC` `#5856D6` `#9E9EA3`，全在活动类型点色台账里。**这类内联是数据定位，不是补丁**，和 11.4/11.5 那种「把坏规则挂到元素上」不是一回事，别按数量一刀切报警。
- 字号只出现 11/12/14/16/18；`.device-frame` 360×780、状态栏 44、标题栏 60、`.nav-btn` 44×44 透明、CTA 44px radius 999 实心 `#0066CC` + `:active #0055BB scale(0.97)`、次级键透明 + 1px `rgba(196, 196, 202, 0.40)` + `#17171A` 墨字；选中卡恰好一条契约式（`rgba(0, 102, 204, 0.10)` + 1px `#0066CC` + 20px 蓝勾），未选卡 `#F7F7F8` 无边。地图 token 全在：`rgba(26, 26, 26, 0.15)` ×7、`#EAF2FA` ×3、渐变 `#FFFFFF → #F1F2F5`、动线 2px `#0066CC`。内容也对：祇园 · 东山 / 河原町 · 三条，理由件文案「早上 7 点前能空着走进清水寺，避开旅行团」，三列 步行 12分钟 / 34分钟 / 9 家。

**差点报错的 token**：动线底下那条 `rgba(0, 102, 204, 0.35)`、`stroke-width 6` 的底层描边，我第一反应是「模型自己造了个发光层，等于把 box-shadow 换个写法」。**错了**——DESIGN.md 第 717 行 `route-paper-path-soft` 就是这个值，ArkTS 侧 `59 00 66 CC`。判一个 alpha 之前查的是 **Translucency ledger（687 行起）**，不是 §1 色表也不是 §3 语义色；只看色表会把契约件当缺陷，这已经是本项目第二次在同一个坑边上撞（第一次是 11.7 的左条）。

**真留下的偏差（数值级，不影响渲染对错）**：地图三个候选区我正文只写了「soft tinted regions」没给 alpha，模型就自己造了 5 个台账外的步骤——`rgba(0, 102, 204, 0.25)`、`rgba(88, 86, 214, 0.08)`、`rgba(88, 86, 214, 0.2)`、`rgba(60, 60, 67, 0.06)`、`rgba(60, 60, 67, 0.15)`；再加 `rx="16"`（不在八个圆角 token 里）、徽章 `padding: 3px 8px` ×2、`.commute-col gap: 2px`、`.status-bar-icons gap: 6px`（都离开 4px 基准）。**根因在我这条正文，不在模型**：约束没给到字面量，它就只能猜。已把屏 5 正文的地图段重写死：只许推荐区有一层 `primary-tint` 填充，另两区无填充、只有 `separator` 虚线描边，圆角限 14/20，并补一句「本屏所有 padding/gap 落在 4px 基准上」。这条改动只对未来那轮重生成生效。

**新的导出事实（值得记进记忆）**：桌面画板的 `screen.png` **机身被整体下移 122 CSS px，底部裁掉 102–122 CSS px**（屏 4 画板 800 高裁 102，屏 5 画板 780 高裁 122，逐帧量过：`frame top css=122`）。底栏正好活在被裁掉的那一条里，所以**底栏材质、安全区留白这类东西永远别想用导出图验**，只能验 CSS——这也是 11.6/11.8 的判定全都建立在样式表文本上的原因。量法：`Image.open(png).size` 除以 2 得画板 CSS 尺寸，再从中心列扫第一个不等于角点背景色的 y。

验收命令（下面这条已对屏 5 实测跑通；**别再用手工白名单判 alpha**，我第一版写了个 `grep -vE '0\.15\)|0\.10\)...'` 的过滤，`0.2` 与 `0.20`、`0.1` 与 `0.10` 两种写法不相等，当场漏判两条、误报两条。正确做法是拿 DESIGN.md 的 Translucency ledger 当集合做差集，数值归一化后再比）：

```bash
cd ~/Downloads/stitch_v7_ledger/屏5_有径-住宿区域选择_1cd06e03 && \
printf "leftRule(仅规则) %s\n" "$(grep -cE '^\s*border-left: 2px solid #0066CC;' code.html)" && \
printf "leftRule(含注释) %s\n" "$(grep -c 'border-left: 2px solid #0066CC' code.html)" && \
printf "bottom-bar blur  %s\n" "$(grep -A3 '\.bottom-bar' code.html | grep -c 'backdrop-filter')" && \
python3 -c "
import re
def key(s):
    r,g,b,a = re.match(r'rgba\(([^,]+),([^,]+),([^,]+),([^)]+)\)', s).groups()
    return (int(r),int(g),int(b),round(float(a),3))
def load(p):
    return {key(m) for m in re.findall(r'rgba\([0-9]+,\s*[0-9]+,\s*[0-9]+,\s*[0-9.]+\)', open(p).read())}
led=load('/Users/itxiaobai/Documents/StitchDesign/DESIGN.md'); off=sorted(load('code.html')-led)
print('off-ledger alpha count', len(off))
for o in off: print('  rgba(%d, %d, %d, %s)'%(o[0],o[1],o[2],str(o[3]).rstrip('0').rstrip('.')))
"
# 屏 5 实测：仅规则 1 / 含注释 3 / bottom-bar blur 0 / 台账外 alpha 5 个（0,102,204,.25 · 60,60,67,.06 · 60,60,67,.15 · 88,86,214,.08 · 88,86,214,.2）
# 重生成后期望：1 / 3 / 0 / 0
```

**屏 5 不加发送返修**：台账外 alpha 与圆角/间距是数值级残留，短纠偏只会叠内联补丁、把样式表弄得更脏；正文已经改死，进清理轮随屏 2、屏 4 一起整屏重生成。清理轮现在是**四屏**（屏 1 理由件缺左条 + `padding: 10px 12px` 越基准、屏 2 四处死规则、屏 4 底栏 + 缺左条、屏 5 地图 alpha 与圆角），删旧帧仍要你点头。

### 11.9 屏 6 全绿 + 判据本身的两处假报（2026-10-14，`35c7d3b4` 实测）

屏 6（行程生成中）首生：**md5 `35c7d3b4dbedcc64a8f8472a075bba74`、14,349 B**，四闸门 0 / 0 / 0 / 3，内联 `style=` **0**，台账外 alpha **0**（只用了 `rgba(255,255,255,0.44)` 顶栏玻璃 + `rgba(196,196,202,0.40)` 描边，两个都是台账件），`box-shadow` 声明 **0**，底栏实心 `#FFFFFF` 零 blur、全文件 blur 只在第 81–82 行的顶栏。实心 `#0066CC` 只出现在 `.progress-fill` 一处——**这屏没有第二个蓝控件**，`取消` 是透明 + 1px 描边 + `#17171A` 墨字。度量逐条对上：360×780、状态栏 44、标题栏 60、步骤行 44、进度条 4px 75% `#0066CC`/`#E9E9EC`、骨架日卡 44px 头部块 + 三行 `min-height: 76px`（52px 时间块 / 24px 节点 / 160px + 56px 双行）、外 20 内 14 圆角、shimmer 1200ms。正文四条中文步骤名全在（筛选景点 / 排布每日动线 / 校验开放时间与预约 / 估算步行耗时），serif 只有一条 `.headline-serif` = **21/700/32**，合第 5 条。

预检改的那三处生效了两处半：顶栏材质 + 页名 生成行程 ✓；**108° 的歧义解决了**——圆弧是 `stroke` 实心 `#0066CC`、`stroke-width 2`，全文件没有为它引入任何 rgba ✓；但 **40ms 逐行入场没实现**：文件里只有 `rotateArc` 与 `shimmerSweep` 两条 `@keyframes`，`animation-delay` / `nth-child` **0 命中**。静态帧做不到序列入场，这条留给 ArkTS 实现，不再对 Stitch 追。

**判据本身的两处假报（都已修进 `audit.sh`）**：

1. `grep -c 'box-shadow'` 在屏 6 报 1，实际命中的是注释「契约画幅：…**零 box-shadow**…」——**我把一条遵守契约的注释读成了违反契约**。
2. 同一类更早就发生过：11.7 的受损表用 `grep -c border-left` 判屏 1「左条活着」，实际命中的是注释 `Correction 7: … strictly NO border-left`，规则体是 `border: none`。**屏 1 是真受损**，而且它是我这条错条款唯一被完整执行的地方。

做法固化成一条：**声明级判据一律先剥注释**（`perl -0pe 's{/\*.*?\*/}{}gs; s{<!--.*?-->}{}gs'`），`box-shadow` 还要排除 `box-shadow: none` 这种防御性重置；裸 grep 的计数只作为参考行列出，不进结论。审计脚本落在 `~/Downloads/stitch_v7_ledger/audit.sh`，用法 `bash audit.sh <帧目录>/code.html`，一次输出四闸门 / 补丁通道 / 字号 / serif / 圆角 / 4px 基准越界 / 台账外 alpha（数值归一化差集）/ 第 7 条 / 第 8 条 / 实心蓝归属。

**九帧横向台账（剥注释后重跑，2026-10-14）**：

| 帧 | md5 | shadow | 内联 style | 台账外 alpha | 左条规则行 | 底栏 blur |
|---|---|---|---|---|---|---|
| 屏1 | `77ed8d08` | 0 | 1（定位） | 0 | **0（受损）** | 0 |
| 屏2 | `e86474fd` | 0 | 1 | 0 | 0（无理由件） | 0 |
| 屏2 | `5c69ef4c` | 0 | 7 | 0 | 0 | 0 |
| 屏2 | `7d2eafa8` | 0 | 8 | 0 | 0 | 0 |
| 屏3 | `b6b3126b` | 0 | 0 | 0 | 0（无理由件） | 0 |
| 屏4 | `7df4d288` | 0 | 0 | **1** | 0（受损） | 0 |
| 屏4 | `7d6e58d6` | 0 | 1 | **1** | 0（受损） | 0 |
| 屏5 | `1cd06e03` | 0 | 6（定位/点色） | **5** | **1** | 0 |
| 屏6 | `35c7d3b4` | 0 | 0 | 0 | 0（无理由件） | 0 |

屏 4 那 1 个台账外 alpha 就是 `rgba(255, 255, 255, 0.92)`——底栏的死规则本体，**差集法把它当场揪出来了**，这正是 11.6 说「样式表里还写着坏值不等于本轮没生效」之后需要的补充判据：内联已覆盖、样式表仍污染，靠 alpha 差集而不是靠肉眼看 `.bottom-bar`。

屏 6 留下的两处数值残留：`gap: 6px`（状态栏图标）与 `margin-top: 6px`；另有图标内部 SVG 子像素 `rx="0.5"/"1.5"/"2.5"`，那是 24 viewBox 里的笔画圆角，不算圆角 token 违例（脚本会列出来，判读时按 viewBox 缩放换算，别当缺陷报）。**屏 6 不发返修。**

对比度一行算式（屏 7 预检起每屏发送前跑一遍，配对来自正文里写死的「前景 × 背景」）：

```bash
python3 -c "
def L(c):
     f=lambda v:(v/255/12.92 if v/255<=0.03928 else ((v/255+0.055)/1.055)**2.4)
     r,g,b=[f(x) for x in c]; return .2126*r+.7152*g+.0722*b
def C(a,b=(255,255,255)):
     x,y=L(a),L(b); hi,lo=max(x,y),min(x,y); return (hi+.05)/(lo+.05)
h=lambda s:tuple(int(s[i:i+2],16) for i in (1,3,5))
for fg,bg in [('#9E9EA3','#FFFFFF'),('#9E9EA3','#EFEFF2'),('#69696E','#EFEFF2'),('#5A5A60','#EFEFF2'),('#17171A','#EFEFF2'),('#A06400','#FFFFFF'),('#FFFFFF','#0066CC')]:
     print(fg,'on',bg,round(C(h(fg),h(bg)),2))
" --  # 期望：文字 ≥4.5，图标/描边 ≥3.0；实测 2.67 / 2.32 / 4.76 / 5.97 / 15.59 / 4.86 / 5.57
```

### 11.10 屏 7 全绿，但它把我前置块的第三条收紧条款顶出来了（2026-10-14，`a21e614c` 实测）

屏 7（生成受阻）首生：**md5 `a21e614ce91272ef5dd04835bf03442f`、11,529 B**，四闸门 **0 / 0 / 0 / 2**，内联 `style=` **0**，台账外 alpha **0**，阴影 0 条，`border-left: 2px solid #0066CC` **规则行 1 条**（第 7 条），`.bottom-bar` 实心 `#FFFFFF` + 零 blur、全文件 blur 只在 84–85 行的顶栏（第 8 条）。字号 {11,12,14,16,18,21}，serif 只有 `.headline-title` = **21/700/32**，圆角只有 999×2 与 14×1（SVG 的 `rx="0.5/1.5/2.5"` 是状态栏电量与信号图形，不是 UI 圆角）。**实心蓝只出现在 `.btn-primary`** 一处，两只描边键 换一天 / 去掉这个景点 是各自独立的 `<button>`——斜杠写成一个标签那个坑没踩。**发送前算对比度拦下来的两处，落地了**：chevron `.solution-chevron` 22×22 + `#69696E`（4.76:1），图标 `.failure-icon` 描边 `#69696E`（5.46:1）。

残留四条，都进末尾统一重生成轮，不发单条返修：`.failure-icon` 被放大成 **24×24**（正文写的是 22×22，Stitch 另套了个 `48×48` 容器，注释里还写着「22×22」——**注释与声明互相矛盾，这正是判据必须先剥注释再看声明的理由**）；`.solution-info` `gap: 2px`、`.status-icons` `gap: 6px` 离开 4px 基准；`.btn-outline:active` 用 `opacity: 0.92`——非图标、又是瞬态按压，算可接受，但契约给的是 `scale(0.97)` + 换色，下一轮统一。

**第 6 条自查翻案（本轮最要紧的一条，改的是我自己的判据）**：原文是「`box-shadow` appears nowhere in the frame. Not on the CTA, not on cards.」——**这是第三条比正文更严的收紧条款**（前两条：11.7 的左条、11.9 的圆角/语义色并集）。DESIGN.md `elevation` 段 269–273 行明明给了五档闭集 `contact / card / floating / segmented / popover`，354 行 `selectedItemShadow: {colors.glass-selection-shadow}` 更是一条**合法的蓝色阴影**，1086 行写「selection pill … with a blue-tinted shadow」、1045 行写 `card` (10px blur, 3px y, 7% black) 用在行程卡与摘要卡。而屏 8 / 9 / 14 / 15 的正文点名要 card 与 floating 投影——再照旧发出去，Stitch 只能在「前置块说零、正文说要」里挑一条，两种结果我都得判它坏。**已改**：前置块第 6 条换成六条声明的闭集 + 归属表（`card`=行程/摘要卡、`floating`=dock/半模态/拖动中的行、`segmented` 与那条 `rgba(0,102,204,0.18)` 只给分段选中胶囊、按钮/徽章/chip/理由件/万能卡片/动线画布一律不许带），CONTROLS 的玻璃条改为「阴影只从闭集来」，屏 4/5/7 正文那三行「zero box-shadow」改成「本屏六条一条都不需要，别加」，`audit.sh` 的阴影栏从「计数 != 0 即坏」换成**六条声明的数值归一化差集**（`rgba(0,0,0,.07)` 与 `rgba(0, 0, 0, 0.07)` 同源，字符串比对会假报——我先写字符串版，测 `.07` 拼法直接漏过）。历史台账里那条「删掉 `.btn-primary` 的 `0 2px 6px rgba(0,102,204,0.2)`」**仍然成立**：CTA 底下的蓝投影从来不在闭集里，翻案翻的是「一处都不许有」，不是「蓝色一律不许有」。

**audit.sh 自己也有一条恒空断言**（11.9 教训的同类，第二次）：`awk '/^\s*\.[a-zA-Z-]+.*\{/'` 在 macOS awk 里 `\s` 不是字符类，选择器永远不匹配，于是「实心 #0066CC 出现在哪些类」这一栏**每屏都输出空**——我第一轮就把它读成了「这屏没有实心蓝控件」。改 `[[:space:]]` 后屏 7 立刻报出 `.btn-primary`。**规矩不变：任何一条恒为 0 / 恒为空的判据，先怀疑模式，再怀疑交付物。**

屏 8 发送前预检拦下七处（三处是正文与前置块当面对撞，一处违反我自己的自查第 3 条）：`44px share icon + 44px more icon`（44 是热区，图标只有一档 22×22）；`two transit legs at 44px on #F2F2F4 with 10px radius` **直接违反自查第 3 条「transit leg 无底色填充」**——第二次出现「我自己的正文和我的自检块打架」，上次是屏 2 的 serif 值与 32px pill；`32px 6px-radius photo thumb` 违反 3:4 媒体（改 36×48）；`a 18px blue glow spot`（DESIGN.md 写的是 ~180px，且 `pressGlow = {colors.primary-tint}`）；`18% border` / `18% blue shadow` 两处含糊（补成 `rgba(60, 60, 67, 0.18)` 与 `0px 0px 8px 0px rgba(0, 102, 204, 0.18)`）；顶栏没写材质与玻璃（屏 5/6 同一课）。改完正文 3,561 字，拼前置块 8,489 字 = **12,052 字**，8 位 hex 0。

还没发出去的屏里，同类坑已登记待改：**12b** 的 `a 48px #9E9EA3 geometric line icon`（两处自伤，和屏 7 原稿一模一样）、**屏 9** 的 `20px swap icon / 20px minus icon`（第二档图标尺寸）与 `six dots, #9E9EA3`（点色压白 2.67:1，压 `#F7F7F8` 更低），改正文时一并落。

### 11.11 屏 8：阴影闭集在第一屏就兑现，另发现契约自己跟自己矛盾（2026-10-14，`9c0acbcd` 实测）

屏 8（行程时间线主视图）首生：**md5 `9c0acbcdca758d1c6b2f53541f988520`、24,789 B**（v7 最大的一屏）。四闸门 **0 / 0 / 0 / 2**；**阴影 2 条 / 违规 0 条**——`.segmented-pill` 拿 `0px 0px 8px 0px rgba(0, 102, 204, 0.18)`、`.floating-dock` 拿 `0px 6px 16px 0px rgba(0, 0, 0, 0.09)`，两条都是正文点名的闭集值。**这就是 11.10 那次翻案的兑现点**：前置块第 6 条若还是「box-shadow 一处都不许出现」，这屏只有两种结局——要么 Stitch 违契约画平的，要么它照正文加阴影、然后被我的判据判成坏帧。第一条路会让分段选中态和 dock 失去层级，第二条路会白白排一轮返修。

玻璃四件逐条对上：`.top-bar-container` blur 24、`.segmented-control` blur 20（DESIGN.md 352 行 `blur: {layout.glass-blur}` 的例外档）、`.sticky-day-header` blur 24、`.floating-dock` blur 24——**正好是契约授权的四件，第五件都没有**。度量：5 条 `.stop-row` `min-height: 76px`、24px 节点 / 10px 点 / 52px 时间栏、`.photo-thumb` **36×48 radius 6**（把正文里我写错的 32px 方形换掉之后落对了 3:4）、`.day-label` serif **21/700/32**、圆角只出现 999/30/20/14/6、`.dock-glow` **180×180**、transit leg 44px **无填充** + `border-left: 2px dashed rgba(60, 60, 67, 0.20)`（自查第 3 条这次没被违反，因为正文不再要求 `#F2F2F4` 底——**上一版正文和自检块打架的那条已拆弹**）。**零实心蓝控件**：实心 `#0066CC` 只在 `.spine-line`（当前段）与 `.dot-sight`（当前节点）两处，都是契约图形件；正文里明写「this screen carries zero solid #0066CC controls」，挡住了「一屏必须有一颗主按钮」的补位冲动。

残留五条进统一重生成轮：① 6 处离开 4px 基准（`.segmented-*` `padding: 2px`、`.booking-badge` `3px 8px`、`.stop-row` `margin-top: 10px`、`.transit-content` `gap: 6px`、`.dock-item` `padding: 0 10px`、`.dock-icon` `margin-bottom: 3px`）。② `.transit-icon` **14×14**——**第三档图标尺寸**，可正文压根没要求这个象形件（我要的是「2px 虚线 + 12/450 文字」），契约也没定义「嵌在 12/450 微文案里的象形件该用哪一档」。这条**不是 Stitch 的错，是契约的空洞**：要么正式加一档 inline pictogram（14/16 都要写清描边是否随盒子放大），要么在正文里禁掉。**待拍板**。③ dock 四只图标里两只挂了内联 `style="stroke: #3C3C43; margin-bottom: 0"`、另两只吃 `.dock-icon` 的 3px——**同一组件内不一致**，这才是内联补丁的真实危害；判内联要看它有没有把同组元素劈成两种渲染，别只看计数。④ 台账外 alpha 1 条 `rgba(0, 102, 204, 0)`：是 180px 光斑径向渐变的**外圈停靠点**，alpha 0 是几何不是颜色 → `audit.sh` 已改成单独一栏「渐变停靠点(alpha=0)」，不再计入违规（改完这屏就是 **台账外 0 种**）。⑤ 内容偏差：`需预约` 徽章 3 枚（正文要求恰好 1 枚）——语义上比 1 枚更真实，但**它是我明写过「恰好一枚」的约束**，记在这里等你拍板留 3 还是改 1。

**契约内部矛盾一条（本轮最该记的）**：DESIGN.md 1098 行「Empty state. Centered: **faint** icon at 48px」和 855 行「`faint` is the only sub-AA token and fails even the 3:1 graphic floor…restricted to disabled and placeholder text」**直接互斥**；而 22×22 这个控制图标档在 DESIGN.md 里**根本没出现**（它只写 `icon-button: size 44px`），是我从已上线的 有据 代码里带进前置块的。所以屏 7 那个「24×24 图标套 48×48 容器」根本不是 Stitch 乱画——**它在两条互斥规则之间取了中点**。已按 855 修 1098（`faint`→`muted` `#69696E` + 写明 48 是唯一的展示档、viewBox 24、描边不随盒子放大），并把前置块 CONTROLS 的图标条补成两档口径。**屏 9 与 12b 正文里同类的三处自伤（`20px swap/minus icon`、`six dots #9E9EA3`、`48px #9E9EA3 icon`）已同批改完**：12b 用 48×48 展示档 + `#69696E`，屏 9 的把手点色改 `#69696E`、两只尾随图标改 22×22 套 44×44 热区，阴影一律写成闭集字面量。

**导出操作这一轮我漏做了第 4 步第 1 小步**（不是 SOP 缺条款，是我没照做）：生成结束后画布上**没有默认选中**那块新帧，直接点 Export 拿到的是 `标题 No screens selected`、格式栏整排不出现、确认键 `(disabled)`——这正是第 1 小步写过的症状，只是我当时以为「刚生成完肯定是选中态」。屏 5/6/7 三次侥幸对（那几轮生成后确实带着选中），屏 8 断了。**判据不变**：对话框里有没有 Format 那一排 = 选没选中，别看画布高亮。**操作不变**：先在画布上坐标点中新帧标题（本例 49% 缩放，屏幕坐标 ×1.64），再点 Export。

### 11.12 屏 9：第一次发送「回复完成但没成帧」，我把这条做成了硬判据（2026-10-14，`ebe57eac` 实测）

屏 9（行程时间线编辑态）正文 2,368 字 + 前置块 9,107 字 = 拼出的文件 **11,478 字 / 11,728 字节 / 8 位 hex 0 处**，一次粘贴一次回车。**第一次发送失败在回写**：聊天侧的回复文本已经流完（末句停在「…数值严格启用 tabular-nums。」），composer 也复位成 placeholder，看起来像成功；但画布上带标题的帧**还是 8 块**，另外挂着 2 个 `Generating Screen...` 标签。我没有靠「感觉它还在生成」下结论，而是把可疑帧导出取证：点中一块 `Generating Screen...` 帧 → context chip 显示的名字就是 `Generating Screen...`、尺寸牌 `1280 x 800` → Export `.zip`（`stitch_youjing_v7 (16).zip`）→ `code.html` **16,052 B / md5 `36f09148…` / `<title>有径 - 景点选择</title>`**，且该帧绑定的聊天消息写的是「对「有径 - 景点选择」界面的底部操作栏 `.bottom-bar` 完成了纠偏」——**它是屏 4 那轮纠偏留下的死帧，不是屏 9**。另一块死帧装的是屏 8 内容。结论：屏 9 那一次**一个字都没落到画布上**。

**由此新增一条认帧判据（写进第 3 步）**：认帧只认 **`HTML 内容 有径 - <title>` 的条数 +1**，或画布上冒出一个**新标题**；「聊天回复写完了」和「画布上有 `Generating Screen...` 标签」都**不能**当成交付。屏 9 这一轮我就是靠这条从 8→9/7→10 的计数变化里确认成帧的。

**我自己的一个未遂因果**：第一次发送后我在 `Generating Screen...` 还挂着的时候点了「重新加载」（元素 `按钮 重新加载`）。回复文本在刷新前就流完了，但帧的 srcdoc 是异步补的，**不能排除是这次刷新掐断了回写**。立规矩：**画布上还有 `Generating Screen...` 就不许刷新**，等它变成标题或明确报错再说。因果未证实，所以只登记成操作禁令，不写成 Stitch 的 bug。

第二次发送前先清掉 context chip（`按钮 Remove`，本例元素 1538；点一次经常不生效，要复查 `chipLeft: []`），再粘同一份 11,478 字 → 成帧 **`有径 - 行程时间线编辑态`** → 坐标点中标题（49% 缩放）→ Export 对话框出现 Format 那一排（= 选中确认，屏 8 漏掉的那一步这次补上了）→ `.zip`（`stitch_youjing_v7 (17).zip`）→ 台账 `屏9_有径-行程时间线编辑态_ebe57eac`：**md5 `ebe57eac83d926b95c3d1eec265eee29` / 20,686 B**。

审计（`bash ~/Downloads/stitch_v7_ledger/audit.sh`）：**四闸门 0 / 0 / 0 / 2**；**阴影 3 条 / 违规 0 条**——`.stop-card` 吃 `card`、`.timeline-row.mid-drag .stop-card` 吃 `floating`（正文点名的那条）、`.insertion-badge` 吃 `contact`，而 `.timeline-row.vacated .stop-card` 主动写了 `box-shadow: none`：**「移走的那一行不再浮起」这个状态语义它自己补对了**，闭集没有把阴影变成无差别的装饰。blur 只有 2 处（顶栏 + 吸顶日头，正是这屏授权的两件），底栏 `background-color: #FFFFFF` 且 `backdrop-filter` 0 命中——**自查第 8 条第二次零违反**。实心 `#0066CC` 只落在 `.btn-primary`（保存修改）一颗，「完成」按正文要求做成 22×22 蓝勾 + 文字动作；其余三处蓝是 `.spine-line` / `.dot-sight` / `.insertion-gap-line` 这些契约图形件。字号 11/12/14/16/18/21 全在档，serif 只有 21/700 一处。**全帧零 `#EFEFF2`** → 自查第 7 条（理由块左条 0 命中）在这屏是 **N/A 不是违规**：正文没放理由块，别把 0 当缺陷报——这是「常量恒 0 的判据先怀疑判据」那条老规矩的第 N 次兑现。

残留五条进统一清理轮：① **5 处内联 `style=`**（`border-style: dashed; border-color: #9E9EA3`、`background-color: #9E9EA3`、`color: #69696E`、`color: #0066CC`、`border-color: #0066CC`）。② **3 只离档象形件**：2× `14×14` `#3C3C43`（撤销、锁定）、1× `12×12` `#0066CC`（插入指示件）——和屏 8 残留②是**同一个契约空洞**（内联在 12/450 微文案里的象形件到底哪一档），**inline pictogram 仍待你拍板**。③ `padding: 3px 8px` ×2、`gap: 6px` ×2 离开 4px 基准。④ `.insertion-badge` 边框 `rgba(0, 102, 204, 0.20)` 是**台账外 alpha**：徽章法只授权「10% 蓝底 + 1px 实心 `#0066CC` 边」或中性底，20% 蓝边是第三种拼法。⑤ `.insertion-gap-line` 的 `border-radius: 1px`——2px 线的端头圆角，属几何不属八档 token，登记是为了下次别误报。

**文档侧本轮两处修**（都在发屏 9 之前做完，所以屏 9 用的是修好的块）：前置块 CONTROLS 里「shadows exist only from the **five-token** closed set」改成 **six-token**——自查第 6 条列的是六条声明，我上一轮建闭集时只改了第 6 条本身，没回头改引用它的地方（**同一份文档里的计数引用要一起改**）。第 1 步的 DESIGN.md 指纹那行现在同时记两个值：**Stitch 端附件仍是 `96aef039…` / 70,730 B**，本地已改成 `fd1daa66…` / 70,962 B（1098 行 faint→muted 只在本地生效）——所以附件每轮还会把旧的 `faint` 48px 口径带进来，前置块的两档图标条就是它的对冲，别指望附件自己变对。

**待你点头的一件事**：画布上现在有 **2 块死帧**（`1280 x 800` 装屏 4 内容的那块、另一块装屏 8 内容），都是历史轮次 fork 出来没改名的。删帧是 GUI 破坏性操作，得你当场同意；不删也不影响后面的流程（认帧靠标题 + md5）。

### 11.13 屏 10：Return 静默失败一次，另抓到 audit.sh 自己的两条假绿（2026-10-14，`471fcea9` 实测）

屏 10（单个活动节点详情）正文 3,013 字 + 前置块 9,107 字 = **12,122 字 / 8 位 hex 0 处**。九处预检改在发送之前做完（全出血 3:4 hero 删掉、`44px chevron` 改 44×44 热区套 22×22、理由块补前景色、提示行钉死 `#FFFFFF` 底、底栏扁平 + 两条 `env()`、删 `免费入内` 第三枚金章、明写宋体是页面标题档、声明这屏六条闭集一条都不需要、外链节点序号色改 `#5A5A60`），正文里每个对比度数字都先用 python3 独立复算过。

**发送这一步静默失败了一次，而且我差点判它成功**。第一次 Return 之后：composer 复位成 placeholder、无障碍树里 `Screen 10 — 单个活动节点详情` 命中 3 次、`add no box-shadow at all` 也命中 3 次——**那三个命中全是 composer 自己的文本节点**，不是已发出的消息。我按老办法去数 `HTML 内容 有径 - ` 的条数，5 分钟纹丝不动停在 10；再按 Escape 取消选中帧、读聊天尾部，才发现**最后一轮仍然是 Screen 9 的回复**，屏 10 根本没进对话。第二次同样的「点 composer → paste → Return」**当场就通了**（30 秒内开始流「正在依照《DESIGN.md》硬性契约与 Pre-Emit 8 项自检规范，构建 Screen 10 — 单个活动节点详情（伏见稻荷大社）」，再 30 秒新帧 `有径 - 单个活动节点详情` 就冒出来了）。

**所以发送判据要补一条，和第 3 步的认帧判据配套**：Return 之后**别只信当次返回的状态**——它可能还带着 composer 的文本。等 ≥30 秒再复查两件事：① 树里 `Screen N` 的字样**还在不在**（不在 = 没发出去）；② 聊天**最后一条 user 气泡**是不是它（先按 Escape 取消选中帧，否则面板会钉在选中帧那条消息上）。终极判据仍然是 `HTML 内容 有径 - ` 条数 +1。同一条提示词重发是安全的：Stitch 每轮新建一块帧，不会污染旧帧。

导出 `stitch_youjing_v7 (18).zip` → 台账 `屏10_有径-单个活动节点详情_471fcea9`：**md5 `471fcea9597e64795dbfe98b236c5594` / 12,984 B**（v7 最小的一屏）。审计结果这一屏最干净：**四闸门 0 / 0 / 0 / 2**；**阴影 0 条 / 违规 0 条**——「这屏六条闭集一条都不需要，一条都别加」第一次被完整兑现（屏 8/9 是"用了的都合法"，这屏是"一个都不用也没乱加"）；**台账外 alpha 0 种**（本项目第一次，屏 8/9 各挂着 1 条）；**理由块左条 1 命中**——屏 9 那屏压根没有 `#EFEFF2`，第 7 条是 N/A，这屏是真的有理由面板并且把 `border-left: 2px solid #0066CC` 画出来了，**自查第 7 条第一次在"本该有"的屏上兑现**；底栏 `.bottom-action-bar` 扁平 `#FFFFFF` + `padding: 12px 16px calc(16px + env(safe-area-inset-bottom, 12px)) 16px`、滚动预留 `calc(94px + env(...))` 各一条，**第 8 条连续第三屏零违反**；全树只有顶栏一处 blur（这屏没有吸顶件，四件授权只用到一件，不多不少）；实心蓝一颗 `.btn-primary`，另两处蓝是 `.mini-route-line` 与 `.mini-node-outer.active`（中心节点，正文点名的动线件）。

**残留两条进统一清理轮**：① 4 处内联 `style=`，其中一处是 `font-size: 18px; font-weight: 600; line-height: 24px; color: #17171A;`——**站名档被写成内联而不是类**，危害不在数值在复用（下一屏改字号时它不会跟着变）。② 3 处 4px 基准越界：`gap: 6px`、`padding: 4px 10px` ×2（两枚徽章的内距）、`gap: 2px`。

**audit.sh 本轮自己坏了两条，都是"恒空 = 假绿"这一族（第 5、6 条判据 bug）**：
1. 底栏那栏原来写死 `grep '\.bottom-bar'`，而屏 10 的类叫 **`.bottom-action-bar`** → 整段抓空，`backdrop-filter` 计数恒 0，**看起来像"这屏底栏合规"，其实是判据没跑**。现在按 `\.bottom[a-zA-Z0-9_-]*` / `\.footer[a-zA-Z0-9_-]*` 前缀抓，并多打一行 **「底栏规则块抓到几段」**——它是判据的自证：为 0 就说明类名不在前缀里，别把下面的 0 当结论。
2. 实心蓝归属的 awk 只认 `.name {`，**复合选择器 `.mini-node-outer.active {` 被跳过**，于是回吐上一个类名，把「中心节点实心蓝」误报成「外圈节点实心蓝」。改成 `/^[[:space:]]*\./` 一律认作类行。复跑屏 9 两条都对上了（`.spine-line.active`、`.bottom-action-bar` 抓到 1 段）。

**图标口径补一条豁免（写进第 3 步预检第 2 项）**：状态栏模拟件（`09:41` 旁的 wifi / cloud / battery，14×14、16×12，stroke `#17171A`，类名 `.status-icon-svg`）**属机身 chrome，不吃两档图标口径**；屏 10 那三只离档 svg 全是这一类，所以这屏**内容图标零违规**。真违规是屏 8 的 `.transit-icon` 14×14 和屏 9 的 12×12 插入件——**分法看 stroke 色与所在容器，别只看尺寸**。

### 11.14 屏 11：前置块自己打架的两处洞被这屏顶出来，另加两条假绿判据（2026-10-14，`1ab099b1` 实测）

屏 11（费用视图）正文 3,740 字 + 前置块 **9,597 字**（TYPE 那行补了「display numeral」并删掉残留的 20px 图标许可，所以变长了）= **13,339 字 / 8 位 hex 0 处**。一次发送成功：Return 后 35 秒复核，`Screen 11 — 费用视图` 命中 3 次、聊天尾部出现 `Thinking…`——**11.13 那条延时复核判据第一次当场把"发出去了"和"没发出去"分开**。新帧 `有径 - 费用视图`，导出 `stitch_youjing_v7 (19).zip` → 台账 `屏11_有径-费用视图_1ab099b1`：**md5 `1ab099b1fee7b4703b5dd5e909a1f0f5` / 16,574 B**。

**这屏预检真正的收获是两处「前置块自己跟自己打架」，不是 Stitch 的错**：
1. **`32/700 sans` 在字阶上是非法的**——TYPE 里 32 档只写了 `32/700/44 serif display`，而 Fonts 那行又规定「every numeral」用 sans、自查里还留着「serif never on a numeral」的语义。费用页的 hero 就是一颗大数字，**照 serif 办违反 sans-numeral，照 sans 办违反 32 只有 serif**，两条必违其一。已在 TYPE 补：`A display numeral takes the 32/700/44 display tier in SANS … the one sanctioned non-serif use of 32px`，并写明它不给其它任何数字开宋体的口子。
2. **`an icon glyph may sit at 20px, nothing else`** 是单档图标时代的残留，和 11.11 之后 CONTROLS 的两档口径（22×22 控制 / 48×48 展示）正面矛盾——**第 4 处我写给自己看的自相残杀**，已删，改成「图标尺寸只从 CONTROLS 两档来，不在这条字阶上」。

**还有一处是我自己正文里的账目矛盾（本轮最该记的）**：原文 `预算 ¥8,000 / 人 · 共 2 人` + `已花 ¥6,420` + `4px 进度条 80%` 三者打架（8,000×2=16,000，6,420 只占 40%），四行分类求和也凑不回任何一条。费用屏的整个卖点就是「数字能对上」，这种稿子发出去等于让 Stitch 在错数字里挑一组。已整套重算并写进正文，**并且把求和关系当约束发给它**：屏 11 预算 ¥16,000 · 已花 ¥12,840（=16,000 的 80.25%）· 剩 ¥3,160，分类 `住宿 6,400 + 交通 2,800 + 餐饮 2,640 + 门票 1,000 = 12,840`，比例条以最大项归一（100/44/41/16%），记账三笔（¥500/¥400/¥1,800）逐笔不超过所属分类；11b 同步重算成 `已花 ¥16,840 / 超支 ¥840`、分类 `8,800+3,200+3,840+1,000=16,840`。**780 画板逐段列预算**（60+36+16+116+20+176+20+132+44+16+94 = **730px**，留 50px 给段间距；第一版我加成 754，发前复核算错纠正）。

审计结果：**四闸门 0 / 0 / 0 / 2**；**阴影 2 条 / 违规 0 条**，就是正文点名的两条（分段选中胶囊 `0px 0px 8px 0px rgba(0, 102, 204, 0.18)` + dock `0px 6px 16px 0px rgba(0, 0, 0, 0.09)`），hero、分类行、记账行、记一笔胶囊一条都没加；**台账外 alpha 0 种**（连续第二屏，9 种全在 DESIGN.md 透明度台账里）；**serif 一处在 CSS 里都没落地**——只有 `@font-face` 声明，正文零 `font-family: 'Noto Serif SC'` 使用，说明 **hero 那颗 32/700 是以 sans 渲染的，新加的 numeral 条款第一屏就兑现**；圆角只出现 999/30/28；**六只 svg 全由 CSS 定尺寸、全是 22×22，这是第一屏「零离档图标」**（屏 10 那三只 14/16px 是状态栏 chrome 豁免，屏 8/9 的 12–14px 是真违规）；玻璃正好三件（顶栏 24 / 分段 20 / dock 24），没有第四件；dock `bottom: calc(28px + env(safe-area-inset-bottom, 12px))`；**CSS 区里实心 `#0066CC` 只有 `.hero-progress-fill` 一条**，即这屏**零实心蓝按钮**，`记一笔` 是 outline 胶囊——正文那句「this screen has zero solid #0066CC buttons」被完整执行。

残留两条进清理轮：① **8 处内联 `style=`，但要分两类判**：4 个是比例条的 `width: 44% / 41% / 16% / 100%`——**这是数据，本来就该内联**（写死成类就没法随账目变）；另 4 个是分类点的 `background-color: #5856D6 / #3C3C43 / #9A6206 / #0066CC`——**该收进 `.cat-lodging` 之类的类**，颜色是语义不是数据。② 3 处 4px 基准越界（`10px`、`2px`、`6px`）。

**audit.sh 本轮又抓到两条假绿（第 7、8 条判据 bug），都是「恒空 = 看着像合规」这一族**：
1. 图标栏原来只查 `<svg width="…">` **属性**，屏 11 的图标全部改用 CSS 定尺寸 → 整栏输出为空，**看起来像"没有离档图标"，其实是判据没跑**。现在额外扫 `… svg { … }` 规则并打印每条的 width/height/stroke-width（复跑屏 10/9 无回归，屏 9 还顺带把 `.status-icon-svg` 14px 显式列了出来）。
2. 「实心蓝归属」原来在**剥注释全文**上跑 awk：HTML 里的内联 `style="background-color: #0066CC"` 也会被算进来，而它的 `cls` 还停在 CSS 区最后一条规则（屏 11 是 `.dock-glow`）上 → **归属全错，还会把"零实心蓝按钮"误报成"有"**。现在先 `sed -n '1,/<\/style>/p'` 切出 CSS 区，并加一行 **「CSS 区行数」自证**（为 0 = 没抓到 `</style>`，本栏判据失效）。
3. 上一轮新加的 **「底栏规则块抓到几段」第一次上岗就抓到东西**：屏 11 根本没有底栏（底部是 dock），所以那栏输出 0 段——**这个 0 是"判据没跑"而不是"合规"**，正是加它的理由。这屏要看的是 blur 列表（三件）和 dock 自己的 `bottom: calc(28px + env(...))`。

### 11.15 屏 12：第 4 处「我写的正文比契约更严」在发送前被抓出来（2026-10-14，`f037b5c4` 实测）

屏 12（我的行程列表）正文 3,444 字 + 前置块 9,597 字 = **13,043 字 / 8 位 hex 0 处**。一次发送成功（35 秒复核：`Screen 12 — 我的行程 list` 命中 3 次、尾部 `Thinking…`），新帧 `有径 - 我的行程`，导出 `stitch_youjing_v7 (20).zip` → 台账 `屏12_有径-我的行程_f037b5c4`：**md5 `f037b5c4fb085120334dbdc4813486f3` / 16,353 B**。

**这屏最该记的一条，是发送前 5 分钟抓出来的**：原正文写着「each #F7F7F8, 20px radius, 16px padding, **flat — no shadow**, separation comes from the surface ladder」。发前按「先 grep 自己的正文」的规矩回查 DESIGN.md，撞见 **`itinerary-summary-card`（569–580 行）明写 `elevation: "{elevation.card}"`**，而且这个组件把 `backgroundColor: surface-elevated` `#F7F7F8`、`titleFont: serif`、`statTypography: headline`(18/600)、`statLabelColor: muted`、`rounded: lg`(20)、`padding: 16px`、`statGap: 12px`、`numeralFeature: tnum` 全定好了——**我那句「flat 无阴影」是直接删掉契约件的一条属性**。这和 11.10 那次「box-shadow 一处都不许出现」同族，是**我写的第 4 处比契约更严的收紧条款**；照旧发出去，Stitch 无论听哪一条都会被判成坏帧。已改成正文里逐字引用闭集值 `box-shadow: 0px 3px 10px 0px rgba(0, 0, 0, 0.07)` 并标出契约行号。

**同类一起清掉的两处**：`at 72–84px each` 是个区间（＝不确定），契约里本来就有 `spacing.profile_stat_width: 72px`，钉死；「the 必去 one **in gold**」二义（`#9A6206` 必去 vs `#A06400` 需预约），钉 `#9A6206` 并把五枚节点的画法逐件写死。**还补了一处我自己漏算的几何**：正文没定卡数，而单卡实测高 236px、可滚区只有 `780 − 60 − 94 = 626px` → 明写「三张，前两张完整、第三张被 dock 净空裁掉」，并把「旅行中」「已完成」两种状态都放进完整区。

审计：**四闸门 0 / 0 / 0 / 2**；**阴影 2 条 / 违规 0 条**——`.trip-card` 吃 `card`（**翻案第一屏就兑现**）、dock 吃 `floating`，正文那句「this screen uses exactly two of the six」一字不差；**零实心蓝按钮**（CSS 区实心蓝只有 `.progress-fill`）；**内容图标零离档**（`.icon-hitbox svg` 与 `.dock-icon` 都是 22×22，唯一的 14×14 是 `.status-bar-icons svg` 状态栏 chrome，按 11.14 的豁免口径不算）；玻璃正好两件（顶栏 24 / dock 24），底栏那栏打印 **「抓到 0 段」= 这屏没有底栏**，自证行第二次上岗；圆角只有 999/30/20；字号只有 10/11/12/18/21；serif 只落地一处（21/700 的目的地名）。

**我那条「禁 opacity 表达完成态」被完整执行，而且它自己解释了那处 opacity**：第 2 张卡的注释写着 `已完成 (No progress track, No opacity reduction)`，全帧唯一的 `opacity: 0.25` 落在 **`.home-indicator`**（机身 home 条，`#17171A` 压白 25%）——**那是设备 chrome，不是可操作件**，和 11.14 状态栏图标同一族。这条如果没写，按已上线那条老毛病（可操作图标被 opacity 弱化）它很可能真把整张卡调成 25% 透明。

残留三条进清理轮：① 4 处内联 `style=`，其中 `width: 40%` 是进度条数据（**该内联**），另 3 处 `color: #69696E` 是完成态标签色，**该收进 `.trip-card--done .x` 之类的类**。② **台账外 alpha 1 条 `rgba(0, 102, 204, 0.12)`**——dock 激活态光斑的渐变起点，正文写的是 `0.10`，它自己抬了一档；`audit.sh` 已能把渐变停靠点单独列出，这条是实色停靠点不是 alpha 0，算真违规。③ 4 处 4px 基准越界（`10px`、`2px`、`3px`、`6px`）。

### 11.16 屏 13 万能卡片：卡了一整轮的发送终于通了，判据仍是「新标题」（2026-10-20）

提示词 `~/Downloads/stitch_v7_ledger/prompts/SEND_屏13.txt`（12,824 B / 12,566 字），前置块 + 正文一次贴入。**发送由用户手点完成**，成帧证据三条：

1. 画布 `有径 - ` 标题从 **13 块涨到 14 块**，且新增的那条是**从未出现过的新标题** `有径 - 万能卡片 (FormAbility widgets)`（`frameLocator('iframe')` → `locator('div').first().innerText()` 67,846 字符，正则 `有径 - [^\n]{0,40}` 计数）。
2. composer 归零回到占位符 `What would you like to change or create?`。
3. composer 上方浮出两条后续建议：「将 Widget B 扩展为深色模式（Dark 2…」「导出卡片在真实多彩动态壁纸下的对比…」——**这两条只有在跑完这屏之后才会出现**，等于 Stitch 自己复述了它做了什么。

**认帧口径再确认一次**：`getByText('有径').count()` 会给出 178 这种大数（缩略图、图层名、尺寸牌里都重复），**不能拿来数帧**；要数的是 `有径 - <标题>` 这种带连字符的完整标签，本轮 15 次命中 / 14 个不同标题，`首启与静默登录` 命中 2 次 = 屏 1 那块 fork 还在。

**待办**：屏 13 尚未导出（连接器队列被一次取消掉的跨域查询堵死，`Tool command waited too long in queue`，MCP 侧同一扩展一起超时——**教训：跨域帧上的 `getByText(..., {exact:true})` 是慢查询，别在没设 `timeoutMs` 的情况下取消它**）。屏 12b 同样只成了帧、没导出。

## 十二、统一清理轮：十屏残留的逐条清单（2026-10-14 盘点，`/tmp/residue2.py` 实测）

盘点脚本扫的是**台账里每屏当前定稿那份 `code.html`**（屏 2 = `7d2eafa8`、屏 4 = `7d6e58d6`，按目录名里的 md5 对号），剥注释后按 CSS 规则逐条判，**状态栏模拟件（`.status-icons` / `.status-bar-icons` / 24×11、22×10 那类电池信号件）一律豁免、不进清单**——口径见 11.14。

### 12.1 两条闸门级：不是数值脏，是**规则本身还错着**

1. **屏 4 的底栏根本没在 CSS 层修好。** 台账 `屏4_有径 - 景点选择_7d6e58d6` 第 345–352 行现在仍然是：
   ```
   .bottom-bar { … background-color: rgba(255, 255, 255, 0.92);
                 backdrop-filter: blur(24px); -webkit-backdrop-filter: blur(24px); }
   ```
   当时那次「底栏材质纠偏」**只在元素上挂了内联 `style="background-color: rgb(255,255,255); backdrop-filter: none"`** 把渲染盖对了，**规则原封不动**。渲染层是对的（内联优先级高），**但把这份 CSS 当规格搬到 ArkUI 就会把 0.92 半透明 + blur 一起带过去**。
   **判据升级（audit.sh 第 8 条）**：一条规则被内联盖住 ≠ 修好。凡 `grep -A9` 到底栏规则里有 `rgba(` 或 `backdrop-filter`，**即使渲染截图正常也算违规**。
2. **屏 1 的理由块是我自己写反的。** `屏1_首启与静默登录_77ed8d08` 第 291 行注释原话 `Correction 7: flat opaque #EFEFF2 with border: none (strictly NO border-left)`——那是 11.7 翻案**之前**的口径，翻案之后这块 `#EFEFF2` 面板就缺 `border-left: 2px solid #0066CC`。**注释还会误导下一轮**（裸 grep 命中过它，见 11.9），清理时必须连注释一起删。

### 12.2 数值级清单（按屏，一条一句、可直接抄进返修提示词）

| 屏 | 死规则 | 4px 基准越界（类 → 现值 → 目标） | 台账外 alpha | 该进类的内联 | 内容图标离档 |
|---|---|---|---|---|---|
| 屏1 `77ed8d08` | — | `.preview-badge 2px 8px→4px 8px` · `.stop-body padding-left 10→12` · `.stop-title-row margin-bottom 2→4` · `.transit-leg 0 10px→0 12px` · `.preview-foot 10px 12px→12px` | — | `bottom: calc(100% - 24px)` 一处 | — |
| 屏2 `7d2eafa8` | `.field-value-serif` | `.field-col gap 2→4` · `.budget-container gap 10→12` · `.budget-track-wrapper gap 6→8` | — | — | 18×18 → 22×22 |
| 屏4 `7d6e58d6` | — | `.summary-strip gap 6→8` · `.badge-booking 2px 8px→4px 8px` | **`.bottom-bar` 0.92（见 12.1）** | 底栏那条内联补丁（删掉，改规则） | — |
| 屏5 `1cd06e03` | — | `.badge-ai 3px 8px→4px 8px` · `.badge-sub 3px 8px→4px 8px` · `.commute-col gap 2→4` | — | 三处 `background-color`（`#0066CC`/`#5856D6`/`#9E9EA3` 活动点色） | 20×20 → 22×22 |
| 屏7 `a21e614c` | — | `.solution-info gap 2→4` | — | — | — |
| 屏8 `9c0acbcd` | `.dot-stay` `.dot-transit` `.dot-rest` | `.segmented-control padding 2→4` · `.booking-badge 3px 8px→4px 8px` · `.reason-block margin-top 10→12` · `.transit-content gap 6→8` · `.floating-dock 0 10px→0 12px` · `.dock-icon margin-bottom 3→4` | — | 两处 `stroke: #3C3C43; margin-bottom: 0`（dock 图标内联补丁，**同组被劈成两种渲染**） | `.transit-icon` 14×14 → 删掉该象形件（正文从没要过） |
| 屏9 `ebe57eac` | `.dot-stay` | `.time-col padding-top 14→16` · `.spine-node margin-top 10→12` · `.stop-title-row gap 6→8` · `.booking-badge 3px 8px→4px 8px` · `.stop-meta margin-top 2→4` | `.insertion-badge border rgba(0,102,204,0.20)` → `1px solid #0066CC`（徽章法） | 5 处（虚线/点色/字色/描边） | 14×14、12×12 → 22×22 |
| 屏10 `471fcea9` | — | `.media-column gap 6→8` · `.header-meta padding-top 2→4` · `.badge-pill-bookmark 4px 10px→4px 12px` · `.badge-pill-warning 4px 10px→4px 12px` · `.hours-row gap 2→4` · `.reason-block gap 6→8` | — | 3 处（含把**站名档 `18/600` 写成内联**那条） | — |
| 屏11 `1ab099b1` | — | `.segmented-control padding 2→4` · `.record-btn gap 6→8` · `.floating-dock 0 10px→0 12px` | — | 4 处分类点色（**4 个 `width: %` 保留——那是数据，本来就该内联**） | — |
| 屏12 `f037b5c4` | — | `.stat-col gap 2→4` · `.stat-num-wrap gap 6→8` · `.booking-badge 2px 6px→4px 8px` · `.card-footer gap 6→8` | `.dock-glow rgba(0,102,204,0.12)` → `0.10`（正文写的就是 0.10） | 3 处 `color: #69696E` → 收进 `.trip-card--done` | — |

**三条贯穿性的根因，不是一条条孤例**：① **活动类型点色被内联 paint**（屏 5/8/9 共 8 处 + 5 条 `.dot-*` 死规则）——Stitch 声明了 token 类却不用，改在元素上写死；**一条指令统一修**：「`.dot-sight/.dot-food/.dot-lodging/.dot-transit/.dot-rest` 五个类必须存在且被 HTML 引用，点色一律走类，不许内联」。② **`padding: 3px 8px` 徽章内距**在屏 5/8/9/12 各出现一次 → 定一条「徽章内距只许 `4px 8px` 或 `4px 12px`」。③ **dock / segmented 的 `padding: 0 10px`、`padding: 2px`** 在屏 8/11 重复 → 同一条修复话术两屏共用。

### 12.3 发送方式（每屏一条，一条一帧）

**必须一屏一条**：前置块没有常驻框（第 2 步实测），且 Stitch 每条只改它选中的那块帧。每条 = **前置块 9,889 字（屏 13-16 预检时把 sheets 从玻璃清单里改掉了，见 12.6） + 该屏的残留清单**，正文一律以 `Apply ONLY the listed changes to this frame; every other declaration must stay byte-identical (zero drift).` 收尾——**屏 2 那次就地修正的逐行 diff 只有 1 处变化，就是这句话换来的**。

顺序建议：**先屏 4 与屏 1（闸门级），再屏 8/9（死规则 + 内联最多），最后屏 2/5/7/10/11/12**。每屏发完照第 4 步认帧 + 导出 + `audit.sh`，**台账目录按新 md5 新建、旧目录保留**（清理轮会把每屏 md5 换掉，旧值是唯一的历史凭据）。

### 12.4 用**现在的** `audit.sh` 把 12 屏定稿件全部重跑一遍（清理前的真凭据）

屏 1–8 当年是用**旧版** `audit.sh` 判的，而旧版有 6 条判据 bug（注释误判、`box-shadow: none`、字符串白名单比 alpha、awk 不认 `\s`、底栏类名写死、复合选择器、CSS 定尺寸 svg 查不到、HTML 内联污染归属）。**旧结论不能直接继承**，2026-10-14 全部重跑：

| 屏 | 四闸门 | 阴影违规 | 台账外 alpha | 4px 越界值 | 第 7 条左条 | 第 8 条底栏 |
|---|---|---|---|---|---|---|
| 屏1 `77ed8d08` | 0/0/0 ✓ | 0 | 0 | 3 | **0（应有，真受损）** | 0 |
| 屏2 `7d2eafa8` | ✓ | 0 | 0 | 3 | N/A（无 `#EFEFF2`） | 0 |
| 屏3 `b6b3126b` | ✓ | 0 | 0 | 2 | N/A | 0 |
| 屏4 `7d6e58d6` | ✓ | 0 | **1** | 2 | **0（应有，真受损）** | **2 + 「规则未修、被内联盖住」** |
| 屏5 `1cd06e03` | ✓ | 0 | **5** | 3 | 1 ✓ | 0 |
| 屏6 `35c7d3b4` | ✓ | 0 | 0 | 1 | N/A | 0 |
| 屏7 `a21e614c` | ✓ | 0 | 0 | 2 | 1 ✓ | 0 |
| 屏8 `9c0acbcd` | ✓ | 0 | 0 | 4 | 1 ✓ | 0 |
| 屏9 `ebe57eac` | ✓ | 0 | **1** | 2 | N/A（无 `#EFEFF2`） | 0 |
| 屏10 `471fcea9` | ✓ | 0 | 0 | 3 | 1 ✓ | 0 |
| 屏11 `1ab099b1` | ✓ | 0 | 0 | 3 | N/A | 0 |
| 屏12 `f037b5c4` | ✓ | 0 | **1** | 4 | N/A | 0 |

**重跑换来两条新事实**：① **屏 4 的底栏从来没在 CSS 层修好**（旧版判据抓不到，见 12.1）；② 屏 1 与 屏 4 的**理由块左条**在今天的判据下确认缺失（当年是「我明令禁止」，见 11.7）。其余十屏的四闸门、阴影闭集、第 8 条都仍然成立——**没有一屏因为判据升级而翻成坏帧**。

### 12.5 十条返修提示词已生成，可直接粘

生成器：`bash ~/Downloads/stitch_v7_ledger/cleanup_gen.sh` → 产物 `/tmp/cleanup/屏N_<定稿md5>.txt` 十条，每条 = **前置块 9,597 字（已逐字节对回本文件，`want=9597 got=9597 equal=true`）+ 该屏残留清单**，全部 **8 位 hex 0 处**，长度 10,080–10,631 字。每条正文都以同一句锁死漂移：`Apply ONLY the listed changes to this frame; every other declaration must stay byte-identical (zero drift).`，并写明**状态栏模拟件豁免、不许增删阴影**。

发送顺序（先闸门级、再内联最多、最后纯数值）：**屏4 → 屏1 → 屏8 → 屏9 → 屏5 → 屏10 → 屏12 → 屏11 → 屏2 → 屏7**。每屏发完照第 4 步认帧 + 导出 + `audit.sh`，**台账按新 md5 新建目录、旧目录保留**（清理轮会把定稿 md5 换掉，旧值是唯一的历史凭据）。

### 12.6 屏 13–16 + 3b/11b 六条的发送前预检收获（2026-10-14，全部未发）

六条正文全部重写并过了机器校验（`node /tmp/gen_send.js` → `/tmp/cleanup/SEND_屏N.txt`，每条 = 前置块 9,889 字 + 正文 1,902–3,012 字，**阴影只出现闭集字面量、字阶只出现 10/11/12/14/16/18/21/32、圆角只出现八档、无 8 位 hex、无 `Frame A/B` 字样、每条都带 `env(safe-area-inset-bottom)`**）。预检挖出来的东西比清单本身重要：

1. **前置块第 5 处过严条款：把 sheets 算进了玻璃。** 原句「Glass/blur on exactly four surfaces — top bar, floating dock, sticky day header, **sheets**」，而 DESIGN.md `sheet-modal`（367 行）与 Sheet 组件注（1092 行）写的是**实色 `surface-elevated` + `elevation.floating` + 一层遮罩**，**没有 blur**。屏 14 就是抽屉屏，照旧发出去我会得到一张半透明模糊抽屉、然后被自己的判据判成违规。已把玻璃改成**三件**，并在屏 14 正文里写死「zero `backdrop-filter` on it」。
2. **契约缺 scrim token**：1092 行说 "scrim behind" 却没给值。已新增 `modal-scrim rgba(23, 23, 26, 0.32)`（ArkTS `52 17 17 1A`）进 colors 与透明度台账——**这是本轮唯一一次我往契约里加值，需要你追认**。
3. **变体屏的通病：跨帧引用等于没写。** 屏 3b 原稿「same chrome and footer law as screen 3」、屏 11b 原稿「same hero / same dock as screen 11」——**Stitch 看不见另一块帧的 CSS**，材质、圆角、阴影、内距必须就地重述。两条变体都已改成自带完整配方，只让数字不同。
4. **屏 13 的 `Frame A` / `Frame B`** 与前置块 `no frame labels like "Frame 1"` 当面对撞（第 5 处正文 vs 前置块），改成 `Widget A/B/C`；同屏的 `photo wallpaper` 违反「无摄影预算」且必然带进台账外色相，改成契约面 `#E9E9EC` 中灰底——**这屏要证的正是「实色面 + 1px 发丝边在任意壁纸上站得住」（DESIGN.md 1053 行）**。
5. **屏 15 三处**：`serif 岚山竹林` 是站名（自查第 1 条要 sans），保留 hero 的页面地名档并锁死「往下每站回 18/600 sans」；`✓` 是文本字符，改 22×22 SVG 勾 + `已确认 #1C7440`；hero 要 `card` 阴影与屏 11 的「hero 一条都不加」跨屏打架，统一成无阴影。
6. **屏 3b 的 `20px #0066CC check` 造了第三档图标**（两档口径之后第 5 处同类自伤）→ 22×22。屏 16 补了整段缺失的底栏材质 + 「结果页无 dock」（否则玻璃面数超标）。屏 14 的开关按 DESIGN.md 无契约件处理：轨道 44×24、ON `#0066CC`、OFF `#E5E5EA`，并**明写开关不算主 CTA**，否则两个 ON 开关会被「一屏一颗实心蓝」误杀；同时修了它自己那句「destructive-by-default 不许预选」与 `日历同步 ON` 的矛盾——**写入类的日历与提醒一律 OFF，只展示的行程卡片 ON**。

**对比度全部 python3 独立复算**：`#A06400` 压 `#F7F7F8` **4.54**（屏 3b 警告行，勉强过 AA，所以必须钉死底色）、`#69696E` 压 `#E9E9EC` 4.51、`#17171A` 压 `#F7F7F8` 16.71、白字压 `#1E1E1E` 16.67、`#E9E9EC` 压 `#1E1E1E` 13.76、`#0A84FF` 压 `#1E1E1E` 4.57、`#1C7440` 压白 5.80、`#C0392B` 压 `#F7F7F8` 5.08、`#9A6206` 压 `#F7F7F8` 4.76。

### 12.7 用 Qoder Browser Connector 驱动 Stitch：读得到，写不进去（2026-10-20 实测，别再试第二遍）

Computer Use 的 SDK 在这次 Qoder 升级后解析不到（`@qoder-space/computer-use-sdk` 已进 `app.asar`，`Resources` 下无 `node_modules`，`computerUseMacOS/` 只剩 `skills`），于是改试浏览器连接器。**读完全通，写全部被拦**：

**通的部分**：`createBrowserAgent()` → `browsers.list()` 出现 Chrome（extension 1.7.6）→ `user.openTabs()` 按 URL 精确匹配 → `claimTab`。关键一手是 **`tab.playwright.frameLocator('iframe')`**：Stitch 整个应用跑在跨域 iframe（`app-companion-430619.appspot.com`）里，所以顶层 `domSnapshot()` 只有 54,611 字符的脚本壳、`getByRole('button').count()` 恒 0、`ax.get('state')` 只有 7 个空节点、`dom_cua.get_visible_dom()` 也只剩 7 个空 ref——**不套 frameLocator 会误判成"页面没渲染"**。套上之后：32 个按钮、1 个 Export、`body.innerText` 66,527 字符、13 块帧标题全在。

**不通的部分（四条全试过，都是硬边界，不要绕）**：
1. `locator.press('Enter')` → `BROWSER_AUTH_REQUIRED: Sensitive field <整段提示词>`。连接器把长文本 + 十六进制色值判成敏感字段。
2. `locator.pressSequentially('Widget')` → 同一道闸门。**只要字段里已有这段文本，任何真实按键写入都被拒**。
3. ~~`locator.fill(text)` 不报错、但 React 状态没同步，发出去的是空消息~~ —— **这条判错了，2026-10-20 已推翻**。`fill()` 写进去的 12,565 字**是真的可发送内容**：用户手点一次发送按钮后，composer 归零、画布冒出全新标题 `有径 - 万能卡片 (FormAbility widgets)`、composer 上方还浮出两条只会在**跑完这屏**之后才有的后续建议（「将 Widget B 扩展为深色模式」「导出卡片在真实多彩动态壁纸下的对比」）。我当时看到的「composer 归零却没有新帧」是**另一回事**：`ax.pressKey('Enter')` 自己把 DOM 清了，但按键进不了跨域帧，所以那一次确实没发出去。**边界在"点哪个控件"，不在"写框"**——我用 `b107.nth(28)` 点的那个 `shrink-0 w-6 h-6` 根本不是发送键（composer 右下角的 `↑` 才是），点下去 `Thinking…`/`Saving updates` 恒 0、帧数不动，被我误读成"写进去的内容无效"。
4. `clipboard.writeText` 成功（读回 12,566 字符），但合成的 `Meta+v` 不触发浏览器粘贴（Chrome 只认真实快捷键）。

**修正后的结论**：**写框是通的，被拦的只有"真实按键"和"发错控件"**。下一条要验的只有一件事——用 frameLocator 精确命中 composer 右下角那个 `↑` 发送键（截图可见它在 `Balanced` 与麦克风图标右侧），点一次看帧数是否 +1。若通，剩下 5 条新屏 + 10 条返修全部可以程序化发；若不通，才回到"人手两键"。**这次别再从"点不动"推"写不进"**——两者是独立变量，我把它们混成一个结论了一次。

**顺手记两条判据 bug（同一族：恒真/恒假信号）**：① `busy` 用 `/Thinking|Generating Screen|Saving/` 判**永远为真**——那两块死帧的标签里就带 `Generating Screen`，必须改判 `Thinking…` 与 `Saving updates` 这两个精确串；② 聊天里 `Hard constraints for every frame` 命中 1 次**不代表发出去了**——每条提示词都以这句开头，上一屏的折叠气泡就是那 1 次，要判**该屏独有的正文串**（屏 13 是 `Widget A` / `launcher field`）。

### 12.8 连接器能把 Export 点开，但**选不中帧**（2026-10-20，五种点法全试完）

Export 侧栏本身可以程序化点开（`flF.locator('button')` 里现取文本为 `Export` 的那个，本轮索引 4），点开后面板实时显示 `No screens selected`。**卡点只在"选中画布上那一帧"**，五种点法全部无效：

| 点法 | 结果 |
|---|---|
| 点帧标题叶子文本（`getByText('FormAbility widgets')` 里取 `trim() === '有径 - 万能卡片 (FormAbility widgets)'` 的那个，本轮索引 23） | 侧栏仍 `No screens selected` |
| 点帧主体 `locator('iframe').nth(14)` | 同上；iframe 自带 `pointer-events: none`，事件落到父级也没触发选中 |
| 同上 + `delay: 200`（怀疑画布把极快 down/up 当拖拽） | 同上 |
| 点标题后直接点 Export（第一次） | **侧栏根本没开**——说明画布当时处于"无选中且未打开面板"，与后面"面板开着但空"是两种状态 |
| `locator('xpath=ancestor::div[k]')` 逐层祖先 | 该连接器的 selector 引擎**不认 `xpath=` 前缀**，八层全部 `Failed to execute 'querySelectorAll'` |

**两条副产物判据（留着有用）**：① 侧栏 `Format` / `.zip` / `Figma` / `Code to Clipboard` 命中数 > 0 **才代表真选中**，画布高亮和尺寸牌都不可靠（本轮全程 `NNN x NNN` 尺寸牌为 0 命中）；② 画布是**虚拟化**的——`locator('iframe').count()` 会在 15/16 之间跳，屏 1 那帧两次枚举间就掉出过渲染，**按索引取帧前必须现取现用，不能缓存上一次的索引**。

**srcdoc 还原路线：已证伪，别再走。** 每帧的 `srcdoc` 确实带完整 HTML（165K–192K 字符），切除 `<style data-stitch-injected>` / `<script data-stitch-injected>` / `<div id="stitch-agent-cursor" data-stitch-injected>` 后，**屏 12 / 屏 10 / 屏 3 / 屏 7 四帧能还原成与台账导出件逐字节相同的文件**（md5 `f037b5c4` / `471fcea9` / `b6b3126b` / `a21e614c` 全部命中）——但其余帧还多出 `<style data-stitch-css-vh="…">`（开标签跨行）、以及 `data-stitch-added-classes`、`data-stitch-orig-opacity`、`data-stitch-swappable` 等**直接改写正文属性**的注入，12/16 还原不出。台账件必须继续用真导出件。

**还发现一条可能的正路**：Stitch 有官方 MCP（`stitch.withgoogle.com/docs/mcp/setup`，OAuth scope 是 `googleapis.com/auth/flexible-api`），若能用它按 screenId 直接取源码，导出这一步就彻底不用点画布了。屏 13 那帧的 `screenId` 已在注入配置里露出：`window.__STITCH_CONFIG__={"screenId":"0b21cc578c5b4696bfdd76238e2d37a7", …}`。

### 12.9 导出全流程已经能自动化（2026-10-20 屏 13 实测跑通，六步照做）

**先说结论：Playwright 的 `locator.click()` 在这条路上只能干两件事——点工具栏按钮、点面板里的格式行；选中画布帧和点最终确认键都必须换成 `cua.click` 的真实输入事件。**

1. **每轮重新认领标签**。`browsers.getForUrl(项目URL)` → `user.openTabs()` → `user.claimTab(id)`。跨轮复用上一轮的 tab 句柄会直接 `TAB_NOT_OWNED: Tab … is not owned by this Turn`。
2. **选中帧 = `tab.cua.click({x, y})`**，坐标换算 **CSS px = 截图显示 px × 1.527**（截图回传 2932×1588 设备像素，CSS 视口 1466×794，dpr=2）。本轮点屏 12b 帧心 (554, 198) 一次命中。**画布帧的三种 Playwright 点法全部无效**（见 12.8 表），别再试。
3. **开面板**：`fl.locator('button').allTextContents()` 里现取文本为 `Export` 的**第一个**（工具栏那颗，本轮索引 8）。索引每轮漂移，绝不复用。
4. **选格式**：`fl.getByText('.zip')` 命中 **21 个**，**必须挑 trim 后最短的那个**（本轮索引 19，长度 4 字符）。`.first()` 是那个 84,813 字符的外层容器、盖住整片画布，点它等于点空白，**会把刚选中的帧清掉**（我踩过一次，面板直接回到 `No screens selected`）。
5. **按确认**：`tab.cua.click({x: 1221, y: 700})`（面板底部那颗 Export）。**Playwright 点它不触发下载**——我连点两次、含 `delay:120`，全部无文件落盘。
6. **落盘**：`~/Downloads/stitch_youjing_v7 (N).zip`。中途会以 `未确认 NNNNNN.crdownload` 停留（屏 13 那次约 1 分钟自行落定；屏 12b 那次卡住不动、需要人在 Edge 下载条上点「保留」）。**判完成只认文件名从 `未确认 *.crdownload` 变成 `*.zip`，别按秒数猜。**

**认帧口径不变**：解包后 `grep -o '<title>[^<]*</title>' code.html` + `md5 -q`。屏 13 = `<title>有径 - 万能卡片 (FormAbility widgets)</title>` / `7fc1cb85` / 13,790 B / `screen.png` 2560×1560。

**顺手破一条旧误判**：`screen.png` 是 **2560×1560（= 1280×780 CSS）而不是手机竖幅**，我一度以为屏 13 的画板跑偏了。逐屏量下来 **屏 2 / 5 / 6 / 8 / 9 / 11 / 13 七屏全是 2560×1560**，屏 3 / 7 / 8' / 10 / 12 是 2560×1682，屏 4 是 2560×1600，**只有屏 1 是 780×1560 真竖幅**。也就是说 Stitch 导出的图本来就带一大圈画布留白，**帧尺寸牌 `1280 x 780` 不是"旧帧"判据**——12.8 之前那句「`1280 x 780` = 旧帧、`390 x 780` = 新帧」作废，认新旧只能靠 `<title>` + md5。

### 12.10 「画布整片空了」的第一判据是控制台地理闸门，不是删除（2026-10-20 实测）

屏 13 / 12b 导出完成后，我按 12.9 的配方试自动发送屏 14：`fill()` 写满 → 补一个真实 `.` + `Backspace` 让编辑器同步 → `cua.click` 点发送键。composer 归零，**但紧接着画布 0 帧、Export 面板 `No screens selected`、reload 超时**。当时最容易下的结论是「帧被我删了」，实际原文是：

```
Error: User is not enabled for Stitch
(CAN_ACCESS_STITCH=true, isStitchEnabledInCountry=false, IS_INTERNAL_TESTER=false)
```

**读法**：`CAN_ACCESS_STITCH=true` = 账号本身有权限；挂的是 **`isStitchEnabledInCountry=false`** = 出口 IP 被判在不支持的地区。所以这是**会话级地理拒绝**，服务端根本不吐 screens，画布自然空。

**三条旁证，下次照这个顺序查，五分钟定性**：
1. **首页给不给项目列表**。这次首页只回欢迎页（`frameLocator('iframe')` 读到 639 字符、零项目卡）——**账号级**症状，不是单个项目被清空。
2. **聊天历史在不在**。屏 13 那段 Pre-Emit 自检文字仍完整可读 → 前端会话数据没被动过。
3. **当天更早有没有 `ERR_CONNECTION_CLOSED` / 生成卡住 / reload 超时**。这次一整天都在抖，属于同一条网络路径。

**取原文的入口**：`tab.dev.logs()` 返回 48,082 字符的 console 快照，`indexOf('User is not enabled')` 直接定位。这条比截图快，也比「猜」硬。

**由此作废两条我刚才下过的结论**：① 12.9 第 5 步的发送键点法**未经证实**——归零可能只是本地清空，请求被服务端挡了；网络恢复后必须用「`有径 - ` 标题数 +1 且冒新标题」复验，通过才算。② 「`fill()` 写的内容是真的可发送」这条也**跟着一起回到未证实**，屏 13 那次成功也可能依赖用户手点时的真实焦点/输入序列。

**本地零损失**：台账 17 个目录 = 屏 1–13 + 屏 12b 共 14 帧，`~/Downloads/stitch_youjing_v7*.zip` 23 个。**恢复动作在人手上**（切回支持地区再刷新），我不碰 VPN 与系统网络设置。

### 12.11 间距判据以前是手写的，现在从契约解析（2026-10-20 修，附全 14 帧复跑结果）

**旧判据有两处错，方向相反**：`audit.sh` 里那条白名单是硬编码的 `0|4|8|12|16|20|24|32|40|44|48|52|56|60|64|72|76|80|88|94|…`。① **漏了 `36`（`segmented-control-height`）和 `300`（`floating-dock-width`）两个真 token** → 谁用了就报假违规；② **收了我自算的 `94 / 52 / 76`** → 真离表也看不见。一假红一假绿，判据本身比被审的帧更不可信。

**现在改成运行时解析 DESIGN.md**：取根级 `spacing:` 块全部值，`layout:` 块**只收键名含 `gap|padding|margin|inset|reserve|baseline` 的**——因为 `layout:` 里同时躺着 `question-progress-dot: "6px"`、`itinerary-node-dot: "10px"`、`tab_item_height: "50px"` 这类**圆点直径与控件高宽**，全量并进来等于没判。收窄后白名单 12 值：`0 4 8 12 16 18 20 24 28 32 48 94`。

**复跑 14 帧，无一帧全绿**，但必须分成两类，混在一起就会去追错东西：

| 帧 | 微间距（真 sloppy，该落 4/8/12） | 屏专属大值（**契约缺口**，不是模型的错） |
|---|---|---|
| 屏1 | 2×3 6×1 10×4 | 64（`margin-left`） |
| 屏2 | 2×1 6×2 10×1 | — |
| 屏3 | 2×1 6×1 | — |
| 屏4 | 2×1 6×2 | — |
| 屏5 | 2×1 3×2 6×1 | — |
| 屏6 | 6×2 | 104（`padding-top`） |
| 屏7 | 2×1 6×1 | 104、180（`padding-bottom: calc(180px + env(…))` 滚动预留） |
| 屏8 | 2×1 3×2 6×1 10×2 | 138（`padding-top`） |
| 屏9 | 2×1 3×2 6×3 10×1 14×1 | 104 |
| 屏10 | 2×2 6×3 10×3 | — |
| 屏11 | 2×2 6×2 10×1 | — |
| 屏12 | 2×2 3×1 6×5 10×1 | — |
| 屏12b | 2×1 6×1 10×1 | — |
| 屏13 | 2×5 6×3 10×1 | — |

**结论两条**：① `2px / 3px / 6px / 10px / 14px` 这五个微值是真缺陷，**清理轮要统一并到 4/8/12**，涉及全部 14 帧、约 60 处；② `64 / 104 / 138 / 180` 是**契约少了一层**——`spacing` 只给了通用阶梯，没有「屏专属滚动预留 / 缩进」这一类命名位。定稿前要么给它们补命名 token（`scroll-reserve--blocking-card: 180px` 这种），要么在契约里明写「滚动预留允许离表、但必须写成 `calc(Npx + env(...))` 且每屏点名」。**这条进待拍板清单，现在是第 6 项。**

**顺带撤回**：13.2 第 3 条（屏13 的 28px）作废——`layout:` 第 233 行 `floating-dock-bottom-margin: "28px"` 就是契约件。**我把它判成自己的第 6 次正文违约，是判据错、不是正文错。**

## 十三、屏 13 万能卡片：首生审计（2026-10-20，`7fc1cb85`）

### 13.1 四闸门与阴影：全过

`tailwind.config=` / 8 位 hex / M3 token 名 三条 **0**，`safe-area-inset-bottom` **1**。阴影 **0 条声明 / 0 条违规**——这屏的正文规则就是「六种闭环阴影使用计数严格为 0」，裸 grep 那 1 次命中在注释里（`box-shadow` 字样出现在「全屏无任何 box-shadow」这句说明中），**又一次证明为什么所有判据都要先剥注释**。实心蓝 CSS 区只有 `.route-line` 与 `.route-node.current`，正是提示词点名的两个例外（动线连线 + 当前站点圆球，都不是按钮）。

### 13.2 真缺陷四条

1. **`border-radius: 12px`（L268 `.dock-app-icon-slot`）不在圆角闭集**。允许的是 0/6/10/14/20/28/30/999，12 是模型自己造的，应并到 10 或 14。
2. **间距离 token 三处**：`gap: 10px`（L70）、`gap: 6px`（L117、L137）、`margin-bottom: 2px`（L104）。
3. **⚠ 撤回：`calc(28px + env(safe-area-inset-bottom, 12px))` 不是缺陷。** 我一度把它算成「我自己写进正文的第 6 次契约违反」，**错了**——DESIGN.md `layout:` 块第 233 行就有 `floating-dock-bottom-margin: "28px"`，28px 是契约件。这条连同下面 12.11 的成因一起记：**判据没对齐契约时，先把人判成罪人。**
4. **35 处内联 `style=`**，其中语义底色全部内联：`background-color: #0066CC` / `#9A6206` / `#5856D6` / `#0A84FF` / `#7D7AFF`，文字色 `#17171A` / `#5A5A60` / `#69696E` / `#E9E9EC` / `#FFFFFF` 也大量内联。该收进 `.widget-tag-label--dark`、`.dot--stay` 这类类名。

### 13.3 合规项（逐条留证，别当"没查"）

字号只出现 10/11/12/14/21，全在梯内；serif 唯一一处 `.serif-title` = 21/700/28，符合「serif 只做 32/700 与 21/700、永不上控件」；圆角其余是 999×3 / 30 / 20；台账外 alpha **0 种**、渐变停靠点 0 种；底栏规则块 **抓到 0 段** = 本屏没有底栏（只有 launcher dock），自证行第三次上岗；图标 5 枚 22×22 全在控制档，另 2 枚 14×14 是 L289/L290 的 wifi 与电池（`stroke="#17171A"`、状态栏容器内）= 机身 chrome，按 11.14 豁免；`.dock-app-icon-slot` 44×44 满足最小命中区。

### 13.4 一条要你拍板：帧内的 `Widget A/B/C` 标注算不算有意义文字

`#8A8A91` **是契约件**（DESIGN.md L52 `dark-faint`），但同文件 L750 明写它 **2.67:1 FAIL — 只许装饰/禁用，绝不承载有意义文字**。本帧它落在 L370 那行 `font-size: 10px; font-weight: 600; color: #8A8A91`，内容是 **`Widget C · 2×2 (Dark)`**——**这是我为了让你分清三张卡片而点名要求的标注**（提示词 L49「the three widget instances are labelled Widget A / Widget B / Widget C」）。所以问题不是模型违规，是**设计稿里要不要保留给人看的元标注**：保留 → 它是有意义文字，`dark-faint` 用错了档，得换 `#E9E9EC` 或 `dark` 梯里过 4.5 的值；不保留 → 整行删掉，Widget A/B/C 靠台账目录名区分。

## 十四、屏 12b 我的行程空状态：首生审计（2026-10-20，`7991fe5b`）

`code.html` 10,096 B / `screen.png` 137,355 B。台账目录 `屏12b_有径-我的行程空状态_7991fe5b`。

**四闸门 0 / 0 / 0 / 3**（`safe-area-inset-bottom` 出现 3 次）。**阴影 1 条声明 / 违规 0 条**：唯一一条是 dock 的 `0px 6px 16px 0px rgba(0, 0, 0, 0.09)` = `elevation.floating`，一字不差。**内联 `style=` 0 处**——14 帧里第一个零内联的。

**这屏是展示档图标的第一次正确落地**：`.empty-icon-box` 48×48、`viewBox="0 0 24 24"`、`stroke="#69696E"`、`stroke-width="2"`，注释还自证「48×48 display glyph: viewBox 24, stroke-width 2, stroke #69696E, fill none」。**描边不随 48 放大**这条守住了，颜色也是 11.14 之后定下的 `muted` 而不是早先写错的 `faint`。

其余逐条：字号只有 10/14/16/18/21；serif 唯一一处 21/700/32 `#17171A`；圆角只有 20×2 / 30 / 999；台账外 alpha 0 种；玻璃正好两处（顶栏 + dock 各 `rgba(255,255,255,0.44)` + `blur(24px)`，dock 300×64、圆角 30，全对 `floating-dock-width` / `tab-bar-height`）；底栏规则块抓到 0 段 = 本屏无底栏；主 CTA `.primary-btn` 44 高、`#0066CC`/`#0055BB`，是 CSS 区唯一实心蓝。

**残留两条**：① 微间距离表三处 —— `margin-bottom: 2px`、`gap: 6px`（L63）、`padding: 0 10px`（L216），按 12.11 收窄后的 `spacing` 白名单（`0 4 8 12 16 18 20 24 28 32 48 94`）应并到 4 / 8 / 12；② `.primary-btn:active` 在 `#0055BB` + `scale(0.97)` 之外**又叠了一层 `opacity: 0.92`**——按下态已经有专属 token 了，这层 opacity 是多余的，而且它压的就是「可操作件不许用 opacity 表达状态」那条已上线老毛病，进清理轮。

### 12.12 srcdoc 还原路线正式判死（2026-10-20，两轮各 16 份实测）

第一轮只切 `<style data-stitch-injected>` / `<script data-stitch-injected>` / `#stitch-agent-cursor`，**4/16 逐字节命中**（屏 12 / 10 / 3 / 7）。第二轮把标记补全（加 `<style data-stitch-css-vh`、以及剥掉全部 `data-stitch-*` 运行时属性），**仍然 4/16**——一个都没多救回来，说明差异不在标记块，而在**运行时改写的正文本身**（`data-stitch-added-classes` 给 `body` 追加的类、`data-stitch-orig-opacity` 记的原值等），这些没有可逆规则。**结论：台账件只能来自真 Export。别再花第三轮。**

顺带记一条**契约级发现（比这条死胡同重要得多）**：DESIGN.md L1053 原文是「blur，且只出现在四处」，组件表也确认是 `top-bar-immersive`(L345) / `segmented-control`(L353) / `floating-dock`(L366) / `day-header`(L469) 四件。**我上一轮把前置块 CONTROLS 的玻璃条从"五处"改成"三处"时，把分段控件一起删了**——而同一份文档 L1088 那条底栏条款的括号里又列着五件（还错把 sheet 算成玻璃面）。三处、四处、五处在一个文件里并存。已改成：**四处，且一律 `blur(24px)`（`layout.glass-blur`）**；同时把屏 8 / 屏 11 / 屏 11b 正文里的 `backdrop blur(20px)` 三处改成 24——**实测全 18 帧里只有这三帧的 `.segmented-control` 是 20，其余全 24，值错完全来自我的正文，不是模型漂移**。这三帧进返修清单。

### 12.13 选中态只能靠真实鼠标坐标，且**没有任何 DOM 信号能证明选中了谁**（2026-10-21，四次废包换来的）

发完屏 14/15/16/3b 之后要导出，我在这一步连吃四次同一个坑，落盘的 `(24)(25)(26)(27).zip` **全是屏 12 `有径 - 我的行程` / md5 `f037b5c4`**——一个都没导对。三条硬事实：

1. **`locator.click()` 选不动画布帧。** 无论按索引 `iframe.nth(14)` 还是按内容 `iframe[srcdoc*="持久化与系统触达"]`，Playwright 都返回成功、面板也确实出现 `Format`，但选中态**一直停在最早那次 `cua.click` 选中的屏 12 上**。原因大概是 Playwright 会先把目标滚进视野，而画布是虚拟化的（Zoom to Fit 时 17 帧齐渲、平时只渲 1 帧），滚动即重排。**所以"点成功了"和"选对了"是两件事。**
2. **composer 上方那颗 `有径 - <屏名>` 按钮不是选中指示，是上一次发送留下的 context chip**，选中态变了它也不变。我拿它当校验，写了 `exportVerified()` 四重试，结果四次都被它骗成"未选中目标"——**判据本身是假的，重试次数再多也没用**。
3. **`Zoom to Selection` 也反查不出来**：`getByText('Zoom to Selection')` 命中 7 个（菜单项的嵌套 span），`.last()` 点下去视图没收窄，17 帧照旧全渲。

**目前唯一可靠的选中信号 = 导出包的 `<title>` + md5**，也就是说每验一次要付一次导出（约 40 秒）。**已确认可用的选中手段只有一个：`tab.cua.click({x, y})` 打在帧的内容区上**——屏 13 (554,198)、屏 12b、屏 11b (878,305) 三次都是这么成的。**下一步要么给人手点三下，要么先解决"怎么把目标帧的屏幕坐标算出来"，别再拿 `locator.click()` 试第五遍。**

### 12.14 **多选批量导出**把 12.13 的死结解开了（2026-10-21 实测，一包装四帧）

12.13 卡在「算不出目标帧的屏幕坐标」。解法不是算坐标，而是**换选中方式**：人按住 `⇧ Shift` 依次点 N 块帧的手机画面（真实鼠标事件，一次点一块），我这边只负责 `Format` 出现后点 `.zip`（取 trim 最短的那个节点）+ `cua.click({x:1221,y:700})` 确认。**一次导出，N 帧全进同一个 zip**：

```
stitch_youjing_v7 (24).zip  595,889 B
└── stitch_youjing_v7/
    ├── _1/  code.html + screen.png   有径 - 持久化与系统触达   d04983a4   9,463 B
    ├── _2/  code.html + screen.png   有径 - 旅行中模式         fc4e40cd  16,508 B
    ├── _3/  code.html + screen.png   有径 - 分享与导出         074108e2  13,681 B
    └── _4/  code.html + screen.png   有径 - 偏好追问（多选变体）480d5d03   7,361 B
```

**子目录名是 `_1…_N`，不含屏名**——所以认帧仍然只能逐个解出 `code.html` 读 `<title>` + md5，跟单屏包一个规矩。屏数越多包越大，四帧 595 KB（单帧约 150–210 KB）。

**这条改写了 12.9 的第 2 步**：不再需要"我算坐标点一帧"，改成"人 shift 点 N 帧 → 我一次导完"。**剩下 14 条返修也照这个走**：每轮把该轮生成的新帧一起 shift 选中，一次导出，再按 md5 分箱进台账。

### 12.15 19 帧齐了：四帧新审计小结（2026-10-21）

四帧**四闸门全过**（`0/0/0/2`），阴影声明 0–1 条、**违规 0 条**，字号全在 `10/11/12/14/16/18/21/32` 梯内，图标全在 22×22 控制档（屏15 `.check-glyph`/`.dock-icon`、屏3b `.check-icon`、屏16 `.icon-btn-44`/`.option-icon-box` 是 44×44 命中盒）。**内联 style 少得意外地好**：屏3b **0 处**、屏14 与屏16 各 1 处、屏15 3 处——对比屏 13 的 35 处，说明前置块这几轮确实收敛住了。屏14 / 屏15 各有 1 条 `border-left: 2px solid #0066CC` 规则行，那是 11.7 转正后的理由件左条，**是合规不是违规**。

**残留仍是同一族**：微间距离表 —— 屏14 `2/6/14px` + 一个 **38px**、屏15 `2/3/6×2/10px` + **72px**、屏16 `2×3/6×2/10px` + **76px**、屏3b `1/2px` + **84px**。大值那一类还是 12.11 说的**契约缺层**（屏专属滚动预留没有命名 token），微值那一类进清理轮统一并到 4/8/12。

至此 **19/19 帧全部成帧、导出、建档、跑过审计**。台账 22 个目录（屏 2 三块 fork、屏 4 两块）。定稿还差的是：14 帧返修、2 帧深色、真机取证、6 项拍板。

### 12.16 **返修必然 fork，且 Stitch 会拿提示词散文当屏名**（2026-10-21 单变量实测，长版短版都试过）

前提纠正：我一度以为屏 13 那次「原帧被就地改好了、fork 是副产品」——**反了**。原因是把 DOM 顺序当成了时间顺序。屏 12b 这次做了带基线的对照，结论干净：

| 测项 | 发前基线 | 发后 |
|---|---|---|
| 原帧 `有径 - 我的行程（空状态）` srcdoc | 173,444 B，`gap:6px`×2、`padding:0 10px`×2、`margin-bottom:2px`×2 | **一字节没变**，计数全同 |
| 画布标题数 | 19 | **20**（多一块） |
| 新帧屏名 | — | `有径 - 有径-我的行程空状态" in this project, in place. Do NOT create a new s…` 与 `…（空状态）」（…）完成就地（in-place）精确修改，未创建新屏幕，未触动标题、布局…` |

**三条硬结论**：
1. **Stitch 不就地改帧。** 任何"修改这一屏"的请求都会 **fork 一块新帧**，旧帧原地不动。跟提示词长短、有没有前置块、有没有写 "in place / do not create a new screen" **全都无关**——我明写了「不要新建屏」，它照样新建，还把我那句原文拿去当了屏名。
2. **屏名会被散文污染。** 提示词里第一句英文说明会被当成新屏标题。以后若还要发，正文开头必须显式给一行 `Screen title: 有径 - <定稿屏名>`，别让 Stitch 自己取。
3. **所以"19 帧机械对齐"这条路的真实代价是：画布上多 19 块帧 + 19 块旧帧要删**，而不是原地变干净。已经为此多出 2 块废帧（屏 13、屏 12b 各一块）。

**我的建议改成：这批机械对齐不发。** 理由：`2px / 3px / 6px / 10px` 这几档微间距，在 ArkTS 落地时本来就是 `padding: 2vp` 一行的事，改起来比在 Stitch 里 fork-再-删-再-验便宜得多；而 fork 19 次会把画布搞成 40 块帧，反而让"哪块是定稿"更难说清。**把它从"设计稿返修"降级成"实现期对照表"**——清单已经由审计器逐帧生成在 `prompts/R2_*.txt`，开发时照着改即可，不必让 Stitch 改。

### 12.17 深色两帧已生成，且 `Screen title:` 这招确实挡住了屏名污染（2026-10-21）

深色真值全部从 DESIGN.md 现取（`colors` 段 40–70 行、§2 文字表、§3 语义表），**没有一条是我凭记忆写的**。两条硬规则值得单独记：

1. **深色零投影。** DESIGN.md 第 4 行与 728 行都写明 dark 是 *luminance ladder*、"shadows are dropped rather than strengthened"。所以深色变体里那条「六条阴影闭集」自查必须**整条替换**成「本帧 `box-shadow` 声明数为 0」，不能追加——追加等于给模型两条互斥指令。
2. **`#F2F2F4` 在两个极性里都存在但不是同一个东西**：浅色的它是 `surface`（第二级灰面），深色的它是 `dark-ink`（正文级文字）。所以深色前置块的浅色残留扫描要把它**放行**，否则会误报。真正要清的是 `#69696E`（浅色 muted）与 `#9E9EA3`（浅色 faint），它们在图标那条里，得逐片段换成 `#97979E` / `#8A8A91`。
3. **徽章极性翻转**：深色下实心语义色（`#FFD60A` / `#FF9F0A` / `#30D158` / `#FF453A` / `#0A84FF`）上的标签必须是 **`#121212` 墨字**，不是白字——沿用浅色"白字压语义色"会直接踩我们上线过的那条对比度缺陷。

**生成物**：`prompts/dark_gen.sh` 产出 `_preflight_dark.txt`（8,704 字，逐行替换 10 处 + 片段替换 3 处），`dark_body_gen.sh` 产出 `SEND_屏8dark.txt` / `SEND_屏12dark.txt`，终检 8 位 hex 0、浅色残留 0、字号全在梯内、radius 全在闭集、blur 一律 24、`env(safe-area-inset-bottom)` 在位。

**两帧都已成帧**，屏名干净：`有径 - 行程时间线主视图（深色）`、`有径 - 我的行程（深色）`。**12.16 那条"散文被当屏名"的坑，用正文第一行显式写 `Screen title: 有径 - <屏名>` 就挡住了**——这条以后每条提示词都固定带上。

**又抓到一处我自己造的假绿**（第 7 次同一族）：`dark_gen.sh` 里 `open().write(PRED)` 写在片段替换**之前**，而校验用的 `left` 是对替换**之后**的 `PRED` 算的 → 报了"只剩 #F2F2F4"，落盘文件其实还是旧的。规矩补一条：**写盘必须在最后一次修改之后，校验要读回文件而不是读内存变量。**

### 12.18 深色两帧首生即全绿：三条深色专用判据全部守住（2026-10-21）

导出建档 `_superseded/屏8dark_有径-行程时间线主视图（深色）_e1245be8`（17,503 B）、`_superseded/屏12dark_有径-我的行程（深色）_ccee0f60`（17,601 B），`screen.png` 各一份。跑标准四闸门 + 三条深色专用判据：

| 判据 | 屏8dark | 屏12dark |
|---|---|---|
| 四闸门（tailwind / 8 位 hex / M3 token / safe-area） | 0 / 0 / 0 / 2 | 0 / 0 / 0 / 2 |
| **① 零 `box-shadow`**（深色是亮度阶梯） | **0 条** ✓ | **0 条** ✓ |
| **② 浅色 hex 残留**（16 个浅色值全查） | **无** ✓ | **无** ✓ |
| **③ 实心语义色上配白字** | **无** ✓ | **无** ✓ |
| 亮度阶梯实际用到的档 | #121212 #1E1E1E #232326 #28282C #3A3A3F | #121212 #1E1E1E #232326 |
| 内联 `style=` | **0 处** | 1 处 |
| 间距离表 | 2 / 6 / 10px 各 1 | 2px×3、10px×2 |

**三条深色规则一次成型、零返修**——这验证了 12.17 的做法：**替换整条闭集，而不是追加一段深色说明**。尤其第③条（语义色上必须是 `#121212` 墨字），只要前置块写清极性翻转，模型就不会退回浅色的白字写法。

**深色变体生成配方定型**（`dark_gen.sh` + `dark_body_gen.sh`，后续要补深色屏直接复用）：10 处逐行替换 + 3 处片段替换 → `_preflight_dark.txt`；正文只描述结构与内容、**一律不写浅色 hex**，颜色全交给前置块；正文第一行必须 `Screen title: 有径 - <屏名>`。

至此 **21 帧**（19 浅色 + 2 深色）全部成帧、导出、建档、跑过审计。剩下的仍是那三样：真机取证、6 项拍板、以及把 `R2_*.txt` 那份微间距对照表在 ArkTS 落地时改掉。

## 十五、渲染几何取证：把「底栏到底在不在画布里」变成可测量（2026-10-21）

**动因**：`screen.png` 固定裁掉机身底部 102–122px，所以底栏与安全区**从来没有过像素级证据**，只有声明级。而声明级判据这一路已经证明会漏。解法不需要真机——**台账里的 `code.html` 是本地文件，用 chrome-devtools MCP 那条独立 Chrome 实例 `emulate` 成 360×780 直接量**。

**方法（两条调用一帧）**：`navigate_page` 到 `file://…/code.html` → `evaluate_script` 读 `document.scrollingElement.scrollHeight`、`.device-frame` 的实际高、每个 `position:absolute/fixed` 底栏的 `rect.bottom` 与距底、最紧可点件的距底、以及**所有带 `backdrop-filter` 的元素清单**。

**关键单值判据：`docH` 必须等于 780。** 一旦 `docH > 780`，`bottom: 0` 的绝对定位底栏就会解析到比画板更高的包含块上，**整条底栏被推出画布**——这是声明级 grep 结构上抓不到的盒模型问题。

### 15.1 屏 4 `7d6e58d6`：三条真缺陷，全部只在渲染下现形

| 实测 | 值 | 判 |
|---|---|---|
| `docH` / `body` 高 | **820**（画板 780） | ✗ 内容溢出 40px |
| `.device-frame` | h 780、`overflow: hidden`、`position: relative` | 画板本身对 |
| `.bottom-bar` | `position: absolute; bottom: 0` → **top 728 / bottom 800** | ✗ **底栏在画布外 20px** |
| `.btn-primary` | **距底 −4px** | ✗ 违反「按钮底边须高于画板底边 ≥16px」——**主 CTA 落在可视区之外** |
| `.bottom-bar` 的 `style=` | `background-color: rgb(255,255,255); backdrop-filter: none;` | ✗ **材质正确只因为内联盖着**，CSS 规则里仍是半透+模糊 → 12.1 那条判断被渲染层证实 |
| 带 `backdrop-filter` 的元素 | `status-bar:blur(24px)`、`title-bar:blur(24px)` | ✗ **状态栏被做成了玻璃面**——它属设备 chrome，等于契约四处之外的第五处玻璃 |
| 滚动内容 | `attraction-row` 一直到 bottom 1067 | 正常（被 `overflow:hidden` 裁掉） |

### 15.2 已量的六帧：屏 4 是唯一溢出者

| 帧 | `docH` | 底栏/dock 距底 | 最紧可点件距底 | 材质靠内联？ | 玻璃面 |
|---|---|---|---|---|---|
| 屏1 `77ed8d08` | 780 ✓ | — | **60** ✓ | 否 | — |
| 屏2 `7d2eafa8` | 780 ✓ | 0（贴边条） | **32** ✓ | **否**（规则本身已修） | — |
| 屏3 `b6b3126b` | 780 ✓ | 0 | **16** 压线 | 否 | — |
| 屏4 `7d6e58d6` | **820** ✗ | **−20** ✗ | **−4** ✗ | **是** ✗ | 2，含状态栏 ✗ |
| 屏8 `9c0acbcd` | 780 ✓ | dock **28** ✓ | 35 ✓ | — | **4 处**，其中 `segmented-control` 是 **blur(20)** ✗，余三处 24 ✓ |
| 屏10 `471fcea9` | 780 ✓ | 0 | **16** 压线 | **否** | — |
| 屏12 `f037b5c4` | 780 ✓ | — | — | — | title-bar 24 + dock-container 24 ✓ |

**两条副产物**：① 屏 8 渲染出**正好四处**玻璃面（top-bar / segmented-control / sticky-day-header / floating-dock），**独立证实了 12.11 的契约读法**——我先前写进前置块的"三处"确实是漏了分段控件。② 探针本身要修：第一版按类名匹配 `bottom|footer` 会把滚动区里的 `.card-footer`/`.trip-card` 当成底栏，量出 −34 这种假缺陷；**只认 `position != static` 且 `bottom > H-200` 的元素，或直接看 `docH`** 才可靠。
### 15.3 全 21 帧几何量完：唯一溢出者是屏 4，屏 12 那条 −34 是我的探针错

统一判据：**`docH` 必须 = 780**；底栏/dock 距底；最紧可点件距底；材质是否靠内联；带 `backdrop-filter` 的元素清单。

| 帧 | `docH` | 底栏/dock 距底 | 最紧可点件 | 内联盖材质 | 玻璃面（实测 blur） |
|---|---|---|---|---|---|
| 屏1 | 780 ✓ | — | 60 ✓ | 否 | — |
| 屏2 | 780 ✓ | 0 | 32 ✓ | 否 | — |
| 屏3 | 780 ✓ | 0 | 16 压线 | 否 | — |
| **屏4** | **820 ✗** | **−20 ✗** | **−4 ✗** | **是 ✗** | 2，**含 `status-bar` ✗** |
| 屏5 | 780 ✓ | 0 | 16 压线 | 否 | title-bar 24 |
| 屏6 | 780 ✓ | 0 | 16 压线 | 否 | title-bar 24 |
| 屏7 | 780 ✓ | 0 | 16 压线 | 否 | top-bar 24 |
| 屏8 | 780 ✓ | dock 28 ✓ | 35 ✓ | — | **4 处**，`segmented-control` **20** ✗，余 24 |
| 屏9 | 780 ✓ | — | 16 压线 | 否 | title-bar 24 + day-header 24 |
| 屏10 | 780 ✓ | 0 | 16 压线 | **否** | — |
| 屏11 | 780 ✓ | dock 28 ✓ | 70 ✓ | — | 3 处，`segmented-control` **20** ✗ |
| 屏11b | 780 ✓ | dock 28 ✓ | 70 ✓ | — | 同上，`segmented` **20** ✗ |
| 屏12 | 780 ✓ | — | — | — | title-bar 24 + dock-container 24 ✓ |
| 屏12b | 780 ✓ | dock 28 ✓ | 301 ✓ | — | top-bar 24 + dock 24 ✓ |
| 屏13 | 780 ✓ | — | — | — | **零 blur、零 opacity 作用于可点件** ✓（合 L593 widget 只许实色） |
| 屏14 | 780 ✓ | scrim 0 | 32 ✓ | — | 零玻璃 ✓；**`modal-scrim` 类被实际使用**（我加的 token 有消费方） |
| 屏15 | 780 ✓ | dock 28 ✓ | 35 ✓ | — | title-bar 24 + dock 24 ✓ |
| 屏16 | 780 ✓ | 0 | 40 ✓ | 否 | title-bar 24 |
| 屏3b | 780 ✓ | 0 | 16 压线 | 否 | top-bar 24 |
| 屏8dark | 780 ✓ | dock 28 ✓ | 28 ✓ | — | **正好 4 处、全部 24** ✓ |
| 屏12dark | 780 ✓ | — | — | — | 3 处、全部 24 ✓ |

**三条要点**：

1. **屏 4 是唯一 `docH > 780` 的帧，也是唯一主 CTA 落到画布外的帧。** 其余 20 帧全部 `docH = 780`、可点件距底 ≥16px。屏 10 那次「底栏材质靠内联」的老问题在渲染层确认**已经修在规则里**（`INLINE` 为否）。
2. **深色两帧一次兑现了全部深色规则**：`box-shadow` 实测 **0 条**、玻璃全部 **24px**（浅色屏 8/11/11b 上反复出现的 `segmented-control: 20px` 在深色版里不存在）、`.device-frame` 背景实测 `rgb(18,18,18)` = `dark-canvas #121212` ✓。**唯一小瑕疵**：两帧的 `body` 背景分别是 `#070B16` 与 `#000000`，都不是契约值——但 `.device-frame` 满幅 780 高把它整个盖住，**画面上不可见**，属死声明；落地 ArkTS 时窗口底色要显式指定，否则会黑一下。
3. **我的第一版探针量出过一条假缺陷**：屏 12 报 `trip-card@−34`，实为滚动区里被折到折叠线以下的卡片，不是底栏。**判据改成「只认非 static 定位 + 直接看 `docH`」后才干净**——这条写进方法论，别再用类名匹配 `bottom|footer`。

## 十六、定稿交付：入口已换到工程文档（2026-10-21）

**给前端工程师的开工入口是 `~/Documents/StitchDesign/youjing-engineering-handoff.md`**（13 节，含 token 全表 + ArkTS 换算、字阶、三个封闭集、四处玻璃面、组件规格、21 帧逐帧「不许照抄」清单、13 条禁令、ArkUI 官方组件映射、已知稿件缺陷、渲染几何验收口径、流转图与路由表、开工顺序）。本文件继续作为**出稿与改稿的流程台账**，不再是交付物本身。

**冻结状态**（本行原话，**已被第十七章部分推翻，以第十七章为准**）：21 帧（19 浅色 + 3 数据态变体 + 2 深色基准）全部成帧、导出、建档、跑过声明级审计与浏览器渲染几何实测；四闸门 21/21 全绿、阴影闭集违规 0、字号离梯 0。契约侧 7 项悬案已在 `DESIGN.md` §9 定死，另加两条禁令（状态栏禁玻璃化、画板 780 硬边界）。

**明确不做的事**：112 处离表间距、91 处内联 `style=`、3 处离表圆角、屏 4 底栏溢出——**不发 Stitch 返修**，因为实测证明任何返修都会 fork 新帧（§12.16），代价远大于在 ArkTS 里改一个数；全部转成工程文档 §7 / §10 的逐帧清单。

## 十七、深色批次推翻重写：判据换成同源解析后炸出四处配方缺陷（2026-10-21）

### 17.1 第十六章那句「冻结」为什么不算数

深色侧此前只有浅色四闸门 + 读回复，**没有任何一条深色专属判据是机器化的**。补上 `audit_dark.sh` 之后，两个已入账的基准深色帧立刻各中一条：

| 帧 | 命中 | 说明 |
|---|---|---|
| 屏 12 深色 `ccee0f60` | `#000000` 在帧内 | §4 明令 never pure `#000000`；另有 1 处内联 `style="stroke: #0A84FF;"` |
| 屏 8 深色 `e1245be8` / 屏 12 深色 `ccee0f60` | `html` / `body` 底色未写 `#121212` | 决议第 7 条。画面被满幅 `.device-frame` 盖住所以看不出来，ArkTS 读这层当窗口底色会闪黑 |

**这两条都不违反浅色四闸门**，所以 21/21「全绿」从来只证明浅色判据过，不证明深色过。第十六章的冻结声明已在原文打上「以第十七章为准」的推翻指针。

### 17.2 四处配方缺陷：都在**发出去的那段字**里，不在画布上

1. **前置块第 19 行仍写 `light mode`**（深色派生只替换了正文里的 light mode，漏了前置块）。它和同一块里的 DARK CLOSED GREY SCALE 直接对撞——这是 11.10 记过的「两条互斥指令」故障复发。
2. **CTA 那条写 `label #FFFFFF`**。昨天才修的 §4 极性（亮底配 `dark-on-primary`，白字压 `#0A84FF` 只有 3.65:1、16px 不算 WCAG large text = 真 AA 失败）在前置块里仍是旧的。
3. **灰阶那条把 `#FFFFFF`「留给压在实心强调底上的标签」**（`...reserved for icon stroke and for labels sitting on a solid accent fill`），和第 2 条同一个根。
4. **route-paper 插画板整块没换色**。DESIGN.md §6 明写深色画布是 **ink night terrain**（`route-night-*` 十件套，组件表 557–566 行逐件 `darkPathColor` 已绑定），而派生器只做了 UI 阶梯色的浅→深映射，于是**屏 5 / 屏 8 / 屏 16 三帧的地图会画成一张浅色地图**：渐变停在 `#F1F2F5`、water `#EAF2FA`、等高线 `rgba(26, 26, 26, 0.15)`（近黑压在浅底上，深色帧里等于隐形）、路线被 sub_hex 翻成主色 `#0A84FF` 而不是 `route-night-path #7DB8FF`。

第 4 条里最坏的一处：**屏 5 正文从浅色稿继承了一句「`rgba(26, 26, 26, 0.15)` and `#EAF2FA` are DESIGN.md tokens … do not correct them」**。这是一条**反纠偏指令**——不只自己错，还命令模型不许修。深色稿必须把这句换成 night 板的 token 名，否则任何返修轮都会被它挡回去。

### 17.3 我自己造的两道假绿（防重犯）

- `used = {h for h in re.findall(r'#([0-9A-Fa-f]{6})\b', txt)}` —— **捕获组把 `#` 吞了**，`used` 里没有 `#`、universe 里全是 `#`，两个集合永不相交：于是「浅色侧专用面/墨命中」恒 0（假绿），而「台账外 hex」= 帧内全部 hex（假红，一次报出 14 种，连 `#121212`、`#0A84FF` 都在里面）。**修法：任何集合判据都要拿一个"应当命中"的对照组跑一次**——我把浅色帧 `9c0acbcd` 丢进深色判据，命中 11 种浅侧专用值，判据这才算活了。
- 判「这帧有没有画地图」最初用关键词 `route|contour|water` —— 有径整屏都是 route 一词，屏 4 被误判成有画布、进而要求 night 板 ≥2 值。**改成用板子本身当证据**：出现纸质板值即违规，用到 night 板才是真画了画布。
- `node_repl` 里**语句必须以 `;` 结尾**，否则报 `SyntaxError: Unexpected identifier '__node_repl_..._snapshot'`。这是 wrapper 的语法坑，跟浏览器、跟代码逻辑都无关，别去查错方向。

### 17.4 现在的机器状态（可直接续作）

| 件 | 状态 |
|---|---|
| `DESIGN.md` | 新增 `dark-hairline: "#3A3A3F"`。此前这个值只存在于 769 行的浅\|深表行、`colors:` 块里没有 → **每个深色帧的合法发丝线都会被报「台账外」**，属于契约的机器可读缺口。同批已补 `dark-on-primary: "#121212"` |
| `prompts/_preflight_dark.txt` | 9,159 字。四条断言：无 `light mode` 残留 / CTA 写 `label #121212` / 含 `html`+`body` 底色令 / 无浅侧专用 hex 残留（残留判据也改成同源解析，`#F2F2F4` 一边是浅色 surface-subtle 一边是 dark-ink，手抄清单必误报） |
| `prompts/SEND_屏*d…txt` | **19 份**（含屏 8）。10,589–13,637 B，`dark_all_gen.py` 生成断言 19/19 通过；`audit_dark.sh` 扫 19/19 全绿；night 板证据：屏 5 用 5 值、屏 8 用 4 值、屏 16 用 4 值，其余 16 帧无画布 |
| `dark_all_gen.py` | 新增 `NIGHT` 换色表（纸质板→ink night terrain 逐件），**必须排在 `sub_hex` 之前**；`route-paper`→`route-night` 这条必须排在**具体长句之后**（否则长句先被改写就永不匹配）；浅色残留判据改为同源解析 + `route-paper-*` 板禁用 |
| `audit_dark.sh` | 深色判据全表：四闸门 / 浅侧专用面墨 / 阴影声明 0 / blur 档 {24} / `html`+`body` 底色 / §4 极性成对 + **盲区自报**（亮底但本块没写 color 的，字色靠继承，判据看不见就明说看不见）/ 纸质板禁用 / night 板证据 / rgba 差集 / 内联 `style=` |

**判据一律运行时从 `DESIGN.md` 解析，不手抄清单。** 手抄那份漏了 `#F1F2F5`、`#EAF2FA`——它们同时是浅色板与插画板的值，只有从 `route-paper-*` 键名解析才知道「这组值只属浅色侧」。

### 17.5 待办：19 帧重发 + 旧深色帧删除（两步都要浏览器）——**两步均已完成，见 17.10**

旧 20 个深色帧（18 批次 + 屏 8dark + 屏 12dark）是在**自相矛盾的前置块 + 浅色地图板 + 一句「别改」**下生成的，结构上带病，修文案不修画布没有意义，整批按新文案重发、旧帧作废帧删除。

- 阻塞点：Chrome 当前只有一个网盘分享标签页（那是你自己在用，我不在你的浏览器里开标签），Stitch 项目页需要你打开一次。
- 打开后我自己做：`ce.fill(正文)` → 焦点 click → `tab.cua.click({x:991,y:747})`，19 条逐条发；认帧只数 `有径 - X（深色）` 标题条数 +1，不读回复文字。
- 成帧后一次多选导出（先试 `⌘A` 全选，不行就 `⇧` 手点）→ 落台账（目录名带 code.html md5）→ `audit.sh` + `audit_dark.sh` 双跑 → 渲染几何量底栏与安全区。
- 全绿之后再删旧 20 帧。删除是 GUI 删除操作，逐次报给你点头。

### 17.6 废稿已清（本地 zip）——**本节末句"屏 1 三块旧帧早已删掉"已被 17.10 推翻；且 27 个包已进一步清到只剩 `(27).zip`**

按「内部帧 md5 无一进台账」判定并删除 6 个包，剩余 20 个包全部对得上台账帧：

| zip | 内部帧 md5 | 身份 |
|---|---|---|
| `stitch_youjing_v7.zip` / `(1).zip` | `370a098f` ×2 | 屏 1 首次生成帧（七条度量偏差全在，画板 1280×780） |
| `stitch_youjing_v7 (2).zip` / `(3).zip` | `7a01af33` ×2 | 屏 1 单条短返修帧（只挂内联 `font-size`，规则块仍 16px） |
| `stitch_youjing_v7 (5).zip` | `ffaca4fd` | 屏 1 七条打包返修帧（七条全绿但画板仍 1280 宽） |
| `stitch_youjing_v7 (16).zip` | `36f09148` | 屏 4 那轮纠偏留下的**死帧**（1262 行记过它：它装的是屏 4 内容、害我把屏 9 的失败发送误判成成功） |

删前逐个核过：这 4 个 md5 都不是任何台账帧的来源，且屏 1 的三块旧帧早已在 Stitch 云端删掉。文档里的引用是**文字记录 + md5 + 字节数**，不依赖包还在，所以删包不削弱证据链。

### 17.7 真人粘贴是唯一提交通路，并用 `html/body` 底色当新帧签名（2026-10-21 实测）

第十七章的重发不是靠"我觉得文案修好了"推进的，是靠一个**每帧可验的签名**。修正版前置块独有一条指令：`html` 与 `body` 必须显式写 `background-color: #121212`。旧批次这一条**全错**（实测 `#070B16` 或 `#000000`），所以「新帧的 `body` 底色是不是 `#121212`」就成了**旧帧与新帧的天然区分器**，不用比 md5、不用读回复文字。

**发送通路：程序化提交彻底走不通，只能真人按两个键。** 逐条实测（Chrome，`stitch.withgoogle.com/projects/686208087596162876`）：

| 通道 | 结果 |
|---|---|
| `ce.fill(10,735 字)` | 文本进 DOM、截图看得见、发送键变实心白圈，但**点发送是空提交**（字数不变、无新帧） |
| `cua.click` 打在像素量出的发送键中心 CSS (1020, 750) | 无提交。**坐标本身没错**——同一比例尺下点 Export 胶囊 (1290, 37) 一次就开了导出面板 |
| `cua.type({text:'.'})` | 不进输入框（10,735 → 10,735） |
| `dom_cua.keypress(['.'])` / `(['space'])` | 不进输入框——composer 从没拿到焦点，键事件落到**画布**上 |
| `dom_cua.keypress(['meta','a'])` / `(['shift','1'])` | **对画布有效**（全选 40 帧、Zoom to Fit 都兑现了） |

所以做法固定成：**我把每条提示词 `clipboard.writeText` 写进剪贴板并读回校验字数 → 你 `⌘V` + `Enter`**。
**绝不用 `⌘A`+`Delete` 去清输入框**：composer 没焦点时那两个键等价于「全选帧 + 删帧」，等于拿云端 40 帧赌焦点。

**另一条必须记住的环境坑**：Chrome 窗口会自己掉到后台。掉下去之后 `elementScreenshot` 返回**固定 17–19 KB 的纯黑图**（不管请求多大区域），而 DOM 读写全部正常，极易误判成"页面没渲染"；更糟的是此时 `cua.*` 真事件会打到**当时前台的别的应用**上。修法：**每次真事件前先 `(await browser.capabilities.get('visibility')).set(true)` 并等 1–1.5 秒**，并且以"截图不是纯色"作为可以点的前提。

**成帧节奏与虚拟化**：真人发送后约 **60 秒**出新帧（我按 20 秒一轮、最多 6 轮轮询）。画布虚拟化很凶——发送后一度只剩 **3 块**内层 iframe 在渲染，且渲染的是"最近被碰过"的那几块，所以轮询要按标题匹配而不是按帧序号。

**已验的两帧 A/B**：

| 屏 | 旧帧 | 新帧 |
|---|---|---|
| 屏 1 首启与静默登录 | `body #000000`、CTA `#FFFFFF` | `body #121212`、CTA `#121212`（168,332 B） |
| 屏 2 行程基础输入 | `body #070B16`、CTA `#FFFFFF` | `body #121212`（168,705 B） |

顺带记一条**浅色侧**的新发现：`有径 - 偏好追问（多选变体）`（浅色帧）的 `html/body` 底色实测是 `#121212`——浅帧挂近黑窗口底色，和深色帧挂浅底是同一类缺陷的反向，实现期要在 `EntryAbility` 显式设窗口色，别读稿件这层。

### 17.8 旧深色批次的全量量化（20 帧，2026-10-22 凌晨）

**先记一条意外收获**：`~/Downloads/stitch_youjing_v7.zip`（4,888,771 B）与 `(1).zip`（5,292,012 B）是 10-21 22:47 / 22:51 的**整项目导出**，各含 **42 块 `code.html`**——旧深色批次 20 帧全在里面。所以旧批次不必抽样推断，可以直接全量跑判据。解到 `stitch_v7_ledger/tmp/oldfull/`（**不进台账**，这 20 帧是要删的）。

20 帧逐条跑 `audit_dark.sh` 的结果：

| 判据 | 命中 | 明细 |
|---|---|---|
| `html/body` 未显式写 `#121212` | **20 / 20** | 决议第 7 条整批违反，无一例外 |
| §4 极性违规（亮字压亮底） | **4 帧** | `f12b571c` 行程基础输入 · `415ce721` 偏好追问状态机 · `d220a111` 住宿区域选择 · `64cdd65f` 生成受阻 |
| 深色出现 `box-shadow` | 3 帧 | `b9252c78` · `c718b882` 万能卡片 · `e0b0de67` 旅行中模式 |
| 纸质板残留 | 1 帧 | `d220a111` 住宿区域选择（地图整块没换 `route-night-*`） |
| 台账外 hex | 6 帧 | 各 1 种 |
| 内联 `style=` | 6 帧 | 最多 9 处（`ca948d8a` 费用超支态、`b24a96a5` 持久化） |
| **浅侧专用面/墨** | **0 帧** | 见下 |

**一条翻案**：我此前推断「前置块画板行残留 `light mode` 会污染出浅色面」——**没有发生**。20 帧的浅侧专用面墨全部为 0，Stitch 自己偏向深色侧解掉了这条矛盾。所以那条缺陷的真实代价不是"画出浅色"，而是**让 CTA 标签极性变成逐屏掷骰子**（4/20 掷出白字压亮蓝，其余 16 帧恰好对）——这比"全错"更糟，因为它看起来是好的。

**极性这条为什么值得单独说**：srcdoc 抽样时我看到 9 帧里 4 帧白字，差点当成探针误差（srcdoc 被 Stitch 注入的包装 CSS 污染，`box-shadow` 计数因此虚高）。全量导出跑下来**恰好也是这 4 帧**，两条独立通道对上了，才算坐实。

**顺带坐实一条台账卫生问题**：`有径 - 我的行程（深色）` 有**两块同名帧**——`ccee0f60`（17,601 B，1 处内联 `style="stroke: #0A84FF;"`）与 `b9252c78`（14,911 B，带阴影违规）。同名帧会让认帧和导出都出错，删帧时要一起清掉。

**新帧的天然区分器**：修正版前置块独有一条 `html`/`body` 必须显式 `background-color: #121212`，而旧批次 20/20 没有。**所以「`body` 底色是不是 `#121212`」就是新帧与旧帧的身份判据**，不用比 md5、不用读回复。真人发送那一轮我已经用它在画布上验过屏1/屏2/屏3/屏3b。

### 17.9 深色 19 屏全部落地：逐条验帧的账（2026-10-22）

改走「**一条一验**」之后，19 屏全部成帧，无一遗漏。每轮的固定动作：`pbcopy` 喂一条（核 md5 与文件一致）→ 核输入框为空（防重复粘）→ 真人 `⌘V`+`Enter` → 轮询该屏出现 `html/body = #121212` 的新帧 → 才喂下一条。

| 屏 | 新帧 srcdoc | night 板 | 纸质板 | 白字压亮蓝 |
|---|---|---|---|---|
| 屏1 首启与静默登录 | 168,332 B | 0 | 0 | 无 |
| 屏2 行程基础输入 | 168,705 B | 0 | 0 | 无 |
| 屏3 偏好追问状态机 | 167,788 B | 0 | 0 | 无 |
| 屏3b 偏好追问多选变体 | 168,643 B | 0 | 0 | 无 |
| 屏4 景点选择 | 171,456 B | 0 | 0 | 无 |
| **屏5 住宿区域选择** | 173,857 B | **9** | **0** | 无 |
| 屏6 行程生成中 | 177,482 B | 0 | 0 | 无 |
| 屏7 生成受阻 | 168,404 B | 0 | 0 | 无 |
| **屏8 行程时间线主视图** | 179,949 B | **3** | **0** | 无 |
| 屏9 行程时间线编辑态 | 176,663 B | 1 | 0 | 无 |
| 屏10 单个活动节点详情 | 170,939 B | 0 | 0 | 无 |
| 屏11 费用视图 | 174,185 B | 0 | 0 | 无 |
| 屏11b 费用视图超支态 | 172,673 B | 0 | 0 | 无 |
| 屏12 我的行程 | 172,217 B | 0 | 0 | 无 |
| 屏12b 我的行程空状态 | 167,902 B | 0 | 0 | 无 |
| 屏13 万能卡片 | 16337 B（导出件） | — | — | — |
| 屏14 持久化与系统触达 | 174,225 B | 0 | 0 | 无 |
| 屏15 旅行中模式 | 18110 B（导出件） | — | — | — |
| **屏16 分享与导出** | 171,722 B | **5** | **0** | 无 |

**三条判据全部兑现**：`html/body` 底色 19/19 为 `#121212`（旧批次 0/20）；§4 极性 19/19 无"亮字压亮蓝"（旧批次 4/20 违规）；三个带路线地图的屏 5/8/16 全部改用 `route-night-*`、纸质板 0 命中（旧批次 `d220a111` 是 paper=2 / night=0）。

**方法论记一笔**：`night` 列在屏 9 上是 1、屏 5 上是 9 —— 这个计数来自 srcdoc 全文，包含 Stitch 注入的包装 CSS，**只能当"有没有换板"的有无判据，不能当数量判据**；真正的数量判据在导出件上跑（`audit_dark.sh` 的 night 板那行）。同理 `阴影=7` 这类 srcdoc 计数全是包装污染，一律不作判据。

### 17.10 云端清场收口：废帧 27 → 0，画布只剩 38 块定稿（2026-10-22）

17.5 的两步（19 条重发 + 旧帧删除）**全部完成**。云端项目 `686208087596162876` 从 60 帧收敛到 **38 帧 = 19 浅 + 19 深**，与台账一一对应。

**先翻掉 17.6 的一句假话**：那节写着「屏 1 的三块旧帧早已在 Stitch 云端删掉」——**没有删掉**。17:40 的整项目导出里它们还在（`_22`=`370a098f`、`_20`=`7a01af33`、`_6`=`ffaca4fd`）。当时的"已删"是看界面印象得出的，这正是 17.9 末尾同一条毛病的第二次犯。

**为什么 md5 不能用来判"删没删"**：同一块帧两轮导出的 `code.html` **字节不同**，只差序列化格式 —— `crossorigin` → `crossorigin=""`、`&display` → `&amp;display`、`<path/>` → `<path></path>`、`<!DOCTYPE html>` 换行压成一行、空白折叠。实测拿 44 个台账 md5 去对新导出**只对上 2 个**。我一度据此报过「20 块全删净」，那是 md5 漂移造成的假绿。

**可用的精确对齐法（本轮立住的方法）**：把两边都剥掉 `<style>` / `<script>` / `<link>` 并归一化空白、实体、自闭合标签、属性引号之后取长度，则

```
云端 srcdoc 剥皮长度  =  导出 code.html 剥皮长度  +  1505
```

`1505` 是注入包裹层的固定开销，实测 38/38 恒定命中、0 未匹配。于是"这块云端帧是导出里哪一格"从相似度猜测降级成查表。

**但同名同长的一对长度法失效**：`formability_widgets_1`（废帧 `2ae6139d`）与 `_2`（定稿 `7fc1cb85`）标题与剥皮长度**完全相同**，只能回落到内容比 —— 剥皮标记的 `SequenceMatcher` 比值对**正确**导出约 `0.885`，对同屏别的版本只 `0.75–0.81`；拿这个区间当阈值判，**别只看最高分**。两个对照组同时过（`_17` 定稿 0.8856、`_11` 定稿 0.8920）。

**本轮实际删掉的 4 块**（另 3 块屏 1 旧帧在复核时已不在云端）：

| 画布坐标 | 导出格 | 身份 | 台账 md5 |
|---|---|---|---|
| y=46301 x=0 | `_48` | 屏3b 深色 fork | `c80ca38d` |
| y=4157 x=1344 | `_40` | 屏4 被取代版 | 定稿是 x=0 的 `7d6e58d6` |
| y=16774 x=1344 | `formability_widgets_1` | 屏13 重复 | `2ae6139d` |
| y=9418 x=0 | `_34` | 死帧 | `9cb9f720` |

**删除的双闸做法**：按 `(x, y)` 在 `div[style*="pointer-events: all"][style*="translate"]` 里精确锁定槽位 → 读该槽 `iframe` 的 `srcdoc` 取 `<title>` 逐字比对 → 才允许 `More → Delete`。**画布标签不能当身份**：y=46301 那块标签渲染成 `Generating Screen...`，真标题只在 `<title>` 里。

**三条浏览器操作口径（推翻旧记录）**：① **Playwright 元素点击能选中帧**，前提是帧已在视口内 —— 旧记录「只认真实鼠标」是错的，当时失败是因为帧在视口外、Playwright 的 scroll-into-view 对 transform 平移层无效；② **`cua.scroll({scrollY:-N})` 按 N CSS 像素平移画布**，这是把目标帧推进视口的唯一可编程通道（`cua.drag` 在选择工具下不平移）；③ **删除可撤销**，右下角 `Deleted / Undo` 浮条与工具条 undo 都能还原，实测 60→59→60 且标题复原。

**两个必须记住的反例**：台账里**浅色屏 14 定稿 `d04983a4` 的画布底色就是 `#000000`**、**浅色屏 3b 定稿 `480d5d03` 的画布底色就是 `#121212`**。所以"深色底 ≠ `#121212` 即废帧"这条看着干净的规则会直接删掉两块定稿 —— 本轮两次差点踩中，都是回台账核底色才拦下的。

**画布会重排版**：删帧后同一块帧的 `translate(x,y)` 会变（屏 1 那块从 x=3986 挪到 x=3532），**别把某一轮量到的画布坐标当持久身份**，每次操作前重读一遍。

**本地核对件已全部清掉，共 108 MB**（两轮）：27 个旧导出 zip + 3 个 10-14 单屏解包目录 + 过程截图 + `proj26`/`oldfull`/`new7` 共 68 MB；打包交付时又清掉 `tmp/` 全量 19 MB、最后一个整项目快照 `(27).zip` 7.2 MB、10-14 那包 `stitch_youjing_travel_itinerary_planner/` 14 MB。`tmp/` 下曾留作 17.8/17.9 原始证据的 `darksrc`/`srcdocs`/`cloudsrc` **也一并删了** —— 那两节的表格数字本身已写进文档，且 §17.9 已注明 srcdoc 计数含注入包装、**只当有无判据不当数量判据**，所以删件不削弱结论；要再取同类数据，对 `frames/` 里活着的 38 块重跑 `audit_dark.sh` 即可，已删的旧深色批次则本就不可复现。屏 12b 云端唯一存活的 `_36`（md5 `06190639`）已导入台账，**38 块定稿现在全部落在磁盘上，交付不再依赖云端**。
