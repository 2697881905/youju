#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
DEPLOY_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
COMPOSE_FILE="$DEPLOY_DIR/docker-compose.production.yml"
ENV_FILE="$DEPLOY_DIR/.env.production"
BACKUP_DIR="${BACKUP_DIR:-$DEPLOY_DIR/backups}"

if [ ! -f "$ENV_FILE" ]; then
  echo "Missing $ENV_FILE" >&2
  exit 1
fi

set -a
. "$ENV_FILE"
set +a
mkdir -p "$BACKUP_DIR"

STAMP="$(date +%Y%m%d-%H%M%S)"
OUTPUT="$BACKUP_DIR/bigbluebook-$STAMP.sql.gz"
docker compose --env-file "$ENV_FILE" -f "$COMPOSE_FILE" exec -T mysql \
  mysqldump -uroot -p"$MYSQL_ROOT_PASSWORD" --single-transaction --routines --events "$MYSQL_DATABASE" \
  | gzip > "$OUTPUT"

# Keep the most recent 14 days of local backups. Copy backups off-server as well.
find "$BACKUP_DIR" -type f -name 'bigbluebook-*.sql.gz' -mtime +14 -delete
echo "Backup created: $OUTPUT"
