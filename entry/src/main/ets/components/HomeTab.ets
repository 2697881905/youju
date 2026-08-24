// 首页 feed（真实内容）：顶栏(三子Tab+搜索框同水平) + 标签筛选 + 帖子网格
// 搜索框获焦时展示 SearchPanel（搜索历史+热搜词），提交或选中关键词后跳结果页
// 数据来源：listPosts / listTags / recordSearchHistory（services/api.ets）

import { DailyPost, Post, Tag } from '../models/types';
import { listDailyPosts, listPosts, listFollowingPosts, listTags, listFollowedTags, recordSearchHistory, getUserProfile } from '../services/api';
import { getUserId } from '../utils/auth';
import { likeStore } from '../utils/likeStore';
import { postDeletionStore } from '../utils/postDeletionStore';
import { PostCard } from './PostCard';
import { TagNav } from './TagNav';
import { SearchPanel } from './SearchPanel';
import { emitTabSwitch, openPostDetail, openSearch } from '../utils/nav';
import { safeShowToast } from '../utils/toast';
import { resolveActionIcon } from '../utils/actionIcons';
import { EmptyState } from '../design/components/EmptyState';
import { SegmentedControl, SegmentedItem } from '../design/components/SegmentedControl';
import { Pressable } from '../design/motion/Pressable';
import { Reveal } from '../design/motion/Reveal';
import { DailyPostDeck } from './DailyPostDeck';
import { ColorTokens } from '../design/tokens/color';
import { IconTokens } from '../design/tokens/icon';
import { MotionCurves, MotionTokens } from '../design/tokens/motion';
import { RadiusTokens } from '../design/tokens/radius';
import { LayoutTokens, SpaceTokens } from '../design/tokens/space';
import { TypeTokens } from '../design/tokens/type';
import { common } from '@kit.AbilityKit';
import { BasicDataSource } from '../utils/data-source';
import { observeGridColumns, gridColumnTemplate } from '../utils/responsive';
import { barBottomReserve } from '../utils/cardTokens';
import { hilog } from '@kit.PerformanceAnalysisKit';

type SortKey = 'hot' | 'latest' | 'recommend';
type FeedMode = 'recommend' | 'following' | 'daily';

// FeedMode → 分段索引 的映射（用于顶栏 ForEach 选中态比较）
const FEED_MODE_IDX_MAP: FeedMode[] = ['recommend', 'following', 'daily'];

// 自动重试上限：避免真机连不上后端时无限重试 → 首页永久「加载中…」转圈。
// 超限后停止重试并展示明确「加载失败」错误态，由用户手动点重试。
const FEED_MAX_RETRY: number = 3;
const TAGS_MAX_RETRY: number = 3;

const SORT_KEYS: SortKey[] = ['hot', 'latest', 'recommend'];
const FEED_SEGMENTS: SegmentedItem[] = [
  { key: 'recommend', label: '推荐' },
  { key: 'following', label: '关注' },
  { key: 'daily', label: '每日一帖' },
];
const ALL_TAG: Tag = { name: '全部' };

