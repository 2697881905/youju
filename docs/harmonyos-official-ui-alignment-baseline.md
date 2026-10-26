# HarmonyOS 官方 UI 对齐基准（实测自华为智慧生活 · 原生「电话」）

采集日期：2026-10-20。用途：本项目分段栏 / 顶栏 / 页签 / 卡片类组件的尺寸与样式，改任何一枚相关 token 前先对这张表。
所有数值来自真机 `uitest dumpLayout` 节点 bounds 与截图像素探针，**不是**目测估计；标注 `tentative` 的项证据不足，不要当依据引用。

## 0. 采集环境与复现方法

| 项 | 值 |
| --- | --- |
| 设备 | 真机 1136×2690，`px/vp = 3.125` |
| 参照 App | `com.huawei.hmos.ailife`（华为智慧生活），API 26 |
| 采集页 | 首页 / 我的 / 场景 / 产品 / 设备详情 / 全部设备 / 添加弹层，共 7 屏 |
| 几何来源 | `hdc shell uitest dumpLayout -p /data/local/tmp/l.json` → `attributes.bounds`（px）÷3.125 |
| 颜色来源 | `snapshot_display` JPEG + PIL 灰度/RGB 探针 |

复现命令（单屏）：

```bash
HDC=/Applications/DevEco-Studio.app/contents/sdk/default/openharmony/toolchains/hdc
$HDC shell "uitest dumpLayout -p /data/local/tmp/l.json"
$HDC file recv /data/local/tmp/l.json /tmp/l.json
$HDC shell "snapshot_display -f /data/local/tmp/s.jpeg" && $HDC file recv /data/local/tmp/s.jpeg /tmp/s.jpeg
```

`dumpLayout` 的 `attributes` 里 `key` / `id` 是开发者显式命名的，认组件比 `type` 更准（例如 `ContainerPage_segmentButton` 直接暴露了官方分段栏）。

## 1. 官方组件清单（节点类型实测）

| 界面元素 | 官方组件（节点类型） | 备注 |
| --- | --- | --- |
| 底部五页签 | `Tabs`(`key=hdsTabs`) + `TabBar` + `TabContent` + 内部 `Swiper` | HDS 样式 Tabs，不是自绘 Row |
| 顶栏 | `Navigation > NavBar > TitleBar > HdsTitleBar > MaskBlur + Mask` + `NavBarContent` | 每页都有；`MaskBlur` 是栏体下方的渐隐/模糊带 |
| 材质宿主 | `EffectComponent` | 顶栏按钮组（168×60）与内容区各一个 |
| 分段栏 | `SegmentButton`（内部 `DynamicLayout > Row > Button×n`） | `key=ContainerPage_segmentButton` |
| 图标 | `SymbolGlyph` | 全部走符号字体，无一处用图片资源 |
| 未读数 | `Badge` | 叠在 `SymbolGlyph`/容器外 |
| 列表 / 网格 | `List` `ListItem` `ListItemGroup`、`Grid` `GridItem`、`GridRow` `GridCol` | 后者是断点栅格 |
| 下拉刷新 | `Refresh` | 首页之外未见重复实现 |
| 开关 / 分隔 | `Toggle`、`Divider`（高 0.3–0.6vp） | 分隔线用 Divider，不用 border |
| 弹层 / 菜单 | `Menu` `MenuItem` `HdsMenuNode` `MenuWrapper` `BottomCustomNode` `StackCustomNode` | 系统菜单 + 自定义底部面板 |
| 卡片自绘层 | `Canvas` | 设备卡内部一层 Canvas |
| H5 容器 | `JsView` | 产品/发现页里的运营内容 |

`metaballNode`（实况窗）属系统状态栏，不是 App 组件，勿抄。

## 2. 分段栏基准（本项目主战场）

> 本节全部是**浅色模式**（智慧生活）取证。深色模式下官方 `SegmentButton` 的对应实测在 **第 7.3 节** —— 4vp 内缩 / 14fp / 331.5×40 轨道 / 16vp 边距 两处一致，只有选中面从「半透明暗面」变成不透明 `#666666`。

⚠️ **本节 2026-10-20 重写。** 初版把两处不同语境的官方实现混成了一张表，结论（选中面纯白+投影=一致、内缩 2vp=一致）**是错的**，错因见 2.3。

### 2.1 参考实测：智慧生活有两套官方分段栏，不是一套

| | A · 顶栏材质分段栏 | B · 设备详情分段栏 |
| --- | --- | --- |
| 位置 | 场景页「我的 \| 探索」，`BottomCustomNode` 内 | 设备详情页「设备 \| 发现 \| 我的」 |
| 节点树 | `__Common__ > Stack > Stack > Flex > Button(selected=true) > Column > Text` | `ContainerPage_segmentButton > Stack > DynamicLayout > Row > Button > __Common__ > Column > Text` |
| 轨道 | 331.5 × **40vp**，边距 16 | 331 × **39vp**，边距 16 |
| 单项/选中面 | 161.9 × 32.3，四边内缩 **4vp** | 108 × 35，内缩 **≈2vp** |
| 文字 | 字盒 28.2×16.3 → **14fp** | 字盒 37×27 → **≈16fp** |
| 背景语境 | **整屏壁纸照片**，材质有东西可采样 | 纯灰页面底 `#F0F1F3` |
| 选中面亮度 | **L 187.4**（比轨道**暗** 25） | 纯白 L 255（比轨道**亮** 13） |
| 轨道亮度 | L 212.8 | L 242 |
| 投影 | **无可测投影**（滑块紧邻轨道 219.9 vs 远处 219.2，差 0.7；正下方反而更亮） | 有可见接触投影 |

A 才是我们顶栏那条栏要对标的形态；B 是纯底页面上的另一种观感。**拿 B 的白卡+投影去实现顶栏，就是当初做错的地方。**

### 2.2 官方字段与默认值（为什么"什么都不传"就是 A）

`SegmentButton`（V1 tab 档）与 `SegmentButtonV2` 的样式字段默认值全是 `"auto"` / 系统资源：

| 官方字段 | 默认值 |
| --- | --- |
| V1 `selectedBackgroundColor`（tab） | `$r('sys.color.segment_button_checked_foreground_color')` |
| V2 `itemSelectedBackgroundColor` | `$r('sys.color.segment_button_v2_tab_selected_item_background')` |
| V2 `itemShadow` | `ShadowStyle.OUTER_DEFAULT_XS`（几乎不可见） |
| V2 `buttonPadding` | `$r('sys.float.padding_level1')` = **4vp** ← 正好是参考 A 的内缩 |
| V2 `buttonMinHeight` / `buttonBorderRadius` / `itemBorderRadius` | `sys.float.segment_button_v2_*` 系统值 |
| V2 `itemFontSize` / `itemSelectedFontSize` | **14fp** ← 正好是参考 A 的字号 |
| 两者 `backgroundSystemMaterial` | 传 `uiMaterial.ImmersiveMaterial` 即接沉浸光感 |

**结论：参考 A 的 4vp 内缩、14fp 文字、暗选中面、无投影，全部落在官方默认值上。** 要还原它，做法是**不覆盖**这些字段，而不是自绘。

### 2.3 本项目现状（已改为官方默认，零自绘）

`design/components/ImmersiveSegmentBar.ets` 现在是官方 `SegmentButton`（tab 档）的薄封装：只传 `buttons`、`buttonPadding`（把 31.7vp 的自适应高度撑到 40vp）、`backgroundSystemMaterial`（门禁内）、以及首页浅色内容态的 `fontColor/selectedFontColor`。选中面底色、圆角、投影、文字样式**一律不传**。

已删除的自绘物：`SharedSlide` 叠加层、透明标签层、`SLIDE_FILL = Color.White`、`SLIDE_SHADOW`、`LayoutTokens.segmentSlideInset`（其注释"内缩 2vp"是 B 语境的值，对 A 是错的）。

**能力边界（不要再绕）**：官方 `selectedIndexes` 只接受整数数组，**没有连续/浮点索引入口**，所以滑块不跟随手指逐帧位移；宿主只把 Swiper 的 `onChange` 落到 `selectedIndex`，切换由官方状态动画完成。MessagePage / HomeTab / ProfilePage 三处的 `slidePosition`、`onContentDidScroll`、`xxSliding` 管线已随之移除。

### 2.4 新暴露的问题：白底画布上材质没有东西可采样

改成官方默认后实测我们首页（页面底为纯白）：

| 区域 | L |
| --- | --- |
| 选中面 | 254.9 |
| 轨道 | 252.0 |
| 轨道外页面底 | 251.7 |

轨道与页面底只差 **0.3 L**，选中面只比轨道亮 **2.9 L** —— 官方默认在白色画布上几乎不产生层次。参考 A 之所以清楚，是因为它背后是壁纸照片。这是**语境差异，不是实现错误**，需要设计决策（见第 8 节决策点 E）。深色模式下这个问题不存在，见第 7 节。

### 2.5 投影净空参照（仍成立）

官方 `HdsTitleBar` 栏体 56vp、其下 `MaskBlur`/`Mask` 高 **88vp**（多出 32vp 过渡带）。我们 `segmentBarTopRoom 14 + segmentBarShadowRoom 28 = 42vp` 与这个量级吻合 —— 净空不是拍脑袋，改小时要重新做像素取证。

## 3. 卡内次级分段（我们缺的那一套）

首页设备卡里的「关闭 | 降噪 | 透传」（`key=noise_root`），**不是** `SegmentButton`，是官方自绘的轻量档：

| 属性 | 实测 |
| --- | --- |
| 整行 | 223 × 35vp |
| 单项 | **74 × 34vp**，等分，项间 **1px 分隔线** |
| 单项底 | `#0C000000`（3% 黑，叠在卡片底上） |
| 图标 | **16 × 16vp** `SymbolGlyph`，与文字同排 |
| 文字 | 字盒 42.6 × 34.9 → ≈14fp |
| 选中面 | 无滑块（禁用态不可见，`tentative`） |

适用判断：卡片内部、空间紧张、三选一 —— 用这套（图标+文字+分隔线），**不要**塞顶栏那种带滑块的 40vp 分段栏。

## 4. 顶栏与页签基准

**HdsTitleBar（首页）**：栏体 56vp；标题字盒 130×30（5 字）→ ≈28fp 粗体，左对齐；右侧按钮 **40×40 圆**、图标 24×24、槽位宽 48/56、按钮间距 8；三个按钮共装在一个 `EffectComponent`(168×60) 里。

**已落地（2026-10-20）**：图标按钮的 glyph 统一到 24（`IconTokens.standard`）—— 顶栏分享/设置/收藏夹管理（`Index.ets`）、首页搜索入口（`HomeTab.ets`）、全局返回键（`BackButton.ets`）；底部页签图标 `IconTokens.tabBar` 26 → 24。
**有意不跟的一处**：官方按钮可视圆底是 **40×40**，我们的热区仍保持 **44×44**（`LayoutTokens.minTouchTarget`，无障碍下限）。只对齐图标尺寸，不把可视/触控尺寸压到 40。

**底部 TabBar**：胶囊 **328.3 × 56vp**，左右外边距 17.6；单项 **60 × 48vp**；图标 24×24（距项顶 9）；标签字盒 20.2×13.1 → ≈10fp；整块预留 **84vp**（56 栏 + 28 底部安全区）。
**选中态只换色**（图标+文字变品牌蓝），**无滑块、无指示条、无光斑**。

对照我们：`tabBarHeight = 64`、`tabBarItemWidth = 58`、`tabBarItemHeight = 50`、`tabBarSideMargin = 18`、`floatingBarReserve = 94`、`tabBarGlowSize = 180`。
→ 高度/边距/预留基本同轨（我们略厚）；**光斑是我们独有的反馈**，见决策点 C。

## 5. 卡片与列表基准

| 组件 | 实测 |
| --- | --- |
| 设备卡 | 332 × 145.9vp，内缩 11.8，底 `#99FFFFFF`（60% 白）+ 一层 `Canvas`，大圆角（视觉 20–24，`tentative`） |
| 卡内「进入」按钮 | 40 × 40 圆底（浅灰），右上 |
| 卡内产品图 | 61 × 61，禁用态 `opacity 0.6` |
| 卡标题 / 副信息 | 字盒高 18.9（≈15fp）/ 16.3（≈13fp），副信息是 `Swiper` 轮播状态文案 |
| 分组列表 | 卡底 `#FFFFFF`，单元 **331.5 × 56vp**（图标 24 + 文字盒 18.9 + chevron 12.2×24），组间 `Divider` 0.6 |
| 数字块 | 73.9 × 51.8（数字盒 24 ≈20fp，标签盒 16 ≈12fp） |
| 宫格入口 | 81 × 80（标签盒 14.1 ≈11fp） |
| 筛选行 | 按钮 96×40 / 64×40，放在可横滚 `Grid` 内；分区小标题字盒 16.3（≈12fp） |

**字号阶梯（墨迹高度反推）**：≈28 / 20 / 16 / 13 / 10–11fp。
对照我们 `TypeTokens`：`title 21` `headline 18` `body 16` `callout 14` `caption 12` `navLabel 10` —— 同轨，最大差异就是分段栏文字（决策点 A）。

## 6. 色彩：本轮不采信（仅指浅色那一轮）

设备详情页与首页耳机处于**未连接禁用态**，整页灰化，测得的轨道/文字色不能当基准。已确认的只有两条：选中面是纯白、卡片是 60% 白叠底。
→ 浅色待设备连接后复测；**深色模式的完整色阶与材质见第 7 节**（框架真值，可直接引用）。

## 7. 深色模式基准（真机原生「电话」App 实测）

采集日期 2026-10-20。设备同上（1136×2690，`px/vp = 3.125`），系统深色模式，参照 App 为原生「电话」（拨号 / 全部通话 / 未接来电 / 联系人 / 收藏 / 更多菜单 / 设置弹层，共 7 屏）。

### 7.0 方法学：先读框架真值，再上像素探针

`uitest dumpLayout` 的 `attributes` 里带 **`backgroundColor`（ARGB 十六进制）/ `opacity` / `blur` / `selected` / `enabled`**。这些是框架真值，比从 JPEG 反推可靠得多 —— 本轮所有色值优先取这里。像素探针只用来量框架不暴露的东西：**圆角半径、材质叠加比例、描边、模糊**。

两条必须遵守的坑：

1. `snapshot_display` 会返回**陈旧帧**。本轮第一帧的拨号盘比 `dumpLayout` 的位置低 143vp（面板还在上滑途中），连拍三帧里前两帧 md5 完全相同。**每帧抓完必须跟 `dumpLayout` 的 bounds 对表**，对不上就是旧帧，不能用。
2. JPEG 在近黑区有 ±3 的噪声，纯黑底上的 `#141414` 材质要用峰值/均值而不是单点。

### 7.1 深色底与表面阶梯

| 层 | 真值 / 实测 | 证据 |
| --- | --- | --- |
| 页面底 | **`#FF000000` 纯黑** | `Navigation` / `TabContent` 的 `backgroundColor` |
| `Tabs key=hdsTabs` 容器 | `#FF202224`（被页面底盖住，实际不可见） | 节点真值 |
| 底部拨号盘面板 | **`#992E3033`**（60% 的 `#2E3033`），363.5×412.2vp，顶部圆角 **R≈32vp** | 节点真值 + 角部轮廓拟合 |
| 卡片 / 名片行 | `#19FFFFFF`（10% 白）→ 实测合成 `#191919`，圆角 **R≈19vp** | 节点真值 + 像素，两者互证 |
| 默认头像圆 | `#33FFFFFF`（20% 白） | 节点真值 |
| 控件面（分段栏轨道 / 搜索框 / 圆形图标按钮底 / 悬浮页签胶囊） | 实测 `#141414` ≈ **8% 白叠加**，描边 **上 `#515151` / 下 `#333333`** | 像素 |
| 悬浮页签胶囊叠加比 | 由「over 黑 = `#141414`」「over 拨号盘 = `#2C2F32`」两点解出 **α≈0.08**，两处实测互洽 | 像素 |
| 设置弹层：sheet 底 / 分组卡底 | `#18191A` / `#212224` | 像素 |
| 弹层关闭 ✕ 圆底 | `#303133` | 像素 |
| 强调色 | **`#317AF7`**（选中索引项 `backgroundColor=#19317AF7`，即 10% 强调色）；Toggle 轨道实测 `#307AF7` | 节点真值 + 像素 |

**深色模式没有一套不透明灰阶，而是白按 8% / 10% / 20% 三档叠在黑底上。** 这三档是可以直接落 token 的数。具体 sys.color 资源名本轮未取证（`tentative`）。

### 7.2 文字与图标梯度（深色）

| 角色 | 实测色 | 字号证据（步进 = 字盒宽 ÷ 字数，CJK 步进 = 字号） |
| --- | --- | --- |
| 页面标题 | `#F0F0F0`~`#F5F5F5` | **26fp**（字盒 52.2×30.4 / 2 字 → 步进 26.1） |
| 模态 / 弹层标题 | `#F4F5F7` | **20fp**（字盒 40.0×26.9 / 2 字） |
| 列表项标题 | — | **16fp**（步进 16.0，字盒高 18.9~22.1） |
| 未选中分段标签 / 搜索占位 | `#B5B5B5` (L181) | **14fp**（步进 14.07，字盒 16.3） |
| 分区小标题 / 行尾值 | `#B9BABC` / `#B5B5B5` | **14fp** |
| 空态主文案 | `#787878` (L120) | **16fp**（6 字墨宽 93.8vp → 步进 15.6） |
| **禁用态** | **`#747474` (L123)** | 节点 `opacity` 恒为 `1.000000` |
| 页签标签 | 选中 `#729EED` / 未选中 `#F7F8FA` | **10fp**（字盒 20.2×11.8 / 2 字） |
| 拨号键盘数字 | `#F0F0F1` | ≈**26fp**（cap 高 19.2vp ÷ 0.72） |
| 拨号键盘字母 | `#7E8285` | ≈11–12fp（`tentative`，无文本节点可核） |
| 拨号输入号码 | `#F0F0F0` | ≈**40fp**（cap 高 28.2vp ÷ 0.72） |

**禁用态改色不改透明度** —— 更多菜单里 `en=false` 的三项 `opacity=1.000000`、文字色 `#747474`；拨号盘删除键禁用 `#737679` / 启用 `#F2F2F3`，同样 `opacity=1.0`。这把项目里「可操作图标禁 opacity 弱化」从我们的约定升级成**官方口径**。

### 7.3 分段栏（官方 `SegmentButton`，深色）

| 属性 | 实测 | 来源 |
| --- | --- | --- |
| 栏位宿主 | `HdsTitleBar > BottomCustomNode > BuilderProxyNode > __Common__ key=…titleSegmentButton` | 节点树 |
| 槽位高 | 56vp | 节点 bounds |
| 轨道 | **331.5 × 40vp**，左右边距 **16vp**，**胶囊圆角 R=20vp（= 半高）** | bounds + 右端轮廓拟合（R=62.5px） |
| 轨道面 | `#141414`（≈8% 白），描边 上 `#515151` / 下 `#333333` | 像素 |
| 单项 | 161.9 × 32vp，四边内缩 **4vp** | bounds（轨道 @16.0,97.9 / 项 @19.8,101.8） |
| 滑块 | **独立 `Stack` 节点**，bounds 跟着选中项走；`backgroundColor=#FF666666` **不透明**；胶囊 R=16vp | 节点真值 + 轮廓 |
| 标签 | 14fp；选中 `#FCFCFC` / 未选中 `#B5B5B5` | 步进 + 峰值 |
| `MaskBlur` / `Mask` | 高 = **栏体高 + 32vp**（56→88、112→144，两屏对照） | 节点 bounds |

对照第 2.1 节的参考 A（智慧生活·浅色）：**4vp 内缩、14fp、轨道 331.5×40、边距 16 全部一致**，官方默认值这条结论在深色下复现。差异只有一处 —— A 的「选中面比轨道暗」是**浅色 + 壁纸背景**下的半透明观感；深色下官方直接给固定灰 `#666666`，比轨道亮 L82，不依赖背景。

→ **决策点 E（白底画布上材质无层次）在深色下不存在**：轨道 `#141414` vs 纯黑底差 L20，滑块 vs 轨道差 L82，层次足够。浅色才需要另想层次来源。

### 7.4 按钮家族（深色）

| 按钮 | 可视尺寸 | 底 | 图标 | 备注 |
| --- | --- | --- | --- | --- |
| 顶栏圆形图标按钮 | **40×40vp** 圆 | `#141414` + 描边 `#353535` | SymbolGlyph **24.3×24vp** | 槽位宽 40，行高 56 |
| 弹层关闭 ✕ | 40×40vp 圆 | `#303133` | 24vp 白 | |
| 列表行尾按钮 | **48×48vp** | 无底（透明） | 24.3×24vp | 拨号建议行的 ⓘ |
| 拨出键 | **56×56vp** 圆 | 绿 `#5AA854` | SymbolGlyph **32×32vp** | 唯一用 32 图标的按钮 |
| 键盘按键 | 110.4 × 60.2vp 网格 | 无底 | 数字 + 字母合成一层 `Image` | 按压反馈**未取到证据** |
| 开关 `Toggle` | **36.2 × 20.2vp** | 轨道 `#307AF7` | 滑块 `#E5E5E5` | |
| 菜单项 | 216.3 × 48vp | 菜单体 224×297.3vp，R≈20vp，描边 上 `#6E6E6E` | 文本左内缩 12.1vp | 项间 `Divider` 0.3vp |
| 搜索框 `Search` | **331.5 × 40vp** | 与分段栏轨道同形同色（`#141414` + 上 `#515151` / 下 `#333333`） | SymbolGlyph **16×16vp** | 左内缩 12.2vp |
| 悬浮页签胶囊 | 236.2 × 56vp，R=28vp，居中（左右各 63.7vp） | 8% 白叠加 | 图标 24.3，标签 10fp | 项 70.7×48.3；上方 `Divider` 0.3vp **`opacity=0`** |
| 空态插画 | 120 × 120vp（`Paf_EmptyPage_icon`） | — | 下方文案 14fp，间距 0 | 组件族 `Paf_EmptyPage_*` |
| 索引条 `AlphabetIndexer` | 24 × 440vp，贴右缘 | 选中项底 `#19317AF7` | 单项 **16×16vp**，27 项 | |

**弹层菜单是真模糊，悬浮页签只是半透明叠加 —— 这两档要分清。** 菜单盖住分段栏滑块（L102）与轨道（L20）的硬边界，菜单内同一行实测 L26→37 平滑渐变、x=568 处**没有台阶**；而页签胶囊能透出对比度几乎不掉的键盘数字。

