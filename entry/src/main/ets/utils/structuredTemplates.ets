import { Genre, StructuredBlock, StructuredDocument } from '../models/types';
import { createStructuredBlock, emptyStructuredDocument } from './structuredDocument';

export interface StructuredTemplateMeta {
  key: string;
  title: string;
  description: string;
  genres: Genre[];
}

export const STRUCTURED_TEMPLATES: StructuredTemplateMeta[] = [
  { key: 'insight', title: '一句结论', description: '先把最重要的判断放大', genres: ['review', 'pitfall', 'tutorial', 'debate', 'share'] },
  { key: 'verdict', title: '数据判断', description: '关键数字 + 结论 + 适用条件', genres: ['review', 'debate'] },
  { key: 'compare', title: '选择对比', description: 'A/B 对照 + 最终建议', genres: ['debate'] },
  { key: 'guide', title: '行动指南', description: '步骤路径 + 准备清单 + 提醒', genres: ['pitfall', 'tutorial'] },
];

export function structuredTemplatesForGenre(genre?: Genre): StructuredTemplateMeta[] {
  const result: StructuredTemplateMeta[] = [];
  for (const template of STRUCTURED_TEMPLATES) {
    if (genre === undefined || template.genres.indexOf(genre) >= 0) {
      result.push(template);
    }
  }
  return result;
}

function append(document: StructuredDocument, block: StructuredBlock): void {
  document.blocks.push(block);
  if (document.primaryBlockId.length === 0) document.primaryBlockId = block.id;
}

export function structuredDocumentFromTemplate(key: string): StructuredDocument {
  const document: StructuredDocument = emptyStructuredDocument();
  if (key === 'verdict') {
    const metric: StructuredBlock = createStructuredBlock('metric');
    metric.title = '关键数字';
    metric.unit = '单位';
    append(document, metric);
    const insight: StructuredBlock = createStructuredBlock('insight');
    insight.title = '我的判断';
    append(document, insight);
    const list: StructuredBlock = createStructuredBlock('list');
    list.title = '适用条件';
    append(document, list);
    return document;
  }
  if (key === 'compare') {
    const compare: StructuredBlock = createStructuredBlock('compare');
    compare.title = '两种选择';
    append(document, compare);
    const insight: StructuredBlock = createStructuredBlock('insight');
    insight.title = '最终建议';
    append(document, insight);
    return document;
  }
  if (key === 'guide') {
    const steps: StructuredBlock = createStructuredBlock('steps');
    steps.title = '行动路径';
    append(document, steps);
    const list: StructuredBlock = createStructuredBlock('list');
    list.title = '开始前准备';
    append(document, list);
    const insight: StructuredBlock = createStructuredBlock('insight');
    insight.title = '关键提醒';
    append(document, insight);
    return document;
  }
  const insight: StructuredBlock = createStructuredBlock('insight');
  insight.title = '核心结论';
  append(document, insight);
  return document;
}
