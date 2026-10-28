// 每日一帖推送服务单元测试（全 mock，不连库、不发消息）
// 钉住四条行为：默认干跑不发送、受众筛选规则、当日去重、上海时区触发窗口。
// mock 写法沿用仓库惯例：jest.mock 会被提升到 import 之前，工厂里不能引用外层 const，
// 因此内联 jest.fn() 再把句柄取回来用。
jest.mock('../prisma', () => ({
  prisma: {
    pushToken: { findMany: jest.fn() },
    user: { findMany: jest.fn() },
    notification: { findFirst: jest.fn() },
  },
}));
jest.mock('./postService', () => ({ listDailyPosts: jest.fn() }));
jest.mock('./notificationService', () => ({ notifySystem: jest.fn() }));

import { prisma } from '../prisma';
import { listDailyPosts } from './postService';
import { notifySystem } from './notificationService';
import { runDailyDigest, inDigestWindow, isDigestPushEnabled, DAILY_DIGEST_PREFIX } from './dailyDigestService';

type Fn = jest.Mock;   // @types/jest 全局命名空间
const mockPushToken = (prisma as unknown as { pushToken: { findMany: Fn } }).pushToken.findMany;
const mockUser = (prisma as unknown as { user: { findMany: Fn } }).user.findMany;
const mockNotifFirst = (prisma as unknown as { notification: { findFirst: Fn } }).notification.findFirst;
const mockListDailyPosts = listDailyPosts as unknown as Fn;
const mockNotifySystem = notifySystem as unknown as Fn;

beforeEach(() => {
  mockPushToken.mockClear(); mockUser.mockClear(); mockNotifFirst.mockClear();
  mockListDailyPosts.mockClear(); mockNotifySystem.mockClear();
  mockListDailyPosts.mockResolvedValue([{ id: 410, title: '数据挖掘', content: '一段正文', userId: 40, metricValue: null }]);
  mockPushToken.mockResolvedValue([{ userId: 1 }, { userId: 2 }, { userId: 3 }, { userId: 4 }]);
  mockUser.mockResolvedValue([
    { id: 1, openId: 'AABreal', unionID: null },
    { id: 2, openId: 'seed_coldstart_7', unionID: null },   // 种子号，应排除
    { id: 3, openId: null, unionID: 'AABreal3' },
    { id: 4, openId: null, unionID: null },                  // 无账号标识，按真实用户保留
  ]);
  mockNotifFirst.mockResolvedValue(null);                     // 默认今天没发过
});

const SHANGHAI_NOON = new Date('2026-11-05T04:00:00Z');   // 上海 12:00
const SHANGHAI_MORNING = new Date('2026-11-05T01:45:00Z'); // 上海 09:45（窗口内）

beforeEach(() => {
  jest.clearAllMocks();
  mockListDailyPosts.mockResolvedValue([{ id: 410, title: '数据挖掘', content: '一段正文', userId: 40, metricValue: null }]);
  mockPushToken.mockResolvedValue([{ userId: 1 }, { userId: 2 }, { userId: 3 }, { userId: 4 }]);
  mockUser.mockResolvedValue([
    { id: 1, openId: 'AABreal', unionID: null },
    { id: 2, openId: 'seed_coldstart_7', unionID: null },   // 种子号，应排除
    { id: 3, openId: null, unionID: 'AABreal3' },
    { id: 4, openId: null, unionID: null },                  // 无账号标识，按真实用户保留
  ]);
  mockNotifFirst.mockResolvedValue(null); // 默认今天没发过
});

describe('runDailyDigest', () => {
  it('缺省是干跑：只回受众与排队数，不调用 notifySystem', async () => {
    const r = await runDailyDigest({ at: SHANGHAI_NOON });
    expect(r.dryRun).toBe(true);
    expect(r.date).toBe('2026-11-05');
    expect(r.postId).toBe(410);
    expect(r.audience).toBe(3);       // 排除 seed 后剩 1/3/4
    expect(r.queued).toBe(3);
    expect(mockNotifySystem).not.toHaveBeenCalled();
  });

  it('dryRun:false 才真正下发，且文案带前缀、带 postId', async () => {
    const r = await runDailyDigest({ dryRun: false, at: SHANGHAI_NOON });
    expect(r.queued).toBe(3);
    expect(mockNotifySystem).toHaveBeenCalledTimes(3);
    const [userId, content, postId] = mockNotifySystem.mock.calls[0];
    expect(userId).toBe(1);
    expect(postId).toBe(410);
    expect(String(content).startsWith(DAILY_DIGEST_PREFIX)).toBe(true);
    expect(String(content)).toContain('《数据挖掘》');
  });

  it('当天已发过的用户被去重跳过，不重复打扰', async () => {
    mockNotifFirst.mockImplementation((arg: { where: { userId: number } }) =>
      Promise.resolve(arg.where.userId === 3 ? { id: 99 } : null));
    const r = await runDailyDigest({ dryRun: false, at: SHANGHAI_NOON });
    expect(r.dupSkipped).toBe(1);
    expect(r.queued).toBe(2);
    expect(mockNotifySystem).toHaveBeenCalledTimes(2);
  });

  it('limit 只截断受众，不影响受众统计口径', async () => {
    const r = await runDailyDigest({ limit: 1, at: SHANGHAI_NOON });
    expect(r.audience).toBe(3);
    expect(r.queued).toBe(1);
  });

  it('没有任何 push token 时安全返回 0 且不发送', async () => {
    // 注：选帖阶段会查一次 user（取种子 id 集合），所以这里不能断言「没查用户表」
    mockPushToken.mockResolvedValue([]);
    const r = await runDailyDigest({ dryRun: false, at: SHANGHAI_NOON });
    expect(r.audience).toBe(0);
    expect(r.queued).toBe(0);
    expect(mockNotifySystem).not.toHaveBeenCalled();
  });

  it('每日一帖选不到帖子时不发送', async () => {
    mockListDailyPosts.mockResolvedValue([]);
    const r = await runDailyDigest({ dryRun: false, at: SHANGHAI_NOON });
    expect(r.postId).toBeNull();
    expect(mockNotifySystem).not.toHaveBeenCalled();
  });
});

