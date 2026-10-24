// 帖子关键词搜索结果页：顶栏(官方返回键玻璃珠+原生搜索框+结果计数/排序分段行) + 首页同款双列
// 卡片列表 + 三态(加载/空/失败)。
// 数据来源：searchPosts（services/api.ets，复用 /v1/posts 端点）
// 列表与废纸篓 / 草稿箱共用 ManagedPostFeed —— 双列布局、卡片样式、入场错峰过渡同一出处
//
// 顶栏已迁 HdsNavigation（配方见基准 §7.6.31）：返回键走官方 backIcon，栏接沉浸光感材质；
// 两行结构映射成 stackBuilder（工具栏）+ bottomBuilder（计数/分段行）。

import { Post } from '../models/types';
import { searchPosts, trackPostEvent } from '../services/api';
import { ManagedPostFeed } from '../components/ManagedPostFeed';
import { openPostDetail, takeSearchKeyword } from '../utils/nav';
import { safeShowToast } from '../utils/toast';
import { buildPageTransition } from '../utils/styles';
import { resolveActionIcon } from '../utils/actionIcons';
import { GRID_GAP, GRID_PADDING } from '../utils/cardTokens';
import { EmptyState } from '../design/components/EmptyState';
import { SegmentedItem } from '../design/components/SegmentedControl';
import { SegmentedControl } from '../design/components/SegmentedControl';
import { isSystemMaterialActive, FloatingTopButtonMaterialModifier } from '../utils/immersiveMaterial';
import { Skeleton } from '../design/motion/Skeleton';
import { ColorTokens } from '../design/tokens/color';
import { RadiusTokens } from '../design/tokens/radius';
import { LayoutTokens, SpaceTokens } from '../design/tokens/space';
import { TypeTokens } from '../design/tokens/type';
import { HdsNavigation, HdsNavigationTitleMode, ScrollEffectType } from '@kit.UIDesignKit';
import { LengthMetrics } from '@kit.ArkUI';
import type {
  HdsNavigationTitleBarOptions,
  TitleBarContentOptions,
  TitleBarStyleOptions,
  ScrollEffectOptions,
  BottomBuilderParams,
  SystemMaterialParams,
  HdsTitleBarContentStyle,
  HdsNavigationIconItemStyle,
  HdsNavigationBackButtonItemOptions,
  HdsNavigationIconOptions,
} from '@kit.UIDesignKit';
// 栏级沉浸光感：与「我的」/首页/聊天页/草稿箱/废纸篓同一对字段、同一门禁（基准 §7.6.29）。
import { isImmersiveLightSenseSupported, HDS_MATERIAL_TYPE_IMMERSIVE, HDS_MATERIAL_LEVEL_EXQUISITE } from '../utils/immersiveMaterial';

// 搜索框 / 搜索按钮的标准控件高度：与搜索探索页（SearchPanel）完全一致
const SEARCH_FIELD_HEIGHT: number = 40;
// 官方返回键占 16~56vp（40vp 圆 + 16vp 左内缩）；stackBuilder 那行是全宽的且 z 序在返回键之上，
// 不留开就会吃掉它的点击（基准 §7.6.31 / 防漂移第 31 条）
const HDS_BACK_SLOT_END_VP: number = 64;
// bottomBuilder 分段行高 = 官方分段栏本体 + 材质投影净空 + 行底留白
//（投影净空必须给足，否则材质落影被行裁成一条硬边灰带，见 immersiveMaterial.ets 顶部注释）
// 自绘分段栏行高：上 xs 呼吸位 + 底部 28vp 材质投影净空（与首页/消息同口径）
const RESULTS_SEG_ROW_VP: number = LayoutTokens.segmentedHeight + SpaceTokens.xs + LayoutTokens.segmentBarShadowRoom;
// 渐变模糊生效区间终点（vp）：与草稿箱/聊天页同量级
const RESULTS_BLUR_END_VP: number = 32;

const SEARCH_SORTS: SegmentedItem[] = [
  { key: 'latest', label: '最新' },
  { key: 'hot', label: '热门' },
];

