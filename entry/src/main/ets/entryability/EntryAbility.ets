import { AbilityConstant, UIAbility, Want, ConfigurationConstant, Configuration } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { window } from '@kit.ArkUI';
import settings from '@ohos.settings';
import { initNavModeWatcher, refreshNavMode, refreshBottomNavInset } from '../utils/navMode';
import { initThemeContext, loadThemeFromPrefs, applyLaunchTheme, applySystemFollowMode, isDarkMode } from '../utils/theme';
import { enqueuePushRoute, readPushRoute } from '../utils/push';

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
    // 冷启动可能来自「点击通知」：把服务端透传的路由意图落盘，等 Index 就绪后消费跳转。
    this.consumePushWant(want);
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onCreate');
  }

  // 应用已在前台/后台存活时点击通知走这里（单实例模式）。不重走 onCreate，
  // 只更新待处理路由信号，由 Index 的监听回调消费。
  onNewWant(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    this.consumePushWant(want);
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onNewWant');
  }

  // 取出的推送意图写入 AppStorage 并递增序号。非推送来源（普通冷启动）时 readPushRoute 返回 null。
  private consumePushWant(want: Want): void {
    const route = readPushRoute(want);
    if (route === null) {
      return;
    }
    enqueuePushRoute(route);
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
    // 导航方式检测（三键/悬浮球/手势）：settings 'float_navigation_info' + 变化监听。
    // 尽早初始化，保证首帧前 AppStorage 已有 navMode；内部全兜底，任何失败不影响启动。
    initNavModeWatcher(this.context);
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

  // 顶部/底部系统栏区域的底色治理（窗口为全屏沉浸式：setWindowLayoutFullScreen(true)）：
  // - 手势导航下 navigationBarColor 不生效（官方论坛确认，仅三键导航可着色），该区域默认
  //   透传「窗口背景色」，而窗口背景默认黑色 → 全屏内容未铺满物理屏底时底部露出黑带，截断卡片。
  // - 正确做法：窗口背景色 = 主题画布色（与 ColorTokens.canvas 浅 #FFFFFF / 深 #121212 一致），
  //   两条系统栏都设透明，让页面背景与内容一路铺到物理屏上下沿，消除上下横带。
  // - 各页负责自己让出状态栏高度（pages/Index 统一写 AppStorage['statusBarHeight']，
  //   路由页在根节点或顶栏加 padding），否则全屏下标题会被状态栏区域盖住。
  private applySystemBarColor(): void {
    if (this.winStage === null) {
      return;
    }
    const dark: boolean = isDarkMode();
    // 与 ColorTokens.canvas（浅 #FFFFFF / 深 #121212）保持一致
    const barColor: string = dark ? '#FF121212' : '#FFFFFFFF';
    // 状态栏/导航条内容色必须显式跟随应用主题（审核问题④：仅设背景色时内容由系统按
    // 「系统深浅」自选，应用内主题与系统深浅不一致时就出现浅底白字/深底黑字（对比度 1.1 < 3）。
    // 纯黑/纯白 vs 画布色对比度均 > 15，稳过 ≥3 要求。
    const barContentColor: string = dark ? '#FFFFFFFF' : '#FF000000';
    try {
      const win = this.winStage.getMainWindowSync();
      win.setWindowBackgroundColor(barColor);
      win.setWindowSystemBarProperties({
        // 上下两条系统栏统一设透明：窗口背景色（= 主题画布色）+ 各页自身背景一路铺到物理屏上下沿，
        // 系统不再额外画一条自己的色带。
        // 顶部此前是 barColor（不透明画布色），在全屏布局下有两个后果：
        //   1) 它会盖住画到状态栏下面的页面内容 —— 例如收藏夹管理页的标题上半截被截断；
        //   2) 下拉通知栏时，这条系统色带不随页面一起变暗/虚化，顶部就出现一条有轻微色差的横带。
        // 透明后该区域显示的就是页面自己的背景，随页面一起响应，两处现象一并消除。
        // 状态栏图标颜色仍由 statusBarContentColor 显式指定，不依赖背景色。
        navigationBarColor: '#00000000',
        navigationBarContentColor: barContentColor,
        statusBarColor: '#00000000',
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
    // 导航方式可能在后台被切换（设置里切三键/手势后返回应用）：avoidAreaChange 在后台
    // 切换时不派发，且后台期的 AppStorage 写入不足以驱动可见重渲染 → 前台恢复时强制
    // 重读配置并重算避让量，挂了 @StorageLink('bottomNavInsetVp') 的贴底栏立即抬高。
    refreshNavMode(this.context);
    refreshBottomNavInset();
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
    // 暖前台回切：触发一次剪贴板分享链接检查（Index @Watch 消费；冷启动由 Index 侧显式触发，
    // 此处首次递增发生在 Index 挂载前后皆可，节流与去重由 utils/clipboardJump.ets 收口）
    const clipSeq: number = (AppStorage.get<number>('clipboardCheckSeq') ?? 0) as number;
    AppStorage.setOrCreate('clipboardCheckSeq', clipSeq + 1);
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onForeground');
  }

  onBackground(): void {
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onBackground');
  }
}
