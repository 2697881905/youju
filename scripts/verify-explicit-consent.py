#!/usr/bin/env python3
"""AGC 7.5 明示同意整改 · 全量取证脚本（Mate 90 Pro Max 模拟器）。

每条断言都从当次 dumpLayout 现取坐标，不硬编码 bounds（硬编码会过期成假绿）。
用法：python3 verify-explicit-consent.py <hap 路径>
"""
import json
import subprocess
import sys
import time

HDC = "/Applications/DevEco-Studio.app/Contents/sdk/default/openharmony/toolchains/hdc"
DEV = "127.0.0.1:5555"
BUNDLE = "com.youju.app"
TMP = "/data/local/tmp/probe.json"

results = []


def sh(args, timeout=60):
    return subprocess.run(args, capture_output=True, text=True, timeout=timeout).stdout


def dump():
    sh([HDC, "-t", DEV, "shell", f"uitest dumpLayout -p {TMP}"])
    local = "/tmp/probe_layout.json"
    sh([HDC, "-t", DEV, "file", "recv", TMP, local])
    with open(local) as f:
        return json.load(f)


def nodes(tree):
    """深度优先，返回 (node, parent) 列表。"""
    out = []

    def walk(n, p):
        out.append((n, p))
        for c in n.get("children") or []:
            walk(c, n)

    walk(tree, None)
    return out


def find_text(tree, text):
    for n, _ in nodes(tree):
        if (n.get("attributes", {}).get("text") or "").strip() == text:
            return n
    return None


def bounds_of(node):
    return node.get("attributes", {}).get("bounds", "")


def center(node):
    b = bounds_of(node)
    x1, y1, x2, y2 = [int(v) for v in b.replace("][", ",").replace("[", "").replace("]", "").split(",")]
    return (x1 + x2) // 2, (y1 + y2) // 2


def tap(node):
    x, y = center(node)
    sh([HDC, "-t", DEV, "shell", f"uitest uiInput click {x} {y}"])


def tap_at(x, y):
    sh([HDC, "-t", DEV, "shell", f"uitest uiInput click {x} {y}"])


def checkbox(tree):
    """复选框节点：定位「我已阅读并同意」→ 回溯两层到勾选整行 → 其第一个子节点即 Checkbox。"""
    label = find_text(tree, "我已阅读并同意")
    if label is None:
        return None
    pairs = nodes(tree)
    by_child = {id(n): p for n, p in pairs}
    cur = label
    for _ in range(2):
        p = by_child.get(id(cur))
        if p is None:
            return None
        cur = p
    kids = cur.get("children") or []
    return kids[0] if kids else None


def login_state(tree):
    cb = checkbox(tree)
    checked = None if cb is None else cb.get("attributes", {}).get("checked")
    # 华为登录钮：从「华为账号登录」文案回溯到按钮容器，看链上是否有 enabled=false
    txt = find_text(tree, "华为账号登录")
    pairs = nodes(tree)
    by_child = {id(n): p for n, p in pairs}
    disabled = None
    if txt is not None:
        cur, seen = txt, 0
        flags = []
        while cur is not None and seen < 5:
            p = by_child.get(id(cur))
            if p is None:
                break
            flags.append(p.get("attributes", {}).get("enabled"))
            cur, seen = p, seen + 1
        disabled = "false" in flags
    return checked, disabled


def check(name, ok, detail):
    results.append((name, "PASS" if ok else "FAIL", detail))
    print(("  PASS  " if ok else "  FAIL  ") + name + "   " + detail, flush=True)


