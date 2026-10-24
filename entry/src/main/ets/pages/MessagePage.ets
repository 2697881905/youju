// 消息通知中心（真实数据：后端 /v1/notifications）
// - 三类互动筛选：赞和收藏（默认，无「全部」视图）/ 新增关注 / 评论（含 @提及）
// - 常驻入口：举报中心（管理员，唯一处置台）、系统通知（所有用户，审核结果/举报回执），
//   两者不随筛选过滤；系统类通知不在互动筛选列表里出现
// - 列表渲染（下拉刷新 / 触底加载更多 / 未读圆点 / 点击已读并跳详情）
// - 空态 / 错误态（重试）
// - 顶部「全部已读」
// - 回写 AppStorage['unreadMessageCount'] 供 Index 消息 Tab 红点

import { NotificationItem, NotificationType, UnreadByType, Conversation, PendingReportSummary } from '../models/types';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { openChat, openPostDetail, openPostDetailAtComment, openUserProfile } from '../utils/nav';
import {
  listNotifications,
  getUnreadCount,
  markNotificationRead,
  markAllRead,
  getConversations,
  getDmUnreadCount,
  getAdminReportSummary,
} from '../services/api';
import { getToken, getUserId, getCurrentUser, getIsAdmin } from '../utils/auth';
import { ChatView } from './ChatView';
import { getMainNavStack, VideoPlayerNavParams } from '../utils/navigationTransition';
import { barBottomReserve } from '../utils/cardTokens';
import { safeShowToast } from '../utils/toast';
import { buildPageTransition } from '../utils/styles';
import { notifIconRes, resolveActionIcon } from '../utils/actionIcons';
import { EmptyState } from '../design/components/EmptyState';
import { MessageRow } from '../design/components/MessageRow';
import { SegmentedItem } from '../design/components/SegmentedControl';
import { Pressable } from '../design/motion/Pressable';
import { Reveal } from '../design/motion/Reveal';
import { ColorTokens } from '../design/tokens/color';
import { IconTokens } from '../design/tokens/icon';
import { RadiusTokens } from '../design/tokens/radius';
import { LayoutTokens, SpaceTokens } from '../design/tokens/space';
import { MotionCurves, MotionTokens } from '../design/tokens/motion';
import { TypeTokens } from '../design/tokens/type';
import { HdsNavigation, HdsNavigationTitleMode, ScrollEffectType } from '@kit.UIDesignKit';
import type { BottomBuilderParams } from '@kit.UIDesignKit';
import type {
  HdsNavigationTitleBarOptions,
  TitleBarContentOptions,
  TitleBarStyleOptions,
  ScrollEffectOptions,
} from '@kit.UIDesignKit';
import { LengthMetrics } from '@kit.ArkUI';
import { SegmentedControl } from '../design/components/SegmentedControl';
import { isSystemMaterialActive } from '../utils/immersiveMaterial';

// 消息分段：通知 | 私信（导出给 Index 的标题栏渲染；本页 Swiper 与之共享选中态）
export const MESSAGE_SEGMENTS: SegmentedItem[] = [
  { key: 'notif', label: '通知' },
  { key: 'dm', label: '私信' },
];

// —— 顶栏（嵌套 HdsNavigation，路线 B，同首页结构）——
// bottomBuilder 分段行高：40 控件（参考App 实测栏高）+ 上方 14 / 下方 28 材质投影净空
// （实测投影向下散 84px、向上散 34px 才收敛回画布白）
// ⚠️ 分段行不可用负 margin 上浮：bottomBuilder 区域对内容**双向裁切**（向上探出被剪、
// 超出声明高度向下也被剪——快筛行首测"丢失"同源），与 stackBuilder 向下溢出可渲染
// 不对称。分段栏位置 = 标题区下沿，结构上不可上移。
// 同理，官方分段栏（SegmentButton）材质自带的环境投影**必须**由行高买单：行高只给 36+4 时
// 投影被裁成灰带（docs/tutorial-titlebar-immersive-light.md 案例 9 同源）。
// 自绘分段栏（36vp）行高：上 xs 呼吸位 + 底部 28vp 材质投影净空（与首页同口径）
const MESSAGE_TITLE_ROW_VP: number = 56;
// bottomBuilder 分段行高：36 控件 + 上 xs 呼吸位 + 下 28 材质投影净空（配平值）
const MESSAGE_TAB_ROW_HEIGHT: number = LayoutTokens.segmentedHeight + SpaceTokens.xs + LayoutTokens.segmentBarShadowRoom;
// 滚动模糊生效区间终点（vp）：与首页定稿一致（0 → 32 线性到位）
const MESSAGE_BLUR_END_VP: number = 32;
// 「上滑收起快捷筛选栏」的实现取舍（真机两轮实证）：
// ✗ bottomBuilder.height 动态重配 → 只在首帧生效，运行期改高度无效（快筛行首测"丢失"根因）；
// ✗ dynamicHideTitleBar({ hideBottomBuilder: true }) → 触发式整段收起（非跟手），真机割裂感；
//   且分段行不能上移 stackBuilder 躲收起——MINI 标题区高度系统定值（首页 56 恰好顶格），
//   stackBuilder 无高度参数，多行内容溢出部分与 bottomBuilder 重叠（真机「组件重叠」）。
// ✓ 定稿：快筛行回归内容区顶部、作为滚动内容随列表滚走（同 pinnedEntries 先例）——
//   跟手丝滑、静止位置与进栏前一致，分段行常驻标题栏。
// 三类互动快捷筛选（内容区顶部，切换通知列表的过滤视图）
interface MessageShortcut {
  key: string;
  label: string;
  icon: string;
}

const MESSAGE_SHORTCUTS: MessageShortcut[] = [
  { key: 'up_bookmark', label: '赞和收藏', icon: 'like' },
  { key: 'follow', label: '新增关注', icon: 'follow' },
  { key: 'comment', label: '评论', icon: 'comment' },
];

@Component
export struct MessagePage {
  // 当前三类筛选视图的通知列表：服务端按 activeFilter 对应的 type 口径分页（见 filterType()），
  // 因此列表与快捷筛选红点（unread-count 的 byType，跨全部分页）同源同口径。
  @State list: NotificationItem[] = [];
  // system 消息独立一页：三类互动视图不展示系统通知，但「系统通知/举报中心」两个常驻入口的
  // 预览文案、时间和红点都要靠它——若继续从混合的 this.list 里找，切换筛选后必然找不到。
  @State systemList: NotificationItem[] = [];
  @State loading: boolean = true;
  @State error: string = '';
  @State page: number = 1;
  @State hasMore: boolean = true;
  @State refreshing: boolean = false;
  // 与 Index 共享的红点计数（@StorageLink 双向，写回即同步红点）
  @StorageLink('unreadMessageCount') unreadCount: number = 0;
  // 按类型未读分布（服务端 unread-count 的 byType）：三类快捷筛选红点的数据源
  @State unreadByType: UnreadByType = { comment: 0, up: 0, bookmark: 0, follow: 0, mention: 0, system: 0 };
  // 监听登录态：LoginPage 自动登录后 authToken 就绪，此页才加载（aboutToAppear 可能在登录前已跑过）
  @StorageLink('authToken') @Watch('onTokenReady') token: string = '';
  // 三类快捷筛选选中项（内容区顶部，无「全部」视图，默认赞和收藏）
  // 列表已由服务端按类型分页，切换筛选 = 换请求口径，必须重拉第一页
  @State @Watch('onFilterChanged') activeFilter: string = 'up_bookmark';
  // ===== 私信 =====
  @State dmTab: string = 'notif'; // 'notif' | 'dm'
  // 分段选中（通知/私信）：由本页 Swiper 与官方分段栏共用，切换动作统一走 @Watch
  @Link @Watch('onDmTabChanged') dmTabIndex: number;
  // 分段切换的轻微透明反馈（标题栏分段栏用）
  @Link tabPulse: boolean;
  // 标题栏「全部已读」按钮 → 本页执行（递增序号触发 @Watch）
  @Link @Watch('onMarkAllRequested') markAllSeq: number;
  @State conversations: Conversation[] = [];
  // —— 宽屏双栏（md/lg 断点）：会话列表 + 内嵌会话 ——
  // 断点来自全局断点中心；activeTab 用于切走消息页时卸载右栏（停掉聊天轮询，省接口配额）。
  @StorageProp('isWidePane') isWidePane: boolean = false;
  @StorageProp('currentBreakpoint') currentBreakpoint: string = 'sm';
  @StorageProp('activeTab') activeTab: number = 0;
  // 右栏当前会话（0 = 未选，显示空态）；点会话只更新这里，不压栈
  @State splitPeerId: number = 0;
  @State splitPeerName: string = '';
  @State splitPeerAvatar: string = '';
  @State dmLoading: boolean = true;
  @State dmError: string = '';
  // 私信未读（与通知红点分开存储，Index 合并显示）
  @StorageLink('unreadDmCount') dmUnread: number = 0;
  // 聊天页发送/已读后自增，触发本页刷新会话列表与未读
  @StorageLink('dmRefreshSignal') @Watch('onDmRefreshSignal') dmRefreshSignal: number = 0;
  // 系统通知页标读完成后自增 → 本页重拉列表，入口红点与预览即时回落
  @StorageLink('systemNoticeRefreshSignal') @Watch('onSystemNoticeRefreshSignal') systemNoticeRefreshSignal: number = 0;
  // 举报处置/内容审核后自增（后端已同步「举报中心」置顶消息的待处理数）
  // → 本页重拉列表，举报中心入口的文案即时刷新
  @StorageLink('reportCenterRefreshSignal') @Watch('onReportCenterRefreshSignal') reportCenterRefreshSignal: number = 0;
  // 订阅登录账号：切换账号（如老张↔小美互测）时重拉通知与私信，
  // 否则 TabContent 内组件被保留，残留上一个账号的通知/会话与红点。
  @StorageLink('authUserId') @Watch('onUserChange') uid: string = '';
  @StorageLink('reduceMotion') reduceMotion: boolean = false;
  @StorageLink('systemReduceMotion') systemReduceMotion: boolean = false;
  // —— 顶栏（嵌套 HdsNavigation，路线 B，同首页结构）——
  // 通知/私信两个列表各一个 Scroller：交给 bindToScrollable 驱动标题栏渐变模糊
  private notifScroller: Scroller = new Scroller();
  private dmScroller: Scroller = new Scroller();
  // 模糊完成态：滚动过模糊终点后顶栏切白（同首页定稿行为）
  @State brandOnBlur: boolean = false;
  // 状态栏高度（Index 启动时写入 AppStorage）：穿底内缩 = 状态栏 + 56vp 标题行
  @StorageProp('statusBarHeight') statusBarHeight: number = 0;
  // 刷新指示器显隐：Refresh 的 builder 内容永远参与绘制，必须属性级门控（同 ProfilePage.refreshBuilder）
  @State refreshIndicatorVisible: boolean = false;

