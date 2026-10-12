# 教程：把页面顶栏改造为 Navigation 标题栏，并适配沉浸光感

> 读者：AI 助手 / 开发者。目标：**看完能独立完成一处"顶栏迁入标题栏 + 沉浸光感"的改造**。
> 配套文档：`docs/immersive-light-integration.md`（踩坑记录，讲"为什么"）；`docs/feature-index.md`（项目功能索引）。
> 本文基于 HarmonyOS（ArkUI）+ `uiMaterial` 系统材质（API 26.0.0+）在本项目的真实改造总结。

---

## 1. 这个改造在解决什么问题

- 想给页面顶栏控件（搜索按钮、分段栏、圈子按钮、操作按钮）加上**系统级沉浸光感（Immersive Light）**；
- 但 ArkUI 的通用属性 `systemMaterial` 有**硬性生效范围**：只有 **Navigation / NavDestination 标题栏**、系统底部 TabBar 内的组件才会真正渲染材质；放在内容区**可以设置、不报错、但完全不渲染**；
- 所以工程动作是：**把顶栏区域整体搬进标题栏** → 才有资格谈材质；同时顺手统一了各页顶栏的结构。

一次完整改造 = 三件事：**结构搬迁 + 状态整理 + 材质适配**。

---

## 2. 先决条件（缺一不可，先自查再动手）

| 条件 | 配置位置 | 不满足的后果 |
|---|---|---|
| 应用级材质开关 | `module.json5` → `metadata`：`ohos.arkui.UIMaterial.state = enable` | 帧率/兼容模式不渲染材质 |
| 设备与系统 | API ≥ 26 的设备 + 系统设置里开启沉浸光感 | 低版本调用会崩（必须做门禁）、系统档位为"弱档"时效果轻微 |
| 全屏布局 | 启动时 `setWindowLayoutFullScreen(true)`（本项目现状） | 标题栏与状态栏的关系不同，需另行处理 |
| 材质状态语义 | `DEFAULT / ENABLE / DISABLE`；本项目用 `enable`：未设置背景/模糊/阴影的组件才会自动获得材质 | 自绘了背景/模糊/阴影的组件会被排除，或需要显式挂材质 |

---

## 3. 三条总体原则（改造全程反复回到这里）

1. **组件用原生尺寸，容器适配组件**。不要为了"对齐"去给原生组件（如 `Search`）强塞一个高度；把容器（栏高）做成跟着组件走。
2. **状态栏避让只能有一处**。要么标题栏里手动下移，要么内容区补 padding —— 两处都做 → 出现一整条状态栏高度的空白。
3. **材质是"接管表面"，不是"叠加一层"**。材质生效时，组件/同级节点上的自绘**背景模糊、边框、阴影必须让位**，否则会出现实心毛玻璃、双圈描边等畸形观感。

---

## 4. 标准流程（8 步）

### Step 1 · 判断该用哪种"壳"

| 场景 | 选择 | 本项目实例 |
|---|---|---|
| 主 Tab 页（`Tabs` + `TabContent`） | 主 Navigation 的标题栏，**按 Tab 索引分支**渲染不同顶栏 | 首页 / 我的 / 消息（`Index.ets`） |
| 独立详情页，或组件被多种壳复用 | **组件自带 `Navigation`**，与壳解耦 | 搜索面板（`SearchPanel`）、圈子详情（`CircleDetailView`） |
| 弹窗类（Dialog / Toast / Popup / 菜单 / 半模态）、`Slider / Toggle / Select` | **无需迁入** —— 官方规定这些全页面生效 | 底部发布面板等 |

> 组件自带 Navigation 的好处：router 壳（`@Entry` 页）与 NavDestination 壳（`NavPathStack` 页）**共用一份实现**，两个入口行为天然一致（圈子详情页就是这样做到"双壳零改动"的）。

### Step 2 · 划定顶栏边界 + 决定状态归属

