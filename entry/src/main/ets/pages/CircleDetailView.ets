import { Post } from '../models/types';
import {
  CircleOverviewItem,
  followTag,
  getCircleOverview,
  listFollowedTags,
  listPosts,
  markTagRead,
  unfollowTag,
  trackPostEvent,
} from '../services/api';
import { getToken } from '../utils/auth';
import { emitTabSwitch, openPostDetail, takeCircleDetailName } from '../utils/nav';
import { setPendingPublishCircle } from '../utils/publishCircleIntent';
import { getMainNavStack, EmptyNavParams, PostDetailNavParams } from '../utils/navigationTransition';
import { gridColumnTemplate, gridColumnsForBreakpoint } from '../utils/responsive';
import { GRID_GAP, GRID_PADDING } from '../utils/cardTokens';
import { safeShowToast } from '../utils/toast';
import { PostCard } from '../components/PostCard';
import { TagIcon } from '../components/TagIcon';
import { DesignButton } from '../design/components/DesignButton';
import { EmptyState } from '../design/components/EmptyState';
import { ImmersiveSegmentBar, SegmentedItem } from '../design/components/ImmersiveSegmentBar';
import { isSystemMaterialActive } from '../utils/immersiveMaterial';
import { HdsNavigation, HdsNavigationTitleMode, ScrollEffectType } from '@kit.UIDesignKit';
import type {
  HdsNavigationTitleBarOptions,
  TitleBarContentOptions,
  TitleBarStyleOptions,
  ScrollEffectOptions,
  HdsTitleBarContentStyle,
  HdsNavigationIconItemStyle,
  HdsNavigationIconOptions,
  HdsNavigationBackButtonItemOptions,
  SystemMaterialParams,
} from '@kit.UIDesignKit';
import { LengthMetrics } from '@kit.ArkUI';
import { isImmersiveLightSenseSupported, HDS_MATERIAL_TYPE_IMMERSIVE, HDS_MATERIAL_LEVEL_EXQUISITE } from '../utils/immersiveMaterial';
import { requestSystemBarRefresh } from '../utils/systemBar';
import { resolveActionIcon } from '../utils/actionIcons';
import { Pressable } from '../design/motion/Pressable';
import { Reveal } from '../design/motion/Reveal';
import { MotionTokens } from '../design/tokens/motion';
import { ColorTokens } from '../design/tokens/color';
import { IconTokens } from '../design/tokens/icon';
import { RadiusTokens } from '../design/tokens/radius';
import { LayoutTokens, SpaceTokens } from '../design/tokens/space';
import { TypeTokens } from '../design/tokens/type';

const FEED_SEGMENTS: SegmentedItem[] = [
  { key: 'latest', label: '最新' },
  { key: 'hot', label: '热门' },
];

// 圈子详情「主体视图」：router 壳（pages/CircleDetailPage）与 Navigation 壳
// （pages/CircleDetailDestination）共用。差异点收敛为注入回调：
// - navMode=true（Navigation 壳）：返回走 onBack，闭环跳转走 navStack.pushPathByName；
// - navMode=false（router 壳）：保持原 router 行为（router.back / router.pushUrl）。
@Component
export struct CircleDetailView {
  // —— 壳注入（Navigation 壳 pages/CircleDetailDestination 使用）——
  @Prop navMode: boolean = false;
  // Navigation 壳经 CircleDetailNavParams 传圈子名；router 壳为空，回退模块级意图通道。
  @Prop initialCircleName: string = '';
  onBack?: () => void = undefined;     // Navigation 壳：navStack.pop()
  @State circleName: string = '';
  // 圈子元信息：来自 /v1/tags/overview?name=，让详情页不再是“只有名字”的空壳。
  @State circleCategory: string = '';
  @State circleDescription: string = '';
  @State circleMemberCount: number = 0;
  @State posts: Post[] = [];
  @State sortIndex: number = 0;
  @State page: number = 1;
  @State loading: boolean = false;
  @State refreshing: boolean = false;
  @State finished: boolean = false;
  @State error: string = '';
  @State joined: boolean = false;
  @State joining: boolean = false;
  @State gridColumns: number = 2;
  @State gridTemplate: string = '1fr 1fr';
  // 网格列数由全局断点驱动（全 app 唯一窗口尺寸监听，见 utils/breakpointCenter.ets）
  @StorageProp('currentBreakpoint') @Watch('onBreakpointChanged') currentBreakpoint: string = 'sm';
  @StorageLink('statusBarHeight') statusBarHeight: number = 0;
  // 2026-10-29 信息行/分段行已移出标题栏（见 circlePageHeader）：标题栏回归纯官方返回键，
  // 让位量改用固定 MINI 栏高（MINI_BAR_HEIGHT），不再回写实测。
  // 模糊出图开关（IMMERSIVE 变体门控，绝对偏移驱动）
  @State circleBarScrolled: boolean = false;
  // 帖子网格滚动源（bindToScrollable 驱动渐变模糊）
  private gridScroller: Scroller = new Scroller();
  private listVersion: number = 0;
  // 已成功加载的排序索引：ImmersiveSegmentBar 会先写 sortIndex 再回调 onSelect，
  // 必须用独立记录判断「这次点击是不是同一个已加载分段」，否则点当前段也会重拉。
  private loadedSortIndex: number = 0;

