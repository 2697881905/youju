import {
  Genre,
  StructuredBlock,
  StructuredBlockType,
  StructuredData,
  StructuredDocument,
  StructuredDocumentTheme,
} from '../models/types';

export type StructuredBlockTextField = 'title' | 'value' | 'unit' | 'helper' |
  'leftLabel' | 'leftValue' | 'rightLabel' | 'rightValue';

let blockSequence: number = 0;

function nextBlockId(): string {
  blockSequence += 1;
  return 'block_' + String(Date.now()) + '_' + String(blockSequence);
}

export function emptyStructuredDocument(): StructuredDocument {
  return {
    schemaVersion: 2,
    primaryBlockId: '',
    theme: 'editorial',
    blocks: [],
  };
}

export function structuredBlockTypeLabel(type: StructuredBlockType): string {
  switch (type) {
    case 'metric': return '数字';
    case 'insight': return '结论';
    case 'list': return '清单';
    case 'steps': return '步骤';
    case 'compare': return '对比';
    default: return '信息';
  }
}

export function structuredBlockTypeHint(type: StructuredBlockType): string {
  switch (type) {
    case 'metric': return '突出一个最值得记住的数字';
    case 'insight': return '用一句话说清核心判断';
    case 'list': return '并列呈现要点、对象或条件';
    case 'steps': return '把过程拆成可执行路径';
    case 'compare': return '把两种选择放在同一视线内';
    default: return '';
  }
}

export function structuredBlockTypesForGenre(genre?: Genre): StructuredBlockType[] {
  switch (genre) {
    case 'review': return ['metric', 'insight', 'list'];
    case 'pitfall': return ['insight', 'steps', 'list'];
    case 'tutorial': return ['steps', 'list', 'insight'];
    case 'debate': return ['compare', 'insight', 'metric'];
    // 分享不做结构化：返回空数组，既用来隐藏发布页的编辑区，
    // 也让切换体裁时 filterStructuredDocumentForGenre 把已有信息块清空（避免留下孤儿块）。
    case 'share': return [];
    default: return ['insight', 'list'];
  }
}

export function createStructuredBlock(type: StructuredBlockType): StructuredBlock {
  let title: string = '核心结论';
  let leftLabel: string = 'A';
  let rightLabel: string = 'B';
  if (type === 'metric') {
    title = '关键数字';
  } else if (type === 'list') {
    title = '快速清单';
  } else if (type === 'steps') {
    title = '行动路径';
  } else if (type === 'compare') {
    title = '两种选择';
  }
  return {
    id: nextBlockId(),
    type: type,
    title: title,
    value: '',
    unit: '',
    helper: '',
    items: [],
    leftLabel: leftLabel,
    leftValue: '',
    rightLabel: rightLabel,
    rightValue: '',
  };
}

export function cloneStructuredBlock(block: StructuredBlock): StructuredBlock {
  return {
    id: block.id,
    type: block.type,
    title: block.title,
    value: block.value,
    unit: block.unit,
    helper: block.helper,
    items: block.items.slice(),
    leftLabel: block.leftLabel,
    leftValue: block.leftValue,
    rightLabel: block.rightLabel,
    rightValue: block.rightValue,
  };
}

export function cloneStructuredDocument(document: StructuredDocument): StructuredDocument {
  const blocks: StructuredBlock[] = [];
  for (const block of document.blocks) {
    blocks.push(cloneStructuredBlock(block));
  }
  return {
    schemaVersion: 2,
    primaryBlockId: document.primaryBlockId,
    theme: document.theme,
    blocks: blocks,
  };
}

export function filterStructuredDocumentForGenre(document: StructuredDocument, genre?: Genre): StructuredDocument {
  const allowed: StructuredBlockType[] = structuredBlockTypesForGenre(genre);
  const next: StructuredDocument = cloneStructuredDocument(document);
  next.blocks = next.blocks.filter((block: StructuredBlock): boolean => allowed.indexOf(block.type) >= 0);
  let primaryExists: boolean = false;
  for (const block of next.blocks) {
    if (block.id === next.primaryBlockId) {
      primaryExists = true;
      break;
    }
  }
  if (!primaryExists) {
    next.primaryBlockId = next.blocks.length > 0 ? next.blocks[0].id : '';
  }
  return next;
}