  // 滚动驱动顶栏切白：读当前列表 Scroller 的绝对偏移，过模糊终点翻转（一次 animateTo）。
  // currentOffset() 加空值防御：类型声明非可选但滚动容器未创建/绑定时运行时返回 undefined
  //（Swiper 懒建页竞态，release 真机已复现崩溃，见 HomeTab.updateBrandCompact 同款修复）
  private updateBarOnBlur(seg: number): void {
    const scroller: Scroller = seg === 1 ? this.dmScroller : this.notifScroller;
    const offset: number = scroller?.currentOffset()?.yOffset ?? 0;
    const onBlur: boolean = offset > MESSAGE_BLUR_END_VP;
    if (onBlur === this.brandOnBlur) {
      return;
    }
    this.getUIContext().animateTo({ duration: MotionTokens.base, curve: MotionCurves.decelerate }, () => {
      this.brandOnBlur = onBlur;
    });
  }

  // bindToScrollable 动态只绑当前可见分段的 Scroller：切分段时数组变化触发重绑，
  // HDS 按新 Scroller 的当前偏移重估模糊——修「通知页滚出模糊后切私信，模糊咬死不消失」
  // （两页同时绑定时 HDS 不感知可见页切换，模糊停留在最后滚动过的列表状态）。
  private activeScrollers(): Scroller[] {
    return [this.dmTabIndex === 1 ? this.dmScroller : this.notifScroller];
  }

  // 穿底内缩：内容区从窗口原点起算（真机实证），让位 = 状态栏 + 56vp 标题行 + bottomBuilder
  // 分段行（基准 §7.6.11/12 同 Index.profileListInset；分段栏已放回标题栏，行高须一并让出）。
  private messageListInset(): number {
    return this.statusBarHeight + MESSAGE_TITLE_ROW_VP + MESSAGE_TAB_ROW_HEIGHT;
  }

  // 「全部已读」可见性：仅通知分段且已登录（原 Index.messageMarkAllVisible 逻辑迁入）
  private markAllVisible(): boolean {
    return this.dmTabIndex === 0 && this.token !== '';
  }
  private tabPulseTimer: number = 0;

  // 归口「系统通知」入口的 system 消息：审核结果（已通过/未通过审核）、举报回执
  // （因被举报正在审核中 / 你的举报已处理）等都在内 —— 三类互动视图不展示系统通知，
  // 这里是它们唯一的收纳处（进页可读、可清未读）。
  // ⚠️ 管理员的「举报中心：有 N 条举报待处理」归口上面的举报中心入口，不在此重复。
  private isSystemNotice(item: NotificationItem): boolean {
    if (item.type !== 'system') {
      return false;
    }
    return !(getIsAdmin() && this.isReportCenterItem(item));
  }

  // 「举报中心」置顶消息判定：作为常驻入口（reportCenterEntry）的副标题/时间数据来源
  private isReportCenterItem(item: NotificationItem): boolean {
    if (item.pinned !== true) {
      return false;
    }
    const content: string = item.content ?? '';
    return content.startsWith('举报中心') || content.includes('收到新举报');
  }

  // 当前筛选视图的渲染列表（方法调用，避免 ArkTS getter 在 build() 中不稳定）。
  // 类型筛选已下推到服务端（listNotifications 的 type，与红点计数同口径），列表就是
  // 当前筛选可完整翻页的一集——此前「本地过滤混合首页」是红点亮着却找不到未读条目的
  // 成因之一：计数跨全部分页，行只有第 1 页，筛完不足一屏时触底事件根本不触发，
  // 第 2 页永远拉不到。
  // 这里再按同口径过一遍是发布顺序的兜底：商店包可能跑在还没支持逗号多类筛选的后端上
  // （老服务端白名单不命中 → 忽略 type → 返回混合页），少了这层就会把关注/系统通知
  // 混进「赞和收藏」。服务端已过滤时它是恒等过滤，不改变任何行为。
  // 系统类（审核/举报回执）不属于这三类视图，另见常驻入口（pinnedEntries）。
  private getFilteredList(): NotificationItem[] {
    const list: NotificationItem[] = this.list;
    if (list === undefined || list === null) {
      return [];
    }
    const types: string[] = this.filterTypes();
    return list.filter((item: NotificationItem) => types.indexOf(String(item.type ?? '')) >= 0);
  }

  aboutToAppear(): void {
    // 已有登录态则直接加载；否则等 onTokenReady 在 token 就绪后补加载
    if (getToken() !== '') {
      this.loadFirst();
    }
  }

  aboutToDisappear(): void {
    if (this.tabPulseTimer !== 0) {
      clearTimeout(this.tabPulseTimer);
      this.tabPulseTimer = 0;
    }
  }

  private shouldReduceMotion(): boolean {
    return this.reduceMotion || this.systemReduceMotion;
  }

  private playTabFeedback(): void {
    if (this.shouldReduceMotion()) {
      return;
    }
    if (this.tabPulseTimer !== 0) {
      clearTimeout(this.tabPulseTimer);
    }
    this.tabPulse = true;
    this.tabPulseTimer = setTimeout((): void => {
      this.tabPulse = false;
      this.tabPulseTimer = 0;
    }, MotionTokens.control) as number;
  }

  // token 由空变为非空（登录完成）→ 列表为空才拉取，避免重复加载；
  // token 清空（登出）→ 清空残留通知/私信，避免未登录时消息中心展示上一账号的个人化数据。
  onTokenReady(): void {
    if (this.token === '') {
      this.resetData();
      return;
    }
    if (this.list.length === 0 && this.error === '') {
      this.loadFirst();
    }
  }

  // 聊天页发送/已读后 dmRefreshSignal 自增 → 刷新会话列表与私信未读红点
  onDmRefreshSignal(): void {
    if (this.token !== '' && this.dmTab === 'dm') {
      this.loadConversations();
    }
    if (this.token !== '') {
      this.loadDmUnread();
    }
  }

  // 从系统通知页返回（该页进入即把系统通知全标已读）→ 重拉列表，
  // 让「系统通知」入口的红点与预览在不切页的情况下即时刷新
  onSystemNoticeRefreshSignal(): void {
    if (this.token !== '') {
      this.loadFirst();
    }
  }

  // 举报处置 / 内容审核后（后端已把「举报中心」待处理数写回置顶消息）→ 重拉列表，
  // 举报中心入口的文案（有 N 条待处理 / 暂无待处理）即时刷新
  onReportCenterRefreshSignal(): void {
    if (this.token !== '') {
      this.loadFirst();
    }
  }

  // 切换登录账号（登出/切换虚拟账号）→ 立即重拉通知与私信，避免 TabContent 内组件残留；
  // 登出（无有效用户）→ 清空所有消息数据，杜绝未登录时展示上一账号的通知/会话/红点。
  onUserChange(): void {
    const u = getCurrentUser();
    if (!u || !u.id) {
      this.resetData();
      return;
    }
    if (this.token !== '') {
      this.loadFirst();
      this.loadConversations();
      this.loadDmUnread();
    }
  }

  // 清空通知/私信/红点（登出或 token 失效时调用）；@StorageLink 写回同步清除底部栏红点。
  private resetData(): void {
    this.list = [];
    this.systemList = [];
    this.conversations = [];
    this.error = '';
    this.dmError = '';
    this.page = 1;
    this.hasMore = true;
    this.loading = false;
    this.dmLoading = false;
    this.refreshing = false;
    this.activeFilter = 'up_bookmark';
    this.unreadCount = 0;
    this.dmUnread = 0;
    this.reportCenterPending = -1;
  }

