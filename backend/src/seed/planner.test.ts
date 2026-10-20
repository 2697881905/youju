import { planContent, plannedMediaKeys } from './planner';
import { LoadedContent, SeedPostRecord } from './types';

const NOW = new Date('2026-10-21T10:00:00+08:00');

const REVIEW: SeedPostRecord = {
  id: 'shuma-0001',
  author: 'laozhang',
  genre: 'review',
  title: '换了三次手机壳，最后留下的还是原厂那个',
  content: '壳这东西，薄一点就像没戴，代价是摔一次就心疼。我前后换了三次。'.repeat(3),
  tags: ['手机数码'],
  tier: 'solid',
  ageHours: 40,
  insight: '薄和防摔只能挑一个。',
  structured: { pros: '薄', cons: '贵', rating: 4.2, targetAudience: '不喜欢厚重手感的人' },
  comments: [
    { author: 'laozhang', text: '补充一句，原厂壳的按键是独立的。', offsetMinutes: 30 },
    { author: 'laozhang', text: '再补一句，边角确实容易磨白。', offsetMinutes: 60, replyToIndex: 0 },
  ],
};

const SHARE: SeedPostRecord = {
  id: 'shuma-0002',
  author: 'laozhang',
  genre: 'share',
  title: '地铁上看见有人用折叠屏看文档',
  content: '今天早高峰，对面大哥把折叠屏摊开看表格，字小得我隔着过道都替他累。'.repeat(3),
  tags: ['手机数码'],
  tier: 'normal',
  ageHours: 200,
};

const CONTENT: LoadedContent = {
  authors: [
    { slug: 'laozhang', nickname: '老张不加班', bio: '换过七台手机', gender: 1, circles: ['手机数码'], avatarColor: '#2F3A45' },
  ],
  posts: [REVIEW, SHARE],
  circleOfPost: new Map([['shuma-0001', '手机数码'], ['shuma-0002', '手机数码']]),
};

describe('planContent', () => {
  it('同一时刻、同一输入，结果完全一致', () => {
    const a = planContent(CONTENT, NOW);
    const b = planContent(CONTENT, NOW);
    expect(a.map((item) => item.hotScore)).toEqual(b.map((item) => item.hotScore));
    expect(a.map((item) => item.createdAt.toISOString())).toEqual(b.map((item) => item.createdAt.toISOString()));
    expect(a.map((item) => item.ups)).toEqual(b.map((item) => item.ups));
  });

  it('发布时间都在导入时刻之前', () => {
    for (const item of planContent(CONTENT, NOW)) {
      expect(item.createdAt.getTime()).toBeLessThan(NOW.getTime());
      expect(item.updatedAt.getTime()).toBe(item.createdAt.getTime());
    }
  });

  it('评论时间在发帖之后、导入之前', () => {
    const [review] = planContent(CONTENT, NOW);
    for (const comment of review.comments) {
      expect(comment.createdAt.getTime()).toBeGreaterThan(review.createdAt.getTime());
      expect(comment.createdAt.getTime()).toBeLessThan(NOW.getTime());
    }
  });

  it('测评有主数字，分享没有结构化文档', () => {
    const [review, share] = planContent(CONTENT, NOW);
    expect(review.derived.metric.metricValue).toBeCloseTo(4.2);
    expect(review.derived.metric.metricKind).toBe('score');
    expect(share.derived.structuredDocument).toBeNull();
    expect(share.derived.metric.metricValue).toBeNull();
  });

  it('封面 key 形如 cos://posts/seed/<id>.jpg', () => {
    const keys = plannedMediaKeys(planContent(CONTENT, NOW));
    expect(keys.length).toBeGreaterThan(0);
    for (const key of keys) {
      expect(key).toMatch(/^posts\/seed\/[a-z]+-\d{4}\.jpg$/);
    }
  });
});
