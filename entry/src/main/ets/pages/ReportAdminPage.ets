// 举报账本（admin）：举报台账列表 + 处置（标记成立/驳回）+ 用户封禁/解封
// 数据：GET /v1/admin/reports?page=&limit=&status=
// 操作：POST /v1/admin/reports/resolve、POST /v1/admin/users/:id/ban、/unban

import { AdminReportItem, ReportTargetType } from '../models/types';
import { listAdminReports, resolveTargetReports, banUser, unbanUser } from '../services/api';
import { safeShowToast } from '../utils/toast';
import { buildPageTransition } from '../utils/styles';
import { resolveActionIcon } from '../utils/actionIcons';
import { BackButton } from '../design/components/BackButton';
import { EmptyState } from '../design/components/EmptyState';
import { ColorTokens } from '../design/tokens/color';
import { RadiusTokens } from '../design/tokens/radius';
import { LayoutTokens, SpaceTokens } from '../design/tokens/space';
import { TypeTokens } from '../design/tokens/type';

// 举报理由 → 中文标签（与报举报弹窗文案对齐）
function reasonLabel(reason: string): string {
  switch (reason) {
    case 'political': return '涉政敏感';
    case 'pornographic': return '色情低俗';
    case 'personal_attack': return '人身攻击';
    case 'gender_war': return '男女对立引战';
    case 'advertisement': return '广告推广';
    case 'spam': return '垃圾信息';
    case 'other': return '其他';
    default: return reason;
  }
}

function targetLabel(type: ReportTargetType): string {
  switch (type) {
    case 'post': return '帖子';
    case 'comment': return '评论';
    case 'user': return '用户';
    default: return type;
  }
}

function statusLabel(status: string): string {
  switch (status) {
    case 'pending': return '待处理';
    case 'resolved': return '已成立';
    case 'dismissed': return '已驳回';
    default: return status;
  }
}

function statusColor(status: string): ResourceColor {
  switch (status) {
    case 'pending': return $r('app.color.semantic_red');
    case 'resolved': return $r('app.color.brand_primary');
    case 'dismissed': return $r('app.color.text_secondary');
    default: return $r('app.color.text_secondary');
  }
}

// 格式化 ISO 时间 → "MM-DD HH:mm"
function formatTime(iso?: string): string {
  if (!iso) {
    return '';
  }
  const d: Date = new Date(iso);
  if (isNaN(d.getTime())) {
    return iso;
  }
  const pad = (n: number): string => (n < 10 ? '0' + n : String(n));
  return pad(d.getMonth() + 1) + '-' + pad(d.getDate()) + ' ' + pad(d.getHours()) + ':' + pad(d.getMinutes());
}

// 筛选 Tab
interface FilterTab {
  key: string; // '' = 全部
  label: string;
}

const FILTERS: FilterTab[] = [
  { key: '', label: '全部' },
  { key: 'pending', label: '待处理' },
  { key: 'resolved', label: '已成立' },
  { key: 'dismissed', label: '已驳回' },
];

@Entry
@Component
export struct ReportAdminPage {
  @State items: AdminReportItem[] = [];
  @State loading: boolean = false;
  @State error: string = '';
  @State forbidden: boolean = false;
  @State isRefreshing: boolean = false;
  @State finished: boolean = false;
  @State page: number = 1;
  @State filterKey: string = ''; // '' | pending | resolved | dismissed
  @State processingKey: string = ''; // 防重复提交：'resolve-$id-$action' / 'ban-$id'
  @StorageLink('statusBarHeight') statusBarHeight: number = 0;

  aboutToAppear(): void {
    this.load(true);
  }

  private currentStatus(): 'pending' | 'resolved' | 'dismissed' | undefined {
    const k: string = this.filterKey;
    if (k === 'pending' || k === 'resolved' || k === 'dismissed') {
      return k;
    }
    return undefined;
  }

  private setFilter(k: string): void {
    if (this.filterKey === k) {
      return;
    }
    this.filterKey = k;
    this.page = 1;
    this.finished = false;
    this.load(true);
  }

  async load(reset: boolean): Promise<void> {
    if (this.loading) {
      return;
    }
    this.loading = true;
    if (reset) {
      this.error = '';
    }
    try {
      const res = await listAdminReports(this.page, 20, this.currentStatus());
      const list: AdminReportItem[] = res.list;
      if (reset) {
        this.items = list;
      } else {
        this.items = this.items.concat(list);
      }
      this.finished = list.length < 20;
      this.forbidden = false;
    } catch (e) {
      const msg: string = (e as Error).message;
      if (msg.includes('权限') || msg.includes('403') || msg.includes('管理员')) {
        this.forbidden = true;
      }
      this.error = msg;
    } finally {
      this.loading = false;
    }
  }

