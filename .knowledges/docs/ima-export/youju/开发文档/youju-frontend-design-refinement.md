---
title: "youju-frontend-design-refinement.md"
id: markdown_798285c88467638f6a8dc28635ad6f33_56778d5c1c7785b25de4b247f80f7fc77505655250320770
kb: 有据-YouJu
folder: "开发文档"
media_type: 7
tags: []
source: ima
exported_at: 2026-11-23T14:52:37.917Z
---
# 有据 App 前端设计审查与「细腻精修」优化方案（修订版 v2）

> **方向调整（依据用户反馈）**：
> 1. **品牌色从蓝→纸感浅棕**：全站强调色不再是 `#1677FF` 蓝，切换为贴合奶油纸底（`#F6F1E3`）的浅棕色系。
> 2. **排版与组件布局对齐成熟社交平台惯例**：子页顶栏规格、列表行、底部弹窗、未读红点、信息流卡片等向小红书/微博/微信等已检验的交互模式校准，不做"编辑实验感"的非常规排版。**首页刊头顶部布局不动**（用户决策）。
>
> 依据：代码库勘察 + DevEco 真机（LEM-AL00）五页截图走查
> 方向：**细腻精修**——保留「暖纸感编辑风」基调与已成立资产，做细做透
> 范围：**全站关键页**（设计 token 层 + 首页/详情/登录/消息/个人主页等关键页面）

---

## 一、现状分析（外光扎实，内里松动）

「有据」已具备一套相当成熟的差异化设计语言：

| 资产 | 现状 | 评价 |
|---|---|---|
| 色彩 | 奶油纸底 `#F6F1E3` / 浮层 `#FFFCF3`，冷暖双模式完全 | ✅ 稀缺而统一 |
| 字体 | 内置 Noto Serif SC（Bold/Regular 双字重），标题衬线、正文无衬线 | ✅ 差异化核心 |
| 版面 | 首页编辑部式刊头（有据 + SUBSTANTIATE + 标语） | ✅ 品牌感强 |
| 玻璃语言 | 悬浮底部栏 + 品牌色光斑 + 弹性按压（HdsTabs/HdsVisualComponent） | ✅ 已达系统级水准 |
| 内容格式 | 信纸引用卡（textPoster 海报）、扇面「每日一帖」、圈子银河 | ✅ 有记忆点 |
| Token 化 | color/type/space/radius/motion/icon/shadow 全语义化 | ✅ 工程底子好 |

**核心问题**
1. **品牌色 `#1677FF` 蓝色与纸感违和**——它是 Ant Design/微信开发者工具同款"通用蓝"（含 `brand_harmony.svg`、gender 徽章、底部栏光斑、选中态等全量使用），压制了暖纸编辑气质，需整站切换为浅棕。
2. **风格还有毛边**——一批脱离 token 的旧写法（裸数字 fontSize、旧色值直用、死代码原型），若干高可见页面（发布弹窗、通知列表、登录页）细节手感与成熟社交平台惯例有差距。

---

## 二、七维度审查发现（含证据）

### 1. 整体视觉风格与配色

