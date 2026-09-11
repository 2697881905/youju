// 首页 feed（真实内容）：顶栏(三子Tab+搜索框同水平) + 标签筛选 + 帖子网格
// 首页 Tab：海报式编辑部头部 + 推荐/关注/每日一帖信息流。
// 数据来源：listPosts / listTags / listDailyPosts（services/api.ets）
// 搜索入口跳转独立搜索页 pages/SearchPanelPage（搜索面板已与首页解耦）。

import { DailyPost, Post, Tag } from '../models/types';
import { listDailyPosts, listPosts, listFollowingPosts, listTags, listFollowedTags, getUserProfile, trackPostEvent } from '../services/api';
import { getUserId } from '../utils/auth';
import { likeStore } from '../utils/likeStore';
import { postDeletionStore } from '../utils/postDeletionStore';
import { PostCard } from './PostCard';
import { TagNav } from './TagNav';
import { emitTabSwitch, openPostDetail } from '../utils/nav';
import { safeShowToast } from '../utils/toast';
import { resolveActionIcon } from '../utils/actionIcons';
import { EmptyState } from '../design/components/EmptyState';
import { SegmentedControl, SegmentedItem } from '../design/components/SegmentedControl';
import { Pressable } from '../design/motion/Pressable';
import { DailyPostDeck } from './DailyPostDeck';
import { ColorTokens } from '../design/tokens/color';
import { IconTokens } from '../design/tokens/icon';
import { MotionCurves, MotionTokens } from '../design/tokens/motion';
import { RadiusTokens } from '../design/tokens/radius';
import { LayoutTokens, SpaceTokens } from '../design/tokens/space';
import { TypeTokens } from '../design/tokens/type';
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
// 今日一帖每日精选篇数固定为 10 条（一次拉齐，读完即完成态）
const DAILY_PICK_LIMIT: number = 10;

const SORT_KEYS: SortKey[] = ['hot', 'latest', 'recommend'];
const FEED_SEGMENTS: SegmentedItem[] = [
  { key: 'recommend', label: '推荐' },
  { key: 'following', label: '关注' },
  { key: 'daily', label: '每日一帖' },
];

// —— 每日一帖刊期 ——
// 首期日（Asia/Shanghai）：2026-09-11 即 No.001；之后每个自然日 +1 期，跨年不重置。
// 计日统一按北京时间（UTC+8），与后端 dailyKey 的 Asia/Shanghai 口径一致，设备处于任意时区均不偏移。
const DAILY_ISSUE_ORIGIN: string = '2026-09-11';
const DAILY_TZ_OFFSET_MS: number = 8 * 60 * 60 * 1000;

// —— 会话级信息流缓存：切 Tab 回来先展示缓存再后台刷新，避免白屏重拉（P2 性能优化）——
// key = feedMode|tag|sort；仅缓存首屏（page=1），TTL 120s；账号切换/发帖后整体失效
interface FeedCacheEntry {
  posts: DailyPost[];
  at: number;
}
const FEED_CACHE_TTL: number = 120000;
const feedSessionCache: Map<string, FeedCacheEntry> = new Map<string, FeedCacheEntry>();
const ALL_TAG: Tag = { name: '全部' };

