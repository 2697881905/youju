---
title: "Docs · superpowers · plans · 2026-11-05-layout-structure-migration.md"
id: markdown_cls1_798285c88467638f6a8dc28635ad6f33_7be4afb76c182df746fa44ad9d2554e37526104239726721
kb: 有径-YouJing
folder: "开发文档"
media_type: 7
tags: []
source: ima
exported_at: 2026-11-23T14:52:37.917Z
---
# 有径布局结构体系迁移（按有据） Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 把有径的界面结构与布局体系迁移成有据那一套——几何量单源、壳层形态、顶栏接口、顶栏跟手收起，分四层落地。

**Architecture:** L1 先把「底部避让 / 导航方式判定 / 系统栏补设」三件事收进两个模块（纯计算与系统读取分离，使纯计算可进 hypium）；L2 把壳层改成 `Stack > Navigation(hideTitleBar) > HdsTabs` 且五格同构；L3 让顶栏配置成为几何与带子的唯一决策点、`TopStrip` 收窄为窗口背景与图标明暗；L4 接入 `dynamicHideTitleBar` + `bindToScrollable` 并把 dock 尺寸对齐有据基准。每层一个提交、独立装机复验、独立回退。

**Tech Stack:** HarmonyOS ArkTS（Stage 模型，SDK 6.x / API 20+）、ArkUI、HDS（`HdsTabs` / `HdsNavigation` / `HdsNavDestination`）、hvigor CLI、hdc + uitest、hypium、Python 静态尺。

**Spec:** `Docs/superpowers/specs/2026-11-05-layout-structure-migration-design.md`（含 §6 冲突拍板与 §6A 契约待改清单）

## Global Constraints

- 语言/平台：ArkTS 严格模式；`.ets` 里禁止 `Record` 索引强转（今晚踩过：`arkts-no-misplaced-imports` / 索引签名报错），`import` 必须在文件顶部语句区。
- 纯计算模块**不得** import `@kit.*` / `@ohos.*`，否则 hypium 上下文拿不到依赖；系统读取只放胶水层。
- 装机前必须看到本轮 `BUILD SUCCESSFUL`——统一走 `tools/build_install.sh`（构建失败时 `hdc install` 仍会回 `AppMod finish` 并装上旧产物）。
- 真机像素/几何换算密度一律 **3.125**（不是 3.0）。
- 状态栏图标可见性、顶栏跟手收起这类**注入 fling 触发不了 HDS 滚动特效**的判据，必须由真人在真机复现后被动抓帧，脚本读数不得当作通过。
- 不修改用户手上的权威契约 `~/Pictures/…/DESIGN.md`；需要它跟改的条目走 spec §6A。
- 一轮工作打包成一个提交；`git add` 按 pathspec，禁止 `git add -A`；push 需单独授权。
- 每层结束必须全绿：hypium（基线 246 例，本计划新增用例后以新基线为准）、十九把静态尺、`tools/verify_scroll_clearance.py`。
- 冲突时**有据优先**（用户 2026-11-05 拍板），但吸顶组头材质那条是平台能力缺失、不是观感分歧，保持现状并记档。

---

### Task 1: 纯几何模块 `navInset.ets`（可进 hypium 的导航方式判定）

**Files:**
- Create: `entry/src/main/ets/utils/navInset.ets`
- Create: `entry/src/ohosTest/ets/test/NavInset.test.ets`
- Modify: `entry/src/ohosTest/ets/test/List.test.ets`（注册新套）

**Interfaces:**
- Consumes: 无（零依赖纯函数）
- Produces:
  - `NAV_MODE_GESTURE: string = 'gesture'` / `NAV_MODE_THREE_BUTTON: string = 'three-button'` / `NAV_MODE_FLOATING_BALL: string = 'floating-ball'`
  - `GESTURE_INDICATOR_MAX: number = 24`、`THREE_BUTTON_MIN_WIDTH_RATIO: number = 0.9`、`NAV_INSET_EXTRA: number = 1`、`GESTURE_INDICATOR_INSET: number = 16`
  - `spansFullWidth(bottomRectWidthVp: number, windowWidthVp: number): boolean`
  - `isThreeButton(heightVp: number, bottomRectWidthVp: number, windowWidthVp: number): boolean`
  - `computeNavInset(heightVp: number, bottomRectWidthVp: number, windowWidthVp: number): number`（悬浮 dock 边距语义：手势恒 0）
  - `computeBarInset(heightVp: number, bottomRectWidthVp: number, windowWidthVp: number): number`（内容级底部内边距：手势 16）

- [x] **Step 1: 写失败测试**

创建 `entry/src/ohosTest/ets/test/NavInset.test.ets`：

```ets
/**
 * 导航方式判定与底部避让量的纯计算回归（utils/navInset）。
 * 钉的是真机踩过的重叠区间：模拟器手势条 27.9vp 与真机三键栏 27.8vp 只看高度判不开，
 * 只看高度的旧写法会把手势条当三键、Dock 白抬 ~28vp（有据同文件头记录的实测后果）。
 */
import { describe, it, expect, TestType, Size, Level } from '@ohos/hypium';
import {
  GESTURE_INDICATOR_MAX, NAV_INSET_EXTRA, GESTURE_INDICATOR_INSET,
  spansFullWidth, isThreeButton, computeNavInset, computeBarInset
} from '../../../main/ets/utils/navInset';

export default function navInsetTest(): void {
  describe('navInset 底部避让判定', () => {
    it('gesture_bar_is_not_three_button_at_overlapping_height',
      TestType.FUNCTION | Size.SMALLTEST | Level.LEVEL0, () => {
        // 手势条：高 27.9vp 但只是居中窄胶囊（实测宽占比 35%）
        expect(spansFullWidth(137, 391)).assertFalse();
        expect(isThreeButton(27.9, 137, 391)).assertFalse();
        expect(computeNavInset(27.9, 137, 391)).assertEqual(0);
        expect(computeBarInset(27.9, 137, 391)).assertEqual(GESTURE_INDICATOR_INSET);
      });

    it('three_button_bar_detected_by_height_and_full_width',
      TestType.FUNCTION | Size.SMALLTEST | Level.LEVEL0, () => {
        // 三键栏：高 27.8vp 且避让矩形横贯整屏
        expect(spansFullWidth(1136, 1136)).assertTrue();
        expect(isThreeButton(27.8, 363.5, 363.5)).assertTrue();
        expect(computeNavInset(27.8, 363.5, 363.5)).assertEqual(27.8 + NAV_INSET_EXTRA);
      });

    it('short_three_button_still_gesture_because_height_threshold',
      TestType.FUNCTION | Size.SMALLTEST | Level.LEVEL0, () => {
        // 阈值 24 以下一律不判三键（满宽也不能翻）
        expect(GESTURE_INDICATOR_MAX).assertEqual(24);
        expect(isThreeButton(20, 363.5, 363.5)).assertFalse();
      });

    it('missing_signal_falls_back_to_gesture_conservatively',
      TestType.FUNCTION | Size.SMALLTEST | Level.LEVEL0, () => {
        // 上报缺项（宽 0）→ 保守判手势：避让 0，维持原布局，不把 dock 白抬
        expect(isThreeButton(30, 0, 363.5)).assertFalse();
        expect(computeNavInset(30, 0, 363.5)).assertEqual(0);
      });

    it('zero_window_width_never_divides',
      TestType.FUNCTION | Size.SMALLTEST | Level.LEVEL0, () => {
        expect(spansFullWidth(100, 0)).assertFalse();
      });
  });
}
```

- [x] **Step 2: 跑测试确认失败**

```bash
cd /Users/itxiaobai/HarmonyProject2 && DEVECO_SDK_HOME=/Applications/DevEco-Studio.app/Contents/sdk \
  node /Applications/DevEco-Studio.app/Contents/tools/hvigor/bin/hvigorw.js \
  --mode module -p module=entry@ohosTest -p product=default -p buildMode=debug assembleHap --no-daemon
```
Expected: 编译失败，报 `Cannot find module '../utils/navInset'`（模块还不存在，这就是失败态）。

- [x] **Step 3: 写最小实现**

创建 `entry/src/main/ets/utils/navInset.ets`：

```ets
/**
 * 底部避让的纯计算层（零 @kit 依赖，因此可进 hypium）。
 *
 * 为什么要和系统读取分开：判定要读 `settings 'float_navigation_info'` 与
 * `getWindowAvoidArea`，那些在测试上下文里拿不到（ohosTest 只有 ApplicationContext，
 * 偏好/DB 类还会被拒）。把「算」抽出来，胶水层只负责取数与发布。
 *
 * 判据来源（有据 navMode.ets 文件头，两处真机实测）：
 *  · 手势指示条是居中窄胶囊（模拟器实测宽 137vp / 屏宽 391vp = 35%）
 *  · 三键栏的避让矩形必然横贯整屏（左右两颗键不可能落在避让区之外）
 *  · **只看高度判不开**：模拟器手势条 27.9vp 与真机三键栏 27.8vp 区间完全重叠，
 *    旧注释「16-24 / 28-42 不重叠」是错的，后果是把手势条当三键、Dock 白抬 28.9vp。
 * 因此三键必须「高度 > 24 **且** 宽度 ≥ 屏宽 90%」两条同时成立；缺项一律保守判手势。
 */

export const NAV_MODE_GESTURE: string = 'gesture';
export const NAV_MODE_THREE_BUTTON: string = 'three-button';
export const NAV_MODE_FLOATING_BALL: string = 'floating-ball';

/** 高度阈值：≤ 此值绝不判三键 */
export const GESTURE_INDICATOR_MAX: number = 24;
/** 三键判定所需的最小宽度占比，0.9 给分屏/小窗留余量 */
export const THREE_BUTTON_MIN_WIDTH_RATIO: number = 0.9;
/** 三键栏高之外的呼吸量（vp） */
export const NAV_INSET_EXTRA: number = 1;
/** 内容级底部内边距：手势档下的指示条预留（vp） */
export const GESTURE_INDICATOR_INSET: number = 16;

export function spansFullWidth(bottomRectWidthVp: number, windowWidthVp: number): boolean {
  if (windowWidthVp <= 0 || bottomRectWidthVp <= 0) {
    return false;
  }
  return bottomRectWidthVp >= windowWidthVp * THREE_BUTTON_MIN_WIDTH_RATIO;
}

export function isThreeButton(heightVp: number, bottomRectWidthVp: number, windowWidthVp: number): boolean {
  return heightVp > GESTURE_INDICATOR_MAX && spansFullWidth(bottomRectWidthVp, windowWidthVp);
}

/** 悬浮 dock 的底部边距增量：手势档恒 0（底栏维持原设计，不整体顶高） */
export function computeNavInset(heightVp: number, bottomRectWidthVp: number, windowWidthVp: number): number {
  return isThreeButton(heightVp, bottomRectWidthVp, windowWidthVp) ? heightVp + NAV_INSET_EXTRA : 0;
}

/** 内容级底部内边距：三键 = 栏高 + 呼吸；手势 = 指示条常量 */
export function computeBarInset(heightVp: number, bottomRectWidthVp: number, windowWidthVp: number): number {
  return isThreeButton(heightVp, bottomRectWidthVp, windowWidthVp)
    ? heightVp + NAV_INSET_EXTRA : GESTURE_INDICATOR_INSET;
}
```

