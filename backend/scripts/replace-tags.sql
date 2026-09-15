-- ============================================================================
-- 有据 · 全量替换圈子标签（新分类/新类目）· replace-tags.sql
-- ============================================================================
-- !! 先备份 !!  执行前提：Post 与 UserFollowTag 为空（本任务已清空用户数据），
-- 否则帖子的 tags 字符串数组和用户关注记录会指向已删除的标签名。
--
-- 服务器执行：
--   curl -fsSL -o /tmp/replace-tags.sql "https://cdn.jsdelivr.net/gh/2697881905/youju@main/backend/scripts/replace-tags.sql"
--   sudo docker cp /tmp/replace-tags.sql youju-mysql:/tmp/replace-tags.sql
--   sudo docker exec youju-mysql sh -c 'exec mysql -uroot -p$MYSQL_ROOT_PASSWORD youju < /tmp/replace-tags.sql'
-- ============================================================================

DELETE FROM `UserFollowTag`;
DELETE FROM `Tag`;

INSERT INTO `Tag` (`name`, `emoji`, `category`) VALUES
('手机数码', '📱', '消费选购'),
('家电选购', '🧊', '消费选购'),
('二手闲置', '♻️', '消费选购'),
('运动装备', '👟', '消费选购'),
('消费维权', '🧾', '消费选购'),
('装修避坑', '🛠️', '动手改造'),
('家常菜谱', '🍳', '动手改造'),
('电脑装机', '🖥️', '动手改造'),
('用车经验', '🚗', '动手改造'),
('求职面试', '📄', '职场与收入'),
('职场成长', '💼', '职场与收入'),
('记账储蓄', '🧮', '职场与收入'),
('副业探索', '💰', '职场与收入'),
('恋爱心得', '❤️', '生活与家庭'),
('婚姻与家庭', '💍', '生活与家庭'),
('育儿经验', '🍼', '生活与家庭'),
('养猫养狗', '🐱', '生活与家庭'),
('健康习惯', '💪', '生活与家庭'),
('租房买房', '🏠', '生活与家庭'),
('音乐分享', '🎵', '兴趣休闲'),
('影视剧集', '🎬', '兴趣休闲'),
('旅行出行', '🧳', '兴趣休闲'),
('美食探店', '🍜', '兴趣休闲');

SELECT category, COUNT(*) AS cnt FROM `Tag` GROUP BY category;
SELECT COUNT(*) AS total FROM `Tag`;
