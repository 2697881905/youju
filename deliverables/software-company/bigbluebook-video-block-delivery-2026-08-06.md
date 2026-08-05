# 交付报告 — 视频上传 + 拉黑/不喜欢

日期：2026-08-06
项目：大蓝书 (BigBlueBook)
工作流：快速模式（工程师实现 → QA 验证）

## TL;DR
1. 视频上传功能全链路闭环（发布→预览→信息流/详情展示）。
2. 他人主页"⋯"更多按钮接入拉黑入口 + 新建"不喜欢"降权（推荐流排除、最新流保留）。
3. QA 后端 `tsc --noEmit` exit 0，6/6 验证项 PASS，无阻断 Bug。

---

## 功能一：视频上传（收尾）

### 改动文件
**后端**
- `backend/prisma/schema.prisma` — Post 加 `videoUrl`/`videoCover`
- `backend/src/routes/upload.ts` — folder 加 `video`、size 入参、ALLOWED_LOCAL_TYPES 加 video/mp4、50MB 兜底
- `backend/src/services/uploadService.ts` — video folder 强制 COS
- `backend/src/services/postService.ts` — createPost/updatePost 落库 videoUrl/videoCover
- `backend/src/routes/posts.ts` — 解构+校验
- `backend/src/config/env.ts` — `maxVideoSizeBytes`

**前端**
- `entry/src/main/ets/models/types.ets` — Post 加 videoUrl/videoCover
- `entry/src/main/ets/services/api.ets` — UploadSignatureBody/CreatePostBody/UpdatePostBody/getUploadSignature 加 video/size
- `entry/src/main/ets/utils/video.ets`（新）— 首帧抓封面/读字节/大小
- `entry/src/main/ets/components/VideoPlayer.ets`（新）— ArkUI Video 封装
- `entry/src/main/ets/components/VideoPicker.ets`（新）— 选视频→封面→直传
- `entry/src/main/ets/components/PostCardMedia.ets` — 视频=封面+Path 三角角标
- `entry/src/main/ets/components/PostCard.ets` — 传视频字段
- `entry/src/main/ets/pages/DetailPage.ets` — 视频优先 VideoPlayer
- `entry/src/main/ets/pages/PublishPage.ets` — 图文/视频/文字三段互斥切换器
- `entry/src/main/ets/pages/PublishPreviewPage.ets` — 视频分支
- `entry/src/main/ets/utils/publishDraft.ets` / `publishFlowStore.ets` / `postDraftStore.ets` — 草稿带视频字段
- `entry/src/main/ets/components/PublishModeSheet.ets` — 加视频发布选项
- `entry/src/main/resources/base/media/media_video.svg`（新）

### 关键决策
- 轻量单视频，与图片互斥不混排
- 视频 folder 强制 COS（忽略 local 降级），≤50MB 服务端兜底
- 信息流非自动播放（封面+角标），点进详情播放
- 播放角标用 Path SVG commands（规避 Polygon 元组 ArkTS 类型风险）

---

## 功能二：拉黑入口 + 不喜欢降权

### 改动文件
**后端**
- `backend/prisma/schema.prisma` — 新增 Dislike 模型
- `backend/src/services/dislikeService.ts`（新）— dislikeUser/undislikeUser/listDisliked/isDisliked，幂等，禁自 dislike
- `backend/src/routes/dislike.ts`（新）— POST/DELETE/GET /v1/me/dislike，auth 中间件
- `backend/src/app.ts` — 注册 dislikeRouter
- `backend/src/services/accessControl.ts` — `getDislikedAuthorIds`（单向）
- `backend/src/services/postService.ts` — listPosts：recommend 流 excluded=拉黑∪dislike 去重；latest/following 仅拉黑
- `backend/src/services/followService.ts` — getUserProfile 返回加 isBlocked/isDisliked

**前端**
- `entry/src/main/ets/models/types.ets` — UserProfile 加 isBlocked?/isDisliked?
- `entry/src/main/ets/services/api.ets` — dislikeUser/undislikeUser
- `entry/src/main/ets/pages/UserProfilePage.ets` — 顶栏"⋯"更多按钮（本人/已注销不显示）+ bindMenu + 拉黑二次确认 + 乐观更新+回滚

### 降权策略
- **拉黑**：双向完全互不可见（已有 accessControl 双向过滤）
- **不喜欢**：单向，推荐流排除该作者帖子，最新流/关注流/作者主页/搜索仍可见

---

## QA 验证结果（严过关）
- 后端 `prisma generate` + `tsc --noEmit`：**exit 0，零错误**
- dislikeService 幂等（P2002/P2025）+ 禁自 dislike：PASS
- followService 两分支返回 isBlocked/isDisliked：PASS
- accessControl getDislikedAuthorIds 单向：PASS
- 前端 ArkTS V1 严格合规（bindMenu/Path/Pressable）：PASS
- 视频草稿持久化（postDraftStore 赋值+校验）：PASS
- **非阻断观察**（无需修复）：getUserProfile 已注销分支硬编码 isBlocked/isDisliked=false（正确匿名化设计）

---

## 用户下一步

### 后端（同步 schema + 重启）
```
cd /Users/itxiaobai/HarmonyProject1/backend
npx prisma db push
npx prisma generate
```
重启后端服务。

### 前端（卸载重装 HAP）
DevEco Build Hap + 卸载旧包 + 重装。

### 验证拉黑/不喜欢
1. 他人主页右上角"⋯" → 拉黑该作者 → 二次确认 → 推荐流不再见该作者
2. 他人主页"⋯" → 不喜欢该作者 → 推荐流不再见，最新流仍见
3. 作者主页/搜索仍可搜到该作者

### 验证视频
1. 发布页切"视频" → 选 mp4（≤50MB）→ 上传 → 预览 → 发布
2. 信息流显示封面 + 播放角标
3. 点进详情页播放视频

### Git 提交
```
cd /Users/itxiaobai/HarmonyProject1
git add -A
git commit -m "feat: 视频上传 + 拉黑入口与不喜欢降权"
git push origin main
```