- 边界：用户要求的"XX 及其以上区域"。用注释把区间写清楚（本项目每个顶栏 Builder 头部都写了）。
- 状态归属判据：**标题栏 Builder 写在哪里，状态就归谁**：
  - 标题栏写在 `Index`（主 Navigation）→ 该页的交互状态要**上移到 Index**，子页面用 `@Link` 共用（本项目：`feedIndex / tabIdx / dmTabIndex / slidePosition …`）；
  - 标题栏写在组件内部（自带 Navigation）→ 状态**留在组件里**，无需上移（圈子详情：`sortIndex / joined` 原地不动）。
- 技巧：`@Watch` 只在**值真正变化**时触发；同值写入天然不触发，可放心用"点击写值、`@Watch` 承接动作"的接线（本项目分段栏 `@Link @Watch('onTabIdxChanged') tabIdx` 即此模式）。

### Step 3 · 写标题栏 Builder

结构模板（根节点必须是单个容器）：

```ts
@Builder
xxxTitleBar(): void {
  Column() {
    // ① 顶栏行（标题/操作按钮）② 次级行 ③ 分段栏/工具行 …
  }
  .width('100%')
  // 全屏布局下标题栏不代为避让状态栏 → 手动下移（避让只此一处！）
  .padding({ top: this.statusBarHeight })
  .onAreaChange((_old: Area, area: Area): void => { /* 实测回写，见模板 F */ })
}
```

**高度**（`@State titleBarContentHeight + 首帧估算`）：
- 固定内容（行高都由 token 决定）→ 用 token 表达式直接算；
- 内容驱动（文案折行、头像/媒体尺寸不定）→ **`onAreaChange` 实测回写**，首帧用与 Builder 同源的估算兜底（本项目：我的页资料区、圈子详情三行顶栏）。
- 高度公式始终是：**栏高（含状态栏内边距） = 状态栏 + 上间距 + 内容高 + 下间距**。

> ⚠️ 高频错误：给行设置了**固定高度**，又在同一节点写 `padding` 且 `padding > 高度` —— ArkUI 的 `.height()` 是**含内边距的总高**，内边距会被吞掉，内容溢出、顶到屏幕顶部。

### Step 4 · 内容区让位

- 删除内容区里原有的 `padding({ top: statusBarHeight })`（避让已由标题栏承担，**二选一**）；
- 被搬走的区域在内容区留出对应空位（标题栏 `BarStyle.STANDARD` 是**占位式**，内容自然从栏下开始；`STACK` 是悬浮式，会与内容重叠）；
- 组件内自带 Navigation 的写法（模板 C）：内容根 `Column` 只放剩余内容，尺寸 `100% × 100%`。

### Step 5 · 挂材质（三种承载方式）

| 组件类型 | 正确做法 | 说明 |
|---|---|---|
| 自定义组件（SegmentedControl / TagNav / DesignButton…） | 给组件加 `@Prop useSystemMaterial: boolean = false`，在组件**根节点**挂 `.attributeModifier(this.useSystemMaterial ? this.materialModifier : undefined)` | 默认 false → 其它调用点零影响；本项目已统一为此范式 |
| 原生组件 / 自绘容器（`Search`、`Button`、`Row`…） | 直接 `.attributeModifier(new TopButtonMaterialModifier())` | 修饰器内含版本门禁 |
| **尾随闭包组件（`Pressable` 等）** | ⚠️ 闭包之后**不能再接属性链** → 材质挂到**内层表面节点**（本项目：首页搜索按钮把材质挂在内层 `Row`；DesignButton 挂在表面 `Text` 上） | 这是 ArkTS 语法限制，不是设计选择 |
| 弹窗类 / `Slider / Toggle / Select` | 不需要迁入标题栏 | 官方：全页面生效 |

### Step 6 · 让位规则（材质生效时，自绘必须收起）

统一判断入口：`isSystemMaterialActive()`（与门禁同源，编译期降级为设备版本比较）。

```ts
// 边框 → 置 0（否则与材质叠成第二圈描边）
.border({ width: (this.useSystemMaterial && isSystemMaterialActive()) ? 0 : 1, ... })
// 背景模糊 → NONE（否则遮挡材质，呈现"实心毛玻璃"）
.backgroundBlurStyle(isSystemMaterialActive() ? BlurStyle.NONE : GlassBlurStyle.Press)
// 阴影 → 收 0（材质自带阴影，叠加会发脏）
.shadow({ radius: isSystemMaterialActive() ? 0 : 6, color: ..., offsetY: ... })
```

