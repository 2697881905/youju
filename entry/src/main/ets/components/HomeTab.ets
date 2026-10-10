// 首页 feed（真实内容）：顶栏(三子Tab+搜索框同水平) + 标签筛选 + 帖子网格
// 首页 Tab：海报式编辑部头部 + 推荐/关注/每日一帖信息流。
// 数据来源：listPosts / listTags / listDailyPosts（services/api.ets）
// 搜索入口跳转独立搜索页 pages/SearchPanelPage（搜索面板已与首页解耦）。

import { DailyPost, Post, Tag } from '../models/types';
import { listDailyPosts, listPosts, listFollowingPosts, listTags, listFollowedTags, getUserProfile, trackPostEvent, trackDailyOpen, resolveDisplayImageUrl } from '../services/api';
import { getUserId } from '../utils/auth';
import { likeStore } from '../utils/likeStore';
import { postDeletionStore } from '../utils/postDeletionStore';
import { PostCard } from './PostCard';
import { TagNav } from './TagNav';
import { emitTabSwitch } from '../utils/nav';
import { openPostDetailViaNav, postDetailCoverOf } from '../utils/longTake/openPostDetailNav';
import { openSearchPanelViaNav, SEARCH_ENTRY_ID } from '../utils/longTake/openSearchPanelNav';
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
import { gridColumnsForBreakpoint } from '../utils/responsive';
import { feedItemTransition } from '../utils/feedMotion';
import { TopButtonMaterialModifier } from '../utils/immersiveMaterial';
import { HdsNavigation, HdsNavigationTitleMode, ScrollEffectType } from '@kit.UIDesignKit';
import type {
  HdsNavigationTitleBarOptions,
  TitleBarContentOptions,
  TitleBarStyleOptions,
  ScrollEffectOptions,
  BottomBuilderParams,
} from '@kit.UIDesignKit';
import { LengthMetrics } from '@kit.ArkUI';
import { hilog } from '@kit.PerformanceAnalysisKit';

type SortKey = 'hot' | 'latest' | 'recommend';
// 信息源模式：导出给 Index 的标题栏共用（@Link 的类型必须与 HomeTab 完全一致）。
export type FeedMode = 'recommend' | 'following' | 'daily';

// FeedMode → 分段索引 的映射（用于顶栏 ForEach 选中态比较）
const FEED_MODE_IDX_MAP: FeedMode[] = ['recommend', 'following', 'daily'];

// 自动重试上限：避免真机连不上后端时无限重试 → 首页永久「加载中…」转圈。
// 超限后停止重试并展示明确「加载失败」错误态，由用户手动点重试。
const FEED_MAX_RETRY: number = 3;
const TAGS_MAX_RETRY: number = 3;
// 今日一帖每日精选篇数固定为 10 条（一次拉齐，读完即完成态）
const DAILY_PICK_LIMIT: number = 10;

const SORT_KEYS: SortKey[] = ['hot', 'latest', 'recommend'];
// 分段栏数据：导出给 Index 的标题栏渲染（key 与 FeedMode 一一对应，FEED_MODE_IDX_MAP 同序）。

// —— 顶栏（路线 B，验证页第七轮定稿结构）——
// bottomBuilder 分段行高：36 控件 + 上下 4 内边距
const HOME_TAB_ROW_HEIGHT: number = SpaceTokens.xs * 2 + LayoutTokens.segmentedHeight;
// 滚动模糊生效区间终点（vp）：0 → 32 线性到位（原 64 偏慢，按用户裁定调小一档；验证页定稿值为 64）
const HOME_FEED_BLUR_END_VP: number = 32;
// 标语收合滚动阈值（vp）：信息流滚过该高度后收起「真实经验，有据可循」。dynamicHideTitleBar
// 粒度为区域级（hideTitleArea 会连品牌行+搜索一起收、hideBottomBuilder 收整个分段行），
// 做不到只收标语一行 → 走滚动驱动自定义收合（品牌块内部高度动画，栏总高不变）。
const BRAND_COMPACT_THRESHOLD_VP: number = 12;
export const FEED_SEGMENTS: SegmentedItem[] = [
  { key: 'recommend', label: '推荐' },
  { key: 'following', label: '关注' },
  { key: 'daily', label: '每日一帖' },
];

// —— 每日一帖刊期 ——
// 首期日（Asia/Shanghai）：2026-09-11 即 No.001；之后每个自然日 +1 期，跨年不重置。
// 计日统一按北京时间（UTC+8），与后端 dailyKey 的 Asia/Shanghai 口径一致，设备处于任意时区均不偏移。
const DAILY_ISSUE_ORIGIN: string = '2026-09-11';
const DAILY_TZ_OFFSET_MS: number = 8 * 60 * 60 * 1000;
// 每日卡堆卡面的媒体比例（与 DECK_MEDIA_RATIO 一致）：只作为一镜到底的
// **飞行目标框比例**（intent.flightAspect）传入 —— 落点与卡面严丝合缝；
// **不要**传给 intent.aspect（阅读比例）：那是转场结束后媒体框的展示比例，
// 用 4:3 会把竖向图片压进横屏框（反复踩过）。
const DAILY_DECK_MEDIA_RATIO: number = 4 / 3;

// —— 会话级信息流缓存：切 Tab 回来先展示缓存再后台刷新，避免白屏重拉（P2 性能优化）——
// key = feedMode|tag|sort；仅缓存首屏（page=1），TTL 120s；账号切换/发帖后整体失效
interface FeedCacheEntry {
  posts: DailyPost[];
  at: number;
}
const FEED_CACHE_TTL: number = 120000;
const feedSessionCache: Map<string, FeedCacheEntry> = new Map<string, FeedCacheEntry>();
const ALL_TAG: Tag = { name: '全部' };

