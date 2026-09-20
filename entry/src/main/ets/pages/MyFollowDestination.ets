// 我的关注/粉丝「Navigation 壳」：跳转方在 pushPathByName('MyFollow', ...) 前已写模块级
// intent openFollowList(...)，视图（MyFollowView）在 aboutToAppear 里 takeFollowListIntent() 读取，
// 故 onReady 无需做任何处理。
import { MyFollowView } from './MyFollowView';
import { getMainNavStack } from '../utils/navigationTransition';
import { ColorTokens } from '../design/tokens/color';

@Component
export struct MyFollowDestination {
  private back(): void {
    const nav: NavPathStack | null = getMainNavStack();
    if (nav !== null) {
      nav.pop();
    }
  }

  build() {
    NavDestination() {
      MyFollowView({ navMode: true, onBack: (): void => { this.back(); } })
    }
    .hideTitleBar(true)
    .backgroundColor(ColorTokens.canvas)
  }
}