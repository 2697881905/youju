-- 回滚：圈子同城维
ALTER TABLE `Tag` DROP COLUMN `cityCode`;
ALTER TABLE `Post` DROP COLUMN `cityCode`;
-- 注：MySQL 8 会随列删除自动清理索引 Tag_cityCode_idx
