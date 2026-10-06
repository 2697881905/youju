// 举报中心（admin）：**唯一处置台** —— 按被举报对象聚合的台账 + 内容状态裁决
// （成立并下架 / 驳回并恢复 / 改判恢复）+ 作者封禁/解封。原「内容审核台」已并入本页，不再有第二处入口。
//
// 为什么聚合：后端 `resolveTargetReports(targetType, targetId, action)` 的语义是
// 「处理该目标的**全部** pending 举报」，而旧实现一条举报一张卡、按钮写「成立/驳回」，
// 审核员根本不知道自己这一下会连带处理掉同对象的其它举报。聚合后「一张卡 = 一个被举报
// 对象」，按钮的作用范围与 UI 终于对上了。
//
// 数据：GET  /v1/admin/reports?page=&limit=&status=   （返回逐条举报，本页在前端聚合；含
//        目标内容状态 targetStatus 与作者信息，供卡片直接渲染「下架/发布」与「封禁作者」）
// 操作：POST /v1/admin/reports/resolve                （作用于该对象的全部 pending 举报）
//       POST /v1/admin/users/:id/ban | /unban
import { AdminReportItem, ReportAction, ReportTargetType } from '../models/types';
import { ListResult, listAdminReports, resolveTargetReports, banUser, unbanUser, deleteAdminReports } from '../services/api';
import { safeShowToast } from '../utils/toast';
import { timeAgo } from '../utils/format';
import { buildPageTransition } from '../utils/styles';
import { resolveActionIcon } from '../utils/actionIcons';
import { openPostDetail, openUserProfile } from '../utils/nav';
import { bottomNavInset } from '../utils/cardTokens';
import { Avatar } from '../design/components/Avatar';
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
  targetTitle: string;         // 帖子标题
  commentContent: string;
  targetNickname: string;      // user 目标昵称
  targetStatus: number | null; // 目标内容当前状态（0 下架 / 1 发布 / 2 旧拒绝）；user 目标 null
  authorId: number | null;     // 内容作者（user 目标 = 自身；作者已注销时 null）
  authorNickname: string;
  authorAvatar: string;
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
    targetTitle: '',
    commentContent: '',
    targetNickname: '',
    targetStatus: it.targetStatus ?? null,
    authorId: it.authorId ?? null,
    authorNickname: '',
    authorAvatar: '',
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
  // 目标级字段（同一目标的各条举报取值相同，取首个非空即可）
  if (g.targetStatus === null && it.targetStatus !== undefined && it.targetStatus !== null) {
    g.targetStatus = it.targetStatus;
  }
  if (g.authorId === null && it.authorId !== undefined && it.authorId !== null) {
    g.authorId = it.authorId;
  }
  if (g.authorNickname.length === 0 && it.authorNickname !== undefined && it.authorNickname !== null) {
    g.authorNickname = it.authorNickname;
  }
  if (g.authorAvatar.length === 0 && it.authorAvatar !== undefined && it.authorAvatar !== null) {
    g.authorAvatar = it.authorAvatar;
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
function copyReport(it: AdminReportItem, status: 'pending' | 'resolved' | 'dismissed', targetStatus: number | null): AdminReportItem {
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
    targetBanned: it.targetBanned,
    targetPostId: it.targetPostId,
    targetStatus: targetStatus,
    authorId: it.authorId,
    authorNickname: it.authorNickname,
    authorAvatar: it.authorAvatar,
    authorBanned: it.authorBanned,
  };
}

// 处置成功后就地回写一条举报（不等重拉，列表要立刻反映新状态）：
// - 内容状态是目标级属性：同一目标的所有行共享 targetStatus
//   （resolved → 0 下架；dismissed 仅 0→1 恢复；restore → 1；user 目标保持 null）
// - 举报状态只随本次处置流转 pending 行（restore 不改举报状态）
function patchReport(it: AdminReportItem, action: ReportAction): AdminReportItem {
  const isContent: boolean = it.targetType !== 'user';
  let ts: number | null = it.targetStatus ?? null;
  if (isContent && action === 'resolved') {
    ts = 0;
  } else if (isContent && action === 'dismissed' && ts === 0) {
    ts = 1;
  } else if (isContent && action === 'restore') {
    ts = 1;
  }
  let st: 'pending' | 'resolved' | 'dismissed' = it.status;
  if (it.status === 'pending' && action !== 'restore') {
    st = action === 'resolved' ? 'resolved' : 'dismissed';
  }
  return copyReport(it, st, ts);
}

