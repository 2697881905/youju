# 搜索面板搜索框：代码实现与样式方案分析报告

> 分析对象：首页 Tab → 搜索入口 → 搜索面板中的搜索框
> 代码基线：main 分支（截至 2026-09-29，含 revert 提交 815ac0b）

## 一、结论摘要

搜索面板的搜索框并非页面内自绘组件，而是复用项目设计系统中的统一输入框组件 `GlowInput`（`design/components/GlowInput.ets`），并以 `segmentStyle: true` 启用"分段栏同款"玻璃材质。其实现要点是：原生 `TextInput` 做输入本体 + 组件壳负责材质/布局/回调透出；样式要点是：**一套组件、两种材质模式**（系统玻璃兜底 / 手工玻璃对齐分段栏），全部取值来自 design tokens，与首页分段栏共享同一组常量。整体方案以较低的代码量实现了跨页面视觉一致性和 API 版本兼容性。

## 二、组件定位与调用链

首页 Tab 顶部标题栏右侧只有一个搜索图标按钮（`HomeTab.ets:845`，透明底 + 细边框 + lg 圆角），点击后 `pushUrl` 进入独立路由页。真正的搜索框在搜索面板内，调用链为：

```
pages/SearchPanelPage.ets     路由壳：状态栏安全区预留 + 画布底色
  └─ components/SearchPanel.ets    面板：玻璃工具栏 + 最近搜索 + 双列热搜 + 联想卡
       └─ design/components/GlowInput.ets   ★ 搜索框本体（segmentStyle: true）
```

`SearchPanel` 通过 `@Builder searchInput()`（`SearchPanel.ets:124-148`）实例化搜索框：

```ts
GlowInput({
  placeholder: '搜索你关心的经验和问题',
  text: $keyword,          // @Link 双向绑定面板的 @State keyword
  fillWidth: true,         // Row 内 flex 拉伸，与返回键、搜索按钮并排
  segmentStyle: true,      // 分段栏同款玻璃材质
  onChange / onEnter / onFocusChanged  // 联想防抖 / 回车提交 / 聚焦状态机
})
```

## 三、代码实现分析

### 3.1 结构：原生组件做内核，壳做差异化

`GlowInput` 内部是 `Stack` 居中包一个原生 `TextInput`，不自绘文本、不接管光标与键盘行为。组件壳只负责三件事：材质与圆角、布局模式、回调透出。这使输入法、文本选择等系统能力零成本继承。

### 3.2 两种布局模式（`fillWidth`）

- `true`：根 Stack 走 `.layoutWeight(1)` 参与 Row 内 flex 拉伸 —— 搜索框即此模式，与 `BackButton`、右上搜索按钮并排成工具栏；
- `false`：`.width('100%')` 独立成行 —— 用于命名弹窗、发布标题等 Column 场景。

### 3.3 两种材质模式（`segmentStyle`）

| | 普通模式（默认） | segmentStyle（搜索框启用） |
|---|---|---|
| 底色 | `ColorTokens.barSurface` | 半透明白 `#20FFFFFF` |
| 模糊 | 系统 `backgroundBlurStyle(BACKGROUND_THICK)` | 手工 `backdropBlur(20)` |
| 描边 | `barBorder` 1px | 高光白 `#30FFFFFF` 1px |
| 圆角 | `RadiusTokens.floatingBar`(30) | `RadiusTokens.lg`(20) |

segmentStyle 的三个常量（`GlowInput.ets:33-35`）与 `SegmentedControl.ets` 顶部的 `IMMERSIVE_*` 逐值相同。这是刻意的"同材质体系"设计：输入框与首页推荐/关注分段栏在视觉上属于同一层玻璃。

### 3.4 交互链路（面板侧）

