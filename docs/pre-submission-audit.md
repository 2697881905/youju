# 「有据」提审前审计报告（AGC）

审计时间：2026-09-14 · 基线 commit `b64baa6`
审计方式：三路只读代码审计（合规/权限、未完成功能、运行时健壮性）+ 逐条人工复核
说明：审计期间工作树存在**你正在进行的未提交批次**（`DetailHeroMedia.ets` 及详情页相关 11 个文件），本报告基于该状态，未改动任何文件。

> **修复进度**
> - **2026-09-14 当晚**：**P0-1 / P0-2 / P0-3 / P0-4 已全部修复**，涉及 `utils/shareCard.ets`、`pages/Index.ets`、`pages/BookmarkFolderDetailPage.ets`、`pages/ChatPage.ets`、`pages/UserProfilePage.ets`、`pages/ProfilePage.ets`。
> - **2026-09-15 早**：**P1 已修 6 项** —— ① ProfilePage 登出清空资料/计数/列表快照；② `clearSession` 复位两个未读计数（消除登出后红点持久化残留）；③ MyFollowPage 参数缺失改为明确失败态（不再显示成「这里还什么都没有」）；④ MessagePage 会话缺 `peer` 字段时不再抛未捕获异常；⑤ SearchPanel / BottomTabBar / SegmentedControl 三个组件补 `aboutToDisappear` 清理长按·防抖定时器；⑥ AboutPage 换用真实应用图标（`$media:logo`，与登录页一致）。另订正 2 处过期注释（ChatPage 文件消息、`utils/share.ets` 分享域名）。
> - **2026-09-15 午**：**P2-3 已修**（`Index.validateStartupSession` 移除 debug 专用的 `loginWithDevStub` 静默重登分支，过期统一走正常 401 流程）；新增 **`check-release.sh` 提审前形态检查脚本**（核对 buildMode 还原 / release 产物形态 / 签名产物存在 / 版本号一致 / 产物内无内网 IP）。**死代码清理完成**（`docs/dead-code-cleanup.md`：9 个文件 + 3 个空转 @Prop，其中 6 个「预览残留」经 git 历史证实确属删了一半的残留）。
> - **实证结论（unzip 产物字符串表）**：`DEBUG_API_HOST` 的字符串**会原样进 release 包**——当前 HAP（09-12 构建）内含旧值 `10.181.227.205:3000`；dev 账号登录桩字符串（`科技老张`/`虚拟小美`/`dev-seed-openid`）也在包内，属已知接受项（入口隐藏 + release throw 双兜底）。
> - **本轮未做及原因**：P1-3 HomeTab 分页并发（`HomeTab.ets` 正处于你的未提交批次中，避免连带提交）；`api.ets` 内网 IP 默认值改 `127.0.0.1`（会新增一个发版前还原点，需你确认是否值得）；版本号改读 bundleInfo / 注销清本地草稿（低风险延后项）。
> 另：修复全程**未触碰**你工作区里那批详情页 hero 未提交改动（以及你自己提交的 `c8ce013` ICP 备案号工作）。

---

## 结论速览

| 档位 | 数量 | 是否阻断提审 |
| --- | --- | --- |
| **P0 必须提审前处理** | 4 | **是**（隐私 2 项、功能缺失 1 项、卡死 3 处） |
| P1 建议修 | 8 | 否，但会影响审核印象或体验 |
| P2 清理 | 6 组 | 否 |
| 复核掉的误报 | 2 | — |

**一句话**：真正卡审核的是**两件隐私相关的事**（未同意先联网、相册权限与政策文案矛盾）＋**收藏夹重命名/删除没有入口**；另外有 3 处「参数丢失 → 永久转圈」需要在真机上手工覆盖测试。

---

## P0 必须提审前处理

### P0-1　首启「未同意隐私政策」之前，首页已经发起网络请求 ⚠️已人工复核

- **证据链**：`pages/Index.ets:322-334` `continueLaunchFlow()` 在 `!isPrivacyAgreed()` 时只弹窗并 `return`（不调 `startInit()`）——**但**同一页 `pages/Index.ets:529-531` 的 `mainTabContents()` 无条件构建 `TabContent() { HomeTab() }`，而 `components/HomeTab.ets:104-107` 的 `aboutToAppear()` 挂载即执行 `loadTags()` + `refresh()`。
- **后果**：用户还没点「同意并继续」，就已经向 `https://api.youju.chat` 发出 `GET /v1/tags`、`GET /v1/posts`。弹窗存在但不构成阻断 → 属「告知—同意后再处理」红线，**AIC 审核最常见的隐私打回项之一**。
- **改法（二选一）**：
  - A（推荐，改动小）：`HomeTab.aboutToAppear()` 与 `refresh()` 开头加同意闸门，`!isPrivacyAgreed()` 直接 return；并给 HomeTab 加 `@StorageLink('privacyAgreed') @Watch(...)`，同意后立即补拉。
  - B（更彻底）：`Index.build()` 里把 `mainTabContents()` 整体包在同意判断内，未同意时只渲染背景 + 弹窗。注意 `isPrivacyAgreed()` 是普通函数，需用 `@StorageLink` 让它驱动 build 重跑。
