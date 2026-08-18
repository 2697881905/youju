-- 回滚前请确认没有待执行的媒体删除任务；回滚会使这些任务丢失。
DROP TABLE IF EXISTS `MediaDeletionTask`;