export function addStructuredBlock(document: StructuredDocument, type: StructuredBlockType): StructuredDocument {
  const next: StructuredDocument = cloneStructuredDocument(document);
  const block: StructuredBlock = createStructuredBlock(type);
  next.blocks.push(block);
  if (next.primaryBlockId.length === 0) {
    next.primaryBlockId = block.id;
  }
  return next;
}

export function removeStructuredBlock(document: StructuredDocument, blockId: string): StructuredDocument {
  const next: StructuredDocument = cloneStructuredDocument(document);
  next.blocks = next.blocks.filter((block: StructuredBlock): boolean => block.id !== blockId);
  if (next.primaryBlockId === blockId) {
    next.primaryBlockId = next.blocks.length > 0 ? next.blocks[0].id : '';
  }
  return next;
}

export function duplicateStructuredBlock(document: StructuredDocument, blockId: string): StructuredDocument {
  const next: StructuredDocument = cloneStructuredDocument(document);
  for (let i = 0; i < next.blocks.length; i++) {
    if (next.blocks[i].id !== blockId) continue;
    const duplicate: StructuredBlock = cloneStructuredBlock(next.blocks[i]);
    duplicate.id = nextBlockId();
    duplicate.title = duplicate.title + ' 副本';
    next.blocks.splice(i + 1, 0, duplicate);
    break;
  }
  return next;
}

export function moveStructuredBlock(document: StructuredDocument, blockId: string, offset: number): StructuredDocument {
  const next: StructuredDocument = cloneStructuredDocument(document);
  let from: number = -1;
  for (let i = 0; i < next.blocks.length; i++) {
    if (next.blocks[i].id === blockId) {
      from = i;
      break;
    }
  }
  const to: number = from + offset;
  if (from < 0 || to < 0 || to >= next.blocks.length) {
    return next;
  }
  const moving: StructuredBlock = next.blocks[from];
  next.blocks.splice(from, 1);
  next.blocks.splice(to, 0, moving);
  return next;
}

export function setStructuredPrimary(document: StructuredDocument, blockId: string): StructuredDocument {
  const next: StructuredDocument = cloneStructuredDocument(document);
  for (const block of next.blocks) {
    if (block.id === blockId) {
      next.primaryBlockId = blockId;
      break;
    }
  }
  return next;
}

export function setStructuredTheme(document: StructuredDocument, theme: StructuredDocumentTheme): StructuredDocument {
  const next: StructuredDocument = cloneStructuredDocument(document);
  next.theme = theme;
  return next;
}

export function withStructuredBlockText(document: StructuredDocument, blockId: string,
  field: StructuredBlockTextField, value: string): StructuredDocument {
  const next: StructuredDocument = cloneStructuredDocument(document);
  for (const block of next.blocks) {
    if (block.id !== blockId) {
      continue;
    }
    if (field === 'title') block.title = value;
    else if (field === 'value') block.value = value;
    else if (field === 'unit') block.unit = value;
    else if (field === 'helper') block.helper = value;
    else if (field === 'leftLabel') block.leftLabel = value;
    else if (field === 'leftValue') block.leftValue = value;
    else if (field === 'rightLabel') block.rightLabel = value;
    else if (field === 'rightValue') block.rightValue = value;
    break;
  }
  return next;
}

function itemLines(text: string): string[] {
  const normalized: string = text.replace(/；/g, '\n').replace(/;/g, '\n');
  const items: string[] = [];
  for (const raw of normalized.split('\n')) {
    const value: string = raw.trim();
    if (value.length > 0) {
      items.push(value);
    }
  }
  return items;
}

export function structuredItemsText(block: StructuredBlock): string {
  return block.items.join('\n');
}

export function withStructuredBlockItems(document: StructuredDocument, blockId: string,
  text: string): StructuredDocument {
  const next: StructuredDocument = cloneStructuredDocument(document);
  for (const block of next.blocks) {
    if (block.id === blockId) {
      block.items = itemLines(text);
      break;
    }
  }
  return next;
}