  // 统一返回入口：Navigation 壳走 onBack（navStack.pop），router 壳走普通返回
  private backAction(): void {
    if (this.onBack !== undefined) {
      this.onBack();
      return;
    }
    this.getUIContext().getRouter().back();
  }

  aboutToAppear(): void {
    this.circleName = this.initialCircleName.length > 0
      ? this.initialCircleName : takeCircleDetailName();
    // 网格列数：按当前全局断点换算（断点中心异步就绪后经 @Watch 修正）
    this.applyGridColumns();
    this.init();
  }

  // 网格列数换算（断点 → 列数/模板）
  private applyGridColumns(): void {
    const cols: number = gridColumnsForBreakpoint(this.currentBreakpoint);
    this.gridColumns = cols;
    this.gridTemplate = gridColumnTemplate(cols);
  }

  // 断点变化（展开折叠屏/旋转/分屏）→ 即时换算网格列数
  onBreakpointChanged(): void {
    this.applyGridColumns();
  }

  private async init(): Promise<void> {
    if (this.circleName.length === 0) {
      this.error = '圈子信息已失效，请从圈子页重新进入';
      return;
    }
    // 进入完整圈子页 = 已浏览该圈：清零未读角标（与降落页语义一致）。
    // 成功后广播 circleRead 信号，让仍挂载在 TabContent 里的星图即时熄灭本地角标
    // （详情页在 Navigation 上，返回本 Tab 不会再次触发 CircleTab.onActiveTab）。
    if (getToken() !== '') {
      const readName: string = this.circleName;
      markTagRead(readName).then((): void => {
        AppStorage.setOrCreate<string>('circleReadName', readName);
        const version: number = AppStorage.get<number>('circleReadVersion') ?? 0;
        AppStorage.setOrCreate<number>('circleReadVersion', version + 1);
      }).catch((): void => {});
    }
    // 帖子流对访客公开可浏览，未登录不拦截；加入/退出圈子时再做登录引导。
    // 关注态、圈子元信息与首页帖子并行拉取，避免串行多轮等待。
    await Promise.all([this.loadJoined(), this.loadCircleMeta(), this.refresh()]);
  }

  private async loadCircleMeta(): Promise<void> {
    try {
      const overview = await getCircleOverview('all', undefined, this.circleName);
      const item: CircleOverviewItem | undefined =
        overview.circles.find((circle: CircleOverviewItem): boolean => circle.name === this.circleName);
      if (item !== undefined) {
        this.circleCategory = item.category;
        this.circleDescription = item.description;
        this.circleMemberCount = item.memberCount;
      }
    } catch (e) {
      // 元信息失败不影响帖子流：标题栏退回通用副标题。
    }
  }

