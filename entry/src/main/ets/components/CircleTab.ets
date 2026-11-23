// 圈子页：服务端数据驱动的轻量星环视图。
// 星环只负责布局与交互；颜色、阴影、字体和圆角全部复用应用 design token。

import { Tag, Post } from '../models/types';
import { hilog } from '@kit.PerformanceAnalysisKit';
import {
  CircleDigestItem,
  CircleOverviewItem,
  CircleOverviewPost,
  deleteTag,
  getCircleOverview,
  getUserProfile,
  listFollowedTags,
  listPosts,
  listTagActivity,
  listTags,
  listTagWeights,
  markTagRead,
  setTagWeight,
  TagActivityItem,
  TagWeightItem,
} from '../services/api';
import { getToken, getUserId, getCurrentUser, persistSessionSnapshot } from '../utils/auth';
import { likeStore } from '../utils/likeStore';
import { barBottomReserve } from '../utils/cardTokens';
import { EmptyState } from '../design/components/EmptyState';
import { CountRoll } from '../design/motion/CountRoll';
import { Pressable } from '../design/motion/Pressable';
import { ColorTokens } from '../design/tokens/color';
import { IconTokens } from '../design/tokens/icon';
import { MotionCurves, MotionTokens } from '../design/tokens/motion';
import { categoryHue } from '../design/tokens/category';
import { RadiusTokens } from '../design/tokens/radius';
import { LayoutTokens, SpaceTokens } from '../design/tokens/space';
import { GalaxyTokens } from '../design/tokens/galaxy';
import { TypeTokens } from '../design/tokens/type';
import {
  HDS_MATERIAL_TYPE_IMMERSIVE,
  HDS_MATERIAL_LEVEL_EXQUISITE,
  PillImmersiveMaterialModifier,
  isImmersiveLightSenseSupported,
  isSystemMaterialActive,
} from '../utils/immersiveMaterial';
import { openCircleDetail, openPostDetail } from '../utils/nav';
import { getMainNavStack, openCircleDetailViaNav, openCircleDiscoverViaNav, PostDetailNavParams } from '../utils/navigationTransition';
import { registerOverlayBackGuard, unregisterOverlayBackGuard, OVERLAY_GUARD_CIRCLE } from '../utils/overlayBackGuard';
import { safeShowToast } from '../utils/toast';
import { CircleUniverse } from './CircleUniverse';
import { CircleDigestDock } from './CircleDigestDock';
import { CircleStarGuide } from './CircleStarGuide';
import { CircleOrbitCanvas, OrbitCircleItem, OrbitSeedPost } from './CircleOrbitCanvas';
import { HdsNavigation, HdsNavigationTitleMode, ScrollEffectType } from '@kit.UIDesignKit';
import type {
  HdsNavigationTitleBarOptions,
  TitleBarContentOptions,
  TitleBarStyleOptions,
  ScrollEffectOptions,
  SystemMaterialParams,
} from '@kit.UIDesignKit';
import { LengthMetrics } from '@kit.ArkUI';
import display from '@ohos.display';

// 展示兜底：只负责「第几环 / 多大」；色相由分类 token 决定。
// 名称、分类、简介、成员数、关注态、权重、未读、最近帖全部以服务端 overview 为准。
interface CircleVisualMeta {
  id: string;
  name: string;
  ring: number;
  size: number;
}

const CIRCLE_VISUALS: CircleVisualMeta[] = [
  // ===== 消费选购 =====
  { id: 'phone-tablet', name: '手机数码', ring: 0, size: 64 },
  { id: 'home-appliance', name: '家电选购', ring: 1, size: 54 },
  { id: 'second-hand', name: '二手闲置', ring: 1, size: 52 },
  { id: 'sports-gear', name: '运动装备', ring: 2, size: 46 },
  { id: 'refund-rights', name: '消费维权', ring: 2, size: 44 },
  // ===== 动手改造 =====
  { id: 'renovation', name: '装修避坑', ring: 0, size: 58 },
  { id: 'home-cooking', name: '家常菜谱', ring: 1, size: 50 },
  { id: 'pc-build', name: '电脑装机', ring: 1, size: 49 },
  { id: 'car-life', name: '用车经验', ring: 2, size: 42 },
  // ===== 职场与收入 =====
  { id: 'resume-interview', name: '求职面试', ring: 0, size: 56 },
  { id: 'career-growth', name: '职场成长', ring: 1, size: 48 },
  { id: 'budget-saving', name: '记账储蓄', ring: 1, size: 47 },
  { id: 'side-hustle', name: '副业探索', ring: 2, size: 40 },
  // ===== 生活与家庭 =====
  { id: 'dating', name: '恋爱心得', ring: 2, size: 44 },
  { id: 'marriage', name: '婚姻与家庭', ring: 2, size: 42 },
  { id: 'parenting', name: '育儿经验', ring: 2, size: 40 },
  { id: 'pets', name: '养猫养狗', ring: 2, size: 44 },
  { id: 'healthy-habits', name: '健康习惯', ring: 2, size: 42 },
  { id: 'renting', name: '租房买房', ring: 1, size: 46 },
  // ===== 兴趣休闲 =====
  { id: 'music-sharing', name: '音乐分享', ring: 2, size: 40 },
  { id: 'shows', name: '影视剧集', ring: 2, size: 40 },
  { id: 'travel-tips', name: '旅行出行', ring: 2, size: 40 },
  { id: 'food-review', name: '美食探店', ring: 2, size: 40 },
];

// 标签宽度必须纳入最外轨道的安全边距计算；过大会在 375vp 视口的左右边缘被裁切。
// PLANET_BOX_WIDTH / CENTER_AVATAR_SIZE 与 CircleOrbitCanvas 共用 GalaxyTokens 单一来源。
const TOP_ANGLE: number = -90;

// @Observed 保证乐观更新人数与 joined 状态能立即驱动星环和详情卡同步刷新。
@Observed
class CircleTag {
  id?: number;
  name: string = '';
  emoji?: string;
  category: string = '';
  followCount: number = 0;
  members: number = 0;
  ring: number = 1;
  size: number = 48;
  description: string = '';
  joined: boolean = false;
  // 同城圈：可出现在「已加入」列表与详情，但不进主星图/主目录。
  isCity: boolean = false;
  // 创建者 id（0=预置/同城圈）：仅创建者可删除自己的空圈
  creatorId: number = 0;
  // 引力档位（1=强/2=常/3=轻，缺省2）与未读新帖数（角标/星子）
  weight: number = 2;
  unread: number = 0;
  // 近 7 天有新帖（overview.active7d）
  hasActivity: boolean = false;
  // 该圈最新帖 id（overview.latestPosts[0]），星子/角标点击直达
  latestPostId: number = 0;
  latestPosts: CircleOverviewPost[] = [];

  constructor(meta: CircleVisualMeta, tag?: Tag, overview?: CircleOverviewItem) {
    this.id = tag?.id;
    this.name = overview?.name ?? meta.name;
    this.emoji = overview?.emoji ?? tag?.emoji;
    this.category = overview?.category ?? tag?.category ?? '';
    this.followCount = overview?.memberCount ?? tag?.followCount ?? 0;
    this.members = this.followCount;
    this.ring = meta.ring;
    this.size = meta.size;
    this.description = overview?.description ?? tag?.description ?? '';
    this.joined = overview?.joined ?? false;
    this.isCity = (overview?.cityCode ?? tag?.cityCode ?? '') !== ''
      || (overview?.category ?? tag?.category ?? '') === '同城';
    this.creatorId = overview?.creatorId ?? tag?.creatorId ?? 0;
    this.weight = overview?.weight ?? 2;
    this.unread = overview?.unread ?? 0;
    this.hasActivity = overview?.active7d ?? false;
    this.latestPosts = overview?.latestPosts ?? [];
    this.latestPostId = this.latestPosts.length > 0 ? this.latestPosts[0].id : 0;
  }
}

// 屏幕可视高度（vp）：星图深空背景首帧即铺满整屏，不等待 onAreaChange 测量。
function screenViewportHeightVp(): number {
  try {
    const d: display.Display = display.getDefaultDisplaySync();
    if (d.densityPixels <= 0 || d.height <= 0) {
      return 780;
    }
    return Math.round(d.height / d.densityPixels);
  } catch (e) {
    return 780;
  }
}

// ===== 星际模式配色（星图深空底上悬浮元素的反白组，与 CircleOrbitCanvas 夜空同调）=====
const COSMIC_PAGE_BG: string = '#151513';      // 页面底（与画布渐变中段同色）
const COSMIC_INK: string = '#ECE6DA';          // 标题/主文字（暖白星光）
const COSMIC_SUB: string = '#A8A094';          // 次级文字（暖灰）
const COSMIC_GLASS: string = '#1AECE6DA';      // 药丸兜底底/提示条

// 「已加入」与「发现圈子」共用的药丸（唯一样式源，两处只传内容与动作，不再各写一份配方）。
// 尺寸/内边距/圆角/字色/表面全部在此定义；内容由调用方以尾随闭包传入
// （「已加入」= 文案 + CountRoll，「发现圈子」= 文案）。
//
// 表面交给栏级沉浸材质：两颗药丸都驻留标题栏，表面走组件级系统材质轨。
// 栏级 systemMaterialEffect 只渲染栏面与官方 content.menu 槽位，**不会**给 stackBuilder
// 里的自绘组件加表面——所以自绘胶囊要玻璃感，只能自己挂组件级材质。
// 档位演进（2026-11-23）：REGULAR → THICK（用户反馈「不像返回键玻璃珠」，分段栏定稿档，
// 见 immersiveMaterial.ets 文字药丸档注释），全部标题栏文字药丸家族统一。
// 低版本（API<26）门禁不通过 → 落回原兜底色，视觉与改造前一致。
const PILL_MATERIAL_FILL: string = '#40FFFFFF';
@Component
struct CircleHeaderPill {
  @BuilderParam content: () => void = this.emptyContent;
  @Prop cosmicMode: boolean = false;
  @Prop darkMode: boolean = false;
  action: () => void = (): void => {};
  private materialModifier: PillImmersiveMaterialModifier = new PillImmersiveMaterialModifier();

