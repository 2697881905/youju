-- 有据：下线「帖子主数字」四列与对比表索引（2026-11-07）
-- 同体裁数字对比功能整体退役（PostCompareSheet / GET /v1/posts/compare / 派生写入全删），
-- 四列不再有任何读写方，按「代码删干净、库也删干净」处理。
-- 回滚用 downgrade-add-post-metric.sql（与原建列迁移的回滚是同一份，操作互逆；
-- 注意：列删除后派生数据不可恢复，回滚得到的是空列）。
ALTER TABLE `Post`
  DROP COLUMN `metricValue`,
  DROP COLUMN `metricKind`,
  DROP COLUMN `metricLabel`,
  DROP COLUMN `metricText`;

DROP INDEX `Post_genre_status_deletedAt_metricValue_idx` ON `Post`;