  // 按通知类型统计未读数：已改由服务端 unread-count 的 byType 提供（见 unreadByType），
  // 从「已加载的一页列表」里数的近似口径已废弃——未读项不在第一页时永远算出 0。

  // 相对时间格式化
  private formatTime(iso?: string): string {
    if (!iso) {
      return '';
    }
    const t: number = new Date(iso).getTime();
    if (isNaN(t)) {
      return '';
    }
    const diff: number = Date.now() - t;
    const min: number = Math.floor(diff / 60000);
    if (min < 1) {
      return '刚刚';
    }
    if (min < 60) {
      return min + '分钟前';
    }
    const hr: number = Math.floor(min / 60);
    if (hr < 24) {
      return hr + '小时前';
    }
    const day: number = Math.floor(hr / 24);
    if (day < 30) {
      return day + '天前';
    }
    const d: Date = new Date(t);
    const y: number = d.getFullYear();
    const m: number = d.getMonth() + 1;
    const dd: number = d.getDate();
    return y + '-' + (m < 10 ? '0' + m : m) + '-' + (dd < 10 ? '0' + dd : dd);
  }

  // 列表请求序号：loadFirst 与 loadMore 共用；响应回来时序号已落后则整体丢弃。
  // 竞态：loadMore（页2）在途时账号切换/信号触发 loadFirst → loadFirst 回包覆盖列表
  // 但 loadMore 回包把 page 写成 2 → 下一页请求直接跳到页3，页2 的通知永久缺失。
  private listSeq: number = 0;
  // system 页请求序号（与主列表各自独立丢弃过期响应）
  private systemSeq: number = 0;

  // 当前筛选视图包含的通知类型（唯一口径来源：服务端查询串与本地下拉过滤都用它）
  private filterTypes(): string[] {
    const filter: string = this.activeFilter;
    if (filter === 'follow') {
      return ['follow'];
    }
    if (filter === 'comment') {
      // @提及（评论中提到了你）并入「评论」——提及只发生在评论区，单独放会无处可看
      return ['comment', 'mention'];
    }
    return ['up', 'bookmark'];
  }

  // 当前筛选视图对应的服务端 type 口径（逗号分隔多类，与红点计数同口径）
  private filterType(): string {
    return this.filterTypes().join(',');
  }

  // 切换筛选：列表换的是请求口径而非本地子集，先清空（让 loading 分支接手）再拉第一页，
  // 避免旧筛选的行在新筛选下短暂显示「暂无此类通知」。红点计数不受影响（服务端权威值）。
  onFilterChanged(): void {
    if (this.token === '') {
      return;
    }
    this.list = [];
    this.fetchFirstPage();
  }

  // 拉取当前筛选视图的第一页（不重复拉未读计数，供筛选切换与整体刷新共用）
  private async fetchFirstPage(): Promise<void> {
    const seq: number = ++this.listSeq;
    this.loading = true;
    this.error = '';
    this.page = 1;
    this.hasMore = true;
    try {
      const res = await listNotifications(1, 20, this.filterType());
      if (seq !== this.listSeq) {
        return; // 过期响应：期间已有更新的请求发起，整体丢弃
      }
      this.list = res.list;
      this.hasMore = res.pagination.total > this.list.length;
      this.loading = false;
    } catch (e) {
      if (seq !== this.listSeq) {
        return; // 过期请求的失败不覆盖新请求的状态
      }
      this.error = (e as Error).message || '加载失败';
      this.loading = false;
    }
  }

  // 常驻入口（系统通知/举报中心）的数据源：system 类独立一页（置顶恒在最前）。
  async fetchSystemList(): Promise<void> {
    const seq: number = ++this.systemSeq;
    try {
      const res = await listNotifications(1, 20, 'system');
      if (seq !== this.systemSeq) {
        return;
      }
      this.systemList = res.list;
    } catch (e) {
      // 忽略：入口退回通用文案，不阻断主列表
    }
  }

  async loadFirst(): Promise<void> {
    this.error = '';
    await this.refreshUnread();
    // 举报中心入口的待处理数（管理员）：与列表同一轮拉取，处置返回后经刷新信号一并刷新
    this.loadReportCenterPending();
    await this.loadDmUnread();
    await this.fetchFirstPage();
    await this.fetchSystemList();
  }

  async loadMore(): Promise<void> {
    if (!this.hasMore || this.loading) {
      return;
    }
    const seq: number = ++this.listSeq;
    const type: string = this.filterType();
    this.loading = true;
    try {
      const next: number = this.page + 1;
      const res = await listNotifications(next, 20, type);
      if (seq !== this.listSeq || type !== this.filterType()) {
        return; // 过期响应：期间 loadFirst/切筛选已重置列表，丢弃（避免旧页 append 进新列表）
      }
      if (res.list.length > 0) {
        this.list = this.list.concat(res.list);
        this.page = next;
        this.hasMore = res.pagination.total > this.list.length;
      } else {
        this.hasMore = false;
      }
      this.loading = false;
    } catch (e) {
      if (seq !== this.listSeq) {
        return;
      }
      this.loading = false;
    }
  }

  async refreshUnread(): Promise<void> {
    try {
      const res = await getUnreadCount();
      this.unreadCount = res.count;
      // 按类型未读分布（服务端权威计数）：三类快捷筛选红点的数据源。
      // 此前从「已加载的一页列表」里数——未读项不在第一页时红点永远为 0。
      if (res.byType !== undefined) {
        this.unreadByType = res.byType;
      }
    } catch (e) {
      // 红点失败不阻断主列表
    }
  }

  // ===== 私信 =====
  async loadDmUnread(): Promise<void> {
    try {
      const res = await getDmUnreadCount();
      this.dmUnread = res.count;
    } catch (e) {
      // 私信红点失败不阻断
    }
  }

  async loadConversations(): Promise<void> {
    this.dmLoading = true;
    this.dmError = '';
    try {
      const res = await getConversations();
      this.conversations = res.list;
      this.dmLoading = false;
    } catch (e) {
      this.dmError = (e as Error).message || '加载失败';
      this.dmLoading = false;
    }
  }

  // 点击会话：窄屏压栈进聊天页（peer 信息经短暂导航意图传递）；
  // 宽屏（md/lg）双栏形态只更新右栏选中会话 —— 列表-会话切换不压栈、不打断上下文。
  onConversationClick(c: Conversation): void {
    // 会话数据在 api 层是 as 直转（无字段级校验），缺 peer 时读 c.peer.id 会在 onClick
    // 回调里抛未捕获异常。同文件对 item.actor 已有同类防御，这里补齐。
    if (!c.peer) {
      return;
    }
    if (this.isWidePane) {
      if (this.splitPeerId !== c.peer.id) {
        this.splitPeerId = c.peer.id;
        this.splitPeerName = c.peer.nickname;
        this.splitPeerAvatar = c.peer.avatar ?? '';
      }
      return;
    }
    openChat({ peerId: c.peer.id, peerName: c.peer.nickname, peerAvatar: c.peer.avatar ?? '' });
    this.getUIContext().getRouter().pushUrl({ url: 'pages/ChatPage' });
  }

  // 相对时间（私信会话列表复用）
  private formatDmTime(iso?: string): string {
    if (!iso) {
      return '';
    }
    const t: number = new Date(iso).getTime();
    if (isNaN(t)) {
      return '';
    }
    const diff: number = Date.now() - t;
    const min: number = Math.floor(diff / 60000);
    if (min < 1) return '刚刚';
    if (min < 60) return min + '分钟前';
    const hr: number = Math.floor(min / 60);
    if (hr < 24) return hr + '小时前';
    const day: number = Math.floor(hr / 24);
    if (day < 30) return day + '天前';
    const d: Date = new Date(t);
    return d.getFullYear() + '-' + (d.getMonth() + 1) + '-' + d.getDate();
  }

  // 会话列表最近消息摘要：图片/视频消息显示占位，避免直接展示 URL
  private conversationPreview(c: Conversation): string {
    if (c.lastType === 'image') {
      return '[图片]';
    }
    if (c.lastType === 'video') {
      return '[视频]';
    }
    return c.lastContent ?? '';
  }

  @Builder
  conversationRow(c: Conversation) {
    MessageRow({
      title: c.peer.nickname,
      subtitle: (c.lastSenderId === this.getSelfId() ? '我: ' : '') + this.conversationPreview(c),
      time: this.formatDmTime(c.lastAt),
      avatar: c.peer.avatar ?? '',
      name: c.peer.nickname,
      unreadCount: c.unreadCount,
      titleMaxLines: 1,
      subtitleMaxLines: 1,
      action: (): void => {
        this.onConversationClick(c);
      },
      avatarAction: (): void => {
        this.goUser(c.peer.id);
      },
    })
  }

  // 当前登录用户 id（用于会话列表区分「我:」前缀）。authUserId 在 AppStorage 中以字符串持久化，
  // 用 getUserId() 统一解析为 number，避免与后端返回的数字 id 用 === 比较时因类型不一致永远不相等。
  private getSelfId(): number {
    return getUserId();
  }

