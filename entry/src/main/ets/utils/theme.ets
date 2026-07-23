// 主题工具：深色/浅色模式切换
// 通过 AppStorage 存储当前模式，组件级通过 @StorageLink 响应变化。
// @ohos.data.preferences 作为持久化源（setColorMode 可能触发 Ability 重建致 AppStorage 清空）。
// 默认跟随系统；用户关闭"跟随系统"后可手动选择。
// EntryAbility 启动时读取系统模式 + onConfigurationUpdate 实时跟随。

import { ConfigurationConstant, common } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';

const PREF_NAME = 'bigbluebook_theme';
const KEY_FOLLOW_SYSTEM = 'followSystem';
const KEY_IS_DARK = 'isDarkMode';

// 全局保存 ApplicationContext（仅用于 setColorMode 和 preferences）
let _appContext: common.ApplicationContext | null = null;
// preferences 实例缓存（延迟初始化）
let _prefs: preferences.Preferences | null = null;

export function initThemeContext(ctx: common.ApplicationContext): void {
  _appContext = ctx;
}

async function getPrefs(): Promise<preferences.Preferences> {
  if (_prefs !== null) {
    return _prefs;
  }
  if (_appContext === null) {
    throw new Error('Theme context not initialized');
  }
  _prefs = await preferences.getPreferences(_appContext, PREF_NAME);
  return _prefs;
}

// ------ 持久化读写 ------

export async function loadThemeFromPrefs(): Promise<void> {
  try {
    const p = await getPrefs();
    const follow: boolean = p.getSync(KEY_FOLLOW_SYSTEM, true) as boolean;
    const dark: boolean = p.getSync(KEY_IS_DARK, true) as boolean;
    AppStorage.setOrCreate('followSystem', follow);
    AppStorage.setOrCreate('isDarkMode', dark);
  } catch (e) {
    // 首次使用无缓存，使用默认值已在 AppStorage 中
  }
}

async function saveFollowSystem(follow: boolean): Promise<void> {
  try {
    const p = await getPrefs();
    p.putSync(KEY_FOLLOW_SYSTEM, follow);
    p.flush();
  } catch (e) {
    // 静默忽略
  }
}

async function saveIsDark(dark: boolean): Promise<void> {
  try {
    const p = await getPrefs();
    p.putSync(KEY_IS_DARK, dark);
    p.flush();
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
