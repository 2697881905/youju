import { Genre, StructuredData } from '../models/types';

// ============================================================================
// 结构化字段：唯一定义处
// ----------------------------------------------------------------------------
// 改造前同一份字段表存在 5 份副本（本文件的 genreStructuredFields、
// DetailPage.structuredFieldDefs、PublishPreviewPage.genreFieldDefs、
// 三个发布页各自复制的 buildStructuredData、两处复制的 readField），
// 新增一个字段要改 7 个地方，漏改不报错、只静默丢字段；
// 且副本之间已经开始漂移（辩论标签一处写「方案A」、另一处写「方案 A」）。
//
// 现在收敛为三件东西，其余一切从它们派生：
//   1) 字段元数据表（label / 控件类型 / 长度上限 / 是否核心 / 示例占位）
//   2) 唯一读入口 readStructuredField（ArkTS V1 禁止按变量索引对象，必须显式 switch）
//   3) 唯一写入口 withStructuredField
//
// 渲染（发布区控件、详情页标签）、长度限制、软校验、后端校验白名单，全部以本文件为准。
// 后端镜像：backend/src/utils/structuredFields.ts —— 改动必须同批提交。
// ============================================================================

// 控件与渲染类型：shortText → 单行输入；longText → 多行输入；rating → 数值输入（0-5）
export type StructuredFieldKind = 'shortText' | 'longText' | 'rating';

export interface StructuredFieldMeta {
  key: keyof StructuredData;
  label: string;
  kind: StructuredFieldKind;
  maxLength: number;
  // 核心字段：缺失时在预览页给一次「补全可提升曝光」的软提示，不阻断发布
  essential: boolean;
  // 示例占位：既是写法范式，也把内容粒度收敛到一致
  hint: string;
}

// —— 各体裁字段表（数组顺序即发布区与详情页的展示顺序）——
const REVIEW_FIELDS: StructuredFieldMeta[] = [
  { key: 'pros', label: '优点', kind: 'longText', maxLength: 200, essential: true,
    hint: '续航强、系统流畅' },
  { key: 'cons', label: '缺点', kind: 'longText', maxLength: 200, essential: true,
    hint: '重量偏重、价格偏高' },
  { key: 'rating', label: '推荐指数', kind: 'rating', maxLength: 3, essential: true,
    hint: '4.5（0-5，可带一位小数）' },
  { key: 'targetAudience', label: '适合人群', kind: 'shortText', maxLength: 40, essential: false,
    hint: '学生党 / 摄影党' },
];

const PITFALL_FIELDS: StructuredFieldMeta[] = [
  { key: 'pitfallExperience', label: '踩坑经历', kind: 'longText', maxLength: 300, essential: true,
    hint: '在哪一步出的问题、当时是怎么判断的' },
  { key: 'lossAmount', label: '损失金额', kind: 'shortText', maxLength: 20, essential: false,
    hint: '3200 元' },
  { key: 'correctApproach', label: '正确做法', kind: 'longText', maxLength: 300, essential: true,
    hint: '如果重来一次会怎么做' },
];

const TUTORIAL_FIELDS: StructuredFieldMeta[] = [
  { key: 'tools', label: '准备工具', kind: 'shortText', maxLength: 120, essential: false,
    hint: '螺丝刀、万用表' },
  { key: 'steps', label: '步骤拆解', kind: 'longText', maxLength: 1000, essential: true,
    hint: '1. 先断电；2. 拆后盖；3. …' },
  { key: 'timeDifficulty', label: '耗时/难度', kind: 'shortText', maxLength: 40, essential: false,
    hint: '20 分钟 / 入门' },
];

const DEBATE_FIELDS: StructuredFieldMeta[] = [
  { key: 'planA', label: '方案A', kind: 'shortText', maxLength: 60, essential: true,
    hint: '先攒钱再买' },
  { key: 'planB', label: '方案B', kind: 'shortText', maxLength: 60, essential: true,
    hint: '分期先享受' },
];

// 跨体裁全量字段表：每个 key 只属于一个体裁，可安全拍平用于按 key 查元数据
const ALL_FIELDS: StructuredFieldMeta[] =
  REVIEW_FIELDS.concat(PITFALL_FIELDS).concat(TUTORIAL_FIELDS).concat(DEBATE_FIELDS);

// 该体裁的字段表；无结构化字段的体裁（分享）返回空数组
export function genreFieldMeta(genre?: Genre): StructuredFieldMeta[] {
  switch (genre) {
    case 'review':
      return REVIEW_FIELDS;
    case 'pitfall':
      return PITFALL_FIELDS;
    case 'tutorial':
      return TUTORIAL_FIELDS;
    case 'debate':
      return DEBATE_FIELDS;
    default:
      return [];
  }
}

export function allFieldMeta(): StructuredFieldMeta[] {
  return ALL_FIELDS;
}

export function fieldMeta(key: keyof StructuredData): StructuredFieldMeta | undefined {
  for (const meta of ALL_FIELDS) {
    if (meta.key === key) {
      return meta;
    }
  }
  return undefined;
}