@Component
export struct HomeTab {
  @State posts: DailyPost[] = [];
  private postSource: BasicDataSource<Post> = new BasicDataSource<Post>();
  @State displayTags: Tag[] = [];
  @State tagsLoaded: boolean = false;
  @State sortIndex: number = 0;
  @State @Watch('onTagChanged') tagIndex: number = 0;
  @State page: number = 1;
  @State loading: boolean = false;
  @State finished: boolean = false;
  @State isRefreshing: boolean = false;
  @State error: string = '';
  @State showPanel: boolean = false;
  @State feedMode: FeedMode = 'recommend';
  @State feedIndex: number = 0;
  @State needLogin: boolean = false; // 关注流且未登录的引导态
  @State followingCount: number = 0; // 关注流的关注数缓存（空态 A/B 区分）
  @State dailyDeckVersion: number = 0;
  // 监听登录态：登录成功后 authToken 就绪，若处于关注流且列表空则自动补加载
  @StorageLink('authToken') @Watch('onTokenReady') token: string = '';
  // 监听登录账号：切换账号（老张↔小美互测）或登出时，清空点赞缓存并重建首页 feed，
  // 否则 PostCard 实例被 LazyForEach 复用不重建、likeStore 单例残留上个账号的 liked/upCount，点赞态串号。
  @StorageLink('authUserId') @Watch('onAccountSwitch') accountId: string = '';
  // 监听当前激活的 Tab：切回首页（index=0）时，若标签仍停留在失败兜底态，自动重试恢复
  @StorageLink('activeTab') @Watch('onHomeActive') homeActive: number = 0;
  // 圈子加入/退出后重排顶部标签栏，让已加入的圈子优先展示。
  @StorageLink('circleMembershipVersion') @Watch('onCircleMembershipChanged') circleMembershipVersion: number = 0;
  // 发布成功后刷新首页，确保从发布页返回时新帖立即进入信息流。
  @StorageLink('postPublishVersion') @Watch('onPostPublished') postPublishVersion: number = 0;
  // 响应式列数（按屏幕宽度 2/3/4 列自适应）+ 对应的 columnsTemplate 字符串
  @State gridColumns: number = 2;
  @State gridTemplate: string = '1fr 1fr';
  private unregisterColumns: () => void = () => {};
  // 订阅帖子删除事件：详情页删除后，首页 feed 即时移除该帖（不依赖刷新/切流）
  private unsubDeletion: () => void = () => {};
  // 标签自愈重试定时器句柄（0 表示未挂起）；避免一次性加载失败后标签栏永久卡在「全部」
  private tagsRetryTimer: number = 0;
  // 模拟器启动时后端端口转发可能尚未就绪，信息流失败后自动补拉一次。
  private feedRetryTimer: number = 0;
  private feedRetryCount: number = 0; // 连接错误自动重试计数（防无限重试）
  private tagsRetryCount: number = 0; // 标签加载自愈重试计数（防无限重试）

  aboutToAppear(): void {
    this.loadTags();
    // 注册响应式列数监听（折叠屏/平板/旋转时实时调整卡片列数）
    this.unregisterColumns = observeGridColumns(
      this.getUIContext().getHostContext() as common.Context,
      (cols: number): void => {
        this.gridColumns = cols;
        this.gridTemplate = gridColumnTemplate(cols);
      }
    );
    // 默认加载推荐公开流（无需登录）；若已登录也保持推荐流默认
    this.refresh();
    // 订阅帖子删除事件：删除后即时从 feed 移除，避免已删帖子残留在内存列表
    this.unsubDeletion = postDeletionStore.subscribe((deletedId: number): void => {
      this.posts = this.posts.filter((p: DailyPost) => p.id !== deletedId);
    });
  }

  aboutToDisappear(): void {
    this.unregisterColumns();
    this.unsubDeletion();
    if (this.tagsRetryTimer !== 0) {
      clearTimeout(this.tagsRetryTimer);
      this.tagsRetryTimer = 0;
    }
    if (this.feedRetryTimer !== 0) {
      clearTimeout(this.feedRetryTimer);
      this.feedRetryTimer = 0;
    }
  }

  // token 由空变为非空（登录完成）→ 关注流且列表空、无 error 时自动补加载
  onTokenReady(): void {
    if (this.token !== '' && this.posts.length === 0 && (this.feedMode === 'following' || this.error !== '')) {
      this.refresh();
    }
  }

  // 账号切换/登出：清空点赞缓存，先清空数据源（销毁旧 PostCard）→ 重拉（新账号的 myUp/upCount 重新灌入）
  onAccountSwitch(): void {
    likeStore.clear();
    this.postSource.clearData();
    this.posts = [];
    this.refresh();
  }

  // 切回首页：若标签仍停留在失败兜底态（仅「全部」），自动重试，避免一次性加载失败后被卡死
  onHomeActive(): void {
    if (this.homeActive === 0 && !this.tagsLoaded) {
      this.loadTags();
    }
  }

  onPostPublished(): void {
    this.postSource.clearData();
    this.posts = [];
    this.refresh();
  }

