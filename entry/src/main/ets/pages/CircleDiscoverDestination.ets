// 发现圈子「Navigation 壳」：承接 pushPathByName('CircleDiscover', CircleDiscoverNavParams)。
// 页面自带顶栏（返回 / 标题 / 搜索），故 hideTitleBar(true)；返回走主栈 pop。
import { CircleDiscoverPage } from './CircleDiscoverPage';
import { getMainNavStack } from '../utils/navigationTransition';
import { ColorTokens } from '../design/tokens/color';

@Component
export struct CircleDiscoverDestination {
  // 由 Index.pageMap 从 CircleDiscoverNavParams 注入：0=发现 1=已加入
  @Prop initialTab: number = 0;

  private back(): void {
    const nav: NavPathStack | null = getMainNavStack();
    if (nav !== null) {
      nav.pop();
    }
  }

  build() {
    NavDestination() {
      CircleDiscoverPage({
        initialTab: this.initialTab,
        onBack: (): void => { this.back(); },
      })
    }
    .hideTitleBar(true)
    .backgroundColor(ColorTokens.canvas)
  }
}
