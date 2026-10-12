import {
  Genre,
  StructuredBlock,
  StructuredBlockType,
  StructuredData,
  StructuredDocument,
  StructuredDocumentTheme,
  StructuredEvidence,
  StructuredEvidenceType,
  StructuredMetricKind,
  STRUCTURED_SCHEMA_VERSION,
} from '../models/types';

export type StructuredBlockTextField = 'title' | 'value' | 'unit' | 'helper' |
  'leftLabel' | 'leftValue' | 'rightLabel' | 'rightValue';

// 证据链上限与长度口径，必须与后端 backend/src/utils/structuredDocument.ts 保持一致：
// 前端放过的提交若被后端按「超长」拒绝，用户在发布最后一步才会看见错误，代价极高。
export const MAX_EVIDENCE_PER_BLOCK: number = 6;
export const MAX_EVIDENCE_NOTE: number = 60;
export const MAX_EVIDENCE_SOURCE_REF: number = 200;

let blockSequence: number = 0;

function nextBlockId(): string {
  blockSequence += 1;
  return 'block_' + String(Date.now()) + '_' + String(blockSequence);
}

export function emptyStructuredDocument(): StructuredDocument {
  return {
    schemaVersion: STRUCTURED_SCHEMA_VERSION,
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
  // V3 三个字段必须逐一带过：任何一次「克隆—改一处—整体替换」漏掉它们，
  // 都会让作者已上传的证据或已选数值类型静默消失（不报错，只是数据没了）。
  const clone: StructuredBlock = {
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
  if (block.kind !== undefined && block.kind !== null) clone.kind = block.kind;
  if (block.numberValue !== undefined && block.numberValue !== null) clone.numberValue = block.numberValue;
  const evidence: StructuredEvidence[] = evidenceOf(block);
  if (evidence.length > 0) clone.evidence = cloneStructuredEvidence(evidence);
  return clone;
}

// 读证据必须走这里：V2 存量帖子的块对象没有 evidence 键，直接 .length 会崩在详情页首屏。
export function evidenceOf(block: StructuredBlock): StructuredEvidence[] {
  const list: StructuredEvidence[] | null | undefined = block.evidence;
  if (list === undefined || list === null) {
    return [];
  }
  return list;
}

function cloneStructuredEvidence(list: StructuredEvidence[]): StructuredEvidence[] {
  const out: StructuredEvidence[] = [];
  for (const item of list) {
    out.push({ type: item.type, ref: item.ref, note: item.note });
  }
  return out;
}

export function structuredEvidenceCount(block: StructuredBlock): number {
  return evidenceOf(block).length;
}

export function cloneStructuredDocument(document: StructuredDocument): StructuredDocument {
  const blocks: StructuredBlock[] = [];
  for (const block of document.blocks) {
    blocks.push(cloneStructuredBlock(block));
  }
  return {
    // 保留原文档版本：编辑一份 V2 草稿不该把它悄悄盖章成 V3，
    // 只有新建文档（emptyStructuredDocument）才用当前版本起笔。
    schemaVersion: document.schemaVersion >= 2 ? document.schemaVersion : STRUCTURED_SCHEMA_VERSION,
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

// —— V3：数值类型 ——
// 「一个最值得记住的数字」只有带上类型才能比较、排序、聚合；
// kind 决定 numberValue 的解析口径，两者成对写入，避免出现有类型没数值（或反之）的半态。

export function structuredMetricKindLabel(kind?: StructuredMetricKind | null): string {
  switch (kind) {
    case 'score': return '评分';
    case 'amount': return '金额';
    case 'duration': return '时长';
    case 'percent': return '百分比';
    case 'count': return '计数';
    default: return '数字';
  }
}

// 从自由文本里取第一个数字：作者写「4.8」「到手 4.8 分」「¥3,200」都能归一到同一个量。
// 取不到就返回 0，并由调用方决定「视为无数值」——后端要求 numberValue 为有限数字。
export function parseStructuredMetricNumber(value: string): number {
  const match: RegExpMatchArray | null = value.replace(/,/g, '').trim().match(/-?\d+(?:\.\d+)?/);
  if (match === null) {
    return 0;
  }
  const parsed: number = Number(match[0]);
  return Number.isFinite(parsed) ? parsed : 0;
}

export function withStructuredMetricKind(document: StructuredDocument, blockId: string,
  kind: StructuredMetricKind): StructuredDocument {
  const next: StructuredDocument = cloneStructuredDocument(document);
  for (const block of next.blocks) {
    // 后端只允许数字块携带 kind/numberValue，非 metric 直接不改，保住这条不变量
    if (block.id !== blockId || block.type !== 'metric') {
      continue;
    }
    block.kind = kind;
    block.numberValue = parseStructuredMetricNumber(block.value);
    break;
  }
  return next;
}

// —— V3：证据链 ——

export function addStructuredEvidence(document: StructuredDocument, blockId: string,
  type: StructuredEvidenceType, ref: string, note: string): StructuredDocument {
  const next: StructuredDocument = cloneStructuredDocument(document);
  for (const block of next.blocks) {
    if (block.id !== blockId) {
      continue;
    }
    const list: StructuredEvidence[] = evidenceOf(block);
    if (list.length >= MAX_EVIDENCE_PER_BLOCK) {
      break;
    }
    list.push({ type: type, ref: ref.trim(), note: note.trim().substring(0, MAX_EVIDENCE_NOTE) });
    block.evidence = list;
    break;
  }
  return next;
}

export function removeStructuredEvidence(document: StructuredDocument, blockId: string,
  index: number): StructuredDocument {
  const next: StructuredDocument = cloneStructuredDocument(document);
  for (const block of next.blocks) {
    if (block.id !== blockId) {
      continue;
    }
    const list: StructuredEvidence[] = evidenceOf(block);
    if (index < 0 || index >= list.length) {
      break;
    }
    list.splice(index, 1);
    block.evidence = list;
    break;
  }
  return next;
}

export function withStructuredEvidenceNote(document: StructuredDocument, blockId: string,
  index: number, note: string): StructuredDocument {
  const next: StructuredDocument = cloneStructuredDocument(document);
  for (const block of next.blocks) {
    if (block.id !== blockId) {
      continue;
    }
    const list: StructuredEvidence[] = evidenceOf(block);
    if (index < 0 || index >= list.length) {
      break;
    }
    list[index].note = note.trim().substring(0, MAX_EVIDENCE_NOTE);
    block.evidence = list;
    break;
  }
  return next;
}

// 出处证据的内容就存在 ref 里（图片证据的 ref 是上传引用，不允许手改）
export function withStructuredEvidenceRef(document: StructuredDocument, blockId: string,
  index: number, ref: string): StructuredDocument {
  const next: StructuredDocument = cloneStructuredDocument(document);
  for (const block of next.blocks) {
    if (block.id !== blockId) {
      continue;
    }
    const list: StructuredEvidence[] = evidenceOf(block);
    if (index < 0 || index >= list.length || list[index].type !== 'source') {
      break;
    }
    list[index].ref = ref.substring(0, MAX_EVIDENCE_SOURCE_REF);
    block.evidence = list;
    break;
  }
  return next;
}

// 没有内容的证据项（选图失败、出处留空）不该进正文，也不该占掉 6 条配额。
function prunedEvidence(list: StructuredEvidence[]): StructuredEvidence[] {
  const out: StructuredEvidence[] = [];
  for (const item of list) {
    if (item.ref.trim().length === 0) {
      continue;
    }
    out.push({ type: item.type, ref: item.ref.trim(), note: item.note.trim().substring(0, MAX_EVIDENCE_NOTE) });
  }
  return out;
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
  let usesV3: boolean = false;
  for (const block of next.blocks) {
    const pruned: StructuredEvidence[] = prunedEvidence(evidenceOf(block));
    // 无条件回写：只在有内容时赋值会把「点了出处但没填」的空条目原样发出去，
    // 后端按「证据内容不能为空」拒绝，用户在发布最后一步才看见错误。
    block.evidence = pruned.length > 0 ? pruned : undefined;
    if (pruned.length > 0) {
      usesV3 = true;
    }
    if (block.type === 'metric' && block.kind !== undefined && block.kind !== null) {
      // 数值可能在选完类型之后又被改过，发布前按最终文本重算一次
      block.numberValue = parseStructuredMetricNumber(block.value);
      usesV3 = true;
    }
  }
  // 版本随内容形态走：新建文档已是当前版本；从 V2 草稿/存量帖子复制来的文档只有真用上
  // V3 槽位才升版本，避免把没带证据的老形态标成新协议。
  if (usesV3 && next.schemaVersion < STRUCTURED_SCHEMA_VERSION) {
    next.schemaVersion = STRUCTURED_SCHEMA_VERSION;
  }
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