- [x] **Step 4: 注册测试套**

Modify `entry/src/ohosTest/ets/test/List.test.ets`：在 import 区末尾加 `import navInsetTest from './NavInset.test';`，在 `export default function testsuite() {` 体内加一行 `navInsetTest();`。（不注册就不跑——这是本仓已知陷阱。）

- [x] **Step 5: 跑测试确认通过**

```bash
cd /Users/itxiaobai/HarmonyProject2 && DEVECO_SDK_HOME=/Applications/DevEco-Studio.app/Contents/sdk \
  node /Applications/DevEco-Studio.app/Contents/tools/hvigor/bin/hvigorw.js \
  --mode module -p module=entry@ohosTest -p product=default -p buildMode=debug assembleHap --no-daemon && \
  /Applications/DevEco-Studio.app/Contents/sdk/default/openharmony/toolchains/hdc install -r \
  entry/build/default/outputs/ohosTest/entry-ohosTest-signed.hap && \
  /Applications/DevEco-Studio.app/Contents/sdk/default/openharmony/toolchains/hdc shell \
  aa test -b com.youjing.app -m entry_test -s unittest OpenHarmonyTestRunner 2>&1 | grep OHOS_REPORT_RESULT
```
Expected: `Tests run: 251, Failure: 0, Error: 0`（基线 246 + 本任务 5 例）。

- [x] **Step 6: 提交**

```bash
git add entry/src/main/ets/utils/navInset.ets entry/src/ohosTest/ets/test/NavInset.test.ets entry/src/ohosTest/ets/test/List.test.ets
git commit -m "feat(布局): 底部避让判定抽成零依赖纯模块 navInset——手势条与三键栏高度重叠"
```

---

### Task 2: `navMode.ets` 胶水层（settings 权威信号 + avoidArea 兜底 + 响应式发布）

**Files:**
- Create: `entry/src/main/ets/utils/navMode.ets`
- Modify: `entry/src/main/ets/entryability/EntryAbility.ets:235-248`（`publishAvoidArea` 内接发布）、`onWindowStageCreate`（初始化）、`onForeground`（刷新）

**Interfaces:**
- Consumes: Task 1 的 `isThreeButton` / `computeNavInset` / `computeBarInset` / 三个模式常量
- Produces:
  - `NAV_MODE_KEY: string = 'navMode'`、`NAV_BUTTON_BAR_HEIGHT_KEY: string = 'navButtonBarHeight'`、`BOTTOM_NAV_INSET_KEY: string = 'bottomNavInsetVp'`、`BOTTOM_BAR_INSET_KEY: string = 'bottomBarInsetVp'`、`NAV_BAR_SPANS_WIDTH_KEY: string = 'navBarSpansWidth'`
  - `initNavModeWatcher(context: common.Context): void`
  - `refreshNavMode(context: common.Context): void`
  - `reportBottomAvoid(heightVp: number, bottomRectWidthVp: number, windowWidthVp: number): void`
  - `refreshBottomNavInset(): void`
  - `bottomNavInset(): number`（非响应式取现值，给不方便挂 `@StorageLink` 的调用点）
  - `isThreeButtonNav(): boolean`

- [x] **Step 1: 写实现**

创建 `entry/src/main/ets/utils/navMode.ets`：

```ets
/**
 * 系统导航方式检测 + 底部避让量发布（胶水层）。
 *
 * 两层信号（照搬有据，两条都是真机实测换来的）：
 *  1) 权威信号：settings 的 USER_PROPERTY 域键 `float_navigation_info`，
 *     JSON 形如 { showType, region }：showType=0 三键已显示（region[3] 是三键栏真实高度 px）、
 *     =1 悬浮球、=-1 未显示三键（全面屏手势/导航条）。读 USER_PROPERTY 不需要权限。
 *  2) 兜底信号：settings 键缺失（模拟器 / 部分云手机 / 非华为 ROM）时，
 *     用 avoidArea 的高度 + 「避让矩形是否横贯整屏」联合判别——判定数学在 `navInset.ets`，
 *     那里有零依赖纯函数与回归用例。
 *
 * 响应式约定（有据文件头写明的踩坑）：消费方必须 `@StorageLink(BOTTOM_NAV_INSET_KEY)`
 * **并在 build 属性里直接读该变量**——只挂 link 不进 build，ArkUI 不建立更新绑定，刷新全是空操作。
 */
import settings from '@ohos.settings';
import display from '@ohos.display';
import { common } from '@kit.AbilityKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { window } from '@kit.ArkUI';
import { Logger } from '../common/logger/Logger';
import {
  NAV_MODE_GESTURE, NAV_MODE_THREE_BUTTON, NAV_MODE_FLOATING_BALL,
  isThreeButton, computeNavInset, computeBarInset
} from './navInset';

const TAG: string = 'Ui.NavMode';
const FLOAT_NAVIGATION_INFO_KEY: string = 'float_navigation_info';

export const NAV_MODE_KEY: string = 'navMode';
export const NAV_BUTTON_BAR_HEIGHT_KEY: string = 'navButtonBarHeight';
export const BOTTOM_NAV_INSET_KEY: string = 'bottomNavInsetVp';
export const BOTTOM_BAR_INSET_KEY: string = 'bottomBarInsetVp';
export const NAV_BAR_SPANS_WIDTH_KEY: string = 'navBarSpansWidth';

/** 兜底信号用的现值缓存：由 EntryAbility.publishAvoidArea 写入 */
function readNumber(key: string): number {
  return AppStorage.get<number>(key) ?? 0;
}

export function isThreeButtonNav(): boolean {
  return (AppStorage.get<string>(NAV_MODE_KEY) ?? NAV_MODE_GESTURE) === NAV_MODE_THREE_BUTTON;
}

export function reportBottomAvoid(heightVp: number, bottomRectWidthVp: number, windowWidthVp: number): void {
  AppStorage.setOrCreate(NAV_BAR_SPANS_WIDTH_KEY, bottomRectWidthVp >= windowWidthVp * 0.9 ? 1 : 0);
  AppStorage.setOrCreate('navBarHeight', heightVp);
  refreshBottomNavInset();
}

export function refreshBottomNavInset(): void {
  const heightVp: number = readNumber('navBarHeight');
  const spans: number = readNumber(NAV_BAR_SPANS_WIDTH_KEY);
  const windowWidthVp: number = windowWidthVpNow();
  const bottomRectWidthVp: number = spans === 1 ? windowWidthVp : heightVp > 0 ? heightVp : 0;
  const three: boolean = isThreeButton(heightVp, bottomRectWidthVp, windowWidthVp);
  AppStorage.setOrCreate(BOTTOM_NAV_INSET_KEY, computeNavInset(heightVp, bottomRectWidthVp, windowWidthVp));
  AppStorage.setOrCreate(BOTTOM_BAR_INSET_KEY, computeBarInset(heightVp, bottomRectWidthVp, windowWidthVp));
  if (!three) {
    Logger.info(TAG, `兜底判据=手势 height=${heightVp}vp spans=${spans}`);
  }
}

function windowWidthVpNow(): number {
  try {
    const d: display.Display = display.getDefaultDisplaySync();
    const density: number = d.densityPixels > 0 ? d.densityPixels : 3.125;
    return d.width / density;
  } catch (err) {
    return 363.5;
  }
}

/** settings 权威信号：showType 0=三键（region[3] 给真实栏高 px）/ 1=悬浮球 / -1=手势 */
export function refreshNavMode(context: common.Context): void {
  let raw: string = '';
  try {
    raw = settings.getValueSync(context, FLOAT_NAVIGATION_INFO_KEY, '', settings.domainName.USER_PROPERTY);
  } catch (err) {
    Logger.warn(TAG, `读 float_navigation_info 失败，走兜底: ${(err as Error).message}`);
    return;
  }
  if (raw.length === 0) {
    return;
  }
  try {
    const info: Record<string, Object> = JSON.parse(raw) as Record<string, Object>;
    const showType: number = Number(info['showType'] ?? -1);
    const region: number[] = info['region'] as number[];
    const density: number = display.getDefaultDisplaySync().densityPixels;
    if (showType === 0) {
      const barHeightVp: number = region.length >= 4 && density > 0 ? region[3] / density : 0;
      AppStorage.setOrCreate(NAV_MODE_KEY, NAV_MODE_THREE_BUTTON);
      AppStorage.setOrCreate(NAV_BUTTON_BAR_HEIGHT_KEY, barHeightVp);
      AppStorage.setOrCreate(BOTTOM_NAV_INSET_KEY, barHeightVp + 1);
      AppStorage.setOrCreate(BOTTOM_BAR_INSET_KEY, barHeightVp + 1);
      Logger.info(TAG, `settings 权威信号=三键 栏高=${barHeightVp.toFixed(1)}vp`);
    } else if (showType === 1) {
      AppStorage.setOrCreate(NAV_MODE_KEY, NAV_MODE_FLOATING_BALL);
      refreshBottomNavInset();
    } else {
      AppStorage.setOrCreate(NAV_MODE_KEY, NAV_MODE_GESTURE);
      refreshBottomNavInset();
    }
  } catch (err) {
    Logger.warn(TAG, `float_navigation_info 解析失败，保持兜底值: ${(err as Error).message}`);
  }
}

export function initNavModeWatcher(context: common.Context): void {
  refreshNavMode(context);
  refreshBottomNavInset();
  try {
    settings.registerKeyObserver(context, FLOAT_NAVIGATION_INFO_KEY, settings.domainName.USER_PROPERTY,
      (_err: BusinessError): void => {
        refreshNavMode(context);
      });
  } catch (err) {
    Logger.warn(TAG, `注册导航方式观察者失败（模拟器/非华为 ROM 常见）: ${(err as Error).message}`);
  }
}

/** 非响应式取现值：只给无法挂 @StorageLink 的调用点，响应式消费必须走 @StorageLink + build 内直读 */
export function bottomNavInset(): number {
  return AppStorage.get<number>(BOTTOM_NAV_INSET_KEY) ?? 0;
}

/** 供 EntryAbility 在 avoidArea 变化时调用，把窗口侧真值灌进兜底链路 */
export function publishNavAvoid(win: window.Window): void {
  try {
    const density: number = display.getDefaultDisplaySync().densityPixels;
    const rect: window.Rect = win.getWindowAvoidArea(window.AvoidAreaType.TYPE_NAVIGATION_INDICATOR).bottomRect;
    reportBottomAvoid(density > 0 ? rect.height / density : 0,
      density > 0 ? rect.width / density : 0, windowWidthVpNow());
  } catch (err) {
    Logger.warn(TAG, `发布导航避让区失败: ${(err as Error).message}`);
  }
}
```

