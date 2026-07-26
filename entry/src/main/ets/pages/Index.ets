// 大蓝书 主框架：悬浮底部导航栏（透明玻璃：backdropBlur 模糊 + 极低 alpha 中性填充，如实透出背后内容）
// Tab：首页 / 圈子 / 发布 / 消息 / 我的；帖子详情经 router 单独跳转（pages/DetailPage）
import { HomeTab } from '../components/HomeTab';
import { CircleTab } from '../components/CircleTab';
import { PublishPage } from './PublishPage';
import { MessagePage } from './MessagePage';
import { ProfilePage } from './ProfilePage';
import { initAuthStorage, getToken, setPrivacyAgreed, isPrivacyAgreed, recordPrivacyConsent, PRIVACY_POLICY_VERSION } from '../utils/auth';
import { getUnreadCount, getDmUnreadCount, getMe } from '../services/api';
import { ensurePushRegistration } from '../utils/huaweiPush';
import { common } from '@kit.AbilityKit';
import { window } from '@kit.ArkUI';

// 悬浮栏尺寸令牌
const BAR_HEIGHT: number = 62;
const BAR_RADIUS: number = 28;
const BAR_SIDE_MARGIN: number = 18;
const BAR_BOTTOM_GAP: number = 18;
const PILL_RADIUS: number = 18;
// 长按滑动高光尺寸（光斑直径 vp）
const GLOW_SIZE: number = 180;
// 长按进入滑动高亮模式的时长（ms）
const LONG_PRESS_MS: number = 180;