### 7.5 动效（证据级别：低，不要当依据引用）

- 一次陈旧帧意外抓到底部拨号盘面板比静置位置低 **143vp** → 面板是上滑入位（`tentative`，非受控抓拍）。
- 分段栏切换抓到一帧接近结束的画面：滑块在 177.2..339.8vp，静置在 181.8..343.7vp → 已位移到位、宽度 +0.4%（`tentative`，单帧）。
- **未取到**：按键按压态、动画时长与曲线。`uitest uiInput click` 是原子「按下+抬起」，紧随其后的 `snapshot_display` 抓不到高亮；设备侧也没有可用的录屏命令。要量动效得换路子（DevEco Profiler / ArkUI 动画回调埋点），**不要靠连拍猜**。
- 本轮想用 `deveco_mcp` 的官方文档检索补时长/曲线口径，该 MCP 服务无响应（连 `get_app_ui_tree` 一起超时），**动效规格本轮零证据**。

### 7.6 顶栏右上「更多」按钮 —— 官方实现链路（深浅两档同测）

真机节点树（原生电话，浅色/深色结构完全一致）：

```
HdsTitleBar (363.5×112vp)
└─ HdsMenuNode   40×56vp @x=307.5          ← n 项时宽 = n×40 + (n−1)×8
   └─ Button     40×40vp  id=dialerMenuHds   backgroundColor = #00000000
      └─ SymbolGlyph 24.3×24vp
```

联系人页有 2 项 → `HdsMenuNode` 宽 **88vp = 40 + 8 + 40** ✓ 由此反推出**项宽 40vp、项间距 8vp**（与第 4 节「按钮间距 8」互证）。
关键一点：Button 的 `backgroundColor` 是 **`#00000000`** —— 那颗圆底、白高光、投影**都不是节点背景色**，是 HDS 组件内部默认样式画的。所以「什么都不传」才拿得到官方那颗圆；一旦自己 `backgroundColor(...)` 就覆盖了它。

官方 API 路径（`@kit.UIDesignKit`，`SystemCapability.UIDesign.HDSComponent.Core`，`@since 5.1.0(18)`）：

```ts
HdsNavigation()
  .titleBar({
    content: {
      menu: {                                          // HdsNavigationMenuContentOptions
        value: [{                                      // Array<HdsNavigationMenuItemOptions>
          content: { icon, label, isEnabled, action, type, componentId },   // HdsNavigationIconOptions
          badge: { /* 可选 HdsNavigationBadgeOptions */ }
        }],
        maxCount: 3                                    // 默认 3
      }
    },
    style: {
      originalStyle: {                                 // HdsNavigationTitleBarStyle
        contentStyle: {                                // HdsTitleBarContentStyle
          menuStyle: { backgroundColor, iconColor, textColor }  // HdsNavigationIconItemStyle
        }
      }
    }
  })
```

- `icon: IconType = ResourceStr | SymbolGlyphModifier | PixelMap`（PixelMap 自 6.0.0(20)）→ 官方口径是**符号字体**，不是图片资源。
- 要改圆底/图标色，**只改 `menuStyle` 这三个字段**，不要自己画圆。

同一枚按钮的两档外观：

| | 浅色 | 深色 |
| --- | --- | --- |
| 圆底 | `#F5F6F8`（L246，**与分段栏轨道同值**） | `#141414`（L20，≈8% 白） |
| 描边 / 高光 | 顶上一圈 `#FEFFFF` 白高光 | 1–2px `#353535` |
| 外投影 | **有**：正下方 12px 处 L235 vs 页面 L243（−8 L），到 40px（12.8vp）仍 −7 L | **无** |
| 图标色 | 近黑（墨迹峰值到 L0） | `#F0F0F0` |
| 尺寸 | 40×40vp 圆 / 图标 24.3×24vp | 同左 |

**与本项目现状的差**：`pages/Index.ets:1047` / `:1070` 的顶栏按钮是 `Pressable({…}) + Image(resolveActionIcon('share'))` **自绘**；`HomeTab.ets` 的 `TitleBarContentOptions` 只传了 `stackBuilder` / `bottomBuilder`，**从未用过 `content.menu`**。也就是说这颗官方圆一直没接上，圆底/高光/投影全靠手搓 —— 这就是决策点 D 的落点。

#### 7.6.1 装机验证结果（本项目 SDK · 浅色 · `pages/HdsMenuVerifyPage.ets`）

按上面的链路做了验证页并装机实测（`entry@default` debug 包，真机 1136×2690）。逐条结论，**含对本节上文的修正**：

| 待验项 | 结果 | 证据 |
| --- | --- | --- |
| 项宽 / 间距 | ✅ **40vp / 8vp 确认** | 3 项时 `HdsMenuNode` = **136vp** = 40×3 + 8×2 |
| `maxCount` 默认 3 | ✅ **确认会折叠**，且官方自绘 4 点圆 | 传 4 项时第 4 项变成 `Button key=hdsNavigationMoreButton`，40×40 **@x=307.5**（与电话 App `dialerMenuHds` 同槽位），图标 SymbolGlyph 24.3×24 |
| `action` 接线 | ✅ 生效 | 点第 1 项后页面文案回显为该项回调写入的字符串 |
| `badge.count` | ✅ 官方支持，红点真值 **`#FFE84026`** | `Badge 40×40` 包住 `Button`，`Text 16×16 @239.7,38.1` 压在圆右上角（**会溢出到栏顶上方**，挂 badge 时要留净空） |
| `SymbolGlyphModifier` 尺寸 | ⚠️ **默认只有 16vp**；补 `fontSize(24)` 后节点 24.3×24，与 `Image` 项 24.0×24 对齐 | 未补 `fontSize` 时符号项明显比图片项小一圈 |
| 栏底 `Divider` | ✅ 与原生一致：0.3vp、**`opacity=0`** | 节点真值 |
| 官方返回键 | 也是 **40×40 圆 + 24.3 符号**，底 `#0C000000` | 节点真值 |

**⚠️ 修正本节上文「什么都不传才拿得到官方那颗圆」这句判断。** 装机后不成立：

- 本项目 SDK 里 `content.menu` 的默认圆底是 **`#0C000000`（3% 黑）**，在白底页面渲染成 `#F7F7F7`(L247) vs 页面 `#FFFFFF`(L255) —— **比页面暗 8 L，且实测无高光、无投影**（圆下方 256–289px 全程 L255）。
- 而电话 App 那颗圆是 `#F5F6F8`(L246) **比页面 `#F1F3F5`(L243) 亮 3 L** + 顶部 `#FEFFFF` 高光 + 正下方 −8 L 投影。**3% 黑叠在任何底色上都只会更暗，不可能变亮** → 电话那颗圆的「抬升感」不来自 `content.menu` 默认值，而来自材质（`TitleBarStyleOptions.systemMaterialEffect` / `hdsMaterial`）或显式 `menuStyle.backgroundColor`。
- 旁证：电话 App 的 Button 节点 `backgroundColor` 读到 `#00000000`，我们读到 `#0C000000` —— 它把默认底色改掉过。

→ 迁移的正确预期：**接上 `content.menu` 能立刻拿到官方几何（40 / 8 / 折叠 / badge / 无障碍），但拿不到电话 App 那层浮起材质**。材质是下一个单变量实验（传 `systemMaterialEffect` 复测，仍然不许自绘）。
→ 另记：验证页自己的 `Navigation` 底是 `#FFFFFFFF` 纯白，又踩在决策点 E 那个「白画布」上，测材质前要先把它换成 `#F1F3F5` 档，否则测出来的对比方向是反的。

#### 7.6.2 单变量实验：`systemMaterialEffect` 才是那颗圆的表面来源（浅色真机）

只改一个变量 —— 给 `titleBar.style` 加 `systemMaterialEffect`，其余全部不动。设备探测：`getSystemMaterialTypes()=[101]`（101 = `MaterialType.IMMERSIVE`）、`apiAvailable('6.1.0')=true`，传入 `IMMERSIVE + MaterialLevel.ADAPTIVE`。

| 探针 | 不传材质 | 传 IMMERSIVE | 电话 App 基准 |
| --- | --- | --- | --- |
| 4 颗 Button 的 `backgroundColor`（节点真值） | **`#0C000000`** | **`#00000000`** | **`#00000000`** ← 与传材质一致 |
| 圆面 vs 周围背板（@y=193 剖面） | 圆 L243 / 周围 L255 → **暗 12 L** | 圆 L253 / 周围 L246 → **亮 7 L** | 圆 L246 / 页面 L243 → 亮 3 L |
| 顶部高光 | 无 | 有（圆顶 L255 vs 圆面 L253） | 有（`#FEFFFF`） |
| 下方投影 | 无 | **仍无**（圆下 L246→250，没有暗带） | 有（−8 L，延伸到 12.8vp） |

**结论：**
1. **沉浸光感接得上**，唯一入口是栏级 `titleBar.style.systemMaterialEffect`（`SystemMaterialParams{materialType, materialLevel}`，`hdsMaterial` @since 6.1.0(23)）。`menuStyle` 只有三个纯色字段，菜单项也没有 builder 槽位（`HdsNavigationIconOptions` = `icon/label/isEnabled/action/componentId/type`），所以**通用 `.systemMaterial()` 属性在官方圆上根本没有挂载点** —— 想给官方圆上材质，只能走栏级这一个开关。
2. 这个开关会**把圆的表面从「3% 黑压暗」整个翻成「比背板亮的浮起面」**，节点 `backgroundColor` 同时变成 `#00000000` —— 与电话 App `dialerMenuHds` 的读数**完全一致**。所以第 7.6.1 节那个「电话那颗圆不是默认值」的疑问，答案是：**它接了材质，我们没接**。
3. **残留差异：投影没复现。** 我们的圆下方没有暗带。最可能的原因是本页给材质「没东西可采样」—— `enableComponentSafeArea: true` 让内容从栏下开始，栏背板后面是纯白，材质无从模糊。**这是假设，未证**：下一步单变量应是让内容穿底到栏下（照 `HomeTab` 的 `bindToScrollable` + `GRADIENT_BLUR` 那套）再复测投影是否出现。
4. 版本约束：`hdsMaterial` / `systemMaterialEffect` 是 **@since 6.1.0(23)**，工程 `compatibleSdkVersion = 6.0.0(20)` → 必须 `deviceInfo.apiAvailable('6.1.0')` 门控（编译器也直接报了这条 warning）。与 `utils/immersiveMaterial.ets` 里 `systemMaterial` 的 `26.0.0` 门禁是同一类问题，**低版本设备上这条路径只能静默降级成「无材质的官方圆」**。

#### 7.6.3 那圈边缘阴影是怎么来的：四轮换变量实测

现象：电话 App 每颗圆的边缘下方有一圈阴影。先确认它**真的是逐颗圆的投影**，不是栏底遮罩的边缘 —— 在圆下方 12px（y=268）做横向剖面：

```
x      840  864  888  912  936  960  984  1008 1032 1056 1080 1104 1128
L       243  243  242  242  240  238  237  235  236  237  239  240  242
                        ← 圆心 x=1023，凹陷局部且向下偏移
对照列 x=400 / x=120 同一 y 区间：243→240 单调缓变，无局部凹陷
```
→ **确认是按钮自带的软投影**：以圆心为中心、比 40vp 圆宽（足迹约 73vp）、深 **−8 L**、向下偏移。

然后逐个排除官方旋钮（每轮只改一个变量，装机复测 `y=268` / `y=193` 两条剖面）：

| 轮次 | 变量 | 结果 |
| --- | --- | --- |
| v2 | `content.menu` 默认（无材质） | 圆 = 3% 黑压暗，**无 rim 无阴影** |
| v3 | + `systemMaterialEffect{IMMERSIVE, ADAPTIVE}` | `backgroundColor` 转 `#00000000`、圆比背板**亮** —— 表面来源确认在这 |
| v4 | + `scrollEffectOpts{GRADIENT_BLUR}` + `bindToScrollable` + 全链 `clip(false)`，`MaskBlur`/`Mask` 结构已与电话 App 对齐（88vp = 栏 56 + 32） | **剖面与 v3 逐位相同** → 遮罩层不是阴影来源，假设证伪 |
| v5 | `materialLevel` ADAPTIVE → **EXQUISITE** | **剖面与 v4 逐位相同** → 材质档位也不是来源，假设证伪 |
| v6 | 页面底 `bg_primary #FFFFFF` → **`#F1F3F5`**（电话 App `Navigation` 的真值） | 圆 vs 周围从 **+5 L → +9 L**，高光 `L255` 出现，观感与电话 App 基本一致 |

**结论：那圈边缘不是某个「阴影开关」，而是材质在「比它暗的背板」上合成出来的结果。** 工程浅色基色 `bg_primary = #FFFFFF` 纯白，材质没有比它暗的落影面，rim 与 shadow 全被压平；把基色降到系统那一档，官方材质自己就把阴影画出来了。**全程零自绘。**

**残留差异（已量化，未解决）**：我们的 rim 是**整周一圈均匀的亮边**，电话 App 是**上亮下暗的定向高光 + 底部投影**（看起来是「被抬起」，我们看起来略偏「描边」）。已排除材质档位与遮罩层，剩下未试的官方旋钮只有 `TitleBarStyleOptions.blurStrategy`（`ENABLE/DISABLE/ADAPTIVE`）、`thermoCtrl`、以及 `scrollEffectStyle`（滚动后那一档样式，我们只设了 `originalStyle`）。**不要为了补这一点去自绘描边或加 `.shadow()` —— 菜单项没有节点挂载点，那样必然回到自绘。**

**这条实测同时给决策点 E 的候选 0 补上了证据**：页面底降到 `#F1F3F5` 不只影响分段栏层次，**官方按钮材质能不能出边缘阴影也取决于它**。

#### 7.6.4 更暗的背板不能让阴影出现 —— 差异是「材质铺在哪一层」

继续加暗背板（v7 = `#E0E0E0`，L224，比电话 App 的 L243 还暗 19 级）：

| 剖面 | 电话 App（L243 底） | 我们 L243 底 | 我们 L224 底 |
| --- | --- | --- | --- |
| y=193 穿圆心：周围 → 圆面 | 239 → 246（**+7**） | 234 → 243（+9） | 216 → 231（**+15**） |
| y=193 高光 | 255 | 255 | 250 |
| **y=268 圆下方** | 243 → **235 局部凹陷** | 235 **整条平** | 217 **整条平** |

→ 背板越暗，圆面反差越大（+7 → +15），但**圆下方始终没有局部凹陷**。所以这圈落影**不是对比度/可见性问题**，加暗背板解决不了。

**真正的差异是材质铺在了不同层级**：电话 App 的栏**没有整条变暗的底板**（栏内 x=600..864 与页面同为 L243），只有每颗圆自带「亮面 + 高光 + 落影」；我们一开 `systemMaterialEffect`，得到的是**整条栏铺一层暗底板**（L243 底 → 栏内整条 L235），圆浮在底板上，但没有逐颗落影。

**机制定位（读 `utils/immersiveMaterial.ets:108-165` 得到，与上述实测自洽）**：逐颗圆的落影来自**通用属性 `.systemMaterial()` 挂在按钮自己身上**，开关就是 `uiMaterial.ImmersiveMaterial({ applyShadow: true })` —— 工程里已经有这一档：`FloatingTopButtonMaterialModifier`（与 `TopButtonMaterialModifier` 唯一差别就是 `applyShadow`，后者为 `false`，因为 `bottomBuilder` 行 `clip=true` 且只比控件高 4vp，投影会被拦腰裁成灰带）。该文件注释原话：「没有系统 App（智慧生活：灰底 240 + 白面 246 + 一条投影）那种浮起感」—— 就是本题的现象。

**于是能力边界清楚了（不自绘前提下的二选一）：**

| | A · `content.menu` + 栏级 `systemMaterialEffect` | B · 自己的 `Button` + `.systemMaterial(FloatingTopButton)` |
| --- | --- | --- |
| 逐颗落影 | ❌ 接不出来（菜单项 6 个字段 `icon/label/isEnabled/action/componentId/type` 里没有任何材质/阴影开关，且按钮是组件内部建的，**没有属性挂载点**） | ✅ 官方属性 `applyShadow: true` |
| 官方几何 / 折叠 / badge / 无障碍 | ✅ 全白送（40vp / 8vp / `hdsNavigationMoreButton` / `#FFE84026`） | ❌ 要自己排 |
| 净空要求 | 无 | **必须给足**：投影向下散 26.9vp、向上 10.9vp（见 [[arkui-bottombuilder-clip-shadow-room]]），否则裁成灰带 |
| 版本门禁 | `apiAvailable('6.1.0')`（材质 @since 6.1.0(23)） | `apiAvailable('26.0.0')`（`systemMaterial`） |

**不要为了补这圈阴影去自绘描边或手写 `.shadow()`** —— 那正是被反复否决的第四条自绘路。要么接受 A 的「栏级底板」观感，要么走 B 拿逐颗材质并自己排布。

#### 7.6.5 B 方案实测：逐颗落影复现成功，与电话 App 定量吻合

在验证页 `bottomBuilder`（行高 96vp、按钮顶置给足净空）放一枚 B 样本：`Button({type: ButtonType.Circle})` + `.backgroundColor(Color.Transparent)` + `FloatingTopButtonMaterialModifier`（= `systemMaterial` + `applyShadow: true`）。与 A 方案官方圆同帧比对：

| 剖面 | 电话 App | B 方案 | A 方案（`content.menu`） |
| --- | --- | --- | --- |
| 钮面 vs 周围（横向穿圆心） | 246 vs 239 → **+7 L** | 246 vs 238~241 → **+6~8 L** | 243 vs 234 → +9 L |
| 钮正下方（纵向） | 243 → **235** | 243 → **235** | 235（整条栏都是 235） |
| **圆下 12px 横向形状** | 243→**235**→243 **钟形局部凹陷**，足迹 ≈51vp | 243→**235**→243 **钟形局部凹陷**，x 40..200 ≈ 51vp | **整条平**（x 696..1080 一律 235~236），无逐颗凹陷 |
| 远离按钮的对照列 | 243 平 | 243 平（x=400 全程 243，无凹陷） | — |

→ **落影深度 −8 L、足迹 ≈51vp、钟形、以按钮为中心 —— B 方案与电话 App 三项定量指标全部吻合**，肉眼比对（裁切放大）已看不出差别。A 方案则始终是「整条栏铺一层暗底板」，怎么调都调不出逐颗落影。

**B 方案成立必须同时满足的三个条件（本轮踩到的坑）：**
1. **`Button` 必须显式 `backgroundColor(Color.Transparent)`** —— `ButtonType.Circle` 自带默认蓝底 `#FF0A59F7`，会把材质表面整个盖住（上一轮实测就是这个，钮看起来是纯蓝圆）。
2. **净空**：投影向下散 26.9vp、向上 10.9vp。本轮 `bottomBuilder` 给 96vp、按钮顶置 → 下方留 ≈48vp，`BottomCustomNode` 报 `clip=false`，投影完整。行高压到 44vp 一类就会被裁成灰带（`TopButtonMaterialModifier` 当初关投影的原因）。
3. **必须在标题栏内**：`systemMaterial` 官方生效区只含 Navigation/NavDestination 标题栏与底部 TabBar，放内容区静默不出图。

**最终结论（回答「那圈阴影怎么实现」）：走 B —— 官方通用属性 `.systemMaterial(ImmersiveMaterial({ style, interactive, applyShadow: true }))` 挂在按钮自己身上，工程里已有现成的 `FloatingTopButtonMaterialModifier`。零自绘。** 代价是放弃 `content.menu` 的自动排布 / 折叠 / badge，自己按 40vp 项宽 + 8vp 间距排，并给标题栏行留 ≥27vp 下方净空。

#### 7.6.6 净空这一条被推翻：`clip(false)` 就够，不用加高行

7.6.5 说「行高要 ≥27vp 净空」是**从 `immersiveMaterial.ets:133` 的历史注释推出来的，本轮实测不成立**。把 B 样本行高压到 **48vp**（40vp 按钮顶置，下方净空 = 0，按钮下沿正好压在行底）再装机：

| y（行底 = 431px） | 426 | 432 | 444 | 462 | 486 | 对照列 x=400 |
| --- | --- | --- | --- | --- | --- | --- |
| 钮中心列 x=112 | 246 | **234** | **235** | 237 | 236 | 全程 243 平 |

行底外 14px 处横向仍是完整钟形（243 → 236 → 243），与 96vp 行那一版（243→235）**深度一致**。全链节点实测 `clip=false`。

→ **投影可以正常溢出行边界。当年「投影被拦腰裁成灰带」的根因是祖先链上有 `clip(true)`，不是行太矮。** 所以迁移不需要动任何已上线的布局高度，只要：换材质档 + 尺寸对齐 40vp + 确认链路上没有 `clip(true)`。

#### 7.6.7 已落地：「我的」页顶栏（真机验证通过）

改动三处，全部在官方能力内：
1. `design/tokens/space.ets` 新增 `LayoutTokens.iconButton = 40`（原借 `segmentedHeight` 36，与官方差 4vp）。
2. `pages/Index.ets` 的 `profileActionMaterial`：`TopButtonMaterialModifier` → **`FloatingTopButtonMaterialModifier`**（`applyShadow: true`）。
3. 三处顶栏图标钮（分享 / 设置 / 管理收藏夹）可视尺寸 36 → **40vp**，并同步 `profileTitleBarHeight()` 的顶栏行那一项（`profileListInset` 会随之 +4vp）。

真机实测（`p1.jpeg`，浅色）：

| 指标 | 电话 App | 我们落地后 |
| --- | --- | --- |
| 钮可视尺寸 | 40.0×40.0vp | **40.0×40.0vp** ✓ |
| 图标 | 24.3×24vp | **24.0×24vp** ✓ |
| 钮间距 | 8vp | **8vp**（`SpaceTokens.sm`，25px）✓ |
| 钮下方落影深度 | −8 L | **−9 L**（255 → 246，钟形、以钮为中心，对照列 x=660 全程 255 无凹陷）✓ |

**未迁移的其余 6 处**（仍在用 `applyShadow:false` 那一档）：`HomeTab.ets` 搜索入口、`CircleTab.ets` 已加入药丸、`TagNav.ets` chip、`ProfileHeader.ets`、`DesignButton.ets`、`SegmentedControl.ets`。`SearchPanel.ets` / `SearchResultPage.ets` 本来就在用带投影那一档。

