// 帖子关键词搜索结果页：顶栏(返回+可改搜索框+清除✕+结果计数) + 2列Grid(复用PostCard) + 三态(加载/空/失败)
// 数据来源：searchPosts（services/api.ets，复用 /v1/posts 端点）
// 点击跳转详情：照抄 HomeTab 父级 GridItem().onClick 包裹模式（PostCard 自身不处理点击）

import { Post } from '../models/types';
import { searchPosts, trackPostEvent } from '../services/api';
import { PostCard } from '../components/PostCard';
import { openPostDetail, takeSearchKeyword } from '../utils/nav';
import { safeShowToast } from '../utils/toast';
import { buildPageTransition } from '../utils/styles';
import { resolveActionIcon } from '../utils/actionIcons';
import { observeGridColumns, gridColumnTemplate } from '../utils/responsive';
import { GRID_GAP, GRID_PADDING } from '../utils/cardTokens';
import { common } from '@kit.AbilityKit';
import { EmptyState } from '../design/components/EmptyState';
import { SegmentedControl, SegmentedItem } from '../design/components/SegmentedControl';
import { isSystemMaterialActive, TopButtonMaterialModifier } from '../utils/immersiveMaterial';
import { BackButton } from '../design/components/BackButton';
import { GlowInput } from '../design/components/GlowInput';
import { Skeleton } from '../design/motion/Skeleton';
import { ColorTokens } from '../design/tokens/color';
import { IconTokens } from '../design/tokens/icon';
import { RadiusTokens } from '../design/tokens/radius';
import { LayoutTokens, SpaceTokens } from '../design/tokens/space';
import { TypeTokens } from '../design/tokens/type';

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
  @StorageLink('statusBarHeight') statusBarHeight: number = 0;
  // 标题栏实测高度（vp）：内容驱动回写（同「我的」顶栏 profileHeroHeight 的做法）；
  // 实测到齐前走估算兜底，避免首帧标题栏高度与内容错位
  @State resultsBarHeight: number = 0;
  // 系统材质修饰器（沉浸光感）：标题栏内输入框/返回键共用（低版本设备门禁自动跳过）
  private titleBarMaterial: TopButtonMaterialModifier = new TopButtonMaterialModifier();
  @State isRefreshing: boolean = false;
  @State pageNum: number = 1;
  @State sortIndex: number = 0;
  private readonly limitNum: number = 10;
  // 响应式列数（按屏幕宽度 2/3/4 列自适应）
  @State gridColumns: number = 2;
  @State gridTemplate: string = '1fr 1fr';
  private unregisterColumns: () => void = () => {};

  aboutToAppear(): void {
    this.keyword = takeSearchKeyword();
    this.unregisterColumns = observeGridColumns(
      this.getUIContext().getHostContext() as common.Context,
      (cols: number): void => {
        this.gridColumns = cols;
        this.gridTemplate = gridColumnTemplate(cols);
      }
    );
    this.refresh();
  }

  aboutToDisappear(): void {
    this.unregisterColumns();
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

  private async fetch(reset: boolean): Promise<void> {
    if (this.loading) {
      return;
    }
    this.loading = true;
    this.error = '';
    try {
      const res = await searchPosts({
        keyword: this.keyword,
        page: this.pageNum,
        pageSize: this.limitNum,
        sort: this.sortIndex === 1 ? 'hot' : 'latest',
      });
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
      this.error = (e as Error).message;
    } finally {
      this.loading = false;
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

  // 聚焦流光输入框：键入（聚焦）点亮原生流光，失焦熄灭
  @Builder
  searchInput(): void {
    GlowInput({
      placeholder: '搜索',
      text: $keyword,
      fillWidth: true,
      onEnter: (): void => {
        this.doSearch(this.keyword);
      },
    })
      // 沉浸光感：标题栏内由系统材质接管输入框表面（低版本自动跳过，保留流光兜底）
      .attributeModifier(this.titleBarMaterial)
  }

  // 标题栏高度：实测值到齐前用估算兜底（状态栏 + 工具栏行 44+8 + 计数/排序行 36+6）
  private resultsTitleBarHeight(): number {
    return this.resultsBarHeight > 0 ? this.resultsBarHeight : this.statusBarHeight + 94;
  }

  // 标题栏：玻璃搜索工具栏（返回 + 流光输入框 + 清除）+ 结果计数 + 最新/最热 分段栏。
  // 迁入 Navigation 标题栏与搜索探索页同构——沉浸光感 uiMaterial 的官方生效区域；
  // 沉浸式布局下系统不代为避让状态栏，由标题栏自行下移（padding top statusBarHeight）。
  @Builder
  private resultsTitleBar(): void {
    Column() {
      Row({ space: SpaceTokens.inline }) {
        BackButton({ action: (): void => { this.getUIContext().getRouter().back(); } })
          .attributeModifier(this.titleBarMaterial)

        this.searchInput()

        if (this.keyword !== '') {
          Row() {
            Image(resolveActionIcon('close'))
              .width(IconTokens.compact)
              .height(IconTokens.compact)
              .fillColor(ColorTokens.icon)
          }
          .width(LayoutTokens.minTouchTarget)
          .height(LayoutTokens.minTouchTarget)
          .justifyContent(FlexAlign.Center)
          .border({ width: LayoutTokens.glassBorderWidth, color: ColorTokens.barBorder, style: BorderStyle.Solid })
          .borderRadius(RadiusTokens.lg)
            .onClick(() => {
              this.keyword = '';
            })
        }
      }
      .width('100%')
      .padding({ left: SpaceTokens.sm, right: SpaceTokens.sm, top: SpaceTokens.xs, bottom: SpaceTokens.xs })
      .alignItems(VerticalAlign.Center)

      Row() {
        Text(this.loading ? '正在查找相关帖子' : ('找到 ' + this.total + ' 篇内容'))
          .fontSize(TypeTokens.caption.size).fontFamily(TypeTokens.fontFamily)
          .fontColor(ColorTokens.secondary)
        Blank()
        SegmentedControl({
          items: SEARCH_SORTS,
          selectedIndex: $sortIndex,
          itemWidth: 54,
          fillWidth: false,
          // 与 Index 标题栏分段栏同配置：标题栏为沉浸光感 uiMaterial 生效区域，
          // 系统材质接管表面（低版本门禁不通过则回退沉浸玻璃/描边分发）
          immersive: !isSystemMaterialActive(),
          outlined: isSystemMaterialActive(),
          glowEnabled: false,
          useSystemMaterial: true,
          onSelect: (index: number): void => { this.onSortChange(index); },
        })
      }
      .width('100%')
      .padding({ left: SpaceTokens.base, right: SpaceTokens.base, top: 0, bottom: SpaceTokens.xs })
      .alignItems(VerticalAlign.Center)
    }
    .width('100%')
    .padding({ top: this.statusBarHeight })
    .onAreaChange((_old: Area, area: Area): void => {
      // 标题栏高度内容驱动回写（同「我的」顶栏 profileHeroHeight 的做法），
      // 实测值到齐前 height 走估算，避免首帧标题栏与内容错位
      const h: number = parseFloat(String(area.height));
      if (h > 0 && Math.abs(h - this.resultsBarHeight) > 0.5) {
        this.resultsBarHeight = h;
      }
    })
  }

  build() {
    Navigation() {
      Column() {
        this.resultsBody()
      }
      .width('100%')
      .height('100%')
      .alignItems(HorizontalAlign.Start)
    }
    .hideTitleBar(false)
    .title({
      builder: this.resultsTitleBar,
      height: this.resultsTitleBarHeight(),
    }, { barStyle: BarStyle.STANDARD, backgroundColor: $r('app.color.bg_primary') })
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
        // 结果列表
        Refresh({ refreshing: this.isRefreshing, builder: this.refreshBuilder }) {
          Grid() {
            ForEach(
              this.searchList,
              (post: Post) => {
                GridItem() {
                  PostCard({
                    post: post,
                    // 多列网格小卡用紧凑档（xs 圆角），避免默认大圆角与半宽卡片失调
                    compact: true,
                    onOpen: () => {
                      this.goDetail(post);
                    },
                  })
                }
              },
              (post: Post) => post.id?.toString() ?? ''
            )
            if (this.finished) {
              GridItem() {
                Text('没有更多了')
                  .fontSize(12).fontFamily($r('app.string.font_family'))
                  .fontColor($r('app.color.text_secondary'))
                  .width('100%')
                  .textAlign(TextAlign.Center)
                  .padding(16)
              }
              .columnStart(0)
              .columnEnd(this.gridColumns - 1)
            }
          }
          .columnsTemplate(this.gridTemplate)
          .columnsGap(GRID_GAP)
          .rowsGap(GRID_GAP)
          .padding(GRID_PADDING)
          .onScrollIndex((_start: number, end: number) => {
            if (end >= this.searchList.length - 1) {
              this.loadMore();
            }
          })
        }
        .onRefreshing(() => {
          this.isRefreshing = true;
          this.refresh().finally(() => {
            this.isRefreshing = false;
          });
        })
        .layoutWeight(1)
        .width('100%')
      }
  }
}