interface TabDef {
  key: string;
  title: string;
}

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
  @State barWidth: number = 0;
  private longPressTimer: number = 0;       // 长按计时器句柄
  private suppressClickUntil: number = 0;   // 滑动结束后短暂屏蔽 tab 自身 onClick，避免重复触发
  private pressArmed: boolean = false;      // 长按已触发，但需移动才进入滑动模式
  private pressDownX: number = 0;           // 按下点的栏内 x，用于移动阈值判断

  private tabs: TabDef[] = [
    { key: 'home', title: '首页' },
    { key: 'circle', title: '圈子' },
    { key: 'publish', title: '发布' },
    { key: 'message', title: '消息' },
    { key: 'profile', title: '我的' }
  ];

  aboutToAppear(): void {
    initAuthStorage();
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

  private navIconRes(index: number): Resource {
    switch (index) {
      case 0: return $r('app.media.nav_home');
      case 1: return $r('app.media.nav_circle');
      case 2: return $r('app.media.nav_publish');
      case 3: return $r('app.media.nav_message');
      default: return $r('app.media.nav_profile');
    }
  }

  // 底栏颜色全部走 app.color.* 资源（bar_surface / bar_border / bar_shadow），
  // 与全 app 共用 setColorMode 这一唯一真相源，彻底避免「底栏与 app 深浅错位」。
  // 色值沿用此前认可的磨砂玻璃方案：浅色 ~99% 白雾，深色 100% 不透明（盖死背后内容）。

  @Builder
  TabInner(tab: TabDef, index: number) {
    Column({ space: 3 }) {
      // 内部芯片：选中/悬停时蓝底只包住图标+文字，不铺满整段
      Column({ space: 3 }) {
        if (index === 3 && (this.unreadCount + this.dmUnread) > 0) {
          Badge({
            count: this.unreadCount + this.dmUnread,
            position: BadgePosition.RightTop,
            style: { badgeColor: $r('app.color.semantic_red'), badgeSize: 16 }
          }) {
            Image(this.navIconRes(index))
              .width(26)
              .height(26)
              .fillColor(this.isActive(index) ? $r('app.color.brand_primary') : $r('app.color.text_secondary'))
          }
        } else {
          Image(this.navIconRes(index))
            .width(26)
            .height(26)
            .fillColor(this.isActive(index) ? $r('app.color.brand_primary') : $r('app.color.text_secondary'))
        }
        Text(tab.title)
          .fontSize(10)
          .fontColor(this.isActive(index) ? $r('app.color.brand_primary') : $r('app.color.text_secondary'))
      }
      .padding({ left: 14, right: 14, top: 6, bottom: 6 })
      .borderRadius(PILL_RADIUS)
      .backgroundColor(Color.Transparent)
      .animation({ duration: 200, curve: Curve.EaseOut })
    }
    .layoutWeight(1)
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
    .onClick(() => {
      if (Date.now() < this.suppressClickUntil) { return; }
      this.selectTab(index);
    })
  }

  @Builder
  FloatingTabBar() {
    Row() {
      ForEach(this.tabs, (tab: TabDef, i: number) => {
        this.TabInner(tab, i);
      }, (tab: TabDef) => tab.key)
    }
    .width('100%')
    .height(BAR_HEIGHT)
    .justifyContent(FlexAlign.SpaceEvenly)
    .alignItems(VerticalAlign.Center)
    .borderRadius(BAR_RADIUS)
    .backdropBlur(40)
    .backgroundColor($r('app.color.bar_surface'))
    .border({ width: 1, color: $r('app.color.bar_border'), style: BorderStyle.Solid })
    .shadow({ radius: 16, color: $r('app.color.bar_shadow'), offsetY: 8 })
    .clip(true)
    .onAreaChange((_old: Area, _new: Area) => {
      this.barWidth = _new.width as number;
    })
    .onTouch((e: TouchEvent) => { this.onBarTouch(e); })
    .overlay(this.glowOverlay)
  }

  // 长按滑动时跟随指尖的高光（关=透明，被 Row 的 clip 限制在栏内）
  @Builder
  glowOverlay(): void {
    Column()
      .width(GLOW_SIZE)
      .height(BAR_HEIGHT)
      .radialGradient({
        center: [GLOW_SIZE / 2, BAR_HEIGHT / 2],
        radius: GLOW_SIZE / 2,
        colors: [
          ['#FFFFFF', 0.0],
          ['#E6FFFFFF', 0.18],
          ['#70FFFFFF', 0.5],
          ['#00FFFFFF', 1.0],
        ],
      })
      .blendMode(BlendMode.SCREEN)
      .position({ x: this.glowX - GLOW_SIZE / 2, y: 0 })
      .opacity(this.scrubbing ? 1 : 0)
      .hitTestBehavior(HitTestMode.None)
      .animation({ duration: 120, curve: Curve.EaseOut })
  }

  // 触屏事件：长按+移动才进入滑动高亮（静止长按仍视为点按，立即走 onClick，不卡 180ms）
  // 滑动时高光跟手 + 悬停按钮高亮；松手触发悬停按钮
  private onBarTouch(e: TouchEvent): void {
    if (e.type === TouchType.Down) {
      const t = e.touches[0];
      if (!t) { return; }
      const x = this.clampGlow(t.x);
      this.pressDownX = x;
      this.glowX = x;
      if (this.longPressTimer !== 0) { clearTimeout(this.longPressTimer); }
      this.longPressTimer = setTimeout(() => {
        this.pressArmed = true;
      }, LONG_PRESS_MS) as number;
    } else if (e.type === TouchType.Move) {
      const t = e.touches[0];
      if (!t) { return; }
      const x = this.clampGlow(t.x);
      this.glowX = x;
      // 长按已触发且手指移动超过阈值，才真正进入滑动模式
      if (this.pressArmed && !this.scrubbing && Math.abs(x - this.pressDownX) > 6) {
        this.scrubbing = true;
      }
      if (this.scrubbing) { this.hoverIndex = this.indexFromX(this.glowX); }
    } else {
      // Up / Cancel：Up 时 e.touches 常为空，切勿在此提前 return，必须无条件复位所有状态
      if (this.longPressTimer !== 0) { clearTimeout(this.longPressTimer); this.longPressTimer = 0; }
      if (this.scrubbing) {
        const target = this.indexFromX(this.glowX);
        this.selectTab(target);
        this.suppressClickUntil = Date.now() + 250;
      }
      this.pressArmed = false;
      this.scrubbing = false;
      this.hoverIndex = -1;
    }
  }

  // 根据栏内 x 推算落在第几个按钮
  private indexFromX(x: number): number {
    if (this.barWidth <= 0) { return this.currentIndex; }
    const w = this.barWidth / this.tabs.length;
    const idx = Math.floor(x / w);
    return Math.min(this.tabs.length - 1, Math.max(0, idx));
  }

  private isActive(index: number): boolean {
    return this.scrubbing ? this.hoverIndex === index : this.currentIndex === index;
  }

  private clampGlow(x: number): number {
    if (this.barWidth <= 0) { return x; }
    return Math.min(this.barWidth, Math.max(0, x));
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
        this.FloatingTabBar()
      }
      .width('100%')
      .padding({ left: BAR_SIDE_MARGIN, right: BAR_SIDE_MARGIN })
      .margin({ bottom: BAR_BOTTOM_GAP + this.navBarHeight })
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.bg_primary'))
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.BOTTOM])
  }
}
