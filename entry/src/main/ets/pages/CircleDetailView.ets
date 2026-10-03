import { Post } from '../models/types';
import { followTag, listFollowedTags, listPosts, unfollowTag, trackPostEvent } from '../services/api';
import { getToken } from '../utils/auth';
import { openPostDetail, takeCircleDetailName } from '../utils/nav';
import { getMainNavStack, EmptyNavParams, PostDetailNavParams } from '../utils/navigationTransition';
import { observeGridColumns, gridColumnTemplate } from '../utils/responsive';
import { GRID_GAP, GRID_PADDING } from '../utils/cardTokens';
import { safeShowToast } from '../utils/toast';
import { PostCard } from '../components/PostCard';
import { TagIcon } from '../components/TagIcon';
import { DesignButton } from '../design/components/DesignButton';
import { EmptyState } from '../design/components/EmptyState';
import { SegmentedControl, SegmentedItem } from '../design/components/SegmentedControl';
import { BackButton } from '../design/components/BackButton';
import { Pressable } from '../design/motion/Pressable';
import { Reveal } from '../design/motion/Reveal';
import { ColorTokens } from '../design/tokens/color';
import { IconTokens } from '../design/tokens/icon';
import { RadiusTokens } from '../design/tokens/radius';
import { LayoutTokens, SpaceTokens } from '../design/tokens/space';
import { TypeTokens } from '../design/tokens/type';
import { isSystemMaterialActive } from '../utils/immersiveMaterial';
import { common } from '@kit.AbilityKit';

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
  @StorageLink('statusBarHeight') statusBarHeight: number = 0;
  // 标题栏（导航行 + 圈子信息行 + 最新/热门分段栏与加入圈子按钮）驻留 Navigation 标题栏 ——
  // uiMaterial 沉浸光感的官方生效区域；栏高由内容实测回写（首帧用估算兜底）。
  @State titleBarContentHeight: number = 0;
  private listVersion: number = 0;
  private unregisterColumns: () => void = () => {};

  // 统一返回入口：Navigation 壳走 onBack（navStack.pop），router 壳走普通返回
  private backAction(): void {
    if (this.onBack !== undefined) {
      this.onBack();
      return;
    }
    this.getUIContext().getRouter().back();
  }

  aboutToAppear(): void {
    this.circleName = takeCircleDetailName();
    this.unregisterColumns = observeGridColumns(
      this.getUIContext().getHostContext() as common.Context,
      (cols: number): void => {
        this.gridColumns = cols;
        this.gridTemplate = gridColumnTemplate(cols);
      }
    );
    this.init();
  }

  aboutToDisappear(): void {
    this.unregisterColumns();
  }

  private async init(): Promise<void> {
    if (this.circleName.length === 0) {
      this.error = '圈子信息已失效，请从圈子页重新进入';
      return;
    }
    // 帖子流对访客公开可浏览，未登录不拦截；加入/退出圈子时再做登录引导。
    await this.loadJoined();
    await this.refresh();
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

  private async refresh(): Promise<void> {
    const version = this.listVersion + 1;
    this.listVersion = version;
    this.page = 1;
    this.finished = false;
    this.error = '';
    this.posts = [];
    await this.fetch(true, version);
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
    // SegmentedControl 会先更新双向绑定的 sortIndex，再触发 onSelect。
    if (this.sortIndex !== index) {
      this.sortIndex = index;
    }
    this.refresh();
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

  // 标题栏：原页头整体驻留于此（导航行 + 圈子信息行 + 最新/热门分段栏与加入圈子按钮）。
  // 全屏沉浸式布局下标题栏不代为避让状态栏：由本 Builder 手动下移（与首页/搜索页标题栏同一写法）。
  @Builder
  circleTitleBar(): void {
    Column() {
      Row() {
        BackButton({ action: (): void => { this.backAction(); } })

        Blank()
        Text('圈子')
          .fontSize(TypeTokens.title.size).fontFamily(TypeTokens.fontFamilySerif)
          .fontWeight(TypeTokens.title.weight)
          .lineHeight(TypeTokens.title.lineHeight)
          .fontColor(ColorTokens.primary)
        Blank()
        Text('')
          .width(LayoutTokens.minTouchTarget)
          .height(LayoutTokens.minTouchTarget)
      }
      .width('100%')
      .padding({ left: SpaceTokens.pageCompact, right: SpaceTokens.pageCompact, top: SpaceTokens.md, bottom: SpaceTokens.sm })
      .alignItems(VerticalAlign.Center)

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
      .padding({ left: SpaceTokens.pageCompact, right: SpaceTokens.pageCompact, top: SpaceTokens.sm, bottom: SpaceTokens.item })

      Row() {
        SegmentedControl({
          items: FEED_SEGMENTS,
          selectedIndex: $sortIndex,
          itemWidth: 64,
          fillWidth: false,
          // 与首页/我的页标题栏同配置：材质生效时用描边底（透明，让系统材质完整透出）；
          // 低版本保留原「华为应用商店同款」沉浸玻璃 —— 它的 backdropBlur 会遮挡材质，二者互斥。
          immersive: !isSystemMaterialActive(),
          outlined: isSystemMaterialActive(),
          glowEnabled: false,
          // 沉浸光感：驻留标题栏，由系统材质接管整栏表面
          useSystemMaterial: true,
          onSelect: (index: number): void => { this.switchSort(index); },
        })
        Blank()
        // 加入/退出圈子：驻留标题栏，由系统材质接管按钮表面（低版本回退原描边样式）
        DesignButton({
          label: this.joined ? '退出圈子' : '加入圈子',
          variant: 'outlined',
          disabled: this.joining,
          useSystemMaterial: true,
          action: (): void => { this.toggleJoin(); },
        })
      }
      .width('100%')
      .padding({ left: SpaceTokens.pageCompact, right: SpaceTokens.pageCompact, bottom: SpaceTokens.sm })
      .alignItems(VerticalAlign.Center)
    }
    .width('100%')
    // 手动避让状态栏（含在栏高内），实测高度供 .title({ height }) 使用
    .padding({ top: this.statusBarHeight })
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
    Navigation() {
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
          Refresh({ refreshing: this.refreshing, builder: this.refreshBuilder }) {
            Grid() {
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
            .columnsTemplate(this.gridTemplate)
            .columnsGap(GRID_GAP)
            .rowsGap(GRID_GAP)
            .padding({ left: GRID_PADDING, right: GRID_PADDING, top: GRID_PADDING, bottom: GRID_PADDING })
            .onScrollIndex((_start: number, end: number) => {
              if (end >= this.posts.length - 1) {
                this.loadMore();
              }
            })
          }
          .onRefreshing(() => {
            this.refreshing = true;
            this.refresh().finally(() => { this.refreshing = false; });
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
    .title({
      builder: this.circleTitleBar,
      height: this.circleTitleBarHeight(),
    }, { barStyle: BarStyle.STANDARD, backgroundColor: ColorTokens.canvas })
    .width('100%')
    .height('100%')
  }
}