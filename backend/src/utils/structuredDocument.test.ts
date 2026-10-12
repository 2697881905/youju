import { validateStructuredDocument, normalizeStructuredDocumentMedia } from './structuredDocument';

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
    expect(validateStructuredDocument({ ...metricDocument(), schemaVersion: 1 }))
      .toBe('结构化信息流版本无效');
    expect(validateStructuredDocument({ ...metricDocument(), schemaVersion: 4 }))
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

describe('V3 evidence and typed metric', () => {
  function v3(blockExtras: Record<string, unknown>) {
    const doc = metricDocument();
    doc.schemaVersion = 3;
    doc.blocks[0] = { ...doc.blocks[0], ...blockExtras };
    return doc;
  }

  it('still accepts a V2 shaped document and a V3 document without new slots', () => {
    expect(validateStructuredDocument(metricDocument())).toBeNull();
    expect(validateStructuredDocument(v3({}))).toBeNull();
  });

  it('accepts an image evidence entry pointing at the upload system', () => {
    expect(validateStructuredDocument(v3({
      evidence: [{ type: 'image', ref: 'cos://posts/2026/10/a.jpg', note: '实测续航 7h12m' }],
    }))).toBeNull();
  });

  it('accepts a source evidence entry with plain text or an http link', () => {
    expect(validateStructuredDocument(v3({
      evidence: [{ type: 'source', ref: '官方规格页 https://example.com/spec', note: '' }],
    }))).toBeNull();
    expect(validateStructuredDocument(v3({
      evidence: [{ type: 'source', ref: '京东订单 2026-10-01' }],
    }))).toBeNull();
  });

  it('rejects an external image reference: it would be auto-fetched by viewers', () => {
    expect(validateStructuredDocument(v3({
      evidence: [{ type: 'image', ref: 'https://evil.example.com/track.gif' }],
    }))).toBe('证据图片引用无效');
  });

  it('rejects pseudo-protocol links without breaking plain source text', () => {
    expect(validateStructuredDocument(v3({
      evidence: [{ type: 'source', ref: 'javascript:alert(1)//' }],
    }))).toBe('证据内容不支持该协议：javascript:');
    expect(validateStructuredDocument(v3({
      evidence: [{ type: 'source', ref: 'Data:text/html;base64,AAAA' }],
    }))).toBe('证据内容不支持该协议：data:');
    expect(validateStructuredDocument(v3({
      evidence: [{ type: 'source', ref: 'ftp://files.example.com/a.pdf' }],
    }))).toBe('证据链接仅支持 http 或 https');
    // 含冒号但并非协议出处文本，必须照常通过
    expect(validateStructuredDocument(v3({
      evidence: [{ type: 'source', ref: 'Note: 说明书第 3 页' }],
    }))).toBeNull();
  });

  it('rejects unknown evidence keys, types and over-length notes', () => {
    expect(validateStructuredDocument(v3({
      evidence: [{ type: 'image', ref: 'cos://posts/a.jpg', extra: 1 }],
    }))).toBe('证据包含未知字段：extra');
    expect(validateStructuredDocument(v3({
      evidence: [{ type: 'video', ref: 'cos://posts/a.jpg' }],
    }))).toBe('证据类型无效');
    expect(validateStructuredDocument(v3({
      evidence: [{ type: 'source', ref: '出处', note: 'x'.repeat(61) }],
    }))).toBe('证据说明最多 60 字');
  });

  it('limits evidence per block', () => {
    const evidence = new Array(7).fill(null).map(() => ({ type: 'source', ref: '出处' }));
    expect(validateStructuredDocument(v3({ evidence }))).toBe('每个信息块最多 6 条证据');
  });

  it('keeps kind and numberValue metric-only and well formed', () => {
    expect(validateStructuredDocument(v3({ kind: 'score', numberValue: 4.8 }))).toBeNull();
    expect(validateStructuredDocument(v3({ kind: 'nonsense' }))).toBe('数值类型无效');
    expect(validateStructuredDocument(v3({ numberValue: '4.8' }))).toBe('规范数值需为有限数字');
    expect(validateStructuredDocument(v3({ numberValue: Infinity }))).toBe('规范数值需为有限数字');
    const insight = v3({ value: '结论' });
    insight.blocks[0].type = 'insight';
    (insight.blocks[0] as Record<string, unknown>).kind = 'score';
    expect(validateStructuredDocument(insight)).toBe('仅数字块可声明数值类型');
  });
});

describe('normalizeStructuredDocumentMedia', () => {
  it('reduces a local-mode absolute uploads URL to a relative ref', () => {
    const doc = {
      schemaVersion: 3,
      primaryBlockId: 'metric_1',
      theme: 'editorial',
      blocks: [{
        id: 'metric_1', type: 'metric', title: '推荐指数', value: '4.8', unit: '', helper: '',
        items: [], leftLabel: '', leftValue: '', rightLabel: '', rightValue: '',
        evidence: [
          { type: 'image', ref: 'http://192.168.3.2:3000/uploads/posts/a.jpg' },
          { type: 'image', ref: 'cos://posts/b.jpg' },
          { type: 'source', ref: '京东订单' },
        ],
      }],
    };
    expect(validateStructuredDocument(doc)).toBeNull();
    normalizeStructuredDocumentMedia(doc);
    const evidence = (doc.blocks[0] as Record<string, unknown>).evidence as Array<Record<string, unknown>>;
    expect(evidence[0].ref).toBe('/uploads/posts/a.jpg');
    expect(evidence[1].ref).toBe('cos://posts/b.jpg');
    expect(evidence[2].ref).toBe('京东订单');
  });

  it('ignores documents without evidence', () => {
    expect(() => normalizeStructuredDocumentMedia(undefined)).not.toThrow();
    expect(() => normalizeStructuredDocumentMedia(metricDocument())).not.toThrow();
  });
});