  @Builder
  emptyContent(): void {}

  private materialActive(): boolean {
    return isSystemMaterialActive();
  }

  // 材质生效时底色透明（表面完全交给系统）；低版本落回原三档兜底。
  private pillBackground(): ResourceColor {
    if (this.materialActive()) {
      return Color.Transparent;
    }
    if (this.cosmicMode) {
      return COSMIC_GLASS;
    }
    // 深色无星（空态）时没有 COSMIC_GLASS 兜底，用 overlay 的 12.5% 白取同档抬升。
    return this.darkMode ? ColorTokens.overlay : PILL_MATERIAL_FILL;
  }

  build() {
    Pressable({
      visualHeight: LayoutTokens.segmentedHeight,
      touchTargetHeight: LayoutTokens.minTouchTarget,
      action: this.action,
    }) {
      Row({ space: SpaceTokens.xs }) {
        this.content()
      }
      .height(LayoutTokens.segmentedHeight)
      .padding({ left: SpaceTokens.md, right: SpaceTokens.md })
      .backgroundColor(this.pillBackground())
      .borderRadius(RadiusTokens.pill)
      .alignItems(VerticalAlign.Center)
      .attributeModifier(this.materialModifier)
    }
  }
}

@Component
export struct CircleTab {
  @State circles: CircleTag[] = [];
  // 星子队列：一颗 ✦ = 一篇真实的新帖（由 overview.latestPosts 直接构造，不再额外打帖子流）。
  // 空 = 星图不出星子。
  @State seedPosts: OrbitSeedPost[] = [];
  // 今日圈内：底部内容 Dock 的数据源（服务端已按「已加入优先」排好）
  @State digest: CircleDigestItem[] = [];
  // 计数变化统一经 @Watch 回写标题栏 @Link（initData 成功/失败/切号三处都会重赋 joinedNames）
  @State @Watch('onJoinedNamesChanged') joinedNames: string[] = [];
  // 顶栏（「圈子」标题 + 「已加入」药丸）迁入 Navigation 标题栏后由 Index 持有：
  // 计数经 @Link 回写标题栏；标题栏按钮点击经 seq 信号回传，由本组件 @Watch 承接弹窗
  // （profileShareSeq 同款「点击写值、@Watch 承接动作」接线，见教程 Step 2 状态归属）。
  @Link circleJoinedCount: number;
  // —— 顶栏（嵌套 HdsNavigation，路线 B，同首页结构）——
  // 星环视口 Scroller：交给 bindToScrollable 驱动标题栏渐变模糊（内容超高滚动时生效）
  private circleScroller: Scroller = new Scroller();
  @State loading: boolean = false;
  @State error: string = '';
  @State selectedName: string = '';
  @State centeredName: string = '';
  // 三条环各自保存角度。不能共用一个 orbitAngle，否则点击一颗行星会带动全部环线内容。
  @State innerOrbitAngle: number = 0;
  @State middleOrbitAngle: number = 0;
  @State outerOrbitAngle: number = 0;
  @State galaxySize: number = 343;
  // Scroll 视口实际高度（onAreaChange 测量）。初值取屏幕高（vp），避免首帧
  // 星图画布高度回退成 galaxySize（方形）导致深空背景不铺满整屏。
  @State scrollViewportHeight: number = screenViewportHeightVp();
  @State ringDragging: boolean = false;
  // 同城已并入发现 Sheet（城市筛选），不再有独立全屏城市层。

  // —— 星图 Live 一期：降落页 + 深空目录 ——
  @State landingName: string = '';
  @State @Watch('onLandingVisibleChanged') landingVisible: boolean = false;
  // 降落「镜头俯冲」（原型 holder scale+fade）：行星飞到中心后星图整体推近淡出，
  // 与降落层升起构成一段运镜；起飞时回位。仅 transform/opacity。
  @State galaxyDiveScale: number = 1;
  @State galaxyDiveOpacity: number = 1;
  // 星图首次图例：解释金环/亮度/红点与手势，看过后不再自动出现
  @State starGuideVisible: boolean = false;
  @StorageLink('circleStarGuideSeen') @Watch('onGuideSeenChanged') starGuideSeen: boolean = false;
  // 星际模式：深色=星图深空底色，悬浮其上的标题栏文字/药丸/Fab/提示条同步反白；
  // 浅色=「纸上星图」（白底墨线），走常规配色。空态/加载/降落层回退常规底色。
  @State cosmicMode: boolean = false;
  // 系统/应用深浅色标记（与 CircleOrbitCanvas 同源）；切换时重估星际模式。
  @StorageLink('isDarkMode') @Watch('onDarkModeChanged') isDarkMode: boolean = false;
  // 悬浮件避让用：内容 Stack 铺到窗口原点，状态栏那一段也在坐标系里。
  @StorageLink('statusBarHeight') statusBarHeight: number = 0;
  @StorageLink('authNickname') authNickname: string = '';
  @StorageLink('authAvatar') authAvatar: string = '';
  // 星系中心头像：以 authAvatar（登录响应缓存，可能有缺）为初始值，
  // 再从后端资料接口 getUserProfile 同步真实头像兜底，避免只显示首字母占位。
  @State selfAvatar: string = '';
  @StorageLink('authUserId') @Watch('onAccountSwitch') accountId: string = '';
  @StorageLink('authToken') @Watch('onTokenReady') token: string = '';
  @StorageLink('activeTab') @Watch('onActiveTab') activeTab: number = 0;
  @StorageLink('circleMembershipVersion') @Watch('onCircleMembershipChanged') circleMembershipVersion: number = 0;
  @StorageLink('circleLogoDismissVersion') @Watch('onCircleLogoDismissed') circleLogoDismissVersion: number = 0;
  // 圈子详情页标记已读后的即时回写信号：详情页是 Navigation 上的独立页面，
  // 返回本 Tab 不会再次触发 onActiveTab，必须靠信号把本地未读角标清零。
  @StorageLink('circleReadVersion') @Watch('onCircleReadSignal') circleReadVersion: number = 0;
  @StorageLink('circleReadName') circleReadName: string = '';
  private dragOffset: number = 0;
  private inertiaVelocity: number = 0;
  private inertiaTimer: number = 0;
  private autoOrbitTimer: number = 0;
  private focusReturnTimer: number = 0;
  // 数据加载版本号：多个触发点（切 Tab/登录/成员变化）可能并发 initData，
  // 旧响应必须丢弃，避免后到的旧数据覆盖新数据。
  private loadVersion: number = 0;
  // 最近一次成功加载时间：60s 内切回 Tab 直接复用，不重复请求。
  private lastLoadedAt: number = 0;
  // init 防抖：token/账号/成员信号可能在同一次会话切换里连续触发。
  private initTimer: number = 0;
  private pendingForceInit: boolean = false;
  private autoOrbitRunning: boolean = false;
  // 三条环各自维护自动旋转开关；任意时刻仅当前选中的一层会暂停。
  private autoOrbitEnabled: boolean[] = [true, true, true];
  private lastPlanetTapAt: number = 0;
  private activeRing: number = 0;
  // 同环布局计划：圈子名 → 实际所在环（-1 = 拥挤时不上星，仍完整留在发现/已加入入口）。
  // 容量按环半径与卡片盒宽计算，保证同一星环上任意两颗星的标签盒永不重叠。
  private ringPlanKey: string = '';
  private ringPlanCache: Map<string, number> = new Map<string, number>();
  aboutToAppear(): void {
    // 页内覆盖层返回守卫：Index 是 @Entry，真正的拦截在 Index.onBackPress；
    // 这里只登记「哪些层算打开、怎么关」，并按页面 id 消费，避免误关详情页的覆盖层。
    registerOverlayBackGuard(
      OVERLAY_GUARD_CIRCLE,
      (): boolean => this.activeTab === 1 && this.landingVisible,
      (): void => { this.takeoffLanding(); },
    );
    if (this.activeTab === 1) {
      this.scheduleInit(false);
    }
  }

  aboutToDisappear(): void {
    unregisterOverlayBackGuard(OVERLAY_GUARD_CIRCLE);
    this.clearInitTimer();
    this.stopInertia();
    this.stopAutoOrbit();
    this.clearFocusReturnTimer();
    this.centeredName = '';
  }

  onActiveTab(): void {
    if (this.activeTab === 1) {
      this.scheduleInit(false);
    } else {
      // TabContent 可能保持挂载：切走时先收起降落层，再停止后台角度刷新，
      // 避免下一次回到本页时仍停在宇宙里。
      if (this.landingVisible) {
        this.takeoffLanding();
      }
      this.stopAutoOrbit();
      this.clearFocusReturnTimer();
      this.centeredName = '';
    }
  }

  private onCircleMembershipChanged(): void {
    if (this.activeTab === 1 && this.token !== '') {
      this.scheduleInit(true);
    }
  }

  // 多个 @Watch 可能在同一轮状态变化里连续触发（登录会同时改 accountId 与 token），
  // 统一防抖到下一帧，最多只发一次 initData；force 表示必须跳过 60s 缓存。
  private scheduleInit(force: boolean): void {
    this.pendingForceInit = this.pendingForceInit || force;
    // 首屏在 16ms 防抖窗口内不能先闪一下空态：先立 loading。
    if (this.circles.length === 0) {
      this.loading = true;
    }
    if (this.initTimer !== 0) {
      clearTimeout(this.initTimer);
    }
    this.initTimer = setTimeout((): void => {
      this.initTimer = 0;
      const runForce: boolean = this.pendingForceInit;
      this.pendingForceInit = false;
      this.initData(runForce);
    }, 16) as number;
  }

