-- 有据：私信撤回 + 仅自己删除
-- 存量库升级前请先备份；新建库由 schema.prisma 自动包含该字段/表。
ALTER TABLE `Message`
  ADD COLUMN `recalledAt` DATETIME(3) NULL;

CREATE TABLE `MessageDeletion` (
  `id`        INT          NOT NULL AUTO_INCREMENT,
  `userId`    INT          NOT NULL,
  `messageId` INT          NOT NULL,
  `createdAt` DATETIME(3)  NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  PRIMARY KEY (`id`),
  UNIQUE KEY `MessageDeletion_userId_messageId_key` (`userId`, `messageId`),
  INDEX `MessageDeletion_messageId_idx` (`messageId`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
