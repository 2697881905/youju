#!/usr/bin/env bash
# ============================================================================
# 有据 · 清空所有帖子（全量连坐删除）· wipe-posts.sh
# ============================================================================
# 在服务器上执行（需 sudo docker 权限）：
#   bash wipe-posts.sh            # 交互确认
#   bash wipe-posts.sh --yes      # 跳过确认（脚本/CI 用）
#
# 流程：
#   1) 自动备份数据库（backup.sh，保留最近 7 天）
#   2) stdin 不可 tty 且未加 --yes 时拒绝执行（防误触）
#   3) docker cp SQL 进 mysql 容器 → 容器内执行
#   4) 输出各表校验计数（期望全 0）
#
# 删除范围：Post + 级联(Comment/Up/Bookmark) + CommentUp + PostEvent
#          + DebateVote + Notification(postId 非空) + 登记 COS 媒体删除任务
# 不影响用户/标签/圈子/私信/收藏夹/举报记录等。
# !! 不可逆 !! 失败可回滚到 backup.sh 生成的快照。
# ============================================================================
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MYSQL_CONTAINER="youju-mysql"
MYSQL_DB="youju"
BACKUP_SCRIPT="$PROJECT_DIR/backup.sh"
SQL_FILE="$PROJECT_DIR/scripts/wipe-posts.sql"

# ---------------------------------------------------------------------------
# 确认防护：交互终端必须显式输入 yes；非 tty（管道/CI）必须 --yes
# ---------------------------------------------------------------------------
CONFIRMED=0
if [[ "${1:-}" == "--yes" ]]; then
  CONFIRMED=1
elif [[ -t 0 ]]; then
  echo "⚠️  即将清空 $MYSQL_DB 库所有帖子及关联数据（不可逆！）"
  read -r -p "确认请输入 yes： " ans
  [[ "$ans" == "yes" ]] && CONFIRMED=1
fi
if [[ $CONFIRMED -ne 1 ]]; then
  echo "✋ 已取消（未确认）。需要跳过确认请加 --yes。"
  exit 1
fi

# ---------------------------------------------------------------------------
# 1) 备份
# ---------------------------------------------------------------------------
if [[ -x "$BACKUP_SCRIPT" ]]; then
  echo "==> [1/3] 备份数据库"
  bash "$BACKUP_SCRIPT"
else
  echo "⚠️  未找到 $BACKUP_SCRIPT，跳过备份（请自行确认已备份！）"
fi

# ---------------------------------------------------------------------------
# 2) 校验 SQL 存在
# ---------------------------------------------------------------------------
if [[ ! -f "$SQL_FILE" ]]; then
  echo "❌ 找不到 $SQL_FILE"
  exit 1
fi

# ---------------------------------------------------------------------------
# 3) 执行清空
# ---------------------------------------------------------------------------
echo "==> [2/3] 上传 SQL 并执行"
tmp_sql="/tmp/wipe-posts.sql"
sudo docker cp "$SQL_FILE" "$MYSQL_CONTAINER:$tmp_sql"
sudo docker exec "$MYSQL_CONTAINER" sh -c "exec mysql -uroot -p\$MYSQL_ROOT_PASSWORD $MYSQL_DB < $tmp_sql"
sudo docker exec "$MYSQL_CONTAINER" sh -c "rm -f $tmp_sql"

# ---------------------------------------------------------------------------
# 4) 校验
# ---------------------------------------------------------------------------
echo "==> [3/3] 校验计数（期望全为 0）"
sudo docker exec "$MYSQL_CONTAINER" sh -c "exec mysql -uroot -p\$MYSQL_ROOT_PASSWORD -N -e \
  \"SELECT 'Post' tbl,COUNT(*) n FROM Post UNION ALL
   SELECT 'Comment',COUNT(*) FROM Comment UNION ALL
   SELECT 'Up',COUNT(*) FROM Up UNION ALL
   SELECT 'Bookmark',COUNT(*) FROM Bookmark UNION ALL
   SELECT 'CommentUp',COUNT(*) FROM CommentUp UNION ALL
   SELECT 'PostEvent',COUNT(*) FROM PostEvent UNION ALL
   SELECT 'DebateVote',COUNT(*) FROM DebateVote UNION ALL
   SELECT 'Notification(postId)',COUNT(*) FROM Notification WHERE postId IS NOT NULL;\"" 

echo "✅ 完成。若上方全为 0 则清空成功。"