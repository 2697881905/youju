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
//  2) 兜底信号：navBarHeight = max(TYPE_SYSTEM, TYPE_NAVIGATION_INDICATOR) 的 bottomRect(vp)，
//     高度阈值 >24vp 判三键 —— 手势导航条约 16-24vp、三键导航条约 28-42vp，区间不重叠。
//     settings 键缺失（模拟器 / 部分云手机 / 非华为 ROM）时退回此判据，行为与历史版本一致。
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

// 高度阈值兜底判别：手势导航条约 16-24vp、三键导航条约 28-42vp，区间不重叠
export const GESTURE_INDICATOR_MAX: number = 24;
// 三键避让的额外呼吸空间（真机实测贴上沿仍显挤）
export const NAV_INSET_EXTRA: number = 10;

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
  return (AppStorage.get<number>('navBarHeight') ?? 0) > GESTURE_INDICATOR_MAX;
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

// 重算避让量并写回 AppStorage（@StorageLink 的消费方随即重渲染）。
export function refreshBottomNavInset(): void {
  AppStorage.setOrCreate<number>(BOTTOM_NAV_INSET_KEY, computeBottomNavInset());
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