  loadMore(): void {
    if (this.finished || this.loading || this.isRefreshing) {
      return;
    }
    this.page += 1;
    this.load(false);
  }

  // 标记成立 / 驳回
  private async onResolve(item: AdminReportItem, action: 'resolved' | 'dismissed'): Promise<void> {
    const key: string = 'r' + item.id + '-' + action;
    if (this.processingKey !== '') {
      return;
    }
    this.processingKey = key;
    try {
      await resolveTargetReports(item.targetType, item.targetId, action);
      safeShowToast(this.getUIContext(), { message: action === 'resolved' ? '已标记成立' : '已驳回' });
      // 刷掉当前筛选下的 pending 项
      this.items = this.items.filter((it: AdminReportItem) =>
        !(it.targetType === item.targetType && it.targetId === item.targetId && it.status === 'pending'));
      if (this.items.length === 0 && !this.finished) {
        this.load(true);
      }
    } catch (e) {
      safeShowToast(this.getUIContext(), { message: (e as Error).message });
    } finally {
      this.processingKey = '';
    }
  }

  // 封禁 / 解封（影响面大，二次确认）
  private onToggleBan(item: AdminReportItem): void {
    const ban: boolean = item.targetBanned !== true;
    this.getUIContext().showAlertDialog({
      title: ban ? '封禁该用户' : '解封该用户',
      message: ban
        ? '封禁后该用户将无法登录与发布内容。确定封禁吗？'
        : '解封后该用户可恢复正常使用。确定解封吗？',
      primaryButton: { value: '取消', action: (): void => {} },
      secondaryButton: {
        value: ban ? '封禁' : '解封',
        fontColor: $r('app.color.semantic_red'),
        action: (): void => {
          this.doBan(item, ban);
        },
      },
    });
  }

  private async doBan(item: AdminReportItem, ban: boolean): Promise<void> {
    const key: string = 'b' + item.targetId + '-' + (ban ? 'on' : 'off');
    if (this.processingKey !== '') {
      return;
    }
    this.processingKey = key;
    try {
      if (ban) {
        await banUser(item.targetId);
      } else {
        await unbanUser(item.targetId);
      }
      safeShowToast(this.getUIContext(), { message: ban ? '已封禁' : '已解封' });
      const next: AdminReportItem[] = this.items.map((it: AdminReportItem): AdminReportItem => {
        if (it.targetType === 'user' && it.targetId === item.targetId) {
          // ArkTS 不支持对象展开，显式拷贝后覆盖封禁态
          const copy: AdminReportItem = {
            id: it.id,
            reporterId: it.reporterId,
            targetType: it.targetType,
            targetId: it.targetId,
            reason: it.reason,
            description: it.description,
            status: it.status,
            createdAt: it.createdAt,
            reporter: it.reporter,
            postTitle: it.postTitle,
            commentContent: it.commentContent,
            targetNickname: it.targetNickname,
            targetBanned: ban,
          };
          return copy;
        }
        return it;
      });
      this.items = next;
    } catch (e) {
      safeShowToast(this.getUIContext(), { message: (e as Error).message });
    } finally {
      this.processingKey = '';
    }
  }

  @Builder
  filterBar(): void {
    Row({ space: SpaceTokens.sm }) {
      ForEach(FILTERS, (f: FilterTab) => {
        Text(f.label)
          .fontSize(TypeTokens.callout.size)
          .fontFamily(TypeTokens.fontFamily)
          .fontWeight(this.filterKey === f.key ? TypeTokens.headline.weight : TypeTokens.callout.weight)
          .fontColor(this.filterKey === f.key ? ColorTokens.primary : ColorTokens.secondary)
          .padding({ left: SpaceTokens.md, right: SpaceTokens.md, top: 6, bottom: 6 })
          .backgroundColor(this.filterKey === f.key ? $r('app.color.bg_primary') : Color.Transparent)
          .borderRadius(RadiusTokens.pill)
          .onClick(() => { this.setFilter(f.key); })
      }, (f: FilterTab) => 'f' + f.key)
    }
    .width('100%')
    .padding({ left: SpaceTokens.sm, right: SpaceTokens.sm, bottom: SpaceTokens.xs })
  }