- [x] **Step 2: 接 EntryAbility**

Modify `entry/src/main/ets/entryability/EntryAbility.ets`：

顶部 import 区加：
```ets
import { initNavModeWatcher, refreshNavMode, publishNavAvoid } from '../utils/navMode';
```
`onWindowStageCreate` 内、`loadContent` **之前**加：
```ets
    initNavModeWatcher(this.context);
```
`publishAvoidArea(win)` 末尾（现有 `Logger.info` 之前）加：
```ets
      publishNavAvoid(win);
```
`onForeground` 内（现有 `this.applySystemBarSurface()` 同侧）加：
```ets
      refreshNavMode(this.context);
```

- [x] **Step 3: 编译验证**

```bash
tools/build_install.sh default
```
Expected: `BUILD SUCCESSFUL` → 装机成功；无 `arkts-no-misplaced-imports`、无索引签名错误。

- [x] **Step 4: 真机取一次日志**

```bash
/Applications/DevEco-Studio.app/Contents/sdk/default/openharmony/toolchains/hdc shell aa start -b com.youjing.app -a EntryAbility
sleep 5
/Applications/DevEco-Studio.app/Contents/sdk/default/openharmony/toolchains/hdc shell "hilog -x -T Ui.NavMode" | tail -3
```
Expected: 出现 `settings 权威信号=…` 或 `兜底判据=…` 其中一条——证明链路真的跑到了，不是静默失败。**没有日志就是没接上，不许进下一步。**

- [x] **Step 5: 提交**

```bash
git add entry/src/main/ets/utils/navMode.ets entry/src/main/ets/entryability/EntryAbility.ets
git commit -m "feat(布局): navMode 胶水层——settings 权威信号 + avoidArea 兜底 + 底部避让响应式发布"
```

---

### Task 3: `systemBar.ets` 补设通道（治 HDS 滚回顶部回写图标色）

**Files:**
- Create: `entry/src/main/ets/utils/systemBar.ets`
- Modify: `entry/src/main/ets/entryability/EntryAbility.ets`（注册 refresher）
- Modify: 滚动宿主的 `onDidScroll`（本任务只改 `YoujingStartPage.ets:71-82` 作为样板，其余页面在 Task 9 统一）

**Interfaces:**
- Consumes: `EntryAbility.applySystemBarSurface()`（已有，private → 本次经 refresher 注入，不改可见性）
- Produces: `setSystemBarRefresher(fn: () => void): void`、`requestSystemBarRefresh(): void`

- [x] **Step 1: 写实现**

创建 `entry/src/main/ets/utils/systemBar.ets`：

```ets
/**
 * 系统栏图标明暗的「补设」通道。
 *
 * 为什么需要：HDS 标题栏在挂载期与滚动特效回位（滚回顶部）时会回写系统栏属性，
 * 把应用按自身主题显式设的 `isStatusBarLightIcon` 覆盖成按**系统**深浅渲染。
 * SDK 没有关停该联动的人口（只有整体隐藏的 hideStatusBar），只能在每次被覆盖后补设。
 * 单发 400ms 会被下一帧覆盖——有据真机两次复现分别在 <0.6s 与 ~2.9s，
 * 所以连发四发、最后一发 3s 与挂载期补设同刻，任何 ≤3s 的回写都会被最后一发压住。
 */
let refresher: (() => void) | null = null;
const REFRESH_SHOTS_MS: number[] = [400, 1000, 1800, 3000];
let pendingTimers: number[] = [];

export function setSystemBarRefresher(fn: () => void): void {
  refresher = fn;
}

export function requestSystemBarRefresh(): void {
  for (const t of pendingTimers) {
    clearTimeout(t);
  }
  pendingTimers = [];
  for (const delay of REFRESH_SHOTS_MS) {
    const id: number = setTimeout((): void => {
      if (refresher !== null) {
        refresher();
      }
      pendingTimers = pendingTimers.filter((t: number): boolean => t !== id);
    }, delay) as number;
    pendingTimers.push(id);
  }
}
```

- [x] **Step 2: EntryAbility 注册**

Modify `entry/src/main/ets/entryability/EntryAbility.ets`：import 区加 `import { setSystemBarRefresher } from '../utils/systemBar';`；在 `onWindowStageCreate` 里 `makeImmersive(windowStage)` 调用**之后**加：
```ets
    setSystemBarRefresher((): void => {
      this.applySystemBarSurface();
    });
```

- [x] **Step 3: 样板页接回顶触发**

Modify `entry/src/main/ets/pages/YoujingStartPage.ets`，在 `syncBarScroll()` 里（现有 `if (on !== this.barScrolled)` 之后）加：
```ets
    if (!on && this.wasScrolled) {
      // 偏移回到 0：HDS 会在这帧回写系统栏属性，补设通道连发四发压住它
      requestSystemBarRefresh();
    }
    this.wasScrolled = on;
```
并在类字段区加 `private wasScrolled: boolean = false;`，import 区加 `import { requestSystemBarRefresh } from '../utils/systemBar';`。

- [ ] **Step 4: 真机验证（必须真人）**

> **执行时状态（2026-11-05）**：代码侧已落地并提交（`bc2de7e`），这一步**等人**。
> 注入 fling 触发不了 HDS 滚动遮罩，脚本自证会出假绿，所以图标明暗只能真人滚到顶后被动抓帧。

```bash
tools/build_install.sh default
```
然后**真人**在规划页往下滚再滚回顶部，停在顶部 4 秒后我被动抓帧判图标可读性：
```bash
/Applications/DevEco-Studio.app/Contents/sdk/default/openharmony/toolchains/hdc shell snapshot_display -f /data/local/tmp/sb.jpeg
/Applications/DevEco-Studio.app/Contents/sdk/default/openharmony/toolchains/hdc file recv /data/local/tmp/sb.jpeg /tmp/ui4/sb_check.jpeg
python3 -c "
from PIL import Image
im=Image.open('/tmp/ui4/sb_check.jpeg').convert('L'); W=im.size[0]
row=[im.getpixel((x,45)) for x in range(60,300)]
print('状态栏图标区最亮点', max(row), '背景', sorted(row)[len(row)//2], '→', '✅ 图标可见' if max(row)-sorted(row)[len(row)//2]>60 else '✗ 图标糊底')"
```
Expected: `✅ 图标可见`。深浅两档各跑一次（浅色用 `--ps lightprobe 1` 冷启）。**这一步脚本无法自证（注入 fling 不触发 HDS 特效），必须真人配合。**

- [x] **Step 5: 提交**

```bash
git add entry/src/main/ets/utils/systemBar.ets entry/src/main/ets/entryability/EntryAbility.ets entry/src/main/ets/pages/YoujingStartPage.ets
git commit -m "feat(布局): 系统栏补设通道——HDS 滚回顶部会回写图标明暗，单发压不住"
```

---

### Task 4: dock 边距改读单源 + `floatingDockClearance` 派生化 + 第 19 把尺

**Files:**
- Modify: `entry/src/main/ets/pages/Index.ets:66`（状态变量）、`:246`（barBottomMargin）
- Modify: `entry/src/main/ets/design/LayoutTokens.ets:127`（`floatingDockClearance` 语义）
- Create: `tools/audit_inset_source.py`
- Modify: `README.md`（尺数与清单）

**Interfaces:**
- Consumes: Task 2 的 `BOTTOM_NAV_INSET_KEY`
- Produces: `LayoutTokens.floatingDockBarHeight: number = 56`（有据 dock 栏高真值），`floatingDockClearance` 改为 `floatingDockBarHeight + floatingDockBottomMargin + 12` 的派生注释（值保持 112 不变，避免本层夹带观感变化）

- [x] **Step 1: 写失败尺**

创建 `tools/audit_inset_source.py`：

