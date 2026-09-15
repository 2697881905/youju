# 高风险问题文档

> 本文档记录「有据」项目中可能导致 AGC 审核被拒、应用崩溃或严重功能异常的高风险问题。
> 每条风险均包含：风险来源、影响范围、触发条件、可能后果及修复建议。

---

## H-1: 权限声明缺少 reason 字段（AGC 审核阻断）

| 维度 | 说明 |
|------|------|
| **风险来源** | `entry/src/main/module.json5` — `requestPermissions` 中 `ohos.permission.INTERNET` 未声明 `reason` 字段 |
| **影响范围** | AGC 应用审核流程；应用上架发布 |
| **触发条件** | 提交 AGC 审核时，审核系统自动检测权限声明完整性 |
| **可能后果** | AGC 审核直接驳回，应用无法上架。华为应用市场要求每个权限必须提供用途说明，否则视为权限声明不合规 |
| **修复建议** | 在 `module.json5` 的 `requestPermissions` 中添加 `"reason": "$string:permission_internet_reason"`，并在 `resources/base/element/string.json` 中添加对应字符串 `{"name": "permission_internet_reason", "value": "用于网络通信以获取服务数据"}` |

---

## H-2: 隐私政策与用户协议日期不一致

| 维度 | 说明 |
|------|------|
| **风险来源** | `pages/PrivacyPage.ets` — 隐私政策生效日期 2026年9月11日；`pages/UserAgreementPage.ets` — 用户协议生效日期 2026年8月14日 |
| **影响范围** | AGC 合规审核；用户信任度 |
| **触发条件** | AGC 审核员核对隐私政策与用户协议的一致性时发现日期差异 |
| **可能后果** | 审核员可能质疑文档维护的规范性，要求统一更新日期后重新提交，延长审核周期。两份核心合规文档日期相差近一个月，可能被判定为文档管理不规范 |
| **修复建议** | 将用户协议的更新/生效日期同步至 2026年9月11日，与隐私政策保持一致 |

---

## H-3: 所有 Image 组件无 onError 回调，图片加载失败无任何处理

| 维度 | 说明 |
|------|------|
| **风险来源** | 全项目约 20 处 Image 组件均未绑定 `.onError()` 回调，包括 `PostCardMedia.ets:23,35`、`DetailHeroMedia.ets:22`、`AvatarView.ets:19`、`Avatar.ets:16`、`ImageViewer.ets:49`、`DailyPostDeck.ets:200,256`、`ChatPage.ets:702`、`ProfilePage.ets:566,799`、`UserProfilePage.ets:648`、`ModerationPage.ets:215,258`、`BookmarkFolderPage.ets:132`、`PublishPreviewPage.ets:435`、`EditableProfilePreview.ets:68,151,153`、`CircleOrbitCanvas.ets:99`、`ImagePicker.ets:168` |
| **影响范围** | 所有展示图片的页面和组件——帖子卡片封面、详情页头部媒体、用户头像、聊天图片、个人主页等 |
| **触发条件** | 图片 URL 失效（404）、网络超时、COS 临时链接过期、服务器故障、DNS 解析失败等任意图片加载失败场景 |
| **可能后果** | 用户看到空白区域或破损图标，无任何错误提示或占位图回退。头像加载失败时不回退默认头像（`AvatarView.ets` 仅在 URL 为空时才用默认头像，URL 非空但加载失败时无兜底）。严重影响用户体验，可能被 AGC 审核判定为"功能不完善" |
| **修复建议** | 1. 为所有 Image 组件添加 `.onError()` 回调，在回调中切换到占位图或默认头像；2. 添加 `.alt()` 属性设置加载中占位图；3. 优先修复 `AvatarView.ets` 和 `PostCardMedia.ets`（高频可见组件） |

---

## H-4: PublishPreviewPage 无 aboutToDisappear，setTimeout 回调可能在组件销毁后执行

| 维度 | 说明 |
|------|------|
| **风险来源** | `pages/PublishPreviewPage.ets:169` — `setTimeout` 用于文字海报生成超时处理，但该页面无 `aboutToDisappear` 生命周期回调清理此定时器 |
| **影响范围** | 发布预览页面——用户在文字海报生成过程中离开页面时 |
| **触发条件** | 用户在发布预览页等待文字海报生成期间（超时定时器尚未触发），通过返回按钮或手势导航离开页面 |
| **可能后果** | 定时器回调在组件已销毁后执行 `finish(new Error('文字海报生成超时'))`，访问已销毁的组件上下文，导致运行时异常或崩溃。ArkUI 框架不保证组件销毁后定时器回调的安全执行 |
| **修复建议** | 添加 `aboutToDisappear()` 生命周期回调，在其中 `clearTimeout(this.posterTimer)` 清理定时器。将 setTimeout 的返回值保存为组件成员变量 |

---

## H-5: SegmentedControl / BottomTabBar 中 e.touches[0] 无长度检查

| 维度 | 说明 |
|------|------|
| **风险来源** | `design/components/SegmentedControl.ets:93,111` — `e.touches[0].globalX` / `e.touches[0].localX`；`design/components/BottomTabBar.ets:89,107` — 同上 |
| **影响范围** | 首页分段控件（推荐/关注/每日一帖）和底部标签栏的触摸交互 |
| **触发条件** | 触摸事件回调中 `e.touches` 数组为空（如系统异常、触摸事件被拦截后转发、多指触摸中某指抬起等边缘场景） |
| **可能后果** | `e.touches[0]` 返回 `undefined`，后续访问 `.globalX` / `.localX` 属性时抛出 `TypeError: Cannot read property of undefined`，导致应用崩溃。这两个组件是首页核心交互元素，崩溃影响面极大 |
| **修复建议** | 在访问 `e.touches[0]` 前添加 `if (e.touches.length > 0)` 保护，或使用可选链 `e.touches[0]?.globalX ?? 0` |