  // 点击会话头像 → 跳转对端主页（与评论/帖子头像跳转一致）
  private goUser(id: number): void {
    openUserProfile(id);
    this.getUIContext().getRouter().pushUrl({ url: 'pages/UserProfilePage' });
  }

  // 点击通知头像 → 跳转触发者（actor）主页；无 actor（系统/无来源）时忽略
  private onActorAvatarClick(item: NotificationItem): void {
    if (item.actor !== undefined && item.actor !== null && item.actor.id !== undefined) {
      this.goUser(item.actor.id);
    }
  }

  // 构造把指定 id 标为已读的新数组（逐字段重建，规避对象展开 {...x}；重赋值才能触发 @State 刷新）
  private withReadFlag(src: NotificationItem[], id: number): NotificationItem[] {
    const out: NotificationItem[] = src.slice();
    for (let i = 0; i < out.length; i++) {
      if (out[i].id === id) {
        const cur: NotificationItem = out[i];
        out[i] = {
          id: cur.id,
          type: cur.type,
          actor: cur.actor,
          postId: cur.postId,
          commentId: cur.commentId,
          content: cur.content,
          read: true,
          pinned: cur.pinned ?? false,
          createdAt: cur.createdAt,
        };
        break;
      }
    }
    return out;
  }

  private findNotifById(src: NotificationItem[], id: number): NotificationItem | undefined {
    for (const it of src) {
      if (it.id === id) {
        return it;
      }
    }
    return undefined;
  }

  // 本地乐观标记已读：就地替换该条 + 递减未读计数，立即驱动红点/角标消失（不必等网络）
  // 两个数据源都要处理：互动列表（this.list）与常驻入口的 system 页（this.systemList）
  private markReadOptimistic(id: number): void {
    const found: NotificationItem | undefined =
      this.findNotifById(this.list, id) ?? this.findNotifById(this.systemList, id);
    const foundType: string = found === undefined ? '' : (found.type ?? '');
    this.list = this.withReadFlag(this.list, id);
    this.systemList = this.withReadFlag(this.systemList, id);
    if (this.unreadCount > 0) {
      this.unreadCount = this.unreadCount - 1;
    }
    // per-type 红点同步乐观减（随后 refreshUnread 以服务端权威值校正）
    const byType: UnreadByType = {
      comment: this.unreadByType.comment,
      up: this.unreadByType.up,
      bookmark: this.unreadByType.bookmark,
      follow: this.unreadByType.follow,
      mention: this.unreadByType.mention,
      system: this.unreadByType.system,
    };
    if (foundType === 'up') {
      byType.up = Math.max(0, byType.up - 1);
    } else if (foundType === 'bookmark') {
      byType.bookmark = Math.max(0, byType.bookmark - 1);
    } else if (foundType === 'follow') {
      byType.follow = Math.max(0, byType.follow - 1);
    } else if (foundType === 'comment') {
      byType.comment = Math.max(0, byType.comment - 1);
    } else if (foundType === 'mention') {
      byType.mention = Math.max(0, byType.mention - 1);
    } else if (foundType === 'system') {
      // 「举报中心」入口点击后，系统通知入口的服务端兜底计数要同步回落，否则会连带误亮
      byType.system = Math.max(0, byType.system - 1);
    }
    this.unreadByType = byType;
  }

  // 点击单条：本地乐观标记已读（立即驱动红点消失）→ 后台同步后端 → 按类型跳转
  async onItemClick(item: NotificationItem): Promise<void> {
    if (item.read !== true && item.id !== undefined) {
      const id: number = item.id;
      // 先乐观更新本地（list + unreadMessageCount），立即隐藏红点，避免等待网络；
      // 否则网络慢时红点迟迟不消失，切花 Tab 重建后才看到。
      this.markReadOptimistic(id);
      // 标记失败不影响已删除的红点与跳转
      try {
        await markNotificationRead(id);
      } catch (e) {
        // 忽略：下次进入消息页拉取会以服务器为准
      }
      // 用后端权威未读数校正（本地乐观可能与服务器有偏差）
      this.refreshUnread();
    }
    // 点击单条跳转：新增关注 → 该用户（actor）主页；带 postId 的通知（赞/收藏/评论）→ 原帖详情，
    // 带 commentId 的（@提及）→ 详情页滚动定位到该评论并高亮
    // （举报中心类通知已从普通行收敛为上方常驻入口，跳转见 onReportCenterClick）
    if (item.type === 'follow' && item.actor !== undefined && item.actor !== null && item.actor.id) {
      openUserProfile(item.actor.id);
      this.getUIContext().getRouter().pushUrl({ url: 'pages/UserProfilePage' });
      return;
    }
    if (item.postId !== undefined && item.postId !== null) {
      const cid: number | null | undefined = item.commentId;
      if (cid !== undefined && cid !== null && cid > 0) {
        openPostDetailAtComment(String(item.postId), cid);
      } else {
        openPostDetail(String(item.postId));
      }
      this.getUIContext().getRouter().pushUrl({ url: 'pages/DetailPage' });
    }
  }

  // ===== 举报中心（管理员）=====
  // 整条举报链路的通知（举报中心待处理数、被举报审核中、举报已处理回执）不再作为
  // 普通行，收敛为通知列表上方一条常驻入口：切换「赞和收藏/新增关注/评论」筛选时
  // 始终置顶可见，不随筛选消失。
  // 待处理数（-1 = 未就绪/非管理员）取自举报台账接口的真实计数，不读置顶消息里的旧文案
  // 同时按板块（帖子/评论/用户）分开计数，副标题直接分类展示
  @State reportCenterPending: number = -1;
  @State reportCenterPost: number = 0;
  @State reportCenterComment: number = 0;
  @State reportCenterUser: number = 0;

  // 拉取待处理举报的分类计数（仅管理员；失败静默，退回通知文案展示）
  async loadReportCenterPending(): Promise<void> {
    if (!getIsAdmin()) {
      return;
    }
    try {
      const res: PendingReportSummary = await getAdminReportSummary();
      this.reportCenterPending = res.total;
      this.reportCenterPost = res.post;
      this.reportCenterComment = res.comment;
      this.reportCenterUser = res.user;
    } catch (e) {
      // 忽略：入口退回通知文案，不阻断消息列表
    }
  }

  private reportCenterItem(): NotificationItem | undefined {
    for (const it of this.systemList) {
      if (this.isReportCenterItem(it)) {
        return it;
      }
    }
    return undefined;
  }

  // 入口副标题：以举报台账的实时待处理数为准（服务端真实数据），并按板块分类展示
  // —— 通知文案只在「新举报产生 / 处置回写」时更新，历史上漏更新的行会让入口一直显示旧数字。
  // 计数未就绪（请求失败/非管理员）时退回通知文案，再退回通用说明。
  private reportCenterSubtitle(): string {
    if (this.reportCenterPending >= 0) {
      if (this.reportCenterPending === 0) {
        return '暂无待处理举报';
      }
      return '帖子 ' + String(this.reportCenterPost)
        + ' · 评论 ' + String(this.reportCenterComment)
        + ' · 用户 ' + String(this.reportCenterUser) + ' 待处理';
    }
    const it: NotificationItem | undefined = this.reportCenterItem();
    if (it === undefined) {
      return '查看举报台账与处置记录';
    }
    const content: string = it.content ?? '';
    if (content.startsWith('举报中心：')) {
      return content.substring('举报中心：'.length);
    }
    return content;
  }

  private reportCenterTime(): string {
    const it: NotificationItem | undefined = this.reportCenterItem();
    return it === undefined ? '' : this.formatTime(it.createdAt);
  }

  private reportCenterUnread(): boolean {
    // 入口红点只跟随「举报中心」这条通知本身：其余举报回执/审核中消息归口系统通知入口
    const it: NotificationItem | undefined = this.reportCenterItem();
    return it !== undefined && it.read !== true;
  }

  // 点击入口：先把「举报中心」通知乐观标为已读（立刻消红点），再进举报中心。
  // 管理员闸门由入口的渲染条件（getIsAdmin）与举报中心页自身兜底，这里不重复判断。
  async onReportCenterClick(): Promise<void> {
    const it: NotificationItem | undefined = this.reportCenterItem();
    if (it !== undefined && it.read !== true && it.id !== undefined) {
      const id: number = it.id;
      this.markReadOptimistic(id);
      try {
        await markNotificationRead(id);
      } catch (e) {
        // 忽略：下次进入消息页拉取会以服务器为准
      }
      this.refreshUnread();
    }
    this.getUIContext().getRouter().pushUrl({ url: 'pages/ReportAdminPage' });
  }

  // ===== 系统通知（所有登录用户）=====
  // 三类互动视图之外的 system 消息（审核结果、举报回执等）在此有唯一入口：
  // 点开进「系统通知」页可读；该页进入即全部标读，返回时经刷新信号让本页入口红点即时回落。
  private systemNoticeItem(): NotificationItem | undefined {
    for (const it of this.systemList) {
      if (this.isSystemNotice(it)) {
        return it;
      }
    }
    return undefined;
  }

