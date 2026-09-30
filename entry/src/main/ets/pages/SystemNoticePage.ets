// 系统通知页：三类互动视图（赞和收藏/新增关注/评论）之外的 system 消息收纳处 ——
// 审核结果（已通过/未通过审核）、举报回执（因被举报正在审核中 / 你的举报已处理）等。
//
// 约定：
// - 进入即把本页可见的系统通知全部标记已读（红点即时回落，底部 Tab 未读数以服务端为准校正）；
//   消息本身不删除，「已读」只影响红点。
// - 点单条：带 postId 的通知跳原帖详情（审核结果类通知指向被处理的内容）。
// - 管理员的「举报中心」置顶消息归口消息页的举报中心入口，不在本页重复展示（其已读由入口清）。
// - 标读完成即自增 systemNoticeRefreshSignal：消息页监听后重拉列表，入口红点/预览即时刷新
//   （放在标读完成处而不是 aboutToDisappear：用户读得快、未等服务端标完就返回时，
//   信号也会在标读真正落库后才发出，重拉拿到的不会是旧的未读状态）。
import { NotificationItem } from '../models/types';
import { listNotifications, markNotificationRead, getUnreadCount } from '../services/api';
import { getToken, getIsAdmin } from '../utils/auth';
import { openPostDetail } from '../utils/nav';
import { timeAgo } from '../utils/format';
import { notifIconRes } from '../utils/actionIcons';
import { buildPageTransition } from '../utils/styles';
import { barBottomReserve, bottomNavInset } from '../utils/cardTokens';
import { BackButton } from '../design/components/BackButton';
import { EmptyState } from '../design/components/EmptyState';
import { MessageRow } from '../design/components/MessageRow';
import { Reveal } from '../design/motion/Reveal';
import { ColorTokens } from '../design/tokens/color';
import { IconTokens } from '../design/tokens/icon';
import { LayoutTokens, SpaceTokens } from '../design/tokens/space';
import { TypeTokens } from '../design/tokens/type';

// 单页取满上限（系统通知量级很小；limit 服务端上限 50）
const PAGE_SIZE: number = 50;

@Entry
@Component
export struct SystemNoticePage {
  @State list: NotificationItem[] = [];
  @State loading: boolean = true;
  @State error: string = '';
  @State refreshing: boolean = false;
  @StorageLink('statusBarHeight') statusBarHeight: number = 0;

  // 「举报中心」置顶消息：管理员视角归口消息页的举报中心入口（与 MessagePage 同口径）
  private isReportCenterItem(item: NotificationItem): boolean {
    if (item.pinned !== true) {
      return false;
    }
    const content: string = item.content ?? '';
    return content.startsWith('举报中心') || content.includes('收到新举报');
  }

  private isVisibleNotice(item: NotificationItem): boolean {
    if (item.type !== 'system') {
      return false;
    }
    return !(getIsAdmin() && this.isReportCenterItem(item));
  }

  aboutToAppear(): void {
    // 入口只在登录态下可见；此处兜底未登录直入（如深链）时退回，不发请求
    if (getToken() === '') {
      this.getUIContext().getRouter().back();
      return;
    }
    this.load();
  }

  async load(): Promise<void> {
    this.loading = true;
    this.error = '';
    try {
      const res = await listNotifications(1, PAGE_SIZE, 'system');
      this.list = res.list.filter((it: NotificationItem): boolean => this.isVisibleNotice(it));
      this.loading = false;
      this.markAllRead();
    } catch (e) {
      this.error = (e as Error).message || '加载失败';
      this.loading = false;
    }
  }

  // 进页即标读：先就地置读（界面立即无红点），再逐条同步后端；
  // 最后拉一次权威未读数写回 AppStorage（底部 Tab 红点与其他页面共享同一计数）。
  private async markAllRead(): Promise<void> {
    const unreadIds: number[] = [];
    const next: NotificationItem[] = [];
    for (const it of this.list) {
      if (it.read !== true && it.id !== undefined) {
        unreadIds.push(it.id);
        next.push({
          id: it.id,
          type: it.type,
          actor: it.actor,
          postId: it.postId,
          content: it.content,
          read: true,
          pinned: it.pinned ?? false,
          createdAt: it.createdAt,
        });
      } else {
        next.push(it);
      }
    }
    if (unreadIds.length === 0) {
      return;
    }
    this.list = next;
    for (const id of unreadIds) {
      try {
        await markNotificationRead(id);
      } catch (e) {
        // 忽略：下次进页重试（已读失败不影响阅读）
      }
    }
    try {
      const res = await getUnreadCount();
      AppStorage.setOrCreate('unreadMessageCount', res.count);
    } catch (e) {
      // 忽略：红点计数刷新失败不阻断本页
    }
    // 标读已全部落库：广播给消息页重拉列表（入口红点/预览即时回落）
    const cur: number = (AppStorage.get<number>('systemNoticeRefreshSignal') ?? 0) as number;
    AppStorage.setOrCreate('systemNoticeRefreshSignal', cur + 1);
  }

