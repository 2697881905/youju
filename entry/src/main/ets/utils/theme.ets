// 主题工具：深色/浅色模式切换
// 策略（最保守版）：
// - setFollowSystem 不调 setColorMode，只更新 AppStorage + preferences
// - toggleDarkMode 调 setColorMode(DARK/LIGHT) 强制指定
// - onConfigurationUpdate 只更新缓存，不调 setColorMode
// - 消除所有 setColorMode 递归/异常路径

import { ConfigurationConstant, common } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';

const PREF_NAME = 'bigbluebook_theme';
const KEY_FOLLOW_SYSTEM = 'followSystem';
const KEY_IS_DARK = 'isDarkMode';

let _appContext: common.ApplicationContext | null = null;
let _prefs: preferences.Preferences | null = null;

export function initThemeContext(ctx: common.ApplicationContext): void {
  _appContext = ctx;
  try {
    _prefs = preferences.getPreferencesSync(ctx, { name: PREF_NAME });
  } catch (e) {
  }
}

export function loadThemeFromPrefs(): void {
  if (_prefs === null) {
    return;
  }
  try {
    const follow: boolean = _prefs.getSync(KEY_FOLLOW_SYSTEM, true) as boolean;
    const dark: boolean = _prefs.getSync(KEY_IS_DARK, false) as boolean;
    AppStorage.setOrCreate('followSystem', follow);
    AppStorage.setOrCreate('isDarkMode', dark);
  } catch (e) {
  }
}

function saveFollowSystem(follow: boolean): void {
  if (_prefs === null) {
    return;
  }
  try {
    _prefs.putSync(KEY_FOLLOW_SYSTEM, follow);
    _prefs.flushSync();
  } catch (e) {
  }
}

function saveIsDark(dark: boolean): void {
  if (_prefs === null) {
    return;
  }
  try {
    _prefs.putSync(KEY_IS_DARK, dark);
    _prefs.flushSync();
  } catch (e) {
  }
}

export function getSystemDark(): boolean {
  return (AppStorage.get<boolean>('systemDark') ?? false) as boolean;
}

// 启动/前后台重建时统一应用主题：
// - 跟随系统：显式交还系统接管（COLOR_MODE_NOT_SET），并清除历史上被手动强制残留的
//   setColorMode——否则会卡在旧模式、与同步后的 isDarkMode 标记错位（浅色 app + 深色底栏）。
// - 手动模式：强制应用用户选择。
// 全 app 的视觉（含底栏，底栏已改为读取 app.color.* 资源）都由 setColorMode 这一唯一真相源驱动。
export function applyLaunchTheme(): void {
  if (_appContext === null) {
    return;
  }
  try {
    const follow: boolean = isFollowSystem();
    if (follow) {
      _appContext.setColorMode(ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET);
      AppStorage.setOrCreate('isDarkMode', getSystemDark());
    } else {
      const dark: boolean = isDarkMode();
      _appContext.setColorMode(dark
        ? ConfigurationConstant.ColorMode.COLOR_MODE_DARK
        : ConfigurationConstant.ColorMode.COLOR_MODE_LIGHT);
    }
  } catch (e) {
  }
}

export function isDarkMode(): boolean {
  return (AppStorage.get<boolean>('isDarkMode') ?? false) as boolean;
}

export function isFollowSystem(): boolean {
  return (AppStorage.get<boolean>('followSystem') ?? true) as boolean;
}

export function toggleDarkMode(dark: boolean): void {
  AppStorage.setOrCreate('isDarkMode', dark);
  saveIsDark(dark);
  if (_appContext === null) {
    return;
  }
  try {
    _appContext.setColorMode(dark
      ? ConfigurationConstant.ColorMode.COLOR_MODE_DARK
      : ConfigurationConstant.ColorMode.COLOR_MODE_LIGHT);
  } catch (e) {
  }
}

export function setFollowSystem(follow: boolean): void {
  AppStorage.setOrCreate('followSystem', follow);
  saveFollowSystem(follow);
  if (_appContext === null) {
    return;
  }
  try {
    if (follow) {
      // 跟随系统：把 isDarkMode 标记同步成系统当前深浅，并交还系统接管颜色模式
      // （COLOR_MODE_NOT_SET）。必须显式复位——否则会沿用历史上被 toggleDarkMode
      // 强制过的模式，导致「app 浅色但底栏深色 / 反之」的错位。
      const sysDark: boolean = getSystemDark();
      AppStorage.setOrCreate('isDarkMode', sysDark);
      _appContext.setColorMode(ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET);
    } else {
      // 退出跟随：锁定当前手动选择并强制应用到颜色模式，确保与 isDarkMode 一致。
      const dark: boolean = isDarkMode();
      _appContext.setColorMode(dark
        ? ConfigurationConstant.ColorMode.COLOR_MODE_DARK
        : ConfigurationConstant.ColorMode.COLOR_MODE_LIGHT);
    }
  } catch (e) {
  }
}
