// 大蓝书 主框架：悬浮底部导航栏（单层磨砂玻璃：backdropBlur + 中性半透填充，无伪装分层/无环境光）
// Tab：首页 / 圈子 / 发布 / 消息 / 我的；帖子详情经 router 单独跳转（pages/DetailPage）
import { HomeTab } from '../components/HomeTab';
import { CircleTab } from '../components/CircleTab';
import { PublishPage } from './PublishPage';
import { MessagePage } from './MessagePage';
import { ProfilePage } from './ProfilePage';
import { initAuthStorage, getToken, setPrivacyAgreed, isPrivacyAgreed } from '../utils/auth';
import { getUnreadCount, getDmUnreadCount } from '../services/api';
import { ensurePushRegistration } from '../utils/huaweiPush';
import { common } from '@kit.AbilityKit';
import { window } from '@kit.ArkUI';

// 悬浮栏尺寸令牌
const BAR_HEIGHT: number = 62;
const BAR_RADIUS: number = 28;
const BAR_SIDE_MARGIN: number = 18;
const BAR_BOTTOM_GAP: number = 18;
const PILL_RADIUS: number = 18;

interface TabDef {
  key: string;
  title: string;
}

@Entry
@Component
struct Index {
  @State currentIndex: number = 0;
  @StorageLink('unreadMessageCount') unreadCount: number = 0;
  @StorageLink('unreadDmCount') dmUnread: number = 0;
  @StorageLink('tabSwitchSignal') @Watch('onTabSwitch') tabSwitchSignal: number = 0;
  @StorageLink('isDarkMode') isDark: boolean = false;
  @State statusBarHeight: number = 0;
  @State navBarHeight: number = 0;

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
    }
  }

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

  // 底栏玻璃填充：真正通透（浅=淡白雾/深=淡黑雾），只留极淡中性+模糊，不加任何发黄色，背后内容如实透出
  private glassFill(): string {
    return this.isDark ? '#00000033' : '#FFFFFF33';
  }
  // 底栏描边（极细高光边，透明玻璃的轻边）
  private barBorderColor(): string {
    return this.isDark ? '#FFFFFF1A' : '#FFFFFF40';
  }
  // 选中项胶囊背景（品牌蓝低透明）
  private pillBgColor(): string {
    return this.isDark ? '#78AAFF33' : '#007AFF1A';
  }

  @Builder
  TabInner(tab: TabDef, index: number) {
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
            .fillColor(index === this.currentIndex ? $r('app.color.brand_primary') : $r('app.color.text_secondary'))
        }
      } else {
        Image(this.navIconRes(index))
          .width(26)
          .height(26)
          .fillColor(index === this.currentIndex ? $r('app.color.brand_primary') : $r('app.color.text_secondary'))
      }
      Text(tab.title)
        .fontSize(10)
        .fontColor(index === this.currentIndex ? $r('app.color.brand_primary') : $r('app.color.text_secondary'))
    }
    .layoutWeight(1)
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
    .borderRadius(PILL_RADIUS)
    .backgroundColor(index === this.currentIndex ? this.pillBgColor() : Color.Transparent)
    .animation({ duration: 200, curve: Curve.EaseOut })
    .onClick(() => {
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
    .backdropBlur(22)
    .backgroundColor(this.glassFill())
    .border({ width: 1, color: this.barBorderColor(), style: BorderStyle.Solid })
    .shadow({ radius: 20, color: this.isDark ? '#000000A6' : '#00000024', offsetY: 10 })
    .clip(true)
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
