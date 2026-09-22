// 帖子详情「Navigation 壳」：承接首页卡片导航。
//
// 一镜到底按官方 transitions-collection 范式实现——**本页自身从卡片帧缩放展开**
// （scale/translate/clip/position/radius），卡片截图顶住首帧、真内容随后淡入。
// 目标是真页面本身，因此不存在旧方案「飞完再被真内容顶一下」的二次对位。
// 参数经 pushPathByName('PostDetail', PostDetailNavParams) 传入，onReady 里注册本页的转场动画。
import { display } from '@kit.ArkUI';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { image } from '@kit.ImageKit';
import { PostDetailView } from './PostDetailView';
import { PostDetailIntent, openPostDetail } from '../utils/nav';
import { getMainNavStack, PostDetailNavParams, UserProfileNavParams } from '../utils/navigationTransition';
import { LongTakeAnim, LongTakeParams, LongTakeTransition } from '../utils/longTakeTransition';
import { ColorTokens } from '../design/tokens/color';

const TAG: string = 'PostDetailDest';
// 详情页里充当「卡片对应节点」的组件 id：整页缩放到「该节点宽 == 卡片宽」再展开
const HERO_ID: string = 'detailHeroMedia';
// 页面根的 id：用来量出「页面内容原点」的窗口位置。官方直接用节点的窗口坐标做初值，
// 隐含「页面原点 == 窗口原点」；这里显式量一下，避免因状态栏避让差异整体偏移。
const PAGE_ROOT_ID: string = 'detailPageRoot';

@Component
export struct PostDetailDestination {
  // 一镜到底可动画属性（@Observed：字段变化直接驱动本页重绘）
  @State anim: LongTakeAnim = new LongTakeAnim();
  // 卡片截图：作为首帧顶替真内容，真内容淡入后淡出
  @State snapShot: image.PixelMap | undefined = undefined;
  private takeParams: LongTakeParams = new LongTakeParams();
  private pageId: string = '';
  private registered: boolean = false;

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

  // 注册本页的一镜到底动画（官方：目的地页自注册，key = navDestinationId）
  private registerTransition(): void {
    if (this.registered || this.pageId.length === 0) {
      return;
    }
    this.registered = true;
    this.anim.init(this.takeParams.cardRect);
    LongTakeTransition.getInstance().register(this.pageId, 2000,
      (proxy: NavigationTransitionProxy): void => {
        const ui: UIContext = this.getUIContext();
        const winWpx: number = display.getDefaultDisplaySync().width;
        // 初值必须在动画开始这一刻量：此时本页已完成布局
        this.anim.initParams(ui, HERO_ID, PAGE_ROOT_ID, winWpx);
        if (LongTakeTransition.getInstance().operation === NavigationOperation.PUSH) {
          this.anim.doEnter(ui, proxy);
        } else {
          this.anim.doBack(ui, proxy);
        }
      });
    hilog.info(0x0000, TAG, 'transition registered: %{public}s', this.pageId);
  }

  build() {
    NavDestination() {
      // Stack 的 alignContent 必须是 TopStart：否则截图与内容会随高度变化被重新定位（官方注释）
      Stack({ alignContent: Alignment.TopStart }) {
        Stack({ alignContent: Alignment.TopStart }) {
          // 卡片截图：落在「对应节点」位置，动画期间由 scale/position 带着一起变形
          if (this.snapShot !== undefined) {
            Image(this.snapShot)
              .width('100%')
              .objectFit(ImageFit.Auto)
              .syncLoad(true)
              .opacity(this.anim.snapOpacity)
              .position({ x: this.anim.snapX, y: this.anim.snapY })
          }

          // 真内容：进场 0→1，返回 1→0
          PostDetailView({
            navMode: true,
            onBack: (): void => { this.back(); },
            onOpenProfile: (userId: number): void => { this.openProfile(userId); },
            // 真媒体首帧就绪 → 淡出卡片截图（交接，不是"闪一下"）
            onHeroReady: (): void => { this.anim.onHeroReady(this.getUIContext()); },
          })
            .width('100%')
            .height('100%')
            .opacity(this.anim.contentOpacity)
        }
        .width('100%')
        // 把「对应节点」挪到卡片位置
        .position({ x: this.anim.posX, y: this.anim.posY })
        .id(PAGE_ROOT_ID)
      }
      .scale({ x: this.anim.scale, y: this.anim.scale })
      .translate({ x: this.anim.tx, y: this.anim.ty })
      .width(this.anim.clipWidth)
      .height(this.anim.clipHeight)
      .borderRadius(this.anim.radius)
      .clip(true)
      .backgroundColor(ColorTokens.canvas)
      .expandSafeArea([SafeAreaType.SYSTEM])
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
      const take: LongTakeParams | null = (param.longTake as LongTakeParams | null) ?? null;
      if (take !== null && take.cardRect.width > 0) {
        this.takeParams = take;
        this.snapShot = take.snapshot;
        this.pageId = ctx.navDestinationId !== undefined ? ctx.navDestinationId : '';
        this.registerTransition();
      }
    })
    .onDisAppear(() => {
      LongTakeTransition.getInstance().unregister(this.pageId);
    })
  }
}