  private systemNoticeSubtitle(): string {
    const it: NotificationItem | undefined = this.systemNoticeItem();
    return it === undefined ? '暂无系统通知' : (it.content ?? '');
  }

  private systemNoticeTime(): string {
    const it: NotificationItem | undefined = this.systemNoticeItem();
    return it === undefined ? '' : this.formatTime(it.createdAt);
  }

  private systemNoticeUnread(): boolean {
    for (const it of this.systemList) {
      if (this.isSystemNotice(it) && it.read !== true) {
        return true;
      }
    }
    // 已加载的 system 页全读，但服务端仍报未读（未读落在第 2 页之后）→ 红点必须亮，
    // 否则就是「消息页有红点、页面上却没有未读条目」的来源之一。
    // 管理员的「举报中心」置顶消息归口另一个入口，从服务端计数里扣掉，避免两个入口同亮。
    let serverUnread: number = this.unreadByType.system;
    if (getIsAdmin() && serverUnread > 0) {
      const rc: NotificationItem | undefined = this.reportCenterItem();
      if (rc !== undefined && rc.read !== true) {
        serverUnread -= 1;
      }
    }
    return serverUnread > 0;
  }

  onSystemNoticeClick(): void {
    this.getUIContext().getRouter().pushUrl({ url: 'pages/SystemNoticePage' });
  }

  // 置顶入口（举报中心 + 系统通知）：渲染在列表内容的最前面，
  // 「置顶但不固定」—— 随列表一起滚动，而不是钉在视口顶部常驻。
  @Builder
  pinnedEntries() {
    // 举报中心（管理员，唯一处置台）
    if (getIsAdmin()) {
      Column() {
        this.reportCenterEntry()
      }
      .width('100%')
    }

    // 系统通知：三类互动视图之外的 system 消息（审核结果/举报回执）唯一入口
    Column() {
      this.systemNoticeEntry()
    }
    .width('100%')
  }

  // 系统通知常驻入口（与举报中心入口同款 MessageRow 样式）
  @Builder
  systemNoticeEntry() {
    MessageRow({
      title: '系统通知',
      subtitle: this.systemNoticeSubtitle(),
      time: this.systemNoticeTime(),
      useIcon: true,
      icon: notifIconRes('system'),
      unread: this.systemNoticeUnread(),
      titleMaxLines: 1,
      subtitleMaxLines: 1,
      action: (): void => {
        this.onSystemNoticeClick();
      },
    })
  }

  // 举报中心常驻入口（图标与设置页「举报中心」一致，指向同一页）
  @Builder
  reportCenterEntry() {
    MessageRow({
      title: '举报中心',
      subtitle: this.reportCenterSubtitle(),
      time: this.reportCenterTime(),
      useIcon: true,
      icon: resolveActionIcon('book'),
      unread: this.reportCenterUnread(),
      titleMaxLines: 1,
      subtitleMaxLines: 1,
      action: (): void => {
        this.onReportCenterClick();
      },
    })
  }

  // 全部已读
  async onMarkAll(): Promise<void> {
    try {
      await markAllRead();
      // 后端把该用户所有通知（含 system 类）都置了已读：三个数据源必须一起归零，
      // 漏掉任何一个就是「条目上没有红点、入口/快捷筛选红点却还亮着」——
      // unreadByType 是三类快捷筛选红点的唯一数据源，此前只清了列表和总未读数。
      const allRead: NotificationItem[] = this.list.slice();
      for (let i = 0; i < allRead.length; i++) {
        const cur: NotificationItem = allRead[i];
        allRead[i] = {
          id: cur.id,
          type: cur.type,
          actor: cur.actor,
          postId: cur.postId,
          commentId: cur.commentId,
          content: cur.content,
          read: true,
          pinned: cur.pinned ?? false,
          createdAt: cur.createdAt,
        };
      }
      this.list = allRead;
      const sysRead: NotificationItem[] = this.systemList.slice();
      for (let j = 0; j < sysRead.length; j++) {
        const cur: NotificationItem = sysRead[j];
        sysRead[j] = {
          id: cur.id,
          type: cur.type,
          actor: cur.actor,
          postId: cur.postId,
          commentId: cur.commentId,
          content: cur.content,
          read: true,
          pinned: cur.pinned ?? false,
          createdAt: cur.createdAt,
        };
      }
      this.systemList = sysRead;
      this.unreadCount = 0;
      this.unreadByType = { comment: 0, up: 0, bookmark: 0, follow: 0, mention: 0, system: 0 };
      safeShowToast(this.getUIContext(), { message: '已全部标记为已读' });
    } catch (e) {
      safeShowToast(this.getUIContext(), { message: '操作失败，请重试' });
    }
  }

  // 通知类型 → 图标资源（ArkTS V1 不支持 obj[key] 索引访问，用函数分发）
  private typeIcon(type: NotificationType | undefined): Resource {
    return notifIconRes(type);
  }

  // 分段切换（标题栏点击 / Swiper 落页共用）：统一由 @Watch(dmTabIndex) 触发。
  // 两条路径都只写 dmTabIndex（同值写入不触发 @Watch），加载因此不会重复。
  onDmTabChanged(): void {
    const tab: string = this.dmTabIndex === 1 ? 'dm' : 'notif';
    if (this.dmTab === tab) {
      return;
    }
    this.dmTab = tab;
    // 切分段重算顶栏切白：目标页 Scroller 偏移（私信回顶 = 0 → 取消切白；切回通知 = 原偏移 → 按需恢复）。
    // onDidScroll 只在滚动时触发，切分段没有滚动事件，不补这一拍切白会咬死上一页的状态。
    this.updateBarOnBlur(this.dmTabIndex);
    this.playTabFeedback();
    if (tab === 'dm') {
      this.loadConversations();
    }
  }

  // 标题栏「全部已读」按钮触发（信号递增 → @Watch）
  onMarkAllRequested(): void {
    this.onMarkAll();
  }

  // 单个快捷筛选的未读数（服务端 unread-count 的 byType，跨全部分页的权威值）
  private unreadCountOf(key: string): number {
    const byType: UnreadByType = this.unreadByType;
    if (key === 'up_bookmark') {
      return byType.up + byType.bookmark;
    }
    if (key === 'follow') {
      return byType.follow;
    }
    return byType.comment + byType.mention;
  }

  // 单个快捷筛选（图标 + 未读红点 + 选中态）：红点数在内部现算，不作参数传入（原因见 messageShortcutsRow）
  @Builder
  notificationShortcut(shortcut: MessageShortcut) {
    Column() {
      Pressable({
        visualHeight: 34 + TypeTokens.callout.lineHeight + SpaceTokens.inline,
        touchTargetHeight: LayoutTokens.minTouchTarget,
        fillWidth: true,
        action: (): void => {
          // 无「全部」视图：点击当前项保持选中（不再回落为未选中态）；
          // 私信分段点击筛选：先切回通知分段（@Watch 承接切换），再落筛选态
          if (this.dmTabIndex !== 0) {
            this.dmTabIndex = 0;
          }
          this.activeFilter = shortcut.key;
        },
      }) {
        Column({ space: SpaceTokens.inline }) {
          Badge({
            count: this.unreadCountOf(shortcut.key),
            position: BadgePosition.RightTop,
            // 与顶栏分段徽标/底栏页签红点同一视觉语言（semantic_red、14）
            // color：深色 semantic_red #FF453A 是亮底，系统默认白字只有 3.41:1，换 onDanger 墨字（5.50:1）
            style: { badgeColor: $r('app.color.semantic_red'), color: ColorTokens.onDanger, badgeSize: 14 },
          }) {
            Image(resolveActionIcon(shortcut.icon))
              .width(34)
              .height(34)
              .objectFit(ImageFit.Contain)
              // 静态配色（icon/brand）：本行在内容区画布上，滚动带模糊阈值的状态色切换
              // 会在半露出时闪白（切白是标题栏模糊背板专用语义），不用
              .fillColor(this.activeFilter === shortcut.key ? ColorTokens.brand : ColorTokens.icon)
          }
          Text(shortcut.label)
            .fontSize(TypeTokens.overline.size).fontFamily(TypeTokens.fontFamily)
            .fontWeight(this.activeFilter === shortcut.key ? TypeTokens.headline.weight : TypeTokens.overline.weight)
            .lineHeight(TypeTokens.overline.lineHeight)
            .letterSpacing(TypeTokens.overline.tracking)
            // 选中态：字色回 primary（brand 字压 brandTint 底深色只有 3.58:1，11px 不达 AA），
            // 「选中」的身份交给 brandTint 底 + brand 图标 + 加粗 + 微放大。
            .fontColor(this.activeFilter === shortcut.key ? ColorTokens.primary : ColorTokens.icon)
            .maxLines(1)
        }
        .width('100%')
        .alignItems(HorizontalAlign.Center)
        .padding({ top: SpaceTokens.xs, bottom: SpaceTokens.xs })
        .backgroundColor(this.activeFilter === shortcut.key ? ColorTokens.brandTint : Color.Transparent)
        .borderRadius(RadiusTokens.md)
        .scale({
          x: this.activeFilter === shortcut.key && !this.shouldReduceMotion() ? 1.03 : 1,
          y: this.activeFilter === shortcut.key && !this.shouldReduceMotion() ? 1.03 : 1,
        })
        .animation({
          duration: this.shouldReduceMotion() ? MotionTokens.instant : MotionTokens.control,
          curve: MotionCurves.springSoft,
        })
      }
    }
    .layoutWeight(1)
  }