**档位选择**（官方设计指南 · 场景规范，照抄即可）：顶部常驻 `ULTRA_THIN`、底部悬浮 `THIN`、任意位置弹出 `THICK`、半模态/弹框 `ULTRA_THICK`。

**原生组件的小心机（`Search` 实例）**：原生组件自带的默认背景可能与材质叠成"双层玻璃"。官方规则：**背景色写在材质之前会被系统清除为透明**；写在材质之后才叠加。所以给原生组件设一个底色（低版本兜底），再挂材质，即可得到单层材质表面。

### Step 7 · 低版本兼容（API < 26 不能崩）

```ts
// 必须：字面量调用的 apiAvailable 门禁，放在 AttributeModifier 内
applyNormalAttribute(instance: CommonAttribute): void {
  if (deviceInfo.apiAvailable('26.0.0')) {   // ⚠️ 必须字面量：ets-loader 会编译期降级为设备版本比较
    instance.systemMaterial(getTopButtonMaterial());  // 门禁内才构造材质（进程级缓存）
  }
}
```

- **不要**用变量拼接的版本号、不要包 `try/catch` 裸调 `uiMaterial` —— 官方《ArkTS API 兼容性保护》示例二/三 是唯一正确姿势；
- 低版本 = 门禁不通过 = **保留自绘兜底样式**（描边、玻璃），视觉零变化；
- 材质实例只在门禁内创建并缓存，低版本设备永不执行构造。

### Step 8 · 构建 + 产物核对 + 真机回归

```bash
# 命令行构建（DevEco 内置 hvigor）
export PATH="/Applications/DevEco-Studio.app/Contents/tools/node/bin:$PATH"
export DEVECO_SDK_HOME=/Applications/DevEco-Studio.app/Contents/sdk
/Applications/DevEco-Studio.app/Contents/tools/hvigor/bin/hvigorw assembleHap \
  --mode module -p module=entry@default -p product=default --no-daemon
```

产物核对（比"构建成功"更可靠）：
- `entry/build/.../CompileArkTS/esmodule/debug/entry/src/main/ets/` 下，对应页面/组件的 `.ts`；
- 确认：`.title({ builder, height })`、`useSystemMaterial` 传参、`__mockApiAvailable`（门禁降级的证据）都在位。

---

## 5. 模板库（复制即用）

### 模板 A · 材质修饰器（含门禁）

```ts
let topButtonMaterial: uiMaterial.Material | null = null;

function getTopButtonMaterial(): uiMaterial.Material {
  if (topButtonMaterial === null) {
    topButtonMaterial = new uiMaterial.ImmersiveMaterial({
      style: uiMaterial.ImmersiveStyle.ULTRA_THIN, // 顶部常驻档
      interactive: true,                            // 按压形变
      applyShadow: false,                           // 投影必关，见案例 9
    });
  }
  return topButtonMaterial;
}

export class TopButtonMaterialModifier implements AttributeModifier<CommonAttribute> {
  applyNormalAttribute(instance: CommonAttribute): void {
    if (deviceInfo.apiAvailable('26.0.0')) {
      instance.systemMaterial(getTopButtonMaterial());
    }
  }
}
```

### 模板 B · 主 Navigation 标题栏（按 Tab 分支）

```ts
Navigation() { /* Tabs ... */ }
  .hideTitleBar(!this.titleBarVisible())                    // 例如：仅首页/我的/消息 显示
  .title(
    { builder: this.mainTitleBar, height: this.mainTitleBarHeight() },
    { barStyle: BarStyle.STANDARD, backgroundColor: ColorTokens.canvas }
  )
```

### 模板 C · 页面自带 Navigation（组件内）

