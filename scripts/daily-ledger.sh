#!/bin/bash
# 有据 · 运营台账自动追加
# 把作战方案 §10 台账从「手填」变成「每天一条命令长一行」。
# 口径：本表是可自证的 **DB 下界**（登录用户行为 + 冷启 token 更新），
#       达标判定看「鸿蒙激励计划2026 上架应用数据查询界面」，趋势看 AGC 报表。
# 用法：./scripts/daily-ledger.sh [YYYY-MM]     默认本月
set -euo pipefail
HOST="${YOUJU_PROD_HOST:-ubuntu@114.132.102.189}"
YM="${1:-$(date +%Y-%m)}"
MONTH_START="${YM}-01"
HERE="$(cd "$(dirname "$0")" && pwd)"
LEDGER=$(cd "$HERE/../deliverables/product-strategy" && pwd)/mau-ledger.md
TODAY="$(date +%Y-%m-%d)"

SQL="
SET @s = DATE('${MONTH_START}');
SET @e = DATE_ADD(@s, INTERVAL 1 MONTH);
SELECT 'evt_users', COUNT(DISTINCT pe.userId) FROM PostEvent pe JOIN User u ON u.id = pe.userId
  WHERE pe.createdAt >= @s AND pe.createdAt < @e AND LEFT(COALESCE(u.openId,u.unionID),4) <> 'seed';
SELECT 'dev_starts', COUNT(DISTINCT pt.userId) FROM PushToken pt JOIN User u ON u.id = pt.userId
  WHERE pt.updatedAt >= @s AND pt.updatedAt < @e AND LEFT(COALESCE(u.openId,u.unionID),4) <> 'seed';
SELECT 'new_users', COUNT(*) FROM User WHERE createdAt >= @s AND createdAt < @e
  AND LEFT(COALESCE(openId,unionID),4) <> 'seed';
SELECT 'real_posts', COUNT(*) FROM Post WHERE deletedAt IS NULL AND status = 1
  AND userId NOT IN (SELECT id FROM User WHERE LEFT(COALESCE(openId,unionID),4)='seed');
SELECT 'seed_posts', COUNT(*) FROM Post WHERE deletedAt IS NULL AND status = 1
  AND userId IN (SELECT id FROM User WHERE LEFT(COALESCE(openId,unionID),4)='seed');
SELECT 'dm_sent', COUNT(*) FROM Message WHERE createdAt >= @s AND createdAt < @e;
"

OUT=$(echo "$SQL" | ssh -o ConnectTimeout=25 "$HOST" \
  'docker exec -i youju-mysql sh -c "mysql -N -B -f --default-character-set=utf8mb4 -uroot -p\"\$MYSQL_ROOT_PASSWORD\" youju"' 2>/dev/null \
  | grep -v "Using a password" || true)

get() { echo "$OUT" | awk -v k="$1" '$1==k {print $2; found=1} END {if(!found) print "-"}'; }
EVT=$(get evt_users); DEV=$(get dev_starts); NEW=$(get new_users)
RP=$(get real_posts); SP=$(get seed_posts); DM=$(get dm_sent)
SRC=$(ssh -o ConnectTimeout=20 "$HOST" 'bash -s' <<'EOS'
docker logs --since 24h youju-nginx 2>&1 | grep -cE '"GET /?\?[^"]*src=' || true
EOS
)
HEADER='| 日期 | 行为月活(下界) | 冷启设备(代理) | 当月新注册 | 真实帖 / 种子帖 | 当月私信 | 24h 渠道点击 |'
SEP='| --- | ---: | ---: | ---: | --- | ---: | ---: |'
ROW="| $TODAY | $EVT | $DEV | $NEW | $RP / $SP | $DM | $SRC |"

if [ ! -f "$LEDGER" ]; then
  {
    echo "# 有据 · 月活台账（脚本自动追加）"
    echo
    echo "生成：\`./scripts/daily-ledger.sh [YYYY-MM]\`。目标：**有效月活 ≥ 400**（HarmonyOS 5.0+ 去重活跃设备，任一自然月，考核窗口至 2027-01-31）。"
    echo
    echo "本表是可自证的**下界**；达标判定以激励计划后台为准，趋势与渠道复盘另见 \`scripts/agc-active-devices.mjs\`（AGC 官方活跃设备数）与 \`scripts/src-report.sh\`（渠道点击)。"
    echo
    echo "$HEADER"
    echo "$SEP"
  } > "$LEDGER"
fi
grep -q '^| 日期 |' "$LEDGER" || { printf '\n%s\n%s\n' "$HEADER" "$SEP" >> "$LEDGER"; }
printf '%s\n' "$ROW" >> "$LEDGER"
echo "已追加到 $LEDGER"
printf '%s\n' "$ROW"
