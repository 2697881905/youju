# 有据 AppGallery 预览图

当前版本按 `1080×1920`、`9:16`、RGB 输出，主交付为 PNG，同时提供高质量 JPG 备用。海报外部采用新版 App 的白底、近黑宋体标题、蓝色强调和浅灰细边；手机截图使用本轮提供的 `1320×2848` 原图，按原比例一次缩放并加圆角。

顶部图标使用 `source/logo.png`，来源为确认的 App 图标 `/Users/itxiaobai/Pictures/有据UI/有据Logo2.png`。海报不再使用上一版米白和暖棕主导的视觉。

## 当前 6 张

- `preview-01-home.png`：首页，推荐/关注/每日一帖
- `preview-02-structured.png`：结构化发布，优缺点与推荐指数字段
- `preview-03-search.png`：搜索你关心的经验和问题
- `preview-04-circles.png`：圈子地图，按问题找到主题圈子
- `preview-05-daily.png`：每日一帖，今日精选卡片
- `preview-06-share-card.png`：分享卡片，整理并分享经验

本轮没有使用登录页、编辑资料页、私信页、空的圈子详情页或数据面板。当前截图仍包含测试头像、测试帖子、品牌搜索词和空编辑字段，正式提审前需要替换为可公开展示的内容。

`manifest.json` 记录每张图的 PNG/JPG 文件、尺寸、色彩模式和对应真实截图。上传时优先选 PNG；若商店文件大小受限，再使用同名 JPG。

重新生成：

```bash
python3 deliverables/appgallery-previews-1080x1920/generate_previews.py
```

上一版截图和旧命名输出保存在 `legacy/`，不用于上传。
