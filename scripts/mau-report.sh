#!/bin/bash
# 有据 · 运营日报（月活/新增/内容水位）
# 口径说明：App 端没有设备级启动埋点，华为激励计划的「有效月活 = 去重活跃设备」真值只能在
# 激励计划后台或 AGC 报表看。本脚本给出的是**可自证的下界代理**：
#   - evt_users  : 当月有 PostEvent（刷信息流/点开帖子等行为）的去重真实用户 —— 只登录用户可计
#   - device_dau : 当月 PushToken.updatedAt 变动过的去重用户 —— 冷启动会重注册 token，最接近设备启动
#   - real_*     : 已排除 45 个 seed_coldstart 种子假账号
# 用法：./scripts/mau-report.sh [YYYY-MM]   默认本月
set -euo pipefail
HOST="${YOUJU_PROD_HOST:-ubuntu@114.132.102.189}"
YM="${1:-$(date +%Y-%m)}"
MONTH_START="${YM}-01"

SQL=$(cat <<EOF
SET @s = DATE('${MONTH_START}');
SET @e = DATE_ADD(@s, INTERVAL 1 MONTH);

-- 1. 行为月活（登录用户，排除种子号）
SELECT '1_evt_users_month' AS metric, COUNT(DISTINCT pe.userId) AS v
FROM PostEvent pe JOIN User u ON u.id = pe.userId
WHERE pe.createdAt >= @s AND pe.createdAt < @e
  AND LEFT(COALESCE(u.openId, u.unionID), 4) <> 'seed';

-- 2. 冷启设备代理（PushToken 当月更新过）
SELECT '2_device_start_users' AS metric, COUNT(DISTINCT pt.userId) AS v
FROM PushToken pt JOIN User u ON u.id = pt.userId
WHERE pt.updatedAt >= @s AND pt.updatedAt < @e
  AND LEFT(COALESCE(u.openId, u.unionID), 4) <> 'seed';

-- 3. 当月新注册（真实 / 种子）
SELECT '3_new_users' AS metric,
       SUM(LEFT(COALESCE(openId, unionID),4) <> 'seed') AS real_new,
       SUM(LEFT(COALESCE(openId, unionID),4) = 'seed') AS seed_new, COUNT(*) AS total
FROM User WHERE createdAt >= @s AND createdAt < @e;

-- 4. 存活账号总量 / 真实账号总量
SELECT '4_stock' AS metric,
       SUM(deletedAt IS NULL AND LEFT(COALESCE(openId, unionID),4) <> 'seed') AS real_alive,
       SUM(deletedAt IS NULL) AS all_alive, COUNT(*) AS all_created
FROM User;

-- 5. 内容水位（真实作者 vs 种子）
SELECT '5_posts' AS metric,
       SUM(userId NOT IN (SELECT id FROM User WHERE LEFT(COALESCE(openId,unionID),4)='seed')) AS real_posts,
       SUM(userId IN (SELECT id FROM User WHERE LEFT(COALESCE(openId,unionID),4)='seed')) AS seed_posts,
       COUNT(*) AS total
FROM Post WHERE deletedAt IS NULL AND status = 1;

-- 6. 近 30 天逐日活跃设备（启动代理，排除种子）
SELECT DATE_FORMAT(pt.updatedAt,'%m-%d') AS d, COUNT(DISTINCT pt.userId) AS starts
FROM PushToken pt JOIN User u ON u.id = pt.userId
WHERE pt.updatedAt >= DATE_SUB(CURDATE(), INTERVAL 30 DAY)
  AND LEFT(COALESCE(u.openId,u.unionID),4) <> 'seed'
GROUP BY d ORDER BY d;

-- 7. 近 30 天逐日行为活跃
SELECT DATE_FORMAT(createdAt,'%m-%d') AS d, COUNT(DISTINCT userId) AS act
FROM PostEvent
WHERE createdAt >= DATE_SUB(CURDATE(), INTERVAL 30 DAY) AND userId IS NOT NULL
GROUP BY d ORDER BY d;

-- 8. 召回名册 Top 20：已装机且最后一次冷启动最近的真实用户（私信与评分引导按此排序）
SELECT u.id, u.nickname,
       (SELECT COUNT(*) FROM Post p WHERE p.userId = u.id AND p.deletedAt IS NULL) AS posts,
       (SELECT COUNT(*) FROM Comment c WHERE c.userId = u.id) AS cmts,
       (SELECT COUNT(*) FROM Bookmark b WHERE b.userId = u.id) AS marks,
       DATE_FORMAT((SELECT MAX(pt.updatedAt) FROM PushToken pt WHERE pt.userId = u.id), '%m-%d') AS last_start
FROM User u
WHERE u.deletedAt IS NULL AND LEFT(COALESCE(u.openId, u.unionID), 4) <> 'seed'
  AND (SELECT MAX(pt.updatedAt) FROM PushToken pt WHERE pt.userId = u.id) IS NOT NULL
ORDER BY last_start DESC LIMIT 20;
EOF
)

echo "== 有据运营日报 · ${YM}（起算 ${MONTH_START}）=="
echo "$SQL" | ssh -o ConnectTimeout=20 "$HOST" \
  'docker exec -i youju-mysql sh -c "mysql -f --default-character-set=utf8mb4 -uroot -p\"\$MYSQL_ROOT_PASSWORD\" -t youju"' 2>&1 \
  | grep -v "Using a password"
