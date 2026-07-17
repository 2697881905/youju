#!/bin/bash
# 大蓝书后端一键启动脚本
# 用法：在 backend/ 目录下执行 bash start.sh
set -e

# cd 到脚本所在目录（backend/）
cd "$(dirname "$0")"

# ANSI 颜色
RED='\033[31m'
GREEN='\033[32m'
YELLOW='\033[33m'
NC='\033[0m'

echo "=== 大蓝书后端一键启动 ==="

# -------------------------------------------------------
# 1. 检查 MySQL（3306 端口是否在监听）
#    用 nc -z 探测端口连通性，而非 lsof -i:3306。
#    原因：macOS 上 lsof 不带 sudo 看不到其他用户（如 _mysql）
#    的进程端口监听，会误判 MySQL 未启动；nc -z 不需 sudo 且与
#    进程所属用户无关，能正确检测端口是否在监听。
# -------------------------------------------------------
if ! nc -z 127.0.0.1 3306 2>/dev/null; then
  echo -e "${RED}MySQL 未启动（3306 未监听），请先启动本机 /usr/local/mysql${NC}"
  exit 1
fi
echo -e "${GREEN}✓ MySQL 已运行（3306 在监听）${NC}"

# -------------------------------------------------------
# 2. 检查 .env 配置文件
# -------------------------------------------------------
if [ ! -f .env ]; then
  echo -e "${RED}请从 .env.example 复制并填写 DATABASE_URL 与 COS 五项${NC}"
  exit 1
fi
echo -e "${GREEN}✓ .env 已存在${NC}"

# -------------------------------------------------------
# 3. 检查 node_modules，不存在则安装
# -------------------------------------------------------
if [ ! -d node_modules ]; then
  echo "node_modules 不存在，开始安装依赖..."
  export PRISMA_ENGINES_MIRROR=https://registry.npmmirror.com/-/binary/prisma/
  if ! npm install; then
    echo -e "${YELLOW}npm install 失败，若报 UNABLE_TO_GET_ISSUER_CERT_LOCALLY，请执行：npm config set strict-ssl false 后重试${NC}"
    exit 1
  fi
fi
echo -e "${GREEN}✓ 依赖已就绪${NC}"

# -------------------------------------------------------
# 4. 同步数据库表结构（prisma db push，失败仅警告不阻断）
# -------------------------------------------------------
echo "同步数据库表结构（prisma db push）..."
if ! npx prisma db push; then
  echo -e "${YELLOW}⚠ prisma db push 失败，请检查 DATABASE_URL 配置；后端仍会尝试启动${NC}"
fi

# -------------------------------------------------------
# 5. 后台启动 npm run dev
# -------------------------------------------------------
echo "启动后端服务..."
nohup npm run dev > /tmp/bigbluebook-backend.log 2>&1 &
BACKEND_PID=$!
echo "后端进程 PID: $BACKEND_PID（日志: /tmp/bigbluebook-backend.log）"

# -------------------------------------------------------
# 6. 等待 4 秒后健康检查
# -------------------------------------------------------
sleep 4
if curl -s http://localhost:3000/health | grep -q '"ok":true'; then
  echo -e "${GREEN}后端已启动: http://localhost:3000${NC}"
else
  echo -e "${YELLOW}后端进程已起，请看上方日志（/tmp/bigbluebook-backend.log）${NC}"
fi

# -------------------------------------------------------
# 7. 模拟器联调提示
# -------------------------------------------------------
echo ""
echo -e "${YELLOW}模拟器联调记得另开终端跑: hdc rport tcp:3000 tcp:3000${NC}"
