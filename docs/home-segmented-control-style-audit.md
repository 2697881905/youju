# 首页顶栏「推荐 / 关注 / 每日一帖」分段栏 · 样式审计

审计对象：首页顶栏分段栏的静态样式、token 取值与可见性。结论均来自源码与色板数值计算，未做实机截图。

## 1. 定位

| 项 | 位置 |
| --- | --- |
| 调用点 | `entry/src/main/ets/components/HomeTab.ets:621-651` |
| 组件实现 | `entry/src/main/ets/design/components/SegmentedControl.ets`（`outlined: true` 分支） |
| 滑块 | `entry/src/main/ets/design/motion/SharedSlide.ets` |
| 数据 | `HomeTab.ets:43-47` `FEED_SEGMENTS` = 推荐 / 关注 / 每日一帖 |
| 同排叠加 | `TagNav`（`compact + dropdownOnly`，`HomeTab.ets:638-648`，`zIndex 2`） |
| 触碰代理 | `design/motion/Pressable.ets` |

`outlined` 风格同一实现共 4 处在用：HomeTab、MessagePage:694、ProfilePage:512、ProfilePage:878。

## 2. 几何与 token

| 属性 | 取值 | 说明 |
| --- | --- | --- |
| 容器宽 | **202vp** | `fillWidth: false` → `intrinsicWidth() = 3 × itemWidth(66) + SpaceTokens.xs(4)` |
| 容器高 | **36vp** | `LayoutTokens.segmentedHeight` |
| itemWidth | **66vp** | `HomeTab.ets:625` 硬编码 |
| 容器内边距 | 2vp | `SpaceTokens.xs / 2` |
| 容器圆角 | 20vp（`RadiusTokens.lg`） | 36 高的元素半径上限为半高 18 → **几何上就是全胶囊** |
| 容器底 | 透明 | `outlined` 分支 → 露出顶栏 `backgroundColor(ColorTokens.canvas)` |
| 容器描边 | 1vp `ColorTokens.barBorder` | `LayoutTokens.glassBorderWidth`，`BorderStyle.Solid` |
| 容器阴影 | 无 | `outlined` 分支 radius 0 |
| 滑块尺寸 | 66 × 36vp | `inset: SpaceTokens.none`（注意：**不是** SharedSlide 的默认 4）→ 贴容器边框 |
| 滑块圆角 | 20vp → 18 | 同容器，全胶囊 |
| 滑块填色 | `ColorTokens.barSelectionSurface` | `SegmentedControl.ets:181`，`outlined || glass` 共用 |
| 滑块阴影 | `ShadowTokens.cardContact` | radius 1 / `#08000000` / offsetY 0 |
| 文字 | 14 / 400 → 600，行高 20，tracking 0 | `TypeTokens.callout` → `headline.weight` |
| 文字色 | `secondary` → `primary` | 选中态同时换字重与色阶 |

顶栏总高 = `padding xs(4) × 2 + titleBarHeight(60) + segmentedHeight(36)` = **104vp**。
在 360vp 屏上，分段栏右侧与 TagNav 胶囊水平间距 = 344 − 202 − 88 = **54vp**（无重叠风险）。

## 3. 排版与动效

- 文字状态切换动画：`MotionTokens.fast (140ms)` + `MotionCurves.standard` `cubicBezier(0.2, 0.8, 0.2, 1)`。`fontWeight` 不可插值，实际只有颜色过渡。
- 整栏按压：`scale(0.99, 0.97)` / `220ms` / `spring cubicBezier(0.34, 1.56, 0.64, 1)`。
- 按压光斑：`glowOverlay()`，180 × 36vp 径向渐变（`glassWhite → brandTint → glassGlowMedium`）+ `BlendMode.SCREEN`，随按下透明度 0 → 0.55 / 扫选 0.92。
- 触控热区：`Pressable` 的 `responseRegion` 高 44vp（`touchOffset = (36 − 44)/2 = −4`），视觉 36vp 不撑高布局。

## 4. 交互

- 长按 180ms 进入「扫选」，横移 > 6vp 后高亮跟随手指（`activeIndex()` 返回 `hoverIndex`），松手提交选中并抑制后续 click 250ms。
- `onAreaChange` 回写 `controlWidth`，扫选用 `indexFromX` 按等分槽位换算，与 `itemWidth` 无关。