@Entry
@Component
struct SearchResultPage {
  @State keyword: string = '';
  @State searchList: Post[] = [];
  @State total: number = 0;
  // 初始必须为 false：fetch 的并发守卫 `if (this.loading) return` 会拦截首次加载。
  // aboutToAppear→refresh→fetch 会在首个 await 前同步置 loading=true，build 仍能正常展示加载态。
  @State loading: boolean = false;
  @State error: string = '';
  @State finished: boolean = false;
  // 交给 HdsNavigation.bindToScrollable 驱动顶栏渐变模糊（配方同草稿箱/废纸篓）
  private feedScroller: Scroller = new Scroller();
  // 系统材质修饰器（沉浸光感）：标题栏内搜索框/搜索按钮共用（低版本设备门禁自动跳过）
  private titleBarMaterial: FloatingTopButtonMaterialModifier = new FloatingTopButtonMaterialModifier();
  @State isRefreshing: boolean = false;
  @State pageNum: number = 1;
  @State sortIndex: number = 0;
  private readonly limitNum: number = 10;

  aboutToAppear(): void {
    this.keyword = takeSearchKeyword();
    this.refresh();
  }

  // 重置并加载第一页
  async refresh(): Promise<void> {
    this.pageNum = 1;
    this.finished = false;
    await this.fetch(true);
  }

  // 追加下一页
  async loadMore(): Promise<void> {
    if (this.finished || this.loading || this.isRefreshing) {
      return;
    }
    this.pageNum += 1;
    await this.fetch(false);
  }

  // 二次搜索：更新 keyword 后重搜（保留本页作为搜索结果页）
  private doSearch(raw: string): void {
    const kw = raw.trim();
    if (!kw) {
      safeShowToast(this.getUIContext(),{ message: '请输入搜索内容' });
      return;
    }
    this.keyword = kw;
    this.refresh();
  }

  private onSortChange(index: number): void {
    if (this.sortIndex === index) {
      return;
    }
    this.sortIndex = index;
    this.refresh();
  }

  // 列表稳定 key（PostCard 一镜到底未启用，仅用于 ForEach 复用）
  private searchKeys(): string[] {
    return this.searchList.map((p: Post): string => String(p.id ?? ''));
  }

  // 跳详情：照抄 HomeTab 父级包裹模式
  private goDetail(post: Post): void {
    if (post.id !== undefined) {
      // 搜索结果点击带 search 场景：用于区分搜索与信息流的点击归因
      trackPostEvent(post.id, 'click', 'search');
      const id = post.id.toString();
      openPostDetail(id);
      this.getUIContext().getRouter().pushUrl({ url: 'pages/DetailPage' });
    }
  }

  // 请求序号：每次发起自增；响应回来时若序号已落后则整体丢弃（最后一次发起的请求生效）。
  // 与 HomeTab.fetch 同一竞态（提审审计 P1-3）：加载更多在途时换关键词/排序/下拉刷新，
  // 旧实现 refresh 先重置 pageNum=1 再被 if (this.loading) return 静默丢弃 → 旧页回包
  // concat 进旧列表、之后 loadMore 再拉同一页，结果重复且可能展示旧关键词的结果。
  private fetchSeq: number = 0;

  private async fetch(reset: boolean): Promise<void> {
    const seq: number = ++this.fetchSeq;
    this.loading = true;
    this.error = '';
    try {
      const res = await searchPosts({
        keyword: this.keyword,
        page: this.pageNum,
        pageSize: this.limitNum,
        sort: this.sortIndex === 1 ? 'hot' : 'latest',
      });
      if (seq !== this.fetchSeq) {
        return; // 过期响应：期间已有更新的请求发起，整体丢弃
      }
      if (reset) {
        this.searchList = res.list;
        this.total = res.pagination.total;
      } else {
        this.searchList = this.searchList.concat(res.list);
      }
      if (res.list.length < this.limitNum) {
        this.finished = true;
      }
    } catch (e) {
      if (seq !== this.fetchSeq) {
        return; // 过期请求的失败不覆盖新请求的状态
      }
      // 分页回滚：loadMore 先 +1 再请求，失败不回滚会让失败那一页被静默跳过
      if (!reset && this.pageNum > 1) {
        this.pageNum -= 1;
      }
      this.error = (e as Error).message;
    } finally {
      // 只有仍是「当前请求」才有资格退出加载态
      if (seq === this.fetchSeq) {
        this.loading = false;
      }
    }
  }