```ts
build() {
  Navigation() {
    Column() {
      /* 剩余内容（列表/网格/空态/加载态） */
    }
    .width('100%')
    .height('100%')
    .backgroundColor(ColorTokens.canvas)
    .alignItems(HorizontalAlign.Start)
  }
  .title(
    { builder: this.pageTitleBar, height: this.pageTitleBarHeight() },
    { barStyle: BarStyle.STANDARD, backgroundColor: ColorTokens.canvas }
  )
  .width('100%')
  .height('100%')
}
```

### 模板 D · 自定义组件的 useSystemMaterial 范式

```ts
@Prop useSystemMaterial: boolean = false;
private materialModifier: TopButtonMaterialModifier = new TopButtonMaterialModifier();

// build 根节点：
.attributeModifier(this.useSystemMaterial ? this.materialModifier : undefined)
// 材质生效 → 自绘让位（边框/模糊/阴影三选对应项，见 Step 6）
```

### 模板 E · 内容驱动的栏高（实测回写）

```ts
@State titleBarContentHeight: number = 0;

private xxxTitleBarHeight(): number {
  return this.titleBarContentHeight > 0 ? this.titleBarContentHeight : this.estimate();
}
// 估算函数：与 Builder 行结构同源（状态栏 + 各行 padding + 控件高度）

// Builder 根节点：
.onAreaChange((_old: Area, area: Area): void => {
  const h: number = parseFloat(String(area.height));
  if (h > 0 && Math.abs(h - this.titleBarContentHeight) > 0.5) {
    this.titleBarContentHeight = h;   // 阈值判断防抖，避免布局抖动
  }
})
```

### 模板 F · 向下溢出的浮层 → 拆两个实例

标题栏内的窗体**不能向下溢出**（ArkUI 触摸只命中父节点范围内的子节点）。做法：把"按钮"留在标题栏、把"展开面板 + 点外遮罩"渲染在内容区（本项目：圈子下拉 = 标题栏 chip + 内容区面板）。

---

## 6. 硬性规则清单（DO / DON'T）

| ✅ DO | ❌ DON'T |
|---|---|
| 材质只挂在**标题栏内**的组件上 | 在内容区挂 `systemMaterial`（无效且不报错） |
| 组件用原生尺寸，容器跟着组件 | 给原生组件强塞高度、又与父容器固定高度打架 |
| 状态栏避让只在**一处** | 标题栏与内容区都加状态栏内边距 |
| 材质挂"表面节点" | 尾随闭包（`Pressable`）后接属性链 |
| 材质生效时自绘模糊/边框/阴影**让位** | 材质与自绘模糊/边框叠加（实心毛玻璃 / 双圈描边） |
| 字面量 `apiAvailable('26.0.0')` 门禁 | 变量版本号、裸调 `uiMaterial`、`try/catch` 兜底 |
| 构建后用**编译产物**核对接线 | 只看"BUILD SUCCESSFUL"就交付 |

---

## 7. 真实案例集（现象 → 根因 → 修复）

