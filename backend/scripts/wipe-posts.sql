-- ============================================================================
-- 有据 · 清空所有帖子（全量连坐删除）· WIPE-POSTS
-- ============================================================================
-- !! 不可逆操作 !! 执行前务必先备份：bash ~/youju/backup.sh
-- 用法（服务器上）：
--   sudo docker cp wipe-posts.sql youju-mysql:/tmp/wipe-posts.sql
--   sudo docker exec youju-mysql sh -c 'exec mysql -uroot -p$MYSQL_ROOT_PASSWORD youju < /tmp/wipe-posts.sql'
--
-- 删除范围：
--   Post（本体）                        → ON DELETE CASCADE 级联清 Comment/Up/Bookmark
--   CommentUp（评论点赞）               → 无外键，手动删
--   PostEvent（曝光/点击埋点）          → 无外键，手动删
--   DebateVote（辩论帖 A/B 投票）       → 无外键，手动删
--   Notification（postId 非空的）       → 标量关联，手动删（保留系统/私信类通知）
--   MediaDeletionTask（登记 COS 媒体）  → 先读后删，抽出帖子媒体 key，交给后端
--                                       mediaDeletionService 定时 worker 删 COS 对象
-- 不影响：User / Tag / UserFollowTag / SearchHistory / Message（私信）/ Follow
--         / Report / BookmarkFolder / PushToken / Notification(无 postId) 等
-- ============================================================================

-- 0) COS 媒体删除任务登记（从将要删除的帖子抽出 cos:// key；`key` 为 MySQL 保留字需反引号）
INSERT IGNORE INTO MediaDeletionTask (`key`)
SELECT TRIM(TRAILING '"' FROM SUBSTRING_INDEX(SUBSTRING_INDEX(p.coverImage, 'cos://', -1), '"', 1))
FROM Post p WHERE p.coverImage LIKE 'cos://%';

INSERT IGNORE INTO MediaDeletionTask (`key`)
SELECT TRIM(TRAILING '"' FROM SUBSTRING_INDEX(SUBSTRING_INDEX(p.videoCover, 'cos://', -1), '"', 1))
FROM Post p WHERE p.videoCover LIKE 'cos://%';

INSERT IGNORE INTO MediaDeletionTask (`key`)
SELECT TRIM(TRAILING '"' FROM SUBSTRING_INDEX(SUBSTRING_INDEX(p.videoUrl, 'cos://', -1), '"', 1))
FROM Post p WHERE p.videoUrl LIKE 'cos://%';

-- images 是 JSON 数组（MySQL 8 JSON 列）：逐元素提取字符串
INSERT IGNORE INTO MediaDeletionTask (`key`)
SELECT DISTINCT TRIM(TRAILING '"' FROM SUBSTRING_INDEX(SUBSTRING_INDEX(JSON_UNQUOTE(json_elem), 'cos://', -1), '"', 1))
FROM Post p
CROSS JOIN JSON_TABLE(COALESCE(p.images, JSON_ARRAY()), '$[*]' COLUMNS(json_elem JSON PATH '$')) AS jt
WHERE p.images IS NOT NULL AND p.images LIKE '%cos://%';

-- 1) 无外键关联表
DELETE FROM PostEvent;
DELETE FROM DebateVote;
DELETE FROM CommentUp;
DELETE FROM Notification WHERE postId IS NOT NULL;

-- 2) 帖子本体（Comment/Up/Bookmark 经内部外键 ON DELETE CASCADE 级联清理）
DELETE FROM Post;

-- 3) 校验应全为 0
SELECT 'Post' AS tbl, COUNT(*) AS n FROM Post
UNION ALL SELECT 'Comment', COUNT(*) FROM Comment
UNION ALL SELECT 'Up', COUNT(*) FROM Up
UNION ALL SELECT 'Bookmark', COUNT(*) FROM Bookmark
UNION ALL SELECT 'CommentUp', COUNT(*) FROM CommentUp
UNION ALL SELECT 'PostEvent', COUNT(*) FROM PostEvent
UNION ALL SELECT 'DebateVote', COUNT(*) FROM DebateVote
UNION ALL SELECT 'Notification(postId)', COUNT(*) FROM Notification WHERE postId IS NOT NULL;