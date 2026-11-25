---
title: "Docs · superpowers · plans · 2026-11-02-contract-v2-foundation.md"
id: markdown_cls1_798285c88467638f6a8dc28635ad6f33_e227b903fad7c7ec88bcee265cb4f4b77526104239726721
kb: 有径-YouJing
folder: "开发文档"
media_type: 7
tags: []
source: ima
exported_at: 2026-11-23T14:52:37.917Z
---
# 家族契约 v2 与同源基座（P1）实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 把设计契约 DESIGN.md 改成「以有据为参考实现」的 v2，并让有径的 token 层、顶栏材质、阴影模型、动效层、间距命名同时跟上，全程尺子可跑、可回退。

**Architecture:** 契约文本是唯一上游；`design/*.ets` 五个 token 表镜像契约；`tools/audit_*.py` 只遍历**契约侧**做逐值比对（所以「加契约行才可能红、删契约行只会绿」）。本计划按这个不对称性排任务顺序：先改尺与仓库 token，再改契约文本，最后逐页接线。

**Tech Stack:** ArkTS（Stage 模型，target/compatible SDK 26.0.0）、@kit.UIDesignKit（HdsNavigation 标题栏）、@kit.ArkUI（`curves.cubicBezierCurve` 返回 `ICurve`）、hypium（真机 191 例）、Python 3 静态尺（零三方依赖）、hvigor 命令行构建、hdc 真机取证。