  private clearInitTimer(): void {
    if (this.initTimer !== 0) {
      clearTimeout(this.initTimer);
      this.initTimer = 0;
    }
    this.pendingForceInit = false;
  }

  private onCircleLogoDismissed(): void {
    this.resumePausedOrbits();
  }

  private onCircleReadSignal(): void {
    const name: string = this.circleReadName;
    if (name.length === 0) {
      return;
    }
    const circle: CircleTag | undefined = this.circles.find((item: CircleTag): boolean => item.name === name);
    if (circle !== undefined && circle.unread > 0) {
      circle.unread = 0;
      this.circles = this.circles.slice();
    }
  }

  onTokenReady(): void {
    if (this.token !== '' && this.activeTab === 1) {
      this.scheduleInit(true);
    }
  }

  onAccountSwitch(): void {
    likeStore.clear();
    this.clearInitTimer();
    // 切号/登出时让在途请求整体作废，避免上一个账号的数据晚到覆盖当前界面。
    this.loadVersion += 1;
    this.lastLoadedAt = 0;
    if (getToken() !== '') {
      this.scheduleInit(true);
    } else {
      this.stopAutoOrbit();
      this.circles = [];
      this.digest = [];
      this.seedPosts = [];
      this.joinedNames = [];
      this.selectedName = '';
      this.centeredName = '';
      this.error = '';
      this.loading = false;
    }
  }

  // 同步自己的头像到星系中心：优先用已就绪的 authAvatar，不足/为空时从后端资料接口兜底拉取，
  // 并回写 authAvatar 让全 App 头像一致。authAvatar 为 @StorageLink，后端有头像时即时覆盖。
  private async syncSelfAvatar(): Promise<void> {
    const cached: string = (getCurrentUser()?.avatar ?? '') as string;
    if (cached.length > 0) {
      this.selfAvatar = cached;
      return;
    }
    const uid: number = getUserId();
    if (uid <= 0) {
      this.selfAvatar = '';
      return;
    }
    try {
      const p = await getUserProfile(uid);
      const avatar: string = p.avatar ?? '';
      this.selfAvatar = avatar;
      if (avatar.length > 0 && this.authAvatar.length === 0) {
        AppStorage.setOrCreate<string>('authAvatar', avatar);
        // authAvatar 已不在 PersistentStorage（会话键走 sessionStore 落盘），回写后需显式快照
        persistSessionSnapshot();
      }
    } catch (e) {
      this.selfAvatar = this.authAvatar;
    }
  }

  // 预置圈只提供视觉兜底（环/尺寸/色）；服务端新建圈统一落外环小尺寸。
  private visualFor(item: CircleOverviewItem): CircleVisualMeta {
    const preset: CircleVisualMeta | undefined =
      CIRCLE_VISUALS.find((visual: CircleVisualMeta): boolean => visual.name === item.name);
    if (preset !== undefined) {
      return preset;
    }
    return { id: 'server-' + item.name, name: item.name, ring: 2, size: 44 };
  }

  private visualForTag(tag: Tag): CircleVisualMeta {
    const name: string = tag.name ?? '';
    const preset: CircleVisualMeta | undefined =
      CIRCLE_VISUALS.find((visual: CircleVisualMeta): boolean => visual.name === name);
    if (preset !== undefined) {
      return preset;
    }
    return {
      id: tag.id !== undefined ? 'tag-' + tag.id : 'server-' + name,
      name,
      ring: 2,
      size: 44,
    };
  }

  // overview.latestPosts → 星子队列：同帖只投一颗，热度最高那颗为金色。
  private buildSeedPosts(circles: CircleTag[]): OrbitSeedPost[] {
    const seeds: OrbitSeedPost[] = [];
    const seen: Set<number> = new Set<number>();
    let hotId: number = 0;
    let hotScore: number = 0;
    circles.forEach((circle: CircleTag): void => {
      circle.latestPosts.forEach((post: CircleOverviewPost): void => {
        if (post.id <= 0 || seen.has(post.id)) {
          return;
        }
        seen.add(post.id);
        seeds.push({ postId: post.id, name: circle.name, gold: false });
        if (post.upCount > hotScore) {
          hotScore = post.upCount;
          hotId = post.id;
        }
      });
    });
    if (hotScore > 0) {
      seeds.forEach((seed: OrbitSeedPost): void => {
        if (seed.postId === hotId) {
          seed.gold = true;
        }
      });
    }
    return seeds.slice(0, 8);
  }

  private async initData(force: boolean = false): Promise<void> {
    // 60s 内切回本 Tab 直接复用内存数据：不再重拉、不重置轨道角度。
    // 但切走时自转被停了，回来必须重新点火，否则星图静止。
    if (!force && this.circles.length > 0 && Date.now() - this.lastLoadedAt < 60000) {
      this.startAutoOrbit();
      this.syncCosmicMode();
      return;
    }
    const version: number = this.loadVersion + 1;
    this.loadVersion = version;
    const hadData: boolean = this.circles.length > 0;
    this.clearFocusReturnTimer();
    this.centeredName = '';
    // 已有数据时不做整页 loading（避免切 Tab闪一下），只在首次进入显示加载态。
    this.loading = !hadData;
    this.error = '';
    this.syncSelfAvatar();
    try {
      // M2：一次拿齐圈子、关注态、权重、未读、成员数、最近帖与今日圈内。
      const overview = await getCircleOverview('main');
      if (version !== this.loadVersion) {
        return;
      }
      const next: CircleTag[] = overview.circles.map((item: CircleOverviewItem): CircleTag =>
        new CircleTag(this.visualFor(item), undefined, item));
      this.applyCircleData(next, overview.digest, hadData);
    } catch (e) {
      if (version !== this.loadVersion) {
        return;
      }
      // 旧后端还没上线 /v1/tags/overview 时退回旧接口组合，避免整页“加载失败”。
      if (this.isMissingOverviewApi(e)) {
        try {
          await this.loadLegacyData(version, hadData);
        } catch (legacyError) {
          if (version === this.loadVersion) {
            this.handleLoadError(legacyError, hadData);
          }
        }
        return;
      }
      this.handleLoadError(e, hadData);
    } finally {
      if (version === this.loadVersion) {
        this.loading = false;
      }
    }
  }

  // 统一应用一份圈子数据：角度、选中、自转、cosmic 模式、缓存时间都在这里收口。
  private applyCircleData(next: CircleTag[], digest: CircleDigestItem[], hadData: boolean): void {
    const previousSelected: string = this.selectedName;
    this.circles = next;
    this.digest = digest;
    this.seedPosts = this.buildSeedPosts(next);
    this.joinedNames = next.filter((circle: CircleTag) => circle.joined).map((circle: CircleTag) => circle.name);
    this.stopAutoOrbit();
    this.autoOrbitEnabled = [true, true, true];
    // 选中项只能从「会真正上星」的集合里挑，不能落到只在目录里的长尾圈。
    const visible: CircleTag[] = this.visibleStarCircles();
    if (!hadData) {
      // 首次进入才把环归零并把默认圈转到 12 点；后续刷新保持用户的空间记忆。
      this.innerOrbitAngle = 0;
      this.middleOrbitAngle = 0;
      this.outerOrbitAngle = 0;
      const initiallySelected: CircleTag | undefined =
        visible.find((circle: CircleTag) => circle.joined) ?? visible[0];
      this.selectedName = initiallySelected?.name ?? '';
      if (initiallySelected !== undefined) {
        this.activeRing = this.effectiveRing(initiallySelected);
        this.setRingAngle(this.activeRing, this.angleToTop(initiallySelected.name));
      }
    } else {
      // 刷新只校正选中项，不重置角度：用户离开再回来看到的仍是同一张星图。
      const keep: CircleTag | undefined = visible.find((circle: CircleTag) => circle.name === previousSelected)
        ?? visible.find((circle: CircleTag) => circle.joined) ?? visible[0];
      this.selectedName = keep?.name ?? '';
      if (keep !== undefined) {
        this.activeRing = this.effectiveRing(keep);
      }
    }
    this.startAutoOrbit();
    this.starGuideVisible = !this.starGuideSeen && this.hasStarCircles();
    this.syncCosmicMode();
    this.lastLoadedAt = Date.now();
  }

  private isMissingOverviewApi(error: Error): boolean {
    const message: string = error.message ?? '';
    return message.indexOf('接口不存在') >= 0 || message.indexOf('HTTP 404') >= 0;
  }

  private handleLoadError(error: Error, hadData: boolean): void {
    // 已有数据时后台刷新失败：保留现有星图，不把用户打回空态。
    this.error = error.message;
    if (!hadData) {
      this.circles = [];
      this.digest = [];
      this.seedPosts = [];
      this.joinedNames = [];
      this.selectedName = '';
      this.centeredName = '';
      this.cosmicMode = false;
    }
  }

