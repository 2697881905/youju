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

---

## 8. 改造完成自查清单

**结构**
- [ ] 顶栏边界与用户要求一致（"XX 及其以上"）
- [ ] 标题栏根节点单容器、宽度 100%
- [ ] `BarStyle.STANDARD`（占位）或明确说明为何用 STACK
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