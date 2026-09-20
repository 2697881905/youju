import { validateStructuredDocument } from './structuredDocument';

function metricDocument() {
  return {
    schemaVersion: 2,
    primaryBlockId: 'metric_1',
    theme: 'editorial',
    blocks: [{
      id: 'metric_1', type: 'metric', title: '推荐指数', value: '4.8', unit: '/ 5', helper: '',
      items: [], leftLabel: '', leftValue: '', rightLabel: '', rightValue: '',
    }],
  };
}

describe('validateStructuredDocument', () => {
  it('accepts an absent or valid V2 document', () => {
    expect(validateStructuredDocument(undefined)).toBeNull();
    expect(validateStructuredDocument(null)).toBeNull();
    expect(validateStructuredDocument(metricDocument())).toBeNull();
  });

  it('rejects unknown schema and fields', () => {
    expect(validateStructuredDocument({ ...metricDocument(), schemaVersion: 3 }))
      .toBe('结构化信息流版本无效');
    expect(validateStructuredDocument({ ...metricDocument(), extra: true }))
      .toBe('结构化信息流包含未知字段：extra');
  });

  it('requires the primary block to exist and ids to be unique', () => {
    expect(validateStructuredDocument({ ...metricDocument(), primaryBlockId: 'missing' }))
      .toBe('主视觉块不存在');
    const doc = metricDocument();
    doc.blocks.push({ ...doc.blocks[0] });
    expect(validateStructuredDocument(doc)).toBe('信息块 ID 不能重复');
  });

  it('checks content rules for each block type', () => {
    const doc = metricDocument();
    doc.blocks[0].value = '';
    expect(validateStructuredDocument(doc)).toBe('数字块缺少数值');

    const list = metricDocument();
    list.blocks[0].type = 'list';
    list.blocks[0].value = '';
    expect(validateStructuredDocument(list)).toBe('清单块至少需要一项');
  });

  it('limits block count and item lengths', () => {
    const doc = metricDocument();
    doc.blocks = new Array(9).fill(null).map((_, index) => ({
      ...doc.blocks[0], id: 'metric_' + index,
    }));
    doc.primaryBlockId = 'metric_0';
    expect(validateStructuredDocument(doc)).toBe('结构化信息块最多 8 个');
  });
});
