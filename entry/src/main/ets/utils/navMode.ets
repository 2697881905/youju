// 系统导航方式检测（三键导航 / 悬浮球 / 手势导航条）+ 底部避让量计算
//
// 判断依据（HarmonyOS 无公开「导航方式」直读 API，采用两层信号融合）：
//  1) 权威信号：系统在 settings 的 USER_PROPERTY 域维护键 'float_navigation_info'，
//     JSON 形如 { showType, region }：
//       showType = 0  → 三键导航已显示（region = [x,y,w,h]，单位 px，含三键栏真实高度）
//       showType = 1  → 悬浮球导航
//       showType = -1 → 未显示三键导航（全面屏手势 / 导航条）
//     读取与监听：settings.getValueSync / settings.registerKeyObserver（均 @since 11，
//     工程下限 API 20 覆盖）；读 USER_PROPERTY 不需要任何权限（仅写需要）。
//  2) 兜底信号（仅 settings 键缺失时）：navBarHeight = max(TYPE_SYSTEM, TYPE_NAVIGATION_INDICATOR)
//     的 bottomRect 高度(vp)。**只看高度判不开两种模式**——模拟器手势条实测 27.9vp，真机三键栏
//     实测 27.8vp，区间完全重叠（旧注释"16-24 / 28-42 不重叠"是错的，模拟器上直接后果是把
//     手势条当三键、Dock 白抬 28.9vp）。改用物理量判别：三键栏的避让矩形必然横贯整屏
//     （左/右两颗键不可能落在自己的避让区之外），手势指示条是居中的窄胶囊
//     （模拟器实测 bottomRect 宽 137vp / 屏宽 391vp = 35%）。故要求「高度 > 24vp **且** 宽度
//     ≥ 屏宽 90%」才判三键；上报缺项时一律保守判手势（避让 0，维持原布局）。
//     settings 键缺失（模拟器 / 部分云手机 / 非华为 ROM）时走此判据。
//
// 响应式约定（两次实测踩坑后定稿）：
//  消费方必须 @StorageLink(BOTTOM_NAV_INSET_KEY) 并在 build 属性里**直接读该状态变量**
//  （见 DetailActionBar）。⚠️ 只挂 link 而不在 build 里读变量是无效的 —— ArkUI 只为
//  「初始渲染时被读过的状态变量」建立更新绑定，变量不进 build，刷新全是空操作。
//  重算并写回 BOTTOM_NAV_INSET_KEY 的三个刷新点：
//   · settings 观察者回调（系统设置里切换导航方式，实时）
//   · EntryAbility.onForeground（后台切换导航方式后回前台 —— avoidAreaChange 不派发，实测）
//   · PostDetailView.applyWindowInsets（avoidAreaChange / 页面重测 navBarHeight 时）

import settings from '@ohos.settings';
import display from '@ohos.display';
import { common } from '@kit.AbilityKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { hilog } from '@kit.PerformanceAnalysisKit';

const TAG: string = 'navMode';
const DOMAIN: number = 0x0000;
const FLOAT_NAVIGATION_INFO_KEY: string = 'float_navigation_info';

export const NAV_MODE_KEY: string = 'navMode';
export const NAV_MODE_GESTURE: string = 'gesture';
export const NAV_MODE_THREE_BUTTON: string = 'three-button';
export const NAV_MODE_FLOATING_BALL: string = 'floating-ball';
// 三键栏高度（vp）：来自 settings region[3]
export const NAV_BUTTON_BAR_HEIGHT_KEY: string = 'navButtonBarHeight';
// 底部避让量（vp）：响应式消费方 @StorageLink 此键，并在 build 属性里直接读变量
export const BOTTOM_NAV_INSET_KEY: string = 'bottomNavInsetVp';
// 内容级底部安全内边距（vp）：详情页互动栏 / 聊天输入栏等**内容控件**用。
// 按导航模式取值：三键 = 避让量（栏高 + 呼吸）；手势 = 指示条高度常量；悬浮球/未知走兜底判别。
// ⚠️ 与 BOTTOM_NAV_INSET_KEY 分开：后者是「悬浮 Dock 的边距」语义（手势下恒 0，
// 底栏维持原设计不整体顶高），二者混用会让手势设备上的主底栏位置变化。
export const BOTTOM_BAR_INSET_KEY: string = 'bottomBarInsetVp';

