-- 大蓝书：回滚 upgrade-add-privacy-consent.sql
-- 在需要回退「隐私政策同意字段」时执行（与 upgrade-add-privacy-consent.sql 成对）。
-- 执行前请先备份数据库。
-- 说明：Prisma 的 DateTime 在 MySQL 下映射为 DATETIME(3)（毫秒精度），DROP 时无需指定。

ALTER TABLE `User`
  DROP COLUMN `privacyPolicyVersion`,
  DROP COLUMN `privacyAgreedAt`;