// ───────────────────────── 筛选 ─────────────────────────
// 两级筛选：上层「板块」= 被举报对象类型（帖子/评论/用户），下层「状态」= 待处理/已成立/已驳回。
// 板块与状态都下推到服务端（分页与 total 同口径），本地再即时重算一次避免等待网络。

interface FilterTab {
  key: string;
  label: string;
}

// 类型板块：'' = 全部（不限类型。入口副标题给的是总量，进来先看全貌再按板块钻取）
const TYPE_TABS: FilterTab[] = [
  { key: '', label: '全部' },
  { key: 'post', label: '帖子' },
  { key: 'comment', label: '评论' },
  { key: 'user', label: '用户' },
];

// 状态：不设「全部」——默认只看待处理，已成立/已驳回按需切换
const FILTERS: FilterTab[] = [
  { key: 'pending', label: '待处理' },
  { key: 'resolved', label: '已成立' },
  { key: 'dismissed', label: '已驳回' },
];

// 成立理由弹窗（自原内容审核台的驳回弹窗并入）：理由选填，填写后随「未通过审核」通知发给作者
@CustomDialog
struct ResolveReasonDialog {
  controller: CustomDialogController;
  onSubmit: (reason: string) => void = (_r: string) => {};

  @State reason: string = '';

  build() {
    Column({ space: SpaceTokens.md }) {
      Text('成立理由')
        .fontSize(TypeTokens.headline.size).fontFamily(TypeTokens.fontFamily)
        .fontWeight(TypeTokens.headline.weight)
        .lineHeight(TypeTokens.headline.lineHeight)
        .fontColor(ColorTokens.primary)
        .width('100%')
      Text('选填；填写后随「未通过审核」通知发给作者，留空则只提示未通过。')
        .fontSize(TypeTokens.caption.size).fontFamily(TypeTokens.fontFamily)
        .lineHeight(TypeTokens.caption.lineHeight)
        .fontColor(ColorTokens.secondary)
        .width('100%')
      TextArea({ placeholder: '例如：含广告推广内容', text: this.reason })
        .height(96)
        .maxLength(200)
        .fontSize(TypeTokens.callout.size).fontFamily(TypeTokens.fontFamily)
        .fontColor(ColorTokens.primary)
        .backgroundColor(ColorTokens.sunken)
        .borderRadius(RadiusTokens.md)
        .onChange((v: string) => {
          this.reason = v;
        })
      Row({ space: SpaceTokens.md }) {
        DesignButton({ label: '取消', variant: 'outlined', fillWidth: true, action: (): void => { this.controller.close(); } })
          .layoutWeight(1)
        DesignButton({
          label: '确认成立',
          variant: 'primary',
          fillWidth: true,
          action: (): void => {
            const r: string = this.reason.trim();
            this.controller.close();
            this.onSubmit(r);
          },
        })
          .layoutWeight(1)
      }
      .width('100%')
    }
    .padding(SpaceTokens.lg)
    .backgroundColor(ColorTokens.elevated)
    .borderRadius(RadiusTokens.lg)
  }
}

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
  @State filterKey: string = 'pending'; // pending | resolved | dismissed（不设「全部」）
  @State typeKey: string = ''; // '' | post | comment | user（板块：被举报对象类型）
  // 多选删除：选择模式 + 已选中的聚合卡 key（targetType#targetId）
  @State selectMode: boolean = false;
  @State selectedKeys: string[] = [];
  @State deleting: boolean = false;
  // 防重复提交：值为正在处理的那张聚合卡的 key（空串 = 空闲）
  @State processingKey: string = '';
  @State total: number = 0; // 服务端返回的举报总条数（当前筛选）
  // 已封禁作者 id（含 user 目标自身）：列表只读不改，封禁/解封后就地维护这一份，
  // 刷新时按服务端返回的 authorBanned 重新对齐
  @State bannedAuthorIds: number[] = [];
  @StorageLink('statusBarHeight') statusBarHeight: number = 0;
  // 请求序号：过期响应整体丢弃（与 974f859 的 HomeTab 同方案）。
  // 旧实现用 `if (this.loading) return` 守卫，正在加载时点筛选会被静默吞掉。
  private fetchSeq: number = 0;

  // 成立理由弹窗：动作行 → 范围确认 → 本弹窗 → doResolve(resolved, reason)
  private pendingResolveType: ReportTargetType = 'post';
  private pendingResolveId: number = 0;
  private resolveController: CustomDialogController = new CustomDialogController({
    builder: ResolveReasonDialog({
      onSubmit: (reason: string): void => {
        this.doResolve(this.pendingResolveType, this.pendingResolveId, 'resolved', reason);
      },
    }),
    alignment: DialogAlignment.Center,
    customStyle: false,
  });

  aboutToAppear(): void {
    // 登录闸门：举报中心需要登录态 + 管理员权限，未登录连 401/403 都分不清（只会是空壳）。
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

  // 板块 → 服务端 targetType 参数（「全部」= undefined，不限类型）
  private currentTargetType(): ReportTargetType | undefined {
    const k: string = this.typeKey;
    if (k === 'post' || k === 'comment' || k === 'user') {
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
    // 换筛选后已选卡片可能已不在列表里：直接退出选择模式
    this.exitSelect();
    // 先就地重算一次：切筛选立刻有反馈，不必等网络
    this.recomputeGroups();
    this.load(true);
  }

  // 切板块（帖子 / 评论 / 用户）：类型下推服务端，分页与 total 都按该板块口径
  private setType(k: string): void {
    if (this.typeKey === k) {
      return;
    }
    this.typeKey = k;
    this.page = 1;
    this.finished = false;
    this.exitSelect();
    this.recomputeGroups();
    this.load(true);
  }

  private recomputeGroups(): void {
    const all: ReportGroup[] = aggregateGroups(this.items);
    const k: string = this.filterKey;
    const t: ReportTargetType | undefined = this.currentTargetType();
    this.groups = all.filter((g: ReportGroup): boolean => {
      if (k.length > 0 && g.status !== k) {
        return false;
      }
      if (t !== undefined && g.targetType !== t) {
        return false;
      }
      return true;
    });
  }

  async load(reset: boolean): Promise<void> {
    const seq: number = ++this.fetchSeq;
    this.loading = true;
    if (reset) {
      this.error = '';
    }
    const reqPage: number = this.page;
    try {
      const res: ListResult<AdminReportItem> = await listAdminReports(reqPage, PAGE_SIZE, this.currentStatus(), this.currentTargetType());
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
      this.syncBannedAuthorIds();
      this.recomputeGroups();
    } catch (e) {
      if (seq !== this.fetchSeq) {
        return;
      }
      // 分页回滚：loadMore 先 +1 再请求，失败不回滚会让失败那一页被静默跳过
      if (!reset && this.page > 1) {
        this.page -= 1;
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

  // ───────────────────────── 状态判定 ─────────────────────────

  // 按服务端返回的 authorBanned 重建封禁名单（下拉刷新/重新进页时对齐；
  // user 目标的 authorId = 目标自身，因此用户卡也走这一份）
  private syncBannedAuthorIds(): void {
    const ids: number[] = [];
    for (const it of this.items) {
      const aid: number | null | undefined = it.authorId;
      if (aid !== undefined && aid !== null && it.authorBanned === true && ids.indexOf(aid) < 0) {
        ids.push(aid);
      }
    }
    this.bannedAuthorIds = ids;
  }

  private isAuthorBanned(g: ReportGroup): boolean {
    return g.authorId !== null && this.bannedAuthorIds.indexOf(g.authorId) >= 0;
  }

  // 内容是否处于下架态（仅 post/comment；user 目标无内容）
  private isTakenDown(g: ReportGroup): boolean {
    return g.targetType !== 'user' && g.targetStatus === 0;
  }

  // 可恢复展示：已成立（无待处理举报）且内容确实处于下架态
  private canRestore(g: ReportGroup): boolean {
    return g.status === 'resolved' && g.pendingCount === 0 && this.isTakenDown(g);
  }

  // 目标内容状态文案：0 下架 / 1 发布；2 为旧审核台拒绝的存量（保持隐藏、无恢复入口）
  private contentStatusLabel(g: ReportGroup): string {
    if (g.targetStatus === 0) {
      return '已下架';
    }
    if (g.targetStatus === 1) {
      return '已发布';
    }
    return '已隐藏';
  }

  // 封禁对象：user 目标 = 自身；post/comment = 内容作者（作者已注销时无对象）
  private canBan(g: ReportGroup): boolean {
    if (g.targetType === 'user') {
      return g.targetId > 0;
    }
    return g.authorId !== null && g.authorId > 0;
  }

  private banTargetId(g: ReportGroup): number {
    return g.targetType === 'user' ? g.targetId : (g.authorId ?? 0);
  }

  private banButtonLabel(g: ReportGroup): string {
    const banned: boolean = this.isAuthorBanned(g);
    if (g.targetType === 'user') {
      return banned ? '解封' : '封禁';
    }
    return banned ? '解封作者' : '封禁作者';
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

  // 「一条举报」与「该对象全部举报」的区分：处置前告知作用范围（成立会一并下架内容并通知作者）
  private resolveScopeText(g: ReportGroup): string {
    const tail: string = g.targetType === 'user' ? '' : '，内容将被下架并通知作者';
    if (g.pendingCount > 1) {
      return '该被举报对象的 ' + g.pendingCount + ' 条待处理举报会一并标记为「已成立」' + tail + '。确认吗？';
    }
    return '该举报会被标记为「已成立」' + tail + '。确认吗？';
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
    if (this.processingKey.length > 0 || this.selectMode) {
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

  // 处置会改变待处理举报数（后端已同步「举报中心」置顶消息）→ 广播给消息页重拉列表，
  // 否则入口会停在上次新举报时的「有 N 条举报待处理」（用户报障：处理完了还显示有）
  private bumpReportCenterRefresh(): void {
    const cur: number = (AppStorage.get<number>('reportCenterRefreshSignal') ?? 0) as number;
    AppStorage.setOrCreate('reportCenterRefreshSignal', cur + 1);
  }

  // 「成立」影响面大（会连带处理该对象的全部待处理举报、下架内容并通知作者），
  // 走「范围确认 → 成立理由」两步；「驳回」「恢复展示」直接提交。
  private confirmResolve(g: ReportGroup): void {
    this.getUIContext().showAlertDialog({
      title: '标记举报成立',
      message: this.resolveScopeText(g),
      primaryButton: { value: '取消', action: (): void => {} },
      secondaryButton: {
        value: '成立',
        fontColor: ColorTokens.danger,
        action: (): void => {
          this.pendingResolveType = g.targetType;
          this.pendingResolveId = g.targetId;
          this.resolveController.open();
        },
      },
    });
  }

  // 三动作统一入口：resolved 成立并下架 / dismissed 驳回举报（内容被下架则一并恢复）/ restore 改判恢复。
  // reason 仅 resolved 时随「未通过审核」通知发给作者。
  private async doResolve(
    targetType: ReportTargetType,
    targetId: number,
    action: ReportAction,
    reason?: string
  ): Promise<void> {
    if (this.processingKey.length > 0) {
      return;
    }
    this.processingKey = targetType + '#' + String(targetId);
    try {
      await resolveTargetReports(targetType, targetId, action, reason);
      // 后端已把「举报中心」置顶消息的待处理数同步到最新 → 广播给消息页重拉列表
      this.bumpReportCenterRefresh();
      const tip: string = action === 'resolved' ? '已成立并下架' : (action === 'dismissed' ? '已驳回举报' : '已恢复展示');
      safeShowToast(this.getUIContext(), { message: tip });
      // 就地更新状态，而不是从列表里移除 —— 台账要留得住刚处置的记录
      const next: AdminReportItem[] = [];
      for (const it of this.items) {
        if (it.targetType === targetType && it.targetId === targetId) {
          next.push(patchReport(it, action));
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
    if (!this.canBan(g)) {
      safeShowToast(this.getUIContext(), { message: '无法获取作者信息' });
      return;
    }
    const ban: boolean = !this.isAuthorBanned(g);
    const isUserTarget: boolean = g.targetType === 'user';
    const who: string = isUserTarget
      ? (g.targetNickname.length > 0 ? g.targetNickname : '该用户')
      : (g.authorNickname.length > 0 ? g.authorNickname : '该作者');
    this.getUIContext().showAlertDialog({
      title: ban ? (isUserTarget ? '封禁该用户' : '封禁作者') : (isUserTarget ? '解封该用户' : '解封作者'),
      message: ban
        ? '封禁后 ' + who + ' 将无法登录与发布内容。确定封禁吗？'
        : '解封后 ' + who + ' 可恢复正常使用。确定解封吗？',
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
    const userId: number = this.banTargetId(g);
    if (userId <= 0) {
      safeShowToast(this.getUIContext(), { message: '无法获取作者信息' });
      return;
    }
    this.processingKey = g.key;
    try {
      if (ban) {
        await banUser(userId);
      } else {
        await unbanUser(userId);
      }
      // 就地维护封禁名单：该作者名下所有卡片立即反映新状态
      const next: number[] = this.bannedAuthorIds.slice();
      const at: number = next.indexOf(userId);
      if (ban && at < 0) {
        next.push(userId);
      } else if (!ban && at >= 0) {
        next.splice(at, 1);
      }
      this.bannedAuthorIds = next;
      safeShowToast(this.getUIContext(), { message: ban ? '已封禁' : '已解封' });
    } catch (e) {
      safeShowToast(this.getUIContext(), { message: (e as Error).message });
    } finally {
      this.processingKey = '';
    }
  }

  // 作者行整行可点：进作者主页（与「查看用户主页」同路，走 UserProfilePage）
  private openAuthor(g: ReportGroup): void {
    if (this.processingKey.length > 0 || this.selectMode) {
      return;
    }
    const authorId: number = this.banTargetId(g);
    if (authorId <= 0) {
      return;
    }
    openUserProfile(authorId);
    this.getUIContext().getRouter().pushUrl({ url: 'pages/UserProfilePage' });
  }

  // ───────────────────────── 多选删除（台账清理） ─────────────────────────

  private isSelected(g: ReportGroup): boolean {
    return this.selectedKeys.indexOf(g.key) >= 0;
  }

  private selectedCount(): number {
    return this.selectedKeys.length;
  }

  private allSelected(): boolean {
    return this.groups.length > 0 && this.selectedKeys.length === this.groups.length;
  }

  private enterSelect(): void {
    if (this.groups.length === 0) {
      safeShowToast(this.getUIContext(), { message: '当前没有可删除的记录' });
      return;
    }
    this.selectMode = true;
    this.selectedKeys = [];
  }

  private exitSelect(): void {
    this.selectMode = false;
    this.selectedKeys = [];
  }

  private toggleSelect(g: ReportGroup): void {
    const next: string[] = this.selectedKeys.slice();
    const at: number = next.indexOf(g.key);
    if (at >= 0) {
      next.splice(at, 1);
    } else {
      next.push(g.key);
    }
    this.selectedKeys = next;
  }

  private toggleSelectAll(): void {
    if (this.allSelected()) {
      this.selectedKeys = [];
      return;
    }
    const next: string[] = [];
    for (const g of this.groups) {
      next.push(g.key);
    }
    this.selectedKeys = next;
  }

  // 选中卡片对应的**已加载**举报记录 id（一张卡 = 一个被举报对象，可能聚合多条举报）
  private selectedReportIds(): number[] {
    const ids: number[] = [];
    for (const it of this.items) {
      const key: string = it.targetType + '#' + String(it.targetId);
      if (this.selectedKeys.indexOf(key) >= 0 && ids.indexOf(it.id) < 0) {
        ids.push(it.id);
      }
    }
    return ids;
  }

  private confirmDelete(): void {
    if (this.processingKey.length > 0) {
      return;
    }
    const ids: number[] = this.selectedReportIds();
    if (ids.length === 0) {
      safeShowToast(this.getUIContext(), { message: '请先选择要删除的信息' });
      return;
    }
    const cards: number = this.selectedKeys.length;
    this.getUIContext().showAlertDialog({
      title: '删除举报记录？',
      message: '将删除选中的 ' + cards + ' 张卡片对应的 ' + ids.length + ' 条举报记录。只清理台账记录，不改动被举报内容的状态；删除后不可恢复。',
      primaryButton: { value: '取消', action: (): void => {} },
      secondaryButton: {
        value: '确认删除',
        fontColor: ColorTokens.danger,
        action: (): void => { this.doDelete(ids); },
      },
    });
  }

  // 删除选中记录：后端删库并回写「举报中心」待处理数，前端就地移除 + 广播刷新消息页入口
  private async doDelete(ids: number[]): Promise<void> {
    if (this.deleting) {
      return;
    }
    this.deleting = true;
    try {
      const count: number = await deleteAdminReports(ids);
      const keep: AdminReportItem[] = [];
      for (const it of this.items) {
        if (ids.indexOf(it.id) < 0) {
          keep.push(it);
        }
      }
      this.items = keep;
      const rest: number = this.total - count;
      this.total = rest > 0 ? rest : 0;
      this.recomputeGroups();
      this.exitSelect();
      this.bumpReportCenterRefresh();
      safeShowToast(this.getUIContext(), { message: '已删除 ' + count + ' 条举报记录' });
    } catch (e) {
      safeShowToast(this.getUIContext(), { message: (e as Error).message });
    } finally {
      this.deleting = false;
    }
  }

  // ───────────────────────── 视图 ─────────────────────────

  @Builder
  topBar(): void {
    Row() {
      BackButton({ action: (): void => { this.getUIContext().getRouter().back(); } })
      Blank()
      Text('举报中心')
        .fontSize(TypeTokens.title.size)
        .fontFamily(TypeTokens.fontFamilySerif)
        .fontWeight(TypeTokens.title.weight)
        .lineHeight(TypeTokens.title.lineHeight)
        .fontColor(ColorTokens.primary)
      Blank()
      if (this.selectMode) {
        this.selectActions()
      } else {
        this.normalActions()
      }
    }
    .width('100%')
    .alignItems(VerticalAlign.Center)
    .padding({ left: SpaceTokens.pageCompact, right: SpaceTokens.pageCompact, top: SpaceTokens.sm, bottom: SpaceTokens.sm })
  }

  // 常规态右上角：刷新 + 删除（进入多选）
  @Builder
  normalActions(): void {
    Row({ space: SpaceTokens.sm }) {
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
      .constraintSize({ minWidth: LayoutTokens.minTouchTarget })
      .height(LayoutTokens.minTouchTarget)
      .justifyContent(FlexAlign.Center)
      .alignItems(VerticalAlign.Center)
      .onClick((): void => { this.refresh(); })

      Text('删除')
        .fontSize(TypeTokens.callout.size)
        .fontFamily(TypeTokens.fontFamily)
        .fontColor(ColorTokens.danger)
        .textAlign(TextAlign.Center)
        .constraintSize({ minWidth: LayoutTokens.minTouchTarget })
        .height(LayoutTokens.minTouchTarget)
        .onClick((): void => { this.enterSelect(); })
    }
    .alignItems(VerticalAlign.Center)
  }

  // 选择态右上角：取消 / 全选 / 删除选中
  @Builder
  selectActions(): void {
    Row({ space: SpaceTokens.sm }) {
      Text('取消')
        .fontSize(TypeTokens.callout.size)
        .fontFamily(TypeTokens.fontFamily)
        .fontColor(ColorTokens.secondary)
        .height(LayoutTokens.minTouchTarget)
        .onClick((): void => { this.exitSelect(); })

      Text(this.allSelected() ? '取消全选' : '全选')
        .fontSize(TypeTokens.callout.size)
        .fontFamily(TypeTokens.fontFamily)
        .fontColor(ColorTokens.brand)
        .height(LayoutTokens.minTouchTarget)
        .onClick((): void => { this.toggleSelectAll(); })

      Text(this.selectedCount() > 0 ? '删除 ' + String(this.selectedCount()) : '删除')
        .fontSize(TypeTokens.callout.size)
        .fontFamily(TypeTokens.fontFamily)
        .fontWeight(TypeTokens.headline.weight)
        .fontColor(this.selectedCount() > 0 ? ColorTokens.danger : ColorTokens.quaternary)
        .height(LayoutTokens.minTouchTarget)
        .onClick((): void => { this.confirmDelete(); })
    }
    .alignItems(VerticalAlign.Center)
  }

  // 板块栏（上层）：被举报对象类型 —— 帖子 / 评论 / 用户
  @Builder
  typeBar(): void {
    Row({ space: SpaceTokens.xs }) {
      ForEach(TYPE_TABS, (t: FilterTab) => {
        Text(t.label)
          .fontSize(TypeTokens.callout.size)
          .fontFamily(TypeTokens.fontFamily)
          .fontWeight(this.typeKey === t.key ? TypeTokens.headline.weight : TypeTokens.callout.weight)
          .fontColor(this.typeKey === t.key ? ColorTokens.onBrand : ColorTokens.secondary)
          .padding({ left: SpaceTokens.md, right: SpaceTokens.md, top: SpaceTokens.xs + 2, bottom: SpaceTokens.xs + 2 })
          .backgroundColor(this.typeKey === t.key ? ColorTokens.brand : ColorTokens.subtle)
          .borderRadius(RadiusTokens.pill)
          .onClick((): void => { this.setType(t.key); })
      }, (t: FilterTab) => 't' + t.key)
    }
    .width('100%')
    .padding({ left: SpaceTokens.pageCompact, right: SpaceTokens.pageCompact, bottom: SpaceTokens.xs })
  }

  // 状态栏（下层）：当前板块内的状态分类 —— 待处理 / 已成立 / 已驳回（不设「全部」）
  @Builder
  filterBar(): void {
    Row({ space: SpaceTokens.xs }) {
      ForEach(FILTERS, (f: FilterTab) => {
        Text(f.label)
          .fontSize(TypeTokens.callout.size)
          .fontFamily(TypeTokens.fontFamily)
          .fontWeight(this.filterKey === f.key ? TypeTokens.headline.weight : TypeTokens.callout.weight)
          .fontColor(this.filterKey === f.key ? ColorTokens.brand : ColorTokens.secondary)
          .padding({ left: SpaceTokens.md, right: SpaceTokens.md, top: SpaceTokens.xs + 2, bottom: SpaceTokens.xs + 2 })
          .backgroundColor(this.filterKey === f.key ? ColorTokens.brandTint : Color.Transparent)
          .border({ width: 1, color: this.filterKey === f.key ? ColorTokens.brand : ColorTokens.separator })
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

  // 内容状态标签（post/comment）：已下架 = danger 圆点 / 已发布 = brand 圆点 / 其余（存量 2）= 中性
  @Builder
  contentStatusPill(g: ReportGroup): void {
    Row({ space: SpaceTokens.xs }) {
      Column()
        .width(6)
        .height(6)
        .borderRadius(RadiusTokens.pill)
        .backgroundColor(
          g.targetStatus === 0 ? ColorTokens.danger : (g.targetStatus === 1 ? ColorTokens.brand : ColorTokens.tertiary)
        )
      Text(this.contentStatusLabel(g))
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

  @Builder
  bannedChip(): void {
    Row({ space: SpaceTokens.xs }) {
      Column()
        .width(6)
        .height(6)
        .borderRadius(RadiusTokens.pill)
        .backgroundColor(ColorTokens.danger)
      Text('已封禁')
        .fontSize(TypeTokens.overline.size)
        .fontFamily(TypeTokens.fontFamily)
        .fontWeight(TypeTokens.overline.weight)
        .fontColor(ColorTokens.primary)
    }
    .padding({ left: SpaceTokens.sm, right: SpaceTokens.sm, top: 2, bottom: 2 })
    .backgroundColor(ColorTokens.subtle)
    .borderRadius(RadiusTokens.xs)
    .alignItems(VerticalAlign.Center)
  }

  // 作者行（post/comment 目标）：头像 + 昵称 + 封禁标记；整行可点进作者主页
  @Builder
  authorRow(g: ReportGroup): void {
    if (this.canBan(g)) {
      Row({ space: SpaceTokens.sm }) {
        Avatar({
          avatar: g.authorAvatar,
          name: g.authorNickname,
          avatarSize: IconTokens.avatarCompact,
        })
        Text(g.authorNickname.length > 0 ? g.authorNickname : ('用户 #' + String(g.authorId ?? 0)))
          .fontSize(TypeTokens.callout.size)
          .fontFamily(TypeTokens.fontFamily)
          .fontWeight(TypeTokens.headline.weight)
          .lineHeight(TypeTokens.callout.lineHeight)
          .fontColor(ColorTokens.primary)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .layoutWeight(1)
        if (this.isAuthorBanned(g)) {
          this.bannedChip()
        }
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)
      .onClick((): void => { this.openAuthor(g); })
    }
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
        if (this.isAuthorBanned(g)) {
          this.bannedChip()
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
          label: '驳回举报',
          variant: 'outlined',
          visualHeight: 34,
          disabled: this.processingKey.length > 0,
          action: (): void => { this.doResolve(g.targetType, g.targetId, 'dismissed'); },
        })
        DesignButton({
          label: '成立并下架',
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
        // 已成立但内容仍处于下架态（误判/作者申诉）→ 提供改判恢复入口（仅内容，不改举报状态）
        if (this.canRestore(g)) {
          DesignButton({
            label: '恢复展示',
            variant: 'outlined',
            visualHeight: 34,
            disabled: this.processingKey.length > 0,
            action: (): void => { this.doResolve(g.targetType, g.targetId, 'restore'); },
          })
        }
      }
      Blank()
      if (this.canBan(g) && this.processingKey !== g.key) {
        DesignButton({
          label: this.banButtonLabel(g),
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

  // 选择模式的勾选标记：选中 = 品牌色圆勾；未选 = 空心圈
  @Builder
  selectMark(g: ReportGroup): void {
    if (this.isSelected(g)) {
      Image(resolveActionIcon('check'))
        .width(18)
        .height(18)
        .fillColor(ColorTokens.brand)
    } else {
      Column()
        .width(18)
        .height(18)
        .borderRadius(RadiusTokens.pill)
        .border({ width: 1, color: ColorTokens.quaternary })
    }
  }

  @Builder
  groupCard(g: ReportGroup): void {
    BaseCard({ cardPadding: SpaceTokens.md, radius: RadiusTokens.lg, elevation: 1 }) {
      Column({ space: SpaceTokens.sm }) {
        // ① 身份行：类型 + 举报状态 + 内容状态 + 最新举报时间
        Row({ space: SpaceTokens.sm }) {
          if (this.selectMode) {
            this.selectMark(g)
          }
          this.typePill(g)
          this.statusPill(g)
          if (g.targetType !== 'user') {
            this.contentStatusPill(g)
          }
          Blank()
          Text(timeAgo(g.newestAt))
            .fontSize(TypeTokens.overline.size)
            .fontFamily(TypeTokens.fontFamily)
            .fontColor(ColorTokens.tertiary)
        }
        .width('100%')
        .alignItems(VerticalAlign.Center)

        // ② 内容 + 元信息：整块可点 —— 常规态直达被举报对象；选择态切换勾选
        Pressable({ fillWidth: true, fullResponseRegion: true, action: (): void => {
          if (this.selectMode) {
            this.toggleSelect(g);
            return;
          }
          this.openTarget(g);
        } }) {
          Column({ space: SpaceTokens.sm }) {
            this.targetLine(g)
            this.metaLine(g)
            if (g.description.length > 0) {
              this.quoteBlock(g.description)
            }
            if (this.canOpenTarget(g) && !this.selectMode) {
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

        // ③ 作者行（post/comment 目标）：封禁决策的对象（用户卡由 targetLine 自身呈现）
        if (g.targetType !== 'user') {
          this.authorRow(g)
        }

        // ④ 动作行：选择态下隐藏（避免与「选卡片删除」混淆），只做勾选
        if (!this.selectMode) {
          Divider()
            .height(LayoutTokens.hairlineWidth)
            .color(ColorTokens.separator)

          this.actionRow(g)
        }
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
      Text('正在加载举报中心')
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
        message: '请用管理员账号登录后查看举报中心',
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
        // key 必须含会变字段：处置状态 / 内容状态 / 封禁态（任一变化都要重建卡片）
        ForEach(this.groups, (g: ReportGroup) => {
          this.groupCard(g)
        }, (g: ReportGroup) => g.key + '#' + String(g.reportCount) + '#' + g.status + '#' + String(g.targetStatus ?? -1) + '#' + (this.isAuthorBanned(g) ? 'b' : 'n') + '#' + (this.isSelected(g) ? 's' : 'n'))
        this.listFooter()
      }
      .width('100%')
    }
  }

  build() {
    Column() {
      this.topBar()
      // 上层板块（帖子/评论/用户）→ 下层状态（待处理/已成立/已驳回）：两级都在当前类目内过滤
      this.typeBar()
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
