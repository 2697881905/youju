-- 有据：回滚 upgrade-add-notification-comment-id.sql。
-- 回滚后 @提及通知丢失「定位到具体评论」的能力，前端自动退回「只打开帖子」。
ALTER TABLE `Notification`
  DROP COLUMN `commentId`;