## 5. 发现

### 5.1 术语不统一：帖 / 贴
App 内 tab 文案是「每日一**帖**」（`HomeTab.ets:46`、`FoundationPreview.ets:32`、`ParchmentPreview.ets:27`），但对外合规文本与埋点注释是「每日一**贴**」（`PrivacyPage.ets:55/57`、`PrivacySettingsPage.ets:229`、`InterestTagsPage.ets:205`、`api.ets:491/514`、`types.ets:303`、`HomeTab.ets:302`）。**隐私政策属对外法律文本，与 App 内栏目名不一致存在解释风险**，建议以 tab 文案为准统一。

### 5.2 描边在画布上几乎不可见
顶栏底色是 `ds_canvas`。按 alpha 合成后：

| 主题 | 描边色 | 合成结果 | 与画布对比度 |
| --- | --- | --- | --- |
| 浅色 | `bar_border #BFFFFCF3` 压 `#F6F1E3` | ≈ `#FDF9EF` | **1.07 : 1** |
| 深色 | `bar_border #523A3120` 压 `#14120C` | ≈ `#201C12` | **1.10 : 1** |

两套主题都远低于 WCAG 1.4.11 对非文本 UI 组件要求的 3 : 1。即 `outlined` 风格真实呈现是「无边框透明条 + 滑块」，而非设计注释里写的「细边框大圆角」。同 token 的右上角搜索按钮同理（靠内部图标维持可识别性）。

> 同排的圈子下拉按钮原先走的是另一套规格（实色 `ds_elevated` 底 + 1vp `separator` 描边 + `pill` 圆角），已统一到本节规格，见 §7。

### 5.3 滑块本身也偏弱
`bar_selection_surface` 合成后：

| 主题 | 值 | 合成结果 | 与画布对比度 |
| --- | --- | --- | --- |
| 浅色 | `#99FFFCF3` 压 `#F6F1E3` | ≈ `#FBF8ED` | **1.06 : 1** |
| 深色 | `#332A251A` 压 `#14120C` | ≈ `#18160F` | **1.02 : 1** |

选中态实际主要由「字重 400 → 600」+「`primary #161410` ↔ `secondary #3F3A2E`」承载，滑块是近乎不可见的纸面提亮。这与设计注释「outlined 用纸面高亮」的意图一致，但强度低于可辨识阈值。

### 5.4 两个死 token，指向被漏掉的选中态强化
`ColorTokens.barSelectionBorder` 与 `ColorTokens.barSelectionShadow` **全项目 0 引用**：

| token | 浅色 | 深色 |
| --- | --- | --- |
| `bar_selection_border` | `#E6FFFCF3`（90% 近白） | `#524A412C` |
| `bar_selection_shadow` | `#2E8A6548`（`ds_brand` 浅，18%） | `#5CC9A47A`（`ds_brand` 深，36%） |

深色 `bar_selection_shadow` 取的是 `ds_brand` 深色值 `#C9A47A` → 原设计应是「选中项 = 品牌色描边 + 柔和品牌色投影」。实现里只落了 surface，等于把选中态的辨识度砍到只剩文字。给 SharedSlide 的滑块补上 `border(1vp, barSelectionBorder) + shadow(barSelectionShadow)` 即可闭环，且不必改任何调用点。

### 5.5 内边距是空转的
容器 `padding(SpaceTokens.xs / 2)` = 2vp，高度 36vp ⇒ 内容区 32vp；但内层 `Row` 与 `SharedSlide` 都写死 `segmentedHeight`(36) 与 `intrinsicWidth`(202)，正好把 2vp 内边距顶满（居中溢出后恰好回到 border box 边缘），叠加 `clip(true)` 后无可见裁切。当前不自相矛盾（两边同为 token），但 `padding` 已无实际约束力，后续若单独改 `segmentedHeight` 需同时确认这两处。

### 5.6 与搜索按钮并非同一形状
搜索按钮 44 × 44 用 `RadiusTokens.lg`(20)，20 < 22 未被钳制 → 是「大圆角方形」；分段栏 36 高的半径被钳到 18 → 是「胶囊」。注释称「与右侧搜索按钮视觉统一」，实际圆角形状不同。

