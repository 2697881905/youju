// 圈子页：服务端数据驱动的轻量星环视图。
// 星环只负责布局与交互；颜色、阴影、字体和圆角全部复用应用 design token。

import { Tag } from '../models/types';
import { Post } from '../models/types';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { listTags, listFollowedTags, getUserProfile, listTagWeights, listTagActivity, setTagWeight, markTagRead, TagWeightItem, TagActivityItem, listAllTags, createTag } from '../services/api';
import { getToken, getUserId, getCurrentUser, persistSessionSnapshot } from '../utils/auth';
import { likeStore } from '../utils/likeStore';
import { barBottomReserve } from '../utils/cardTokens';
import { EmptyState } from '../design/components/EmptyState';
import { CountRoll } from '../design/motion/CountRoll';
import { Pressable } from '../design/motion/Pressable';
import { ColorTokens } from '../design/tokens/color';
import { IconTokens } from '../design/tokens/icon';
import { MotionTokens } from '../design/tokens/motion';
import { RadiusTokens } from '../design/tokens/radius';
import { LayoutTokens, SpaceTokens } from '../design/tokens/space';
import { TypeTokens } from '../design/tokens/type';
import { ShadowTokens } from '../design/tokens/shadow';
import { TopButtonMaterialModifier, isSystemMaterialActive } from '../utils/immersiveMaterial';
import { openCircleDetail, openPostDetail } from '../utils/nav';
import { safeShowToast } from '../utils/toast';
import { JoinedCirclesDialog } from './JoinedCirclesDialog';
import { CircleLandingOverlay } from './CircleLandingOverlay';
import { CircleExploreSheet, CatalogItem, CatalogGroup } from './CircleExploreSheet';
import { CircleOrbitCanvas, OrbitCircleItem } from './CircleOrbitCanvas';
import { followTag } from '../services/api';
import { HdsNavigation, HdsNavigationTitleMode, ScrollEffectType } from '@kit.UIDesignKit';
import type {
  HdsNavigationTitleBarOptions,
  TitleBarContentOptions,
  TitleBarStyleOptions,
  ScrollEffectOptions,
} from '@kit.UIDesignKit';
import { LengthMetrics } from '@kit.ArkUI';

interface CircleMeta {
  id: string;
  name: string;
  ring: number;
  size: number;
  color: string;
  description: string;
  category: string;
}

// 圈子的布局与展示元数据。成员数只读取服务端 followCount，不能回退到演示值。
// 圈子名必须与 backend/prisma/seed.ts 的 Tag.name 完全一致（按 name 对齐服务端数据）。
const CIRCLE_META: CircleMeta[] = [
  // ===== 消费选购 =====
  { id: 'phone-tablet', name: '手机数码', ring: 0, size: 64, color: '#0A84FF', description: '买前的真实体验，比参数表更可信。', category: '消费选购' },
  { id: 'home-appliance', name: '家电选购', ring: 1, size: 54, color: '#34C759', description: '大件家电决策成本高，值得认真比较。', category: '消费选购' },
  { id: 'second-hand', name: '二手闲置', ring: 1, size: 52, color: '#FF9F0A', description: '出闲置、淘好物，都是正经经验。', category: '消费选购' },
  { id: 'sports-gear', name: '运动装备', ring: 2, size: 46, color: '#30D158', description: '装备好不好，要放回真实运动里看。', category: '消费选购' },
  { id: 'refund-rights', name: '消费维权', ring: 2, size: 44, color: '#64D2FF', description: '退货、投诉与售后，较真的方法。', category: '消费选购' },
  // ===== 动手改造 =====
  { id: 'renovation', name: '装修避坑', ring: 0, size: 58, color: '#34C759', description: '装修的水深，过来人一句顶一万句。', category: '动手改造' },
  { id: 'home-cooking', name: '家常菜谱', ring: 1, size: 50, color: '#34C759', description: '从翻车到拿手，厨房里的真实记录。', category: '动手改造' },
  { id: 'pc-build', name: '电脑装机', ring: 1, size: 49, color: '#0A84FF', description: '配置单发出来，帮你砍掉多余预算。', category: '动手改造' },
  { id: 'car-life', name: '用车经验', ring: 2, size: 42, color: '#FF9500', description: '选车、保养、油电之争，车主的一手账。', category: '动手改造' },
  // ===== 职场与收入 =====
  { id: 'resume-interview', name: '求职面试', ring: 0, size: 56, color: '#5E5CE6', description: '简历怎么写、面试怎么答，都有人趟过。', category: '职场与收入' },
  { id: 'career-growth', name: '职场成长', ring: 1, size: 48, color: '#5E5CE6', description: '沟通、协作与晋升，真实职场的一手经验。', category: '职场与收入' },
  { id: 'budget-saving', name: '记账储蓄', ring: 1, size: 47, color: '#5E5CE6', description: '支出看得见，攒钱才有方向。', category: '职场与收入' },
  { id: 'side-hustle', name: '副业探索', ring: 2, size: 40, color: '#5E5CE6', description: '能跑通的说思路，踩过坑的说原因。', category: '职场与收入' },
  // ===== 生活与家庭 =====
  { id: 'dating', name: '恋爱心得', ring: 2, size: 44, color: '#FF2D55', description: '相亲、约会与心动，少一点套路多一分真诚。', category: '生活与家庭' },
  { id: 'marriage', name: '婚姻与家庭', ring: 2, size: 42, color: '#FF2D55', description: '夫妻、婆媳与家庭经营，柴米油盐里的智慧。', category: '生活与家庭' },
  { id: 'parenting', name: '育儿经验', ring: 2, size: 40, color: '#FF2D55', description: '从新生儿到入园，新手父母的实操帖。', category: '生活与家庭' },
  { id: 'pets', name: '养猫养狗', ring: 2, size: 44, color: '#BF5AF2', description: '粮食、就医、绝育，铲屎官的经验之谈。', category: '生活与家庭' },
  { id: 'healthy-habits', name: '健康习惯', ring: 2, size: 42, color: '#30D158', description: '作息、运动与饮食，把状态调整好的真实做法。', category: '生活与家庭' },
  { id: 'renting', name: '租房买房', ring: 1, size: 46, color: '#34C759', description: '押金、中介、贷款，重要决策慢慢聊。', category: '生活与家庭' },
  // ===== 兴趣休闲 =====
  { id: 'music-sharing', name: '音乐分享', ring: 2, size: 40, color: '#FF2D55', description: '正在循环的歌，和歌背后的心情。', category: '兴趣休闲' },
  { id: 'shows', name: '影视剧集', ring: 2, size: 40, color: '#AF52DE', description: '值得花时间的剧和电影，烂片也点名。', category: '兴趣休闲' },
  { id: 'travel-tips', name: '旅行出行', ring: 2, size: 40, color: '#FF9500', description: '攻略里不会写的那部分经验。', category: '兴趣休闲' },
  { id: 'food-review', name: '美食探店', ring: 2, size: 40, color: '#FF9F0A', description: '网红店值不值，实测说话。', category: '兴趣休闲' },
];