**Spec:** [`Docs/家族UI契约对齐方案-2026-11-02.md`](file:///Users/itxiaobai/HarmonyProject2/Docs/家族UI契约对齐方案-2026-11-02.md) §1 硬事实、§2 C1-C8、§3 原子顺序、§4 P1 行、§5 闸门、§6 真机验收；评审结论四项见该文件文首。

**前置条件（硬门槛）：** P2（家族件与 46 处迁移）另开计划。本计划里 T5 只落动效 token 与尺，不落任何页面动画。

## Global Constraints

- **DESIGN.md 不在 git 下**：改前必须 `cp -R` 备份，同级 `有径-设计底稿-v1.zip` 作二次兜底。改完必须同步仓库镜像 `Docs/design-v1/DESIGN.md`（现与原件 IDENTICAL）。
- **原子性**：契约 colors/rounded/spacing/layout/elevation 的值改动，必须与对应 token 表在**同一个提交**内完成（先改哪边都红）。唯一可分步的方向是「先补仓库 token 字段，再往契约加行」。
- **不许发明新档位**：语义别名只能复用契约已有数值；无消费方的字段不新增（契约 `motion` 段 18 项，本计划只落 `press`、`control`、`container`、`shimmer`、`pressScale` 与三条曲线）。
- **只用官方件**：家族件是官方件的封装，本计划不改任何交互语义。
- **不碰 CodeArts 在途文件**：`data/{EntitlementStore,IapStore,DeviceActivator,DeviceTokenStore}.ets`、`pages/PricingPage.ets`（未跟踪），以及 `LlmClient.ets`、`Index.ets`、`MapPage.ets` 等 21 个已改文件属另一会话。T4 需要动 `Index.ets` 与 `MapPage.ets`：**开工前重跑 `git status`，若这两个文件仍带未提交改动就停下来问用户**，不替对方提交、也不把对方改动裹进我的提交。
- **不 push**：每任务一个提交，`git add <pathspec>` 逐文件加，禁止 `git add -A`；`.merkle-snapshot.json` 永不入库。
- **真机纪律**：每次注入点击前重新 dump 断言前台；不解锁、不绕过 `10106102`；设备被真人取走即停手，未验部分写成边界。
- **零 LLM 花费**：本计划不触发真模型调用，验收走 mock 通道。
- **证据先于结论**：尺未跑、复拍未做一律标 `[待验证]`，不许用「应该没问题」过关。
- **设备密度 3.125**：真机像素除以 3.125 才是 vp，别把换算误差当实现偏差。

---

## File Structure

| 文件 | 职责 | 本计划动作 |
| --- | --- | --- |
| `~/Pictures/有径/有径-设计底稿-v1/docs/DESIGN.md` | 家族契约文本（唯一上游） | 改 5 处（T1） |
| `Docs/design-v1/DESIGN.md` | 契约的仓库镜像（尺读原件，镜像供人读） | 与原件同步（T1） |
| `entry/src/main/ets/design/ShadowTokens.ets` | 投影档 | 五档改六档重命名 + `none`（T2） |
| `entry/src/main/resources/{base,dark}/element/color.json` | 色值 51 条 | 加 `bar_shadow` 成对（T2） |
| `entry/src/main/ets/design/ColorTokens.ets` | 色单点出口 | 加 `barShadow`（T2） |
| `entry/src/main/ets/design/HdsChrome.ets` | 顶栏材质单点 | 半径 24→50 + `scrollEffectStyle` + `scrollable`（T3） |
| `entry/src/main/ets/pages/*.ets`（18 个） | 滚动状态供给 | 传 `scrolled` 或表态 `scrollable: false`（T4） |
| `entry/src/main/ets/design/MotionTokens.ets` | 动效 token | 全文重写 + `MotionCurves`（T5） |
| `entry/src/main/ets/design/SpaceTokens.ets` | 间距档 | 契约名三段迁移（T6） |
| `tools/audit_elevation.py` / `audit_material.py` / `audit_geometry.py` / `audit_fontfamily.py` | 读契约的尺 | 反转 / 加严 / 恒等 / 真读（T2、T3、T6、T7） |
| `tools/audit_motion.py` | 新尺 | 创建（T5） |
| `entry/src/ohosTest/ets/test/StyleConfig.test.ets` | 设计 token 断言所在套件（已在 `List.test.ets` 注册） | 加 3 个 describe/it（T2、T5、T6） |
| `Docs/INIT_REPORT.md:1867` / `README.md:23,39,74` / `CHANGELOG.md` | 规矩文本 | 改写「契约不可改」句 + 尺数校正（T8） |

---

### Task 1: 契约备份与 DESIGN.md v2 文本改动

**Files:**
- Create: `~/Pictures/有径/有径-设计底稿-v1.bak-2026-11-02/`
- Modify: `~/Pictures/有径/有径-设计底稿-v1/docs/DESIGN.md`（239 / 271-276 / 1048-1055）
- Modify: `Docs/design-v1/DESIGN.md`

**Interfaces:**
- Produces: 契约 v2 文本，是 T2/T3/T5/T6 的比对基准。

- [ ] **Step 1: 备份并记录回退基准**

```bash
cp -R ~/Pictures/有径/有径-设计底稿-v1 ~/Pictures/有径/有径-设计底稿-v1.bak-2026-11-02
ls ~/Pictures/有径/有径-设计底稿-v1.bak-2026-11-02/docs/DESIGN.md
md5 -q ~/Pictures/有径/有径-设计底稿-v1/docs/DESIGN.md
```

预期：备份文件存在；记下这个 md5（回退基准）。

- [ ] **Step 2: 改玻璃半径（239 行）并加门控声明**

`  glass-blur: "24"` 改为 `  glass-blur: "50"`，其后新增一行（引号必须留着，`audit_geometry.py:67` 按带引号解析）：

```yaml
  glass-bar-scroll-gated: "true"
```

- [ ] **Step 3: `elevation:` YAML 段（271-276）整段替换为六档 + none**

保持顶格 `elevation:`、两空格缩进：

```yaml
elevation:
  none: "0px 0px 0px 0px rgba(0,0,0,0)"
  cardContact: "0px 0px 1px 0px rgba(0,0,0,0.03)"
  cardAmbient: "0px 3px 10px 0px rgba(0,0,0,0.07)"
  floating: "0px 6px 16px 0px rgba(0,0,0,0.09)"
  pillFloat: "0px 3px 8px 0px rgba(0,0,0,0.15)"
  segmented: "0px 0px 8px 0px rgba(0,0,0,0.06)"
  popover: "0px 0px 8px 0px rgba(0,0,0,0.07)"
```

- [ ] **Step 4: 正文 §Elevation 三条 bullet（1048-1050）与深色句（1053）**

`audit_elevation.py:63` 是从正文散文按正则取值的，必须保持「反引号档名 + 括号里 `Npx blur, Npx y, N% black` 三件齐全」。逐行替换为：

```text
- `cardContact` (1px blur, 0px y, 3% black): the crisp edge under a card; never alone.
- `cardAmbient` (10px blur, 3px y, 7% black): itinerary cards, summary card, sheets — layered under `cardContact` by two nested containers, since ArkUI renders one shadow layer per node.
- `floating` (16px blur, 6px y, 9% black): sheets, popovers, the dock.
- `pillFloat` (8px blur, 3px y, 15% black): floating pills and drag-elevated rows.
```

1053 行整句替换：

```text
Shadow is black-with-alpha, which is theme-neutral: it stays in dark mode and must not carry a zeroing branch. Only large-area drops (`bar_shadow`) are promoted to a paired resource (light `#2E1A1A1E`, dark `#8C000000`).
```

**「When system material (沉浸光感) is active, the surface must zero out its own background, border, and shadow」这条不动** —— 那是材质门控（`glassOn`），不是深浅门控，v2 保留。

- [ ] **Step 5: §Translucency（1055 段）里的 blur 数字与门控说明**

`blur 24` 改 `blur 50`，同段补一句：

```text
The bar surface is gated by the **absolute** scroll offset (`scrolled ? 50 : 0`), never by per-frame delta, because a spring-back negative delta turns the blur off at rest.
```

- [ ] **Step 6: `components:` 段补双层卡与按压件（C3），并新增 `transitions:` 段（C5）**

在 `components.card:` 子树（296 行起）内补三行，值全部复用已命名档位，不产生新数字：

```yaml
  card:
    backgroundColor: "{colors.surface-elevated}"
    textColor: "{colors.body}"
    typography: "{typography.hierarchy.body}"
    rounded: "{rounded.lg}"
    padding: "16px"
    innerGap: "12px"
    elevation: "{elevation.cardAmbient}"
    contactLayer: "{elevation.cardContact}"
    hairline: "1px solid {colors.separator}"
    shadowStack: "two nested containers — outer cardAmbient, inner cardContact; ArkUI renders one shadow layer per node"
```

在 `components:` 内新增按压件：

```yaml
  pressable:
    pressedOpacity: "{motion.press-opacity}"
    pressedScale: "{motion.press-scale}"
    duration: "{motion.press}"
    curve: "{motion.curve-standard}"
    touchTarget: "{layout.min-touch-target}"
    note: "stateStyles must be preceded by .animation() in the chain, otherwise the press has no transition"
```

在 YAML 末尾（`components:` 之后、正文 `---` 之前）新增转场段：

```yaml
transitions:
  page-enter: "opacity 220ms + translate{x:12px} 240ms"
  page-fade: "opacity 380ms, decelerate, delay 60ms"
  feed-stagger-step: "{motion.stagger}"
  long-take: "350ms, radius 16px -> 24px"
  snapshot-handover: "min 300ms, max 1500ms"
```

`page-fade` / `long-take` / `snapshot-handover` 三行是 P3 的规格来源，本计划只把它们写进契约、不实现（实现无消费方不等于声明无消费方）。

- [ ] **Step 7: 同步底稿两份文档里被改动的具体值（评审结论 3）**

`youjing-stitch-prompts.md` 有 5 处提到 `blur 24` / `glass-blur`（行 229、374、843、1252、1556），`youjing-engineering-handoff.md` 0 处。只改**数值**，不动叙述：

```bash
D=~/Pictures/有径/有径-设计底稿-v1/docs
cp "$D/youjing-stitch-prompts.md" "$D/youjing-stitch-prompts.md.bak-2026-11-02"
perl -pi -e 's/blur 24\b/blur 50/g; s/blur\(24px\)/blur(50px)/g; s/一律 `blur\(50px\)`（`layout\.glass-blur`）/一律 `blur(50px)`（`layout.glass-blur`）/;' "$D/youjing-stitch-prompts.md"
grep -c 'blur 50\|blur(50px)' "$D/youjing-stitch-prompts.md"
grep -n 'blur 24\|blur(24px)' "$D/youjing-stitch-prompts.md"
```

预期：前者 ≥5，后者 **0**。第 1556 行那句「三处、四处、五处在一个文件里并存」的历史记录**保留原样**（它记的是当时的口径混乱事实，不是当前规格），只把它给出的结论数值 24 换成 50。

**不碰 `frames/*/code.html`**：那 39 帧是 v1 视觉留档，且底稿自带的 `tools/audit.sh:6` 读的是另一份 `~/Documents/StitchDesign/DESIGN.md`（审 frames 用），改 frames 等于重切设计稿，属产品负责人的单独动作，不在本计划内。

- [ ] **Step 8: 同步仓库镜像并核对**


```bash
cp ~/Pictures/有径/有径-设计底稿-v1/docs/DESIGN.md Docs/design-v1/DESIGN.md
md5 -q ~/Pictures/有径/有径-设计底稿-v1/docs/DESIGN.md Docs/design-v1/DESIGN.md
grep -c 'glass-blur: "50"' Docs/design-v1/DESIGN.md
```

预期：两个 md5 相同；命中 1。

镜像目录名保留 `design-v1`（历史路径，`Docs/design-v1/README.md` 被别处引用过），只把它的说明改成 v2 事实：

```bash
python3 - <<'INNER'
p='Docs/design-v1/README.md'
s=open(p,encoding='utf-8').read()
s=s.replace('# design-v1 · 设计底稿快照（2026-10-26）',
            '# design-v1 · 设计底稿快照（2026-11-02 起随契约 v2 更新）')
s=s.replace('> 本目录是「有径-设计底稿 v1」三份契约文档的**只读快照**，防仓库外单点丢失。',
            '> 本目录是家族契约文档的**镜像快照**，防仓库外单点丢失；目录名沿用 design-v1 是历史路径，正文自 2026-11-02 起为契约 v2（以有据为参考实现）。')
open(p,'w',encoding='utf-8').write(s)
INNER
grep -n "契约 v2" Docs/design-v1/README.md
```

预期：命中 2 行。

- [ ] **Step 9: 提交**

```bash
git add Docs/design-v1/DESIGN.md
git commit -m "docs(契约): DESIGN.md 升 v2——玻璃 50、深色保留阴影、投影拆六档"
```

（原件在 `~/Pictures`，不进仓库；备份留在那边。）

---

### Task 2: 投影模型反转（token + 资源 + 尺 + 删深色分支，一个提交）

**Files:**
- Modify: `entry/src/main/ets/design/ShadowTokens.ets:14-39`
- Modify: `entry/src/main/resources/base/element/color.json`、`.../dark/element/color.json`（各 51 → 52）
- Modify: `entry/src/main/ets/design/ColorTokens.ets`
- Modify: `pages/TripsPage.ets:327`、`pages/StayPickPage.ets:363`、`pages/MapPage.ets:416`、`pages/EditItineraryPage.ets:328`
- Modify: `tools/audit_elevation.py:32-36,42,135-138`
- Test: `entry/src/ohosTest/ets/test/StyleConfig.test.ets`

**Interfaces:**
- Consumes: T1 的契约六档名与值。
- Produces: `ShadowTokens.none/cardContact/cardAmbient/floating/pillFloat/segmented/popover`（`ElevationSpec`），`ColorTokens.barShadow: ResourceColor`。P2 的双层 `BaseCard` 直接引用这两个档名。

- [ ] **Step 1: 先改尺认新档名（此步必红，属预期）**

`tools/audit_elevation.py:32-36`：

```python
CONTRACT = {'cardContact': (1, 0, 3), 'cardAmbient': (10, 3, 7),
            'floating': (16, 6, 9), 'pillFloat': (8, 3, 15)}
```

`:63` 的提取正则扩档名：

```python
for m in re.finditer(r'`(cardContact|cardAmbient|contact|card|floating|pillFloat)` \(([^)]*)\)', txt):
```

`segmented`/`popover` 继续走原 `AMBIENT` 分支（无偏移），不进 bullet 提取。

- [ ] **Step 2: 反转「深色必须归零」判据**

`:42` 的 `GATE` 与 `:135-138` 的判据改为「禁止深浅门控、允许材质门控」：

```python
THEME_GATE = re.compile(r'isDark|ColorMode|colorMode')
MATERIAL_GATE = re.compile(r'glassOn|isSystemMaterialActive')
# 循环体
window = '\n'.join(lines[max(0, i - 2):i + 3])
if THEME_GATE.search(window):
    fails.append(f'[深色仍归零] {rel}:{i+1} .shadow( 带深浅门控（契约 v2：黑 alpha 阴影主题中性）')
elif 'radius: 0' in window and not MATERIAL_GATE.search(window):
    fails.append(f'[无门控归零] {rel}:{i+1} .shadow( 出现 radius:0 却无材质门控')
```

- [ ] **Step 3: 给这把尺补 `--selftest`（防「0 命中假绿」，项目已踩两次）**

```python
SELFTEST_BAD = '  .shadow(this.isDark ? { radius: 0 } : ShadowTokens.cardAmbient)\n'
SELFTEST_OK = '  .shadow(ShadowTokens.cardAmbient)\n'
```

断言 `scan(SELFTEST_BAD)` 命中 `[深色仍归零]`、`scan(SELFTEST_OK)` 命中 0。命令与预期：

```bash
python3 tools/audit_elevation.py --selftest    # 期望 [selftest] pass
```

- [ ] **Step 4: 改 ShadowTokens**

```typescript
export interface ShadowTokensType {
  none: ElevationSpec;
  /** 卡片下沿实边，与 cardAmbient 分两层叠加 */
  cardContact: ElevationSpec;
  /** 行程卡 / 摘要卡的环境影 */
  cardAmbient: ElevationSpec;
  /** dock / 弹层 / 拖动中的行 */
  floating: ElevationSpec;
  /** 悬浮药丸 */
  pillFloat: ElevationSpec;
  /** 分段控件轨道 */
  segmented: ElevationSpec;
  /** 浮层菜单 */
  popover: ElevationSpec;
}