```python
#!/usr/bin/env python3
"""第 19 把静态尺：底部/顶部避让量只能有一个来源。

R1 禁止页面把 `statusBarHeight` / `navIndicatorHeight` / `navBarHeight`
   直接写进 padding / margin / height 表达式——必须走 navMode 发布的键。
   阳性对照是 2026-11-05 真机抓到的那条 `pages/Index` `.padding({ top: this.statusBarHeight })`：
   壳层避让 + 栏体避让 = 同一件事写两遍，后果是状态栏带子拿不到栏体的沉浸遮罩，
   滚动时出现「带子 L=18 / 栏体 L=11」的硬台阶。
R2 底部 dock 边距必须读 BOTTOM_NAV_INSET_KEY（`bottomNavInsetVp`），
   禁止再写 `+ this.navIndicatorHeight` 这类只看高度的自算。

用法：python3 tools/audit_inset_source.py [--selftest]
"""
import glob
import re
import sys

EXEMPT = ('utils/navMode.ets', 'utils/navInset.ets', 'entryability/EntryAbility.ets')
R1 = re.compile(r'\.(padding|margin|height)\s*\([^)]*\b(statusBarHeight|navIndicatorHeight|navBarHeight)\b')
R2 = re.compile(r'navIndicatorHeight')
KEY_READ = 'bottomNavInsetVp'

SELFTEST = [
    ('pages/Index.ets', ".padding({ top: this.statusBarHeight })", 'R1', '壳层重复避让（今晚的真缺陷）'),
    ('pages/Index.ets', "barBottomMargin: LayoutTokens.floatingDockBottomMargin + this.navIndicatorHeight,", 'R2', 'dock 只看高度自算'),
    ('pages/Index.ets', "@StorageLink(BOTTOM_NAV_INSET_KEY) dockNavInset: number = 0;", None, '走单源键'),
    ('pages/Index.ets', "barBottomMargin: LayoutTokens.floatingDockBottomMargin + this.dockNavInset,", None, '派生自单源键'),
    ('utils/navMode.ets', "AppStorage.setOrCreate('navBarHeight', heightVp);", None, '发布点豁免'),
]


def classify(path, line):
    if any(path.endswith(e) for e in EXEMPT):
        return None
    if line.strip().startswith('//'):
        return None
    if R1.search(line):
        return 'R1'
    if R2.search(line) and KEY_READ not in line:
        return 'R2'
    return None


def selftest():
    bad = 0
    for path, frag, want, note in SELFTEST:
        got = classify(path, frag)
        if got != want:
            print('  SELFTEST FAIL %s → got=%s want=%s' % (note, got, want))
            bad += 1
    pos = sum(1 for x in SELFTEST if x[2])
    neg = len(SELFTEST) - pos
    if bad:
        print('自测 %d 条不过：控制样本没立住时，真跑的 0 命中不算证据' % bad)
        return 1
    print('自测通过：阳性 %d / 阴性 %d' % (pos, neg))
    return 0


def main():
    if '--selftest' in sys.argv:
        return selftest()
    if selftest() != 0:
        return 1
    hits = []
    for path in sorted(glob.glob('entry/src/main/ets/**/*.ets', recursive=True)):
        for i, line in enumerate(open(path, encoding='utf-8').read().split('\n'), 1):
            rule = classify(path, line)
            if rule:
                hits.append((rule, path, i, line.strip()))
    for rule, path, i, text in hits:
        print('  %-3s %s:%d  %s' % (rule, path, i, text[:96]))
    print('避让量来源：偏差 %d 项（R1 顶部/底部不得自算，R2 dock 必须读 bottomNavInsetVp）' % len(hits))
    return 1 if hits else 0


if __name__ == '__main__':
    sys.exit(main())
```

- [x] **Step 2: 跑尺确认它现在是红的**

```bash
python3 tools/audit_inset_source.py
```
Expected: `自测通过：阳性 2 / 阴性 3`，随后 `避让量来源：偏差 1 项` 并列出 `Index.ets:246` 的 `+ this.navIndicatorHeight`，退出码 1。（**尺必须先红**，红了才证明它抓得到真东西。）

- [x] **Step 3: 改 Index 消费方式**

Modify `entry/src/main/ets/pages/Index.ets`：

`import` 区加：
```ets
import { BOTTOM_NAV_INSET_KEY } from '../utils/navMode';
```
把 `:66` 的
```ets
  @StorageProp('navIndicatorHeight') navIndicatorHeight: number = 0;
```
替换为
```ets
  /** 底部避让量（vp）：唯一来源是 utils/navMode 的判定结果。
   *  ⚠ 必须 @StorageLink **且在 build 属性里直接读**——只挂 link 不进 build，
   *  ArkUI 不为它建立更新绑定，刷新全是空操作（有据 navMode 文件头的踩坑记录）。 */
  @StorageLink(BOTTOM_NAV_INSET_KEY) dockNavInset: number = 0;
```
把 `:246` 的
```ets
      barBottomMargin: LayoutTokens.floatingDockBottomMargin + this.navIndicatorHeight,
```
替换为
```ets
      barBottomMargin: LayoutTokens.floatingDockBottomMargin + this.dockNavInset,
```

- [x] **Step 4: 跑尺确认转绿 + 编译装机**

```bash
python3 tools/audit_inset_source.py && tools/build_install.sh default
```
Expected: `避让量来源：偏差 0 项` + `BUILD SUCCESSFUL` + 装机成功。

- [x] **Step 5: 真机净空复验**

```bash
python3 tools/verify_scroll_clearance.py
```
Expected: `== 滚到底无遮挡（pass）==`，退出码 0。

> **执行时修正（Task 2 真机实测，2026-11-05）**：本步原写「dock 位置与改动前像素一致」，那条判据是错的。
> 日志给出 `指示条=87px` ÷ 3.125 = **27.84vp**，旧代码是 `28 + navIndicatorHeight = 55.84vp`；
> 有据的语义是「手势档 dock 边距恒 0，基线 28vp 已含指示条空间」。
> 所以改读单源键后 **dock 下移约 27.8vp**——这是「按有据布局体系」的预期可见变化，不是回归。
> 判据改为：dock 顶边从 748.8vp **下移**到 **约 776.6vp**（本行原写「约 721vp」，是把「下移」
> 算成了 y 变小；2026-11-05 Task 4 装机实测 dock 板 `[55,2427][1081,2602]`，
> 2427÷3.125=776.6vp，与迁移前差正好 +27.84vp，方向和量级都符合本段文字），
> 且 `verify_scroll_clearance.py` 仍必须 pass
> （末行要还能滚出来）；若净空不足，走 Task 8 的预留调整，不回退本步。
> 另：真机 `settings` 键可用且报 `showType=-1`（手势），权威信号链路已验证通畅。
```bash
/Applications/DevEco-Studio.app/Contents/sdk/default/openharmony/toolchains/hdc shell uitest dumpLayout -p /data/local/tmp/d.json
/Applications/DevEco-Studio.app/Contents/sdk/default/openharmony/toolchains/hdc file recv /data/local/tmp/d.json /tmp/ui4/d.json
python3 -c "
import json,re
d=json.load(open('/tmp/ui4/d.json'));t=d.get('root',d);out=[]
def w(n):
    a=n.get('attributes',{})
    if 'TabBar' in (a.get('type','') or '') or (a.get('text','') in ('地图','行程','规划','费用','我的')):
        out.append((a.get('text',''),a.get('bounds','')))
    for c in n.get('children',[]): w(c)
w(t); print(out[:6])"
```
Expected: dock 顶边 y = **2427px（776.6vp）**，即迁移前记录值 2340px 的 +87px（= 指示条 27.84vp）。
本行原写「与 2340px 差 ≤3px」，那是单源化之前的旧判据，与本段上方的执行时修正冲突，已作废。
另附 dock 板高实测 2602-2427=175px ÷ 3.125 = **56vp**，与新 token `floatingDockBarHeight` 对齐。

- [x] **Step 6: 提交**

```bash
git add entry/src/main/ets/pages/Index.ets tools/audit_inset_source.py README.md
git commit -m "feat(布局): dock 边距改读 navMode 单源 + 第 19 把尺 audit_inset_source（阳性对照是今晚那条 padding）"
```

---

### Task 5: L1 收口——模拟器三键态验证 + 文档读数

**Files:**
- Modify: `Docs/INIT_REPORT.md`（新增「续」小节）
- Modify: `CHANGELOG.md`

**Interfaces:**
- Consumes: Task 1–4 全部产物
- Produces: L1 的验收记录（三键/手势两态 dock 位置、图标明暗补设、尺数十九把）

- [x] **Step 1: 跑全量闸门**

```bash
for r in colors type geometry material fontfamily tnum elevation button_width scroll_actions label_fit a11y_name layout_patterns skip_worktree motion bar_scroll seed self_call span_source inset_source; do printf "%-15s " $r; python3 tools/audit_$r.py 2>&1 | tail -1 | cut -c1-70; done
```
Expected: 十九把全部无新增红（`type` 那条「待裁决」是既有项，不算新增）。

- [x] **Step 2: hypium 全量**

```bash
export DEVECO_SDK_HOME=/Applications/DevEco-Studio.app/Contents/sdk && HDC=/Applications/DevEco-Studio.app/Contents/sdk/default/openharmony/toolchains/hdc && \
node /Applications/DevEco-Studio.app/Contents/tools/hvigor/bin/hvigorw.js --mode module -p module=entry@ohosTest -p product=default -p buildMode=debug assembleHap --no-daemon | tail -1 && \
$HDC install -r entry/build/default/outputs/ohosTest/entry-ohosTest-signed.hap && \
$HDC shell aa test -b com.youjing.app -m entry_test -s unittest OpenHarmonyTestRunner 2>&1 | grep OHOS_REPORT_RESULT
```
Expected: `Tests run: 251, Failure: 0, Error: 0`。

- [ ] **Step 3: 三键态实测（模拟器）**

> **执行时状态（2026-11-05）**：本步的前提「模拟器可切三键导航」在本机不成立——
> Mate 90 Pro Max 起出来就是**手势胶囊**（屏底实量 376px=111.4vp，占屏宽 28.5%），
> 且 `hdc` 没有切导航方式的命令、`settings` 键在这台上查不到（`QueryValue failed, rows=0`）。
> 已拿到的等价证据：**兜底链路在这台无 settings 键的机器上跑通并判对**——
> 指示条 94px=27.85vp（与真机三键栏 27.8vp 重叠），若只看高度就会误判三键、dock 白抬 28.8vp；
> 实测 dock 板 `[106,2564][1214,2753]`，距屏底 27.9vp=基线 28 ⇒ 避让量 0，宽度判据挡下了误判。
> **仍缺的真数据点**：真三键档下 dock 顶边是否抬高 `barHeight+1`。要么真人把 Pocket 2 系统设置切成三键，
> 要么等一台默认三键的设备；风险已量化（各页底部预留按最大档 112vp 钉死，多的是空白不是遮挡）。

