// 消息通知中心（真实数据：后端 /v1/notifications）
// - 列表渲染（下拉刷新 / 触底加载更多 / 未读圆点 / 点击已读并跳详情）
// - 空态 / 错误态（重试）
// - 顶部「全部已读」
// - 回写 AppStorage['unreadMessageCount'] 供 Index 消息 Tab 红点

import { NotificationItem, NotificationType, Conversation } from '../models/types';
import { openChat, openPostDetail, openUserProfile } from '../utils/nav';
import {
  listNotifications,
  getUnreadCount,
  markNotificationRead,
  markAllRead,
  getConversations,
  getDmUnreadCount,
} from '../services/api';
import { getToken, getUserId, getCurrentUser } from '../utils/auth';
import { barBottomReserve } from '../utils/cardTokens';
import { safeShowToast } from '../utils/toast';
import { buildPageTransition } from '../utils/styles';
import { notifIconRes, resolveActionIcon } from '../utils/actionIcons';
import { EmptyState } from '../design/components/EmptyState';
import { MessageRow } from '../design/components/MessageRow';
import { SegmentedControl, SegmentedItem } from '../design/components/SegmentedControl';
import { Pressable } from '../design/motion/Pressable';
import { Reveal } from '../design/motion/Reveal';
import { ColorTokens } from '../design/tokens/color';
import { IconTokens } from '../design/tokens/icon';
import { RadiusTokens } from '../design/tokens/radius';
import { LayoutTokens, SpaceTokens } from '../design/tokens/space';
import { MotionCurves, MotionTokens } from '../design/tokens/motion';
import { TypeTokens } from '../design/tokens/type';

const MESSAGE_SEGMENTS: SegmentedItem[] = [
  { key: 'notif', label: '通知' },
  { key: 'dm', label: '私信' },
];

@Entry
@Component
export struct MessagePage {
  @State list: NotificationItem[] = [];
  @State loading: boolean = true;
  @State error: string = '';
  @State page: number = 1;
  @State hasMore: boolean = true;
  @State refreshing: boolean = false;
  // 与 Index 共享的红点计数（@StorageLink 双向，写回即同步红点）
  @StorageLink('unreadMessageCount') unreadCount: number = 0;
  // 监听登录态：LoginPage 自动登录后 authToken 就绪，此页才加载（aboutToAppear 可能在登录前已跑过）
  @StorageLink('authToken') @Watch('onTokenReady') token: string = '';
  @State activeFilter: string = 'all'; // 'all' | 'up_bookmark' | 'follow' | 'comment'
  // ===== 私信 =====
  @State dmTab: string = 'notif'; // 'notif' | 'dm'
  @State dmTabIndex: number = 0;
  @State tabPulse: boolean = false;
  @State conversations: Conversation[] = [];
  @State dmLoading: boolean = true;
  @State dmError: string = '';
  // 私信未读（与通知红点分开存储，Index 合并显示）
  @StorageLink('unreadDmCount') dmUnread: number = 0;
  // 聊天页发送/已读后自增，触发本页刷新会话列表与未读
  @StorageLink('dmRefreshSignal') @Watch('onDmRefreshSignal') dmRefreshSignal: number = 0;
  // 订阅登录账号：切换账号（如老张↔小美互测）时重拉通知与私信，
  // 否则 TabContent 内组件被保留，残留上一个账号的通知/会话与红点。
  @StorageLink('authUserId') @Watch('onUserChange') uid: string = '';
  @StorageLink('reduceMotion') reduceMotion: boolean = false;
  @StorageLink('systemReduceMotion') systemReduceMotion: boolean = false;
  private tabPulseTimer: number = 0;

