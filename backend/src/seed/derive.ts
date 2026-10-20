// 派生字段的唯一出口。
//
// 作者只写人话（正文、优缺点、步骤、结论），信息块由这里按体裁装配。两条原则：
//   1) 复用生产代码里的同一批函数（buildStructuredSearchText / buildPostMetricPatch /
//      validateStructuredDocument），不另写一套，否则造出来的数据在详情页和搜索里的
//      表现会和真实发布的帖子不一致，验收时看不出问题、上线后才炸。
//   2) 装配带变化：同一体裁不该每条帖子都长成「数字 + 结论 + 对比」三件套，
//      用帖子 id 取种决定用哪套骨架，观感上更像不同人写的。

import {
  StructuredBlock,
  StructuredBlockType,
  StructuredDocument,
} from './types';
import { buildPostMetricPatch } from '../utils/postMetric';
import { buildStructuredSearchText } from '../utils/structuredSearchText';
import { themeForCircle } from './catalog';
import { rngFor } from './rng';
import { SeedBlockSpec, SeedPostRecord, SeedStructuredFields } from './types';

export interface DerivedContent {
  structuredData: Record<string, unknown>;
  structuredDocument: StructuredDocument | null;
  structuredSearchText: string | null;
  metric: {
    metricValue: number | null;
    metricKind: string | null;
    metricLabel: string | null;
    metricText: string | null;
  };
}

function splitItems(text: string | undefined, limit: number): string[] {
  if (!text) return [];
  const byLine = text
    .split(/\n+/)
    .map((line) => line.replace(/^\s*\d+[.、)]\s*/, '').trim())
    .filter((line) => line.length > 0);
  const source = byLine.length > 1 ? byLine : text.split(/[、；;|]/);
  const items: string[] = [];
  for (const raw of source) {
    const item = raw.replace(/^\s*\d+[.、)]\s*/, '').trim();
    if (item.length === 0) continue;
    if (items.indexOf(item) >= 0) continue;
    items.push(item.slice(0, 120));
    if (items.length >= limit) break;
  }
  return items;
}

function emptyBlock(type: StructuredBlockType, id: string, title: string): StructuredBlock {
  return {
    id,
    type,
    title,
    value: '',
    unit: '',
    helper: '',
    items: [],
    leftLabel: 'A',
    rightLabel: 'B',
    leftValue: '',
    rightValue: '',
  };
}

function toBlock(spec: SeedBlockSpec, id: string): StructuredBlock {
  const block = emptyBlock(spec.type, id, spec.title);
  if (spec.value !== undefined) block.value = spec.value;
  if (spec.unit !== undefined) block.unit = spec.unit;
  if (spec.helper !== undefined) block.helper = spec.helper;
  if (spec.items !== undefined) block.items = spec.items.slice(0, 12);
  if (spec.leftLabel !== undefined) block.leftLabel = spec.leftLabel;
  if (spec.leftValue !== undefined) block.leftValue = spec.leftValue;
  if (spec.rightLabel !== undefined) block.rightLabel = spec.rightLabel;
  if (spec.rightValue !== undefined) block.rightValue = spec.rightValue;
  if (spec.kind !== undefined) block.kind = spec.kind;
  if (spec.numberValue !== undefined && Number.isFinite(spec.numberValue)) {
    block.numberValue = spec.numberValue;
  }
  return block;
}

function reviewBlocks(post: SeedPostRecord, structured: SeedStructuredFields, seed: string): StructuredBlock[] {
  const blocks: StructuredBlock[] = [];
  const rating = typeof structured.rating === 'number' ? structured.rating : Number(structured.rating ?? 0);
  const metric = emptyBlock('metric', `${seed}-b0`, '推荐指数');
  metric.value = String(rating);
  metric.unit = '分';
  metric.kind = 'score';
  metric.numberValue = rating;
  blocks.push(metric);

  const insight = emptyBlock('insight', `${seed}-b1`, '一句话结论');
  insight.value = post.insight ?? '';
  blocks.push(insight);

  const variant = rngFor(`${post.id}:review`).int(0, 2);
  const audience = splitItems(structured.targetAudience, 6);
  const useListFirst = variant === 1 && audience.length > 0;
  if (useListFirst) {
    const list = emptyBlock('list', `${seed}-b2`, '适合谁');
    list.items = audience;
    blocks.push(list);
  } else {
    const compare = emptyBlock('compare', `${seed}-b2`, variant === 2 ? '好在哪，差在哪' : '优点与缺点');
    compare.leftLabel = '优点';
    compare.leftValue = String(structured.pros ?? '').slice(0, 180);
    compare.rightLabel = '缺点';
    compare.rightValue = String(structured.cons ?? '').slice(0, 180);
    blocks.push(compare);
    if (audience.length > 0 && variant === 2) {
      const list = emptyBlock('list', `${seed}-b3`, '适合谁');
      list.items = audience;
      blocks.push(list);
    }
  }
  return blocks;
}