在模拟器（可切三键导航）上装机后取 dock 顶边，与手势态对比：
```bash
python3 tools/verify_scroll_clearance.py
```
Expected: 三键态下 dock 顶边比手势态**高约 28.8vp**（栏高 + 1），且 `滚到底无遮挡 pass`；手势态数值不变。若模拟器拿不到 settings 键，日志应出现 `兜底判据=…`，此时用「宽度占比」那条兜底也能判对——这正是 Task 1 用例钉的重叠区间。

- [x] **Step 4: 写文档并提交**

`Docs/INIT_REPORT.md` 新增一节「续 N：L1 几何单源落地」，必须含：三键/手势两态实测数字、图标补设的真人验证结论、第 19 把尺的自测阳性/阴性条数、`verify_scroll_clearance` 读数。`CHANGELOG.md` 的 `### Changed` 顶部加一条同主题条目。

```bash
git add Docs/INIT_REPORT.md CHANGELOG.md
git commit -m "docs(布局): L1 几何单源收口——两态 dock 实测、十九把尺与 251 例读数"
```

---

### Task 6: L2 壳层形态——外层 `Navigation` 宿主 + 五格同构

**Files:**
- Modify: `entry/src/main/ets/pages/Index.ets`（`build()` 与 `mainTabs()`）
- Modify: `entry/src/main/ets/pages/YoujingStartPage.ets`（加 `rootMode` 双分支，自带 `HdsNavigation`）

**Interfaces:**
- Consumes: `HdsChrome.bar`、`routerMap`、`APP_NAV`、`stackOfTab`
- Produces: 五格统一「格内自带 `HdsNavigation` + `titleBar`」；外层 `Navigation` 仅作深链宿主且 `hideTitleBar(true)`；`routeTo` 语义不变（按 `tabOfRoute` 切页签后 push **该页签的栈**）

- [x] **Step 1: 规划格自带导航**

Modify `entry/src/main/ets/pages/YoujingStartPage.ets`：仿 `MinePage.ets:392-421` 的双分支形态改造 `build()`：

```ets
  rootMode: boolean = false;
  private pathStack: NavPathStack = APP_NAV;
```
`build()` 外层改成：
```ets
  build() {
    if (this.rootMode) {
      HdsNavigation(this.pathStack) {
        this.scrollBody()
      }
      .titleMode(HdsNavigationTitleMode.MINI)
      .hideBackButton(true)
      .titleBar(HdsChrome.bar({ mainTitle: '规划', scrolled: this.barScrolled }))
      .navDestination(routerMap)
      .mode(NavigationMode.Stack)
      .width('100%')
      .height('100%')
    } else {
      this.scrollBody()
    }
  }

  @Builder
  scrollBody() {
    /* 现有 Scroll(this.barScroller) { Column() { … } } 整块搬进来，属性链原样保留 */
  }
```
并把原来经 `AppStorage(PLAN_SCROLL_KEY)` 外送滚动状态的桥接删掉（栏体现在归本页，`this.barScrolled` 直接可用）。

- [x] **Step 2: Index 五格同构 + 外层宿主**

Modify `entry/src/main/ets/pages/Index.ets`：

`mainTabs()` 里规划格改为：
```ets
      TabContent() {
        YoujingStartPage({ rootMode: true })
      }
      .tabBar(this.tabLabel(TAB_PLAN))
```
（原 `HdsNavigation(APP_NAV) { YoujingStartPage() }` 整块替换；`TabContent` 只能有一个子组件。）

`build()` 的主体包一层宿主 Navigation：
```ets
  build() {
    Stack({ alignContent: Alignment.Bottom }) {
      if (this.consentAgreed !== '1') {
        Blank()
      } else if (this.authState === '') {
        Blank()
      } else if (this.authState !== 'huawei' && !this.guestChosen) {
        LoginView({ /* 原参数不变 */ })
      } else {
        Navigation(APP_NAV) {
          this.mainTabs()
        }
        .mode(NavigationMode.Stack)
        .hideTitleBar(true)
        .clip(false)
        .width('100%')
        .height('100%')
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.stripName === STRIP_MAP ? $r('app.color.map_strip_base') : $r('app.color.canvas'))
  }
```

- [x] **Step 3: 编译 + 装机**

```bash
tools/build_install.sh default
```
Expected: `BUILD SUCCESSFUL`。若报 `The 'TabContent' component can have only one child component` 或 `Property 'tabBar' does not exist on type 'HdsNavigationAttribute'`，说明大括号配对被改坏——按 `git diff` 找回缺失的 `}`，不要靠删属性绕过。

- [x] **Step 4: 16 屏深链逐屏复验**

```bash
cd /tmp/ui4 && python3 - <<'PY'
import subprocess, time, sys, re
sys.path.insert(0,'/tmp/ui4')
from drive import dump, nodes
HDC='/Applications/DevEco-Studio.app/Contents/sdk/default/openharmony/toolchains/hdc'
TID='trip-1793804833293-53pyb1'
def sh(a): return subprocess.run([HDC]+a, capture_output=True, text=True, timeout=60).stdout
def go(r,p=None):
    c=['shell','aa','start','-b','com.youjing.app','-a','EntryAbility','--ps','route',r]
    if p: c+=['--ps','param',p]
    sh(c); time.sleep(4.6)
    return [t for t,b,ty in nodes(dump()) if len(t)>1]
ok=True
for r,p,mark in [('TripInput',None,'一句话成行程'),('PreferenceQA',None,'这趟想怎么过'),('SpotPick',None,'建议停留'),
                 ('StayPick',None,'为什么是这里'),('Itinerary',TID,'去减一站'),('OnTrip',TID,'完成打卡'),
                 ('Map',TID,'全图'),('Expense',TID,'记一笔'),('Trips',None,'行程进度'),('Share',TID,'导出日历文件'),
                 ('Review',TID,'旅途回放'),('Badges',TID,'行囊里的勋章'),('Pricing',TID,'行程通行证'),
                 ('EditItinerary',None,'没有带进行程'),('AreaMore','北京','选这片'),('GenerateFailed',None,'改用本机规则引擎')]:
    ts=go(r,p)
    hit=any(mark in t for t in ts)
    print('%-14s %s %s'%(r,'✅' if hit else '✗ 没到', ('| '+ts[0][:24]) if ts else ''))
    ok = ok and hit
print('16 屏深链', '全通' if ok else '有未达')
PY
```
Expected: 16 屏全部 `✅`（判据是**目的页独有文本**，不判壳层——沿用本仓「断内容不断壳」的验收纪律）。

- [x] **Step 5: 尺与净空**

```bash
python3 tools/audit_bar_scroll.py && python3 tools/audit_inset_source.py && python3 tools/verify_scroll_clearance.py
```
Expected: `bar 调用点 22 处，未表态 0 处`（规划格的 bar 从 Index 移到页面，调用点总数应仍是 22；若变 23 说明漏删了壳层那份，回去查 Step 2）、`避让量来源：偏差 0 项`、`滚到底无遮挡（pass）`。

- [x] **Step 6: 提交**

> **执行时修正（2026-11-05，Task 6 落地）**——三处按证据改了写法：
> 1. **外层宿主不绑 `APP_NAV`，改绑新增的 `HOST_NAV`**。一个 `NavPathStack` 只能被一个
>    `Navigation` 持有，宿主若抢绑规划格的栈，`YoujingStartPage` 里那个
>    `HdsNavigation(APP_NAV)` 就失去绑定，向导链从「页签内」变成「盖住 dock 的全屏」。
>    有据 `Index.ets:2055` 的宿主本来就是独立的 `this.pageStack`，这版才是照搬。
>    新增第 6 条版式规则 `audit_layout_patterns.py --rule R6` 钉住这条不变式
>    （自测注入阳性 R6 抓到 1 处；现仓 6 个绑定点：`HOST_NAV`×1 + 五格各自 `this.pathStack`×5）。
> 2. **`YoujingStartPage` 不加 `rootMode` 双分支**：全仓它只有 Index 一个调用点（grep 确认），
>    另一支永远不跑，属为假想需求留形。直接单分支自带 `HdsNavigation`。
> 3. **`build()` 外层保持 `Column`**，没按计划改成 `Stack(alignContent: Bottom)`——
>    L2 要的是宿主 `Navigation`，换容器是夹带风险（`height('100%')` 在定高容器里的既有坑）。
>
> Step 4 的 16 屏判据也要改：`OnTrip/Review/AreaMore/GenerateFailed/Map` 五格的 marker
> 是旧文案，真机 dump 显示**全部到达**（标题分别是「旅行中」「旅行回顾」「全部区域」「生成受阻」
> 与地图格的日程筛选条），只是这些屏在当前数据下走空态 / 无错误码分支。
> 判据按「目的页标题 + 内容」而不是照抄 marker 串（沿用「断内容不断壳」）。

```bash
git add entry/src/main/ets/pages/Index.ets entry/src/main/ets/pages/YoujingStartPage.ets
git commit -m "refactor(布局): 壳层改外层 Navigation 宿主 + 五格同构自带 HdsNavigation（有据形态）"
```

---

### Task 7: L3 顶栏接口对齐——带子决策移交栏体

> **执行结论（2026-11-05）：Step 1–4 的「移交」不成立，功能改动已回退，本任务只落了死字段清理。**
> 真机同一机位三列对照（详见 `Docs/INIT_REPORT.md` §5ci 续 198）：
> `barBackground` 给实心色时 dump 的 `TitleBar` 节点仍是 `#00000000`，
> 说明 `HdsNavigationBackgroundStyle.backgroundColor` 没有落成不透明层；
> 撤掉壳层那道按页签涂色后，地图格顶边从「带子与栏区平 L=55/56」变成
> 「L=50→26 的透底图渐变」（地图 `XComponent` 从 y=281 起排，106..281 以前正是被壳层盖住的那段）。
> 回退后复拍回到 54/56/55/56，与批准基线一致。
> **所以壳层涂色不是多余图层，它就是顶边基色的实现点**；本任务保留的只有
> 删除零调用点且实测会翻乱栏内两行顺序的 `fullBleed`，以及把这条证伪写进
> `HdsChrome` / `pages/Index` 的注释（别再试第三次）。
> 顺带修了 `audit_bar_scroll.py` 的一个假红：注释里的 `HdsChrome.bar(` 被数成调用点，
> 现在跳过 `//` 与 `*` 行，并加了一条控制样本。
> Step 5 的真人复验随之一并作废（没有需要复验的视觉改动）。

