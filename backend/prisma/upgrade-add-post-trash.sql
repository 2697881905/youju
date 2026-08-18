-- 有据：帖子废纸篓（软删除）
-- 存量库升级前请先备份；新建库由 schema.prisma 自动包含该字段。
ALTER TABLE `Post`
  ADD COLUMN `deletedAt` DATETIME(3) NULL;
