-- 运营漏斗取数（只读）：设备 → 注册 → 可推送 → 仍开启 → 30天内活跃 → 产出内容
-- 1. 注册池
SELECT COUNT(*) AS registered_alive
FROM User WHERE deletedAt IS NULL AND status = 1
  AND LEFT(COALESCE(openId, unionID), 4) <> 'seed';

-- 2. 其中有过 PushToken 的（含历史 token）
SELECT COUNT(DISTINCT pt.userId) AS ever_token
FROM PushToken pt JOIN User u ON u.id = pt.userId
WHERE u.deletedAt IS NULL AND u.status = 1
  AND LEFT(COALESCE(u.openId, u.unionID), 4) <> 'seed';

-- 3. token 近 30 天还更新过的（设备大概率仍在装）
SELECT COUNT(DISTINCT pt.userId) AS fresh_token_30d
FROM PushToken pt JOIN User u ON u.id = pt.userId
WHERE u.deletedAt IS NULL AND u.status = 1
  AND pt.updatedAt >= DATE_SUB(CURDATE(), INTERVAL 30 DAY)
  AND LEFT(COALESCE(u.openId, u.unionID), 4) <> 'seed';

-- 4. 明确关掉系统/关注类通知的
SELECT COUNT(DISTINCT t.userId) AS pref_off FROM (
  SELECT pt.userId FROM PushToken pt JOIN User u ON u.id = pt.userId
  WHERE u.deletedAt IS NULL AND LEFT(COALESCE(u.openId,u.unionID),4) <> 'seed'
  GROUP BY pt.userId
) t JOIN NotificationPreference np ON np.userId = t.userId
WHERE np.system = 0 OR np.follow = 0 OR np.comment = 0 OR np.up = 0 OR np.bookmark = 0;

-- 5. 30 天内有过任意行为的注册用户（PostEvent 口径）
SELECT COUNT(DISTINCT pe.userId) AS act30_evt
FROM PostEvent pe JOIN User u ON u.id = pe.userId
WHERE pe.createdAt >= DATE_SUB(CURDATE(), INTERVAL 30 DAY)
  AND LEFT(COALESCE(u.openId,u.unionID),4) <> 'seed';

-- 6. 产出过已发布内容的注册用户
SELECT COUNT(DISTINCT p.userId) AS authors_published
FROM Post p JOIN User u ON u.id = p.userId
WHERE p.deletedAt IS NULL AND p.status = 1
  AND LEFT(COALESCE(u.openId,u.unionID),4) <> 'seed';

-- 7. 评论过的人
SELECT COUNT(DISTINCT c.userId) AS commenters
FROM Comment c JOIN User u ON u.id = c.userId
WHERE LEFT(COALESCE(u.openId,u.unionID),4) <> 'seed';

-- 8. 注册当天之后再也没有任何行为的人（一次性注册）
SELECT COUNT(*) AS registered_but_silent FROM User u
WHERE u.deletedAt IS NULL AND LEFT(COALESCE(u.openId,u.unionID),4) <> 'seed'
  AND NOT EXISTS (SELECT 1 FROM PostEvent pe WHERE pe.userId = u.id)
  AND NOT EXISTS (SELECT 1 FROM Post p WHERE p.userId = u.id)
  AND NOT EXISTS (SELECT 1 FROM Comment c WHERE c.userId = u.id)
  AND NOT EXISTS (SELECT 1 FROM Up up2 WHERE up2.userId = u.id);
