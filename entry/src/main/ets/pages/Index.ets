// 有据 主框架：悬浮底部导航栏（系统背景模糊 + 半透明分层 + 动态高光透镜）
// Tab：首页 / 圈子 / 发布 / 消息 / 我的；帖子详情经 router 单独跳转（pages/DetailPage）
import { HomeTab } from '../components/HomeTab';
import { CircleTab } from '../components/CircleTab';
import { CircleOnboarding } from '../components/CircleOnboarding';
import { MessagePage } from './MessagePage';
import { ProfilePage } from './ProfilePage';
import { initAuthStorage, getToken, getUserId, loginWithDevStub, setPrivacyAgreed, isPrivacyAgreed, PRIVACY_POLICY_VERSION } from '../utils/auth';
import { BUILD_MODE_NAME } from '../utils/buildMode';
import { getUnreadCount, getDmUnreadCount, getMe, recordPrivacyConsent, followTag, listTags } from '../services/api';
import { Tag } from '../models/types';
import { safeShowToast } from '../utils/toast';
import { BottomTabBar, BottomTabItem } from '../design/components/BottomTabBar';
import { PublishMode, PublishModeSheet } from '../components/PublishModeSheet';
import { LayoutTokens } from '../design/tokens/space';
import { RadiusTokens } from '../design/tokens/radius';
import { common } from '@kit.AbilityKit';
import { window } from '@kit.ArkUI';
import { hilog } from '@kit.PerformanceAnalysisKit';
import font from '@ohos.font';
import { publishFlowStore } from '../utils/publishFlowStore';
import { AppTab, subscribeTabSwitch } from '../utils/nav';
import { setSerifTypeface } from '../utils/textPoster';
import { drawing } from '@kit.ArkGraphics2D';

@CustomDialog
struct PrivacyConsentDialog {
  controller: CustomDialogController;
  getIsUpdate: () => boolean = (): boolean => false;
  onReadPrivacy: () => void = (): void => {};
  onReadAgreement: () => void = (): void => {};
  onAgree: () => void = (): void => {};
  onDecline: () => void = (): void => {};

  build() {
    Column({ space: 16 }) {
      Text(this.getIsUpdate() ? '隐私政策更新' : '隐私政策与用户协议')
        .fontSize(19)
        .fontWeight(600)
        .fontColor($r('app.color.text_primary'))
        .width('100%')
        .textAlign(TextAlign.Center)
      Text(this.getIsUpdate()
        ? '我们的隐私政策已更新，请阅读并重新同意以继续使用。'
        : '欢迎使用有据。我们仅在为你提供内容推荐、账号安全等必要服务时收集相关信息。')
        .fontSize(14)
        .fontColor($r('app.color.text_secondary'))
        .lineHeight(21)
        .width('100%')
      Row({ space: 4 }) {
        Text('点击查看')
          .fontSize(14)
          .fontColor($r('app.color.text_secondary'))
        Text('《隐私政策》')
          .fontSize(14)
          .fontColor($r('app.color.brand_primary'))
          .onClick((): void => { this.onReadPrivacy(); })
        Text('和')
          .fontSize(14)
          .fontColor($r('app.color.text_secondary'))
        Text('《用户协议》')
          .fontSize(14)
          .fontColor($r('app.color.brand_primary'))
          .onClick((): void => { this.onReadAgreement(); })
      }
      .width('100%')
      .justifyContent(FlexAlign.Center)
      Row({ space: 12 }) {
        Button('不同意')
          .layoutWeight(1)
          .fontColor($r('app.color.semantic_red'))
          .backgroundColor($r('app.color.bar_surface'))
          .backdropBlur(LayoutTokens.glassBlur)
          .border({ width: LayoutTokens.glassBorderWidth, color: $r('app.color.bar_border'), style: BorderStyle.Solid })
          .borderRadius(RadiusTokens.md)
          .shadow({ radius: 10, color: $r('app.color.bar_shadow'), offsetY: 3 })
          .clip(true)
          .onClick((): void => {
            this.controller.close();
            this.onDecline();
          })
        Button('同意并继续')
          .layoutWeight(1)
          .fontColor($r('app.color.ds_brand'))
          .backgroundColor($r('app.color.bar_surface'))
          .backdropBlur(LayoutTokens.glassBlur)
          .border({ width: LayoutTokens.glassBorderWidth, color: $r('app.color.bar_border'), style: BorderStyle.Solid })
          .borderRadius(RadiusTokens.md)
          .shadow({ radius: 10, color: $r('app.color.bar_shadow'), offsetY: 3 })
          .clip(true)
          .onClick((): void => {
            this.controller.close();
            this.onAgree();
          })
      }
      .width('100%')
    }
    .width('100%')
    .padding(20)
    .backgroundColor($r('app.color.card_bg'))
    .borderRadius(16)
  }
}