  private circleSubtitle(): string {
    const parts: string[] = [];
    if (this.circleMemberCount > 0) {
      parts.push(this.circleMemberCount + ' 人已加入');
    }
    if (this.circleCategory.length > 0) {
      parts.push(this.circleCategory);
    }
    if (this.circleDescription.length > 0) {
      parts.push(this.circleDescription);
    }
    return parts.length > 0 ? parts.join(' · ') : '浏览这个圈子里的真实帖子';
  }

  // 空态「去发布」：把当前圈子作为预选意图带进发布流，再退出详情页切到发布 Tab。
  private goPublish(): void {
    // 把当前圈子带进发布流：用户选好文/图/视频后，新建草稿会自动预选它。
    setPendingPublishCircle(this.circleName);
    // 先退出当前详情壳，再切发布 Tab；router 壳不能只切 Tab（页面还压在栈顶）。
    if (this.navMode) {
      this.backAction();
    } else {
      this.getUIContext().getRouter().back();
    }
    setTimeout((): void => { emitTabSwitch(2); }, MotionTokens.fast) as number;
  }

  private async loadJoined(): Promise<void> {
    // 未登录不请求加入态（默认未加入），避免空 token 拉取关注列表。
    if (getToken() === '') {
      this.joined = false;
      return;
    }
    try {
      const names = await listFollowedTags();
      this.joined = names.indexOf(this.circleName) >= 0;
    } catch (e) {
      // 帖子流仍可继续加载；加入状态在本次会话中保持默认值。
    }
  }

  // keepExisting=true：下拉刷新/切排序时保留旧列表，等新数据回来再替换；
  // 不再先把 posts 清空导致 Refresh/Grid 被销毁、页面闪白。
  private async refresh(keepExisting: boolean = false): Promise<void> {
    const version = this.listVersion + 1;
    this.listVersion = version;
    this.page = 1;
    this.finished = false;
    this.error = '';
    if (!keepExisting) {
      this.posts = [];
    }
    await this.fetch(true, version);
    if (keepExisting && this.error.length > 0 && this.posts.length > 0) {
      safeShowToast(this.getUIContext(), { message: '刷新失败：' + this.error });
      this.error = '';
    }
  }

  private async loadMore(): Promise<void> {
    if (this.loading || this.finished || this.refreshing) {
      return;
    }
    this.page += 1;
    await this.fetch(false, this.listVersion);
  }

  private async fetch(reset: boolean, version: number): Promise<void> {
    if (!reset && this.loading) {
      return;
    }
    this.loading = true;
    try {
      const result = await listPosts({
        page: this.page,
        limit: 20,
        sort: this.sortIndex === 0 ? 'latest' : 'hot',
        tag: this.circleName,
      });
      if (version !== this.listVersion) {
        return;
      }
      this.posts = reset ? result.list : this.posts.concat(result.list);
      this.finished = result.list.length < 20;
      if (reset) {
        this.loadedSortIndex = this.sortIndex;
      }
    } catch (e) {
      if (version === this.listVersion) {
        this.error = (e as Error).message;
      }
    } finally {
      if (version === this.listVersion) {
        this.loading = false;
      }
    }
  }

  private switchSort(index: number): void {
    // ImmersiveSegmentBar 会先更新双向绑定的 sortIndex，再触发 onSelect；
    // 因此不能用 sortIndex 判断是否变化，必须对比上次成功加载的分段。
    const previous: number = this.loadedSortIndex;
    if (this.sortIndex !== index) {
      this.sortIndex = index;
    }
    if (previous === index) {
      return;
    }
    this.refresh(true).then((): void => {
      // 拉取失败时把分段拨回上一次成功加载的项，避免“显示热门、列表还是最新”的错位。
      if (this.loadedSortIndex !== index) {
        this.sortIndex = this.loadedSortIndex;
      }
    });
  }

