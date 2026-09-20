import { buildStructuredSearchText } from './structuredSearchText';

describe('buildStructuredSearchText', () => {
  it('flattens V2 blocks and removes duplicate fragments', () => {
    expect(buildStructuredSearchText({
      blocks: [{
        title: '适合人群', value: '', unit: '', helper: '第一次装修',
        items: ['租房党', '租房党'], leftLabel: '', leftValue: '', rightLabel: '', rightValue: '',
      }],
    }, null)).toBe('适合人群 第一次装修 租房党');
  });

  it('keeps legacy posts searchable during migration', () => {
    expect(buildStructuredSearchText(undefined, { pros: '续航强', rating: 4.8 }))
      .toBe('续航强 4.8');
    expect(buildStructuredSearchText(undefined, {})).toBeNull();
  });
});
