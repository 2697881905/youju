# 有据 AppGallery 预览图草稿

这套文件按 1080×1920、9:16、RGB 导出，主交付为无损 PNG，同时提供高质量 JPG 兼容版本。

顶部品牌图标使用你确认的 App 图标 `source/logo.png`（`/Users/itxiaobai/Pictures/有据UI/有据Logo2.png`）。

## 当前状态

这是“真实截图版式草稿”，脚本只使用 `source/` 中的真实 App 截图，不绘制来源徽章、证伪标签、投票结果或隐私设置控件。每张标题现在只描述对应截图中实际可见的页面能力。

当前附件仍包含测试数据或未填写状态，正式提审前需要替换为干净的公开内容：

- `preview-01-home.png`：首页需替换测试帖子
- `preview-02-structured.png`：结构化发布页目前是未填写状态
- `preview-03-detail.png`：帖子详情页需替换测试内容
- `preview-04-circles.png`：圈子页需替换测试账号和人数
- `preview-05-daily.png`：每日一帖需替换测试封面和标题
- `preview-06-messages.png`：当前展示的是消息中心；隐私设置页需另行补拍后才能宣传隐私控制

当前标题与截图一一对应：推荐/关注首页、结构化发布、帖子详情、圈子地图、每日一帖、消息中心。旧版命名文件已移入 `legacy/`，不用于提审。

补齐截图后，在 `source/` 替换对应文件并重新运行：

```bash
python3 deliverables/appgallery-previews-1080x1920/generate_previews.py
```

`manifest.json` 记录每张图的尺寸、色彩模式、PNG/JPG 文件和真实来源。当前版本没有来源标注/证伪功能，首图不会宣称“每条经验都有来源”。
