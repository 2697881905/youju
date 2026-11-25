---
title: "home-search-entry-title-bar-immersive.md"
id: markdown_798285c88467638f6a8dc28635ad6f33_da0358fb3436871ce19c7fca97c92c877505655250320770
kb: 有据-YouJu
folder: "开发文档"
media_type: 7
tags: []
source: ima
exported_at: 2026-11-23T14:52:37.917Z
---
# 首页搜索入口迁入 Navigation 标题栏（沉浸光感正式落地）

## 摘要

真机验证已通过：主 Navigation 标题栏里的「材质验证」按钮正常呈现沉浸光感材质（且随系统强度联动）。按官方生效范围规则（`systemMaterial` 仅在 Navigation/NavDestination 标题栏或系统底部 TabBar 生效），本计划把**首页右上角搜索按钮**从 HomeTab 内容区正式迁入主 Navigation 标题栏（`BarStyle.STACK` 悬浮、仅首页显示），移除临时验证代码，并保留低版本设备（API < 26）的描边样式兜底。

## 现状分析（探查结论）

### 已验证事实
- Pocket 2（HarmonyOS 7 / API 26）真机上，标题栏中的「材质验证」按钮样式没问题 → `uiMaterial` 轨在标题栏内生效。
- 官方 FAQ：其他组件（非 Slider/Toggle/Select/弹窗/菜单类）**仅在 Navigation/NavDestination 标题栏或横向 Tabs（barPosition=End）底部 TabBar 中生效**；内容区设置材质系统不渲染（日志 `Material inactive: out of scope`）。

### 关键文件与现状

**`entry/src/main/ets/pages/Index.ets`**
- `@State currentIndex: number = 0;`（L229）；`selectTab(index)` 更新 `currentIndex` 与 `activeTab`（L732-738），HdsTabs `.onChange` / `handleTabBarClick` 都汇入 `selectTab`。
- `@State statusBarHeight`（L259）；主内容 `Column` 有 `.padding({ top: this.statusBarHeight })`；`@StorageLink('privacyAgreed')`（L236）控制主 Tab 内容是否构建（未同意隐私前为 Blank）。
- **临时验证代码（本次要替换）**：L829-858 —— 字段 `immersiveVerifyMaterial: TopButtonMaterialModifier`（L836）+ `@Builder immersiveVerifyTitle()`（L838-858，右上角「材质验证」胶囊）。
- **主 Navigation 属性（本次要改）**：L1001-1006 —— `.id('mainNav')` / `.hideTitleBar(false)` / `.title({ builder: this.immersiveVerifyTitle, height: 56 }, { barStyle: BarStyle.STACK })`；随后是 `.clip(false)`（每日一帖飞行卡需溢出顶部）、`.navDestination(...)`、`.customNavContentTransition(...)`（一镜到底，勿动）。
- 已 import：`LayoutTokens/SpaceTokens`（L15）、`RadiusTokens`（L17）、`ColorTokens`（L18）、`TypeTokens`（L19）、`TopButtonMaterialModifier`（L33）。**未 import**：`Pressable`、`resolveActionIcon`、`IconTokens`（迁入按钮需要新增）。

**`entry/src/main/ets/components/HomeTab.ets`**
- 头部结构（build 内）：`Column` → `Row`［`Column`（"有据/SUBSTANTIATE/真实经验"，`layoutWeight(1)`）＋ 搜索 `Pressable`］；搜索按钮为 L848-873：`Pressable({ visualHeight/touchTargetHeight: minTouchTarget, action: pushUrl('pages/SearchPanelPage') })` 包 `Row`（44×44、`glassBorderWidth(1)` 细描边、`RadiusTokens.lg` 圆角、`attributeModifier(this.searchMaterial)`、`accessibilityText('搜索')`）。
- 字段 `private searchMaterial: TopButtonMaterialModifier = new TopButtonMaterialModifier();`（L124）。
- import：`Pressable`（L19，全文件仅此一处使用）、`TopButtonMaterialModifier`（L28，仅字段用）；`resolveActionIcon`/`IconTokens` 另有大量使用点（勿删）。

