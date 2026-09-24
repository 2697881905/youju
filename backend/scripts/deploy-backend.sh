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
# 还会做一次 schema 对账：新镜像里的 prisma/schema.prisma 与线上库不一致时中止部署。
# 原因：新增一列之后，不带 select 的 findMany 会连新列一起查，库里没这列就报 P2022，
# 相关接口全部 500，而 /health 仍然返回 ok（SELECT 1 不会因为缺列失败）。
# 2026-09-24 就这样把私信页弄挂过一次，同月更早还有 PostEvent.scene 那次。
#
# 注意：脚本里所有变量引用一律写成 ${VAR}。当变量后面紧跟中文或全角标点时，
# 不加大括号会让 bash 把全角字符的首字节并入变量名（`${VAR}（` 会被解析成
# `VAR\xef`），报 unbound variable。这类错误只在特定分支触发，极难在测试前发现。
#
# 用法（在 backend/ 目录下）：
#   bash scripts/deploy-backend.sh              # 构建新镜像并滚动替换（日常用这个）
#   bash scripts/deploy-backend.sh --no-build   # 跳过构建，用现有 latest 镜像替换
#   bash scripts/deploy-backend.sh --allow-drift  # 明知库与 schema 有差异仍要部署
#
set -euo pipefail

APP_CONTAINER="youju-backend"
TMP_CONTAINER="youju-backend-new"
IMAGE="backend_backend:latest"
DB_CONTAINER="youju-mysql"
NGINX_CONTAINER="youju-nginx"
# 健康检查最多等待的秒数（可用 DEPLOY_HEALTH_RETRIES 覆盖，便于测试或按机器调整）
HEALTH_RETRIES="${DEPLOY_HEALTH_RETRIES:-60}"

BUILD=1
ALLOW_DRIFT=0
for arg in "$@"; do
  case "${arg}" in
    --no-build) BUILD=0 ;;
    --allow-drift) ALLOW_DRIFT=1 ;;
    *)
      echo "未知参数：${arg}（仅支持 --no-build / --allow-drift）" >&2
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
for c in "${DB_CONTAINER}" "${APP_CONTAINER}"; do
  if docker inspect "${c}" >/dev/null 2>&1; then
    NET=$(docker inspect "${c}" --format '{{range $k, $v := .NetworkSettings.Networks}}{{$k}}{{end}}')
    if [ -n "${NET}" ]; then
      break
    fi
  fi
done
if [ -z "${NET}" ]; then
  echo "错误：既找不到 ${DB_CONTAINER} 也找不到 ${APP_CONTAINER}，无法确定容器网络" >&2
  exit 1
fi
echo "容器网络：${NET}"

# --- 构建镜像（docker-compose build 只编译镜像、不创建/删除任何容器，安全） ---
if [ "${BUILD}" = 1 ]; then
  echo "构建镜像：docker-compose -f docker-compose.prod.yml build backend"
  docker-compose -f docker-compose.prod.yml build backend
else
  echo "跳过构建（--no-build）"
fi

# --- 清理可能残留的临时容器 ---
docker rm -f "${TMP_CONTAINER}" >/dev/null 2>&1 || true

# --- 起新容器（临时名）。旧容器继续对外服务，此时两个容器同时在网内 ---
echo "启动新容器：${TMP_CONTAINER}"
docker run -d --name "${TMP_CONTAINER}" \
  --restart unless-stopped \
  --network "${NET}" \
  --memory 1g \
  --env-file .env \
  -e NODE_OPTIONS=--max-old-space-size=512 \
  "${IMAGE}" >/dev/null

# --- 健康检查：在容器内部请求 /health ---
echo "健康检查（最多 ${HEALTH_RETRIES} 秒）..."
HEALTHY=0
i=1
while [ "${i}" -le "${HEALTH_RETRIES}" ]; do
  if docker exec "${TMP_CONTAINER}" node -e \
    "fetch('http://127.0.0.1:3000/health').then(r=>process.exit(r.ok?0:1)).catch(()=>process.exit(1))" \
    >/dev/null 2>&1; then
    HEALTHY=1
    echo "健康检查通过（第 ${i} 秒）"
    break
  fi
  if [ "$(docker inspect -f '{{.State.Running}}' "${TMP_CONTAINER}" 2>/dev/null || echo false)" != "true" ]; then
    echo "新容器已退出，停止等待"
    break
  fi
  sleep 1
  i=$((i + 1))
done

# --- 失败：打印日志 → 删新容器 → 旧容器原样保留（自动回滚） ---
if [ "${HEALTHY}" != 1 ]; then
  echo "" >&2
  echo "✗ 新容器健康检查失败，已回滚（旧容器未受影响）" >&2
  echo "--- 新容器最近 40 行日志 ---" >&2
  docker logs --tail 40 "${TMP_CONTAINER}" >&2 || true
  docker rm -f "${TMP_CONTAINER}" >/dev/null 2>&1 || true
  exit 1
