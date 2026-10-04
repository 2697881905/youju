// 有据 主框架：悬浮底部导航栏（系统背景模糊 + 半透明分层 + 动态高光透镜）
// Tab：首页 / 圈子 / 发布 / 消息 / 我的；帖子详情经 router 单独跳转（pages/DetailPage）
import { HomeTab, FeedMode, FEED_SEGMENTS } from '../components/HomeTab';
import { CircleTab } from '../components/CircleTab';
import { CircleOnboarding } from '../components/CircleOnboarding';
import { MessagePage, MESSAGE_SEGMENTS } from './MessagePage';
import { ProfilePage, PROFILE_SEGMENTS } from './ProfilePage';
import { initAuthStorage, getToken, getUserId, setPrivacyAgreed, isPrivacyAgreed, clearSession, PRIVACY_POLICY_VERSION } from '../utils/auth';
import { getUnreadCount, getDmUnreadCount, getMe, recordPrivacyConsent, followTag, listTags, getPost, PostWithComments } from '../services/api';
import { Tag } from '../models/types';
import { safeShowToast } from '../utils/toast';
import { PublishMode, PublishModeSheet } from '../components/PublishModeSheet';
import { SearchPanelDestination } from './SearchPanelDestination';
import { openSearchPanelViaNav, SEARCH_ENTRY_ID } from '../utils/longTake/openSearchPanelNav';
import { SpringPanel } from '../design/motion/SpringPanel';
import { DesignButton } from '../design/components/DesignButton';
import { LayoutTokens, SpaceTokens } from '../design/tokens/space';
import { bottomNavInset, DOCK_WIDTH_SMALL, DOCK_BOTTOM_MARGIN_BASE, DOCK_SIDE_MARGIN_MIN, DOCK_GRADIENT_MASK_HEIGHT, DOCK_MATERIAL_TYPE, DOCK_MATERIAL_LEVEL } from '../utils/cardTokens';
import { RadiusTokens } from '../design/tokens/radius';
import { ShadowTokens } from '../design/tokens/shadow';
import { ColorTokens } from '../design/tokens/color';
import { TypeTokens } from '../design/tokens/type';
import { IconTokens } from '../design/tokens/icon';
import { CountRoll } from '../design/motion/CountRoll';
import { Pressable } from '../design/motion/Pressable';
import { resolveActionIcon } from '../utils/actionIcons';
import { resolveSettingsIcon } from '../utils/settingsIcons';
import { EXTERNAL_SHARE_ENABLED } from '../utils/share';
import { ProfileHeader } from '../components/ProfileHeader';
import { resolveDisplayImageUrl } from '../services/api';
import { User } from '../models/types';
import { SegmentedControl } from '../design/components/SegmentedControl';
import { TagNav } from '../components/TagNav';
import { common } from '@kit.AbilityKit';
import { window, display } from '@kit.ArkUI';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { publishFlowStore } from '../utils/publishFlowStore';
import { AppTab, subscribeTabSwitch, emitTabSwitch, openPostDetail, openPostDetailAtComment, openChat, openFollowList, openUserProfile } from '../utils/nav';
import { MotionCurves, MotionTokens } from '../design/tokens/motion';
import { takePushRoute, syncPushToken, requestNotificationPermission } from '../utils/push';
import { readClipboardPostId, markClipboardIdHandled } from '../utils/clipboardJump';
import { ClipboardPostSheet, ClipboardPostPayload } from '../components/ClipboardPostSheet';
import { setMainNavStack, setSharedUiContext } from '../utils/navigationTransition';
import { AnimateCallback, CustomTransition } from '../utils/longTake/customNavigationUtils';
import { setSerifTypeface, setSerifBodyTypeface } from '../utils/poster/posterText';
import { drawing } from '@kit.ArkGraphics2D';
import { HdsTabs, HdsTabsController } from '@kit.UIDesignKit';
import { isImmersiveLightSenseSupported, isSystemMaterialActive, TopButtonMaterialModifier } from '../utils/immersiveMaterial';
import { BottomTabBar } from '../design/components/BottomTabBar';
import { PostDetailDestination } from './PostDetailDestination';
import { UserProfileDestination } from './UserProfileDestination';
import { CircleDetailDestination } from './CircleDetailDestination';
import { ChatDestination } from './ChatDestination';
import { MyFollowDestination } from './MyFollowDestination';
import { LoginDestination } from './LoginDestination';
import { VideoPlayerDestination } from './VideoPlayerDestination';

// 底部页签数据项（含发布占位 tab）。发布 tab 也走同一 builder，展示 + 图标。
interface IndexTabItem {
  key: string;
  title: string;
  icon: Resource;
  color?: ResourceColor;
}

// 首启/更新隐私同意弹窗。
// 样式层完全对齐应用设计系统，面板规格与 PublishModeSheet / FolderNameDialog 同规格
// （panelWidth 344 / panelPadding lg / radius lg / solid 实色档）：
//   · 材质走 solid 档（elevated 实色暖纸底 + separator 1px 发丝描边 + cardAmbient 阴影）。
//     承载合规正文的浮层不用半透明玻璃 —— 玻璃底会让正文对比度随背景漂移，
//     且 docs/feature-index.md 已实测「大面积承载正文不适合 outlined/透明底」。
//   · 正文与链接落在 solid 底上的实测对比度（WCAG）：
//     浅色 primary 17.9:1 / secondary 11.0:1 / brand 5.1:1；
//     深色 primary 15.1:1 / secondary 8.1:1 / brand 7.6:1。全部 AA 及以上。
//   · 底部两键：主键 DesignButton primary（brand 实色 + onBrand 字，浅 5.2:1 / 深 8.2:1），
//     次键自绘（透明底 + separator 描边 + secondary 字，浅 11.0:1 / 深 8.1:1），
//     不再用 iOS 亮红（旧实现 semantic_red 在浅色玻璃底上仅 3.1:1，不达 AA）。
//   · 正文放 Scroll 并按屏高封顶（maxBodyHeightVp），长文滚动不塌陷、
//     标题与按钮行常驻可见；面板宽度按屏宽封顶 344、下限 280，适配小屏与大屏。
// 仅调整样式层：打开/关闭、协议跳转、同意/不同意行为与回调签名均未改动。
@CustomDialog
struct PrivacyConsentDialog {
  controller: CustomDialogController;
  getIsUpdate: () => boolean = (): boolean => false;
  onReadPrivacy: () => void = (): void => {};
  onReadAgreement: () => void = (): void => {};
  onAgree: () => void = (): void => {};
  onDecline: () => void = (): void => {};

  // 屏宽（vp）：面板宽度基准。px→vp 走 densityPixels 除法（与 utils/navMode.ets 同法，
  // 不依赖 px2vp 的 UIContext 形态 —— 那是 @since 22，高于工程下限 20）。
  // 取不到时按应用标准宽度 344 兜底。
  private screenWidthVp(): number {
    try {
      const d: number = display.getDefaultDisplaySync().densityPixels;
      const w: number = display.getDefaultDisplaySync().width;
      return d > 0 && w > 0 ? w / d : 344;
    } catch (e) {
      return 344;
    }
  }

  // 面板宽度：标准 344；窄屏按屏宽留边不溢出，宽屏不再无限拉伸。
  private panelWidth(): number {
    const w: number = this.screenWidthVp();
    return Math.max(280, Math.min(344, w - 48));
  }

