// 大蓝书 主框架：底部 TabBar 壳
// Tab：首页 / 发布 / 消息 / 我的；帖子详情经 router 单独跳转（pages/DetailPage）
import { HomeTab } from '../components/HomeTab';
import { CircleTab } from '../components/CircleTab';
import { PublishPage } from './PublishPage';
import { MessagePage } from './MessagePage';
import { ProfilePage } from './ProfilePage';
import { initAuthStorage, getToken, setPrivacyAgreed, isPrivacyAgreed } from '../utils/auth';
import { getUnreadCount } from '../services/api';
import { common } from '@kit.AbilityKit';
import { window } from '@kit.ArkUI';

@Entry
@Component
struct Index {
  @State currentIndex: number = 0;
  @StorageLink('unreadMessageCount') unreadCount: number = 0;
  @StorageLink('tabSwitchSignal') @Watch('onTabSwitch') tabSwitchSignal: number = 0;
  // 状态栏高度（全屏布局后顶部内容需下移避让）
  @State statusBarHeight: number = 0;

  aboutToAppear(): void {
    initAuthStorage();
    this.setupFullScreen();
    // 首启隐私协议弹窗：未同意则拦截初始化（同意后才继续登录态判断）
    if (!isPrivacyAgreed()) {
      this.showPrivacyDialog();
      return;
    }
    this.startInit();
  }

  // 从 LoginPage 返回后（aboutToAppear 不再重跑）刷新未读红点
  onPageShow(): void {
    if (getToken() !== '') {
      this.refreshUnread();
    }
  }

  // 窗口全屏布局：内容延伸到系统导航条之下让底部栏贴底，同时读取状态栏高度用于顶部避让
  private async setupFullScreen(): Promise<void> {
    try {
      const ctx = this.getUIContext().getHostContext();
      if (!ctx) {
        return;
      }
      const win = await window.getLastWindow(ctx);
      await win.setWindowLayoutFullScreen(true);
      const area = win.getWindowAvoidArea(window.AvoidAreaType.TYPE_SYSTEM);
      this.statusBarHeight = px2vp(area.topRect.height);
      AppStorage.setOrCreate<number>('statusBarHeight', this.statusBarHeight);
    } catch (e) {
      // 失败不阻断
    }
  }

  // 登录态判断 + 未读拉取（隐私同意后或已同意时执行）
  private startInit(): void {
    // 无登录态时跳到登录页；登录成功后 router.back() 回此页
    if (getToken() === '') {
      this.getUIContext().getRouter().pushUrl({ url: 'pages/LoginPage' });
    } else {
      // 已登录则拉一次未读总数，驱动消息 Tab 红点
      this.refreshUnread();
    }
  }

  // 首启隐私协议弹窗（仅未同意时出现；不同意则退出应用）
  private showPrivacyDialog(): void {
    this.getUIContext().showAlertDialog({
      title: '隐私政策与用户协议',
      message: '欢迎使用大蓝书。请你仔细阅读并同意《隐私政策》与《用户协议》后再开始使用。' +
        '我们仅在为你提供内容推荐、账号安全等必要服务时收集相关信息。',
      primaryButton: {
        value: '同意并继续',
        action: (): void => {
          setPrivacyAgreed();
          this.startInit();
        },
      },
      secondaryButton: {
        value: '不同意',
        fontColor: $r('app.color.semantic_red'),
        action: (): void => {
          const ctx = this.getUIContext().getHostContext() as common.UIAbilityContext;
          ctx.terminateSelf();
        },
      },
    });
  }

  // 拉取未读消息总数（写入 AppStorage，红点随之刷新）
  private refreshUnread(): void {
    getUnreadCount()
      .then((res) => {
        this.unreadCount = res.count;
      })
      .catch(() => {
        // 失败不阻断
      });
  }

  // 跨 Tab 跳转监听：子组件 emitTabSwitch() 写入 tabSwitchSignal 后触发
  onTabSwitch(): void {
    const target: number = AppStorage.get<number>('tabSwitchTarget') ?? 0;
    if (target >= 0 && target <= 4) {
      this.currentIndex = target;
      // 广播当前激活 Tab，供各 Tab 页感知自己是否可见（如个人主页据此刷新列表）
      AppStorage.setOrCreate<number>('activeTab', target);
    }
  }

  // 底部导航线条图标资源（Apple 风格）
  private navIconRes(index: number): Resource {
    switch (index) {
      case 0: return $r('app.media.nav_home');
      case 1: return $r('app.media.nav_circle');
      case 2: return $r('app.media.nav_publish');
      case 3: return $r('app.media.nav_message');
      default: return $r('app.media.nav_profile');
    }
  }

  // 单个 Tab 内容：图标在上 + 文字在下（iOS 风格）
  @Builder
  tabContent(title: string, index: number) {
    Column({ space: 3 }) {
      Image(this.navIconRes(index))
        .width(24)
        .height(24)
        .fillColor(this.currentIndex === index ? $r('app.color.brand_primary') : $r('app.color.text_secondary'))
      Text(title)
        .fontSize(10)
        .fontColor(this.currentIndex === index ? $r('app.color.brand_primary') : $r('app.color.text_secondary'))
    }
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
    .height('100%')
    .width('100%')
  }

  // 底部 Tab：图标 + 文字；消息 Tab 带未读红点
  @Builder
  tabItem(title: string, index: number) {
    if (index === 3) {
      Badge({
        count: this.unreadCount,
        style: { badgeColor: $r('app.color.semantic_red') },
        position: BadgePosition.RightTop,
      }) {
        this.tabContent(title, index)
      }
    } else {
      this.tabContent(title, index)
    }
  }

  build() {
    Tabs({ barPosition: BarPosition.End, index: this.currentIndex }) {
      TabContent() {
        HomeTab()
      }
      .tabBar(this.tabItem('首页', 0))

      TabContent() {
        CircleTab()
      }
      .tabBar(this.tabItem('圈子', 1))

      TabContent() {
        PublishPage()
      }
      .tabBar(this.tabItem('发布', 2))

      TabContent() {
        MessagePage()
      }
      .tabBar(this.tabItem('消息', 3))

      TabContent() {
        ProfilePage()
      }
      .tabBar(this.tabItem('我的', 4))
    }
    .scrollable(false)
    .barHeight(56)
    .barMode(BarMode.Fixed)
      .onChange((index: number) => {
        this.currentIndex = index;
        // 广播当前激活 Tab，供各 Tab 页感知自己是否可见
        AppStorage.setOrCreate<number>('activeTab', index);
      })
    .animationDuration(250)
    .width('100%')
    .height('100%')
    .padding({ top: this.statusBarHeight })  // 全屏布局下顶部避让状态栏
    .barBackgroundBlurStyle(BlurStyle.COMPONENT_ULTRA_THICK)
    .barBackgroundColor($r('app.color.glass_bar_bg'))
    .backgroundColor($r('app.color.bg_primary'))
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.BOTTOM])
  }
}
