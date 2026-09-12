-- 清空搜索历史与热搜榜（两者同源 SearchHistory 表：历史=按用户查询，热搜=按关键词聚合）
-- 不影响用户/帖子/标签等其他数据。
DELETE FROM SearchHistory;

-- 校验
SELECT 'SearchHistory' AS tbl, COUNT(*) AS n FROM SearchHistory;