### 5.7 扩容会溢出
`itemWidth` 66 与总宽 202vp 都是写死的。加第 4 个分段（如「热榜」）后 `intrinsicWidth = 4 × 66 + 4 = 268`，加 TagNav 胶囊 88 与左右内边距 16 = **372vp > 360vp**，在常见窄屏上必溢出。建议改为按可用宽度等分（`fillWidth: true` 或按屏宽计算 `itemWidth`）。

### 5.8 光斑在浅色主题下无效
`glowOverlay` 用 `BlendMode.SCREEN`，在浅色画布（`#F6F1E3`）上 SCREEN 混合几乎无输出；且 180 × 36vp 超出容器高 36 被 `clip(true)` 裁成条状。该效果只在深色主题可见，建议按主题（或 `isImmersiveLightSenseSupported`）决定是否挂载。

## 6. 建议优先级

1. **P1** 统一「每日一帖」术语，优先改对外合规文本（`PrivacyPage` / `PrivacySettingsPage` / `InterestTagsPage`）。
2. **P1** 补齐选中态：给 SharedSlide 滑块加 `barSelectionBorder` + `barSelectionShadow`（两个 token 已在位，零调用点改动的收益最大）。
3. **P2** 复核 `bar_border` 在纯色画布上的可用性——若需真正的「描边风格」，应立一个高于 3 : 1 的描边色 token，而不是复用为玻璃浮层准备的 hairline。
4. **P2** 分段栏宽度改为自适应，避免扩容溢出。
5. **P3** 清理 `padding` 空转与 `glowOverlay` 主题适配。

## 7. 变更记录

### 2026-09-14 · 圈子下拉按钮统一到 `outlined` 规格
`entry/src/main/ets/components/TagNav.ets:113-123`（`chipBarInner` 的下拉按钮），改动前 → 改动后：

| 属性 | 改动前 | 改动后 |
| --- | --- | --- |
| 背景 | `this.glass ? Transparent : ColorTokens.elevated` | `Color.Transparent` |
| 描边 | `1vp` + `ColorTokens.separator` | `LayoutTokens.glassBorderWidth` + `ColorTokens.barBorder` |
| 圆角 | `this.glass ? RadiusTokens.lg : RadiusTokens.pill` | `RadiusTokens.lg` |

要点：

- 三项全部保持尺寸不变（`88 × segmentedHeight(36)`），只换材质 token，不涉及布局。
- `pill(999)` 与 `lg(20)` 在 36 高的元素上都被钳制到半高 18，**渲染结果原本就一致（同为全胶囊）**，此次改 `lg` 仅为了与分段栏共用同一形状 token，无像素变化。
- 背景从 `ds_elevated` 换成透明后，与画布的对比从约 1.10 : 1（浅）/ 1.07 : 1（深）变为 1.07 : 1 / 1.10 : 1 —— **视觉差异极小**。本次改动的主要收益是 token 与形状语言对齐（两个控件同用 `barBorder` + `lg`），而非观感强度提升。
- `glass` 三元分支因此在该按钮上失效（两个分支结果相同），已直接写常量；`TagNav` 的玻璃容器本身仍走 `barSurface / barBorder / floatingBar` 分支，不受影响。
- 副作用：该按钮不再使用 `ColorTokens.separator`，但 `ChipRow`（`design/components/ChipRow.ets:84`，`compact || glass` 态的 chip 描边）仍在用同一 token，所以同一页面内「圈子 chip 横滑栏」与「圈子下拉按钮」在非首页场景下的描边 token 仍可能不一致，后续若启用 `dropdownOnly: false` 需一并核对。

### 2026-09-14 · 圈子页底部资料卡统一到同一规格
`entry/src/main/ets/components/CircleSelectionCard.ets`（`cardBody()` 尾部），改动前 → 改动后：

| 属性 | 改动前 | 改动后 |
| --- | --- | --- |
| 背景 | `ColorTokens.barSelectionSurface`（纸面高亮） | `Color.Transparent` |
| 描边 | 无 | `LayoutTokens.glassBorderWidth` + `ColorTokens.barBorder` |
| 圆角 | `RadiusTokens.lg` | 不变 |
| 阴影 | `ShadowTokens.cardContact` | 无 |