describe('选帖：宁可不推也不推伪造亲历', () => {
  it('候选全部来自种子账号时当天跳过，且不查受众、不发送', async () => {
    mockListDailyPosts.mockResolvedValue([
      { id: 1, title: '修了十二年车', content: 'x', userId: 2, metricValue: 5 },
      { id: 2, title: '搬过五次家', content: 'y', userId: 173, metricValue: 3 },
    ]);
    // userId=2 与 173 在 mock 的 user 查询里不是 seed 前缀，这里显式让种子集合命中
    mockUser.mockResolvedValue([
      { id: 1, openId: 'AABreal', unionID: null },
      { id: 2, openId: 'seed_coldstart_1', unionID: null },
      { id: 3, openId: 'AABreal3', unionID: null },
      { id: 4, openId: null, unionID: null },
      { id: 173, openId: 'seed_coldstart_9', unionID: null },
    ]);
    const r = await runDailyDigest({ dryRun: false, at: SHANGHAI_NOON });
    expect(r.postId).toBeNull();
    expect(r.reason).toContain('种子或示例内容');
    expect(mockNotifySystem).not.toHaveBeenCalled();
  });

  it('归队后作者变成官方账号，但正文带「示例内容」声明照样被排除', async () => {
    // 这正是 seed-rehome.sql 跑完后的状态：userId 不再是 seed 前缀，只剩正文标记可判
    mockListDailyPosts.mockResolvedValue([
      { id: 800, title: '装了二十年空调', content: '> 示例内容 · 编辑部整理。非当事人亲历\n正文', userId: 40, metricValue: 9 },
    ]);
    const r = await runDailyDigest({ dryRun: false, at: SHANGHAI_NOON });
    expect(r.postId).toBeNull();
    expect(r.reason).toContain('示例内容');
    expect(mockNotifySystem).not.toHaveBeenCalled();
  });

  it('有真实内容时优先选带主数字的结构化帖', async () => {
    mockListDailyPosts.mockResolvedValue([
      { id: 700, title: '普通帖', content: 'a', userId: 40, metricValue: null },
      { id: 701, title: '踩坑金额 2800 元', content: 'b', userId: 40, metricValue: 2800 },
    ]);
    const r = await runDailyDigest({ at: SHANGHAI_NOON });
    expect(r.postId).toBe(701);
    expect(r.reason).toBe('结构化内容优先');
  });

  it('真实内容但没有主数字时退到首条，并在 reason 里说明', async () => {
    mockListDailyPosts.mockResolvedValue([{ id: 702, title: '没有数字的帖', content: 'c', userId: 40 }]);
    const r = await runDailyDigest({ at: SHANGHAI_NOON });
    expect(r.postId).toBe(702);
    expect(r.reason).toContain('无主数字');
  });
});

describe('inDigestWindow / 开关', () => {
  it('上海 09:45 在窗口内，12:00 不在', () => {
    expect(inDigestWindow(SHANGHAI_MORNING)).toBe(true);
    expect(inDigestWindow(SHANGHAI_NOON)).toBe(false);
  });

  it('推送开关默认关闭（未设环境变量时不会自动给真机发消息）', () => {
    const saved = process.env.DAILY_DIGEST_PUSH;
    delete process.env.DAILY_DIGEST_PUSH;
    expect(isDigestPushEnabled()).toBe(false);
    process.env.DAILY_DIGEST_PUSH = 'on';
    expect(isDigestPushEnabled()).toBe(true);
    if (saved === undefined) {
      delete process.env.DAILY_DIGEST_PUSH;
    } else {
      process.env.DAILY_DIGEST_PUSH = saved;
    }
  });
});
