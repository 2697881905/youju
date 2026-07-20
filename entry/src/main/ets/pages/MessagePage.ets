// 消息通知中心（真实数据：后端 /v1/notifications）
// - 列表渲染（下拉刷新 / 触底加载更多 / 未读圆点 / 点击已读并跳详情）
// - 空态 / 错误态（重试）
// - 顶部「全部已读」
// - 回写 AppStorage['unreadMessageCount'] 供 Index 消息 Tab 红点

import { NotificationItem, NotificationType } from '../models/types';
import {
  listNotifications,
  getUnreadCount,
  markNotificationRead,
  markAllRead,
} from '../services/api';
import { getToken } from '../utils/auth';
import { safeShowToast } from '../utils/toast';
import { buildPageTransition } from '../utils/styles';

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

  // 根据当前筛选条件过滤列表
  private get displayList(): NotificationItem[] {
    if (this.activeFilter === 'all') {
      return this.list;
    }
    return this.list.filter((item: NotificationItem) => {
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
      // 重赋值数组（逐字段构造新对象，规避 ArkTS V1 禁用的对象展开 {...x}），确保 @State 触发 UI 刷新
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
    }
    if (item.postId !== undefined && item.postId !== null) {
      AppStorage.setOrCreate('detailPostId', String(item.postId));
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

  // 通知类型 → 图标（ArkTS V1 不支持 obj[key] 索引访问，用函数分发）
  private typeIcon(type: NotificationType | undefined): string {
    const t: NotificationType = type ?? 'system';
    if (t === 'comment') {
      return '💬';
    }
    if (t === 'up') {
      return '👍';
    }
    if (t === 'bookmark') {
      return '🔖';
    }
    if (t === 'follow') {
      return '➕';
    }
    return '📢';
  }

  @Builder
  notificationRow(item: NotificationItem) {
    Row({ space: 12 }) {
      // 头像区域：系统通知用品牌色圆+图标，普通通知用用户头像或昵称首字
      if (item.type === 'system') {
        // 系统通知：品牌色背景圆 + 系统图标
        Circle({ width: 40, height: 40 })
          .fill($r('app.color.brand_primary'))
        Text('📢')
          .fontSize(18)
          .fontColor(Color.White)
          .position({ x: 10, y: 9 })
      } else if (item.actor && item.actor.avatar) {
        // 普通通知：用户头像
        Image(item.actor.avatar)
          .width(40)
          .height(40)
          .borderRadius(20)
          .objectFit(ImageFit.Cover)
      } else {
        // 普通通知：昵称首字兜底
        Circle({ width: 40, height: 40 })
          .fill($r('app.color.brand_primary'))
          .opacity(0.15)
        Text(item.actor && item.actor.nickname ? item.actor.nickname.slice(0, 1) : this.typeIcon(item.type))
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
          .fill($r('app.color.semantic_red'))
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

      // 快捷入口：三大类通知大图标
      Row({ space: 0 }) {
        Column({ space: 6 }) {
          Column() {
            Text('👍')
              .fontSize(28)
          }
          .width(56)
          .height(56)
          .borderRadius(16)
          .backgroundColor($r('app.color.glass_border'))
          .justifyContent(FlexAlign.Center)
          Text('赞和收藏')
            .fontSize(11)
            .fontColor($r('app.color.text_secondary'))
        }
        .layoutWeight(1)
        .onClick(() => { this.activeFilter = this.activeFilter === 'up_bookmark' ? 'all' : 'up_bookmark'; })

        Column({ space: 6 }) {
          Column() {
            Text('➕')
              .fontSize(28)
          }
          .width(56)
          .height(56)
          .borderRadius(16)
          .backgroundColor($r('app.color.glass_border'))
          .justifyContent(FlexAlign.Center)
          Text('新增关注')
            .fontSize(11)
            .fontColor($r('app.color.text_secondary'))
        }
        .layoutWeight(1)
        .onClick(() => { this.activeFilter = this.activeFilter === 'follow' ? 'all' : 'follow'; })

        Column({ space: 6 }) {
          Column() {
            Text('💬')
              .fontSize(28)
          }
          .width(56)
          .height(56)
          .borderRadius(16)
          .backgroundColor($r('app.color.glass_border'))
          .justifyContent(FlexAlign.Center)
          Text('评论')
            .fontSize(11)
            .fontColor($r('app.color.text_secondary'))
        }
        .layoutWeight(1)
        .onClick(() => { this.activeFilter = this.activeFilter === 'comment' ? 'all' : 'comment'; })
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 4, bottom: 12 })

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
      } else if (this.displayList.length === 0) {
        Column() {
          Text(this.activeFilter === 'all' ? '暂无新消息' : '暂无此类通知')
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
              this.displayList,
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
        .onRefreshing(() => {
          this.loadFirst().finally(() => {
            this.refreshing = false;
          });
        })
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.bg_primary'))
    .transition(buildPageTransition())
  }
}