**残留观感差**：我们的页面底是 `bg_primary = #FFFFFF` 纯白，钮面也是近白 → 圆盘与背景几乎同色，只靠 rim + 落影撑出轮廓；电话 App 底是 `#F1F3F5`，圆盘明显「浮」在灰底上。**这正是决策点 E 候选 0，改一个 token 就能补齐。**

#### 7.6.8 两页顶栏口径统一（原型 → 验证页方向），真机复测吻合

原型页 `ProfileBarProtoPage` 与验证页 `HdsMenuVerifyPage` 的顶栏圆钮观感不一致，**统一方向：改原型去对齐验证页**（用户指定，验证页保持它自己实验期的取值不动）。两处取值搬到原型页：

| 项 | 统一前（原型） | 统一后（= 验证页） |
| --- | --- | --- |
| 页面底 | `bg_primary`（纯白） | **`#FFF1F3F5`**（写死，实验输入） |
| `materialLevel` | `ADAPTIVE` | **`EXQUISITE`** |

装机复测（深色模式下拍的两页，`v_a.jpeg` / `p_a.jpeg`，同一列剖面逐像素对表）：

| 指标 | 验证页 | 原型页 |
| --- | --- | --- |
| Navigation 节点 `backgroundColor` | `#FFF1F3F5` | `#FFF1F3F5` ✓ |
| `TitleBar` / `HdsTitleBar` / 各 `Button` 节点 | `#00000000`、`clip=false` | 同 ✓ |
| 钮可视尺寸（bounds） | 125px = **40.0vp** | 125px = **40.0vp** ✓ |
| 圆面（穿圆心 RGB） | `(207,208,210)` L207.9 | `(207,208,210)` L207.9 ✓ **逐字节同** |
| 左上 rim（圆边内侧） | `(238,239,241)` L238.9 | `(238,239,241)` L238.9 ✓ |
| 干净列 x=112 纵向剖面 y=120..290 | 44 个采样点 | **与验证页逐点相同** ✓ |
| 落影深度（圆正下方 vs 上方基线） | −4.1 L（237.9 → 233.8） | −3.1 L（237.9 → 234.8） |

→ 观感一致达成，剩下的差是**内容**差（右两颗图标不同 → 剖面中段 160..228 有尖峰；菜单项数 3 vs 2；栏下方放的东西不同），不是材质差。

**顺带量清 A 方案那块底板的足迹（补 7.6.4/7.6.5 的「整条栏铺一层」说法）**：`#F1F3F5` 画布上沿 y=268 横向切（正好在圆下 12px）：

| 帧 | x=560 | 660 | 720 | 800 | 880 | 1020 | 1080 | 1120 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 验证页（3 颗，`HdsMenuNode` 661..1086） | 242.9 | 238.9 | 234.9 | 235.9 | 234.9 | 234.9 | 238.9 | 240.9 |
| 原型页（2 颗，`HdsMenuNode` 811..1086） | 242.9 | 242.9 | 242.9 | 238.9 | 234.9 | 234.9 | 238.9 | 240.9 |

凹陷**起止正好跟着 `HdsMenuNode` 的 bounds**（原型页 x<800 全程平、验证页 x<650 平），中间不随圆数起伏 → 精确表述应是：**材质底板铺在整组菜单的矩形足迹上，不是逐颗圆**。深度 −8 L，与 B 方案逐颗落影（243→235）**同深度、不同足迹**。

**对迁移的实际含义**：我们的顶栏动作钮是**紧邻排布**的，「一组一板」与「逐颗一影」在这一列上几乎看不出差别 —— 所以从 B 换到 A（官方 `content.menu`）**不会掉观感**，只要钮仍然挨着。钮一旦被拉开（中间夹文字/空档），A 就会在空档处也多铺一块板，那时才露馅。

**顺带量到一条材质性质（原以为是实现差异，实为材质本性）**：同一颗 IMMERSIVE 圆，铺在 `#121212` 底上比底**亮 18 L**（L18 → L36），铺在 `#F1F3F5` 底上比底**暗 35 L**（L243 → L208）。用 `L=(1-α)·L_bg+α·L_c` 解两点会得 α<0 —— **沉浸材质不是简单 alpha-over，它按背后亮度重算表面色**。所以「圆比底亮」还是「圆比底暗」**不能当作实现对错的判据**，只能在同一背板语境下两页互比。

⚠️ **写死 `#FFF1F3F5` 的副作用（迁移前必须处理）**：深色模式下系统状态栏图标是白的，而这两页画了浅色画布 → 状态栏时间/电量几乎看不见（实测那一带亮度 222..255，没有任何暗像素，白字压浅底）。临时对比页可以忍，**生产上这一条必须落成浅色/深色一对 token（= 决策点 E 候选 0），不能把 `#FFF1F3F5` 硬编进页面。**
→ **已落成 token**：`ds_material_canvas`（浅 `#F1F3F5` / 深 `#121212`）+ `ColorTokens.materialCanvas`，两个临时页同时改吃它。浅色侧取值与写死时逐字节相同，所以 7.6.8 的比对结论仍然成立；深色侧不再是浅色画布，官方标题/图标恢复可读（复测 `p_b`：`Navigation.backgroundColor = #FF121212`）。**`ds_canvas` / `bg_primary` 未动** —— 决策点 E 候选 0 仍是开放决策，这里只是把实验输入挪进 token。

#### 7.6.9 迁移前两个结构未知，装机都答了（原型页定稿）

原型页 `ProfileBarProtoPage` 本轮把「能不能把已上线『我的』的栏模型等价搬进 `HdsNavigation`」拆成两个单变量实验，**两条都成立**，所以迁移不需要改视觉顺序：

**① `bottomBuilder.height` 运行期可重配 —— 成立。** 把 `height` 写成读 `@State` 的表达式（`82vp ⇄ 126vp`），点主分段来回切：

| 状态 | `TitleBar` bounds | `BottomCustomNode` | 折算 |
| --- | --- | --- | --- |
| 我发布（无子分段） | `[0,106][1136,537]` | `[0,280][1136,536]` | 256px = **82vp** ✓ |
| 我收藏（有子分段） | `[0,106][1136,675]` | `[0,281][1136,675]` | 394px = **126vp** ✓ |
| 再切回我发布 | `[0,106][1136,537]` | `[0,280][1136,536]` | **82vp** ✓ 双向可逆 |

子分段那一行（帖子 | 收藏夹）随高度一起出现/消失，无残影、无裁切。

→ **推翻 `MessagePage.ets:70` 记的「`bottomBuilder.height` 只在首帧生效」**。那条结论的语境是 `stackBuilder` + 快筛行，且高度表达式未必读的是会触发 `build()` 重算的 `@State`；在 `content.menu` + `bottomBuilder` 组合下不成立。**没有回头改 MessagePage** —— 它的快筛行方案（回归内容区顶部）已上线且观感正确，只是这条结论不能再当成通用限制引用。

**这条为什么关键**：已上线「我的」的资料区高度是内容驱动的（`ProfileHeader` → `onAreaChange` → `profileHeroHeight` → 栏高），登录态、有无背景图、屏宽都会改它。`bottomBuilder.height` 若能跟随，资料区就能住进栏体，保住 **标题行 → 资料区 → 主分段 → 子分段** 的原顺序；若不能，资料区只能挪到整条栏之下（顺序变）或被固定高（背景图 16:10 变体放不下）。

**② 穿底要 `enableComponentSafeArea: false` —— 成立。** 两档实测 `Scroll` 起点：

| `enableComponentSafeArea` | `Scroll` bounds | 含义 |
| --- | --- | --- |
| `true` | `[0,675][1136,2690]` | 内容区被栏体顶开 → **列表永远穿不到栏底**，与已上线的 `BarStyle.STACK` 覆盖式不等价 |
| `false` | `[0,106][1136,2690]` | 内容区从状态栏下沿起算，栏盖在它上面 → 穿底 + 渐变模糊成立 |

`false` 之后让位由列表自己的 spacer 承担，且必须与栏高同源：`listInset = 标题行 56vp + barBuilderHeight`（标题行 175px ÷ 3.125 = 56vp，官方 MINI 定值不可调）。定稿帧 `p_g`：栏底 750px，首颗卡片顶 775px（差 = `SpaceTokens.sm` 的列间距）→ **无空洞、无重叠**；而改之前 spacer 写死 272vp，资料区与首卡之间空了 180vp。

**③ 顺带：资料区不要铺自己的底色。** 它住进栏体后若画 opaque 底，会把栏级材质截成两段、在资料区与分段栏之间留一条接缝。定稿为透明，让材质整块铺过去。

**原型页现在剩的开放项只有一个**：分段栏深色表面与原生基线相反（§7.3 那条，`ImmersiveSegmentBar.ets:76` 传了 `backgroundSystemMaterial`），待拍板 —— 见决策点 D 附注 / 任务 #14。

#### 7.6.10 衬线标题与官方圆钮可同栏：`stackBuilder` + `content.menu` 共存成立

迁移前最后一条取舍（「用官方 `content.title` 就要放弃工程衬线字族」）装机验完 —— **不用取舍**：`content` 里去掉 `title`、改挂 `stackBuilder` 自排标题，`menu` 与 `bottomBuilder` 全部照常。

实测帧 `p_h`（浅色）节点真值：

| 节点 | bounds | 说明 |
| --- | --- | --- |
| `Text '我的'`（stackBuilder 自排） | `[50,144][182,244]` | 132px ÷ 3.125 = 42vp = 2 个 CJK × `titleSerif.size` 21fp ✓ 字族是衬线 |
| `HdsMenuNode` | `[811,106][1086,281]` | 官方两颗圆**仍在**，40vp / 8vp 间距不变 ✓ |
| `BottomCustomNode` | `[0,281][1136,750]` | 栏体（资料区 + 主分段）完好 ✓ |
| `Scroll` | `[0,106][1136,2690]` | 穿底仍成立 ✓ |

**一条要注意的边界**：`stackBuilder` 铺满整条标题行、**从 x=50 起排**，官方返回钮（`Button [50,131][175,256]`）仍然会渲染并被标题压住 —— 原型页是 router push 进去的，所以有返回钮。**真实「我的」是 Tab 根页、没有返回钮**，所以撞不上；但迁移后要专门确认这一点（HdsNavigation 挂在 TabContent 里不该出返回钮）。

→ **迁移定形**：标题 = `stackBuilder` 自排衬线；动作钮 = 官方 `content.menu`；资料区 + 两条分段栏 = `bottomBuilder`（高度读 `@State`）；穿底 = `enableComponentSafeArea: false`。四项互不冲突。

#### 7.6.11 已落地：「我的」顶栏迁入内嵌 HdsNavigation（真机验收 · 浅色）

`Index.ets` 改动（全部官方能力，零自绘）：

| 位置 | 改动 |
| --- | --- |
| tab 4 `TabContent` | 外包 `HdsNavigation` + `.titleMode(MINI)` + `.titleBar(profileTitleBarOptions())` + `.hideBackButton(true)` + `.clip(false)` |
| 标题行 | `content.stackBuilder` 自排衬线「我的」（保住 `TypeTokens.titleSerif`） |
| 动作钮 | `content.menu`（分享 / 设置），官方 40vp 圆 + 折叠 + 无障碍 |
| 栏体 | `content.bottomBuilder` = 资料区 + 主分段 +（子分段），`height` 读 `@State` 动态重配 |
| 材质 | `style.systemMaterialEffect` 传**数值字面量** `101/10`（`hdsMaterial` 值 import 在 API 22 上会崩）；级别用 `ADAPTIVE` 而非原型的 `EXQUISITE`（工程规范禁写死，§7.6.5 实测两档剖面相同） |
| 外层 `Navigation` | `.hideTitleBar(true)`，`.title({builder,BarStyle.STACK})` 整段退役；内容区 padding 不再为 tab 4 特判 |

真机实测（`o3/q1/q2`）：`TitleBar [0,106][1136,1209]`、`HdsMenuNode [811,106][1086,281]`（两颗 40vp 圆，右缘距屏 16vp）、衬线 `Text '我的' [50,144][182,244]`、`Scroll [0,106]`（穿底成立）、切「我收藏」时 `BottomCustomNode` 由 928px→1064px（+43.8vp，动态重配在生产页同样成立）。四个 Tab 回访无回归。

**两条把让位量算错的坑（各吃掉 14vp / 34vp，都是装机才看得出来的）：**

1. **`bottomBuilder` 把内容垂直居中塞进声明高**，实测上下各留 46px = 14.7vp（`BottomCustomNode 280..1345` 而内容 `Column 326..1299`）。所以分段栏的实际顶边比「栏体顶 + 资料区 + 间隙」再低 14.7vp —— 让位量必须补 `segmentBarShadowRoom/2`，否则首行卡片压在分段栏底下。
   副作用：投影净空被对半分成「上 14.7 / 下 14.7」，**没法只给下方**。想要下方满 28vp，只能把声明高再加 28 并接受上方同步变空。
2. **`enableComponentSafeArea: false` 之后，子页内容盒的顶边落在窗口 0，不是状态栏下沿。** 节点树里 `Scroll` 报 `[0,106]` 容易误读成「已从状态栏下起算」，但 `padding(top: topInset)` 是按窗口 0 排的 —— 实测差值正好 34vp = `statusBarHeight`。所以 `profileListInset()` 必须含 `statusBarHeight`（与迁移前那条公式同形，不是巧合）。

**修完的落点**：「我发布」首行卡片顶 1190px vs 分段栏控件底 1162px → 卡片在栏下 28px；「我收藏」1327px vs 子栏控件底 1299px → 同样 28px。余下对 `BottomCustomNode` 声明底的 −19px 落在投影净空带内（那是刻意留给材质投影的），肉眼无叠压。

**尚未验收**：深色档（本机当前停在浅色，切系统深色属于改动用户设备设置，留给用户翻）。

#### 7.6.12 落地后立刻踩到的功能性缺陷：`GRADIENT_BLUR` 不绑 Scroller 会把子列表滚动整个吃掉

迁移首版照抄首页/圈子/消息那套 `scrollEffectType: GRADIENT_BLUR`，但**没有**同时接 `bindToScrollable`（当时想「先不做模糊绑定」）。真机结果：「我的」帖子流**完全滑不动** —— 从 y=1300/1600/1900/2200 上滑，卡片行顶恒为 1178px，纹丝不动。

排查路径（单变量，各一轮装机）：

| 试法 | 结果 |
| --- | --- |
| 怀疑栏体/遮罩盖住触摸区 | ❌ 排除：卡片行顶 1190px 起，从 y=1400（栏底 1209 之下）上滑同样不动 |
| `enableScrollEffect: false` | ✅ 恢复滚动（1190 → 159），但标题行**不再糊**，穿上来的卡片在「我的」三个字后面清晰可见 → 观感回退 |
| `enableScrollEffect: true` + `COMMON_BLUR` | ✅ 滚动正常（1190 → 172），标题行仍是干净的磨砂 plate |

→ **根因**：`GRADIENT_BLUR` 是「随滚动进度算渐变」的效果，必须知道滚了多少 —— 没有 `bindToScrollable` 就没有滚动源，组件把整条滚动链握在手里不往下传，子 `Scroll` 直接不响应。**`COMMON_BLUR` 是常量模糊，不需要滚动源，所以不受影响。**

**结论（写进防漂移）**：`GRADIENT_BLUR` 与 `bindToScrollable` 是**一对**，不能只上一个。要么两个都上（首页/圈子/消息的做法），要么用 `COMMON_BLUR`。「我的」当前取 `COMMON_BLUR` —— 它迁移前本来就是常量高斯（外层 `backgroundEffect: {radius: 50}`），不是渐变，所以这反而是等价替换而不是降级。想要和另外三 Tab 一致的渐变爬坡，就得把 ProfilePage 四条分页 `Scroller` 交回 Index 绑上（HomeTab 的 `boundFeedScrollers` 范式，注意那个「不可在 build 里每次返回新数组」的坑）。

复测附带确认：下拉刷新正常（「刷新中…」指示器 opacity=1，落在 y=1153）；切「我收藏」栏体 928→1064px、子分段 1211..1262、首卡行顶 1327（在子栏控件底 1299 之下 28px）。

#### 7.6.13 「栏内起滑抓不到列表」不是迁移引入的 —— 新旧两版装机同口径对比

用户反馈「还是滑不上去，无法穿底资料区」。逐一起滑点实测（每次冷启动复位，上滑 400px，2.5s 后读首图块顶）：

| 上滑起点 y | 新版（HdsNavigation，栏底 1209px） | 旧版（外层 Navigation STACK，栏底 ≈1075px） |
| --- | --- | --- |
| 500（栏内） | ✗ 恒位 1193 | ✗ 恒位 1111 |
| 700（栏内） | ✗ 恒位 1193 | ✗ 恒位 1111 |
| 900（栏内/栏边缘） | ✗ 恒位 1193 | ✓ → 497 |
| 1100（栏下） | ✓ → 543 | ✓ → 439 |
| 1300 / 1500 | ✓ → 566 / 543 | ✓ → 493 / 439 |

→ **两版同一条规律：手势起点必须落在栏底之下，栏内起滑一律不响应。** 差别只是新栏比旧栏高 134px（43vp ≈ 屏高 5%），来自官方 MINI 标题行 56vp（旧自排 48vp）+ `bottomBuilder` 居中上留白 14.7vp。**不是回归，是「资料区住在标题栏里」这个既有决定的固有代价**（迁移前资料区也在栏体里）。

**试过且无效的解法（别再走）**：给栏体根 Column、资料卡背景 `Image`、遮罩 `Column`、`Stack`、`stackBuilder` 标题行逐一挂 `hitTestBehavior(HitTestMode.Transparent / None)` —— 装机复测起滑点 700/900/1100 **全部仍然不响应**。原因：ArkUI 的滚动手势只在「touch-down 命中的子树及其祖先链」里进竞技场，列表不是标题栏的祖先，`Transparent` 只影响命中测试、不会把 pan 手势跨子树路由过去。要解只能把资料区搬出栏体（代价见 §7.6.9 那条视觉顺序）。

**测旧版的办法留档**：旧版 `Index.ets` 与当前组件已不兼容（另一会话把 `slidePosition` 从 HomeTab/ProfilePage/ImmersiveSegmentBar 摘了），取 `git show HEAD:...Index.ets` 后删掉那三处 `slidePosition:` 实参即可编译，装完记得换回来。

#### 7.6.13b 更正 7.6.13：死区不是「5%」，是 41% —— 结构本身偏离了官方

2026-10-21 用户再次反馈「内容又滑不上去了」。同一 build 逐落点重测（每次先复位到列表中段，保证探针一定有行程；向下拖 500px）：

| 起滑 y | 300 | 600 | 900 | 1100 | 1250 | 1500 | 1900 | 2300 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 列表位移 | 0 | 0 | 0 | 0 | 595px | 601px | 595px | 599px |

**死区边界 = `TitleBar` 节点底边 1209px**，即状态栏以下、整条栏体（资料卡 + 主分段栏 + 子分段栏）**全部吃掉手势**，占屏高 41%。7.6.13 那句「差别只是新栏比旧栏高 134px（≈5%）」是拿栏底坐标相减得出的，不是量出来的响应边界；按响应边界量，旧版翻转点在 700~900 之间、新版在 1100~1250 之间，**实际恶化约 300~400px（10~13% 屏高）**。结论从「不是回归」更正为「机制不是新的，但代价被结构放大了一个量级」。

**官方参照系给出的答案是「资料区根本不该住在栏体里」**（同机同版本 智慧生活「我的」节点真值）：

| 节点 | 官方 | 我们 |
| --- | --- | --- |
| `TitleBar` | `[0,106][1136,281]` —— **只有 56vp 标题行** | `[0,106][1136,1209]` —— 1103vp·px，装了整个资料区 + 两条分段栏 |
| `Scroll` | `[0,106][1136,2690]` —— 从状态栏下沿起，**头像/昵称/浏览·获赞·关注·粉丝四格（y 328..490）都在 Scroll 里** | 列表让位到栏底之下 |
| 死区 | 175px（5.6% 屏高） | 1103px（41% 屏高） |

官方的穿底靠的是「Scroll 顶到 y=106 + 薄栏浮在其上 + 栏体模糊」，不是「把内容搬进栏体」。`HdsNavigationAttribute` 全量方法（`titleBar` / `titleMode` / `hideTitleBar` / `divider` / `ignoreLayoutSafeArea` / `systemBarStyle` / `navBarPosition` …）**没有任何手势穿透开关**，7.6.13 也已证明 `hitTestBehavior` 改不了 pan 的跨子树路由 —— 所以这一条只能靠结构解决。

#### 7.6.14 栏体模糊档位：只有 `IMMERSIVE_GRADIENT_BLUR` 能顶替旧版整条均匀高斯





用户反馈「能穿底了，但资料区底部是实色的，没有之前的模糊」。装机逐档量同一条带（x∈[20,140]，避开分段栏控件本体；栏内应低=糊、栏底之下应高=锐）后定位：**是我自己换档换掉的**。

SDK 原文（`@hms.hds.hdsBaseComponent.d.ets:1099`，`blurRadius` @since 6.1.0(23)）：

> Blur radius of the title bar in the navigation component. **The setting takes effect only in `ScrollEffectType.GRADIENT_BLUR` mode and `ScrollEffectType.IMMERSIVE_GRADIENT_BLUR` mode.**

四档实测（栏体总高 353vp，栏底 1209px）：

| 档 | 栏内 y=1080/1100/1180 梯度能量 | 栏外 y=1280 | 列表可滑 | 判定 |
| --- | --- | --- | --- | --- |
| `COMMON_BLUR` | 平色 plate，`blurRadius` 不生效 | — | ✓ | ✗ 整条栏画成平色，穿上来的内容一点不糊 |
| `GRADIENT_BLUR` | **14.1 / 16.4 / 11.4**（= 文字仍锐） | 2.1 | ✓（需绑 Scroller） | ✗ 空间渐变：顶部糊、往下衰减，**栏一高下半条就漏** |
| `IMMERSIVE_GRADIENT_BLUR` | **0.36 / 1.82 / 1.86** | 6.18 | ✓ | ✅ 整条糊、栏底之外锐 —— 与旧版 `backgroundEffect{radius:50}` 观感一致 |

→ 定档 `IMMERSIVE_GRADIENT_BLUR` + `backgroundStyle.blurRadius = 50`（半径沿用迁移前外层标题栏实测值）+ `bindToScrollable`。

