// 圈子详情「Navigation 壳」：承接 Navigation 导航进入圈子详情。
// 跳转方在 pushPathByName('CircleDetail', ...) 前已写模块级 intent openCircleDetail(name)，
// 视图（CircleDetailView）在 aboutToAppear 里 takeCircleDetailName() 读取，故 onReady 无需做任何处理。
import { CircleDetailView } from './CircleDetailView';
import { getMainNavStack } from '../utils/navigationTransition';
import { ColorTokens } from '../design/tokens/color';

@Component
export struct CircleDetailDestination {
  private back(): void {
    const nav: NavPathStack | null = getMainNavStack();
    if (nav !== null) {
      nav.pop();
    }
  }

  build() {
    NavDestination() {
      CircleDetailView({ navMode: true, onBack: (): void => { this.back(); } })
    }
    .hideTitleBar(true)
    .backgroundColor(ColorTokens.canvas)
  }
}