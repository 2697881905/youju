-- ============================================================================
-- 有据 · 清空「全部用户数据」（上架前彻底重置）· WIPE-ALL-DATA
-- ============================================================================
-- !! 不可逆操作 !! 执行前务必先备份：
--   本地：mysqldump -h127.0.0.1 -uyouju -pyouju youju > backup.sql
--   生产：bash ~/youju/backup.sh（或脚本 wipe-all-data.sh 会自动先备份）
--
-- 用法（服务器上）：
--   bash scripts/wipe-all-data.sh            # 交互确认 + 自动备份
--   bash scripts/wipe-all-data.sh --yes      # 跳过确认
--
-- 删除范围（账号 + 内容 + 互动 + 消息 + 通知 + 设置，即「软件内所有存储的数据」）：
--   User / Post / Comment / CommentUp / Up / Bookmark / BookmarkFolder /
--   UserFollowTag / SearchHistory / UserBinding / Notification /
--   NotificationPreference / PushToken / PushLog / Follow / Report /
--   Blocklist / Dislike / PrivacySettings / DebateVote / Message /
--   MessageDeletion / PostEvent
--   （Comment/Up/Bookmark 对 Post、UserBinding/PushToken 对 User 虽为 Cascade，
--    但多数表是「裸 userId/postId 无外键」，不会级联——故一律显式删除，
--    避免留下孤儿数据。）
--
-- ★ 保留：Tag（标签/圈子基座，删除会导致首页与发帖不可用）
-- ★ 保留：MediaDeletionTask（待删除 COS 媒体队列，本脚本会把帖子媒体登记进去，
--          由后端 mediaDeletionService 定时 worker 真实删除 COS 对象）
--
-- ⚠️ 执行后必须做的一件事：
--   所有账号已删除，新登录用户 id 会变化；管理员身份由环境变量 ADMIN_USER_IDS
--   决定（本地 .env / 生产 .env.production）。请用新账号登录一次、查到其 userId，
--   更新 ADMIN_USER_IDS=<新id> 后重启后端，否则「内容审核台」将不可用。
-- ============================================================================

-- 0) COS 媒体删除任务登记（从将被删除的帖子抽出 cos:// key）
INSERT IGNORE INTO MediaDeletionTask (`key`)
SELECT TRIM(TRAILING '"' FROM SUBSTRING_INDEX(SUBSTRING_INDEX(p.coverImage, 'cos://', -1), '"', 1))
FROM Post p WHERE p.coverImage LIKE 'cos://%';

INSERT IGNORE INTO MediaDeletionTask (`key`)
SELECT TRIM(TRAILING '"' FROM SUBSTRING_INDEX(SUBSTRING_INDEX(p.videoCover, 'cos://', -1), '"', 1))
FROM Post p WHERE p.videoCover LIKE 'cos://%';

INSERT IGNORE INTO MediaDeletionTask (`key`)
SELECT TRIM(TRAILING '"' FROM SUBSTRING_INDEX(SUBSTRING_INDEX(p.videoUrl, 'cos://', -1), '"', 1))
FROM Post p WHERE p.videoUrl LIKE 'cos://%';

INSERT IGNORE INTO MediaDeletionTask (`key`)
SELECT DISTINCT TRIM(TRAILING '"' FROM SUBSTRING_INDEX(SUBSTRING_INDEX(JSON_UNQUOTE(json_elem), 'cos://', -1), '"', 1))
FROM Post p
CROSS JOIN JSON_TABLE(COALESCE(p.images, JSON_ARRAY()), '$[*]' COLUMNS(json_elem JSON PATH '$')) AS jt
WHERE p.images IS NOT NULL AND p.images LIKE '%cos://%';

-- 1) 叶子表 / 无外键约束的用户数据（先删，避免外键阻塞）
DELETE FROM `CommentUp`;
DELETE FROM `PostEvent`;
DELETE FROM `DebateVote`;
DELETE FROM `MessageDeletion`;
DELETE FROM `PushLog`;
DELETE FROM `SearchHistory`;
DELETE FROM `UserFollowTag`;
DELETE FROM `Dislike`;
DELETE FROM `Blocklist`;
DELETE FROM `Follow`;
DELETE FROM `Report`;
DELETE FROM `Notification`;
DELETE FROM `NotificationPreference`;
DELETE FROM `PrivacySettings`;
DELETE FROM `Message`;
DELETE FROM `Bookmark`;         -- 先删收藏（folderId 指向收藏夹）
DELETE FROM `BookmarkFolder`;

-- 2) 帖子从属表（对 Post 有 Cascade，但显式删更明确）
DELETE FROM `Up`;
DELETE FROM `Comment`;

-- 3) 帖子本体
DELETE FROM `Post`;

-- 4) 账号（最后删；UserBinding/PushToken 若残留由 Cascade 清理）
DELETE FROM `UserBinding`;
DELETE FROM `PushToken`;
DELETE FROM `User`;

-- 5) 校验：用户数据应全为 0；Tag 应保持原有数量（>0 说明基座未受影响）
SELECT 'User' tbl, COUNT(*) n FROM `User`
UNION ALL SELECT 'Post', COUNT(*) FROM `Post`
UNION ALL SELECT 'Comment', COUNT(*) FROM `Comment`
UNION ALL SELECT 'CommentUp', COUNT(*) FROM `CommentUp`
UNION ALL SELECT 'Up', COUNT(*) FROM `Up`
UNION ALL SELECT 'Bookmark', COUNT(*) FROM `Bookmark`
UNION ALL SELECT 'BookmarkFolder', COUNT(*) FROM `BookmarkFolder`
UNION ALL SELECT 'Notification', COUNT(*) FROM `Notification`
UNION ALL SELECT 'NotificationPreference', COUNT(*) FROM `NotificationPreference`
UNION ALL SELECT 'PushToken', COUNT(*) FROM `PushToken`
UNION ALL SELECT 'PushLog', COUNT(*) FROM `PushLog`
UNION ALL SELECT 'Message', COUNT(*) FROM `Message`
UNION ALL SELECT 'MessageDeletion', COUNT(*) FROM `MessageDeletion`
UNION ALL SELECT 'Follow', COUNT(*) FROM `Follow`
UNION ALL SELECT 'Report', COUNT(*) FROM `Report`
UNION ALL SELECT 'Blocklist', COUNT(*) FROM `Blocklist`
UNION ALL SELECT 'Dislike', COUNT(*) FROM `Dislike`
UNION ALL SELECT 'PrivacySettings', COUNT(*) FROM `PrivacySettings`
UNION ALL SELECT 'UserBinding', COUNT(*) FROM `UserBinding`
UNION ALL SELECT 'UserFollowTag', COUNT(*) FROM `UserFollowTag`
UNION ALL SELECT 'SearchHistory', COUNT(*) FROM `SearchHistory`
UNION ALL SELECT 'DebateVote', COUNT(*) FROM `DebateVote`
UNION ALL SELECT 'PostEvent', COUNT(*) FROM `PostEvent`
UNION ALL SELECT 'Tag(保留)', COUNT(*) FROM `Tag`
UNION ALL SELECT 'MediaDeletionTask(保留)', COUNT(*) FROM `MediaDeletionTask`;