**「栏越高、渐变档越糊不住」是这条的实用判据**：首页/圈子/消息的栏只有 56 + 分段行 ≈ 140vp，`GRADIENT_BLUR` 的衰减区还没走完就到底了，所以它们看不出问题；「我的」把资料区也装进栏体后总高 353vp，同一档就在下半条露出锐利内容。**别照抄兄弟 Tab 的档位，按栏高选。**

**并且 `GRADIENT_BLUR` / `IMMERSIVE_GRADIENT_BLUR` 都必须配 `bindToScrollable`**（§7.6.12 的滚动锁死）。本页做法：Scroller 池由 Index 造好**往下传**给 `ProfilePage`（`scrollers: Scroller[]`，下标 0..3 = 四条分页、4 = 收藏夹子视图），`@Watch(profileTabIdx / profileBookmarkSubTab)` 把当前可见那条同步进 `@State boundProfileScrollers` 再绑出去 —— 沿用 HomeTab「不可在 build 里每次现算新数组」的告警。

**7.6.14 补：改生产页配方必须同步验证页，否则两页观感不可比（用户实测抓到）。**
把「我的」换成 `IMMERSIVE_GRADIENT_BLUR` + `blurRadius 50` + 终点 32vp 时没动验证页（它仍是 `GRADIENT_BLUR` / 不设半径 / 终点 64vp），于是两页顶栏圆钮在「内容穿过去时」明显不同：验证页底板均匀发白、生产页底板透绿发暗。

把验证页对齐到同一配方后，改用量「圆面 L − 圆外紧邻底板 L」（与栏背后是什么内容无关）复测：

| 帧 | 圆面 L | 圆外底板 L | **圆 − 底板** |
| --- | --- | --- | --- |
| 生产「我的」 | 198.0 | 204.1 | **−6.1** |
| 验证页（对齐后） | 234.3 | 240.0 | **−5.7** |

→ 材质行为已一致。剩下的绝对差（198 vs 234）是**栏背后内容不同**造成的（生产页是一张绿的树照，验证页是浅色色卡），不是配置差。**判两页观感是否一致要用「圆 − 底板」这类相对量，别比绝对 L。**

仍未对齐的一项：生产页底是 `ds_canvas`（浅 `#FFFFFF`），验证页是 `materialCanvas`（浅 `#F1F3F5`）—— 即决策点 E 候选 0，还没拍板。

#### 7.6.15 推翻 7.6.14 补的「两页已一致」：验证页是矮栏，不能当高栏页的参照

7.6.14 补里我用「圆面 L − 圆外底板 L」得出两页材质行为已一致 —— **那个结论是错的，两个原因：**

1. **取样把图标本身算进去了。** 生产那颗是齿轮（大块深色笔画）、验证页那颗是四点（小点），圆盘均值被图标面积拉偏，一度得出「生产圆比底板暗 6.1 L、验证页亮 9.2 L」的假符号翻转。改用**避开图标的圆内环**（半径 42..55px，图标半径约 37px）后符号就翻回来了。
2. **更要命的：验证页当时 `enableComponentSafeArea: true`，`Scroll` 起点 = 栏底 431px，内容根本不会从按钮下面经过** —— 那个指标测的是「没有东西穿过时」的两页，当然一致。它页顶那条注释写着「滚动时穿到标题栏下方，给渐变模糊/材质提供可采样的彩度」，但结构上一直做不到。改 `false` 并补 104vp 垫高后才真正可测。

用**同页内**的「圆内环彩度 ÷ 紧邻底板彩度」（不受跨页内容差异影响）重测：

| 页 | 栏高 | 底板彩度 | 圆内环彩度 | **透传比** | 圆−底板 L |
| --- | --- | --- | --- | --- | --- |
| 验证页（矮栏） | 104vp | 6.5 | 3.1 | **47%** | +9.4 |
| 原型页（高栏） | 353vp | 13.4 / 15.2 | 12.2 / 10.2 | **91% / 67%** | +8.5 / +12.6 |
| 生产「我的」（高栏） | 353vp | 10.0 | 8.3 | **83%** | +17.9 |

已排除的因子（各一轮单变量装机）：`scrollEffectType`、`blurRadius`、`blurEffectiveEndOffset`、**`materialLevel`**（EXQUISITE→ADAPTIVE：242.9±0.3/彩度3.1 → 245.9±0.3/彩度3.0，几乎不动）。

→ **透传比与栏高同向**：两页高栏（原型 67~91%、生产 83%）明显比矮栏验证页（47%）透。`IMMERSIVE_GRADIENT_BLUR` 的合成强度看起来是**按栏高归一**的 —— 按钮距栏顶的绝对像素两页相同（25..150px），相对位置却差 3.4 倍。**所以验证页（104vp 矮栏）不能当「我的」（353vp 高栏）的观感参照**，之前拿它对齐是拿错了基准。

**尚未定论**：生产页 `圆−底板 = +17.9 L`，比电话 App 那颗的 +7 L 偏大 —— 生产那颗可能太亮/太对比。要判对错只能回到唯一的地面真值：**原生电话 App，卡片从其按钮下方滚过时同口径取帧**。

#### 7.6.16 地面真值：官方 HDS 圆穿底时透传比 86% —— 生产页 85% 命中，验证页 47% 才是异常方

`com.huawei.hmos.ailife` / module `phone` 的「我的」页是同一套构造的官方参照：`TitleBar [0,106][1136,281]`（56vp）、`HdsMenuNode [961,106][1086,281]`（与我们同一像素位置）、`Scroll [0,106]`（**它也穿底**）。用它当基准，探针换成**同页内比值**（不受两页背后内容不同干扰）：圆内环彩度 ÷ 紧邻底板彩度，圆内环取半径 0.68R..0.88R（避开图标笔画，也避开 rim）。

| 参照（全部浅色模式） | 底板彩度 | 圆内环彩度 | **透传比** | **圆 − 底板 L** |
| --- | --- | --- | --- | --- |
| 智慧生活官方 HDS 圆 | 19.3 | 16.7 | **86%** | **+11.2** |
| 生产「我的」 | 9.8 | 8.3 | **85%** | **+17.6** |
| 验证页 `HdsMenuVerifyPage` | 6.6 | 3.1 | **47%** | +9.5 |

→ **两件事：**
1. **生产页的透传度（85%）几乎正中官方（86%）；验证页那颗太奶白、太不透（47%）。** 所以「生产页和验证页不一致」是真的，但**该改的是验证页**，不是把生产页往验证页拉。前面几轮拿验证页当基准是拿错了对象。
2. **唯一真实残差：生产页 `圆 − 底板 = +17.6 L`，官方是 `+11.2 L`** —— 我们那颗圆比它周围的栏底板**亮过头约 6 L**。方向对（都是浮起），幅度偏。

> ⚠️ **本节两条结论都已被 §7.6.17 推翻**：那批「透传比 / 彩度 / 明度」指标量的是**透射**，而真正的问题是**折射**（玻璃透镜感）。用错探针得出的「验证页是异常方」不成立 —— 实际是两页当时都缺折射（生产）或都有折射（验证页 EXQUISITE），而 `materialLevel` 才是开关。数据保留仅作方法学反面教材。

**色模判定方法（别再靠肉眼看别的 App）**：智慧生活那页满屏偏暗，容易被误判成「系统已切深色」从而以为跨页对比失效。实测它是**自己的模糊封面**。可靠判据是打开我们 App 设置页取亮度直方图 —— `bg_primary` 浅 `#FFFFFF` / 深 `#121212`，97% 像素落在 L 240..256 即为浅色。本轮确认：**系统一直是浅色，上面三行数据同色模可比。**

**探针脚本**：`/tmp/native-phone-study/probe.py <jpeg> <圆心x> <圆心y> <圆半径px> [标签]`。

**下一步（未做）**：把生产页的 `圆 − 底板` 从 +17.6 压到 ≈+11，候选是 `blurRadius`（现 50）与栏级材质的组合 —— 这是唯一还没试过的旋钮；验证页则应改成与生产页同配方后重测，确认它也落到 85% 附近。

#### 7.6.17 「折射」vs「透过去」：`materialLevel` 是唯一开关，ADAPTIVE 不出玻璃感

用户描述：验证页那颗圆在内容穿过时「像一块圆润的**玻璃折射**」，生产「我的」那颗「只是**透过去**」。这是两种不同性质 —— 折射是几何弯折（透镜），透过去只是半透。前面 §7.6.15/16 那些彩度、明度指标量的都是后者，所以量不出差别，**指标选错了三次**。

决定性实验是同机同构造只差一个字段的单变量（验证页 `HdsMenuVerifyPage` EXQUISITE ⇄ ADAPTIVE 各装一版，让色块穿到按钮底下取帧）：

| 帧 | 观感 |
| --- | --- |
| 验证页 **EXQUISITE** · 蓝块压在圆下 | 深蓝**玻璃珠**：边缘一圈暗色折射环、内部颜色被汇聚、左侧红块在圆边处明显折弯 |
| 验证页 **ADAPTIVE** · 同位 | 细描边空心圈，蓝只是均匀透过去，无透镜边 |
| 生产「我的」**ADAPTIVE**（旧落地） | 同右 —— 就是用户指出的那个问题 |
| 生产「我的」**EXQUISITE**（已改） | 绿色玻璃珠，与验证页 EXQUISITE 同性质 ✓ |

→ **`hdsMaterial.MaterialLevel`：EXQUISITE(0) 才带折射，ADAPTIVE(10) 退化为普通半透。** 「ADAPTIVE = 系统会挑最好档」这个理解是错的。

**已改**：`Index.ets` 的 `profileSystemMaterial()` 由 `HDS_MATERIAL_LEVEL_ADAPTIVE` → `HDS_MATERIAL_LEVEL_EXQUISITE`（新增常量，仍走数值字面量，不 import `hdsMaterial`）。

**⚠️ 这条推翻了 `immersiveMaterial.ets:55` 的旧规范**「一律交给系统自适应，禁止在低端设备写死 EXQUISITE」。原注释已在代码里改写为实测结论。**代价要说清**：放弃「低端机由系统自动降级」这层保护，而 `materialLevel` 没有能力查询接口 —— 只能显式取舍。若日后要按机型分档，需要另找能力判据，不能靠 ADAPTIVE 兜底（它兜出来的是另一种观感）。

**同类残留（未动，待拍板）**：底部悬浮 Dock 仍用 `cardTokens.ets` 的 `DOCK_MATERIAL_LEVEL = 10`（ADAPTIVE），同样不会有折射。那是已上线且过审的面，改它属于新的取舍。

**方法学教训（写进防漂移）**：观感类差异先让用户/自己**用语言定性**（「折射」「弯折」「发虚」「透过去」），再倒推该量什么几何量。我连着三轮用彩度/明度这类「透射」指标去找一个「折射」问题，全是无效功。

#### 7.6.18 分段栏轨道「跟其他组件完全不是一套」：真因是我们自己盖上去的 `ULTRA_THIN`

用户反馈：「我的」页顶部分段栏的样式与同页其他组件全然不一致。浅色真机复现（`p2.jpeg` / `now.jpeg`）：

| 同一条栏上的相邻件 | 轨道/面明度 | 观感 |
| --- | --- | --- |
| 分段栏轨道（`ULTRA_THIN`） | L63（深色模式）/ 深浅随背板漂移（浅色模式） | 深色玻璃 |
| 紧挨其上的 草稿箱 / 废纸篓 | L98 / L105 | 浅色玻璃 |
| 顶栏官方圆钮 | L68 | 深色玻璃 |
| 分段栏选中面 | **L238** | 近白实心块 |

参照对象（智慧生活 场景页「我的 \| 探索」，深色模式同机同帧）：轨道 L79.6、选中面 L84.5、页面底 L69.6 —— **选中面只比轨道亮 5 L**，整条栏是「比底板略亮的一层磨砂」。第 7.7 节浅色档同样是 +3 / +9 的微弱差。

**真因**：`ImmersiveSegmentBar` 一直在传 `opts.backgroundSystemMaterial = uiMaterial.ImmersiveMaterial({style: ULTRA_THIN, …})`。`ULTRA_THIN` 薄到几乎只透背板，于是：

1. 轨道明度完全由身后内容决定 —— 同一条栏在浅色页底上发白、压到深色卡片上转黑并吸走色相（真机 `ab2/ab3`：子分段栏左半被绿叶染成浅绿、右半压在黑卡上变灰黑，主分段栏同帧仍是白的）。
2. 选中面是官方固定浅色，轨道却被背板拉黑 → 两者不再像同一层材质，选中块炸成 L238 的实心白斑。

**修法（官方方案，非自绘）**：不传 `backgroundSystemMaterial`。应用级 `module.json5` 已配 `ohos.arkui.UIMaterial.state = enable`，而 `uiMaterial.MaterialState.ENABLE` 的文档明确把 `SegmentButton` 列入「默认启用沉浸材质」清单 —— 交回官方即得系统默认档。组件新增 `overrideTrackMaterial`（默认 `false`）承载这个开关。

复测（`t_profile_full` / `w2_bar` / `v1_home_rest` / `t_msg_top`）：主/子分段栏、首页、消息四处轨道一致，选中面回落到「比轨道略亮的白」，与第 7.7 节 +3/+9 的官方关系吻合。

**⚠️ 不能一刀切：`ULTRA_THIN` 是 `lightContent` 的前提。** 首页把默认材质拿掉后，滑到位那一帧轨道被提亮成浅绿，而 `lightContent: true` 仍把标签刷白 → **白字压白滑块，选中标签整条消失**（`sc1_top`）。所以 `HomeTab` 显式传 `overrideTrackMaterial: this.brandOnBlur`，与 `lightContent` 同值。二者的耦合已写进组件注释与防漂移第 16 条。

**顺带查出的既有缺陷（未修，待拍板）**：
1. **首页滑到位 + 亮色背板 = 白字压白滑块。** 与本轮无关（该帧 `brandOnBlur=true` → 仍走 `ULTRA_THIN`，与改造前逐像素同构）。根因是 `lightContent` 只看「模糊是否到位」，不看背板实际明度，遇到亮图（绿叶）就翻车。
2. **「我的」页顶栏两颗官方圆钮在浅色下几乎看不见**：`w1_profile` 圆面 L252 / 页面底 L255，仅 3 L 差；深色下同位置圆面 L68 对比正常。原因正是第 7.6.8 节记过的「纯白底把描边和落影一起抹平」—— 当时为此造的 `ds_material_canvas`（浅 `#F1F3F5` / 深 `#121212`）只落在两张原型页上，生产 `ProfilePage.ets:932` 仍是 `ColorTokens.canvas` = `#FFFFFF`。

**未覆盖**：`SearchResultPage` / `CircleDetailView` / `ReportAdminPage` 三处宿主本轮未上机复测（都不传 `lightContent`，按推理应落在与消息页同一档）。

#### 7.6.19 已落地：资料卡搬出栏体，「我的」改整页一条 List + 吸顶分段栏

按 §7.6.13b 的官方口径重做。结构：

```
HdsNavigation
  titleBar: content{ stackBuilder 衬线「我的」, content.menu 官方圆钮 }   ← 只有 56vp，无 bottomBuilder
  ProfilePage
    Refresh({ refreshing: $$… })
      List({ scroller })
        ListItem            → 资料卡（Index 以 @BuilderParam heroHeader 下发）
        ListItemGroup(header: 主分段 +（子分段）)  → List.sticky(StickyStyle.Header)
          ListItem          → 当前分段的帖子 / 收藏夹列表
      .contentStartOffset(statusBarHeight + 56)
```

真机节点：`TitleBar [0,106][1136,281]`（与智慧生活「我的」`[0,106][1136,281]` **逐像素同尺寸**）、`List [0,106][1136,2690]`（穿底保留）、资料卡项 `[0,281][1136,984]`。

**死区复测（同 §7.6.13b 的探针，每落点前先复位到列表中段保证有行程）**：

| 起滑 y | 300 | 600 | 900 | 1100 | 1250 | 1500 | 1900 | 2300 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 改造前 | 0 | 0 | 0 | 0 | 595 | 601 | 595 | 599 |
| 改造后 | 608 | 598 | 585 | 613 | 603 | 588 | 597 | 594 |

盲区只剩 56vp 标题行（y<281，占屏高 6.5%，与官方同档），此前是 1209px / 45%。

**两个新踩的坑**：

1. **`contentStartOffset` 必须含 `statusBarHeight`**。`List` 节点报 `[0,106]` 是**裁剪后的可视框**，布局原点仍在窗口 0 —— 防漂移第 12 条换了个组件重演一遍。只给 56vp 时资料卡项落在 y=175px，正压在标题栏（106..281）底下、头像被「我的」那行切掉半张。
2. **`ListItemGroup` 的 header 默认透明，吸顶后列表从它背后穿过去**。真机实测「我发布/我收藏/我赞过/我评论」四个标签直接叠在卡片标题上，读不了 —— 组头必须自带底。**但不能垫实色**：垫 `ColorTokens.canvas` 那一版真机看下来是一条实心白板压在列表上，分段栏要的是「悬浮」，用户当场打回。
   正确配方照抄底部 Dock（`BottomTabBar.ets:260`）：`backgroundBlurStyle` 常驻，实色只在 `!isImmersiveLightSenseSupported()` 时兜底。**不能用 `systemMaterial`** —— `immersiveMaterial.ets:182` 已记过：挂在内容区普通组件上属于官方生效范围外、完全不渲染，而栏体 `systemMaterialEffect` 只覆盖 56vp 那一格。

   **模糊档位实测**（同一滚动位置、同一深色卡片背板，逐标签算 WCAG）：

   | 档位 | 玻璃带均值 | 我收藏 | 我赞过 | 我评论 | 判定 |
   | --- | --- | --- | --- | --- | --- |
   | `GlassBlurStyle.Card`（BACKGROUND_REGULAR） | 160 | 4.51 | 4.50 | **4.26** | 未选标签踩在/低于 AA 线 |
   | `GlassBlurStyle.Floating`（BACKGROUND_THICK） | 153 | 4.51 | 4.50 | **4.26** | 横向不均度 28.7→25.2，对比度没救回来 |
   | **`BlurStyle.COMPONENT_THICK`（当时采用，后被 §7.6.23 的 COMPONENT_REGULAR 取代）** | **199** | **4.98** | **4.94** | **4.80** | 全部过 AA |

   根因：`BACKGROUND_*` 几乎原样透出背板（背板卡片 std 55.7，糊完还剩约 45%），暗图一压上来标签就落在暗底上。`COMPONENT_*` 是**组件表面**系列、自带系统着色，把玻璃带抬到 L199（对照官方浅色档轨道 L246）。别指望用参数补：`BackgroundBlurStyleOptions` 本 SDK 只有 `policy` / `inactiveColor`，**没有 `adaptiveColor` / `backgroundColor` 这类「保持提亮」的官方入口**，`AdaptiveColor` 也只有 `DEFAULT`/`AVERAGE`（后者往背板均值走，方向相反）。
   代价记清：`COMPONENT_THICK` 比 `BACKGROUND_THICK` 更不透明，「透过去」弱一档，换来 AA 达标。


**换来的代价，说清不藏**：
- 四个分段的**横向跟手切页没了**（原 `Swiper` 四页），改为点击切换 —— 这是「单条 List + 吸顶栏」这条路的直接后果，用户拍板时已选定。
- 四条列表合成一条，**逐分段独立滚动位不复存在**。切分段/切「帖子↔收藏夹」一律 `scrollTo(0,0)` 回顶，否则会停在上一段的滚动深度上，看着像列表串页。
- 资料卡现在会随滚动消失（官方行为），不再是常驻。

**顺带修好的**：吸顶组头 + 穿底保留后，顶栏两颗官方圆钮在浅色下重新有了可采样的背板（`k1_view` 圆面描边与图标都回来了）。§7.6.18 记的那条「纯白底抹平圆钮」在「我的」页不再复现，但 `ColorTokens.canvas` 仍是 `#FFFFFF`，其它纯白底页上的圆钮照旧会发虚 —— 决策点本身没撤。

#### 7.6.20 顶栏常年模糊 + 浅色下圆钮白底白图标：两处都栽在同一个配置对象的两个槽位上

用户一次报两个缺陷。逐一定位后，根因分别是 `TitleBarStyleOptions.originalStyle` 里多写的一个字段、和压根没写的一个字段。

**官方语义（`@hms.hds.hdsBaseComponent.d.ets` 原文）**：
- `originalStyle` = "titleBar **oringinal style before scroll effect take effect**" —— 静止态
- `scrollEffectStyle` = "titleBar **final style after scroll effect take effect**" —— 滚到位后
- `blurEffectiveStartOffset` / `blurEffectiveEndOffset` = 两者之间的过渡区间

**缺陷 A：顶栏一直是模糊，应该滚动才模糊。**

根因：`originalStyle.backgroundStyle.blurRadius = 50`。这一行是 §7.6.14 那次「资料区底下是实色的、没有模糊」的修法 —— 但那时资料卡**住在栏体里**，栏必须自带模糊才有玻璃底。§7.6.19 把资料卡搬进列表之后，静止态栏下只剩页面画布，这个 blurRadius 就变成了「要求静止态先糊」，纯害无益。

修法：删掉这一行（半径交回 scrollEffect 的官方默认），与已上线的「消息」页对齐 —— `MessagePage.ets:1262` 同一个槽位只给 `backgroundColor`。

真机证据（栏体带 y 120..265 / x 300..780 的灰度不均度）：

| 状态 | 修复前 std | 修复后 std |
| --- | --- | --- |
| 静止 | 1.5（带模糊晕） | **0.5**（干净白） |
| 滚动 | — | 15.9（内容透上来、被糊） |

**缺陷 B：浅色模式右上角两颗圆钮是白图标压白底板，完全看不见。**

实测静止时圆盘 L252.1 / 图标字形 L250.0 → **对比度 1.02:1**（图形下限 3:1）。

根因：`content.menu` 的图标色**默认就是白的** —— HDS 的约定是「静止态那条透明栏压在 hero 媒体上，所以给白图标」。我们这条栏静止时压在页面画布（浅色 L255）上，于是白压白。
最容易看走眼的是：**同一条栏里左侧「我的」是黑的**。那是因为 `profileStackTitle()` 自己写了 `.fontColor(ColorTokens.primary)`。标题走 `titleStyle`、菜单走 `menuStyle`，两个槽位互不相干 —— 只有 `menuStyle` 一直没人管。

官方出口：`originalStyle.contentStyle.menuStyle.iconColor`（`menuStyle` 只暴露 `backgroundColor` / `iconColor` / `textColor` 三个纯色，见 `HdsMenuVerifyPage.ets:158`）。填 `ColorTokens.primary` 而不是常量，深色模式下画布是 `#121212`、图标要跟着翻白。