**Files:**
- Modify: `entry/src/main/ets/design/HdsChrome.ets`（`ChromeSpec` + `bar()`）
- Modify: `entry/src/main/ets/pages/Index.ets:310`（去掉带子涂色）
- Modify: `entry/src/main/ets/utils/TopStrip.ets`（职责收窄为窗口背景 + 图标明暗）
- Modify: 22 个 `HdsChrome.bar` 调用点中需要底图连续顶边的那几处

**Interfaces:**
- Consumes: 无新外部
- Produces: `ChromeSpec.barBackground?: string`（资源名，底图类屏用它声明顶边基色）、`ChromeSpec.bleedTop?: boolean`（是否穿底，替代 `fullBleed` 的误用语义）；`TopStrip.paint` 不再决定带子色

- [ ] **Step 1: 扩 spec 字段**

Modify `entry/src/main/ets/design/HdsChrome.ets`，`ChromeSpec` 内追加：
```ets
  /** 顶边基色资源名（底图类屏用 `map_strip_base`）。不给即画布。
   *  带子色从此由栏体声明，壳层不再涂——壳层涂是今晚那条硬台阶的来源。 */
  barBackground?: string;
  /** 内容是否穿到栏底（底图/全屏媒体页）。true 时 enableComponentSafeArea=false。
   *  ⚠ 不要用 fullBleed 换连续顶边：真机实测会把栏内两行翻转成分段在上、标题在下（契约 §1055）。 */
  bleedTop?: boolean;
```
`bar()` 末尾的 `options` 改为：
```ets
    const options: HdsNavigationTitleBarOptions = {
      content: content,
      style: style,
      avoidLayoutSafeArea: true,
      enableComponentSafeArea: spec.bleedTop !== true && spec.fullBleed !== true
    };
```

- [ ] **Step 2: 壳层不再涂带子**

Modify `entry/src/main/ets/pages/Index.ets:310`：
```ets
    .backgroundColor($r('app.color.canvas'))
```
（替换掉 `this.stripName === STRIP_MAP ? … : …` 那行；`stripName`/`syncTopStrip`/`TOP_STRIP_KEY` 若再无消费点则一并删除，用 `grep -rn "stripName\|TOP_STRIP_KEY\|STRIP_MAP" entry/src/main/ets` 确认后再删。）

- [ ] **Step 3: 底图类屏自己声明顶边**

Modify `entry/src/main/ets/pages/MapPage.ets:182`：
```ets
    return HdsChrome.bar({ mainTitle: this.titleText, subTitle: sub, menu: items,
      scrollable: false, barBackground: 'map_strip_base' });
```
并在 `OnTripPage.ets:1107`（有 hero 媒体顶边）按同样方式声明，其余 20 处不传即画布。

- [ ] **Step 4: TopStrip 收窄**

Modify `entry/src/main/ets/utils/TopStrip.ets`：`paint()` 保留 `setWindowBackgroundColor` + 透明系统栏 + `isStatusBarLightIcon`，删除 `resName` 参数与 `TOP_STRIP_KEY`/`current()`/`apply()` 的带子语义（改为 `apply(ctx)` 只重涂窗口背景与图标）。同步改 `EntryAbility.applySystemBarSurface()` 与 `syncTopStrip` 的调用形式。

- [ ] **Step 5: 真机复验（深浅两档 + 地图格）**

```bash
tools/build_install.sh default
```
真人滚到地图格与规划页各一次，我被动抓帧量顶边连续性：
```bash
cd /tmp/ui4 && python3 - <<'SNAP'
import subprocess, time
from PIL import Image
HDC='/Applications/DevEco-Studio.app/Contents/sdk/default/openharmony/toolchains/hdc'
def sh(a): return subprocess.run([HDC]+a, capture_output=True, text=True, timeout=60).stdout
def meas(tag, ys=(30,60,90,110,150,220,300,360)):
    n='L3_'+tag
    sh(['shell','snapshot_display','-f','/data/local/tmp/%s.jpeg'%n]); time.sleep(1.6)
    sh(['file','recv','/data/local/tmp/%s.jpeg'%n,'/tmp/ui4/%s.jpeg'%n])
    g=Image.open('/tmp/ui4/%s.jpeg'%n).convert('L'); W=g.size[0]
    v=[sorted(g.getpixel((x,y)) for x in range(16,W-16,5))[len(range(16,W-16,5))//2] for y in ys]
    band=v[:3]; bar=v[3:]
    print('%-10s band=%s bar=%s diff=%d'%(tag,band,bar,max(abs(b-c) for b in band for c in bar)))
meas('plan'); meas('map')
SNAP
```
Expected: 规划页带子与栏下中位色 **差 ≤2**；地图格 `y=0..360` 全程 L≈55/56 连续；浅色档（`--ps lightprobe 1`）同样成立——浅色档地图格顶边是既有欠账，本次一并补上。

- [ ] **Step 6: 尺 + 提交**

```bash
python3 tools/audit_material.py && python3 tools/audit_colors.py && python3 tools/audit_bar_scroll.py && tools/build_install.sh default
git add entry/src/main/ets/design/HdsChrome.ets entry/src/main/ets/pages/Index.ets entry/src/main/ets/pages/MapPage.ets entry/src/main/ets/pages/OnTripPage.ets entry/src/main/ets/utils/TopStrip.ets entry/src/main/ets/entryability/EntryAbility.ets
git commit -m "refactor(布局): 带子色决策移交栏体——barBackground/bleedTop 显式声明，TopStrip 收窄为窗口背景与图标"
```

---

### Task 8: L4 顶栏跟手收起 + dock 尺寸对齐有据

> **执行结论（2026-11-05）：Step 3 按证据改写、Step 1–2 停在真人检查点。**
>
> **Step 3「dock 尺寸对齐有据」不是一次改动**：真机 dock 板 `[55,2427][1081,2602]` ÷ 3.125
> = **328.3 × 56vp**，本来就是有据基准——因为它由 `HdsTabs.barFloatingStyle` 产出，
> 不由 `floatingDockWidth: 300` 算出来。把 token 改成 328.3 是**把镜像值当输入**，
> 而 `audit_geometry.py` 要求契约每个 layout 键都有同名 token，所以两个 token 保留原值、
> 注释改成写清「这是契约镜像，实测是 328.3×56，差异进 Task 9 的契约待改清单」。
>
> **`floatingDockClearance` 不降 84**：84 只在手势档刚好（实测 (2690-2427)÷3.125=84.2vp），
> 三键档 dock 抬高 `barHeight+1≈28.8vp` ⇒ 需要 112.8vp，按 84 钉会把末行压进 dock 底下
> （这是算术，不是猜测，且本机没有三键设备可复验）。保持 112 = 最大档上界，
> 多出的 28vp 是滚动区底部空白而不是遮挡。按档派生的前提是 24 处消费点都能直读 `dockNavInset`，
> 那是独立一轮的活，不在本层夹带。
>
> **Step 1–2（跟手收起）未执行，停在真人检查点**，两个理由都是硬的：
> ① 前提条件与已证伪的 L3 撞车——`dynamicHideTitleBar` 必须配 `enableComponentSafeArea=false`
> 才不会让内容跑 2.2 倍速（记忆 `arkui-hds-dynamichide-safearea-double-speed`，真机踩过、
> `hideRatio` 治不了），而 `false` 就是「穿底」形态，动的正是 Task 7 刚刚证伪的那块顶边几何；
> ② 这一层脚本无法自证（注入 fling 不触发 HDS 滚动特效），本仓库的纪律是不合入无法验证的代码。
> 要开这一格，需要真人配合跑一遍：五格各滚到底再回顶，看顶栏收起有无跳变、内容位置是否抖、
> 以及地图格顶边是否退回 Task 7 那种渐变。

**Files:**
- Modify: `entry/src/main/ets/design/HdsChrome.ets`（新增 `hideOnScroll` 支持）
- Modify: 五格根页（`MapPage` / `TripsPage` / `ExpensePage` / `MinePage` / `YoujingStartPage`）
- Modify: `entry/src/main/ets/design/LayoutTokens.ets:125-127`（dock 尺寸按有据基准）

**Interfaces:**
- Consumes: Task 4 的 `dockNavInset`
- Produces: `ChromeSpec.hideOnScroll?: boolean` + `ChromeSpec.scroller?: Scroller`；`floatingDockWidth: **300**`（**2026-11-06 续 205 更正**：原写 328.3 是"不设 `barWidth` 时官方排出来的读数"，把它写进 token 是把镜像当输入；正确做法是 `barWidth.smallWidth = 300`，真机实测板宽 300.2vp、与有据逐像素相同）、`floatingDockBarHeight: 56`、`floatingDockClearance: **112**`（**续 199 更正**：84 是手势档 dock 净空本身，按 84 钉会在三键档把末行压进 dock；112 是最大档上界，属既定取舍，见续 223）

- [ ] **Step 1: 栏体跟手收起**

Modify `entry/src/main/ets/design/HdsChrome.ets`：`ChromeSpec` 加
```ets
  /** 顶栏跟手收起（有据 HomeTab 同款）。⚠ 必须与 bleedTop 一起评估：
   *  dynamicHideTitleBar 配 enableComponentSafeArea=true 会让内容跑 2.2 倍速，
   *  hideRatio 治不了——真机踩过，所以本开关只在页面已按 §7.6.11 穿底配好时才开。 */
  hideOnScroll?: boolean;
```
返回处不变（`dynamicHideTitleBar` / `bindToScrollable` 是 `HdsNavigation` 的属性，不在 titleBar options 里）。

- [ ] **Step 2: 五格各自挂上**