要点：

- 该卡原先对齐的是分段栏的**滑块**（纸面高亮 + 无边框），现在改为对齐分段栏的**容器**（透明底 + 细描边）。同时移除了随之失效的 `ShadowTokens` import。
- 卡内「进入」按钮本来就走同一套 outlined 规格（`CircleSelectionCard.ets:60-61`），改动后内外两级描边同色同宽。
- ⚠️ **需实机复核**：卡片是 116vp 高的内容块，`bar_border` 压 `ds_canvas` 的对比只有约 1.07:1（浅）/ 1.10:1（深），容器又已透明 → 卡片与画布的分层几乎只剩这条几乎不可见的描边，且内部「进入」按钮的轮廓与卡片轮廓同色。若实机上认为卡片「立不住」，按 §5.2/§5.4 的思路补对比度（单独立一个 ≥3:1 的描边色 token，或恢复 `cardSelectionSurface` 面），而不是继续复用 `barBorder`。
- 这是同一规格的第 4 处采用方，规格本身见 §2。

### 2026-09-14 · 批量推广到圈子/发布相关控件（第 5–7 处）+ 新增 `DesignButton.outlined` 变体
规格从「顶栏单行胶囊」推广到卡片与列表行。**注意：可复用的是「材质三件套」（透明底 + `glassBorderWidth`/`barBorder` 描边 + `RadiusTokens.lg` 圆角，无阴影）；「高 36vp」只约束顶栏单行控件**，卡片/行按其自身尺寸（116 / 76 / 68 / 44）走，半径 20 在这些高度上不再被钳制。

| # | 位置 | 改动前 | 改动后 |
| --- | --- | --- | --- |
| 5 | `pages/CircleDetailPage.ets` 的「最新/热门」分段栏 | `glass: true`（`barSurface` 底 + 系统模糊 + `floatingBar` 圆角 + radius 18 阴影） | `glass: false, outlined: true` |
| 6 | `components/JoinedCirclesDialog.ets` 的圈子格子（76 高） | `barSelectionSurface` 填充 + `cardContact` 阴影 | 透明底 + `barBorder` 描边，无阴影 |
| 7 | `components/PublishModeSheet.ets` 的发布方式选项行（68 高） | `barSelectionSurface` 填充（描边/圆角已合规） | 透明底（描边/圆角不变） |

配套新增 `DesignButton` 的 `outlined` 变体（`design/components/DesignButton.ets`），并让 `CircleDetailPage` 的「退出圈子 / 加入圈子」按钮改用它：

```
export type DesignButtonVariant = 'primary' | 'ghost' | 'glass' | 'outlined';
// outlined = 透明底 + barBorder 1vp 描边 + lg 圆角 + 无阴影 + primary 文字
```

要点与风险：

- **`DesignButton.outlined` 是这次唯一新增的公共 API**。规格落在组件内（`isOutlined()` + `resolvedRadius()` + `fontColor` / `border` 三元分支），页面侧只写 `variant: 'outlined'`，与「规格住在组件里」的约定一致。`primary` / `ghost` / `glass` 三个既有变体行为未改动。
- ⚠️ 「退出圈子」是**破坏性操作**，改用 outlined 后它变成透明底 + 无品牌色（文字走 `primary`）的中性控件，和旁边的分段栏视觉同权。设计系统里本来也没有 danger 变体，若希望它仍有警示性，需要一个独立的 danger/outlined-danger 变体，而不是复用这条规格。
- ⚠️ 该按钮 `visualHeight` 用 `DesignButton` 默认 44vp，`lg`(20) 在 44 高上不被钳制 → 形状是「大圆角方形」，与同排 36 高的分段栏（被钳成**全胶囊**）**不是同一形状**，与搜索按钮同款。要真正对齐需显式给 `cornerRadius: RadiusTokens.pill`。
- ✅ 第 6、7 处落在 `SpringPanel`（系统玻璃 + `barBorder` 描边）之内，而 `barBorder` 本来就是为了浮在玻璃/影像上而设的 hairline → 在这两个弹窗里透明 + 描边的可读性**优于**画布上的场景（第 1–5 处），风险较低。
- 顺带清理：`JoinedCirclesDialog` 移除失效的 `ShadowTokens` import；`PublishModeSheet` 与 `CircleDetailPage` 无残留 `barSelectionSurface` 引用。