  // 旧后端兜底：overview 不存在时退回旧的 tags/followed/weights/activity/posts 组合。
  // 只在滚动部署窗口使用；新后端上线后不会再走这里。
  private async loadLegacyData(version: number, hadData: boolean): Promise<void> {
    const tags: Tag[] = await listTags();
    if (version !== this.loadVersion) {
      return;
    }
    let followed: string[] = [];
    if (getToken() !== '') {
      try {
        followed = await listFollowedTags();
      } catch (e) {
        followed = [];
      }
    }
    if (version !== this.loadVersion) {
      return;
    }
    const next: CircleTag[] = [];
    tags.forEach((tag: Tag): void => {
      const name: string = tag.name ?? '';
      if (name.length === 0) {
        return;
      }
      const joined: boolean = followed.indexOf(name) >= 0;
      const isCity: boolean = (tag.cityCode ?? '') !== '' || (tag.category ?? '') === '同城';
      if (isCity && !joined) {
        return;
      }
      const circle: CircleTag = new CircleTag(this.visualForTag(tag), tag);
      circle.joined = joined;
      // 旧后端不一定有 activity 接口：先用 useCount 近似“有内容即亮星”。
      circle.hasActivity = (tag.useCount ?? 0) > 0;
      next.push(circle);
    });
    if (getToken() !== '') {
      try {
        const weights: TagWeightItem[] = await listTagWeights();
        const weightMap: Map<string, number> = new Map();
        weights.forEach((item: TagWeightItem): void => { weightMap.set(item.tagName, item.weight); });
        next.forEach((circle: CircleTag): void => {
          const weight: number | undefined = weightMap.get(circle.name);
          if (weight !== undefined) {
            circle.weight = weight;
          }
        });
      } catch (e) {
        // 权重失败保持默认 2
      }
      try {
        const activity: TagActivityItem[] = await listTagActivity();
        const actMap: Map<string, TagActivityItem> = new Map();
        activity.forEach((item: TagActivityItem): void => { actMap.set(item.tagName, item); });
        next.forEach((circle: CircleTag): void => {
          const item: TagActivityItem | undefined = actMap.get(circle.name);
          if (item !== undefined) {
            circle.hasActivity = item.active;
            circle.unread = item.unread;
            circle.latestPostId = item.latestPostId ?? 0;
          }
        });
      } catch (e) {
        // 活跃度失败保留 useCount 近似
      }
    }
    if (version !== this.loadVersion) {
      return;
    }
    // 旧后端兜底内容：最新 20 条帖子里按圈子挑，构造今日圈内与星子。
    const latestByCircle: Map<string, CircleOverviewPost[]> = new Map();
    const digest: CircleDigestItem[] = [];
    const usedCircles: Set<string> = new Set<string>();
    const nameSet: Set<string> = new Set<string>(next.map((circle: CircleTag): string => circle.name));
    try {
      const latest = await listPosts({ page: 1, limit: 20, sort: 'latest' });
      if (version !== this.loadVersion) {
        return;
      }
      latest.list.forEach((post: Post): void => {
        const postId: number = post.id ?? 0;
        if (postId <= 0) {
          return;
        }
        (post.tags ?? []).forEach((name: string): void => {
          if (!nameSet.has(name)) {
            return;
          }
          const bucket: CircleOverviewPost[] | undefined = latestByCircle.get(name);
          if (bucket === undefined) {
            latestByCircle.set(name, [{ id: postId, title: post.title ?? '', upCount: post.upCount ?? 0 }]);
          } else if (bucket.length < 2) {
            bucket.push({ id: postId, title: post.title ?? '', upCount: post.upCount ?? 0 });
          }
          if (!usedCircles.has(name) && digest.length < 3) {
            usedCircles.add(name);
            digest.push({
              postId,
              title: post.title ?? '',
              authorName: post.user?.nickname ?? '',
              circleName: name,
              upCount: post.upCount ?? 0,
              createdAt: post.createdAt ?? '',
            });
          }
        });
      });
    } catch (e) {
      // 帖子流失败：仍展示星图，只是没有内容 Dock/星子
    }
    next.forEach((circle: CircleTag): void => {
      const bucket: CircleOverviewPost[] | undefined = latestByCircle.get(circle.name);
      if (bucket !== undefined && bucket.length > 0) {
        circle.latestPosts = bucket;
        circle.latestPostId = bucket[0].id;
        circle.hasActivity = true;
      }
    });
    if (version !== this.loadVersion) {
      return;
    }
    this.applyCircleData(next, digest, hadData);
  }

  private jumpCircle(name: string): void {
    if (name.length === 0) {
      return;
    }
    // 内部入口优先走主 Navigation 栈；仅当 Navigation 未就绪时才回退 router 整页。
    if (openCircleDetailViaNav(name)) {
      console.info('jumpCircle via nav: ' + name);
      return;
    }
    openCircleDetail(name);
    console.info('jumpCircle via router: ' + name);
    this.getUIContext().getRouter().pushUrl({ url: 'pages/CircleDetailPage' });
  }

  // 圈子内点星子/角标 → 帖子详情：与圈子详情一致，优先 Navigation 栈。
  // 只有真正回退 router 时才写 nav 意图，避免 nav 模式下多写一次无用的模块变量。
  private openPostViaNav(postId: number): void {
    if (postId <= 0) {
      return;
    }
    const nav: NavPathStack | null = getMainNavStack();
    if (nav !== null) {
      const params: PostDetailNavParams = new PostDetailNavParams();
      params.postId = postId;
      nav.pushPathByName('PostDetail', params);
      return;
    }
    openPostDetail(String(postId));
    this.getUIContext().getRouter().pushUrl({ url: 'pages/DetailPage' });
  }

  // 引力档位 → 显示环：已加入圈子按 weight 落环（1=强→内环0，2=常→中环1，3=轻→外环2），
  // 未加入圈子保持 meta.ring。拖拽行星即改 weight → 行星换环 = 引力可视化。
  private displayRing(circle: CircleTag): number {
    if (!circle.joined) {
      return circle.ring;
    }
    const w: number = circle.weight;
    return w === 1 ? 0 : (w === 3 ? 2 : 1);
  }

  // 单个星环的容量：相邻两星的圆心弦距必须 ≥ 卡片盒宽 + 呼吸，
  // 否则两枚 72vp 宽的标签会在旋转中叠在一起。圆心角 θ = 2·asin(box / 2R)，容量 = ⌊360/θ⌋。
  private ringCapacity(ring: number): number {
    const radius: number = this.radiusForRing(ring);
    if (radius <= 0) {
      return 1;
    }
    const boxChord: number = GalaxyTokens.planetBoxWidth + SpaceTokens.xs;
    const ratio: number = Math.min(1, boxChord / (2 * radius));
    const step: number = 2 * Math.asin(ratio) * 180 / Math.PI;
    return Math.max(1, Math.floor(360 / step));
  }

  // 拥挤时的让位优先级：已加入 > 有未读 > 仅活跃；同级按名称稳定排序，
  // 避免刷新后环位在环间乱跳（同一份数据永远得到同一张布局）。
  private starRank(circle: CircleTag): number {
    if (circle.joined) {
      return 0;
    }
    return circle.unread > 0 ? 1 : 2;
  }

  // 环位计划：先按引力档位占位，超出容量的星先向外环顺延、再回内环补位；
  // 三条环都满时才不上星（-1），这些圈仍完整留在「发现圈子 / 已加入」入口。
  // 结果按数据内容缓存，逐颗行星取 baseAngle 时不会重复 O(n²) 计算。
  private ringPlan(): Map<string, number> {
    const items: CircleTag[] = this.starCircles().slice();
    let key: string = String(this.galaxySize) + '/' + String(this.scrollViewportHeight);
    for (const circle of items) {
      key += '|' + circle.name + ',' + this.displayRing(circle) + ',' + this.starRank(circle);
    }
    if (key === this.ringPlanKey) {
      return this.ringPlanCache;
    }
    items.sort((first: CircleTag, second: CircleTag): number => {
      const rank: number = this.starRank(first) - this.starRank(second);
      if (rank !== 0) {
        return rank;
      }
      if (first.name < second.name) {
        return -1;
      }
      return first.name > second.name ? 1 : 0;
    });
    const caps: number[] = [this.ringCapacity(0), this.ringCapacity(1), this.ringCapacity(2)];
    const used: number[] = [0, 0, 0];
    const plan: Map<string, number> = new Map<string, number>();
    const overflow: CircleTag[] = [];
    for (const circle of items) {
      const preferred: number = this.displayRing(circle);
      if (used[preferred] < caps[preferred]) {
        plan.set(circle.name, preferred);
        used[preferred] = used[preferred] + 1;
      } else {
        overflow.push(circle);
      }
    }
    for (const circle of overflow) {
      const preferred: number = this.displayRing(circle);
      let placed: number = -1;
      for (let ring: number = preferred + 1; ring < 3; ring++) {
        if (used[ring] < caps[ring]) {
          placed = ring;
          break;
        }
      }
      if (placed < 0) {
        for (let ring: number = 0; ring < preferred; ring++) {
          if (used[ring] < caps[ring]) {
            placed = ring;
            break;
          }
        }
      }
      if (placed >= 0) {
        plan.set(circle.name, placed);
        used[placed] = used[placed] + 1;
      } else {
        plan.set(circle.name, -1);
      }
    }
    this.ringPlanKey = key;
    this.ringPlanCache = plan;
    return plan;
  }

  // 行星实际所在的环（拥挤会让位）；-1 表示本轮不上星。
  private effectiveRing(circle: CircleTag): number {
    const planned: number | undefined = this.ringPlan().get(circle.name);
    return planned === undefined ? this.displayRing(circle) : planned;
  }

  // 真正会出现在星图上的圈子（排除环满时让位的长尾）。
  private visibleStarCircles(): CircleTag[] {
    return this.starCircles().filter((circle: CircleTag): boolean => this.effectiveRing(circle) >= 0);
  }

  private ringItems(ring: number): CircleTag[] {
    // 星图 Live 四期：角度均分只按「上星」子集计算——若按全量 circles 排 index，
    // 未上星的长尾圈会占位，导致可见行星角度重叠。
    return this.visibleStarCircles().filter((circle: CircleTag) => this.effectiveRing(circle) === ring);
  }