  // 判断是否为网络连接类失败（后端未起 / hdc rport 未建立 / 启动竞态）
  private isConnError(msg: string): boolean {
    const m: string = msg.toLowerCase();
    return m.includes('connect') || m.includes('refused') || m.includes('econnrefused') ||
      m.includes('unreachable') || m.includes('timed out') || m.includes('network') ||
      m.includes('无法连接后端');
  }

  private delay(ms: number): Promise<void> {
    return new Promise<void>((resolve: () => void): void => {
      setTimeout(resolve, ms);
    });
  }

  private sortTagsByMembership(tags: Tag[], followedNames: string[]): Tag[] {
    const followedOrder: Map<string, number> = new Map();
    followedNames.forEach((name: string, index: number) => followedOrder.set(name, index));
    return [...tags].sort((first: Tag, second: Tag): number => {
      const firstOrder: number | undefined = followedOrder.get(first.name ?? '');
      const secondOrder: number | undefined = followedOrder.get(second.name ?? '');
      if (firstOrder !== undefined && secondOrder !== undefined) {
        return firstOrder - secondOrder;
      }
      if (firstOrder !== undefined) {
        return -1;
      }
      if (secondOrder !== undefined) {
        return 1;
      }
      return 0;
    });
  }

  // 单次拉取标签：成功返回 true（已写入 displayTags），失败返回 false（兜底为 [ALL_TAG]）
  private async fetchTagsOnce(): Promise<boolean> {
    const MAX = 3;
    let lastErr: Error | null = null;
    for (let attempt = 1; attempt <= MAX; attempt++) {
      try {
        const tags = await listTags();
        if (!Array.isArray(tags)) {
          throw new Error('标签接口返回格式异常（非数组）');
        }
        // 后端启动/种子初始化期间可能暂时返回空数组；不要把它当成成功，
        // 否则标签栏会永久停留在“全部”，错过后续自动重试。
        if (tags.length === 0) {
          throw new Error('标签列表为空');
        }
        const previousSelectedName: string | undefined = this.currentTag();
        let followedNames: string[] = [];
        if (this.token !== '') {
          followedNames = await listFollowedTags();
        }
        const orderedTags: Tag[] = this.sortTagsByMembership(tags, followedNames);
        this.displayTags = [ALL_TAG, ...orderedTags];
        if (previousSelectedName !== undefined) {
          const selectedIndex: number = this.displayTags.findIndex((tag: Tag) => tag.name === previousSelectedName);
          this.tagIndex = selectedIndex >= 0 ? selectedIndex : 0;
        }
        hilog.info(0x0000, 'HomeTab', 'loadTags ok, 圈子数=%{public}d', (tags as Tag[]).length);
        return true;
      } catch (e) {
        lastErr = e as Error;
        const msg: string = lastErr.message ?? '未知错误';
        hilog.warn(0x0000, 'HomeTab', 'loadTags 第%{public}d次失败: %{public}s', attempt, msg);
        // 仅网络类错误重试（后端/端口转发未就绪的启动竞态），其余错误直接放弃
        if (attempt < MAX && (this.isConnError(msg) || msg.includes('标签列表为空'))) {
          await this.delay(1000);
          continue;
        }
        break;
      }
    }
    // 全部重试仍失败：保留 “全部”，但把错误暴露出来便于排查
    this.displayTags = [ALL_TAG];
    const msg: string = lastErr?.message ?? '未知错误';
    hilog.error(0x0000, 'HomeTab', 'loadTags 最终失败: %{public}s', msg);
    safeShowToast(this.getUIContext(), { message: '圈子标签加载失败：' + msg });
    return false;
  }

  async loadTags(): Promise<void> {
    const ok: boolean = await this.fetchTagsOnce();
    if (ok) {
      this.tagsLoaded = true;
    } else {
      this.tagsLoaded = false;
      // 自愈：挂起延迟重试（约 4s），后端恢复后兜底态自动解除；用句柄防重入 + 次数上限防无限重试
      if (this.tagsRetryCount < TAGS_MAX_RETRY && this.tagsRetryTimer === 0) {
        this.tagsRetryCount += 1;
        this.tagsRetryTimer = setTimeout((): void => {
          this.tagsRetryTimer = 0;
          this.loadTags();
        }, 4000) as number;
      }
    }
  }

