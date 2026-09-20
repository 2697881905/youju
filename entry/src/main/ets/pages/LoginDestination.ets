// 登录欢迎「Navigation 壳」：供 Navigation 内跳入登录页使用。
// 登录页无必需模块级 intent（内部私隐/协议仍走 router），故 onReady 无需处理。
import { LoginView } from './LoginView';
import { getMainNavStack } from '../utils/navigationTransition';
import { ColorTokens } from '../design/tokens/color';

@Component
export struct LoginDestination {
  build() {
    NavDestination() {
      LoginView({
        navMode: true,
        onBack: (): void => {
          const nav: NavPathStack | null = getMainNavStack();
          if (nav !== null) {
            nav.pop();
          }
        },
      })
    }
    .hideTitleBar(true)
    .backgroundColor(ColorTokens.canvas)
  }
}