// 高度阈值兜底判别（单独不够，见文件头：模拟器手势条 27.9vp 与真机三键栏 27.8vp 重叠，
// 必须与「避让矩形是否横贯整屏」联合判别）
export const GESTURE_INDICATOR_MAX: number = 24;
// 三键栏判定所需的避让矩形最小宽度占比：三键栏必然满宽（左右两颗键不能被排除在避让区外），
// 手势指示条是居中窄胶囊（实测 35%）。取 0.9 留分屏/小窗余量。
export const THREE_BUTTON_MIN_WIDTH_RATIO: number = 0.9;
// 兜底判据的实测宽度比（1=满宽三键栏 / 0=窄胶囊或尚未上报）
export const NAV_BAR_SPANS_WIDTH_KEY: string = 'navBarSpansWidth';
// 三键避让的额外呼吸空间（vp）。初版 10 → 7 → 3 → 1（2026-09-28 用户多轮实测下调）：
// 总避让 ≈27.8+1=28.8vp，贴着审核 28vp 线；再降（0）会顶到导航栏上沿，不建议。
export const NAV_INSET_EXTRA: number = 1;

interface NavigationButtonInfo {
  showType: number; // -1 未显示(手势) / 0 三键 / 1 悬浮球
  region: number[]; // [x, y, w, h]，px
}

let watcherStarted: boolean = false;

// 当前是否三键导航（settings 判别优先；键缺失时退回高度阈值判别）
export function isThreeButtonNav(): boolean {
  const mode: string = (AppStorage.get<string>(NAV_MODE_KEY) ?? '');
  if (mode === NAV_MODE_GESTURE || mode === NAV_MODE_FLOATING_BALL) {
    return false;
  }
  if (mode === NAV_MODE_THREE_BUTTON) {
    return true;
  }
  return (AppStorage.get<number>('navBarHeight') ?? 0) > GESTURE_INDICATOR_MAX
    && (AppStorage.get<number>(NAV_BAR_SPANS_WIDTH_KEY) ?? 0) === 1;
}

// 计算当前底部避让量（vp）：三键 = max(settings 真实栏高, 避让区测量) + 呼吸；
// 手势导航条 / 悬浮球 / 未知 → 0（维持原布局，永不劣化）
export function computeBottomNavInset(): number {
  if (!isThreeButtonNav()) {
    return 0;
  }
  const bar: number = AppStorage.get<number>(NAV_BUTTON_BAR_HEIGHT_KEY) ?? 0;
  const nav: number = AppStorage.get<number>('navBarHeight') ?? 0;
  return Math.max(bar, nav) + NAV_INSET_EXTRA;
}

// 手势导航指示条避让高度（vp）：官方口径手势条 16-24vp，取 16（栏体自身另有 8-12vp 内边距，
// 合计 ≥24vp，覆盖指示条触发区）。
// ⚠️ 不取 avoidArea 实测值：实测（2026-10-08 真机日志）发现切到手势后 window 底部避让区
// 仍报三键档高度（bottomRect 87px ≈ 27.8vp，切模式后不变）——若取实测，避让量会卡在三键档，
// 表现为「切换导航模式后底栏高度纹丝不动」。避让高度必须按**模式**给值，不能信这个实测。
export const GESTURE_INDICATOR_INSET: number = 16;

// 内容级底部安全内边距：按导航模式取值（三键 = 栏高 + 呼吸；手势 = 指示条常量；
// 悬浮球/未知 = 走既有兜底判别）
export function computeBottomBarInset(): number {
  const mode: string = AppStorage.get<string>(NAV_MODE_KEY) ?? '';
  if (mode === NAV_MODE_GESTURE) {
    return GESTURE_INDICATOR_INSET;
  }
  return computeBottomNavInset();
}

// 底部避让区实测值上报（Index.setupFullScreen / PostDetailView.applyWindowInsets 两处）。
// 三个量必须同时上报：兜底判据要拿 bottomRect 的**宽度**和屏宽比，只给高度会把
// 模拟器的手势条误判成三键栏（实测差出一整档 28.9vp 避让）。
export function reportBottomAvoid(heightVp: number, bottomRectWidthVp: number, windowWidthVp: number): void {
  AppStorage.setOrCreate<number>('navBarHeight', heightVp);
  const spans: boolean = windowWidthVp > 0 && bottomRectWidthVp >= windowWidthVp * THREE_BUTTON_MIN_WIDTH_RATIO;
  AppStorage.setOrCreate<number>(NAV_BAR_SPANS_WIDTH_KEY, spans ? 1 : 0);
  refreshBottomNavInset();
}

