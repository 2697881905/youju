// 主题工具：深色/浅色模式切换
// 通过 AppStorage 存储当前模式，组件级通过 @StorageLink 响应变化。
// @ohos.data.preferences 作为持久化源（setColorMode 可能触发 Ability 重建致 AppStorage 清空）。
// 全线使用 getPreferencesSync 同步读写，避免 async 写入未完成时 setColorMode 已触发重建。
// 默认跟随系统；用户关闭"跟随系统"后可手动选择。

import { ConfigurationConstant, common } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';

const PREF_NAME = 'bigbluebook_theme';
const KEY_FOLLOW_SYSTEM = 'followSystem';
const KEY_IS_DARK = 'isDarkMode';

// 全局保存 ApplicationContext（仅用于 setColorMode 和 preferences）
let _appContext: common.ApplicationContext | null = null;
// preferences 实例（同步初始化）
let _prefs: preferences.Preferences | null = null;

export function initThemeContext(ctx: common.ApplicationContext): void {
  _appContext = ctx;
  try {
    _prefs = preferences.getPreferencesSync(ctx, { name: PREF_NAME });
  } catch (e) {
    // 初始化失败，后续写入/读取静默跳过
  }
}

// ------ 持久化读写（全同步）------

export function loadThemeFromPrefs(): void {
  if (_prefs === null) {
    return;
  }
  try {
    const follow: boolean = _prefs.getSync(KEY_FOLLOW_SYSTEM, true) as boolean;
    const dark: boolean = _prefs.getSync(KEY_IS_DARK, true) as boolean;
    AppStorage.setOrCreate('followSystem', follow);
    AppStorage.setOrCreate('isDarkMode', dark);
  } catch (e) {
    // 首次使用无缓存
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
    // 静默忽略
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
    // 静默忽略
  }
}

// ------ 读取 ------

export function getSystemDark(): boolean {
  return (AppStorage.get<boolean>('systemDark') ?? true) as boolean;
}

export function isDarkMode(): boolean {
  return (AppStorage.get<boolean>('isDarkMode') ?? true) as boolean;
}

export function isFollowSystem(): boolean {
  return (AppStorage.get<boolean>('followSystem') ?? true) as boolean;
}

// ------ 操作 ------

export function toggleDarkMode(dark: boolean): void {
  const prev: boolean | undefined = AppStorage.get<boolean>('isDarkMode');
  AppStorage.setOrCreate('isDarkMode', dark);
  saveIsDark(dark);
  if (prev === dark) {
    return;
  }
  if (_appContext === null) {
    return;
  }
  try {
    if (dark) {
      _appContext.setColorMode(ConfigurationConstant.ColorMode.COLOR_MODE_DARK);
    } else {
      _appContext.setColorMode(ConfigurationConstant.ColorMode.COLOR_MODE_LIGHT);
    }
  } catch (e) {
    // 忽略设置失败
  }
}

export function setFollowSystem(follow: boolean): void {
  AppStorage.setOrCreate('followSystem', follow);
  saveFollowSystem(follow);
  if (follow) {
    const sysDark: boolean = getSystemDark();
    toggleDarkMode(sysDark);
  }
}