| 圆钮 | 修复前 | 修复后·静止 | 修复后·滚动 |
| --- | --- | --- | --- |
| 分享 | 1.02:1 不可见 | **16.79:1** | 18.31:1 |
| 设置 | 1.03:1 不可见 | **17.79:1** | 19.09:1 |

参照系（官方智慧生活首页 TitleBar 三颗钮，静止态）：圆盘 L212~219、字形 p5 27/78 → 14.7:1 / 7.2:1。我们修复后圆盘 L232/222，与参照同为「比画布明显暗一档的浮起面」。

**未验**：深色模式这两项没复测（`iconColor` 用的是成对 token，按构造应当自动翻转，但任务 #13 仍未结）。





#### 7.6.21 模糊只认 `originalStyle.blurRadius`；`scrollEffectStyle.blurRadius` 与 `maskExtraHeight` 实测均为空操作

承接 §7.6.20。把 blurRadius 从 `originalStyle` 摘掉之后，「内容穿到 Title 行」反而**不糊了**，于是补做一轮逐档实测。

**探针教训**：先用「Title 行内 edge 能量」当模糊判据，结果是**内容自带细节**在骗我 —— 平滑照片糊与不糊 edge 都低，卡片文字锐利时 edge 高，同一指标在相邻两帧之间来回跳（0.33 → 4.59 → 0.59）。换成**同帧内「栏内 vs 栏下对照」的尺度无关锐度 `edge/std`** 才可分辨（u1 栏内 0.0062 vs 对照 0.0602 = 糊 10 倍；u4 栏内 0.0633 vs 对照 0.0496 = 没糊）。

**三个参数的真实效力**（同一页、同一装配，逐项单变量装机）：

| 配置 | 结果 |
| --- | --- |
| `originalStyle.backgroundStyle.blurRadius = 50` | **唯一有效**。栏内起雾、内容穿上来被糊 |
| `scrollEffectStyle.backgroundStyle.blurRadius = 50` | **空操作**。五档轻滑逐帧 std/edge 与不加时逐项相同（0.33→0.34、1.26→1.26、2.15→2.11、4.59→4.56） |
| `backgroundStyle.maskExtraHeight = 0`（默认 32） | **空操作**。栏底之下雾化深度两版都是 **120px**（锐利恢复到 y=401），逐行曲线完全重合 |

所以 §7.6.20 那句「模糊只放 scrollEffectStyle」的推断**是错的**：官方文档说 `originalStyle` 是特效生效**之前**的样式，但本页实测 blurRadius 只有挂在这一格才出图。合理解释是 `systemMaterialEffect` 接管了表面渲染、只读 original 那一格 —— 未取证，标 tentative。

**最终形态**：`originalStyle.backgroundStyle = { backgroundColor: Transparent, blurRadius: 50, maskExtraHeight: 0 }` + `blurEffectiveStartOffset: 0`。真机：静止态栏内 std **0.5**（干净白，因为栏下是均匀画布，糊白底=白底）、滚动后 std **28.7** 且内容穿进来即被糊；圆钮静止 17.3/18.4:1、滚动 13.3/16.1:1。

**未解决**：`maskExtraHeight` 压不住那条 **120px 下溢雾化带**（静止时资料卡顶边仍被糊到 y≈401）。已连试 3 个入口无变化，按「三次失败先质疑结构」停手，未继续猜第 4 个。候选方向：改 `GRADIENT_BLUR` 档、或把 `blurEffectiveStartOffset` 抬到 >0 让静止态完全不进特效。

#### 7.6.22 落地：模糊半径由列表偏移驱动 —— 官方声明式表达不出「滚起来才糊」

§7.6.21 的三个空操作把路堵死了：唯一有效的 `originalStyle.blurRadius` **无条件生效**，静止态也照糊，于是「摘掉它 → 穿进来不糊」和「装回去 → 常年糊」两头必占其一。用户两轮反馈正好各命中一头，说明这不是调参问题。

**结论**：「静止不糊 / 内容一进 Title 行就糊」这个要求，`TitleBarStyleOptions` 里没有任何声明式写法能表达。改由滚动源驱动：

- `ProfilePage` 的 List 加 `.onDidScroll`，把纵向偏移经 `onListScroll` 回调上抛；
- `Index` 存 `@State profileBarScrolled`，**只在翻转那一帧写入**（逐帧写会让标题栏配置逐帧重建）；
- `blurRadius: this.profileBarScrolled ? PROFILE_BLUR_RADIUS : 0`。

判据不需要阈值：内容顶边静止时正好贴在栏底（`contentStartOffset = 状态栏 + 56`），偏移一 >0 就有内容进 Title 行。

**真机结果**（浅色，同机同账号）：

| 状态 | 观感 | 圆钮对比度 |
| --- | --- | --- |
| 静止 | 栏内干净白（std 0.2），资料卡顶边**锐利** —— §7.6.21 那条 120px 下溢带随之消失 | 17.3 / 18.4:1 |
| 滚动后 | 穿进 Title 行的卡片被糊成柔和色块，栏底以下依旧锐利 | 16.9 / 16.7:1 |

**顺带结掉 §7.6.21 的未解决项**：那条下溢带不是靠 `maskExtraHeight` 压的（它无效），而是静止态半径归零后根本没有可溢的模糊。任务 #23 关闭。

**探针教训补一条**：量「模糊有没有下溢」不能用「栏下若干行的 edge 能量」—— 资料卡顶部本来就是一面平滑的墙，低 edge 是内容不是糊。同帧对照也会骗人。最终判定回到看渲染帧：`w0_strip` 锐利、`v0_strip` 发糊，一眼可分。


#### 7.6.23 吸顶分段栏「悬浮」：官方轨道当不了表面，能用的只有 COMPONENT 系列薄档

用户诉求：吸顶分段栏要「通透玻璃、内容透得过来」，不要实心板。逐条装机试下来：

**先否掉「让官方 SegmentButton 轨道自己当玻璃」这条前提**（两次尝试，同一结论）：

| 尝试 | 结果 |
| --- | --- |
| 行不垫任何底，只留应用级默认轨道材质 | 轨道压在内容上方**几乎不出面** —— 只有选中滑块可见，卡片文字锐利透上来与「我收藏/我赞过/我评论」叠字（`g0_view`） |
| 行不垫底 + 轨道材质显式改 `ImmersiveStyle.REGULAR` 厚档 | **同样不出面**（`h1_view`）。换材质档救不了轨道 |

所以表面只能由**那一行**给。剩下的问题纯粹是选哪一档 `backgroundBlurStyle`：

| 档位 | 吸顶带 | 未选中标签 WCAG | 判定 |
| --- | --- | --- | --- |
| `BACKGROUND_REGULAR`（`GlassBlurStyle.Card`） | L160 | 4.51 / 4.50 / **4.26** | 掉出 AA |
| `BACKGROUND_THICK`（`GlassBlurStyle.Floating`） | L153 | 4.51 / 4.50 / **4.26** | 掉出 AA（只把横向不均度 28.7→25.2） |
| `COMPONENT_THICK` | L199 | 4.80 / 4.94 / 4.98 | 达标，但偏实、悬浮感弱 |
| **`COMPONENT_REGULAR`（已采用）** | L208 / std 35.4 | 4.93 / 5.16 / 5.16 | 达标，且左右两侧能看到背板透上来的暖调与灰调 |

`COMPONENT_*` 与 `BACKGROUND_*` 的差别是这一档的命门：前者自带系统着色，所以「透」不是把背板原样搬上来（那会毁对比度），而是**透出明暗倾向**；后者原样透，深色卡片一压就 4.26。

⚠️ **对比度那一列不能跨版本直接比**：`COMPONENT_THICK` 与 `COMPONENT_REGULAR` 是在不同滚动位、不同背板内容下各测一次的，不是同帧对照。能下的结论只有「REGULAR 在它自己那一帧过 AA 且肉眼更透」，不能下「REGULAR 比 THICK 高 0.2」。要定量得同帧 A/B。

**探针教训（第二次踩同一类坑）**：用「标签框内最亮像素当底色」算 WCAG，在**没有底板**的那一版给出了 11~14:1 的漂亮数字 —— 而真实缺陷是文字压文字的**遮挡**，明度对比度天生看不见它。同帧内容区 std 四张完全一致也暴露了列表根本没滚（帖子数少，早早到底）。判「有没有叠字」只能看渲染帧。

**下一个可试点**：`COMPONENT_THIN` 更透，但会更靠近 4.5 那条线；再往下就只能回到「浮起胶囊」（圆角+描边+落影，与底部 Dock 同套），那条不靠通透、靠 Z 轴表达悬浮。


#### 7.6.24 收口：分段栏不吸顶，跟资料区一起滚走 —— 需求消失而不是被满足

§7.6.19 / §7.6.23 两节把「吸顶分段栏要悬浮玻璃又要过 AA」这条来回试了五版（实色底板 → BACKGROUND_REGULAR → BACKGROUND_THICK → COMPONENT_THICK → COMPONENT_REGULAR → 摘底只留轨道 → 轨道换厚档），**没有一版同时满足「通透」和「标签可读」**。用户最后换了个方向：不要吸顶，让分段栏跟着资料区一起滚走。

这个方向把问题**消掉**而不是解掉：

- 不吸顶 → 这一行不需要自给表面 → 不需要 `backgroundBlurStyle`，也就不存在「透 vs 可读」的取舍；
- 分段栏绝大多数时间直接站在页面画布上，官方 `SegmentButton` 轨道在画布上的表现早已量过并认定与原生同档（§7.6.18 / §7.7：轨道 L246 对画布 L243、滑块 L255）；
- 滚起来时它从标题栏底下穿过，被栏体渐变模糊糊掉 —— 与内容其他部分同一套待遇，不再是个特例图层。

**与官方参照一致**：智慧生活「我的 | 探索」那条分段栏也在 `Scroll` 里（节点 `[62,324][568,425]`），同样跟着滚走。我们绕了一大圈才回到参照系的位置。

**实现**：`ListItemGroup(header:) + List.sticky(StickyStyle.Header)` 换成两个普通 `ListItem`（分段栏一项、列表一项），`profileSegRows()` 上的 `backgroundBlurStyle` / `backgroundColor` 全部删除。

**代价（用户已确认接受）**：
1. 滚深后要换分段得先滚回顶部；
2. 「我收藏 → 收藏夹」子行右侧的管理入口（重命名/删除）会跟着卷走 —— 它当初正是为了不被卷走才从列表头部提到子分段行的。

**真机复验**：分段栏静止位 y=1031（资料卡之下）；点「我收藏」换内容并长出子分段栏；下拉刷新照常触发；滚走后列表直接顶到磨砂标题栏底下。

**教训（进防漂移）**：一个视觉属性如果连续五版都调不满足，先怀疑它是不是**不该存在** —— 吸顶本身才是那个假设，而参照系里它根本不吸顶。


#### 7.6.25 「点分段栏画面跳一下」：两个独立成因，第三个残留未解

用户报：点击分段栏按钮，画面跳一下。按落点量出来是**整屏一致位移**（编辑资料 / 草稿箱 / 我收藏 全部 Δ 相同、各自高度不变），所以不是布局变化，是滚动位被改。

**成因 1（已修，确证）**：上一阶段我自己加的 `onTabIdxChanged` / `onBookmarkSubTabChange` 里各有一句 `scrollers[0].scrollTo(0,0)`。那是**吸顶时代**的产物（分段栏钉在顶上，切段不回顶会停在上一段深度）。分段栏进列表之后，用户能点到它就说明它就在眼前，回顶等于白扔最多 750px 滚动位。删掉两句，子分段那一层实测从跳变变成 **Δ0px**。

**成因 2（已修，2/3 分段确证）**：整页只剩一条 List，切到**未缓存**分段时 `feedBody()` 那一瞬间渲染 loading/空态占位。旧版每条 `Scroll` 的内层 Column 本来有 `constraintSize({minHeight:'100%'}）` 撑着，改单条 List 时丢了 → 列表总高骤降 → 当前滚动位被钳死，数据回来后内容长回去但滚动位回不来，表现为一次性弹跳。
补回 minHeight 时踩到第二个坑：**ListItem 里 `minHeight:'100%'` 不生效**（List 内容高度无界，百分比没有参照物），实测仍跳 +498px；改成父页按 `display.height / densityPixels` 算出的具体 vp 值后，「我赞过」「我评论」冷切均 **Δ0px**。

**判别实验**（用来把两个因素分开）：先把四个分段都访问一遍建立缓存，再测 —— 结果 0→1、1→2、2→1 **全部 Δ0px**。这同时证明：①子分段行出现/消失不是成因；②剩下的跳变只发生在冷加载窗口内。

**残留（未解）**：冷缓存下切「我收藏」仍跳 **+487px**，另两个分段已归零。它的收藏列表接口是三个里最慢的，怀疑在 loading 占位与真实内容交接的某个瞬间总高仍不足以为当前偏移供位。下一步该量的是**跳变的时间形状**（点击后 0.2/0.5/1/2/3.5/6s 逐点采编辑资料的 y 与当前渲染分支），先分清是「加载窗内瞬时抖动、之后自己长回来」还是「永久钳死」，再决定是补高度还是改成切换时保存/恢复偏移。

**教训**：整页从「N 条 Scroll」合并成「一条 List」不是纯渲染改动 —— 每条 Scroll 原有的撑高约束、各自的滚动位、各自的钳制边界都会消失。合并时要把这些隐式约束逐条显式补回，否则会以「跳一下」这种很难归因的形式冒出来。


#### 7.6.26 `systemMaterial` 的生效边界：**TitleBar 子树**出图，NavBarContent 不出图

盘点「把右上角按钮样式复用到所有按钮」时先得出过一个**过宽**的结论（"内容区一律不出图，只有 HdsNavigation 栏才行"）。本轮把四条 Tab 栏逐条上机复测后，边界重画如下 —— 判据是**挂载点在布局树里的位置**，与用的是 `HdsNavigation` 还是普通 `Navigation` 无关：

| 挂载位置 | 节点路径 | `systemMaterial` | 真机证据 |
|---|---|---|---|
| HdsNavigation `content.stackBuilder` / `bottomBuilder` | `TitleBar > HdsTitleBar > StackCustomNode` | **出图** | 首页搜索钮滚动帧：44vp 圆盘 + 白霜面 + 上缘高光（`h_scrolled_bar.png`） |
| 普通 `Navigation().title({ builder })` | `Navigation > NavBar > TitleBar` | **出图** | 搜索面板返回键 / 「搜索」钮：白盘压在 247 灰底上、带接触投影（`sp_bar.png`） |
| 页面主体（List / Refresh / Scroll 内） | `… > NavBarContent > …` | **不出图** | 修前 `ph_pill.png`：木纹与 caster 轮子原样穿过胶囊，内部零模糊 → 只剩一圈描边的透明壳 |

**为什么容易判错**：`TitleBar` 与 `NavBarContent` 是两个平级节点，但代码里都写成"页面顶部那一行"。`CircleDetailView` 的 `circleTitleBar()` 名字带 title、也确实挂在 `.title({ builder })`（`CircleDetailView.ets:403-405`）→ **在生效区内**；`ProfileHeader` 现在住在 `List` 的第一个 `ListItem`（`NavBarContent` 下）→ **在生效区外**。两者名字与直觉刚好相反，所以只能查树、不能看命名。

**两档失败方式**（都发生在真正的 NavBarContent 消费方）：
1. `ProfileHeader:80/117/150` 三颗 —— `backgroundBlurStyle` 被置 `BlurStyle.NONE`、阴影置 0，但**描边留着** → 透明壳。
2. `DesignButton.ets:103` 在材质激活时把**自绘描边也置 0** → 材质没来、描边也没了，**只剩文字**。

**修法**：`ProfileHeader` 删掉 `attributeModifier(materialModifier)` 与三处 `isSystemMaterialActive() ? BlurStyle.NONE : ...`，改回常驻 `backgroundBlurStyle` + 描边 + 阴影 —— 与底部 Dock 同一配方（模糊常驻、实色仅在系统材质不支持时兜底）。修后 `fx_pill.png`：木纹在胶囊内糊开、胶囊外依旧锐利 → 表面真的渲染了。

**判据（进防漂移第 23 条）**：撤兜底表面的权限只属于**祖先链里有 `TitleBar`** 的组件。`isSystemMaterialActive()` 只回答「这台设备支持材质吗」，不回答「我在不在生效区」—— 拿它当撤兜底的判据，设备越新反而越没表面。

**复核后确认无需改动的消费方**：`SearchPanel:170/211/279`、`SearchResultPage:226/239/263`、`UserProfileView:619/645`、`PostDetailView:1615/1631` 全在 `.title()` 内，材质出图，它们的 `isSystemMaterialActive()` 让位逻辑是对的。


#### 7.6.27 五条 HdsNavigation 顶栏的按钮口径盘点：只有一条用了官方 `content.menu`

「复用右上角按钮样式」真正该对齐的范围不是内容区，是**另外四条栏**。逐条上机（`hdc` 1136×2690，px/vp=3.125，静止态纯白画布）：

| 栏 | 栏级 `systemMaterialEffect` | 可操作件 | 表面来源 | 实测几何 | 静止态表面灰度 vs 画布 |
|---|---|---|---|---|---|
| 我的 `Index:1259` | **有**（IMMERSIVE / EXQUISITE） | 分享、设置 = **官方 `content.menu`** | 栏级材质 | 125px=**40.0vp**，间距 25px=**8.0vp**，右缘 1086 | 251.8 vs 255（**−3.2，偏暗**：折射把周围灰拉进来） |
| 首页 `HomeTab:970` | **无** | 搜索 = 自绘 `Row` + `TopButtonMaterialModifier` | uiMaterial ULTRA_THIN | 138px=**44.2vp**，右缘 1112（比官方多出挑 8.3vp） | 253.0 vs 255（**−2.0，偏亮**：普通霜面） |
| 消息 `MessagePage:1253` | **无** | 「全部已读」= **裸 `Text`，无任何表面** | — | 44vp 触控框，无视觉件 | — |
| 圈子 `CircleTab:1135` | **无** | 「已加入 2 个」= 自绘药丸 + `TopButtonMaterialModifier` | uiMaterial ULTRA_THIN | 272×113px=87×36.2vp | 内 248–250 / 缘 253–254 vs 画布 247（**+1~7，边缘亮环**） |
| 聊天 `ChatView:1289` | **无** | 「举报」= 裸 `Text`；返回键 = `BackButton` | — | — | — |

**三条结论**：

1. **两套材质不是一种材质的两个亮度**。滚动帧同框比对：官方圆是**灰底 + 亮折射环**（EXQUISITE 才有折射），自绘钮是**白霜面 + 上缘高光**（ULTRA_THIN 只有模糊和提亮，官方没有给通用组件留折射开关，见 §7.6.18）。所以首页那颗钮再怎么调参也调不成「我的」那两颗的样子 —— 这是能力边界，不是没调对。
2. **官方件与非官方件的差在几何 + 表面 + 出挑三处同时发生**：40 vs 44.2vp、8vp 间距 vs 自定 margin、右缘 1086 vs 1112。只统一其中一项不会收敛。
3. **纯白画布上任何浅色表面都读不出来**（−2~−3 级），原生参照页能读出来是因为它**画布 240 + 表面 246 + 一条接触投影**（6 级差 + 投影）。我们画布是 255，白面压不上去。这条与栏无关，是画布决策，见 §8 决策点。

**`content.menu` 能不能装下这些件**（SDK 契约实测：`HdsNavigationMenuItemOptions = HdsNavigationBadgeIconOptions = { content: HdsNavigationIconOptions, badge }`，`content` 有 `icon / label / isEnabled / action / componentId / type`，`type` 可取 `IconStyleMode(100/101/102)` 或 `TextStyleMode(200/201)`）：
- 首页搜索钮 → **装得下**（一个 icon item）。但首页栏同时有 `bottomBuilder`，`menu` + `bottomBuilder` 共存只在 `ProfileBarProtoPage` 上装过机，生产首页还没验过。
- 消息「全部已读」/ 聊天「举报」→ **装得下**（`TextStyleMode.NORMAL` 文字项），且这两条栏没有 bottomBuilder，是风险最低的一刀。
- 圈子「已加入 2 个」→ **装不下**。它是一段「文字 + 滚动计数 + 文字」的药丸，menu item 只有 icon/label/badge 三个位；硬迁就得改成「图标圆 + 红点徽标」，那是换交互形态不是换样式，需单独拍板。


#### 7.6.28 试水第一刀：消息页「全部已读」迁 `content.menu` 文字项 —— 试过，退回自绘

按 §8-F 里风险最低的那条先落（消息栏没有 `bottomBuilder` 与 menu 的冲突史）。改法：`messageBrandRow()` 删掉自绘 `Pressable + Text`，改由 `messageHdsTitleBarOptions()` 挂一个文字项。**结论是回退**，但这一轮量出来的四条契约要留下。

**官方文字项的实测契约**（`HdsNavigationIconOptions{label, type}`，`type` **默认是 `IconStyleMode.NORMAL`**，文字项必须显式给 `TextStyleMode.NORMAL`，否则排成图标槽）：

| 项 | 实测 |
|---|---|
| 节点 | `HdsMenuNode [786,106][1086,281] > Button '全部已读'`，`enabled=true` |
| 尺寸 | 300×125px = **96×40vp** —— 高度与「我的」图标圆**同档**（40vp），宽度随文字 |
| 右缘 | **1086**，与「我的」两颗图标圆同一条基线（自绘那颗是 1112，多出挑 8.3vp） |
| 动态增删 | `markAllVisible()` 为假时返回 `[]` → `HdsMenuNode` 整个消失；切回通知分段又出现 |
| 命中 | 真机点击出 toast「已全部标记为已读」→ `action` 通路完整，没被同宽度的 stackBuilder 标题行吃掉 |

**⭐ 官方件的表面能摘，typography 摘不掉 —— 这就是回退的原因。**
`HdsNavigationIconItemStyle` 只有 `backgroundColor / iconColor / textColor` 三个槽：

- **表面可以摘**：`backgroundColor = Color.Transparent` 把默认那颗浅灰药丸清掉了，真机剖面复核盒内/盒外**无台阶**（x=820 竖剖 115→145 单调渐变，就是栏自己的模糊）。所以「用官方件」不等于「接受官方观感」，排布/命中/按压反馈/无障碍可以白拿。
- **字号与内边距没有任何入口**：墨迹比原本**高 9%**（46px vs 42px）、离右缘**多出 17vp 内缩**（墨迹右缘 1033 vs 1083）。而这一颗的要求是「与原本完全一致」，改不掉就是硬伤。

