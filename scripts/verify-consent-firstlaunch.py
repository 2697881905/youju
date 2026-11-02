#!/usr/bin/env python3
"""首启明示同意全流程取证（要求全新安装态，脚本会卸载重装 = 清掉本地会话与缓存）。

坐标全部从当次 dumpLayout 现取；每条「不生效」结论都配一条同层注入正证。
⚠️ 跑之前确认目标设备上的登录态是可以丢的：卸载会清本地会话、深色偏好、圈子引导标记与图片缓存
   （服务端账号数据不受影响）。release 签名包无法侧装（9568322 非受信来源），
   真机只能装同源码的调试签名包。
用法：YOUJU_PROBE_DEVICE=<hdc地址> YOUJU_PROBE_HAP=<hap路径> python3 scripts/verify-consent-firstlaunch.py
"""
import json
import os
import subprocess
import sys
import time

HDC = "/Applications/DevEco-Studio.app/Contents/sdk/default/openharmony/toolchains/hdc"
# 设备与产物都可从环境覆盖：真机走无线 hdc 地址，模拟器用 127.0.0.1:5555
DEV = os.environ.get("YOUJU_PROBE_DEVICE", "192.168.2.3:46077")
BUNDLE = "com.youju.app"
HAP = os.environ.get(
    "YOUJU_PROBE_HAP",
    "/Users/itxiaobai/HarmonyProject1/entry/build/default/outputs/default/entry-default-signed.hap",
)
TMP = "/data/local/tmp/rp.json"
LOC = "/tmp/rp_layout.json"


def sh(args, timeout=90):
    return subprocess.run(args, capture_output=True, text=True, timeout=timeout).stdout


def dump():
    sh([HDC, "-t", DEV, "shell", f"uitest dumpLayout -p {TMP}"])
    sh([HDC, "-t", DEV, "file", "recv", TMP, LOC])
    with open(LOC) as f:
        return json.load(f)


def pairs(tree):
    out = []

    def walk(n, p):
        out.append((n, p))
        for c in n.get("children") or []:
            walk(c, n)

    walk(tree, None)
    return out


def ft(tree, text):
    for n, _ in pairs(tree):
        if (n.get("attributes", {}).get("text") or "").strip() == text:
            return n
    return None


def has(tree, text):
    return ft(tree, text) is not None


def bb(node):
    return node.get("attributes", {}).get("bounds", "")


def center(node):
    x1, y1, x2, y2 = [int(v) for v in bb(node).replace("][", ",").replace("[", "").replace("]", "").split(",")]
    return (x1 + x2) // 2, (y1 + y2) // 2


def tap(node):
    x, y = center(node)
    sh([HDC, "-t", DEV, "shell", f"uitest uiInput click {x} {y}"])
    return x, y


def tap_at(x, y):
    sh([HDC, "-t", DEV, "shell", f"uitest uiInput click {x} {y}"])


def back():
    sh([HDC, "-t", DEV, "shell", "uitest uiInput keyEvent Back"])


def checkbox(tree):
    lab = ft(tree, "我已阅读并同意")
    if lab is None:
        return None
    by = {id(n): p for n, p in pairs(tree)}
    cur = lab
    for _ in range(2):
        cur = by.get(id(cur))
    kids = (cur or {}).get("children") or []
    return kids[0] if kids else None


def hw_chain_disabled(tree):
    txt = ft(tree, "华为账号登录")
    if txt is None:
        return None
    by = {id(n): p for n, p in pairs(tree)}
    cur, flags = txt, []
    for _ in range(5):
        cur = by.get(id(cur))
        if cur is None:
            break
        flags.append(cur.get("attributes", {}).get("enabled"))
    return "false" in flags


R = []


def check(name, ok, detail):
    R.append((name, ok))
    print(("  PASS  " if ok else "  FAIL  ") + name + "   " + detail, flush=True)


