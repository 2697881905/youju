-- 有据：结构化帖子 V2 通用信息块文档
-- 存量帖子继续读取 structuredData；新帖子双写兼容并以 structuredDocument 为主。
ALTER TABLE `Post`
  ADD COLUMN `structuredDocument` JSON NULL,
  ADD COLUMN `structuredSearchText` TEXT NULL;

-- 历史 structuredData 先展平到检索列；V2 新帖由服务端写入完整块文本。
UPDATE `Post`
SET `structuredSearchText` = NULLIF(CONCAT_WS(' ',
  NULLIF(JSON_UNQUOTE(JSON_EXTRACT(`structuredData`, '$.pros')), 'null'),
  NULLIF(JSON_UNQUOTE(JSON_EXTRACT(`structuredData`, '$.cons')), 'null'),
  NULLIF(JSON_UNQUOTE(JSON_EXTRACT(`structuredData`, '$.rating')), 'null'),
  NULLIF(JSON_UNQUOTE(JSON_EXTRACT(`structuredData`, '$.targetAudience')), 'null'),
  NULLIF(JSON_UNQUOTE(JSON_EXTRACT(`structuredData`, '$.pitfallExperience')), 'null'),
  NULLIF(JSON_UNQUOTE(JSON_EXTRACT(`structuredData`, '$.lossAmount')), 'null'),
  NULLIF(JSON_UNQUOTE(JSON_EXTRACT(`structuredData`, '$.correctApproach')), 'null'),
  NULLIF(JSON_UNQUOTE(JSON_EXTRACT(`structuredData`, '$.tools')), 'null'),
  NULLIF(JSON_UNQUOTE(JSON_EXTRACT(`structuredData`, '$.steps')), 'null'),
  NULLIF(JSON_UNQUOTE(JSON_EXTRACT(`structuredData`, '$.timeDifficulty')), 'null'),
  NULLIF(JSON_UNQUOTE(JSON_EXTRACT(`structuredData`, '$.planA')), 'null'),
  NULLIF(JSON_UNQUOTE(JSON_EXTRACT(`structuredData`, '$.planB')), 'null')
), '');
