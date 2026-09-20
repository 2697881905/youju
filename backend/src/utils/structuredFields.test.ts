import { validateStructuredData, genreFieldMeta, allowedStructuredKeys } from './structuredFields';

/**
 * 结构化字段校验的回归测试。
 *
 * 背景：structuredData 是无 schema 的 Json 列，改造前后端完全不校验，
 * 任意键/任意长度/任意类型都能入库。这些用例把「什么会被拒绝」固定下来，
 * 避免后续改动把校验放宽（放宽的后果是不可回溯的脏数据）。
 */
describe('validateStructuredData', () => {
  test('合法的各体裁字段通过', () => {
    expect(validateStructuredData(
      { pros: '续航强', cons: '偏重', rating: '4.5', targetAudience: '学生党' }, 'review',
    )).toBeNull();
    expect(validateStructuredData(
      { pitfallExperience: '贪便宜', lossAmount: '3200 元', correctApproach: '先查评测' }, 'pitfall',
    )).toBeNull();
    expect(validateStructuredData(
      { tools: '螺丝刀', steps: '1. 断电', timeDifficulty: '20 分钟 / 入门' }, 'tutorial',
    )).toBeNull();
    expect(validateStructuredData({ planA: '攒钱', planB: '分期' }, 'debate')).toBeNull();
  });

  test('空值与未填一律放行', () => {
    expect(validateStructuredData(undefined, 'review')).toBeNull();
    expect(validateStructuredData(null, 'review')).toBeNull();
    expect(validateStructuredData({}, 'review')).toBeNull();
    expect(validateStructuredData({ pros: '   ' }, 'review')).toBeNull();
    expect(validateStructuredData({ pros: undefined }, 'review')).toBeNull();
    expect(validateStructuredData({}, 'share')).toBeNull();
  });

  test('非对象被拒', () => {
    expect(validateStructuredData([1, 2], 'review')).toBe('结构化字段格式无效');
    expect(validateStructuredData('pros=好', 'review')).toBe('结构化字段格式无效');
  });

  test('白名单外的键被拒', () => {
    expect(validateStructuredData({ foo: 'x' }, 'review')).toBe('未知的结构化字段：foo');
    // 跨体裁串键：想给测评帖塞教程字段
    expect(validateStructuredData({ steps: 'x' }, 'review')).toBe('未知的结构化字段：steps');
  });

  test('无体裁时按全量白名单校验（编辑接口不带 genre 的场景）', () => {
    expect(validateStructuredData({ planA: '攒钱' }, undefined)).toBeNull();
    expect(validateStructuredData({ zzz: 'x' }, undefined)).toBe('未知的结构化字段：zzz');
  });

  test('分享体裁不接受任何结构化字段', () => {
    expect(validateStructuredData({ pros: 'x' }, 'share')).toBe('该体裁不支持结构化字段');
  });

  test('字段长度上限', () => {
    expect(validateStructuredData({ pros: '好'.repeat(200) }, 'review')).toBeNull();
    expect(validateStructuredData({ pros: '好'.repeat(201) }, 'review')).toBe('优点最多 200 字');
    expect(validateStructuredData({ steps: 'x'.repeat(1001) }, 'tutorial')).toBe('步骤拆解最多 1000 字');
    expect(validateStructuredData({ lossAmount: 'x'.repeat(21) }, 'pitfall')).toBe('损失金额最多 20 字');
  });

  test('推荐指数格式：0-5，整数或一位小数', () => {
    expect(validateStructuredData({ rating: '4.5' }, 'review')).toBeNull();
    expect(validateStructuredData({ rating: '0.5' }, 'review')).toBeNull();
    expect(validateStructuredData({ rating: '5' }, 'review')).toBeNull();
    expect(validateStructuredData({ rating: 4 }, 'review')).toBeNull();
    // 格式错误优先于长度错误，避免出现「4.55 → 最多 3 字」这种误导文案
    expect(validateStructuredData({ rating: '4.55' }, 'review'))
      .toBe('推荐指数需为 0-5 的数字（可带一位小数）');
    expect(validateStructuredData({ rating: '6' }, 'review'))
      .toBe('推荐指数需为 0-5 的数字（可带一位小数）');
    expect(validateStructuredData({ rating: '-1' }, 'review'))
      .toBe('推荐指数需为 0-5 的数字（可带一位小数）');
    expect(validateStructuredData({ rating: '很好' }, 'review'))
      .toBe('推荐指数需为 0-5 的数字（可带一位小数）');
  });

  test('内部标记 coverOnlyTextPoster 只接受布尔', () => {
    expect(validateStructuredData({ coverOnlyTextPoster: true }, 'review')).toBeNull();
    expect(validateStructuredData({ coverOnlyTextPoster: false }, 'review')).toBeNull();
    expect(validateStructuredData({ coverOnlyTextPoster: 'yes' }, 'review')).toBe('封面样式标记格式无效');
  });

  test('字段值类型必须是字符串或数字', () => {
    expect(validateStructuredData({ pros: { a: 1 } }, 'review')).toBe('优点格式无效');
    expect(validateStructuredData({ pros: ['a'] }, 'review')).toBe('优点格式无效');
  });
});

describe('字段表', () => {
  test('各体裁键集合与前端镜像一致', () => {
    expect(allowedStructuredKeys('review')).toEqual(['pros', 'cons', 'rating', 'targetAudience']);
    expect(allowedStructuredKeys('pitfall')).toEqual(['pitfallExperience', 'lossAmount', 'correctApproach']);
    expect(allowedStructuredKeys('tutorial')).toEqual(['tools', 'steps', 'timeDifficulty']);
    expect(allowedStructuredKeys('debate')).toEqual(['planA', 'planB']);
    expect(allowedStructuredKeys('share')).toEqual([]);
    expect(allowedStructuredKeys('不存在的体裁')).toEqual([]);
  });

  test('每个字段都有正的 maxLength', () => {
    for (const genre of ['review', 'pitfall', 'tutorial', 'debate']) {
      for (const meta of genreFieldMeta(genre)) {
        expect(meta.maxLength).toBeGreaterThan(0);
      }
    }
  });
});
