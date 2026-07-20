// 主题工具：深色/浅色模式切换
// 通过 AppStorage 存储当前模式，组件级通过 @StorageLink 响应变化。
// 默认跟随系统；用户关闭"跟随系统"后可手动选择。
// EntryAbility 启动时读取系统模式 + onConfigurationUpdate 实时跟随。

import { ConfigurationConstant, common } from '@kit.AbilityKit';

// 全局保存 ApplicationContext（由 EntryAbility 注入，仅用于 setColorMode）
let _appContext: common.ApplicationContext | null = null;

export function initThemeContext(ctx: common.ApplicationContext): void {
  _appContext = ctx;
}

// 读取缓存的系统颜色模式（由 EntryAbility 在启动/onConfigurationUpdate 时写入 systemDark）
export function getSystemDark(): boolean {
  return (AppStorage.get<boolean>('systemDark') ?? true) as boolean;
}

export function isDarkMode(): boolean {
  return (AppStorage.get<boolean>('isDarkMode') ?? true) as boolean;
}

export function isFollowSystem(): boolean {
  return (AppStorage.get<boolean>('followSystem') ?? true) as boolean;
}

export function toggleDarkMode(dark: boolean): void {
  if (_appContext === null) {
    return;
  }
  AppStorage.setOrCreate('isDarkMode', dark);
  // 延迟调用 setColorMode，避免在 UI 渲染回调中同步执行导致死锁
  setTimeout(() => {
    try {
      if (dark) {
        _appContext!.setColorMode(ConfigurationConstant.ColorMode.COLOR_MODE_DARK);
      } else {
        _appContext!.setColorMode(ConfigurationConstant.ColorMode.COLOR_MODE_LIGHT);
      }
    } catch (e) {
      // 忽略设置失败（模拟器可能不支持）
    }
  }, 0);
}

// 切换是否跟随系统（true: 跟随系统; false: 手动模式）
export function setFollowSystem(follow: boolean): void {
  AppStorage.setOrCreate('followSystem', follow);
  if (follow) {
    // 开启跟随：立即应用当前缓存的系统模式
    const sysDark: boolean = getSystemDark();
    toggleDarkMode(sysDark);
  }
}
