#!/bin/sh
# 提审前形态检查：确认源码开关与 release 产物没有 debug 残留。
# 用法：sh check-release.sh
# 背景：buildMode.ets 是源码级开关（hvigor -p buildMode=... 不生效），本地联调要手改
#       debug/true、验证后手改回 release/false——「忘还原」是提审前最大的操作风险，
#       本脚本就是防它的（build/ 提审审计时确实发现过本地构建树处于 debug 形态）。
# 任何一项 ❌ 都不要提交代码或上传产物。
set -u
cd "$(dirname "$0")"
fail=0

# 1) 源码形态开关必须是 release / false
if grep -q "BUILD_MODE_NAME: string = 'release'" entry/src/main/ets/utils/buildMode.ets \
   && grep -q "DEBUG: boolean = false" entry/src/main/ets/utils/buildMode.ets; then
  echo "✅ buildMode.ets：release / false"
else
  echo "❌ buildMode.ets 不是 release/false —— 本地联调后忘还原了"
  fail=1
fi

# 2) release 中间产物不能是 debug 形态
MOD="entry/build/release/intermediates/res/default/module.json"
if [ -f "$MOD" ]; then
  if grep -qE '"(buildMode|debug)": *"?((debug)|(true))"?' "$MOD"; then
    echo "❌ release 中间产物是 debug 形态 —— 请用 release product 重新构建"
    fail=1
  else
    echo "✅ release 中间产物 module.json：非 debug"
  fi
else
  echo "⚠️ 未找到 $MOD —— 还没用 release product 构建过"
  fail=1
fi

# 3) release 签名产物存在
HAP=$(ls entry/build/release/outputs/default/*-signed.hap 2>/dev/null | head -n 1)
if [ -n "$HAP" ]; then
  echo "✅ release 产物：$HAP"
else
  echo "❌ 未找到 entry/build/release/outputs/default/*-signed.hap —— 请用 release product 构建"
  fail=1
fi

# 4) 版本号一致（app.json5 vs AboutPage / SettingsPage 里的字面量）
VER=$(sed -n 's/.*"versionName": "\([^"]*\)".*/\1/p' AppScope/app.json5 | head -n 1)
if [ -n "$VER" ]; then
  miss=0
  for f in entry/src/main/ets/pages/AboutPage.ets entry/src/main/ets/pages/SettingsPage.ets; do
    if grep -q "$VER" "$f"; then
      echo "✅ $(basename "$f") 版本号 = $VER"
    else
      echo "❌ $(basename "$f") 的版本号与 app.json5（$VER）不一致"
      miss=1
    fi
  done
  if [ "$miss" -ne 0 ]; then
    fail=1
  fi
else
  echo "⚠️ 读不到 AppScope/app.json5 的 versionName"
fi

# 5) 产物字节码字符串表里的内网 IP / 明文调试地址
#    DEBUG_API_HOST 的字符串会原样进包（已实证）：本 HAP 里就有旧值 10.181.227.205:3000。
#    联调时手改成 LAN IP 后忘还原再出包，也会在这里被抓住。
if [ -n "$HAP" ]; then
  n=$(unzip -p "$HAP" 2>/dev/null | grep -acE 'http://(10\.|172\.(1[6-9]|2[0-9]|3[01])\.|192\.168\.)' || true)
  if [ "${n:-0}" -gt 0 ]; then
    echo "⚠️  release 产物内含内网 IP / 明文调试地址（$n 处）—— 私有地址、非凭据，可接受；"
    echo "    若要清零：把 services/api.ets 的 DEBUG_API_HOST 改回 http://127.0.0.1:3000 后重新构建（发版前还原点 +1）"
  else
    echo "✅ release 产物：无内网 IP / 明文调试后端地址"
  fi
  # dev 账号登录桩（科技老张/虚拟小美）按现状是接受的：入口隐藏 + release throw 双兜底
  dn=$(unzip -p "$HAP" 2>/dev/null | grep -ac 'dev-seed-openid' || true)
  if [ "${dn:-0}" -gt 0 ]; then
    echo "ℹ️  release 产物含 dev 账号登录桩字符串（$dn 处）—— 已知且接受，如需清零需移除 LoginPage 的 debug 按钮"
  fi
fi

if [ "$fail" -ne 0 ]; then
  echo ""
  echo "⛔ 存在上述问题，先修复再提交代码 / 上传产物"
  exit 1
fi
echo ""
echo "🎉 全部通过，可以出包上传"