// —— 关注流空态 A/B 的判别哨兵 ——
// 空态 A（你还没有关注任何人）与 B（你关注的人还没有发布内容）靠「关注数」区分，
// 而关注数是异步取的。判别依据没到齐时**不能**用一个看起来合理的默认值（0）下结论，
// 否则进关注 Tab 会先闪一下 A 再变成 B（用户实测的闪烁）。
const FOLLOWING_COUNT_UNKNOWN: number = -1; // 还没取到 → 渲染加载态
const FOLLOWING_COUNT_FAILED: number = -2;  // 取数失败 → 渲染中性空态（A/B 两个文案都在断言，都不能用）

@Component
export struct HomeTab {
  // 三页（推荐/关注/每日一帖）各自独立缓存：Swiper 滑动时相邻页显示自己的内容，
  // 未访问过的分段缓存为空 → 页内先呈现加载态（与「我的」页 postsCache 同构）。
  @State postsCache: DailyPost[][] = [[], [], []];
  // —— 顶部区域迁入 Navigation 标题栏后，以下状态由 Index 持有、这里 @Link 共用 ——
  // （标题栏的分段栏/圈子 chip 读写这些状态，信息流据此联动）
  @Link displayTags: Tag[];
  @State tagsLoaded: boolean = false;
  @State sortIndex: number = 0;
  @Link @Watch('onTagChanged') tagIndex: number;
  @State page: number = 1;
  @State loading: boolean = false;
  @State finished: boolean = false;
  @State isRefreshing: boolean = false;
  // 刷新指示器可见性：isRefreshing 只在下拉过阈值后为 true，拉拽过程（Drag/OverDrag）
  // 需要 onStateChange 单独跟踪，否则下拉全程指示器不可见
  @State refreshIndicatorVisible: boolean = false;
  @State error: string = '';
  @Link feedMode: FeedMode;
  // 标题栏分段栏切换走这里写入；@Watch 负责把「外部切换」翻译成信息源加载（见 onFeedIndexChanged）
  @Link @Watch('onFeedIndexChanged') feedIndex: number;
  // 分段滑块跟手位置：Swiper 滚动（拖动/吸附）中喂入的连续索引；-1 = 未滚动
  @Link slidePosition: number;
  // 分页区实测宽度（vp）：onGestureSwipe 的 currentOffset 是 vp 位移，换算连续索引要用
  @State swiperWidth: number = 0;
  // 圈子下拉面板开合（标题栏 chip ↔ 本页面板 共享）
  @Link showCircleDropdown: boolean;
  @State needLogin: boolean = false; // 关注流且未登录的引导态
  // 关注流的关注数缓存（空态 A/B 区分）。取值三态，见 FOLLOWING_COUNT_* 常量：
  // 保留上次取到的真实值，切回关注 Tab 时不会先闪加载态（关注数极少变，够用）。
  @State followingCount: number = FOLLOWING_COUNT_UNKNOWN;
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
  // 展开态网格列数（600/840vp 断点 → 3/4 列，手机竖屏保持 2 列）。
  // 断点来自全局断点中心（全 app 唯一窗口尺寸监听），本组件不再自注册 windowSizeChange。
  @State feedColumns: number = 2;
  @StorageProp('currentBreakpoint') @Watch('onBreakpointChanged') currentBreakpoint: string = 'sm';
  // —— 顶栏（嵌套 HdsNavigation，路线 B）——
  // 推荐/关注流各一个 Scroller：交给 bindToScrollable 驱动标题栏渐变模糊（每日一帖无 Scroll 不绑）
  private feedScrollers: Scroller[] = [new Scroller(), new Scroller()];

  // bindToScrollable 的绑定数组：仅随分段切换整体替换（实例引用稳定）。
  // ⚠️ 不可在 build 里每次返回新数组：滑动的逐帧状态变化（slidePosition）会让 HomeTab
  // 逐帧重渲染，新数组实例 = 逐帧重订阅 HDS 背板，相邻页（每日一帖卡堆）在切段瞬间
  // 闪现（真机实证）。由 onSwiperChanged → syncFeedScrollerBinding 按分段更新。
  @State boundFeedScrollers: Scroller[] = [this.feedScrollers[0]];

  private syncFeedScrollerBinding(index: number): void {
    const next: Scroller[] = index === 1 ? [this.feedScrollers[1]]
      : index === 2 ? [] : [this.feedScrollers[0]];
    // 内容未变（引用相同）不替换，避免无谓重订阅
    if (next.length !== this.boundFeedScrollers.length
      || (next.length > 0 && next[0] !== this.boundFeedScrollers[0])) {
      this.boundFeedScrollers = next;
    }
  }
  // 搜索按钮同源材质修饰器（沉浸光感，HDS 标题栏 = 官方生效区域）
  private searchMaterial: TopButtonMaterialModifier = new TopButtonMaterialModifier();
  // 标语收合态：信息流滚过阈值后收起「真实经验，有据可循」（品牌块 56→32，Row 自动居中「有据」行）
  @State brandCompact: boolean = false;
  // 模糊完成态：滚动过模糊终点（HOME_FEED_BLUR_END_VP）后品牌行切白——模糊背板变深，
  // 深色品牌字对比度不足（系统标题的 originalStyle/scrollEffectStyle 颜色过渡管不到自绘 stackBuilder）
  @State brandOnBlur: boolean = false;

