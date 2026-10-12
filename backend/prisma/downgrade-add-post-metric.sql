-- 有据：回滚 upgrade-add-post-metric.sql。
-- 四列是派生列（随时可由 structuredDocument 重算），删掉不丢作者内容。
DROP INDEX `Post_genre_status_deletedAt_metricValue_idx` ON `Post`;

ALTER TABLE `Post`
  DROP COLUMN `metricValue`,
  DROP COLUMN `metricKind`,
  DROP COLUMN `metricLabel`,
  DROP COLUMN `metricText`;