export function structuredBlockHasContent(block: StructuredBlock): boolean {
  if (block.type === 'metric' || block.type === 'insight') {
    return block.value.trim().length > 0;
  }
  if (block.type === 'list' || block.type === 'steps') {
    return block.items.length > 0;
  }
  return block.leftValue.trim().length > 0 || block.rightValue.trim().length > 0;
}

// 发布时剔除空白块；编辑中的半成品仍保留在本地状态和草稿里。
export function collectStructuredDocument(document: StructuredDocument): StructuredDocument {
  const next: StructuredDocument = cloneStructuredDocument(document);
  next.blocks = next.blocks.filter((block: StructuredBlock): boolean => structuredBlockHasContent(block));
  let primaryExists: boolean = false;
  for (const block of next.blocks) {
    if (block.id === next.primaryBlockId) {
      primaryExists = true;
      break;
    }
  }
  if (!primaryExists) {
    next.primaryBlockId = next.blocks.length > 0 ? next.blocks[0].id : '';
  }
  return next;
}

function legacyText(value: string | number | undefined): string {
  if (typeof value === 'number') return String(value);
  return typeof value === 'string' ? value.trim() : '';
}

function appendLegacyBlock(document: StructuredDocument, block: StructuredBlock): void {
  if (!structuredBlockHasContent(block)) return;
  document.blocks.push(block);
  if (document.primaryBlockId.length === 0) document.primaryBlockId = block.id;
}

// 老草稿首次打开时转换为 V2；老帖子仍保留 structuredData 作为只读兼容数据。
export function structuredDocumentFromLegacy(data: StructuredData, _genre?: Genre): StructuredDocument {
  const document: StructuredDocument = emptyStructuredDocument();
  const rating: string = legacyText(data.rating);
  if (rating.length > 0) {
    const metric: StructuredBlock = createStructuredBlock('metric');
    metric.title = '推荐指数';
    metric.value = rating;
    metric.unit = '/ 5';
    appendLegacyBlock(document, metric);
  }
  const loss: string = legacyText(data.lossAmount);
  if (loss.length > 0) {
    const metric: StructuredBlock = createStructuredBlock('metric');
    metric.title = '实际损失';
    metric.value = loss;
    appendLegacyBlock(document, metric);
  }
  const planA: string = legacyText(data.planA);
  const planB: string = legacyText(data.planB);
  if (planA.length > 0 || planB.length > 0) {
    const compare: StructuredBlock = createStructuredBlock('compare');
    compare.title = '两种选择';
    compare.leftValue = planA;
    compare.rightValue = planB;
    appendLegacyBlock(document, compare);
  }
  const steps: string = legacyText(data.steps);
  if (steps.length > 0) {
    const block: StructuredBlock = createStructuredBlock('steps');
    block.title = '操作路径';
    block.items = itemLines(steps);
    if (block.items.length === 0) block.items = [steps];
    block.helper = legacyText(data.timeDifficulty);
    appendLegacyBlock(document, block);
  }
  const insightValues: string[] = [legacyText(data.pitfallExperience), legacyText(data.correctApproach),
    legacyText(data.pros), legacyText(data.cons)];
  const insightTitles: string[] = ['踩坑经历', '正确做法', '优点', '缺点'];
  for (let i = 0; i < insightValues.length; i++) {
    if (insightValues[i].length === 0) continue;
    const insight: StructuredBlock = createStructuredBlock('insight');
    insight.title = insightTitles[i];
    insight.value = insightValues[i];
    appendLegacyBlock(document, insight);
  }
  const listValues: string[] = [legacyText(data.targetAudience), legacyText(data.tools)];
  const listTitles: string[] = ['适合人群', '准备工具'];
  for (let i = 0; i < listValues.length; i++) {
    if (listValues[i].length === 0) continue;
    const list: StructuredBlock = createStructuredBlock('list');
    list.title = listTitles[i];
    list.items = listValues[i].replace(/，/g, '、').replace(/,/g, '、').split('、')
      .map((item: string): string => item.trim()).filter((item: string): boolean => item.length > 0);
    appendLegacyBlock(document, list);
  }
  return document;
}