1. **联想防抖**：`onChange` → `debounceSuggest`（300ms）→ `listSearchSuggest`，失败静默清空；`aboutToDisappear` 清理在途定时器，防止组件销毁后回调写已失效状态（`SearchPanel.ets:65-85`）。
2. **聚焦状态机**：聚焦时 `inputFocused=true`，隐藏"最近搜索/大家都在搜"仅留联想卡（避免两卡粘连）；失焦清空联想，再次聚焦且有已输入关键词时重新拉取。
3. **提交**：回车或右侧搜索按钮 → `doSearch`（trim 非空校验，空则 toast）→ `onKeywordSelect` → 路由壳 `openSearch` 写进程内搜索意图、`recordSearchHistory` fire-and-forget 记历史，再 `replaceUrl` 进结果页（保证返回键直达首页）。

### 3.5 值得注意的工程细节

- **`direction(Direction.Ltr)`**：父层握姿镜像（Rtl）时输入内容仍从左排版，中文不被挤到右侧；
- **`lineHeight = fontSize × 1.45` + 上下 padding 显式归零**：均为修复小高度输入框（如 32vp Dock）文字底部被裁的问题；
- **`maxLength` 默认 2147483647**：调用方不传即不限长，避免 0 被当成"不可输入"。

## 四、样式方案分析

### 4.1 双体系材质策略

普通模式依赖系统材质（`backgroundBlurStyle`），由系统统一控制模糊半径与降级，覆盖 API 22 及以下与模拟器。这一策略源自 AGC 审核崩溃问题（hdsMaterial 静态 import 导致 API 22 启动即崩，见 `utils/immersiveMaterial.ets` 头注释）：任何启动路径不得静态 import @since 6.1.0 的 HDS API。segmentStyle 模式则完全不依赖新 API（`半透明白底 + backdropBlur + 高光边框`），任何版本可用——搜索框因此天然规避了兼容性风险。

### 4.2 周边样式的一致性

搜索框不是孤立样式，面板内的配套元素全部对齐同一规格：

- 历史胶囊 / 热搜格子 = 分段栏 outlined 同款：透明底 + `glassBorderWidth`(1px) `barBorder` 边框 + `RadiusTokens.lg`(20) 圆角 + 无阴影，高度 `segmentedHeight`(36)，触控区放大到 `minTouchTarget`(44)（`Pressable` 将视觉高度与触控高度分离）；
- 联想卡使用 `GlassPanel` 玻璃卡；热搜排名前三使用固定色 `#FF3B30 / #FF9500 / #34C759`。

### 4.3 样式演进背景

git 历史显示搜索框样式近四轮反复：鸿蒙 6 沉浸光感（72cd2b2）→ 原生 Search 组件（88f3564）→ H7 定制胶囊（1268e11）→ revert 回 `GlowInput segmentStyle` 玻璃底（815ac0b，当前状态）。当前方案是反复试错后的收敛结果：牺牲了独立定制的观感，换回与分段栏的同材质一致性和零 API 风险。

## 五、评价与小结

**优点**：单组件双模式，7 个调用方（搜索面板/结果页/评论 Dock/聊天页/编辑资料/收藏夹命名/分享私信）共享一份实现；常量级对齐分段栏，视觉一致性强；原生 `TextInput` 内核使系统能力零成本；兼容性策略明确。

**可改进点**：segmentStyle 三个常量在 `GlowInput.ets` 与 `SegmentedControl.ets` 各自维护一份、靠注释约定同步，存在漂移风险，宜上收到 design tokens；文件名 `GlowInput` 中的"流光"已移除，属于已知的历史命名。

---

*涉及文件：`entry/src/main/ets/components/SearchPanel.ets`、`entry/src/main/ets/design/components/GlowInput.ets`、`entry/src/main/ets/pages/SearchPanelPage.ets`、`entry/src/main/ets/components/HomeTab.ets`、`entry/src/main/ets/utils/immersiveMaterial.ets`、`entry/src/main/ets/design/components/SegmentedControl.ets`*
