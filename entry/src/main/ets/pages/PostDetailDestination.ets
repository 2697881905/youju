// 帖子详情「Navigation 壳」：承接首页卡片导航（已按需求移除所有转场动画，直接切换）。
// 参数经 NavPathStack.pushPathByName('PostDetail', {...}) 传入，onReady 中写模块级 intent 供 PostDetailView 消费。
import { PostDetailView } from './PostDetailView';
import { PostDetailIntent, openPostDetail } from '../utils/nav';
import { getMainNavStack, PostDetailNavParams, UserProfileNavParams } from '../utils/navigationTransition';
import { ColorTokens } from '../design/tokens/color';

@Component
export struct PostDetailDestination {
  private back(): void {
    const nav: NavPathStack | null = getMainNavStack();
    if (nav !== null) {
      nav.pop(false);
    }
  }

  private openProfile(userId: number): void {
    const nav: NavPathStack | null = getMainNavStack();
    if (nav !== null) {
      const p: UserProfileNavParams = new UserProfileNavParams();
      p.userId = userId;
      nav.pushPathByName('UserProfile', p);
    }
  }

  build() {
    NavDestination() {
      Stack() {
        PostDetailView({
          navMode: true,
          onBack: (): void => { this.back(); },
          onOpenProfile: (userId: number): void => { this.openProfile(userId); },
        })
      }
      .width('100%')
      .height('100%')
    }
    .hideTitleBar(true)
    .backgroundColor(ColorTokens.canvas)
    .onReady((ctx: NavDestinationContext) => {
      const param: PostDetailNavParams = ctx.pathInfo.param as PostDetailNavParams;
      if (param === undefined || param === null || typeof param.postId !== 'number') {
        return;
      }
      openPostDetail(String(param.postId), (param.intent as PostDetailIntent | null) ?? undefined);
    })
  }
}