  // 重置并加载第一页
  async refresh(): Promise<void> {
    this.page = 1;
    this.finished = false;
    this.followingCount = 0; // 重置关注流空态缓存
    this.feedRetryCount = 0; // 手动刷新/切换信息源时重置重试计数
    await this.fetch(true);
  }

  // 追加下一页
  async loadMore(): Promise<void> {
    if (this.finished || this.loading || this.isRefreshing) {
      return;
    }
    this.page += 1;
    await this.fetch(false);
  }

  onTagChanged(): void {
    this.refresh();
  }

  onCircleMembershipChanged(): void {
    if (this.token !== '') {
      this.loadTags();
    }
  }

  private currentTag(): string | undefined {
    return this.tagIndex > 0 ? this.displayTags[this.tagIndex]?.name : undefined;
  }

  private useCircleBarOverlap(): boolean {
    // 圈子栏仅推荐流显示；关注流/每日一帖均不显示（关注页顶部保持干净）
    return this.feedMode === 'recommend';
  }

  private feedTopSpacerIndices(): number[] {
    const indices: number[] = [];
    if (this.useCircleBarOverlap()) {
      for (let index: number = 0; index < this.gridColumns; index++) {
        indices.push(index);
      }
    }
    return indices;
  }

  private feedTopSpacerHeight(): number {
    return LayoutTokens.segmentedHeight + SpaceTokens.xs;
  }

  // 切换信息源：推荐 / 关注 / 每日一帖
  private switchFeed(mode: FeedMode): void {
    const nextIndex: number = FEED_MODE_IDX_MAP.indexOf(mode);
    if (nextIndex >= 0) {
      this.feedIndex = nextIndex;
    }
    if (this.feedMode !== mode) {
      this.feedMode = mode;
      this.needLogin = (mode === 'following' && this.token === '');
      this.refresh();
    }
  }

  private async fetch(reset: boolean): Promise<void> {
    if (this.loading) {
      return;
    }
    // 关注流且未登录：不发起请求，展示登录引导态
    if (this.feedMode === 'following' && this.token === '') {
      this.needLogin = true;
      this.posts = []; // 清空上一流（推荐流）残留内容
      this.postSource.clearData();
      return;
    }
    this.loading = true;
    this.error = '';
    this.needLogin = false; // 进入真正的拉取流程，复位登录引导态
    const sort = SORT_KEYS[this.sortIndex];
    try {
      if (this.feedMode === 'daily') {
        const res = await listDailyPosts(this.page, 10);
        if (reset) {
          this.posts = res.list;
          this.postSource.clearData();
          this.dailyDeckVersion += 1;
        } else {
          this.posts = this.posts.concat(res.list);
        }
        this.finished = this.posts.length >= res.pagination.total;
        return;
      }
      const res =
        this.feedMode === 'following'
          ? await listFollowingPosts({ page: this.page, limit: 20, sort, tag: this.currentTag() })
          : await listPosts({ page: this.page, limit: 20, sort, tag: this.currentTag() });
      if (reset) {
        this.posts = res.list;
        this.postSource.setData(res.list);
      } else {
        this.posts = this.posts.concat(res.list);
        this.postSource.appendData(res.list);
      }
      if (res.list.length < 20) {
        this.finished = true;
      }
      // 关注流空列表：异步取 followingCount 用于空态 A/B 区分（不阻塞渲染）
      if (this.feedMode === 'following' && res.list.length === 0 && this.token !== '') {
        this.loadFollowingCount();
      }
    } catch (e) {
      this.error = (e as Error).message;
      if (this.isConnError(this.error) && this.feedRetryCount < FEED_MAX_RETRY && this.feedRetryTimer === 0) {
        this.feedRetryCount += 1;
        this.feedRetryTimer = setTimeout((): void => {
          this.feedRetryTimer = 0;
          this.refresh();
        }, 1500) as number;
      }
    } finally {
      this.loading = false;
    }
  }

