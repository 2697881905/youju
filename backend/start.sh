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
# 7. 自动建立 hdc 反向端口转发（模拟器/真机本地联调）
#    让设备侧的 127.0.0.1:3000 指向本机后端，避免“圈子栏只显示全部”
#    等因连不上后端而触发降级（displayTags 回退为 [全部]）。
#    设备/模拟器重启或重连后该转发会失效，故每次启动都尝试重建一次。
# -------------------------------------------------------
echo ""
echo "建立 hdc 反向端口转发（设备 127.0.0.1:3000 -> 本机 3000）..."
# 定位 hdc：优先 PATH，否则尝试 DevEco / OpenHarmony 自带 toolchains
HDC_BIN=""
if command -v hdc >/dev/null 2>&1; then
  HDC_BIN="hdc"
else
  for p in \
    "$DEVECO_SDK_HOME/HarmonyOS/toolchains/hdc" \
    "/Applications/DevEco-Studio.app/Contents/sdk/HarmonyOS/toolchains/hdc" \
    "$HOME/Library/OpenHarmony/Sdk/HarmonyOS/toolchains/hdc"; do
    if [ -x "$p" ]; then HDC_BIN="$p"; break; fi
  done
fi

if [ -z "$HDC_BIN" ]; then
  echo -e "${YELLOW}⚠ 未找到 hdc，跳过端口转发。真机/模拟器联调请手动执行: hdc rport tcp:3000 tcp:3000${NC}"
elif ! "$HDC_BIN" list targets 2>/dev/null | grep -q .; then
  echo -e "${YELLOW}⚠ 未检测到已连接的设备/模拟器，跳过端口转发。连接后请手动执行: hdc rport tcp:3000 tcp:3000${NC}"
else
  # 已存在则忽略错误（避免 “already exist” 导致非零退出）
  "$HDC_BIN" rport tcp:3000 tcp:3000 2>/dev/null || true
  echo -e "${GREEN}✓ 已建立端口转发（设备 127.0.0.1:3000 -> 本机 3000）${NC}"
  echo -e "${GREEN}  真机/模拟器现在可直接访问 127.0.0.1:3000 拉取后端数据${NC}"
fi