// 重算避让量并写回 AppStorage（@StorageLink 的消费方随即重渲染）。
// 两个键同刻更新：Dock 边距 + 内容级内边距。日志留痕便于真机核对切模式是否生效。
export function refreshBottomNavInset(): void {
  const dock: number = computeBottomNavInset();
  const content: number = computeBottomBarInset();
  AppStorage.setOrCreate<number>(BOTTOM_NAV_INSET_KEY, dock);
  AppStorage.setOrCreate<number>(BOTTOM_BAR_INSET_KEY, content);
  // ⚠️ 占位符必须是 %{public}s：写成 %{public}f 时 hilog 把 'f' 当字面量吞掉，
  // 日志只剩 "dock=}fvp"（2026-10-30 模拟器取证实测），等于没打。
  hilog.info(DOMAIN, TAG, 'bottom insets: dock=%{public}s content=%{public}s mode=%{public}s',
    dock.toFixed(2), content.toFixed(2), AppStorage.get<string>(NAV_MODE_KEY) ?? 'unknown');
}

// 非响应式消费方（既有 5 处调用点）：读 AppStorage 现值，尚未初始化时现算
export function bottomNavInset(): number {
  const cached: number = AppStorage.get<number>(BOTTOM_NAV_INSET_KEY) ?? -1;
  if (cached >= 0) {
    return cached;
  }
  return computeBottomNavInset();
}

// 应用启动时调用一次（EntryAbility.onWindowStageCreate）。幂等：重复调用不再注册。
export function initNavModeWatcher(context: common.Context): void {
  if (watcherStarted) {
    return;
  }
  watcherStarted = true;
  refreshNavMode(context);
  refreshBottomNavInset();
  try {
    const ok: boolean = settings.registerKeyObserver(context, FLOAT_NAVIGATION_INFO_KEY,
      settings.domainName.USER_PROPERTY, (_err: BusinessError): void => {
        // 导航方式在系统设置里被切换 → 重读重算；消费方经 @StorageLink 即时响应，免重启
        refreshNavMode(context);
        refreshBottomNavInset();
      });
    if (!ok) {
      // 注册失败：保留首读结果，消费方继续走高度阈值兜底
      hilog.warn(DOMAIN, TAG, 'registerKeyObserver returned false');
    }
  } catch (e) {
    hilog.warn(DOMAIN, TAG, 'registerKeyObserver threw: %{public}s', (e as Error).message);
  }
}

// 重读系统导航配置并归一化 → AppStorage（不含避让量，那由 refreshBottomNavInset 负责）。
// 任何失败静默降级（保持原值/未知）。EntryAbility.onForeground 也会调用它：
// 「在后台切换导航方式 → 回前台」时 avoidAreaChange 不派发，靠这里补读最新配置。
export function refreshNavMode(context: common.Context): void {
  try {
    const raw: string = settings.getValueSync(context, FLOAT_NAVIGATION_INFO_KEY, '',
      settings.domainName.USER_PROPERTY);
    if (raw.length === 0) {
      // 键不存在（模拟器 / 部分云手机 / 非华为 ROM）→ 保持「未知」，消费方走高度阈值兜底
      hilog.info(DOMAIN, TAG, 'float_navigation_info absent, fallback to avoid-area heuristic');
      return;
    }
    const info = JSON.parse(raw) as NavigationButtonInfo;
    // showType 缺失/非法（JSON.parse 出的运行时 undefined → NaN）→ 不写 mode，保持未知
    const showType: number = Number(info.showType);
    if (isNaN(showType)) {
      hilog.warn(DOMAIN, TAG, 'float_navigation_info has no showType');
      return;
    }
    if (showType === 0) {
      const region: number[] = Array.isArray(info.region) ? info.region : [];
      const barPx: number = region.length >= 4 ? region[3] : 0;
      const density: number = display.getDefaultDisplaySync().densityPixels;
      const barVp: number = density > 0 ? barPx / density : 0;
      AppStorage.setOrCreate<number>(NAV_BUTTON_BAR_HEIGHT_KEY, barVp);
      AppStorage.setOrCreate<string>(NAV_MODE_KEY, NAV_MODE_THREE_BUTTON);
      hilog.info(DOMAIN, TAG, 'nav mode: three-button, bar=%{public}svp', barVp.toFixed(2));
      return;
    }
    if (showType === 1) {
      AppStorage.setOrCreate<string>(NAV_MODE_KEY, NAV_MODE_FLOATING_BALL);
      hilog.info(DOMAIN, TAG, 'nav mode: floating-ball');
      return;
    }
    if (showType === -1) {
      AppStorage.setOrCreate<string>(NAV_MODE_KEY, NAV_MODE_GESTURE);
      hilog.info(DOMAIN, TAG, 'nav mode: gesture (indicator)');
      return;
    }
    hilog.warn(DOMAIN, TAG, 'unknown showType=%{public}d', showType);
  } catch (e) {
    // 读取/解析失败：保持当前值（未知 → 消费方走兜底判据），不外抛
    hilog.warn(DOMAIN, TAG, 'refresh failed: %{public}s', (e as Error).message);
  }
}