export const ShadowTokens: ShadowTokensType = {
  none: { radius: 0, offsetX: 0, offsetY: 0, color: '#00000000' },
  cardContact: { radius: 1, offsetX: 0, offsetY: 0, color: '#08000000' },
  cardAmbient: { radius: 10, offsetX: 0, offsetY: 3, color: '#12000000' },
  floating: { radius: 16, offsetX: 0, offsetY: 6, color: '#18000000' },
  pillFloat: { radius: 8, offsetX: 0, offsetY: 3, color: '#26000000' },
  segmented: { radius: 8, offsetX: 0, offsetY: 0, color: '#0F000000' },
  popover: { radius: 8, offsetX: 0, offsetY: 0, color: '#12000000' }
};
```

`floating` 的 alpha 由 `#17` 改 `#18`（对齐有据 9.4%，契约散文写 9%）。尺的 alpha 容差是 ±1 个百分点（`:100`），`round(24/255*100)=9` 仍命中。

- [ ] **Step 5: 加 `bar_shadow` 成对资源与 token 字段**

`base/element/color.json` 数组尾部：

```json
    { "name": "bar_shadow", "value": "#2E1A1A1E" }
```

`dark/element/color.json` 同位置：

```json
    { "name": "bar_shadow", "value": "#8C000000" }
```

`ColorTokens.ets`：

```typescript
  /** 大面积落影：契约 v2 里唯一按深浅成对的阴影色 */
  static readonly barShadow: ResourceColor = $r('app.color.bar_shadow');
```

- [ ] **Step 6: 删 4 处深色归零分支**

```bash
grep -n "this.isDark ? { radius: 0 }" entry/src/main/ets/pages/*.ets
```

`TripsPage.ets:327`、`StayPickPage.ets:363` → `.shadow(ShadowTokens.cardAmbient)`；`MapPage.ets:416`、`EditItineraryPage.ets:328` → `.shadow(ShadowTokens.floating)`。改完这 4 个文件里 `isDark` 若无其它用途，删掉各自的 `@StorageProp('isDarkMode')`（`TripsPage.ets:70`、`StayPickPage.ets:54`、`EditItineraryPage.ets:48`、`MapPage.ets:70`）。**`ItineraryPage.ets:54` 的 `isDark` 必须保留** —— 它在 794-795 行做材质门控，合法。

- [ ] **Step 7: 收拾旧档名引用**

```bash
grep -rn "ShadowTokens\.\(contact\|card\)" entry/src/main/ets
```

命中处按语义改 `cardAmbient`（需要实边的双层等 P2）。

- [ ] **Step 8: hypium 断言 token 镜像契约**

`StyleConfig.test.ets` 内新增（并补 import）：

