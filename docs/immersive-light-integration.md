# 沉浸光感（Immersive Light）接入实践与踩坑记录

记录时间：2026-10-03。范围：把「首页 / 我的」两块顶栏（含分段栏、按钮）接入 HarmonyOS 沉浸光感的完整过程，以及其中踩到的坑与结论。

所有结论均来自真实设备（华为 Pocket 2 / HarmonyOS 7 / API 26）+ 源码 + 官方文档核对，不是推测。

---

## 0. 结论速览

| # | 结论 | 严重度 |
| --- | --- | --- |
| 1 | `systemMaterial` 只在 **Navigation/NavDestination 标题栏** 或系统底部 TabBar 生效，内容区设置**完全不渲染** | 🔴 决定架构 |
| 2 | 低版本必须用 `AttributeModifier.applyNormalAttribute` + `apiAvailable` **字面量门禁**保护，否则可能崩 | 🔴 崩溃风险 |
| 3 | 材质生效时必须**撤掉自绘兜底**（`backdropBlur` / `backgroundBlurStyle` / `shadow`），否则遮挡或叠加 | 🟠 视觉错误 |
| 4 | 标题栏（STANDARD）栏高**已含状态栏**，内容区再补 `statusBarHeight` 内边距 → 多一条空白 | 🟠 布局错误 |
| 5 | 组件自定义 `@Prop` **不能叫 `systemMaterial`**（与内置通用属性同名，与基类冲突，编译失败） | 🟡 编译报错 |
| 6 | `@Builder` 引用不能放进三元表达式；`@Builder` 体内不能声明 `const` | 🟡 编译报错 |
| 7 | `@Link` 的类型必须与父组件**完全一致** → 类型要 `export` | 🟡 编译报错 |
| 8 | `@Watch` 对**同值写入不触发** → 可用来做「只写一次、天然去重」的联动 | 🟢 可利用特性 |

---

## 1. 两条轨道：先选路，再动手

沉浸光感有 **两条互不替代** 的接入轨道，版本门槛、枚举体系、生效条件完全不同：

| 维度 | HDS 组件轨 | uiMaterial 轨 |
| --- | --- | --- |
| 入口 | `hdsMaterial` / `HdsTabs.barFloatingStyle.systemMaterialEffect` | 通用属性 `systemMaterial(uiMaterial.ImmersiveMaterial)` |
| 起始版本 | HarmonyOS 6.1.0（API 23） | **API 26.0.0** |
| 系统能力 | `SystemCapability.UIDesign.HDSComponent.Core` | `SystemCapability.ArkUI.ArkUI.Full` |
| 覆盖组件 | HdsNavigation 标题栏、HdsTabs 页签 | **任意普通 ArkUI 组件** |
| 档位体系 | `MaterialType`(NONE/ADAPTIVE/IMMERSIVE) + `MaterialLevel`(含 ADAPTIVE=10，可选策略) | `ImmersiveStyle` 五档（厚度）+ 设备算力档（**只读**，`getGlobalMaterialLevel()`） |
| 不支持时 | 查询不到 IMMERSIVE → 降级 SMOOTH | **可设置但无效果**（不报错！） |

**本项目分工**（`entry/src/main/ets/utils/immersiveMaterial.ets`）：

- 底部悬浮导航栏 → HDS 轨（`HdsTabs.barFloatingStyle`，已有）
- 顶栏按钮 / 分段栏 / 弹层面板 → uiMaterial 轨 + HDS 流光（`ImmersiveSurface`）

> ⚠️ 两条轨都有一个叫 `MaterialLevel` 的枚举，语义完全不同（一个可选含 ADAPTIVE，一个是只读算力标签）。混用类型上可能编得过、语义完全错。

---

## 2. 最大的坑：生效范围

### 现象

首页右上角搜索按钮挂上 `systemMaterial` 后，**真机上毫无变化，且不随系统「沉浸光感」强度档位联动**。

### 根因（官方 FAQ「组件不在沉浸光感生效范围」）

