// 有据 主框架：悬浮底部导航栏（系统背景模糊 + 半透明分层 + 动态高光透镜）
// Tab：首页 / 圈子 / 发布 / 消息 / 我的；帖子详情经 router 单独跳转（pages/DetailPage）
import { HomeTab } from '../components/HomeTab';
import { CircleTab } from '../components/CircleTab';
import { CircleOnboarding } from '../components/CircleOnboarding';
import { MessagePage } from './MessagePage';
import { ProfilePage } from './ProfilePage';
import { initAuthStorage, getToken, getUserId, setPrivacyAgreed, isPrivacyAgreed, clearSession, PRIVACY_POLICY_VERSION } from '../utils/auth';
import { getUnreadCount, getDmUnreadCount, getMe, recordPrivacyConsent, followTag, listTags } from '../services/api';
import { Tag } from '../models/types';
import { safeShowToast } from '../utils/toast';
import { PublishMode, PublishModeSheet } from '../components/PublishModeSheet';
import { LayoutTokens } from '../design/tokens/space';
import { bottomNavInset, DOCK_WIDTH_SMALL, DOCK_BOTTOM_MARGIN_BASE, DOCK_SIDE_MARGIN_MIN, DOCK_GRADIENT_MASK_HEIGHT, DOCK_MATERIAL_TYPE, DOCK_MATERIAL_LEVEL } from '../utils/cardTokens';
import { RadiusTokens } from '../design/tokens/radius';
import { ColorTokens } from '../design/tokens/color';
import { ShadowTokens } from '../design/tokens/shadow';
import { common } from '@kit.AbilityKit';
import { window } from '@kit.ArkUI';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { publishFlowStore } from '../utils/publishFlowStore';
import { AppTab, subscribeTabSwitch } from '../utils/nav';
import { setMainNavStack, setSharedUiContext } from '../utils/navigationTransition';
import { LongTakeCallback, LongTakeTransition } from '../utils/longTakeTransition';
import { setSerifTypeface, setSerifBodyTypeface } from '../utils/textPoster';
import { drawing } from '@kit.ArkGraphics2D';
import { HdsTabs, HdsTabsController } from '@kit.UIDesignKit';
import { isImmersiveLightSenseSupported, GlassBlurStyle } from '../utils/immersiveMaterial';
import { BottomTabBar } from '../design/components/BottomTabBar';
import { PostDetailDestination } from './PostDetailDestination';
import { UserProfileDestination } from './UserProfileDestination';
import { CircleDetailDestination } from './CircleDetailDestination';
import { ChatDestination } from './ChatDestination';
import { MyFollowDestination } from './MyFollowDestination';
import { LoginDestination } from './LoginDestination';

// 底部页签数据项（含发布占位 tab）。发布 tab 也走同一 builder，展示 + 图标。
interface IndexTabItem {
  key: string;
  title: string;
  icon: Resource;
  color?: ResourceColor;
}

@CustomDialog
struct PrivacyConsentDialog {
  controller: CustomDialogController;
  getIsUpdate: () => boolean = (): boolean => false;
  onReadPrivacy: () => void = (): void => {};
  onReadAgreement: () => void = (): void => {};
  onAgree: () => void = (): void => {};
  onDecline: () => void = (): void => {};

