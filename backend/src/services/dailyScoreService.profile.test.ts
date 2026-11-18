import { buildViewerProfile, computeDailyScore, emptyProfile } from './dailyScoreService';
import { prisma } from '../prisma';

jest.mock('../prisma', () => ({
  prisma: {
    userFollowTag: { findMany: jest.fn() },
    userTagPref: { findMany: jest.fn() },
    up: { findMany: jest.fn() },
    bookmark: { findMany: jest.fn() },
    comment: { findMany: jest.fn() },
    debateVote: { findMany: jest.fn() },
    postEvent: { findMany: jest.fn() },
    post: { findMany: jest.fn() },
  },
}));

const AS_OF = new Date('2026-09-11T00:00:00.000Z');
const VIEWER = 42;

function resetMocks(): void {
  jest.clearAllMocks();
  (prisma.userFollowTag.findMany as jest.Mock).mockResolvedValue([]);
  (prisma.userTagPref.findMany as jest.Mock).mockResolvedValue([]);
  (prisma.up.findMany as jest.Mock).mockResolvedValue([]);
  (prisma.bookmark.findMany as jest.Mock).mockResolvedValue([]);
  (prisma.comment.findMany as jest.Mock).mockResolvedValue([]);
  (prisma.debateVote.findMany as jest.Mock).mockResolvedValue([]);
  (prisma.postEvent.findMany as jest.Mock).mockResolvedValue([]);
  (prisma.post.findMany as jest.Mock).mockResolvedValue([]);
}

describe('buildViewerProfile · 点击信号接入', () => {
  beforeEach(resetMocks);

  it('点击帖子标签进入画像，actionCount 计入去重后的点击数', async () => {
    (prisma.postEvent.findMany as jest.Mock).mockResolvedValue([
      { postId: 10, createdAt: new Date('2026-09-10T00:00:00Z') },
      { postId: 11, createdAt: new Date('2026-09-09T00:00:00Z') },
    ]);
    (prisma.post.findMany as jest.Mock).mockResolvedValue([
      { id: 10, tags: ['数码'], userId: 100 },
      { id: 11, tags: ['旅行'], userId: 101 },
    ]);

    const profile = await buildViewerProfile(VIEWER, AS_OF);

    expect(profile.tagW.get('数码')).toBeGreaterThan(0);
    expect(profile.tagW.get('旅行')).toBeGreaterThan(0);
    expect(profile.authorW.get('100')).toBeGreaterThan(0);
    expect(profile.actionCount).toBe(2);
  });

  it('同一帖多次点击只按最新一条计入（去重防刷）', async () => {
    (prisma.postEvent.findMany as jest.Mock).mockResolvedValue([
      { postId: 10, createdAt: new Date('2026-09-01T00:00:00Z') },
      { postId: 10, createdAt: new Date('2026-09-10T00:00:00Z') },
      { postId: 10, createdAt: new Date('2026-09-05T00:00:00Z') },
    ]);
    (prisma.post.findMany as jest.Mock).mockResolvedValue([
      { id: 10, tags: ['数码'], userId: 100 },
    ]);

    const profile = await buildViewerProfile(VIEWER, AS_OF);

    expect(profile.actionCount).toBe(1);
    // 最新一条是 09-10（距今 1 天），衰减系数应 > 0.9；若误用最早一条 09-01（10 天）会明显更低
    expect(profile.tagW.get('数码')!).toBeGreaterThan(0.9);
  });

  it('postEvent 读取失败时降级：其它信号仍在，不抛异常', async () => {
    (prisma.postEvent.findMany as jest.Mock).mockRejectedValue(new Error('mock: postEvent down'));
    (prisma.userFollowTag.findMany as jest.Mock).mockResolvedValue([{ tagName: '音乐' }]);

    const profile = await buildViewerProfile(VIEWER, AS_OF);

    expect(profile.followed.has('音乐')).toBe(true);
    expect(profile.tagW.get('音乐')).toBeGreaterThan(0);
    expect(profile.actionCount).toBe(0);
  });

  it('游客（无 viewerId）不查点击表，直接空画像', async () => {
    const profile = await buildViewerProfile(undefined, AS_OF);
    expect(profile.actionCount).toBe(0);
    expect(prisma.postEvent.findMany).not.toHaveBeenCalled();
  });
});

describe('computeDailyScore · 冷启动收缩接线', () => {
  const post = { id: 1, userId: 10, tags: ['数码'], hotScore: 0 };

  it('shrunk 档（1~9 行为）：亲和被收缩，低于未收缩 profile', () => {
    const sparse = emptyProfile();
    sparse.tagW.set('数码', 25);
    sparse.actionCount = 2;
    const dense = emptyProfile();
    dense.tagW.set('数码', 25);
    dense.actionCount = 20;

    // 同为 tagW=25，2 次行为应显著收缩（亲和被压到 25*2/7），20 次基本不收缩
    expect(computeDailyScore(post, sparse, AS_OF)).toBeLessThan(computeDailyScore(post, dense, AS_OF));
  });

  it('hot 档（0 行为）：显式关注标签的亲和不被收缩', () => {
    const withFollow = emptyProfile();
    withFollow.tagW.set('数码', 6);
    withFollow.followed.add('数码');
    // actionCount=0 且 followed>0 → popular 档，亲和原样保留
    const score = computeDailyScore(post, withFollow, AS_OF);
    const baseline = computeDailyScore(post, emptyProfile(), AS_OF);
    expect(score).toBeGreaterThan(baseline);
  });

  it('高活跃（≥10 行为）：不收缩，与纯 tanh 一致', () => {
    const profile = emptyProfile();
    profile.tagW.set('数码', 5);
    profile.actionCount = 12;
    // n=12, m=5 → 若误收缩会是 5*12/17≈3.5；不收缩应等于 tanh(5/5)=tanh(1)
    const score = computeDailyScore(post, profile, AS_OF);
    expect(score).toBeCloseTo(Math.tanh(1) * 1.4, 5);
  });
});