```typescript
import { ShadowTokens } from '../../../main/ets/design/ShadowTokens';

  describe('ShadowTokensV2', () => {
    it('tiers_match_contract', TestType.FUNCTION | Size.SMALLTEST | Level.LEVEL0, () => {
      expect(ShadowTokens.cardContact.radius).assertEqual(1);
      expect(ShadowTokens.cardAmbient.offsetY).assertEqual(3);
      expect(ShadowTokens.floating.color).assertEqual('#18000000');
      expect(ShadowTokens.pillFloat.radius).assertEqual(8);
      expect(ShadowTokens.none.radius).assertEqual(0);
    });
  });
```

`List.test.ets` 已 `import styleConfigTest`，无需再注册。

- [ ] **Step 9: 跑尺 + 构建**

```bash
python3 tools/audit_elevation.py
DEVECO_SDK_HOME=/Applications/DevEco-Studio.app/Contents/sdk \
  /Applications/DevEco-Studio.app/Contents/tools/node/bin/node \
  /Applications/DevEco-Studio.app/Contents/tools/hvigor/bin/hvigorw.js \
  --mode module -p module=entry@default assembleHap -p buildMode=debug --no-daemon
grep -c '"name"' entry/src/main/resources/base/element/color.json
```

预期：`投影偏差 0 处`、`BUILD SUCCESSFUL`、`52`。`audit_colors.py` 会把 `bar_shadow` 归入「契约未直接命名」跳过清单且退出 0。

- [ ] **Step 10: 提交**

```bash
git add entry/src/main/ets/design/ShadowTokens.ets entry/src/main/ets/design/ColorTokens.ets \
        entry/src/main/resources/base/element/color.json entry/src/main/resources/dark/element/color.json \
        entry/src/main/ets/pages/TripsPage.ets entry/src/main/ets/pages/StayPickPage.ets \
        entry/src/main/ets/pages/MapPage.ets entry/src/main/ets/pages/EditItineraryPage.ets \
        tools/audit_elevation.py entry/src/ohosTest/ets/test/StyleConfig.test.ets
git commit -m "feat(契约v2): 投影拆六档并取消深色归零——bar_shadow 成对、尺反转判据加自测"
```

---

### Task 3: 顶栏模糊 50 + 两态样式（HdsChrome 单点）

**Files:**
- Modify: `entry/src/main/ets/design/HdsChrome.ets:36-37,66-96`
- Modify: `tools/audit_material.py:184-204`

**Interfaces:**
- Consumes: 契约 `glass-blur: "50"`、`glass-bar-scroll-gated: "true"`。
- Produces: `ChromeSpec` 新增可选字段 `scrollable?: boolean`（缺省视为 true）；`HdsChrome.bar(spec): HdsNavigationTitleBarOptions` 签名不变。

- [ ] **Step 1: 先把尺加严（预期红 2 条）**

`audit_material.py` 的 `check_blur_value`：把 `:200` 与 `:203` 的 `notes.append` 改成 `fails.append`，并新增两态判据：

```python
if 'IMMERSIVE_GRADIENT_BLUR' in chrome and 'scrollEffectStyle:' not in chrome:
    fails.append('[两态缺失] HdsChrome 用 IMMERSIVE_GRADIENT_BLUR 却没写 scrollEffectStyle')
```

```bash
python3 tools/audit_material.py
```

预期红：`[半径] BAR_BLUR_RADIUS=24 契约是 50` + `[两态缺失]`。

- [ ] **Step 2: 改 HdsChrome**

```typescript
/** 滚动后栏体磨砂半径（vp）：契约 layout.glass-blur = 50，四点位同一把尺 */
const BAR_BLUR_RADIUS: number = 50;
```

`ChromeSpec` 加字段：

```typescript
  /** 本页是否存在可滚容器；false 时关滚动特效，避免静止态空糊 */
  scrollable?: boolean;
```

`bar()` 内两处调整：

```typescript
    const scrollEffect: ScrollEffectOptions = {
      enableScrollEffect: spec.scrollable !== false,
      scrollEffectType: ScrollEffectType.IMMERSIVE_GRADIENT_BLUR,
      blurEffectiveStartOffset: LengthMetrics.vp(0),
      blurEffectiveEndOffset: LengthMetrics.vp(endVp)
    };
    const style: TitleBarStyleOptions = {
      scrollEffectOpts: scrollEffect,
      originalStyle: originalStyle,
      scrollEffectStyle: { contentStyle: contentStyle }
    };
```

- [ ] **Step 3: 分段控件的 blur 跟着走还是留 24，必须先判一件事**

契约 `segmented-control` 写的是 `blur: "{layout.glass-blur}"`（引用同一 token），所以契约改 50 后它**自动变 50**。但 `prompts.md:843` 记着一条历史例外（帧里曾出现 `blur(20px)`，2026-10 已统一成 24）。做法：

```bash
grep -n "blur" entry/src/main/ets/components/ImmersiveSegmentBar.ets
```

- 若命中 `backgroundBlurStyle(BlurStyle.COMPONENT_*)` 或 `blurRadius(数字)`：**该处不受 `layout.glass-blur` 支配**（分段栏是官方 BlurStyle，不是 HDS blurRadius），保持现状不动，并在 `Docs/INIT_REPORT.md` §5ci 记一句「契约 glass-blur 只支配顶栏/dock 的 blurRadius 路径」。
- 若命中 `BAR_BLUR_RADIUS` 或引用 `HdsChrome` 常量：随 T3 一起变 50，不许留 24。

判完再动下一步，别默认「跟契约走」。

- [ ] **Step 4: 跑尺 + 构建**

```bash
python3 tools/audit_material.py && echo MATERIAL_OK
```

预期 `材质偏差 0 处`。此时 `scrolled` 还没人传，实际模糊仍为 0 —— 属预期中间态，T4 接上。

- [ ] **Step 5: 提交**

```bash
git add entry/src/main/ets/design/HdsChrome.ets tools/audit_material.py
git commit -m "feat(契约v2): 顶栏模糊对齐有据 50 并补 scrollEffectStyle 两态，半径判据由 note 升为 fail"
```

---

### Task 4: 18 个页面表态滚动状态（`scrolled` 今天全仓无人传）

**Files:**
- Modify（16 个有滚动容器，`bar:` 行号即调用点）：`AreaMorePage.ets:256`、`BadgePage.ets:304`、`EditItineraryPage.ets:624`、`ExpensePage.ets:977`、`GenerateFailedPage.ets:230`、`ItineraryPage.ets:1386`、`MinePage.ets:321`、`OnTripPage.ets:1087`、`PreferenceQAPage.ets:238`、`SharePage.ets:355`、`SpotPickPage.ets:416`、`StayPickPage.ets:213`、`TripInputPage.ets:996`、`TripReviewPage.ets:627`、`TripsPage.ets:528`、`MapPage.ets:180`
- Modify（只表态不接线）：`GeneratingPage.ets:264`
- 跳过并登记：`PricingPage.ets:168`（CodeArts 未跟踪）

**Interfaces:**
- Consumes: T3 的 `ChromeSpec.scrolled` / `scrollable`。
- Produces: 每页 `@State barScrolled: boolean` + `private barScroller: Scroller`（已有 scroller 的页面复用现有变量）。