1. **搜索按钮加了材质完全没反应** → 按钮在 TabContent 内容区，不在生效范围 → 搭"标题栏最小验证点"确认能力 → 迁移顶栏。
2. **"我的"页按钮变成实心毛玻璃** → 组件原有 `backgroundBlurStyle + backgroundColor + shadow` 叠在材质之上 → 材质生效时全部让位。
3. **"我的"页分段栏与首页观感不一致** → 该页分段栏配了 `immersive`（自带 backdropBlur），把材质挡住了 → 与首页统一为"材质生效时 `outlined`（透明底）"。
4. **按钮/分段栏多出一圈描边** → 自绘 1vp 边框画在材质**管不到的子节点**上 → 统一规则：`useSystemMaterial && isSystemMaterialActive()` 时边框宽度置 0。
5. **搜索栏一行贴到屏幕顶** → 行节点"固定高度 36 + padding top 状态栏"，固定高度吞掉内边距 → 行高改为**含内边距的总高**。
6. **原生 Search 放大镜比输入框高 / 材质发浊** → 未显式定高导致内部按真实高度定位；自带默认材质与叠加材质成双层 → 定高统一 + "底色写在材质之前（被清透明）"。
7. **圈子下拉在标题栏里点不到** → 面板/遮罩向下溢出标题栏，触摸命中不到 → chip 留栏内、面板与遮罩移到内容区。
8. **低版本设备风险** → 必须字面量门禁 + 编译期降级（产物里可见 `__mockApiAvailable`），低版本自动回退原样式。
9. **「分段栏下方一条灰带，与标题区/内容区颜色不一致」（真机灰度实测：canvas 255，带内 250~254，紧贴胶囊下沿 241，在标题区/内容区交界 406px 处硬切）** → `ImmersiveMaterial` 的 `applyShadow` 默认为 `true`，投影画在组件外圈；而挂材质的控件都在 `bottomBuilder` 行内，该行（`BottomCustomNode`）`clip=true` 且只比控件高 4vp，投影被拦腰裁切 → 残留部分渲染成带硬边的灰带（首页/消息页同源，非消息页专属）。→ 材质构造显式 `applyShadow: false`（真机复测：交界全列 255，深浅两态、首页/消息页均无带）。**不要**试图靠加大 `bottomBuilder.height` 给投影留位：投影横向扩散 ≥32vp，行高需 ~100vp 才装得下，代价远大于收益。
10. **「列表帖子要能穿到分段栏底下」→ 进一步「穿到资料卡图层下」** → `BarStyle.STANDARD` 是**占位**排布（栏排在内容区上方），列表盒子永远从栏底开始，物理上穿不进去。→ 改 `BarStyle.STACK`（栏覆盖在内容区之上）：真机 `dumpLayout` 实证 `NavBarContent` 与 `TitleBar` **同顶**（都从窗口内容顶起算），列表盒子铺满全屏，帖子能一路滚到窗口顶部。声明栏高**不再决定内容起点**，只圈定「栏体背景画到哪」，所以要画满整条栏（顶栏行 + 资料区 + 分段栏顶部 xs + 分段栏本体），否则胶囊左右缺口与资料卡留白露出未模糊的硬边。另两点实证：① Navigation **不会**把标题栏 Builder 裁到声明高度，溢出部分照常渲染、触摸命中也照常（`uitest` 点溢出区可切分段）；② 内容区**不能**再给根节点加 `padding(top:)`——那等于把列表盒子重新推回栏底，穿底立刻失效；让位要落在「列表内容的顶部 padding / 悬浮件 offset」上，`topInset` 只让到分段栏**顶边**，胶囊本体那一条另计。
11. **「栏底一透明就整条变灰带」/「刷新指示器不见了」** → 穿底要求栏体不能是实色，但 `backgroundBlurStyle: BACKGROUND_THICK` 自带一层灰白着色：它**确实**采样到了底下滚过的列表（留白列灰度静止 230 → 滚动中 214→118 渐变，证明穿底生效），可静止时整条栏 230 vs 内容区 255，把刚消灭的「分段栏下一条常驻灰带」又请了回来。→ 换 `backgroundEffect: { radius: 50, color: Color.Transparent }`（纯高斯、无色罩）：静止时糊的是白底=255（与内容区无缝），有内容穿过才显出模糊形状，深浅两态自适应（`NavigationTitleOptions.backgroundEffect` 是 @since 19，本工程 `compatibleSdkVersion 6.0.0(20)` 已在门槛之上，无需案例 8 那套字面量门禁）。`Refresh` 的自定义指示器同理受新几何影响——盒子顶边跑到窗口顶部，指示器槽位整个藏在栏体底下（实测停在 909~959，被 106~1071 的磨砂糊住），`.offset` 要加到 `topInset + 胶囊本体 + 自身 16vp`（有子分段再 + 一条），才落到栏底之下。
12. **接案例 11：指示器挪出遮挡后，四个分段页顶部「刷新中…」常驻** → `Refresh` 的自定义 `builder` 内容**永远参与布局与绘制**，`.offset()` 只挪绘制不挪布局。改造前它只是被磨砂栏**挡住**了（藏在遮挡区里不等于不存在），一旦 offset 把它挪到栏底之下，静止状态也照样画在胶囊与卡片之间。真机证据：静止 8s、卡片停在 y=1111（未处于刷新态），`dumpLayout` 里 `'刷新中…'` 仍在 `[531,1071][681,1121]`，截图该带能看到文字与转圈。→ 显隐只能**属性级**门控：`@State refreshIndicatorVisible` 由 `.onStateChange()` 按 `Drag/OverDrag/Refresh` 置位，builder 的 `Row` 上 `.opacity(isRefreshing || refreshIndicatorVisible ? 1 : 0)` + 同步 `hitTestBehavior`；**禁止**用 `if` 抽空 builder 内容——指示区高度参与布局，抽空会让区域塌陷、内容区整体上移铺满屏幕。配套：`refreshing` 必须 `$$` 双向绑定，`seg === tabIdx ? isRefreshing : false` 这类单向表达式在 Swiper 横滑切页时内外不同源，是另一条「常驻收不回」的路子（`onRefreshing` 里既不能再手动置 `true`，也不能加 `isRefreshing` 重入守卫）。复测（慢速 `uiInput swipe` 200px/s 抓拉拽中帧）：静止四个分段该带全白无文字，拉拽中指示器随槽位下移到 `[531,1374][681,1424]` 正常显示，松手刷新完回 1111 且带内重新全白，横滑切段后无残留。后补「我收藏」子分段的同一用例（`swipe 600 1500→2250 200px/s`，1.6s 处抓帧）：拉拽中槽位随下拉继续下移、指示器在白色空隙里完整可见，静止时 `[456,1209][681,1245]` 条带最暗 242（无字形）。注意 `snapshot_display` 在 1s 内连拍会返回**同一帧**，抓动画必须拉开 ≥1.2s 间隔并按内容哈希复核，否则会把「静止帧重复」误读成「动画已播完」。
13. **「二级悬浮件（子分段栏）想要沉浸光感」** → 它在内容区，`systemMaterial` 设了也不渲染（生效范围只有标题栏 / 系统 TabBar，见案例 1），只能退回自绘玻璃；而自绘玻璃的模糊半径与着色跟栏体材质不是一套，两条栏之间那条间隙必然留接缝。→ **把它也搬进标题栏**：① 选中态提到外层页面持有、`@Link` 下发（动作仍留在原页的 `@Watch`，业务逻辑不用搬家）；② 栏高**按分支**追加这一行（`extra = 该段 ? xs + 36 : 0`），磨砂矩形随之盖住它；③ **让位锚点别动** —— `listInset` 同步减掉 `extra`，使下发给内容区的 `topInset` 恒等于「主栏顶边」，各段内容留白公式一字不改，只有栏体变长。真机 `dumpLayout` 复核：有子栏的段 `TitleBar` 底边 1196、无子栏的段 1071，子胶囊 1087~1187 落在磨砂区内，静止时两栏之间与栏下各列灰度 243~255（无灰带）。
   - 附带收益：`Refresh` 指示器偏移、二级视图列表的顶部留白都不必再关心「这条悬浮件画在哪一层」，它们与主栏同属一条 `topInset` 序列。
   - 同批补的三项（2026-10-12）：
     ① **尺寸对齐主栏、保持整行铺满**：`itemWidth: 67`（与主栏同值），`fillWidth` 维持默认 true。满宽控件配兄弟节点会把分段栏挤偏（当年它因此被移出顶栏），但解法不是关 `fillWidth` 收成固有宽——那样会多出一条左对齐的短胶囊，与主栏的整行形状不成一套。真正的解法是**在外面包一层加权格子**：`Column(){ SegmentedControl(...) }.layoutWeight(1).height(36).justifyContent(FlexAlign.Center)`，控件根节点那句 `width('100%')` 于是解析在「整行扣掉右侧图标那一格」上，而不是父 `Row` 的全宽。真机 `dumpLayout`：「帖子」子页（无图标）两条目 `[31,1087][568,1187]` / `[568,1087][1105,1187]` 各占一半；「收藏夹」子页整条控件缩为 `[31,1087][981,1187]`，右侧那一格放「管理」图标，滑块落位与点击命中均正常。
     ② **出现方式改淡入**：外层 `Row` 挂 `.transition(TransitionEffect.OPACITY.animation({ duration: MotionTokens.container, curve: MotionCurves.emphasized }))`。**淡入生效、淡出不生效**——移除那一帧栏体立即从 1196 收缩回 1071，消失中的子行落在已收缩的栏槽之外，画不出来。测法是临时把 duration 改成 3000ms 再抓帧：切入收藏时子胶囊文字最暗像素 129（静止为 0~20）、该带 `灰度<120` 计数为 0，即 alpha≈0.5，磨砂轨道 244~251 连续无接缝；切出收藏时同一时刻栏下带均值从 247 直跳 195（内容卡片），子行像素全无。要淡出就得让栏高连续变化，即回到「其余分段的磨砂区跟着抖」那条代价，未做。
     ③ **「管理」入口常驻标题栏**：从收藏夹列表头部（原先随列表滚走）提到子栏右侧，作为子行的第二个子节点（宽度由①那层加权格子自动让出，不需要 `Blank()` 撑）；只在 `profileBookmarkSubTab === 1 && profileFolderCount > 0` 时出现（空列表没有可管理的东西），条数由 ProfilePage 的 `loadFolders()` 经 `@Link folderCount` 上抛。材质与顶栏分享/设置同源（`TopButtonMaterialModifier`，低版本自动跳过）。真机：`uitest` 点 `[1050,1137]` 落到 `pages/BookmarkFolderPage`（页头「收藏夹」+ 底部「新建收藏夹」）；切回「帖子」子段图标消失、控件随之铺回整行（见①），列表头部只剩「共 1 个收藏夹」。图标外面那层 `Row` 只为承载 transition——`Pressable` 是自定义组件，挂不上通用属性。
