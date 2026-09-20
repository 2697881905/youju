import { Genre, StructuredBlock, StructuredData, StructuredDocument, StructuredDocumentTheme } from '../models/types';
import { pairValueOf, structuredFieldPairs, StructuredFieldPair } from './structuredFields';
import { structuredBlockHasContent } from './structuredDocument';

// 结构化信息的新视觉投影。
// 旧帖子仍然保存 StructuredData；这里先把它投影成通用摘要，
// 让信息流可以先完成视觉重构，再逐步迁移编辑器和后端协议。
export type StructuredSummaryMode = 'metric' | 'compare' | 'steps' | 'insight' | 'list';

export interface StructuredSummary {
  mode: StructuredSummaryMode;
  eyebrow: string;
  label: string;
  primary: string;
  secondary: string[];
  helper: string;
  theme?: StructuredDocumentTheme;
}

function genreLabel(genre?: Genre | string): string {
  switch (genre) {
    case 'review': return '测评';
    case 'pitfall': return '避坑';
    case 'tutorial': return '教程';
    case 'debate': return '观点';
    default: return '有据摘要';
  }
}

function compactText(value: string, max: number): string {
  const text: string = value.replace(/\s+/g, ' ').trim();
  return text.length > max ? text.substring(0, max) + '…' : text;
}

