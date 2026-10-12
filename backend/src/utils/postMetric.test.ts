import { buildPostMetricPatch, extractPostMetric } from './postMetric';

function doc(primaryBlockId: string, blocks: Array<Record<string, unknown>>): Record<string, unknown> {
  return { schemaVersion: 3, primaryBlockId, theme: 'editorial', blocks };
}

describe('extractPostMetric', () => {
  it('prefers the primary metric block over an earlier one', () => {
    const result = extractPostMetric(doc('b2', [
      { id: 'b1', type: 'metric', title: '耗时', value: '30', unit: '分钟' },
      { id: 'b2', type: 'metric', title: '推荐指数', value: '4.6', unit: '分', kind: 'score', numberValue: 4.6 },
    ]));
    expect(result).toEqual({ metricValue: 4.6, metricKind: 'score', metricLabel: '推荐指数', metricText: '4.6分' });
  });

  it('falls back to the first metric block when primary points elsewhere', () => {
    const result = extractPostMetric(doc('insight-1', [
      { id: 'm1', type: 'metric', title: '价格', value: '1,299', unit: '元' },
      { id: 'insight-1', type: 'insight', value: '值' },
    ]));
    expect(result).toEqual({ metricValue: 1299, metricKind: 'amount', metricLabel: '价格', metricText: '1,299元' });
  });

  it('does not repeat a unit already present in the display text', () => {
    const result = extractPostMetric(doc('m1', [
      { id: 'm1', type: 'metric', title: '续航', value: '约 12 小时', unit: '小时' },
    ]));
    expect(result?.metricText).toBe('约 12 小时');
  });

  it('reads numberValue ahead of the display text', () => {
    const result = extractPostMetric(doc('m1', [
      { id: 'm1', type: 'metric', title: '续航', value: '约 12 小时', unit: '小时', numberValue: 11.5 },
    ]));
    expect(result?.metricValue).toBe(11.5);
    expect(result?.metricKind).toBe('duration');
  });

  it('treats a standalone 分 as score and 分钟 as duration', () => {
    expect(extractPostMetric(doc('m1', [{ id: 'm1', type: 'metric', title: '评分', value: '4.6', unit: '分' }]))?.metricKind)
      .toBe('score');
    expect(extractPostMetric(doc('m1', [{ id: 'm1', type: 'metric', title: '耗时', value: '30', unit: '分钟' }]))?.metricKind)
      .toBe('duration');
    expect(extractPostMetric(doc('m1', [{ id: 'm1', type: 'metric', title: '好评率', value: '82', unit: '%' }]))?.metricKind)
      .toBe('percent');
  });

  it('rejects documents without a usable number', () => {
    expect(extractPostMetric(null)).toBeNull();
    expect(extractPostMetric({ blocks: 'nope' })).toBeNull();
    expect(extractPostMetric(doc('', [{ id: 'i1', type: 'insight', value: '4.6' }]))).toBeNull();
    expect(extractPostMetric(doc('', [{ id: 'm1', type: 'metric', title: '一句话', value: '还行', unit: '' }]))).toBeNull();
    expect(extractPostMetric(doc('', [{ id: 'm1', type: 'metric', value: '1e99', numberValue: Number.NaN }]))).toBeNull();
  });

  it('keeps zero distinct from missing', () => {
    expect(extractPostMetric(doc('m1', [{ id: 'm1', type: 'metric', title: '翻车次数', value: '0', unit: '次' }])))
      .toEqual({ metricValue: 0, metricKind: 'count', metricLabel: '翻车次数', metricText: '0次' });
  });

  it('truncates long labels to the column width', () => {
    const result = extractPostMetric(doc('m1', [
      { id: 'm1', type: 'metric', title: '相'.repeat(40), value: '4.6', unit: '分' },
    ]));
    expect(result?.metricLabel).toHaveLength(30);
  });

  it('nulls all four columns together so edits leave no stale metric', () => {
    expect(buildPostMetricPatch(null)).toEqual({
      metricValue: null, metricKind: null, metricLabel: null, metricText: null,
    });
    const emptyLabel = buildPostMetricPatch(doc('m1', [{ id: 'm1', type: 'metric', title: '', value: '4.6', unit: '' }]));
    expect(emptyLabel.metricLabel).toBeNull();
    expect(emptyLabel.metricText).toBe('4.6');
    expect(emptyLabel.metricValue).toBe(4.6);
  });
});
