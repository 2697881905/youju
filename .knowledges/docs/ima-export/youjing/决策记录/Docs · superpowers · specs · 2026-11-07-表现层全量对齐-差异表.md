---
title: "Docs · superpowers · specs · 2026-11-07-表现层全量对齐-差异表.md"
id: markdown_cls1_798285c88467638f6a8dc28635ad6f33_3ddc219e0ad49f413858ecb0f87343487526104239726721
kb: 有径-YouJing
folder: "决策记录"
media_type: 7
tags: []
source: ima
exported_at: 2026-11-23T14:52:37.917Z
---
# 有径表现层全量对齐「有据」· 基准差异表

日期：2026-11-07　状态：执行中（层 1 冻结）

## 0. 口径

- **唯一事实源**：`/Users/itxiaobai/HarmonyProject1`（下称 `YU/`）当前 `entry/src/main/ets` 源码。
- 优先级：`YU/` 源码 > `Docs/design-v2/DESIGN.md` 契约 > IMA「有据-YouJu」知识库 > 旧 spec 裁决。
- 「按有据的界面结构和布局体系」旧结论（spec §10 33 行对表、契约待改清单 C5–C8、#24/25/26/31）**一律标注为已推翻**；历史正文保留作取证，本表是本次完成度判据。
- 生成方式：`find` 全量枚举（YJ 157 / YU 199 个 `.ets`）+ `color.json` 逐件比对 + `grep -rIn '对标有据'` 锚点 + 24 把 `audit_*.py` 盯的常量/正则集合做集合差 + `verify_route_sweep.py` 路由集合 × 调用点交叉。全部只读命令，非人工列名。
- YJ 符号名与 import 路径**保持不变**；只搬值与配方。两仓 token 形态不兼容，禁止整文件跨仓复制。

## 1. 基线与既有红尺（改动前实测）

| 项 | 读数 |
|---|---|
| 分支 / HEAD | `workbuddy/feat-layout-structure-migration-4fa8ea69` @ `8854751`，工作树干净 |
| `verify_mirror.sh` | rc=0，三份镜像逐字节相同（DESIGN 76598 B / prompts 299661 B / handoff 54049 B），v1 四份冻结哈希未动 |
| 24 把尺 | `audit_contrast.py` 缺 `PIL`（环境）；`audit_motion.py` 15 处历史裸时长集中在 `utils/longTake/longTakeAnimationProperties.ets`；`audit_skip_worktree.py` 环境判定 rc=2。**均为改动前既有红尺**，本次按「净增红尺 = 0」验收 |

## 2. token 值对表（YU 源码 → YJ 落点）

### 2.1 字阶 `YU/design/tokens/type.ets` ↔ `YJ/entry/src/main/ets/design/TypeTokens.ets`

