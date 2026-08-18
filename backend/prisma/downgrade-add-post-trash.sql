-- 有据：回滚 upgrade-add-post-trash.sql。
-- 执行前请确认废纸篓中的帖子已经处理，回滚会丢失其删除时间。
ALTER TABLE `Post`
  DROP COLUMN `deletedAt`;