---

## H-6: DetailPage 中 (post.tags ?? [])[0] 当 tags 为空数组时显示 "undefined"

| 维度 | 说明 |
|------|------|
| **风险来源** | `pages/DetailPage.ets:706` — `(post.tags ?? [])[0] + ' · '` |
| **影响范围** | 帖子详情页的标签显示区域 |
| **触发条件** | 后端返回的帖子数据中 `tags` 字段为空数组 `[]`（而非 null/undefined） |
| **可能后果** | `[][0]` 返回 `undefined`，`undefined + ' · '` 得到字符串 `"undefined · ..."`，在详情页标签位置显示 "undefined" 字样。这是用户可见的 UI 异常，影响应用专业度，AGC 审核可能判定为"显示异常" |
| **修复建议** | 改为 `((post.tags ?? []).length > 0 ? post.tags![0] : '') + ' · '`，或先检查数组长度再访问 |

---

## H-7: ChatPage 的 error 状态在 build 中无对应 UI 渲染分支

| 维度 | 说明 |
|------|------|
| **风险来源** | `pages/ChatPage.ets:108-113` — `error` 状态变量有赋值逻辑，但 `build()` 方法中只有 `loading` 和 `messages` 两个渲染分支，无 `error` 分支 |
| **影响范围** | 私信聊天页面 |
| **触发条件** | 聊天页面加载消息失败（网络错误、服务器异常、token 过期等） |
| **可能后果** | 加载失败时 `loading` 变为 false、`error` 被赋值，但 build 中无 error 分支渲染，用户看到空白页面或永久 loading 状态，无法感知错误也无法重试。聊天是核心社交功能，此问题严重影响用户体验 |
| **修复建议** | 在 `build()` 中添加 `else if (this.error.length > 0)` 分支，显示错误提示和重试按钮 |

---

## H-8: uploadChatMedia 绕过 401 拦截，上传时 token 过期不触发登录引导

| 维度 | 说明 |
|------|------|
| **风险来源** | `services/api.ets:974-997` — `uploadChatMedia` 函数直接使用 `http.createHttp()` 发起 PUT 请求，未经过统一的 `request()` 函数，因此 401 登录态过期拦截（第105-108行、第114-117行）不会在上传场景生效 |
| **影响范围** | 私信聊天中发送图片和视频消息 |
| **触发条件** | 用户在聊天页面发送图片/视频时，auth token 已过期（超过有效期或被服务端失效） |
| **可能后果** | 上传请求返回 401 但不会被拦截，`uploadChatMedia` 只检查 HTTP 状态码 200-299，401 会被当作上传失败处理，用户看到"发送失败"但不会被引导到登录页面重新登录。用户无法理解为什么突然不能发图片，且无法自动恢复 |
| **修复建议** | 在 `uploadChatMedia` 的错误处理中添加 401 状态码检测，调用 `markAuthExpired()` 触发全局登录引导；或将上传逻辑改为通过 `request()` 函数走统一拦截 |

---

## H-9: DailyPostDeck 中 4 个 setTimeout 未在 aboutToDisappear 中清理

| 维度 | 说明 |
|------|------|
| **风险来源** | `components/DailyPostDeck.ets:470,499,515,518` — `advance()` 方法中创建 4 个 setTimeout 用于卡片飞行动画序列，均未保存定时器 ID，`aboutToDisappear` 中无法清理 |
| **影响范围** | 每日一帖卡片组组件——卡片切换动画 |
| **触发条件** | 用户在每日一帖卡片动画播放期间（动画序列尚未完成），快速切换 Tab 或导航离开当前页面 |
| **可能后果** | 定时器回调在组件已销毁后执行，访问 `this.flyPost`、`this.inFlight` 等已销毁的组件状态变量，导致运行时异常。虽然 ArkUI 对已销毁组件的状态访问有一定容错，但不保证所有场景都安全 |
| **修复建议** | 将 4 个 setTimeout 的返回值保存为组件成员变量（如 `flyTimer1/2/3/4`），在 `aboutToDisappear()` 中逐一 `clearTimeout` |

---

## H-10: DetailPage.navigateBack 的 setTimeout 未清理

| 维度 | 说明 |
|------|------|
| **风险来源** | `pages/DetailPage.ets:244-246` — `navigateBack()` 中 `setTimeout(() => { this.getUIContext().getRouter().back(); }, 16)` 延迟一帧执行返回，该 setTimeout 未被 `aboutToDisappear` 清理（第399-411行只清理了 `holdTimer`） |
| **影响范围** | 帖子详情页的退出导航 |
| **触发条件** | 用户点击返回按钮触发 `navigateBack()`，但在 16ms 内组件被系统销毁（如快速连续操作、内存压力下系统回收） |
| **可能后果** | 定时器回调执行时 `this.getUIContext()` 可能返回 null 或抛异常（组件已销毁），导致崩溃。虽然 16ms 窗口很短，但在低端设备或高负载场景下仍可能触发 |
| **修复建议** | 将 setTimeout 返回值保存为成员变量（如 `backTimer`），在 `aboutToDisappear()` 中清理；或在回调中添加 null 检查 `if (this.getUIContext())` |