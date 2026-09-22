// 帖子详情「Navigation 壳」：承接首页卡片导航（已按需求移除所有转场动画，直接切换）。
// 参数经 NavPathStack.pushPathByName('PostDetail', {...}) 传入，onReady 中写模块级 intent 供 PostDetailView 消费。
import { PostDetailView } from './PostDetailView';
import { PostDetailIntent, openPostDetail } from '../utils/nav';
import { getMainNavStack, PostDetailNavParams, UserProfileNavParams, CardRect } from '../utils/navigationTransition';
import { CardSnapshotLayer } from '../components/CardSnapshotLayer';
import { ColorTokens } from '../design/tokens/color';

@Component
export struct PostDetailDestination {
  // 一镜到底飞行态：onReady 收到起点帧后置真，飞行结束（onDone）置假
  @State flying: boolean = false;
  @State flySrc: CardRect = { left: 0, top: 0, width: 0, height: 0 };
  @State flyCover: string = '';
  @State flyAspect: number = 0.75;
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
          mediaCovered: this.flying,
          onBack: (): void => { this.back(); },
          onOpenProfile: (userId: number): void => { this.openProfile(userId); },
        })
        if (this.flying && this.flyCover.length > 0) {
          CardSnapshotLayer({
            coverUrl: this.flyCover,
            src: this.flySrc,
            aspect: this.flyAspect,
            targetId: 'detailHeroMedia',
            onDone: (): void => { this.flying = false; },
          })
        }
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
      const intent: PostDetailIntent | null = (param.intent as PostDetailIntent | null) ?? null;
      openPostDetail(String(param.postId), intent);
      if (param.src !== null && param.src.width > 0 && intent !== null && intent.cover.length > 0) {
        this.flySrc = param.src;
        this.flyCover = intent.cover;
        this.flyAspect = intent.aspect > 0 ? intent.aspect : 0.75;
        this.flying = true;
      }
      // undefined);
    })
  }
}