- ✅ 奶油纸 + 墨字构成可信赖的"编辑/出版"气质，与「真实经验，有据可循」吻合。
- 🔴 **品牌蓝 `#1677FF` 应改为纸感浅棕**。当前蓝色出现在：[color.json](file:///Users/itxiaobai/HarmonyProject1/entry/src/main/resources/base/element/color.json)（`ds_brand`/`brand_primary`/`surface_selected`/`bar_selection_shadow` 等）、[dark/element/color.json](file:///Users/itxiaobai/HarmonyProject1/entry/src/main/resources/dark/element/color.json)、[brand_harmony.svg](file:///Users/itxiaobai/HarmonyProject1/entry/src/main/resources/base/media/brand_harmony.svg)（两处填充）、[ProfileIdentity.ets](file:///Users/itxiaobai/HarmonyProject1/entry/src/main/ets/components/ProfileIdentity.ets)（性别徽章走 `ColorTokens.brand`）、[Index.ets](file:///Users/itxiaobai/HarmonyProject1/entry/src/main/ets/pages/Index.ets)（tab 元数据色 `#0A84FF`）、[utils/tagIcons.ets](file:///Users/itxiaobai/HarmonyProject1/entry/src/main/ets/utils/tagIcons.ets)/[settingsIcons.ets](file:///Users/itxiaobai/HarmonyProject1/entry/src/main/ets/utils/settingsIcons.ets)（分类语义色盘，保留）、[shareCard.ets](file:///Users/itxiaobai/HarmonyProject1/entry/src/main/ets/utils/shareCard.ets)（品牌色注释）、design/preview 两处。
- ⚠️ `bg_secondary`/`card_bg`/`glass_card_bg` 等**旧色值与 `ds_*` token 并存**（约 20 个文件直接引用 `app.color.text_primary`/`bg_secondary`，如 [Index.ets](file:///Users/itxiaobai/HarmonyProject1/entry/src/main/ets/pages/Index.ets)、[ChatPage.ets](file:///Users/itxiaobai/HarmonyProject1/entry/src/main/ets/pages/ChatPage.ets)）。
- ⚠️ [DailyPostView.ets](file:///Users/itxiaobai/HarmonyProject1/entry/src/main/ets/components/DailyPostView.ets) 是硬编码苹果系统色（`#F2F2F7`/`#007AFF`/`#1C1C1E`）的旧原型，全工程无引用（死代码）。

### 2. 布局结构与信息层级（对齐成熟社交平台）

- ✅ 首页刊头→分段→圈子→瀑布流的层级符合直觉。
- ✅ **首页刊头顶部布局（有据刊头 + 分段 + 圈子下拉）用户确认具有差异化，本次不修改**（用户决策）。
- ⚠️ 消息页三枚快捷统计**无计数**；通知列表行**无未读态**（对照微信/微博通知中心的红点+加粗惯例）。
- ⚠️ 发布方式弹窗（真机截图可见）三行选项图标描边粗细不一、无副标题、无按压缩放——对照成熟平台 action sheet（如微信分享、小红书发布），每项应是大行高 + 图标 + 主文/副文 + 按压反馈。

### 3. 字体与排版

- ✅ 标题衬线、正文无衬线分工正确。
- ⚠️ **全工程 214 处裸数字 `fontSize(n)`** 绕过 `TypeTokens`（[LoginPage.ets](file:///Users/itxiaobai/HarmonyProject1/entry/src/main/ets/pages/LoginPage.ets) 的 40/15/12/16、[DetailPage.ets](file:///Users/itxiaobai/HarmonyProject1/entry/src/main/ets/pages/DetailPage.ets) 的 16/18/13/14 等），行高/字重各异。
- ⚠️ [LoginPage.ets](file:///Users/itxiaobai/HarmonyProject1/entry/src/main/ets/pages/LoginPage.ets) 直接写 `fontFamily($r('app.string.font_family'))` 而非 `TypeTokens.fontFamily`。

### 4. 组件一致性与交互细节

- ✅ `Pressable`/`EmptyState`/`Avatar`/`BackButton` 共享组件已统一；顶栏「BackButton + Blank 居中标题」约定已成型。
- ⚠️ 自定义 `BottomTabBar` 仅用于 design preview（[ParchmentPreview.ets](file:///Users/itxiaobai/HarmonyProject1/entry/src/main/ets/design/preview/ParchmentPreview.ets)、[FoundationPreview.ets](file:///Users/itxiaobai/HarmonyProject1/entry/src/main/ets/design/preview/FoundationPreview.ets)），与线上 `HdsTabs` 双轨并存——保留作设计展示，注意观感不漂移。
- ✅ 置顶通知「置顶 · 」前缀规则已落地（真机截图可见）。

### 5. 响应式与移动端体验

- ✅ 瀑布流 2/3/4 列自适应、断点 440/840、内容最大宽 720。
- ⚠️ 真机（360vp）下底部悬浮栏 `smallWidth: 300` 容 5 项偏紧，真机截图可见"发布"项视觉偏满。

### 6. 可用性与可访问性

- ✅ 44vp 触控目标、reducedMotion 全局存储、icon 按钮 accessibilityText 有基础。
- ⚠️ 浅色 `ds_text_quaternary`（`#817269` 于 `#F6F1E3` 上约 4.0:1）对 12px 以下小字略低于 WCAG AA 4.5:1，需微调加深。
- ⚠️ 部分图标按钮（分享/设置/全部已读）语义标签待核查补全。
- ⚠️ 弹窗选项行/通知行触目标高度未显式保证 ≥44vp。

### 7. 品牌感塑造

- ✅ 「有据 + SUBSTANTIATE + 标语」刊头与宋体大标题是可辨识资产。
- 🔴 **品牌色为蓝 → 切换为浅棕**，与纸张形成"纸墨一体"的品牌联想（浅棕≈纸质/牛皮纸/印章朱泥的亲和色），同时去除"程序蓝"的通用感。
- ⚠️ 空态 icon 为单线条图标，品牌叙事弱；登录页无品牌时刻。

---

## 三、优化方案（细粒度、低风险、分批次）

> 原则：**不改变设计方向、不动已成立的结构**；所有改动收敛在 token 层或可映射层；每批可独立构建验证、可 git 回退。

### 批次 0 — 品牌色切换：蓝 → 纸感浅棕（Token 层 + 资源，全局生效）

**0.1 品牌色 token 全量切换（核心）**
- 文件：`resources/base/element/color.json`、`resources/dark/element/color.json`
- 拟定取值（草拟值，single-token 可微调；白/深文字对比均 >4.5:1）：

| token | 浅色模式（现→新） | 暗色模式（现→新） |
|---|---|---|
| `ds_brand` | `#1677FF` → **`#8A6548`**（纸感浅棕） | `#6FA8FF` → **`#C9A47A`**（暖纸亮棕） |
| `ds_brand_tint` | `#161677FF` → `#1A8A6548`（10% 透明棕） | `#336FA8FF` → `#33C9A47A` |
| `ds_brand_press` | `#0B5CD6` → `#6F4F38`（深一档） | `#8FBBFF` → `#D6B88E` |
| `ds_on_brand` | `#FFFFFF`（保持） | `#101010`（保持） |
| `brand_primary`（旧） | 同步 → `#8A6548` | 同步 → `#C9A47A` |
| `surface_selected` / `bar_selection_shadow` | `#161677FF`/`#2E1677FF` → 对应棕透明值 | `#246FA8FF`/`#5C6FA8FF` → 对应棕透明值 |

- 效果：点赞/选中态、链接、按钮、性别徽章、底部栏品牌光斑、玻璃选中纸面全部随 token 变为纸感棕，蓝不再出现。
- 风险：changes 收敛在 color.json，观感不佳 `git checkout` 即回退。

**0.2 硬编码蓝资源/元数据同步**
- `resources/base/media/brand_harmony.svg`：两处 `#1677FF` 填充 → `#8A6548`。
- `ets/pages/Index.ets`：`bottomTabItems()` 的 tab 元数据色 `#0A84FF` 等 → 品牌棕（仅元数据，不参与着色）。
- `ets/utils/shareCard.ets`：更新"品牌色：浅棕"注释口径。
- `design/preview/FoundationPreview.ets` / `ParchmentPreview.ets`：`#0A84FF`/`#1677FF` 同步（预览一致性）。
- **保留不动**：`tagIcons.ets`/`settingsIcons.ets`/`CircleTab.ets` 的分类语义色盘（数码=蓝、车=橙等是"类别标识色"，不属于品牌强调色）。

**0.3 记忆同步**
- 更新 `project_memory.md` 中品牌色相关表述：**品牌色=纸感浅棕（`#8A6548`），不再使用蓝色作为品牌强调色**；分类色盘除外。

### 批次 1 — 排版与组件对齐成熟社交平台惯例

**1.1 顶栏规格核查（首页以外的子页）**
- 基准（成熟平台通用）：44–48vp 高度；左玻璃 `BackButton`（40vp 圆）→ `Blank` 居中标题（`titleSerif`）→ 右侧动作按钮。
- 核查并统一：`DetailPage`/`SearchResultPage`/`UserProfilePage`/`SettingsPage`/`SearchPanelPage` 等的顶栏高度、间距、标题字重与现有约定是否一致；不一致处按 token 收敛。

**1.2 列表行基准**
- 基准（微信/微博/设置页惯例）：行高 ≥48vp、左右 `16vp` padding、行首 icon 40vp 方块、主文 `body` + 次行/时间 `caption` 两级、hairline 分隔线（`ds_separator`）。
- 应用：`MessagePage` 通知行、`SettingsPage` 设置行、`MyFollowPage`/`BlocklistPage` 行（先核对现有实现，逐处收敛）。

**1.3 发布方式弹窗 → 标准 action sheet**
- 文件：`components/PublishModeSheet.ets`
- 改动：
  - 选项行高 56vp（≥44 触控），图标 24vp 画布、2vp 描边统一（对齐 [icon.ets](file:///Users/itxiaobai/HarmonyProject1/entry/src/main/ets/design/tokens/icon.ets)）。
  - 每行：图标 + 主文（`body`）+ 12vp 副文（`caption`/tertiary，如「图文」「视频」「长文」一句话说明）+ 右箭头；`Pressable` 按压高亮（`pressScale 0.97` + `MotionCurves.spring`）。
  - 底部"取消"按钮与其他选项视觉隔离（灰色字，成熟平台惯例）。

**1.4 通知列表未读态 + 统计计数**
- 文件：`pages/MessagePage.ets`
- 改动：
  - 未读项：8vp 品牌棕圆点 + 主文加粗（`body`）；已读项降为常规。点击后立即清除未读态。
  - 三枚快捷统计图标（赞和收藏/新增关注/评论）叠加计数角标（0 时不显示）。
  - 置顶项维持「置顶 · 」前缀（现有），与普通行拉开层级。

### 批次 2 — 字体与排版规范化

**2.1 高可见页 fontSize 迁移到 TypeTokens**
- 文件：`pages/LoginPage.ets`、`pages/DetailPage.ets`、`pages/MessagePage.ets`、`pages/SettingsPage.ets`、`pages/ProfilePage.ets`、`pages/ChatPage.ets`（优先）
- 映射规则（值与现状对齐，纯引用替换）：
  - `fontSize(11/12)` → `TypeTokens.caption`；`13/14` → `callout`；`15/16` → `body`；`17/18` → `headline`；`20/21` → `title`；`30+` → `display`；行高/字重/字距一并使用 token。
- 不做视觉改变，消灭"手气"，后续全局调级一处生效。

**2.2 衬线标题规范化**
- `MessagePage` 大标题、`ProfilePage` 页头、`SearchResultPage` 结果标题统一为 `titleSerif`/`headline` 衬线组合（已用则核对字号一致）。

### 批次 3 — 页面级精修

**3.1 信息流卡片质感补全**
- 文件：`utils/textPoster.ets`
- 纸面加 2–3% 明度噪点与细规则线（11vp/tertiary 脚注小字），呼应信纸身份；不降低底不透明度（防 `componentSnapshot` 文本发灰）。不触碰首页刊头顶栏。

**3.2 每日一帖日期与编号（编辑感）**
- 文件：`components/DailyPostDeck.ets`
- 顶部加「日期 · 第 N 帖」小标（overline/tertiary 衬线数字），genre 标签样式与刊头统一。

**3.3 登录页品牌时刻**
- 文件：`pages/LoginPage.ets`
- 全部替换为 token；「有据」用 `displaySerif` 放大 + `SUBSTANTIATE` overline 串联；暖色径向渐变背景；按钮统一玻璃质感（对齐发布弹窗按钮）；保留现有登录方式与流程。

**3.4 杂页 token 化**
- 文件：`pages/PrivacySettingsPage.ets`（含 `#` 硬编码色）、`pages/AboutPage.ets`、`pages/UserAgreementPage.ets`——只做"引用变 token、值不变"。

### 批次 4 — 可用性与可访问性

- **4.1** 浅色 `ds_text_quaternary` `#817269` → `#7A7260`（于 `#F6F1E3` ≥4.5:1）；暗色已达标不动。文件：`resources/base/element/color.json`。
- **4.2** 弹窗选项行/通知行/设置行高度显式 ≥44vp（`LayoutTokens.minTouchTarget`）。
- **4.3** `Reveal`/`DailyPostDeck` 等装饰性入场动画补齐 `shouldReduceMotion()` 门控。
- **4.4** 搜索/分享/设置/全部已读/私信等图标按钮补 `accessibilityText`/`accessibilityGroup`；弹窗选项行补语义。

### 批次 5 — 构建与真机验证

1. `hvigorw` 构建 debug HAP（沿用 debug 签名）。
2. `hdc install` 到真机（LEM-AL00：10.181.227.50:43471）。
3. 逐页走查截图：首页/圈子/消息/我的/详情/登录 + **亮/暗双模式**。
4. 回归清单：
   - **品牌色切换**：全站无残留蓝色（grep `#1677FF`/`#6FA8FF`/`#0A84FF`（分类色盘除外））；棕用于选中/按钮/链接/性别徽章/底部栏光斑/分享卡片，白字/深字对比度达标。
   - action sheet / 通知未读态在模拟器与真机双降级正确；未读/已读切换即时刷新（注意 ForEach key 含 read 的已知坑）。
   - 文字海报导出/截图仍不透明底（防文本发灰）。
   - reducedMotion 开启无跳变；玻璃底部栏、圈子银河、每日一帖扇面、信纸卡无回归。

---

## 四、参考设计风格 / 成熟平台对标

| 对标对象 | 借鉴点 | 落地场景 |
|---|---|---|
| 小红书信息流 | 2 列瀑布卡片紧凑 gap、标题二字级、作者行右对齐 | 3.1/3.2 信息流微校准 |
| 微博详情页 | 顶部返回 + 作者行 + 正文 + 底部动作栏的通用骨架 | 详情页顶栏核查（1.1） |
| 微信通知中心 | 未读红点 + 置顶 + 时间戳 + 全部已读的列表惯例 | 1.4 通知列表 |
| iOS / 主流 App action sheet | 大行高选项 + 图标主文副文 + 隔离取消按钮 | 1.3 发布弹窗 |
| 《金融时报》深蓝配米白纸编排 | 纸与色克制的高差编排（不引入蓝，借用其"色纸高差"思路） | 信息流/详情页阅读气质 |
| 明确不跟风 | 强视觉瀑布、灰阶工具感、紫蓝渐变 | 保持编辑气质 |

---

## 五、假设与决策

- **品牌色**：纸感浅棕 `#8A6548`（浅色）/ `#C9A47A`（暗色）为草拟值，可通过 single token 微调；如需换色相再评审。
- **首页刊头顶部布局（有据刊头 + 分段 + 圈子下拉）保留现状，不做任何改动**（用户决策）。
- **分类语义色盘**（圈子图标、设置图标、tab 元数据外的类别颜色）不在品牌切换范围，保留原语义色。
- 不做方向性大改；不动圈子银河、玻璃底部栏、信纸卡、每日一帖扇面等成立资产；不动后端与数据流。
- 死代码 `DailyPostView.ets` 保留并标注弃用（不删除，避免误伤），不纳入迁移范围。
- 平板/折叠屏适配已在 token 层支持，本次仅真机验证，不扩展新适配逻辑。

## 六、验证入口

- 构建：DevEco Studio 或 `hvigorw` 命令行 debug 构建。
- 安装：`hdc install <hap>` 到真机。
- 走查：见批次 5 清单，逐页截图对比优化前后；建议按批次 0–4 每批一 commit，便于回退与评审。
