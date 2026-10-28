-- ============================================================
-- 「有据」内容归队 SQL 包（作战方案 §6 处置 1+3）
-- 状态：**未执行**。这是给开发者在生产库自己跑的脚本。
-- 目的：把 45 个 seed_coldstart 假账号的 331 篇第一人称「亲历」帖，
--       归队成一个明写身份的官方账号「有据编辑部」，并给正文加示例声明。
--       把「假 UGC」变成「官方 PGC」，同时消除虚构口碑的信任与合规风险。
-- 为什么归到 id=40：该账号已是全站最活跃号（6 帖 / 5 评 / 37 通知 / 10 条私信），
--       且**发布新内容只能发生在能登录的账号上**——seed 账号没有可用的登录通路
--       （release 构建已隐藏测试登录桩），新建官方账号同样登不进去。
--       代价：本人的「抹茶味的琴」身份与官方身份合一（单人 App 常见做法）。
-- ============================================================

-- ---------- 第 0 步：备份（先跑这句，出事能逐行还原） ----------
CREATE TABLE IF NOT EXISTS RelabelBackup202610 AS
SELECT p.id AS postId, p.userId AS oldUserId, p.hotScore AS oldHotScore,
       p.content AS oldContent, p.title AS oldTitle,
       u.nickname AS oldNickname, u.bio AS oldBio
FROM Post p JOIN User u ON u.id = p.userId
WHERE 1 = 0;   -- 占位建表，真正的备份在下一步用 INSERT 写入

-- ---------- 第 1 步：预览影响面（只读，先看数字再决定跑不跑） ----------
-- 1a. 会被改名的账号（应只有 1 行）
SELECT id, nickname, bio FROM User WHERE id = 40;

-- 1b. 会被归队的帖子数（预期 331）与被删除归属的假账号数（预期 45）
SELECT COUNT(*) AS posts_to_rehome
FROM Post WHERE deletedAt IS NULL
  AND userId IN (SELECT id FROM User WHERE LEFT(COALESCE(openId, unionID), 4) = 'seed');

SELECT COUNT(*) AS seed_accounts FROM User
WHERE LEFT(COALESCE(openId, unionID), 4) = 'seed';

-- 1c. 归队后官方账号的帖子总量（预期 337 = 331 + 现有 6）
SELECT COUNT(*) AS official_posts_after
FROM Post WHERE deletedAt IS NULL
  AND (userId = 40 OR userId IN (SELECT id FROM User WHERE LEFT(COALESCE(openId,unionID),4)='seed'));

-- 1d. 降权影响：这些帖的当前 hotScore 分布（首屏前 20 条全在这里）
SELECT ROUND(MIN(hotScore),1) AS min_hot, ROUND(MAX(hotScore),1) AS max_hot,
       ROUND(AVG(hotScore),1) AS avg_hot, COUNT(*) AS n
FROM Post WHERE deletedAt IS NULL AND status = 1
  AND userId IN (SELECT id FROM User WHERE LEFT(COALESCE(openId,unionID),4)='seed');

-- ---------- 第 2 步：真正执行（逐条跑，每条跑完看行数对不对） ----------
START TRANSACTION;

-- 2.1 备份要动的行（用于回滚；表名带日期，重复跑不覆盖）
INSERT INTO RelabelBackup202610
SELECT p.id, p.userId, p.hotScore, p.content, p.title, u.nickname, u.bio
FROM Post p JOIN User u ON u.id = p.userId
WHERE p.deletedAt IS NULL
  AND (p.userId = 40 OR p.userId IN (SELECT id FROM User WHERE LEFT(COALESCE(openId,unionID),4)='seed'));

-- 2.2 给示例帖正文加声明（幂等：已有声明的跳过）
-- ⚠️ 两个契约，改任何一条都要同步另一条：
--   ① 幂等判断必须匹配**实际写入的形态**（带 markdown 引用符号 '> '）。
--      原先写的是 NOT LIKE '示例内容 · 编辑部整理%'，永远匹配不上已加过声明的行，
--      重跑本脚本会把声明**重复追加**一遍（自查时发现并修正）。
--   ② 这个标记串同时被 backend/src/services/dailyDigestService.ts 的 EXEMPLAR_MARKER 依赖，
--      每日一帖推送靠它把示例内容排除在外；改字面量会让推送又开始推伪造亲历。
UPDATE Post SET content = CONCAT(
  '> 示例内容 · 编辑部整理。非当事人亲历，观点与数据均来自公开资料，可在评论区追问出处。\n\n',
  COALESCE(content, ''))
WHERE deletedAt IS NULL
  AND userId IN (SELECT id FROM User WHERE LEFT(COALESCE(openId,unionID),4) = 'seed')
  AND (content IS NULL OR content NOT LIKE '%示例内容 · 编辑部整理%');

-- 2.3 热榜降权 0.5（用 2.2 的标记判定，避免误伤以后编辑部的真内容）
--     ⚠️ 注意：这一步不足以让真实帖上位——见第 3 节「坏消息」。
UPDATE Post SET hotScore = hotScore * 0.5
WHERE deletedAt IS NULL AND content LIKE '> 示例内容 · 编辑部整理%';

-- 2.4 归队到官方账号
UPDATE Post SET userId = 40
WHERE deletedAt IS NULL
  AND userId IN (SELECT id FROM User WHERE LEFT(COALESCE(openId,unionID),4) = 'seed');

-- 2.5 账号身份改造
UPDATE User SET nickname = '有据编辑部',
  bio = '官方内容 · 编辑部整理，每条都给出处。这里不发广告、不装亲历。'
WHERE id = 40;

COMMIT;

-- 之后 45 个 seed 账号可以软注销（保留行、不再出现在任何列表）：
-- UPDATE User SET deletedAt = NOW() WHERE LEFT(COALESCE(openId,unionID),4) = 'seed';
-- （先别跑：帖子已归队，但历史通知的 actorId 指向它们，注销后昵称/头像补全会失败。要动就一起验消息中心。）

-- ---------- 第 3 步：回滚（只在需要时用） ----------
-- UPDATE Post p JOIN RelabelBackup202610 b ON b.postId = p.id
--   SET p.userId = b.oldUserId, p.hotScore = b.oldHotScore, p.content = b.oldContent;
-- UPDATE User SET nickname='抹茶味的琴', bio=NULL WHERE id = 40;  -- 按 2.1 备份里的 oldBio 原值填
-- 或者整表还原：mysqldump 兜底
--   docker exec youju-mysql sh -c 'mysqldump -uroot -p"$MYSQL_ROOT_PASSWORD" youju Post User > ~/backup-$(date +%F).sql'

-- ============================================================
-- 坏消息（执行前必须知道）：降权救不了真实内容的曝光
-- ============================================================
-- 真实帖 19 篇的 hotScore **全部为 0**（没有互动就没有热度），种子帖 hotScore 在 97-140 量级。
-- ×0.5 之后仍是 48-70，真实帖照一条都进不了首屏。
-- 所以 §6 处置 4（推荐流真实内容保底配额）才是唯一有效的解，且它改的是后端排序逻辑
--   backend/src/services/postService.ts:80  orderBy: [{hotScore:'desc'},{createdAt:'desc'}]
--   backend/src/services/dailyScoreService.ts:247  每日一帖打分同样吃 hotScore
-- 后端部署 = git pull + docker compose up -d --build backend，**不需要客户端发版、不需要 AGC 审核**。
-- 建议顺序：先做机制配额（本文件之外的代码改动，需你认可设计意图），再跑本 SQL 包。
