-- 大蓝书：隐私政策同意落地（PIPL 可追溯）
-- 给 User 表追加两个字段，服务端留存用户同意的隐私政策版本与同意时间。
--
-- 用法：
--   ① 全新部署（库还未建表）：无需本脚本，直接 `npx prisma migrate dev --name init`，
--      会依据完整 schema.prisma 一次性建表（已含这两个字段）。
--   ② 存量库升级（表已存在）：执行本脚本追加列。执行前请先备份数据库。
--
-- 说明：Prisma 的 DateTime 在 MySQL 下映射为 DATETIME(3)（毫秒精度）。

ALTER TABLE `User`
  ADD COLUMN `privacyPolicyVersion` VARCHAR(32) NULL,
  ADD COLUMN `privacyAgreedAt` DATETIME(3) NULL;
