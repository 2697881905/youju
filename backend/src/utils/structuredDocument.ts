const DOCUMENT_KEYS = new Set(['schemaVersion', 'primaryBlockId', 'theme', 'blocks']);
const BLOCK_KEYS = new Set([
  'id', 'type', 'title', 'value', 'unit', 'helper', 'items',
  'leftLabel', 'leftValue', 'rightLabel', 'rightValue',
]);
const BLOCK_TYPES = new Set(['metric', 'insight', 'list', 'steps', 'compare']);
const THEMES = new Set(['editorial', 'warm', 'cool']);

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
  return null;
}

/**
 * V2 通用结构化信息协议校验。undefined/null 表示客户端没有提交 V2，兼容历史版本。
 */
export function validateStructuredDocument(input: unknown): string | null {
  if (input === undefined || input === null) return null;
  if (!isPlainObject(input)) return '结构化信息流格式无效';
  for (const key of Object.keys(input)) {
    if (!DOCUMENT_KEYS.has(key)) return '结构化信息流包含未知字段：' + key;
  }
  if (input.schemaVersion !== 2) return '结构化信息流版本无效';
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
