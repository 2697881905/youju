-- 有据：私有 COS 媒体异步删除任务。
-- 执行前请备份数据库；新建库由 schema.prisma 自动包含此表。
CREATE TABLE IF NOT EXISTS `MediaDeletionTask` (
  `id` INT NOT NULL AUTO_INCREMENT,
  `key` VARCHAR(512) NOT NULL,
  `attempts` INT NOT NULL DEFAULT 0,
  `nextAttemptAt` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  `lastError` VARCHAR(1000) NULL,
  `completedAt` DATETIME(3) NULL,
  `createdAt` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  `updatedAt` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  PRIMARY KEY (`id`),
  UNIQUE INDEX `MediaDeletionTask_key_key` (`key`),
  INDEX `MediaDeletionTask_completedAt_nextAttemptAt_idx` (`completedAt`, `nextAttemptAt`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