  // 滚动驱动标语收合 + 品牌行切白：读当前页 Scroller 的绝对偏移，各自独立判断翻转
  //（⚠️ 两个阈值不能共用 early-return——否则先翻转的状态会挡住后一个的判断，切白永远不触发）。
  // 每日一帖（seg=2）无 Scroll，保持当前状态不翻转。
  private updateBrandCompact(seg: number): void {
    if (seg > 1) {
      return;
    }
    // Swiper 懒建页竞态：滑动瞬间目标页 Scroll 可能尚未创建/绑定，currentOffset() 运行时
    // 会返回 undefined（类型声明非可选但真机已复现，release 包因此崩溃杀进程，见故障报告
    // 2026-10-09 Pocket 2）——未就绪时按 0（静止态）处理，Scroll 创建后 onDidScroll 自然接管
    const offset: number = this.feedScrollers[seg]?.currentOffset()?.yOffset ?? 0;
    const compact: boolean = offset > BRAND_COMPACT_THRESHOLD_VP;
    const onBlur: boolean = offset > HOME_FEED_BLUR_END_VP;
    if (compact !== this.brandCompact) {
      this.getUIContext().animateTo({ duration: MotionTokens.base, curve: MotionCurves.decelerate }, () => {
        this.brandCompact = compact;
      });
    }
    if (onBlur !== this.brandOnBlur) {
      this.getUIContext().animateTo({ duration: MotionTokens.base, curve: MotionCurves.decelerate }, () => {
        this.brandOnBlur = onBlur;
      });
    }
  }

  aboutToAppear(): void {
    this.loadTags();
    // 默认加载推荐公开流（无需登录）；若已登录也保持推荐流默认
    this.refresh();
    // 订阅帖子删除事件：删除后即时从 feed 移除，避免已删帖子残留在内存列表
    this.unsubDeletion = postDeletionStore.subscribe((deletedId: number): void => {
      this.setPagePosts(this.feedIndex, this.pagePostsOf(this.feedIndex).filter((p: DailyPost) => p.id !== deletedId));
    });
    // 展开态列数：按当前全局断点换算（断点中心异步就绪后经 @Watch 修正）
    this.feedColumns = gridColumnsForBreakpoint(this.currentBreakpoint);
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

  // 断点变化（展开折叠屏/旋转/分屏）→ 即时换算网格列数
  onBreakpointChanged(): void {
    this.feedColumns = gridColumnsForBreakpoint(this.currentBreakpoint);
  }

  // token 由空变为非空（登录完成）→ 关注流且列表空、无 error 时自动补加载
  onTokenReady(): void {
    if (this.token !== '' && this.pagePostsOf(this.feedIndex).length === 0 && (this.feedMode === 'following' || this.error !== '')) {
      this.refresh();
    }
  }

  // 分页只读自己那份缓存：Swiper 拖动过程中相邻页显示的是它自己的内容
  private pagePostsOf(seg: number): DailyPost[] {
    return this.postsCache[seg] ?? [];
  }

  // 整体替换数组以触发 @State 刷新（ArkTS 不观察数组元素的原地修改）
  private setPagePosts(seg: number, list: DailyPost[]): void {
    const next: DailyPost[][] = [[], [], []];
    for (let i: number = 0; i < FEED_SEGMENTS.length; i++) {
      next[i] = i === seg ? list : this.pagePostsOf(i);
    }
    this.postsCache = next;
  }

  // 账号切换/登出：清空点赞缓存，先清空数据源（销毁旧 PostCard）→ 重拉（新账号的 myUp/upCount 重新灌入）
  onAccountSwitch(): void {
    likeStore.clear();
    // 会话缓存必须整体失效：cacheKey（feedMode|tag|sort）不含账号维度，stale-while-revalidate
    // 会先渲染上一账号的首屏（关注流尤其明显），请求失败时旧内容还会滞留
    feedSessionCache.clear();
    this.setPagePosts(this.feedIndex, []);
    // 换账号：上一个账号的关注数与当前账号无关，必须退回「未知」而不是 0
    this.followingCount = FOLLOWING_COUNT_UNKNOWN;
    this.refresh();
  }

  // 切回首页：若标签仍停留在失败兜底态（仅「全部」），自动重试，避免一次性加载失败后被卡死
  onHomeActive(): void {
    if (this.homeActive === 0 && !this.tagsLoaded) {
      this.loadTags();
    }
  }

  onPostPublished(): void {
    this.setPagePosts(this.feedIndex, []);
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
    // 这里刻意**不**重置 followingCount：它是空态 A/B 的判别依据，置成 0 就等于断言
    // 「未关注任何人」，真实值到达前会先闪一下错误的空态。保留上次取到的真实值，
    // 换账号时才由 onAccountSwitch 重置为 UNKNOWN。
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
      // 圈子下拉仅在推荐流可用：离开推荐流时收起（chip 在标题栏、面板在本页，靠共享态同步）
      if (mode !== 'recommend') {
        this.showCircleDropdown = false;
      }
      this.needLogin = (mode === 'following' && this.token === '');
      // 进入「每日一贴」即上报一次页面级事件，用于计算每日一贴打开率/渗透率。
      if (mode === 'daily') {
        trackDailyOpen();
      }
      this.refresh();
    }
  }

  // 标题栏分段栏（Index 持有 feedIndex）写入后的联动入口：等价于点击分段栏切换信息源。
  // 自身路径（Swiper 回调 / switchFeed 内部）写入相同值时不会触发 @Watch，因此不会重复加载。
  onFeedIndexChanged(): void {
    if (this.feedIndex < 0 || this.feedIndex >= FEED_MODE_IDX_MAP.length) {
      return;
    }
    this.switchFeed(FEED_MODE_IDX_MAP[this.feedIndex]);
  }

  // 左右滑动切换由 Swiper 原生接管（跟手、相邻页可见、松手吸附）。
  // Swiper.onChange → 这里更新 feedMode/needLogin 并懒加载该页数据。
  private onSwiperChanged(index: number): void {
    // 切段后按新页的滚动偏移重算标语收合态（每日一帖 seg=2 保持现状）
    this.updateBrandCompact(index);
    // 分段切换 → 同步 bindToScrollable 绑定（动态重估模糊，见 syncFeedScrollerBinding 注释）
    this.syncFeedScrollerBinding(index);
    if (index === this.feedIndex) {
      return;
    }
    this.switchFeed(FEED_MODE_IDX_MAP[index]);
  }