  // 点单条：带 postId（审核结果类）跳原帖详情；纯回执（如「你的举报已处理」带 postId 时同样可跳）
  private onRowClick(item: NotificationItem): void {
    if (item.postId !== undefined && item.postId !== null) {
      openPostDetail(String(item.postId));
      this.getUIContext().getRouter().pushUrl({ url: 'pages/DetailPage' });
    }
  }

  @Builder
  topBar(): void {
    Row() {
      BackButton({ action: (): void => { this.getUIContext().getRouter().back(); } })
      Blank()
      Text('系统通知')
        .fontSize(TypeTokens.title.size)
        .fontFamily(TypeTokens.fontFamilySerif)
        .fontWeight(TypeTokens.title.weight)
        .lineHeight(TypeTokens.title.lineHeight)
        .fontColor(ColorTokens.primary)
      Blank()
      Row() {
        if (this.refreshing) {
          LoadingProgress().width(IconTokens.small).height(IconTokens.small)
        } else {
          Text('刷新')
            .fontSize(TypeTokens.callout.size)
            .fontFamily(TypeTokens.fontFamily)
            .fontColor(ColorTokens.brand)
        }
      }
      .width(LayoutTokens.minTouchTarget)
      .height(LayoutTokens.minTouchTarget)
      .justifyContent(FlexAlign.Center)
      .alignItems(VerticalAlign.Center)
      .onClick((): void => { this.refresh(); })
    }
    .width('100%')
    .alignItems(VerticalAlign.Center)
    .padding({ left: SpaceTokens.pageCompact, right: SpaceTokens.pageCompact, top: SpaceTokens.sm, bottom: SpaceTokens.sm })
  }

  private refresh(): void {
    if (this.refreshing) {
      return;
    }
    this.refreshing = true;
    this.load().finally((): void => {
      this.refreshing = false;
    });
  }

  @Builder
  noticeRow(item: NotificationItem) {
    MessageRow({
      title: item.content ?? '',
      subtitle: timeAgo(item.createdAt),
      useIcon: true,
      icon: notifIconRes('system'),
      unread: item.read !== true,
      titleMaxLines: 2,
      subtitleMaxLines: 1,
      action: (): void => {
        this.onRowClick(item);
      },
    })
  }

  @Builder
  stateArea(): void {
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
      .width('100%')
      .padding({ top: SpaceTokens.x3l, bottom: SpaceTokens.x3l })
      .justifyContent(FlexAlign.Center)
    } else if (this.error !== '' && this.list.length === 0) {
      EmptyState({
        title: '加载失败',
        message: this.error,
        actionLabel: '重试',
        onAction: (): void => { this.load(); },
      })
    } else if (this.list.length === 0) {
      EmptyState({
        title: '暂无系统通知',
        message: '审核结果与举报处理进度会显示在这里',
      })
    } else {
      Column({ space: SpaceTokens.none }) {
        ForEach(
          this.list,
          (item: NotificationItem, idx: number) => {
            Reveal({ index: idx % 5 }) {
              this.noticeRow(item)
            }
          },
          // key 必须包含已读状态：ForEach 复用相同 key 的行时不刷新子组件 @Prop，
          // 否则进页标读后未读圆点不会消失（与消息页通知列表同一坑）。
          (item: NotificationItem) => String(item.id ?? 0) + (item.read ? '-r' : '-u'),
        )
        // 底部预留：为系统手势区让出滚动空间（本页无悬浮底栏）
        Column() {
          Blank().width('100%').height(barBottomReserve())
        }
        .width('100%')
      }
      .width('100%')
      .constraintSize({ minHeight: '100%' })
    }
  }

  build() {
    Column() {
      this.topBar()

      // 三态与列表统一包在 Refresh + Scroll 里：空态 / 错误态也能下拉刷新。
      // 全屏沉浸壳内列表一律用 Scroll（List 的滚动终点会被底部非安全区钳制）。
      Refresh({ refreshing: $$this.refreshing, offset: 80, friction: 48 }) {
        Scroll() {
          Column() {
            this.stateArea()
          }
          .width('100%')
          .constraintSize({ minHeight: '100%' })
          .justifyContent(this.loading || this.list.length === 0 ? FlexAlign.Center : FlexAlign.Start)
          .padding({
            left: SpaceTokens.sm,
            right: SpaceTokens.sm,
            bottom: SpaceTokens.x2l,
          })
        }
        .layoutWeight(1)
        .width('100%')
        .scrollBar(BarState.Off)
      }
      .onRefreshing((): void => { this.refresh(); })
      .layoutWeight(1)
      .width('100%')
    }
    .width('100%')
    .height('100%')
    .padding({ top: this.statusBarHeight, bottom: bottomNavInset() })
    .backgroundColor(ColorTokens.canvas)
    .transition(buildPageTransition())
  }
}