  // 目标摘要行（帖子标题 / 评论内容 / 用户昵称）
  @Builder
  targetLine(item: AdminReportItem): void {
    if (item.targetType === 'post') {
      Text(item.postTitle ?? ('帖子 #' + item.targetId))
        .fontSize(16).fontFamily(TypeTokens.fontFamily).fontWeight(FontWeight.Medium)
        .fontColor(ColorTokens.primary)
        .maxLines(2).textOverflow({ overflow: TextOverflow.Ellipsis })
    } else if (item.targetType === 'comment') {
      Text(item.commentContent ?? ('评论 #' + item.targetId))
        .fontSize(14).fontFamily(TypeTokens.fontFamily)
        .fontColor(ColorTokens.primary)
        .maxLines(3).textOverflow({ overflow: TextOverflow.Ellipsis })
    } else {
      Row({ space: 6 }) {
        Text(item.targetNickname ?? ('用户 #' + item.targetId))
          .fontSize(16).fontFamily(TypeTokens.fontFamily).fontWeight(FontWeight.Medium)
          .fontColor(ColorTokens.primary)
        if (item.targetBanned === true) {
          Text('已封禁')
            .fontSize(11).fontFamily(TypeTokens.fontFamily)
            .fontColor($r('app.color.semantic_red'))
            .padding({ left: 6, right: 6, top: 2, bottom: 2 })
            .backgroundColor('#FFE5E5')
            .borderRadius(6)
        }
      }
    }
  }

  // 操作按钮（pending → 成立/驳回；用户目标 → 追加封禁/解封）
  @Builder
  actions(item: AdminReportItem): void {
    Row({ space: 8 }) {
      if (item.status === 'pending') {
        Button('成立')
          .fontSize(13).fontFamily(TypeTokens.fontFamily)
          .height(32)
          .backgroundColor('#34C759')
          .fontColor('#FFFFFF')
          .enabled(this.processingKey === '')
          .onClick(() => { this.onResolve(item, 'resolved'); })
        Button('驳回')
          .fontSize(13).fontFamily(TypeTokens.fontFamily)
          .height(32)
          .backgroundColor($r('app.color.bg_primary'))
          .fontColor($r('app.color.text_secondary'))
          .enabled(this.processingKey === '')
          .onClick(() => { this.onResolve(item, 'dismissed'); })
      } else {
        Text(statusLabel(item.status))
          .fontSize(13).fontFamily(TypeTokens.fontFamily)
          .fontColor($r('app.color.text_secondary'))
      }
      if (item.targetType === 'user') {
        Button(item.targetBanned === true ? '解封' : '封禁')
          .fontSize(13).fontFamily(TypeTokens.fontFamily)
          .height(32)
          .backgroundColor(item.targetBanned === true ? $r('app.color.bg_primary') : $r('app.color.semantic_red'))
          .fontColor(item.targetBanned === true ? $r('app.color.text_secondary') : '#FFFFFF')
          .enabled(this.processingKey === '')
          .onClick(() => { this.onToggleBan(item); })
      }
    }
  }