@Entry
@Component
struct Index {
  @State currentIndex: number = 0;
  @State privacyDialogShown: boolean = false; // 防隐私弹窗重复弹出
  @State privacyDialogIsUpdate: boolean = false;
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
  @State launchComplete: boolean = false;
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
  private privacyConsentController: CustomDialogController = new CustomDialogController({
    builder: PrivacyConsentDialog({
      getIsUpdate: (): boolean => this.privacyDialogIsUpdate,
      onReadPrivacy: (): void => {
        this.getUIContext().getRouter().pushUrl({ url: 'pages/PrivacyPage' });
      },
      onReadAgreement: (): void => {
        this.getUIContext().getRouter().pushUrl({ url: 'pages/UserAgreementPage' });
      },
      onAgree: (): void => { this.agreePrivacy(); },
      onDecline: (): void => { this.declinePrivacy(); },
    }),
    alignment: DialogAlignment.Center,
    customStyle: true,
    width: 344,
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

  // 内置开源宋体（Noto Serif SC），保证「全文科感」标题在无系统宋体的设备上也真实呈现。
  private registerSerifFont(): void {
    try {
      font.registerFont({
        familyName: 'Noto Serif SC',
        familySrc: $rawfile('fonts/NotoSerifSC-Bold.otf'),
      });
      // 创建 drawing Typeface 并传递给 textPoster.ets，让 canvas 绘制也使用衬线字体
      const typeface: drawing.Typeface = drawing.Typeface.makeFromRawFile($rawfile('fonts/NotoSerifSC-Bold.otf'));
      setSerifTypeface(typeface);
      hilog.info(0x0000, 'Index', 'serif font registered');
    } catch (err) {
      hilog.error(0x0000, 'Index', 'register serif font failed: %{public}s', JSON.stringify(err));
    }
  }

  aboutToAppear(): void {
    this.registerSerifFont();
    initAuthStorage();
    AppStorage.setOrCreate<number>('circleLogoDismissVersion', AppStorage.get<number>('circleLogoDismissVersion') ?? 0);
    this.unsubscribeTabSwitch();
    this.unsubscribeTabSwitch = subscribeTabSwitch((target: AppTab): void => {
      this.selectTab(target);
    });
    // TabContent 会提前创建隐藏页面；先广播真实激活项，避免隐藏页误触发登录守卫。
    AppStorage.setOrCreate<number>('activeTab', this.currentIndex);
    this.setupFullScreen();
    this.continueLaunchFlow();
  }

  onPageShow(): void {
    if (this.launchComplete && getToken() !== '') {
      this.refreshUnread();
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
    // 访客可浏览首页/圈子等公开内容；登录仅用于发布/私信/个人中心等需鉴权操作。
    // 未登录不再强制弹出登录页，避免“进首页即强制登录”的体验；登录态就绪时再补拉个人数据。
    if (getToken() === '') {
      return;
    }
    this.validateStartupSession();
    this.refreshUnread();
    this.maybeShowCircleOnboarding();
  }

  private onCircleOnboardingPendingChanged(): void {
    if (!this.launchComplete) {
      return;
    }
    this.maybeShowCircleOnboarding();
  }

  private continueLaunchFlow(): void {
    if (this.launchComplete) {
      return;
    }
    this.launchComplete = true;
    // 隐私需「明示同意」：首启未同意时弹出自检同意弹窗（含「不同意」退出，满足审核红线）。
    // 不再叠加 checkPrivacyUpdate 的版本更新二次弹窗，避免多个隐私弹窗。
    if (!isPrivacyAgreed()) {
      this.showPrivacyDialog();
      return;
    }
    this.startInit();
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
    this.privacyDialogIsUpdate = isUpdate;
    this.privacyConsentController.open();
  }

  private agreePrivacy(): void {
    setPrivacyAgreed(); // 本地兜底（离线也能拦截首启）
    // 已登录则落地服务端（PIPL 可追溯）；失败不阻断（离线/后端未起）
    if (getToken() !== '') {
      recordPrivacyConsent(PRIVACY_POLICY_VERSION).catch(() => {});
    }
    this.privacyDialogShown = false;
    this.startInit();
  }

  private declinePrivacy(): void {
    const ctx = this.getUIContext().getHostContext() as common.UIAbilityContext;
    ctx.terminateSelf();
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

  private broadcastCircleLogoDismissal(): void {
    const version: number = AppStorage.get<number>('circleLogoDismissVersion') ?? 0;
    AppStorage.setOrCreate<number>('circleLogoDismissVersion', version + 1);
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
    // 所有页面点击统一通知圈子页；Logo 点击由 CircleTab 的时间戳保护过滤。
    .onClick((): void => { this.broadcastCircleLogoDismissal(); })
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.BOTTOM])
  }
}
