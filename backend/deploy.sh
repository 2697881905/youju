#!/bin/bash
# 有据后端生产重建脚本（服务器 docker 引擎无 compose v2 插件时的部署方式）
# 用法：git pull 后在本目录执行 bash deploy.sh
# 前置：本目录 .env 已存在且含生产配置；docker 网络 youju_default 已存在
#       （youju-nginx / youju-mysql 所在网络，由历史部署创建，长期存在）。
#
# ⚠️ 为什么不用 docker-compose：服务器上的 docker-compose 1.29.2 在新版引擎上
#    recreate 容器必报 KeyError: 'ContainerConfig' 且回滚删容器（2026-11-05 实测
#    两次生产中断）。本脚本用「build + rm + run」组合，永远走创建路径，绕开该 bug。
#    compose v2 插件装好后可改回 docker compose up -d --build backend。
set -e
cd "$(dirname "$0")"

if [ ! -f .env ]; then
  echo "ERROR: .env 不存在，请先配置生产环境变量"
  exit 1
fi

echo "=== 1/4 构建镜像（package-lock 未变时全部走缓存，秒级）==="
docker build -t backend_backend:latest .

echo "=== 2/4 移除旧容器（/app/uploads 为容器层目录，已验证无本地兜底上传数据）==="
docker rm -f youju-backend 2>/dev/null || true

echo "=== 3/4 启动新容器（env-file 注入全部配置；挂载华为推送凭证；加入 youju_default 网络供 nginx 反代）==="
docker run -d --name youju-backend \
  --network youju_default \
  --restart unless-stopped \
  --env-file ./.env \
  -v "$PWD/agc-service-account.json:/app/agc-service-account.json" \
  backend_backend:latest

echo "=== 4/4 健康检查 ==="
sleep 5
if docker exec youju-backend curl -s http://127.0.0.1:3000/health | grep -q '"ok":true'; then
  echo "✓ 后端健康检查通过"
else
  echo "✗ 健康检查失败，查看日志：docker logs youju-backend --tail 50"
  exit 1
fi
docker exec youju-backend curl -s http://127.0.0.1:3000/v1/ai/status
echo
echo "=== 部署完成 ==="