@Component
export struct HomeTab {
  @State posts: DailyPost[] = [];
  @State displayTags: Tag[] = [];
  @State tagsLoaded: boolean = false;
  @State sortIndex: number = 0;
  @State @Watch('onTagChanged') tagIndex: number = 0;
  @State page: number = 1;
  @State loading: boolean = false;
  @State finished: boolean = false;
  @State isRefreshing: boolean = false;
  @State error: string = '';
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
  // 曝光埋点去重集合：同一帖子只上报一次 expose（避免列表复用重复计数）
  private exposedIds: Set<number> = new Set<number>();
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
    // 默认加载推荐公开流（无需登录）；若已登录也保持推荐流默认
    this.refresh();
    // 订阅帖子删除事件：删除后即时从 feed 移除，避免已删帖子残留在内存列表
    this.unsubDeletion = postDeletionStore.subscribe((deletedId: number): void => {
      this.posts = this.posts.filter((p: DailyPost) => p.id !== deletedId);
    });
  }

  aboutToDisappear(): void {
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
    this.posts = [];
    feedSessionCache.clear(); // 新帖发布后旧缓存失效
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

  // 信息流缓存 key：feedMode|tag|sort（每日一帖不缓存）
  private feedCacheKey(): string {
    return this.feedMode + '|' + (this.currentTag() ?? '') + '|' + SORT_KEYS[this.sortIndex];
  }

  private useCircleBarOverlap(): boolean {
    // 圈子栏仅推荐流显示；关注流/每日一帖均不显示（关注页顶部保持干净）
    return this.feedMode === 'recommend';
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
      return;
    }
    this.loading = true;
    this.error = '';
    this.needLogin = false; // 进入真正的拉取流程，复位登录引导态
    const sort = SORT_KEYS[this.sortIndex];
    // P2 会话缓存：recent 切回首屏时若缓存命中且未过期，先渲染缓存（不白屏），请求成功后再覆盖
    if (reset && this.feedMode !== 'daily') {
      const cacheKey: string = this.feedCacheKey();
      const cached: FeedCacheEntry | undefined = feedSessionCache.get(cacheKey);
      if (cached !== undefined && Date.now() - cached.at < FEED_CACHE_TTL && cached.posts.length > 0) {
        this.posts = cached.posts;
      }
    }
    try {
      if (this.feedMode === 'daily') {
        // 今日一帖：每日精选固定 10 条一次拉齐，不随滚动追加。
        // 读完精选即进入完成态（对齐原型「每日唯一内容」的仪式感）。
        const res = await listDailyPosts(1, DAILY_PICK_LIMIT);
        this.posts = res.list;
        this.finished = true;
        if (reset) {
          this.dailyDeckVersion += 1;
        }
        // 后端若不足 10 条（数据库文章少），按实际条数展示，避免出现「只有 3 张卡却显示 01/10」
        hilog.info(0x0000, 'HomeTab', 'daily posts fetched, list=%{public}d, total=%{public}d',
          res.list.length, res.pagination.total);
        return;
      }
      const res =
        this.feedMode === 'following'
          ? await listFollowingPosts({ page: this.page, limit: 20, sort, tag: this.currentTag() })
          : await listPosts({ page: this.page, limit: 20, sort, tag: this.currentTag() });
      if (reset) {
        this.posts = res.list;
        // 写回会话缓存（仅首屏，供切 Tab 回来快速呈现）
        feedSessionCache.set(this.feedCacheKey(), { posts: res.list, at: Date.now() });
      } else {
        this.posts = this.posts.concat(res.list);
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

  // 每日一帖报头：日期/星期/期数 + 发丝分隔线（品牌标题已被顶部栏承担，不再重复）
  // 对应原型 masthead 的 date-row / rule；期数 = 真实刊期（首期日 2026-09-11 为 No.001）。
  @Builder
  dailyMasthead(): void {
    Column({ space: SpaceTokens.md }) {
      Row() {
        Row({ space: SpaceTokens.sm }) {
          Text(this.dailyDateStr())
            .fontSize(21).fontFamily(TypeTokens.fontFamilySerif)
            .fontWeight(TypeTokens.titleSerif.weight)
            .letterSpacing(1)
            .fontColor(ColorTokens.primary)
          Text(this.dailyWeekStr())
            .fontSize(12).fontFamily(TypeTokens.fontFamily)
            .letterSpacing(2)
            .fontColor(ColorTokens.tertiary)
        }
        .alignItems(VerticalAlign.Bottom)
        Blank()
        Text('No.' + this.dailyIssueStr())
          .fontSize(12).fontFamily(TypeTokens.fontFamily)
          .fontWeight(TypeTokens.overline.weight)
          .letterSpacing(2)
          .fontColor(ColorTokens.brand)
      }
      .width('100%')
      .alignItems(VerticalAlign.Bottom)

      // 发丝分隔线（与报头文字拉开间距，形成明确的编辑部头版层次）
      Row()
        .width('100%')
        .height(1)
        .backgroundColor(ColorTokens.separator)
    }
    .width('100%')
    .padding({ left: SpaceTokens.md, right: SpaceTokens.md, top: SpaceTokens.sm, bottom: SpaceTokens.sm })
    // 切换进每日一帖时整块入场（减速淡入 + 轻微下落）
    .transition(TransitionEffect.OPACITY
      .animation({ duration: 450, curve: MotionCurves.decelerate })
      .combine(TransitionEffect.translate({ y: -8 })
        .animation({ duration: 450, curve: MotionCurves.decelerate })))
  }

  // 报头「当日」口径 = 北京时间（UTC+8）：与刊期同源，避免设备时区非 +8 时日期栏与期号跨天。
  // 实现：时间戳加 8 小时后取 UTC 字段，等价于北京时间本地字段。
  private shanghaiNow(): Date {
    return new Date(Date.now() + DAILY_TZ_OFFSET_MS);
  }

  private dailyDateStr(): string {
    const d: Date = this.shanghaiNow();
    return d.getUTCFullYear() + '年' + (d.getUTCMonth() + 1) + '月' + d.getUTCDate() + '日';
  }

  private dailyWeekStr(): string {
    const d: Date = this.shanghaiNow();
    return '星期' + ['日', '一', '二', '三', '四', '五', '六'][d.getUTCDay()];
  }

  // 真实刊期：首期日（DAILY_ISSUE_ORIGIN）为 No.001，此后按北京时间自然日连续递增，跨年不重置。
  // 天数差用「日序数」相减（不受时分秒/夏令时影响）；早于首期日（理论不会发生）兜底 No.001。
  private dailyIssueStr(): string {
    const parts: string[] = DAILY_ISSUE_ORIGIN.split('-');
    const originDay: number = Math.floor(
      Date.UTC(Number(parts[0]), Number(parts[1]) - 1, Number(parts[2])) / 86400000
    );
    const todayDay: number = Math.floor((Date.now() + DAILY_TZ_OFFSET_MS) / 86400000);
    const issue: number = Math.max(1, todayDay - originDay + 1);
    return String(issue).padStart(3, '0');
  }

  // 推荐/关注流单卡：PostCard + 曝光埋点（卡片出现在屏幕上即上报，去重跳过）。
  // idx 为该卡在其分列内的下标：入场错位延迟按分列索引阶梯递增（错峰 Stagger），上限截断避免末项累积延迟。
  @Builder
  feedPost(post: Post, idx: number): void {
    PostCard({
      post: post,
      compact: true,
      onOpen: () => {
        if (post.id !== undefined) {
          trackPostEvent(post.id, 'click');
          openPostDetail(post.id.toString());
          this.getUIContext().getRouter().pushUrl({ url: 'pages/DetailPage' });
        }
      },
    })
      .transition(
        TransitionEffect.OPACITY
          .animation({ duration: MotionTokens.slow, curve: MotionCurves.decelerate, delay: Math.min(idx, 6) * MotionTokens.stagger })
          .combine(TransitionEffect.translate({ y: 14 })
            .animation({ duration: MotionTokens.slow, curve: MotionCurves.decelerate, delay: Math.min(idx, 6) * MotionTokens.stagger }))
      )
      .onAppear(() => {
        if (post.id !== undefined && !this.exposedIds.has(post.id)) {
          this.exposedIds.add(post.id);
          trackPostEvent(post.id, 'expose');
        }
      })
  }

  // 推荐/关注流：Scroll 显式双列（偶数项固定左列、奇数项固定右列，首项始终位于左上角）。
  // 两列独立排列保留瀑布流紧凑效果。必须用 Scroll：懒加载容器(WaterFlow/List)会把内容
  // 滚动终点钳制在底部非安全区之上、露出窗口底色横带截断末卡（实测 expandSafeArea /
  // ignoreLayoutSafeArea 挂容器自身均无效），Scroll 滚动范围天然到物理屏底。
  @Builder
  feedScroll(): void {
    Scroll() {
      Column({ space: SpaceTokens.sm }) {
        Row({ space: SpaceTokens.xs }) {
          Column({ space: SpaceTokens.xs }) {
            ForEach(this.posts.filter((_p: Post, idx: number) => idx % 2 === 0),
              (post: Post, idx: number) => { this.feedPost(post, idx) },
              (post: Post) => 'feed-even-' + String(post.id ?? ''))
          }
          .layoutWeight(1)
          Column({ space: SpaceTokens.xs }) {
            ForEach(this.posts.filter((_p: Post, idx: number) => idx % 2 === 1),
              (post: Post, idx: number) => { this.feedPost(post, idx) },
              (post: Post) => 'feed-odd-' + String(post.id ?? ''))
          }
          .layoutWeight(1)
        }
        .width('100%')
        .alignItems(VerticalAlign.Top)
        // 尾注 + 底部预留：既是悬浮底栏的让位，也是 Scroll 滚到物理底的滚动余量
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
          Blank().width('100%').height(barBottomReserve())
        }
        .width('100%')
      }
      .width('100%')
      .constraintSize({ minHeight: '100%' })
      .padding({
        left: SpaceTokens.sm,
        right: SpaceTokens.sm,
        top: 5,
        bottom: SpaceTokens.md,
      })
    }
    .scrollable(ScrollDirection.Vertical)
    .onScrollEdge((edge: Edge) => {
      if (edge === Edge.Bottom) {
        this.loadMore();
      }
    })
  }

  build() {
    Column() {
      // 海报式编辑部头部：编号、品牌标题、主标语和栏目切换构成明确的阅读层级。
      Column({ space: SpaceTokens.xs }) {
          Row() {
            Column({ space: SpaceTokens.xs }) {
              Row({ space: SpaceTokens.sm }) {
                Text('有据')
                  .fontSize(TypeTokens.titleSerif.size)
                  .fontFamily(TypeTokens.fontFamilySerif)
                  .fontWeight(TypeTokens.titleSerif.weight)
                  .lineHeight(TypeTokens.titleSerif.lineHeight)
                  .fontColor(ColorTokens.primary)
                Text('SUBSTANTIATE')
                  .fontSize(TypeTokens.overline.size)
                  .fontFamily(TypeTokens.fontFamily)
                  .fontWeight(TypeTokens.overline.weight)
                  .fontColor(ColorTokens.tertiary)
              }
              Text('真实经验，有据可循')
                .fontSize(TypeTokens.headline.size)
                .fontFamily(TypeTokens.fontFamilySerif)
                .fontWeight(TypeTokens.headline.weight)
                .lineHeight(TypeTokens.headline.lineHeight)
                .fontColor(ColorTokens.primary)
            }
            .alignItems(HorizontalAlign.Start)
            .layoutWeight(1)
            Pressable({
              visualHeight: LayoutTokens.minTouchTarget,
              touchTargetHeight: LayoutTokens.minTouchTarget,
              action: (): void => {
                // 搜索入口跳转独立搜索页（与首页解耦）
                this.getUIContext().getRouter().pushUrl({ url: 'pages/SearchPanelPage' });
              },
            }) {
              // 与 SearchPanel 右上角搜索按钮完全同款：透明底 + 细边框 + 大圆角（无实色垫底/阴影）
              Row() {
                Image(resolveActionIcon('search'))
                  .width(IconTokens.small)
                  .height(IconTokens.small)
              }
              .width(LayoutTokens.minTouchTarget)
              .height(LayoutTokens.minTouchTarget)
              .border({ width: LayoutTokens.glassBorderWidth, color: ColorTokens.barBorder, style: BorderStyle.Solid })
              .borderRadius(RadiusTokens.lg)
              .justifyContent(FlexAlign.Center)
              .alignItems(VerticalAlign.Center)
              .accessibilityText('搜索')
            }
          }
          .width('100%')
          .height(LayoutTokens.titleBarHeight)
          .alignItems(VerticalAlign.Center)

          Stack({ alignContent: Alignment.TopStart }) {
            SegmentedControl({
              items: FEED_SEGMENTS,
              selectedIndex: $feedIndex,
              itemWidth: 66,
              fillWidth: false,
              // 描边风格：与右上角搜索按钮同款（透明底 + 细边框 + 大圆角），顶栏视觉统一
              glass: false,
              outlined: true,
              onSelect: (idx: number): void => {
                const mode: FeedMode = FEED_MODE_IDX_MAP[idx];
                this.switchFeed(mode);
              },
            })
              .alignSelf(ItemAlign.Start)
              // 置顶于全宽的 TagNav 圈子栏之上：TagNav 透明占位区不再拦截本控件的点击。
              .zIndex(3)
            if (this.useCircleBarOverlap()) {
              TagNav({
                tags: this.displayTags,
                selectedIndex: $tagIndex,
                compact: true,
                glass: false,
                dropdownOnly: true,
              })
                .width('100%')
                .zIndex(2)
            }
          }
          .width('100%')
          .height(LayoutTokens.segmentedHeight)
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
              Column({ space: SpaceTokens.xs }) {
                // 每日一帖：编辑部头版报头（日期/期数/EDITOR'S PICK）
                this.dailyMasthead()
                DailyPostDeck({
                  deckVersion: this.dailyDeckVersion,
                  posts: this.posts,
                  loading: this.loading,
                  finished: this.finished,
                  onLoadMore: (): void => { this.loadMore(); },
                  onOpen: (post: DailyPost): void => {
                    if (post.id !== undefined) {
                      trackPostEvent(post.id, 'click');
                      openPostDetail(post.id.toString());
                      this.getUIContext().getRouter().pushUrl({ url: 'pages/DetailPage' });
                    }
                  },
                })
                  .width('100%')
                  .layoutWeight(1)
              }
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
            // 推荐/关注流：Scroll 显式双列。懒加载容器(WaterFlow)实测把滚动终点钳制在
            // 底部非安全区之上、露出窗口底色横带截断末卡，故统一走 Scroll（天然到物理屏底）
            Refresh({ refreshing: this.isRefreshing, builder: this.refreshBuilder }) {
              this.feedScroll()
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
        }
        }
        .width('100%')
        .height('100%')
        .clip(true)
        .layoutWeight(1)
      }
      .width('100%')
      .height('100%')
      .alignItems(HorizontalAlign.Start)
      .backgroundColor(ColorTokens.canvas)
  }
}