- [ ] **Step 0: 撞车检查**

```bash
git status --short entry/src/main/ets/pages/MapPage.ets entry/src/main/ets/pages/Index.ets
```

若两文件仍带未提交改动 → 停下问用户，不裹对方改动。

- [ ] **Step 1: 每页加三件（模板）**

```typescript
  @State barScrolled: boolean = false;
  private barScroller: Scroller = new Scroller();

  // 模糊开关必须由绝对滚动偏移驱动：每帧增量正负会被松手回弹的负帧打灭（有据 2026-10-24 根因）
  private syncBarScroll(): void {
    const y: number = this.barScroller.currentOffset().yOffset;
    const on: boolean = y > 0;
    if (on !== this.barScrolled) {
      this.barScrolled = on;
    }
  }
```

挂到该页主滚动件（容器行号见上表 Files）：

```typescript
    List({ scroller: this.barScroller })
      .onDidScroll((): void => { this.syncBarScroll(); })
```

`Refresh` 包着的页面（`TripsPage.ets:469` 容器是 `Refresh`+`List`）把 scroller 给内层 `List`。`Scroll` 型页面用 `Scroll({ scroller: this.barScroller })`。

- [ ] **Step 2: 已有 Scroller 的两页复用**

`ItineraryPage.ets`（4 处）与 `MapPage.ets`（3 处）不新建实例：对**该页主滚动件已用的 scroller 变量**调 `currentOffset()`。`MapPage` 是地图底图，传 `scrollable: false` 且不动 `TopStrip` 跟随逻辑（已验收项）。

- [ ] **Step 3: `GeneratingPage` 关特效**

无滚动容器 → `HdsChrome.bar({ ..., scrollable: false })`。

- [ ] **Step 4: `PricingPage` 登记不接**

在 `Docs/INIT_REPORT.md` §5ci 末尾追加一行：「`PricingPage` 顶栏未表态 `scrollable`，待 CodeArts 侧提交后补」。

- [ ] **Step 5: 机检（不靠肉眼）**

```bash
grep -rn "HdsChrome.bar(" entry/src/main/ets/pages \
  | grep -v "scrolled\|scrollable" | wc -l
```

预期 `0`：每个调用点要么传 `scrolled`，要么表态 `scrollable: false`。

- [ ] **Step 6: 构建、装机、真机两帧对比**

```bash
DEVECO_SDK_HOME=/Applications/DevEco-Studio.app/Contents/sdk \
  /Applications/DevEco-Studio.app/Contents/tools/node/bin/node \
  /Applications/DevEco-Studio.app/Contents/tools/hvigor/bin/hvigorw.js \
  --mode module -p module=entry@default assembleHap -p buildMode=debug --no-daemon
HDC=/Applications/DevEco-Studio.app/Contents/sdk/default/openharmony/toolchains/hdc
$HDC install -r entry/build/default/outputs/default/entry-default-signed.hap
$HDC shell "aa start -b com.youjing.app -a EntryAbility"
$HDC shell uitest dumpLayout -p /data/local/tmp/a.json && $HDC file recv /data/local/tmp/a.json /tmp/a.json
$HDC shell "snapshot_display -f /data/local/tmp/t0.jpeg" && $HDC file recv /data/local/tmp/t0.jpeg /tmp/bar-t0.jpeg
$HDC shell "uitest uiInput fling 540 1600 540 900 800"
$HDC shell "snapshot_display -f /data/local/tmp/t1.jpeg" && $HDC file recv /data/local/tmp/t1.jpeg /tmp/bar-t1.jpeg
```

判定：`bar-t0` 顶栏带与画布同亮（未开模糊），`bar-t1` 顶栏内容透出且发糊。**两张图都要人眼看过**，不许只比数值。深浅两档各跑一次，钉完 `setColorMode` 验完还原。

- [ ] **Step 7: 提交**

```bash
git add entry/src/main/ets/pages/<逐个文件>
git commit -m "feat(契约v2): 16 页接上绝对偏移滚动门控——顶栏模糊首次真正出图"
```

---

### Task 5: 动效 token 落契约（含 `ICurve`）+ 新尺 `audit_motion.py`

**Files:**
- Modify: `entry/src/main/ets/design/MotionTokens.ets`（全文重写）
- Create: `tools/audit_motion.py`
- Test: `entry/src/ohosTest/ets/test/StyleConfig.test.ets`

**Interfaces:**
- Produces: `MotionTokens.press/control/container/shimmer/pressScale`（number）、`MotionCurves.standard/decelerate/linear`（`ICurve`）。P2 的 `BaseCard`/`Pressable` 与 P3 的转场工厂直接引用。

- [ ] **Step 1: 重写 MotionTokens**

```typescript
import { curves } from '@kit.ArkUI';

export interface MotionTokensType {
  press: number;
  control: number;
  container: number;
  shimmer: number;
  pressScale: number;
}

export const MotionTokens: MotionTokensType = {
  press: 140,
  control: 220,
  container: 320,
  shimmer: 1200,
  pressScale: 0.97
};

/** 契约 curve-standard = cubic-bezier(0.2, 0.8, 0.2, 1)。ArkTS 的 Curve 是枚举，
 *  自定义贝塞尔必须走 curves.cubicBezierCurve 返回 ICurve（有据 motion.ets:32 已在用）。 */
export class MotionCurves {
  static readonly standard: ICurve = curves.cubicBezierCurve(0.2, 0.8, 0.2, 1);
  static readonly decelerate: ICurve = curves.cubicBezierCurve(0, 0, 0.2, 1);
  static readonly linear: ICurve = curves.cubicBezierCurve(0, 0, 1, 1);
}
```

删除 `durationFast 100`、`durationBase 200`、`durationSlow 300`、`curveStandard: Curve`、`curveDecelerate: Curve`（实测 `MotionTokens` 全仓零消费方，改值改名无用户可见影响）。

- [ ] **Step 2: 新尺（先写失败样本）**

创建 `tools/audit_motion.py`：

```python
#!/usr/bin/env python3
# 动效尺：时长/曲线只准走 MotionTokens/MotionCurves；.animation() 必须挂在 .stateStyles() 之前。
import os, re, sys

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'entry', 'src', 'main', 'ets')
SELF_BAD = ('  .animation({ duration: 180, curve: Curve.EaseInOut })\n'
            '  .stateStyles({ normal: { .opacity(1) } })\n')
SELF_OK = ('  .animation({ duration: MotionTokens.press, curve: MotionCurves.standard })\n'
           '  .stateStyles({ normal: { .opacity(1) } })\n')
SKIP = ('design/MotionTokens.ets',)

def scan(text):
    hits = []
    lines = text.split('\n')
    for i, ln in enumerate(lines):
        if re.search(r'duration:\s*\d', ln):
            hits.append(f'[裸时长] L{i+1}: {ln.strip()}')
        if re.search(r'curve:\s*Curve\.', ln):
            hits.append(f'[枚举曲线] L{i+1}: {ln.strip()}')
        if '.stateStyles(' in ln:
            j = i - 1
            prev = ''
            while j >= 0 and lines[j].lstrip().startswith('.'):
                prev = lines[j].strip()
                break
            if not prev.startswith('.animation('):
                hits.append(f'[顺序] L{i+1}: .stateStyles 前一行不是 .animation')
    return hits
```