  build() {
    // 已去掉 ImmersiveSurface 流光层，仅保留系统玻璃拟态面板。
    // 注意：customStyle 弹窗的最终尺寸由 builder 内容决定，controller.width 不约束内容层，
    // 因此必须在顶层 Column 上显式给定宽度（320vp），否则子元素（长文本）会撑满全屏宽、两侧贴边。
    Column({ space: 12 }) {
      Text(this.getIsUpdate() ? '隐私政策更新' : '隐私政策与用户协议')
        .fontSize(17)
        .fontWeight(600)
        .fontFamily('Noto Serif SC')
        .fontColor($r('app.color.text_primary'))
        .textAlign(TextAlign.Center)
      Text(this.getIsUpdate()
        ? '我们的隐私政策已更新，请阅读并重新同意以继续使用。'
        : '欢迎使用有据。我们仅在为你提供内容推荐、账号安全等必要服务时收集相关信息。')
        .fontSize(13)
        .fontFamily('Noto Serif SC')
        .fontColor($r('app.color.text_secondary'))
        .lineHeight(19)
      Row({ space: 4 }) {
        Text('点击查看')
          .fontSize(13)
          .fontFamily('Noto Serif SC')
          .fontColor($r('app.color.text_secondary'))
        Text('《隐私政策》')
          .fontSize(13)
          .fontFamily('Noto Serif SC')
          .fontColor($r('app.color.brand_primary'))
          .onClick((): void => { this.onReadPrivacy(); })
        Text('和')
          .fontSize(13)
          .fontFamily('Noto Serif SC')
          .fontColor($r('app.color.text_secondary'))
        Text('《用户协议》')
          .fontSize(13)
          .fontFamily('Noto Serif SC')
          .fontColor($r('app.color.brand_primary'))
          .onClick((): void => { this.onReadAgreement(); })
      }
      .justifyContent(FlexAlign.Center)
      Row({ space: 12 }) {
        Button('不同意')
          .layoutWeight(1)
          .fontSize(14)
          .height(40)
          .fontFamily('Noto Serif SC')
          .fontColor($r('app.color.semantic_red'))
          // 与首页分段栏「容器」完全一致：恒透明底 + 细描边 + 大圆角 + 无阴影
          .backgroundColor(Color.Transparent)
          .border({ width: LayoutTokens.glassBorderWidth, color: $r('app.color.bar_border'), style: BorderStyle.Solid })
          .borderRadius(RadiusTokens.lg)
          .clip(true)
          .onClick((): void => {
            this.controller.close();
            this.onDecline();
          })
        Button('同意并继续')
          .layoutWeight(1)
          .fontSize(14)
          .height(40)
          .fontFamily('Noto Serif SC')
          .fontColor($r('app.color.ds_brand'))
          // 与首页分段栏「选中滑块」完全一致：纸面高亮 + 大圆角 + 无边框 + 细接触阴影
          .backgroundColor(ColorTokens.barSelectionSurface)
          .borderRadius(RadiusTokens.lg)
          .shadow(ShadowTokens.cardContact)
          .clip(true)
          .onClick((): void => {
            this.controller.close();
            this.onAgree();
          })
      }
      .width('100%')
      }
      .width(320)
      .padding(16)
      // 玻璃拟态：半透明暖白 + 背景模糊，透出底下内容形成毛玻璃质感
      .backgroundBlurStyle(GlassBlurStyle.Dialog)
      .backgroundColor(isImmersiveLightSenseSupported() ? Color.Transparent : $r('app.color.glass_overlay_heavy'))
      .border({ width: LayoutTokens.glassBorderWidth, color: $r('app.color.glass_border'), style: BorderStyle.Solid })
      .borderRadius(16)
      .shadow({ radius: 16, color: $r('app.color.bar_shadow'), offsetY: 4 })
  }
}