- 同样要检查 `CircleTab` / `MessagePage` / `ProfilePage` 的 `aboutToAppear` 是否有联网行为（它们同属 TabContent，会被一起构建）。

### P0-2　相册写权限：代码里申请了未声明的 `WRITE_IMAGEVIDEO`，且与隐私政策文案矛盾 ⚠️已人工复核

- **证据**：
  - 声明侧：`entry/src/main/module.json5:56-60` 的 `requestPermissions` **只有 `ohos.permission.INTERNET`**（构建产物 `entry/build/default/intermediates/res/default/module.json` 一致）。
  - 使用侧：`utils/shareCard.ets:270` `sharePostCardToSystem()` → `:284-287` `requestPermissionsFromUser(context, ['ohos.permission.WRITE_IMAGEVIDEO'])` → `:302` `createAsset` 静默写入系统图库。
  - 文案侧：`pages/PrivacyPage.ets:51` 明确写「图片和视频通过系统相册选择器选择，**我们不直接申请相册或相机权限**」。
- **关键事实**：`sharePostCardToSystem` 全项目 **0 调用点**（已 grep 确认，仅定义处 + 其内部的权限申请各 1 处）→ 是死代码。
- **后果**：HAP 内存在「申请未声明权限 + 访问相册」的代码，且与隐私政策自相矛盾。审核做静态比对时会命中。虽然运行时不触发，但属于**零收益的纯风险**。
- **改法**：直接删除 `utils/shareCard.ets:265-312` 这段（连同未使用的 import）。注意分享实际走的是 `pages/DetailPage.ets` 的 `sharePostToSystem` / `generateShareCardBytes`，删掉不影响功能。若将来确需保存到相册，本仓已有免权限方案：`utils/mediaSave.ets:59-66` 的 `showAssetsCreationDialog`。

### P0-3　收藏夹「重命名 / 删除」没有任何入口（功能缺失）

- **证据**：`pages/BookmarkFolderPage.ets` 已实现重命名（`:90` `renameBookmarkFolder`）与删除（`:109` `deleteBookmarkFolder`）、按钮在 `:164`，页面也已在 `main_pages.json:29` 注册 —— 但全项目 **0 处** `pushUrl`/`replaceUrl` 指向它，两个 API 也只有这一个调用方。
- **后果**：用户能新建收藏夹（`components/FolderPickDialog.ets:108-130`），但**永远改不了名、删不掉**。「功能半成品」是审核会点的问题。
- **改法**：在 `pages/ProfilePage.ets` 的「我收藏 → 收藏夹」子视图（约 `:577-591`）加一个「管理」入口；或把重命名/删除直接内联到收藏夹行（`:522-540`）。

### P0-4　参数丢失导致「永久转圈」，共 3 处（真机需手工覆盖测试）

`utils/nav.ts:1` 自己的注释就写明 **`router.getParams()` 在 API 24 不稳定**，以下三处把它当唯一数据来源，且没有兜底：

| 位置 | 触发条件 | 后果 |
| --- | --- | --- |
| `pages/BookmarkFolderDetailPage.ets:31-35` | `getParams()` 缺 `folderId`，或值非数字 → `Number()` 得 `NaN` → `NaN > 0` 为 false → `load()` 不执行 | `ready`（`:22` 初值 false）永远为 false → `:235` 永久「加载中…」，且 `:246` 的重试按钮在 `ready===true` 分支内，**没有出口** ⚠️已人工复核 |
| `pages/ChatPage.ets:74 / 104-106` | 进程恢复后模块级 `takeChatIntent()` 返回 null → `peerId = 0`；或未登录进入 | `loading`（初值 `true`）永不复位 → `:1020` 永久转圈；同时 `:107` 无条件 `startPolling()`，每 5 秒空跑 ⚠️已人工复核 |
| `pages/UserProfilePage.ets:131` | 游客先看到「去登录」→ 登录后 `authToken` 变化触发 `onTokenReady`，但 `targetId` 仍为 0 故不 `loadAll()`，而 `getToken() !== ''` 使 if/else 落入 Loading 分支 | 永久转圈。入口可能传 0：`components/CommentList.ets:133-136`、`components/PostCard.ets:91-92` 只判 `uid !== undefined`，未判 `uid > 0` |

