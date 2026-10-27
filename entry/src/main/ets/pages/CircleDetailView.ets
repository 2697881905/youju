import { Post } from '../models/types';
import { followTag, listFollowedTags, listPosts, markTagRead, unfollowTag, trackPostEvent } from '../services/api';
import { getToken } from '../utils/auth';
import { openPostDetail, takeCircleDetailName } from '../utils/nav';
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
  // 标题栏（导航行 + 圈子信息行 + 最新/热门分段栏与加入圈子按钮）驻留 Navigation 标题栏 ——
  // uiMaterial 沉浸光感的官方生效区域；栏高由内容实测回写（首帧用估算兜底）。
  @State titleBarContentHeight: number = 0;
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
      markTagRead(this.circleName).then((): void => {
        AppStorage.setOrCreate<string>('circleReadName', this.circleName);
        const version: number = AppStorage.get<number>('circleReadVersion') ?? 0;
        AppStorage.setOrCreate<number>('circleReadVersion', version + 1);
      }).catch((): void => {});
    }
    // 帖子流对访客公开可浏览，未登录不拦截；加入/退出圈子时再做登录引导。
    // 关注态与首页帖子并行拉取，避免串行多一轮等待。
    await Promise.all([this.loadJoined(), this.refresh()]);
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

  // 标题栏首帧估算：与 Builder 三行的内边距/控件高度同源（实测回写后不再使用）
  private circleTitleBarEstimate(): number {
    const navRow: number = SpaceTokens.md + LayoutTokens.minTouchTarget + SpaceTokens.sm;
    const infoRow: number = SpaceTokens.sm
      + TypeTokens.display.lineHeight + SpaceTokens.inlineTight + TypeTokens.callout.lineHeight
      + SpaceTokens.item;
    const segRow: number = LayoutTokens.minTouchTarget + SpaceTokens.sm;
    return this.statusBarHeight + navRow + infoRow + segRow;
  }

  private circleTitleBarHeight(): number {
    return this.titleBarContentHeight > 0 ? this.titleBarContentHeight : this.circleTitleBarEstimate();
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
    const content: TitleBarContentOptions = {
      stackBuilder: (): void => { this.circleStackContent(); },
      backIcon: backIcon,
    };
    return {
      content: content,
      style: style,
      avoidLayoutSafeArea: true,
      enableComponentSafeArea: false,
    };
  }

  // 标题栏（穿底三件套·消息页路线 B 模板，序位③）：官方返回键 + 多行 stackBuilder
  //（圈子信息行 + 最新/热门分段行与加入按钮）。原居中「圈子」导航行随 BackButton 一并退役
  //——信息行已承载身份。高度由 onAreaChange 实测（titleBarContentHeight），内容让位量共用它。
  @Builder
  circleStackContent(): void {
    Column() {
      Row({ space: SpaceTokens.item }) {
        TagIcon({ name: this.circleName, iconSize: IconTokens.avatarProfile + 2, tint: ColorTokens.brand })
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
          Text('浏览这个圈子里的真实帖子')
            .fontSize(TypeTokens.callout.size).fontFamily(TypeTokens.fontFamily)
            .fontWeight(TypeTokens.callout.weight)
            .lineHeight(TypeTokens.callout.lineHeight)
            .fontColor(ColorTokens.secondary)
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)
      }
      .width('100%')
      .padding({ left: SpaceTokens.sm, right: SpaceTokens.pageCompact, top: SpaceTokens.sm, bottom: SpaceTokens.item })

      Row() {
        // 排序分段（官方 SegmentButton）：标题栏生效区内浮起档材质接管表面
        ImmersiveSegmentBar({
          items: FEED_SEGMENTS,
          selectedIndex: $sortIndex,
          itemWidth: 64,
          overrideTrackMaterial: true,
          onSelect: (index: number): void => { this.switchSort(index); },
        })
        Blank()
        // 加入/退出圈子：这一整块确实挂在 .title({ builder })（见本文件 build 尾部），材质出图。
        // 但仍走描边而非让材质接管表面：ULTRA_THIN 在浅色栏面上只比画布亮 2 级（真机 253 vs 255），
        // 而 DesignButton 挂材质时会把自绘描边一并置 0（DesignButton.ets:103）—— 换来的那 2 级读不出来，
        // 按钮却没了可点性。描边才是这颗钮的实际表面。
        DesignButton({
          label: this.joined ? '退出圈子' : '加入圈子',
          variant: 'outlined',
          disabled: this.joining,
          useSystemMaterial: false,
          action: (): void => { this.toggleJoin(); },
        })
      }
      .width('100%')
      .padding({ left: SpaceTokens.pageCompact, right: SpaceTokens.pageCompact, bottom: SpaceTokens.sm })
      .alignItems(VerticalAlign.Center)
    }
    .width('100%')
    // ⚠️ 左内缩 64vp 让开官方返回键（stackBuilder 行是返回键 Button 的后兄弟、z 序更高，
    // 全宽可点会吃掉返回键——防漂移 31）
    .padding({ left: 64, top: SpaceTokens.xs, bottom: SpaceTokens.sm })
    .onAreaChange((_old: Area, area: Area): void => {
      const h: number = parseFloat(String(area.height));
      if (h > 0 && Math.abs(h - this.titleBarContentHeight) > 0.5) {
        this.titleBarContentHeight = h;
      }
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
              actionLabel: this.error ? '重试' : '',
              onAction: (): void => { this.refresh(); },
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
                    PostCard({ post: post, compact: true, onOpen: (): void => { this.openPost(post); } })
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
            .padding({ left: GRID_PADDING, right: GRID_PADDING, top: GRID_PADDING + this.circleListInset(), bottom: GRID_PADDING })
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