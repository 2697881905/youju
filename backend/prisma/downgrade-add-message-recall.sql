-- 有据：回滚私信撤回 + 仅自己删除
ALTER TABLE `Message` DROP COLUMN `recalledAt`;
DROP TABLE IF EXISTS `MessageDeletion`;
