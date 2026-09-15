# 低风险问题文档

> 本文档记录「有据」项目中的代码规范、防御性编程缺失及构建警告等低风险问题。
> 这些问题当前不会导致功能异常或用户体验问题，但影响代码可维护性和长期质量。

---

## L-1: 多处空 catch 或仅注释的 catch，无日志记录

| 维度 | 说明 |
|------|------|
| **风险来源** | `Index.ets:277-279`（`catch (e) { // 失败不阻断 }`）、`Index.ets:408-411`（`catch (_) { // 校验失败不阻断启动 }`）、`Index.ets:425,437,451,454`（`.catch(() => {})` 完全静默）、`ChatPage.ets:172-174`（`catch (e) { // 轮询失败静默 }`）、`ChatPage.ets:123-125`（`catch (e) { // UIContext 未就绪时忽略 }`）、`auth.ets:117,233`（`catch (_) { /* ignore */ }`）、`DetailPage.ets:407-409`（`catch (e) { // 注销失败可忽略 }`） |
| **影响范围** | 首页初始化、聊天轮询、认证流程、详情页生命周期清理 |
| **触发条件** | 对应的 try-catch 块中发生异常时 |
| **可能后果** | 异常被完全静默吞掉，开发者无法从日志中发现问题。虽然这些异常在设计上"不阻断主流程"，但如果发生非预期异常（如后端 API 变更导致的解析错误），开发者完全无感知，问题会持续积累直到爆发 |
| **修复建议** | 在所有 catch 块中添加 `hilog.warn` 或 `hilog.error` 记录异常信息，至少保留最小日志输出用于排查 |

---

## L-2: 多处 async 函数 fire-and-forget 调用，潜在未处理 rejection

| 维度 | 说明 |
|------|------|
| **风险来源** | `CircleTab.ets:243`（`this.syncSelfAvatar()` 在 `initData()` 中无 await 无 .catch）、`HomeTab.ets:365`（`this.loadFollowingCount()` 在 `fetch()` 中无 await 无 .catch） |
| **影响范围** | 圈子标签页头像同步、首页关注计数加载 |
| **触发条件** | `syncSelfAvatar` / `loadFollowingCount` 内部的 try-catch 块本身抛出异常时（如 `this.authAvatar` 属性访问异常） |
| **可能后果** | 虽然 `syncSelfAvatar` 和 `loadFollowingCount` 内部有 try-catch，但如果 catch 块本身的代码抛出异常（如访问已销毁的组件属性），会产生未处理的 Promise rejection。ArkUI 运行时通常只记录警告，不会崩溃，但持续积累的 rejection 可能影响运行时稳定性 |
| **修复建议** | 为所有 fire-and-forget 的 async 调用添加 `.catch((e: Error) => { hilog.warn(...) })`，确保即使内部 catch 失败也不会产生未处理 rejection |

---

## L-3: 硬编码 UI 文本未使用资源引用（200+ 处）

| 维度 | 说明 |
|------|------|
| **风险来源** | `string.json` 仅定义了 6 个字符串资源（`module_desc`、`EntryAbility_desc`、`EntryAbility_label`、`font_family`、`font_family_serif`、`font_family_serif_body`），而代码中存在 200+ 处硬编码中文/英文文本。典型示例：`Index.ets:52-102`（隐私弹窗全部文案）、`Index.ets:195-199`（Tab 标题）、`LoginPage.ets:70-201`（登录页全部文案）、`HomeTab.ets:44-46`（推荐/关注/每日一帖）、`CircleTab.ets:38-50+`（圈子名称描述约 20+ 条）、各发布页 placeholder 文案等 |
| **影响范围** | 全项目所有面向用户的可见文本 |
| **触发条件** | 需要修改文案、支持多语言、或统一术语时 |
| **可能后果** | 1. 无法支持多语言切换（国际化）；2. 文案修改需逐文件搜索替换，容易遗漏；3. 无法通过资源文件统一管理文案版本；4. 同一术语在不同页面可能不一致（如"取消"vs"关闭"） |
| **修复建议** | 分批将面向用户的可见文本提取到 `string.json`，通过 `$r('app.string.xxx')` 引用。优先处理高频复用文本（Tab 标题、隐私弹窗、登录页、通用按钮文案），再逐步覆盖其他页面 |

---

## L-4: 多个页面缺少 aboutToDisappear（当前无定时器需清理）

| 维度 | 说明 |
|------|------|
| **风险来源** | `MyFollowPage.ets`、`BlocklistPage.ets`、`TrashBoxPage.ets`、`ModerationPage.ets`、`ReportAdminPage.ets`、`SettingsPage.ets`、`PrivacySettingsPage.ets`、`InterestTagsPage.ets`、`NotificationSettingsPage.ets`、`AccountBindingPage.ets`、`BookmarkFolderDetailPage.ets` — 共约 11 个页面有 `aboutToAppear` 但无 `aboutToDisappear` |
| **影响范围** | 上述 11 个页面的组件生命周期管理 |
| **触发条件** | 当前这些页面没有定时器、订阅或需要清理的资源，所以缺少 `aboutToDisappear` 暂无实际风险 |
| **可能后果** | 当前无影响。但如果未来在这些页面中添加了定时器、事件订阅或网络请求监听，开发者可能忘记添加 `aboutToDisappear` 清理逻辑，导致内存泄漏。缺少防御性的生命周期回调是一种代码规范隐患 |
| **修复建议** | 为所有有 `aboutToAppear` 的页面添加空的 `aboutToDisappear` 回调作为占位，并在代码注释中标注"当前无资源需清理"，提醒后续开发者在此添加清理逻辑 |