function splitValues(text: string): string[] {
  const normalized: string = text
    .replace(/，/g, '、')
    .replace(/,/g, '、')
    .replace(/\//g, '、')
    .replace(/；/g, '、')
    .replace(/;/g, '、');
  const out: string[] = [];
  for (const raw of normalized.split('、')) {
    const value: string = raw.trim();
    if (value.length > 0 && out.indexOf(value) < 0) {
      out.push(value);
    }
  }
  return out;
}

function stripStepNumber(value: string): string {
  const text: string = value.trim();
  let index: number = 0;
  while (index < text.length && text.charAt(index) >= '0' && text.charAt(index) <= '9') {
    index += 1;
  }
  if (index === 0 || index >= text.length) {
    return text;
  }
  const separator: string = text.charAt(index);
  if (separator === '.' || separator === '、' || separator === ')' || separator === '）' ||
    separator === ':' || separator === '：') {
    return text.substring(index + 1).trim();
  }
  return text;
}

function splitStepValues(text: string): string[] {
  let raw: string[] = text.split('\n');
  if (raw.length < 2) {
    raw = text.replace(/；/g, ';').split(';');
  }
  const out: string[] = [];
  for (const item of raw) {
    const value: string = stripStepNumber(item);
    if (value.length > 0) {
      out.push(value);
    }
  }
  return out.length >= 2 ? out : [];
}

function firstMeaningful(pairs: StructuredFieldPair[], keys: string[]): StructuredFieldPair | undefined {
  for (const key of keys) {
    for (const pair of pairs) {
      if (pair.key === key && pair.value.trim().length > 0) {
        return pair;
      }
    }
  }
  return undefined;
}

function secondaryText(pairs: StructuredFieldPair[], keys: string[], max: number = 2): string[] {
  const values: string[] = [];
  for (const key of keys) {
    for (const pair of pairs) {
      if (pair.key !== key || pair.value.trim().length === 0) {
        continue;
      }
      const pieces: string[] = pair.kind === 'chips' ? splitValues(pair.value) : [compactText(pair.value, 28)];
      for (const piece of pieces) {
        if (piece.length > 0 && values.indexOf(piece) < 0) {
          values.push(piece);
        }
        if (values.length >= max) {
          return values;
        }
      }
    }
  }
  return values;
}

// 从当前四种体裁字段投影出信息流主视觉。
// 优先级是「数字结论 > 对比关系 > 步骤路径 > 一句话经验 > 标签列表」，
// 这样信息流不会把所有字段平均摊平，首屏只保留一个明确的视觉焦点。
export function structuredSummaryFromPairs(pairs: StructuredFieldPair[], genre?: string): StructuredSummary | null {
  if (pairs.length === 0) {
    return null;
  }

  const rating: string = pairValueOf(pairs, '推荐指数');
  if (rating.length > 0) {
    return {
      mode: 'metric',
      eyebrow: genreLabel(genre),
      label: '推荐指数',
      primary: rating,
      secondary: secondaryText(pairs, ['targetAudience', '适合人群', 'pros'], 2),
      helper: '/ 5',
    };
  }

  const loss: string = pairValueOf(pairs, '损失金额');
  if (loss.length > 0) {
    return {
      mode: 'metric',
      eyebrow: genreLabel(genre),
      label: '实际损失',
      primary: compactText(loss, 16),
      secondary: secondaryText(pairs, ['correctApproach', '正确做法', 'pitfallExperience'], 2),
      helper: '先看教训，再看做法',
    };
  }

  const planA: string = pairValueOf(pairs, '方案A');
  const planB: string = pairValueOf(pairs, '方案B');
  if (planA.length > 0 && planB.length > 0) {
    return {
      mode: 'compare',
      eyebrow: genreLabel(genre),
      label: '两种选择',
      primary: compactText(planA, 22),
      secondary: [compactText(planB, 22)],
      helper: 'A / B 观点对照',
    };
  }

  const steps: string = pairValueOf(pairs, '步骤拆解');
  const stepItems: string[] = steps.length > 0 ? splitStepValues(steps) : [];
  if (stepItems.length >= 2) {
    return {
      mode: 'steps',
      eyebrow: genreLabel(genre),
      label: '操作路径',
      primary: String(stepItems.length) + ' 步',
      secondary: [compactText(stepItems[0], 24), compactText(stepItems[1], 24)],
      helper: pairValueOf(pairs, '耗时/难度') || '按顺序完成',
    };
  }

  const insight: StructuredFieldPair | undefined = firstMeaningful(pairs,
    ['pitfallExperience', '踩坑经历', 'correctApproach', '正确做法', 'pros', '优点', 'cons', '缺点']);
  if (insight !== undefined) {
    return {
      mode: 'insight',
      eyebrow: genreLabel(genre),
      label: insight.label,
      primary: compactText(insight.value, 54),
      secondary: secondaryText(pairs, ['targetAudience', '适合人群', 'tools', '准备工具'], 2),
      helper: '结构化经验',
    };
  }

  const listPair: StructuredFieldPair | undefined = firstMeaningful(pairs, ['targetAudience', '适合人群', 'tools', '准备工具']);
  if (listPair !== undefined) {
    return {
      mode: 'list',
      eyebrow: genreLabel(genre),
      label: listPair.label,
      primary: splitValues(listPair.value).slice(0, 3).join(' · '),
      secondary: [],
      helper: '快速浏览',
    };
  }

  const fallback: StructuredFieldPair = pairs[0];
  return {
    mode: 'insight',
    eyebrow: genreLabel(genre),
    label: fallback.label,
    primary: compactText(fallback.value, 54),
    secondary: [],
    helper: '结构化信息',
  };
}

function primaryBlockOf(document: StructuredDocument): StructuredBlock | null {
  for (const block of document.blocks) {
    if (block.id === document.primaryBlockId && structuredBlockHasContent(block)) {
      return block;
    }
  }
  for (const block of document.blocks) {
    if (structuredBlockHasContent(block)) {
      return block;
    }
  }
  return null;
}

export function structuredSummaryFromDocument(document: StructuredDocument | undefined,
  genre?: string): StructuredSummary | null {
  if (document === undefined || document.schemaVersion !== 2) {
    return null;
  }
  const block: StructuredBlock | null = primaryBlockOf(document);
  if (block === null) {
    return null;
  }
  if (block.type === 'metric') {
    return {
      mode: 'metric', eyebrow: genreLabel(genre), label: block.title,
      primary: compactText(block.value, 18), secondary: block.items.slice(0, 2),
      helper: block.unit.length > 0 ? block.unit : block.helper, theme: document.theme,
    };
  }
  if (block.type === 'compare') {
    return {
      mode: 'compare', eyebrow: genreLabel(genre), label: block.title,
      primary: compactText(block.leftValue, 24), secondary: [compactText(block.rightValue, 24)],
      helper: (block.leftLabel || 'A') + ' / ' + (block.rightLabel || 'B'), theme: document.theme,
    };
  }
  if (block.type === 'steps') {
    return {
      mode: 'steps', eyebrow: genreLabel(genre), label: block.title,
      primary: String(block.items.length) + ' 步', secondary: block.items.slice(0, 2),
      helper: block.helper.length > 0 ? block.helper : '按顺序完成', theme: document.theme,
    };
  }
  if (block.type === 'list') {
    return {
      mode: 'list', eyebrow: genreLabel(genre), label: block.title,
      primary: block.items.slice(0, 3).join(' · '), secondary: [],
      helper: block.helper.length > 0 ? block.helper : '快速浏览', theme: document.theme,
    };
  }
  return {
    mode: 'insight', eyebrow: genreLabel(genre), label: block.title,
    primary: compactText(block.value, 60), secondary: block.items.slice(0, 2),
    helper: block.helper.length > 0 ? block.helper : '作者结论', theme: document.theme,
  };
}

// 双读兼容：V2 是主路径；历史帖子没有 V2 时才投影旧 structuredData。
export function structuredSummaryOf(data: StructuredData | undefined, genre?: Genre,
  document?: StructuredDocument): StructuredSummary | null {
  const v2: StructuredSummary | null = structuredSummaryFromDocument(document, genre);
  return v2 !== null ? v2 : structuredSummaryFromPairs(structuredFieldPairs(data, genre), genre);
}
