// 帖子详情「Navigation 壳」：承接首页卡片导航。
//
// 一镜到底按官方 transitions-collection 范式实现——**本页自身从卡片帧缩放展开**
// （scale/translate/clip/position/radius），卡片截图顶住首帧、真内容随后淡入。
// 变形目标就是真页面本身，因此不存在旧方案「飞完再被真内容顶一下」的二次对位。
//
// 与官方一致的三段式分工：源页（HomeTab）截图+量帧+传参 → 本页 onReady 自注册 →
// 框架（Index.customNavContentTransition）按 navDestinationId 查表转交。
// 参数经 pushPathByName('PostDetail', PostDetailNavParams) 传入。
import { hilog } from '@kit.PerformanceAnalysisKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { image } from '@kit.ImageKit';
import { PostDetailView, DETAIL_HERO_ID, DETAIL_HERO_SHELL_ID } from './PostDetailView';
import { PostDetailIntent, openPostDetail } from '../utils/nav';
import { getMainNavStack, PostDetailNavParams, UserProfileNavParams } from '../utils/navigationTransition';
import { CustomTransition } from '../utils/longTake/customNavigationUtils';
import { LongTakeAnimationProperties, LongTakeParams } from '../utils/longTake/longTakeAnimationProperties';
import { ColorTokens } from '../design/tokens/color';
import { consumeOverlayBack } from '../utils/overlayBackGuard';

const TAG: string = 'PostDetailDest';
// 转场超时：超时由框架兜底结束，避免动画异常时页面卡住不放行
const TRANSITION_TIMEOUT_MS: number = 2000;
// 详情页里充当「卡片对应节点」的组件 id：整页缩放到「该节点宽 == 卡片宽」再展开。
// 主 id = 真实内容里的媒体 Stack；回退 id = 加载壳里的占位（数据异步时先量到的是它），
// 两个 id 不能同名 —— 同名会被编译器判 duplicate id（发布构建实测报 WARN）。
const PAGE_ROOT_ID: string = 'detailPageRoot';

@Component
export struct PostDetailDestination {
  // 一镜到底可动画属性（@Observed：字段变化直接驱动本页重绘）
  @State longTakeAnimationProperties: LongTakeAnimationProperties = new LongTakeAnimationProperties();
  // 卡片截图：作为首帧顶替真内容，真内容接管后淡出
  @State snapShotImage: image.PixelMap | undefined = undefined;
  private takeParams: LongTakeParams = new LongTakeParams();
  private pageId: string = '';
  private registered: boolean = false;
  // 窗口尺寸变化的基准（vp）：变化后已缓存的初值作废，退回系统默认转场
  private rootWidth_vp: number = 0;
  private rootHeight_vp: number = 0;