- **统一改法**：所有「必须有参数才能工作」的页面，在参数缺失时**显式置失败态 + 文案 + 重试入口**（如 `this.error = '页面参数缺失，请返回重新进入'; this.ready = true;`），而不是停在初始 loading；调用方一律 `uid > 0` 才跳转。

---

## P1 建议修（不阻断，但影响印象或体验）

1. **登出后「我的」页仍显示上一账号的昵称/头像/帖子**：`pages/ProfilePage.ets:203-208` 的 `onUserChange()` 在 `!u || !u.id` 时直接 return，不清 `user`/`posts`/计数。TabContent 内组件被保留 → 隐私观感问题（其余页面 `MessagePage:150-161`、`HomeTab:136-140`、`CircleTab:188-200` 都做了清理，只有 ProfilePage 漏了）。
2. **登出后消息红点残留且可持久化**：`utils/auth.ets:83-91` 的 `clearSession()` 未复位 `unreadMessageCount` / `unreadDmCount`（两者是 `PersistentStorage`，`auth.ets:29-30`）→ 只要没打开过消息页就登出，红点会留着，**冷启动后依然显示上一账号的未读数**。
3. **加载更多进行中触发下拉刷新 → 刷新被静默丢弃 + 分页错位**：`components/HomeTab.ets:254-260`（refresh 先重置 page=1）、`:312-315`（`if (this.loading) return`）→ 在途的 `loadMore` 以旧页码回包 `concat`，用户看到「刷新没反应」甚至重复条目。
4. **关注/粉丝页参数丢失时显示「空态」而非失败态**：`pages/MyFollowPage.ets:56-62` + `:179-184` → 用户误以为自己没有关注/粉丝，且无重试。
5. **会话数据缺 `peer` 字段时点击即抛未捕获异常**：`pages/MessagePage.ets:295` `c.peer.id`，同文件 `:365`、`:414-415` 对 `actor` 做了防御，这里漏了。`services/api.ets:925-927` 是 `as` 直转，无字段级校验。
6. **3 个组件的定时器未纳入清理范式**：`components/SearchPanel.ets:66`、`design/components/BottomTabBar.ets:95`、`design/components/SegmentedControl.ets:98` —— 都只存句柄、只在 Up/Cancel 清，全文件**没有 `aboutToDisappear`**。SearchPanel 卸载后还会继续发联想请求。
7. **关于页应用图标是占位**：`pages/AboutPage.ets:37-41` 用的是通用「书本」线条图标（注释自述「App 图标占位」）。审核常核对「关于页品牌信息」，建议换成 `$media:layered_image` 或现有 logo。
8. **提审产物必须是 release product**：`build-profile.json5` 里 **`default` product 挂的是 `debug` 签名**（`:33-34`），只有 `release` product（`:58-70`，compatibleSdkVersion 6.0.0(20) / targetSdk 6.1.1(24)，挂 `release` 签名）才是提审用的。上传前确认取的是 `entry/build/release/outputs/default/entry-default-signed.hap`，不要误传 `default` / `debug` 目录下的包。

---

## P2 清理项（可延后）

