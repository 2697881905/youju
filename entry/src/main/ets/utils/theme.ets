// 主题工具：深色/浅色模式切换
// 通过 AppStorage 存储当前模式，组件级通过 @StorageLink 响应变化。
// 默认深色模式，用户切换后仅当前会话生效（重启恢复默认深色）。

import { ConfigurationConstant, common } from '@kit.AbilityKit';

// 全局保存 ApplicationContext（由 EntryAbility 注入）
let _appContext: common.ApplicationContext | null = null;

export function initThemeContext(ctx: common.ApplicationContext): void {
  _appContext = ctx;
}

export function isDarkMode(): boolean {
  return (AppStorage.get<boolean>('isDarkMode') ?? true) as boolean;
}

export function toggleDarkMode(dark: boolean): void {
  if (_appContext === null) {
    return;
  }
  AppStorage.setOrCreate('isDarkMode', dark);
  try {
    if (dark) {
      _appContext.setColorMode(ConfigurationConstant.ColorMode.COLOR_MODE_DARK);
    } else {
      _appContext.setColorMode(ConfigurationConstant.ColorMode.COLOR_MODE_LIGHT);
    }
  } catch (e) {
    // 忽略设置失败（模拟器可能不支持）
  }
}