以 `TripsPage.ets:708-729` 的 rootMode 分支为例，其余四格同形：
```ets
      .dynamicHideTitleBar({ hideBottomBuilder: true, mode: HideMode.SCROLL_UP_TO,
        hideOffset: 0, hideRatio: 1.0 })
      .bindToScrollable(this.mainScroller)
      .clip(false)
```
（`this.mainScroller` 用各页现有的 `barScroller`；`HideMode` 从 `@kit.UIDesignKit` 导入。）

- [ ] **Step 3: dock 尺寸对齐有据**

Modify `entry/src/main/ets/design/LayoutTokens.ets`：
```ets
  floatingDockWidth: 300,          // **续 205 更正**：原写 328.3 是官方默认排版的读数；现在由 barWidth.smallWidth 显式给 300（真机 300.2vp 与有据同值）
  floatingDockBarHeight: 56,       // 栏体高，dock 预留的基数
  floatingDockBottomMargin: 28,
  floatingDockClearance: 84,       // 整块预留 = 56 栏 + 28 底部安全区（原 112 是推导值，按基准改）
```
接口区同步加 `floatingDockBarHeight: number;`。

- [ ] **Step 4: 净空与遮挡回归**

```bash
tools/build_install.sh default && python3 tools/verify_scroll_clearance.py && python3 tools/audit_button_width.py
```
Expected: `滚到底无遮挡（pass）`。**注意**：预留从 112 降到 84 会让 24 处 `bottom: floatingDockClearance` 全部变小，`verify_scroll_clearance.py` 是唯一能证明末行仍滚得出来的判据；任何一屏报 ⚠ 都要当层回退，不许调容差让它过。

- [ ] **Step 5: 真人观感验收**

真人逐格滚动确认：顶栏跟手收起无跳变、内容不跑 2.2 倍速（判据：滚到底再回顶，末行位置与 dock 不抖）、dock 变宽后左右边距与图标间距观感符合预期。**这层脚本无法自证**（注入 fling 不触发 HDS 滚动特效），未拿到真人结论前不得宣布完成。

- [ ] **Step 6: 提交**

```bash
git add entry/src/main/ets/design/HdsChrome.ets entry/src/main/ets/design/LayoutTokens.ets entry/src/main/ets/pages/MapPage.ets entry/src/main/ets/pages/TripsPage.ets entry/src/main/ets/pages/ExpensePage.ets entry/src/main/ets/pages/MinePage.ets entry/src/main/ets/pages/YoujingStartPage.ets
git commit -m "feat(布局): 顶栏跟手收起 + dock 尺寸按有据基准（328.3×56 / 预留 84vp）"
```

---

### Task 9: 全量收口——契约待改清单、尺数与文档、README

**Files:**
- Modify: `README.md:23,39,83`（十九把尺 + 新基线例数）
- Modify: `Docs/INIT_REPORT.md`（L2/L3/L4 各一节，含实测数字与未验项）
- Modify: `CHANGELOG.md`
- Create: `Docs/superpowers/specs/2026-11-05-契约待改清单.md`（spec §6A 展开，交用户逐条确认）

- [x] **Step 1: 全量闸门**

```bash
for r in colors type geometry material fontfamily tnum elevation button_width scroll_actions label_fit a11y_name layout_patterns skip_worktree motion bar_scroll seed self_call span_source inset_source; do printf "%-15s " $r; python3 tools/audit_$r.py 2>&1 | tail -1 | cut -c1-70; done; \
bash tools/verify_dock_tabs.sh; python3 tools/verify_scroll_clearance.py
```
Expected: 十九把无新增红；`verify_scroll_clearance` pass；`verify_dock_tabs.sh` 的 §4j 六项需真人逐条对，脚本只给证据目录。

- [x] **Step 2: hypium 新基线**

按 Task 1 Step 5 的命令跑一次，把实际例数记进 README（预期 251/251，若 Task 8 加了用例以新增数为准）。

- [x] **Step 3: 写契约待改清单**

`Docs/superpowers/specs/2026-11-05-契约待改清单.md`，逐条给：契约条目原文、迁移后实现值、实测证据（哪个屏、哪个数字）、建议改法。**不碰 `~/Pictures/…/DESIGN.md` 本体**，只出清单。

- [x] **Step 4: 文档与提交**

```bash
git add README.md Docs/INIT_REPORT.md CHANGELOG.md Docs/superpowers/specs/2026-11-05-契约待改清单.md
git commit -m "docs(布局): 迁移收口——十九把尺读数、hypium 新基线与契约待改清单"
```

---

## Self-Review（写完后的一次自查，已按结果修订）

1. **Spec 覆盖**：G1→Task 1/2/3/4；G2→Task 6；G3→Task 7/8；G4→每层的独立提交与「当层回退」条款；§6A→Task 9 Step 3；§5 复验协议→Task 4/5/7/8/9 的验收步骤。无遗漏。
2. **占位符**：Task 7 Step 5 的抓帧脚本我给的是"沿用 Task 3 Step 4 的写法"的指路而非重复代码——这是**有意的**，两处判据完全相同；执行时按 Task 3 的 meas 片段展开即可，不构成 TBD。
3. **类型一致性**：`BOTTOM_NAV_INSET_KEY`（Task 2 定义）↔ Task 4 消费同名；`dockNavInset` 变量名与有据一致；`computeNavInset`/`computeBarInset` 在 Task 1 定义、Task 2 调用签名一致（三参数顺序 heightVp, bottomRectWidthVp, windowWidthVp）；`floatingDockBarHeight` 在 Task 8 同时补接口声明与取值。
4. **范围**：四个层次属于同一子系统（布局几何），单计划可承载；但 L4 依赖真人验收，执行时应在 Task 7 后设一个显式检查点向用户要一次现场配合，不要攒到最后。

---

## 执行收口（2026-11-06 深夜最终版）

这份计划原本只有四层（L1 几何单源 → L2 壳层形态 → L3 顶栏接口 → L4 顶栏行为）。
执行到 L4 后目标被扩宽成「按有据的**界面结构和布局体系**来」，于是又跑了三轮扫描
（配置面 → token 数值 → 组件选档语义）。**判据只有一个：spec §10 覆盖对表（32 行）**，
本计划不再另立口径。

### 一、四层的结果
- **L1 几何单源**：已落地。底部避让量唯一来源 `utils/navMode` → `BOTTOM_NAV_INSET_KEY`；
  第 19 把尺 `audit_inset_source`（R1 不得自算 / R2 dock 读单源键 / R3 滚动预留按档派生）。
- **L2 壳层形态**：已落地。宿主 `Navigation(HOST_NAV)` + 五格各自 `HdsNavigation`+`titleBar`；
  「同一栈被多处绑定」做成尺规则 R6。
- **L3 顶栏接口**：**真机证伪并回退**——栏体画不出不透明层，壳层那道按页签涂色就是顶边基色的实现点。
- **L4 跟手收起**：**停在真人检查点**（任务 #26）。前提是穿底，正撞 L3 证伪的顶边几何。

### 二、今晚新增并已验证的（都有读数或尺）
| 项 | 证据 |
| --- | --- |
| dock 板宽三档 | 手机 `[99,2427][1037,2602]`=300.2×56vp 与有据逐像素相同；md 档 `[230,2153][1980,2328]`=560.0×56vp、切页不跳宽 |
| 液态选中胶囊 | 五格逐位 +0.5px、浅色档表面差 −0.026、md 档容器 162.88vp 对上公式 162.9、跟位 +0.5/+1.0px |
| 胶囊盖住的官方页签 opacity gate | 真机被盖那颗外层 Column 读 `opacity=0.000000`，实拍玻璃下无第二份图标 |
| 系统栏六字段 | 应用深/系统浅的对照量：带子最亮 2% 均值 253；浅色档最暗 2% 均值 50 |
| 横滑切页 | `.scrollable(true)` + 胶囊起飞迁 `onAnimationStart`；真机三条路径验通 |
| 卡面内缩 22 处 | 按契约收到 16，尺 `audit_card_inset`=0；真机父→直接子级左内缩 屏2/我的/费用 =16.0、行程屏 16.0×2 |
| 回弹常开 13 处 | `audit_scroll_actions` 扩 `SPRING_BARE` 规则，先红 13 后绿 |
| 吸顶组头底板 2 处 | SpotPick/AreaMore 补 `canvas` 底板（另三处本来就有） |
| 两档对比度 | 浅色 7 屏（19–35 节点）+ 深色 5 格（21–37 节点）**全部 0 违规** |
| 回归 | **当前 HEAD 产物 254/254、Failure 0**（续 246 在本地模拟器 Mate 90 Pro Max 上跑完整 `aa test`；254＝旧 251＋续 237 新增 3 例，数字对得上才证明跑的是新包）；上一轮真机读数 251/251 未被推翻，只是不再代表当前代码；**24 把**静态尺全 0（`audit_card_inset`/`audit_sticky_header` 为本轮新增；`audit_contrast` 需 dump+截图参数） |
| 离线回归（续 241 新增能力） | `node tools/offline_hypium/run.mjs` → **28 套件 / 192 例全过**（跑的就是 `ohosTest` 那批用例源码，一条断言不复制）；10 套件因闭包含 `@kit.*`（TestKit/AbilityKit/ArkData/AccountKit 等需设备上下文）只能真机；`--selftest` 证明这条管线会红。离线过了不等于真机过了，`aa test` 仍是权威 |

