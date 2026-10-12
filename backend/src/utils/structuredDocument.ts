import { normalizeMediaRefInput } from './mediaRef';

const DOCUMENT_KEYS = new Set(['schemaVersion', 'primaryBlockId', 'theme', 'blocks']);
const BLOCK_KEYS = new Set([
  'id', 'type', 'title', 'value', 'unit', 'helper', 'items',
  'leftLabel', 'leftValue', 'rightLabel', 'rightValue',
  // V3 新增：数值类型 / 规范数值 / 证据链。三者都可选，所以 V2 客户端提交的形态照旧通过。
  'kind', 'numberValue', 'evidence',
]);
const BLOCK_TYPES = new Set(['metric', 'insight', 'list', 'steps', 'compare']);
const THEMES = new Set(['editorial', 'warm', 'cool']);
const METRIC_KINDS = new Set(['score', 'amount', 'duration', 'percent', 'count', 'plain']);
const EVIDENCE_KEYS = new Set(['type', 'ref', 'note']);
const EVIDENCE_TYPES = new Set(['image', 'source']);
// V2 是老客户端唯一会提交的版本，V3 只是给它加了三个可选槽位，形态完全兼容。
// 因此部署顺序必须是「后端先放宽并单独上线，客户端后发 V3」——反过来跑，
// 老后端会把带 evidence 的整次发布按「未知字段」拒掉。
const SCHEMA_VERSIONS = new Set([2, 3]);
const MAX_EVIDENCE_PER_BLOCK = 6;
const MAX_EVIDENCE_NOTE = 60;
const MAX_EVIDENCE_SOURCE_REF = 200;
// 数值上限：够装金额/时长/百分比，同时把 NaN/Infinity/科学计数法垃圾挡在 Json 列外。
const MAX_METRIC_NUMBER_VALUE = 1e12;

function isPlainObject(value: unknown): value is Record<string, unknown> {
  return typeof value === 'object' && value !== null && !Array.isArray(value);
}

function textError(block: Record<string, unknown>, key: string, label: string, max: number): string | null {
  const value = block[key];
  if (typeof value !== 'string') return label + '格式无效';
  if (value.length > max) return label + '最多 ' + max + ' 字';
  return null;
}

function hasText(value: unknown): boolean {
  return typeof value === 'string' && value.trim().length > 0;
}

// 出处证据的 ref 是展示文本/链接，不会被客户端 Image 组件自动 GET，所以不套媒体白名单；
// 但它仍会被渲染成可点链接，故拦掉伪协议。用显式黑名单而不是「非 http 的 scheme: 全拒」，
// 后者会误伤 "Note: 见说明书" 这类正常出处文本。
const DANGEROUS_SOURCE_PREFIXES = ['javascript:', 'data:', 'vbscript:', 'file:', 'blob:'];

