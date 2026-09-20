import { UserProfileView } from './UserProfileView';
import { getMainNavStack, UserProfileNavParams } from '../utils/navigationTransition';
import { openUserProfile } from '../utils/nav';
import { ColorTokens } from '../design/tokens/color';
@Component
export struct UserProfileDestination {
  private back(): void {
    const s = getMainNavStack();
    if (s !== null) { s.pop(); }
  }
  build() {
    NavDestination() {
      UserProfileView({
        navMode: true,
        onBack: (): void => { this.back(); },
      })
    }
    .hideTitleBar(true)
    .backgroundColor(ColorTokens.canvas)
    .onReady((ctx: NavDestinationContext) => {
      const param = ctx.pathInfo.param as UserProfileNavParams;
      if (param && typeof param.userId === 'number') {
        openUserProfile(param.userId);
      }
    })
  }
}