# 死代码清理清单与影响评估

生成时间：2026-09-15 · 基线 commit `f99dd66`
方法：全项目 `entry/src/main/ets/**/*.ets` 逐符号引用扫描（脚本判定「仅自身出现」）+ 逐个文件人工核对注释与调用链。
**重要**：本清单已纠正提审审计报告里的一处误判——审计把 9 个文件列为「不可达死代码」，其中 6 个实际是**自述的内部预览工具**，不能删（见 Tier 3）。

> **执行状态**：Tier 1 的 3 个文件 + Tier 5 的 3 个空转 @Prop **已在本批次删除**；Tier 2 / Tier 3 保留项 / Tier 4 待确认。
> 删除项均已通过引用扫描（0 处引用）与调用点检查（无人传被删的 prop）。**未编译验证**，建议 Build Hap 一次。

---

## Tier 1 · 已删（3 个文件，依赖已闭合，删除零影响）

| 文件 | 判定依据 | 影响 |
| --- | --- | --- |
| `utils/breakpoint.ets` | 0 处引用；导出的 `Breakpoint` / `getBreakpoint` / `getGridColumns` / `getGridTemplate` 全部 0 引用 | 无。响应式列数最终由各页 `onAreaChange` 自行实现（ProfilePage 的 `gridColumns`） |
| `utils/data-source.ets` | 0 处引用（`BasicDataSource` 0 引用） | 无。本项目列表已统一改用 `Scroll`（约定禁用 List/WaterFlow/Grid，见 MEMORY.md §五），用不上 `LazyForEach` 的 `IDataSource` |
| `components/DailyPostView.ets` | 0 处引用；文件自带 `const MOCK_POSTS`（硬编码「林默 / 周予安」+ **Unsplash 外链图片**），`@Prop posts = MOCK_POSTS` | 无。是早期「Apple-inspired light 版每日一贴」，已被 `components/DailyPostDeck.ets` 完全取代 |

这 3 个文件之间以及与其余代码**不存在互相引用**，删完不会留下悬空 import。已确认 `design/components/` 下没有 barrel/index 再导出它们。

---

## Tier 2 · 需你拍板（1 个文件）

**`pages/ParchmentPreviewPage.ets`** —— 0 处引用，但它自己的注释写着：

> 设计系统先行版预览页：羊皮纸 + 宋体，真机查看效果用。**可从「设置 - 通用 - 设计系统预览」进入**。

而全项目**没有任何一处跳转指向它**，`main_pages.json` 也没注册 → 注释里承诺的设置入口并不存在。两个选择：

- **补入口**：在设置页「通用」区加一行「设计系统预览」跳 `pages/ParchmentPreviewPage`（需同时注册进 `main_pages.json`）；
- **删掉它**：删页面不影响预览能力，因为它的 `@Preview` 壳 `design/preview/ParchmentPreview.ets` 可以**直接在 DevEco Previewer 里打开**。

倾向后者（这是一次性验收工具，不需要挂进产品导航；挂上去反而多一个审核可见的页面）。

---

## Tier 3 · 不要删（审计误判，已纠正）

这 4 个文件在提审审计里被列为「完全不可达死代码」，核对后**属内部验收工具，应保留**：

| 文件 | 保留依据 |
| --- | --- |
| `pages/FoundationPreviewPage.ets` | 文件注释明确：「Phase1 内部预览页：**不挂接产品导航，仅用于 DevEco Preview 与设计地基验收**」 |
| `design/preview/FoundationPreview.ets` | 带 `@Preview` 装饰器，DS 验收壳 |
| `design/preview/ParchmentPreview.ets` | 带 `@Preview` 装饰器，DS 验收壳（含一句「敬请期待」占位文案，因不挂导航不会展示给用户） |
| `design/components/AuthorRow.ets` / `PollBlock.ets` | 仅被上面两个预览壳引用，是设计系统**原子清单**的一部分（`docs/feature-index.md` 的 DS 表里也列着） |

**结论：这 6 个是一组**——删预览壳会让 `AuthorRow` / `PollBlock` 变成真孤儿，删原子又会丢 DS 库存。要删就一起删、要留就一起留，**建议留**（它们的价值是让你随时能在 Previewer 里验收设计系统）。

---

## Tier 4 · 0 引用导出符号（12 个，低风险但属 API 面）

全部经脚本验证「仅自身出现」。按建议分两档：

### 建议删（7 个，已被取代或改走别的路径）