@Entry
@Component
struct Index {
  @State currentIndex: number = 0;
  @State privacyDialogShown: boolean = false; // 防隐私弹窗重复弹出
  @State privacyDialogIsUpdate: boolean = false;
  // 隐私同意标记（PersistentStorage 字符串 '0'/'1'，见 utils/auth.ets）。
  // 未同意前不构建主 Tab 内容——TabContent 的子组件会立即挂载，而 HomeTab/CircleTab/
  // MessagePage/ProfilePage 的 aboutToAppear 里就会发网络请求（continueLaunchFlow 的
  // 同意闸门只挡住 startInit()，挡不住这条路径，属「告知—同意前处理」红线）。
  @StorageLink('privacyAgreed') privacyAgreed: string = '0';
  @StorageLink('unreadMessageCount') unreadCount: number = 0;
  @StorageLink('unreadDmCount') dmUnread: number = 0;
  @StorageLink('circleOnboardingPendingUserId') @Watch('onCircleOnboardingPendingChanged') circleOnboardingPendingUserId: string = '';
  // 登录态过期标记：api.ets 在服务端 401（非登录接口）时写入，本页统一清态 + 提示 + 引导重登
  @StorageLink('authExpiredAt') @Watch('onAuthExpired') authExpiredAt: number = 0;
  @State showCircleOnboarding: boolean = false;
  @State onboardingTags: Tag[] = [];
  @State onboardingSelectedNames: string[] = [];
  @State onboardingLoading: boolean = false;
  @State onboardingSubmitting: boolean = false;
  @State statusBarHeight: number = 0;
  @State navBarHeight: number = 0;
  @State launchComplete: boolean = false;
  private hdsController: HdsTabsController = new HdsTabsController();
  // API 20-22 分支用内置 Tabs（API 7）承载内容，底栏由自绘玻璃药丸（BottomTabBar）负责。
  private tabsController: TabsController = new TabsController();
  // 悬浮玻璃底栏（barFloatingStyle 及其全部字段）@since 6.1.0(23)：API 6.0.2(22) 上调用会抛
  // TypeError（方法不存在）导致首页无法渲染。isImmersiveLightSenseSupported() 现为同步确定值
  // （deviceInfo.sdkApiVersion + canIUse，进程级缓存），不会运行期翻转 → 组件不会重建。
  private hdsFloatingBar: boolean = isImmersiveLightSenseSupported();
  @State lastPageIndex: number = 0;   // 发布前的实际页面 tab，用于发布后回跳
  // 导航栈：主框架为 Navigation 首页，帖子详情等走 navDestination（首页卡片一镜到底）
  private pageStack: NavPathStack = new NavPathStack();
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
        // 审核修复：先关闭弹窗再打开政策页，避免内容被 Modal 遮挡无法阅读；返回后未同意则重弹
        this.privacyDialogShown = true;
        this.privacyConsentController.close();
        this.getUIContext().getRouter().pushUrl({ url: 'pages/PrivacyPage' });
      },
      onReadAgreement: (): void => {
        this.privacyDialogShown = true;
        this.privacyConsentController.close();
        this.getUIContext().getRouter().pushUrl({ url: 'pages/UserAgreementPage' });
      },
      onAgree: (): void => { this.agreePrivacy(); },
      onDecline: (): void => { this.declinePrivacy(); },
    }),
    alignment: DialogAlignment.Center,
    customStyle: true,
    width: 320,
  });

  private bottomTabItems(): IndexTabItem[] {
    return [
      { key: 'home', title: '首页', icon: $r('app.media.nav_home'), color: '#8A6548' },
      { key: 'circle', title: '圈子', icon: $r('app.media.nav_circle'), color: '#34C759' },
      { key: 'publish', title: '发布', icon: $r('app.media.nav_publish'), color: '#FF9500' },
      { key: 'message', title: '消息', icon: $r('app.media.nav_message'), color: '#AF52DE' },
      { key: 'profile', title: '我的', icon: $r('app.media.nav_profile'), color: '#FF2D55' },
    ];
  }

  // 内置开源宋体（Noto Serif SC），保证「全文科感」标题在无系统宋体的设备上也真实呈现。
  private registerSerifFont(): void {
    try {
      this.getUIContext().getFont().registerFont({
        familyName: 'Noto Serif SC',
        familySrc: $rawfile('fonts/NotoSerifSC-Bold.otf'),
      });
      // 正文字重：Regular 单独注册一个 family（一个 familyName 只能绑一个字体文件），
      // 正文用 Bold 字形会被整体拉粗，与标题失去层次。
      this.getUIContext().getFont().registerFont({
        familyName: 'Noto Serif SC Body',
        familySrc: $rawfile('fonts/NotoSerifSC-Regular.otf'),
      });
      // 创建 drawing Typeface 并传递给 textPoster.ets，让 canvas 绘制也使用衬线字体
      const typeface: drawing.Typeface = drawing.Typeface.makeFromRawFile($rawfile('fonts/NotoSerifSC-Bold.otf'));
      setSerifTypeface(typeface);
      // 海报正文用 Regular 字重，标题仍用 Bold
      const bodyTypeface: drawing.Typeface = drawing.Typeface.makeFromRawFile($rawfile('fonts/NotoSerifSC-Regular.otf'));
      setSerifBodyTypeface(bodyTypeface);
      hilog.info(0x0000, 'Index', 'serif font registered');
    } catch (err) {
      hilog.error(0x0000, 'Index', 'register serif font failed: %{public}s', JSON.stringify(err));
    }
  }

  aboutToAppear(): void {
    // 注册全局唯一 UIContext：util 文件（auth/navigationTransition 等）没有组件上下文，
    // 替换已废弃的全局 router/组件工具 API 时从这里取（与 mainNavStack 同一注册时机）。
    setSharedUiContext(this.getUIContext());
    this.registerSerifFont();
    initAuthStorage();
    setMainNavStack(this.pageStack);
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
    // 从隐私政策/用户协议页返回时，若用户尚未同意，重新弹出同意弹窗（审核可用性修复）
    if (this.privacyDialogShown && !isPrivacyAgreed()) {
      this.showPrivacyDialog(this.privacyDialogIsUpdate);
      return;
    }
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
      this.statusBarHeight = this.getUIContext().px2vp(area.topRect.height);
      // 底部导航高度（审核问题③）：三键导航条区域在 NEXT 上由 TYPE_NAVIGATION_INDICATOR 报告
      //（TYPE_SYSTEM bottomRect 实测为 0），手势指示条也在该类型。取两者最大值——
      // 三键 ≈28-40vp 抬升避让，手势 ≈16vp 顺带避开指示条。
      const sysBottom = win.getWindowAvoidArea(window.AvoidAreaType.TYPE_SYSTEM);
      const navIndicator = win.getWindowAvoidArea(window.AvoidAreaType.TYPE_NAVIGATION_INDICATOR);
      this.navBarHeight = Math.max(this.getUIContext().px2vp(sysBottom.bottomRect.height), this.getUIContext().px2vp(navIndicator.bottomRect.height));
      AppStorage.setOrCreate<number>('statusBarHeight', this.statusBarHeight);
      AppStorage.setOrCreate<number>('navBarHeight', this.navBarHeight);
    } catch (e) {
      // 失败不阻断
    }
  }

  private startInit(): void {
    // 冷启动即探测一次沉浸光感能力（真实日志输出），确保设备能力在首页构建期可用。
    isImmersiveLightSenseSupported();
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

  // 登录态过期（服务端 401，api.ets 打的全局标记）：清本地登录态 → 提示 → 引导重新登录。
  // 用户此前"看起来还登录着"（本地 token 在、界面显示昵称），但所有鉴权操作都会失败——
  // 统一在此收口，避免用户到处碰壁却不知道要重新登录。
  private onAuthExpired(): void {
    if (!this.authExpiredAt) {
      return;
    }
    // 区分文案：本地有 token 说明是会话过期；无 token 是匿名用户触发了需登录的操作
    const hadToken: boolean = getToken().length > 0;
    clearSession();
    safeShowToast(this.getUIContext(), { message: hadToken ? '登录已过期，请重新登录' : '请先登录后重试' });
    try {
      const r = this.getUIContext().getRouter();
      const state = r.getState();
      // 已在登录页时不重复入栈
      if (!state || state.path !== 'pages/LoginPage') {
        r.pushUrl({ url: 'pages/LoginPage' });
      }
    } catch (e) {
      // router 未就绪等异常不阻断（下次 401 标记会再试）
    }
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

  // 冷启动时校验持久化 JWT 是否仍有效。
  // 过期一律走正常 401 流程（api 写 authExpiredAt → onAuthExpired 统一清态并引导重登），
  // **不自动重登**：原先这里有一个 debug 专用的 loginWithDevStub 静默重登分支，
  // 提审前已移除——发布包不应包含「自动用测试账号重建会话」的路径。
  private async validateStartupSession(): Promise<void> {
    if (getToken() === '') {
      return;
    }
    try {
      await getMe();
    } catch (_) {
      // 校验失败不阻断启动：页面各自的网络重试机制稍后会再次拉取；
      // 若确为登录过期，401 处理器会把用户引到登录页。
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
    }).catch((e: Error) => {
      // 失败不阻断（离线/后端未起），但保留最小日志便于排查
      hilog.warn(0x0000, 'Index', 'getMe 失败（不阻断首启）: %{public}s', String(e.message));
    });
  }

  private showPrivacyDialog(isUpdate: boolean = false): void {
    this.privacyDialogIsUpdate = isUpdate;
    this.privacyConsentController.open();
  }

  private agreePrivacy(): void {
    setPrivacyAgreed(); // 本地兜底（离线也能拦截首启）
    // 已登录则落地服务端（PIPL 可追溯）；失败不阻断（离线/后端未起）
    if (getToken() !== '') {
      recordPrivacyConsent(PRIVACY_POLICY_VERSION).catch((e: Error) => {
        // 失败不阻断（离线/后端未起），本地已置位；保留日志用于追溯
        hilog.warn(0x0000, 'Index', '隐私同意落地失败（不阻断）: %{public}s', String(e.message));
      });
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

  // 发布占位 tab（index=2）点击拦截：只弹发布弹窗，通过 onContentWillChange 返回 false
  // 阻止 HdsTabs 切换到发布占位页（不再"先切走再弹回"，消除横向闪烁动画）。
  private handleTabBarClick(index: number): void {
    if (index === 2) {
      this.showPublishModeDialog();
      return;
    }
    this.lastPageIndex = index;
    this.selectTab(index);
  }

  // 导航目的地注册：pushPathByName(name, params) 对应的 NavDestination
  @Builder
  pageMap(name: string, _param: Object) {
    if (name === 'PostDetail') {
      PostDetailDestination()
    } else if (name === 'UserProfile') {
      UserProfileDestination()
    } else if (name === 'CircleDetail') {
      CircleDetailDestination()
    } else if (name === 'ChatPage') {
      ChatDestination()
    } else if (name === 'MyFollow') {
      MyFollowDestination()
    } else if (name === 'Login') {
      LoginDestination()
    }
  }

  // 官方 HdsTabs 页签：图标 + 文字，选中态品牌色；消息 tab（index=3）叠加未读红点。
  @Builder
  tabBarBuilder(index: number) {
    Column({ space: 3 }) {
      Stack({ alignContent: Alignment.Center }) {
        if (index === 3 && (this.unreadCount + this.dmUnread) > 0) {
          Badge({
            count: this.unreadCount + this.dmUnread,
            position: BadgePosition.RightTop,
            style: { badgeColor: $r('app.color.semantic_red'), badgeSize: 14 },
          })           {
            Image(this.bottomTabItems()[index].icon)
              .width(24).height(24)
              .objectFit(ImageFit.Contain)
          }
        } else {
          Image(this.bottomTabItems()[index].icon)
            .width(24).height(24)
            .objectFit(ImageFit.Contain)
        }
      }
      .width(28).height(28)
      Text(this.bottomTabItems()[index].title)
        .fontSize(10)
        .fontColor(this.currentIndex === index ? $r('app.color.ds_brand') : $r('app.color.ds_text_secondary'))
    }
    .width(64).height(54)
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
  }

  // 五个页签内容：发布占位（index=2）点击由 handleTabBarClick 拦截，不展示任何内容。
  @Builder
  mainTabContents() {
    // TabContent 默认在页面边界裁剪内容：每日一帖的飞行卡向上抛射需溢出到
    // 屏幕顶部（状态栏区域），首页 Tab 关闭裁剪，其余 Tab 内容各自不溢出、不受影响。
    TabContent() { HomeTab() }
      .clip(false)
      .tabBar(this.tabBarBuilder(0))
    TabContent() { CircleTab() }
      .tabBar(this.tabBarBuilder(1))
    // 发布占位：内容为空，点击由 handleTabBarClick 拦截弹窗，不展示任何内容。
    TabContent() { Column() {} }
      .tabBar(this.tabBarBuilder(2))
    TabContent() { MessagePage() }
      .tabBar(this.tabBarBuilder(3))
    TabContent() { ProfilePage() }
      .tabBar(this.tabBarBuilder(4))
  }

  // API 23+ 分支：悬浮玻璃底栏（barFloatingStyle/HdsTabsFloatingStyle/hdsMaterial 均 @since 23）。
  // systemMaterialEffect 传数值字面量（IMMERSIVE=101 / ADAPTIVE=10，对照见 immersiveMaterial.ets），
  // 避免静态 import hdsMaterial——该模块在 API 22 上不存在，import 即崩（审核问题①根因）。
  @Builder
  mainTabsFloating() {
    HdsTabs({ controller: this.hdsController }) {
      this.mainTabContents()
    }
    .clip(false)                             // 首页飞行卡向上抛射需溢出页面边界（状态栏区域）
    .barOverlap(true)                        // 悬浮：页签覆盖内容
    .barPosition(BarPosition.End)            // 底部
    .vertical(false)                         // 水平
    .barFloatingStyle({
      // barBottomMargin 在系统导航区之上再留 28vp：三键导航设备 navInset≈28-32vp，
      // 固定 28 会让底栏侵入导航条（审核问题③）；手势导航 navInset=0，维持原设计。
      barWidth: { smallWidth: DOCK_WIDTH_SMALL, mediumWidth: 420, largeWidth: 560 },
      barSideMargin: DOCK_SIDE_MARGIN_MIN,
      barBottomMargin: DOCK_BOTTOM_MARGIN_BASE + bottomNavInset(),
      gradientMask: { maskColor: $r('app.color.bar_gradient_mask'), maskHeight: DOCK_GRADIENT_MASK_HEIGHT },
      systemMaterialEffect: {
        materialType: DOCK_MATERIAL_TYPE,
        materialLevel: DOCK_MATERIAL_LEVEL,
      },
    })
    .scrollable(false)                       // 禁止页面主体左右滑动切换 Tab，仅点击底部页签切换
    .onContentWillChange((currentIndex: number, comingIndex: number): boolean => {
      // 发布占位 tab 不可切换：点击发布 tab 时阻止内容切换（配合 onTabBarClick 弹窗），
      // 从根上消除"先切走再弹回"的横向动画
      if (comingIndex === 2) {
        return false;
      }
      return true;
    })
    .onTabBarClick((index: number): void => { this.handleTabBarClick(index); })
    .onChange((index: number): void => {
      // 防发布占位页误切换：即使当前瞬时 index=2，也回跳并拒绝广播，确保 activeTab 不驻留 2。
      if (index === 2) {
        this.hdsController.changeIndex(this.currentIndex === 2 ? this.lastPageIndex : this.currentIndex);
        return;
      }
      this.selectTab(index);
    })
  }

  // API 20-22 / 模拟器分支：HdsTabs.barFloatingStyle @since 23 不可用，但视觉不降级——
  // 内置 Tabs（API 7）承载内容（barHeight(0) 隐藏自带条 + 隐藏分隔线），底部悬浮玻璃药丸
  // 由自绘 BottomTabBar（纯标准 ArkUI API，圆角/模糊/描边/阴影/点光源/弹性高亮全保留）
  // 叠加实现，视觉与 API 23+ 悬浮条同款。三键导航避让由药丸外层 margin 承担。
  @Builder
  mainTabsPlain() {
    Tabs({ barPosition: BarPosition.End, controller: this.tabsController }) {
      this.mainTabContents()
    }
    .width('100%')
    .height('100%')
    .clip(false)                             // 首页飞行卡向上抛射需溢出页面边界（状态栏区域）
    .vertical(false)
    .scrollable(false)
    .barHeight(0)
    .divider({ strokeWidth: 0, color: Color.Transparent })
    .onContentWillChange((currentIndex: number, comingIndex: number): boolean => {
      if (comingIndex === 2) {
        return false;
      }
      return true;
    })
    .onChange((index: number): void => {
      if (index === 2) {
        this.tabsController.changeIndex(this.currentIndex === 2 ? this.lastPageIndex : this.currentIndex);
        return;
      }
      this.selectTab(index);
    })
  }

  build() {
    Stack({ alignContent: Alignment.Bottom }) {
      // —— 组件导航根：主框架（Tabs + 悬浮底栏）作为 Navigation 首页 ——
      // 首页卡片→详情走 navDestination（customNavContentTransition + componentSnapshot 一镜到底）
      Navigation(this.pageStack) {
        Stack({ alignContent: Alignment.Bottom }) {
          Column() {
            // ⚠️ 隐私红线：未同意隐私政策前不构建主 Tab 内容。
            // 同意后 privacyAgreed 变 '1' → build 重跑 → 正常构建 Tab 并加载。
            if (this.privacyAgreed !== '1') {
              Blank()
            } else if (this.hdsFloatingBar) {
              this.mainTabsFloating()
            } else {
              this.mainTabsPlain()
            }
          }
          .width('100%')
          .height('100%')
          .padding({ top: this.statusBarHeight })

          // API 20-22 分支：自绘悬浮玻璃药丸底栏（BottomTabBar，纯标准 ArkUI，无 HDS 依赖）。
          // 与 API 23+ 的 HdsTabs 悬浮条同款视觉；三键导航避让由 margin 承担（审核问题③）。
          // 未同意隐私政策时不渲染底栏（此时没有可切换的页面，避免空白壳里出现可点的假壳）。
          if (!this.hdsFloatingBar && this.privacyAgreed === '1') {
            Row() {
              BottomTabBar({
                items: this.bottomTabItems(),
                currentIndex: $currentIndex,
                unreadCount: this.unreadCount + this.dmUnread,
                onSelect: (index: number): void => {
                  this.handleTabBarClick(index);
                  if (index !== 2) {
                    this.tabsController.changeIndex(index);
                  }
                },
              })
            }
            .width('100%')
            .padding({ left: LayoutTokens.tabBarSideMargin, right: LayoutTokens.tabBarSideMargin })
            .margin({ bottom: LayoutTokens.tabBarBottomGap + bottomNavInset() })
            .zIndex(50)
          }
        }
        .width('100%')
        .height('100%')
      }
      .id('mainNav')
      .hideTitleBar(true)
      // 首页每日一帖飞行卡向上抛射需一路溢出到窗口顶部（状态栏区域），
      // 关闭 Navigation 内容裁剪（详情页全屏、快照转场在独立层，均不受影响）。
      .clip(false)
      .navDestination(this.pageMap)
      // 首页卡片 → 帖子详情：一镜到底按官方范式实现——目的地页在 onReady 里
      // 按自己的 navDestinationId 注册转场，这里只负责按 from/to 的 id 查表并转交
      // （PUSH 交 to、POP 交 from）。未注册的目的地返回 undefined，走系统默认转场。
      .customNavContentTransition((from: NavContentInfo, to: NavContentInfo,
        operation: NavigationOperation): NavigationAnimatedTransition | undefined => {
        const toId: string = to.navDestinationId !== undefined ? to.navDestinationId : '';
        const fromId: string = from.navDestinationId !== undefined ? from.navDestinationId : '';
        const toCb: LongTakeCallback = LongTakeTransition.getInstance().get(toId);
        const fromCb: LongTakeCallback = LongTakeTransition.getInstance().get(fromId);
        LongTakeTransition.getInstance().operation = operation;
        if (toCb.animation === undefined && fromCb.animation === undefined) {
          return undefined;   // 未注册自定义转场的目的地（含返回目标）走系统默认
        }
        return {
          timeout: toCb.timeout !== undefined ? toCb.timeout : fromCb.timeout,
          onTransitionEnd: (): void => {
            LongTakeTransition.getInstance().proxy = undefined;
          },
          transition: (proxy: NavigationTransitionProxy): void => {
            LongTakeTransition.getInstance().proxy = proxy;
            const cb: LongTakeCallback = operation === NavigationOperation.PUSH ? toCb : fromCb;
            if (cb.animation !== undefined) {
              cb.animation(proxy);
            } else {
              proxy.finishTransition();
            }
          },
        };
      })
      .width('100%')
      .height('100%')

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