### 2026-09-14 · 两个弹窗的面板参数统一（内部描边规格之后的收尾）
反馈：改完内部格子/选项行后，「已加入的圈子」弹窗**总体仍是实心**，发布弹窗样式**又不一样**。排查结论是**问题在面板层，不在内部元素**——`SpringPanel` 6 个调用方的实测参数：

| 弹窗 | panelPadding | radius | immersive | 内部 space |
| --- | --- | --- | --- | --- |
| FolderPickDialog / FolderNameDialog / ProfileShareSheet / PostStatsDialog | `lg`(20) | 默认 `lg`(20) | 开 | `base`(16) |
| JoinedCirclesDialog | `lg`(20) | 默认 `lg`(20) | **关** | `base`(16) |
| PublishModeSheet（改前） | `md`(12) | `xl`(28) | 开 | `sm`(8) |
| PublishModeSheet（改后） | `lg`(20) | 默认 `lg`(20) | **关** | `base`(16) |

结论与改动：

- **`PublishModeSheet` 是三项全偏的异类**，`JoinedCirclesDialog` 是唯一关流光的。本次只改前者（`immersive: false` + 参数回归约定），后者本来已落在目标状态，**未改动**。
- `immersive: false` 同时关掉 `ImmersiveSurface` 的 HDS 双边流光与 `#1EFFFFFF→#1E86CFFF` 蒙层 → 面板回到「系统玻璃 + 细描边」。用户 2026-09-14 明确选择「要最薄」。
- ⚠️ **根因提醒**：`ImmersiveSurface` 源码记录「部分真机 `backgroundBlurStyle` 会渲染为不透明面板」。所以「实心」本质是**面板材质问题**——内部元素做成透明底也不会透出任何东西。**后续不要再通过调内部元素的透明度来试图解决面板的实心感**，剩下的杠杆只有 ① 面板 `ShadowTokens.floating` 外阴影（`SpringPanel` 共享，需加 prop 才能只改这两个）② 给面板描边单独提对比度。
- 副作用：这两个弹窗现在与其余 4 个（保留流光的）**面板材质不同**，属刻意的差异，不是遗漏。
- 图标体系差异（未处理）：`JoinedCirclesDialog` 用 `TagIcon` 的**彩色**图标（`fillColor` 可主题化），`PublishModeSheet` 用**单色灰**图标（`publish_*_outline` / `chevron_right` / `close_x`，`base` 与 `dark` 各一份写死 `#3F3A2E` / `#B9B09A`）。两套着色方式在弹窗体系内并列，若要统一需先把后者改成 `currentColor` + 使用处 `fillColor`。

### 2026-09-14 · 发布选项弹窗对齐三段栏：面板 outlined（A）+ 单条容器描边（B）；形状（C）几何不可行
用户复核后指出「首页顶部分段栏的样式和发布选项弹窗不一致」，逐行比对后确认**材质三件套已完全一致**，剩余差异只有三项。按用户选择处理 A、B，C 经几何验算判定不可行。

**A · 面板也做 outlined** —— 给 `SpringPanel` 增加 `@Prop outlined: boolean = false`：

```
.backgroundBlurStyle(this.outlined ? BlurStyle.NONE : GlassBlurStyle.Floating)
.backgroundColor(this.outlined ? Color.Transparent : (isImmersiveLightSenseSupported() ? Color.Transparent : ColorTokens.barSurface))
.border({ width: LayoutTokens.glassBorderWidth, color: ColorTokens.barBorder, style: BorderStyle.Solid })   // 不变
.shadow(this.outlined ? ShadowTokens.none : ShadowTokens.floating)
// build(): if (this.immersive && !this.outlined) → 跳过 ImmersiveSurface 流光层
```

`PublishModeSheet` 传 `outlined: true`（并显式 `immersive: false`）。默认值 `false`，**其余 5 个弹窗行为零变化**。

