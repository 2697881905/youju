// 消息通知中心（真实数据：后端 /v1/notifications）
// - 列表渲染（下拉刷新 / 触底加载更多 / 未读圆点 / 点击已读并跳详情）
// - 空态 / 错误态（重试）
// - 顶部「全部已读」
// - 回写 AppStorage['unreadMessageCount'] 供 Index 消息 Tab 红点
import { router } from '@kit.ArkUI';
import { NotificationItem, NotificationType } from '../models/types';
import {
  listNotifications,
  getUnreadCount,
  markNotificationRead,
  markAllRead,
} from '../services/api';
import { getToken } from '../utils/auth';
import { safeShowToast } from '../utils/toast';

// 通知类型 → 图标
const TYPE_ICON: Record<NotificationType, string> = {
  comment: '💬',
  up: '👍',
  bookmark: '🔖',
  follow: '➕',
  system: '📢',
};

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

  aboutToAppear(): void {
    // 已有登录态则直接加载；否则等 onTokenReady 在 token 就绪后补加载
    if (getToken() !== '') {
      this.loadFirst();
    }
  }

  // token 由空变为非空（登录完成）→ 列表为空才拉取，避免重复加载
  onTokenReady(): void {
    if (this.token !== '' && this.list.length === 0 && this.error === '') {
      this.loadFirst();
    }
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

  // 点击单条：标记已读 → 本地更新（重赋值数组触发刷新）→ 有 postId 则跳详情
  async onItemClick(item: NotificationItem): Promise<void> {
    if (item.read !== true && item.id !== undefined) {
      const id: number = item.id;
      try {
        await markNotificationRead(id);
      } catch (e) {
        // 标记失败不影响跳转
      }
      // 重赋值数组，确保 @State 触发 UI 刷新
      const next: NotificationItem[] = this.list.slice();
      for (let i = 0; i < next.length; i++) {
        if (next[i].id === id) {
          next[i] = { ...next[i], read: true };
          break;
        }
      }
      this.list = next;
      if (this.unreadCount > 0) {
        this.unreadCount = this.unreadCount - 1;
      }
    }
    if (item.postId !== undefined && item.postId !== null) {
      AppStorage.setOrCreate('detailPostId', String(item.postId));
      router.pushUrl({ url: 'pages/DetailPage' });
    }
  }

  // 全部已读
  async onMarkAll(): Promise<void> {
    try {
      await markAllRead();
      // 重赋值数组，确保 @State 触发 UI 刷新
      this.list = this.list.map((it: NotificationItem) => ({ ...it, read: true }));
      this.unreadCount = 0;
      safeShowToast(this.getUIContext(), { message: '已全部标记为已读' });
    } catch (e) {
      safeShowToast(this.getUIContext(), { message: '操作失败，请重试' });
    }
  }

  @Builder
  notificationRow(item: NotificationItem) {
    Row({ space: 12 }) {
      // 头像（无 URL 时用昵称首字兜底）
      if (item.actor && item.actor.avatar) {
        Image(item.actor.avatar)
          .width(40)
          .height(40)
          .borderRadius(20)
          .objectFit(ImageFit.Cover)
      } else {
        Circle({ width: 40, height: 40 })
          .fill($r('app.color.brand_primary'))
          .opacity(0.15)
        Text(item.actor && item.actor.nickname ? item.actor.nickname.slice(0, 1) : TYPE_ICON[item.type ?? 'system'])
          .fontSize(16)
          .fontColor($r('app.color.brand_primary'))
          .position({ x: 12, y: 10 })
      }

      // 文案 + 时间
      Column({ space: 4 }) {
        Text(item.content ?? '')
          .fontSize(14)
          .fontColor($r('app.color.text_primary'))
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        Text(this.formatTime(item.createdAt))
          .fontSize(12)
          .fontColor($r('app.color.text_secondary'))
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)

      // 未读红点
      if (item.read !== true) {
        Circle({ width: 8, height: 8 })
          .fill('#FF453A')
      }
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 12, bottom: 12 })
    .backgroundColor($r('app.color.card_bg'))
    .onClick(() => {
      this.onItemClick(item);
    })
  }

  build() {
    Column() {
      // 顶栏
      Row() {
        Text('消息')
          .fontSize(17)
          .fontWeight(600)
          .layoutWeight(1)
          .textAlign(TextAlign.Center)
        Text('全部已读')
          .fontSize(13)
          .fontColor($r('app.color.brand_primary'))
          .padding({ right: 16 })
          .onClick(() => {
            this.onMarkAll();
          })
      }
      .width('100%')
      .padding({ top: 12, bottom: 12 })

      if (this.loading && this.list.length === 0) {
        Column() {
          Text('加载中…')
            .fontSize(14)
            .fontColor($r('app.color.text_secondary'))
        }
        .layoutWeight(1)
        .width('100%')
        .justifyContent(FlexAlign.Center)
      } else if (this.error !== '' && this.list.length === 0) {
        // 错误态（重试）
        Column({ space: 12 }) {
          Text(this.error)
            .fontSize(14)
            .fontColor($r('app.color.text_secondary'))
            .textAlign(TextAlign.Center)
          Text('点击重试')
            .fontSize(14)
            .fontColor($r('app.color.brand_primary'))
            .onClick(() => {
              this.loadFirst();
            })
        }
        .layoutWeight(1)
        .width('100%')
        .justifyContent(FlexAlign.Center)
      } else if (this.list.length === 0) {
        // 空态
        Column() {
          Text('暂无新消息')
            .fontSize(14)
            .fontColor($r('app.color.text_secondary'))
        }
        .layoutWeight(1)
        .width('100%')
        .justifyContent(FlexAlign.Center)
      } else {
        Refresh({ refreshing: $$this.refreshing, offset: 80, friction: 48 }) {
          List({ space: 8 }) {
            ForEach(
              this.list,
              (item: NotificationItem) => {
                ListItem() {
                  this.notificationRow(item)
                }
              },
              (item: NotificationItem) => String(item.id ?? 0),
            )
          }
          .width('100%')
          .layoutWeight(1)
          .onReachEnd(() => {
            this.loadMore();
          })
        }
        .onRefresh(() => {
          this.loadFirst().finally(() => {
            this.refreshing = false;
          });
        })
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.bg_primary'))
  }
}