`main()` 遍历 `ROOT` 下 `.ets`（跳过 `SKIP`），`--selftest` 断言 `scan(SELF_BAD)` 命中 >=3 且 `scan(SELF_OK)` 命中 0。

```bash
python3 tools/audit_motion.py --selftest && python3 tools/audit_motion.py
```

预期：selftest pass；全仓 0 命中（今天全站无动画）。

- [ ] **Step 3: hypium 断言**

```typescript
import { MotionTokens } from '../../../main/ets/design/MotionTokens';

    it('motion_tiers_match_contract', TestType.FUNCTION | Size.SMALLTEST | Level.LEVEL0, () => {
      expect(MotionTokens.press).assertEqual(140);
      expect(MotionTokens.control).assertEqual(220);
      expect(MotionTokens.container).assertEqual(320);
      expect(MotionTokens.shimmer).assertEqual(1200);
    });
```

- [ ] **Step 4: 构建 + 提交**

```bash
git add entry/src/main/ets/design/MotionTokens.ets tools/audit_motion.py entry/src/ohosTest/ets/test/StyleConfig.test.ets
git commit -m "feat(契约v2): 动效 token 落契约五档并新增动效尺——含 ICurve 自定义贝塞尔"
```

---

### Task 6: 间距档改成契约名（三段式，全程零像素）

**Files:**
- Modify: `entry/src/main/ets/design/SpaceTokens.ets:22-57`
- Modify: 18 个 pages + components 内全部 `SpaceTokens.*` 触点
- Modify: `tools/audit_geometry.py:32-33`

**Interfaces:**
- Consumes: 契约 `spacing` 八档 `xxs4 xs8 sm12 base16 md20 lg24 xl32 xxl48`。
- Produces: `SpaceTokens.xxs/xs/sm/base/md/lg/xl/xxl` + `itemGap/blockGap/sectionGap/pagePadding/pagePaddingWide/gridGutter` + `bottomReserve`。P2 家族件按语义名引用。

- [ ] **Step 1: 一次性把旧阶梯改名让位 + 加契约名（同提交，否则新旧 `md` 同名不同值）**

```typescript
export const SpaceTokens: SpaceTokensType = {
  xxs: 4, xs: 8, sm: 12, base: 16, md: 20, lg: 24, xl: 32, xxl: 48,
  itemGap: 12, blockGap: 16, sectionGap: 24, pagePadding: 16, pagePaddingWide: 20, gridGutter: 12,
  bottomReserve: 94
};
```

迁移期临时保留 `legacyXs=4 legacySm=8 legacyMd=12 legacyLg=16 legacyXl=24 legacyTwoXl=20 legacyFourXl=32 legacyFiveXl=48` 八个字段，**Step 3 后必须删净**（`lgLoose=18`、`threeXl=28` 是零消费方，直接删，不进 legacy）。

- [ ] **Step 2: 触点先指向 legacy（纯改名，零像素）**

```bash
cd entry/src/main/ets
grep -rl "SpaceTokens\.\(xs\|sm\|md\|lg\|xl\|twoXl\|fourXl\|fiveXl\|lgLoose\|threeXl\)" \
  pages components design utils | while read f; do
  perl -pi -e 's/SpaceTokens\.lgLoose\b/SpaceTokens.base/g;
               s/SpaceTokens\.threeXl\b/SpaceTokens.lg/g;
               s/SpaceTokens\.xs\b/SpaceTokens.legacyXs/g;
               s/SpaceTokens\.sm\b/SpaceTokens.legacySm/g;
               s/SpaceTokens\.md\b/SpaceTokens.legacyMd/g;
               s/SpaceTokens\.lg\b/SpaceTokens.legacyLg/g;
               s/SpaceTokens\.xl\b/SpaceTokens.legacyXl/g;
               s/SpaceTokens\.twoXl\b/SpaceTokens.legacyTwoXl/g;
               s/SpaceTokens\.fourXl\b/SpaceTokens.legacyFourXl/g;
               s/SpaceTokens\.fiveXl\b/SpaceTokens.legacyFiveXl/g;' "$f"
done
grep -rc "SpaceTokens\.legacy" pages components design utils | awk -F: '{s+=$2} END {print "legacy 触点:", s}'
python3 tools/audit_geometry.py
```

预期：`核对结果：偏差 0 项`（`SPACE_ALIAS` 此刻仍指向 legacy 字段，所以绿）。

- [ ] **Step 3: legacy → 契约名（值一一对应，仍零像素）**

| 旧 | 值 | 新 |
| --- | --- | --- |
| `legacyXs` | 4 | `xxs` |
| `legacySm` | 8 | `xs` |
| `legacyMd` | 12 | `sm` |
| `legacyLg` | 16 | `base` |
| `legacyTwoXl` | 20 | `md` |
| `legacyXl` | 24 | `lg` |
| `legacyFourXl` | 32 | `xl` |
| `legacyFiveXl` | 48 | `xxl` |

```bash
grep -rl "SpaceTokens\.legacy" pages components design utils | while read f; do
  perl -pi -e 's/SpaceTokens\.legacyXs\b/SpaceTokens.xxs/g; s/SpaceTokens\.legacySm\b/SpaceTokens.xs/g;
               s/SpaceTokens\.legacyMd\b/SpaceTokens.sm/g; s/SpaceTokens\.legacyLg\b/SpaceTokens.base/g;
               s/SpaceTokens\.legacyTwoXl\b/SpaceTokens.md/g; s/SpaceTokens\.legacyXl\b/SpaceTokens.lg/g;
               s/SpaceTokens\.legacyFourXl\b/SpaceTokens.xl/g; s/SpaceTokens\.legacyFiveXl\b/SpaceTokens.xxl/g;' "$f"
done
grep -rn "SpaceTokens\.legacy" pages components design utils | wc -l
```

预期 `0`。

- [ ] **Step 4: 删 legacy 字段 + 收 `ALLOWED_SPACINGS`**

`SpaceTokensType` 与常量里删净 8 个 legacy 字段；白名单改为：

```typescript
/** 允许间距封闭集 = 契约 spacing 八档 + 0 + 底部预留 94（尺用） */
export const ALLOWED_SPACINGS: number[] = [0, 4, 8, 12, 16, 20, 24, 32, 48, 94];
```

- [ ] **Step 5: `SPACE_ALIAS` 恒等化**

`audit_geometry.py:32-33`：

```python
SPACE_ALIAS = {'xxs': 'xxs', 'xs': 'xs', 'sm': 'sm', 'base': 'base',
               'md': 'md', 'lg': 'lg', 'xl': 'xl', 'xxl': 'xxl'}
```

```bash
python3 tools/audit_geometry.py && echo GEOMETRY_OK
```

预期 `偏差 0 项`。

