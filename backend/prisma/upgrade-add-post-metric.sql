-- 有据：帖子主数字落列（跨帖对比表）
-- 协议 V3 的 kind/numberValue 只活在 JSON 列里，按它排序既吃不到索引也慢；
-- 这里把「这篇帖子最硬的那个数字」收敛成四列，由服务端在发布/编辑时从 metric 块抽取。
-- 四列同生同灭：没有可比数字时一起留 NULL，与「数字为 0」区分开。
ALTER TABLE `Post`
  ADD COLUMN `metricValue` DOUBLE NULL,
  ADD COLUMN `metricKind` VARCHAR(16) NULL,
  ADD COLUMN `metricLabel` VARCHAR(30) NULL,
  ADD COLUMN `metricText` VARCHAR(40) NULL;

-- 对比表查询形态：genre 等值 + status/deletedAt 等值 + metricValue 排序，一条复合索引全覆盖。
CREATE INDEX `Post_genre_status_deletedAt_metricValue_idx` ON `Post`(`genre`, `status`, `deletedAt`, `metricValue`);

-- 存量帖子回填：本迁移不猜 JSON（MySQL 侧要区分主视觉块与首个数字块、还要判单位，
-- 写进 SQL 会既难读又难回滚）。改由一次性脚本回填，可重复执行：
--   本地：npx tsx src/scripts/backfill-post-metric.ts
--   生产：docker exec youju-backend node dist/scripts/backfill-post-metric.js