14. **「内容区自绘的下拉面板与整栏风格脱节」→ 换系统原生菜单**（首页圈子下拉，2026-10-12）→ 旧实现是「chip 在标题栏、面板在内容区」双宿主 + 2000vp 透明遮罩 + 共享开合态，面板自绘玻璃与栏体材质两套模糊半径/着色，怎么看都是另一套东西。官方在 `bindMenu` 上给齐了替代件：定位（`placement`）、越界翻转、点外关闭、滚动（`maxHeight` + `scrollBar`）、材质（`MenuOptions.systemMaterial`，@since 26.0.0）全部系统承担，`TagNav` 只剩 chip 一种形态。三条实测口径：
    - **材质载体只能是 options**：`MenuOptions.systemMaterial` 与 `SheetOptions.systemMaterial` 同源，把 `systemMaterial` 挂在菜单内容组件上属于生效范围外（案例 1）。档位按沉浸光感场景规范取「任意位置弹出 → `ImmersiveStyle.THICK`」，`interactive: false`（菜单是静态容器，形变由菜单项按压态承担）。
    - **`gridStyle` 只对 `MenuElement[]` 载体生效**：官方注释写「`MenuElement in bindMenu` 或 `MenuItemOptions in MenuItem`」二者皆可，真机只有前者出网格——`MenuItem` 传 `MenuItemOptions` 仍走 CustomBuilder 通道，`gridStyle` 静默失效（把 `.selected()/.selectIcon()` 全注释掉复测，依旧单列，可排除是选中属性锁死的）。而 `MenuElement[]` 有两处硬伤：`MenuElement` 结构里根本没有选中态字段（系统对勾没了），且网格单元只有约 61vp 宽，「手机数码」这类四字名截成「手机…」。另外 `count` 的语义是**进网格的条目数**而非列数（`count: 3` → 1 行 3 列；`count: 6` → 2 行 3 列，网格恒为 3 列），`horizontalSize` 传 `tags.length` 与传默认值渲染完全一致。结论：24 个圈子的选择器要「选中可见 + 全名可读」，只能取单列列表，`gridStyle` 不开。
    - **受控模式（`bindMenu(isShow, …)`）关闭不回写 `isShow`**：点外、选中、返回键都只触发 `options.onDisappear`，必须在那里把共享态收回，否则下一次点 chip 的取反逻辑变成「关不掉」。真机复核：开→点 `[973,350]` 出菜单（`Menu [512,421][1086,1671]`，`maxHeight` 按 8 行 ×48vp 折算生效）、点项选中并自动收（chip 文案同步为「手机数码」）、点 `[200,1500]` 空白处收、收完再点 chip 能重新开、切「关注」chip 隐藏且无残留节点。