  // 未登录（游客）态：消息中心不展示任何个人化内容，仅提供手动登录入口
  @Builder
  guestState() {
    Column() {
      EmptyState({
        icon: resolveActionIcon('lock'),
        title: '未登录',
        message: '登录后可查看赞与收藏、关注、评论和私信等消息',
        actionLabel: '去登录',
        onAction: (): void => {
          this.getUIContext().getRouter().pushUrl({ url: 'pages/LoginPage' });
        },
      })
    }
    .layoutWeight(1)
    .width('100%')
    .justifyContent(FlexAlign.Center)
  }

  // 私信分段内容：窄屏单栏会话列表；宽屏（md/lg）列表-会话双栏
  @Builder
  dmContent() {
    if (this.isWidePane) {
      this.dmSplit()
    } else {
      this.dmList()
    }
  }

  // 宽屏双栏：左列会话列表（定宽）+ 右列内嵌会话（未选=空态）。
  // 右栏仅在消息页处于激活 Tab 时挂载：切走消息页即卸载，停掉聊天轮询（省接口配额）；
  // 回页时随选中会话重挂载并静默重拉（ChatView 挂载即 load + 标读）。
  @Builder
  dmSplit() {
    Row() {
      Column() {
        this.dmList()
      }
      .width(this.currentBreakpoint === 'lg' ? 340 : 300)
      .height('100%')

      Divider()
        .vertical(true)
        .strokeWidth(0.5)
        .color(ColorTokens.separator)
        .height('100%')

      Column() {
        if (this.splitPeerId > 0 && this.activeTab === 3) {
          ChatView({
            embedded: true,
            embedPeer: { id: this.splitPeerId, name: this.splitPeerName, avatar: this.splitPeerAvatar },
            navMode: true,
            onOpenVideo: (url: string, poster: string): void => { this.openChatVideo(url, poster); },
          })
        } else {
          // 未选会话 / 已切走消息页（右栏停挂载，轮询随之停止）
          Column() {
            EmptyState({
              icon: resolveActionIcon('send'),
              title: this.splitPeerId > 0 ? '会话已暂停' : '选择一条会话',
              message: this.splitPeerId > 0 ? '回到消息页继续' : '会话会在这里展开，列表与聊天同屏',
            })
          }
          .width('100%')
          .height('100%')
          .justifyContent(FlexAlign.Center)
        }
      }
      .layoutWeight(1)
      .height('100%')
      .padding({ top: this.messageListInset() })
    }
    .width('100%')
    .height('100%')
    .alignItems(VerticalAlign.Top)
  }

  // 内嵌会话点击视频 → 独立播放器页（与 ChatDestination 同通道）
  private openChatVideo(url: string, poster: string): void {
    const nav: NavPathStack | null = getMainNavStack();
    if (nav === null) {
      return;
    }
    const p: VideoPlayerNavParams = new VideoPlayerNavParams();
    p.url = url;
    p.poster = poster;
    nav.pushPathByName('VideoPlayer', p);
  }