// 标签宽度必须纳入最外轨道的安全边距计算；过大会在 375vp 视口的左右边缘被裁切。
const PLANET_BOX_WIDTH: number = 64;
const CENTER_AVATAR_SIZE: number = 64;
const TOP_ANGLE: number = -90;

// @Observed 保证乐观更新人数与 joined 状态能立即驱动星环和详情卡同步刷新。
@Observed
class CircleTag {
  id?: number;
  name: string = '';
  emoji?: string;
  category: string = '';
  useCount?: number;
  followCount: number = 0;
  members: number = 0;
  ring: number = 1;
  size: number = 48;
  color: string = '#2D7CFF';
  description: string = '';
  active: number = 0;
  joined: boolean = false;
  // 星图 Live 二期：引力档位（1=强/2=常/3=轻，缺省2）与未读新帖数（角标/星子）
  weight: number = 2;
  unread: number = 0;
  // 近7天有新帖（后端 activity 接口回填；缺省由 useCount>0 近似）
  hasActivity: boolean = false;
  // 星图 Live 三期：星等原始分（近14天衰减热度）。-1=无数据（退回 active 近似），
  // >=0 由后端 Tag.activeScore / activity 接口回填，换算为行星亮度三档。
  activeScore: number = -1;

  constructor(meta: CircleMeta, tag?: Tag) {
    this.id = tag?.id;
    this.name = meta.name;
    this.emoji = tag?.emoji;
    this.category = tag?.category ?? meta.category;
    this.useCount = tag?.useCount;
    this.followCount = tag?.followCount ?? 0;
    this.members = this.followCount;
    this.ring = meta.ring;
    this.size = meta.size;
    this.color = meta.color;
    this.description = tag?.description ?? meta.description;
    this.active = 0;
    this.activeScore = tag?.activeScore ?? -1;
  }
}

// 星图 Live 三期：创建圈子的分类白名单（与后端 TAG_CATEGORIES 一致）。
const CIRCLE_CATEGORIES: string[] = ['消费选购', '动手改造', '职场与收入', '生活与家庭', '兴趣休闲'];

