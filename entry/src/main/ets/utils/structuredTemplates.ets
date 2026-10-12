import { Genre, StructuredBlock, StructuredDocument } from '../models/types';
import { createStructuredBlock, emptyStructuredDocument } from './structuredDocument';

export interface StructuredTemplateMeta {
  key: string;
  title: string;
  description: string;
  genres: Genre[];
}

const SKELETON_GENRES: Genre[] = ['review', 'pitfall', 'tutorial', 'debate'];

// 每个体裁一条签名骨架，排在最前；「一句结论」是四个体裁共用的兜底起步。
// 骨架的作用不是给空壳，而是把这个体裁该有的表达顺序摆好、标题填好、数值类型选好，
// 让作者改词而不是搭架子——选完体裁就该看出「这是一篇测评 / 这是一篇教程」。
export const STRUCTURED_TEMPLATES: StructuredTemplateMeta[] = [
  { key: 'review_score', title: '推荐指数', description: '评分 + 结论 + 优缺点 + 适合谁', genres: ['review'] },
  { key: 'pitfall_case', title: '踩坑复盘', description: '坑是什么 + 怎么识别 + 正确做法', genres: ['pitfall'] },
  { key: 'tutorial_path', title: '上手路径', description: '准备清单 + 分步操作 + 关键提醒', genres: ['tutorial'] },
  { key: 'debate_side', title: '正反对照', description: '双方论点 + 支持度 + 我的立场', genres: ['debate'] },
  { key: 'insight', title: '一句结论', description: '先把最重要的判断放大', genres: SKELETON_GENRES },
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
  if (document.primaryBlockId.length === 0) {
    document.primaryBlockId = block.id;
  }
}

function block(type: 'metric' | 'insight' | 'list' | 'steps' | 'compare', title: string): StructuredBlock {
  const created: StructuredBlock = createStructuredBlock(type);
  created.title = title;
  return created;
}

export function structuredDocumentFromTemplate(key: string): StructuredDocument {
  const document: StructuredDocument = emptyStructuredDocument();
  if (key === 'review_score') {
    const score: StructuredBlock = block('metric', '推荐指数');
    score.unit = '/5';
    score.kind = 'score';
    append(document, score);
    append(document, block('insight', '一句话结论'));
    const pros: StructuredBlock = block('compare', '优点与缺点');
    pros.leftLabel = '优点';
    pros.rightLabel = '缺点';
    append(document, pros);
    append(document, block('list', '适合谁'));
    return document;
  }
  if (key === 'pitfall_case') {
    append(document, block('insight', '这个坑是什么'));
    append(document, block('list', '怎么认出这个坑'));
    append(document, block('steps', '正确做法'));
    return document;
  }
  if (key === 'tutorial_path') {
    append(document, block('steps', '跟着做'));
    append(document, block('list', '开始前准备'));
    append(document, block('insight', '关键提醒'));
    return document;
  }
  if (key === 'debate_side') {
    const sides: StructuredBlock = block('compare', '正反对照');
    sides.leftLabel = '正方';
    sides.rightLabel = '反方';
    append(document, sides);
    const support: StructuredBlock = block('metric', '我的支持度');
    support.unit = '%';
    support.kind = 'percent';
    append(document, support);
    append(document, block('insight', '我的立场'));
    return document;
  }
  append(document, block('insight', '核心结论'));
  return document;
}
