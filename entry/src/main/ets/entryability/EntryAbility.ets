import { AbilityConstant, UIAbility, Want, ConfigurationConstant, Configuration } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { window } from '@kit.ArkUI';
import { initThemeContext, loadThemeFromPrefs, toggleDarkMode, setFollowSystem } from '../utils/theme';

const DOMAIN = 0x0000;

export default class EntryAbility extends UIAbility {
  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    initThemeContext(this.context.getApplicationContext());
    loadThemeFromPrefs();
    const sysDark: boolean = Number(this.context.config.colorMode) === ConfigurationConstant.ColorMode.COLOR_MODE_DARK;
    AppStorage.setOrCreate('systemDark', sysDark);
    const follow: boolean = AppStorage.get<boolean>('followSystem') ?? true;
    if (follow) {
      // 跟随系统：交还系统控制，系统自动渲染
      setFollowSystem(true);
    } else {
      // 手动模式：强制用户选择的颜色
      const dark: boolean = AppStorage.get<boolean>('isDarkMode') ?? false;
      toggleDarkMode(dark);
    }
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onCreate');
  }

  // 系统配置变化（含深浅模式切换）
  // 跟随系统时：仅更新缓存，系统自动管颜色，不调 setColorMode
  // 不跟随系统时：完全忽略，用户手动选择优先
  onConfigurationUpdate(newConfig: Configuration): void {
    const sysDark: boolean = Number(newConfig.colorMode) === ConfigurationConstant.ColorMode.COLOR_MODE_DARK;
    const prev: boolean | undefined = AppStorage.get<boolean>('systemDark');
    AppStorage.setOrCreate('systemDark', sysDark);
    const follow: boolean = AppStorage.get<boolean>('followSystem') ?? true;
    if (follow && prev !== sysDark) {
      // 跟随系统模式下系统颜色变了，同步 isDarkMode 缓存供 UI 显示
      // 不调 setColorMode — 系统已自动切换资源
      AppStorage.setOrCreate('isDarkMode', sysDark);
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