function sourceRefError(ref: string): string | null {
  if (ref.length === 0) return '证据内容不能为空';
  if (ref.length > MAX_EVIDENCE_SOURCE_REF) return '证据内容最多 ' + MAX_EVIDENCE_SOURCE_REF + ' 字';
  const lowered: string = ref.trim().toLowerCase();
  for (const prefix of DANGEROUS_SOURCE_PREFIXES) {
    if (lowered.startsWith(prefix)) return '证据内容不支持该协议：' + prefix;
  }
  const schemeMatch = ref.match(/^([A-Za-z][A-Za-z0-9+.-]*):\/\//);
  if (schemeMatch !== null && schemeMatch[1].toLowerCase() !== 'http' && schemeMatch[1].toLowerCase() !== 'https') {
    return '证据链接仅支持 http 或 https';
  }
  return null;
}

function evidenceError(raw: unknown): string | null {
  if (!isPlainObject(raw)) return '证据格式无效';
  for (const key of Object.keys(raw)) {
    if (!EVIDENCE_KEYS.has(key)) return '证据包含未知字段：' + key;
  }
  if (typeof raw.type !== 'string' || !EVIDENCE_TYPES.has(raw.type)) return '证据类型无效';
  if (raw.note !== undefined && (typeof raw.note !== 'string' || raw.note.length > MAX_EVIDENCE_NOTE)) {
    return '证据说明最多 ' + MAX_EVIDENCE_NOTE + ' 字';
  }
  if (typeof raw.ref !== 'string') return '证据内容格式无效';
  if (raw.type === 'image') {
    // 图片证据会被浏览者客户端自动加载，与帖图同一条白名单：只认本系统上传体系产出的引用。
    return normalizeMediaRefInput(raw.ref).ok ? null : '证据图片引用无效';
  }
  return sourceRefError(raw.ref.trim());
}

// 证据图片引用的入库归一化：本地调试模式的绝对 URL（含主机名）归约为 /uploads/ 相对路径，
// 与 images/coverImage 的处理口径一致——主机随环境漂移，不应进库。
// 校验已在路由层通过（normalizeMediaRefInput.ok），这里只做静默改写。
function normalizeEvidenceRefs(blocks: unknown): void {
  if (!Array.isArray(blocks)) return;
  for (const block of blocks) {
    if (!isPlainObject(block) || !Array.isArray(block.evidence)) continue;
    for (const item of block.evidence) {
      if (!isPlainObject(item) || item.type !== 'image' || typeof item.ref !== 'string') continue;
      item.ref = normalizeMediaRefInput(item.ref).ref;
    }
  }
}

function validateBlock(block: unknown, index: number): string | null {
  if (!isPlainObject(block)) return '第 ' + (index + 1) + ' 个信息块格式无效';
  for (const key of Object.keys(block)) {
    if (!BLOCK_KEYS.has(key)) return '信息块包含未知字段：' + key;
  }
  if (typeof block.id !== 'string' || block.id.trim().length === 0 || block.id.length > 80) {
    return '信息块 ID 格式无效';
  }
  if (typeof block.type !== 'string' || !BLOCK_TYPES.has(block.type)) return '信息块类型无效';
  const textFields: Array<[string, string, number]> = [
    ['title', '信息块标题', 30], ['value', '信息块正文', 300], ['unit', '数字单位', 16],
    ['helper', '补充说明', 80], ['leftLabel', '左侧标签', 12], ['leftValue', '左侧内容', 180],
    ['rightLabel', '右侧标签', 12], ['rightValue', '右侧内容', 180],
  ];
  for (const [key, label, max] of textFields) {
    const error = textError(block, key, label, max);
    if (error) return error;
  }
  if (!Array.isArray(block.items) || block.items.length > 12) return '清单或步骤最多 12 项';
  for (const item of block.items) {
    if (typeof item !== 'string' || item.trim().length === 0 || item.length > 120) {
      return '清单或步骤单项需为 1-120 字';
    }
  }
  if ((block.type === 'metric' || block.type === 'insight') && !hasText(block.value)) {
    return block.type === 'metric' ? '数字块缺少数值' : '结论块缺少正文';
  }
  if ((block.type === 'list' || block.type === 'steps') && block.items.length === 0) {
    return block.type === 'list' ? '清单块至少需要一项' : '步骤块至少需要一步';
  }
  if (block.type === 'compare' && !hasText(block.leftValue) && !hasText(block.rightValue)) {
    return '对比块至少填写一侧内容';
  }
  // —— V3 可选字段：缺失即视为未启用（V2 形态），出现则按数字块专属校验 ——
  if (block.kind !== undefined) {
    if (block.type !== 'metric') return '仅数字块可声明数值类型';
    if (typeof block.kind !== 'string' || !METRIC_KINDS.has(block.kind)) return '数值类型无效';
  }
  if (block.numberValue !== undefined) {
    if (block.type !== 'metric') return '仅数字块可携带规范数值';
    if (typeof block.numberValue !== 'number' || !Number.isFinite(block.numberValue) ||
      Math.abs(block.numberValue) > MAX_METRIC_NUMBER_VALUE) {
      return '规范数值需为有限数字';
    }
  }
  if (block.evidence !== undefined) {
    if (!Array.isArray(block.evidence)) return '证据格式无效';
    if (block.evidence.length > MAX_EVIDENCE_PER_BLOCK) return '每个信息块最多 ' + MAX_EVIDENCE_PER_BLOCK + ' 条证据';
    for (const item of block.evidence) {
      const error = evidenceError(item);
      if (error) return error;
    }
  }
  return null;
}

/**
 * 结构化信息流协议校验（V2/V3）。undefined/null 表示客户端没有提交，兼容历史版本。
 * V3 相对 V2 只多了三个可选槽位，因此两版共用一套块级规则。
 */
export function validateStructuredDocument(input: unknown): string | null {
  if (input === undefined || input === null) return null;
  if (!isPlainObject(input)) return '结构化信息流格式无效';
  for (const key of Object.keys(input)) {
    if (!DOCUMENT_KEYS.has(key)) return '结构化信息流包含未知字段：' + key;
  }
  if (typeof input.schemaVersion !== 'number' || !SCHEMA_VERSIONS.has(input.schemaVersion)) {
    return '结构化信息流版本无效';
  }
  if (typeof input.primaryBlockId !== 'string' || input.primaryBlockId.length > 80) {
    return '主视觉块格式无效';
  }
  if (typeof input.theme !== 'string' || !THEMES.has(input.theme)) return '信息流主题无效';
  if (!Array.isArray(input.blocks) || input.blocks.length > 8) return '结构化信息块最多 8 个';

  const ids = new Set<string>();
  for (let i = 0; i < input.blocks.length; i++) {
    const error = validateBlock(input.blocks[i], i);
    if (error) return error;
    const id = (input.blocks[i] as Record<string, unknown>).id as string;
    if (ids.has(id)) return '信息块 ID 不能重复';
    ids.add(id);
  }
  if (input.blocks.length === 0 && input.primaryBlockId !== '') return '空信息流不能指定主视觉块';
  if (input.blocks.length > 0 && !ids.has(input.primaryBlockId)) return '主视觉块不存在';
  return null;
}

/**
 * 入库前归一化结构化信息流里的媒体引用（证据图片）。就地改写，与 createPost/updatePost
 * 对 images/coverImage 的处理同时调用。
 */
export function normalizeStructuredDocumentMedia(input: unknown): void {
  if (!isPlainObject(input)) return;
  normalizeEvidenceRefs(input.blocks);
}