  // 请求序号：每次发起自增；响应回来时若序号已落后（期间又发起了新请求）则整体丢弃，
  // 只让「最后一次发起」的请求生效。修复提审审计 P1-3：加载更多在途时触发下拉刷新，
  // 旧实现 refresh 先重置 page=1 再被 if (this.loading) return 静默丢弃，在途 loadMore
  // 以旧页码回包 concat → 列表重复/分页错位；同理快速切换推荐/关注时，旧响应会写进
  // 新信息源的槽位（setPagePosts 用的是响应时刻的 feedIndex）。
  private fetchSeq: number = 0;

  private async fetch(reset: boolean): Promise<void> {
    const seq: number = ++this.fetchSeq;
    // 关注流且未登录：不发起请求，展示登录引导态（序号已自增，在途请求的响应会被丢弃）
    if (this.feedMode === 'following' && this.token === '') {
      this.loading = false;
      this.needLogin = true;
      this.setPagePosts(this.feedIndex, []); // 清空当前页残留内容
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
        this.setPagePosts(this.feedIndex, cached.posts);
      }
    }
    try {
      if (this.feedMode === 'daily') {
        // 今日一帖：每日精选固定 10 条一次拉齐，不随滚动追加。
        // 读完精选即进入完成态（对齐原型「每日唯一内容」的仪式感）。
        const res = await listDailyPosts(1, DAILY_PICK_LIMIT);
        if (seq !== this.fetchSeq) {
          return; // 过期响应：期间已有更新的请求发起，整体丢弃
        }
        this.setPagePosts(this.feedIndex, res.list);
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
      if (seq !== this.fetchSeq) {
        return; // 过期响应：丢弃，不写列表、不改 finished/页码
      }
      if (reset) {
        this.setPagePosts(this.feedIndex, res.list);
        // 写回会话缓存（仅首屏，供切 Tab 回来快速呈现）
        feedSessionCache.set(this.feedCacheKey(), { posts: res.list, at: Date.now() });
      } else {
        this.setPagePosts(this.feedIndex, this.pagePostsOf(this.feedIndex).concat(res.list));
      }
      if (res.list.length < 20) {
        this.finished = true;
      }
      // 关注流空列表：异步取 followingCount 用于空态 A/B 区分（不阻塞渲染）
      if (this.feedMode === 'following' && res.list.length === 0 && this.token !== '') {
        this.loadFollowingCount();
      }
    } catch (e) {
      if (seq !== this.fetchSeq) {
        return; // 过期请求的失败不覆盖新请求的状态
      }
      this.error = (e as Error).message;
      // 分页回滚：loadMore 先 +1 再请求，失败不回滚会让失败那一页被静默跳过
      // （error 只在列表为空时可见，非空列表下用户无感知）；连接类失败走 refresh 自愈会重置 page，回滚无害
      if (!reset && this.page > 1) {
        this.page -= 1;
      }
      if (this.isConnError(this.error) && this.feedRetryCount < FEED_MAX_RETRY && this.feedRetryTimer === 0) {
        this.feedRetryCount += 1;
        this.feedRetryTimer = setTimeout((): void => {
          this.feedRetryTimer = 0;
          this.refresh();
        }, 1500) as number;
      }
    } finally {
      // 只有仍是「当前请求」才有资格退出加载态；被取代的请求不能替新请求关 loading
      if (seq === this.fetchSeq) {
        this.loading = false;
      }
    }
  }

  // 取当前用户的关注数（关注流空态 A/B 区分：0→未关注任何人，>0→关注的人未发帖）
  private async loadFollowingCount(): Promise<void> {
    try {
      const id: number = getUserId();
      if (id === 0) {
        // 未登录：没有「关注数」这回事（此时页面走 needLogin 引导态，本值不会被用来判空态）
        this.followingCount = 0;
        return;
      }
      const profile = await getUserProfile(id);
      this.followingCount = profile.followingCount;
    } catch (e) {
      // 取数失败：不要拿 0 冒充「未关注任何人」—— 那是在断言一件我们并不知道的事。
      // 已有上次的真实值时保留（不降级），否则标记 FAILED 走中性空态。
      if (this.followingCount === FOLLOWING_COUNT_UNKNOWN) {
        this.followingCount = FOLLOWING_COUNT_FAILED;
      }
    }
  }

  // —— 「一镜到底」意图组装 ——
  // 每日一帖卡面展示图口径：与 DeckSlotCard.hasMedia()/mediaUrl() 一致（视频封面优先，其次封面）。
  // （信息流/「我的」等 Post 表面的封面口径与发起器已抽到 utils/longTake/openPostDetailNav.ets 共享）
  private dailyDeckCover(p: DailyPost): string {
    const raw: string = (p.videoCover ?? '').length > 0 ? (p.videoCover ?? '') : (p.coverImage ?? '');
    return raw.length > 0 ? resolveDisplayImageUrl(raw) : '';
  }

  // 卡片 → 详情：走 Navigation 的 PostDetail 目的地以启用自定义转场（一镜到底）。
  // 发起逻辑已抽到 utils/longTake/openPostDetailNav.ets（openPostDetailViaNav），
  // 与「我的」四分段共享；此处仅保留卡堆特有的 DailyPost 封面口径。