  // 私信会话列表内容（窄屏单栏本体 / 宽屏左列）
  @Builder
  dmList() {
    if (this.dmLoading && this.conversations.length === 0) {
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
      .layoutWeight(1)
      .width('100%')
      .justifyContent(FlexAlign.Center)
    } else if (this.dmError !== '' && this.conversations.length === 0) {
      Column() {
        EmptyState({
          title: '加载失败',
          message: this.dmError,
          actionLabel: '重试',
          onAction: (): void => {
            this.loadConversations();
          },
        })
      }
      .layoutWeight(1)
      .width('100%')
      .justifyContent(FlexAlign.Center)
    } else if (this.conversations.length === 0) {
      Column() {
        EmptyState({
          icon: resolveActionIcon('send'),
          title: '还没有私信',
          message: '去他人主页发起聊天吧',
        })
      }
      .layoutWeight(1)
      .width('100%')
      .justifyContent(FlexAlign.Center)
    } else {
      Refresh({ refreshing: $$this.refreshing, builder: this.msgRefreshBuilder, offset: 80, friction: 48 }) {
        // 私信会话列表：Scroll 单列（懒加载 List 实测把滚动终点钳制在底部非安全区之上、
        // 露出窗口底色横带截断末行，Scroll 滚动范围天然到物理屏底）。
        // scroller 显式挂载：bindToScrollable 驱动标题栏渐变模糊；Refresh/Scroll 均需关裁切（穿底链路）
        Scroll(this.dmScroller) {
          Column({ space: SpaceTokens.none }) {
            ForEach(
              this.conversations,
              (c: Conversation, idx: number) => {
                Reveal({ index: idx % 5 }) {
                  this.conversationRow(c)
                }
              },
              // key 必须包含 unreadCount：同一坑见通知列表（key 带 read）。
              // 聊天页返回后重拉会话，未读已清零但 key 不变时 ForEach 复用旧行，
              // MessageRow.unreadCount 不刷新 → 会话红点残留不消失。
              (c: Conversation) => String(c.peer.id) + '-' + String(c.unreadCount),
            )
            // 底部预留：为悬浮底栏与系统手势区让出滚动空间（宽屏停靠栏同样悬浮在列首侧，同样需要）
            Column() {
              Blank().width('100%').height(barBottomReserve())
            }
            .width('100%')
          }
          .width('100%')
          .constraintSize({ minHeight: '100%' })
          .padding({
            left: SpaceTokens.sm,
            right: SpaceTokens.sm,
            top: this.messageListInset(),
            bottom: SpaceTokens.sm,
          })
        }
        .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true })
        .scrollable(ScrollDirection.Vertical)
        // 不裁剪 + 滚动驱动顶栏切白（私信列表）
        .clip(false)
        .onDidScroll((): void => {
          this.updateBarOnBlur(1);
        })
        .width('100%')
        .layoutWeight(1)
      }
      .onRefreshing(() => {
        this.loadConversations().finally(() => {
          this.refreshing = false;
        });
      })
      .onStateChange((state: RefreshStatus) => {
        this.refreshIndicatorVisible = state === RefreshStatus.Drag
          || state === RefreshStatus.OverDrag || state === RefreshStatus.Refresh;
      })
      .clip(false)
      .layoutWeight(1)
      .width('100%')
    }
  }

  @Builder
  notificationRow(item: NotificationItem) {
    MessageRow({
      title: this.notificationTitle(item),
      subtitle: this.formatTime(item.createdAt),
      avatar: item.actor?.avatar ?? '',
      name: item.actor?.nickname ?? '',
      useIcon: item.type === 'system' || item.actor === undefined || item.actor === null,
      icon: this.typeIcon(item.type),
      unread: item.read !== true,
      titleMaxLines: 2,
      subtitleMaxLines: 1,
      action: (): void => {
        this.onItemClick(item);
      },
      // 点击通知头像 → 直接进入触发者主页
      avatarAction: (): void => {
        this.onActorAvatarClick(item);
      },
    })
  }

  // 置顶系统通知（举报受理/审核）在主标题前加「置顶」标识，与普通消息区分
  private notificationTitle(item: NotificationItem): string {
    const base: string = item.content ?? '';
    if (item.pinned === true) {
      return '置顶 · ' + base;
    }
    return base;
  }

  // —— 顶栏标题栏配置（嵌套 HdsNavigation，路线 B：同首页定稿结构）——
  // MINI + stackBuilder 顶栏行（消息 + 全部已读）+ bottomBuilder 分段行（通知|私信 + 徽标）
  // + GRADIENT_BLUR 0→32vp + 透明起步 + avoid/enableComponentSafeArea 双开。逐层显式标注 SDK 类型。
  private messageHdsTitleBarOptions(): HdsNavigationTitleBarOptions {
    const scrollEffect: ScrollEffectOptions = {
      enableScrollEffect: true,
      scrollEffectType: ScrollEffectType.GRADIENT_BLUR,
      blurEffectiveStartOffset: LengthMetrics.vp(0),
      blurEffectiveEndOffset: LengthMetrics.vp(MESSAGE_BLUR_END_VP),
    };
    const style: TitleBarStyleOptions = {
      scrollEffectOpts: scrollEffect,
      originalStyle: {
        // maskExtraHeight 官方默认 32vp（模糊区往栏底之下多伸 32vp）——穿底后会把栏下内容
        // 多糊一截，压到 0 让磨砂正好停在栏底（同「我的」页 profileTitleBarOptions）。
        backgroundStyle: { backgroundColor: Color.Transparent, maskExtraHeight: 0 },
      },
    };
    const content: TitleBarContentOptions = {
      stackBuilder: (): void => { this.messageBrandRow(); },
      // 分段栏放回标题栏 bottomBuilder（用户拍板）：标题栏=材质生效区，栏上挂的
      // 系统材质/浮起投影由此出图（1.0.1 同款）。穿底保持——内容穿到整条栏底下被
      // 渐变模糊，同首页路线 B；栏行自带材质表面，不需要让位净空以外的处理。
      bottomBuilder: {
        builder: (): void => { this.messageTabRow(); },
        height: MESSAGE_TAB_ROW_HEIGHT,
      } as BottomBuilderParams,
    };
    const options: HdsNavigationTitleBarOptions = {
      content: content,
      style: style,
      avoidLayoutSafeArea: true,
      // 穿底前提（基准 §7.6.9）：内容区从窗口原点起算，让位由各滚动内容顶部的
      // messageListInset() padding 承担（同 ProfilePage 的 topInset 思路）。
      enableComponentSafeArea: false,
    };
    return options;
  }

  // stackBuilder 顶栏行：「消息」标题 + 「全部已读」（仅通知分段且已登录；原 Index.messageTitleBar 迁入）。
  // 点击递增 markAllSeq 信号，由本组件 @Watch 承接实际标记动作。
  // 「消息」模糊到位后切白（brandOnBlur 同首页品牌行）；「全部已读」同样切白（用户裁定，
  // 品牌色在深色模糊背板上仍嫌沉）。
  // ⚠️ 这颗试过官方 content.menu 文字项，退回自绘是用户裁定：官方件只有
  // backgroundColor / iconColor / textColor 三个槽，**字号与内边距改不掉** —— 实测墨迹比原本高 9%
  // （46px vs 42px）、离右缘多出 17vp 内缩，而这里的观感要求是「与原本完全一致」。
  // 官方件的表面倒是能摘（menuStyle.backgroundColor = Transparent），但 typography 不行就没辙。
  // 结论：文字动作留自绘，官方 content.menu 只用于图标钮。基准 §7.6.28。
  @Builder
  messageBrandRow() {
    Row() {
      Text('消息')
        .fontSize(TypeTokens.titleSerif.size).fontFamily(TypeTokens.fontFamilySerif)
        .fontWeight(TypeTokens.titleSerif.weight)
        .lineHeight(TypeTokens.titleSerif.lineHeight)
        .layoutWeight(1)
        .fontColor(this.brandOnBlur ? Color.White : ColorTokens.primary)
      if (this.markAllVisible()) {
        Pressable({
          visualHeight: LayoutTokens.minTouchTarget,
          touchTargetHeight: LayoutTokens.minTouchTarget,
          action: (): void => {
            // 递增信号 → 本组件 @Watch：标记全部已读仍由本页执行
            this.markAllSeq += 1;
          },
        }) {
          Text('全部已读')
            .fontSize(TypeTokens.callout.size).fontFamily(TypeTokens.fontFamily)
            .fontWeight(TypeTokens.headline.weight)
            .lineHeight(TypeTokens.callout.lineHeight)
            .letterSpacing(TypeTokens.callout.tracking)
            .fontColor(this.brandOnBlur ? Color.White : ColorTokens.brand)
            .height(LayoutTokens.minTouchTarget)
            .padding({ left: SpaceTokens.sm, right: SpaceTokens.sm })
            .textAlign(TextAlign.Center)
            .accessibilityText('全部已读')
        }
      }
    }
    .width('100%')
    // ⚠️ 高度撑满 MINI 标题区（系统定值，同首页品牌块 56 顶格）：标题区高度不可压缩，
    // 行高不足时区域余量会成为标题与分段栏之间的空隙（真机实证「看似未上移」的根因）。
    // 撑满后空隙归零，分段栏视觉上紧贴标题块。
    .height('100%')
    .padding({
      left: SpaceTokens.sm,
      right: SpaceTokens.sm,
      top: SpaceTokens.xs,
      bottom: SpaceTokens.xs,
    })
  }

  // 分段徽标计数：官方 SegmentButton 的 item 只有文本/图标，没有徽标位，红点单独叠一层（见 messageTabRow）
  private tabBadgeCount(index: number): number {
    return index === 1 ? this.dmUnread : this.unreadCount;
  }

  // 刷新指示器（穿底架构）：builder 内容永远参与绘制，显隐必须属性级驱动（opacity，
  // 禁止 if 条件化——指示区高度参与布局，抽空会塌陷，真机实证同 HomeTab/ProfilePage）。
  // 槽位在窗口顶部、整条藏在标题栏底下——offset 只挪绘制，把图形画到栏底之下。
  @Builder
  msgRefreshBuilder(): void {
    Row({ space: SpaceTokens.inline }) {
      LoadingProgress().width(IconTokens.compact).height(IconTokens.compact)
      Text('刷新中…')
        .fontSize(TypeTokens.caption.size).fontFamily(TypeTokens.fontFamily)
        .fontWeight(TypeTokens.caption.weight)
        .lineHeight(TypeTokens.caption.lineHeight)
        .letterSpacing(TypeTokens.caption.tracking)
        .fontColor(ColorTokens.secondary)
    }
    .opacity((this.refreshing || this.refreshIndicatorVisible) ? 1 : 0)
    .hitTestBehavior((this.refreshing || this.refreshIndicatorVisible) ? HitTestMode.Default : HitTestMode.None)
    .offset({ y: this.messageListInset() + SpaceTokens.sm })
    // ↑ messageListInset 已含分段行高：指示器落在分段栏之下的内容区顶部（栏已回标题栏）
  }

  // 分段行（自绘 SegmentedControl，bottomBuilder）：标题栏=材质生效区，挂着的系统材质
  // （浮起档，自带投影）由此出图——1.0.1 同款玻璃面+底部阴影；低版本回退 outlined 描边。
  // 未读徽标叠加层保留（自绘/官方栏都没有徽标位）。
  @Builder
  messageTabRow() {
    Row() {
      Stack() {
        SegmentedControl({
          items: MESSAGE_SEGMENTS,
          selectedIndex: $dmTabIndex,
          itemWidth: 88,
          immersive: !isSystemMaterialActive(),
          outlined: isSystemMaterialActive(),
          glowEnabled: false,
          // 1.0.1 同款：系统材质 + 浮起档（材质自带投影，自绘阴影仅低版本回退）
          useSystemMaterial: true,
          useFloatingMaterial: true,
        })
        // 未读徽标层：分段栏把可用宽度等分，逐槽位叠一个「同字号透明标签 + 系统 Badge」，
        // 红点就落在各自标签右上角（与底部页签红点同一视觉语言，>99 自动 99+）。
        // ⚠️ ForEach 的 key 必须带计数：只写 item.key 时未读数变化不会重建，红点数字会咬死。
        Row() {
          ForEach(
            MESSAGE_SEGMENTS,
            (item: SegmentedItem, index: number) => {
              Column() {
                if (this.tabBadgeCount(index) > 0) {
                  Badge({
                    count: this.tabBadgeCount(index),
                    position: BadgePosition.RightTop,
                    style: { badgeColor: $r('app.color.semantic_red'), color: ColorTokens.onDanger, badgeSize: 14 },
                  }) {
                    Text(item.label)
                      .fontSize(TypeTokens.callout.size).fontFamily(TypeTokens.fontFamily)
                      .opacity(0)
                  }
                }
              }
              .layoutWeight(1)
              .height('100%')
              .justifyContent(FlexAlign.Center)
            },
            (item: SegmentedItem, index: number): string => item.key + '-' + String(this.tabBadgeCount(index))
          )
        }
        .width('100%')
        .height('100%')
        // 徽标层纯装饰，整棵子树都要退出命中树。None 只豁免节点自身、子节点照常参与命中测试
        // （SDK enums.d.ts 口径），层内 Column 会替下面的官方 Button 吃掉点击（真机实测点哪一槽都无响应）；
        // BLOCK_DESCENDANTS(@since 20) 才把自身与全部后代一起摘掉。compatibleSdkVersion 已是 6.0.0(20)。
        .hitTestBehavior(HitTestMode.BLOCK_DESCENDANTS)
      }
      // ⚠️ 必须定高：徽标层是 height('100%')，父容器不定高时它会把 Stack 连带拉满整个
      // 滚动内容（minHeight 100% 链），栏再被 Stack 默认居中顶到内容中部（真机 y1407 巨Gap）。
      .height(LayoutTokens.segmentedHeight)
      // 官方组件不支持通用属性，按压/切换反馈挂在这层容器上：只改透明度，避免高度跳变
      .opacity(this.tabPulse ? 0.96 : 1)
      .animation({
        duration: this.shouldReduceMotion() ? MotionTokens.instant : MotionTokens.control,
        curve: MotionCurves.springSoft,
      })
    }
    .width('100%')
    // 左右 16vp = 参考App 轨道边距实测 50px；上 xs 呼吸位、底 14vp 供自绘软阴影衰减
    .padding({
      left: SpaceTokens.base,
      right: SpaceTokens.base,
      top: SpaceTokens.xs,
      bottom: 14,
    })
  }

  // 快捷筛选行（内容区顶部）：赞和收藏/新增关注/评论。
  // 随通知列表一起滚动（同 pinnedEntries 先例）：上滑跟手滚走、在渐变模糊下自然淡出，
  // 回滚到顶复位——「收起」由滚动本身完成，无触发式动画的割裂感。
  // 横向留白由所在滚动容器的 Column padding 提供（列表态/空态均已带 left/right sm）。
  // 红点计数用服务端 unread-count 的 byType（权威值，未读不在已加载页内也能点亮）；
  // 赞和收藏 = up + bookmark，评论 = comment + mention（@提及并入评论，与过滤视图同口径）。
  //
  // ⚠️ 计数必须在 notificationShortcut 内部按 key 现算，不能作为第二个参数传进来：
  // @Builder 的参数是**值快照**（ArkUI 已知限制，同 docs/dead-code-cleanup.md 记的
  // 「@Builder 值快照不刷新 → 改内联」），外部状态变化不会刷新 Builder 内用到该参数的 UI。
  // 而这里 ForEach 的数据源是常量数组、key 固定为 s.key，条目也永远不会重建，
  // 于是首帧算出的数字被永久冻结——表现就是两个症状：
  // 「筛选图标红点亮着，可列表里没有任何未读条目」/「点了评论、评论红点不消失」。
  // 通知行/会话行不受影响，因为它们的 key 带了 read/unreadCount（见下方 ForEach 注释）。
  @Builder
  messageShortcutsRow() {
    Row({ space: SpaceTokens.none }) {
      ForEach(MESSAGE_SHORTCUTS, (s: MessageShortcut) => {
        this.notificationShortcut(s)
      }, (s: MessageShortcut) => s.key)
    }
    .width('100%')
    .padding({
      top: SpaceTokens.inlineTight,
      bottom: SpaceTokens.item,
    })
  }

  build() {
    // 穿底架构（同首页路线 B）：MINI + stackBuilder 标题行 + bottomBuilder 分段行（材质生效区）
    // + GRADIENT_BLUR + enableComponentSafeArea:false——内容穿到整条栏底下被渐变模糊，
    // 滚动源由 bindToScrollable(activeScrollers) 动态绑定。
    HdsNavigation() {
    Column() {
      // 顶栏（消息 + 全部已读）、分段栏（通知/私信）、三类快捷筛选已整体迁入
      // Navigation 标题栏（uiMaterial 沉浸光感的官方生效区域）；这里只剩内容区。
      if (this.token === '') {
        // 未登录（游客）：不展示任何个人化消息内容，提供手动登录入口（不做自动跳转）
        this.guestState()
      } else {
        // 两个分段做成真正的分页：内容跟手位移、松手按速度吸附，
        // 而不是「划一下、内容瞬间换掉」——后者即使加了淡入也仍然生硬。
        // 分页手势由 Swiper 自带，因此页面不再绑任何横向手势（避免两套手势互相干扰）。
        Swiper() {
          // 页 1：通知。内容整体包一层定高 Column：
          // 内部各态用的是 layoutWeight(1) 撑满，在 Swiper 分页里必须先有确定高度的父容器。
          // （快捷筛选行在列表态/空态的滚动内容首行，随列表滚走；加载/错误为瞬态不渲染该行。）
          Column() {
            if (this.loading && this.list.length === 0) {
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
              .layoutWeight(1)
              .width('100%')
              .justifyContent(FlexAlign.Center)
            } else if (this.error !== '' && this.list.length === 0) {
              // 错误态（重试）
              Column() {
                EmptyState({
                  title: '加载失败',
                  message: this.error,
                  actionLabel: '重试',
                  onAction: (): void => { this.loadFirst(); },
                })
              }
              .layoutWeight(1)
              .width('100%')
              .justifyContent(FlexAlign.Center)
            } else if (this.getFilteredList().length === 0) {
              // 展示侧为空（含：没有该类型通知、或管理员的通知只剩已收敛到
              // 举报中心入口的消息）→ 空态，但常驻入口仍要可点
              Scroll() {
                Column({ space: SpaceTokens.none }) {
                  this.messageShortcutsRow()
                  this.pinnedEntries()
                  Column() {
                    EmptyState({
                      title: '暂无此类通知',
                      message: '新的互动会显示在这里',
                    })
                  }
                  .width('100%')
                  .constraintSize({ minHeight: 320 })
                  .justifyContent(FlexAlign.Center)
                }
                .width('100%')
                .constraintSize({ minHeight: '100%' })
                .padding({
                  left: SpaceTokens.sm,
                  right: SpaceTokens.sm,
                  top: this.messageListInset(),
                  bottom: SpaceTokens.sm,
                })
              }
              .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true })
              .scrollable(ScrollDirection.Vertical)
              .clip(false)
              .width('100%')
              .layoutWeight(1)
            } else {
              Refresh({ refreshing: $$this.refreshing, builder: this.msgRefreshBuilder, offset: 80, friction: 48 }) {
              // 通知列表：Scroll 单列（懒加载 List 会把滚动终点钳制在底部非安全区之上，
              // 露出窗口底色横带截断末行；Scroll 滚动范围天然到物理屏底）。
              // scroller 显式挂载：bindToScrollable 驱动标题栏渐变模糊；Refresh/Scroll 均需关裁切
              Scroll(this.notifScroller) {
              Column({ space: SpaceTokens.none }) {
              // 快捷筛选行：随列表滚动的首个内容（上滑跟手收起，见 messageShortcutsRow 注释）
              this.messageShortcutsRow()
              // 置顶入口（举报中心/系统通知）：位于列表最前，随列表一起滚动（不固定）
              this.pinnedEntries()
              ForEach(
                    this.getFilteredList(),
                    (item: NotificationItem, idx: number) => {
                        Reveal({ index: idx % 5 }) {
                          this.notificationRow(item)
                        }
                    },
                    // key 必须包含已读状态：ArkUI ForEach 复用相同 key 的行时不刷新子组件 @Prop，
                    // 若不带上 read，点击单条已读后红点不会消失（只有重进页面才恢复）。
                    (item: NotificationItem) => String(item.id ?? 0) + (item.read ? '-r' : '-u'),
                  )
                  // 底部预留：为悬浮底栏与系统手势区让出滚动空间
                  Column() {
                    Blank().width('100%').height(barBottomReserve())
                  }
                  .width('100%')
                }
                .width('100%')
                .constraintSize({ minHeight: '100%' })
                .padding({
                  left: SpaceTokens.sm,
                  right: SpaceTokens.sm,
                  top: this.messageListInset(),
                  bottom: SpaceTokens.sm,
                })
              }
              .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true })
              .scrollable(ScrollDirection.Vertical)
              // 不裁剪 + 滚动驱动顶栏切白（通知列表）
              .clip(false)
              .onDidScroll((): void => {
                this.updateBarOnBlur(0);
              })
              .onScrollEdge((edge: Edge) => {
                if (edge === Edge.Bottom) {
                  this.loadMore();
                }
              })
              .width('100%')
              .layoutWeight(1)
              }
              .onRefreshing(() => {
                this.loadFirst().finally(() => {
                  this.refreshing = false;
                });
              })
              .onStateChange((state: RefreshStatus) => {
                // 拉拽/刷新全程显示指示器；空闲与完成回弹隐藏（builder 常驻绘制的门控）
                this.refreshIndicatorVisible = state === RefreshStatus.Drag
                  || state === RefreshStatus.OverDrag || state === RefreshStatus.Refresh;
              })
              .clip(false)
              .layoutWeight(1)
              .width('100%')
            }
          }
          .width('100%')
          .height('100%')

          // 页 2：私信。dmContent 内部各态同样以 layoutWeight(1) 撑满，故同样包定高 Column。
          Column() {
            this.dmContent()
          }
          .width('100%')
          .height('100%')
        }
        .index(this.dmTabIndex)
        .loop(false)              // 到边界不循环：与分段栏两端不可再点一致
        .indicator(false)         // 进度点由分段栏承担
        .duration(this.shouldReduceMotion() ? MotionTokens.instant : MotionTokens.container)
        // 容器的 320ms + 轻微过冲的柔弹簧：整页位移用纯缓动会显干，带一点回稳才有"丝滑"感
        .curve(MotionCurves.springSoft)
        .onChange((index: number): void => {
          hilog.info(0x0000, 'MessagePage', '分段页切换 index=%{public}s', String(index));
          // 只写共享的选中值（同值写入不触发 @Watch），切换动作统一由 @Watch('onDmTabChanged') 承接；
          // 分段栏是官方 SegmentButton，选中面由它自己的状态动画完成，这里不再驱动任何滑块位。
          this.dmTabIndex = index;
        })
        .layoutWeight(1)          // 标题栏之外的剩余高度全部给分页区
        .width('100%')
        // 不裁剪：列表内容穿出 Swiper 顶边画到 HDS 标题栏下方（模糊采样素材）
        .clip(false)
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(ColorTokens.canvas)
    }
    .titleBar(this.messageHdsTitleBarOptions())
    .titleMode(HdsNavigationTitleMode.MINI)
    .hideBackButton(true)
    // 动态绑定当前分段的 Scroller（切分段重估模糊，见 activeScrollers 注释）
    .bindToScrollable(this.activeScrollers())
    .clip(false)
    .width('100%')
    .height('100%')
    .backgroundColor(ColorTokens.canvas)
    .transition(buildPageTransition())
  }
}