  private back(): void {
    // 页内覆盖层（图片查看器 / 分享卡预览 / 数据面板）打开时，页内返回按钮先关覆盖层，
    // 与系统返回手势保持一致（系统手势的拦截见下面的 onBackPressed）
    if (consumeOverlayBack()) {
      return;
    }
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

  /* 注册本页的一镜到底动画（官方：目的地页自注册，key = navDestinationId）
   * 官方做法是整段 try/catch：注册/量测出异常时落回终态，绝不让页面停在半途。
   */
  private tryRegisterCustomTransition(): void {
    if (this.registered || this.pageId.length === 0) {
      return;
    }
    this.registered = true;
    try {
      this.longTakeAnimationProperties.init(this.takeParams.cardRect,
        DETAIL_HERO_ID, DETAIL_HERO_SHELL_ID, PAGE_ROOT_ID, this.takeParams.cardId);
      CustomTransition.getInstance().registerNavParam(this.pageId, TRANSITION_TIMEOUT_MS,
        (transitionProxy: NavigationTransitionProxy): void => {
          // 初值必须在动画开始这一刻量：此时本页已完成布局
          this.longTakeAnimationProperties.doAnimation(this.getUIContext(), transitionProxy);
        });
    } catch (error) {
      const err = error as BusinessError;
      hilog.error(0x0000, TAG, `tryRegisterCustomTransition failed. code=${err.code}, message=${err.message}`);
      this.longTakeAnimationProperties.setFinalStatus();
    }
  }

  // 窗口尺寸变化（旋转/折叠/分屏）→ 缓存的初值失效：注销本页转场，退回系统默认
  private onWindowSizeChanged(width_vp: number, height_vp: number): void {
    if (this.rootWidth_vp <= 0) {
      this.rootWidth_vp = width_vp;
      this.rootHeight_vp = height_vp;
      return;
    }
    if (Math.abs(width_vp - this.rootWidth_vp) < 1 && Math.abs(height_vp - this.rootHeight_vp) < 1) {
      return;
    }
    this.rootWidth_vp = width_vp;
    this.rootHeight_vp = height_vp;
    hilog.info(0x0000, TAG, `window size changed, fall back to default transition: ${this.pageId}`);
    CustomTransition.getInstance().unregisterNavParam(this.pageId);
  }

  build() {
    NavDestination() {
      // Stack 的 alignContent 必须是 TopStart：否则截图与内容会随高度变化被重新定位（官方注释）
      Stack({ alignContent: Alignment.TopStart }) {
        Stack({ alignContent: Alignment.TopStart }) {
          // 卡片截图：落在「对应节点」位置，动画期间由 scale/position 带着一起变形
          if (this.snapShotImage !== undefined) {
            Image(this.snapShotImage)
              .width('100%')
              .objectFit(ImageFit.Auto)
              .syncLoad(true)
              .opacity(this.longTakeAnimationProperties.snapShotOpacity)
              .position({
                x: this.longTakeAnimationProperties.snapShotPositionX,
                y: this.longTakeAnimationProperties.snapShotPositionY
              })
          }

          // 真内容：进场 0→1，返回 1→0
          PostDetailView({
            navMode: true,
            onBack: (): void => { this.back(); },
            onOpenProfile: (userId: number): void => { this.openProfile(userId); },
            // 真媒体首帧就绪 → 淡出卡片截图（交接，不是"闪一下"）
            onHeroReady: (): void => {
              this.longTakeAnimationProperties.onHeroReady(this.getUIContext());
            },
          })
            .size({ width: '100%', height: '100%' })
            .opacity(this.longTakeAnimationProperties.postPageOpacity)
        }
        .width('100%')
        .id(PAGE_ROOT_ID)
        // 把「对应节点」挪到卡片位置
        .position({
          x: this.longTakeAnimationProperties.positionXValue,
          y: this.longTakeAnimationProperties.positionYValue
        })
      }
      .scale({
        x: this.longTakeAnimationProperties.scaleValue,
        y: this.longTakeAnimationProperties.scaleValue
      })
      .translate({
        x: this.longTakeAnimationProperties.translateX,
        y: this.longTakeAnimationProperties.translateY
      })
      .width(this.longTakeAnimationProperties.clipWidth)
      .height(this.longTakeAnimationProperties.clipHeight)
      .borderRadius(this.longTakeAnimationProperties.radius)
      .clip(true)
      .backgroundColor(ColorTokens.canvas)
      .expandSafeArea([SafeAreaType.SYSTEM])
      .onAreaChange((_oldValue: Area, newValue: Area): void => {
        this.onWindowSizeChanged(newValue.width as number, newValue.height as number);
      })
    }
    .hideTitleBar(true)
    .backgroundColor(ColorTokens.canvas)
    // 系统返回手势/返回键：页内覆盖层打开时先关覆盖层（返回 true = 已处理，不执行默认 pop）。
    // Navigation 壳取代了 router 壳的 onBackPress —— 两者都要接，见 DetailPage.ets。
    .onBackPressed((): boolean => consumeOverlayBack())
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
        this.snapShotImage = take.snapshot;
        this.pageId = ctx.navDestinationId !== undefined ? ctx.navDestinationId : '';
        this.tryRegisterCustomTransition();
      }
    })
    .onDisAppear(() => {
      CustomTransition.getInstance().unregisterNavParam(this.pageId);
    })
  }
}
