// 主题工具：深色/浅色模式切换
// 策略：
// - 跟随系统时调 setColorMode(COLOR_MODE_NOT_SET)，系统自动管颜色，onConfigurationUpdate 只更新缓存不调 setColorMode
// - 手动模式调 setColorMode(DARK/LIGHT) 强制指定
// - preferences 持久化 followSystem/isDarkMode，AppStorage 供 @StorageLink 双向绑定

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
    // 初始化失败静默
  }
}

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
    // 首次无缓存
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

// 手动切换深/浅色（仅在 !followSystem 时由用户操作触发）
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

// 切换是否跟随系统
// 开启跟随 → setColorMode(COLOR_MODE_NOT_SET) 交还系统控制，系统自动管颜色
// 关闭跟随 → 不调 setColorMode，保持当前颜色，等用户手动选深色/浅色
export function setFollowSystem(follow: boolean): void {
  AppStorage.setOrCreate('followSystem', follow);
  saveFollowSystem(follow);
  if (follow) {
    // 交还系统控制：系统自动按当前系统模式渲染资源
    if (_appContext !== null) {
      try {
        _appContext.setColorMode(ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET);
      } catch (e) {
      }
    }
    // 同步 isDarkMode 缓存为系统当前值
    const sysDark: boolean = getSystemDark();
    AppStorage.setOrCreate('isDarkMode', sysDark);
  }
  // follow=false 时不调 setColorMode，当前颜色保持不变
}