> 其他组件**仅在 Navigation/NavDestination 标题栏，或横向 Tabs 中 barPosition 为 `BarPosition.End` 的底部 TabBar 中生效**。在其他区域中设置沉浸光感效果不生效。
>
> 日志特征：`Material inactive: out of scope. Use component in navigation title bar or Tabbar.`

本项目首页的搜索按钮位于 `Navigation(hideTitleBar: true)` 的**内容区**、且在 `TabContent` 内 —— 既不在标题栏也不在底部页签栏，系统直接不渲染。

### 处理

不是"样式没调好"，而是**位置不对**。要沉浸光感就必须把控件放进标题栏：

1. 先做一个**最小验证点**（把主 Navigation 临时 `hideTitleBar(false)`，标题栏里放一个同构按钮），确认真机材质生效、且随系统档位联动 —— 这一步非常关键，能避免在错误方向上反复调样式。
2. 验证通过后再做正式迁移（见 §5）。

### 教训

> **"可设置但无效果"是该 API 的失败模式 —— 不报错、不警告。**
> 接入前先查生效范围；拿不准就先搭最小验证点，确认链路通了再投入改造。

---

## 3. 兼容性保护：低版本设备不能崩

`systemMaterial` 是 `@since 26.0.0`。工程 `compatibleSdkVersion = 6.0.0(20)`，直接写 `.systemMaterial(...)` 在 API 20/22/23 设备上运行期会崩。

### 正确写法（官方《ArkTS API 兼容性保护》示例二/三同款）

```ts
// utils/immersiveMaterial.ets
export class TopButtonMaterialModifier implements AttributeModifier<CommonAttribute> {
  applyNormalAttribute(instance: CommonAttribute): void {
    if (deviceInfo.apiAvailable('26.0.0')) {   // ← 字面量，且必须在 if 条件里
      instance.systemMaterial(getTopButtonMaterial());
    }
  }
}
```

使用处：`Row() { ... }.attributeModifier(this.materialModifier)`

### 为什么必须这么写

- `systemMaterial` 是**属性方法**，在低版本运行时不存在 → 不能无条件调用；
- 门禁必须写在 `AttributeModifier.applyNormalAttribute` 内、且是 `apiAvailable('26.0.0')` **纯字面量 if 判断**；
- ets-loader 在编译期把 `apiAvailable` 降级为本地版本比较函数（产物里叫 `__mockApiAvailable`），**不发起任何新 API 调用**，低版本设备天然安全。

### 编译产物佐证（`entry/build/.../utils/immersiveMaterial.ts`）

```js
systemMaterialActive = __mockApiAvailable(deviceInfo, '26.0.0');
...
if (__mockApiAvailable(deviceInfo, '26.0.0')) {
    instance.systemMaterial(getTopButtonMaterial());
}
function __mockApiAvailable(e, t) { /* 纯读 sdkApiVersion / distributionOSApiVersion 比较 */ }
```

### 官方给出的**反例**（会导致告警消除失效 / 风险）

```ts
// ❌ 用变量传参、自定义封装、逻辑复合、三元表达式、取反 —— 都不受保护
let v: string = '26.0.0';
if (deviceInfo.apiAvailable(v)) { ... }
let r: boolean = deviceInfo.apiAvailable('26.0.0'); if (r) { ... }
if (deviceInfo.apiAvailable('26.0.0') && xxx) { ... }
```

### 同源判断入口

为了让"材质是否生效"可被复用（见 §4），同文件导出了：

```ts
export function isSystemMaterialActive(): boolean   // 门禁同源，进程级缓存
```

---

## 4. 自绘兜底必须让位给系统材质

### 现象

「编辑资料 / 草稿箱 / 废纸篓」挂上材质后，变成**实心毛玻璃按钮**，而不是系统材质的通透感。

### 根因（两个独立问题）