  @Builder
  refreshBuilder(): void {
    Row({ space: 8 }) {
      LoadingProgress().width(20).height(20)
      Text('刷新中…').fontSize(12).fontFamily($r('app.string.font_family')).fontColor($r('app.color.text_secondary'))
    }
  }

  @Builder
  private resultSkeleton(): void {
    Column({ space: GRID_GAP }) {
      Row({ space: GRID_GAP }) {
        Column({ space: SpaceTokens.sm }) {
          Skeleton({ skeletonHeight: 180, radius: RadiusTokens.md })
          Skeleton({ skeletonWidth: '76%', skeletonHeight: 16 })
          Skeleton({ skeletonWidth: '48%', skeletonHeight: 12 })
        }
        .layoutWeight(1)
        Column({ space: SpaceTokens.sm }) {
          Skeleton({ skeletonHeight: 220, radius: RadiusTokens.md })
          Skeleton({ skeletonWidth: '70%', skeletonHeight: 16 })
          Skeleton({ skeletonWidth: '52%', skeletonHeight: 12 })
        }
        .layoutWeight(1)
      }
      Row({ space: GRID_GAP }) {
        Column({ space: SpaceTokens.sm }) {
          Skeleton({ skeletonHeight: 210, radius: RadiusTokens.md })
          Skeleton({ skeletonWidth: '68%', skeletonHeight: 16 })
        }
        .layoutWeight(1)
        Column({ space: SpaceTokens.sm }) {
          Skeleton({ skeletonHeight: 170, radius: RadiusTokens.md })
          Skeleton({ skeletonWidth: '74%', skeletonHeight: 16 })
        }
        .layoutWeight(1)
      }
    }
    .width('100%')
    .padding({ left: GRID_PADDING, right: GRID_PADDING, top: SpaceTokens.item })
  }

  // 工具栏行（stackBuilder）：系统原生搜索框（原生清除 ×）+ 独立搜索按钮。
  // 返回键已交出去 —— 由 HdsNavigation 的官方 backIcon 承担（40vp 玻璃圆，见 titleBarOptions）。
  // ⚠️ 左内缩 64vp 让开官方返回键：这一行 width('100%') 且住在 StackCustomNode 里，
  // 是返回键 Button 的后一个兄弟节点（z 序更高），不留开会把它的点击吃掉（基准 §7.6.31）。
  @Builder
  searchToolbar(): void {
    Row({ space: SpaceTokens.inline }) {
      // 系统原生搜索框：清除 × 为原生自带 —— 不再自绘清除按钮。
      // 不用自带的 searchButton：那是搜索框内部的文字子节点，systemMaterial 只接管
      // 组件自身表面、管不到内部子节点，拿不到沉浸光感；改由右侧独立 Button 承载。
      Search({ placeholder: '搜索', value: this.keyword })
        .layoutWeight(1)
        .height(SEARCH_FIELD_HEIGHT)
        // 底色写在材质之前 —— 材质生效时由系统强制清除为透明（官方行为），低版本则作为兜底底色
        .backgroundColor($r('sys.color.comp_background_tertiary'))
        // 沉浸光感：标题栏内由系统材质接管搜索框表面（低版本自动跳过，保留系统默认样式）
        .attributeModifier(this.titleBarMaterial)
        .onChange((v: string): void => { this.keyword = v; })
        .onSubmit((v: string): void => { this.doSearch(v); })

      // 搜索按钮：文字动作按既定口径留自绘（content.menu 只有颜色三个槽，字号/内边距改不掉），
      // 挂同一块标题栏材质，按压形变由系统承担
      Button('搜索', { type: ButtonType.Normal, stateEffect: true })
        .fontSize(TypeTokens.callout.size)
        .fontWeight(TypeTokens.headline.weight)
        .fontColor(ColorTokens.brand)
        .height(SEARCH_FIELD_HEIGHT)
        .padding({ left: SpaceTokens.md, right: SpaceTokens.md })
        .responseRegion({
          x: (SEARCH_FIELD_HEIGHT - LayoutTokens.minTouchTarget) / 2,
          y: (SEARCH_FIELD_HEIGHT - LayoutTokens.minTouchTarget) / 2,
          width: LayoutTokens.minTouchTarget,
          height: LayoutTokens.minTouchTarget,
        })
        .backgroundColor(Color.Transparent)
        .border({
          width: isSystemMaterialActive() ? 0 : LayoutTokens.glassBorderWidth,
          color: ColorTokens.barBorder,
          style: BorderStyle.Solid,
        })
        .borderRadius(RadiusTokens.lg)
        .attributeModifier(this.titleBarMaterial)
        .accessibilityText('搜索')
        .onClick((): void => { this.doSearch(this.keyword); })
    }
    .width('100%')
    .height('100%')
    .padding({ left: HDS_BACK_SLOT_END_VP, right: SpaceTokens.sm })
    .alignItems(VerticalAlign.Center)
  }

