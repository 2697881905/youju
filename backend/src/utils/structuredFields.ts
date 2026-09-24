/**
 * 结构化字段：后端侧的字段表与入库校验
 *
 * 本文件是前端 entry/src/main/ets/utils/structuredFields.ets 的镜像。
 * ArkTS 与 Node 两套构建产物无法共享模块，字段表只能各留一份 —— 改动必须同批提交，
 * 否则会出现「前端能提交、后端拒绝」或反过来的不一致。
 *
 * 校验目标不是「逼用户填满」，而是把非法值挡在入库之前：
 * structuredData 是无 schema 的 Json 列，历史上任何键、任何长度、任何类型都能进库；
 * 脏数据一旦落库，详情渲染、检索、分享都要写兼容分支，且无法回溯清洗。
 */
export type StructuredFieldKind = 'shortText' | 'longText' | 'steps' | 'rating' | 'amount' | 'chips';

export interface StructuredFieldMeta {
  key: string;
  label: string;
  kind: StructuredFieldKind;
  maxLength: number;
  /** 核心字段：缺失只在客户端软提示，后端不强制 */
  essential: boolean;
}

const REVIEW_FIELDS: StructuredFieldMeta[] = [
  { key: 'pros', label: '优点', kind: 'longText', maxLength: 200, essential: true },
  { key: 'cons', label: '缺点', kind: 'longText', maxLength: 200, essential: true },
  { key: 'rating', label: '推荐指数', kind: 'rating', maxLength: 3, essential: true },
  { key: 'targetAudience', label: '适合人群', kind: 'chips', maxLength: 40, essential: false },
];

const PITFALL_FIELDS: StructuredFieldMeta[] = [
  { key: 'pitfallExperience', label: '踩坑经历', kind: 'longText', maxLength: 300, essential: true },
  { key: 'lossAmount', label: '损失金额', kind: 'amount', maxLength: 20, essential: false },
  { key: 'correctApproach', label: '正确做法', kind: 'longText', maxLength: 300, essential: true },
];

const TUTORIAL_FIELDS: StructuredFieldMeta[] = [
  { key: 'tools', label: '准备工具', kind: 'chips', maxLength: 120, essential: false },
  { key: 'steps', label: '步骤拆解', kind: 'steps', maxLength: 1000, essential: true },
  { key: 'timeDifficulty', label: '耗时/难度', kind: 'shortText', maxLength: 40, essential: false },
];

const DEBATE_FIELDS: StructuredFieldMeta[] = [
  { key: 'planA', label: '方案A', kind: 'shortText', maxLength: 60, essential: true },
  { key: 'planB', label: '方案B', kind: 'shortText', maxLength: 60, essential: true },
];

const ALL_FIELDS: StructuredFieldMeta[] =
  REVIEW_FIELDS.concat(PITFALL_FIELDS, TUTORIAL_FIELDS, DEBATE_FIELDS);

const FIELDS_BY_GENRE: Record<string, StructuredFieldMeta[]> = {
  review: REVIEW_FIELDS,
  pitfall: PITFALL_FIELDS,
  tutorial: TUTORIAL_FIELDS,
  debate: DEBATE_FIELDS,
  share: [],   // 分享体裁没有结构化字段
};

/** 内部标记（是否用文字海报当封面），不是内容字段 */
const INTERNAL_KEYS: string[] = ['coverOnlyTextPoster'];

/** 推荐指数：0-5，整数或一位小数 */
const RATING_PATTERN = /^[0-5](\.\d)?$/;

export function genreFieldMeta(genre?: string | null): StructuredFieldMeta[] {
  const key = String(genre ?? '').trim();
  return FIELDS_BY_GENRE[key] ?? [];
}

export function allowedStructuredKeys(genre?: string | null): string[] {
  return genreFieldMeta(genre).map((m) => m.key);
}

/**
 * 校验 structuredData。
 * @returns null 表示通过；否则返回可直接回给客户端的错误文案。
 *
 * genre 缺省（编辑接口未带体裁）时按全量字段白名单校验，只挡非法键/超长/错误格式，
 * 不因「体裁不匹配」误拒。
 */
export function validateStructuredData(input: unknown, genre?: string | null): string | null {
  if (input === undefined || input === null) {
    return null;
  }
  if (typeof input !== 'object' || Array.isArray(input)) {
    return '结构化字段格式无效';
  }
  const raw = input as Record<string, unknown>;
  const keys = Object.keys(raw);
  const hasGenre = genre !== undefined && genre !== null && String(genre).trim().length > 0;

  // 内部标记先于体裁判断处理：预览页发布会随 share 等无字段体裁带上
  // coverOnlyTextPoster（photo 无图纯文字海报为 true），不能因此触发体裁拒绝。
  for (const key of keys) {
    if (INTERNAL_KEYS.includes(key) && typeof raw[key] !== 'boolean') {
      return '封面样式标记格式无效';
    }
  }
  const contentKeys = keys.filter((key) => !INTERNAL_KEYS.includes(key));

  if (hasGenre && genreFieldMeta(genre).length === 0) {
    return contentKeys.length === 0 ? null : '该体裁不支持结构化字段';
  }

  const meta = hasGenre ? genreFieldMeta(genre) : ALL_FIELDS;
  const byKey = new Map<string, StructuredFieldMeta>(meta.map((m) => [m.key, m]));

  for (const key of contentKeys) {
    const field = byKey.get(key);
    if (!field) {
      return `未知的结构化字段：${key}`;
    }
    const value = raw[key];
    if (value === undefined || value === null) {
      continue;
    }
    if (typeof value !== 'string' && typeof value !== 'number') {
      return `${field.label}格式无效`;
    }
    const text = String(value).trim();
    if (text.length === 0) {
      continue;   // 空值视为未填，交由客户端收敛（collectStructuredData 会丢弃）
    }
    // 推荐指数先判格式：正则本身已把长度约束在 3 字内，
    // 若先判长度会出现「4.55 → 最多 3 字」这类误导性文案。
    if (field.kind === 'rating') {
      if (!RATING_PATTERN.test(text)) {
        return '推荐指数需为 0-5 的数字（可带一位小数）';
      }
      continue;
    }
    if (text.length > field.maxLength) {
      return `${field.label}最多 ${field.maxLength} 字`;
    }
  }
  return null;
}