1. **背景模糊遮挡材质**：官方 FAQ 明确「背景色或背景模糊遮挡材质效果」。这三个按钮原本有 `backgroundBlurStyle(GlassBlurStyle.Press)`，自己画了一层毛玻璃，材质被压在下面看不到。
2. **阴影叠加**：材质自带阴影（`ImmersiveOptions.applyShadow` 默认 `true`，且**优先于**通用 `shadow` 属性）；自绘 `shadow` 会与之叠加。

同类问题在**我的页分段栏**上表现为：`SegmentedControl` 的 `immersive: true` 分支会启用 `backdropBlur`（伪沉浸），把材质遮死 → 与首页分段栏观感不一致。

### 处理范式

```ts
// 材质生效 → 撤掉全部自绘兜底；低版本 → 保留原样式
.backgroundBlurStyle(isSystemMaterialActive() ? BlurStyle.NONE : GlassBlurStyle.Press)
.shadow({
  radius:   isSystemMaterialActive() ? 0 : 12,
  color:    isSystemMaterialActive() ? Color.Transparent : ColorTokens.barShadow,
  offsetY:  isSystemMaterialActive() ? 0 : 4,
})
.attributeModifier(this.materialModifier)
```

```ts
// 分段栏：着色风格与材质互斥（immersive 自带 backdropBlur；outlined 是透明底）
immersive:   !isSystemMaterialActive(),   // 低版本：华为应用商店同款沉浸玻璃
outlined:    isSystemMaterialActive(),    // 材质生效：透明底，让系统材质完整透出
glowEnabled: false,
useSystemMaterial: true,
```

### 教训

> **叠加式改造要检查"原来那层还在不在"。**
> 材质是「接管表面」而不是「叠一层」—— 凡是原来在画背景/模糊/阴影/描边的属性，都要在材质生效时显式关掉。

---

## 5. 「顶栏迁入标题栏」标准范式

首页与我的页都按这套做，可作为后续页面的模板。

### 5.1 结构：一块标题栏，按 Tab 分支

```ts
// Index.ets
private mainTitleBarVisible(): boolean {           // hideTitleBar 与内容区避让共用同一条件
  return (this.currentIndex === 0 || this.currentIndex === 4) && this.privacyAgreed === '1';
}

@Builder
mainTitleBar() {                                    // @Builder 引用不能放进三元表达式 → 必须 if/else
  if (this.currentIndex === 4) { this.profileTitleBar() } else { this.homeTitleBar() }
}

Navigation(this.pageStack) { ... }
  .hideTitleBar(!this.mainTitleBarVisible())
  .title({
    builder: this.mainTitleBar,
    height: this.currentIndex === 4 ? this.profileTitleBarHeight() : this.homeTitleBarHeight(),
  }, { barStyle: BarStyle.STANDARD, backgroundColor: ColorTokens.canvas })
```