  // 顶栏配置：官方返回键（backIcon）+ stackBuilder 工具栏行 + bottomBuilder 计数/分段行。
  // 两行结构映射与首页同构；栏级材质 + IMMERSIVE 渐变模糊与「我的」/首页同口径。
  private resultsTitleBarOptions(): HdsNavigationTitleBarOptions {
    const immersive: boolean = isImmersiveLightSenseSupported();
    const scrollEffect: ScrollEffectOptions = {
      enableScrollEffect: true,
      scrollEffectType: immersive ? ScrollEffectType.IMMERSIVE_GRADIENT_BLUR : ScrollEffectType.GRADIENT_BLUR,
      blurEffectiveStartOffset: LengthMetrics.vp(0),
      blurEffectiveEndOffset: LengthMetrics.vp(RESULTS_BLUR_END_VP),
    };
    const style: TitleBarStyleOptions = {
      scrollEffectOpts: scrollEffect,
      originalStyle: {
        backgroundStyle: { backgroundColor: Color.Transparent },
        contentStyle: {
          backIconStyle: { iconColor: ColorTokens.primary } as HdsNavigationIconItemStyle,
        } as HdsTitleBarContentStyle,
      },
    };
    if (immersive) {
      style.systemMaterialEffect = {
        materialType: HDS_MATERIAL_TYPE_IMMERSIVE,
        materialLevel: HDS_MATERIAL_LEVEL_EXQUISITE,
      } as SystemMaterialParams;
    }
    // backIcon 带 action 槽 → 返回行为原样保留（还是 router.back()）
    const backContent: HdsNavigationIconOptions = {
      icon: resolveActionIcon('back'),
      label: '返回',
      action: (): void => { this.getUIContext().getRouter().back(); },
    };
    const backIcon: HdsNavigationBackButtonItemOptions = backContent;
    const content: TitleBarContentOptions = {
      stackBuilder: (): void => { this.searchToolbar(); },
      backIcon: backIcon,
      bottomBuilder: {
        builder: (): void => { this.resultsSegRow(); },
        height: RESULTS_SEG_ROW_VP,
      } as BottomBuilderParams,
    };
    const options: HdsNavigationTitleBarOptions = {
      content: content,
      style: style,
      avoidLayoutSafeArea: true,
      // ⚠️ 这页保持 true（内容从栏下开始、不穿到栏下）。试过 false + topInset 做穿底：
      // 材质折射确实出图了（返回键圆内 210~215 vs 圆外 195，是这批页里最明显的一次），
      // 但 bottomBuilder 行里的「找到 N 篇内容」是**无表面的裸小字**，内容一穿到栏下
      // 它就压在渐变模糊的暗背板上，实测字/背板 **1.78:1**，掉出 AA。
      // 工程既有规则「小字不压 tint」在先，故退回不穿底。要拿回穿底，得先把这行计数
      // 搬进列表当表头（它就有自己的白色画布可站），属布局决策，待拍板。基准 §7.6.31。
      enableComponentSafeArea: true,
    };
    return options;
  }

