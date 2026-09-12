import { AbilityConstant, UIAbility, Want, ConfigurationConstant, Configuration } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { window } from '@kit.ArkUI';
import settings from '@ohos.settings';
import { initThemeContext, loadThemeFromPrefs, applyLaunchTheme, applySystemFollowMode, isDarkMode } from '../utils/theme';

const DOMAIN = 0x0000;

export default class EntryAbility extends UIAbility {
  // 主窗口引用：主题切换时重设导航条/状态栏背景
  private winStage: window.WindowStage | null = null;
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
      // 跟随系统：强改窗口颜色模式后再交还系统接管，修复「切回浅色残留深色」（审核反馈问题2）。
      // applySystemFollowMode 内部按系统深浅变化标记去重，setColorMode 回派的重入回调会跳过，不会递归。
      applySystemFollowMode(sysDark);
    }
    // 深浅切换后重设导航条/状态栏背景色
    this.applySystemBarColor();
  }

  onDestroy(): void {
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onDestroy');
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onWindowStageCreate');
    this.winStage = windowStage;
    windowStage.loadContent('pages/Index', (err) => {
      if (err.code) {
        hilog.error(DOMAIN, 'testTag', 'Failed to load the content. Cause: %{public}s', JSON.stringify(err));
        return;
      }
      hilog.info(DOMAIN, 'testTag', 'Succeeded in loading the content.');
      // 窗口创建完成后再切全屏布局：loadContent 前 getMainWindowSync 会抛 1300002（窗口状态异常），
      // 此前在 onWindowStageCreate 直接取主窗口设置的代码实际从未生效——底部因此一直是系统
      // 按深浅模式着色的导航区（浅色白条/深色黑条），内容滚不进最底部 2mm。
      // 先 setWindowLayoutFullScreen(true) 再补系统栏配色（全屏切换可能重置系统栏状态）。
      try {
        const win = windowStage.getMainWindowSync();
        win.setWindowLayoutFullScreen(true)
          .then(() => {
            this.applySystemBarColor();
          })
          .catch(() => {
            // 全屏切换失败不阻断：直接补系统栏配色（部分设备全屏后无需额外设置）
            this.applySystemBarColor();
          });
      } catch (e) {
        this.applySystemBarColor();
      }
    });
  }

  // 底部系统栏区域（手势指示条/三键导航）的底色治理：
  // - 手势导航下 navigationBarColor 不生效（官方论坛确认，仅三键导航可着色），该区域默认
  //   透传「窗口背景色」，而窗口背景默认黑色 → 全屏内容未铺满物理屏底时底部露出黑带，截断卡片。
  // - 正确做法：窗口背景色 = 主题画布色（与 ColorTokens.canvas 浅 #F6F1E3 / 深 #14120C 一致），
  //   导航条设透明，让页面背景与内容一路铺到物理屏底，消除底部横带。
  private applySystemBarColor(): void {
    if (this.winStage === null) {
      return;
    }
    const dark: boolean = isDarkMode();
    // 与 ColorTokens.canvas（浅 #F6F1E3 / 深 #14120C）保持一致
    const barColor: string = dark ? '#FF14120C' : '#FFF6F1E3';
    // 状态栏/导航条内容色必须显式跟随应用主题（审核问题④：仅设背景色时内容由系统按
    // 「系统深浅」自选，应用内主题与系统深浅不一致时就出现浅底白字/深底黑字（对比度 1.1 < 3）。
    // 纯黑/纯白 vs 画布色对比度均 > 15，稳过 ≥3 要求。
    const barContentColor: string = dark ? '#FFFFFFFF' : '#FF000000';
    try {
      const win = this.winStage.getMainWindowSync();
      win.setWindowBackgroundColor(barColor);
      win.setWindowSystemBarProperties({
        navigationBarColor: '#00000000', // 底部透明：内容可延伸到物理底，不被系统色带遮挡
        navigationBarContentColor: barContentColor,
        statusBarColor: barColor,
        statusBarContentColor: barContentColor,
      }).catch((): void => {
        // 系统栏着色失败可忽略：窗口背景色已兜底底部区域配色
      });
    } catch (e) {
      // 窗口不可用时跳过（如页面销毁竞态），下次主题变化/前台恢复会重试
    }
  }

  onWindowStageDestroy(): void {
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onWindowStageDestroy');
  }

  onForeground(): void {
    this.syncSystemMotionPreference();
    // 前台恢复时直读系统当前深浅（后台切换深浅时 onConfigurationUpdate 可能不派发，
    // 缓存的 systemDark 是旧值 → 界面不跟随。用 context.config 保证拿到最新并走完整应用链路）
    const sysDark: boolean = Number(this.context.config.colorMode) === ConfigurationConstant.ColorMode.COLOR_MODE_DARK;
    AppStorage.setOrCreate('systemDark', sysDark);
    const follow: boolean = AppStorage.get<boolean>('followSystem') ?? true;
    if (follow) {
      applySystemFollowMode(sysDark);
    } else {
      applyLaunchTheme();
    }
    // 主题可能已变（后台切换/手动开闭深色），重设导航条/状态栏背景色
    this.applySystemBarColor();
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onForeground');
  }

  onBackground(): void {
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onBackground');
  }
}
