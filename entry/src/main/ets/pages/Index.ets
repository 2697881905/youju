// 大蓝书 主框架：iOS 26 液态玻璃质感悬浮底部导航栏
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
import { sensor } from '@kit.SensorServiceKit';

// 悬浮栏尺寸令牌（iOS 26 风格大圆角厚胶囊）
const BAR_HEIGHT: number = 62;
const BAR_RADIUS: number = 28;
const BAR_SIDE_MARGIN: number = 18;
const BAR_BOTTOM_GAP: number = 18;
// 选中项玻璃凸起胶囊圆角
const PILL_RADIUS: number = 18;

// 单个 Tab 定义
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
  @StorageLink('isDarkMode') @Watch('onThemeChange') isDark: boolean = false;
  // 状态栏高度（全屏布局后顶部内容需下移避让）
  @State statusBarHeight: number = 0;
  // 底部系统导航条高度（用于让悬浮栏避开手势条）
  @State navBarHeight: number = 0;

  // 玻璃质感 / 反射 / 流光 动态状态
  @State glassBg: string = '#FFFFFF80';
  @State glassBorder: string = '#FFFFFFA6';
  @State glassBlur: number = 30;
  @State glossAlpha: number = 0.5;
  @State shimmerAlpha: number = 0.3;
  @State shimmerOffset: number = -300;
  @State selectedBg: string = '#007AFF1F';
  @State barShadow: ShadowOptions = { radius: 20, color: '#00000033', offsetY: 10 };

  // 环境光强度比例（0 暗 ~ 1 亮），默认偏亮
  private ambientRatio: number = 0.6;
  // 光带宽度与悬浮栏宽度（用于流光位移计算）
  private shimmerWidth: number = 90;
  private barWidth: number = 360;
  // 组件存活标记，防止销毁后动画递归
  private alive: boolean = true;

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
    // 首启隐私协议弹窗：未同意则拦截初始化（同意后才继续登录态判断）
    if (!isPrivacyAgreed()) {
      this.showPrivacyDialog();
      return;
    }
    this.startInit();
  }

  aboutToDisappear(): void {
    this.alive = false;
    try {
      sensor.off(sensor.SensorId.AMBIENT_LIGHT);
    } catch (e) {
      // 忽略注销失败
    }
  }

  // 从 LoginPage 返回后（aboutToAppear 不再重跑）刷新未读红点 + 注册推送
  onPageShow(): void {
    if (getToken() !== '') {
      this.refreshUnread();
      ensurePushRegistration();
    }
  }

  // 窗口全屏布局：内容延伸到系统导航条之下让悬浮栏贴底，同时读取状态栏 / 导航条高度用于避让
  private async setupFullScreen(): Promise<void> {
    try {
      const ctx = this.getUIContext().getHostContext();
      if (!ctx) {
        this.initVisual();
        return;
      }
      const win = await window.getLastWindow(ctx);
      await win.setWindowLayoutFullScreen(true);
      const area = win.getWindowAvoidArea(window.AvoidAreaType.TYPE_SYSTEM);
      this.statusBarHeight = px2vp(area.topRect.height);
      this.navBarHeight = px2vp(area.bottomRect.height);
      AppStorage.setOrCreate<number>('statusBarHeight', this.statusBarHeight);
      AppStorage.setOrCreate<number>('navBarHeight', this.navBarHeight);
      const rect = win.getWindowProperties().windowRect;
      const screenW = px2vp(rect.width);
      this.barWidth = screenW - BAR_SIDE_MARGIN * 2;
      this.initVisual();
    } catch (e) {
      // 失败不阻断，使用默认视觉
      this.initVisual();
    }
  }

  // 视觉初始化：玻璃质感计算 + 流光动画 + 环境光订阅
  private initVisual(): void {
    this.recomputeGlass();
    this.startShimmer();
    this.subscribeAmbient();
  }

  // 登录态判断 + 未读拉取（隐私同意后或已同意时执行）
  private startInit(): void {
    // 无登录态时跳到登录页；登录成功后 router.back() 回此页
    if (getToken() === '') {
      this.getUIContext().getRouter().pushUrl({ url: 'pages/LoginPage' });
    } else {
      // 已登录则拉一次未读总数，驱动消息 Tab 红点；并注册华为推送 Token
      this.refreshUnread();
      ensurePushRegistration();
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

  // 拉取未读消息总数（通知 + 私信），写入 AppStorage，红点随之刷新
  private refreshUnread(): void {
    getUnreadCount()
      .then((res) => {
        this.unreadCount = res.count;
      })
      .catch(() => {
        // 失败不阻断
      });
    getDmUnreadCount()
      .then((res) => {
        this.dmUnread = res.count;
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

  // 点击底部 Tab：切换并广播激活态
  private selectTab(index: number): void {
    if (this.currentIndex === index) {
      return;
    }
    this.currentIndex = index;
    AppStorage.setOrCreate<number>('activeTab', index);
  }

  onThemeChange(): void {
    this.recomputeGlass();
  }

  // 将 0~1 的透明度转为两位十六进制（用于 8 位 hex 颜色）
  private hexAlpha(a: number): string {
    const v: number = Math.max(0, Math.min(255, Math.round(a * 255)));
    const s: string = v.toString(16);
    return s.length === 1 ? '0' + s : s;
  }

  // 根据深色模式 + 环境光强度，重算液态玻璃材质 / 光泽 / 流光参数
  private recomputeGlass(): void {
    const r: number = this.ambientRatio;
    if (this.isDark) {
      // 深色：更实一点的暗玻璃，边缘微亮，选中项冷蓝凸起
      this.glassBg = '#1C1C1E' + this.hexAlpha(0.5 + 0.25 * r);
      this.glassBorder = '#FFFFFF' + this.hexAlpha(0.18);
      this.selectedBg = '#78AAFF' + this.hexAlpha(0.22);
      this.barShadow = { radius: 18, color: '#000000A6', offsetY: 8 };
      this.glossAlpha = 0.14 + 0.18 * r;
      this.shimmerAlpha = 0.1 + 0.16 * r;
    } else {
      // 浅色：低不透明度白玻璃，强高光描边，选中项品牌蓝凸起
      this.glassBg = '#FFFFFF' + this.hexAlpha(0.3 + 0.28 * r);
      this.glassBorder = '#FFFFFF' + this.hexAlpha(0.65);
      this.selectedBg = '#007AFF' + this.hexAlpha(0.12);
      this.barShadow = { radius: 20, color: '#00000033', offsetY: 10 };
      this.glossAlpha = 0.32 + 0.34 * r;
      this.shimmerAlpha = 0.16 + 0.24 * r;
    }
    this.glassBlur = 22 + 16 * r;
  }

  // 环境光强度（lux）→ 0~1 比例，驱动玻璃通透度与光效强度
  private applyAmbient(lux: number): void {
    const clamped: number = Math.max(10, Math.min(2000, lux));
    this.ambientRatio = (clamped - 10) / (2000 - 10);
    this.recomputeGlass();
  }

  // 订阅华为环境光传感器，实现「沉浸光感视效」：环境越亮，玻璃越实、反光越强
  private subscribeAmbient(): void {
    try {
      sensor.on(sensor.SensorId.AMBIENT_LIGHT, (data: sensor.LightResponse): void => {
        const lux: number = data.intensity;
        this.applyAmbient(lux);
      });
    } catch (e) {
      // 传感器不可用则保持默认玻璃质感
    }
  }

  // 流光扫光动画：一条倾斜的白色光带在栏内循环横扫
  private startShimmer(): void {
    if (!this.alive) {
      return;
    }
    const start: number = -(this.barWidth / 2 + this.shimmerWidth);
    const end: number = this.barWidth / 2 + this.shimmerWidth;
    this.shimmerOffset = start;
    animateTo({ duration: 3600, curve: Curve.Linear, onFinish: (): void => {
      if (this.alive) {
        this.startShimmer();
      }
    } }, (): void => {
      this.shimmerOffset = end;
    });
  }

  // 底部内容需为悬浮栏预留的底部内边距
  private contentBottomReserve(): number {
    return BAR_HEIGHT + BAR_BOTTOM_GAP + this.navBarHeight;
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

  // 流光层：倾斜白色光带，循环横扫（被父级 clip 裁剪为圆角矩形）
  @Builder
  ShimmerLayer() {
    Row() {
    }
    .width(this.shimmerWidth)
    .height(BAR_HEIGHT * 2)
    .linearGradient({
      angle: 0,
      colors: [
        ['#FFFFFF00', 0.0],
        ['#FFFFFF' + this.hexAlpha(this.shimmerAlpha), 0.5],
        ['#FFFFFF00', 1.0]
      ]
    })
    .rotate({ angle: -18 })
    .align(Alignment.Center)
    .translate({ x: this.shimmerOffset })
    .opacity(this.shimmerAlpha > 0.02 ? 1 : 0)
  }

  // 顶部光泽层：上白下透明的柔和高光，模拟光线打在玻璃顶面
  @Builder
  GlossLayer() {
    Row() {
    }
    .width('100%')
    .height('58%')
    .linearGradient({
      angle: 90,
      colors: [
        ['#FFFFFF' + this.hexAlpha(this.glossAlpha), 0.0],
        ['#FFFFFF00', 1.0]
      ]
    })
    .align(Alignment.Top)
  }

  // 顶部高光描边（specular rim）：1.5px 横向高光，强化玻璃边缘反光
  @Builder
  TopHighlightLine() {
    Row() {
    }
    .width('100%')
    .height(1.5)
    .linearGradient({
      angle: 0,
      colors: [
        ['#FFFFFF00', 0.0],
        ['#FFFFFFFF', 0.5],
        ['#FFFFFF00', 1.0]
      ]
    })
    .align(Alignment.Top)
  }

  // 单个 Tab 内部：图标（仅图标带未读 Badge）+ 文字；选中态带玻璃凸起胶囊
  // 外层 Column 保留 layoutWeight(1) → 5 个按钮等宽等距
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
    .backgroundColor(index === this.currentIndex ? this.selectedBg : Color.Transparent)
    .border(index === this.currentIndex ? { width: 1, color: '#FFFFFFA6', style: BorderStyle.Solid } : undefined)
    .shadow(index === this.currentIndex
      ? { radius: 8, color: '#00000014', offsetY: 1 }
      : undefined)
    .animation({ duration: 220, curve: Curve.EaseOut })
    .onClick(() => {
      this.selectTab(index);
    })
  }

  // 悬浮液态玻璃底部栏主体
  @Builder
  FloatingTabBar() {
    Stack({ alignContent: Alignment.Center }) {
      // 顶部光泽
      this.GlossLayer()
      // 流光层（透出玻璃产生扫光）
      this.ShimmerLayer()
      // 顶部高光描边（specular rim）
      this.TopHighlightLine()
      // Tab 项行：等宽均分
      Row() {
        ForEach(this.tabs, (tab: TabDef, i: number) => {
          this.TabInner(tab, i);
        }, (tab: TabDef) => tab.key)
      }
      .width('100%')
      .height('100%')
      .justifyContent(FlexAlign.SpaceEvenly)
      .alignItems(VerticalAlign.Center)
    }
    .width('100%')
    .height(BAR_HEIGHT)
    .borderRadius(BAR_RADIUS)
    .backdropBlur(this.glassBlur)
    .backgroundColor(this.glassBg)
    .border({ width: 1.5, color: this.glassBorder, style: BorderStyle.Solid })
    .shadow(this.barShadow)
    .clip(true)
  }

  build() {
    Stack({ alignContent: Alignment.Bottom }) {
      // 内容层：5 个页面全部挂载，靠 visibility 控制显示，保留各自状态
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
      .padding({ top: this.statusBarHeight, bottom: this.contentBottomReserve() })

      // 悬浮液态玻璃底部栏（底部居中、左右留白，避开系统导航条）
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