  private async toggleJoin(): Promise<void> {
    if (this.joining || this.circleName.length === 0) {
      return;
    }
    // 未登录先引导登录，避免空 token 调用 followTag 后 401 静默失败。
    if (getToken() === '') {
      if (this.navMode) {
        const nav: NavPathStack | null = getMainNavStack();
        if (nav !== null) {
          nav.pushPathByName('Login', new EmptyNavParams());
          return;
        }
      }
      this.getUIContext().getRouter().pushUrl({ url: 'pages/LoginPage' });
      return;
    }
    const wasJoined = this.joined;
    this.joining = true;
    this.joined = !wasJoined;
    try {
      if (wasJoined) {
        await unfollowTag(this.circleName);
      } else {
        await followTag(this.circleName);
      }
      const version: number = AppStorage.get<number>('circleMembershipVersion') ?? 0;
      AppStorage.setOrCreate('circleMembershipVersion', version + 1);
      safeShowToast(this.getUIContext(), { message: wasJoined ? '已退出圈子' : '已加入圈子' });
    } catch (e) {
      this.joined = wasJoined;
      safeShowToast(this.getUIContext(), { message: '操作失败：' + (e as Error).message });
    } finally {
      this.joining = false;
    }
  }

  private openPost(post: Post): void {
    if (post.id === undefined) {
      return;
    }
    // 圈子（标签页）点击带 circle 场景：圈层内容点击是标签亲和的重要信号
    trackPostEvent(post.id, 'click', 'circle');
    const id = String(post.id);
    openPostDetail(id);
    if (this.navMode) {
      const nav: NavPathStack | null = getMainNavStack();
      if (nav !== null) {
        const p: PostDetailNavParams = new PostDetailNavParams();
        p.postId = post.id;
        nav.pushPathByName('PostDetail', p);
        return;
      }
    }
    this.getUIContext().getRouter().pushUrl({ url: 'pages/DetailPage' });
  }

  // 官方 MINI 标题栏体高（真机实测 57vp，2026-10-29）：标题栏回归纯返回键后无自定义
  // 内容可量，让位用固定值——statusBar 由 @StorageLink 注入
  private static readonly MINI_BAR_HEIGHT: number = 58;

  private circleTitleBarHeight(): number {
    return CircleDetailView.MINI_BAR_HEIGHT;
  }

  // 滚动态 → 模糊出图开关 + 系统栏补设（绝对偏移，§36/竞速同款）
  private syncCircleScroll(): void {
    const offset: number = this.gridScroller?.currentOffset()?.yOffset ?? 0;
    const scrolled: boolean = offset > 0;
    if (scrolled !== this.circleBarScrolled) {
      this.circleBarScrolled = scrolled;
    }
    if (offset <= 0) {
      requestSystemBarRefresh();
    }
  }

  // 穿底让位：状态栏 + stackBuilder 实测高（enableComponentSafeArea:false 后自管）
  private circleListInset(): number {
    return this.statusBarHeight + this.circleTitleBarHeight();
  }