**B · 描边层级改成 1 条** —— 三个选项合并进一个 `Column` 容器（`barBorder` 1vp + `RadiusTokens.lg` + `clip(true)`），条目自身去掉描边、保持透明底；条目之间用 `Divider().height(LayoutTokens.hairlineWidth).color(ColorTokens.separator)`。这与分段栏「1 条容器描边 + 内部 3 段无边框」同构。

**C · 形状改成胶囊 —— 几何上不可行**（未实施，附验算）：

| 量 | 值 |
| --- | --- |
| 容器宽 | `panelWidth 344` − `panelPadding lg`×2 = **304vp** |
| 容器高 | 3 × 68 + 2 × 0.5(hairline) = **205vp** |
| `RadiusTokens.pill` 钳制后半径 | `min(304, 205) / 2` = **102.5vp** |
| 第一行图标左上角 (16, 22) 到圆角圆心 (102.5, 102.5) 的距离 | **118.2vp > 102.5 → 落在圆角之外** |
| 第一行左侧内容区中心 (16, 34) 到圆心距离 | **110.3vp > 102.5 → 同样在圆角之外** |

结论：**多行容器做不成胶囊**。圆角半径随容器总高增长（= 高/2），而内容内缩固定为 `SpaceTokens.base`(16)，两行以上必然让首/末行的图标与文字跑到圆角之外（`clip(true)` 会直接裁掉）。分段栏之所以是胶囊，是因为它是**单行 36vp** 的元素（半径钳到 18 = 高/2）。

要把形状统一，只能在下面两条里选一条，二者互斥：

- **C1（放弃 B）**：回到 3 个条目各自描边，半径改 `pill` → 68 高的条目各成 radius 34 的胶囊，形状与分段栏一致；代价是描边回到 3 条。
- **C2（保留 B）**：容器保持单条描边，半径用 `RadiusTokens.floatingBar`(30) 折中——比 `lg`(20) 更圆，且内容不被裁。

补充一个易被忽略的事实：分段栏渲染半径实际是 **18**（`lg` 20 被 36 高钳制），而本次容器半径是 **20**（205 高不钳制）——**两者的绝对圆度几乎相同（差 2vp）**，真正的差别是「圆角占自身高度的比例」。这一项无法靠换 token 消除，属于几何固有差异。

⚠️ **可读性待实机确认**：面板去掉背景模糊与外阴影后，只剩一条描边（`barBorder` 压遮罩 ≈1.1:1 量级），弹窗内容直接浮在遮罩之上。若实机上文字/图标对比不足，应回退到「保留系统玻璃」或给面板单独提描边对比度，**不要**再靠内部元素解决。

### 2026-09-14 · 两个弹窗面板材质互换（发布 → 毛玻璃，已加入的圈子 → 透明）
上面的可读性风险在实机上被确认，用户随即做了对称调整：

| 弹窗 | 调整前 | 调整后 |
| --- | --- | --- |
| PublishModeSheet（发布方式） | `outlined: true`（透明、无模糊、无阴影） | **默认档位**：系统毛玻璃 + `barBorder` 描边 + `ShadowTokens.floating`，仍保留 `immersive: false` |
| JoinedCirclesDialog（已加入的圈子） | 默认档位（系统毛玻璃） | **`outlined: true`**（透明、无模糊、无阴影） |

要点：

- 两处各只是 `SpringPanel` 的一个 prop 开关，**弹窗内部结构未动**（发布弹窗的单条容器描边 + 无边框条目 + 发丝分隔线保持；已加入圈子的 3 列透明格子保持）。
- `outlined` 档位目前的使用方从「发布方式」换成了「已加入的圈子」，仍是 1 个，未变成死 prop。
- ⚠️ **同一个可读性风险被平移到了「已加入的圈子」**：它的结构（标题 + 若干 hairline 条目浮在遮罩上）与发布弹窗几乎同构，透明面板下大概率出现同样的对比不足。若复现，处理方式同上——回退毛玻璃、或单独给面板描边提对比度，**不要**动内部元素。
- 结论沉淀：**弹窗面板这类大面积、承载正文的浮层不适合用 `outlined` 档位**；`outlined` 的适用面是「小面积、单行、控件级」（分段栏、搜索按钮、下拉按钮、按钮）。此为经验判断，如需再评估应先在真机上看对比度。

