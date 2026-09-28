#!/usr/bin/env bash
# 有据后端 · Git 自动部署
#
# 作用：检查 origin/main 是否有新提交；有则 fast-forward 拉取并执行滚动部署，
#      无变化时静默秒退（由 systemd timer 每 2 分钟触发一次，属正常路径）。
#
# 安全性（这几条是这套自动化能放心跑在生产上的原因）：
#   1) flock 并发保护：上一次部署未结束时本次直接跳过
#   2) 工作区有未提交改动 → 拒绝部署（绝不覆盖服务器上的手工修改）
#   3) 仅 fast-forward（不产生自动合并提交）
#   4) 部署失败 → 回退检出 + 记入 last-failed，避免定时器每 2 分钟无脑重试
#   5) 实际替换交给 scripts/deploy-backend.sh：
#      构建镜像 → 新容器健康检查通过才删旧容器 → 失败回滚 → 线上库与 schema 对账
#
# 手动触发一次：sudo systemctl start youju-autodeploy.service
# 查看日志：    journalctl -u youju-autodeploy.service -n 100 --no-pager
set -euo pipefail

# 非交互：git 需要凭据时立即失败，而不是在 systemd 里永久挂住
export GIT_TERMINAL_PROMPT=0

REPO_DIR="${REPO_DIR:-$(cd "$(dirname "$0")/../.." && pwd)}"
BRANCH="${BRANCH:-main}"
REMOTE="${REMOTE:-origin}"
# 状态目录放在仓库之外：放在仓库内会被 git status 视为未跟踪文件，反而触发「工作区不干净」保护
STATE_DIR="${STATE_DIR:-$HOME/.local/state/youju-autodeploy}"
LOCK_FILE="${LOCK_FILE:-/tmp/youju-autodeploy.lock}"

mkdir -p "${STATE_DIR}"
log() { echo "[$(date '+%F %T')] $*"; }

# --- 1) 并发保护 ---
exec 9>"${LOCK_FILE}"
if ! flock -n 9; then
  log "上一次部署仍在进行，跳过本次"
  exit 0
fi

cd "${REPO_DIR}"

# --- 2) 取远端最新 ---
if ! git fetch --prune "${REMOTE}" "${BRANCH}" >/dev/null 2>&1; then
  log "ERROR: git fetch 失败（网络或凭据问题）。请确认可非交互 fetch："
  log "       git -C ${REPO_DIR} fetch ${REMOTE} ${BRANCH}"
  exit 1
fi

LOCAL_SHA="$(git rev-parse HEAD)"
REMOTE_SHA="$(git rev-parse "${REMOTE}/${BRANCH}")"

if [ "${LOCAL_SHA}" = "${REMOTE_SHA}" ]; then
  exit 0   # 无新提交：静默退出
fi

# --- 3) 上次失败的提交不重复重试，避免反复构建 ---
if [ -f "${STATE_DIR}/last-failed" ] && [ "$(cat "${STATE_DIR}/last-failed")" = "${REMOTE_SHA}" ]; then
  log "提交 ${REMOTE_SHA:0:7} 上次部署失败，已跳过重试；"
  log "人工修复后删除 ${STATE_DIR}/last-failed 即可恢复自动部署"
  exit 1
fi

log "发现新提交：${LOCAL_SHA:0:7} -> ${REMOTE_SHA:0:7}"

# --- 4) 已跟踪文件必须干净 ---
# 只看「已跟踪文件」：未跟踪文件（服务器生成的 certbot/、uploads/ 等）不会与 fast-forward 冲突，
# 若把它们也算进来，自动部署会被永久卡住。
if [ -n "$(git status --porcelain --untracked-files=no)" ]; then
  log "ERROR: 已跟踪文件存在未提交改动，拒绝自动部署（避免覆盖手工修改）。请人工处理："
  git status --porcelain --untracked-files=no | sed 's/^/    /'
  exit 1
fi

# --- 5) 仅 fast-forward ---
git merge --ff-only "${REMOTE}/${BRANCH}"

# --- 6) 滚动部署 ---
if ( cd "${REPO_DIR}/backend" && bash scripts/deploy-backend.sh ); then
  echo "${REMOTE_SHA}" > "${STATE_DIR}/last-deployed"
  rm -f "${STATE_DIR}/last-failed"
  log "部署成功：${REMOTE_SHA:0:7}"
else
  log "ERROR: 部署失败，回退检出到 ${LOCAL_SHA:0:7}（修好后推新提交或删除 last-failed 重试）"
  echo "${REMOTE_SHA}" > "${STATE_DIR}/last-failed"
  git reset --hard "${LOCAL_SHA}"
  exit 1
fi
