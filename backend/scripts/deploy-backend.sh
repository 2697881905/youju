#!/usr/bin/env bash
# 有据后端安全部署脚本（在服务器 backend/ 目录下执行）
#
# 为什么不用 docker-compose up：
#   这台机器的容器由 compose v2 创建，而命令行只有 apt 的 v1，v1 认不出它们。
#   `up` 会尝试重建 youju-mysql 并撞名失败；更糟的是失败之前它可能已经把
#   backend 容器删掉了，导致线上 API 中断（2026-09-24 就发生过一次）。
#
# 本脚本直接管理 backend 容器，并保证：
#   新容器健康检查通过之后才删除旧容器 —— 失败自动回滚，旧容器全程不动。
#
# 用法（在 backend/ 目录下）：
#   bash scripts/deploy-backend.sh              # 构建新镜像并滚动替换（日常用这个）
#   bash scripts/deploy-backend.sh --no-build   # 跳过构建，用现有 latest 镜像替换
#
set -euo pipefail

APP_CONTAINER="youju-backend"
TMP_CONTAINER="youju-backend-new"
IMAGE="backend_backend:latest"
DB_CONTAINER="youju-mysql"
# 健康检查最多等待的秒数（可用 DEPLOY_HEALTH_RETRIES 覆盖，便于测试或按机器调整）
HEALTH_RETRIES="${DEPLOY_HEALTH_RETRIES:-60}"

BUILD=1
for arg in "$@"; do
  case "$arg" in
    --no-build) BUILD=0 ;;
    *)
      echo "未知参数：$arg（仅支持 --no-build）" >&2
      exit 2
      ;;
  esac
done

cd "$(dirname "$0")/.."
echo "== 有据后端部署 =="
echo "工作目录：$(pwd)"

if [ ! -f .env ]; then
  echo "错误：当前目录没有 .env，请确认在 backend/ 下执行" >&2
  exit 1
fi

# --- 取网络名：优先从数据库容器（始终在线），退化到旧 backend 容器 ---
NET=""
for c in "$DB_CONTAINER" "$APP_CONTAINER"; do
  if docker inspect "$c" >/dev/null 2>&1; then
    NET=$(docker inspect "$c" --format '{{range $k, $v := .NetworkSettings.Networks}}{{$k}}{{end}}')
    if [ -n "$NET" ]; then
      break
    fi
  fi
done
if [ -z "$NET" ]; then
  echo "错误：既找不到 $DB_CONTAINER 也找不到 $APP_CONTAINER，无法确定容器网络" >&2
  exit 1
fi
echo "容器网络：$NET"

# --- 构建镜像（docker-compose build 只编译镜像、不创建/删除任何容器，安全） ---
if [ "$BUILD" = 1 ]; then
  echo "构建镜像：docker-compose -f docker-compose.prod.yml build backend"
  docker-compose -f docker-compose.prod.yml build backend
else
  echo "跳过构建（--no-build）"
fi

# --- 清理可能残留的临时容器 ---
docker rm -f "$TMP_CONTAINER" >/dev/null 2>&1 || true

# --- 起新容器（临时名）。旧容器继续对外服务，此时两个容器同时在网内 ---
echo "启动新容器：$TMP_CONTAINER"
docker run -d --name "$TMP_CONTAINER" \
  --restart unless-stopped \
  --network "$NET" \
  --memory 1g \
  --env-file .env \
  -e NODE_OPTIONS=--max-old-space-size=512 \
  "$IMAGE" >/dev/null

# --- 健康检查：在容器内部请求 /health ---
echo "健康检查（最多 ${HEALTH_RETRIES} 秒）..."
HEALTHY=0
i=1
while [ "$i" -le "$HEALTH_RETRIES" ]; do
  if docker exec "$TMP_CONTAINER" node -e \
    "fetch('http://127.0.0.1:3000/health').then(r=>process.exit(r.ok?0:1)).catch(()=>process.exit(1))" \
    >/dev/null 2>&1; then
    HEALTHY=1
    echo "健康检查通过（第 ${i} 秒）"
    break
  fi
  if [ "$(docker inspect -f '{{.State.Running}}' "$TMP_CONTAINER" 2>/dev/null || echo false)" != "true" ]; then
    echo "新容器已退出，停止等待"
    break
  fi
  sleep 1
  i=$((i + 1))
done

# --- 失败：打印日志 → 删新容器 → 旧容器原样保留（自动回滚） ---
if [ "$HEALTHY" != 1 ]; then
  echo "" >&2
  echo "✗ 新容器健康检查失败，已回滚（旧容器未受影响）" >&2
  echo "--- 新容器最近 40 行日志 ---" >&2
  docker logs --tail 40 "$TMP_CONTAINER" >&2 || true
  docker rm -f "$TMP_CONTAINER" >/dev/null 2>&1 || true
  exit 1
fi

# --- 成功：删旧容器，把新容器改名为正式名 ---
# 删除到改名之间有一个极短的窗口（毫秒级），期间 nginx 可能收到一两个失败请求，
# 这是单机无负载均衡下无法完全避免的；nginx 自身有重试，实际影响可忽略。
if docker inspect "$APP_CONTAINER" >/dev/null 2>&1; then
  echo "移除旧容器：$APP_CONTAINER"
  docker rm -f "$APP_CONTAINER" >/dev/null
fi
docker rename "$TMP_CONTAINER" "$APP_CONTAINER"

echo ""
echo "✓ 部署完成，$APP_CONTAINER 已运行新镜像："
docker ps --filter "name=^/${APP_CONTAINER}$" --format '   {{.Names}}  {{.Status}}  {{.Image}}'
echo ""
echo "线上验证：curl -s -D- -o /dev/null https://youju.chat/user/40 | grep -i content-security-policy"