1. **版本号 3 处硬编码**：`AppScope/app.json5:6` `1.0.0`、`pages/AboutPage.ets:47`、`pages/SettingsPage.ets:351` —— 当前一致，但改版本号会漏改。
2. **4 处过期注释**（代码已实现、注释还写「占位/待办」，会被误读）：`pages/DetailPage.ets:649`（分享域名占位，实际 `utils/share.ets:11` 已是 `https://youju.chat`）、`pages/DetailPage.ets:677`（系统分享「待接入」，实际已接入）、`pages/ChatPage.ets:717`（文件消息「预览留待 P1」，实际 `:805` 已实现）、`utils/share.ets:18/23`。
3. **开发桩残留分支**：`pages/Index.ets:406-408` 仍有 `await loginWithDevStub()`，仅由 `BUILD_MODE_NAME === 'debug'` 守卫（release 不可达）。发布前建议直接删除该分支及其 import。
4. **内网 IP 打进产物**：`services/api.ets:14` `DEBUG_API_HOST = 'http://10.116.97.205:3000'`（`DEBUG=false` 使其不生效，但字符串仍在包里）。建议改占位符。
5. **死代码批量清单**（不影响审核，建议清理）：
   - 完全不可达文件 9 个：`pages/ParchmentPreviewPage.ets`、`pages/FoundationPreviewPage.ets`、`design/preview/{ParchmentPreview,FoundationPreview}.ets`、`components/DailyPostView.ets`（自带 mock 数据 + Unsplash 外链）、`design/components/{AuthorRow,PollBlock}.ets`、`utils/breakpoint.ets`、`utils/data-source.ets`。其中 `design/preview/ParchmentPreview.ets:144` 含「敬请期待」占位文案，**一旦被误接回路由就直接暴露审核风险**。
   - 0 引用导出函数 10 个：`utils/share.ets:29 buildShareText`、`utils/settingsIcons.ets:36 resolveSettingsIconColor`、`utils/video.ets:178 captureVideoCoverBytes`、`utils/auth.ets:193 loginByHuaweiResult`、`utils/shareCard.ets:270 sharePostCardToSystem`、`utils/postDraftStore.ets:84 getPostDraft`、`utils/theme.ets:152 isReduceMotion`、`services/api.ets:359 updatePost`、`services/api.ets:382 listComments`、`services/api.ets:412 registerPushToken`（推送未接线）。
   - 0 引用 @Builder 3 个：`pages/SettingsPage.ets:160 toggleRow`（已被内联实现取代）、`pages/PublishPreviewPage.ets:113 posterOverlayBuilder`、`pages/ProfilePage.ets:637 postFooter`。
   - 空实现残留：`pages/PublishPreviewPage.ets:148-151 buildPosterOverlay()` 恒返回 `undefined`（与上面 `posterOverlayBuilder` 是同一废弃方案的上下两半）。
   - 死 @Prop 7 个（传了但组件内 0 引用 / 从未传）：`design/components/Avatar.ets:7 name`、`components/AvatarView.ets:10 name`、`design/components/IconTile.ets:13 tint`、`:14 selected`（且 `:29` 三元两个分支返回同值，选中态视觉不变）、`design/components/GlassPanel.ets:13 glassBlurRadius`、`components/CircleOrbitCanvas.ets:49 nickname`、`components/PostCard.ets:23 variant`（8 个调用点全不传 → `draft`/`preview` 分支不可达）。
6. **两个 Tab 子页面未注册**：`pages/MessagePage.ets`、`pages/ProfilePage.ets` 未进 `main_pages.json`，但作为 `Index` 的 TabContent 使用（正常）。若你担心审核以「文件必须注册」核对，可一并注册（无副作用）。另：`main_pages.json` 注册但 0 跳转的只有 `BookmarkFolderPage`（见 P0-3）。

---

## 我复核掉的误报（避免制造无效工作量）

1. **「游客进消息页会永久转圈」——不成立**。`pages/MessagePage.ets:702-705` 的 `if (this.token === '') { this.guestState() }` 分支在 `loading` 判断**之前**，游客走的是登录引导态，不会命中 `:725` 的转圈分支。
2. **「@StorageLink key 拼错 / 永远同步不上」——不成立**。已逐个 key 反查写入方，未发现只有读取方、或形似拼写不同的 key 对（`unreadMessageCount` / `unreadDmCount` 语义不同，是设计如此）。

---

## 建议的处理顺序

1. **P0-2（删死代码）**：改动最小、收益最直接 —— 一次删除同时消除「未声明权限」「与隐私政策矛盾」两个风险点。
2. **P0-1（同意闸门）**：隐私红线的正解，建议按方案 A 做（HomeTab 加闸门 + 同意后补拉），并顺手确认其余 Tab 的 `aboutToAppear` 无联网。
3. **P0-4（3 处永久转圈）**：都是「参数缺失时没有失败态」，统一按同一模式改。
4. **P0-3（收藏夹入口）**：纯 UI 接线，改 ProfilePage 一处。
5. P1 里优先 **1、2**（登出残留是隐私观感问题）、**8**（产物形态，上传前必查）。
6. P2 挑着做；**`design/preview/ParchmentPreview.ets` 的「敬请期待」占位文案建议一并删掉**，它是最容易被误接回路由的雷。

---

## 提审前的手工核对清单（代码查不出来的）

- [ ] **先跑 `sh check-release.sh`**（自动核对：buildMode 还原 / release 产物形态与签名包存在 / 版本号一致 / 产物内无内网 IP），全部 ✅ 再继续下面的
- [ ] 用 **release product** 构建，确认产物是 `entry/build/release/outputs/default/*-signed.hap`
- [ ] AGC 后台的**隐私政策 URL / 应用介绍 / 截图 / 分类**与本包一致
- [ ] 真机冷启动首启流程：弹窗 →「不同意」能退出；「同意并继续」后功能正常
- [ ] 真机手工覆盖 P0-4 三个页面：直接进详情页（丢参数）、弱网、切后台恢复
- [ ] 真机走一遍：注册/登录 → 发帖（图文/视频/长文）→ 分享 → 举报 → 拉黑 → 注销账号
- [ ] 权限弹窗只出现在「用到时」，且文案与 `module.json5` 一致（本人版本应无任何权限弹窗）
- [ ] 弱网/飞行模式下每个列表页都能出「失败 + 重试」，不出现永久转圈