---

## 8. 改造完成自查清单

**结构**
- [ ] 顶栏边界与用户要求一致（"XX 及其以上"）
- [ ] 标题栏根节点单容器、宽度 100%
- [ ] `BarStyle.STANDARD`（占位）；只有要做「内容穿到栏底下」才用 STACK，且按案例 10/11/12 配套：栏高画满整条栏、内容区根节点不加 padding、栏体用无色罩的 `backgroundEffect`、`Refresh` 指示器 offset 补到栏底之下 + 属性级 `opacity` 门控（`$$` 双向绑定）
- [ ] 内容区不留"想要材质却搬不进栏"的悬浮件：二级栏/二级筛选要沉浸光感，按案例 13 一并搬进标题栏，栏高按分支追加、让位锚点保持不变
- [ ] 下拉/弹出菜单优先用系统 `bindMenu`（材质走 `MenuOptions.systemMaterial`，受控模式记得 `onDisappear` 回写开合态），不要自绘面板 + 遮罩，见案例 14
- [ ] 内容区无重复的状态栏避让

**高度**
- [ ] 栏高 = 状态栏 + 间距 + 内容（与 Builder 实际高度严格相等）
- [ ] 内容驱动的部分有 `onAreaChange` 回写 + 首帧估算兜底
- [ ] 没有"固定高度 < padding"的行