  // 每颗星的基础角度在环内严格均分。
  // 旧实现给每颗星加了 ±8° 的逐个偏移（避免机械正对），但相邻两颗的偏移方向相反时
  // 会把弦距压掉一大截，正好抵消容量计算——所以偏移改成「整环一个常量」：
  // 环与环之间不再对齐，环内间距恒定，容量保证才真正成立。
  private baseAngle(circle: CircleTag): number {
    const dr: number = this.effectiveRing(circle);
    const items: CircleTag[] = this.ringItems(dr);
    const index: number = Math.max(0, items.findIndex((item: CircleTag) => item.name === circle.name));
    const count: number = Math.max(1, items.length);
    const ringOffset: number[] = [0, 3, -1];
    return TOP_ANGLE + index * 360 / count + (ringOffset[dr] ?? 0);
  }

  private normalizedAngle(angle: number): number {
    let value: number = angle % 360;
    if (value > 180) {
      value -= 360;
    }
    if (value <= -180) {
      value += 360;
    }
    return value;
  }

  private angleDistance(first: number, second: number): number {
    return Math.abs(this.normalizedAngle(first - second));
  }

  private angleToTop(name: string): number {
    const circle: CircleTag | undefined = this.circles.find((item: CircleTag) => item.name === name);
    return circle === undefined ? 0 : this.normalizedAngle(TOP_ANGLE - this.baseAngle(circle));
  }

  private angleForRing(ring: number): number {
    if (ring === 0) {
      return this.innerOrbitAngle;
    }
    if (ring === 1) {
      return this.middleOrbitAngle;
    }
    return this.outerOrbitAngle;
  }

  private setRingAngle(ring: number, angle: number): void {
    // 运行角度单调累积，不归一化：避免每半圈 normalize 把 rotate 目标跳变 360° 引发回甩 glitch。
    // 归一化仅在“转到顶端”的吸附目标计算中使用（见 nearestAngleTo / angleToTop）。
    if (ring === 0) {
      this.innerOrbitAngle = angle;
    } else if (ring === 1) {
      this.middleOrbitAngle = angle;
    } else {
      this.outerOrbitAngle = angle;
    }
  }

  // 只在正在拨动的那一条环里寻找 12 点最近的行星，避免另外两环意外抢走选中态。
  private syncSelectedFromRing(ring: number): void {
    const items: CircleTag[] = this.ringItems(ring);
    let nearestIndex: number = -1;
    let nearestDistance: number = 361;
    const ringAngle: number = this.angleForRing(ring);
    for (let index: number = 0; index < items.length; index++) {
      const circle: CircleTag = items[index];
      const distance: number = this.angleDistance(this.baseAngle(circle) + ringAngle, TOP_ANGLE);
      if (distance < nearestDistance) {
        nearestIndex = index;
        nearestDistance = distance;
      }
    }
    if (nearestIndex >= 0 && items[nearestIndex].name !== this.selectedName) {
      this.selectedName = items[nearestIndex].name;
    }
  }

  private selectPlanet(circle: CircleTag): void {
    // 点击当前环时，先恢复之前暂停的环，确保始终只有当前环停住。
    // 注意用 effectiveRing（引力档位 + 拥挤让位后的实际所在环），不是 meta.ring。
    const dr: number = this.effectiveRing(circle);
    this.clearFocusReturnTimer();
    this.pauseOrbitExcept(dr);
    this.stopInertia();
    this.activeRing = dr;
    this.selectedName = circle.name;
    this.centeredName = circle.name;
  }

  private stopInertia(): void {
    if (this.inertiaTimer !== 0) {
      clearTimeout(this.inertiaTimer);
      this.inertiaTimer = 0;
    }
  }

  // 自动旋转只更新仍处于启用状态的环：内/外环顺时针，中环逆时针。
  // 16ms 一帧配合轻量 transform，离开页面或点击行星时立即清理。
  private startAutoOrbit(): void {
    if (this.autoOrbitRunning) {
      return;
    }
    if (!this.hasStarCircles()) {
      return;
    }
    this.autoOrbitRunning = true;
    hilog.info(0x0000, 'CircleTab', '星环自转启动');
    const tick = (): void => {
      if (!this.autoOrbitRunning) {
        this.autoOrbitTimer = 0;
        return;
      }
      // 环境公转降到 30fps：速度 0.22°/帧 ≈ 6.6°/秒（约 54 秒一圈），
      // 比 60fps 逐帧重算更省电，观感仍是连续缓动。
      const speed: number = 0.22;
      if (this.autoOrbitEnabled[0]) {
        this.setRingAngle(0, this.innerOrbitAngle + speed);
      }
      if (this.autoOrbitEnabled[1]) {
        this.setRingAngle(1, this.middleOrbitAngle - speed);
      }
      if (this.autoOrbitEnabled[2]) {
        this.setRingAngle(2, this.outerOrbitAngle + speed);
      }
      if (!this.autoOrbitEnabled[0] && !this.autoOrbitEnabled[1] && !this.autoOrbitEnabled[2]) {
        this.stopAutoOrbit();
        return;
      }
      this.autoOrbitTimer = setTimeout(tick, 33) as number;
    };
    this.autoOrbitTimer = setTimeout(tick, 33) as number;
  }

  private stopAutoOrbit(): void {
    const wasRunning: boolean = this.autoOrbitRunning;
    this.autoOrbitRunning = false;
    if (this.autoOrbitTimer !== 0) {
      clearTimeout(this.autoOrbitTimer);
      this.autoOrbitTimer = 0;
    }
    if (wasRunning) {
      hilog.info(0x0000, 'CircleTab', '星环自转停止');
    }
  }

  private clearFocusReturnTimer(): void {
    if (this.focusReturnTimer !== 0) {
      clearTimeout(this.focusReturnTimer);
      this.focusReturnTimer = 0;
    }
  }

  private resumeAllOrbits(): void {
    this.autoOrbitEnabled = [true, true, true];
    this.startAutoOrbit();
  }

  private pauseOrbitExcept(ring: number): void {
    this.autoOrbitEnabled = [true, true, true];
    if (ring >= 0 && ring < this.autoOrbitEnabled.length) {
      this.autoOrbitEnabled[ring] = false;
    }
  }

  private resumePausedOrbits(): void {
    // 子 Logo 的点击可能冒泡到星系背景，短时间内忽略这次背景事件。
    if (Date.now() - this.lastPlanetTapAt < 150) {
      return;
    }
    if (this.circles.length === 0) {
      return;
    }
    if (this.centeredName.length > 0) {
      this.centeredName = '';
      this.clearFocusReturnTimer();
      // 等 Logo 回到暂停时保存的圆环位置，再恢复三环旋转。
      this.focusReturnTimer = setTimeout(() => {
        this.focusReturnTimer = 0;
        this.resumeAllOrbits();
      }, MotionTokens.emphasis) as number;
      return;
    }
    if (this.autoOrbitEnabled[0] && this.autoOrbitEnabled[1] && this.autoOrbitEnabled[2]) {
      return;
    }
    this.resumeAllOrbits();
  }

  // ArkUI 没有浏览器 rAF；以 16ms 任务帧等价实现速度衰减，且仅更新 transform 所需的角度状态。
  private startInertia(): void {
    if (Math.abs(this.inertiaVelocity) < 0.08) {
      this.syncSelectedFromRing(this.activeRing);
      this.resumePausedOrbits();
      return;
    }
    this.stopInertia();
    const tick = (): void => {
      this.setRingAngle(this.activeRing, this.angleForRing(this.activeRing) + this.inertiaVelocity);
      this.inertiaVelocity *= 0.91;
      this.syncSelectedFromRing(this.activeRing);
      if (Math.abs(this.inertiaVelocity) > 0.08) {
        this.inertiaTimer = setTimeout(tick, 16) as number;
      } else {
        this.inertiaTimer = 0;
        // onRingPanStart 只暂停被拨的这一环，惯性收尾后必须复位，否则该环从此不再自转。
        this.resumePausedOrbits();
      }
    };
    this.inertiaTimer = setTimeout(tick, 16) as number;
  }

  // 拨哪一环转哪一环：环由触点半径决定（画布回报）。
  // 旧实现全程只用 activeRing（仅由「上次选中的圈 / 点击的行星」决定，拖拽不改它），
  // 于是无论按在哪里都只转那一环 —— 表现为「拨动任意区域只有最内层星环在转动」。
  private onRingPanStart(ring: number): void {
    if (this.centeredName.length > 0) {
      return;
    }
    if (ring >= 0 && ring < this.autoOrbitEnabled.length) {
      this.activeRing = ring;
    }
    this.stopInertia();
    // 拖动期间只暂停「正在拨动的这一环」，其余两环保持自转；
    // 复位三环开关再单独关掉当前环，避免上一轮拖动的环一直停着。
    this.pauseOrbitExcept(this.activeRing);
    this.dragOffset = 0;
    this.inertiaVelocity = 0;
    this.ringDragging = true;
  }

  private onRingPanUpdate(event: GestureEvent): void {
    if (this.centeredName.length > 0 || !this.ringDragging) {
      return;
    }
    const delta: number = event.offsetX - this.dragOffset;
    this.dragOffset = event.offsetX;
    this.inertiaVelocity = delta * 0.22;
    this.setRingAngle(this.activeRing, this.angleForRing(this.activeRing) + this.inertiaVelocity);
    this.syncSelectedFromRing(this.activeRing);
  }

  private onRingPanEnd(): void {
    if (!this.ringDragging) {
      return;
    }
    this.ringDragging = false;
    this.startInertia();
  }

  // 环半径的基准边长：窄屏取画布宽（环被左右边距约束），宽屏改受竖向净空约束。
  // 星环是正圆，展开屏宽 707vp 但可视高只有 ~773vp：若仍以宽为基准，外环半径 325vp
  // 会把顶部行星送进标题栏、底部行星送进 Dock。竖向净空 = 圆心(高×0.42) 到标题栏底
  // 再让出行星半盒与一档呼吸；sm 上该基准(≈369)大于画布宽(363.5)，行为不变。
  private orbitBasis(): number {
    const centerY: number = this.scrollViewportHeight * 0.42;
    const verticalBudget: number = centerY - this.circleTitleBarHeight() - GalaxyTokens.planetBoxWidth / 2 - SpaceTokens.md;
    const budgetBasis: number = Math.max(240, (verticalBudget - SpaceTokens.xs) / 0.46);
    return Math.min(this.galaxySize, budgetBasis);
  }