---

## L-5: 构建警告——废弃 API 使用

| 维度 | 说明 |
|------|------|
| **风险来源** | `px2vp`（`CircleTab.ets:730,738`、`responsive.ets:12`、`Index.ets:268,274`、`DetailPage.ets:391,393`、`SettingsPage.ets:37`）、`registerFont`（`Index.ets:206,212`）、`pushUrl`（`auth.ets:111,116`）、`back`（`PhotoPublishPage.ets:459`、`VideoPublishPage.ets:448`、`TextPublishPage.ets:502`）、`getState`（`auth.ets:109`）、`createPlainTextData`（`share.ets:42`）、`encode`（`dataExport.ets:28`）、`ANIMATOR_DURATION_SCALE`（`EntryAbility.ets:28`） |
| **影响范围** | 构建警告约 15 处，涉及 UI 布局、字体注册、路由导航、分享、数据导出、动画等模块 |
| **触发条件** | 每次构建时编译器发出废弃警告 |
| **可能后果** | 当前功能正常运作，但废弃 API 在未来 SDK 版本中可能被移除，届时需要紧急迁移。大量构建警告也会影响开发者对真正问题的敏感度（"狼来了"效应） |
| **修复建议** | 逐批替换废弃 API：`px2vp` → `vp2px` 的反向计算或使用 `UIContext.vp2px`；`registerFont` → 新字体注册 API；`pushUrl` → `UIContext.getRouter().pushUrl`；`back` → `UIContext.getRouter().back()`。优先处理 `px2vp`（最多）和 `pushUrl`/`back`（影响导航核心） |

---

## L-6: app_icon.png 缺少 base 资源（构建警告）

| 维度 | 说明 |
|------|------|
| **风险来源** | 构建输出 `WARN: Warning: the media of 'app_icon.png' does not have a base resource.` — `AppScope/resources/phone-*/media/app_icon.png` 各密度目录都有图标文件，但 `AppScope/resources/base/media/` 目录下缺少 `app_icon.png` 的 base 版本 |
| **影响范围** | 应用图标在部分设备密度下的显示 |
| **触发条件** | 构建时资源处理阶段 |
| **可能后果** | 在不匹配任何特定密度目录的设备上，系统无法找到 base 版本的 `app_icon.png` 作为兜底，可能导致图标显示异常或使用系统默认图标。当前项目有 phone-ldpi/mdpi/sdpi/xldpi/xxldpi/xxxldpi 六个密度目录，覆盖了主流设备，但缺少 base 兜底不符合资源规范 |
| **修复建议** | 在 `AppScope/resources/base/media/` 目录下添加 `app_icon.png`（使用 xxxldpi 版本作为 base，因为高分辨率图标缩小比低分辨率放大效果好） |

---

## L-7: barFloatingStyle API 版本不匹配

| 维度 | 说明 |
|------|------|
| **风险来源** | `Index.ets:550` — `barFloatingStyle` API 需要 SDK 6.1.0(23)，但 `build-profile.json5` 中 `default`/`release` product 的 `compatibleSdkVersion` 为 6.0.0(20) |
| **影响范围** | 首页底部 Tab 栏的浮动样式 |
| **触发条件** | 在 SDK 6.0.0(20) 的设备上运行应用 |
| **可能后果** | `barFloatingStyle` 在兼容 SDK 6.0.0(20) 的设备上可能不可用，导致 Tab 栏浮动样式不生效或运行时异常。当前 `debug` product 的 `compatibleSdkVersion` 为 6.1.1(24)，所以开发调试时不会发现问题 |
| **修复建议** | 两种方案：1. 将 `default`/`release` product 的 `compatibleSdkVersion` 提升至 6.1.0(23)（如果不需要支持更低版本）；2. 使用条件判断在低版本设备上降级为非浮动样式 |

---

## L-8: 大量列表项缺少按压反馈效果

| 维度 | 说明 |
|------|------|
| **风险来源** | `MyFollowPage.ets:189-224`（ListItem 直接 onClick）、`ReportAdminPage.ets:364-443`（reportCard onClick）、`ModerationPage.ets:210-335`（postCard onClick）、`BookmarkFolderDetailPage.ets:212-230`（操作按钮 onClick）、`InterestTagsPage.ets:120-160`（标签 chip onClick）、`AccountBindingPage.ets:147-190`（解绑按钮 onClick）、`PrivacySettingsPage.ets:113-133,261-270,275-297`（选项行 onClick）、`SettingsPage.ets:379,396`（退出登录/注销行 onClick） |
| **影响范围** | 关注列表、举报管理、审核管理、收藏夹详情、兴趣标签、账号绑定、隐私设置、设置页面 |
| **触发条件** | 用户点击上述列表项或按钮时 |
| **可能后果** | 点击时无视觉反馈（如缩放、颜色变化），用户无法确认点击是否生效，尤其在弱网环境下点击后等待响应期间感知"无反应"。项目已有 `Pressable` 动效组件和 `stateStyles` 模式，但这些页面未使用 |
| **修复建议** | 为列表项添加 `.stateStyles({ pressed: ... })` 按压样式，或用 `Pressable` 组件包裹。优先处理高频操作项（设置页退出登录、关注列表项） |