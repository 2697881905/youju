// 举报账本（admin）：**按被举报对象聚合**的台账 + 处置（成立/驳回）+ 用户封禁/解封。
//
// 为什么聚合：后端 `resolveTargetReports(targetType, targetId, action)` 的语义是
// 「处理该目标的**全部** pending 举报」，而旧实现一条举报一张卡、按钮写「成立/驳回」，
// 审核员根本不知道自己这一下会连带处理掉同对象的其它举报。聚合后「一张卡 = 一个被举报
// 对象」，按钮的作用范围与 UI 终于对上了。
//
// 数据：GET  /v1/admin/reports?page=&limit=&status=   （返回逐条举报，本页在前端聚合）
// 操作：POST /v1/admin/reports/resolve                （作用于该对象的全部 pending 举报）
//       POST /v1/admin/users/:id/ban | /unban
import { AdminReportItem, ReportTargetType } from '../models/types';
import { ListResult, listAdminReports, resolveTargetReports, banUser, unbanUser } from '../services/api';
import { safeShowToast } from '../utils/toast';
import { timeAgo } from '../utils/format';
import { buildPageTransition } from '../utils/styles';
import { resolveActionIcon } from '../utils/actionIcons';
import { openPostDetail, openUserProfile } from '../utils/nav';
import { bottomNavInset } from '../utils/cardTokens';
import { BackButton } from '../design/components/BackButton';
import { BaseCard } from '../design/components/BaseCard';
import { DesignButton } from '../design/components/DesignButton';
import { EmptyState } from '../design/components/EmptyState';
import { Pressable } from '../design/motion/Pressable';
import { ColorTokens } from '../design/tokens/color';
import { IconTokens } from '../design/tokens/icon';
import { RadiusTokens } from '../design/tokens/radius';
import { LayoutTokens, SpaceTokens } from '../design/tokens/space';
import { TypeTokens } from '../design/tokens/type';
import { getUserId, getIsAdmin } from '../utils/auth';

const PAGE_SIZE: number = 20;
// 聚合卡上最多并列展示几个举报理由 / 举报人（其余折成「等 N 类 / 等 N 人」）
const MAX_REASON_PILLS: number = 2;
const MAX_REPORTERS: number = 3;

// ───────────────────────── 文案映射 ─────────────────────────

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

// 状态圆点色：文字本身用 ColorTokens.primary 保证对比度（ds_danger 在浅底上做小字
// 达不到 AA 4.5:1，见 topics/arkts-ui.md 的对比度护栏），语义交给圆点。
function statusDotColor(status: string): ResourceColor {
  if (status === 'pending') {
    return ColorTokens.danger;
  }
  if (status === 'resolved') {
    return ColorTokens.brand;
  }
  return ColorTokens.tertiary;
}

// ───────────────────────── 聚合 ─────────────────────────

interface ReasonTally {
  reason: string;
  count: number;
}

// 一个被举报对象 = 一张卡
interface ReportGroup {
  key: string;                 // targetType + '#' + targetId
  targetType: ReportTargetType;
  targetId: number;
  targetPostId: number;        // post 自身 / comment 所属帖 / user 无
  reportCount: number;         // 已加载到的举报条数
  pendingCount: number;
  status: string;              // 有 pending 就是 pending，否则取最新一条的状态
  newestAt: string;
  newestMs: number;
  reasons: ReasonTally[];      // 按条数降序
  reporters: string[];         // 去重昵称（最多 MAX_REPORTERS 个）
  reporterTotal: number;       // 去重后的举报人总数
  description: string;         // 最新一条非空补充说明
  targetBanned: boolean;
  targetTitle: string;         // 帖子标题
  commentContent: string;
  targetNickname: string;
}

function newGroup(key: string, it: AdminReportItem): ReportGroup {
  return {
    key: key,
    targetType: it.targetType,
    targetId: it.targetId,
    targetPostId: it.targetPostId ?? 0,
    reportCount: 0,
    pendingCount: 0,
    status: it.status,
    newestAt: it.createdAt,
    newestMs: new Date(it.createdAt).getTime(),
    reasons: [],
    reporters: [],
    reporterTotal: 0,
    description: '',
    targetBanned: false,
    targetTitle: '',
    commentContent: '',
    targetNickname: '',
  };
}