  // 取当前用户的关注数（关注流空态 A/B 区分：0→未关注任何人，>0→关注的人未发帖）
  private async loadFollowingCount(): Promise<void> {
    try {
      const id: number = getUserId();
      if (id === 0) {
        this.followingCount = 0;
        return;
      }
      const profile = await getUserProfile(id);
      this.followingCount = profile.followingCount;
    } catch (e) {
      // 计数失败不阻断，默认按空态 A 处理
      this.followingCount = 0;
    }
  }

  // 搜索：校验关键词 → 隐藏面板 → 跳结果页 → 记录历史（fire-and-forget）
  private doSearch(raw: string): void {
    const kw = raw.trim();
    if (!kw) {
      safeShowToast(this.getUIContext(),{ message: '请输入搜索内容' });
      return;
    }
    this.showPanel = false;
    openSearch(kw);
    this.getUIContext().getRouter().pushUrl({ url: 'pages/SearchResultPage' });
    // fire-and-forget：记录搜索历史，失败不阻断
    this.recordHistoryAsync(kw);
  }

  // 异步记录搜索历史（独立方法，避免阻塞搜索跳转）
  private async recordHistoryAsync(kw: string): Promise<void> {
    try {
      await recordSearchHistory(kw);
    } catch (e) {
      // 记录历史失败不影响搜索体验
    }
  }

  // SearchPanel 关键词选中回调：触发搜索
  private onKeywordSelect(kw: string): void {
    this.doSearch(kw);
  }

  @Builder
  refreshBuilder(): void {
    Row({ space: SpaceTokens.inline }) {
      LoadingProgress().width(IconTokens.compact).height(IconTokens.compact)
      Text('刷新中…')
        .fontSize(TypeTokens.caption.size).fontFamily(TypeTokens.fontFamily)
        .fontWeight(TypeTokens.caption.weight)
        .lineHeight(TypeTokens.caption.lineHeight)
        .letterSpacing(TypeTokens.caption.tracking)
        .fontColor(ColorTokens.secondary)
    }
  }

  // footer 是 WaterFlow 的真实滚动内容。不能只用 padding.bottom，Refresh 嵌套时会被裁切，
  // 造成最后一张卡片无法滑到悬浮底栏下方。
  @Builder
  feedFooter(): void {
    Column() {
      if (this.finished) {
        Text('没有更多了')
          .fontSize(TypeTokens.caption.size).fontFamily(TypeTokens.fontFamily)
          .fontWeight(TypeTokens.caption.weight)
          .lineHeight(TypeTokens.caption.lineHeight)
          .letterSpacing(TypeTokens.caption.tracking)
          .fontColor(ColorTokens.tertiary)
          .width('100%')
          .textAlign(TextAlign.Center)
          .padding(SpaceTokens.base)
      }
      Blank()
        .width('100%')
        .height(barBottomReserve())
    }
    .width('100%')
  }

