# AGC 上架审核打回 — 深色模式对比度审计与修复报告

> 日期：2026-09-04
> 打回原因（审核原文）：**系统深色模式下控件文字与背景对比度存在问题**
> 结论：根因是全局色板中「次要/辅助文字层级」（tertiary / quaternary）在深色模式下亮度不足，叠加在深色控件面（卡片/芯片/输入框底 `#221E15`、`#2A251A`）上对比度跌破 WCAG AA（4.5:1）。本次在**色板 token 层一处修复、全局生效**，并顺带补了深色模式品牌 Logo 白化。

---

## 一、审计方法

1. 读取 `resources/base|dark/element/color.json` 全量色板；
2. 按 WCAG 2.x 相对亮度公式，对「文字色 × 常见实心背景色」（bg_primary / card_bg / ds_elevated / ds_subtle / control_bg / surface_elevated / ds_canvas）做全组合对比度计算；
3. 对 `entry/src/main/ets/**` 全部 `fontColor` / `fillColor` / 图标用色扫描，归类「走 token（自动随主题修正）」与「硬编码色（需单独处理）」；
4. 审计结论结合真机 / 审核截图场景人工复核。

## 二、发现的问题（修复前）

### P0 — 深色模式文字层级亮度不足（本次打回主因）

| token（dark） | 原值 | 在 ds_subtle #221E15 上 | 在 control_bg #2A251A 上 | 在 card #1C1912 上 | 判定 |
|---|---|---|---|---|---|
| text_tertiary / ds_text_tertiary | `#8C836F` | 4.42 | **4.06** | 5.12 | ❌ 多处 < 4.5 |
| ds_text_quaternary | `#5F5848` | **2.35** | **2.16** | **2.49** | ❌❌ 严重不足 |

- tertiary 用于全 App 25+ 文件、40+ 处的辅助说明文字、次要图标描边（StatRow、AuthorRow、分享列表、圈子卡、消息时间等）——全部落在深色卡片/芯片上，正是审核截图可见的小字区域。
- quaternary 用于输入框占位符、弱化元素，接近不可读。
- 浅色版 ds_text_quaternary `#817A68` 在卡片上 4.16，同样略低于 4.5。

### P1 — 品牌色文字 / 浅色按钮（未在本次深色打回范围内，记录待定）

| 组合 | 对比度 | 说明 |
|---|---|---|
| 浅色：ds_on_brand(#FFF) on ds_brand(#1677FF) | 4.10 | 主按钮小字略低于 4.5，若后续浅色模式被抽检需加深 ds_brand |
| 浅色：ds_brand(#1677FF) 作正文 | 3.64–4.00 | 链接/选中态文字同因 |
| 浅色：semantic_red(#FF3B30) 作正文 | 3.14–3.46 | 系统红惯例色，破坏性文字建议深一档 |
| 深色：semantic_red(#FF453A) on control_bg | 4.47 | 临界，实际红色文字多落于更暗的卡片上（≥5） |

> 说明：`ds_on_brand × 普通背景` 那一批 1.x 对比度是**误报**——该色只出现在品牌色实底按钮上，不落普通背景。

## 三、修复内容

### 1. 深色文字层级提亮（`resources/dark/element/color.json`）

| token | 修复后 | 在 ds_subtle | 在 control_bg | 在 card | 判定 |
|---|---|---|---|---|---|
| text_tertiary / ds_text_tertiary | `#9C937C` | 5.44 | 4.99 | 5.75 | ✅ 全场景 ≥4.5 |
| ds_text_quaternary | `#817A68` | 3.89 | 3.57 | 4.11 | ✅ 图标/弱元素 ≥3:1，占位符近 4.1 |

- 层级保留：secondary `#B9B09A`(7.07) > tertiary `#9C937C`(4.99) > quaternary `#817A68`(3.57+)，视觉递减清晰。
- legacy 与 ds 两套 tertiary 同步，旧页面（$r('app.color.text_tertiary')）一并受益。

### 2. 浅色 quaternary（顺手补足 4.5，`resources/base/element/color.json`）

- ds_text_quaternary `#817A68` → `#817269`，卡片上 4.16 → 4.50 ✅（仅微调）

### 3. 品牌 Logo 深色白化（上一轮已完成，含在此次提交）

- `resources/dark/media/brand_{harmony,huawei,wechat}.svg` 白色版；
- 贴片底色抽为资源 `account_tile_*`（base 10% / dark 24%），由 `setColorMode` 自动切换。

### 4. 全量图标用色扫描结论

- 所有 `fillColor` 均走 `ColorTokens.secondary/tertiary/brand/onBrand` 或 legacy `$r(app.color.*)`——已随上述 token 修复自动达标；
- 硬编码白字（`#FFFFFF` 系列、`#CC/E6FFFFFF`）只出现在图片/视频浮层上（cover、VideoViewer、ImageViewer），属合理高对比场景；
- 例外：`pages/HdsPocPage.ets` 为开发 POC 页（未挂路由、无入口），硬编码 `#888/#666/#333` 不影响上架，建议后续直接删除该页。

## 四、改动文件

| 文件 | 内容 |
|---|---|
| `entry/src/main/resources/dark/element/color.json` | tertiary/quaternary 提亮 |
| `entry/src/main/resources/base/element/color.json` | quaternary 微调至 4.5 |
| `entry/src/main/resources/dark/media/brand_*.svg` ×3 | 白色版 Logo |
| `entry/src/main/ets/utils/brandIcons.ets` | 贴片底改资源色 |
| `entry/src/main/ets/pages/AccountBindingPage.ets` | providerTile 替换纯色圆 |

## 五、复核建议

1. 真机切深色过一遍核心页：首页信息流、详情、我的、设置→各设置子页、发布流程、分享列表——凡「灰字说明」应明显更亮、清晰。
2. 若 AGC 复审仍打回浅色模式或品牌色文字，下一档改动预案：
   - light `ds_brand` `#1677FF → #0E5BD6` 档（白字按钮 ≥4.5，品牌文字 ≥4.5）；
   - 破坏性红字改用 `#C74040` 档（浅色 ≥4.5）。
3. 视觉回退保护：本次未改 secondary/primary、未动任何布局字号；若觉得 tertiary 提亮后"说明文字偏白"，可在 `#98907A~#9C937C` 区间微调（不得低于 `#948C6F`，那是 4.53 的临界值）。
