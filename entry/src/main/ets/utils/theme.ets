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
  // 不调 setColorMode — 避免任何副作用
  // 跟随系统时系统自动管颜色（应用未调 setColorMode 即默认跟随）
  // 手动模式时由 toggleDarkMode 调 setColorMode 强制指定
  if (follow) {
    const sysDark: boolean = getSystemDark();
    AppStorage.setOrCreate('isDarkMode', sysDark);
  }
}