  private radiusForRing(ring: number): number {
    // 先确定内环距头像的安全距离，再在可用空间内等分两段。
    // 不能从外环按大间距硬向内回推，否则 375vp 视口会把内环压到头像上。
    const basis: number = this.orbitBasis();
    const maxOuterRadius: number = Math.max(
      0,
      // 星系视口本身已有 4vp 页边距，无需在半径内重复预留，外环可再向外扩展。
      basis / 2 - GalaxyTokens.planetBoxWidth / 2,
    );
    // 标签容器不再参与选中缩放，可安全借用页面两侧的 4vp 边距再外扩一档。
    const outerRadius: number = Math.min(basis * 0.46, maxOuterRadius) + SpaceTokens.xs;
    // 从头像外缘到最外环的可用径向距离严格三等分：
    // avatar→内环 = 内环→中环 = 中环→外环。
    const avatarEdgeRadius: number = GalaxyTokens.centerAvatarSize / 2;
    const ringGap: number = Math.max(18, (outerRadius - avatarEdgeRadius) / 3);
    const innerRadius: number = avatarEdgeRadius + ringGap;
    const middleRadius: number = innerRadius + ringGap;
    if (ring <= 0) {
      return innerRadius;
    }
    if (ring === 1) {
      return middleRadius;
    }
    return outerRadius;
  }

  // 星图只挂「你的 + 近 7 天活跃的 + 有未读的」；其余长尾圈交给深空目录。
  // overview 不再提供 useCount / activeScore，避免“有历史帖就永远上星”的伪活跃。
  private starCircles(): CircleTag[] {
    return this.circles.filter((circle: CircleTag): boolean =>
      !circle.isCity && (circle.joined || circle.hasActivity || circle.unread > 0));
  }

  private hasStarCircles(): boolean {
    return this.visibleStarCircles().length > 0;
  }

  // Canvas 用基础角度、所属圆环的实时角度和半径共同计算 Logo 位置。
  private orbitItems(): OrbitCircleItem[] {
    return this.visibleStarCircles().map((circle: CircleTag): OrbitCircleItem => ({
      name: circle.name,
      category: circle.category,
      size: circle.size,
      ring: this.effectiveRing(circle),
      baseAngle: this.baseAngle(circle),
      joined: circle.joined,
      // 活跃度：overview.active7d 是唯一口径
      active: circle.hasActivity,
      unread: circle.unread,
      magnitude: this.magnitudeFor(circle),
    }));
  }

  private orbitAngles(): number[] {
    return [this.innerOrbitAngle, this.middleOrbitAngle, this.outerOrbitAngle];
  }

  private orbitRadii(): number[] {
    return [this.radiusForRing(0), this.radiusForRing(1), this.radiusForRing(2)];
  }

  private onPlanetPressed(name: string): void {
    const circle: CircleTag | undefined = this.circles.find((item: CircleTag) => item.name === name);
    if (circle === undefined) {
      return;
    }
    this.lastPlanetTapAt = Date.now();
    this.selectPlanet(circle);
    // 星图 Live：点行星 = 降落（轻详情层）。选中/飞心编舞照常播放，
    // 降落层延迟入场，让「行星飞到 12 点」与「页面升起」形成两段式节奏。
    this.landingName = name;
    setTimeout((): void => { this.landingVisible = true; }, MotionTokens.emphasis) as number;
  }

  private takeoffLanding(): void {
    this.landingVisible = false;
    this.landingName = '';
    this.resumePausedOrbits();
  }

  // ===== 引力拖拽 / 星子 =====

  // 亮度只由近 7 天活跃决定；overview 不提供星等后，耀星光晕不再触发，
  // 星图回到“亮=有活跃 / 暗=已加入但近期无帖”的单一编码。
  private magnitudeFor(circle: CircleTag): number {
    return circle.hasActivity ? 1 : 0;
  }

  // 拖拽行星开始：冻结该行星所在环的自转，避免拖拽期间行星漂移。
  private onGravityStart(name: string): void {
    const circle: CircleTag | undefined = this.circles.find((item: CircleTag) => item.name === name);
    if (circle === undefined) {
      return;
    }
    this.stopAutoOrbit();
    this.stopInertia();
    this.pauseOrbitExcept(this.effectiveRing(circle));
  }

  // 触点距圆心 → 最近档位（1/2/3）。以三条环半径为基准吸附。
  private weightForDistance(distance: number): number {
    const radii: number[] = this.orbitRadii();
    let best: number = 2;
    let bestGap: number = -1;
    for (let i: number = 0; i < radii.length; i++) {
      const gap: number = Math.abs(distance - radii[i]);
      if (bestGap < 0 || gap < bestGap) {
        bestGap = gap;
        best = i + 1;
      }
    }
    return best;
  }

  // 拖拽结束：换算档位 → 本地即时换环（行星跳环）+ 落库；失败回滚。
  private onGravityEnd(name: string, distance: number): void {
    const circle: CircleTag | undefined = this.circles.find((item: CircleTag) => item.name === name);
    if (circle === undefined) {
      this.resumePausedOrbits();
      return;
    }
    const target: number = this.weightForDistance(distance);
    const previous: number = circle.weight;
    if (target === previous) {
      this.resumePausedOrbits();
      return;
    }
    circle.weight = target;
    this.circles = this.circles.slice();
    const labels: string[] = ['强关注 · 每日推荐更偏向它', '常关注 · 按常规参与推荐', '轻关注 · 每日推荐少一些'];
    safeShowToast(this.getUIContext(), { message: circle.emoji + ' ' + circle.name + ' → ' + labels[target - 1] });
    setTagWeight(name, target).then((): void => {
      this.resumePausedOrbits();
    }).catch((e: Error): void => {
      // 落库失败：回滚档位，透出真实原因便于定位（403=后端无关注记录 / 500=表缺失或异常）
      circle.weight = previous;
      this.circles = this.circles.slice();
      safeShowToast(this.getUIContext(), { message: '调节失败：' + (e as Error).message });
      this.resumePausedOrbits();
    });
  }

  // 拖动未加入行星：不改变引力，弹加入引导（转化钩子）。
  private onGravityBlocked(name: string): void {
    const circle: CircleTag | undefined = this.circles.find((item: CircleTag) => item.name === name);
    safeShowToast(this.getUIContext(), {
      message: (circle?.emoji ?? '') + '「' + name + '」还未加入 · 加入后才能调节引力档位',
    });
    this.resumePausedOrbits();
  }

  // 星子点击 = 读那一帖：星子自带 postId（投放时来自帖子流），直接打开。
  // 与「点行星 = 降落逛圈子」语义彻底分离——星子悬在行星旁边，点它却打开星球页，
  // 用户感知就是「点开了离触点最近的星球」。
  // postId<=0 只可能来自行星的未读角标（角标只代表「该圈有新帖」，不带帖子 id），
  // 此时按圈子实时取最新一帖；真的取不到才退回降落页读帖子流。
  private async onSeedTap(name: string, postId: number): Promise<void> {
    const circle: CircleTag | undefined = this.circles.find((item: CircleTag) => item.name === name);
    if (circle === undefined) {
      return;
    }
    this.dismissStarGuide();
    if (circle.unread > 0) {
      circle.unread = 0;
      this.circles = this.circles.slice();
    }
    markTagRead(name).catch((): void => {});
    let target: number = postId;
    if (target <= 0) {
      target = circle.latestPostId;
    }
    if (target <= 0) {
      target = await this.fetchLatestPostId(name);
      circle.latestPostId = target;
    }
    if (target > 0) {
      this.openPostViaNav(target);
      return;
    }
    // 兜底：该圈确实取不到任何帖子 → 降落页读帖子流
    this.selectPlanet(circle);
    this.landingName = name;
    setTimeout((): void => { this.landingVisible = true; }, MotionTokens.emphasis) as number;
  }

  private async fetchLatestPostId(name: string): Promise<number> {
    try {
      const result = await listPosts({ page: 1, limit: 1, sort: 'latest', tag: name });
      const first: Post | undefined = result.list.length > 0 ? result.list[0] : undefined;
      return first?.id ?? 0;
    } catch (e) {
      return 0;
    }
  }

  // 进入圈子（降落）即标记已读：角标/星子归零（登录后异步，失败静默）。
  private markLandingRead(name: string): void {
    if (getToken() === '' || name.length === 0) {
      return;
    }
    const circle: CircleTag | undefined = this.circles.find((item: CircleTag) => item.name === name);
    if (circle !== undefined && circle.unread > 0) {
      circle.unread = 0;
      this.circles = this.circles.slice();
    }
    markTagRead(name).catch((): void => {});
  }

  // 星际模式开关：星图有星可看且降落层未升起时为 true。
  // 深空画布是恒定的，但标题栏文字/药丸/Fab/提示条要跟着反白；
  // 空态、加载、降落层（浅色内容）时回退常规配色，避免白字白底。
  // 浅色模式走「纸上星图」（白底墨线），悬浮元素本就用常规深色文字，无需反白。
  private syncCosmicMode(): void {
    const hasStars: boolean = this.hasStarCircles();
    this.cosmicMode = hasStars && !this.landingVisible && this.isDarkMode;
  }

  // 深浅色切换：星图画布自动换调色板，页面反白状态需重估。
  private onDarkModeChanged(): void {
    this.syncCosmicMode();
  }

