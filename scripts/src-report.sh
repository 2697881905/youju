#!/bin/bash
# 有据 · 渠道归因计数（零埋点）
# 原理：外部渠道发的是带参数的落地页链接 https://youju.chat/?src=<渠道代号>，
#       nginx 标准 combined 日志会记录完整 request 行（含 query），按 src 聚合即得各渠道点击量。
#       不采集设备标识、不涉 PIPL，也不需要发版。
# 口径：这里数的是「点击到落地页」，不是安装、不是活跃设备；落地页点击 → 安装的经验转化 15-28%。
#       活跃设备真值仍以华为激励后台 / AGC 统计为准，配合 scripts/mau-report.sh 的下界一起看。
# 用法：./scripts/src-report.sh [时长，默认 168h]
set -euo pipefail
HOST="${YOUJU_PROD_HOST:-ubuntu@114.132.102.189}"
SINCE="${1:-168h}"

ssh -o ConnectTimeout=20 "$HOST" "bash -s" <<EOF
L=\$(docker logs --since $SINCE youju-nginx 2>&1)
echo "== 渠道点击量（--since $SINCE）=="
echo "\$L" | grep -E '"GET /?\\?[^"]*src=' | grep -oE 'src=[A-Za-z0-9_-]+' | sed 's/src=//' | sort | uniq -c | sort -rn
echo
echo "== 逐日 x 渠道 =="
echo "\$L" | grep -E '"GET /?\\?[^"]*src=' | awk '{
  d = substr(\$4, 2, 11);
  match(\$0, /src=[A-Za-z0-9_-]+/); s = substr(\$0, RSTART+4, RLENGTH-4);
  k = d " " s; c[k]++
} END { for (x in c) print x, c[x] }' | sort
echo
echo "== 落地页总请求数（含无参）=="
echo "\$L" | grep -cE '"GET / ' || true
EOF