### 二·补　续 235–240（设备不可达那段时间做完的四面，全有静态证据）
| 项 | 落点与证据 |
| --- | --- |
| 吸顶组头**带高单源**（第 29 行另一半） | 四处钉 `LayoutTokens.stickyHeaderHeight`=36（有据 `PublishTagPanel.ets:83-86`，契约对单行组头无档），`dayHeader` 留契约 44；尺 `audit_sticky_header` 加第 5 条，HEAD 反证抓 4 处、现 0 偏差 5 配对 |
| 补设通道**宿主接线 1/16 → 16/16**（第 4 行） | 15 页 `syncBarScroll()` 回顶时调 `requestSystemBarRefresh()`；第 24 把尺 `audit_systembar_refresh`（R1 接线+条件+import、R2 注册器、R3 连发 ≥3 发末发 ≥2500ms），HEAD 反证抓 15 处 |
| 兜底链路**第二条 avoid rect**（第 30 行） | `publishNavAvoid` 补读 `TYPE_SYSTEM`；数学抽进 `navInset`，离线 `node --experimental-strip-types` 6 组断言全过、`NavInset.test` 5→8 例、双 HAP 构建过。**写法有意偏离有据的 max**，判掉它需要两档真值（任务 #37） |
| 滚动宿主 `edgeEffect` **13 处挂满 26/26**（第 21 行） | 逐宿主括号配对判"字段整个没写"，倒序插入 + 每处重解析确认链上恰好一条，numstat 每处 +1/−0；尺第三条已进硬闸，真代码反证 rc=1/0 |
| 配置面**全表普查**（第 32 行） | SDK 声明列 94 个面：dock 28+10、Navigation 25+23、顶栏 6+2。差异只剩 4 个一边为 0 的名字，全部归到既有格；`overlayBackGuard` 判为不适用（有径 bindSheet 19 / 自绘层 0） |

### 三、仍开着的格（都写在 spec 对表里，编号对应；续 240 后为九条）
**要手指（三格）**
1. 第 4 行 HDS 回顶回写：屏2 长表单滚到底再回顶，看状态栏图标有没有闪/跳。
   （注入 `swipe`/`fling`/`dircFling` 在本机对这几页滚不动——不是注入失效，是那些页内容不满一屏；
   屏2 那种长表单今天确实被注入滚过，所以试验台只有它。）
2. 第 21 行回弹手感：屏1/3/9 拉一次短列表，看是橡皮筋还是"拉不动像卡死"。
3. 第 14 行胶囊观感：切几次页签看鼓包+回弹、按住看缩放（浅色档玻璃存在感弱是已知特性）。

**要点头（三格 + 两项授权）**
4. 第 13 行 L4 跟手收起：要穿底，代价是可能请回第 8 行证伪过的顶边硬台阶。
5. 第 15 行一镜到底转场：属转场体系不是布局骨架，要不要做是产品取舍。
6. 第 19/20 行 穿底 + 栏级材质：**同一个改动**。真机取证已证明栏体下面从来没有内容
   （地图格 y100–260 全 255、底图从 300 开始），没穿底材质就是白压白；配方在任务 #31。
7. **push** 与 **合并 main**（分支领先本地 `main` 的提交数以 `git rev-list --count main..HEAD` 现算为准，写死就会过期——本轮实测从 63 涨到 66）。
8. **第 31 行 材质入口三处零消费**（任务 #38）：`GlassBlurStyle`/`TopButtonMaterialModifier`/
   `FloatingTopButtonMaterialModifier` 在有径只有声明、0 个 import 方。删（零行为变化）或
   给顶栏钮接材质（可见变化，必须真机 A/B）——两句之一即可，默认建议删，
   因为顶栏钮外观已由 `HdsNavigation` 栏级材质负责。
9. **第 30 行有意偏离**（任务 #37）：有据对两条 avoid rect 取 `max`，本仓落的是保守形
   （指示条有读数就用、为 0 才回退）。要判掉只需在真机两档各读一次两条 rect 的 height/width；
   读出来若三键档下 `TYPE_SYSTEM` 确实更高且满宽，就换回有据写法并删那条偏离用例。

### 四、两条观察（不是缺陷，留档）
- 规划页「结构化路线承诺」静止态被 dock 盖掉半句：dump 证明**不是裁剪**（文本底 2447 < 卡片 clip 底 2534），
  页面能滚出约 194px；要不要让预览卡在 dock 之上收尾是设计取舍。
- 本机有两趟几乎相同的「北京」行程（同日期同人数同 ¥1,540，景点 8 vs 9）——是**数据**，删不删由用户定。

### 四·补　真机一轮跑完的顺序（续 250 收尾时定稿，一次会话可全部量完）

```bash
hdc list targets                      # ① 先取真实 URI——模拟器每实例端口不同（5555/5557），真机也别说死
T=<上一步的 URI>
tools/build_install.sh                # ② 构建成功才装机（装机成功不证明产物含改动）
python3 tools/verify_route_sweep.py --target $T          # ③ 真机 sm 档 17 屏结构巡检
python3 tools/verify_route_sweep.py --target $T --only SpotPick,Trips   # ④ 带高 36vp / 卡内缩 16.0vp 读数
hdc -t $T shell aa test -b com.youjing.app -m entry_test -s unittest OpenHarmonyTestRunner   # ⑤ 254 例
# ⑥ 手指四格（脚本替代不了，见对表第 4/14/21/29 行）：
#    短内容页拉一下看橡皮筋与回位 · 切几次页签看胶囊鼓包与按压缩放 ·
#    长表单滚到底再回顶看状态栏图标是否闪/跳 · 滚动态看吸顶组头有无字压字
# ⑦ 第 30 行的偏离判定：系统设置切「三键 / 手势」两档，各读一次
#    TYPE_SYSTEM.bottomRect 与 TYPE_NAVIGATION_INDICATOR.bottomRect 的 h/w（÷3.125）
```

等一句裁决的五项（每项都已在对表写明代价，不重复展开）：
**#26** L4 跟手收起（前提是穿底，可能请回第 8 行证伪过的顶边硬台阶）·
**#15** 一镜到底转场（转场体系，不是布局骨架）·
**#31** 穿底 + 栏级材质（同一个改动，配方与 A/B 判据都在任务里）·
**#38** 材质入口三处零消费（删=零行为变化；接=可见变化需真机 A/B）·
**push／合并 main**（分支领先本地 `main` 的提交数按 `git rev-list --count main..HEAD` 现算）。

### 四·终·要你做的三件事（每件 ≤1 分钟，做完就能收口）

**A. 看一眼五项观感**（手机已装当前包，直接点开即可）
1. 行程 tab → 点第二张进行中的行程卡 → 看**卡片飞入详情**是否顺（约 0.35s）、
   落地时有没有「图→灰块→内容」的闪跳；返回时看是否原路飞回。
2. 我的 / 费用 / 今日 这类短列表 → 手指**往下拉一下**：有没有橡皮筋、松手是否回位。
3. 长列表上滑 → 看顶栏（含分段/搜索行）是否**跟着手指**收、下滑是否原样展开。
4. 看底部浮动 dock：切几次页签看胶囊跟不跟手、按住有没有按压缩放。
5. 系统设置里把系统切深色、App 保持浅色（或反之），在长表单里滚到底再滚回顶部，
   看状态栏图标有没有**闪一下/跳色**。
> 回复格式：逐条「OK / 有问题（一句话描述）」即可。

**B. 三键档（30 秒）**：手机「设置 → 系统和更新 → 系统导航方式」切到**三键**，
然后重新打开有径（冷启）。我读一行 `avoidRects` 日志就能判第 37 行要不要改。
切完回来说一声「已切三键」，用完记得切回你习惯的档。

**C. 合并授权**：push 已完成（分支 `feat/layout-structure-migration`，领先 main 112 提交）；
要不要合并到 `main` 只差一句「合并吧」。

**B/C 任何一个先回都行；A 可以慢慢看。**

> **合并预演（2026-11-07，未执行）**：`git merge-tree $(git merge-base main HEAD) main HEAD`
> 报 **0 冲突**；本地 `main` 仍在分叉点 `203c991`（没人动过），所以这条分支并进 main 是
> **无冲突**操作。改动面 64 个文件、+7081/−346（含 3 把新尺、离线执行器、两页 bottomBuilder 迁移、
> 一镜到底移植）。等你一句「合并吧」即执行。


### 四·终　2026-11-07 三项授权落地后的终盘状态

用户裁决：**#38 删 / 13·15·19·20 做（风险自认） / push 授权**。四项均已落地并推送：

| 项 | 状态 | 关键证据 |
| --- | --- | --- |
| #38 删死码 | ✅ 完成 | 三个零消费材质入口连缓存清除，−63 行，材质尺 0 |
| 13 跟手收起 | ✅ 机制结案 | 全页铺满；真机双向 175→0→175px（带栏内行页 325→175px）；比例 0.98≈1:1 |
| 15 一镜到底 | ✅ 移植结案 | register success + `initParams scale=0.9119718` + 终态满幅 + 单次 Back 返回；补 onHeroReady 后 2.5s→1.1s 落定 |
| 19/20 穿底+材质 | ✅ 结案（设计结论） | 两档 16 屏无内容被栏盖；导航行 2 页迁入 bottomBuilder；**材质无折射经阳性对照判为设计使然**（dock 与栏面两个玻璃面在内容滚过时像素都不变，而列表中部差 44.38%）——玻璃面近不透明，契约自己写明「白面到 251 无向上余量」 |
| push | ✅ 已推 | `feat/layout-structure-migration`，领先本地 main 100+ 提交，**未合并** |

**仍待人（自动化已尽力）**：
1. 人眼五项（任务 #30）：一镜到底飞行顺滑与交接、回弹手感、跟手 1:1 观感、dock 胶囊观感、SpotPick 滚动态字压字。
2. 三键导航档（任务 #37）：需用户在系统设置切一次，切后冷启读 hilog `avoidRects` 那行即可判。
3. 合并 main 的授权（当前只授权了 push）。

### 五、施工纪律（这一整轮反复用到的）
- 装机/点击前必须断言前台与当前屏；真人正在用手机时立刻停手（本轮有 90 分钟设备被占用，全部改走模拟器/源码取证，没抢过一次屏）。
- 不锁屏绕过、不删用户数据、不为了过闸改 `~/Pictures/…/DESIGN.md`。
- 只按 pathspec 提交，一轮一笔；push 需要单独授权（至今未 push）。
- 检测器报 0 之前先反证它抓得到；数值改动要用与"发现候选"不同方向的判据复核落点。
- **无法验证的代码不合入**，改交付配方（本轮实际执行三次：L3 回退、栏级材质回退、方案 c 自我推翻）。
- 模拟器 `snapshot_display`+`file recv` 在本机不可靠（本轮三次挂死），要出帧优先用手机。