@Component
export struct CircleTab {
  @State circles: CircleTag[] = [];
  // 计数变化统一经 @Watch 回写标题栏 @Link（initData 成功/失败/切号三处都会重赋 joinedNames）
  @State @Watch('onJoinedNamesChanged') joinedNames: string[] = [];
  // 顶栏（「圈子」标题 + 「已加入」药丸）迁入 Navigation 标题栏后由 Index 持有：
  // 计数经 @Link 回写标题栏；标题栏按钮点击经 seq 信号回传，由本组件 @Watch 承接弹窗
  // （profileShareSeq 同款「点击写值、@Watch 承接动作」接线，见教程 Step 2 状态归属）。
  @Link circleJoinedCount: number;
  @Link @Watch('onJoinedEntryRequested') circleJoinedSeq: number;
  // —— 顶栏（嵌套 HdsNavigation，路线 B，同首页结构）——
  // 星环视口 Scroller：交给 bindToScrollable 驱动标题栏渐变模糊（内容超高滚动时生效）
  private circleScroller: Scroller = new Scroller();
  // 「已加入」药丸同源材质修饰器（沉浸光感，HDS 标题栏 = 官方生效区域）
  private pillMaterial: TopButtonMaterialModifier = new TopButtonMaterialModifier();
  @State loading: boolean = false;
  @State error: string = '';
  @State selectedName: string = '';
  @State centeredName: string = '';
  // 三条环各自保存角度。不能共用一个 orbitAngle，否则点击一颗行星会带动全部环线内容。
  @State innerOrbitAngle: number = 0;
  @State middleOrbitAngle: number = 0;
  @State outerOrbitAngle: number = 0;
  @State galaxySize: number = 343;
  // Scroll 视口实际高度（onAreaChange 测量）。Scroll 子组件百分比高度不按视口解析，
  // Blank 弹性推底必须用显式数值 minHeight，否则卡片无法贴底。
  @State scrollViewportHeight: number = 0;
  @State ringDragging: boolean = false;
  // —— 星图 Live 一期：降落页 + 深空目录 ——
  @State landingName: string = '';
  @State @Watch('onLandingVisibleChanged') landingVisible: boolean = false;
  @State exploreVisible: boolean = false;
  @State exploreKeyword: string = '';
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
  private dragOffset: number = 0;
  private inertiaVelocity: number = 0;
  private inertiaTimer: number = 0;
  private autoOrbitTimer: number = 0;
  private focusReturnTimer: number = 0;
  private autoOrbitRunning: boolean = false;
  // 三条环各自维护自动旋转开关；任意时刻仅当前选中的一层会暂停。
  private autoOrbitEnabled: boolean[] = [true, true, true];
  private lastPlanetTapAt: number = 0;
  private activeRing: number = 0;
  private joinedDialogController: CustomDialogController = new CustomDialogController({
    builder: JoinedCirclesDialog({
      getCircles: (): CircleTag[] => this.joinedCircles(),
      onOpenCircle: (name: string): void => { this.jumpCircle(name); },
    }),
    alignment: DialogAlignment.Center,
    customStyle: false,
    autoCancel: true,
  });

  aboutToAppear(): void {
    if (this.activeTab === 1) {
      this.initData();
    }
  }

  aboutToDisappear(): void {
    this.stopInertia();
    this.stopAutoOrbit();
    this.clearFocusReturnTimer();
    this.centeredName = '';
  }

  onActiveTab(): void {
    if (this.activeTab === 1) {
      this.initData();
    } else {
      // TabContent 可能保持挂载，切走时主动停止后台角度刷新。
      this.stopAutoOrbit();
      this.clearFocusReturnTimer();
      this.centeredName = '';
    }
  }

  private onCircleMembershipChanged(): void {
    if (this.activeTab === 1 && this.token !== '') {
      this.initData();
    }
  }

  private onCircleLogoDismissed(): void {
    this.resumePausedOrbits();
  }

  onTokenReady(): void {
    if (this.token !== '' && this.activeTab === 1) {
      this.initData();
    }
  }