  // 首次图例：看过后持久化；点「知道了」或进入降落/发现都视为已读。
  private dismissStarGuide(): void {
    this.starGuideVisible = false;
    this.starGuideSeen = true;
    AppStorage.setOrCreate<boolean>('circleStarGuideSeen', true);
  }

  private onGuideSeenChanged(): void {
    if (this.starGuideSeen) {
      this.starGuideVisible = false;
    }
  }

  // 降落层可见性变化：升起时标记该圈已读（角标归零），并上演「镜头俯冲」——
  // 星图推近淡出让位给降落页；起飞时回位（原型 holder scale(2.8)+opacity .16）。
  private onLandingVisibleChanged(): void {
    if (this.landingVisible) {
      this.dismissStarGuide();
      // 降落层是浅色内容页 → 悬浮元素配色回退常规
      this.cosmicMode = false;
      this.markLandingRead(this.landingName);
      this.getUIContext().animateTo({ duration: 620, curve: MotionCurves.emphasized }, () => {
        this.galaxyDiveScale = 1.8;
        this.galaxyDiveOpacity = 0.12;
      });
    } else {
      this.syncCosmicMode();
      this.getUIContext().animateTo({ duration: MotionTokens.slow, curve: MotionCurves.springSoft }, () => {
        this.galaxyDiveScale = 1;
        this.galaxyDiveOpacity = 1;
      });
    }
  }

  // 加入/退出回报：本地即时更新 circles（金环/计数/目录态）。
  // 不广播 membershipVersion 触发 initData——避免重拉打断降落编舞；
  // 详情页等外部一致性由下一次进入本页/显式刷新兜底（目录加入路径除外，见 joinFromCatalog）。
  private applyJoinLocal(name: string, joined: boolean): void {
    const circle: CircleTag | undefined = this.circles.find((item: CircleTag) => item.name === name);
    if (circle === undefined) {
      return;
    }
    circle.joined = joined;
    circle.followCount = Math.max(0, circle.followCount + (joined ? 1 : -1));
    circle.members = circle.followCount;
    this.circles = this.circles.slice();
    this.joinedNames = this.circles.filter((item: CircleTag) => item.joined).map((item: CircleTag) => item.name);
  }

  private onLandingJoinChanged(joined: boolean): void {
    this.applyJoinLocal(this.landingName, joined);
  }

  // 降落页「删除这个圈子」：只有创建者本人可见（creatorId 与当前登录用户一致）。
  private canDeleteLanding(): boolean {
    const circle: CircleTag | undefined = this.landingCircle();
    const uid: number = getUserId();
    return circle !== undefined && uid > 0 && circle.creatorId === uid;
  }

  private confirmDeleteLanding(): void {
    const circle: CircleTag | undefined = this.landingCircle();
    if (circle === undefined) {
      return;
    }
    const name: string = circle.name;
    this.getUIContext().showAlertDialog({
      title: '删除「' + name + '」？',
      message: '删除后无法恢复，圈子里的关注记录也会清空；圈子里已有帖子时不能删除。',
      primaryButton: { value: '取消', action: (): void => {} },
      secondaryButton: {
        value: '删除',
        fontColor: $r('app.color.semantic_red'),
        action: async (): Promise<void> => { await this.deleteLandingCircle(name); },
      },
    });
  }

  private async deleteLandingCircle(name: string): Promise<void> {
    try {
      await deleteTag(name);
      this.circles = this.circles.filter((item: CircleTag) => item.name !== name);
      this.joinedNames = this.circles
        .filter((item: CircleTag) => item.joined)
        .map((item: CircleTag) => item.name);
      if (this.selectedName === name) {
        const remaining: CircleTag[] = this.visibleStarCircles();
        this.selectedName = remaining.length > 0 ? remaining[0].name : '';
      }
      if (this.centeredName === name) {
        this.centeredName = '';
      }
      this.takeoffLanding();
      safeShowToast(this.getUIContext(), { message: '圈子已删除' });
      const version: number = AppStorage.get<number>('circleMembershipVersion') ?? 0;
      AppStorage.setOrCreate('circleMembershipVersion', version + 1);
    } catch (e) {
      safeShowToast(this.getUIContext(), { message: '删除失败：' + (e as Error).message });
    }
  }

  private joinedCircles(): CircleTag[] {
    return this.circles.filter((circle: CircleTag) => circle.joined);
  }

  // 已加入列表变化 → 回写标题栏计数（Index 的 circleTitleBar 读取）
  private onJoinedNamesChanged(): void {
    this.circleJoinedCount = this.joinedNames.length;
  }

  @Builder
  galaxy(): void {
    CircleOrbitCanvas({
      galaxySize: this.galaxySize,
      galaxyHeight: this.scrollViewportHeight,
      ringAngles: this.orbitAngles(),
      radii: this.orbitRadii(),
      circles: this.orbitItems(),
      selectedName: this.selectedName,
      centeredName: this.centeredName,
      ringDragging: this.ringDragging,
      avatar: this.selfAvatar,
      nickname: this.authNickname,
      live: this.activeTab === 1,
      seedPosts: this.seedPosts,
      onPlanet: (name: string): void => { this.onPlanetPressed(name); },
      onGravityStart: (name: string): void => { this.onGravityStart(name); },
      onGravityEnd: (name: string, distance: number): void => { this.onGravityEnd(name, distance); },
      onGravityBlocked: (name: string): void => { this.onGravityBlocked(name); },
      onSeedTap: (name: string, postId: number): void => { this.onSeedTap(name, postId); },
      onPanStart: (ring: number): void => { this.onRingPanStart(ring); },
      onPanUpdate: (event: GestureEvent): void => { this.onRingPanUpdate(event); },
      onPanEnd: (): void => { this.onRingPanEnd(); },
    })
  }

  // 星图 Live：底部资料卡（CircleSelectionCard）已移除——轻详情由降落层承担，
  // 点行星即降落读帖/加入；选中行星仍保留飞心 + 涟漪编舞。