def main():
    hap = sys.argv[1]
    print(f"设备 {DEV} · 包 {hap}\n", flush=True)
    sh([HDC, "-t", DEV, "uninstall", BUNDLE])
    print(sh([HDC, "-t", DEV, "install", hap]).strip() or "(no output)", flush=True)
    sh([HDC, "-t", DEV, "shell", f"aa force-stop {BUNDLE}"])
    sh([HDC, "-t", DEV, "shell", f"aa start -a EntryAbility -b {BUNDLE}"])
    time.sleep(7)

    # ── 首启弹窗 ──
    t = dump()
    title = find_text(t, "隐私政策与用户协议")
    decline = find_text(t, "不同意")
    accept = find_text(t, "同意并继续")
    check("A1 首启弹隐私弹窗，且含「不同意」拒绝项",
          title is not None and decline is not None and accept is not None,
          f"标题={title is not None} 不同意={decline is not None} 同意并继续={accept is not None}")

    # A2 遮罩不可关（点面板外）
    if accept is not None:
        ax, ay = center(accept)
        tap_at(60, 300)  # 面板外左上角
        time.sleep(2)
        t2 = dump()
        still = find_text(t2, "同意并继续") is not None
        check("A2 点弹窗遮罩不关闭（autoCancel:false）", still, f"遮罩点击位 (60,300)，弹窗仍在={still}")
        # 反证：同一时刻该层仍能收到注入
        tap(find_text(t2, "同意并继续"))
        time.sleep(4)
        t3 = dump()
        gone = find_text(t3, "同意并继续") is None
        home = find_text(t3, "有据可依  更好的生活") is not None or find_text(t3, "真实经验，有据可循") is not None
        check("A3 注入正证：点「同意并继续」确实生效（排除 A2 是点不动）",
              gone and home, f"弹窗消失={gone} 主界面已加载={home}")

    # A4 登录页复选框默认空白 + 华为按钮 disabled
    t4 = dump()
    banner = find_text(t4, "登录")
    if banner is not None:
        tap(banner)
        time.sleep(3)
        t5 = dump()
        checked, disabled = login_state(t5)
        check("A4 登录页复选框默认空白（明示同意，非默认勾选）",
              checked == "false", f"checkbox.checked={checked}")
        check("A5 未勾选时华为登录按钮节点 enabled=false",
              disabled is True, f"按钮链上含 enabled=false = {disabled}")

        # A6 勾选后翻转
        cb = checkbox(t5)
        tap(cb)
        time.sleep(2)
        t6 = dump()
        checked2, disabled2 = login_state(t6)
        check("A6 勾选后 checked=true 且按钮 enabled 恢复（闸门非死锁）",
              checked2 == "true" and disabled2 is False,
              f"checked={checked2} 含disabled={disabled2}")

        # A7 取消勾选 → 点《隐私政策》读完返回，不得顺带勾选
        cb = checkbox(t6)
        tap(cb)
        time.sleep(1)
        t7 = dump()
        c0, d0 = login_state(t7)
        link = find_text(t7, "《隐私政策》")
        tap(link)
        time.sleep(3)
        t8 = dump()
        on_policy = find_text(t8, "隐私政策") is not None and login_state(t8)[0] is None
        sh([HDC, "-t", DEV, "shell", "uitest uiInput keyEvent Back"])
        time.sleep(3)
        t9 = dump()
        c1, d1 = login_state(t9)
        check("A7 点《隐私政策》读完返回，复选框不被顺带勾选",
              c0 == "false" and c1 == "false",
              f"点前 checked={c0}（按钮disabled={d0}）→ 落在政策页={on_policy} → 返回后 checked={c1}")

        # A8 协议链接本身可点（能真读到政策，不是死链）
        tap(find_text(t9, "《用户协议》"))
        time.sleep(3)
        ta = dump()
        agree_page = find_text(ta, "用户协议") is not None
        check("A8 《用户协议》链接可打开（闸门不挡阅读通路）", agree_page, f"落在用户协议页={agree_page}")
        sh([HDC, "-t", DEV, "shell", "uitest uiInput keyEvent Back"])
    else:
        check("A4 登录页复选框默认空白", False, "首页找不到「登录」入口，后续断言未跑")

    # A9 「不同意」= 退出应用
    sh([HDC, "-t", DEV, "shell", f"bm clean -n {BUNDLE} -d"])
    sh([HDC, "-t", DEV, "shell", f"aa force-stop {BUNDLE}"])
    sh([HDC, "-t", DEV, "shell", f"aa start -a EntryAbility -b {BUNDLE}"])
    time.sleep(7)
    tb = dump()
    dec = find_text(tb, "不同意")
    if dec is not None:
        tap(dec)
        time.sleep(4)
        alive = sh([HDC, "-t", DEV, "shell", f"pidof {BUNDLE}"]).strip()
        check("A9 点「不同意」应用直接退出（拒绝路径可用）", alive == "", f"pidof 返回={alive!r}")
    else:
        check("A9 点「不同意」应用直接退出", False, "清数据后未复现首启弹窗")

    print("\n小结")
    for n, s, d in results:
        print(f"  {s}  {n}")
    fails = [r for r in results if r[1] == "FAIL"]
    print(f"\n{len(results) - len(fails)}/{len(results)} 通过")
    return 1 if fails else 0


if __name__ == "__main__":
    sys.exit(main())
