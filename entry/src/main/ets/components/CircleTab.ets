// 圈子页：服务端数据驱动的轻量星环视图。
// 星环只负责布局与交互；颜色、阴影、字体和圆角全部复用应用 design token。

import { Tag } from '../models/types';
import { listTags, listFollowedTags, getUserProfile } from '../services/api';
import { getToken, getUserId, getCurrentUser } from '../utils/auth';
import { likeStore } from '../utils/likeStore';
import { barBottomReserve } from '../utils/cardTokens';
import { CountRoll } from '../design/motion/CountRoll';
import { Pressable } from '../design/motion/Pressable';
import { EmptyState } from '../design/components/EmptyState';
import { ColorTokens } from '../design/tokens/color';
import { IconTokens } from '../design/tokens/icon';
import { MotionTokens } from '../design/tokens/motion';
import { RadiusTokens } from '../design/tokens/radius';
import { ShadowTokens } from '../design/tokens/shadow';
import { LayoutTokens, SpaceTokens } from '../design/tokens/space';
import { TypeTokens } from '../design/tokens/type';
import { openCircleDetail } from '../utils/nav';
import { JoinedCirclesDialog } from './JoinedCirclesDialog';
import { CircleSelectionCard } from './CircleSelectionCard';
import { CircleOrbitCanvas, OrbitCircleItem } from './CircleOrbitCanvas';

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
const CIRCLE_META: CircleMeta[] = [
  { id: 'digital-shopping', name: '数码选购', ring: 0, size: 64, color: '#2D7CFF', description: '把预算花在真正影响体验的地方。', category: '消费决策' },
  { id: 'phone-digital', name: '手机数码', ring: 0, size: 58, color: '#2D7CFF', description: '手机、平板和智能设备的真实使用分享。', category: '消费决策' },
  { id: 'car-trade', name: '汽车买卖', ring: 0, size: 56, color: '#2D7CFF', description: '选车、比价与交易流程的经验交换。', category: '消费决策' },
  { id: 'camping', name: '露营户外', ring: 0, size: 54, color: '#2D7CFF', description: '装备清单、营地选择和出行记录。', category: '动手实操' },
  { id: 'relationship', name: '情感经营', ring: 1, size: 52, color: '#2D7CFF', description: '真诚交流日常关系里的理解与边界。', category: '生活方式' },
  { id: 'family-life', name: '家庭相处', ring: 1, size: 48, color: '#FF2D55', description: '分享家庭沟通、陪伴与相处中的真实经验。', category: '生活方式' },
  { id: 'healthy-living', name: '健康生活', ring: 1, size: 48, color: '#30D158', description: '交流作息、饮食与让生活保持好状态的方法。', category: '生活方式' },
  { id: 'hobbies', name: '兴趣爱好', ring: 1, size: 46, color: '#AF52DE', description: '找到愿意长期投入的兴趣，也认识同好。', category: '生活方式' },
  { id: 'sports-gear', name: '运动装备', ring: 1, size: 50, color: '#2D7CFF', description: '把装备选择放回真实运动场景。', category: '消费决策' },
  { id: 'peripheral', name: '外设推荐', ring: 1, size: 49, color: '#2D7CFF', description: '桌搭、键鼠与生产力外设的细节讨论。', category: '消费决策' },
  { id: 'wine', name: '酒水品鉴', ring: 1, size: 48, color: '#2D7CFF', description: '从风味到场景，记录每次品鉴。', category: '生活方式' },
  { id: 'car-care', name: '汽车养护', ring: 2, size: 47, color: '#2D7CFF', description: '保养、清洁与用车问题的实用答案。', category: '动手实操' },
  { id: 'digital-repair', name: '数码维修', ring: 2, size: 46, color: '#2D7CFF', description: '拆解、维修和问题排查的可复用经验。', category: '动手实操' },
  { id: 'home-repair', name: '家居维修', ring: 2, size: 44, color: '#2D7CFF', description: '把家的小问题拆成可完成的步骤。', category: '动手实操' },
  { id: 'food-sharing', name: '美食分享', ring: 2, size: 42, color: '#2D7CFF', description: '从食材到火候，认真分享一顿饭。', category: '动手实操' },
  { id: 'music-sharing', name: '音乐分享', ring: 2, size: 42, color: '#FF2D55', description: '分享正在循环的歌，也分享听歌时的心情。', category: '分享' },
  { id: 'daily-sharing', name: '日常分享', ring: 2, size: 40, color: '#FF9F0A', description: '记录生活里值得留下的小事与片段。', category: '分享' },
  { id: 'movie-recommendation', name: '影视推荐', ring: 2, size: 40, color: '#AF52DE', description: '分享值得看的电影、剧集和片段。', category: '分享' },
  { id: 'book-reading', name: '书籍阅读', ring: 2, size: 40, color: '#64D2FF', description: '交换正在阅读的书和留下来的观点。', category: '分享' },
  { id: 'pet-daily', name: '宠物日常', ring: 2, size: 40, color: '#BF5AF2', description: '记录和分享宠物陪伴生活的日常。', category: '分享' },
  { id: 'podcast-sharing', name: '播客分享', ring: 2, size: 40, color: '#5E5CE6', description: '分享听过的节目，也分享值得回味的观点。', category: '分享' },
  { id: 'exhibition-events', name: '展览活动', ring: 2, size: 40, color: '#FF9500', description: '交换展览、演出与城市活动的现场感受。', category: '分享' },
  { id: 'photo-journal', name: '摄影记录', ring: 2, size: 40, color: '#0A84FF', description: '用照片记录看见的人、事与生活片段。', category: '分享' },
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
    this.description = meta.description;
    this.active = 0;
  }
}