- [ ] **Step 6: 语义名接管场景（只改调用点名字，不改值）**

| 场景 | 判据 | 改成 |
| --- | --- | --- |
| 页面左右内缩 | `.padding({ left: SpaceTokens.base, right: SpaceTokens.base })` 且是页面根容器 | `pagePadding` / 宽档 `pagePaddingWide` |
| 卡片内边距 16 | 家族卡 `card.padding` | `blockGap` |
| gap 12 的列表/栅格 | `List().space()` / `Flex({ space })` | `itemGap` / `gridGutter` |
| 段落间距 24 | `Column().space(SpaceTokens.lg)` | `sectionGap` |

```bash
python3 tools/audit_geometry.py
grep -rn "SpaceTokens.pagePadding\b" entry/src/main/ets | wc -l
```

预期：尺 0 偏差；语义名至少各出现 1 次（否则说明这条只是空改名 —— 那就把这处退回值名，别留死字段）。

- [ ] **Step 7: hypium 断言间距档镜像契约**

`StyleConfig.test.ets` 内新增：

```typescript
import { SpaceTokens, ALLOWED_SPACINGS } from '../../../main/ets/design/SpaceTokens';

  describe('SpaceTokensV2', () => {
    it('eight_contract_rungs_present', TestType.FUNCTION | Size.SMALLTEST | Level.LEVEL0, () => {
      expect(SpaceTokens.xxs).assertEqual(4);
      expect(SpaceTokens.xs).assertEqual(8);
      expect(SpaceTokens.sm).assertEqual(12);
      expect(SpaceTokens.base).assertEqual(16);
      expect(SpaceTokens.md).assertEqual(20);
      expect(SpaceTokens.lg).assertEqual(24);
      expect(SpaceTokens.xl).assertEqual(32);
      expect(SpaceTokens.xxl).assertEqual(48);
      expect(ALLOWED_SPACINGS.indexOf(18)).assertEqual(-1);
      expect(ALLOWED_SPACINGS.indexOf(28)).assertEqual(-1);
    });
  });
```

- [ ] **Step 8: 构建 + 复拍（改名批最容易在 padding/margin 交叠上误吃）**

批量改名最容易把同名但职责不同的容器一起改错（本项目 `lanes` 那次：同名锚点贴到不同职责的容器）。做法：`git stash` 前先用 `grep -n` 抽样 6 处（每档 1 处）人工确认，再装机同机位复拍，与 T4 的 `bar-t0/t1` 逐屏对比；`python3 tools/audit_layout_patterns.py --self-test` 仍过。

```bash
HDC=/Applications/DevEco-Studio.app/Contents/sdk/default/openharmony/toolchains/hdc
$HDC shell "aa test -b com.youjing.app -m entry_test -s unittest OpenHarmonyTestRunner"
```

预期 `Tests run: 194, Failure: 0`（191 + T2/T5/T6 各 1 例）。

- [ ] **Step 9: 提交**

```bash
git add entry/src/main/ets/design/SpaceTokens.ets tools/audit_geometry.py entry/src/main/ets
git commit -m "refactor(契约v2): 间距档改用契约名——同名不同值的跨 App 错位从根上消掉，像素零变化"
```

---

### Task 7: 修 `audit_fontfamily` 的假绿（定义了契约路径却从不 open）

**Files:**
- Modify: `tools/audit_fontfamily.py:29-34`

- [ ] **Step 1: 先反证规则有效**

```bash
python3 tools/audit_fontfamily.py --selftest
```

若该尺现在没有 `--selftest`：先补一个（喂「serif 档未带 `.fontFamily`」的假源码，断言命中 `[漏字族]`）。这一步证明**规则本身有效**，从而把「只有契约解析是假的」隔离出来。

- [ ] **Step 2: 改成真读契约 serif 档**

```python
def contract_serif_tiers():
    with open(DESIGN, encoding='utf-8') as fh:
        txt = fh.read()
    out = {}
    for m in re.finditer(r'^    ([a-z][a-z0-9-]*):\n((?:      .*\n)+)', txt, re.M):
        body = m.group(2)
        if 'serif' not in body:
            continue
        size = re.search(r'fontSize: "(\d+)px"', body)
        weight = re.search(r'fontWeight: (\d+)', body)
        if size and weight:
            out[m.group(1)] = (int(size.group(1)), int(weight.group(2)))
    return out

TIERS = contract_serif_tiers()
if not TIERS:
    print('[契约解析] 没从 DESIGN.md 抓到 serif 档，尺子失明')
    sys.exit(1)
```

原 `CONTRACT_SERIF_TIERS`（`display 32/700`、`title 21/700`、`day-label 21/700`、`body-serif 16/400`）作为**降级兜底保留**，但降级时打印 `[降级] 使用内置 serif 档` 并退 1 —— 不许静默。

- [ ] **Step 3: 跑尺 + 提交**

```bash
python3 tools/audit_fontfamily.py && echo FONTFAMILY_OK
git add tools/audit_fontfamily.py
git commit -m "fix(闸门): audit_fontfamily 真解析契约 serif 档——修掉一条永远 0 红的假绿"
```

预期 `字族偏差 0 处`（契约 typography 段本轮未改）。

---

### Task 8: 规矩文本改写与尺数校正

**Files:**
- Modify: `Docs/INIT_REPORT.md:1867-1868`
- Modify: `README.md:23,39,74`
- Modify: `CHANGELOG.md`（新增条目，不回改历史）

- [ ] **Step 1: 改规范句（只改现行硬约束，历史记录不动）**

`Docs/INIT_REPORT.md:1867-1868` 里「是权威契约，**不许为了让尺子过而改它**」改为：

