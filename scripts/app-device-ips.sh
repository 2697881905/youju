#!/bin/bash
# 有据 · 独立 App 客户端 IP 估计（游客设备口径）
# 为什么需要它：华为激励计划的「有效月活」= 去重活跃**设备**，游客打开 App 也计分；
#   而 DB 只能看到登录用户（scripts/mau-report.sh 的 46 是**下界**）。
#   本脚本从 nginx 日志按 App 的 HTTP 客户端 UA 指纹估设备量级。
# 指纹：HarmonyOS @ohos.net.http 走 curl / RedTail，UA 形如 "libcurl-agent/1.0"、"libredtail-http"。
#   2026-10-28 实测：30 天内 236 个 IP，其中 223 个呈真实使用画像（>=10 请求且 >=3 端点），
#   只有 1 个像扫描器。
# 口径与边界（必须一起读）：
#   - IP ≠ 设备：移动网络会换 IP（高估），校园/家庭出口多人共用一个 IP（低估）。
#     所以这是**量级估计**，定标必须回到激励后台真值。
#   - 机房/云主机 IP 多为自动化流量，单列出来供人工判断是否剔除。
# 用法：./scripts/app-device-ips.sh [时长，默认 720h（30 天）]
set -euo pipefail
HOST="${YOUJU_PROD_HOST:-ubuntu@114.132.102.189}"
SINCE="${1:-720h}"

{
  printf 'SINCE=%q\n' "$SINCE"
  cat <<'EOS'
L=$(docker logs --since "$SINCE" youju-nginx 2>&1)
# $2 = 请求行，$6 = UA（nginx combined 变体，按引号切列）
APP=$(echo "$L" | awk -F'"' '$6 ~ /libcurl-agent|libredtail-http/ {split($1, x, " "); split($2, r, " "); p = r[2]; sub(/\?.*/, "", p); print x[1], p}')
echo "$APP" | awk '{cnt[$1]++; k = $1 "|" $2; if (!(k in s)) { s[k] = 1; ep[$1]++ } } END { for (ip in cnt) print cnt[ip], ep[ip], ip }' | sort -rn > /tmp/ipprof.txt

echo "== 独立 App 客户端 IP（--since $SINCE）=="
echo -n "全部 IP：";              wc -l < /tmp/ipprof.txt
echo -n "真实使用画像(>=10请求且>=3端点)："; awk '$1>=10 && $2>=3' /tmp/ipprof.txt | wc -l
echo -n "疑似扫描/探测(<=1端点且<5请求)：";   awk '$2<=1 && $1<5' /tmp/ipprof.txt | wc -l

echo
echo "== 疑似机房/云主机 IP（自动化流量，人工判断是否剔除）=="
awk '$1>=10 && $2>=3 {print $3, "req="$1, "ep="$2}' /tmp/ipprof.txt \
  | grep -E '^(123\.60\.|121\.37\.|139\.159\.|124\.70\.|119\.3\.|1\.9[45]\.|171\.80\.)' || echo "（无）"

echo
echo "== 真实口径逐日去重 IP（含游客设备）=="
GOOD=$(awk '$1>=10 && $2>=3 {print $3}' /tmp/ipprof.txt | tr '\n' ' ')
echo "$L" | awk -v g="$GOOD" 'BEGIN { n = split(g, a, " "); for (i = 1; i <= n; i++) keep[a[i]] = 1 }
  { if ($0 !~ /libcurl-agent|libredtail-http/) next
    ip = $1; d = substr($4, 2, 11); k = d " " ip
    if (keep[ip] && !(k in s)) { s[k] = 1; c[d]++ } }
  END { for (x in c) print x, c[x] }' | sort

echo
echo "== 已登录设备 vs 游客设备（按端点判）=="
echo -n "打过 /v1/auth/me 的去重 IP（≈已登录）："
echo "$L" | awk -F'"' '$6 ~ /libcurl-agent|libredtail-http/ && $2 ~ /\/v1\/auth\/me/ {split($1, x, " "); print x[1]}' | sort -u | wc -l
echo -n "打过 /v1/posts 的去重 IP（含游客）："
echo "$L" | awk -F'"' '$6 ~ /libcurl-agent|libredtail-http/ && $2 ~ /GET \/v1\/posts/ {split($1, x, " "); print x[1]}' | sort -u | wc -l
EOS
} | ssh -o ConnectTimeout=25 "$HOST" 'bash -s'
