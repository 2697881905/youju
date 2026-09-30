-- 有据：通知表补充 commentId（@提及通知「点击跳转到该评论」所需）
--
-- 背景：@提及通知此前只记录 postId，点开后只能落在帖子顶部，无法定位到具体评论。
-- 补一列记录被提及评论的 id，前端点通知可滚动定位并高亮该评论。
--
-- 该列 NULL 允许，加列不影响现有行；历史数据保持 NULL，前端遇到 NULL 时
-- 维持「只打开帖子」的旧行为，与现在一致。

ALTER TABLE `Notification`
  ADD COLUMN `commentId` INTEGER NULL;