  // —— 顶栏（嵌套 HdsNavigation，路线 B，同首页结构，但避让策略相反）——
  // MINI + stackBuilder 品牌行（「圈子」标题 + 「已加入」/「发现圈子」两颗药丸）
  // + 栏级 IMMERSIVE/EXQUISITE 材质 + 沉浸渐变模糊。
  // 注意素材侧：本页 Scroll 禁用了滚动交互（星图是固定画布），滚动特效永远不会进入
  // 生效区间，栏面观感**全靠栏级材质常驻**，不能只靠 scrollEffect 兜。
  // avoidLayoutSafeArea=true：标题栏自己让开状态栏（品牌行不被时钟压住）。
  // enableComponentSafeArea=false（首页为 true）：内容不被标题栏顶下去——
  // 星图是全屏沉浸画布，必须铺到状态栏与标题栏之下，由材质栏悬浮其上做采样；
  // 开着 true 时画布从栏下方才开始，顶部就留下一条栏底色的白带（浅色尤其明显）。
  private circleHdsTitleBarOptions(): HdsNavigationTitleBarOptions {
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
        backgroundStyle: { backgroundColor: Color.Transparent },
      },
    };
    if (immersive) {
      // 档位传数值字面量而非 hdsMaterial 枚举：该模块在 API 22 上不存在，值 import 即崩。
      style.systemMaterialEffect = {
        materialType: HDS_MATERIAL_TYPE_IMMERSIVE,
        materialLevel: HDS_MATERIAL_LEVEL_EXQUISITE,
      } as SystemMaterialParams;
    }
    const content: TitleBarContentOptions = {
      stackBuilder: (): void => { this.circleBrandRow(); },
    };
    const options: HdsNavigationTitleBarOptions = {
      content: content,
      style: style,
      avoidLayoutSafeArea: true,
      enableComponentSafeArea: false,
    };
    return options;
  }

  // 悬浮元素需要避让的顶栏高度。enableComponentSafeArea=false 后内容 Stack 的顶边
  // 落在窗口原点（画布因此能铺到状态栏上），position 的 y 也就是从 0 起算——
  // 必须自己加回状态栏 + 品牌行，否则悬浮件会压在时钟和「已加入」药丸上。
  private circleTitleBarHeight(): number {
    return this.statusBarHeight + LayoutTokens.titleBarHeight;
  }

  // stackBuilder 品牌行：「圈子」标题 + 「已加入」/「发现圈子」两颗药丸。
  // 计数经 @Link 回写；点击「已加入」递增 seq 信号，由本组件 @Watch 承接弹窗。
  // 状态栏避让由 avoidLayoutSafeArea(true) 承担（不再手动补 statusBarHeight 内边距）。
  @Builder
  circleBrandRow() {
    Row({ space: SpaceTokens.sm }) {
      Text('圈子')
        .fontSize(TypeTokens.titleSerif.size).fontFamily(TypeTokens.fontFamilySerif)
        .fontWeight(TypeTokens.titleSerif.weight)
        .lineHeight(TypeTokens.titleSerif.lineHeight)
        .fontColor(this.cosmicMode ? COSMIC_INK : ColorTokens.primary)
      Blank()
      CircleHeaderPill({
        cosmicMode: this.cosmicMode,
        darkMode: this.isDarkMode,
        action: (): void => {
          // 已加入列表已并入发现页第二页签（不再开 CustomDialog）
          openCircleDiscoverViaNav(1);
        },
      }) {
        Text('已加入')
          .fontSize(TypeTokens.caption.size).fontFamily(TypeTokens.fontFamily)
          .fontWeight(TypeTokens.caption.weight)
          .fontColor(this.cosmicMode ? COSMIC_SUB : ColorTokens.secondary)
        CountRoll({ value: this.circleJoinedCount, prefix: '', textSize: TypeTokens.caption.size, textColor: this.cosmicMode ? COSMIC_INK : ColorTokens.primary })
        Text('个')
          .fontSize(TypeTokens.caption.size).fontFamily(TypeTokens.fontFamily)
          .fontWeight(TypeTokens.caption.weight)
          .fontColor(this.cosmicMode ? COSMIC_SUB : ColorTokens.secondary)
      }
      // 探索星云入口：原为星图右上悬浮药丸，材质在标题栏外不出图只能复刻着色；
      // 2026-11-19 迁入标题栏，与「已加入」同排，表面由栏级材质接管。
      CircleHeaderPill({
        cosmicMode: this.cosmicMode,
        darkMode: this.isDarkMode,
        action: (): void => {
          // 发现页为独立 NavDestination（半模态装不下内容橱窗，且同页只能有一个 bindSheet）
          this.dismissStarGuide();
          openCircleDiscoverViaNav(0);
        },
      }) {
        Text('发现圈子')
          .fontSize(TypeTokens.caption.size).fontFamily(TypeTokens.fontFamily)
          .fontWeight(TypeTokens.caption.weight)
          .fontColor(this.cosmicMode ? COSMIC_SUB : ColorTokens.secondary)
      }
    }
    .width('100%')
    .alignItems(VerticalAlign.Center)
    // 标题左右边距统一为「我的」页基准 base(16vp)，四页 Title 与屏幕左缘等距。
    .padding({ left: SpaceTokens.base, right: SpaceTokens.base, top: SpaceTokens.xs, bottom: SpaceTokens.xs })
    // 五个 tab 顶部区域手势隔离（fix-tab-top-gesture-isolation，机制见 HomeTab.homeBrandRow 注释）：
    // priorityGesture 横向 Pan 空手势优先于 HdsTabs 内建翻页——顶部拖动不触发切页，点击/纵滚不受影响。
    // 与历史已回退的「拖动锁」不同：那是全局锁整页（干扰珠体拖拽/Swiper），这里只在顶栏行内
    // 做子组件优先仲裁，范围仅标题行，不触碰珠体拖拽与主体区滑动。
    .priorityGesture(
      PanGesture({ direction: PanDirection.Horizontal, fingers: 1, distance: 5 })
        .onActionStart((): void => {})
        .onActionUpdate((_e: GestureEvent): void => {})
        .onActionEnd((): void => {})
    )
  }

  private landingCircle(): CircleTag | undefined {
    return this.circles.find((item: CircleTag) => item.name === this.landingName);
  }

  // 降落页泛光：按圈子分类取低饱和色相，深色模式自动提亮。
  private landingAccent(): string {
    const circle: CircleTag | undefined = this.landingCircle();
    return circle !== undefined ? categoryHue(circle.category, this.cosmicMode) : GalaxyTokens.brandAccentFallback;
  }

  // 今日圈内 Dock：内容优先，0 次点击可读；没有 digest 时才退回操作提示胶囊。
  @Builder
  digestDock() {
    Column() {
      CircleDigestDock({
        items: this.digest,
        maxItems: this.scrollViewportHeight < 720 ? 2 : 3,
        onOpen: (postId: number): void => { this.openPostViaNav(postId); },
      })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Center)
    .position({ x: 0, y: '100%' })
    .markAnchor({ y: '100%' })
    .padding({ left: SpaceTokens.base, right: SpaceTokens.base, bottom: barBottomReserve() + SpaceTokens.sm })
  }

  // 首次图例卡：只出现一次，替代旧的一行提示条；看完后让位给今日圈内 Dock。
  @Builder
  starGuideCard() {
    Column() {
      CircleStarGuide({ onDismiss: (): void => { this.dismissStarGuide(); } })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Center)
    .position({ x: 0, y: '100%' })
    .markAnchor({ y: '100%' })
    .padding({ left: SpaceTokens.base, right: SpaceTokens.base, bottom: barBottomReserve() + SpaceTokens.sm })
  }

  build() {
    // 顶栏（圈子标题 + 已加入药丸）迁入嵌套 HdsNavigation（路线 B，同首页定稿结构）
    HdsNavigation() {
    Stack({ alignContent: Alignment.TopStart }) {
      Column() {
        if (this.circles.length === 0 && this.loading) {
          Column({ space: SpaceTokens.md }) {
            LoadingProgress().width(IconTokens.empty).height(IconTokens.empty)
            Text('加载中…')
              .fontSize(TypeTokens.callout.size).fontFamily(TypeTokens.fontFamily)
              .fontWeight(TypeTokens.callout.weight)
              .lineHeight(TypeTokens.callout.lineHeight)
              .fontColor(ColorTokens.secondary)
          }
          .layoutWeight(1)
          .width('100%')
          .justifyContent(FlexAlign.Center)
        } else if (!this.hasStarCircles()) {
          // 数据加载成功但没有一颗可用行星（未加入 + 无活跃 + 无内容）：
          // 不能只留三条空环和一句操作提示，必须给可执行的下一步。
          Column() {
            EmptyState({
              title: this.error && this.circles.length === 0 ? '加载失败' : '星图还没有亮星',
              message: this.error && this.circles.length === 0
                ? this.error : '先加入几个圈子，或者去发现正在活跃的圈子',
              actionLabel: this.error && this.circles.length === 0 ? '重试' : '去发现',
              onAction: (): void => {
                if (this.error && this.circles.length === 0) {
                  this.initData(true);
                } else {
                  this.dismissStarGuide();
                  openCircleDiscoverViaNav(0);
                }
              },
            })
          }
          .layoutWeight(1)
          .width('100%')
          .justifyContent(FlexAlign.Center)
        } else {
          // 星图 Live 四期：全屏沉浸星图（原型 s2-galaxy-holder inset:0）——
          // 画布铺满视口，星系中心在 (宽/2, 高×0.42)，标题栏/Tab 栏悬浮其上。
          // Scroll 仅作 HdsNavigation bindToScrollable 的模糊宿主：内容高度=视口高，
          // 禁用滚动交互与回弹（圈子页是固定星图，不应上下滑动）。
          Scroll(this.circleScroller) {
            Column() {
              this.galaxy()
            }
            .width('100%')
            .height(this.scrollViewportHeight)
            // 降落镜头俯冲：scale/opacity 为纯 transform，不触发重排
            .scale({ x: this.galaxyDiveScale, y: this.galaxyDiveScale })
            .opacity(this.galaxyDiveOpacity)
          }
          .enableScrollInteraction(false)
          .layoutWeight(1)
          .width('100%')
          // 不裁剪：星图泛光画到 HDS 标题栏下方（模糊采样素材）
          .clip(false)
          .scrollBar(BarState.Off)
          .onAreaChange((_old: Area, area: Area) => {
            // 在外层滚动视口测量，避免星系内容的固有宽度反过来影响自身尺寸。
            const rawWidth: number = area.width as number;
            const viewportWidth: number = rawWidth > 1200 ? this.getUIContext().px2vp(rawWidth) : rawWidth;
            if (viewportWidth > 0) {
              // 星图 Live 四期：画布宽=视口宽（全屏沉浸），不再封顶 420；
              // 环半径仍以宽度为基准，中心在高度 42% 处，上下留白天然避让标题/Tab 栏。
              this.galaxySize = Math.max(300, viewportWidth);
            }
            // 记录视口高度，供星图全屏画布高度与 minHeight 使用。
            const rawHeight: number = area.height as number;
            this.scrollViewportHeight = rawHeight > 1200 ? this.getUIContext().px2vp(rawHeight) : rawHeight;
          })
        }
      }
      .width('100%')
      .height('100%')
      .alignItems(HorizontalAlign.Start)

      if (this.hasStarCircles()) {
        if (this.starGuideVisible && !this.starGuideSeen) {
          this.starGuideCard()
        } else if (this.digest.length > 0) {
          this.digestDock()
        }
      }

      // 圈子宇宙：点行星坠入该圈专属宇宙（帖子化作星星），Tab 栏在 HdsNavigation 外天然保留。
      // 点行星的「镜头俯冲」运镜（galaxyDive）顺理成章变成「坠入宇宙」。
      if (this.landingVisible && this.landingCircle() !== undefined) {
        CircleUniverse({
          circleName: this.landingCircle()?.name ?? '',
          description: this.landingCircle()?.description ?? '',
          category: this.landingCircle()?.category ?? '',
          memberCount: this.landingCircle()?.followCount ?? 0,
          accentColor: this.landingAccent(),
          joined: this.landingCircle()?.joined ?? false,
          visible: this.landingVisible,
          canDelete: this.canDeleteLanding(),
          onTakeoff: (): void => { this.takeoffLanding(); },
          onOpenFull: (): void => { this.jumpCircle(this.landingName); },
          onJoinChanged: (joined: boolean): void => { this.onLandingJoinChanged(joined); },
          onDelete: (): void => { this.confirmDeleteLanding(); },
        })
      }
    }
    .width('100%')
    .height('100%')
    // 星际模式：页面底色与星图深空同调，消除画布四周白边（安全区/状态栏透出）；
    // 深浅色切换（星际↔纸白）走底色过渡动画
    .backgroundColor(this.cosmicMode ? COSMIC_PAGE_BG : ColorTokens.canvas)
    .animation({ duration: MotionTokens.base, curve: MotionCurves.standard })
    }
    .titleBar(this.circleHdsTitleBarOptions())
    .titleMode(HdsNavigationTitleMode.MINI)
    // 默认 Auto 在展开宽度切 Split，navBar 列被压成 240vp、右栏常驻预留 → 整页挤在左侧。
    .mode(NavigationMode.Stack)
    .hideBackButton(true)
    // 星环视口滚动绑定：内容超高时驱动标题栏渐变模糊
    .bindToScrollable([this.circleScroller])
    .clip(false)
    .width('100%')
    .height('100%')
    .backgroundColor(this.cosmicMode ? COSMIC_PAGE_BG : ColorTokens.canvas)
  }
}
