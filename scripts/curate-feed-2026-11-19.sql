-- 有据 · 首屏推荐流治理（2026-11-19）
-- 目的：把 26 条正文 <120 字的碎帖中的 21 条移出推荐流，让首屏不再是「早/测试/哈哈」。
-- 原则：只改 status（1 已发布 → 2 已拒绝/下架），不删数据、不动作者、不动计数；全表可回滚。
-- 依据：11-19 生产库实测清单（见 deliverables/product-strategy/growth-diagnosis-2026-11-19.md §1.2）
-- 执行前必须：1) 建备份表  2) 看预览读数  3) 确认 deleted=0 / status=1  4) 再 UPDATE
-- ⚠️ 生产库写操作，需开发者本人授权后执行。

-- ========== 1. 备份（建一次，重复执行会报错停下，这是防覆盖保护） ==========
CREATE TABLE CurateBackup20261119 (
  postId INT PRIMARY KEY,
  oldStatus INT,
  oldDeletedAt DATETIME NULL,
  title VARCHAR(255) NULL,
  contentLen INT
);
INSERT INTO CurateBackup20261119
SELECT id, status, deletedAt, title, CHAR_LENGTH(COALESCE(content,''))
FROM Post WHERE id IN (422,421,418,417,415,414,413,412,411,410,409,408,71,64,62,47,41,32,31,28,27);

-- ========== 2. 预览：应为 21 行，status 全为 1，deletedAt 全为 NULL ==========
SELECT COUNT(*) AS will_hide, SUM(status=1) AS published, SUM(deletedAt IS NULL) AS alive
FROM Post WHERE id IN (422,421,418,417,415,414,413,412,411,410,409,408,71,64,62,47,41,32,31,28,27);

-- ========== 3. 执行下架（21 条：编辑部自测帖 + 明显测试/无意义帖） ==========
START TRANSACTION;
UPDATE Post SET status = 2
WHERE id IN (422,421,418,417,415,414,413,412,411,410,409,408,71,64,62,47,41,32,31,28,27)
  AND deletedAt IS NULL AND status = 1;
COMMIT;

-- ========== 4. 验收：推荐流前 20 条应无碎帖 ==========
SELECT p.id, LEFT(COALESCE(p.title,''),18) AS title, IF(p.content LIKE '> 示例内容%','示例','真实') AS kind,
       ROUND(p.hotScore,1) AS hot
FROM Post p
WHERE p.deletedAt IS NULL AND p.status = 1
ORDER BY p.hotScore DESC, p.createdAt DESC LIMIT 20;

-- ========== 5. 回滚（只在需要时执行） ==========
-- UPDATE Post p JOIN CurateBackup20261119 b ON p.id = b.postId
--   SET p.status = b.oldStatus, p.deletedAt = b.oldDeletedAt;

-- 说明：
-- 1) 未纳入本次的 5 条内容（id 72/70/69/65 为同一作者的日期日记、73 为「猫🐱」）保留不动：
--    它们是真实用户发的，下架会打击作者；其正文长度 32–105，靠 createdAt 排序自然沉底。
-- 2) 不要用 DELETE，也不要改 deletedAt：status=2 在推荐流/热榜被 where 过滤，作者自己仍可见，风险最小。
-- 3) 执行后不要立刻 docker restart youju-backend（会触发全量 recompute 刷掉 hotScore），
--    本次不改 hotScore，重启无收益。