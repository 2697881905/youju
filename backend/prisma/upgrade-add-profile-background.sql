-- 给 User 表追加个人主页背景图字段。
-- 存量库升级前请先备份；新建库由 schema.prisma 自动包含该字段。
ALTER TABLE `User`
  ADD COLUMN `profileBackground` LONGTEXT NULL;