  // 根据当前筛选条件过滤列表（方法调用，避免 ArkTS getter 在 build() 中不稳定）
  private getFilteredList(): NotificationItem[] {
    const list: NotificationItem[] = this.list;
    if (!list) {
      return [];
    }
    if (this.activeFilter === 'all') {
      return list;
    }
    return list.filter((item: NotificationItem) => {
      if (this.activeFilter === 'up_bookmark') {
        return item.type === 'up' || item.type === 'bookmark';
      }
      if (this.activeFilter === 'follow') {
        return item.type === 'follow';
      }
      if (this.activeFilter === 'comment') {
        return item.type === 'comment';
      }
      return true;
    });
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

  // token 由空变为非空（登录完成）→ 列表为空才拉取，避免重复加载
  onTokenReady(): void {
    if (this.token !== '' && this.list.length === 0 && this.error === '') {
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

  // 切换登录账号（登出/切换虚拟账号）→ 立即重拉通知与私信，
  // 避免 TabContent 内组件被保留导致消息页残留上一个账号的内容与红点。
  onUserChange(): void {
    const u = getCurrentUser();
    if (!u || !u.id) {
      return; // 登出态不拉取
    }
    if (this.token !== '') {
      this.loadFirst();
      this.loadConversations();
      this.loadDmUnread();
    }
  }

  // 按通知类型统计未读数（仅统计已加载列表中的未读项），用于各分区红点
  private unreadCountOf(types: NotificationType[]): number {
    let n: number = 0;
    for (const it of this.list) {
      if (!it.read && types.indexOf(it.type as NotificationType) >= 0) {
        n++;
      }
    }
    return n;
  }

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

  async loadFirst(): Promise<void> {
    this.loading = true;
    this.error = '';
    this.page = 1;
    this.hasMore = true;
    await this.refreshUnread();
    await this.loadDmUnread();
    try {
      const res = await listNotifications(1, 20);
      this.list = res.list;
      this.hasMore = res.pagination.total > res.list.length;
      this.loading = false;
    } catch (e) {
      this.error = (e as Error).message || '加载失败';
      this.loading = false;
    }
  }

  async loadMore(): Promise<void> {
    if (!this.hasMore || this.loading) {
      return;
    }
    this.loading = true;
    try {
      const next: number = this.page + 1;
      const res = await listNotifications(next, 20);
      if (res.list.length > 0) {
        this.list = this.list.concat(res.list);
        this.page = next;
        this.hasMore = res.pagination.total > this.list.length;
      } else {
        this.hasMore = false;
      }
      this.loading = false;
    } catch (e) {
      this.loading = false;
    }
  }

  async refreshUnread(): Promise<void> {
    try {
      const res = await getUnreadCount();
      this.unreadCount = res.count;
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

  // 点击会话 → 进入聊天页，peer 信息经短暂导航意图传递。
  onConversationClick(c: Conversation): void {
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

  // 点击单条：本地乐观标记已读（立即驱动红点消失）→ 后台同步后端 → 按类型跳转
  async onItemClick(item: NotificationItem): Promise<void> {
    if (item.read !== true && item.id !== undefined) {
      const id: number = item.id;
      // 先乐观更新本地（list + unreadMessageCount），立即隐藏红点，避免等待网络；
      // 否则网络慢时红点迟迟不消失，切花 Tab 重建后才看到。
      const next: NotificationItem[] = this.list.slice();
      for (let i = 0; i < next.length; i++) {
        if (next[i].id === id) {
          const cur: NotificationItem = next[i];
          next[i] = {
            id: cur.id,
            type: cur.type,
            actor: cur.actor,
            postId: cur.postId,
            content: cur.content,
            read: true,
            createdAt: cur.createdAt,
          };
          break;
        }
      }
      this.list = next;
      if (this.unreadCount > 0) {
        this.unreadCount = this.unreadCount - 1;
      }
      // 标记失败不影响已删除的红点与跳转
      try {
        await markNotificationRead(id);
      } catch (e) {
        // 忽略：下次进入消息页拉取会以服务器为准
      }
      // 用后端权威未读数校正（本地乐观可能与服务器有偏差）
      this.refreshUnread();
    }
    // 点击单条跳转：新增关注 → 该用户（actor）主页；带 postId 的通知（赞/收藏/评论）→ 原帖详情
    if (item.type === 'follow' && item.actor !== undefined && item.actor !== null && item.actor.id) {
      openUserProfile(item.actor.id);
      this.getUIContext().getRouter().pushUrl({ url: 'pages/UserProfilePage' });
      return;
    }
    if (item.postId !== undefined && item.postId !== null) {
      openPostDetail(String(item.postId));
      this.getUIContext().getRouter().pushUrl({ url: 'pages/DetailPage' });
    }
  }

  // 全部已读
  async onMarkAll(): Promise<void> {
    try {
      await markAllRead();
      // 重赋值数组（逐字段构造新对象，规避对象展开 {...x}），确保 @State 触发 UI 刷新
      const allRead: NotificationItem[] = this.list.slice();
      for (let i = 0; i < allRead.length; i++) {
        const cur: NotificationItem = allRead[i];
        allRead[i] = {
          id: cur.id,
          type: cur.type,
          actor: cur.actor,
          postId: cur.postId,
          content: cur.content,
          read: true,
          createdAt: cur.createdAt,
        };
      }
      this.list = allRead;
      this.unreadCount = 0;
      safeShowToast(this.getUIContext(), { message: '已全部标记为已读' });
    } catch (e) {
      safeShowToast(this.getUIContext(), { message: '操作失败，请重试' });
    }
  }

  // 通知类型 → 图标资源（ArkTS V1 不支持 obj[key] 索引访问，用函数分发）
  private typeIcon(type: NotificationType | undefined): Resource {
    return notifIconRes(type);
  }

  private switchDmTab(index: number): void {
    const tab: string = index === 1 ? 'dm' : 'notif';
    this.dmTabIndex = index;
    if (this.dmTab !== tab) {
      this.dmTab = tab;
      this.playTabFeedback();
      if (tab === 'dm') {
        this.loadConversations();
      }
    }
  }

  @Builder
  notificationShortcut(filter: string, label: string, icon: Resource, unread: number, iconColor: ResourceColor) {
    Column() {
      Pressable({
        visualHeight: 34 + TypeTokens.callout.lineHeight + SpaceTokens.inline,
        touchTargetHeight: LayoutTokens.minTouchTarget,
        fillWidth: true,
        action: (): void => {
          this.activeFilter = this.activeFilter === filter ? 'all' : filter;
        },
      }) {
        Column({ space: SpaceTokens.inline }) {
          Badge({
            count: unread,
            position: BadgePosition.RightTop,
            style: { badgeColor: ColorTokens.danger },
          }) {
            Image(icon)
              .width(34)
              .height(34)
              .fillColor(iconColor)
              .objectFit(ImageFit.Contain)
          }
          Text(label)
            .fontSize(TypeTokens.overline.size).fontFamily(TypeTokens.fontFamily)
            .fontWeight(this.activeFilter === filter ? TypeTokens.headline.weight : TypeTokens.overline.weight)
            .lineHeight(TypeTokens.overline.lineHeight)
            .letterSpacing(TypeTokens.overline.tracking)
            .fontColor(this.activeFilter === filter ? ColorTokens.brand : ColorTokens.secondary)
            .maxLines(1)
        }
        .width('100%')
        .alignItems(HorizontalAlign.Center)
        .padding({ top: SpaceTokens.xs, bottom: SpaceTokens.xs })
        .backgroundColor(this.activeFilter === filter ? ColorTokens.brandTint : Color.Transparent)
        .borderRadius(RadiusTokens.md)
        .scale({ x: this.activeFilter === filter && !this.shouldReduceMotion() ? 1.03 : 1, y: this.activeFilter === filter && !this.shouldReduceMotion() ? 1.03 : 1 })
        .animation({ duration: this.shouldReduceMotion() ? MotionTokens.instant : MotionTokens.control, curve: MotionCurves.springSoft })
      }
    }
    .layoutWeight(1)
  }

  // 私信会话列表内容
  @Builder
  dmContent() {
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
      Refresh({ refreshing: $$this.refreshing, offset: 80, friction: 48 }) {
        List({ space: SpaceTokens.none }) {
          ForEach(
            this.conversations,
            (c: Conversation, idx: number) => {
              ListItem() {
                Reveal({ index: idx % 5 }) {
                  this.conversationRow(c)
                }
              }
            },
            (c: Conversation) => String(c.peer.id),
          )
          // 真实列表项会计入滚动范围，避免 Refresh + List 的 padding 被裁掉。
          ListItem() {
            Column() {
              Blank().width('100%').height(barBottomReserve())
            }
            .width('100%')
          }
        }
        .width('100%')
        .layoutWeight(1)
        .padding({
          left: SpaceTokens.pageCompact,
          right: SpaceTokens.pageCompact,
          bottom: SpaceTokens.sm,
        })
      }
      .onRefreshing(() => {
        this.loadConversations().finally(() => {
          this.refreshing = false;
        });
      })
      .layoutWeight(1)
      .width('100%')
    }
  }

  @Builder
  notificationRow(item: NotificationItem) {
    MessageRow({
      title: item.content ?? '',
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

  build() {
    Column() {
      // 顶栏
      Row() {
        Text('消息')
          .fontSize(TypeTokens.title.size).fontFamily(TypeTokens.fontFamilySerif)
          .fontWeight(TypeTokens.title.weight)
          .lineHeight(TypeTokens.title.lineHeight)
          .letterSpacing(TypeTokens.title.tracking)
          .layoutWeight(1)
          .fontColor(ColorTokens.primary)
        if (this.dmTab === 'notif') {
          Pressable({
            visualHeight: LayoutTokens.minTouchTarget,
            touchTargetHeight: LayoutTokens.minTouchTarget,
            action: (): void => {
              this.onMarkAll();
            },
          }) {
            Text('全部已读')
              .fontSize(TypeTokens.callout.size).fontFamily(TypeTokens.fontFamily)
              .fontWeight(TypeTokens.headline.weight)
              .lineHeight(TypeTokens.callout.lineHeight)
              .letterSpacing(TypeTokens.callout.tracking)
              .fontColor(Color.Black)
              .height(LayoutTokens.minTouchTarget)
              .padding({ left: SpaceTokens.sm, right: SpaceTokens.sm })
              .textAlign(TextAlign.Center)
              .accessibilityText('全部已读')
          }
        }
      }
      .width('100%')
      .padding({
        left: SpaceTokens.pageCompact,
        right: SpaceTokens.pageCompact,
        top: SpaceTokens.md,
        bottom: SpaceTokens.sm,
      })

      // 分段：通知 | 私信
      SegmentedControl({
        items: MESSAGE_SEGMENTS,
        selectedIndex: $dmTabIndex,
        itemWidth: 88,
        glass: true,
        onSelect: (idx: number): void => { this.switchDmTab(idx); },
      })
      .margin({ left: SpaceTokens.pageCompact, right: SpaceTokens.pageCompact, bottom: SpaceTokens.sm })
      // 分段控件保持固定尺寸；切换反馈只改变透明度，避免 Tab 状态切换时高度跳变。
      .opacity(this.tabPulse ? 0.96 : 1)
      .animation({ duration: this.shouldReduceMotion() ? MotionTokens.instant : MotionTokens.control, curve: MotionCurves.springSoft })

      if (this.dmTab === 'notif') {
        // 快捷入口：三类通知共用可选中图标块。
        Row({ space: SpaceTokens.none }) {
          this.notificationShortcut('up_bookmark', '赞和收藏', resolveActionIcon('like'), this.unreadCountOf(['up', 'bookmark']), '#FF2D55')
          this.notificationShortcut('follow', '新增关注', resolveActionIcon('follow'), this.unreadCountOf(['follow']), '#34C759')
          this.notificationShortcut('comment', '评论', resolveActionIcon('comment'), this.unreadCountOf(['comment']), '#0A84FF')
        }
        .width('100%')
        .padding({
          left: SpaceTokens.pageCompact,
          right: SpaceTokens.pageCompact,
          top: SpaceTokens.inlineTight,
          bottom: SpaceTokens.item,
        })

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
        } else if (this.list.length === 0) {
          Column() {
            EmptyState({
              title: this.activeFilter === 'all' ? '暂无新消息' : '暂无此类通知',
              message: '新的互动会显示在这里',
            })
          }
          .layoutWeight(1)
          .width('100%')
          .justifyContent(FlexAlign.Center)
        } else {
          Refresh({ refreshing: $$this.refreshing, offset: 80, friction: 48 }) {
          List({ space: SpaceTokens.none }) {
          ForEach(
                this.getFilteredList(),
                (item: NotificationItem, idx: number) => {
                  ListItem() {
                    Reveal({ index: idx % 5 }) {
                      this.notificationRow(item)
                    }
                  }
                },
                // key 必须包含已读状态：ArkUI ForEach 复用相同 key 的行时不刷新子组件 @Prop，
                // 若不带上 read，点击单条已读后红点不会消失（只有重进页面才恢复）。
                (item: NotificationItem) => String(item.id ?? 0) + (item.read ? '-r' : '-u'),
              )
              // 真实列表项会计入滚动范围，避免最后一条通知被毛玻璃底栏遮住。
              ListItem() {
                Column() {
                  Blank().width('100%').height(barBottomReserve())
                }
                .width('100%')
              }
            }
            .width('100%')
            .layoutWeight(1)
            .padding({
              left: SpaceTokens.pageCompact,
              right: SpaceTokens.pageCompact,
              bottom: SpaceTokens.sm,
            })
            .onReachEnd(() => {
              this.loadMore();
            })
          }
          .onRefreshing(() => {
            this.loadFirst().finally(() => {
              this.refreshing = false;
            });
          })
          .layoutWeight(1)
          .width('100%')
        }
      } else {
        this.dmContent()
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(ColorTokens.canvas)
    .transition(buildPageTransition())
  }
}
