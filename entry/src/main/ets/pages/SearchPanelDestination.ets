// 搜索页「Navigation 壳」：首页搜索按钮一镜到底的落点。
//
// 与 PostDetailDestination 同范式：**本页自身从按钮帧缩放展开**
// （scale/translate/clip/position/radius），自定义转场由本页 onReady 自注册、
// Index.customNavContentTransition 按 navDestinationId 查表转交。
// 参数经 pushPathByName('SearchPanel', LongTakeParams) 传入。
//
// 与 PostDetail 的两点差异：
//   1) 无截图层——搜索面板标题栏（搜索框）是同步内容，展开首帧即真实页面，
//      不存在 PostDetail「详情数据异步、需截图顶住首帧」的问题；
//   2) 「对应节点」= 页面根本身（宽 = 窗宽，满足展开公式的前提），
//      无需单独的 hero id 与回退 id。
import { hilog } from '@kit.PerformanceAnalysisKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { SearchPanel } from '../components/SearchPanel';
import { openSearch } from '../utils/nav';
import { recordSearchHistory } from '../services/api';
import { getMainNavStack } from '../utils/navigationTransition';
import { CustomTransition } from '../utils/longTake/customNavigationUtils';
import { LongTakeAnimationProperties, LongTakeParams } from '../utils/longTake/longTakeAnimationProperties';
import { ColorTokens } from '../design/tokens/color';

const TAG: string = 'SearchPanelDest';
// 转场超时：超时由框架兜底结束，避免动画异常时页面卡住不放行
const TRANSITION_TIMEOUT_MS: number = 2000;
// 页面根组件 id：一镜到底量测的「对应节点」（整页从按钮帧展开到该节点满幅）
const PAGE_ROOT_ID: string = 'searchPanelRoot';

@Component
export struct SearchPanelDestination {
  // 一镜到底可动画属性（@Observed：字段变化直接驱动本页重绘）
  @State longTakeAnimationProperties: LongTakeAnimationProperties = new LongTakeAnimationProperties();
  private takeParams: LongTakeParams = new LongTakeParams();
  private pageId: string = '';
  private registered: boolean = false;
  // 窗口尺寸变化的基准（vp）：变化后已缓存的初值作废，退回系统默认转场
  private rootWidth_vp: number = 0;
  private rootHeight_vp: number = 0;

  private back(): void {
    const nav: NavPathStack | null = getMainNavStack();
    if (nav !== null) {
      nav.pop();
    }
  }

  // 关键词进结果页：结果页沿用既有独立 router 页。
  // ⚠️ 必须用 pushUrl 而非 replaceUrl——本页是 NavDestination，不在 router 页栈里，
  // replace 的对象是唯一的 router 页（Index），会把整个应用主框架替换掉（返回即退出）。
  private openResults(keyword: string): void {
    openSearch(keyword);
    // fire-and-forget：记录搜索历史，失败不阻断
    recordSearchHistory(keyword).catch((): void => {});
    this.getUIContext().getRouter().pushUrl({ url: 'pages/SearchResultPage' });
  }

  /* 注册本页的一镜到底动画（官方：目的地页自注册，key = navDestinationId）
   * 官方做法是整段 try/catch：注册/量测出异常时落回终态，绝不让页面停在半途。
   * 「对应节点」= 页面根本身（宽 = 窗宽），mediaRadius 传 0（无截图层，不参与圆角交接）。
   */
  private tryRegisterCustomTransition(): void {
    if (this.registered || this.pageId.length === 0) {
      return;
    }
    this.registered = true;
    try {
      this.longTakeAnimationProperties.init(this.takeParams.cardRect,
        PAGE_ROOT_ID, '', PAGE_ROOT_ID, this.takeParams.cardId,
        this.takeParams.cardRadius, 0);
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
      // 飞行窗口：clip/scale/translate 把整页从按钮帧展开到满幅
      Stack({ alignContent: Alignment.TopStart }) {
        Column() {
          SearchPanel({
            onKeywordSelect: (kw: string): void => { this.openResults(kw); },
            onCancel: (): void => { this.back(); },
          })
        }
        .width('100%')
        .height('100%')
        .alignItems(HorizontalAlign.Start)
      }
      .width(this.longTakeAnimationProperties.clipWidth)
      .height(this.longTakeAnimationProperties.clipHeight)
      .scale({
        x: this.longTakeAnimationProperties.scaleValue,
        y: this.longTakeAnimationProperties.scaleValue
      })
      .translate({
        x: this.longTakeAnimationProperties.translateX,
        y: this.longTakeAnimationProperties.translateY
      })
      .borderRadius(this.longTakeAnimationProperties.radius)
      .clip(true)
      .backgroundColor(ColorTokens.canvas)
      // 页面延伸进状态栏：搜索面板标题栏自行避让（statusBarHeight 手动下移）
      .expandSafeArea([SafeAreaType.SYSTEM])
      .id(PAGE_ROOT_ID)
      .onAreaChange((_oldValue: Area, newValue: Area): void => {
        this.onWindowSizeChanged(newValue.width as number, newValue.height as number);
      })
    }
    .hideTitleBar(true)
    .backgroundColor(ColorTokens.canvas)
    .onBackPressed((): boolean => {
      this.back();
      return true;
    })
    .onReady((ctx: NavDestinationContext) => {
      const param: LongTakeParams | null = ctx.pathInfo.param as LongTakeParams | null;
      // 无有效按钮帧（量不到/兜底路径）：不注册转场，页面按终态直接呈现（功能完整）
      if (param === null || param === undefined || param.cardRect.width <= 0) {
        return;
      }
      this.takeParams = param;
      this.pageId = ctx.navDestinationId !== undefined ? ctx.navDestinationId : '';
      this.tryRegisterCustomTransition();
    })
    .onDisAppear(() => {
      CustomTransition.getInstance().unregisterNavParam(this.pageId);
    })
  }
}
