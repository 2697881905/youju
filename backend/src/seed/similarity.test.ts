import { findSimilarPairs, jaccard, trigramSet } from './similarity';

describe('trigramSet', () => {
  it('忽略标点与空白', () => {
    const a = trigramSet('换了三次壳，最后留下原厂。');
    const b = trigramSet('换了三次壳 最后留下原厂');
    expect(jaccard(a, b)).toBeGreaterThan(0.9);
  });
});

describe('findSimilarPairs', () => {
  it('同义改写能命中', () => {
    const text = '我换了三次手机壳，最后留下的还是原厂那个。它薄，按键不顶手，边角也不割。';
    const hits = findSimilarPairs([
      { id: 'a', text },
      { id: 'b', text: '我换了三次手机壳，最后留下的还是原厂那个。它薄，按键不顶手，边角不割手。' },
    ]);
    expect(hits).toHaveLength(1);
    expect(hits[0].severity).toBe('hard');
  });

  it('不同主题不误报', () => {
    const hits = findSimilarPairs([
      { id: 'a', text: '装修水电改造时，强弱电不能同槽，间距留三十厘米以上，后期网速才稳。' },
      { id: 'b', text: '猫粮换粮要七天过渡，前三天新旧各一半，第三天开始按比例加新粮。' },
    ]);
    expect(hits).toHaveLength(0);
  });
});
