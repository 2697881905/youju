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
import { PublishMode, PublishModeSheet } from '../components/PublishModeSheet';
import { LayoutTokens } from '../design/tokens/space';
import { bottomNavInset } from '../utils/cardTokens';
import { RadiusTokens } from '../design/tokens/radius';
import { common } from '@kit.AbilityKit';
import { window } from '@kit.ArkUI';
import { hilog } from '@kit.PerformanceAnalysisKit';
import font from '@ohos.font';
import { publishFlowStore } from '../utils/publishFlowStore';
import { AppTab, subscribeTabSwitch } from '../utils/nav';
import { setSerifTypeface, setSerifBodyTypeface } from '../utils/textPoster';
import { drawing } from '@kit.ArkGraphics2D';
import { HdsTabs, HdsTabsController } from '@kit.UIDesignKit';
import { isImmersiveLightSenseSupported, GlassBlurStyle } from '../utils/immersiveMaterial';
import { ImmersiveSurface } from '../design/components/ImmersiveSurface';

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
    // 沉浸光感面板：真机在弹窗下方叠加双边流光，模拟器自动降级为系统玻璃（视觉不变）。
    ImmersiveSurface({ radius: 16 }) {
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
          .backgroundBlurStyle(GlassBlurStyle.Dialog)
          .backgroundColor(isImmersiveLightSenseSupported() ? Color.Transparent : $r('app.color.bar_surface'))
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
          .fontSize(14)
          .height(40)
          .fontFamily('Noto Serif SC')
          .fontColor($r('app.color.ds_brand'))
          .backgroundBlurStyle(GlassBlurStyle.Dialog)
          .backgroundColor(isImmersiveLightSenseSupported() ? Color.Transparent : $r('app.color.bar_surface'))
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
  private hdsController: HdsTabsController = new HdsTabsController();
  // 悬浮玻璃底栏（barFloatingStyle 及其全部字段）@since 6.1.0(23)：API 6.0.2(22) 上调用会抛
  // TypeError（方法不存在）导致首页无法渲染。isImmersiveLightSenseSupported() 现为同步确定值
  // （deviceInfo.sdkApiVersion + canIUse，进程级缓存），不会运行期翻转 → 组件不会重建。
  private hdsFloatingBar: boolean = isImmersiveLightSenseSupported();
  @State lastPageIndex: number = 0;   // 发布前的实际页面 tab，用于发布后回跳
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
      font.registerFont({
        familyName: 'Noto Serif SC',
        familySrc: $rawfile('fonts/NotoSerifSC-Bold.otf'),
      });
      // 正文字重：Regular 单独注册一个 family（一个 familyName 只能绑一个字体文件），
      // 正文用 Bold 字形会被整体拉粗，与标题失去层次。
      font.registerFont({
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
      this.statusBarHeight = px2vp(area.topRect.height);
      this.navBarHeight = px2vp(area.bottomRect.height);
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
    TabContent() { HomeTab() }
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
    .barOverlap(true)                        // 悬浮：页签覆盖内容
    .barPosition(BarPosition.End)            // 底部
    .vertical(false)                         // 水平
    .barFloatingStyle({
      // barBottomMargin 在系统导航区之上再留 28vp：三键导航设备 navInset≈28-32vp，
      // 固定 28 会让底栏侵入导航条（审核问题③）；手势导航 navInset=0，维持原设计。
      barWidth: { smallWidth: 300, mediumWidth: 420, largeWidth: 560 },
      barSideMargin: 16,
      barBottomMargin: 28 + bottomNavInset(),
      gradientMask: { maskColor: $r('app.color.bar_gradient_mask'), maskHeight: 92 },
      systemMaterialEffect: {
        materialType: 101,
        materialLevel: 10,
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

  // API 22 及以下 / 模拟器分支：省略 barFloatingStyle（@since 23），其余属性全部 @since 20 可用。
  // 底栏退化为标准悬浮页签（barOverlap 仍生效），功能完整，仅失去玻璃药丸视觉。
  @Builder
  mainTabsPlain() {
    HdsTabs({ controller: this.hdsController }) {
      this.mainTabContents()
    }
    .barOverlap(true)                        // 悬浮：页签覆盖内容
    .barPosition(BarPosition.End)            // 底部
    .vertical(false)                         // 水平
    .scrollable(false)
    // API 22 分支：底栏抬升避让三键导航条（审核问题③）；手势导航 navInset=0 不影响。
    .padding({ bottom: bottomNavInset() })
    .onContentWillChange((currentIndex: number, comingIndex: number): boolean => {
      if (comingIndex === 2) {
        return false;
      }
      return true;
    })
    .onTabBarClick((index: number): void => { this.handleTabBarClick(index); })
    .onChange((index: number): void => {
      if (index === 2) {
        this.hdsController.changeIndex(this.currentIndex === 2 ? this.lastPageIndex : this.currentIndex);
        return;
      }
      this.selectTab(index);
    })
  }

  build() {
    Stack({ alignContent: Alignment.Bottom }) {
      Column() {
        if (this.hdsFloatingBar) {
          this.mainTabsFloating()
        } else {
          this.mainTabsPlain()
        }
      }
      .width('100%')
      .height('100%')
      .padding({ top: this.statusBarHeight })

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
