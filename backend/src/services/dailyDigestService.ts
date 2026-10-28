import { prisma } from '../prisma';
import { notifySystem } from './notificationService';
import { listDailyPosts } from './postService';

// 只用到这三个字段；postService 返回的是 Prisma 帖子视图，避免引入不存在的类型路径
interface DailyPick {
  id: number;
  title?: string | null;
  content?: string | null;
}

// 每日一帖推送（运营侧的日活引擎）
//
// 为什么要它：激励计划按「去重活跃设备」计月活，而实测约 211 台设备在用 App、
// 库里只有 57 个 PushToken —— 已注册设备是**唯一能主动召回的存量**。
// 站内本来就有「每日一帖」，但后端没有任何定时推送，这条召回通道一直空着。
//
// 实现取向：全部复用现成件，零表结构变更、零客户端发版。
//   - 选帖：postService.listDailyPosts（按上海日期稳定轮换，未登录视角=全局兜底）
//   - 落库+推送：notificationService.notifySystem → createNotification
//       · 已按 NotificationPreference 门控（用户关了系统通知则静默跳过）
//       · 已带 data.postId，点击直达详情页而不是只开首页
//   - 去重：当天已发过同前缀系统通知则跳过（所以重复调用是安全的）
//
// 频控与合规：每人每日最多 1 条运营推送（华为未申请自分类权益时单设备每日限 2 条，
// 本通道占 1 条）；关闭入口沿用「设置 → 通知偏好」的 system 开关，无需新增。
//
// 开关：环境变量 DAILY_DIGEST_PUSH=on 才会被 index.ts 的定时器自动触发；
//       默认关闭 —— 给真人手机发东西需要运营明确开启。
// 手动：POST /v1/admin/daily-digest  body {"dryRun":true,"limit":5}
//       dryRun 缺省为 true，只算不发，便于先看受众规模。

export const DAILY_DIGEST_PREFIX: string = '每日一帖：';
export const DAILY_DIGEST_HOUR: number = 9;      // 上海时间 09:30 触发
export const DAILY_DIGEST_MINUTE: number = 30;

export interface DigestOptions {
  dryRun?: boolean;
  limit?: number;
  at?: Date;
}

export interface DigestResult {
  date: string;
  postId: number | null;
  postTitle: string;
  audience: number;
  dupSkipped: number;
  queued: number;
  dryRun: boolean;
}

// 上海时区的 YYYY-MM-DD 与当日 00:00 对应的 UTC 时刻
function shanghaiDate(d: Date): string {
  return new Intl.DateTimeFormat('en-CA', {
    timeZone: 'Asia/Shanghai', year: 'numeric', month: '2-digit', day: '2-digit',
  }).format(d);
}

function shanghaiDayStart(d: Date): Date {
  return new Date(`${shanghaiDate(d)}T00:00:00+08:00`);
}

// listDailyPosts 的返回在路由层直接透传给客户端，这里只取第一条且兼容两种形态
function firstDailyPost(rows: unknown): DailyPick | null {
  if (Array.isArray(rows)) {
    return (rows[0] as DailyPick) ?? null;
  }
  const wrapped = rows as { list?: DailyPick[] } | null;
  return (wrapped && Array.isArray(wrapped.list) ? wrapped.list[0] : null) ?? null;
}

function digestContent(title: string, excerpt: string): string {
  const t = title.trim().length > 0 ? title.trim() : '一条真实经验';
  const e = excerpt.replace(/\s+/g, ' ').trim().slice(0, 60);
  // Notification.content 是 VarChar(255)，留足余量
  return `${DAILY_DIGEST_PREFIX}《${t.slice(0, 60)}》${e}`.slice(0, 200);
}

// 受众：有 PushToken（否则推不到）、账号未注销未封禁、排除 seed 种子账号
async function resolveAudience(): Promise<number[]> {
  const tokens = await prisma.pushToken.findMany({ select: { userId: true }, distinct: ['userId'] });
  const ids: number[] = tokens.map((t: { userId: number }): number => t.userId);
  if (ids.length === 0) {
    return [];
  }
  const users = await prisma.user.findMany({
    where: { id: { in: ids }, deletedAt: null, status: 1 },
    select: { id: true, openId: true, unionID: true },
  });
  return users
    .filter((u: { id: number; openId: string | null; unionID: string | null }): boolean => {
      const acct: string = (u.openId ?? u.unionID ?? '');
      return acct.slice(0, 4) !== 'seed';
    })
    .map((u: { id: number }): number => u.id);
}

export async function runDailyDigest(opts: DigestOptions = {}): Promise<DigestResult> {
  const dryRun: boolean = opts.dryRun !== false;      // 缺省干跑
  const at: Date = opts.at ?? new Date();
  const date: string = shanghaiDate(at);
  const dayStart: Date = shanghaiDayStart(at);

  const rows = await listDailyPosts({ limit: 1 });
  const pick: DailyPick | null = firstDailyPost(rows);
  if (pick === null || pick === undefined) {
    return { date, postId: null, postTitle: '', audience: 0, dupSkipped: 0, queued: 0, dryRun };
  }

  const audience: number[] = await resolveAudience();
  const capped: number[] = typeof opts.limit === 'number' && opts.limit > 0 ? audience.slice(0, opts.limit) : audience;
  const content: string = digestContent(pick.title ?? '', pick.content ?? '');

  let dupSkipped: number = 0;
  let queued: number = 0;
  for (const userId of capped) {
    const dup = await prisma.notification.findFirst({
      where: { userId, type: 'system', createdAt: { gte: dayStart }, content: { startsWith: DAILY_DIGEST_PREFIX } },
      select: { id: true },
    });
    if (dup !== null) {
      dupSkipped++;
      continue;
    }
    if (dryRun) {
      queued++;
      continue;
    }
    // notifySystem 内部会按通知偏好静默跳过关闭者，因此 queued 是「计划数」而非「实收数」
    await notifySystem(userId, content, pick.id);
    queued++;
  }

  return { date, postId: pick.id ?? null, postTitle: pick.title ?? '', audience: audience.length, dupSkipped, queued, dryRun };
}

// 是否处于触发窗口（上海时间 09:30–10:00）；配合 30 分钟一轮的定时器 + 当日去重，
// 既不会漏发也不会重发。
export function inDigestWindow(at: Date = new Date()): boolean {
  const parts = new Intl.DateTimeFormat('en-GB', {
    timeZone: 'Asia/Shanghai', hour: '2-digit', minute: '2-digit', hour12: false,
  }).format(at).split(':');
  const h: number = Number(parts[0]);
  const m: number = Number(parts[1]);
  return h === DAILY_DIGEST_HOUR && m >= DAILY_DIGEST_MINUTE;
}

export function isDigestPushEnabled(): boolean {
  return (process.env.DAILY_DIGEST_PUSH ?? '').trim().toLowerCase() === 'on';
}