**`entry/src/main/ets/utils/immersiveMaterial.ets`**
- `TopButtonMaterialModifier implements AttributeModifier<CommonAttribute>`（L76-113）：门禁 `deviceInfo.apiAvailable('26.0.0')` 内置 `systemMaterial(new uiMaterial.ImmersiveMaterial({ style: ULTRA_THIN, interactive: true }))`，低版本自动跳过。**本次不改动，直接复用。**

### 尺寸令牌（对齐依据）
- `LayoutTokens.titleBarHeight = 44 + 16 = 60`（与首页头部行等高）；`LayoutTokens.minTouchTarget = 44`；`LayoutTokens.glassBorderWidth = 1`。
- `SpaceTokens.sm = 8`（头部首行左右内边距），`xs = 4`（头部上下内边距）。

## 变更方案（按文件）

### 1. `entry/src/main/ets/pages/Index.ets`

**1.1 删除临时验证代码（L829-858 整块）**
- 移除 `immersiveVerifyMaterial` 字段与 `immersiveVerifyTitle()` Builder（含其上方临时说明注释）。

**1.2 新增正式首页标题栏按钮（替代上述位置）**

```ts
// 首页右上角搜索入口：迁入 Navigation 标题栏（uiMaterial 沉浸光感的官方生效区域）。
// 低版本设备（API < 26）门禁不通过 → 材质自动跳过，按钮回退为细描边样式（与旧首页一致）。
private homeSearchMaterial: TopButtonMaterialModifier = new TopButtonMaterialModifier();

@Builder
homeTitleBar() {
  Row() {
    Blank()
    Pressable({
      visualHeight: LayoutTokens.minTouchTarget,
      touchTargetHeight: LayoutTokens.minTouchTarget,
      action: (): void => {
        this.getUIContext().getRouter().pushUrl({ url: 'pages/SearchPanelPage' });
      },
    }) {
      Row() {
        Image(resolveActionIcon('search'))
          .width(IconTokens.small)
          .height(IconTokens.small)
          .fillColor(ColorTokens.icon)
      }
      .width(LayoutTokens.minTouchTarget)
      .height(LayoutTokens.minTouchTarget)
      .border({ width: LayoutTokens.glassBorderWidth, color: ColorTokens.barBorder, style: BorderStyle.Solid })
      .borderRadius(RadiusTokens.lg)
      .justifyContent(FlexAlign.Center)
      .alignItems(VerticalAlign.Center)
      .attributeModifier(this.homeSearchMaterial)
      .accessibilityText('搜索')
    }
  }
  .width('100%')
  .height(LayoutTokens.titleBarHeight)
  .padding({ left: SpaceTokens.sm, right: SpaceTokens.sm })
  .alignItems(VerticalAlign.Center)
}
```

按钮内容与旧首页搜索按钮逐属性一致（尺寸/描边/圆角/图标/无障碍文案/跳转行为），仅宿主从内容区变为标题栏。

**1.3 修改主 Navigation（L1001-1006）**
- `.hideTitleBar(false)` → `.hideTitleBar(this.currentIndex !== 0 || this.privacyAgreed !== '1')`
  - 仅首页显示；其它 Tab 完全隐藏（不遮挡消息/圈子/我的页顶部交互，如分段栏、头像、设置入口）。
  - 隐私未同意时不显示（冷启动壳内不出现游离按钮，避免破坏冷启动视觉过渡）。
- `.title({ builder: this.immersiveVerifyTitle, height: 56 }, ...)` → `.title({ builder: this.homeTitleBar, height: LayoutTokens.titleBarHeight }, { barStyle: BarStyle.STACK })`（保持 STACK 悬浮、不挤占内容布局；高度与首页头部行等高 = 60）。

**1.4 新增 import**
- `import { Pressable } from '../design/motion/Pressable';`
- `import { resolveActionIcon } from '../utils/actionIcons';`
- `import { IconTokens } from '../design/tokens/icon';`

