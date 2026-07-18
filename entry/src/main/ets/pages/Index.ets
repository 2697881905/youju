// 大蓝书 主框架：底部 TabBar 壳
// Tab：首页 / 发布 / 消息 / 我的；帖子详情经 router 单独跳转（pages/DetailPage）
import { HomeTab } from '../components/HomeTab';
import { CircleTab } from '../components/CircleTab';
import { PublishPage } from './PublishPage';
import { MessagePage } from './MessagePage';
import { ProfilePage } from './ProfilePage';
import { initAuthStorage, getToken } from '../utils/auth';
import { router } from '@kit.ArkUI';

@Entry
@Component
struct Index {
  @State currentIndex: number = 0;

  aboutToAppear(): void {
    initAuthStorage();
    // 无登录态时跳到登录页；登录成功后 router.back() 回此页
    if (getToken() === '') {
      router.pushUrl({ url: 'pages/LoginPage' });
    }
  }

  @Builder
  tabItem(title: string, icon: string, index: number) {
    Column({ space: 2 }) {
      if (index === 2) {
        // 发布：纯图标，无文字，加大尺寸
        Text(icon)
          .fontSize(28)
      } else {
        Text(icon)
          .fontSize(20)
        Text(title)
          .fontSize(10)
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
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.bg_primary'))
  }
}