**状态**
- [ ] 状态归属与标题栏 Builder 位置一致（上移 `@Link` 或留在组件内）
- [ ] 交互接线梳理清楚（点击写值 / `@Watch` 承接），滑动跟手用一个连续值

**材质**
- [ ] 所有目标控件都挂了材质（组件用 `useSystemMaterial`，节点用 `attributeModifier`）
- [ ] 材质生效时自绘模糊/边框/阴影全部让位
- [ ] 档位符合场景规范（顶部 ULTRA_THIN / 底部 THIN / 弹出 THICK / 半模态 ULTRA_THICK）

**兼容**
- [ ] 字面量门禁在 `AttributeModifier.applyNormalAttribute` 内
- [ ] 材质实例进程级缓存、门禁内构造
- [ ] 低版本回退样式完好（无空白、无错位）

**回归（真机）**
- [ ] 顶栏位置/观感与改造前一致（除材质外无其它变化）
- [ ] 材质随系统"沉浸光感"强度档位联动
- [ ] 各交互路径（切换、跳转、下拉、返回）全部正常
- [ ] 切 Tab / 双壳入口不串台、不闪烁

---

## 9. 关键文件索引（本项目）

| 文件 | 作用 |
|---|---|
| `entry/src/main/ets/utils/immersiveMaterial.ets` | 材质修饰器、档位规范、`isSystemMaterialActive()` 统一判断、HDS 轨与 uiMaterial 轨说明 |
| `entry/src/main/ets/pages/Index.ets` | 主 Navigation 标题栏（首页/我的/消息）与状态上移范式 |
| `entry/src/main/ets/components/SearchPanel.ets` | 页面自带 Navigation 范式（组件内标题栏 + 原生 Search 适配） |
| `entry/src/main/ets/pages/CircleDetailView.ets` | 双壳复用场景的自带 Navigation 范式 |
| `entry/src/main/ets/design/components/SegmentedControl.ets` | `useSystemMaterial` 组件范式 + 让位规则 |
| `entry/src/main/ets/design/components/DesignButton.ets` | 尾随闭包组件把材质挂"表面节点"的范式 |
| `entry/src/main/module.json5` | `ohos.arkui.UIMaterial.state = enable` 应用级开关 |

## 10. 官方参考

- 沉浸光感设计指南（场景规范 / 三档强度 / 五级枚举）
- 通用属性 `systemMaterial`（API 26.0.0 起）
- 官方 FAQ：组件不在沉浸光感生效范围 / 背景模糊会遮挡材质
- 《ArkTS API 兼容性保护》：示例二/三（新属性挂在 `AttributeModifier` 内做门禁）