function addReason(g: ReportGroup, reason: string): void {
  for (const r of g.reasons) {
    if (r.reason === reason) {
      r.count += 1;
      return;
    }
  }
  g.reasons.push({ reason: reason, count: 1 });
}

function addReporter(g: ReportGroup, nickname: string): void {
  const name: string = nickname.length > 0 ? nickname : '匿名用户';
  for (const n of g.reporters) {
    if (n === name) {
      return;
    }
  }
  g.reporterTotal += 1;
  if (g.reporters.length < MAX_REPORTERS) {
    g.reporters.push(name);
  }
}

// 把一条举报并入它所属对象的聚合卡
function mergeReport(g: ReportGroup, it: AdminReportItem): void {
  g.reportCount += 1;
  if (it.status === 'pending') {
    g.pendingCount += 1;
  }
  const ms: number = new Date(it.createdAt).getTime();
  const isNewest: boolean = !Number.isNaN(ms) && (Number.isNaN(g.newestMs) || ms > g.newestMs);
  if (isNewest) {
    g.newestAt = it.createdAt;
    g.newestMs = ms;
    g.status = it.status;
    // 最新一条的说明优先展示（审核时最关心「最近这次说了什么」）
    if (it.description !== undefined && it.description !== null && it.description.length > 0) {
      g.description = it.description;
    }
  }
  if (g.description.length === 0 && it.description !== undefined && it.description !== null) {
    g.description = it.description;
  }
  addReason(g, it.reason);
  addReporter(g, it.reporter?.nickname ?? '');
  if (it.targetBanned === true) {
    g.targetBanned = true;
  }
  if (g.targetTitle.length === 0 && it.postTitle !== undefined && it.postTitle !== null) {
    g.targetTitle = it.postTitle;
  }
  if (g.commentContent.length === 0 && it.commentContent !== undefined && it.commentContent !== null) {
    g.commentContent = it.commentContent;
  }
  if (g.targetNickname.length === 0 && it.targetNickname !== undefined && it.targetNickname !== null) {
    g.targetNickname = it.targetNickname;
  }
  if (g.targetPostId <= 0 && (it.targetPostId ?? 0) > 0) {
    g.targetPostId = it.targetPostId ?? 0;
  }
}

function finishGroup(g: ReportGroup): ReportGroup {
  // 有 pending 就以 pending 为代表状态（这才是要处置的那张卡）
  if (g.pendingCount > 0) {
    g.status = 'pending';
  }
  g.reasons.sort((a: ReasonTally, b: ReasonTally): number => b.count - a.count);
  return g;
}

// 待处理优先，其次按最新举报时间倒序
function compareGroups(a: ReportGroup, b: ReportGroup): number {
  const ap: number = a.pendingCount > 0 ? 0 : 1;
  const bp: number = b.pendingCount > 0 ? 0 : 1;
  if (ap !== bp) {
    return ap - bp;
  }
  const am: number = Number.isNaN(a.newestMs) ? 0 : a.newestMs;
  const bm: number = Number.isNaN(b.newestMs) ? 0 : b.newestMs;
  return bm - am;
}

function aggregateGroups(items: AdminReportItem[]): ReportGroup[] {
  const order: string[] = [];
  const byKey: Map<string, ReportGroup> = new Map<string, ReportGroup>();
  for (const it of items) {
    const key: string = it.targetType + '#' + String(it.targetId);
    let g: ReportGroup | undefined = byKey.get(key);
    if (g === undefined) {
      g = newGroup(key, it);
      byKey.set(key, g);
      order.push(key);
    }
    mergeReport(g, it);
  }
  const groups: ReportGroup[] = [];
  for (const key of order) {
    const g: ReportGroup | undefined = byKey.get(key);
    if (g !== undefined) {
      groups.push(finishGroup(g));
    }
  }
  groups.sort(compareGroups);
  return groups;
}

