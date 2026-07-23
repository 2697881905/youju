import { AbilityConstant, UIAbility, Want, ConfigurationConstant, Configuration } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { window } from '@kit.ArkUI';
import { initThemeContext, loadThemeFromPrefs, toggleDarkMode } from '../utils/theme';

const DOMAIN = 0x0000;

export default class EntryAbility extends UIAbility {
  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    // 注入 ApplicationContext 到主题工具（含 preferences 同步初始化）
    initThemeContext(this.context.getApplicationContext());
    // 从持久化存储同步恢复用户之前设置的 followSystem / isDarkMode
    loadThemeFromPrefs();
    // 启动时读取系统当前颜色模式
    const sysDark: boolean = Number(this.context.config.colorMode) === ConfigurationConstant.ColorMode.COLOR_MODE_DARK;
    const follow: boolean = AppStorage.get<boolean>('followSystem') ?? true;
    if (follow) {
      toggleDarkMode(sysDark);
    } else {
      const dark: boolean = AppStorage.get<boolean>('isDarkMode') ?? true;
      toggleDarkMode(dark);
    }
    AppStorage.setOrCreate('systemDark', sysDark);
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onCreate');
  }

  // 系统配置变化（含深浅模式切换）：实时跟随
  onConfigurationUpdate(newConfig: Configuration): void {
    const follow: boolean = AppStorage.get<boolean>('followSystem') ?? true;
    if (!follow) {
      return;
    }
    const sysDark: boolean = Number(newConfig.colorMode) === ConfigurationConstant.ColorMode.COLOR_MODE_DARK;
    const prev: boolean | undefined = AppStorage.get<boolean>('systemDark');
    AppStorage.setOrCreate('systemDark', sysDark);
    // 仅在新旧值不同时才调用 toggleDarkMode，避免 self-trigger loop
    if (prev !== sysDark) {
      toggleDarkMode(sysDark);
    }
  }

  onDestroy(): void {
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onDestroy');
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onWindowStageCreate');
    windowStage.loadContent('pages/Index', (err) => {
      if (err.code) {
        hilog.error(DOMAIN, 'testTag', 'Failed to load the content. Cause: %{public}s', JSON.stringify(err));
        return;
      }
      hilog.info(DOMAIN, 'testTag', 'Succeeded in loading the content.');
    });
  }

  onWindowStageDestroy(): void {
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onWindowStageDestroy');
  }

  onForeground(): void {
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onForeground');
  }

  onBackground(): void {
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onBackground');
  }
}