```text
`~/Pictures/有径/有径-设计底稿-v1/docs/DESIGN.md` 是家族契约文本，**由产品负责人修订**；任何改动必须与 `design/*.ets` token 表、`tools/audit_*.py` 判据在**同一批提交**里同步（尺只遍历契约侧：加行可能红、删行只会绿）。
```

`:4710`、`:4707-4713`、`CHANGELOG.md:252-254` 是**历史记录**，原文不动；在 §5ci 新增段落里写明口径已变。

- [ ] **Step 2: README 尺数校正**

`README.md:23` 与 `:39` 的「十二把静态尺」、`:74` 的「十三把尺」统一为「**十四把静态尺**」（13 原有静态 + `audit_motion`；`audit_contrast` 需真机不计入静态），`:74` 闸门表补一行 `audit_motion.py`。

- [ ] **Step 3: CHANGELOG 顶部新条目**

记：契约 v2 五处改动、投影六档 + 深色不归零、模糊 50 + 16 页门控（写明「顶栏模糊此前从未出图」这条实况）、动效 token 与 `ICurve`、间距契约名迁移、`audit_fontfamily` 与 `audit_elevation` 两条假绿/反转修复。

- [ ] **Step 4: 提交**

```bash
git add Docs/INIT_REPORT.md README.md CHANGELOG.md
git commit -m "docs(规矩): 契约改为可由产品负责人修订——改后必须同批同步 token 与尺"
```

---

### Task 9: 全量回归与取证销案

- [ ] **Step 1: 静态尺全跑**

```bash
for f in tools/audit_*.py; do
  case "$f" in *audit_contrast.py) continue;; esac
  python3 "$f" >/dev/null 2>&1 && echo "PASS $f" || echo "FAIL $f"
done
```

预期 14 把全 PASS。

- [ ] **Step 2: 离线断言六套**

```bash
for s in tools/verify_*.sh; do bash "$s" >/dev/null 2>&1 && echo "PASS $s" || echo "FAIL $s"; done
```

- [ ] **Step 3: 构建、装机、hypium**

```bash
DEVECO_SDK_HOME=/Applications/DevEco-Studio.app/Contents/sdk \
  /Applications/DevEco-Studio.app/Contents/tools/node/bin/node \
  /Applications/DevEco-Studio.app/Contents/tools/hvigor/bin/hvigorw.js \
  --mode module -p module=entry@default assembleHap -p buildMode=debug --no-daemon
HDC=/Applications/DevEco-Studio.app/Contents/sdk/default/openharmony/toolchains/hdc
$HDC install -r entry/build/default/outputs/default/entry-default-signed.hap
$HDC shell "aa test -b com.youjing.app -m entry_test -s unittest OpenHarmonyTestRunner"
```

预期 `Tests run: 194, Failure: 0`。

- [ ] **Step 4: 全路由两档复拍 + 两条自留疑问销案**

- 深色档逐屏复拍（4 tab + 17 push 页），重点量**阴影不再归零后**卡片/dock 在 `#121212`/`#1E1E1E`/`#28282C` 上是否真的近乎不可见 —— 有据的结论不能直接代到有径色阶上。
- `BAR_BLUR_RADIUS` 销案：临时各装一版（24 与 50）同机位对比，验完恢复 50 并 `git diff` 确认干净，结论写进 `Docs/INIT_REPORT.md` §5ci。
- 对比度尺重跑：`python3 tools/audit_contrast.py --selftest` 后跑全路由，**一次只跑一份**（并行会污染证据，本项目踩过）。

- [ ] **Step 5: 提交**

```bash
git add Docs/INIT_REPORT.md
git commit -m "docs(取证): 契约v2 基座全量回归——顶栏模糊首次出图、深色阴影实拍定案"
```

---

## 验收矩阵（对应方案 §4 P1、§5、§6）

| 方案验收项 | 方式 | 判定 |
| --- | --- | --- |
| 契约 v2 落地 | 原件与 `Docs/design-v1/DESIGN.md` md5 比对 + `grep -c glass-blur: "50"` | 一致 / 命中 1 |
| 投影六档镜像契约 | `audit_elevation.py` + hypium `tiers_match_contract` | 偏差 0 / 5 断言过 |
| 深色不归零 | `audit_elevation` 反转判据 + 深色逐屏复拍 | 0 条深浅门控 / 屏屏看过 |
| 顶栏模糊 50 + 门控 | `audit_material`（note 升 fail）+ T4 两帧对比 | 尺 0 偏差 / t1 帧可见磨砂 |
| 每个 bar 调用点都表态 | `grep … \| wc -l` | 0 |
| 动效 token 落契约 | `audit_motion --selftest` + hypium | pass + 4 断言过 |
| 间距名对齐契约 | `grep legacy \| wc -l` + `audit_geometry` | 0 / 偏差 0 |
| 两条假绿修掉 | `audit_fontfamily` 真读、抓不到退 1；`audit_elevation` 有 `--selftest` | 不再静默 |
| 改名批像素零回退 | 同机位 diff + `audit_layout_patterns --self-test` + 逐屏复拍 | 无新增截断/重叠 |
| 全局回归 | 14 静态尺 + 6 离线套 + hypium 194 | 全绿 |

## 已知边界

- `PricingPage.ets`（CodeArts 未跟踪）的顶栏未表态 `scrollable`，登记后由对方补。
- 底稿 `frames/*/code.html` 的 39 帧仍是 v1 视觉（blur 24），本计划只改契约与提示词文档的数值，不重切设计稿；底稿自带 `tools/audit.sh` 读的是 `~/Documents/StitchDesign/DESIGN.md` 那份，与家族契约并存的分叉保持原样。
- `audit_shadows.py`（双层影检查）与 `audit_family_card.py`（46 处三元组）都在 P2 落地：前者要有 `BaseCard` 双层件才有对象，后者一上就把现存 46 处全报红、闸门失可用性。
- 「黑 alpha 在深底近乎不可见」是按有据色阶得出的推断，有径必须自己用像素证；若证伪（深色下阴影可见且脏），回方案 §7 作设计取舍上报，不自行再翻契约。
- 契约 `motion` 其余 13 项（`page 420`/`emphasis 460`/`stagger 40`/`shared-element 380`/`press-opacity 0.92`/`press-slide-scale 0.94`/`success-scale`/`enter-scale`/`spring*`/`frame-rates`）按「无消费方不声明」本轮不加，P3 随用随补。
- `~/Pictures/…/tools/audit.sh` 与 `audit_dark.sh` 默认读另一份 `~/Documents/StitchDesign/DESIGN.md`（审 frames 用），本次不同步 —— 已知分叉。
- 若真机在 T4/T6/T9 期间被真人取走：该点之后的复拍一律 `[待验证]`，保留已完成提交，不代解锁、不猜结论。


---

## 附录：批次一之后的范围变更（2026-11-02，用户第二次拍板）

用户原话「继续推进UI开发，组件全量对标有据」⇒ **R23 撤销 spec §7 第 2 项**「消费方 ≥2 才建件」。本计划的 T2/T4/T6/T9 仍以 CodeArts 的 29 条在飞改动落地为前置，**不受 R23 影响的可以先做的**记为 **T10（家族件库 · 未挂载）**：

- 允许文件：`entry/src/main/ets/components/**`（新建件文件）、`entry/src/main/ets/design/ShadowTokens.ets`（**只加不改**：新增 `none`/`cardContact`/`cardAmbient`/`pillFloat`，保留 `contact`/`card` 供现存 4 个页面调用点，别名删除归 T2 原子批）、`entry/src/main/resources/{base,dark}/element/color.json`（加 `bar_shadow` 成对）、`entry/src/main/ets/design/ColorTokens.ets`（加 `barShadow`）、`entry/src/ohosTest/ets/test/StyleConfig.test.ets`（token 镜像断言）。
- **禁止**：`pages/**`、`data/**`、`ai/**`、`model/**`、`common/**`、`bff/**`、`Docs/design-v1|v2/**`、`~/Pictures/**`；不许反转 `audit_elevation` 的深色判据（那需要删 4 个页面的 isDark 分支，属 T2）；不许挂载任何件（挂载即像素变化，须逐屏复拍）。
- 依据的原子顺序（§3）：「先在仓库 token 补同名字段，再往契约加行」是唯一可分步的方向 ⇒ 本任务把 `cardContact`/`cardAmbient`/`pillFloat`/`bar_shadow` **先落在代码侧**，T2 再改契约 elevation 散文与反转尺。
