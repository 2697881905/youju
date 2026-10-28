import { prisma } from '../prisma';
import { notifySystem } from './notificationService';
import { listDailyPosts } from './postService';

// 只用到这三个字段；postService 返回的是 Prisma 帖子视图，避免引入不存在的类型路径
interface DailyPick {
  id: number;
  title?: string | null;
  content?: string | null;
  userId?: number;
  metricValue?: number | null;
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

// 示例内容标记：与 scripts/seed-rehome.sql 里写进正文头部的声明**必须逐字一致**，
// 否则归队后（331 篇改挂到非种子的官方账号 id=40）这一层过滤会整体失效、又把伪造亲历推出去。
export const EXEMPLAR_MARKER: string = '示例内容 · 编辑部整理';
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
  /** 选不到合规内容时的原因（宁可不推，也不把伪造亲历推到人手机上） */
  reason: string;
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

// listDailyPosts 的返回在路由层直接透传给客户端，这里兼容数组与 {list} 两种形态
function firstDailyList(rows: unknown): DailyPick[] {
  if (Array.isArray(rows)) {
    return rows as DailyPick[];
  }
  const wrapped = rows as { list?: DailyPick[] } | null;
  return wrapped && Array.isArray(wrapped.list) ? wrapped.list : [];
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

// 选帖：宁可当天不推，也不推伪造亲历的内容。
//   1) 候选取当日轮换的前 20 条（listDailyPosts 按上海日期稳定排序）
//   2) 剔除 seed_coldstart 种子账号的帖子（库里 94% 内容是脚本造的示例，
//      标题是「修了十二年车」这类第一人称亲历 —— 推给用户等于把假经验当推荐发出去）
//   3) 剩下的里面优先带「主数字」的结构化帖（metricValue 非空），那才是本产品的差异化
//   4) 一条都没有 → 返回原因，当天跳过（等内容归队/编辑部产出后自然就有）
async function pickDigestPost(): Promise<{ post: DailyPick | null; reason: string }> {
  const rows = await listDailyPosts({ limit: 20 });
  const list = firstDailyList(rows);
  if (list.length === 0) {
    return { post: null, reason: '每日一帖候选为空' };
  }
  const seeds = await prisma.user.findMany({
    where: { OR: [{ openId: { startsWith: 'seed' } }, { unionID: { startsWith: 'seed' } }] },
    select: { id: true },
  });
  const seedIds = new Set<number>(seeds.map((u: { id: number }): number => u.id));
  // 两道排除：① 作者仍是 seed 账号；② 正文带「示例内容」声明（归队后作者会变成官方账号，
  // 只靠①会漏，所以标记必须独立判一次）
  // 归队 SQL 写进正文的是「> 示例内容 · 编辑部整理…」（带 markdown 引用符号），
  // 所以不能用 startsWith 判裸标记——那样在真实数据上会静默失效（单测抓到的就是这个）。
  // 取正文前 40 字判包含：足够覆盖引用符号与前导空白，又不会误伤正文中间偶然提到这句话的帖子。
  const isExemplar = (p: DailyPick): boolean => (p.content ?? '').slice(0, 40).includes(EXEMPLAR_MARKER);
  const real = list.filter((p: DailyPick): boolean =>
    (p.userId === undefined || !seedIds.has(p.userId)) && !isExemplar(p));
  if (real.length === 0) {
    return { post: null, reason: `候选 ${list.length} 条全部是种子或示例内容，已跳过（先补编辑部真实产出）` };
  }
  const structured = real.filter((p: DailyPick): boolean => typeof p.metricValue === 'number' && p.metricValue !== null);
  const post = structured.length > 0 ? structured[0] : real[0];
  return { post, reason: structured.length > 0 ? '结构化内容优先' : '无主数字内容，取首条真实内容' };
}

export async function runDailyDigest(opts: DigestOptions = {}): Promise<DigestResult> {
  const dryRun: boolean = opts.dryRun !== false;      // 缺省干跑
  const at: Date = opts.at ?? new Date();
  const date: string = shanghaiDate(at);
  const dayStart: Date = shanghaiDayStart(at);

  const picked = await pickDigestPost();
  if (picked.post === null) {
    return { date, postId: null, reason: picked.reason, postTitle: '', audience: 0, dupSkipped: 0, queued: 0, dryRun };
  }
  const pick: DailyPick = picked.post;

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

  return { date, postId: pick.id ?? null, reason: picked.reason, postTitle: pick.title ?? '', audience: audience.length, dupSkipped, queued, dryRun };
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