  // HdsNavigation 标题栏配置（详情页同款配方）
  private circleTitleBarOptions(): HdsNavigationTitleBarOptions {
    const immersive: boolean = isImmersiveLightSenseSupported();
    const scrollEffect: ScrollEffectOptions = {
      enableScrollEffect: true,
      scrollEffectType: immersive ? ScrollEffectType.IMMERSIVE_GRADIENT_BLUR : ScrollEffectType.GRADIENT_BLUR,
      blurEffectiveStartOffset: LengthMetrics.vp(0),
      blurEffectiveEndOffset: LengthMetrics.vp(32),
    };
    const style: TitleBarStyleOptions = {
      scrollEffectOpts: scrollEffect,
      originalStyle: {
        backgroundStyle: {
          backgroundColor: Color.Transparent,
          blurRadius: this.circleBarScrolled ? 50 : 0,
          maskExtraHeight: 0,
        },
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
    const backContent: HdsNavigationIconOptions = {
      icon: resolveActionIcon('back'),
      label: '返回',
      action: (): void => { this.backAction(); },
    };
    const backIcon: HdsNavigationBackButtonItemOptions = backContent;
    // 标题栏回归纯官方（2026-10-29）：仅返回键，无 stackBuilder——MINI 栏体 57vp 装不下
    // 双行信息行（~88vp），此前溢出栏底 3vp 且让位回写被污染。信息行驻内容区页头
    //（见 circlePageHeader），身份承载不变。
    const content: TitleBarContentOptions = {
      backIcon: backIcon,
    };
    return {
      content: content,
      style: style,
      avoidLayoutSafeArea: true,
      enableComponentSafeArea: false,
    };
  }

  // 内容区页头：圈子信息行（图标 + 名称 + 副标题）+ 分段行（见 circleSegRow）。
  // 2026-10-29 整体移出标题栏：MINI 标题栏本体仅 57vp，双行信息行（~88vp）物理放不下，
  // 副标题溢出栏底 3vp、分段行让位回写被污染——标题栏回归纯官方（仅返回键，零自定义
  // 内容即零溢出）。信息行左右 padding 与网格对齐。
  @Builder
  circlePageHeader(): void {
    Column() {
      Row({ space: SpaceTokens.item }) {
        TagIcon({
          name: this.circleName,
          category: this.circleCategory,
          iconSize: IconTokens.avatarProfile + 2,
          tint: ColorTokens.brand,
        })
          .width(IconTokens.avatarProfile)
          .height(IconTokens.avatarProfile)

        Column({ space: SpaceTokens.inlineTight }) {
          Text(this.circleName)
            .fontSize(TypeTokens.display.size).fontFamily(TypeTokens.fontFamilySerif)
            .fontWeight(TypeTokens.display.weight)
            .lineHeight(TypeTokens.display.lineHeight)
            .fontColor(ColorTokens.primary)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
          Text(this.circleSubtitle())
            .fontSize(TypeTokens.callout.size).fontFamily(TypeTokens.fontFamily)
            .fontWeight(TypeTokens.callout.weight)
            .lineHeight(TypeTokens.callout.lineHeight)
            .fontColor(ColorTokens.secondary)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)
      }
      .width('100%')
      .padding({ left: GRID_PADDING, right: GRID_PADDING, bottom: SpaceTokens.item })

      this.circleSegRow()
    }
    .width('100%')
    // 全屏沉浸壳内容器从屏顶起排：顶部让位穿底标题栏（statusBar + 官方 MINI 栏体高），
    // 否则页头被返回键行盖住（同举报中心 8a0ab3a 口径）
    .padding({ top: this.circleListInset() })
  }

  // 分段行（最新/热门 + 加入/退出按钮）：固定驻内容区顶部（2026-10-28 移出标题栏，
  // 原因同举报中心——HdsNavigation 把 content 布局高度钳制 ~76vp，信息行+分段行 ~150vp
  // 溢出悬浮、列表让位回写被污染，卡片顶与按钮底贴死）。分段栏恢复 itemWidth 64：
  // 与「加入圈子」按钮并排的定宽场景（推导 45×2=90vp 过窄失衡）；材质走官方组件
  // 表面通道（overrideTrackMaterial），内容区正常出图。左右 padding 与网格对齐。
  @Builder
  circleSegRow(): void {
    Row() {
      ImmersiveSegmentBar({
        items: FEED_SEGMENTS,
        selectedIndex: $sortIndex,
        itemWidth: 64,
        overrideTrackMaterial: true,
        onSelect: (index: number): void => { this.switchSort(index); },
      })
      Blank()
      // 加入/退出圈子：走描边而非材质接管表面——ULTRA_THIN 在浅色栏面上只比画布亮 2 级
      //（真机 253 vs 255），DesignButton 挂材质时会把自绘描边一并置 0（DesignButton.ets:103）
      // ——换来的那 2 级读不出来，按钮却没了可点性。描边才是这颗钮的实际表面。
      DesignButton({
        label: this.joined ? '退出圈子' : '加入圈子',
        variant: 'outlined',
        disabled: this.joining,
        useSystemMaterial: false,
        action: (): void => { this.toggleJoin(); },
      })
    }
    .width('100%')
    .alignItems(VerticalAlign.Center)
    .padding({
      left: GRID_PADDING,
      right: GRID_PADDING,
      bottom: SpaceTokens.sm,
    })
  }

  @Builder
  refreshBuilder(): void {
    Row({ space: SpaceTokens.inline }) {
      LoadingProgress().width(IconTokens.compact).height(IconTokens.compact)
      Text('刷新中…')
        .fontSize(TypeTokens.caption.size).fontFamily(TypeTokens.fontFamily)
        .fontWeight(TypeTokens.caption.weight)
        .fontColor(ColorTokens.secondary)
    }
  }

  build() {
    HdsNavigation() {
      Column() {
        // 页头固定区（信息行 + 分段行）：2026-10-29 整体移出标题栏，见 circlePageHeader 注释
        this.circlePageHeader()
        if (this.posts.length === 0 && this.loading) {
          Column({ space: SpaceTokens.item }) {
            LoadingProgress().width(IconTokens.empty).height(IconTokens.empty)
            Text('正在加载帖子')
              .fontSize(TypeTokens.callout.size).fontFamily(TypeTokens.fontFamily)
              .fontWeight(TypeTokens.callout.weight)
              .fontColor(ColorTokens.secondary)
          }
          .layoutWeight(1)
          .width('100%')
          .justifyContent(FlexAlign.Center)
        } else if (this.posts.length === 0) {
          Column() {
            EmptyState({
              title: this.error ? '加载失败' : '这个圈子还没有帖子',
              message: this.error ? this.error : '第一篇相关内容发布后会显示在这里',
              actionLabel: this.error ? '重试' : '去发布',
              onAction: (): void => {
                if (this.error) {
                  this.refresh();
                } else {
                  this.goPublish();
                }
              },
            })
          }
          .layoutWeight(1)
          .width('100%')
          .justifyContent(FlexAlign.Center)
        } else {
          // refreshing 走 $$ 双向绑定，置位交给组件内部状态机；勿在 onRefreshing 里手动置 true（见 HomeTab.ets:831）
          Refresh({ refreshing: $$this.refreshing, builder: this.refreshBuilder }) {
            Grid(this.gridScroller) {
              ForEach(this.posts, (post: Post, index: number) => {
                GridItem() {
                  Reveal({ index: index % 5 }) {
                    PostCard({
                      post: post,
                      compact: true,
                      navMode: this.navMode,
                      onOpen: (): void => { this.openPost(post); },
                    })
                  }
                }
              }, (post: Post) => this.circleName + '-' + (post.id?.toString() ?? ''))
              if (this.finished) {
                GridItem() {
                  Text('没有更多了')
                    .fontSize(TypeTokens.caption.size).fontFamily(TypeTokens.fontFamily)
                    .fontWeight(TypeTokens.caption.weight)
                    .fontColor(ColorTokens.tertiary)
                    .width('100%')
                    .textAlign(TextAlign.Center)
                    .padding(SpaceTokens.base)
                }
                .columnStart(0)
                .columnEnd(this.gridColumns - 1)
              }
            }
            .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true })
            .onDidScroll((): void => { this.syncCircleScroll(); })
            .onScrollStop((): void => { this.syncCircleScroll(); })
            .columnsTemplate(this.gridTemplate)
            .columnsGap(GRID_GAP)
            .rowsGap(GRID_GAP)
            // 顶部不再补标题栏让位：分段行固定区已承担 circleListInset（见 circleSegRow），
            // 卡片顶 = 分段行底，再补会出大空隙/贴死按钮（真机实证 2026-10-28）
            .padding({ left: GRID_PADDING, right: GRID_PADDING, bottom: GRID_PADDING })
            .onScrollIndex((_start: number, end: number) => {
              if (end >= this.posts.length - 1) {
                this.loadMore();
              }
            })
          }
          .onRefreshing(() => {
            this.refresh(true).finally(() => { this.refreshing = false; });
          })
          .layoutWeight(1)
          .width('100%')
        }
      }
      .width('100%')
      .height('100%')
      .backgroundColor(ColorTokens.canvas)
      .alignItems(HorizontalAlign.Start)
    }
    .titleMode(HdsNavigationTitleMode.MINI)
    .titleBar(this.circleTitleBarOptions())
    // 滚动源绑定：帖子网格驱动栏体渐变模糊（§7.6.12）
    .bindToScrollable([this.gridScroller])
    .clip(false)
    .width('100%')
    .height('100%')
  }
}