**回退已验收到像素级**：还原后真机墨框 `(912,174)→(1083,215)`、42×172px，与迁移前**逐位相同**；代码相对 HEAD 零实质改动（只剩一段说明注释）。

**顺带量到的两条，留给以后要用图标钮的人**：

1. **保留药丸时字色规则会反向失效。** 药丸跟着栏变暗（静止态 243 → 特效接管后 **169**）。旧自绘那颗定的是「静止态品牌蓝、模糊到位切白」，那是**裸文字压深色背板**的规则；加了表面后白字压浅药丸 = **2.35:1**，品牌蓝压变暗药丸 = **2.9:1**、`brandPress #0055BB` 也只 2.93:1 —— 品牌色族无一档过 4.5，只能换墨字（7.63:1）。
2. **`originalStyle` 只管 scroll 特效生效之前。** 只往它写 `contentStyle` 时静止态一切正常，**一模糊就掉回 HDS 默认白字**（当时量到 1.88:1）—— 接管后菜单项颜色改读 `scrollEffectStyle`。§7.6.20 那条坑换了个槽位重演，而且静止态看着没问题，不滚一下就发现不了。**用了 `enableScrollEffect`，`contentStyle` 就得两个态各写一遍。**


#### 7.6.29 首页搜索钮迁进 `content.menu`：图标这一类成了，比自绘更读得出来

§8-F 范围裁定（官方件只用于图标钮）落的第一条。`homeBrandRow()` 删掉自绘 `Pressable + Row + Image`（连同 `searchMaterial` 修饰器、`Pressable` / `TopButtonMaterialModifier` 两个 import），改由 `homeHdsTitleBarOptions()` 挂一个图标项。

**已上机证到的**：

| 项 | 实测 | 对照 |
|---|---|---|
| 节点几何 | `HdsMenuNode [961,106][1086,281] > Button [961,131][1086,256]` = **40vp、右缘 1086** | 与「我的」两颗官方圆**同一基线**；自绘那颗是 44.2vp / 右缘 1112 |
| 默认圆底 | 节点 `backgroundColor = '#0C000000'`，真机**圆盘 243 vs 画布 255 = 暗 12 级** | 自绘那颗 ULTRA_THIN 只有 **2 级**。**不传栏级 `systemMaterialEffect` 反而最清楚** |
| 与 `bottomBuilder` 共存 | `TitleBar` 下 `StackCustomNode` / `HdsMenuNode` / `BottomCustomNode` 三者同在，分段行照常 | 此前只在 `ProfileBarProtoPage` 装过，生产首页第一次 |
| 图标渲染 | `icon: resolveActionIcon('search')`（`Resource`）正常出放大镜，`label` 走无障碍 | 与「我的」同款写法 |
| 一镜到底量帧 | dump 出官方 `Button` 节点 **`id = 'homeSearchEntry'` / `key = 'homeSearchEntry'`** —— `componentId` 直接落到节点 id 上，而 `cardRectOf()` 走的正是 `getComponentUtils().getRectangleById(id)` | 通路对得上 |

**未证的一条（真机已交还用户，不再上机）**：**飞行动画本身没跑过**。`componentId → 节点 id` 与 `getRectangleById` 同源，静态证据齐，但「点一下、页面从那颗圆缩放展开」这个过程没抓到帧。失败模式是有界的：`openSearchPanelViaNav` 量不到帧时自己兜底 —— 无飞行但照常推页，**点击不会被吞**。

**顺带修正一个既有值**：飞行起点圆角 `p.cardRadius = RadiusTokens.lg`（=20vp）。自绘那颗是 44vp 方盒配 20vp 圆角（略扁的方圆形），官方这颗是 40vp 正圆、半径正好 20 —— **同一个常量在新几何下才第一次是"对"的**，不用改。

**图标色按 §7.6.28 第 2 条两个态各写一遍**：`originalStyle.contentStyle.menuStyle.iconColor = ColorTokens.icon`、`scrollEffectStyle...iconColor = Color.White`。不写后者的话，滚动特效一接管就掉回 HDS 默认白 —— 静止态看着正常，滚一下就发现图标没了。

**⚠️ 上面那版还不算"一致"，补第二轮（未上机）**。用户复看后指出：首页这颗与「我的」那两颗**材质不同一类** —— 「我的」是玻璃珠（边缘暗折射环、内部汇聚、邻侧色块在圆边折弯），首页是**平色圆盘**（默认 `#0C000000` 三 percent 黑、无轮廓、无落影）。差在两个字段，而这两个字段是**一对**、同为 @6.1.0(23)：

| 字段 | 「我的」`Index.ets:1267-1309` | 首页改前 | 首页改后 |
|---|---|---|---|
| `scrollEffectType` | `IMMERSIVE_GRADIENT_BLUR` | `GRADIENT_BLUR` | `IMMERSIVE_GRADIENT_BLUR` |
| `style.systemMaterialEffect` | `{IMMERSIVE(101), EXQUISITE(0)}` | **没传** | 同「我的」 |

两者一起由 `isImmersiveLightSenseSupported()`（`sdkApiVersion >= 23 && canIUse(HDS_SYSCAP)`）门禁包住，低版本回落 `GRADIENT_BLUR` 且不传材质。`bindToScrollable` 首页早就接好了（`HomeTab.ets:1190`），渐变模糊的滚动源不缺。
顺带把静止态图标色从 `ColorTokens.icon`（浅色 `#3C3C43`）改成 `ColorTokens.primary`（`#17171A`）—— 与「我的」那颗同值；原先差一档灰。

**能力边界（要跟用户讲清的）**：`systemMaterialEffect` 是**栏级**入口，官方没给 `content.menu` 逐颗材质的槽位。所以要那颗玻璃珠，**整条首页顶栏就得接同一种材质**，不可能只给搜索钮单独上玻璃。这一改对栏体本身（品牌行底、分段行底）的影响**尚未上机复核**。


**待验清单复核（用户自行装机验收，2026-10-21）**：
① ✅ **材质对了** —— 那颗圆出折射玻璃珠，与「我的」同性质。
③ →已修 **`brandOnBlur` 的「模糊到位切白」整套失效**。旧 `GRADIENT_BLUR` 把栏面压成**深色**磨砂，白字是为压它而定的；换成 `IMMERSIVE_GRADIENT_BLUR` + EXQUISITE 后栏面是**亮**的，浅色模式下一滑动，「有据」Logo、SUBSTANTIATE、标语全成了白字压亮面 → 隐形。改法：三处 `fontColor` 去掉三元、两态一律深色墨（`primary` / `tertiary`），与「我的」同口径（那条栏的标题一直是 `primary`，从不切白）。同一根因也波及搜索图标 —— `scrollEffectStyle.menuStyle.iconColor` 上一轮填了白，现与 `originalStyle` 同值 `primary`（两个态仍要各写一遍，否则掉回 HDS 默认白）。
②④⑤ 仍未验。**同源的第二处暴露已一并收掉**：分段栏的 `lightContent` / `overrideTrackMaterial` 与 `TagNav.lightContent` 原先都吃 `brandOnBlur`，同一根因下白标签压亮轨道同样隐形 —— 也就是挂了很久的「首页沉浸态遇亮图时白字压白滑块」。现在三处都不再传，`brandOnBlur` 这个 @State 连同 `updateBrandCompact` 里那一路翻转**整个退役**，首页顶栏两态一律深色墨 + 官方默认轨道，与「我的」「消息」同口径。
**副作用**：`ImmersiveSegmentBar` 的 `lightContent` / `overrideTrackMaterial` 两个 @Prop 自此**没有任何消费方**（组件内 `:77` / `:81-82` 的分支恒不进入）。按「只动首页」的范围约束没删，留作下一次清理。
**别顺手照抄到消息页**：`MessagePage` 仍保留自己的 `brandOnBlur` 切白，因为那条栏**还是旧 `GRADIENT_BLUR`**（深色磨砂背板），白字在那儿是对的。只有把某条栏换成 IMMERSIVE + EXQUISITE，才需要同时退役它上面的切白开关 —— 即防漂移第 28 条。


#### 7.6.30 首页分段栏改「与内容绑定、随滚动一起走」：用官方 `dynamicHideTitleBar`

首页的分段栏住在标题栏 `bottomBuilder` 那一行，原先是**钉死**的 —— 信息流从它底下滚过去，它自己不动。「我的」那条栏早就改成跟着内容滚走（§7.6.24），首页要同口径。

**没有自绘、没有搬出栏体**：HDS 有现成入口 `HdsNavigation.dynamicHideTitleBar(DynamicHideParams)`，**@6.0.0(20) 与工程 compatibleSdk 同档，不需要版本门禁**（这点和 `systemMaterialEffect` / `IMMERSIVE_GRADIENT_BLUR` 不同）。参数语义（SDK 注释原文）：

| 字段 | 默认 | 本次取值 | 依据 |
|---|---|---|---|
| `hideBottomBuilder` | false | **true** | 只收分段那一行 |
| `hideTitleArea` | false | 不设（false） | 品牌行留在原地 |
| `mode` | `SCROLL_UP_TO` | `SCROLL_UP_TO` | 按绝对偏移收/放，回滚对称还原 |
| `hideOffset` | 0 | 0 | 一起步就开始收 |
| `hideRatio` | **2.0** | **1.0** | 官方语义：内容每滚 1vp，栏收 `1/hideRatio` vp。默认 2.0 是**半速跟随**，要「绑死」得显式给 1.0 |

前置条件：需要滚动源，首页已有 `.bindToScrollable(this.boundFeedScrollers)`。

**待复看的三处风险**（本轮只做到"构建过 + 装机起"，观感未复核）：
1. 首页是 `enableComponentSafeArea: true`（内容让位到栏下）。栏体高度随滚动收缩时，**内容区会不会跟着上跳/回流** —— 「我的」的口径是穿底要改 `false`，这里没改，是本次最需要盯的一处。
2. 分段行收起过程中与品牌行的**叠压关系**，以及 `TagNav` 那个「圈子」chip 的落点。
3. **每日一帖那一页没有 Scroll**（`boundFeedScrollers` 不绑它）→ 切到第三段后分段栏还收不收、会不会卡在收起态。

**与 §7.6.24 的分工**：那条讲的是「分段栏该不该吸顶」，结论是别吸顶、跟着资料区滚走；本条是同一诉求在**首页结构**下的官方实现路径（不搬进 List，而是让栏体自己收）。

**真机复核结果（2026-10-22，1136×2690，`uitest dumpLayout` 量节点边界）**：

| 检查 | 静止 | 滚一段后 | 判定 |
|---|---|---|---|
| `TitleBar` | `[0,106][1136,537]`（431px） | `[0,106][1136,281]`（175px） | 收起到只剩品牌行 ✓ |
| `BottomCustomNode` | `[0,280][1136,536]` | **整行从树里消失** | 分段行真的走了，不是被盖住 ✓ |
| `StackCustomNode` / `HdsMenuNode` | `[0,106][1136,281]` / `[961,106][1086,281]` | **一字未动** | 品牌行与搜索圆不被牵连 ✓ |
| 内容 `Scroll` 顶边 | **537** | **281** | 恰等于品牌行底 → **无叠压**，但也意味着内容区跟着回流 |
| 回顶后 | 全部复原 | — | 收/放对称，不卡态 ✓ |
| 每日一帖（无 Scroll） | `[0,106][1136,537]` | 两次 fling 后**不变** | 不收起也不卡死，分段行始终可达 ✓ |

**但「绑定」没做到，量出来了**：用 200px **无惯性慢拖**（`uiInput drag ... 200`）测同一批卡片的位移 —— **卡片上移 440px**，是手指距离的 **2.2 倍**。

成因就是 `Scroll` 顶边跟着栏底从 537 抬到 281：卡片屏幕位置 = `Scroll.top + 内容偏移 − 滚动量`，`Scroll.top` 自己又抬了 256px，两笔叠加。所以栏体收起那一段里内容会**从手指底下跑掉**，收起完成后才回到 1:1 —— 有一个速度断点。

`hideRatio` 治不了这个：它只改收起**用时**，不改收起**总量**（恒为那 256px），额外位移始终存在。

**要真 1:1 只有一条路**：`enableComponentSafeArea: false`，让 `Scroll` 顶边固定在窗口原点、不跟栏底跑，栏体收起只是"让出遮挡"而非"改变布局"；代价是内容会**穿到栏下绘制**（正是「我的」那套），且三页 Swiper 各自要补 `statusBar + 品牌行 + 分段行` 的 `topInset`。这属于结构改动，不是调参，待拍板。

**操作教训**：栏体收起后分段行的坐标就失效了，照静止态的坐标再点会点到卡片上（本轮就这么误开过一次帖子详情页，`keyEvent Back` 退回）。**每次点顶栏前必须重新 dump 取坐标**，别复用上一帧的。


#### 7.6.31 折射玻璃珠可用范围全仓盘点（2026-10-22）

「这颗玻璃珠还能用在哪些地方」——逐个顶栏可操作件过一遍。先记住四条硬约束，它们决定了一个按钮有没有戏：

1. `content.menu` **只渲染在 `HdsNavigation` 标题区右侧** —— 普通 `Navigation` 没有这个入口，页面要先迁容器；
2. 只装得下**纯图标**（`icon/label/badge` 三个位，排成 40vp 正圆）—— 带文字、动态文案、胶囊形态的装不进；
3. **绑了 `.bindMenu()` 的一律迁不进去**（官方菜单项没有挂 bindMenu 的槽位，见 §8-F / 防漂移第 30 条）；
4. 材质是**栏级**的，所以每用一次玻璃珠，那条栏就得接 `systemMaterialEffect`（防漂移第 28 条：接了还要同时重判该栏所有滚动驱动的字色翻转）。

**已在用（生产 2 处）**：「我的」分享 + 设置（`Index.ets:1231-1253`，材质 `1306-1309`）· 首页搜索（`HomeTab.ets:967-979`，材质 `1022-1026`）。另有验证页 `HdsMenuVerifyPage` / `ProfileBarProtoPage` 两处，仅取证。

**还能用的，按成本排**：

| 候选 | 位置 | 现状 | 成本 |
|---|---|---|---|
| **ChatView 返回键** | `ChatView.ets:1259` + `:1331` | 已是 `HdsNavigation`，却 `.hideBackButton(true)` 后自绘 `BackButton` | **最低**：去掉一行 + 接材质 + `backIconStyle.iconColor`，单文件 |
| **PostDetailView 分享钮** | `PostDetailView.ets:1603-1617` | 44×44 纯图标、无 bindMenu，但页面是普通 `Navigation`（`:1649` + `.title():1657`） | 高：要先迁容器，等于重做一遍「我的/首页」那种多轮迁移 |

**结构性没戏的（别再试）**：
- **被 `bindMenu` 阻断**：PostDetailView「更多」`:1619-1634`、UserProfileView「⋯」`:379-386`、首页「圈子 ▾」chip。
- **形态装不进圆**（文字/胶囊/动态文案）：消息「全部已读」、圈子页「已加入 N 个」药丸、聊天「举报」、圈子详情「加入/退出圈子」、编辑资料「保存」（三态文案）、发布栏「清空/预览」、举报中心那一排。
- **在内容区，材质根本不渲染**（§7.6.26 边界）：`ProfileHeader` 三颗、「管理收藏夹」、消息四颗快捷筛选、「探索星云」FAB、ImageViewer 关闭。

**没被算过的一块大账**：`BackButton` 这个自绘组件被 **30 个文件**引用，全是 44vp 裸图标、零表面。它们是"顶栏看起来不统一"的最大一处存量。但**绝大多数宿主页是普通 `Navigation`**，要拿到官方玻璃珠得逐页迁容器 —— 这是约 20 个页面的迁移量，不是一次样式改动。

**⚠️ 一个尚未知的点，排期前必须先验**：全仓 6 处 `HdsNavigation` **无一例外都写了 `.hideBackButton(true)`**，也就是说**官方那颗返回键从没在这个 app 里渲染过**。它接到栏级材质后到底出不出玻璃珠、`backIconStyle` 能不能压住默认白色，都是推断而非实测。所以 ChatView 那一处应当当成**验证性试点**做，而不是当成"稳赚的改动"直接铺开。

**试点已完成（2026-10-22，ChatView，真机通过）—— 上面那个未知已消**：

- **官方返回键会渲染，且拿到同一套材质表面**：`Button [50,131][175,256]` = **40vp 正圆**、左内缩 16vp、图标 24vp；节点 `backgroundColor` 从默认 `#0C000000` 翻成 **`#00000000`**（材质接管的标志，与「我的」那四颗同现象）。圆内均值 **252.2 vs 画布 255 = −2.8 级**，与「我的」的 −3.2 同档 —— **`backIcon` 和 `content.menu` 项吃同一个栏级材质**，不用额外配。
- **`backIconStyle.iconColor` 有效**，压得住 HDS 默认白；两个态仍各写一遍（防漂移第 25 条）。
- **`backIcon.action` 存在可用** —— 换官方返回键**不需要改返回行为**：原 `backAction()`（nav 模式走宿主 `onBack`、router 模式走 `router.back()`）原样接回，没被换成 NavPathStack 默认 pop。
- **⚠️ 会咬人的坑：官方返回键会被 stackBuilder 的全宽可点行吃掉点击。** 第一版装机后点返回键**跳到了对端主页**而不是返回 —— `chatTopRowContent` 里那条对端 Row 挂了 `onClick(goPeer)` 且带 `layoutWeight(1)`，横向铺满 25~979，盖在返回键（50~175）之上，而 `StackCustomNode` 是 `Button` 的后一个兄弟节点、z 序在上。修法：`chatHdsTopRow` 左内边距让开返回键 —— 它占 16~56vp，内容从 **64vp** 起（修后可点行左缘 25→200px、留 8vp 间隙，返回键恢复）。
  **这条对所有"顶栏里有全宽可点行"的迁移都成立**：`content.menu` 那颗在右侧同理会被吃，只是「我的」的标题是左对齐窄条才没暴露。**迁完必须真点一次返回**，不能只看它长出来了。

**第二块试验田：`DraftBoxPage` 已迁完（2026-10-22，真机通过）** —— 「普通 `Navigation` → `HdsNavigation`」的第一例，也是最便宜的一种：顶栏只有一颗返回键 + 一段静态文字，没有成对按钮、没有覆盖层。结果：

- 官方圆 `Button [50,131][175,256]`、`backgroundColor=#00000000`、圆内 **252.3 vs 画布 255 = −2.7 级**（与聊天页 −2.8、「我的」−3.2 同档）。
- 标题 `Text '草稿箱'` 落在 x=200（= 64vp 让位），返回键右缘 175 → 间隙 8vp；**真点一次确认回到「我的」**（顶栏文本 `草稿箱[200,156]` → `我的[50,144]`）。
- 栏体 56vp、`NavBarContent` 从 y=281 起 —— 内容照旧从栏下开始，`enableComponentSafeArea: true` 单独就够，原来 `BarStyle.STANDARD` 的占位语义被它替掉了。
- HDS 默认那条 `Divider [0,280][1136,281]` 实测 **255 = 不可见**，不用特意关。

**⚠️ 顺带修正 §7.6.29 那句「两个字段是一对」**：本页 `scrollEffectOpts.enableScrollEffect = false`（`ManagedPostFeed` 不外露 Scroller，拿不到滚动源），**只传 `systemMaterialEffect` 也照样出了玻璃珠**。所以成对的是「折射观感 ↔ 栏面模糊强度」，不是「玻璃珠 ↔ 滚动特效」：想要那颗圆，`systemMaterialEffect` 单独就够；`IMMERSIVE_GRADIENT_BLUR` 管的是栏面随滚动的模糊，没有滚动源时不开也不影响圆。

**第三例：`TrashBoxPage` 已套同一模板（2026-10-22，真机通过）** —— 官方圆 `Button [50,131][175,256]` / `bg=#00000000`、标题 `废纸篓` 落在 x=200（64vp 让位）、`Scroll` 从 y=106 起（穿底开）、真点返回确认回到「我的」。**模板已稳定到可以直接批量套**：`HdsNavigation` + `titleBar(backIcon + stackBuilder 左缩 64vp)` + `IMMERSIVE_GRADIENT_BLUR`/`systemMaterialEffect` 成对 + `enableComponentSafeArea:false` 配 `topInset = statusBarHeight + 56` + `bindToScrollable`。

**⚠️ 但"看不到效果"在这两页是数据问题，不是接线问题**：草稿箱当时只有 1 条草稿、废纸篓只有 4 条（双列两行），**两次 fling 后卡片位移都是 0px** —— 内容撑不满一屏就滚不动，永远没有东西经过栏下，材质自然无从折射。接线本身是对的（`Scroll` 节点已从栏下 537 移到窗口原点 106，静止态首屏仍无叠压）。所以这类短列表页验收**不能只看静止帧**，要么先凑够内容再验，要么承认"材质要等内容够长才显形"。

**第四例：`SearchResultPage` 已迁（2026-10-22，真机通过），但它把「穿底」与「栏内裸小字」的冲突量化了。** 这页顶栏是两行结构，映射成 `stackBuilder`（搜索框 + 搜索按钮）+ `bottomBuilder`（结果计数 + 最新/热门分段栏），`TitleBar [0,106][1136,506]` = 128vp = 56 + 72。

- 官方返回键 `Button [50,131][175,256]` / `bg=#00000000`；`SearchField` 落在 x=312（工具栏行左缩 64vp 生效）；分段两颗在 `BottomCustomNode` 内正常。**真点返回确认回到搜索探索页。**
- **穿底试过，效果是这批页里最好的一次**：内容穿到栏下被渐变模糊，返回键圆内 **210~215 vs 圆外 195**（+18~20 级），折射环真的吸住了背后的暗色卡片 —— 前面几页在纯白画布上只有 2~3 级，这页第一次让人"看出材质"。
- **但同一帧量出我自己引入的缺陷**：`bottomBuilder` 行里的「找到 N 篇内容」是**无表面的裸小字**（`ColorTokens.secondary`），内容一穿到栏下它就压在渐变模糊的暗背板上，实测**字/背板 1.78:1**，掉出 AA。这页原本是 `BarStyle.STANDARD` 不透明栏，内容从不经过栏下，所以计数一直站在白色上 —— 缺陷是穿底带出来的，不是原有的。
- **处置：这页退回 `enableComponentSafeArea: true`**（计数区背板复测 255 纯白），保留官方返回键与两行栏结构。**要拿回穿底带来的材质可见性，前提是先把这行计数搬进列表当表头** —— 让它有自己的白色画布可站，而不是让字色去赌背后是什么内容。这正是工程既有规则「小字不压 tint」的又一次落地。