  @Builder
  reportCard(item: AdminReportItem): void {
    Column({ space: 8 }) {
      // 头部：类型 + 状态 + 举报人 + 时间
      Row({ space: 6 }) {
        Text(targetLabel(item.targetType))
          .fontSize(11).fontFamily(TypeTokens.fontFamily)
          .fontColor($r('app.color.brand_primary'))
          .padding({ left: 8, right: 8, top: 2, bottom: 2 })
          .backgroundColor('#E8F1FF')
          .borderRadius(6)
        Text(statusLabel(item.status))
          .fontSize(11).fontFamily(TypeTokens.fontFamily)
          .fontColor(statusColor(item.status))
          .padding({ left: 8, right: 8, top: 2, bottom: 2 })
          .backgroundColor('#F2F2F2')
          .borderRadius(6)
        Blank()
        Text(formatTime(item.createdAt))
          .fontSize(11).fontFamily(TypeTokens.fontFamily)
          .fontColor($r('app.color.text_tertiary'))
      }
      .width('100%')

      this.targetLine(item)

      // 理由 + 补充说明 + 举报人
      Column({ space: 4 }) {
        Row({ space: 6 }) {
          Text(reasonLabel(item.reason))
            .fontSize(12).fontFamily(TypeTokens.fontFamily)
            .fontColor($r('app.color.semantic_red'))
            .padding({ left: 8, right: 8, top: 2, bottom: 2 })
            .backgroundColor('#FFE5E5')
            .borderRadius(10)
          if (item.reporter) {
            Text((item.reporter.nickname ?? '匿名') + ' 举报')
              .fontSize(11).fontFamily(TypeTokens.fontFamily)
              .fontColor($r('app.color.text_tertiary'))
          }
        }
        if (item.description) {
          Text(item.description)
            .fontSize(12).fontFamily(TypeTokens.fontFamily)
            .fontColor($r('app.color.text_secondary'))
            .maxLines(2).textOverflow({ overflow: TextOverflow.Ellipsis })
            .width('100%')
        }
      }
      .alignItems(HorizontalAlign.Start)
      .width('100%')

      this.actions(item)
    }
    .padding({ left: 12, right: 12, top: 12, bottom: 12 })
    .backgroundColor($r('app.color.card_bg'))
    .borderRadius(RadiusTokens.lg)
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  refreshBuilder(): void {
    Row({ space: 8 }) {
      LoadingProgress().width(20).height(20)
      Text('刷新中…').fontSize(12).fontFamily($r('app.string.font_family')).fontColor($r('app.color.text_secondary'))
    }
  }

  build() {
    Column() {
      // 顶栏：返回 + 标题 + 刷新
      Row() {
        BackButton({ action: (): void => { this.getUIContext().getRouter().back(); } })
        Text('举报账本')
          .fontSize(17).fontFamily($r('app.string.font_family'))
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.text_primary'))
          .layoutWeight(1)
          .textAlign(TextAlign.Center)
        Text('刷新')
          .fontSize(15).fontFamily($r('app.string.font_family'))
          .fontColor($r('app.color.brand_primary'))
          .width(44).height(44).textAlign(TextAlign.Center)
          .onClick(() => {
            if (this.isRefreshing || this.loading) {
              return;
            }
            this.isRefreshing = true;
            this.page = 1;
            this.finished = false;
            this.load(true).finally(() => {
              this.isRefreshing = false;
            });
          })
      }
      .width('100%')
      .padding({ top: 12, bottom: 8, left: 0, right: 0 })

      this.filterBar()

      if (this.loading && this.items.length === 0) {
        Column({ space: SpaceTokens.sm }) {
          LoadingProgress().width(28).height(28)
          Text('加载中…')
            .fontSize(13).fontFamily($r('app.string.font_family'))
            .fontColor($r('app.color.text_secondary'))
        }
        .layoutWeight(1).width('100%').justifyContent(FlexAlign.Center)
      } else if (this.forbidden) {
        Column({ space: 8 }) {
          Image(resolveActionIcon('lock')).width(48).height(48)
          Text('无管理员权限')
            .fontSize(16).fontFamily($r('app.string.font_family'))
            .fontColor($r('app.color.text_secondary'))
          Text('请联系管理员或检查登录账号')
            .fontSize(12).fontFamily($r('app.string.font_family'))
            .fontColor($r('app.color.text_tertiary'))
        }
        .layoutWeight(1).width('100%').justifyContent(FlexAlign.Center)
      } else if (this.items.length === 0) {
        EmptyState({
          icon: this.error.length > 0 ? resolveActionIcon('warning') : resolveActionIcon('inbox'),
          title: this.error.length > 0 ? '加载失败' : '暂无举报记录',
          message: this.error.length > 0 ? this.error : '新举报会自动同步到这里与飞书群',
          actionLabel: this.error.length > 0 ? '重试' : '',
          onAction: this.error.length > 0
            ? (): void => { this.load(true); }
            : (): void => {},
        })
          .layoutWeight(1).width('100%')
      } else {
        Refresh({ refreshing: this.isRefreshing, builder: this.refreshBuilder }) {
          List() {
            ForEach(
              this.items,
              (item: AdminReportItem) => {
                ListItem() {
                  this.reportCard(item)
                }
              },
              (item: AdminReportItem) => 'r' + item.id
            )
            if (!this.finished) {
              ListItem() {
                Row({ space: 8 }) {
                  LoadingProgress().width(18).height(18)
                  Text('加载更多…').fontSize(12).fontFamily($r('app.string.font_family')).fontColor($r('app.color.text_tertiary'))
                }
                .width('100%').justifyContent(FlexAlign.Center).padding(14)
              }
            }
          }
          .width('100%')
          .layoutWeight(1)
          .onScrollIndex((_start: number, end: number) => {
            if (end >= this.items.length - 1) {
              this.loadMore();
            }
          })
        }
        .onRefreshing(() => {
          this.isRefreshing = true;
          this.page = 1;
          this.finished = false;
          this.load(true).finally(() => {
            this.isRefreshing = false;
          });
        })
        .layoutWeight(1)
        .width('100%')
      }
    }
    .width('100%')
    .padding({ top: this.statusBarHeight })
    .height('100%')
    .backgroundColor($r('app.color.bg_primary'))
    .transition(buildPageTransition())
  }
}