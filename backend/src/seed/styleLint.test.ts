import { findStyleViolations, densityWarnings, sentenceLengthSpread } from './styleLint';

describe('findStyleViolations', () => {
  it('挡住中文冒号与破折号', () => {
    const hits = findStyleViolations('结论：这个壳值一百二。用了三个月——还行。');
    const rules = hits.map((hit) => hit.rule);
    expect(rules).toContain('中文冒号');
    expect(rules).toContain('破折号');
  });

  it('挡住翻案句与路标词', () => {
    const hits = findStyleViolations('这不是省钱，而是省心。首先，壳要薄。');
    const rules = hits.map((hit) => hit.rule);
    expect(rules).toContain('翻案句-不是而是');
    expect(rules).toContain('路标词-首先');
  });

  it('挡住商业黑话', () => {
    const hits = findStyleViolations('这套方案能赋能一线，形成闭环。');
    expect(hits.some((hit) => hit.rule === '黑话-商业')).toBe(true);
  });

  it('放行正常口语', () => {
    const hits = findStyleViolations('换了三次壳，最后留下的还是原厂那个。边角磨白了一点，无所谓。');
    expect(hits.filter((hit) => hit.severity === 'hard')).toHaveLength(0);
  });
});

describe('densityWarnings', () => {
  it('短文本出现一次不算问题', () => {
    expect(densityWarnings('其实还行。')).toHaveLength(0);
  });

  it('长文本里堆叠才算问题', () => {
    const text = '其实'.repeat(6) + '这段文字长度并不算长，'.repeat(4);
    expect(densityWarnings(text).length).toBeGreaterThan(0);
  });
});

describe('sentenceLengthSpread', () => {
  it('长短交错时标准差更大', () => {
    const mixed = '换了三次壳。最后留下的还是原厂那个，因为它薄，按键也不顶手。三个月。';
    const flat = '我买了一个壳。我用了一个月。我觉得还可以。我没换过别的。';
    expect(sentenceLengthSpread(mixed).stdDev).toBeGreaterThan(sentenceLengthSpread(flat).stdDev);
  });
});
