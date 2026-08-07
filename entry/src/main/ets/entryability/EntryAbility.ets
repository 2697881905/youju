import { AbilityConstant, UIAbility, Want, ConfigurationConstant, Configuration } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { window } from '@kit.ArkUI';
import settings from '@ohos.settings';
import { initThemeContext, loadThemeFromPrefs, applyLaunchTheme } from '../utils/theme';

const DOMAIN = 0x0000;

export default class EntryAbility extends UIAbility {
  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    initThemeContext(this.context.getApplicationContext());
    loadThemeFromPrefs();
    const sysDark: boolean = Number(this.context.config.colorMode) === ConfigurationConstant.ColorMode.COLOR_MODE_DARK;
    AppStorage.setOrCreate('systemDark', sysDark);
    // 统一由 applyLaunchTheme 应用主题：跟随系统时显式交还系统接管，
    // 清除历史残留的强制模式，避免与 isDarkMode 标记错位（浅色 app + 深色底栏）。
    applyLaunchTheme();
    this.syncSystemMotionPreference();
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onCreate');
  }

  // 系统动画缩放为 0 时，设计原语统一退化为瞬时/透明度反馈。
  // 读取失败时保持用户在应用内设置的偏好，不阻断启动。
  private syncSystemMotionPreference(): void {
    AppStorage.setOrCreate('systemReduceMotion', false);
    settings.getValue(this.context, settings.display.ANIMATOR_DURATION_SCALE)
      .then((value: string): void => {
        // 空字符串（设置项未配置）不能误判为缩放 0：Number('') === 0 会让全局动画被错误冻结。
        // 仅当明确读到数值且等于 0 时才视为“减动”；其余（含空/NaN/正常缩放）保持默认 false（不冻结）。
        const scale: number = Number(value);
        const reduce: boolean = value !== '' && !isNaN(scale) && scale === 0;
        AppStorage.setOrCreate('systemReduceMotion', reduce);
      })
      .catch((): void => {});
  }

  onConfigurationUpdate(newConfig: Configuration): void {
    const sysDark: boolean = Number(newConfig.colorMode) === ConfigurationConstant.ColorMode.COLOR_MODE_DARK;
    AppStorage.setOrCreate('systemDark', sysDark);
    const follow: boolean = AppStorage.get<boolean>('followSystem') ?? true;
    if (follow) {
      // 跟随系统：同步缓存，不调 setColorMode
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
    this.syncSystemMotionPreference();
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onForeground');
  }

  onBackground(): void {
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onBackground');
  }
}
