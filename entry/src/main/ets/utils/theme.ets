// 主题工具：深色/浅色模式切换
// 策略（最保守版）：
// - setFollowSystem 不调 setColorMode，只更新 AppStorage + preferences
// - toggleDarkMode 调 setColorMode(DARK/LIGHT) 强制指定
// - onConfigurationUpdate 只更新缓存，不调 setColorMode
// - 消除所有 setColorMode 递归/异常路径

import { ConfigurationConstant, common } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';

const PREF_NAME = 'youju_theme';
const KEY_FOLLOW_SYSTEM = 'followSystem';
const KEY_IS_DARK = 'isDarkMode';
const KEY_REDUCE_MOTION = 'reduceMotion';

let _appContext: common.ApplicationContext | null = null;
let _prefs: preferences.Preferences | null = null;

// 最近一次显式应用的颜色模式（防 setColorMode → onConfigurationUpdate 回派 → setColorMode 死循环。
// API24 上 setColorMode 每次调用都会回派一次配置回调，须按值去重才可终止递归）。
const COLOR_MODE_NONE: number = -1;
let _lastAppliedMode: number = COLOR_MODE_NONE;

// 上次看到的系统深浅（用于识别「系统真正切换」而非 setColorMode 回派的同值回调）
let _lastSysDark: boolean | null = null;

// 显式应用颜色模式。先记账再调用：setColorMode 会回派一次配置变更回调（可能同步），
// 若在调用后才记录，重入的回调会再一次通过守卫 → 无限递归栈溢出；先记录后重入直接跳过，递归终止。
function applyMode(colorMode: number): void {
  if (_appContext === null || colorMode === _lastAppliedMode) {
    return;
  }
  _lastAppliedMode = colorMode;
  try {
    _appContext.setColorMode(colorMode);
  } catch (e) {
    // setColorMode 失败：回退记账，允许下次相同目标重试
    _lastAppliedMode = COLOR_MODE_NONE;
  }
}

// 跟随系统时的「系统深浅切换回调」处理。
// 现象：仅用 COLOR_MODE_NOT_SET 交还时，系统深→浅窗口资源不重新解算（「跟深不跟浅」残留，
// 审核反馈问题2）；仅用显式 DARK/LIGHT 时，系统切换完全不派发回调（模式被冻结）。
// 方案：进入交还态保持回调链路；检测到系统深浅真正变化时，先显式应用目标模式强制重解算，
// 再立即交还系统（保持链路），并用 _lastSysDark 判重防止 setColorMode 回派的同值回调重放/递归。
export function applySystemFollowMode(sysDark: boolean): void {
  if (sysDark === _lastSysDark) {
    return;
  }
  _lastSysDark = sysDark;
  AppStorage.setOrCreate('isDarkMode', sysDark);
  applyMode(sysDark
    ? ConfigurationConstant.ColorMode.COLOR_MODE_DARK
    : ConfigurationConstant.ColorMode.COLOR_MODE_LIGHT);
  // 交还系统接管：让后续系统深浅变更继续派发配置回调
  applyMode(ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET);
}

export function resetSysDarkMarker(): void {
  _lastSysDark = null;
}

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
    const reduceMotion: boolean = _prefs.getSync(KEY_REDUCE_MOTION, false) as boolean;
    AppStorage.setOrCreate('followSystem', follow);
    AppStorage.setOrCreate('isDarkMode', dark);
    AppStorage.setOrCreate('reduceMotion', reduceMotion);
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

function saveReduceMotion(reduceMotion: boolean): void {
  if (_prefs === null) {
    return;
  }
  try {
    _prefs.putSync(KEY_REDUCE_MOTION, reduceMotion);
    _prefs.flushSync();
  } catch (e) {
  }
}

export function getSystemDark(): boolean {
  return (AppStorage.get<boolean>('systemDark') ?? false) as boolean;
}

// 启动 / 前后台重建时统一应用主题：
// - 跟随系统：进入 COLOR_MODE_NOT_SET 交还态。交还后系统深浅变更会派发配置回调，
//   由 applySystemFollowMode 在回调里强制重解算窗口资源（根治「跟深不跟浅」残留）。
// - 手动模式：显式强制应用用户选择。
export function applyLaunchTheme(): void {
  if (_appContext === null) {
    return;
  }
  const follow: boolean = isFollowSystem();
  const dark: boolean = follow ? getSystemDark() : isDarkMode();
  AppStorage.setOrCreate('isDarkMode', dark);
  if (follow) {
    applyMode(ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET);
  } else {
    applyMode(dark
      ? ConfigurationConstant.ColorMode.COLOR_MODE_DARK
      : ConfigurationConstant.ColorMode.COLOR_MODE_LIGHT);
  }
}

export function isDarkMode(): boolean {
  return (AppStorage.get<boolean>('isDarkMode') ?? false) as boolean;
}

export function isFollowSystem(): boolean {
  return (AppStorage.get<boolean>('followSystem') ?? true) as boolean;
}

export function isReduceMotion(): boolean {
  return (AppStorage.get<boolean>('reduceMotion') ?? false) as boolean;
}

export function setReduceMotion(reduceMotion: boolean): void {
  AppStorage.setOrCreate('reduceMotion', reduceMotion);
  saveReduceMotion(reduceMotion);
}

export function toggleDarkMode(dark: boolean): void {
  AppStorage.setOrCreate('isDarkMode', dark);
  saveIsDark(dark);
  applyMode(dark
    ? ConfigurationConstant.ColorMode.COLOR_MODE_DARK
    : ConfigurationConstant.ColorMode.COLOR_MODE_LIGHT);
}

export function setFollowSystem(follow: boolean): void {
  AppStorage.setOrCreate('followSystem', follow);
  saveFollowSystem(follow);
  if (follow) {
    // 跟随系统：把 isDarkMode 标记同步成系统当前深浅，并进入交还态；
    // 系统后续切换深浅时由 applySystemFollowMode 在回调里强制重解算（修复「跟深不跟浅」）。
    const sysDark: boolean = getSystemDark();
    AppStorage.setOrCreate('isDarkMode', sysDark);
    resetSysDarkMarker();
    applyMode(ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET);
  } else {
    // 退出跟随：锁定当前手动选择并强制应用到颜色模式，确保与 isDarkMode 一致。
    const dark: boolean = isDarkMode();
    applyMode(dark
      ? ConfigurationConstant.ColorMode.COLOR_MODE_DARK
      : ConfigurationConstant.ColorMode.COLOR_MODE_LIGHT);
  }
}
