// 系统导航方式检测（三键导航 / 悬浮球 / 手势导航条）
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
// 兼容性要点：
//  - registerKeyObserver 的变化回调内重读重写 AppStorage：用户在系统设置里切换导航方式后
//    免重启即时生效；
//  - 读取 / 解析 / 注册任何一步失败都静默降级到兜底判据，不外抛、不影响启动；
//  - region 高度 px→vp 用 display 屏幕密度换算，不依赖 UIContext；
//  - 悬浮球模式底部没有系统栏，与手势同样按「无避让」处理。

import settings from '@ohos.settings';
import display from '@ohos.display';
import { common } from '@kit.AbilityKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { hilog } from '@kit.PerformanceAnalysisKit';

const TAG: string = 'navMode';
const DOMAIN: number = 0x0000;
const FLOAT_NAVIGATION_INFO_KEY: string = 'float_navigation_info';

// AppStorage 键与模式值（cardTokens.bottomNavInset 消费）
export const NAV_MODE_KEY: string = 'navMode';
export const NAV_MODE_GESTURE: string = 'gesture';
export const NAV_MODE_THREE_BUTTON: string = 'three-button';
export const NAV_MODE_FLOATING_BALL: string = 'floating-ball';
// 三键栏高度（vp）：来自 settings region[3]，bottomNavInset 取它与避让区测量的大者
export const NAV_BUTTON_BAR_HEIGHT_KEY: string = 'navButtonBarHeight';
// 避让参数版本号：每次导航方式/高度刷新都递增（Date.now）。消费方 @StorageLink 它来
// 强制重渲染 —— 实测「在后台切换导航方式 → 回前台」时 avoidAreaChange 不派发、后台期
// 的 AppStorage 写入不足以驱动可见重渲染，必须用前台显式 bump 兜底（2026-09-28 真机日志）。
export const NAV_INSET_VERSION_KEY: string = 'navInsetVersion';

interface NavigationButtonInfo {
  showType: number; // -1 未显示(手势) / 0 三键 / 1 悬浮球
  region: number[]; // [x, y, w, h]，px
}

let watcherStarted: boolean = false;

// 强制刷新避让参数的消费方：版本号恒变（时间戳），@StorageLink 它的组件必然重渲染，
// build 里的 bottomNavInset() 随即读到最新 AppStorage 值。
export function bumpNavInsetVersion(): void {
  AppStorage.setOrCreate<number>(NAV_INSET_VERSION_KEY, Date.now());
}

// 应用启动时调用一次（EntryAbility.onWindowStageCreate）。幂等：重复调用不再注册。
export function initNavModeWatcher(context: common.Context): void {
  if (watcherStarted) {
    return;
  }
  watcherStarted = true;
  refreshNavMode(context);
  try {
    const ok: boolean = settings.registerKeyObserver(context, FLOAT_NAVIGATION_INFO_KEY,
      settings.domainName.USER_PROPERTY, (_err: BusinessError): void => {
        // 导航方式在系统设置里被切换 → 重读重写 + bump；消费方经 @StorageLink 即时响应，免重启
        refreshNavMode(context);
        bumpNavInsetVersion();
      });
    if (!ok) {
      // 注册失败：保留首读结果，消费方继续走高度阈值兜底
      hilog.warn(DOMAIN, TAG, 'registerKeyObserver returned false');
    }
  } catch (e) {
    hilog.warn(DOMAIN, TAG, 'registerKeyObserver threw: %{public}s', (e as Error).message);
  }
}

// 重读系统导航配置并归一化 → AppStorage（不 bump 版本号；需要强制重渲染的调用方自己 bump）。
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