  @Builder
  refreshBuilder(): void {
    // ⚠️ 显隐必须属性级驱动（opacity），禁止结构条件化渲染：Refresh 的指示区高度
    // 参与布局，builder 内容抽空会导致区域塌陷、内容区整体上移铺满屏幕（真机实证）。
    // 常驻 Row + opacity 切换：布局占位不变，静止透明（clip(false) 穿底下不可见），
    // 刷新时渐显；非激活态同时关闭命中，避免挡住列表顶部触摸。
    Row({ space: SpaceTokens.inline }) {
      LoadingProgress().width(IconTokens.compact).height(IconTokens.compact)
      Text('刷新中…')
        .fontSize(TypeTokens.caption.size).fontFamily(TypeTokens.fontFamily)
        .fontWeight(TypeTokens.caption.weight)
        .lineHeight(TypeTokens.caption.lineHeight)
        .letterSpacing(TypeTokens.caption.tracking)
        .fontColor(ColorTokens.secondary)
    }
    .opacity((this.isRefreshing || this.refreshIndicatorVisible) ? 1 : 0)
    .hitTestBehavior((this.isRefreshing || this.refreshIndicatorVisible) ? HitTestMode.Default : HitTestMode.None)
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

  // 分页内容：每个分段一页（Swiper 子项）。每页只读自己那份缓存，
  // 因此拖动过程中相邻页显示的是它自己的内容，而非当前分段的数据；
  // 未访问过的分段缓存为空 → 页内先呈现加载态（与「我的」页 postsCache 同构）。
  @Builder
  feedPage(seg: number): void {
    Column() {
      if (this.needLogin && seg === 1) {
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
      } else if (this.pagePostsOf(seg).length === 0 && seg !== this.feedIndex) {
        // 相邻页缓存为空：加载态（当前页的加载/空态在下方分支处理）
        Column() {
          LoadingProgress().width(IconTokens.empty).height(IconTokens.empty)
        }
        .width('100%')
        .height('100%')
        .justifyContent(FlexAlign.Center)
      } else if (this.pagePostsOf(seg).length === 0 && this.loading) {
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
      } else if (this.pagePostsOf(seg).length === 0) {
        Column() {
          if (this.error) {
            EmptyState({
              icon: resolveActionIcon('warning'),
              title: '加载失败',
              message: this.error,
              actionLabel: '重试',
              onAction: (): void => { this.refresh(); },
            })
          } else if (seg === 1) {
            // 关注流空态 A/B 区分：判别依据是异步取到的「关注数」，所以必须等它到齐再下结论。
            // 旧实现把它默认成 0 且每次 refresh() 都重置为 0 → 进关注 Tab 先闪一下
            //「你还没有关注任何人」，真实值到了再变成「你关注的人还没有发布内容」。
            if (this.followingCount === FOLLOWING_COUNT_UNKNOWN) {
              // 判别依据未就绪：给加载态，而不是拿默认值冒充结论
              Column() {
                LoadingProgress().width(IconTokens.empty).height(IconTokens.empty)
              }
              .width('100%')
              .height('100%')
              .justifyContent(FlexAlign.Center)
            } else if (this.followingCount === FOLLOWING_COUNT_FAILED) {
              // 取数失败：这时「有没有关注人」并不知道，A/B 两个文案都是在断言，改用中性文案
              EmptyState({
                icon: resolveActionIcon('inbox'),
                title: '这里还没有内容',
                message: '稍后下拉刷新，或去发现感兴趣的人',
                actionLabel: '刷新',
                onAction: (): void => { this.refresh(); },
              })
            } else if (this.followingCount === 0) {
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
          } else if (seg === 2) {
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
        if (seg === 2) {
          // 每日一帖禁用下拉刷新：10 帖为固定编辑部精选，下拉无意义；
          // 且 Refresh 手势与 DailyPostDeck 的卡牌拖拽冲突
          Column({ space: SpaceTokens.xs }) {
            // 每日一帖：编辑部头版报头（日期/期数/EDITOR'S PICK）
            this.dailyMasthead()
            DailyPostDeck({
              deckVersion: this.dailyDeckVersion,
              posts: this.pagePostsOf(seg),
              loading: this.loading,
              finished: this.finished,
              onLoadMore: (): void => { this.loadMore(); },
              onOpen: (post: DailyPost): void => {
                if (post.id !== undefined) {
                  trackPostEvent(post.id, 'click', 'daily');
                  // 阅读比例 = 标准 3:4（竖向图片不被压横）；飞行目标比例 = 卡面 4:3
                  // （落点与卡面严丝合缝，真图就绪交接时再平滑过渡到阅读比例）。
                  // 圆角 = 卡堆卡容器圆角（RadiusTokens.md）
                  openPostDetailViaNav(this.getUIContext(), post, LayoutTokens.cardMediaAspectRatio, this.dailyDeckCover(post), 'deckCardMedia-' + post.id,
                    RadiusTokens.md, DAILY_DECK_MEDIA_RATIO);
                }
              },
            })
              .width('100%')
              .layoutWeight(1)
          }
          .width('100%')
          .height('100%')
        } else {
          // 推荐/关注流：Scroll 显式双列（Swiper 每页独立，见 feedScroll）
          // ⚠️ Refresh 默认裁切子节点：不关掉它，滚动内容被切在栏底，穿底+渐变模糊失效
          // （验证页无 Refresh 层所以没暴露；真机首页实测卡片流无法穿底、栏底实色的根因）
          Refresh({ refreshing: this.isRefreshing, builder: this.refreshBuilder }) {
            this.feedScroll(seg)
          }
          .onStateChange((state: RefreshStatus) => {
            // 拉拽/刷新全程显示指示器；空闲与完成回弹隐藏
            this.refreshIndicatorVisible = state === RefreshStatus.Drag
              || state === RefreshStatus.OverDrag || state === RefreshStatus.Refresh;
          })
          .onRefreshing(() => {
            this.isRefreshing = true;
            this.refresh().finally(() => {
              this.isRefreshing = false;
            });
          })
          .clip(false)
          .width('100%')
          .height('100%')
        }
      }
    }
    .width('100%')
    .height('100%')
  }

  // 推荐/关注流单卡：PostCard + 曝光埋点（卡片出现在屏幕上即上报，去重跳过）。
  // idx 为该卡在其分列内的下标：入场错位延迟按分列索引阶梯递增（错峰 Stagger），上限截断避免末项累积延迟。
  @Builder
  feedPost(post: Post, idx: number): void {
    PostCard({
      post: post,
      // 首页信息流是唯一走 Navigation 一镜到底的 PostCard 面：挂飞行 id 前缀
      // （其余 PostCard 列表面默认不挂，防跨面同帖 id 撞车量错飞行起点）
      mediaTag: 'cardMedia-',
      compact: true,
      onOpen: () => {
        if (post.id !== undefined) {
          trackPostEvent(post.id, 'click', 'feed');
          // 飞行物 = 3:4 封面海报本身（PostCardMedia.coverFace 挂着 cardMedia-{id}）；
          // 圆角 = 该封面 Image 的圆角 —— compact 卡封面与卡片容器同为 RadiusTokens.xs。
          // 标题/互动区不参与缩放变形（与卡堆「只飞媒体块」口径一致）。
          // 信息流卡面与阅读框同为 3:4：飞行/阅读比例传同一个值。
          openPostDetailViaNav(this.getUIContext(), post, LayoutTokens.cardMediaAspectRatio, postDetailCoverOf(post), 'cardMedia-' + post.id,
            RadiusTokens.xs, LayoutTokens.cardMediaAspectRatio);
        }
      },
    })
      // 不再挂整卡 id：截图与测量起点由封面块自带 id 承担（PostCardMedia：cardMedia-{id}）
      // 入场错峰过渡与其余列表统一（单一出处 utils/feedMotion）
      .transition(feedItemTransition(idx))
      .onAppear(() => {
        if (post.id !== undefined && !this.exposedIds.has(post.id)) {
          this.exposedIds.add(post.id);
          trackPostEvent(post.id, 'expose', 'feed');
        }
      })
  }

  // 信息流列数（2/3/4，responsive.ets 按窗口宽度断点回传）与列下标数组（ForEach 数据源）。
  // 帖子按其在页面数组中的原始下标对列数取模分列（原偶左奇右两列的泛化）。
  private feedColCount(): number {
    return Math.max(2, Math.min(4, this.feedColumns));
  }

  private feedColIndexes(): number[] {
    const arr: number[] = [];
    for (let i = 0; i < this.feedColCount(); i++) {
      arr.push(i);
    }
    return arr;
  }

  // 推荐/关注流：Scroll 显式多列（列数随窗口宽度自适应，偶数项固定首列、首项始终位于左上角）。
  // 两列独立排列保留瀑布流紧凑效果。必须用 Scroll：懒加载容器(WaterFlow/List)会把内容
  // 滚动终点钳制在底部非安全区之上、露出窗口底色横带截断末卡（实测 expandSafeArea /
  // ignoreLayoutSafeArea 挂容器自身均无效），Scroll 滚动范围天然到物理屏底。
  // seg 参数：Swiper 每页只读属于自己的 postsCache[seg]，拖动时相邻页显示各自内容。
  @Builder
  feedScroll(seg: number): void {
    // scroller 显式挂载（位置参数）：交给嵌套 HdsNavigation 的 bindToScrollable 驱动标题栏渐变模糊
    Scroll(this.feedScrollers[seg]) {
      Column({ space: SpaceTokens.sm }) {
        Row({ space: SpaceTokens.xs }) {
          ForEach(this.feedColIndexes(), (colIdx: number) => {
            Column({ space: SpaceTokens.xs }) {
              ForEach(this.pagePostsOf(seg).filter((_p: Post, idx: number) => idx % this.feedColCount() === colIdx),
                (post: Post, idx: number) => { this.feedPost(post, idx) },
                (post: Post) => seg + '-feed-' + colIdx + '-' + String(post.id ?? ''))
            }
            .layoutWeight(1)
          }, (colIdx: number) => colIdx.toString())
        }
        .width('100%')
        // 展开态铺满全宽：列数由 responsive.ets 按窗口宽度自适应（2/3/4 列），
        // 不限宽——详情正文才做 720vp 限宽居中（阅读面），发现流保持满幅
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
    .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true })
    .scrollable(ScrollDirection.Vertical)
    // 不裁剪：滚动内容穿出 Scroll 顶边画到 HDS 标题栏下方（渐变模糊的采样素材）
    .clip(false)
    // 滚动驱动标语收合（绝对偏移读自 Scroller，避免逐帧 setState）
    .onDidScroll((): void => {
      this.updateBrandCompact(seg);
    })
    .onScrollEdge((edge: Edge) => {
      if (edge === Edge.Bottom) {
        this.loadMore();
      }
    })
  }

  // 瀑布流（WaterFlow + LazyForEach）在 Swiper 三页下数据源无法按页隔离，
  // 且滚动终点被钳制在底部安全区之上；统一回退到 Scroll 双列（feedScroll）。
  // —— 顶栏标题栏配置（嵌套 HdsNavigation，路线 B：验证页第七轮定稿结构）——
  // MINI 模式 + stackBuilder 品牌行（品牌 + 搜索同行）+ bottomBuilder 分段行（分段 + 圈子 chip）
  // + GRADIENT_BLUR 滚动模糊（0 → 64vp）+ 透明起步 + 安全区双开关。逐层显式标注 SDK 类型。
  private homeHdsTitleBarOptions(): HdsNavigationTitleBarOptions {
    const scrollEffect: ScrollEffectOptions = {
      enableScrollEffect: true,
      scrollEffectType: ScrollEffectType.GRADIENT_BLUR,
      blurEffectiveStartOffset: LengthMetrics.vp(0),
      blurEffectiveEndOffset: LengthMetrics.vp(HOME_FEED_BLUR_END_VP),
    };
    const style: TitleBarStyleOptions = {
      scrollEffectOpts: scrollEffect,
      originalStyle: {
        backgroundStyle: { backgroundColor: Color.Transparent },
      },
    };
    const content: TitleBarContentOptions = {
      stackBuilder: (): void => { this.homeBrandRow(); },
      bottomBuilder: {
        builder: (): void => { this.homeTabRow(); },
        height: HOME_TAB_ROW_HEIGHT,
      } as BottomBuilderParams,
    };
    const options: HdsNavigationTitleBarOptions = {
      content: content,
      style: style,
      // 安全区双开关：avoid 让标题栏内容（品牌/搜索）从状态栏下沿开始；
      // enableComponentSafeArea 让信息流静止时从栏下开始、滚动时穿入栏下被渐变模糊。
      avoidLayoutSafeArea: true,
      enableComponentSafeArea: true,
    };
    return options;
  }

  // stackBuilder 品牌行：品牌块（有据 + SUBSTANTIATE / 标语，旧首页同款宋体规格）与搜索按钮同一行。
  // stackBuilder 行固定 56vp（旧 POC 实测）——品牌块 32 + 24 = 56 顶格排布（无额外 space）。
  // 搜索按钮保持一镜到底接线（SEARCH_ENTRY_ID 供发起器量帧/截图定位）。
  // 字色：静止态深色（品牌规范）；模糊到位后切白（模糊背板变深，深字对比度不足）。
  @Builder
  homeBrandRow() {
    Row() {
      Column() {
        Row({ space: SpaceTokens.sm }) {
          Text('有据')
            .fontSize(TypeTokens.titleSerif.size)
            .fontFamily(TypeTokens.fontFamilySerif)
            .fontWeight(TypeTokens.titleSerif.weight)
            .lineHeight(TypeTokens.titleSerif.lineHeight)
            .fontColor(this.brandOnBlur ? Color.White : ColorTokens.primary)
          Text('SUBSTANTIATE')
            .fontSize(TypeTokens.overline.size)
            .fontFamily(TypeTokens.fontFamily)
            .fontWeight(TypeTokens.overline.weight)
            .fontColor(this.brandOnBlur ? '#99FFFFFF' : ColorTokens.tertiary)
        }
        Text('真实经验，有据可循')
          .fontSize(TypeTokens.headline.size)
          .fontFamily(TypeTokens.fontFamilySerif)
          .fontWeight(TypeTokens.headline.weight)
          .lineHeight(TypeTokens.headline.lineHeight)
          .fontColor(this.brandOnBlur ? Color.White : ColorTokens.primary)
          // 上滑收标语（只收这一行）：高度+透明度一次收合，品牌块 56→32 由 Row 自动居中「有据」行；
          // dynamicHideTitleBar 粒度为区域级，做不到只收标语 → 自定义滚动驱动
          .height(this.brandCompact ? 0 : TypeTokens.headline.lineHeight)
          .opacity(this.brandCompact ? 0 : 1)
      }
      .alignItems(HorizontalAlign.Start)
      Blank()
      Pressable({
        visualHeight: LayoutTokens.minTouchTarget,
        touchTargetHeight: LayoutTokens.minTouchTarget,
        action: (): void => {
          // 搜索入口跳转独立搜索页（与首页解耦）；Navigation 未就绪时兜底 router 整页
          openSearchPanelViaNav(this.getUIContext());
        },
      }) {
        Row() {
          Image(resolveActionIcon('search'))
            .width(IconTokens.small)
            .height(IconTokens.small)
            .fillColor(this.brandOnBlur ? Color.White : ColorTokens.icon)
        }
        .width(LayoutTokens.minTouchTarget)
        .height(LayoutTokens.minTouchTarget)
        .border({
          width: LayoutTokens.glassBorderWidth,
          color: this.brandOnBlur ? '#66FFFFFF' : ColorTokens.barBorder,
          style: BorderStyle.Solid,
        })
        .borderRadius(RadiusTokens.lg)
        .justifyContent(FlexAlign.Center)
        .alignItems(VerticalAlign.Center)
        .attributeModifier(this.searchMaterial)
        .id(SEARCH_ENTRY_ID)
        .accessibilityText('搜索')
      }
    }
    .width('100%')
    .padding({ left: SpaceTokens.sm, right: SpaceTokens.sm })
  }

  // bottomBuilder 分段行：分段栏（推荐/关注/每日一帖）+ 圈子 chip（仅推荐流显示，与旧顶栏口径一致）。
  @Builder
  homeTabRow() {
    Row() {
      SegmentedControl({
        items: FEED_SEGMENTS,
        selectedIndex: $feedIndex,
        slidePosition: this.slidePosition,
        itemWidth: 66,
        fillWidth: false,
        glass: false,
        outlined: true,
        // 关闭按压/长按光斑：材质玻璃/描边风格上光斑过于抢眼
        glowEnabled: false,
        // 沉浸光感：处于 HDS 标题栏内（uiMaterial 官方生效区域），系统材质接管整栏表面
        useSystemMaterial: true,
        // 模糊到位后随品牌行一起切白（浅色内容态）
        lightContent: this.brandOnBlur,
        onSelect: (idx: number): void => {
          // 点击立即落整数位（弹性动画由 SharedSlide 整数分支承担）；
          // 信息源加载由本组件 @Watch(feedIndex) 承接（见 onFeedIndexChanged）
          this.slidePosition = idx;
          this.feedIndex = idx;
        },
      })
      if (this.feedMode === 'recommend') {
        TagNav({
          tags: this.displayTags,
          selectedIndex: $tagIndex,
          dropdownVisible: $showCircleDropdown,
          compact: true,
          glass: false,
          dropdownOnly: true,
          // 沉浸光感：圈子按钮与分段栏同源材质
          useSystemMaterial: true,
          // 模糊到位后随品牌行一起切白（浅色内容态）
          lightContent: this.brandOnBlur,
        })
          .layoutWeight(1)
      }
    }
    .width('100%')
    .height(HOME_TAB_ROW_HEIGHT)
    .padding({
      left: SpaceTokens.sm,
      right: SpaceTokens.sm,
      top: SpaceTokens.xs,
      bottom: SpaceTokens.xs,
    })
  }

  build() {
    // 顶栏（品牌行 + 分段行）迁入嵌套 HdsNavigation（路线 B，验证页第七轮定稿结构）：
    // MINI + stackBuilder + bottomBuilder + GRADIENT_BLUR；信息流本体 + 圈子下拉面板宿主为内容区。
    HdsNavigation() {
    Stack({ alignContent: Alignment.TopStart }) {
      Column() {
        // 列表区：Swiper 三页分页（推荐/关注/每日一帖）。
        // 原生 Swiper 提供跟手位移、相邻页可见、松手按速度弹性吸附（springSoft），
        // 与「我的」页分段栏同款体验；onChange 切换当前段并懒加载该段数据。
        Swiper() {
          this.feedPage(0)
          this.feedPage(1)
          this.feedPage(2)
        }
        .index(this.feedIndex)
        .loop(false)                 // 到边界不循环：与分段栏两端不可再点一致
        .indicator(false)            // 进度由分段栏承担
        .duration(MotionTokens.container)
        .curve(MotionCurves.springSoft)
        .onChange((index: number): void => { this.onSwiperChanged(index); })
        // 拖动/吸附逐帧联动滑块（1:1 跟手，见 slidePosition 注释）
        .onContentDidScroll((selectedIndex: number, index: number, position: number, _mainAxisLength: number): void => {
          // 只取当前选中页的回报（selectedIndex 在整段滚动中恒定）：
          // 连续索引 = index - position，官方语义 position 为 index 页相对主轴起始的位移比例
          if (index !== selectedIndex) {
            return;
          }
          const continuous: number = selectedIndex - position;
          this.slidePosition = Math.max(0, Math.min(FEED_SEGMENTS.length - 1, continuous));
        })
        // 拖拽逐帧跟手：手势拖动的每一帧（onContentDidScroll 在手势拖动期不保证回调，
        // 吸附/程序化动画帧仍由它覆盖）——连续索引 = index - currentOffset/页宽
        .onGestureSwipe((index: number, event: SwiperAnimationEvent): void => {
          if (this.swiperWidth <= 0) {
            return;
          }
          const continuous: number = index - event.currentOffset / this.swiperWidth;
          this.slidePosition = Math.max(0, Math.min(FEED_SEGMENTS.length - 1, continuous));
        })
        .onAreaChange((_old: Area, area: Area): void => {
          const w: number = parseFloat(String(area.width));
          if (w > 0 && Math.abs(w - this.swiperWidth) > 0.5) {
            this.swiperWidth = w;
          }
        })
        .onAnimationEnd((): void => {
          // 吸附收尾：已回到整数位才清除跟手覆盖（回落整数索引，数值一致无跳变）；
          // 中途被打断的动画保持浮点覆盖，避免滑块闪跳回旧位置
          if (Math.abs(this.slidePosition - Math.round(this.slidePosition)) < 0.01) {
            this.slidePosition = -1;
          }
        })
        .width('100%')
        .height('100%')
        .layoutWeight(1)
        // 每日一帖不裁剪：Swiper 默认裁切子节点，卡堆向上拖动/抛射的卡片需溢出列表区穿过报头；
        // 推荐/关注流同样不裁剪（路线 B）：滚动内容需穿出 Swiper 顶边画到 HDS 标题栏下方被渐变模糊采样
        .clip(false)
        // 每日一帖提升列表区整体层级：卡片随列表区一起向上拖动/抛出，不被同层其它节点遮挡。
        // 顶部区域已迁至 Navigation 标题栏层（STANDARD 模式下内容后绘制，
        // 溢出裁剪关闭后飞行卡仍可越过标题栏区域——见真机回归清单）。
        .zIndex(this.feedMode === 'daily' ? 1001 : 0)
      }
      .width('100%')
      .height('100%')
      .alignItems(HorizontalAlign.Start)
      .backgroundColor(ColorTokens.canvas)

      // 圈子下拉面板宿主（标题栏 chip 通过共享的 showCircleDropdown 开合）：
      // 面板 + 点外关闭遮罩都渲染在内容区这一层，向下覆盖信息流 ——
      // 绕开「标题栏高度固定 + 触摸只命中父节点范围内子节点」这两处限制。
      if (this.showCircleDropdown && this.useCircleBarOverlap()) {
        TagNav({
          tags: this.displayTags,
          selectedIndex: $tagIndex,
          dropdownVisible: $showCircleDropdown,
          compact: true,
          glass: false,
          dropdownOnly: true,
          panelOnly: true,
        })
      }
    }
    .width('100%')
    .height('100%')
    }
    .titleBar(this.homeHdsTitleBarOptions())
    .titleMode(HdsNavigationTitleMode.MINI)
    .hideBackButton(true)
    // 动态绑定当前分段的 Scroller（数组仅随分段切换替换，见 boundFeedScrollers 注释）
    .bindToScrollable(this.boundFeedScrollers)
    // 穿底绘制链路：HdsNavigation 自身不裁切（内容需画到栏下被模糊采样）
    .clip(false)
    .width('100%')
    .height('100%')
    .backgroundColor(ColorTokens.canvas)
  }
}
