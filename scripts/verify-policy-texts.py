#!/usr/bin/env python3
"""隐私政策 / 用户协议「四处文本 + 版本常量」一致性闸门。

为什么需要：2026-11-02 实测发现三份副本各自漂移——应用内政策是 V1.2，
公网部署源（AGC 里填的 URL）还停在 V1.0，仓库根又有一份 V1.1 的死副本；
同时线上 .env 的 PRIVACY_POLICY_VERSION=1.0.0 与客户端上报的 1.1.0 不一致，
导致 /v1/auth/privacy-consent 全部 409、库里 142 个账号同意留痕全空。
本脚本把这些正好会踩的坑做成断言。

用法：python3 scripts/verify-policy-texts.py   （非 0 退出 = 有漂移）
"""
import re
import subprocess
import sys

ROOT = '.'
HOSTED_PRIV = 'backend/nginx-static/privacy/index.html'
HOSTED_TERMS = 'backend/nginx-static/terms/index.html'
APP_PRIV = 'entry/src/main/ets/pages/PrivacyPage.ets'
APP_TERMS = 'entry/src/main/ets/pages/UserAgreementPage.ets'
AUTH_ETS = 'entry/src/main/ets/utils/auth.ets'
ENV_TS = 'backend/src/config/env.ts'
ENV_EXAMPLE = 'backend/env.prod.example'
MODULE_JSON = 'entry/src/main/module.json5'

errors = []
notes = []


def read(path):
    with open(path, encoding='utf-8') as f:
        return f.read()


def strip_html(s):
    return re.sub(r'<[^>]+>', '', s)


def need(haystack, needles, label, where):
    missing = [n for n in needles if n not in haystack]
    if missing:
        errors.append(f'{label} 缺 {where}：{missing}')


# ── 1. 应用真正申请的权限，两份政策都必须列全 ──
perms = re.findall(r'"name"\s*:\s*"ohos\.permission\.([A-Z_]+)"', read(MODULE_JSON))
perms = sorted(set(perms))
pub_priv = strip_html(read(HOSTED_PRIV))
app_priv = read(APP_PRIV)
for p in perms:
    for label, text in (('公网政策', pub_priv), ('应用内政策', app_priv)):
        need(text, [p], label, f'实际申请的权限 {p}')
notes.append(f'包内声明权限 {len(perms)} 项：{", ".join(perms)}')

# ── 2. 此前公网漏披露的三项处理活动，现在两份都要有 ──
for label, text in (('公网政策', pub_priv), ('应用内政策', app_priv)):
    need(text, ['剪贴板'], label, '剪贴板处理活动')
    need(text, ['握持'], label, '握持姿态处理活动')
    need(text, ['推送令牌', 'Push Token'], label, '推送标识处理活动')
    need(text, ['ODID'], label, '登录凭据本机加密（设备标识）')
    need(text, ['数据导出'], label, '数据导出行权路径')

# ── 3. 版本常量三处必须一致（客户端 / 后端默认 / 部署模板）──
client_v = re.search(r"PRIVACY_POLICY_VERSION: string = '([^']+)'", read(AUTH_ETS)).group(1)
env_v = re.search(r"privacyPolicyVersion: process\.env\.PRIVACY_POLICY_VERSION \?\? '([^']+)'", read(ENV_TS)).group(1)
example_v = re.search(r'^PRIVACY_POLICY_VERSION=(.+)$', read(ENV_EXAMPLE), re.M).group(1).strip()
if not (client_v == env_v == example_v):
    errors.append(f'隐私政策版本常量三处不一致：客户端 {client_v} / 后端默认 {env_v} / env 模板 {example_v}')
else:
    notes.append(f'版本常量三处一致：{client_v}')

# 政策文本里的版本号要与常量对得上（1.2.0 ↔ V1.2）
expect_tag = 'V' + '.'.join(client_v.split('.')[:2])
for label, text in (('公网政策', pub_priv), ('应用内政策', app_priv)):
    need(text, [expect_tag], label, f'政策文本版本号应为 {expect_tag}')

# ── 4. 明示同意口径：两份协议都不得保留「使用即视为同意」类默示条款 ──
BAD = ['即表示你已阅读', '即表示您已阅读', '即视为接受修订', '继续使用即视为']
for label, path in (('应用内用户协议', APP_TERMS), ('公网用户协议', HOSTED_TERMS),
                    ('应用内隐私政策', APP_PRIV), ('公网隐私政策', HOSTED_PRIV)):
    text = strip_html(read(path))
    hit = [b for b in BAD if b in text]
    if hit:
        errors.append(f'{label} 仍含默示同意措辞：{hit}')
    need(text, ['明示同意'] if '用户协议' in label else ['主动点击', '同意并继续'],
         label, '明示同意表述')

# ── 5. 承诺与实现必须成对：政策说"重新征得同意"，代码里就要有调用点 ──
calls = subprocess.run(
    ['grep', '-rn', 'checkPrivacyUpdate()', 'entry/src/main/ets'],
    capture_output=True, text=True).stdout.strip().splitlines()
def_sites = [c for c in calls if 'private checkPrivacyUpdate' not in c]
pub_terms = strip_html(read(HOSTED_TERMS))
if '重新征得' in pub_priv or '重新征得' in pub_terms:
    if not def_sites:
        errors.append('政策文本承诺「实质性变更重新征得同意」，但 checkPrivacyUpdate() 没有调用点（死代码）')
    else:
        notes.append(f'二次征求已接通：checkPrivacyUpdate() 调用点 {len(def_sites)} 处')

# ── 6. 法定要素抽查（公网政策是 AGC 审核员真正打开的那一页）──
need(pub_priv, ['白逸飞', '2697881905@qq.com', '陕ICP备', '中国境内', '不满 14 周岁',
                '注销', '人民法院提起诉讼'], '公网政策', '法定要素')

# ── 7. 仓库根那份是镜像：必须与部署源逐字节相同，否则就是下一次漂移的种子 ──
# （2026-11-02 之前的状态：部署源 V1.0 / 镜像 V1.1 / 应用内 V1.2，三份各说各话）
MIRROR = 'privacy-policy.html'
if read(MIRROR) != read(HOSTED_PRIV):
    errors.append(f'{MIRROR} 与部署源 {HOSTED_PRIV} 不再逐字节相同 —— 要么同步覆盖，要么删掉镜像并改本脚本')
else:
    notes.append(f'{MIRROR} 与部署源逐字节一致（镜像，非第二份可编辑副本）')

print('')
for n in notes:
    print(f'  · {n}')
print('')
if errors:
    print(f'[失败] {len(errors)} 项漂移：')
    for e in errors:
        print(f'  ✗ {e}')
    sys.exit(1)
print('[通过] 权限清单、处理活动披露、版本常量、明示同意口径、承诺与实现成对 —— 四处文本一致。')