  // 正文区最大高度（vp）：约屏高 1/3 封顶，保证标题与按钮行始终留在可视区内。
  private maxBodyHeightVp(): number {
    try {
      const d: number = display.getDefaultDisplaySync().densityPixels;
      const h: number = display.getDefaultDisplaySync().height;
      if (d <= 0 || h <= 0) {
        return 240;
      }
      return Math.max(160, Math.round(h / d / 3));
    } catch (e) {
      return 240;
    }
  }

  @Builder
  policyLink(label: string, action: () => void): void {
    // 条款链接与 LoginView 底部「《用户协议》/《隐私政策》」同语言：brand 色 + headline 字重，
    // 不加下划线（应用内链接统一不装饰，避免与正文混淆）。
    Text(label)
      .fontSize(TypeTokens.callout.size).fontFamily(TypeTokens.fontFamily)
      .fontWeight(TypeTokens.headline.weight)
      .lineHeight(TypeTokens.callout.lineHeight)
      .fontColor(ColorTokens.brand)
      .onClick((): void => {
        action();
      })
  }

  build() {
    SpringPanel({ panelWidth: this.panelWidth(), panelPadding: SpaceTokens.lg, solid: true }) {
      Column({ space: SpaceTokens.base }) {
        // 标题：衬线 + headline 字级（与 PublishModeSheet / FolderNameDialog 弹窗标题同规格）
        Text(this.getIsUpdate() ? '隐私政策更新' : '隐私政策与用户协议')
          .fontSize(TypeTokens.headline.size).fontFamily(TypeTokens.fontFamilySerif)
          .fontWeight(TypeTokens.headline.weight)
          .lineHeight(TypeTokens.headline.lineHeight)
          .fontColor(ColorTokens.primary)
          .width('100%')
          .textAlign(TextAlign.Center)

        // 正文 + 条款链接：可滚动区，长文本滚动时标题/按钮不塌陷
        Scroll() {
          Column({ space: SpaceTokens.md }) {
            Text(this.getIsUpdate()
              ? '我们的隐私政策已更新，请阅读并重新同意以继续使用。'
              : '欢迎使用有据。我们仅在为你提供内容推荐、账号安全等必要服务时收集相关信息。')
              .fontSize(TypeTokens.callout.size).fontFamily(TypeTokens.fontFamily)
              .fontWeight(TypeTokens.callout.weight)
              .lineHeight(TypeTokens.callout.lineHeight)
              .fontColor(ColorTokens.secondary)
              .width('100%')

            // 链接区：Flex 换行容器，窄屏/大字体下链接换行而不溢出
            Flex({ wrap: FlexWrap.Wrap }) {
              Text('点击查看')
                .fontSize(TypeTokens.callout.size).fontFamily(TypeTokens.fontFamily)
                .fontWeight(TypeTokens.callout.weight)
                .lineHeight(TypeTokens.callout.lineHeight)
                .fontColor(ColorTokens.tertiary)
              this.policyLink('《隐私政策》', (): void => { this.onReadPrivacy(); })
              Text('和')
                .fontSize(TypeTokens.callout.size).fontFamily(TypeTokens.fontFamily)
                .fontWeight(TypeTokens.callout.weight)
                .lineHeight(TypeTokens.callout.lineHeight)
                .fontColor(ColorTokens.tertiary)
              this.policyLink('《用户协议》', (): void => { this.onReadAgreement(); })
            }
            .width('100%')
          }
          .width('100%')
          .alignItems(HorizontalAlign.Start)
        }
        .width('100%')
        .constraintSize({ maxHeight: this.maxBodyHeightVp() })
        .scrollBar(BarState.Auto)

        // 底部操作：主次分明。
        // ⚠️ 写法约束（ArkTS 解析规则，报 10505001）：自定义组件若带尾随闭包
        // `Foo({...}) { ... }`，闭包后**不能再接属性链**。Pressable / SpringPanel 都属此类，
        // 不能写成 `Pressable({...}){...}.layoutWeight(1)`（本项目 ReportAdminPage.ets:1153
        // 已记过同一条坑）。DesignButton 走构造参数、无尾随闭包，故可以链式挂 layoutWeight。
        //   · 同意 = DesignButton primary：brand 实色 + onBrand 字（浅 5.2:1 / 深 8.2:1），
        //     填充与面板 5.1:1 / 7.6:1，主键辨识度足够。
        //   · 不同意 = 自绘：透明底 + separator 描边 + secondary 字。
        //     不用 DesignButton('outlined'/'glass')：二者在 elevated 实色底上的描边
        //     分别只有 1.07:1 与 1.09:1（barBorder / separator 压 elevated），
        //     等于看不见 —— 见 docs/home-segmented-control-style-audit.md §5.2。
        //     按压反馈用 Text.stateStyles（同 SettingsPage.ets:189 写法）。
        Row({ space: SpaceTokens.md }) {
          Text('不同意')
            .layoutWeight(1)
            .height(LayoutTokens.minTouchTarget)
            .textAlign(TextAlign.Center)
            .fontSize(TypeTokens.callout.size).fontFamily(TypeTokens.fontFamily)
            .fontWeight(TypeTokens.headline.weight)
            .lineHeight(TypeTokens.callout.lineHeight)
            .fontColor(ColorTokens.secondary)
            .backgroundColor(Color.Transparent)
            .border({ width: 1, color: ColorTokens.separator, style: BorderStyle.Solid })
            .borderRadius(RadiusTokens.pill)
            .stateStyles({
              normal: {
                .opacity(1)
              },
              pressed: {
                .opacity(0.7)
                .scale({ x: 0.97, y: 0.97 })
              }
            })
            .onClick((): void => {
              this.controller.close();
              this.onDecline();
            })

          DesignButton({
            label: '同意并继续',
            fillWidth: true,
            visualHeight: LayoutTokens.minTouchTarget,
            action: (): void => {
              this.controller.close();
              this.onAgree();
            },
          })
            .layoutWeight(1)
        }
        .width('100%')
      }
      .width('100%')
    }
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
  // 通知点击带来的待处理路由序号（值 payload 在 AppStorage['pendingPushRoute']）。
  // 用单调递增的序号而非 payload 本身做信号：连点两条同类通知时值可能相同，
  // AppStorage 对同值写入不派发变更，必须有序号才会触发回调。
  @StorageLink('pushRouteSeq') @Watch('onPushRouteChanged') pushRouteSeq: number = 0;
  // 剪贴板分享链接检查信号（EntryAbility.onForeground 递增）：暖前台回切时重新检测。
  // 冷启动的检测点在 continueLaunchFlow / agreePrivacy（挂载后一次性触发）。
  @StorageLink('clipboardCheckSeq') @Watch('onClipboardCheckSeq') clipboardCheckSeq: number = 0;
  // 剪贴板命中的帖子（确认面板数据）。id > 0 = 面板展示中，期间忽略重复检查信号。
  @State clipboardPostId: number = 0;
  @State clipboardPostTitle: string = '';
  @State clipboardAuthorName: string = '';
  private clipboardBusy: boolean = false;
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
  // —— 首页顶栏共享状态：顶部区域（品牌标题/搜索/分段栏/圈子按钮）整体驻留
  // Navigation 标题栏后由本页持有，HomeTab 通过 @Link 共用并联动信息流 ——
  @State feedIndex: number = 0;
  @State feedMode: FeedMode = 'recommend';
  @State slidePosition: number = -1;
  @State tagIndex: number = 0;
  @State displayTags: Tag[] = [];
  @State showCircleDropdown: boolean = false;
  // —— 「我的」页顶栏共享状态：顶栏（我的/分享/设置 + 资料区 + 主分段栏）同样驻留标题栏 ——
  @State profileUser: User = {};
  @State profileFollowingCount: number = 0;
  @State profileFollowerCount: number = 0;
  @State profileTotalLikes: number = 0;
  @State profileTabIdx: number = 0;
  @State profileSlidePosition: number = -1;
  @State profilePresented: boolean = false;
  @State profileShareSeq: number = 0;
  // —— 「消息」页顶栏共享状态：顶栏（消息+全部已读）+ 分段栏驻留标题栏 ——
  // （三类快捷筛选/举报中心/系统通知都在 MessagePage 内容区，不经此处）
  @StorageLink('authToken') messageToken: string = '';
  @State messageTabIndex: number = 0;
  @State messageSlidePosition: number = -1;
  @State messageTabPulse: boolean = false;
  @State messageMarkAllSeq: number = 0;
  // —— 「圈子」页顶栏共享状态：顶栏（圈子标题 + 已加入药丸）迁入标题栏 ——
  // （星环画布、选中卡片等仍在 CircleTab 内容区，不经此处）
  @State circleJoinedCount: number = 0;   // 已加入 N 个：CircleTab 加载后经 @Link 回写
  @State circleJoinedSeq: number = 0;     // 点击药丸的递增信号，弹窗仍由 CircleTab 承接
  // 顶栏分段切换的透明反馈动画遵循系统「减弱动态效果」
  @StorageLink('reduceMotion') reduceMotion: boolean = false;
  @StorageLink('systemReduceMotion') systemReduceMotion: boolean = false;
  // 资料区实测高度（内容驱动：身份块 / 背景图卡），首帧用估算值兜底，实测后取代
  @State profileHeroHeight: number = 0;
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
  // 剪贴板分享链接确认面板：命中 youju.chat/post/{id} 后由用户决定是否打开
  private clipboardSheetController: CustomDialogController = new CustomDialogController({
    builder: ClipboardPostSheet({
      getPayload: (): ClipboardPostPayload | null => this.clipboardPayload(),
      onOpen: (): void => { this.openClipboardPost(); },
      onIgnore: (): void => { this.dismissClipboardPost(); },
    }),
    alignment: DialogAlignment.Bottom,
    customStyle: true,
    autoCancel: true,
    // 点击面板外/返回键关闭同样视为「忽略」：本会话内不再对该链接打扰
    cancel: (): void => { this.dismissClipboardPost(); },
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
  });

  private bottomTabItems(): IndexTabItem[] {
    return [
      { key: 'home', title: '首页', icon: $r('app.media.nav_home'), color: $r('app.color.ds_brand') },
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
      // 登录/切号返回首页时补推送初始化：冷启动为访客时 startInit 会跳过推送注册，
      // 这里兜住「游客 → 应用内登录」路径（syncPushToken 幂等，已上报则空跑）
      this.initPushCapabilities();
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
      // 访客也可能经 youju:// 分享链接（落地页「去有据看看」按钮）或通知点击冷启动：
      // 帖子/主页内容公开，路由意图的消费不依赖登录态——否则访客冷启动的直达意图会被静默丢掉
      this.consumePendingPushRoute();
      return;
    }
    this.validateStartupSession();
    this.refreshUnread();
    this.maybeShowCircleOnboarding();
    this.initPushCapabilities();
    // 冷启动若来自通知点击，路由意图在 Index 挂载前已由 EntryAbility 写入 AppStorage，此处补消费
    this.consumePendingPushRoute();
  }

  // 登录后启用推送：先申请通知权限（未授权时系统不把 Push 消息展示进通知栏），再上报本机 Token。
  // 两者都异步且失败静默 —— 取不到 token 只影响推送，不波及主流程。
  private initPushCapabilities(): void {
    const ctx = this.getUIContext().getHostContext();
    if (ctx !== undefined && ctx !== null) {
      requestNotificationPermission(ctx as common.UIAbilityContext);
    }
    syncPushToken();
  }

  // 消费通知点击带来的路由意图（一次性取出即清空）
  private consumePendingPushRoute(): void {
    const route = takePushRoute();
    if (route === null) {
      return;
    }
    if (route.type === 'dm' && route.peerId > 0) {
      // 私信：直接进会话页，peer 头像缺失交给 ChatView 走占位
      openChat({ peerId: route.peerId, peerName: route.peerName, peerAvatar: '' });
      try {
        this.getUIContext().getRouter().pushUrl({ url: 'pages/ChatPage' });
      } catch (e) {
        hilog.warn(0x0000, 'push', '通知跳转私信页失败 %{public}s', JSON.stringify(e));
      }
      return;
    }
    if (route.userId > 0) {
      // deep link youju://user/{id}（分享落地页拉起）：与站内点击头像同通道进他人主页
      openUserProfile(route.userId);
      try {
        this.getUIContext().getRouter().pushUrl({ url: 'pages/UserProfilePage' });
      } catch (e) {
        hilog.warn(0x0000, 'push', '链接拉起用户主页失败 %{public}s', JSON.stringify(e));
      }
      return;
    }
    if (route.postId > 0) {
      // @提及带 commentId 时定位到具体评论，其余进详情顶部
      if (route.commentId > 0) {
        openPostDetailAtComment(String(route.postId), route.commentId);
      } else {
        openPostDetail(String(route.postId));
      }
      try {
        this.getUIContext().getRouter().pushUrl({ url: 'pages/DetailPage' });
      } catch (e) {
        hilog.warn(0x0000, 'push', '通知跳转详情页失败 %{public}s', JSON.stringify(e));
      }
      return;
    }
    // 无关联帖子（关注 / 系统通知）：落到消息 Tab
    emitTabSwitch(3);
  }

  private onPushRouteChanged(): void {
    // 启动流程未走完时 Tab 容器还没就绪，先不跳：pendingPushRoute 保留着，
    // 由 startInit 兜底消费；已就绪则该走 @Watch 的实时路径（热启动点通知）。
    if (!this.launchComplete) {
      return;
    }
    this.consumePendingPushRoute();
  }

  // ===== 剪贴板分享链接：抖音式「复制打开有据」 =====
  // 链接只来自我们自己生成的分享文案（youju.chat/post/{id}）；命中后先弹确认面板，
  // 用户点「打开帖子」才跳转 —— 不静默读取跳转；同一链接本会话内只打扰一次。

  private clipboardPayload(): ClipboardPostPayload | null {
    if (this.clipboardPostId <= 0) {
      return null;
    }
    const payload: ClipboardPostPayload = {
      postId: this.clipboardPostId,
      title: this.clipboardPostTitle,
      authorName: this.clipboardAuthorName,
    };
    return payload;
  }

  private onClipboardCheckSeq(): void {
    // 启动流程未走完（或隐私未同意）不检测：冷启动由 continueLaunchFlow/agreePrivacy 统一触发
    if (!this.launchComplete || !isPrivacyAgreed()) {
      return;
    }
    this.checkClipboardPostLink();
  }

  private async checkClipboardPostLink(): Promise<void> {
    if (this.clipboardBusy || this.clipboardPostId > 0) {
      return;
    }
    const ctx = this.getUIContext().getHostContext();
    if (ctx === undefined || ctx === null) {
      return;
    }
    const id: number = await readClipboardPostId(ctx as common.UIAbilityContext);
    // 异步窗口内可能已被处理（重复信号 / 面板已打开）
    if (id <= 0 || this.clipboardBusy || this.clipboardPostId > 0) {
      return;
    }
    this.clipboardBusy = true;
    try {
      const post: PostWithComments = await getPost(id);
      this.clipboardPostId = id;
      this.clipboardPostTitle = post.title ?? '';
      this.clipboardAuthorName = post.user?.nickname ?? '有据用户';
      this.clipboardSheetController.open();
    } catch (e) {
      // 帖子已删除 / 无权访问 / 网络失败：本会话不再对同一链接重复打扰
      markClipboardIdHandled(id);
    } finally {
      this.clipboardBusy = false;
    }
  }

  private openClipboardPost(): void {
    const id: number = this.clipboardPostId;
    this.dismissClipboardPost();
    if (id <= 0) {
      return;
    }
    // 与通知点击跳转同一通道：意图通道 openPostDetail + router 推 DetailPage
    openPostDetail(String(id));
    try {
      this.getUIContext().getRouter().pushUrl({ url: 'pages/DetailPage' });
    } catch (e) {
      hilog.warn(0x0000, 'Index', '剪贴板跳转详情页失败 %{public}s', JSON.stringify(e));
    }
  }

  private dismissClipboardPost(): void {
    markClipboardIdHandled(this.clipboardPostId);
    this.clipboardPostId = 0;
    this.clipboardSheetController.close();
  }

  // 启动就绪后的剪贴板检查：有待消费的通知跳转意图时让位（本次跳过，回前台信号会再来）
  private checkClipboardPostLinkAfterStart(): void {
    if ((AppStorage.get<string>('pendingPushRoute') ?? '') !== '') {
      return;
    }
    this.checkClipboardPostLink();
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
    // 能走到这里必然是「本地曾有 token 但服务端判定失效」—— 匿名访客的 401 已在 api.ets
    // 的 markAuthExpired 里被拦掉（不打标记），那种情况交给各入口/目标页自己的登录闸门。
    clearSession();
    safeShowToast(this.getUIContext(), { message: '登录已过期，请重新登录' });
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
    // 冷启动剪贴板分享链接检查（首启同意隐私后走 agreePrivacy 的同名钩子）
    this.checkClipboardPostLinkAfterStart();
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
    // 首启刚同意隐私：此刻起才允许读剪贴板，补一次检查（此前红线是「告知—同意前处理」）
    this.checkClipboardPostLinkAfterStart();
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
    // 离开首页时收起圈子下拉面板：标题栏会隐藏，但面板挂在 HomeTab 内容层，需显式关闭
    this.showCircleDropdown = false;
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
      // 未登录：在这里就拦住，直接引导登录，**不**弹发布方式弹窗、更不入发布页。
      // 旧实现缺这道闸门 —— 登录跳转发生在发布页内部（ImagePicker/VideoPicker/预览页的
      // ensureLogin 把 LoginPage 压在发布页之上），用户取消登录返回时露出的就是发布页，
      // 而不是主页（用户反馈的实际现象）。
      if (getToken() === '') {
        this.getUIContext().getRouter().pushUrl({ url: 'pages/LoginPage' });
        return;
      }
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
    } else if (name === 'VideoPlayer') {
      // 独立视频播放器页：帖子等入口点击视频后进入（详情页不再内嵌播放器浮层）
      VideoPlayerDestination()
    } else if (name === 'SearchPanel') {
      // 搜索面板：首页搜索按钮一镜到底的落点（自定义转场，整页从按钮帧缩放展开）
      SearchPanelDestination()
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
              .fillColor($r('app.color.ds_icon'))
          }
        } else {
          Image(this.bottomTabItems()[index].icon)
            .width(24).height(24)
            .objectFit(ImageFit.Contain)
            .fillColor($r('app.color.ds_icon'))
        }
      }
      .width(28).height(28)
      Text(this.bottomTabItems()[index].title)
        .fontSize(10)
        .fontColor(this.currentIndex === index ? $r('app.color.ds_brand') : $r('app.color.ds_icon'))
    }
    .width(64).height(54)
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
  }

  // —— 首页顶栏（品牌标题 + 搜索 + 分段栏 + 圈子按钮）：整体驻留 Navigation 标题栏 ——
  // 这是通用属性 systemMaterial（沉浸光感）的官方生效区域（内容区不渲染，见官方 FAQ）。
  // 低版本设备（API < 26）门禁不通过 → 材质自动跳过，各控件回退为细描边样式（与旧首页一致）。
  private homeSearchMaterial: TopButtonMaterialModifier = new TopButtonMaterialModifier();
  // 「我的」标题栏右上角分享/设置按钮的同源材质修饰器（沉浸光感，标题栏为官方生效区域）
  private profileActionMaterial: TopButtonMaterialModifier = new TopButtonMaterialModifier();
  // 「圈子」标题栏「已加入」药丸的同源材质修饰器（沉浸光感，标题栏为官方生效区域）
  private circleJoinedMaterial: TopButtonMaterialModifier = new TopButtonMaterialModifier();

  // 标题栏总高：状态栏 + 头部上下内边距(xs×2) + 品牌行 + 行距(xs) + 分段行（与旧首页头部等高）
  private homeTitleBarHeight(): number {
    return this.statusBarHeight + SpaceTokens.xs * 2 + LayoutTokens.titleBarHeight
      + SpaceTokens.xs + LayoutTokens.segmentedHeight;
  }

  // 顶栏是否显示（hideTitleBar 与内容区状态栏避让共用同一条件，保证两者同步）：
  // 首页(0)/圈子(1)/消息(3)/我的(4) 有顶栏，其它 Tab 与隐私壳无顶栏（仍需手动避让状态栏）。
  // 顶栏为 STANDARD 占位 → 显示时栏体已涵盖状态栏区域，内容区不能再重复加内边距。
  private mainTitleBarVisible(): boolean {
    return (this.currentIndex === 0 || this.currentIndex === 1 || this.currentIndex === 3
      || this.currentIndex === 4) && this.privacyAgreed === '1';
  }

  // 顶层标题栏内容：首页顶栏 / 圈子顶栏 / 消息页顶栏 / 我的页顶栏
  // （按当前 Tab 分支；@Builder 引用不能放进三元表达式）
  @Builder
  mainTitleBar() {
    if (this.currentIndex === 4) {
      this.profileTitleBar()
    } else if (this.currentIndex === 3) {
      this.messageTitleBar()
    } else if (this.currentIndex === 1) {
      this.circleTitleBar()
    } else {
      this.homeTitleBar()
    }
  }

  // 标题栏高度（须与 mainTitleBar 的分支一一对应）
  private mainTitleBarHeight(): number {
    if (this.currentIndex === 4) {
      return this.profileTitleBarHeight();
    }
    if (this.currentIndex === 3) {
      return this.messageTitleBarHeight();
    }
    if (this.currentIndex === 1) {
      return this.circleTitleBarHeight();
    }
    return this.homeTitleBarHeight();
  }

  // 「圈子」标题栏总高：状态栏 + 顶栏行上下内边距(xs×2) + 药丸行（segmentedHeight）。
  // 与原 CircleTab topBar 行同构：titleSerif 行高 32 < 36，行高由药丸决定。
  private circleTitleBarHeight(): number {
    return this.statusBarHeight + SpaceTokens.xs * 2 + LayoutTokens.segmentedHeight;
  }

  // 「圈子」标题栏：原 CircleTab 顶部「圈子」标题 + 「已加入 N 个」药丸整体驻留于此
  // （沉浸光感官方生效区域）。计数来自 CircleTab 加载后经 @Link 回写；点击药丸经
  // circleJoinedSeq 信号由 CircleTab @Watch 打开弹窗（profileShareSeq 同款接线）。
  @Builder
  circleTitleBar() {
    // 状态栏避让必须由本 Builder 手动承担（全屏布局下标题栏不代为避让，教程 Step 3），
    // 且要放在外层容器上：同一节点写两次 .padding 是整体覆盖（后者吞掉前者），
    // 不能与行内边距混在一个 padding 里之外再补一条。
    Column() {
      Row({ space: SpaceTokens.sm }) {
        Text('圈子')
          .fontSize(TypeTokens.titleSerif.size).fontFamily(TypeTokens.fontFamilySerif)
          .fontWeight(TypeTokens.titleSerif.weight)
          .lineHeight(TypeTokens.titleSerif.lineHeight)
          .alignSelf(ItemAlign.Start)
          .fontColor(ColorTokens.primary)
        Blank()
        Pressable({
          visualHeight: LayoutTokens.segmentedHeight,
          touchTargetHeight: LayoutTokens.minTouchTarget,
          action: (): void => {
            // 递增信号 → CircleTab @Watch：JoinedCirclesDialog 仍由 CircleTab 打开
            this.circleJoinedSeq += 1;
          },
        }) {
          Row({ space: SpaceTokens.xs }) {
            Text('已加入')
              .fontSize(TypeTokens.caption.size).fontFamily(TypeTokens.fontFamily)
              .fontWeight(TypeTokens.caption.weight)
              .fontColor(ColorTokens.secondary)
            CountRoll({ value: this.circleJoinedCount, prefix: '', textSize: TypeTokens.caption.size, textColor: ColorTokens.primary })
            Text('个')
              .fontSize(TypeTokens.caption.size).fontFamily(TypeTokens.fontFamily)
              .fontWeight(TypeTokens.caption.weight)
              .fontColor(ColorTokens.secondary)
          }
          .height(LayoutTokens.segmentedHeight)
          .padding({ left: SpaceTokens.md, right: SpaceTokens.md })
          // 沉浸光感：材质生效时自绘让位（底/描边/阴影归零，否则实心毛玻璃/双圈描边，
          // 见教程案例②④），系统材质接管药丸表面；低版本门禁不通过 → 保留原样式
          .backgroundColor(isSystemMaterialActive() ? Color.Transparent : ColorTokens.subtle)
          .border({
            width: isSystemMaterialActive() ? 0 : LayoutTokens.glassBorderWidth,
            color: ColorTokens.separator,
            style: BorderStyle.Solid,
          })
          .borderRadius(RadiusTokens.pill)
          .shadow(isSystemMaterialActive() ? ShadowTokens.none : ShadowTokens.cardContact)
          .alignItems(VerticalAlign.Center)
          .attributeModifier(this.circleJoinedMaterial)
        }
      }
      .width('100%')
      .padding({ left: SpaceTokens.sm, right: SpaceTokens.sm, top: SpaceTokens.xs, bottom: SpaceTokens.xs })
      .alignItems(VerticalAlign.Center)
    }
    .width('100%')
    // 手动避让状态栏（含在栏高 statusBarHeight + xs×2 + segmentedHeight 内；避让只此一处）
    .padding({ top: this.statusBarHeight })
  }

  @Builder
  homeTitleBar() {
    Column({ space: SpaceTokens.xs }) {
      // 品牌标题行：有据 / SUBSTANTIATE / 真实经验，有据可循 + 右上角搜索按钮
      Row() {
        Column({ space: SpaceTokens.xs }) {
          Row({ space: SpaceTokens.sm }) {
            Text('有据')
              .fontSize(TypeTokens.titleSerif.size)
              .fontFamily(TypeTokens.fontFamilySerif)
              .fontWeight(TypeTokens.titleSerif.weight)
              .lineHeight(TypeTokens.titleSerif.lineHeight)
              .fontColor(ColorTokens.primary)
            Text('SUBSTANTIATE')
              .fontSize(TypeTokens.overline.size)
              .fontFamily(TypeTokens.fontFamily)
              .fontWeight(TypeTokens.overline.weight)
              .fontColor(ColorTokens.tertiary)
          }
          Text('真实经验，有据可循')
            .fontSize(TypeTokens.headline.size)
            .fontFamily(TypeTokens.fontFamilySerif)
            .fontWeight(TypeTokens.headline.weight)
            .lineHeight(TypeTokens.headline.lineHeight)
            .fontColor(ColorTokens.primary)
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)
        // 搜索入口（图标按钮）：一镜到底走 PostDetail 同款自定义转场——
        // 量按钮屏幕帧 + push SearchPanel（NavDestination 整页从按钮帧缩放展开）。
        // id 供发起器量帧/截图定位（SEARCH_ENTRY_ID，见 openSearchPanelNav.ets）。
        Pressable({
          visualHeight: LayoutTokens.minTouchTarget,
          touchTargetHeight: LayoutTokens.minTouchTarget,
          action: (): void => {
            // 搜索入口跳转独立搜索页（与首页解耦）；Navigation 未就绪时兜底 router 整页
            openSearchPanelViaNav(this.getUIContext());
          },
        }) {
          Row() {
            Image(resolveActionIcon('search'))
              .width(IconTokens.small)
              .height(IconTokens.small)
              .fillColor(ColorTokens.icon)
          }
          .width(LayoutTokens.minTouchTarget)
          .height(LayoutTokens.minTouchTarget)
          .border({ width: LayoutTokens.glassBorderWidth, color: ColorTokens.barBorder, style: BorderStyle.Solid })
          .borderRadius(RadiusTokens.lg)
          .justifyContent(FlexAlign.Center)
          .alignItems(VerticalAlign.Center)
          .attributeModifier(this.homeSearchMaterial)
          .id(SEARCH_ENTRY_ID)
          .accessibilityText('搜索')
        }
      }
      .width('100%')
      .height(LayoutTokens.titleBarHeight)
      .alignItems(VerticalAlign.Center)

      // 分段栏（推荐/关注/每日一帖）+ 圈子下拉按钮：与搜索按钮同一套系统材质
      Stack({ alignContent: Alignment.TopStart }) {
        SegmentedControl({
          items: FEED_SEGMENTS,
          selectedIndex: $feedIndex,
          slidePosition: this.slidePosition,
          itemWidth: 66,
          fillWidth: false,
          glass: false,
          outlined: true,
          // 关闭按压/长按光斑：顶栏为材质玻璃/描边风格，光斑在这块纸面上过于抢眼
          glowEnabled: false,
          // 沉浸光感：驻留标题栏，由系统材质接管整栏表面
          useSystemMaterial: true,
          onSelect: (idx: number): void => {
            // 点击立即落整数位（弹性动画由 SharedSlide 整数分支承担）；
            // 信息源加载由 HomeTab 的 @Watch(feedIndex) 承接（见 onFeedIndexChanged）
            this.slidePosition = idx;
            this.feedIndex = idx;
          },
        })
          .alignSelf(ItemAlign.Start)
          // 置顶于全宽的 TagNav 圈子 chip 之上：TagNav 透明占位区不拦截本控件的点击
          .zIndex(3)
        if (this.feedMode === 'recommend') {
          TagNav({
            tags: this.displayTags,
            selectedIndex: $tagIndex,
            dropdownVisible: $showCircleDropdown,
            compact: true,
            glass: false,
            dropdownOnly: true,
            // 沉浸光感：圈子按钮与搜索/分段栏同源材质
            useSystemMaterial: true,
          })
            .width('100%')
            .zIndex(2)
        }
      }
      .width('100%')
      .height(LayoutTokens.segmentedHeight)
    }
    .width('100%')
    // 全屏沉浸式布局下标题栏不代为避让状态栏：按 statusBarHeight 手动下移，
    // 再加 xs(4) 与旧首页头部（首行 padding 顶 4vp）严格对齐。
    .padding({
      left: SpaceTokens.sm,
      right: SpaceTokens.sm,
      top: this.statusBarHeight + SpaceTokens.xs,
      bottom: SpaceTokens.xs,
    })
    .height(this.homeTitleBarHeight())
    .alignItems(HorizontalAlign.Start)
  }

  // —— 我的页顶栏（我的/分享/设置 + 资料区 + 主分段栏）：同样驻留 Navigation 标题栏 ——
  // 数据来自 ProfilePage 的共享态（@Link），跳转/登录引导在此接线；分享流程仍由 ProfilePage 完成。
  private profileLoggedIn(): boolean {
    return (this.profileUser.id ?? 0) > 0;
  }

  // 关注/粉丝数字块：已登录进列表页，未登录就地引导登录（与旧 ProfilePage 行为一致）
  private openProfileFollow(mode: string): void {
    const uid: number = this.profileUser.id ?? 0;
    if (uid === 0) {
      this.getUIContext().getRouter().pushUrl({ url: 'pages/LoginPage' });
      return;
    }
    openFollowList({ userId: uid, mode: mode === 'followers' ? 'followers' : 'following' });
    this.getUIContext().getRouter().pushUrl({ url: 'pages/MyFollowPage' });
  }

  // 资料区背景图地址（空串 = 无背景图）：profileBackground 为可选字段，
  // 这里统一收敛类型，供 @Builder 分支与 Image 源共用（@Builder 体内不能声明 const）。
  private profileBackgroundUrl(): string {
    return this.profileUser.profileBackground ?? '';
  }

  // 屏宽（vp）：背景图卡按 16:10 估算高度用。px→vp 走 densityPixels 除法
  // （与 PrivacyConsentDialog.screenWidthVp 同法，不依赖 px2vp 的 UIContext 形态）。
  private screenWidthVp(): number {
    try {
      const d: number = display.getDefaultDisplaySync().densityPixels;
      const w: number = display.getDefaultDisplaySync().width;
      return d > 0 && w > 0 ? w / d : 400;
    } catch (e) {
      return 400;
    }
  }

  // 资料区首帧高度估算（实测值 profileHeroHeight 到齐前兜底）：
  // 有背景图 → 16:10 图卡（按屏宽算）；无背景 → 身份块 146 + 统计行 + 已登录的草稿/废纸篓行。
  private profileHeroEstimate(): number {
    if (this.profileBackgroundUrl() !== '') {
      return (this.screenWidthVp() - SpaceTokens.sm * 2) / (16 / 10) + SpaceTokens.xs * 2;
    }
    return 146 + 44 + SpaceTokens.sm + (this.profileLoggedIn() ? LayoutTokens.segmentedHeight + SpaceTokens.xs + 4 : 0);
  }

  // 「我的」标题栏总高：状态栏 + 顶栏行(36+xs×2) + 资料区 + 主分段栏(36+顶部 xs)
  private profileTitleBarHeight(): number {
    const hero: number = this.profileHeroHeight > 0 ? this.profileHeroHeight : this.profileHeroEstimate();
    return this.statusBarHeight + LayoutTokens.segmentedHeight + SpaceTokens.xs * 2
      + hero + LayoutTokens.segmentedHeight + SpaceTokens.xs;
  }

  // 资料区本体（ProfileHeader 只呈现，跳转/登录引导等意图在这里接线）
  @Builder
  profileHeaderBlock(onBackground: boolean) {
    ProfileHeader({
      avatar: this.profileUser.avatar ?? '',
      name: this.profileLoggedIn() ? (this.profileUser.nickname ?? '有据用户') : '未登录',
      gender: this.profileUser.gender ?? 0,
      bio: this.profileLoggedIn() ? (this.profileUser.bio ?? '') : '登录后查看与发布你的内容',
      userId: this.profileUser.id ?? 0,
      isLoggedIn: this.profileLoggedIn(),
      followingCount: this.profileFollowingCount,
      followerCount: this.profileFollowerCount,
      totalLikes: this.profileTotalLikes,
      onBackground: onBackground,
      onOpenFollowing: (): void => { this.openProfileFollow('following'); },
      onOpenFollowers: (): void => { this.openProfileFollow('followers'); },
      onEdit: (): void => { this.getUIContext().getRouter().pushUrl({ url: 'pages/EditProfilePage' }); },
      onOpenDrafts: (): void => { this.getUIContext().getRouter().pushUrl({ url: 'pages/DraftBoxPage' }); },
      onOpenTrash: (): void => { this.getUIContext().getRouter().pushUrl({ url: 'pages/TrashBoxPage' }); },
      onLogin: (): void => { this.getUIContext().getRouter().pushUrl({ url: 'pages/LoginPage' }); },
    })
  }

  @Builder
  profileTitleBar() {
    Column({ space: SpaceTokens.none }) {
      // 顶栏行：我的 + 分享（外部分享开关开启时）+ 设置
      Row({ space: SpaceTokens.sm }) {
        Text('我的')
          .fontSize(TypeTokens.titleSerif.size).fontFamily(TypeTokens.fontFamilySerif)
          .fontWeight(TypeTokens.titleSerif.weight)
          .lineHeight(TypeTokens.titleSerif.lineHeight)
          .alignSelf(ItemAlign.Start)
          .fontColor(ColorTokens.primary)
        Blank()
        if (EXTERNAL_SHARE_ENABLED) {
          Pressable({
            visualHeight: LayoutTokens.segmentedHeight,
            touchTargetHeight: LayoutTokens.minTouchTarget,
            action: (): void => {
              // 递增信号 → ProfilePage @Watch：分享弹层/文案/系统分享仍由本页逻辑完成
              this.profileShareSeq += 1;
            },
          }) {
            Row() {
              Image(resolveActionIcon('share'))
                .width(IconTokens.small)
                .height(IconTokens.small)
                .fillColor(ColorTokens.icon)
            }
            .width(LayoutTokens.segmentedHeight)
            .height(LayoutTokens.segmentedHeight)
            .justifyContent(FlexAlign.Center)
            // 沉浸光感：标题栏内由系统材质接管表面（低版本自动跳过；无底色/描边，仅材质）
            .borderRadius(RadiusTokens.lg)
            .attributeModifier(this.profileActionMaterial)
            .accessibilityText('分享主页')
          }
        }
        Pressable({
          visualHeight: LayoutTokens.segmentedHeight,
          touchTargetHeight: LayoutTokens.minTouchTarget,
          action: (): void => {
            this.getUIContext().getRouter().pushUrl({ url: 'pages/SettingsPage' });
          },
        }) {
          Row() {
            Image(resolveSettingsIcon('gear'))
              .width(IconTokens.small)
              .height(IconTokens.small)
              .fillColor(ColorTokens.icon)
          }
          .width(LayoutTokens.segmentedHeight)
          .height(LayoutTokens.segmentedHeight)
          .justifyContent(FlexAlign.Center)
          // 沉浸光感：与分享按钮同源材质（低版本自动跳过；无底色/描边，仅材质）
          .borderRadius(RadiusTokens.lg)
          .attributeModifier(this.profileActionMaterial)
        }
      }
      .width('100%')
      .padding({
        left: SpaceTokens.sm,
        right: SpaceTokens.sm,
        top: SpaceTokens.xs,
        bottom: SpaceTokens.xs,
      })

      // 资料区（含背景图变体与入场动效）：高度实测回写 → 栏高随内容自适应
      Column() {
        if (this.profileBackgroundUrl() !== '') {
          Column() {
            Stack() {
              Image(resolveDisplayImageUrl(this.profileBackgroundUrl()))
                .width('100%')
                .height('100%')
                .objectFit(ImageFit.Cover);
              Column() {
                this.profileHeaderBlock(true);
              }
              .width('100%')
              .height('100%')
              .justifyContent(FlexAlign.End)
              .backgroundColor('#52000000');
            }
            .width('100%')
            .aspectRatio(16 / 10)
            .borderRadius(RadiusTokens.lg)
            .clip(true);
          }
          .width('100%')
          .padding({ left: SpaceTokens.sm, right: SpaceTokens.sm, top: SpaceTokens.xs, bottom: SpaceTokens.xs });
        } else {
          Column() {
            this.profileHeaderBlock(false);
          }
          .width('100%');
        }
      }
      .width('100%')
      .opacity(this.profilePresented ? 1 : 0)
      .translate({ y: this.profilePresented ? 0 : SpaceTokens.xl })
      .scale({
        x: this.profilePresented ? 1 : MotionTokens.enterScale,
        y: this.profilePresented ? 1 : MotionTokens.enterScale,
      })
      .animation({
        duration: MotionTokens.page,
        curve: MotionCurves.emphasized,
      })
      .onAreaChange((_old: Area, area: Area): void => {
        // 资料区高度是内容驱动的（不受栏高钳制），实测后回写栏高：
        // 登录态切换、背景图有无、屏宽变化都会自然修正。
        const h: number = parseFloat(String(area.height));
        if (h > 0 && Math.abs(h - this.profileHeroHeight) > 0.5) {
          this.profileHeroHeight = h;
        }
      })

      // 主分段栏：我发布 / 我收藏 / 我赞过 / 我评论（沉浸光感：系统材质接管表面）
      SegmentedControl({
        items: PROFILE_SEGMENTS,
        selectedIndex: $profileTabIdx,
        slidePosition: this.profileSlidePosition,
        itemWidth: 67,
        // 与首页分段栏同配置：材质生效时用描边底（透明，让系统材质完整透出）；
        // 低版本保留原「华为应用商店同款」沉浸玻璃 —— 它的 backdropBlur 会遮挡材质，二者互斥。
        immersive: !isSystemMaterialActive(),
        outlined: isSystemMaterialActive(),
        glowEnabled: false,
        useSystemMaterial: true,
        onSelect: (idx: number): void => {
          // 点击立即落整数位（弹性动画由 SharedSlide 整数分支承担）；
          // 列表刷新由 ProfilePage 的 @Watch(tabIdx) 承接
          this.profileSlidePosition = idx;
          this.profileTabIdx = idx;
        },
      })
      .margin({ left: SpaceTokens.sm, right: SpaceTokens.sm, top: SpaceTokens.xs })
    }
    .width('100%')
    // 全屏沉浸式布局下标题栏不代为避让状态栏：手动下移
    .padding({ top: this.statusBarHeight })
  }

  // —— 「消息」页顶栏（消息/全部已读 + 通知|私信分段 + 三类快捷筛选）：同样驻留标题栏 ——
  // 数据与动作来自 MessagePage 的共享态（@Link）；列表统计回写、全部已读仍由本页执行。
  private shouldReduceMotion(): boolean {
    return this.reduceMotion || this.systemReduceMotion;
  }

  // 「全部已读」只在通知分段且已登录时出现（私信分段没有该动作）
  private messageMarkAllVisible(): boolean {
    return this.messageTabIndex === 0 && this.messageToken !== '';
  }

  // 栏高：状态栏 + 顶栏行(44+上下 xs) + 分段栏(36+底部 sm)
  private messageTitleBarHeight(): number {
    const headerRow: number = LayoutTokens.minTouchTarget + SpaceTokens.xs * 2;
    const segmented: number = LayoutTokens.segmentedHeight + SpaceTokens.sm;
    return this.statusBarHeight + headerRow + segmented;
  }

  @Builder
  messageTitleBar() {
    Column({ space: SpaceTokens.none }) {
      // 顶栏行：消息 + 全部已读（仅通知分段且已登录）
      Row() {
        Text('消息')
          .fontSize(TypeTokens.titleSerif.size).fontFamily(TypeTokens.fontFamilySerif)
          .fontWeight(TypeTokens.titleSerif.weight)
          .lineHeight(TypeTokens.titleSerif.lineHeight)
          .alignSelf(ItemAlign.Start)
          .layoutWeight(1)
          .fontColor(ColorTokens.primary)
        if (this.messageMarkAllVisible()) {
          Pressable({
            visualHeight: LayoutTokens.minTouchTarget,
            touchTargetHeight: LayoutTokens.minTouchTarget,
            action: (): void => {
              // 递增信号 → MessagePage @Watch：标记全部已读仍由本页执行
              this.messageMarkAllSeq += 1;
            },
          }) {
            Text('全部已读')
              .fontSize(TypeTokens.callout.size).fontFamily(TypeTokens.fontFamily)
              .fontWeight(TypeTokens.headline.weight)
              .lineHeight(TypeTokens.callout.lineHeight)
              .letterSpacing(TypeTokens.callout.tracking)
              .fontColor(ColorTokens.brand)
              .height(LayoutTokens.minTouchTarget)
              .padding({ left: SpaceTokens.sm, right: SpaceTokens.sm })
              .textAlign(TextAlign.Center)
              .accessibilityText('全部已读')
          }
        }
      }
      .width('100%')
      // 固定顶栏高度：避免切换分段时整块回弹（私信页没有「全部已读」）
      .height(LayoutTokens.minTouchTarget + SpaceTokens.xs * 2)
      .padding({
        left: SpaceTokens.sm,
        right: SpaceTokens.sm,
        top: SpaceTokens.xs,
        bottom: SpaceTokens.xs,
      })

      // 分段：通知 | 私信（沉浸光感：材质生效时用描边底，让系统材质完整透出）
      SegmentedControl({
        items: MESSAGE_SEGMENTS,
        selectedIndex: $messageTabIndex,
        slidePosition: this.messageSlidePosition,
        itemWidth: 88,
        immersive: !isSystemMaterialActive(),
        outlined: isSystemMaterialActive(),
        glowEnabled: false,
        useSystemMaterial: true,
        onSelect: (idx: number): void => {
          // 点击立即落整数位（弹性动画由 SharedSlide 整数分支承担）；
          // 分段切换动作由 MessagePage 的 @Watch(dmTabIndex) 承接
          this.messageSlidePosition = idx;
          this.messageTabIndex = idx;
        },
      })
      .margin({ left: SpaceTokens.sm, right: SpaceTokens.sm, bottom: SpaceTokens.sm })
      // 分段控件保持固定尺寸；切换反馈只改变透明度，避免高度跳变
      .opacity(this.messageTabPulse ? 0.96 : 1)
      .animation({
        duration: this.shouldReduceMotion() ? MotionTokens.instant : MotionTokens.control,
        curve: MotionCurves.springSoft,
      })
    }
    .width('100%')
    // 全屏沉浸式布局下标题栏不代为避让状态栏：手动下移
    .padding({ top: this.statusBarHeight })
  }

  // 五个页签内容：发布占位（index=2）点击由 handleTabBarClick 拦截，不展示任何内容。
  @Builder
  mainTabContents() {
    // TabContent 默认在页面边界裁剪内容：每日一帖的飞行卡向上抛射需溢出到
    // 屏幕顶部（状态栏区域），首页 Tab 关闭裁剪，其余 Tab 内容各自不溢出、不受影响。
    // 首页：顶栏已整体迁入 Navigation 标题栏，这里通过 @Link 共享顶栏状态
    TabContent() {
      HomeTab({
        feedIndex: $feedIndex,
        feedMode: $feedMode,
        slidePosition: $slidePosition,
        tagIndex: $tagIndex,
        displayTags: $displayTags,
        showCircleDropdown: $showCircleDropdown,
      })
    }
      .clip(false)
      .tabBar(this.tabBarBuilder(0))
    // 「圈子」：顶栏（圈子标题 + 已加入药丸）迁入 Navigation 标题栏，这里通过 @Link 共享顶栏状态
    // （计数由 CircleTab 加载后回写；点击药丸经 seq 信号由 CircleTab 打开弹窗）
    TabContent() {
      CircleTab({
        circleJoinedCount: $circleJoinedCount,
        circleJoinedSeq: $circleJoinedSeq,
      })
    }
      .tabBar(this.tabBarBuilder(1))
    // 发布占位：内容为空，点击由 handleTabBarClick 拦截弹窗，不展示任何内容。
    TabContent() { Column() {} }
      .tabBar(this.tabBarBuilder(2))
    // 「消息」：顶栏已整体迁入 Navigation 标题栏，这里通过 @Link 共享顶栏状态
    TabContent() {
      MessagePage({
        dmTabIndex: $messageTabIndex,
        slidePosition: $messageSlidePosition,
        tabPulse: $messageTabPulse,
        markAllSeq: $messageMarkAllSeq,
      })
    }
      .tabBar(this.tabBarBuilder(3))
    // 「我的」：顶栏已整体迁入 Navigation 标题栏，这里通过 @Link 共享顶栏状态
    TabContent() {
      ProfilePage({
        user: $profileUser,
        followingCount: $profileFollowingCount,
        followerCount: $profileFollowerCount,
        totalLikes: $profileTotalLikes,
        tabIdx: $profileTabIdx,
        slidePosition: $profileSlidePosition,
        profilePresented: $profilePresented,
        profileShareSeq: $profileShareSeq,
      })
    }
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
          // 顶栏（首页/圈子/消息/我的）显示时，状态栏避让已由标题栏承担（栏高含 statusBarHeight）；
          // 这里若再补一条状态栏内边距，标题栏与内容之间会多出整条状态栏高度的空白。
          // 其它 Tab / 隐私壳没有标题栏，仍需手动避让状态栏。
          .padding({ top: this.mainTitleBarVisible() ? 0 : this.statusBarHeight })

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
      // 标题栏承载首页/圈子/消息/「我的」整块顶栏（品牌标题/搜索/分段栏/已加入药丸/资料区等）
      // —— uiMaterial 沉浸光感的官方生效区域。
      // 仅首页(0)/圈子(1)/消息(3)/我的(4) 显示（隐私未同意时不显示）；其它 Tab 完全隐藏，不占用各页顶部布局。
      // barStyle: STANDARD → 顶栏占位、内容从顶栏之下开始（与旧页面头部在流内的布局同构）；
      // 底色 canvas 与旧头部一致（也作为各控件系统材质的采样底色）。
      .hideTitleBar(!this.mainTitleBarVisible())
      .title({
        builder: this.mainTitleBar,
        height: this.mainTitleBarHeight(),
      }, { barStyle: BarStyle.STANDARD, backgroundColor: ColorTokens.canvas })
      // 首页每日一帖飞行卡向上抛射需一路溢出到窗口顶部（状态栏区域），
      // 关闭 Navigation 内容裁剪（详情页全屏、快照转场在独立层，均不受影响）。
      .clip(false)
      .navDestination(this.pageMap)
      // 首页卡片 → 帖子详情：一镜到底按官方范式实现——目的地页在 onReady 里
      // 按自己的 navDestinationId 注册转场，这里只负责按 from/to 的 id 查表并转交
      // （PUSH 交 to、POP 交 from）。未注册的目的地返回 undefined，走系统默认转场。
      .customNavContentTransition((from: NavContentInfo, to: NavContentInfo,
        operation: NavigationOperation): NavigationAnimatedTransition | undefined => {
        // ⚠️ 官方在此处要求 from/to **都**有 navDestinationId，那条守卫成立的前提是
        // 「源页本身也是 NavDestination」（官方示例的卡片列表页就是）。本项目源页是
        // Navigation 的**根内容**（HomeTab 在 navBar 位），PUSH 时 from.navDestinationId 为空，
        // 照抄这条守卫会让首页→详情的自定义转场整条失效（踩过：页面不展开变形、内容停在
        // 0 透明度，屏幕上只剩一张放大的卡片截图）。因此这里只用 id 查表，取不到即视为未注册。
        const toParam: AnimateCallback = CustomTransition.getInstance().getAnimateParam(to.navDestinationId ?? '');
        const fromParam: AnimateCallback =
          CustomTransition.getInstance().getAnimateParam(from.navDestinationId ?? '');
        // 未注册自定义转场的目的地（含返回目标）走系统默认转场
        if (fromParam.animation === undefined && toParam.animation === undefined) {
          return undefined;
        }
        CustomTransition.getInstance().operation = operation;
        const customAnimation: NavigationAnimatedTransition = {
          // PUSH 交 to、POP 交 from
          timeout: operation === NavigationOperation.PUSH ? toParam.timeout : fromParam.timeout,
          onTransitionEnd: (): void => {
            CustomTransition.getInstance().proxy = undefined;
          },
          transition: (transitionProxy: NavigationTransitionProxy): void => {
            CustomTransition.getInstance().proxy = transitionProxy;
            const animateParam: AnimateCallback =
              operation === NavigationOperation.PUSH ? toParam : fromParam;
            if (animateParam.animation !== undefined) {
              animateParam.animation(transitionProxy);
            } else {
              transitionProxy.finishTransition();
            }
          }
        };
        return customAnimation;
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