### 2. `entry/src/main/ets/components/HomeTab.ets`

- **删除头部搜索按钮**（L848-873 的 `Pressable` 整块，含其注释），头部 `Row` 保留标题块（`layoutWeight(1)`），布局与高度不变（标题块自动占满整行）。
- **删除** `searchMaterial` 字段（L124）及其上方注释。
- **删除 import**：`Pressable`（L19）、`TopButtonMaterialModifier`（L28）——两者在文件内已无其它引用（已核）。`resolveActionIcon`/`IconTokens`/`ColorTokens`/`RadiusTokens` 仍有其它使用点，保留。

### 3. `entry/src/main/ets/utils/immersiveMaterial.ets`

- 不改动（`TopButtonMaterialModifier` 被 Index 复用）。

## 关键决策与假设

1. **只在首页显示标题栏**：搜索入口本就属于首页；其它 Tab 隐藏（动态 `hideTitleBar`），从根上避免 STACK 悬浮层对其它页顶部交互的触摸拦截。
   - 风险：动态切换 `hideTitleBar` 的真机表现未验证；若出现残影/闪烁/不刷新，回退方案：标题栏常驻、Builder 内仅 `currentIndex === 0` 时渲染按钮，并给 Builder 根 `Row` 加 `hitTestBehavior(HitTestMode.Transparent)` 让空白区穿透（按回退方案需再验证其它 Tab 顶部点击）。
2. **材质档位不变**：`ULTRA_THIN + interactive: true`（用户已确认验证按钮样式没问题；对应设计指南「顶部悬浮 → ULTRA_THIN」）。
3. **低版本兜底**：API < 26 时修饰器自动跳过 → 按钮呈现原有细描边样式，无视觉回归、无崩溃风险（门禁已由 ets-loader 降级为版本比较）。
4. **垂直对齐**：标题栏内容区在状态栏下方、行高 60 且垂直居中；与旧按钮位置理论差约 4vp（旧头部首行有 `xs=4` 上内边距）。真机若观感有偏差，用 Builder 根 `Row` 的 padding 微调（±4vp）。
5. **不在本次范围**：SearchPanel 页右上角"同款"按钮（路由页内容区，同样不在生效范围；如需，后续单独按 NavDestination 标题栏方案处理）。
6. **每日一帖飞行卡**：标题栏为透明层、`.clip(false)` 保持不变，卡片仍可抛射越过顶部（真机需回归确认）。

## 验证步骤

1. **构建**（项目惯例命令）：
   `export PATH="/Applications/DevEco-Studio.app/Contents/tools/node/bin:$PATH" && export DEVECO_SDK_HOME=/Applications/DevEco-Studio.app/Contents/sdk && /Applications/DevEco-Studio.app/Contents/tools/hvigor/bin/hvigorw assembleHap --mode module -p module=entry@default -p product=default --no-daemon` → BUILD SUCCESSFUL。
2. **真机（Pocket 2 / HarmonyOS 7）**：
   - 首页右上角搜索按钮带材质（玻璃感、随系统「沉浸光感」强度联动），点击进入 SearchPanelPage（跳转行为不变）。
   - 与旧位置对比无明显错位；页头"有据"区域无重复按钮、无遮挡。
   - 切到消息 / 圈子 / 我的：标题栏隐藏，顶部区域点击（分段栏、头像、设置入口等）全部正常。
   - 回到首页：标题栏恢复；再进详情页/发布流程返回后，标题栏状态正确。
   - 每日一帖：抛卡动画正常越过顶部，不被标题栏裁剪或异常遮挡。
   - 未同意隐私的冷启动壳：不出现游离搜索按钮。
3. **低版本兜底（如可测）**：模拟器/API 20-22 → 按钮为细描边样式、无崩溃。

## 回滚方案

- 将 `.hideTitleBar(...)` 改回 `.hideTitleBar(true)` 并把搜索按钮还原回 HomeTab 头部（改动集中于 2 个文件，均可用 git 回退单文件）。