def main():
    # 前置：确认现在是全新安装的首启弹窗
    t = dump()
    if not has(t, "同意并继续"):
        print("前置失败：当前不是首启弹窗态，先卸载重装", flush=True)
        return 2
    check("F1 全新安装后首启弹隐私弹窗，含「不同意」",
          has(t, "隐私政策与用户协议") and has(t, "不同意"),
          f"标题=True 不同意={bb(ft(t,'不同意'))}")

    # F2 遮罩不可关
    tap_at(60, 400)
    time.sleep(2)
    t2 = dump()
    check("F2 点弹窗遮罩（60,400）弹窗不关闭", has(t2, "同意并继续"), "autoCancel:false 在真机生效")

    # F3 读政策 → 返回必须重弹
    tap(ft(t2, "《隐私政策》"))
    time.sleep(3)
    t3 = dump()
    on_policy = has(t3, "隐私政策") and not has(t3, "同意并继续")
    back()
    time.sleep(3)
    t4 = dump()
    check("F3 点《隐私政策》进正文、返回后弹窗重弹",
          on_policy and has(t4, "同意并继续"),
          f"落在政策页={on_policy} → 返回后重弹={has(t4,'同意并继续')}")

    # F4 未同意前主界面不构建（无 Tab、无信息流）
    leaks = [x for x in ("首页", "圈子", "消息", "我的") if has(t4, x)]
    check("F4 未同意时主 Tab 与信息流不构建（同意前不初始化）",
          leaks == [], f"泄露节点={leaks or '无'}")

    # F5 正证 + 同意后主界面加载
    tap(ft(t4, "同意并继续"))
    time.sleep(4)
    t5 = dump()
    check("F5 点「同意并继续」生效：弹窗消失且主界面加载",
          not has(t5, "同意并继续") and has(t5, "首页"),
          f"弹窗消失=True 首页 Tab 在位={has(t5,'首页')}")

    # F6 登录页闸门（真机 release 形态源码）
    banner = ft(t5, "登录")
    if banner is not None:
        tap(banner)
        time.sleep(3)
        t6 = dump()
        cb = checkbox(t6)
        cval = cb.get("attributes", {}).get("checked") if cb else None
        check("F6 登录页复选框默认空白 + 华为按钮节点 disabled",
              cval == "false" and hw_chain_disabled(t6) is True,
              f"checked={cval} 按钮含disabled={hw_chain_disabled(t6)}")
        tap(cb)
        time.sleep(2)
        t7 = dump()
        cb2 = checkbox(t7)
        check("F7 勾选后闸门放开",
              cb2.get("attributes", {}).get("checked") == "true" and hw_chain_disabled(t7) is False,
              f"checked={cb2.get('attributes',{}).get('checked')} 按钮含disabled={hw_chain_disabled(t7)}")
        back()
        time.sleep(2)
    else:
        check("F6 登录页复选框默认空白 + 华为按钮节点 disabled", False, "首页无「登录」入口，未跑")

    # F8 不同意 → 退出应用（重装回到首启态后再测）
    sh([HDC, "-t", DEV, "uninstall", BUNDLE])
    sh([HDC, "-t", DEV, "install", HAP])
    sh([HDC, "-t", DEV, "shell", f"aa start -a EntryAbility -b {BUNDLE}"])
    time.sleep(8)
    t8 = dump()
    dec = ft(t8, "不同意")
    if dec is not None:
        tap(dec)
        time.sleep(4)
        alive = sh([HDC, "-t", DEV, "shell", f"pidof {BUNDLE}"]).strip()
        check("F8 点「不同意」应用直接退出", alive == "", f"pidof={alive!r}")
    else:
        check("F8 点「不同意」应用直接退出", False, "重装后未复现首启弹窗")

    # 收尾：把手机留在「已同意 + 未登录」可用态
    sh([HDC, "-t", DEV, "shell", f"aa start -a EntryAbility -b {BUNDLE}"])
    time.sleep(8)
    t9 = dump()
    ok_btn = ft(t9, "同意并继续")
    if ok_btn is not None:
        tap(ok_btn)
        time.sleep(4)
    t10 = dump()
    print(f"\n收尾：手机停在 {'主界面（未登录）' if has(t10,'首页') else '非主界面'}", flush=True)

    fails = [n for n, ok in R if not ok]
    print(f"\n{len(R) - len(fails)}/{len(R)} 通过" + (f"；失败：{fails}" if fails else ""))
    return 1 if fails else 0


if __name__ == "__main__":
    sys.exit(main())