| YU 档 | 值 | YJ 现有档 | 差 | 处置 |
|---|---|---|---|---|
| display | 32/700/40 | display 32/700/44 serif | 行高 40 vs 44 | 值按 YU；保留 serif 归属 |
| displaySerif | 32/700/44 | — | 缺档 | 新增别名 |
| title | 21/**650**/28 | title 21/700/32 serif | 字重+行高 | 新增 `titleSans` 别名，不动现有 title |
| titleSerif | 21/700/32 | title（同值） | 仅名 | 新增别名 |
| headline | 18/600/24 | headline 同 | 0 | 已对齐 |
| body | 16/400/24 | body 同 | 0 | 已对齐 |
| callout | 14/400/20 | **small** 14/400/20 | 仅名 | **新增 `callout` 别名 = small**（不重命名，644 调用点不崩） |
| caption | 12/450/16 | caption 同 | 0 | 已对齐 |
| overline | 11/600/**14** | overline 11/600/**0** | 行高语义 | 保留 YJ「0=不设行高」并登记为平台适配（`audit_type.py` ZERO_LH 钉住） |
| navLabel | 10/400/14 | navLabel 同 | 0 | 已对齐 |
| tabularFeature | 'tnum' | 各页 `.fontFeature("'tnum' on")` | 形态差 | 保留 |

### 2.2 间距 / 圆角 / 阴影（`space.ets` / `radius.ets` / `shadow.ets`）

- **值全等、名错一格**：YU `xs=4/sm=8/md=12/base=16/lg=20/xl=24/x2l=32/x3l=48`；YJ `xxs=4/xs=8/sm=12/base=16/md=20/lg=24/xl=32/xxl=48`。`tools/audit_geometry.py:30-35` 的 `SPACE_ALIAS` 已是这张映射 → **不改值、不改映射**，只在 YJ 新增语义别名（`item=sm`、`block=base`、`section=lg`、`segmentedHeight=segmentedControlHeight`）。
- 圆角 YU `xs=6/sm=10/md=14/lg=20/xl=28/floatingBar=30/pill=999` = YJ `media/capsule/reason/card/hero/dock/pill`，全等 → 只补别名。
- 阴影 YU 5 档 `none/cardContact/cardAmbient/floating/pillFloat` 与 YJ 前 5 档逐字同值；YJ 多 `segmented`/`popover` 两档已在契约 v2 登记且被 `StyleConfig.test.ets:186-187`、`audit_elevation.py` 钉住 → **七档全保留**。

### 2.3 动效 `YU/design/tokens/motion.ets` ↔ `YJ/.../design/MotionTokens.ets`

| YU | 值 | YJ | 处置 |
|---|---|---|---|
| instant / none | 100 / 0 | 缺 | 新增 |
| fast / base / slow / enter / page / emphasis | 140 / 220 / 320 / 360 / 420 / 460 | press=140 / control=220 / container=320 / shimmer=1200 | 保留原五档名与值（`StyleConfig.test.ets` 断言 + `audit_motion.py` 白名单依赖），**新增** YU 档名别名 |
| stagger / staggerEmphasis / shimmer | 40 / 56 / 1200 | shimmer 已有 | 新增 stagger 等 |
| pressScale / pressSlideScale / pressOpacity | 0.97 / 0.94 / **0.92** | pressScale 0.97；pressOpacity 被 C4 明令「无消费者不加」 | **新增 pressOpacity 0.92 + pressSlideScale** |
| successScale / enterScale | 1.045 / 0.975 | 缺 | 新增 |
| 曲线 | standard(0.2,0.8,0.2,1) / decelerate(0,0,0.2,1) / accelerate / spring / springSoft / emphasized / linear / springInteract(0.6,0.85) / springBounce(0.4,0.7) / springRelease / springSettle / springTrack | 仅 standard / decelerate / linear / springBounce(0.4,**0.55**) | 补齐曲线；**保留 springBounce 现有 (0.4,0.55)**（曲线指纹被 `StyleConfig.test.ets:120-140` 钉死，改参数会红）→ 新增 `springBounceYu(0.4,0.7)` 别名 |

### 2.4 图标 `YU/design/tokens/icon.ets` ↔ `YJ/.../design/LayoutTokens.ets:216-225`

| YU | 值 | YJ | 处置 |
|---|---|---|---|
| canvas / stroke | 24 / 2 | 无 | 新增 |
| compact / small / standard / tabBar | 16 / 20 / 24 / 24 | `IconSizes.control=22` | **control 22→24** |
| avatarCompact / avatarProfile | 24 / 68 | 无 | 新增 |
| empty | **44** | `IconSizes.display=48` | **display 48→44** |
| shortcutTile | 56 | 无 | 新增 |

- 消费点实测：`IconSizes.control` 36 处 / 18 文件、`IconSizes.display` 20 处 / 11 文件 → **只改 `LayoutTokens` 两个值即辐射全 App**。
- `audit_type.py:19 ICON_TOKEN_SIZES={12,14,18,20,22,48}` 扩到含 16/24/44/56/68。

### 2.5 布局具名量 `YU/.../space.ets` ↔ `YJ/.../LayoutTokens.ets`

| YU | 值 | YJ | 处置 |
|---|---|---|---|
| minTouchTarget | 44 | 44 | 已对齐 |
| segmentedHeight | 36 | `segmentedControlHeight=36` | 新增同名别名 |
| glassBlur | **24** | `HdsChrome.BAR_BLUR_RADIUS=50` | YJ 契约 v2 已判 50（三处栏面），**保留 50 并登记为有意差异**（YU 的 24 是 GlassTokens 语义，见 §4） |
| floatingBarReserve | 94 | `bottomScrollReserve=94` | 仅名 |
| skeletonDefaultWidth / HighlightWidth | 160 / 56 | 同 | 已对齐 |
| hairlineWidth / glassBorderWidth | 0.5 / 1 | 同 | 已对齐 |
| profileStatWidth / tabBar* | 72 / 64 / 58 / 50 / 18 / 18 | 同 | 已对齐 |

## 3. 资源色表（`resources/{base,dark}/element/color.json`）

- 实测：YU 各 **79** 件（`ds_*` 前缀），YJ 各 **53** 件（无前缀），同名交集仅 3（`surface_elevated` / `start_window_background` / `bar_shadow` 一类）。
- **表面阶梯与语义色逐值全等**（只差命名前缀/alpha 位）：YU `ds_canvas/ds_elevated/ds_subtle/ds_panel/ds_sunken` = YJ `canvas/surface_elevated/surface_subtle/surface_panel/surface_sunken`；`ds_text_primary/secondary/tertiary/quaternary/ds_icon` = `ink/body/muted/faint/icon`；`ds_brand/brand_press/brand_tint` = `primary/primary_press/primary_tint`；深色同理。YU 另有同名 `surface_elevated`（`#F2F2F4`）是其**遗留件**，不是 `ds_elevated`，不构成差异 → **现有 53 件值一律不动**。
- 唯一需新增的是 YJ 侧缺失的语义（`brandSolid` / `onBrand` / `dangerTint` / 玻璃栏面一组），按 YU 成对新增（8 位 `#AARRGGBB`）：

| 语义 | YU base | YU dark | YJ 新键 | 用途 |
|---|---|---|---|---|
| brandSolid | `#0066CC` | `#0050A0` | `brand_solid` | 选中胶囊/主按钮实心底；白字 7.91:1 |
| onBrand | `#FFFFFF` | `#FFFFFF` | `on_brand` | 实心品牌底上的字 |
| dangerTint | `#1AFF3B30` | 同 | `danger_tint` | SoftChip DANGER 档 |
| barSurface | `#70FFFFFF` | `#59121212` | `bar_surface` | 玻璃栏面兜底 |
| barBorder | `#66C4C4CA` | `#5245454B` | `bar_border` | 玻璃栏面 1vp 描边 |
| glassSegmentBg | `#1A3C3C43` | `#20FFFFFF` | `glass_segment_bg` | 分段玻璃底（blur 20） |
| glassSegmentBorder | `#2E3C3C43` | `#24FFFFFF` | `glass_segment_border` | 分段玻璃描边 |
| glassCardBg | `#F7F7F8` | `#1E1E1E` | `glass_card_bg` | 内容卡玻璃底 |
| glassBarBg | `#E5FFFFFF` | `#B3121212` | `glass_bar_bg` | 悬浮条玻璃底 |
| skeletonBase / Highlight | `#E8E8EC`/`#F8F8FA` | `#2A2A2F`/`#35353B` | 已有同名 | 已对齐（`audit_colors` 0 偏差） |
| dsSeparator | `#333C3C43` | `#4D545458` | `separator` | 已有，已对齐 |

- `audit_colors.py` 对「契约未直接命名」的件只列 `unchecked` 不判红 → 新增色件不破尺，但**必须在 DESIGN.md Translucency ledger 增同名浅/深条目**，否则契约失同步。
- **残留 `primaryTint` 5 处 = 视觉等价，保留**：有据 `ds_brand_tint` 浅 `#1A0066CC` / 深 `#330A84FF`，有径 `primary_tint` 浅 `#1A0066CC` / 深 `#330A84FF`，**逐值相同、仅异名**。5 处（`EditItineraryPage:428` 拖动高亮、`MinePage:148` 头像底、`TripsPage:387` 阶段胶囊、`TripsPage:558` 回顾卡、`ItineraryPage:808` 联动高亮）语义均为非选中态，改 `brandSolid` 会误读为「选中」→ 不动。

## 4. 组件映射表（YU 源码 → YJ 落点）

| # | YU 组件 | YU 关键规格 | YJ 现状 | 处置 | 落点级别 |
|---|---|---|---|---|---|
| 1 | `design/components/DesignButton.ets` | 四变体 primary/ghost/glass/outlined；`callout 14` + `headline.weight 600`；primary=brandSolid+onBrand；outlined=透明 + 1vp barBorder + pill；禁用 `.opacity(0.45)`；press scale+opacity 走 Pressable | `components/YoujingButton.ets` 官方 Button + 三变体 + `body 16` + 禁用换 muted | 新增 `DesignButton`（YJ 资源名/具名 interface 重写），`YoujingButton` 改为薄适配层委托它（55 个调用点 API 不动） | 组件级 |
| 2 | `design/motion/Pressable.ets` | `.animation({fast,standard})` **在** `.stateStyles()` 之前；normal opacity1/scale1；pressed opacity0.92/scale0.97；`.responseRegion(44)`；`.enabled(!disabled)` | `components/Pressable.ets` 仅 scale，无 opacity；responseRegion 已有 | 补 opacity 两态 + 保留顺序硬约束 | 组件级 |
| 3 | `design/components/ChipRow.ets` | 选中 `brandSolid` + `onBrand`；未选 `sunken`；`chipHeight=segmentedHeight 36`；`RadiusTokens.sm(10)` 方片；`Pressable(touchTargetHeight=44)` 保命中 | `components/ChipRow.ets` tint + 描边；`TripInputPage` 内联胶囊 44 | 组件按 YU 重写；逐屏 12 处 `primaryTint` 判定选中语义后改 `brandSolid` | 组件 + 逐屏 |
| 4 | `design/components/EmptyState.ets` | 图形 `IconTokens.empty 44` + `.fillColor(icon)`；`headline 18/600` serif；`callout 14` secondary；brandSolid 动作钮；`accessibilityGroup(true)` | `components/EmptyState.ets` 48/title21 且**零消费方**；三处内联空态（TripsPage/BadgePage/AreaMorePage） | 件按 YU 重写；三处内联逐处改档（布局各异，不直接换件） | 组件 + 逐屏 |
| 5 | `design/components/BaseCard.ets` | `CARD_PADDING=16`、20 圆角、cardAmbient 影、stateStyles 按下反馈 | 无件；23 处卡内缩已收口 16 | **不新增**（2026-11-07 收尾复核）：有据该件 2 个调用点包的是其**固定内缩**卡；有径 17 屏卡片内缩各不相同，硬套会改版式 → 登记「不适用」，不引入 | — |
| 6 | `design/components/GlassPanel.ets` | `backgroundBlurStyle(GlassBlurStyle.Card)` + elevated 底 + 1vp separator + `xl(28)` 圆角 + cardAmbient 影 + clip(true) | 无 | 新增；落点 1 处：`GenerateFailedPage` 失败说明块（`radius: RadiusTokens.card`）。其余屏卡片内缩各异，不铺 | 组件 + 单屏 |
| 7 | `design/components/GlowInput.ets` | **默认官方原生**：实色 subtle + 无描边 + 无模糊 + `lg(20)` 胶囊 + 40vp；`segmentStyle=true` 才走玻璃（YU 当前 0 调用方） | 无；YJ 5 处 `TextInput(`（ExpensePage 3 / TripInputPage 2） | 新增；**只有对话类输入接入**：`TripInputPage` 其他城市 + 一句话描述（对应有据 `ChatView`/`DetailActionBar` 那 4 个调用点）。ExpensePage 3 处是表单，有据表单就是原生 `TextInput`（`StructuredComposer.ets:236-271`），只对齐字档/底色/圆角 | 组件 + 逐屏 |
| 8 | `design/motion/SpringPanel.ets` | `panelWidth 344` + `panelPadding SpaceTokens.lg(20)` + 三档（玻璃/outlined/solid）+ 入场 `.opacity/translate/scale` + `container 320`/springSoft | 无；YJ 8 处 `bindSheet(` | **不新增**（2026-11-07 收尾复核）：该件在有据只服务 4 处 `@CustomDialog` 居中弹窗（`FolderNameDialog:40` / `JoinedCirclesDialog:79` / `FolderPickDialog:83` / `Index:246`），有径全仓 **0 处** `CustomDialogController`/`openCustomDialog`/`@CustomDialog`，无载体；半模态在有据走 `bindSheet` + `systemMaterial`，配方见 §6 → 登记「不适用」，8 处 `bindSheet` 改补材质门控 | — |
| 9 | `design/components/ImmersiveSurface.ets` | 双边流光 `DUAL_EDGE_FLOW_LIGHT_WITH_BACKGROUND_MASK`，流光层置最上层，尺寸 explicit/onAreaChange，`hitTestBehavior(Transparent)` | `components/ImmersiveSurface.ets` 已有（自 YU 移植），**保留 YJ 浅色 LIGHT_* 四色 / clip / 主题跟随**（用户拍板保留） | 恢复 scene 参数与「表面可透明」，健壮性修复不动 | 组件级 |
| 10 | `design/components/ImmersiveSegmentBar.ets` | **官方 SegmentButton**（`YU:6-9` 明写不再自绘表面），仅 `selectedBackgroundColor` 一处自绘 | `components/ImmersiveSegmentBar.ets` 同路线 | 对齐参数；保留 YJ 深色选中面修复 | 组件级 |
| 11 | `design/components/GlassPillButton.ets` | 顶栏玻璃胶囊钮；材质生效时自绘 border/shadow 归零 | 无 | **不新增**（2026-11-07 收尾复核）：有据 6 个调用点全在 `ProfileHeader` / `UserProfileView` 的个人主页标题栏（草稿箱/废纸篓/关注/私信/去登录），有径对应位置是列表行而非标题栏钮；地图页浮层 CTA 需要**不透明**可读表面，`Pressable` 包 elevated 胶囊更合适 → 登记「不适用」 | — |
| 12 | `design/components/SoftChip.ets` | 三档 neutral/brand/**danger**；禁用 `.opacity(0.45)` | `components/SoftChip.ets` 两档、禁用换 muted | 补 DANGER 档 + 禁用改 opacity | 组件级 |
| 13 | `design/components/StatRow.ets` / `Avatar.ets` / `Separator.ets` / `Skeleton.ets` | 72vp 一档 / 24·40·56 圆 / 发丝线 / 1200ms 流光 | YJ 8 个家族件「已落地未挂载」，只在 ohosTest 编译图 | 按差异值对齐，保持 8/8 进编译图 | 组件级 |
| 14 | `design/components/BottomTabBar.ets` | **仅 API 20–22 降级分支**（`YU/pages/Index.ets:2081`） | 无 | 新增低 SDK 降级分支；`Index.ets` 加 `deviceInfo.sdkApiVersion >= 23` 分流；不改 `build-profile.json5` | 组件 + 壳 |
| 15 | `utils/immersiveMaterial.ets` | `GlassBlurStyle` Floating/Card/Press/Dialog；`TopButtonMaterialModifier` / `FloatingTopButtonMaterialModifier`；`isImmersiveLightSenseSupported()` | `YJ/utils/immersiveMaterial.ets:53-58` 记 #38 已删三个入口，仅存 Sheet/Menu/Segment 工厂 | 恢复四档 + 两个 modifier（均在 `apiAvailable` 门禁内） | 组件级 |

## 5. 交互态配方（YU 实测，YJ 落点）

| 态 | YU 实现 | YJ 处置 |
|---|---|---|
| 默认 | `DesignButton` 四变体默认参数 | 见 §4-1 |
| 按下 | `motion/Pressable.ets:32-45`：`.animation({duration:fast,curve:standard}).stateStyles({normal:{.opacity(1).scale(1)},pressed:{.opacity(disabled?1:0.92).scale(disabled?1:0.97)}}).enabled(!disabled)` | 补 `.opacity` 两态；`.animation` 必须紧贴 `.stateStyles` 之前（`audit_motion.py` 钉） |
| 禁用 | `DesignButton.ets:115` / `SoftChip.ets:73` `.opacity(disabled ? 0.45 : 1)` | 删 `YoujingButton.ets:36-43` 的 muted 换色与「禁 opacity」注释 |
| 聚焦 | `GlowInput.ets:91-92` `.onFocus/.onBlur → onFocusChanged` | 移植件带该回调 |
| 加载 | `motion/Skeleton.ets` + shimmer 1200 | 家族件对齐 |
| 空 | 见 §4-4 | 见 §4-4 |
| 错误 | YU 无独立 error 件，复用 outlined / DesignButton | `GenerateFailedPage` 表面按配方改，业务文案不变 |
| **不做** | `onHover` / `hoverEffect` 全仓 **0 处** | 明确不加，任何 hover 判据不进尺 |

## 6. 材质与渐变点位

- 档位：`GlassBlurStyle` Floating=`BACKGROUND_THICK`（悬浮栏/底栏/弹层）、Card=`BACKGROUND_REGULAR`（内容卡）、Press=`BACKGROUND_THIN`、Dialog=`BACKGROUND_THICK`；`GlassTokens.SEGMENT_BLUR=20`、`SEGMENT_BG`/`SEGMENT_BORDER` 随深浅；栏面 `BAR_BLUR_RADIUS=50` 与 `scrolled?50:0` 门控保留。
- YJ 现状渐变 3 处（`MapPage:362` 底图淡出、`StayPickPage:489` 路线背景、`Skeleton:71` shimmer）、`backgroundBlurStyle` 5 处（`ItineraryPage:873` 回退 + `ImmersiveSurface` 2 处注释）、`.shadow(` 4 处消费（TripsPage/StayPickPage/MapPage/EditItineraryPage）。
- 新增点位按 YU 实际：内容卡 → `GlassPanel`；对话类输入框 → `GlowInput`；浮层 → `ImmersiveSurface` 流光；顶栏钮 → `TopButtonMaterialModifier`。`SpringPanel` / `BaseCard` / `GlassPillButton` 经复核在 YJ **无载体**，不引入（§4 #5/#8/#11）。
- **半模态（`bindSheet`）配方**——逐字照 `YU/components/DetailPostContent.ets:287-296`，8 处全部落地：
  `systemMaterial: getSheetImmersiveMaterial(), blurStyle: isSystemMaterialActive() ? BlurStyle.NONE : GlassBlurStyle.Floating, backgroundColor: isSystemMaterialActive() ? undefined : ColorTokens.canvas`。
  材质生效时自绘 blur 与实色底都必须让位，否则玻璃面外再叠一层 = 双表面；材质不可用时按 `Floating` + `canvas` 兜底（与改前行为等价，真机不退回透明壳）。
- 三条避让（写进新件文件头）：① 材质生效时自绘 `border.width→0` / `shadow→none` / `backgroundBlurStyle→NONE`；② `systemMaterial` 只在 Navigation/NavDestination 标题栏或系统 TabBar 生效，内容区必须 `backgroundBlurStyle` + 实色兜底，半模态/菜单/分段栏走 options 字段；③ `hdsMaterial`/`barFloatingStyle` @since 23、`systemMaterial` @since 26，全部 `deviceInfo.apiAvailable` + `canIUse` 门禁，**门禁外溢会被 `audit_material.py` R4 判红**（除 `utils/immersiveMaterial.ets` 外任何文件不得出现 `deviceInfo.apiAvailable(` / `deviceInfo.sdkApiVersion`）。

## 7. 消费点实测（决定「改 1 处辐射全 App」还是「逐屏」）

| 符号 | 处数 | 文件数 | 落点 |
|---|---:|---:|---|
| `YoujingButton(` | 55 | 21 | 组件级（改 `YoujingButton` 一个文件） |
| `IconSizes.control` | 36 | 18 | token 级（改 `LayoutTokens` 一个值） |
| `IconSizes.display` | 20 | 11 | token 级 |
| `primaryTint` | 14 | 10 | **逐屏判定**（含 `ColorTokens.ets` 2 处定义、`ChipRow.ets` 2、`TripInputPage` 2、`TripsPage` 2、`Avatar`/`OptionCard`/`EditItineraryPage`/`ExpensePage` 各 1） |
| `ImmersiveSurface(` | 2 | 2 | 组件级 |
| `ImmersiveSegmentBar(` | 2 | 2 | 组件级 |
| `bindSheet(` | 8 | 5 | 逐屏（ExpensePage 2 / ItineraryPage 2 / TripInputPage 2 / EditItineraryPage 1 / LoginView 1）→ 补 §6 材质门控三条，**不包 SpringPanel** |
| `TextInput(` | 5 | 2 | 逐屏：ExpensePage 3 处表单按有据表单配方对齐字档/底/圆角；TripInputPage 2 处对话类换 `GlowInput` |
| `Button(`（非 YoujingButton） | 31 | 14 | **分两类**：① `Button({ type: ButtonType.* })` **11 处**是「用 stateEffect 当按压态的壳」，已全部换 `Pressable`（视觉下沉内层 Column）：`MinePage:309` 换 `YoujingButton(PRIMARY, fullWidth)`、其余 10 处换 `Pressable`；② `Button('label')` / `Button() {}` **20 处**是胶囊/分段族，已带 `brandSolid`+`onBrand`+`callout 14`+高 36+`responseRegion(44)`，与有据 chip 配方逐项一致，**不动** |
| `.shadow(` | 8（4 消费） | 6 | 逐屏 |
| `stateStyles` | 6（1 生产消费） | 3 | 组件级 |
| `EmptyState(` | **0** | 0 | 三处内联逐屏改 |

页面清单以 `pages/AppRouter.ets:54-88` 的 17 路由 + `pages/Index.ets` 5 个 dock 根页为准（`main_pages.json` 只注册 `pages/Index`）。

## 8. 契约 / 尺 / 测试同步清单（不改就红）

| 对象 | 位置 | 同步改法 |
|---|---|---|
| 契约「四处玻璃面 / only four」「Don't apply glass to cards」 | DESIGN.md §5/§Do's and Don'ts + 三份原件 | 改为「材质点位由本差异表登记，卡片/输入框/弹窗允许自绘玻璃」 |
| 契约「禁 opacity 表达状态」「官方件优先、禁自绘」 | DESIGN.md §8 禁令 10、`youjing-engineering-handoff.md` §8、`youjing-stitch-prompts.md` 全局规则块、各 `.ets` 文件头 | 同批改口径句；**历史实测/取证行逐字节不动** |
| C5–C8 数值 | DESIGN.md:922/809/440-444/1150、§9 决议 1 | 按钮 14、brandSolid+onBrand、36+responseRegion、44/18；对比度论证重算 |
| `audit_type.py:19` `ICON_TOKEN_SIZES` | tools | 扩到含 16/24/44/56/68 |
| `audit_material.py` | tools | 扩允许材质点位清单；`--selftest` 阳性/阴性样本同步（DOC_* 三个常量与断言数必须对表） |
| `audit_motion.py` | tools | 保留顺序判据，W4 白名单容纳新增 MotionTokens 档 |
| `audit_geometry.py` / `audit_colors.py` | tools | 映射不动；DESIGN.md 增补新色件 ledger 条目 |
| `audit_a11y_name.py` / `audit_button_width.py` / `audit_label_fit.py` | tools | 加「36 视觉高必须挂 `responseRegion(44)`」判据 |
| `audit_contrast.py` | tools | brandSolid/onBrand 对比度口径重算 |
| `StyleConfig.test.ets` / `FamilyProbePage.ets` | ohosTest | **新增断言不删旧断言**：pressOpacity、IconSizes 24/44、IconTokens 全档、SoftChipTone.DANGER、callout 别名；曲线指纹与七档阴影断言保留 |
| `verify_mirror.sh` | tools | 三份原件 ↔ `Docs/design-v2/` 逐字节 cmp；`Docs/design-v1/` 四份冻结哈希绝不动 |

## 9. 平台限制 / 保留 / 不适用登记（格式照 `2026-11-05-契约待改清单.md:41-50` C3 六要素）

| 编号 | 项 | 结论 | 状态 |
|---|---|---|---|
| P-01 | 栏体 `barBackground` 给实心色时 `TitleBar` 仍 `#00000000` | 平台限制（C3 已证伪），壳层涂色是顶边基色的唯一实现点 | 已回退，注释落在 `HdsChrome.ets` / `Index.ets` |
| P-02 | API 门（@since 23）在 compatibleSdk 26 下是死代码 | 不跟 | 已裁决 |
| P-03 | 栏下无内容时栏级材质「无可见折射」 | **设计使然**（spec §10 ① 续 214 阳性对照） | 登记，非欠账 |
| P-04 | Dock 覆盖层 `systemMaterial` 不出图 | 平台限制（`YU/utils/immersiveMaterial.ets:179-182`） | 引用既有证伪 |
| P-05 | 内容区 `systemMaterial` 完全不渲染 | 平台限制，一律 `backgroundBlurStyle` + 实色兜底 | 本次真机 A/B 后确认 |
| P-06 | 部分真机 `backgroundBlurStyle` 渲染为不透明面板 | 平台限制（`YU/.../ImmersiveSurface.ets:91`），流光层置最上层 | 本次真机 A/B 后确认 |
| P-07 | YJ `ImmersiveSurface` 浅色 `LIGHT_*` 四色 / 外层 clip / `@StorageProp('isDarkMode')`；`ImmersiveSegmentBar` 深色选中面 | **平台适配差异，用户拍板保留**；仅恢复 YU scene 参数与「表面可透明」 | 保留并登记，不计欠账 |
| P-08 | `TypeTokens.overline/time` lineHeight=0 语义 | 平台适配（`audit_type.py` ZERO_LH 钉住） | 保留 |
| P-09 | 低 SDK（API 20–22）`BottomTabBar` 降级分支 | 用户要求预留；compatibleSdk 26 下**当前设备不可达** | 标记「预留兼容，当前设备未验证」 |
| P-10 | 3 个桌面 widget 卡片（`TodayCard` / `TodayTripCard` / `TodayTripFormAbility`） | **不适用**：YU 无对应件；契约规定 widget 实色不模糊 | 保持不动 |
| P-11 | `HdsTabs` / `HdsNavigation` 官方导航壳 | YU 当前 API 23+ 主分支同为官方件（自绘 `BottomTabBar` 只在低版本分支） | 保留，不推倒 spec §10 的 33 行成果 |

## 10. 交付与验收

交付 = 完整可编译的 ArkTS 前端实现，不是报告。业务层（`model/`、`data/`、`ai/`、`bff/`、`cloud/`、页面文案、数据结构、路由注册）零改动。

判据：`verify_mirror.sh` rc=0；24 把尺**净增红尺 0**（基线 3 把红尺见 §1）；各尺 `--selftest` 阳性/阴性对照全过；`assembleHap` BUILD SUCCESSFUL 且零 ArkTS error（含 `entry@ohosTest`）；hypium 251+/251+；`verify_route_sweep.py` / `verify_scroll_clearance.py` / `verify_dock_tabs.sh`；逐屏浅/深 × 静止/滚到位四格同机位复拍 + `uitest dumpLayout` bounds 反证；`audit_contrast.py` 低对比度 0。收尾 `git push origin HEAD:workbuddy/feat-layout-structure-migration-4fa8ea69`，不合并 main。
