// 把「这篇帖子最硬的那个数字」从 JSON 信息块里抽出来，落成 Post 上可排序、可索引的三列。
//
// 为什么不直接查 JSON：跨帖对比要按数值排序、要能走索引，MySQL 的 JSON 路径排序既慢又
// 吃不到索引。所以协议里的 kind/numberValue 只用于展示，检索侧靠这一列收敛。

const METRIC_KINDS = new Set(['score', 'amount', 'duration', 'percent', 'count', 'plain']);
const MAX_METRIC_NUMBER_VALUE = 1e12;
const MAX_METRIC_LABEL = 30;
const MAX_METRIC_TEXT = 40;

export interface PostMetric {
  metricValue: number;
  metricKind: string | null;
  metricLabel: string | null;
  metricText: string | null;
}

function isObject(value: unknown): value is Record<string, unknown> {
  return typeof value === 'object' && value !== null && !Array.isArray(value);
}

// 老客户端只填 value 文本（"4.6"、"82%"、"1,299 元"），规范数值是 V3 才有的槽位，
// 所以这里必须能从文本里回捞一个数，否则 V2 存量帖永远进不了对比表。
// 锚定在「跳过前缀后的第一个数字串」：不锚定会把 "第 1 名，4.6 分" 取成 4.6 之外的错值，
// 而带上指数位是为了让 "1e99" 这类科学计数法在数值上限处被挡掉，而不是被截成 1。
function parseLeadingNumber(text: string): number | null {
  const cleaned = text.replace(/[,，\s]/g, '');
  const match = cleaned.match(/^\D*?(-?\d+(?:\.\d+)?(?:[eE][-+]?\d+)?)/);
  if (match === null) return null;
  const value = Number(match[1]);
  return Number.isFinite(value) ? value : null;
}

// kind 缺省时按单位猜。判定顺序即优先级：'分钟' 必须先于 '分' 落，否则评分和耗时互相误伤。
function inferKind(valueText: string, unit: string): string {
  const text = (valueText + ' ' + unit).trim();
  if (text.indexOf('%') >= 0) return 'percent';
  if (/[元￥¥]/.test(text)) return 'amount';
  if (/分钟|小时|秒|\b(ms|min|sec|hrs?|h)\b/i.test(text)) return 'duration';
  if (/分|星|[／/]\s*[15]0\b/.test(text)) return 'score';
  if (/次|人|台|款|篇/.test(text)) return 'count';
  return 'plain';
}

function pickMetricBlock(document: Record<string, unknown>): Record<string, unknown> | null {
  const blocks = Array.isArray(document.blocks) ? document.blocks : [];
  const metrics: Array<Record<string, unknown>> = [];
  for (const raw of blocks) {
    if (isObject(raw) && raw.type === 'metric') metrics.push(raw);
  }
  if (metrics.length === 0) return null;
  if (typeof document.primaryBlockId === 'string') {
    const primary = metrics.find((block) => block.id === document.primaryBlockId);
    if (primary) return primary;
  }
  return metrics[0];
}

/**
 * 从 V2/V3 结构化信息流抽取帖子主数字。没有数字块、或数字块里取不出有限数值时返回 null，
 * 三列一起留空——「没有可比的数」和「数值为 0」必须是两回事。
 */
export function extractPostMetric(document: unknown): PostMetric | null {
  if (!isObject(document)) return null;
  const block = pickMetricBlock(document);
  if (!block) return null;

  const unit = typeof block.unit === 'string' ? block.unit : '';
  const valueText = typeof block.value === 'string' ? block.value : '';
  let value: number | null = null;
  if (typeof block.numberValue === 'number' && Number.isFinite(block.numberValue)) {
    value = block.numberValue;
  } else {
    value = parseLeadingNumber(valueText);
  }
  if (value === null || Math.abs(value) > MAX_METRIC_NUMBER_VALUE) return null;

  const kind = typeof block.kind === 'string' && METRIC_KINDS.has(block.kind)
    ? block.kind
    : inferKind(valueText, unit);
  const title = typeof block.title === 'string' ? block.title.trim() : '';
  const label = title.length > 0 ? title.slice(0, MAX_METRIC_LABEL) : null;
  // 展示串单独存一列：对比表要原样显示作者写的「4.6 分」「1,299 元」，
  // 而客户端不该为了一行表格去拉整篇 structuredDocument。
  const trimmedUnit = unit.trim();
  const joined = trimmedUnit.length > 0 && valueText.indexOf(trimmedUnit) < 0
    ? valueText + trimmedUnit
    : valueText;
  const displayText = joined.trim();
  const text = displayText.length > 0 ? displayText.slice(0, MAX_METRIC_TEXT) : null;

  return { metricValue: value, metricKind: kind, metricLabel: label, metricText: text };
}

/**
 * 抽成 Post 表可写的补丁：取不到数字时四列显式置空，避免编辑后残留上一个数字块的值。
 */
export function buildPostMetricPatch(document: unknown): {
  metricValue: number | null;
  metricKind: string | null;
  metricLabel: string | null;
  metricText: string | null;
} {
  const metric = extractPostMetric(document);
  return {
    metricValue: metric ? metric.metricValue : null,
    metricKind: metric ? metric.metricKind : null,
    metricLabel: metric ? metric.metricLabel : null,
    metricText: metric ? metric.metricText : null,
  };
}