// ArkTS 禁对象展开：就地改字段必须显式全字段拷贝。
// status 收窄成联合类型：AdminReportItem.status 是 'pending' | 'resolved' | 'dismissed'，
// 参数写成 string 会编译不过（string 不能赋给该联合类型）。
function copyReport(it: AdminReportItem, status: 'pending' | 'resolved' | 'dismissed', banned: boolean): AdminReportItem {
  return {
    id: it.id,
    reporterId: it.reporterId,
    targetType: it.targetType,
    targetId: it.targetId,
    reason: it.reason,
    description: it.description,
    status: status,
    createdAt: it.createdAt,
    reporter: it.reporter,
    postTitle: it.postTitle,
    commentContent: it.commentContent,
    targetNickname: it.targetNickname,
    targetBanned: banned,
    targetPostId: it.targetPostId,
  };
}

// ───────────────────────── 筛选 ─────────────────────────

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
  // 原始举报（累计分页）→ 聚合后的展示列表
  @State items: AdminReportItem[] = [];
  @State groups: ReportGroup[] = [];
  @State loading: boolean = false;
  @State error: string = '';
  @State forbidden: boolean = false;
  @State isRefreshing: boolean = false;
  @State finished: boolean = false;
  @State page: number = 1;
  @State filterKey: string = ''; // '' | pending | resolved | dismissed
  // 防重复提交：值为正在处理的那张聚合卡的 key（空串 = 空闲）
  @State processingKey: string = '';
  @State total: number = 0; // 服务端返回的举报总条数（当前筛选）
  @StorageLink('statusBarHeight') statusBarHeight: number = 0;
  // 请求序号：过期响应整体丢弃（与 974f859 的 HomeTab 同方案）。
  // 旧实现用 `if (this.loading) return` 守卫，正在加载时点筛选会被静默吞掉。
  private fetchSeq: number = 0;

  aboutToAppear(): void {
    // 登录闸门：举报账本需要登录态 + 管理员权限，未登录连 401/403 都分不清（只会是空壳）。
    // 用 replaceUrl 把本页从路由栈里替换掉 —— 取消登录返回时落到**入口页**（设置页）。
    if (getUserId() === 0) {
      this.getUIContext().getRouter().replaceUrl({ url: 'pages/LoginPage' });
      return;
    }
    // 管理员闸门（E2E 审计 D2）：登录 ≠ 管理员。普通用户误入（通知深链等）直接退回，
    // 不渲染管理 UI、不发 /v1/admin 请求（后端虽会 403，前端不该把管理界面暴露出去）。
    if (!getIsAdmin()) {
      this.getUIContext().getRouter().back();
      return;
    }
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
    // 先就地重算一次：切筛选立刻有反馈，不必等网络
    this.recomputeGroups();
    this.load(true);
  }

  private recomputeGroups(): void {
    const all: ReportGroup[] = aggregateGroups(this.items);
    const k: string = this.filterKey;
    if (k.length === 0) {
      this.groups = all;
      return;
    }
    this.groups = all.filter((g: ReportGroup): boolean => g.status === k);
  }

  async load(reset: boolean): Promise<void> {
    const seq: number = ++this.fetchSeq;
    this.loading = true;
    if (reset) {
      this.error = '';
    }
    const reqPage: number = this.page;
    try {
      const res: ListResult<AdminReportItem> = await listAdminReports(reqPage, PAGE_SIZE, this.currentStatus());
      if (seq !== this.fetchSeq) {
        return; // 过期响应：期间已有更新的请求发起，整体丢弃
      }
      const list: AdminReportItem[] = res.list;
      if (reset) {
        this.items = list;
      } else {
        this.items = this.items.concat(list);
      }
      this.total = res.pagination.total;
      this.finished = list.length < PAGE_SIZE;
      this.forbidden = false;
      this.recomputeGroups();
    } catch (e) {
      if (seq !== this.fetchSeq) {
        return;
      }
      const msg: string = (e as Error).message;
      if (msg.includes('权限') || msg.includes('403') || msg.includes('管理员')) {
        this.forbidden = true;
      }
      this.error = msg;
    } finally {
      if (seq === this.fetchSeq) {
        this.loading = false;
      }
    }
  }

  loadMore(): void {
    if (this.finished || this.loading || this.isRefreshing) {
      return;
    }
    this.page += 1;
    this.load(false);
  }

  private refresh(): void {
    if (this.isRefreshing) {
      return;
    }
    this.isRefreshing = true;
    this.page = 1;
    this.finished = false;
    this.load(true).finally((): void => {
      this.isRefreshing = false;
    });
  }

  // ───────────────────────── 显示文案 ─────────────────────────

  private reasonsText(g: ReportGroup): string {
    if (g.reasons.length === 0) {
      return '未填写理由';
    }
    let text: string = '';
    const n: number = Math.min(MAX_REASON_PILLS, g.reasons.length);
    for (let i: number = 0; i < n; i++) {
      text += (i === 0 ? '' : ' · ') + reasonLabel(g.reasons[i].reason);
    }
    if (g.reasons.length > n) {
      text += ' 等 ' + g.reasons.length + ' 类';
    }
    return text;
  }

  private reportersText(g: ReportGroup): string {
    if (g.reporterTotal === 0) {
      return '';
    }
    if (g.reporterTotal === 1) {
      return g.reporters[0] + ' 举报';
    }
    return g.reporters[0] + ' 等 ' + g.reporterTotal + ' 人举报';
  }

  private pendingText(g: ReportGroup): string {
    return g.pendingCount > 1 ? '待处理 · ' + g.pendingCount : '待处理';
  }

  // 「一条举报」与「该对象全部举报」的区分：处置前告知作用范围
  private resolveScopeText(g: ReportGroup): string {
    if (g.pendingCount > 1) {
      return '该被举报内容的 ' + g.pendingCount + ' 条待处理举报会一并标记为「已成立」。确认吗？';
    }
    return '该举报会被标记为「已成立」。确认吗？';
  }

  // ───────────────────────── 直达被举报对象 ─────────────────────────

  private canOpenTarget(g: ReportGroup): boolean {
    if (g.targetType === 'user') {
      return g.targetId > 0;
    }
    return g.targetPostId > 0;
  }

  private targetLinkLabel(g: ReportGroup): string {
    if (g.targetType === 'user') {
      return '查看用户主页';
    }
    if (g.targetType === 'comment') {
      return '在帖子中查看该评论';
    }
    return '查看原帖内容';
  }

  private openTarget(g: ReportGroup): void {
    if (this.processingKey.length > 0) {
      return;
    }
    if (g.targetType === 'user') {
      openUserProfile(g.targetId);
      this.getUIContext().getRouter().pushUrl({ url: 'pages/UserProfilePage' });
      return;
    }
    if (g.targetPostId <= 0) {
      safeShowToast(this.getUIContext(), { message: '目标内容不存在或已被删除' });
      return;
    }
    openPostDetail(String(g.targetPostId));
    this.getUIContext().getRouter().pushUrl({ url: 'pages/DetailPage' });
  }

  // ───────────────────────── 处置 ─────────────────────────

  // 「成立」影响面大（会连带处理该对象的全部待处理举报），走二次确认；
  // 「驳回」是低风险快操作，直接提交。
  private confirmResolve(g: ReportGroup): void {
    this.getUIContext().showAlertDialog({
      title: '标记举报成立',
      message: this.resolveScopeText(g),
      primaryButton: { value: '取消', action: (): void => {} },
      secondaryButton: {
        value: '成立',
        fontColor: ColorTokens.danger,
        action: (): void => { this.doResolve(g, 'resolved'); },
      },
    });
  }

  private async doResolve(g: ReportGroup, action: 'resolved' | 'dismissed'): Promise<void> {
    if (this.processingKey.length > 0) {
      return;
    }
    this.processingKey = g.key;
    try {
      await resolveTargetReports(g.targetType, g.targetId, action);
      safeShowToast(this.getUIContext(), { message: action === 'resolved' ? '已标记成立' : '已驳回' });
      // 就地更新状态，而不是从列表里移除 —— 账本要留得住刚处置的记录
      const next: AdminReportItem[] = [];
      for (const it of this.items) {
        if (it.targetType === g.targetType && it.targetId === g.targetId && it.status === 'pending') {
          next.push(copyReport(it, action, it.targetBanned === true));
        } else {
          next.push(it);
        }
      }
      this.items = next;
      this.recomputeGroups();
    } catch (e) {
      safeShowToast(this.getUIContext(), { message: (e as Error).message });
    } finally {
      this.processingKey = '';
    }
  }

  private confirmBan(g: ReportGroup): void {
    const ban: boolean = !g.targetBanned;
    this.getUIContext().showAlertDialog({
      title: ban ? '封禁该用户' : '解封该用户',
      message: ban
        ? '封禁后该用户将无法登录与发布内容。确定封禁吗？'
        : '解封后该用户可恢复正常使用。确定解封吗？',
      primaryButton: { value: '取消', action: (): void => {} },
      secondaryButton: {
        value: ban ? '封禁' : '解封',
        fontColor: ban ? ColorTokens.danger : ColorTokens.brand,
        action: (): void => { this.doBan(g, ban); },
      },
    });
  }

  private async doBan(g: ReportGroup, ban: boolean): Promise<void> {
    if (this.processingKey.length > 0) {
      return;
    }
    this.processingKey = g.key;
    try {
      if (ban) {
        await banUser(g.targetId);
      } else {
        await unbanUser(g.targetId);
      }
      safeShowToast(this.getUIContext(), { message: ban ? '已封禁' : '已解封' });
      const next: AdminReportItem[] = [];
      for (const it of this.items) {
        if (it.targetType === g.targetType && it.targetId === g.targetId) {
          next.push(copyReport(it, it.status, ban));
        } else {
          next.push(it);
        }
      }
      this.items = next;
      this.recomputeGroups();
    } catch (e) {
      safeShowToast(this.getUIContext(), { message: (e as Error).message });
    } finally {
      this.processingKey = '';
    }
  }

  // ───────────────────────── 视图 ─────────────────────────

  @Builder
  topBar(): void {
    Row() {
      BackButton({ action: (): void => { this.getUIContext().getRouter().back(); } })
      Blank()
      Text('举报账本')
        .fontSize(TypeTokens.title.size)
        .fontFamily(TypeTokens.fontFamilySerif)
        .fontWeight(TypeTokens.title.weight)
        .lineHeight(TypeTokens.title.lineHeight)
        .fontColor(ColorTokens.primary)
      Blank()
      Row() {
        if (this.isRefreshing) {
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

  @Builder
  filterBar(): void {
    Row({ space: SpaceTokens.xs }) {
      ForEach(FILTERS, (f: FilterTab) => {
        Text(f.label)
          .fontSize(TypeTokens.callout.size)
          .fontFamily(TypeTokens.fontFamily)
          .fontWeight(this.filterKey === f.key ? TypeTokens.headline.weight : TypeTokens.callout.weight)
          .fontColor(this.filterKey === f.key ? ColorTokens.onBrand : ColorTokens.secondary)
          .padding({ left: SpaceTokens.md, right: SpaceTokens.md, top: SpaceTokens.xs + 2, bottom: SpaceTokens.xs + 2 })
          .backgroundColor(this.filterKey === f.key ? ColorTokens.brand : ColorTokens.subtle)
          .borderRadius(RadiusTokens.pill)
          .onClick((): void => { this.setFilter(f.key); })
      }, (f: FilterTab) => 'f' + f.key)
    }
    .width('100%')
    .padding({ left: SpaceTokens.pageCompact, right: SpaceTokens.pageCompact, bottom: SpaceTokens.sm })
  }

  // 类型标签：品牌色 10% 底 + 品牌色文字（对比度 4.5:1）
  @Builder
  typePill(g: ReportGroup): void {
    Text(targetLabel(g.targetType))
      .fontSize(TypeTokens.overline.size)
      .fontFamily(TypeTokens.fontFamily)
      .fontWeight(TypeTokens.overline.weight)
      .fontColor(ColorTokens.brand)
      .padding({ left: SpaceTokens.sm, right: SpaceTokens.sm, top: 3, bottom: 3 })
      .backgroundColor(ColorTokens.brandTint)
      .borderRadius(RadiusTokens.xs)
  }

  // 状态标签：圆点承载语义色，文字用 primary 保证小字对比度（danger 做小字不达 AA）
  @Builder
  statusPill(g: ReportGroup): void {
    Row({ space: SpaceTokens.xs }) {
      Column()
        .width(6)
        .height(6)
        .borderRadius(RadiusTokens.pill)
        .backgroundColor(statusDotColor(g.status))
      Text(g.status === 'pending' ? this.pendingText(g) : statusLabel(g.status))
        .fontSize(TypeTokens.overline.size)
        .fontFamily(TypeTokens.fontFamily)
        .fontWeight(TypeTokens.overline.weight)
        .fontColor(ColorTokens.primary)
    }
    .padding({ left: SpaceTokens.sm, right: SpaceTokens.sm, top: 3, bottom: 3 })
    .backgroundColor(ColorTokens.subtle)
    .borderRadius(RadiusTokens.pill)
    .alignItems(VerticalAlign.Center)
  }

  // 被举报内容（帖子标题 / 评论 / 昵称）：卡片主角
  @Builder
  targetLine(g: ReportGroup): void {
    if (g.targetType === 'post') {
      Text(g.targetTitle.length > 0 ? g.targetTitle : ('帖子 #' + g.targetId))
        .fontSize(TypeTokens.body.size)
        .fontFamily(TypeTokens.fontFamily)
        .fontWeight(FontWeight.Medium)
        .lineHeight(TypeTokens.body.lineHeight)
        .fontColor(ColorTokens.primary)
        .maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .width('100%')
    } else if (g.targetType === 'comment') {
      Text(g.commentContent.length > 0 ? g.commentContent : ('评论 #' + g.targetId))
        .fontSize(TypeTokens.callout.size)
        .fontFamily(TypeTokens.fontFamily)
        .lineHeight(TypeTokens.callout.lineHeight)
        .fontColor(ColorTokens.primary)
        .maxLines(3)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .width('100%')
    } else {
      Row({ space: SpaceTokens.sm }) {
        Text(g.targetNickname.length > 0 ? g.targetNickname : ('用户 #' + g.targetId))
          .fontSize(TypeTokens.body.size)
          .fontFamily(TypeTokens.fontFamily)
          .fontWeight(FontWeight.Medium)
          .fontColor(ColorTokens.primary)
        if (g.targetBanned) {
          Row({ space: SpaceTokens.xs }) {
            Column()
              .width(6)
              .height(6)
              .borderRadius(RadiusTokens.pill)
              .backgroundColor(ColorTokens.danger)
            Text('已封禁')
              .fontSize(TypeTokens.overline.size)
              .fontFamily(TypeTokens.fontFamily)
              .fontColor(ColorTokens.primary)
          }
          .padding({ left: SpaceTokens.sm, right: SpaceTokens.sm, top: 2, bottom: 2 })
          .backgroundColor(ColorTokens.subtle)
          .borderRadius(RadiusTokens.xs)
          .alignItems(VerticalAlign.Center)
        }
      }
      .alignItems(VerticalAlign.Center)
    }
  }

  // 举报元信息：理由分布 + 举报人（聚合后的两个关键信号）
  @Builder
  metaLine(g: ReportGroup): void {
    Column({ space: SpaceTokens.xs }) {
      Text(this.reasonsText(g))
        .fontSize(TypeTokens.caption.size)
        .fontFamily(TypeTokens.fontFamily)
        .fontColor(ColorTokens.secondary)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .width('100%')
      if (this.reportersText(g).length > 0) {
        Text(this.reportersText(g))
          .fontSize(TypeTokens.caption.size)
          .fontFamily(TypeTokens.fontFamily)
          .fontColor(ColorTokens.tertiary)
          .maxLines(1)
          .width('100%')
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  // 补充说明：左侧引文竖线，与正文区分
  @Builder
  quoteBlock(text: string): void {
    Text(text)
      .fontSize(TypeTokens.caption.size)
      .fontFamily(TypeTokens.fontFamily)
      .fontColor(ColorTokens.secondary)
      .maxLines(2)
      .textOverflow({ overflow: TextOverflow.Ellipsis })
      .padding({ left: SpaceTokens.sm })
      // 四边显式写全：只给 left 的 EdgeWidths/EdgeColors 在部分版本上语义不明
      .border({
        width: { left: 2, right: 0, top: 0, bottom: 0 },
        color: {
          left: ColorTokens.quaternary, right: Color.Transparent,
          top: Color.Transparent, bottom: Color.Transparent,
        },
      })
      .width('100%')
  }

  @Builder
  actionRow(g: ReportGroup): void {
    Row({ space: SpaceTokens.sm }) {
      if (this.processingKey === g.key) {
        Text('处理中…')
          .fontSize(TypeTokens.caption.size)
          .fontFamily(TypeTokens.fontFamily)
          .fontColor(ColorTokens.tertiary)
      } else if (g.pendingCount > 0) {
        DesignButton({
          label: '驳回',
          variant: 'outlined',
          visualHeight: 34,
          disabled: this.processingKey.length > 0,
          action: (): void => { this.doResolve(g, 'dismissed'); },
        })
        DesignButton({
          label: '成立',
          variant: 'primary',
          visualHeight: 34,
          disabled: this.processingKey.length > 0,
          action: (): void => { this.confirmResolve(g); },
        })
      } else {
        Row({ space: SpaceTokens.xs }) {
          Column()
            .width(6)
            .height(6)
            .borderRadius(RadiusTokens.pill)
            .backgroundColor(statusDotColor(g.status))
          Text('已处置 · ' + statusLabel(g.status))
            .fontSize(TypeTokens.caption.size)
            .fontFamily(TypeTokens.fontFamily)
            .fontColor(ColorTokens.tertiary)
        }
        .alignItems(VerticalAlign.Center)
      }
      Blank()
      if (g.targetType === 'user') {
        DesignButton({
          label: g.targetBanned ? '解封' : '封禁',
          variant: 'outlined',
          visualHeight: 34,
          disabled: this.processingKey.length > 0,
          action: (): void => { this.confirmBan(g); },
        })
      }
    }
    .width('100%')
    .alignItems(VerticalAlign.Center)
  }

  @Builder
  groupCard(g: ReportGroup): void {
    BaseCard({ cardPadding: SpaceTokens.md, radius: RadiusTokens.lg, elevation: 1 }) {
      Column({ space: SpaceTokens.sm }) {
        // ① 身份行：类型 + 状态 + 最新举报时间
        Row({ space: SpaceTokens.sm }) {
          this.typePill(g)
          this.statusPill(g)
          Blank()
          Text(timeAgo(g.newestAt))
            .fontSize(TypeTokens.overline.size)
            .fontFamily(TypeTokens.fontFamily)
            .fontColor(ColorTokens.tertiary)
        }
        .width('100%')
        .alignItems(VerticalAlign.Center)

        // ② 内容 + 元信息：整块可点，直达被举报对象看完整上下文
        Pressable({ fillWidth: true, fullResponseRegion: true, action: (): void => { this.openTarget(g); } }) {
          Column({ space: SpaceTokens.sm }) {
            this.targetLine(g)
            this.metaLine(g)
            if (g.description.length > 0) {
              this.quoteBlock(g.description)
            }
            if (this.canOpenTarget(g)) {
              Row() {
                Blank()
                Text(this.targetLinkLabel(g) + ' ›')
                  .fontSize(TypeTokens.caption.size)
                  .fontFamily(TypeTokens.fontFamily)
                  .fontColor(ColorTokens.brand)
              }
              .width('100%')
            }
          }
          .width('100%')
          .alignItems(HorizontalAlign.Start)
        }

        Divider()
          .height(LayoutTokens.hairlineWidth)
          .color(ColorTokens.separator)

        // ③ 动作行
        this.actionRow(g)
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
    }
  }

  // 列表尾部：可点的加载更多 / 已全部加载（不必依赖滚到底才触发）
  @Builder
  listFooter(): void {
    // disabled 是 Pressable 自己的 @Prop，必须走构造参数；
    // 写成 `Pressable({...}){...}.disabled(x)` 会被当成通用属性 → 编译不过
    Pressable({ fillWidth: true, disabled: this.finished, action: (): void => { this.loadMore(); } }) {
      Row({ space: SpaceTokens.sm }) {
        if (this.loading) {
          LoadingProgress().width(IconTokens.compact).height(IconTokens.compact)
          Text('加载中…')
            .fontSize(TypeTokens.caption.size)
            .fontFamily(TypeTokens.fontFamily)
            .fontColor(ColorTokens.tertiary)
        } else if (this.finished) {
          Text(this.total > 0 ? '已全部加载 · 共 ' + this.total + ' 条举报' : '已全部加载')
            .fontSize(TypeTokens.caption.size)
            .fontFamily(TypeTokens.fontFamily)
            .fontColor(ColorTokens.tertiary)
        } else {
          Text('加载更多')
            .fontSize(TypeTokens.caption.size)
            .fontFamily(TypeTokens.fontFamily)
            .fontColor(ColorTokens.brand)
        }
      }
      .width('100%')
      .justifyContent(FlexAlign.Center)
      .padding({ top: SpaceTokens.base, bottom: SpaceTokens.base })
    }
  }

  @Builder
  refreshBuilder(): void {
    Row({ space: SpaceTokens.sm }) {
      LoadingProgress().width(20).height(20)
      Text('刷新中…')
        .fontSize(TypeTokens.caption.size)
        .fontFamily(TypeTokens.fontFamily)
        .fontColor(ColorTokens.secondary)
    }
  }

  // 加载中 / 空 / 错误三种「内容不足一屏」的状态要在视口里垂直居中
  private stateCentered(): boolean {
    return (this.loading && this.items.length === 0) || this.forbidden || this.groups.length === 0;
  }

  @Builder
  loadingState(): void {
    Column({ space: SpaceTokens.sm }) {
      LoadingProgress().width(IconTokens.empty).height(IconTokens.empty)
      Text('正在加载举报台账')
        .fontSize(TypeTokens.callout.size)
        .fontFamily(TypeTokens.fontFamily)
        .fontColor(ColorTokens.secondary)
    }
    .width('100%')
    .padding({ top: SpaceTokens.x3l, bottom: SpaceTokens.x3l })
    .justifyContent(FlexAlign.Center)
  }

  @Builder
  stateArea(): void {
    if (this.loading && this.items.length === 0) {
      this.loadingState()
    } else if (this.forbidden) {
      EmptyState({
        icon: resolveActionIcon('lock'),
        title: '无管理员权限',
        message: '请用管理员账号登录后查看举报台账',
      })
    } else if (this.groups.length === 0) {
      EmptyState({
        icon: this.error.length > 0 ? resolveActionIcon('warning') : resolveActionIcon('inbox'),
        title: this.error.length > 0 ? '加载失败' : '这里还没有记录',
        message: this.error.length > 0 ? this.error : '新的举报会自动同步到这里与飞书群',
        actionLabel: '刷新',
        onAction: (): void => { this.refresh(); },
      })
    } else {
      Column({ space: SpaceTokens.md }) {
        ForEach(this.groups, (g: ReportGroup) => {
          this.groupCard(g)
        }, (g: ReportGroup) => g.key + '#' + String(g.reportCount) + '#' + g.status)
        this.listFooter()
      }
      .width('100%')
    }
  }

  build() {
    Column() {
      this.topBar()
      this.filterBar()

      // 三态与列表统一包在 Refresh + Scroll 里：空态 / 错误态也能下拉刷新。
      // 全屏沉浸壳内列表一律用 Scroll（List/WaterFlow/Grid 的滚动终点会被底部非安全区钳制）。
      Refresh({ refreshing: this.isRefreshing, builder: this.refreshBuilder }) {
        Scroll() {
          Column() {
            this.stateArea()
          }
          .width('100%')
          .constraintSize({ minHeight: '100%' })
          .justifyContent(this.stateCentered() ? FlexAlign.Center : FlexAlign.Start)
          .padding({ left: SpaceTokens.pageCompact, right: SpaceTokens.pageCompact, bottom: SpaceTokens.x2l })
        }
        .layoutWeight(1)
        .width('100%')
        .scrollBar(BarState.Off)
        .onScrollEdge((edge: Edge): void => {
          if (edge === Edge.Bottom) {
            this.loadMore();
          }
        })
      }
      .onRefreshing((): void => { this.refresh(); })
      .layoutWeight(1)
      .width('100%')
    }
    .width('100%')
    .height('100%')
    // 底部避让：三键导航条下最后一张卡的处置按钮不能被压住
    .padding({ top: this.statusBarHeight, bottom: bottomNavInset() })
    .backgroundColor(ColorTokens.canvas)
    .transition(buildPageTransition())
  }
}
