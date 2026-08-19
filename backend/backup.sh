#!/bin/bash
# 有据 MySQL 每日备份脚本（保留最近 7 天）
# 由 crontab 每日调用：30 3 * * * /home/ubuntu/youju/backup.sh
BACKUP_DIR=/home/ubuntu/youju/backups
mkdir -p "$BACKUP_DIR"
STAMP=$(date +%F)
# 容器内 mysqldump，root 密码取容器环境变量；失败则退出并记录日志
sudo docker exec youju-mysql sh -c 'exec mysqldump -uroot -p"$MYSQL_ROOT_PASSWORD" youju' > "$BACKUP_DIR/youju_$STAMP.sql"
if [ $? -ne 0 ]; then
  echo "$(date '+%F %T') mysqldump FAILED" >> "$BACKUP_DIR/backup.log"
  exit 1
fi
gzip -f "$BACKUP_DIR/youju_$STAMP.sql"
# 清理 7 天前的备份
find "$BACKUP_DIR" -name 'youju_*.sql.gz' -mtime +7 -delete
echo "$(date '+%F %T') backup ok: youju_$STAMP.sql.gz ($(du -h "$BACKUP_DIR/youju_$STAMP.sql.gz" | cut -f1))" >> "$BACKUP_DIR/backup.log"