@Component
export struct CircleTab {
  @State circles: CircleTag[] = [];
  @State joinedNames: string[] = [];
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
  @StorageLink('reduceMotion') appReduceMotion: boolean = false;
  @StorageLink('systemReduceMotion') systemReduceMotion: boolean = false;
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

  private shouldReduceMotion(): boolean {
    return this.appReduceMotion || this.systemReduceMotion;
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
      this.joinedNames = this.circles.filter((circle: CircleTag) => circle.joined).map((circle: CircleTag) => circle.name);
      const initiallySelected: CircleTag | undefined = this.circles.find((circle: CircleTag) => circle.joined) ?? this.circles[0];
      this.selectedName = initiallySelected?.name ?? '';
      this.innerOrbitAngle = 0;
      this.middleOrbitAngle = 0;
      this.outerOrbitAngle = 0;
      this.stopAutoOrbit();
      this.autoOrbitEnabled = [true, true, true];
      if (initiallySelected !== undefined) {
        this.activeRing = initiallySelected.ring;
        this.setRingAngle(initiallySelected.ring, this.angleToTop(initiallySelected.name));
      }
      this.startAutoOrbit();
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

  private ringItems(ring: number): CircleTag[] {
    return this.circles.filter((circle: CircleTag) => circle.ring === ring);
  }

  // 每颗星的基础角度均分，并给外环一个固定的轻微偏移，避免机械正对。
  private baseAngle(circle: CircleTag): number {
    const items: CircleTag[] = this.ringItems(circle.ring);
    const index: number = Math.max(0, items.findIndex((item: CircleTag) => item.name === circle.name));
    const count: number = Math.max(1, items.length);
    const jitterMap: number[][] = [
      [0, -8, 5, -4],
      [3, -5, 7, -2],
      [-1, 6, -4, 2],
    ];
    const jitter: number = jitterMap[circle.ring]?.[index] ?? 0;
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
    this.clearFocusReturnTimer();
    this.pauseOrbitExcept(circle.ring);
    this.stopInertia();
    this.activeRing = circle.ring;
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
    if (this.autoOrbitRunning || this.shouldReduceMotion() || this.circles.length === 0) {
      return;
    }
    this.autoOrbitRunning = true;
    const tick = (): void => {
      if (!this.autoOrbitRunning || this.shouldReduceMotion()) {
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
    this.autoOrbitRunning = false;
    if (this.autoOrbitTimer !== 0) {
      clearTimeout(this.autoOrbitTimer);
      this.autoOrbitTimer = 0;
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
      if (this.shouldReduceMotion()) {
        this.resumeAllOrbits();
      } else {
        // 等 Logo 回到暂停时保存的圆环位置，再恢复三环旋转。
        this.focusReturnTimer = setTimeout(() => {
          this.focusReturnTimer = 0;
          this.resumeAllOrbits();
        }, MotionTokens.emphasis) as number;
      }
      return;
    }
    if (this.shouldReduceMotion()) {
      return;
    }
    if (this.autoOrbitEnabled[0] && this.autoOrbitEnabled[1] && this.autoOrbitEnabled[2]) {
      return;
    }
    this.resumeAllOrbits();
  }

  // ArkUI 没有浏览器 rAF；以 16ms 任务帧等价实现速度衰减，且仅更新 transform 所需的角度状态。
  private startInertia(): void {
    if (this.shouldReduceMotion() || Math.abs(this.inertiaVelocity) < 0.08) {
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

  private onRingPanStart(): void {
    if (this.centeredName.length > 0) {
      return;
    }
    this.stopInertia();
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
      followCount: circle.followCount,
      size: circle.size,
      ring: circle.ring,
      baseAngle: this.baseAngle(circle),
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
  }

  private joinedCircles(): CircleTag[] {
    return this.circles.filter((circle: CircleTag) => circle.joined);
  }

  private showJoinedList(): void {
    this.joinedDialogController.open();
  }

  @Builder
  topBar(): void {
    Row({ space: SpaceTokens.sm }) {
      Text('圈子')
        .fontSize(TypeTokens.title.size).fontFamily(TypeTokens.fontFamily)
        .fontWeight(TypeTokens.title.weight)
        .lineHeight(TypeTokens.title.lineHeight)
        .letterSpacing(TypeTokens.title.tracking)
        .fontColor(ColorTokens.primary)
      Blank()
      Pressable({
        visualHeight: LayoutTokens.segmentedHeight,
        touchTargetHeight: LayoutTokens.minTouchTarget,
        action: (): void => { this.showJoinedList(); },
      }) {
        Row({ space: SpaceTokens.xs }) {
          Text('已加入')
            .fontSize(TypeTokens.caption.size).fontFamily(TypeTokens.fontFamily)
            .fontWeight(TypeTokens.caption.weight)
            .fontColor(ColorTokens.secondary)
          CountRoll({ value: this.joinedNames.length, prefix: '', textSize: TypeTokens.caption.size, textColor: ColorTokens.primary })
          Text('个')
            .fontSize(TypeTokens.caption.size).fontFamily(TypeTokens.fontFamily)
            .fontWeight(TypeTokens.caption.weight)
            .fontColor(ColorTokens.secondary)
        }
        .height(LayoutTokens.segmentedHeight)
        .padding({ left: SpaceTokens.md, right: SpaceTokens.md })
        .backgroundColor(ColorTokens.subtle)
        .border({ width: LayoutTokens.glassBorderWidth, color: ColorTokens.separator, style: BorderStyle.Solid })
        .borderRadius(RadiusTokens.pill)
        .shadow(ShadowTokens.cardContact)
        .alignItems(VerticalAlign.Center)
      }
    }
    .width('100%')
    .padding({ left: SpaceTokens.sm, right: SpaceTokens.sm, top: SpaceTokens.xs, bottom: SpaceTokens.sm })
    .alignItems(VerticalAlign.Center)
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
      reduceMotion: this.shouldReduceMotion(),
      avatar: this.selfAvatar,
      nickname: this.authNickname,
      onPlanet: (name: string): void => { this.onPlanetPressed(name); },
      onPanStart: (): void => { this.onRingPanStart(); },
      onPanUpdate: (event: GestureEvent): void => { this.onRingPanUpdate(event); },
      onPanEnd: (): void => { this.onRingPanEnd(); },
    })
  }

  @Builder
  detailCard(): void {
    ForEach(this.circles, (circle: CircleTag) => {
      if (circle.name === this.selectedName) {
        CircleSelectionCard({
          name: circle.name,
          description: circle.description,
          memberCount: circle.followCount,
          todayActive: circle.active,
          category: circle.category,
          onOpen: (): void => { this.jumpCircle(circle.name); },
        })
      }
    }, (circle: CircleTag) => circle.name)
  }

  build() {
    Column() {
      this.topBar()
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
        Scroll() {
          // Scroll 只承载一个全宽子容器；否则 ArkUI 会按行星的固有宽度收缩视口，
          // 导致 onAreaChange 取到错误的宽度，三个环随之挤成一团。
          // 星环固定在顶部（首项，位置与初始布局一致）；Blank 弹性把详情卡片
          // 推到视口底部贴近 Tab 栏。内容超高（小屏/字体放大）时 Blank 收缩至
          // x2l 保底间距，恢复正常滚动。
          Column() {
            // 星环居中区：占满“视口 - 卡片 - 底部占位”的剩余高度，
            // 星环在其中垂直居中；卡片固定在底部占位上方，贴近底部栏。
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
            .layoutWeight(1)
            // 小屏保护：居中区至少放下星环高度 + 32vp 间距，避免与卡片重叠；
            // 内容超高时外层 Column 按内容扩展，恢复正常滚动。
            .constraintSize({ minHeight: this.galaxySize + SpaceTokens.x2l })
            .justifyContent(FlexAlign.Center)
            this.detailCard()
            // 底部占位仅保留 Tab 栏+安全区高度，卡片在其上方即可贴近底部栏。
            Row().height(barBottomReserve()).width('100%')
          }
          .width('100%')
          // 用显式数值 minHeight（onAreaChange 实测的视口高度）撑满视口，
          // 让 Blank 有剩余空间把详情卡片推到贴底；内容超高时 minHeight 被
          // 内容高度撑破，恢复正常滚动。星环保持顶部原位，不额外下移。
          .constraintSize({ minHeight: this.scrollViewportHeight })
          .alignItems(HorizontalAlign.Start)
        }
        .layoutWeight(1)
        .width('100%')
        // 星系使用更窄的安全边距，把释放出的宽度用于等距环线；外环仍由半径安全值约束。
        .padding({ left: SpaceTokens.xs, right: SpaceTokens.xs })
        .scrollBar(BarState.Off)
        .onAreaChange((_old: Area, area: Area) => {
          // 在外层滚动视口测量，避免星系内容的固有宽度反过来影响自身尺寸。
          const rawWidth: number = area.width as number;
          const viewportWidth: number = rawWidth > 1200 ? px2vp(rawWidth) : rawWidth;
          const availableWidth: number = viewportWidth - SpaceTokens.xs * 2;
          if (availableWidth > 0) {
            // 不再强制 360vp 下限：375vp 手机扣除页边距后不足 360，旧逻辑会横向溢出。
            this.galaxySize = Math.max(300, Math.min(availableWidth, 420));
          }
          // 记录视口高度，供内容 Column 的 minHeight 使用（弹性推底依赖显式数值）。
          const rawHeight: number = area.height as number;
          this.scrollViewportHeight = rawHeight > 1200 ? px2vp(rawHeight) : rawHeight;
        })
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(ColorTokens.canvas)
    .alignItems(HorizontalAlign.Start)
  }
}