function pitfallBlocks(post: SeedPostRecord, structured: SeedStructuredFields, seed: string): StructuredBlock[] {
  const insight = emptyBlock('insight', `${seed}-b0`, '这个坑是怎么来的');
  insight.value = post.insight ?? '';
  const steps = emptyBlock('steps', `${seed}-b1`, '后来我是这么处理的');
  steps.items = splitItems(structured.correctApproach, 6);
  if (structured.lossAmount) {
    steps.helper = `损失 ${structured.lossAmount}`;
  }
  return [insight, steps];
}

function tutorialBlocks(post: SeedPostRecord, structured: SeedStructuredFields, seed: string): StructuredBlock[] {
  const blocks: StructuredBlock[] = [];
  const tools = splitItems(structured.tools, 8);
  const variant = rngFor(`${post.id}:tutorial`).int(0, 1);
  if (tools.length > 0 && variant === 1) {
    const list = emptyBlock('list', `${seed}-b0`, '开始前准备');
    list.items = tools;
    blocks.push(list);
  }
  const steps = emptyBlock('steps', `${seed}-b1`, '按这个顺序做');
  steps.items = splitItems(structured.steps, 8);
  if (structured.timeDifficulty) {
    steps.helper = structured.timeDifficulty;
  }
  blocks.push(steps);
  if (tools.length > 0 && variant === 0) {
    const list = emptyBlock('list', `${seed}-b2`, '要准备的东西');
    list.items = tools;
    blocks.push(list);
  }
  const insight = emptyBlock('insight', `${seed}-b3`, '做完才知道的一句');
  insight.value = post.insight ?? '';
  blocks.push(insight);
  return blocks;
}

function debateBlocks(post: SeedPostRecord, seed: string): StructuredBlock[] {
  const a = Number(post.planAVotes ?? 0);
  const b = Number(post.planBVotes ?? 0);
  const total = a + b;
  const percent = total > 0 ? Math.round((a / total) * 100) : 50;
  const compare = emptyBlock('compare', `${seed}-b0`, '两边各自的理由');
  compare.leftLabel = '方案A';
  compare.leftValue = String(post.structured?.planA ?? '').slice(0, 180);
  compare.rightLabel = '方案B';
  compare.rightValue = String(post.structured?.planB ?? '').slice(0, 180);
  const metric = emptyBlock('metric', `${seed}-b1`, '我现在的倾向');
  metric.value = String(percent);
  metric.unit = '%';
  metric.kind = 'percent';
  metric.numberValue = percent;
  metric.helper = `${a} 人站 A，${b} 人站 B`;
  const insight = emptyBlock('insight', `${seed}-b2`, '为什么这么选');
  insight.value = post.insight ?? '';
  return [compare, metric, insight];
}

function buildDocument(post: SeedPostRecord, circleName: string): StructuredDocument | null {
  if (post.genre === 'share') return null;
  const seed = post.id;
  let blocks: StructuredBlock[] = [];
  if (Array.isArray(post.blocks) && post.blocks.length > 0) {
    blocks = post.blocks.map((spec, index) => toBlock(spec, `${seed}-b${index}`));
  } else {
    const structured = post.structured ?? {};
    if (post.genre === 'review') blocks = reviewBlocks(post, structured, seed);
    else if (post.genre === 'pitfall') blocks = pitfallBlocks(post, structured, seed);
    else if (post.genre === 'tutorial') blocks = tutorialBlocks(post, structured, seed);
    else if (post.genre === 'debate') blocks = debateBlocks(post, seed);
  }
  if (blocks.length === 0) return null;

  const primaryIndex = post.primaryBlockIndex !== undefined && post.primaryBlockIndex < blocks.length
    ? post.primaryBlockIndex
    : blocks.findIndex((block) => block.type === 'metric');
  const primaryBlockId = blocks[primaryIndex >= 0 ? primaryIndex : 0].id;

  return {
    schemaVersion: 3,
    primaryBlockId,
    theme: post.theme ?? themeForCircle(circleName),
    blocks,
  };
}

export function deriveContent(post: SeedPostRecord, circleName: string): DerivedContent {
  const structuredData: Record<string, unknown> = post.genre === 'share'
    ? {}
    : ({ ...(post.structured ?? {}) } as Record<string, unknown>);
  const document = buildDocument(post, circleName);
  return {
    structuredData,
    structuredDocument: document,
    structuredSearchText: buildStructuredSearchText(document, structuredData),
    metric: buildPostMetricPatch(document),
  };
}
