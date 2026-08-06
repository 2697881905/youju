// 大蓝书 主框架：悬浮底部导航栏（系统背景模糊 + 半透明分层 + 动态高光透镜）
// Tab：首页 / 圈子 / 发布 / 消息 / 我的；帖子详情经 router 单独跳转（pages/DetailPage）
import { HomeTab } from '../components/HomeTab';
import { CircleTab } from '../components/CircleTab';
import { CircleOnboarding } from '../components/CircleOnboarding';
import { MessagePage } from './MessagePage';
import { ProfilePage } from './ProfilePage';
import { initAuthStorage, getToken, getUserId, loginWithDevStub, setPrivacyAgreed, isPrivacyAgreed, PRIVACY_POLICY_VERSION } from '../utils/auth';
import { BUILD_MODE_NAME } from 'BuildProfile';
import { getUnreadCount, getDmUnreadCount, getMe, recordPrivacyConsent, followTag, listTags } from '../services/api';
import { Tag } from '../models/types';
import { safeShowToast } from '../utils/toast';
import { ensurePushRegistration } from '../utils/huaweiPush';
import { BottomTabBar, BottomTabItem } from '../design/components/BottomTabBar';
import { PublishMode, PublishModeSheet } from '../components/PublishModeSheet';
import { LayoutTokens } from '../design/tokens/space';
import { common } from '@kit.AbilityKit';
import { window } from '@kit.ArkUI';
import { publishFlowStore } from '../utils/publishFlowStore';
import { AppTab, subscribeTabSwitch } from '../utils/nav';

@Entry
@Component
struct Index {
  @State currentIndex: number = 0;
  @State privacyDialogShown: boolean = false; // 防隐私弹窗重复弹出
  @StorageLink('unreadMessageCount') unreadCount: number = 0;
  @StorageLink('unreadDmCount') dmUnread: number = 0;
  @StorageLink('circleOnboardingPendingUserId') @Watch('onCircleOnboardingPendingChanged') circleOnboardingPendingUserId: string = '';
  @State showCircleOnboarding: boolean = false;
  @State onboardingTags: Tag[] = [];
  @State onboardingSelectedNames: string[] = [];
  @State onboardingLoading: boolean = false;
  @State onboardingSubmitting: boolean = false;
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
  private sessionRecovering: boolean = false;
  private unsubscribeTabSwitch: () => void = () => {};
  private publishModeController: CustomDialogController = new CustomDialogController({
    builder: PublishModeSheet({
      onSelect: (mode: PublishMode): void => { this.openPublish(mode); },
    }),
    alignment: DialogAlignment.Center,
    customStyle: true,
  });

  private bottomTabItems(): BottomTabItem[] {
    return [
      { key: 'home', title: '首页', icon: $r('app.media.nav_home'), color: '#0A84FF' },
      { key: 'circle', title: '圈子', icon: $r('app.media.nav_circle'), color: '#34C759' },
      { key: 'publish', title: '发布', icon: $r('app.media.nav_publish'), color: '#FF9500' },
      { key: 'message', title: '消息', icon: $r('app.media.nav_message'), color: '#AF52DE' },
      { key: 'profile', title: '我的', icon: $r('app.media.nav_profile'), color: '#FF2D55' },
    ];
  }