fi

# --- schema 对账闸门：新镜像的 prisma schema 必须与线上库一致 ---
# 放在「健康检查通过之后、删旧容器之前」：此时新容器已证明能起来，但线上仍在用旧容器，
# 中止部署对用户零影响。diff 由新容器执行，所以它反映的是「新代码期望什么 vs 库里有什么」。
echo "校验线上库与 prisma/schema.prisma 是否一致..."
DRIFT_SQL=""
if DRIFT_SQL=$(docker exec "${TMP_CONTAINER}" sh -c \
  'npx prisma migrate diff --from-url "$DATABASE_URL" --to-schema-datamodel prisma/schema.prisma --script' \
  2>/dev/null); then
  :
else
  DRIFT_SQL=""
fi

if [ -z "${DRIFT_SQL}" ]; then
  echo "警告：无法执行 prisma migrate diff，跳过 schema 校验（请自行确认迁移已执行）" >&2
elif printf '%s' "${DRIFT_SQL}" | grep -q 'This is an empty migration'; then
  echo "✓ 线上库与 schema 一致"
else
  echo "" >&2
  echo "✗ 线上库缺少本次代码需要的表或列，直接切换会让相关接口 500。" >&2
  echo "  典型症状：新增列后不带 select 的 findMany 报 P2022，而 /health 依然 ok。" >&2
  echo "" >&2
  echo "--- 需要先执行的 DDL ---" >&2
  printf '%s\n' "${DRIFT_SQL}" >&2
  echo "------------------------" >&2
  echo "" >&2
  echo "执行完上面的 SQL 再重新部署。确认可以忽略时改用 --allow-drift。" >&2
  if [ "${ALLOW_DRIFT}" = 1 ]; then
    echo "（--allow-drift：忽略漂移，继续部署）" >&2
  else
    docker rm -f "${TMP_CONTAINER}" >/dev/null 2>&1 || true
    echo "已中止并回滚（旧容器未受影响，线上不受影响）" >&2
    exit 1
  fi
fi

# --- 成功：删旧容器，把新容器改名为正式名 ---
# 删除到改名之间有一个极短的窗口（毫秒级），期间 nginx 可能收到一两个失败请求，
# 这是单机无负载均衡下无法完全避免的；nginx 自身有重试，实际影响可忽略。
if docker inspect "${APP_CONTAINER}" >/dev/null 2>&1; then
  echo "移除旧容器：${APP_CONTAINER}"
  docker rm -f "${APP_CONTAINER}" >/dev/null
fi
docker rename "${TMP_CONTAINER}" "${APP_CONTAINER}"

# --- reload nginx：这一步不能省 ---
# nginx 在启动时解析一次 proxy_pass 里的上游主机名并长期缓存，容器重建后不会自动
# 重新解析。本脚本为了保证零中断，是先起新容器（必然占一个新 IP）、健康后才删旧的，
# 所以 backend 的 IP 一定会变 —— 不 reload 就是「部署显示成功、线上持续 502」
# （2026-09-24 踩过）。这里 reload 后再实测一次 nginx 到 backend 的连通性。
if docker inspect "${NGINX_CONTAINER}" >/dev/null 2>&1; then
  echo "reload ${NGINX_CONTAINER}（刷新上游地址）..."
  if docker exec "${NGINX_CONTAINER}" nginx -s reload 2>/dev/null; then
    echo "已 reload"
  else
    echo "警告：reload ${NGINX_CONTAINER} 失败，线上可能仍指向旧容器地址" >&2
    echo "  手动执行：docker exec ${NGINX_CONTAINER} nginx -s reload" >&2
  fi

  echo "验证 ${NGINX_CONTAINER} 到 ${APP_CONTAINER} 的连通性..."
  if docker exec "${NGINX_CONTAINER}" wget -qO- --timeout=6 "http://${APP_CONTAINER}:3000/health" 2>/dev/null | grep -q '"ok":true'; then
    echo "✓ nginx 已能正常访问后端"
  else
    echo "警告：nginx 仍无法访问 ${APP_CONTAINER}，线上可能 502" >&2
    echo "  排查：docker exec ${NGINX_CONTAINER} nginx -s reload" >&2
  fi
else
  echo "提示：未找到 ${NGINX_CONTAINER}，跳过 reload（若 nginx 在宿主机上，请手动 nginx -s reload）"
fi

echo ""
echo "✓ 部署完成，${APP_CONTAINER} 已运行新镜像："
docker ps --filter "name=^/${APP_CONTAINER}$" --format '   {{.Names}}  {{.Status}}  {{.Image}}'
echo ""
echo "线上验证：curl -s -D- -o /dev/null https://youju.chat/user/40 | grep -i content-security-policy"
