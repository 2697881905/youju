// 大蓝书 主框架：悬浮底部导航栏（系统背景模糊 + 半透明分层 + 动态高光透镜）
// Tab：首页 / 圈子 / 发布 / 消息 / 我的；帖子详情经 router 单独跳转（pages/DetailPage）
import { HomeTab } from '../components/HomeTab';
import { CircleTab } from '../components/CircleTab';
import { PublishPage } from './PublishPage';
import { MessagePage } from './MessagePage';
import { ProfilePage } from './ProfilePage';
import { initAuthStorage, getToken, setPrivacyAgreed, isPrivacyAgreed, PRIVACY_POLICY_VERSION } from '../utils/auth';
import { getUnreadCount, getDmUnreadCount, getMe, recordPrivacyConsent } from '../services/api';
import { ensurePushRegistration } from '../utils/huaweiPush';
import { BottomTabBar, BottomTabItem } from '../design/components/BottomTabBar';
import { LayoutTokens } from '../design/tokens/space';
import { common } from '@kit.AbilityKit';
import { window } from '@kit.ArkUI';

@Entry
@Component
struct Index {
  @State currentIndex: number = 0;
  @State privacyDialogShown: boolean = false; // 防隐私弹窗重复弹出
  @StorageLink('unreadMessageCount') unreadCount: number = 0;
  @StorageLink('unreadDmCount') dmUnread: number = 0;
  @StorageLink('tabSwitchSignal') @Watch('onTabSwitch') tabSwitchSignal: number = 0;
  @State statusBarHeight: number = 0;
  @State navBarHeight: number = 0;
  // 长按滑动高光状态
  @State scrubbing: boolean = false;        // 是否处于长按滑动高亮模式
  @State glowX: number = 0;                 // 高光中心 x（栏内局部坐标）
  @State hoverIndex: number = -1;           // 滑动时悬停的按钮下标（用于高亮 + 松手触发）
  @State barPressed: boolean = false;        // 按下即显示局部折射高光
  @State barWidth: number = 0;
  private longPressTimer: number = 0;       // 长按计时器句柄
  private suppressClickUntil: number = 0;   // 滑动结束后短暂屏蔽 tab 自身 onClick，避免重复触发
  private pressArmed: boolean = false;      // 长按已触发，但需移动才进入滑动模式
  private pressDownX: number = 0;           // 按下点的栏内 x，用于移动阈值判断

  private bottomTabItems(): BottomTabItem[] {
    return [
      { key: 'home', title: '首页', icon: $r('app.media.nav_home') },
      { key: 'circle', title: '圈子', icon: $r('app.media.nav_circle') },
      { key: 'publish', title: '发布', icon: $r('app.media.nav_publish') },
      { key: 'message', title: '消息', icon: $r('app.media.nav_message') },
      { key: 'profile', title: '我的', icon: $r('app.media.nav_profile') },
    ];
  }

  aboutToAppear(): void {
    initAuthStorage();
    // TabContent 会提前创建隐藏页面；先广播真实激活项，避免隐藏页误触发登录守卫。
    AppStorage.setOrCreate<number>('activeTab', this.currentIndex);
    this.setupFullScreen();
    if (!isPrivacyAgreed()) {
      this.showPrivacyDialog();
      return;
    }
    this.startInit();
  }

  onPageShow(): void {
    if (getToken() !== '') {
      this.refreshUnread();
      ensurePushRegistration();
    }
  }

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
      this.navBarHeight = px2vp(area.bottomRect.height);
      AppStorage.setOrCreate<number>('statusBarHeight', this.statusBarHeight);
      AppStorage.setOrCreate<number>('navBarHeight', this.navBarHeight);
    } catch (e) {
      // 失败不阻断
    }
  }

  private startInit(): void {
    if (getToken() === '') {
      this.getUIContext().getRouter().pushUrl({ url: 'pages/LoginPage' });
    } else {
      this.refreshUnread();
      ensurePushRegistration();
      this.checkPrivacyUpdate(); // 已登录：若隐私政策已更新则重新弹窗
    }
  }

  // 登录态稳定后异步核对服务端隐私同意版本；过期则重新弹窗（版本更新场景）。
  // 网络失败/未配置时不阻断使用，以本地 privacyAgreed 标记为准。
  private checkPrivacyUpdate(): void {
    if (this.privacyDialogShown) {
      return;
    }
    getMe().then((me) => {
      if (me.privacyRequired) {
        this.privacyDialogShown = true;
        this.showPrivacyDialog(true);
      }
    }).catch(() => {});
  }

  private showPrivacyDialog(isUpdate: boolean = false): void {
    this.getUIContext().showAlertDialog({
      title: isUpdate ? '隐私政策更新' : '隐私政策与用户协议',
      message: isUpdate
        ? '我们的隐私政策已更新，请阅读并重新同意以继续使用。'
        : '欢迎使用大蓝书。请你仔细阅读并同意《隐私政策》与《用户协议》后再开始使用。' +
          '我们仅在为你提供内容推荐、账号安全等必要服务时收集相关信息。',
      primaryButton: {
        value: '同意并继续',
        action: (): void => {
          setPrivacyAgreed(); // 本地兜底（离线也能拦截首启）
          // 已登录则落地服务端（PIPL 可追溯）；失败不阻断（离线/后端未起）
          if (getToken() !== '') {
            recordPrivacyConsent(PRIVACY_POLICY_VERSION).catch(() => {});
          }
          this.privacyDialogShown = false;
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

  private refreshUnread(): void {
    getUnreadCount()
      .then((res) => { this.unreadCount = res.count; })
      .catch(() => {});
    getDmUnreadCount()
      .then((res) => { this.dmUnread = res.count; })
      .catch(() => {});
  }

  onTabSwitch(): void {
    const target: number = AppStorage.get<number>('tabSwitchTarget') ?? 0;
    if (target >= 0 && target <= 4) {
      this.currentIndex = target;
      AppStorage.setOrCreate<number>('activeTab', target);
    }
  }

  private selectTab(index: number): void {
    if (this.currentIndex === index) {
      return;
    }
    this.currentIndex = index;
    AppStorage.setOrCreate<number>('activeTab', index);
  }

  build() {
    Stack({ alignContent: Alignment.Bottom }) {
      Stack() {
        HomeTab()
          .visibility(this.currentIndex === 0 ? Visibility.Visible : Visibility.None)
        CircleTab()
          .visibility(this.currentIndex === 1 ? Visibility.Visible : Visibility.None)
        PublishPage()
          .visibility(this.currentIndex === 2 ? Visibility.Visible : Visibility.None)
        MessagePage()
          .visibility(this.currentIndex === 3 ? Visibility.Visible : Visibility.None)
        ProfilePage()
          .visibility(this.currentIndex === 4 ? Visibility.Visible : Visibility.None)
      }
      .width('100%')
      .height('100%')
      .padding({ top: this.statusBarHeight })

      Row() {
        BottomTabBar({
          items: this.bottomTabItems(),
          currentIndex: $currentIndex,
          unreadCount: this.unreadCount + this.dmUnread,
          onSelect: (index: number): void => {
            this.selectTab(index);
          },
        })
      }
      .width('100%')
      .padding({ left: LayoutTokens.tabBarSideMargin, right: LayoutTokens.tabBarSideMargin })
      .margin({ bottom: LayoutTokens.tabBarBottomGap + this.navBarHeight })
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.bg_primary'))
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.BOTTOM])
  }
}