**⚠️ 由此得出一条批量迁移的前置检查**（写进防漂移第 32 条）：给某页开穿底之前，先数一遍它的 `bottomBuilder` 行里有没有**无表面的裸文字**。有 → 要么先搬走，要么这页不穿底。首页/消息之所以能穿，是因为那一行里只有分段栏和 chip，**两者都有自己的官方表面**。


#### 7.6.32 沉浸光感 tabbar 优化落地：Dock 玻璃选中指示器（2026-10-26）

来源：华为开发者联盟文章 [`03212848303315412`《对沉浸光感tabbar的优化改造》](https://developer.huawei.com/consumer/cn/blog/topic/03212848303315412)（2026-04-29）。原文两条痛点逐条对表真机基线：

| 原文痛点 | 我们命中吗 | 真机基线（LEM-AL00 / HarmonyOS 7.0 / 1136×2690 / px÷vp=3.125） |
|---|---|---|
| ① 高光与图标同层，切换时盖住图标 | **不存在** | `TabBar [99,2427][1037,2602]` 下只有 5 个 `Column`，无任何表面节点 |
| ② 只靠图标样式变化，通透背景下辨识度不足 | **正中** | 选中态唯一差别是 `fillColor`（`#0066CC` vs `#3C3C43`），压在 251 灰度的 Dock 面上；五颗图标还都保持镂空 |

### 先记一次做错的：把「玻璃」做成了「色块贴片」

第一版落地的是一颗 `brandTint` 10% 蓝填充 + 1px 蓝描边 + `cardAmbient` 投影、**尺寸往槽位里内缩**、且**不在胶囊里放内容**的贴片，理由写的是「内容区拿不到系统材质，加模糊只会糊掉官方图标，不如半透色面清楚」。这个理由是错的，而且错在三个地方 —— 全部由参照图（文章的效果预览，360×240）量化后打回：

| 属性 | 参照图实测 | 第一版 | 错在哪 |
|---|---|---|---|
| 胶囊面 vs Dock 面 | 53 vs 24 → **亮 +29 级** | 与 Dock 同亮度、只偏蓝 10% | 没有表面差就没有体积。白底 Dock 是 251、上限 255，**"更亮"这条路没有余量**，只能反向压暗（见 §7.6.27 结论 3） |
| 边缘 | 顶缘高光比 Dock **亮 +86 级**的一条镜面弧 | 均匀 1px 蓝线 | 玻璃读得出来主要靠 rim，不是靠填充色 |
| 内容 | 胶囊里是**清晰**的图标+文字 | 只有下层官方那份 | 见下：真磨砂必然毁掉下层，副本是**必需品**不是装饰 |
| 尺寸 | 宽 ≈ **1.22 倍槽距**、高 ≈ 0.93 倍栏高，行进中**溢出 Dock 圆端** | 比槽位还窄（内缩 6/3vp） | 方向整个反了，玻璃无从谈起 |

**「不给胶囊加 blur」这个决定本身，正是把玻璃做成贴片的原因。** 加上 `backdropBlur(SEGMENT_BLUR=20)` 之后真机实拍：底下的官方图标被糊成一团蓝色光晕、完全不可读 —— 这才看懂原文为什么要在胶囊内复制一份图标+文字。**副本不是可选的美化，是真磨砂的必然配套**。

### 材质轨：一次性判定实验，覆盖层拿不到官方材质

挂 `uiMaterial.ImmersiveMaterial({style: THIN, applyShadow: true})`（场景规范「底部悬浮 → THIN」）、同时把自绘表面**全清空**，装机看像素：胶囊整个消失（247~254 vs Dock 252，无差）。与 §7.6.26 一致 —— `systemMaterial` 只在 `TitleBar` 子树渲染，`NavBarContent` 下的覆盖层拿不到。**Dock 指示器只能自绘玻璃，这条到此封死**（`immersiveMaterial.ets` 里已把该实验结论写成注释，不留死代码）。

### 最终配方

| 项 | 值 | 依据 |
|---|---|---|
| 尺寸 | 宽 = 实测槽距 × 1.22，高 = 实测槽高 × 0.96（≈52vp），圆角 = 高/2 | 参照图比例；槽位框实测 64vp 但**中心间距只有 55.2vp**（中心 222/394/567/740/912px，互叠 27.5px），所以宽度只能取反算槽距，取节点宽度会盖住邻居 |
| ① 透底模糊 | `backdropBlur(GlassTokens.SEGMENT_BLUR)` | Dock 是 `barOverlap(true)` 悬浮的，信息流会从背后穿过，磨砂要糊得掉它 |
| ② 中性半透面 | `glass_pill_fill`：浅色 `#14000000` / 深色 `#26FFFFFF` | 参照图暗底提亮，白底镜像过来就是压暗；**玻璃本身不着色**，品牌色留给图标和文字 |
| ③ 镜面 rim | 1.5vp，`glass_pill_rim`：浅色 `#A6FFFFFF` / 深色 `#40FFFFFF` | 参照图顶缘 +86 级 |
| ④ 落影 | `ShadowTokens.pillFloat`（radius 8 / 15% 黑 / offsetY 3） | 实测胶囊下方 215~241 一条影；`floating`(16/6) 对 52vp 的件太大 |
| ⑤ 胶囊内副本 | 复用官方那份的 `tabItemContent(index)`，同时把被盖槽的官方件 `opacity(0)` | 不隐就会「清晰副本 + 磨砂光晕」叠成脏；隐了玻璃下面只剩 Dock 表面。副本与官方位差实测 1px |
| 动效 | 300ms `springSoft` 位移 + 鼓包 +6 → 240ms `springInteract` 收回 | 原文 tap 分支（它的速度形变只服务拖拽，本应用不接） |

**⚠️ 两个必须记住的坑**：
1. **胶囊里那份不能用 `this.tabItemContent(this.dockPillCovered)`** —— `@Builder` 参数是值快照，落位后 index 变了副本不刷（真机实证：胶囊飞到「消息」里画的还是「首页」）。改成 key 随 `dockPillCovered` 变化的单元素 `ForEach` 强制重建。见 [[arkui-builder-param-value-snapshot]]。
2. **承载副本的 `Column` 必须显式 `justifyContent(Center)` + `alignItems(Center)`** —— 官方那份是被 `Stack(alignContent: Center)` 居中的，Column 主轴默认从顶排，漏写会高 9px = 2.9vp，落位瞬间图标跳一下。

### 覆盖层坐标：本轮最贵的一块地（详见防漂移第 37 条）

| 量 | 接口回报 | dumpLayout 实际 | 差 |
|---|---|---|---|
| 槽位 `windowOffset.y`（`getRectangleById`） | 2527px | 2439px | **+88px** |
| 槽位 `globalPosition.y`（`Area`） | 808.64vp = 2527px | 2439px | **+88px** |
| 槽位 x | 122.35px | 122px | +0.6px（不修正） |

两个不同源的 API 给同一个偏差 ⇒ 不是接口 bug，是坐标语义：系统把悬浮条整体上提了 `barBottomMargin`，但 TabBar 子树的矩形按上提之前算。88px = 28.16vp，与传进去的 `DOCK_BOTTOM_MARGIN_BASE(28) + bottomNavInset()(0)` 吻合到 0.4px。另：覆盖层 `globalPosition` 报 (0,0)、`Area.height` 报 860.8vp（整窗），而 dumpLayout 给它 `[0,106]` 起算 —— `.position()` 吃前者，别拿 dump bounds 校它。

### 按压反馈：点光源这条路在白底上走不通，改按压缩放

用户实测反馈「长按底部栏，玻璃指示器无反应」。根因是我把覆盖层写成 `HitTestMode.None`（当时为了"零交互风险"），玻璃根本收不到手指。原文用 **`HitTestMode.Transparent`** 不是随手写的 —— 它让覆盖层自己响应触摸、同时把命中继续透给下层的官方页签，两者兼得。改回 Transparent 后真机复点确认切页照常（`圈子 [362,2553]` 官方件与 `[363,2553]` 副本同帧，页面确实切过去了）。

接上官方点光源（`CommonMethod.visualEffect()`@12 + `hdsEffect.HdsEffectBuilder().pointLight()`@20，不需要 hdsMaterial 那套门禁）后，**三档实测全部不能用**：

| 档位 | 按压时胶囊面 Δ | 结果 |
|---|---|---|
| `BRIGHT + BORDER_CONTENT`（原文档） | 231→**255**、图标 86→252 | 整块过曝，内容被擦掉 |
| `SOFT + BORDER` | +4 | 等于没反应 |
| `BRIGHT + BORDER` | +4 | 等于没反应 |

**机理**：`illuminatedType` 的「照边框」作用在**材质自己的边框**上，而覆盖层拿不到 `systemMaterial`（见下节判定实验），所以只有「照内容」那条路会出效果 —— 而它洗掉的正是要保持清晰的图标。原文那档是**深色底**，光打上去是反光；同一档压到近乎纯白的 Dock（251、上限 255）上只剩白化。这是 §7.6.27 结论 3（白画布上没有亮度余量）在按压反馈上的第二次应验。

**改走本项目已定稿的按压范式**：`.scale(pressSlideScale=0.94)`（华为应用商店同款按压缩放）**同时**把落影从 `pillFloat`(radius 8 / offsetY 3) 收到 `cardContact`(radius 1 / offsetY 0) —— 影变短 = 件贴近背板，两件一起才读得出"按下去了"。真机按住帧量得：胶囊暗部面积 38726→34035 = **×0.879**，与 0.94² = 0.884 吻合；顶缘下移 9~15px；松手后回满尺寸无残留。

### 底栏材质档

`DOCK_MATERIAL_LEVEL` ADAPTIVE(10) → EXQUISITE(0)，与四条顶栏同档（§7.6.17 实测 ADAPTIVE 无折射，原文同样写 EXQUISITE）。⚠️ **已上线过审表面**的观感变更，回退只需把 `cardTokens.ets` 该字段改回 10。

**未采纳**：`adaptToHandedness`（智感握姿会平移整条 Dock，指示器要跟着重测、底栏位置不再稳定）、`lightColor`、`animationDuration(0)`、`barHeight(59)`、三档 `barWidth` 同值（我们那三档差异是为修「切页时底栏忽长忽短」定的）。**拖拽切页仍不采纳** —— 改交互，`scrollable(false)` 是明确决策。

### 验收（真机，浅色）

| 场景 | 结果 |
|---|---|
| 冷启落位 | 中心 x 222.5（槽 0 = 222）、y 807.64vp（真值 807.52）✓ |
| 表面量化 | 胶囊 231~235 vs Dock 251 = **−16~−20 级**；rim 亮边；下方落影 215~241 ✓ |
| 点消息（跨发布槽行进） | 落在槽 3、副本是**清晰的品牌蓝消息图标**、官方那份已隐、其余四颗照常 ✓ |
| 副本与官方对位 | `[190,2553]` vs `[191,2554]` = 1px ✓ |
| 点发布 | 半模态弹出、**胶囊不动**、被盖槽不切换 ✓ |
| 点击命中 | 五颗页签 + 首页搜索钮（一镜到底入口）全部照常 ✓ |

**未验**：① 行进动效观感（`snapshot_display` 抓不到 300ms 中间帧，要真人眼验）；② 深色档表面强度（配方给了 `#26FFFFFF`/`#40FFFFFF` 一套，未上机）；③ 信息流从 Dock 背后穿过时磨砂是否够（dev 后端 `127.0.0.1:3000` 的 `hdc rport` 随设备换址失效，首页是「加载失败」空态，没有可滚内容）。

**边界**：指示器只在 `hdsFloatingBar`（API 23+）分支画。API 20-22 走自绘 `BottomTabBar`，它自带高亮件，两套选中语言不并存。


### 7.7 浅色那一档顺手复测（补第 6 节的 TODO）

原生电话·浅色的分段栏与文字（同一套几何，只有色不同）：

| 项 | 实测 |
| --- | --- |
| 页面底 | `#FFF1F3F5`（节点真值），像素 `#F2F3F5` L243 |
| `hdsTabs` | `#FFFFFFFF` |
| 分段栏轨道 | `#F5F6F8` L246（比页面底 **+3 L**） |
| 滑块 | `#FFFFFFFF` 节点真值，L255（比轨道 **+9 L**） |
| 选中标签 / 未选中标签 | 近黑 `#020202` / `#4D4E4F` |
| 几何 | 轨道 331.5×40、项 161.9×32、内缩 4vp —— **与深色逐位相同** |

→ **修正第 2.1 节的框架**：「选中面比轨道**暗**」只是参考 A（沉浸材质 + 壁纸背景）的观感；在**平色浅底**上官方默认给的是**纯白滑块比轨道亮 9 L**（跟参考 B 同侧）。语境决定方向，不是实现差异。

→ **决策点 E 多了一条最省事的候选**：系统浅色能把这条栏显出来，靠的是**页面底不取纯白**（`#F1F3F5`）→ 轨道抬 +3 L、滑块再抬 +9 L。我们首页页面底是纯白，轨道无处可抬（实测轨道 252.0 vs 页面 251.7，差 0.3）。把页面底降到 `#F1F3F5` 档，官方默认自己就出层次，不需要自绘。

### 7.8 未取证项

- 4 点「更多」图标的 `sys.symbol.*` 资源名：SDK 内**没有符号名字典**（`hm_symbol_config_next.json` 只有 glyph id ↔ 图层映射），`deveco_mcp` 的官方文档检索本轮全程超时。**要准名只能在 DevEco 的 Symbol 选择器里看，不要猜。**
- `menuStyle.backgroundColor` 的实际默认资源名（官方 d.ts 只给了字段，没写默认值）—— 待查 `HdsNavigation` 的样式默认表。

### 7.9 复现命令（深浅两档通用）

```bash
HDC=/Applications/DevEco-Studio.app/Contents/sdk/default/openharmony/toolchains/hdc
$HDC shell "uitest dumpLayout -p /data/local/tmp/l.json"
$HDC file recv /data/local/tmp/l.json /tmp/l.json
$HDC shell "snapshot_display -f /data/local/tmp/s.jpeg" && $HDC file recv /data/local/tmp/s.jpeg /tmp/s.jpeg
$HDC shell "uitest uiInput click <px-x> <px-y>"   # bounds 是 px，÷3.125 才是 vp
```

抓完先做两件事：`md5` 比对上一帧（相同 = 缓存帧），再把关键节点 bounds 与像素特征对表（对不上 = 陈旧帧）。本轮采集结束后设备已复位到原始状态（整屏 0 差异像素）。

## 8. 决策点（需要拍板，不要静默改）

**A. 分段栏文字 14 → 16fp。已作废。** 16fp 是 B 语境（设备详情 V1 纯底栏）的值；顶栏对标的是 A 语境，官方默认就是 **14fp**，我们已是 14fp。不再需要动槽位预算。

**E. 白底画布上材质无层次（待拍板，本轮新增首选候选）。** 改官方默认后实测：轨道 L252.0 vs 页面底 L251.7（差 0.3），选中面 L254.9（比轨道亮 2.9）。参考那条栏背后是整屏壁纸，材质有东西可采样；我们顶栏背后是纯白画布，所以官方默认几乎不可见。四条候选，都要真机复测：
  0. **（首选，成本最低）把页面底从纯白降到 `#F1F3F5` 档。** 原生电话浅色就是这么做才让同一条栏显出来的：页面底 `#F1F3F5` → 轨道 `#F5F6F8`（+3 L）→ 滑块纯白（再 +9 L），滑块对比是我们现在的 **3 倍**（见 7.7）。不改任何组件字段，只改页面底色，官方默认自己就出层次。
     **2026-10-20 追加证据（7.6.3）**：这条不只是分段栏的问题 —— 工程浅色基色 `bg_primary = #FFFFFF` 会让**官方按钮材质画不出边缘阴影**（rim/落影没有可比背板，全被压平）。把验证页底色换成 `#F1F3F5` 后，圆 vs 背板反差从 +5 L 涨到 +9 L、高光出现、观感与电话 App 基本一致。**一个 token 改动同时解掉分段栏层次与按钮材质两件事**，建议优先落这一条。
     **落法约束（7.6.8 实测副作用）**：`#F1F3F5` 是浅色基色，硬编进页面会在深色模式下画出浅色画布 + 白色状态栏图标 → 状态栏几乎不可读。落这条必须同时给出深色档（深色侧维持 `#121212` 系），做成 light/dark token 对，别只改浅色。
  1. 给顶栏区域可采样的背景（首页报头/壁纸层穿到栏后），最贴近参考 A；
  2. 用官方字段抬对比：`backgroundBlurStyle`（V1）或 `buttonBackgroundBlurStyle` / `buttonBackgroundColor`（V2）传系统资源值，不写死色值；
  3. 接受"文字即分段栏"的极简观感，靠选中面区分。
  **不要**用自绘描边/自绘底色去硬凑对比 —— 那是第 4 次回到自绘。
  ⚠️ 本轮同时**修正了 2.1 的框架**：「选中面比轨道暗」只是 A（材质 + 壁纸）的观感，平色浅底上官方默认是**白滑块比轨道亮**（跟 B 同侧）。所以候选 0 与 B 语境同向，不算自绘、也不算回到旧错误。

**B. 是否新增「卡内次级分段」组件。** 建议照第 3 节尺寸落 `MiniSegmentRow`，配三枚 token：`miniSegmentHeight = 34`、`miniSegmentItemWidth = 74`、`miniSegmentIcon = 16`。候选消费方：引力档位选择、发布体裁、对比弹层。

**C. 底部页签光斑去留。** 官方无任何选中装饰，只换色。我们的 180vp 光斑是品牌个性，也是与官方差异最大的一处。

**D. 图标资源策略（本轮定位到具体通路）。** 官方全量使用 `SymbolGlyph`（符号字体，随字重/着色一致缩放）。我们仍有 `resolveActionIcon` / `resolveSettingsIcon` 等资源图入口，混用会造成深浅色与描边粗细不一致。
  本轮实测确认：顶栏那几枚圆形图标钮**有官方现成实现** —— `HdsNavigation.titleBar({ content: { menu: { value: [...] } } })`，由 `HdsMenuNode` 负责排布（项宽 40、间距 8）、由组件内部画圆底/高光/投影，改色只走 `style.originalStyle.contentStyle.menuStyle`（见 7.6）。我们目前**完全没用 `content.menu`**，`Index.ets:1047/1070` 是 `Pressable + Image` 自绘 —— 圆底/描边/投影一直在手搓。待拍板：是否把顶栏图标钮迁到 `content.menu`。
  ⚠️ 迁移的已知代价：`HdsNavigation` 的 `bottomBuilder` 行会裁投影（见 [[arkui-bottombuilder-clip-shadow-room]] 与 `utils/immersiveMaterial.ets:140` 的注释）—— 但官方那颗圆的投影在**浅色**下是可见的（7.6 实测 −8 L），所以迁过去之后要重新验一次投影净空，别默认沿用现在"关投影"的做法。
  ✅ **本轮已定论（见 7.6.5）**：要拿到电话 App 那圈逐颗落影，走 **B 方案** —— 自研 `Button` + `.backgroundColor(Color.Transparent)` + `FloatingTopButtonMaterialModifier`（`applyShadow: true`），行高给 ≥27vp 下方净空。实测落影深度 −8 L、足迹 ≈51vp、钟形，与电话 App 三项指标定量吻合。`content.menu`（A 方案）无论怎么调材质档位/遮罩层/背板亮度都**接不出逐颗落影**，只能得到整条栏的暗底板。二者不可兼得，待拍板。

**F. 其余四条顶栏要不要一起迁进 `content.menu`（2026-10-21 盘点，见 7.6.27）。** 目前五条栏里只有「我的」用了官方 `content.menu` + 栏级 `systemMaterialEffect`，首页/消息/圈子/聊天四条**连 `systemMaterialEffect` 都没传**，可操作件全是自绘或裸文字 —— 这就是「分段栏样式跟其他组件不一致」的同一条病，只是发生在按钮上。逐条可行性已实测过一遍：
  - **消息「全部已读」/ 聊天「举报」**：~~风险最低~~ → **已试过并回退，这类不再迁**。两条栏都没有 `bottomBuilder`，`content.menu` 的 `TextStyleMode.NORMAL` 文字项也装得下、命中与动态增删都验通了，但官方件**只有颜色三个槽，字号和内边距改不掉**（墨迹高 +9%、离右缘多 17vp），达不到「与原本完全一致」。详见 §7.6.28。
  - **范围裁定（2026-10-21，用户选 3）**：**官方 `content.menu` 只用于图标钮**。文字动作（全部已读 / 举报 / 已加入药丸）一律留自绘。下一步落首页搜索钮。
  - **首页搜索钮**：✅ **已落（2026-10-21，见 §7.6.29）**。40vp / 右缘 1086 与「我的」同基线；默认 `#0C000000` 圆底实测比画布暗 12 级，比自绘那层 ULTRA_THIN 白霜（2 级）好得多，**不需要给首页栏补 `systemMaterialEffect`**；`menu` + `bottomBuilder` 在生产首页共存已验。⚠️ **一镜到底飞行动画未跑过**（真机已交还）—— `componentId` 确认落到节点 `id`/`key`、与 `getRectangleById` 同源，静态证据齐，但没抓到中间帧。失败是有界的：量不到帧就不飞、照常推页。
  - **圈子页「已加入 N 个」药丸**：**装不下**。menu item 只有 `icon / label / badge` 三个位，装不进「文字 + 滚动计数 + 文字」的药丸；硬迁等于把药丸换成图标圆 + 红点，那是换交互形态不是换样式。
  - **首页「圈子 ▾」下拉 chip（分段行右侧，`TagNav` `dropdownOnly` 分支）**：**做不到，已定论**（2026-10-22 用户问「能不能也做成搜索按钮那样」）。三条硬约束：① `content.menu` 只渲染在标题区右侧，**没法把某一项放进 `bottomBuilder` 那一行**，迁过去就离开它所属的分段栏；② menu item 只有 `icon/label/badge`、排成 40vp 正圆，而这颗是 88×36 全胶囊、装的是**动态的已选圈子名 + 下箭头**，圆里放不下变长文本；③ **最致命的一条：官方没有"在指定坐标弹出系统菜单"的可编程接口** —— 整个 SDK（`openharmony/ets` + `hms/ets`）搜 `showMenu` 零命中，下拉只能靠 `.bindMenu()` 绑在自己拥有的节点上（现绑在 chip 本体，`TagNav.ets:168`），而 `HdsNavigationIconOptions` 没这个槽位，迁过去面板就开不出来。
    唯一能拿到玻璃圆的办法是把交互从「贴按钮下展开的菜单」换成「从底部升起的 `bindSheet`」（sheet 相对窗口弹，不需要锚点，官方 menu item 能触发）。**用户裁定代价过大 —— 交互形态不能变，本条关闭**，chip 维持霜面 + 细描边胶囊（那已是该位置能拿到的官方最优）。
    材质也追不平：折射玻璃珠只来自栏级 `systemMaterialEffect` 渲染的官方 item；自定义节点在 `bottomBuilder` 里只能走 `uiMaterial` 霜面，没有折射开关（防漂移第 24 条）。按上面的范围裁定，**留自绘，本条关闭**。
  - **仍未决**：二级页的 `BackButton`（44vp 裸图标、零表面，`design/components/BackButton.ets`）不在 HdsNavigation 栏里，走不了 `content.menu`；要不要统一是另一个问题。
  - **迁过去也不会自动变好看**：官方圆是 EXQUISITE 折射（静止态比白画布**暗** 3.2 级），自绘 ULTRA_THIN 是白霜面（**亮** 2 级），两者在纯白画布上**都读不出来**。真正的可见性还得等决策点 E 的候选 0（画布降到 `#F1F3F5`）落地，否则统一只是从"两种看不见"变成"一种看不见"。

## 9. 防漂移规则

1. 分段栏的表面（选中面底色、圆角、投影、文字样式）**一律不传**，走官方默认；改这些字段等于自绘，需先在此文档给出实测依据。几何类字段（`buttonPadding` 撑高度、`itemWidth` 定宽）允许显式传值。
2. 改 `segmentBarHeight` / `segmentBarShadowRoom` / `segmentBarTopRoom` 前，先回第 2 节核对；改完必须重新做像素取证（参照 [[harmonyos-device-pixel-probe]] 流程），不要只改代码。
3. 新分段栏一律走 `design/components/ImmersiveSegmentBar.ets`。**禁止**：自绘轨道、把官方选中面设成 `Color.Transparent` 再叠自绘滑块、自绘标签层替代官方文字 —— 这些都算自绘，已被三轮否决。
4. 官方 `selectedIndexes` 无连续索引入口，**不要为了跟手再引入自绘滑块**；需要跟手感时先提出取舍决策，不自行实现。
5. 卡片内的三选一控件优先按第 3 节尺寸，不要复用顶栏分段栏。
6. 分隔线用 `Divider`，不要用 `border({width:0.5})` 拼。
7. 本文档只记**实测**值；目测/估计的写 `tentative` 并给出复测方法。同一组件在不同背景语境下观感不同，必须分开记（见 2.1 的 A/B 两栏）。
8. 深色模式的表面色**一律按「白叠加比例」表达**（控件面 8% / 卡片 10% / 强调圆底 20%，强调色 `#317AF7`、其选中底取该色的 10%），不要写死一串灰阶 —— 叠加比例在黑底和 `#992E3033` 面板上都能对上实测值（第 7.1 节两点解出 α≈0.08），写死色值换背景就错。
9. **禁用态改色不改透明度**：官方禁用项 `opacity` 恒为 1.0，靠色值 `#747474` 表达（第 7.2 节）。可操作元素禁止用 `opacity` 弱化，这条是官方口径不是我们的偏好。
10. 量深色值先读 `dumpLayout` 的 `backgroundColor` / `opacity` / `blur`（框架真值），像素只用于圆角、材质叠加比、描边、模糊。帧必须过「md5 比对 + bounds 对表」两道关再用（第 7.0 节）。
11. **`ScrollEffectType.GRADIENT_BLUR` 与 `bindToScrollable` 是一对，不能只上一个**：只开渐变模糊不绑 Scroller，子列表会整条不响应滚动（真机实测「我的」帖子流恒位不动，第 7.6.12 节）。常量模糊用 `COMMON_BLUR`，它不需要滚动源。
12. `enableComponentSafeArea: false` 之后，子页内容盒顶边落在**窗口 0**，不是状态栏下沿 —— 列表让位量必须含 `statusBarHeight`；`Scroll` 节点报 `[0,106]` 是裁剪后的可视框，别拿它当布局原点（第 7.6.11 节）。同理 `bottomBuilder` 把内容垂直居中塞进声明高，上下各吃掉约 `segmentBarShadowRoom/2`。
13. **标题栏模糊按栏高选档，别照抄兄弟 Tab**：`blurRadius` 只在 `GRADIENT_BLUR` / `IMMERSIVE_GRADIENT_BLUR` 下生效；`COMMON_BLUR` 把整条栏画成平色，`GRADIENT_BLUR` 是空间渐变（顶部糊、往下衰减），栏体超过约 140vp 下半条就漏成锐利内容。高栏（如把资料区也装进栏体的「我的」，353vp）用 `IMMERSIVE_GRADIENT_BLUR`（第 7.6.14 节）。
14. **要「玻璃折射」必须 `materialLevel = EXQUISITE(0)`；`ADAPTIVE(10)` 只出普通半透**（第 7.6.17 节）。别把 ADAPTIVE 理解成「系统会挑最好档」—— 它兜出来的是另一种观感。
15. **观感差异先用语言定性，再倒推该量什么**：「折射 / 弯折」是几何量，「透过去 / 发虚」是透射量。拿彩度、明度这类透射指标去找折射问题必然量不出差别（本轮连错三次）。
16. **分段栏不要传 `backgroundSystemMaterial`**：`ULTRA_THIN` 让轨道只透背板，颜色随身后内容漂移，同一条栏在不同页、同一页不同滚动位都不是一套观感（第 7.6.18 节）。官方默认档由应用级 `ohos.arkui.UIMaterial.state = enable` 提供，`SegmentButton` 在其默认启用清单里。
17. **`overrideTrackMaterial` 与 `lightContent` 必须同值**：白标签（`lightContent`）只在 `ULTRA_THIN` 的深轨道上才有对比；轨道换成官方默认档会被提亮成近白，白字直接消失。
18. **`ListItemGroup` 的 header 默认透明，吸顶必须自己垫底，但垫的是玻璃不是实色**：`backgroundBlurStyle(BlurStyle.COMPONENT_REGULAR)` 常驻 + 实色只在 `!isImmersiveLightSenseSupported()` 兜底（抄底部 Dock 的配方）。`BACKGROUND_*` 系列会把背板原样透出来、暗图下未选标签掉到 4.26:1 不达标；`systemMaterial` 在内容区组件根本不渲染；**官方轨道自己也当不了表面**（换材质档也没用）。档位表见第 7.6.19 / 7.6.23 节。
19. **`List`/`Scroll` 节点报的 `[0,106]` 是裁剪后的可视框，不是布局原点**：`contentStartOffset`、`padding.top` 这类让位量仍要自己含 `statusBarHeight`。第 12 条换了组件重演一次，代价是资料卡被标题栏切掉半张头像。只改其中一个 = 制造对比度缺陷。

## 10. 相关既有文档

- `docs/home-segmented-control-style-audit.md` —— 迁移**前**旧 `SegmentedControl` 首页分段栏的样式审计，几何结论（36vp 容器、202vp 宽）已被本文档第 2 节取代，仅作历史参照。
- `docs/immersive-light-integration.md`、`docs/tutorial-titlebar-immersive-light.md` —— 沉浸光感接入选型与踩坑。
20. **`originalStyle` 里不要写 `blurRadius`**：它是「scroll 特效生效**之前**」的样式，写了就是命令顶栏静止态先糊。模糊只放 `scrollEffectStyle` / 交给 scrollEffect 默认（第 7.6.20 节；对照 `MessagePage.ets:1262`）。
21. **`content.menu` 图标默认是白色**，静止态栏下若是页面画布（浅色）就是白压白、实测 1.02:1 直接消失。必须显式给 `originalStyle.contentStyle.menuStyle.iconColor`，且用成对 token 不用常量。同一条栏里标题正常不代表菜单正常 —— 它们走 `titleStyle` / `menuStyle` 两个互不相干的槽位。
22. **吸顶分段栏是五版调不好的那个假设本身**：内容区拿不到栏体材质，吸顶行只能靠 `backgroundBlurStyle` 自给表面，而「通透」与「标签过 AA」在这条轴上互斥（§7.6.19 / §7.6.23 的档位表）。官方参照的分段栏压根不吸顶。别再调档，先问要不要吸顶（§7.6.24）。
23. **`isSystemMaterialActive()` 不能用来撤兜底表面**：它只回答「设备支持材质吗」，不回答「我在不在生效区」。生效区判据是**祖先链里有没有 `TitleBar` 节点**（`HdsNavigation` 的 `stackBuilder`/`bottomBuilder` 和普通 `Navigation().title({builder})` 都算），与用哪个 Navigation 组件无关。`NavBarContent` 下的组件据此把 `backgroundBlurStyle` 置 NONE、把描边置 0，结果是材质没来、兜底也没了 —— 静默变成透明壳甚至只剩文字（第 7.6.26 节，真机同帧对照证实）。**别按 builder 函数的命名判位置**：`circleTitleBar()` 真在栏里，`ProfileHeader` 名字普通却住在 `List` 里。
24. **顶栏圆钮有两套互不等价的材质轨，别指望调参跨轨对齐**：官方 `content.menu` 的表面来自栏级 `hdsMaterial.systemMaterialEffect`（EXQUISITE 才有折射环，实测静止态比白画布**暗** 3.2 级），自绘件挂的是通用 `uiMaterial.ImmersiveMaterial` ULTRA_THIN（只有模糊 + 提亮，实测比画布**亮** 2 级、滚动帧是白霜面）。通用轨没有折射开关（§7.6.18），要同一观感只能整件迁进 `content.menu`，同时几何（40vp / 8vp 间距 / 右缘出挑）也得跟着交出去 —— 只统一一项不收敛（第 7.6.27 节，五条栏逐条实测）。
25. **开了 `enableScrollEffect`，`contentStyle` 就要在 `originalStyle` 和 `scrollEffectStyle` 各写一遍**：`originalStyle` 只管特效生效**之前**，接管后菜单项颜色改读 `scrollEffectStyle`，不传就用 HDS 默认白字。静止态看着正常不等于没问题 —— 必须滚过 `blurEffectiveEndOffset` 再量一次（第 7.6.28 节：只写 originalStyle 时模糊态掉到 1.88:1）。
26. **`content.menu` 的表面能摘、typography 摘不掉 —— 文字动作不要迁过去**：`HdsNavigationIconItemStyle` 只有 `backgroundColor / iconColor / textColor` 三个槽，`backgroundColor = Transparent` 可以清掉默认那颗浅药丸（排布/命中/按压反馈照样白拿），但**字号与内边距没有任何入口**（真机：墨迹比自绘高 9%、离右缘多 17vp 内缩）。所以官方件这条路只推荐给**图标钮**；纯文字动作要保原本观感就留自绘（第 7.6.28 节，已试过并逐像素回退）。若保留那颗药丸还要重判字色 —— 它会跟着栏变暗（243→169），「裸文字压深色背板 → 模糊后切白」这类规则在有表面后直接反向失效。
27. **官方 `content.menu` 项要外部量帧，用 `componentId` 而不是自己 `.id()`**：`HdsNavigationIconOptions.componentId` 会原样落到内部 `Button` 节点的 `id` / `key`（dumpLayout 实测 `id = 'homeSearchEntry'`），所以 `componentUtils.getRectangleById()` 这类按 id 取矩形的通路照样命中 —— 一镜到底这种"要拿入口帧当动画起点"的接线迁进官方件不用拆。另外：图标项默认圆底 `#0C000000` 在浅色画布上实测**暗 12 级**，比自绘挂 ULTRA_THIN 白霜（2 级）清楚得多，别默认"必须补栏级 `systemMaterialEffect` 才看得见"（第 7.6.29 节）。
32. **开穿底（`enableComponentSafeArea: false`）之前，先数 `bottomBuilder` 行里有没有"无表面的裸文字"**：内容一穿到栏下，那些字就压在渐变模糊的背板上，而背板亮度随内容变 —— 没有任何固定字色能同时赢过白画布和暗图（实测「找到 N 篇内容」1.78:1）。首页/消息能穿是因为那一行只有分段栏和 chip，两者都有自己的官方表面。有裸文字就先搬进列表当表头，或者这页干脆不穿底（第 7.6.31 节）。
29. **`dynamicHideTitleBar` 配 `enableComponentSafeArea: true` 会让内容跑出手指的 2 倍速**：栏体一收，`Scroll` 顶边跟着栏底上抬，卡片位移 = 滚动量 + 栏体收起量（真机 200px 慢拖 → 卡片走 440px）。`hideRatio` 只改收起用时、不改收起总量，治不了。要真 1:1 绑定只能 `enableComponentSafeArea: false` + 内容自己补 `topInset`（「我的」那套），代价是内容穿到栏下绘制。别把它当成调参问题（第 7.6.30 节）。
30. **系统下拉菜单没有"可编程弹出"入口，所以带 `bindMenu` 的控件一律迁不进 `content.menu`**：整个 SDK 搜 `showMenu` 零命中，菜单只能由 `.bindMenu()` 挂在**自己拥有的节点**上、以它为锚点。`HdsNavigationIconOptions` 没有这个槽位，把这类控件搬进官方菜单，面板就开不出来了。唯一替代是换成 `bindSheet`（相对窗口弹、不需要锚点），但那是改交互形态，得单独拍板（第 8 节 F 条）。
31. **顶栏里放了全宽可点行，就会吃掉官方返回键／菜单钮的点击**：`StackCustomNode`（stackBuilder）是 `Button`（backIcon）与 `HdsMenuNode` 的**后一个兄弟节点**、z 序在上，所以那条行只要带 `layoutWeight(1)` + `onClick`，就会盖住两侧官方件的命中区（真机：点返回跳到了对端主页）。给 stackBuilder 行留出左右内缩 —— 官方件占 16~56vp，内容从 **64vp** 起。**验收必须真点一次官方返回键**，只看节点长出来了不算过（第 7.6.31 节）。
28. **改顶栏的模糊档 / 材质档，必须同时重判这条栏上所有「滚动驱动的字色翻转」**：`brandOnBlur ? White : 墨` 这类开关是为**某一档背板亮度**定的。`GRADIENT_BLUR` 把栏面压深 → 白字是对的；换 `IMMERSIVE_GRADIENT_BLUR` + EXQUISITE 后栏面变亮 → 同一个开关立刻变成白字压亮面（第 7.6.29 节，浅色模式一滑动就复现）。所以换档那一次就要把这条栏上所有吃该开关的着色逐个过一遍，别只改触发它的那颗按钮。
33. **别给 `List`/`Scroll` 这类滚动容器挂自定义 `PanGesture`/`SwipeGesture` 做横滑翻页**：挂上之后快速多次切换页面状态，滚动容器**子树的重渲染会被框架丢弃**——build() 探针证实照常重跑、状态与数据全对、fetch 照常执行，但屏幕内容冻结在旧渲染上且**永不自愈**（下拉刷新、换底部 Tab 都唤不回；手势回调里 `setTimeout` 延迟写状态也救不了，手势挂载本身就是触发条件。「我的」页真机复现 2026-10-24）。滚动容器上的横滑翻页只接受滚动容器**自带的**分页件（`Swiper`），或者像「我的」这样干脆用点击 + 分段栏拖动。
34. **官方 `SegmentButton`（tab 档）自带"拖到哪个分段松手就选哪个"，但它不走 `onItemClicked`**：拖动选择只回写双向绑定的 `selectedIndexes`，宿主若只监听 `onItemClicked`，就会出现「选中面动了、页面不切换」。修法：给封装内部承接 `selectedIndexes` 的 `@State` 挂 `@Watch` 反向同步宿主，且**同步写宿主状态要 `setTimeout` 延迟一拍**——官方组件会在自身更新期回写，同步嵌进渲染期会加剧丢更新。同值守卫防 `syncIndexes` 回灌死循环（`ImmersiveSegmentBar.ets`，真机 2026-10-24）。
35. **产品拍板（2026-10-24，两轮修正后定稿）：分段栏回迁 1.0.1 自绘版；下拉菜单交互保持新版**。①9 处分段栏换回自绘 `SegmentedControl`（参数逐站照抄 1.0.1 c50f8318：透明轨道 + `#99EFEFF2` 滑块 + 弹簧跟手扫选，标题栏内 `useSystemMaterial` 保留），首页滑块跟手机制（`onContentDidScroll`/`onGestureSwipe` 喂 `slidePosition`）恢复；②圈子下拉**保持 bindMenu 系统弹层**——chip 与 1.0.1 本就同款样式（透明底+细描边+系统材质接管），改回内联面板被用户否决（「下拉菜单交互不要变，只改变按钮样式材质」）；③发布页体裁**保持分段选择交互**（自绘分段栏，即迁移前状态），1.0.1 的滚轮弹窗方案试过后撤回。`ImmersiveSegmentBar`（官方 SegmentButton 封装）仅剩两个临时验证页在用，勿据此推断产品形态。第 16/17/22/34 条的技术结论仍然成立（那是官方组件本身的边界），只是产品不再走那条路；「我的」页画布随之回白（材质画布是为官方轨道层次引入的）。
36. **栏级 EXQUISITE 材质会盖掉普通 GRADIENT_BLUR 的透过模糊——两者要共存必须换 IMMERSIVE_GRADIENT_BLUR + originalStyle.blurRadius 动态门控**：给标题栏挂 `systemMaterialEffect`（EXQUISITE）后，普通 `GRADIENT_BLUR` 的滚动透过模糊实测归零（消息页真机 0/80 采样），材质表面把穿栏内容整个挡住。唯一共存配方 = `IMMERSIVE_GRADIENT_BLUR` + `originalStyle.blurRadius`（绝对滚动偏移 >0 门控，**不能用每帧增量正负**——松手弹簧回弹的负帧会打灭开关，「松手模糊消失」根因）+ `maskExtraHeight: 0`。另外：分段栏住在 bottomBuilder 时不要同时挂通用组件材质（ULTRA_THIN）——两轨不等价（第 24 条）且叠加成两层玻璃；让栏透明描边直接站在栏级材质上即可（消息页 2026-10-24/25 落地，与「我的」页同配方）。
37. **给官方悬浮 `TabBar` 的子节点做覆盖层定位，y 要自己补回 `barBottomMargin`**：`componentUtils.getRectangleById().windowOffset` 和 `Area.globalPosition` 两个 API 在这一点上**给出同一个错值** —— 真机实测槽位报 y=2527px，dumpLayout 量到实际渲染在 2439px，差 88px = 28.16vp，正好等于我们传给 `barFloatingStyle.barBottomMargin` 的 `28 + bottomNavInset()(0)`。语义是「系统把悬浮条整体上提了，但 TabBar 子树的矩形按上提之前算」。所以拿这两个接口任一者做覆盖层 `.position()` 都会把东西画到 Dock 底下，必须显式减回这一档；X 方向没有对应 margin，不要顺手也减。另记：覆盖层自己的 `globalPosition`/`Area.height` 报的是**整窗**（(0,0) / 860.8vp），而 dumpLayout 给它的 bounds 从状态栏下沿起算（y=106）—— `.position()` 吃前者，**别拿 dump 的 bounds 校 `.position()`**，会差一整条状态栏（第 7.6.32 节）。
38. **「玻璃件」的判定标准是「表面差 + 镜面 rim + 落影 + 模糊」四件齐全，缺模糊就不算玻璃；而一旦真加了模糊，就必须自带清晰副本并隐掉被它盖住的官方那份**：Dock 选中指示器第一版做成 `brandTint` 10% 蓝填充 + 1px 蓝描边、还往槽位里**内缩**，被判定为「色块贴片不是玻璃」——四条全缺，且尺寸方向整个反了（参照图胶囊宽是 **1.22 倍槽距**、盖过槽位并溢出 Dock 圆端，不是嵌在槽位里）。补上 `backdropBlur` 后真机实拍：底下的官方图标被糊成不可读的蓝色光晕，**这才看懂参照图里胶囊自带一份清晰图标+文字是必然配套，不是装饰**。配套三条：① 被盖那槽的官方件 `opacity(0)`，否则「清晰副本 + 磨砂光晕」叠成脏；② 副本与官方那份**逐像素重合**（承载容器要显式 `justifyContent/alignItems` 居中 —— Column 主轴默认从顶排，漏写真机实测高 2.9vp、落位瞬间图标跳一下）；③ 副本的 index 会随落位变化，**不能走 @Builder 参数**（值快照，见第 21 条同源问题），要用 key 含该状态的单元素 `ForEach` 强制重建。另：白底画布上「更亮」没有余量（Dock 251、上限 255），玻璃只能反向压暗、靠 rim 与投影立住（§7.6.27 结论 3）。第 7.6.32 节，含参照图量化表。
39. **覆盖式玻璃件要响应按压，`hitTestBehavior` 只能是 `Transparent`；而在拿不到材质的面上，点光源要么无感要么过曝，按压反馈只能用「缩放 + 落影收紧」**：`HitTestMode.None` 时覆盖层自己收不到手指，按下去整颗胶囊毫无反应（用户实测反馈）；`Transparent` 才既响应自身触摸、又把命中继续透给下层官方页签 —— 原文覆盖层用它正是这个原因。**改命中模式后必须真点一次切页**（防漂移第 31 条同源）。官方点光源（`CommonMethod.visualEffect()`@12 + `hdsEffect.HdsEffectBuilder().pointLight()`@20）在三档实测里：`BRIGHT+BORDER_CONTENT` 把胶囊从 231 冲到 255、图标从 86 洗到 252（内容消失）；`SOFT+BORDER` 与 `BRIGHT+BORDER` 都只有 +4（无感）。机理：「照边框」作用在**材质自己的边框**上，覆盖层拿不到 `systemMaterial`（§7.6.26），于是只有「照内容」会出效果，而它洗掉的正是要保持清晰的图标。原文那档是深色底、光是反光，压到近白 Dock（251、上限 255）上只剩白化 —— 第 38 条「白画布没有亮度余量」的第二次应验。可用配方：`.scale(MotionTokens.pressSlideScale)` + 落影从 `pillFloat` 换 `cardContact`（影变短=贴近背板），按住帧面积比实测 ×0.879 ≈ 0.94²（第 7.6.32 节）。