- **`BarStyle.STANDARD`**：顶栏占位，内容从栏下开始 —— 与原「头部在内容流里」的布局同构，观感不变。
- `backgroundColor` 用页面画布色（也作为材质的采样底色）。
- 关键文件：[Index.ets](file:///Users/itxiaobai/HarmonyProject1/entry/src/main/ets/pages/Index.ets) `mainTitleBarVisible` / `mainTitleBar` / `homeTitleBar` / `profileTitleBar`

### 5.2 状态归属：上移到 Index，子页面 `@Link` 共用

顶栏被搬走后，**顶栏相关的状态必须上移**到标题栏宿主（Index），页面通过 `@Link` 共用：

| 状态 | 归属 | 消费方 |
| --- | --- | --- |
| `feedIndex / feedMode / slidePosition` | Index | 首页顶栏分段栏 + HomeTab Swiper |
| `tagIndex / displayTags / showCircleDropdown` | Index | 圈子 chip + HomeTab 下拉面板 |
| `profileUser / followingCount / followerCount / totalLikes` | Index | 我的页资料区 + ProfilePage |
| `profileTabIdx / profileSlidePosition` | Index | 我的页分段栏 + ProfilePage Swiper |
| `profilePresented / profileShareSeq` | Index | 资料区入场动效 / 分享信号 |

**联动用 `@Watch` 承接"外部写入"**：

```ts
// 子页面：标题栏写入 feedIndex → 这里翻译成信息源加载
@Link @Watch('onFeedIndexChanged') feedIndex: number;

onFeedIndexChanged(): void { this.switchFeed(FEED_MODE_IDX_MAP[this.feedIndex]); }
```

> ✅ **同值写入不触发 `@Watch`** 在这里是优点：Swiper 自身路径（回调 / `switchFeed` 内部）写入相同值时不会重复加载，无需额外去重判断。

**跨层"一次性动作"用递增序号信号**（分享按钮 → 分享流程仍在页面内）：

```ts
// Index：action 里 this.profileShareSeq += 1
// ProfilePage：@Link @Watch('onShareRequested') profileShareSeq: number;
onShareRequested(): void { this.shareProfile(); }   // 弹层/文案/系统分享逻辑留在页面
```

### 5.3 高度：栏高必须精确等于内容，且**状态栏避让只能有一处**

- 标题栏（STANDARD）的栏高**已经涵盖状态栏区域** → 内容区 `padding({ top: 0 })`。
  否则会出现「标题栏与内容之间多出一条状态栏高度的空白」（**实际踩到过**）。
- 其它 Tab 没有标题栏 → 内容区仍需 `padding({ top: statusBarHeight })`。
- 两者必须**共用同一个判断方法**，否则隐藏/显示切换时会不同步：

```ts
.padding({ top: this.mainTitleBarVisible() ? 0 : this.statusBarHeight })
```

- 全屏沉浸式布局下标题栏**不代为避让状态栏**，栏内 Builder 要自己 `padding({ top: statusBarHeight })`。

### 5.4 内容驱动的高度：`onAreaChange` 实测回写

我的页资料区高度是**内容驱动**的（身份块 / 有背景图的 16:10 卡 / 是否登录影响是否有"草稿箱+废纸篓"行），无法只靠常量算准。

做法：首个渲染帧用**估算值**兜底，`onAreaChange` 实测后回写；登录态切换、背景图有无、屏宽变化都会自然修正。

```ts
@State profileHeroHeight: number = 0;

.onAreaChange((_o: Area, area: Area): void => {
  const h: number = parseFloat(String(area.height));
  if (h > 0 && Math.abs(h - this.profileHeroHeight) > 0.5) { this.profileHeroHeight = h; }
})

private profileTitleBarHeight(): number {
  const hero = this.profileHeroHeight > 0 ? this.profileHeroHeight : this.profileHeroEstimate();
  return this.statusBarHeight + LayoutTokens.segmentedHeight + SpaceTokens.xs * 2 + hero + ...;
}
```

### 5.5 需要"向下溢出"的浮层：拆成两个实例

标题栏高度固定，**ArkUI 触摸只命中父节点区域内的子节点** —— 放在标题栏里的下拉面板，展开部分会点不到（还可能有裁剪）。

圈子下拉的解法（`TagNav`）：

- **chip** 渲染在标题栏内（可挂材质，带 `useSystemMaterial` 开关）
- **面板 + 点外关闭遮罩** 渲染在**内容区顶部**（`panelOnly` 模式），贴着标题栏向下覆盖
- 两实例靠共享的 `@Link dropdownVisible` 同步开合；面板选中高亮改用 `selectedIndex` 推导（面板随开合挂载/卸载，不能依赖实例内状态）

---

## 6. ArkTS / ArkUI 语法踩坑清单

| 坑 | 现象 | 处理 |
| --- | --- | --- |
| 自定义 `@Prop` 名与内置通用属性同名 | `Property 'systemMaterial' in type 'X' is not assignable to the same property in base type 'CustomComponent'` | 改名 `useSystemMaterial` |
| `@Builder` 引用放进三元表达式 | 编译失败 | 用 `if / else` 分支包裹 |
| `@Builder` 体内声明 `const` | 编译失败 | 抽成方法（如 `profileBackgroundUrl()`） |
| `@Link` 类型不完全一致 | 编译失败 / 行为异常 | 类型定义 `export`（如 `export type FeedMode`），两端引用同一份 |
| 可选类型字段（`string \| undefined`）直接传给 `Image()` | `Argument of type 'string \| undefined' is not assignable to parameter of type 'string'` | 统一收敛为方法返回 `string` |
| `@State` 变量写在文件顶层作用域 | 编译报错（本项目 `screenWidthVp` 曾误写在 `@CustomDialog` struct 内被引用） | 方法必须定义在**使用它的 struct 内** |
| 高版本枚举 | 静态 import 不存在的模块 → 低版本加载即崩 | 传**数值字面量**（配文件头对照表） |
| `ForEach` key 不含影响 UI 的状态 | 子组件复用、`@Prop` 不刷新 | key 带上状态变量（如未读数、已读态） |

---

## 7. 新增一处沉浸光感 · 自查清单

- [ ] 控件**在不在** Navigation/NavDestination 标题栏（或底部 TabBar）里？不在就先迁移或放弃材质。
- [ ] 材质调用是否包在 `AttributeModifier.applyNormalAttribute` 的 `apiAvailable('26.0.0')` **字面量 if** 门禁内？
- [ ] 档位是否按场景选对？（顶部悬浮 `ULTRA_THIN` / 底部悬浮 `THIN` / 任意弹出 `THICK` / 半模态弹框 `ULTRA_THICK`）
- [ ] 原组件的 `backgroundBlurStyle` / `backdropBlur` 是否已在材质生效时关掉？（否则遮挡）
- [ ] 原组件的 `shadow` 是否已在材质生效时归零？（否则与材质阴影叠加）
- [ ] 低版本（API < 26）下视觉是否与改造前**完全一致**？
- [ ] 栏高是否与内容精确相等？**状态栏避让是否只有一处**？
- [ ] 需要向下溢出的浮层是否已拆到内容区渲染？
- [ ] 构建产物里 `apiAvailable` 是否被降级为 `__mockApiAvailable`？
- [ ] 真机上是否随系统「沉浸光感」强度档位联动？

---

## 8. 相关文件索引

| 文件 | 作用 |
| --- | --- |
| `entry/src/main/ets/utils/immersiveMaterial.ets` | 统一入口：HDS 轨探测、`GlassBlurStyle`、`TopButtonMaterialModifier`、`isSystemMaterialActive()` |
| `entry/src/main/ets/pages/Index.ets` | 标题栏宿主：`mainTitleBarVisible` / `mainTitleBar` / `homeTitleBar` / `profileTitleBar` + 全部共享状态 |
| `entry/src/main/ets/components/HomeTab.ets` | 信息流；顶栏状态改为 `@Link`；圈子面板宿主 |
| `entry/src/main/ets/pages/ProfilePage.ets` | 我的页列表；顶栏状态改为 `@Link`；`PROFILE_SEGMENTS` 导出 |
| `entry/src/main/ets/components/TagNav.ets` | 圈子 chip（标题栏，可挂材质）+ 面板（内容区）双形态 |
| `entry/src/main/ets/design/components/SegmentedControl.ets` | 分段栏；`useSystemMaterial` 开关 + 风格与材质互斥 |
| `entry/src/main/ets/components/ProfileHeader.ets` | 资料区（编辑资料/草稿箱/废纸篓按钮挂材质 + 兜底让位） |
| `entry/src/main/ets/design/components/ImmersiveSurface.ets` | HDS 轨：双边流光表面容器 |
| `docs/home-segmented-control-style-audit.md` | 分段栏静态样式与 token 审计 |

## 9. 官方文档参考

- 《沉浸光感常见问题》— 生效范围、背景遮挡、阴影叠加、反色限制
- 《ArkTS API 兼容性保护》— `apiAvailable` 保护写法与正反例
- 《@ohos.arkui.uiMaterial（系统材质）》— `ImmersiveMaterial` / `ImmersiveOptions` / `ImmersiveStyle`
- 《沉浸光感》设计指南 — 场景规范与档位推荐