  onAccountSwitch(): void {
    likeStore.clear();
    if (getToken() !== '') {
      this.initData();
    } else {
      this.stopAutoOrbit();
      this.circles = [];
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

  private async initData(): Promise<void> {
    this.clearFocusReturnTimer();
    this.centeredName = '';
    this.loading = true;
    this.error = '';
    this.syncSelfAvatar();
    try {
      const tags: Tag[] = await listTags();
      const followed: string[] = getToken() === '' ? [] : await listFollowedTags();
      this.circles = CIRCLE_META.map((meta: CircleMeta): CircleTag => {
        const remote: Tag | undefined = tags.find((tag: Tag) => tag.name === meta.name);
        const circle: CircleTag = new CircleTag(meta, remote);
        circle.joined = followed.indexOf(meta.name) >= 0;
        return circle;
      });
      // 星图 Live 三期：服务端新建、非预置的圈子（点亮新星）也上星——
      // 统一落外环（ring=2）、小尺寸，简介/星等取服务端值。
      tags.forEach((tag: Tag): void => {
        if (tag.name === undefined || CIRCLE_META.some((meta: CircleMeta): boolean => meta.name === tag.name)) {
          return;
        }
        const extra: CircleTag = new CircleTag(
          { id: 'server-' + tag.name, name: tag.name, ring: 2, size: 44, color: '#2D7CFF', description: '', category: tag.category ?? '兴趣休闲' },
          tag);
        extra.joined = followed.indexOf(tag.name) >= 0;
        this.circles.push(extra);
      });
      this.joinedNames = this.circles.filter((circle: CircleTag) => circle.joined).map((circle: CircleTag) => circle.name);
      const initiallySelected: CircleTag | undefined = this.circles.find((circle: CircleTag) => circle.joined) ?? this.circles[0];
      this.selectedName = initiallySelected?.name ?? '';
      this.innerOrbitAngle = 0;
      this.middleOrbitAngle = 0;
      this.outerOrbitAngle = 0;
      this.stopAutoOrbit();
      this.autoOrbitEnabled = [true, true, true];
      if (initiallySelected !== undefined) {
        this.activeRing = this.displayRing(initiallySelected);
        this.setRingAngle(this.activeRing, this.angleToTop(initiallySelected.name));
      }
      this.startAutoOrbit();
      // 二期：引力档位 + 活跃度/未读角标（登录后异步补齐，失败静默不影响星图）
      this.fetchOrbitMeta();
    } catch (e) {
      this.error = (e as Error).message;
      this.circles = [];
      this.joinedNames = [];
      this.selectedName = '';
      this.centeredName = '';
    } finally {
      this.loading = false;
    }
  }

  // 圈子页仅负责浏览和进入；加入或退出必须在详情页中明确选择。
  private jumpCircle(name: string): void {
    if (name.length === 0) {
      return;
    }
    openCircleDetail(name);
    console.info('jumpCircle: ' + name);
    this.getUIContext().getRouter().pushUrl({ url: 'pages/CircleDetailPage' });
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

  private ringItems(ring: number): CircleTag[] {
    return this.circles.filter((circle: CircleTag) => this.displayRing(circle) === ring);
  }

  // 每颗星的基础角度均分，并给外环一个固定的轻微偏移，避免机械正对。
  private baseAngle(circle: CircleTag): number {
    const dr: number = this.displayRing(circle);
    const items: CircleTag[] = this.ringItems(dr);
    const index: number = Math.max(0, items.findIndex((item: CircleTag) => item.name === circle.name));
    const count: number = Math.max(1, items.length);
    const jitterMap: number[][] = [
      [0, -8, 5, -4],
      [3, -5, 7, -2],
      [-1, 6, -4, 2],
    ];
    const jitter: number = jitterMap[dr]?.[index] ?? 0;
    return TOP_ANGLE + index * 360 / count + jitter;
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
    // 注意用 displayRing（引力档位决定的实际所在环），不是 meta.ring。
    const dr: number = this.displayRing(circle);
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
    if (this.circles.length === 0) {
      return;
    }
    this.autoOrbitRunning = true;
    hilog.info(0x0000, 'CircleTab', '星环自转启动');
    const tick = (): void => {
      if (!this.autoOrbitRunning) {
        this.autoOrbitTimer = 0;
        return;
      }
      const speed: number = 0.16;
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
      this.autoOrbitTimer = setTimeout(tick, 16) as number;
    };
    this.autoOrbitTimer = setTimeout(tick, 16) as number;
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

  private radiusForRing(ring: number): number {
    // 先确定内环距头像的安全距离，再在可用空间内等分两段。
    // 不能从外环按大间距硬向内回推，否则 375vp 视口会把内环压到头像上。
    const maxOuterRadius: number = Math.max(
      0,
      // 星系视口本身已有 4vp 页边距，无需在半径内重复预留，外环可再向外扩展。
      this.galaxySize / 2 - PLANET_BOX_WIDTH / 2,
    );
    // 标签容器不再参与选中缩放，可安全借用页面两侧的 4vp 边距再外扩一档。
    const outerRadius: number = Math.min(this.galaxySize * 0.46, maxOuterRadius) + SpaceTokens.xs;
    // 从头像外缘到最外环的可用径向距离严格三等分：
    // avatar→内环 = 内环→中环 = 中环→外环。
    const avatarEdgeRadius: number = CENTER_AVATAR_SIZE / 2;
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

  // Canvas 用基础角度、所属圆环的实时角度和半径共同计算 Logo 位置。
  private orbitItems(): OrbitCircleItem[] {
    return this.circles.map((circle: CircleTag): OrbitCircleItem => ({
      name: circle.name,
      size: circle.size,
      ring: this.displayRing(circle),
      baseAngle: this.baseAngle(circle),
      joined: circle.joined,
      // 活跃度：后端 activity 回填优先，缺省用 useCount>0 近似（有内容即亮星）
      active: circle.hasActivity || (circle.useCount ?? 0) > 0,
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

  // ===== 星图 Live 二期：引力拖拽 / 星子 / 活跃度 =====

  // 登录后异步补齐引力档位与圈子活跃度/未读；失败静默（星图仍可自转与降落）。
  private async fetchOrbitMeta(): Promise<void> {
    if (getToken() === '') {
      return;
    }
    try {
      const weights: TagWeightItem[] = await listTagWeights();
      const weightMap: Map<string, number> = new Map();
      weights.forEach((w: TagWeightItem): void => { weightMap.set(w.tagName, w.weight); });
      this.circles.forEach((circle: CircleTag): void => {
        const w: number | undefined = weightMap.get(circle.name);
        if (w !== undefined) {
          circle.weight = w;
        }
      });
    } catch (e) {
      // 引力档位拉取失败：保持默认 weight=2，不阻塞
    }
    try {
      const activity: TagActivityItem[] = await listTagActivity();
      const actMap: Map<string, TagActivityItem> = new Map();
      activity.forEach((a: TagActivityItem): void => { actMap.set(a.tagName, a); });
      this.circles.forEach((circle: CircleTag): void => {
        const a: TagActivityItem | undefined = actMap.get(circle.name);
        if (a !== undefined) {
          circle.hasActivity = a.active;
          circle.unread = a.unread;
          // 星图 Live 三期：星等以 activity 接口为准（覆盖 listTags 初始值）
          circle.activeScore = a.activeScore;
        }
      });
    } catch (e) {
      // 活跃度拉取失败：退回 useCount>0 近似（orbitItems 已兜底）
    }
    this.circles = this.circles.slice();
  }

  // 星等分 → 三档亮度：>=1.5=耀星（带光晕）、>=0.3=常星、其余=暗星；
  // 无数据（-1）退回 active 近似（亮=1 常档 / 暗=0 档）。
  private magnitudeFor(circle: CircleTag): number {
    if (circle.activeScore < 0) {
      return circle.hasActivity || (circle.useCount ?? 0) > 0 ? 1 : 0;
    }
    if (circle.activeScore >= 1.5) {
      return 2;
    }
    if (circle.activeScore >= 0.3) {
      return 1;
    }
    return 0;
  }

  // 拖拽行星开始：冻结该行星所在环的自转，避免拖拽期间行星漂移。
  private onGravityStart(name: string): void {
    const circle: CircleTag | undefined = this.circles.find((item: CircleTag) => item.name === name);
    if (circle === undefined) {
      return;
    }
    this.stopAutoOrbit();
    this.stopInertia();
    this.pauseOrbitExcept(this.displayRing(circle));
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
    const labels: string[] = ['强关注 · 新帖必送达', '常关注 · 按热度推送', '轻关注 · 偶尔看看'];
    safeShowToast(this.getUIContext(), { message: circle.emoji + ' ' + circle.name + ' → ' + labels[target - 1] });
    setTagWeight(name, target).then((): void => {
      this.resumePausedOrbits();
    }).catch((e: Error): void => {
      // 落库失败（如后端未就绪/403）：回滚档位，不静默吞掉
      circle.weight = previous;
      this.circles = this.circles.slice();
      safeShowToast(this.getUIContext(), { message: '调节失败，已还原' });
      this.resumePausedOrbits();
    });
  }

  // 拖动未加入行星：不改变引力，弹加入引导（转化钩子）。
  private onGravityBlocked(name: string): void {
    const circle: CircleTag | undefined = this.circles.find((item: CircleTag) => item.name === name);
    safeShowToast(this.getUIContext(), {
      message: (circle?.emoji ?? '') + '「' + name + '」还未加入 · 加入后才能调节推送强度',
    });
    this.resumePausedOrbits();
  }

  // 星子点击：直达该圈子最新帖（一期简化：打开降落页读该圈帖子流）。
  private onSeedTap(name: string): void {
    const circle: CircleTag | undefined = this.circles.find((item: CircleTag) => item.name === name);
    if (circle === undefined) {
      return;
    }
    this.lastPlanetTapAt = Date.now();
    this.selectPlanet(circle);
    this.landingName = name;
    setTimeout((): void => { this.landingVisible = true; }, MotionTokens.emphasis) as number;
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

  // 降落层可见性变化：升起时标记该圈已读（角标归零）。
  private onLandingVisibleChanged(): void {
    if (this.landingVisible) {
      this.markLandingRead(this.landingName);
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

  // —— 深空目录数据：全量圈子按分类分组，支持名字/分类/简介过滤 ——
  private catalogGroups(): CatalogGroup[] {
    const order: string[] = [];
    const map: Map<string, CatalogItem[]> = new Map();
    const kw: string = this.exploreKeyword.trim();
    this.circles.forEach((circle: CircleTag): void => {
      if (kw.length > 0
        && !circle.name.includes(kw) && !circle.category.includes(kw) && !circle.description.includes(kw)) {
        return;
      }
      if (!map.has(circle.category)) {
        map.set(circle.category, []);
        order.push(circle.category);
      }
      map.get(circle.category)?.push({
        name: circle.name,
        category: circle.category,
        description: circle.description,
        memberCount: circle.followCount,
        joined: circle.joined,
      });
    });
    return order.map((category: string): CatalogGroup => ({ category: category, items: map.get(category) ?? [] }));
  }

  // 目录内直接加入：成功后关目录（星图金环即时更新）；失败仅 toast。
  private async joinFromCatalog(name: string): Promise<void> {
    if (getToken() === '') {
      safeShowToast(this.getUIContext(), { message: '请先登录后再加入圈子' });
      return;
    }
    const circle: CircleTag | undefined = this.circles.find((item: CircleTag) => item.name === name);
    if (circle === undefined || circle.joined) {
      return;
    }
    try {
      await followTag(name);
      this.exploreVisible = false;
      this.landingName = name;
      this.onLandingJoinChanged(true);
      // 目录加入的点亮编舞：让对应行星飞到 12 点再收场，用户「看见自己的新星挂上轨道」
      this.selectPlanet(circle);
      safeShowToast(this.getUIContext(), { message: '已加入「' + name + '」· 新星已点亮' });
      const version: number = AppStorage.get<number>('circleMembershipVersion') ?? 0;
      AppStorage.setOrCreate('circleMembershipVersion', version + 1);
    } catch (e) {
      safeShowToast(this.getUIContext(), { message: '加入失败：' + (e as Error).message });
    }
  }

  // 星图 Live 三期：目录内点亮新星（创建圈子）。成功后新行星即时上星 + 飞心编舞，
  // 等价于「加入」路径（后端已让创建者自动关注）。
  private async createFromCatalog(name: string, category: string, description: string): Promise<boolean> {
    if (getToken() === '') {
      safeShowToast(this.getUIContext(), { message: '请先登录后再点亮新星' });
      return false;
    }
    try {
      const tag: Tag = await createTag(name, category, description);
      const tagName: string = tag.name ?? name;
      const meta: CircleMeta = {
        id: 'server-' + tagName, name: tagName, ring: 2, size: 44,
        color: '#2D7CFF', description: description, category: category,
      };
      const circle: CircleTag = new CircleTag(meta, tag);
      circle.joined = true;
      this.circles.push(circle);
      this.circles = this.circles.slice();
      this.joinedNames = this.circles.filter((item: CircleTag) => item.joined).map((item: CircleTag) => item.name);
      this.exploreVisible = false;
      this.landingName = tagName;
      // 点亮编舞：新行星飞到 12 点，用户「看见自己的新星挂上轨道」
      this.selectPlanet(circle);
      safeShowToast(this.getUIContext(), { message: '「' + tagName + '」已点亮 · 欢迎第一位旅人' });
      const version: number = AppStorage.get<number>('circleMembershipVersion') ?? 0;
      AppStorage.setOrCreate('circleMembershipVersion', version + 1);
      return true;
    } catch (e) {
      safeShowToast(this.getUIContext(), { message: '点亮失败：' + (e as Error).message });
      return false;
    }
  }

  private openPostFromLanding(post: Post): void {
    if (post.id === undefined) {
      return;
    }
    openPostDetail(String(post.id));
    this.getUIContext().getRouter().pushUrl({ url: 'pages/DetailPage' });
  }

  private joinedCircles(): CircleTag[] {
    return this.circles.filter((circle: CircleTag) => circle.joined);
  }

  private showJoinedList(): void {
    this.joinedDialogController.open();
  }

  // 标题栏「已加入」药丸点击（Index 经 circleJoinedSeq 递增信号触发）
  private onJoinedEntryRequested(): void {
    this.showJoinedList();
  }

  // 已加入列表变化 → 回写标题栏计数（Index 的 circleTitleBar 读取）
  private onJoinedNamesChanged(): void {
    this.circleJoinedCount = this.joinedNames.length;
  }

  @Builder
  galaxy(): void {
    CircleOrbitCanvas({
      galaxySize: this.galaxySize,
      ringAngles: this.orbitAngles(),
      radii: this.orbitRadii(),
      circles: this.orbitItems(),
      selectedName: this.selectedName,
      centeredName: this.centeredName,
      ringDragging: this.ringDragging,
      avatar: this.selfAvatar,
      nickname: this.authNickname,
      onPlanet: (name: string): void => { this.onPlanetPressed(name); },
      onGravityStart: (name: string): void => { this.onGravityStart(name); },
      onGravityEnd: (name: string, distance: number): void => { this.onGravityEnd(name, distance); },
      onGravityBlocked: (name: string): void => { this.onGravityBlocked(name); },
      onSeedTap: (name: string): void => { this.onSeedTap(name); },
      onPanStart: (ring: number): void => { this.onRingPanStart(ring); },
      onPanUpdate: (event: GestureEvent): void => { this.onRingPanUpdate(event); },
      onPanEnd: (): void => { this.onRingPanEnd(); },
    })
  }

  // 星图 Live：底部资料卡（CircleSelectionCard）已移除——轻详情由降落层承担，
  // 点行星即降落读帖/加入；选中行星仍保留飞心 + 涟漪编舞。

  // —— 顶栏（嵌套 HdsNavigation，路线 B：同首页定稿结构）——
  // MINI + stackBuilder 品牌行（「圈子」标题 + 「已加入」药丸）+ GRADIENT_BLUR +
  // avoid/enableComponentSafeArea 双开。星环内容通常不超高（视口推底布局），
  // 模糊仅在内容超高滚动时出现——与首页同一基线参数，观感自动一致。
  private circleHdsTitleBarOptions(): HdsNavigationTitleBarOptions {
    const scrollEffect: ScrollEffectOptions = {
      enableScrollEffect: true,
      scrollEffectType: ScrollEffectType.GRADIENT_BLUR,
      blurEffectiveStartOffset: LengthMetrics.vp(0),
      blurEffectiveEndOffset: LengthMetrics.vp(32),
    };
    const style: TitleBarStyleOptions = {
      scrollEffectOpts: scrollEffect,
      originalStyle: {
        backgroundStyle: { backgroundColor: Color.Transparent },
      },
    };
    const content: TitleBarContentOptions = {
      stackBuilder: (): void => { this.circleBrandRow(); },
    };
    const options: HdsNavigationTitleBarOptions = {
      content: content,
      style: style,
      avoidLayoutSafeArea: true,
      enableComponentSafeArea: true,
    };
    return options;
  }

  // stackBuilder 品牌行：「圈子」标题 + 「已加入」药丸（原 Index.circleTitleBar 整体迁入）。
  // 计数经 @Link 回写；点击药丸递增 seq 信号，由本组件 @Watch 承接弹窗。
  // 状态栏避让由 avoidLayoutSafeArea(true) 承担（不再手动补 statusBarHeight 内边距）。
  @Builder
  circleBrandRow() {
    Row({ space: SpaceTokens.sm }) {
      Text('圈子')
        .fontSize(TypeTokens.titleSerif.size).fontFamily(TypeTokens.fontFamilySerif)
        .fontWeight(TypeTokens.titleSerif.weight)
        .lineHeight(TypeTokens.titleSerif.lineHeight)
        .fontColor(ColorTokens.primary)
      Blank()
      Pressable({
        visualHeight: LayoutTokens.segmentedHeight,
        touchTargetHeight: LayoutTokens.minTouchTarget,
        action: (): void => {
          // 递增信号 → 本组件 @Watch：JoinedCirclesDialog 仍由本组件打开
          this.circleJoinedSeq += 1;
        },
      }) {
        Row({ space: SpaceTokens.xs }) {
          Text('已加入')
            .fontSize(TypeTokens.caption.size).fontFamily(TypeTokens.fontFamily)
            .fontWeight(TypeTokens.caption.weight)
            .fontColor(ColorTokens.secondary)
          CountRoll({ value: this.circleJoinedCount, prefix: '', textSize: TypeTokens.caption.size, textColor: ColorTokens.primary })
          Text('个')
            .fontSize(TypeTokens.caption.size).fontFamily(TypeTokens.fontFamily)
            .fontWeight(TypeTokens.caption.weight)
            .fontColor(ColorTokens.secondary)
        }
        .height(LayoutTokens.segmentedHeight)
        .padding({ left: SpaceTokens.md, right: SpaceTokens.md })
        // 沉浸光感：材质生效时自绘让位（底/描边/阴影归零），系统材质接管药丸表面；
        // 低版本门禁不通过 → 保留原样式
        .backgroundColor(isSystemMaterialActive() ? Color.Transparent : ColorTokens.subtle)
        .border({
          width: isSystemMaterialActive() ? 0 : LayoutTokens.glassBorderWidth,
          color: ColorTokens.separator,
          style: BorderStyle.Solid,
        })
        .borderRadius(RadiusTokens.pill)
        .shadow(isSystemMaterialActive() ? ShadowTokens.none : ShadowTokens.cardContact)
        .alignItems(VerticalAlign.Center)
        .attributeModifier(this.pillMaterial)
      }
    }
    .width('100%')
    .alignItems(VerticalAlign.Center)
    .padding({ left: SpaceTokens.sm, right: SpaceTokens.sm, top: SpaceTokens.xs, bottom: SpaceTokens.xs })
  }

  private landingCircle(): CircleTag | undefined {
    return this.circles.find((item: CircleTag) => item.name === this.landingName);
  }

  @Builder
  exploreSheet() {
    CircleExploreSheet({
      groups: this.catalogGroups(),
      keyword: this.exploreKeyword,
      totalCount: this.circles.length,
      categories: CIRCLE_CATEGORIES,
      onKeywordChange: (kw: string): void => { this.exploreKeyword = kw; },
      onJoin: (name: string): void => { this.joinFromCatalog(name); },
      onCreate: (name: string, category: string, description: string): Promise<boolean> =>
        this.createFromCatalog(name, category, description),
      onOpen: (name: string): void => {
        this.exploreVisible = false;
        const circle: CircleTag | undefined = this.circles.find((item: CircleTag) => item.name === name);
        if (circle !== undefined) {
          this.lastPlanetTapAt = Date.now();
          this.selectPlanet(circle);
          this.landingName = name;
          setTimeout((): void => { this.landingVisible = true; }, MotionTokens.emphasis) as number;
        }
      },
    })
  }

  // 星图 Live：探索星云入口（悬浮于星图右上，标题栏之下）。
  // Pressable 是自定义组件不能直接挂 position，外包一层定位容器。
  @Builder
  exploreFab() {
    Column() {
      Pressable({
        visualHeight: 36,
        touchTargetHeight: LayoutTokens.minTouchTarget,
        action: (): void => { this.exploreVisible = true; },
      }) {
        Row({ space: SpaceTokens.xs }) {
          Text('✦').fontSize(14).fontColor(ColorTokens.warm)
          Text('探索星云')
            .fontSize(TypeTokens.caption.size).fontFamily(TypeTokens.fontFamily)
            .fontWeight(TypeTokens.headline.weight)
            .fontColor(ColorTokens.primary)
        }
        .height(36)
        .padding({ left: SpaceTokens.md, right: SpaceTokens.md })
        .backgroundColor(ColorTokens.glassWhite)
        .border({ width: LayoutTokens.glassBorderWidth, color: ColorTokens.separator, style: BorderStyle.Solid })
        .borderRadius(RadiusTokens.pill)
        .shadow(ShadowTokens.cardContact)
        .alignItems(VerticalAlign.Center)
      }
    }
    .position({ x: '100%', y: SpaceTokens.md })
    .markAnchor({ x: '100%' })
    .padding({ right: SpaceTokens.base })
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
        } else if (this.circles.length === 0) {
          Column() {
            EmptyState({
              title: this.error ? '加载失败' : '暂无圈子',
              message: this.error ? this.error : '发现并加入你感兴趣的话题',
              actionLabel: this.error ? '重试' : '',
              onAction: (): void => { this.initData(); },
            })
          }
          .layoutWeight(1)
          .width('100%')
          .justifyContent(FlexAlign.Center)
        } else {
          // scroller 显式挂载：交给嵌套 HdsNavigation 的 bindToScrollable 驱动标题栏渐变模糊
          Scroll(this.circleScroller) {
            // 星图 Live：星图占满「视口 - 底部占位」全屏居中（底部资料卡已移除，
            // 轻详情改由降落层承担）。内容超高（小屏/字体放大）时恢复正常滚动。
            Column() {
              Row() {
                Blank()
                this.galaxy()
                Blank()
              }
              .width('100%')
              .justifyContent(FlexAlign.Center)
            }
            .width('100%')
            .constraintSize({ minHeight: this.scrollViewportHeight - barBottomReserve() })
            .justifyContent(FlexAlign.Center)
          }
          .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true })
          .layoutWeight(1)
          .width('100%')
          // 不裁剪：内容超高滚动时穿出 Scroll 顶边画到 HDS 标题栏下方（模糊采样素材）
          .clip(false)
          // 星系使用更窄的安全边距，把释放出的宽度用于等距环线；外环仍由半径安全值约束。
          .padding({ left: SpaceTokens.xs, right: SpaceTokens.xs })
          .scrollBar(BarState.Off)
          .onAreaChange((_old: Area, area: Area) => {
            // 在外层滚动视口测量，避免星系内容的固有宽度反过来影响自身尺寸。
            const rawWidth: number = area.width as number;
            const viewportWidth: number = rawWidth > 1200 ? this.getUIContext().px2vp(rawWidth) : rawWidth;
            const availableWidth: number = viewportWidth - SpaceTokens.xs * 2;
            if (availableWidth > 0) {
              // 不再强制 360vp 下限：375vp 手机扣除页边距后不足 360，旧逻辑会横向溢出。
              this.galaxySize = Math.max(300, Math.min(availableWidth, 420));
            }
            // 记录视口高度，供星图 minHeight 使用（全屏居中依赖显式数值）。
            const rawHeight: number = area.height as number;
            this.scrollViewportHeight = rawHeight > 1200 ? this.getUIContext().px2vp(rawHeight) : rawHeight;
          })
          // 底部占位仅保留 Tab 栏+安全区高度，星图在其上方即可贴近底部栏。
          Row().height(barBottomReserve()).width('100%')
        }
      }
      .width('100%')
      .height('100%')
      .alignItems(HorizontalAlign.Start)

      if (this.circles.length > 0) {
        this.exploreFab()
      }

      // 降落层：点行星后全屏覆盖（Tab 栏在 HdsNavigation 外，天然保留）
      if (this.landingVisible && this.landingCircle() !== undefined) {
        CircleLandingOverlay({
          circleName: this.landingCircle()?.name ?? '',
          description: this.landingCircle()?.description ?? '',
          category: this.landingCircle()?.category ?? '',
          memberCount: this.landingCircle()?.followCount ?? 0,
          joined: this.landingCircle()?.joined ?? false,
          visible: this.landingVisible,
          onTakeoff: (): void => { this.takeoffLanding(); },
          onOpenFull: (): void => { this.jumpCircle(this.landingName); },
          onOpenPost: (post: Post): void => { this.openPostFromLanding(post); },
          onJoinChanged: (joined: boolean): void => { this.onLandingJoinChanged(joined); },
        })
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(ColorTokens.canvas)
    .bindSheet($$this.exploreVisible, this.exploreSheet(), {
      detents: [SheetSize.MEDIUM, SheetSize.LARGE],
      blurStyle: BlurStyle.COMPONENT_THICK,
      showClose: true,
      backgroundColor: ColorTokens.canvas,
      radius: { topLeft: RadiusTokens.xl, topRight: RadiusTokens.xl },
    })
    }
    .titleBar(this.circleHdsTitleBarOptions())
    .titleMode(HdsNavigationTitleMode.MINI)
    .hideBackButton(true)
    // 星环视口滚动绑定：内容超高时驱动标题栏渐变模糊
    .bindToScrollable([this.circleScroller])
    .clip(false)
    .width('100%')
    .height('100%')
    .backgroundColor(ColorTokens.canvas)
  }
}