  build() {
    Column() {
      if (this.showPanel) {
        // 全屏搜索面板：自带 < 返回 + 输入框 + 搜索 头部栏，隐藏首页推荐/关注顶栏
        SearchPanel({
          onKeywordSelect: (kw: string): void => {
            this.onKeywordSelect(kw);
          },
          onCancel: (): void => {
            this.showPanel = false;
          }
        })
          .layoutWeight(1)
          .transition(TransitionEffect.OPACITY
            .animation({ duration: MotionTokens.base, curve: MotionCurves.decelerate })
            .combine(TransitionEffect.translate({ x: '100%' })
              .animation({ duration: MotionTokens.slow, curve: MotionCurves.decelerate })))
      } else {
        // 标题和搜索固定在两侧，信息源分段作为独立中心层，避免被两侧内容挤向左侧。
        Stack({ alignContent: Alignment.Center }) {
          Row() {
            Text('有据')
              .fontSize(TypeTokens.title.size).fontFamily(TypeTokens.fontFamilySerif)
              .fontWeight(TypeTokens.title.weight)
              .lineHeight(TypeTokens.title.lineHeight)
              .letterSpacing(TypeTokens.title.tracking)
              .fontColor(ColorTokens.primary)
            Blank()
            Pressable({
              visualHeight: LayoutTokens.segmentedHeight,
              touchTargetHeight: LayoutTokens.minTouchTarget,
              action: (): void => {
                this.showPanel = true;
              },
            }) {
              Row() {
                Image(resolveActionIcon('search'))
                  .width(IconTokens.compact)
                  .height(IconTokens.compact)
              }
              .width(LayoutTokens.segmentedHeight)
              .height(LayoutTokens.segmentedHeight)
              .border({ width: LayoutTokens.glassBorderWidth, color: ColorTokens.barBorder, style: BorderStyle.Solid })
              .borderRadius(RadiusTokens.lg)
              .shadow({ radius: 10, color: ColorTokens.barShadow, offsetY: 4 })
              .justifyContent(FlexAlign.Center)
              .alignItems(VerticalAlign.Center)
              .accessibilityText('搜索')
            }
          }
          .width('100%')
          .alignItems(VerticalAlign.Center)

          SegmentedControl({
            items: FEED_SEGMENTS,
            selectedIndex: $feedIndex,
            itemWidth: 66,
            fillWidth: false,
            glass: true,
            onSelect: (idx: number): void => {
              const mode: FeedMode = FEED_MODE_IDX_MAP[idx];
              this.switchFeed(mode);
            },
          })
        }
        .padding({
          left: SpaceTokens.sm,
          right: SpaceTokens.sm,
          top: SpaceTokens.xs,
          bottom: SpaceTokens.xs,
        })
        .width('100%')
        .backgroundColor(ColorTokens.canvas)
        .zIndex(1000)

        // 列表区与圈子栏共用同一 Stack，圈子栏始终作为玻璃浮层而不参与列表排版。
        Stack({ alignContent: Alignment.TopStart }) {
        if (this.needLogin) {
          // 未登录引导态（关注流且未登录）：不发起请求，引导登录
          Column() {
            EmptyState({
              icon: resolveActionIcon('lock'),
              title: '登录后查看你关注的人发布的帖子',
              message: '关注的人发了什么，这里第一时间看到',
              actionLabel: '登录',
              onAction: (): void => {
                this.getUIContext().getRouter().pushUrl({ url: 'pages/LoginPage' });
              },
            })
          }
          .width('100%')
          .height('100%')
          .justifyContent(FlexAlign.Center)
        } else if (this.posts.length === 0 && this.loading) {
          Column() {
            LoadingProgress().width(IconTokens.empty).height(IconTokens.empty)
            Text('加载中…')
              .fontSize(TypeTokens.callout.size).fontFamily(TypeTokens.fontFamily)
              .fontWeight(TypeTokens.callout.weight)
              .lineHeight(TypeTokens.callout.lineHeight)
              .letterSpacing(TypeTokens.callout.tracking)
              .fontColor(ColorTokens.secondary)
              .margin({ top: SpaceTokens.md })
          }
          .width('100%')
          .height('100%')
          .justifyContent(FlexAlign.Center)
        } else if (this.posts.length === 0) {
          Column() {
            if (this.error) {
              EmptyState({
                icon: resolveActionIcon('warning'),
                title: '加载失败',
                message: this.error,
                actionLabel: '重试',
                onAction: (): void => { this.refresh(); },
              })
            } else if (this.feedMode === 'following') {
              // 关注流空态 A/B 区分：按 followingCount 判定
              if (this.followingCount === 0) {
                // 空态 A：未关注任何人
                EmptyState({
                  icon: resolveActionIcon('guide'),
                  title: '你还没有关注任何人',
                  message: '去发现有趣的人，关注后这里就有内容',
                  actionLabel: '去发现',
                  onAction: (): void => {
                    emitTabSwitch(1);
                  },
                })
              } else {
                // 空态 B：关注了人但无人发帖
                EmptyState({
                  icon: resolveActionIcon('inbox'),
                  title: '你关注的人还没有发布内容',
                  message: '去他们的主页催更吧',
                })
              }
            } else if (this.feedMode === 'daily') {
              EmptyState({
                icon: resolveActionIcon('book'),
                title: '今日一帖正在准备',
                message: '这里会精选每天最值得讨论的一条内容',
              })
            } else {
              EmptyState({
                icon: resolveActionIcon('inbox'),
                title: '暂无内容',
                message: '内容出现后会显示在这里',
              })
            }
          }
          .width('100%')
          .height('100%')
          .justifyContent(FlexAlign.Center)
        } else {
          if (this.feedMode === 'daily') {
            Refresh({ refreshing: this.isRefreshing, builder: this.refreshBuilder }) {
              DailyPostDeck({
                deckVersion: this.dailyDeckVersion,
                posts: this.posts,
                loading: this.loading,
                finished: this.finished,
                onLoadMore: (): void => { this.loadMore(); },
                onOpen: (post: DailyPost): void => {
                  if (post.id !== undefined) {
                    openPostDetail(post.id.toString());
                    this.getUIContext().getRouter().pushUrl({ url: 'pages/DetailPage' });
                  }
                },
              })
                .width('100%')
                .height('100%')
            }
            .onRefreshing(() => {
              this.isRefreshing = true;
              this.refresh().finally(() => {
                this.isRefreshing = false;
              });
            })
            .width('100%')
            .height('100%')
          } else {
          Stack({ alignContent: Alignment.TopStart }) {
            Refresh({ refreshing: this.isRefreshing, builder: this.refreshBuilder }) {
              // 瀑布流：每列独立流动，卡片仅以 rowsGap 与同列上下卡片贴靠，
              // 彻底消除 Grid 等高行造成的「矮卡片底部留白」问题
              WaterFlow({ footer: this.feedFooter }) {
                // 每列首位的可滚动占位项让首屏卡片从圈子栏下方开始；
                // 它随内容一起上移，避免 WaterFlow 固定 padding 形成硬裁切带。
                ForEach(this.feedTopSpacerIndices(), (_value: number, index: number) => {
                  FlowItem() {
                    Column()
                      .width('100%')
                      .height(this.feedTopSpacerHeight())
                  }
                }, (_value: number, index: number) => 'circle_bar_spacer_' + index)
                LazyForEach(
                  this.postSource,
                  (post: Post, idx: number) => {
                    FlowItem() {
                      Reveal({ index: idx % 5 }) {
                        PostCard({
                          post: post,
                          compact: true,
                          onOpen: () => {
                            if (post.id !== undefined) {
                              const id = post.id.toString();
                              openPostDetail(id);
                              this.getUIContext().getRouter().pushUrl({ url: 'pages/DetailPage' });
                            }
                          },
                        })
                      }
                    }
                  },
                  (post: Post, idx: number) => (post.id ?? idx).toString()
                )
              }
              .columnsTemplate(this.gridTemplate)
              .columnsGap(SpaceTokens.xs)
              .rowsGap(SpaceTokens.xs)
              .padding({
                left: SpaceTokens.sm,
                right: SpaceTokens.sm,
                bottom: SpaceTokens.md,
              })
              .onScrollIndex((_start: number, end: number) => {
                if (end - this.feedTopSpacerIndices().length >= this.posts.length - 1) {
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
            .width('100%')
            .height('100%')
          }
          .width('100%')
          .height('100%')
          .clip(true)
          }
        }
        if (this.useCircleBarOverlap()) {
          TagNav({
            tags: this.displayTags,
            selectedIndex: $tagIndex,
            compact: true,
            glass: true,
          })
          .padding({ bottom: SpaceTokens.xs })
          .zIndex(999)
        }
        }
        .layoutWeight(1)
        .width('100%')
      }
    }
    .width('100%')
    .height('100%')
    .alignItems(HorizontalAlign.Start)
    .backgroundColor(ColorTokens.canvas)
  }
}
