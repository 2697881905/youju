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

@Entry
@Component
struct Index {
  @State currentIndex: number = 0;
  @StorageLink('unreadMessageCount') unreadCount: number = 0;
  @StorageLink('tabSwitchSignal') @Watch('onTabSwitch') tabSwitchSignal: number = 0;

  aboutToAppear(): void {
    initAuthStorage();
    // 首启隐私协议弹窗：未同意则拦截初始化（同意后才继续登录态判断）
    if (!isPrivacyAgreed()) {
      this.showPrivacyDialog();
      return;
    }
    this.startInit();
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
    }
  }

  @Builder
  tabItem(title: string, icon: string, index: number) {
    Column({ space: 2 }) {
      if (index === 2) {
        // 发布：纯图标，无文字，加大尺寸
        Text(icon)
          .fontSize(28)
      } else if (index === 3) {
        // 消息：纯文字 + 红点（有未读时显示，红点为功能提示非图标）
        Badge({
          count: this.unreadCount,
          style: { badgeColor: $r('app.color.semantic_red') },
          position: BadgePosition.RightTop,
        }) {
          Text(title)
            .fontSize(14)
            .fontColor(this.currentIndex === index ? $r('app.color.brand_primary') : $r('app.color.text_secondary'))
        }
      } else {
        // 首页 / 圈子 / 我的：纯文字（去掉图标）
        Text(title)
          .fontSize(14)
          .fontColor(this.currentIndex === index ? $r('app.color.brand_primary') : $r('app.color.text_secondary'))
      }
    }
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
    .height('100%')
    .width('100%')
  }

  build() {
    Tabs({ barPosition: BarPosition.End, index: this.currentIndex }) {
      TabContent() {
        HomeTab()
      }
      .tabBar(this.tabItem('首页', '🏠', 0))

      TabContent() {
        CircleTab()
      }
      .tabBar(this.tabItem('圈子', '⭕', 1))

      TabContent() {
        PublishPage()
      }
      .tabBar(this.tabItem('发布', '➕', 2))

      TabContent() {
        MessagePage()
      }
      .tabBar(this.tabItem('消息', '🔔', 3))

      TabContent() {
        ProfilePage()
      }
      .tabBar(this.tabItem('我的', '👤', 4))
    }
    .scrollable(false)
    .barHeight(56)
    .barMode(BarMode.Fixed)
    .onChange((index: number) => {
      this.currentIndex = index;
    })
    .animationDuration(250)
    .width('100%')
    .height('100%')
    .barBackgroundBlurStyle(BlurStyle.COMPONENT_ULTRA_THICK)
    .barBackgroundColor('rgba(0,0,0,0.55)')
    .backgroundColor($r('app.color.bg_primary'))
  }
}