export function fieldMaxLength(key: keyof StructuredData): number {
  const meta: StructuredFieldMeta | undefined = fieldMeta(key);
  return meta !== undefined ? meta.maxLength : 200;
}

export function fieldLabel(key: keyof StructuredData): string {
  const meta: StructuredFieldMeta | undefined = fieldMeta(key);
  return meta !== undefined ? meta.label : '';
}

// 唯一读入口。ArkTS V1 不允许以变量索引对象，必须显式 switch ——
// 这里与 readStructuredField 同在，是新增字段时唯一必须同步的代码位置。
export function readStructuredField(data: StructuredData, key: keyof StructuredData): string | number | undefined {
  switch (key) {
    case 'pros': return data.pros;
    case 'cons': return data.cons;
    case 'rating': return data.rating;
    case 'targetAudience': return data.targetAudience;
    case 'pitfallExperience': return data.pitfallExperience;
    case 'lossAmount': return data.lossAmount;
    case 'correctApproach': return data.correctApproach;
    case 'tools': return data.tools;
    case 'steps': return data.steps;
    case 'timeDifficulty': return data.timeDifficulty;
    case 'planA': return data.planA;
    case 'planB': return data.planB;
    default: return undefined;
  }
}

// 唯一的一处字段全量枚举：写路径都基于它的产出做单字段改动，
// 避免每个写函数各抄一份 12 键字面量（改造前有 3 份）。
export function cloneStructuredData(src: StructuredData): StructuredData {
  return {
    coverOnlyTextPoster: src.coverOnlyTextPoster,
    pros: src.pros,
    cons: src.cons,
    rating: src.rating,
    targetAudience: src.targetAudience,
    pitfallExperience: src.pitfallExperience,
    lossAmount: src.lossAmount,
    correctApproach: src.correctApproach,
    tools: src.tools,
    steps: src.steps,
    timeDifficulty: src.timeDifficulty,
    planA: src.planA,
    planB: src.planB,
  };
}

export function withStructuredField(data: StructuredData, key: keyof StructuredData, value: string): StructuredData {
  const next: StructuredData = cloneStructuredData(data);
  switch (key) {
    case 'pros': next.pros = value; break;
    case 'cons': next.cons = value; break;
    case 'rating': next.rating = value; break;
    case 'targetAudience': next.targetAudience = value; break;
    case 'pitfallExperience': next.pitfallExperience = value; break;
    case 'lossAmount': next.lossAmount = value; break;
    case 'correctApproach': next.correctApproach = value; break;
    case 'tools': next.tools = value; break;
    case 'steps': next.steps = value; break;
    case 'timeDifficulty': next.timeDifficulty = value; break;
    case 'planA': next.planA = value; break;
    case 'planB': next.planB = value; break;
    default: break;
  }
  return next;
}

export function withCoverOnlyTextPoster(data: StructuredData, enabled: boolean): StructuredData {
  const next: StructuredData = cloneStructuredData(data);
  next.coverOnlyTextPoster = enabled;
  return next;
}

// 发布前统一收敛：只保留本体裁字段、丢弃空值、按上限截断。
// 与后端路由校验同源，保证「前端能提交的」与「后端会接受的」是同一集合。
export function collectStructuredData(data: StructuredData, genre?: Genre): StructuredData {
  let out: StructuredData = {};
  for (const meta of genreFieldMeta(genre)) {
    const raw: string | number | undefined = readStructuredField(data, meta.key);
    if (raw === undefined || raw === null) {
      continue;
    }
    let value: string = String(raw).trim();
    if (value.length === 0) {
      continue;
    }
    if (value.length > meta.maxLength) {
      value = value.substring(0, meta.maxLength);
    }
    out = withStructuredField(out, meta.key, value);
  }
  return out;
}

// 软校验：列出该体裁缺失的核心字段标签（用于预览页提示，不阻断发布）
export function missingEssentialLabels(data: StructuredData, genre?: Genre): string[] {
  const missing: string[] = [];
  for (const meta of genreFieldMeta(genre)) {
    if (!meta.essential) {
      continue;
    }
    const raw: string | number | undefined = readStructuredField(data, meta.key);
    if (raw === undefined || raw === null || String(raw).trim().length === 0) {
      missing.push(meta.label);
    }
  }
  return missing;
}

// 展示用：[标签, 值] 列表。空值不产出条目 —— 改造前只过滤 undefined/null，
// 空字符串会渲染成「只有标签、没有内容」的空行。
export interface StructuredFieldPair {
  key: string;
  label: string;
  value: string;
}

export function structuredFieldPairs(data: StructuredData | undefined, genre?: Genre): StructuredFieldPair[] {
  const out: StructuredFieldPair[] = [];
  if (data === undefined || data === null) {
    return out;
  }
  for (const meta of genreFieldMeta(genre)) {
    const raw: string | number | undefined = readStructuredField(data, meta.key);
    if (raw === undefined || raw === null) {
      continue;
    }
    const value: string = String(raw).trim();
    if (value.length === 0) {
      continue;
    }
    out.push({ key: meta.key as string, label: meta.label, value: value });
  }
  return out;
}