| 位置 | 符号 | 取代者 / 依据 |
| --- | --- | --- |
| `utils/auth.ets:193` | `loginByHuaweiResult` | 登录页改用 `setSession`（`LoginPage.ets:237`） |
| `utils/video.ets:178` | `captureVideoCoverBytes` | 视频封面当前走别的路径 |
| `utils/settingsIcons.ets:36` | `resolveSettingsIconColor` | 设置图标配色改由 `base`/`dark` 双份板写死色承担 |
| `utils/theme.ets:152` | `isReduceMotion` | 各组件自己的 `shouldReduceMotion()` |
| `utils/postDraftStore.ets:84` | `getPostDraft` | 草稿读走 `listPostDrafts` |
| `pages/SettingsPage.ets:160` | `@Builder toggleRow` | 同文件 `:258` 注释已说明「因 @Builder 值快照不刷新改为内联」 |
| `pages/PublishPreviewPage.ets:113` | `@Builder posterOverlayBuilder` | 与 `buildPosterOverlay()`（`:148-151`，恒返回 `undefined`）是**同一废弃方案的上下两半**，建议一起删 |

### 建议留（3 个，属后端接口客户端封装，删了将来要重写）

- `services/api.ets:359` `updatePost`（编辑帖子接口）
- `services/api.ets:382` `listComments`（评论由 `getPost` 一并返回，但接口本身有效）
- `services/api.ets:412` `registerPushToken`（推送未接线，属于**未来功能的预留**——建议保留并在注释里标明「未接线」，或等你决定是否放弃推送）

### 需你确认（2 个）

- `utils/share.ets:29` `buildShareText` —— 注释写「用于系统分享面板接入后使用」。系统分享**已经接入**（`utils/share.ets:83 sharePostToSystem`），但分享文案改由 `shareCard` 侧生成 → 判断为可删，但涉及分享链路，建议你扫一眼再定。
- `pages/ProfilePage.ets:637` `@Builder postFooter` —— **这条不是普通死代码，见下方「顺带发现」**。

---

## Tier 5 · 死 @Prop（可无痛删 3 个，另 3 个不建议动）

### 已删（组件内 0 使用 **且** 调用点从不传）

| 位置 | @Prop | 说明 |
| --- | --- | --- |
| `design/components/IconTile.ets` | `tint` | 0 使用、0 调用点传 → 已删 |
| `design/components/IconTile.ets` | `selected` | 0 调用点传；且原 `:29` 的三元 **两个分支都返回 `ColorTokens.brandTint`** → 该 prop 完全空转。已删 prop 并把三元简化为 `this.showBackground ? ColorTokens.brandTint : Color.Transparent` |
| `design/components/GlassPanel.ets` | `glassBlurRadius` | 0 使用、0 调用点传 → 已删 |

### 不建议动（组件内 0 使用，但调用点在传 → 删 prop 要连带改多处调用点，收益极低）

- `design/components/Avatar.ets:7` `name`（8 个调用点在传）
- `components/AvatarView.ets:10` `name`（多个调用点在传）
- `components/CircleOrbitCanvas.ets:49` `nickname`（`CircleTab` 在传）

> 已核对：`Avatar` 与 `AvatarView` **都有 `default_avatar` 兜底**（`Avatar.ets:23-28`、`AvatarView.ets:26-30`），所以 `name` 不是「缺失的兜底功能」，纯粹是无用参数。

---

## ⚠️ 顺带发现的两个真问题（不是死代码）

1. **个人主页永远不会显示「没有更多了」**
   `pages/ProfilePage.ets:637` 的 `@Builder postFooter()` 是唯一渲染该文案的地方，但它**全项目 0 调用**。其他列表页（`CircleDetailPage` 等）都有到底提示 → 个人主页「我发布 / 我收藏 / 我赞过 / 我评论」滚到底时没有任何反馈。
   **处理**：要么在四个列表末尾接上 `this.postFooter()`，要么删掉这个 builder（删了就承认没有到底提示）。

2. **`IconTile.selected` 是个没实现的选中态**
   `IconTile.ets:29` 的三元 `(this.selected ? ColorTokens.brandTint : ColorTokens.brandTint)` 两个分支返回同一个值，加上没有任何调用点传 `selected` → 即便传了也看不出变化。若设计本意是「选中时换底色」，那是**未实现的视觉状态**（当前不可见，但属隐患）。

---

## 建议执行方式

- **Tier 1（3 个文件）**：本次已删（见同批次提交）。全部在 git 历史里，`git revert` 或 `git checkout <commit> -- <path>` 可随时恢复。
- **Tier 2 / Tier 4 / Tier 5**：等你在回复里点一下要哪几项，我再动；每项都是独立的、可单独提交的改动。
- **建议不要一次性全删**：Tier 4 的 7 个符号分散在 5 个 utils/api 文件里，混在一起提审前不好回归。推荐顺序：Tier 1 → Tier 5（3 个 prop）→ Tier 4「建议删」7 个 → Tier 2。
- ⚠️ 本轮所有改动**均未编译验证**，删完请 Build Hap 一次（死代码删除最容易暴露的其实是「被删的东西其实有人用」——虽然本次逐条脚本验证过，仍建议过一次编译）。