  aboutToAppear(): void {
    initAuthStorage();
    this.unsubscribeTabSwitch();
    this.unsubscribeTabSwitch = subscribeTabSwitch((target: AppTab): void => {
      this.selectTab(target);
    });
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
      this.maybeShowCircleOnboarding();
    }
  }

  aboutToDisappear(): void {
    this.unsubscribeTabSwitch();
    this.unsubscribeTabSwitch = () => {};
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
      this.validateStartupSession();
      this.refreshUnread();
      ensurePushRegistration();
      this.checkPrivacyUpdate(); // 已登录：若隐私政策已更新则重新弹窗
      this.maybeShowCircleOnboarding();
    }
  }

  private onCircleOnboardingPendingChanged(): void {
    this.maybeShowCircleOnboarding();
  }

  private maybeShowCircleOnboarding(): void {
    const currentUserId: string = String(getUserId());
    if (!getToken() || currentUserId === '0' || this.circleOnboardingPendingUserId !== currentUserId ||
      this.showCircleOnboarding || this.onboardingLoading) {
      return;
    }
    this.showCircleOnboarding = true;
    this.loadOnboardingTags();
  }

  private async loadOnboardingTags(): Promise<void> {
    this.onboardingLoading = true;
    try {
      this.onboardingTags = await listTags();
    } catch (e) {
      safeShowToast(this.getUIContext(), { message: '圈子加载失败，请稍后重试' });
    } finally {
      this.onboardingLoading = false;
    }
  }

  private toggleOnboardingTag(name: string): void {
    if (name.length === 0 || this.onboardingSubmitting) {
      return;
    }
    if (this.onboardingSelectedNames.indexOf(name) >= 0) {
      this.onboardingSelectedNames = this.onboardingSelectedNames.filter((item: string) => item !== name);
    } else {
      this.onboardingSelectedNames = [...this.onboardingSelectedNames, name];
    }
  }

  private finishCircleOnboarding(): void {
    this.showCircleOnboarding = false;
    this.onboardingSelectedNames = [];
    AppStorage.setOrCreate('circleOnboardingPendingUserId', '');
    const version: number = AppStorage.get<number>('circleMembershipVersion') ?? 0;
    AppStorage.setOrCreate('circleMembershipVersion', version + 1);
  }

  private async confirmCircleOnboarding(): Promise<void> {
    if (this.onboardingSubmitting) {
      return;
    }
    if (this.onboardingSelectedNames.length === 0) {
      this.finishCircleOnboarding();
      return;
    }
    this.onboardingSubmitting = true;
    try {
      await Promise.all(this.onboardingSelectedNames.map((name: string) => followTag(name)));
      this.finishCircleOnboarding();
    } catch (e) {
      safeShowToast(this.getUIContext(), { message: '加入圈子失败，请重试' });
    } finally {
      this.onboardingSubmitting = false;
    }
  }

  // 冷启动时校验持久化 JWT。模拟器 debug 包可能长期复用旧开发 token，
  // 过期后自动重新建立开发账号会话，避免圈子/帖子页被误判为空；生产包不静默登录。
  private async validateStartupSession(): Promise<void> {
    if (this.sessionRecovering || getToken() === '') {
      return;
    }
    try {
      await getMe();
    } catch (e) {
      const msg: string = (e as Error).message ?? '';
      if (String(BUILD_MODE_NAME) === 'debug' && msg.includes('登录已过期')) {
        this.sessionRecovering = true;
        try {
          await loginWithDevStub();
        } catch (_) {
          // 后端未就绪时保留原会话，页面的网络重试机制稍后会再次拉取。
        } finally {
          this.sessionRecovering = false;
        }
      }
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

  private selectTab(index: number): void {
    if (this.currentIndex === index) {
      return;
    }
    this.currentIndex = index;
    AppStorage.setOrCreate<number>('activeTab', index);
  }

  private openPublish(mode: PublishMode): void {
    publishFlowStore.startNew(mode);
    const url: string = mode === 'video' ? 'pages/VideoPublishPage'
      : (mode === 'text' ? 'pages/TextPublishPage' : 'pages/PhotoPublishPage');
    this.getUIContext().getRouter().pushUrl({ url: url });
  }

  private showPublishModeDialog(): void {
    this.publishModeController.open();
  }

  build() {
    Stack({ alignContent: Alignment.Bottom }) {
      Stack() {
        HomeTab()
          .visibility(this.currentIndex === 0 ? Visibility.Visible : Visibility.None)
        CircleTab()
          .visibility(this.currentIndex === 1 ? Visibility.Visible : Visibility.None)
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
            if (index === 2) {
              this.showPublishModeDialog();
            } else {
              this.selectTab(index);
            }
          },
        })
      }
      .width('100%')
      .padding({ left: LayoutTokens.tabBarSideMargin, right: LayoutTokens.tabBarSideMargin })
      .margin({ bottom: LayoutTokens.tabBarBottomGap + this.navBarHeight })

      if (this.showCircleOnboarding) {
        CircleOnboarding({
          tags: this.onboardingTags,
          selectedNames: this.onboardingSelectedNames,
          loading: this.onboardingLoading,
          submitting: this.onboardingSubmitting,
          onToggle: (name: string): void => { this.toggleOnboardingTag(name); },
          onSkip: (): void => { this.finishCircleOnboarding(); },
          onConfirm: (): void => { this.confirmCircleOnboarding(); },
        })
        .zIndex(100)
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.bg_primary'))
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.BOTTOM])
  }
}
