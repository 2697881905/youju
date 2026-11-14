-- 「有据」计数对账 X（作战方案 §6.7）
-- 状态：未执行。由开发者在生产库自行跑，AI 不碰生产写操作。
-- 目的：Post.upCount 合计 15081 但 Up 表只有 36 行；bookmarkCount 合计 4648 但 Bookmark 表只有 15 行。
--       hotScore 吃的就是这几列灌出来的假数，重算也救不了排序。
--       本脚本把计数列回填成真实行为表行数，再调 recompute-hot（或重启 backend，index.ts 启动时会重算）。
-- 前置：先跑 ~/youju-backup-20261115.sql 那份 mysqldump 全表备份。
-- 不改：viewCount 保留（详情页「N 人看过」不能全空）、commentCount 保留（426 vs 429 已对得上）。
-- 回滚：UPDATE Post p JOIN CountBackup20261115 b ON b.postId = p.id
--          SET p.upCount = b.oldUpCount, p.bookmarkCount = b.oldBookmarkCount, p.hotScore = b.oldHotScore;

-- 备份计数列与热度分。故意不加 IF NOT EXISTS：重复执行会报「table already exists」，
-- 这是防止把首次备份覆盖掉的保护，别删表重跑。
CREATE TABLE CountBackup20261115 AS
SELECT id AS postId, upCount AS oldUpCount, bookmarkCount AS oldBookmarkCount, hotScore AS oldHotScore
FROM Post;

-- 对账前读数（预期：up 合计 15081 / bookmark 合计 4648）
SELECT COUNT(*) AS posts, SUM(upCount) AS up_sum, SUM(bookmarkCount) AS bookmark_sum
FROM Post WHERE deletedAt IS NULL;
SELECT COUNT(*) AS real_ups FROM Up;
SELECT COUNT(*) AS real_bookmarks FROM Bookmark;

-- 回填（字段名已核 backend/prisma/schema.prisma：Up.postId / Bookmark.postId / Post.id）
UPDATE Post p SET p.upCount = (SELECT COUNT(*) FROM Up u WHERE u.postId = p.id);
UPDATE Post p SET p.bookmarkCount = (SELECT COUNT(*) FROM Bookmark b WHERE b.postId = p.id);

-- 对账后读数（预期：up 合计 36 / bookmark 合计 15）
SELECT COUNT(*) AS posts, SUM(upCount) AS up_sum_after, SUM(bookmarkCount) AS bookmark_sum_after
FROM Post WHERE deletedAt IS NULL;
SELECT COUNT(*) AS backed_up_rows FROM CountBackup20261115;