  // bottomBuilder 行：结果计数 + 最新/热门 分段栏。
  // 上下净空按首页同法配平：分段栏本体 + 材质投影净空，避免落影被行裁成硬边灰带。
  @Builder
  private resultsSegRow(): void {
    Row() {
      Text(this.loading ? '正在查找相关帖子' : ('找到 ' + this.total + ' 篇内容'))
        .fontSize(TypeTokens.caption.size).fontFamily(TypeTokens.fontFamily)
        .fontColor(ColorTokens.secondary)
      Blank()
      // 排序分段（回迁 1.0.1 自绘样式）：标题栏生效区内系统材质接管表面
      SegmentedControl({
        items: SEARCH_SORTS,
        selectedIndex: $sortIndex,
        itemWidth: 54,
        fillWidth: false,
        immersive: !isSystemMaterialActive(),
        outlined: isSystemMaterialActive(),
        glowEnabled: false,
        // 1.0.1 同款：系统材质 + 浮起档（材质自带投影）
        useSystemMaterial: true,
        useFloatingMaterial: true,
        onSelect: (index: number): void => { this.onSortChange(index); },
      })
    }
    .width('100%')
    .height(RESULTS_SEG_ROW_VP)
    .padding({ left: SpaceTokens.base, right: SpaceTokens.base })
    .alignItems(VerticalAlign.Center)
  }

  build() {
    HdsNavigation() {
      Column() {
        this.resultsBody()
      }
      .width('100%')
      .height('100%')
      .alignItems(HorizontalAlign.Start)
    }
    .mode(NavigationMode.Stack)
    .titleBar(this.resultsTitleBarOptions())
    .titleMode(HdsNavigationTitleMode.MINI)
    // 渐变模糊的滚动源：没有它，栏后拿不到内容可采样，材质在纯白画布上只差 2~3 级看不出
    .bindToScrollable([this.feedScroller])
    // 穿底绘制链路：HdsNavigation 自身不裁切（内容需画到栏下被模糊采样）
    .clip(false)
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.bg_primary'))
    .transition(buildPageTransition())
  }

  // 三态主体：加载骨架 / 失败重试 / 空态 / 结果网格（原 build 内容整体下沉为内容区）
  @Builder
  resultsBody(): void {
      if (this.searchList.length === 0 && this.loading) {
        Column() {
          this.resultSkeleton()
        }
        .layoutWeight(1)
        .width('100%')
      } else if (this.searchList.length === 0 && this.error !== '') {
        Column() {
          EmptyState({
            icon: resolveActionIcon('warning'),
            title: '搜索暂时不可用',
            message: this.error,
            actionLabel: '重试',
            onAction: (): void => { this.refresh(); },
          })
        }
        .layoutWeight(1)
        .width('100%')
        .justifyContent(FlexAlign.Center)
      } else if (this.searchList.length === 0) {
        // 空态
        Column() {
          EmptyState({
            icon: resolveActionIcon('search'),
            title: '暂时没有相关内容',
            message: '换个关键词，可能会有新发现',
          })
        }
        .layoutWeight(1)
        .width('100%')
        .justifyContent(FlexAlign.Center)
      } else {
        // 结果列表：与首页信息流同款双列布局 + 卡片样式 + 入场错峰过渡（ManagedPostFeed）
        // refreshing 走 $$ 双向绑定，置位交给组件内部状态机；勿在 onRefreshing 里手动置 true（见 HomeTab.ets:831）
        Refresh({ refreshing: $$this.isRefreshing, builder: this.refreshBuilder }) {
          ManagedPostFeed({
            posts: this.searchList,
            itemKeys: this.searchKeys(),
            finished: this.finished,
            bottomPadding: SpaceTokens.x3l,
            // 滚动源仍交给顶栏：静止态不穿底，但渐变模糊需要滚动量来决定栏面强度
            scroller: this.feedScroller,
            onOpen: (post: Post, _key: string): void => { this.goDetail(post); },
            onReachEnd: (): void => { this.loadMore(); },
          })
        }
        .onRefreshing(() => {
          this.refresh().finally(() => {
            this.isRefreshing = false;
          });
        })
        .layoutWeight(1)
        .width('100%')
      }
  }
}
