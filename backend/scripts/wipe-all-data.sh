#!/usr/bin/env bash
# ============================================================================
# 有据 · 清空全部用户数据（上架前彻底重置）· wipe-all-data.sh
# ============================================================================
# 在服务器上执行（需 sudo docker 权限）：
#   cd ~/youju && bash scripts/wipe-all-data.sh          # 交互确认（推荐）
#   cd ~/youju && bash scripts/wipe-all-data.sh --yes    # 跳过确认（CI/脚本用）
#
# 流程：
#   1) 自动备份数据库（backup.sh，保留最近 7 天）
#   2) stdin 非 tty 且未加 --yes 时拒绝执行（防误触）
#   3) docker cp SQL 进 mysql 容器 → 容器内执行
#   4) 输出各表校验计数（用户数据期望全 0；Tag 应保持原数量）
#
# 删除范围：User + Post/Comment/CommentUp/Up/Bookmark/BookmarkFolder +
#          UserFollowTag/SearchHistory/UserBinding/Notification/
#          NotificationPreference/PushToken/PushLog/Follow/Report/Blocklist/
#          Dislike/PrivacySettings/DebateVote/Message/MessageDeletion/PostEvent
# ★ 保留：Tag（标签/圈子基座）、MediaDeletionTask（COS 待删媒体队列）
#
# ⚠️ 执行后必做：所有账号已删，新用户 id 会变化。管理员身份由环境变量
#    ADMIN_USER_IDS 决定 —— 用新账号登录一次、查出其 userId，更新
#    .env.production 的 ADMIN_USER_IDS=<新id> 后重启后端，否则内容审核台不可用。
#
# !! 不可逆 !! 失败可回滚到 backup.sh 生成的快照。
# ============================================================================
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MYSQL_CONTAINER="youju-mysql"
MYSQL_DB="youju"
BACKUP_SCRIPT="$PROJECT_DIR/backup.sh"
SQL_FILE="$PROJECT_DIR/scripts/wipe-all-data.sql"

CONFIRMED=0
if [[ "${1:-}" == "--yes" ]]; then
  CONFIRMED=1
elif [[ -t 0 ]]; then
  echo "⚠️  即将清空 $MYSQL_DB 库的【全部用户数据】（账号 + 帖子 + 通知 + 私信 + 互动，不可逆！）"
  echo "    保留：标签/圈子基座（Tag）、COS 待删媒体队列（MediaDeletionTask）"
  read -r -p "确认请输入 yes： " ans
  [[ "$ans" == "yes" ]] && CONFIRMED=1
fi
if [[ $CONFIRMED -ne 1 ]]; then
  echo "✋ 已取消（未确认）。需要跳过确认请加 --yes。"
  exit 1
fi

if [[ -x "$BACKUP_SCRIPT" ]]; then
  echo "==> [1/3] 备份数据库"
  bash "$BACKUP_SCRIPT"
else
  echo "⚠️  未找到 $BACKUP_SCRIPT，跳过备份（请自行确认已备份！）"
fi

if [[ ! -f "$SQL_FILE" ]]; then
  echo "❌ 找不到 $SQL_FILE"
  exit 1
fi

echo "==> [2/3] 上传 SQL 并在容器内执行"
tmp_sql="/tmp/wipe-all-data.sql"
sudo docker cp "$SQL_FILE" "$MYSQL_CONTAINER:$tmp_sql"
sudo docker exec "$MYSQL_CONTAINER" sh -c "exec mysql -uroot -p\$MYSQL_ROOT_PASSWORD $MYSQL_DB < $tmp_sql"
sudo docker exec "$MYSQL_CONTAINER" sh -c "rm -f $tmp_sql"

echo "==> [3/3] 校验计数（用户数据期望 0，Tag 应保持原数量）"
sudo docker exec "$MYSQL_CONTAINER" sh -c "exec mysql -uroot -p\$MYSQL_ROOT_PASSWORD -N -e \
  \"SELECT 'User',COUNT(*) FROM \`User\` UNION ALL
   SELECT 'Post',COUNT(*) FROM \`Post\` UNION ALL
   SELECT 'Comment',COUNT(*) FROM \`Comment\` UNION ALL
   SELECT 'Notification',COUNT(*) FROM \`Notification\` UNION ALL
   SELECT 'Message',COUNT(*) FROM \`Message\` UNION ALL
   SELECT 'Follow',COUNT(*) FROM \`Follow\` UNION ALL
   SELECT 'Tag(保留)',COUNT(*) FROM \`Tag\`;\"" 

echo ""
echo "✅ 完成。若上方用户数据全为 0、Tag 数量不变，则清空成功。"
echo "⚠️  下一步（必做）：用新账号登录一次，查出其 userId，更新 .env.production 的"
echo "    ADMIN_USER_IDS=<新id> 并重启后端，否则内容审核台不可用。"
