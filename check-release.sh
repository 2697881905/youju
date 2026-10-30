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

# 4) 版本号一致：单一真源是 buildMode.ets 的 APP_VERSION_NAME（2026-10-13 收敛，
#    页面不再写字面量）。旧版这里 grep 页面里的字面量，收敛后必然误报 ❌ 卡住提审。
VER=$(sed -n 's/.*"versionName": "\([^"]*\)".*/\1/p' AppScope/app.json5 | head -n 1)
if [ -z "$VER" ]; then
  echo "❌ 没从 app.json5 读到 versionName"
  fail=1
else
  if grep -q "APP_VERSION_NAME: string = '$VER'" entry/src/main/ets/utils/buildMode.ets; then
    echo "✅ APP_VERSION_NAME = $VER（与 app.json5 一致）"
  else
    echo "❌ buildMode.ets 的 APP_VERSION_NAME 与 app.json5（$VER）不一致 —— 版本号漏改"
    fail=1
  fi
  for f in entry/src/main/ets/pages/AboutPage.ets entry/src/main/ets/pages/SettingsPage.ets; do
    if grep -q "APP_VERSION_NAME" "$f"; then
      echo "✅ $(basename "$f") 取单一常量 APP_VERSION_NAME"
    elif grep -q "$VER" "$f"; then
      echo "⚠️ $(basename "$f") 仍写死字面量 $VER —— 能过检，但建议改读常量"
    else
      echo "❌ $(basename "$f") 既没引用 APP_VERSION_NAME 也没有当前版本号"
      fail=1
    fi
  done
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

# 6) 签名身份核验：产物内嵌 profile 必须是 release 型、不得带设备白名单。
#    背景（2026-10-30 实测）：build-profile.json5 里名为 "release" 的 signingConfig 曾指向
#    release_HarmonyProject1_*.{cer,p7b,p12} 三件套——文件名写着 release，实际叶子证书是
#    ",Development"、profile 是 type=debug 且带 4 条 udid 设备白名单。这样出的包只能装白名单机，
#    上传 AppGallery 必被拒。上面 1)~5) 全绿也拦不住它，因为它压根不看签名身份。
#    profile 不在 zip 条目里，是随签名块嵌进产物的，故直接按字节判。
if [ -n "$HAP" ]; then
  SIGINFO=$(python3 - "$HAP" <<'PY'
import sys, re
b = open(sys.argv[1], 'rb').read()
m = re.search(rb'"type":"(debug|release)"', b)
print((m.group(1).decode() if m else 'unknown') + '|' + str(b.count(b'udid')))
PY
)
  PTYPE=${SIGINFO%%|*}
  PUDID=${SIGINFO##*|}
  if [ "$PTYPE" = "release" ] && [ "${PUDID:-1}" = "0" ]; then
    echo "✅ 签名 profile：type=release 且无设备白名单"
  else
    echo "❌ 签名 profile 是 type=$PTYPE、udid 标记 $PUDID 处 —— 这是调试签名，上传必被拒。"
    echo "   改 build-profile.json5 的 release signingConfig 指向真正的发布三件套："
    echo "   ~/.ohos/config/youju-release-key4-20260815.{p12,cer} +"
    echo "   ~/.ohos/config/youju-release-key4-acl-20261008Release.p7b（含 READ_PASTEBOARD ACL）"
    echo "   口令只能在 DevEco 签名面板里填（它写加密值），填完重新构建再跑本脚本。"
    fail=1
  fi
fi

if [ "$fail" -ne 0 ]; then
  echo ""
  echo "⛔ 存在上述问题，先修复再提交代码 / 上传产物"
  exit 1
fi
echo ""
echo "🎉 全部通过，可以出包上传"
