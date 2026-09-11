import {
  coldStartChain,
  computeDailyScore,
  emptyProfile,
  rankPostsByDailyScore,
  shanghaiDayStart,
  shrinkAffinity,
} from './dailyScoreService';

const AS_OF = new Date('2026-09-11T00:00:00.000Z');

describe('dailyScoreService', () => {
  describe('shanghaiDayStart', () => {
    it('返回当日上海零点（UTC 前一日 16:00）', () => {
      // 2026-09-11T00:00Z = 北京时间 09-11 08:00 → 当日上海零点为 09-10T16:00Z
      expect(shanghaiDayStart(new Date('2026-09-11T00:00:00.000Z')).toISOString())
        .toBe('2026-09-10T16:00:00.000Z');
    });

    it('跨日边界：UTC 15:59 仍属前一上海日', () => {
      // 2026-09-10T15:59Z = 北京 09-10 23:59 → 当日上海零点为 09-09T16:00Z
      expect(shanghaiDayStart(new Date('2026-09-10T15:59:00.000Z')).toISOString())
        .toBe('2026-09-09T16:00:00.000Z');
    });
  });

  describe('computeDailyScore', () => {
    it('命中偏好标签的帖子分数更高', () => {
      const profile = emptyProfile();
      profile.tagW.set('数码', 6);

      const matched = computeDailyScore({ id: 1, userId: 10, tags: ['数码'] }, profile, AS_OF);
      const other = computeDailyScore({ id: 2, userId: 11, tags: ['旅行'] }, profile, AS_OF);

      expect(matched).toBeGreaterThan(other);
    });

    it('负反馈标签会拉低分数', () => {
      const profile = emptyProfile();
      profile.negTags.add('职场');

      const penalized = computeDailyScore({ id: 3, userId: 12, tags: ['职场'] }, profile, AS_OF);
      const normal = computeDailyScore({ id: 4, userId: 13, tags: ['旅行'] }, profile, AS_OF);

      expect(penalized).toBeLessThan(normal);
    });

    it('全局热度参与打分：热度高的帖子分数更高', () => {
      const hot = computeDailyScore({ id: 5, userId: 14, tags: [], hotScore: 60 }, emptyProfile(), AS_OF);
      const cold = computeDailyScore({ id: 6, userId: 15, tags: [], hotScore: 0 }, emptyProfile(), AS_OF);

      expect(hot).toBeGreaterThan(cold);
    });

    it('字段缺失（无 createdAt / 无 tags / 无 hotScore）不产生 NaN', () => {
      const score = computeDailyScore({ id: 7, userId: 16 }, emptyProfile(), AS_OF);
      expect(Number.isFinite(score)).toBe(true);
    });

    it('同输入同分数（日内可复现 → 分页稳定）', () => {
      const profile = emptyProfile();
      profile.tagW.set('数码', 6);
      const post = { id: 8, userId: 17, tags: ['数码'], hotScore: 12 };

      expect(computeDailyScore(post, profile, AS_OF)).toBe(computeDailyScore(post, profile, AS_OF));
    });
  });

  describe('rankPostsByDailyScore', () => {
    it('亲和高的帖子排在前面', () => {
      const profile = emptyProfile();
      profile.tagW.set('旅行', 6);
      const rows = [
        { id: 1, userId: 101, tags: ['职场'] },
        { id: 2, userId: 102, tags: ['旅行'] },
      ];

      expect(rankPostsByDailyScore(rows, profile, AS_OF).map((post) => post.id)).toEqual([2, 1]);
    });

    it('同分保持原序，且多次调用结果一致（可复现）', () => {
      const rows = [
        { id: 5, userId: 101, tags: ['a'] },
        { id: 6, userId: 102, tags: ['b'] },
        { id: 7, userId: 103, tags: ['c'] },
      ];

      const first = rankPostsByDailyScore(rows, emptyProfile(), AS_OF).map((post) => post.id);
      const again = rankPostsByDailyScore(rows, emptyProfile(), AS_OF).map((post) => post.id);

      expect(first).toEqual([5, 6, 7]);
      expect(again).toEqual(first);
    });

    it('负反馈标签的帖子被排到后面', () => {
      const profile = emptyProfile();
      profile.negTags.add('职场');
      const rows = [
        { id: 1, userId: 101, tags: ['职场'] },
        { id: 2, userId: 102, tags: ['旅行'] },
      ];

      expect(rankPostsByDailyScore(rows, profile, AS_OF).map((post) => post.id)).toEqual([2, 1]);
    });
  });

  describe('coldStartChain', () => {
    it('全冷（无行为无标签）退化为全局热度', () => {
      expect(coldStartChain(emptyProfile(), 0)).toBe('hot');
    });

    it('有显式标签但无行为 → 走热门标签', () => {
      expect(coldStartChain(emptyProfile(), 3)).toBe('popular');
    });

    it('行为稀疏 → 贝叶斯收缩', () => {
      const profile = emptyProfile();
      profile.actionCount = 3;
      expect(coldStartChain(profile, 0)).toBe('shrunk');
    });

    it('行为充足 → 完全个性化', () => {
      const profile = emptyProfile();
      profile.actionCount = 12;
      expect(coldStartChain(profile, 0)).toBe('personalized');
    });
  });

  describe('shrinkAffinity', () => {
    it('无行为时完全向大盘收缩', () => {
      expect(shrinkAffinity(100, 10, 0)).toBe(10);
    });

    it('行为越多越接近自身值', () => {
      const few = shrinkAffinity(100, 10, 1);
      const many = shrinkAffinity(100, 10, 50);
      expect(many).toBeGreaterThan(few);
      expect(many).toBeLessThan(100);
    });
  });
});
