import { StructuredBlock, StructuredDocument } from '../models/types';
import { StructuredFieldPair } from './structuredFields';
import { structuredBlockHasContent } from './structuredDocument';

// 帖子内容的纯文本投影：详情页长按正文「复制正文」用（标题不在此内，由长按标题单独复制）。
// 结构化块压平成「【标题】内容」的行式布局，粘贴到微信/备忘录仍保持可读；
// 展示层被海报容纳而隐藏的正文同样纳入（复制不丢信息），与详情页的可见性规则无关。

// 单个 V2 信息块 → 可读文本。metric/insight/list 值跟在标题行后；
// steps/compare 天然多行（编号步骤 / A B 两栏），退化为逐行文本。
export function structuredBlockPlainText(block: StructuredBlock): string {
  let body: string = '';
  if (block.type === 'metric') {
    const unit: string = block.unit.trim().length > 0 ? ' ' + block.unit.trim() : '';
    body = block.value.trim() + unit;
  } else if (block.type === 'insight') {
    body = block.value.trim();
  } else if (block.type === 'list') {
    body = block.items.join('、');
  } else if (block.type === 'steps') {
    const lines: string[] = [];
    for (let i = 0; i < block.items.length; i++) {
      lines.push(String(i + 1) + '. ' + block.items[i]);
    }
    body = lines.join('\n');
  } else {
    // compare：展示层是左右两栏，文本里退化成两行「栏名：值」
    const leftLabel: string = block.leftLabel.trim().length > 0 ? block.leftLabel.trim() : 'A';
    const rightLabel: string = block.rightLabel.trim().length > 0 ? block.rightLabel.trim() : 'B';
    body = leftLabel + '：' + block.leftValue.trim() + '\n' + rightLabel + '：' + block.rightValue.trim();
  }
  const heading: string = '【' + block.title.trim() + '】';
  const helper: string = block.helper.trim();
  return heading + (body.length > 0 ? '\n' + body : '') + (helper.length > 0 ? '\n' + helper : '');
}

// V2 文档 → 文本。与 StructuredFlowView.visibleBlocks 同序（主视觉块最先、跳过空块）；
// schemaVersion 不是 2（旧数据）时返回 ''，调用方回退旧字段投影。
export function structuredDocumentPlainText(document: StructuredDocument | null | undefined): string {
  if (!document || document.schemaVersion !== 2) {
    return '';
  }
  const ordered: StructuredBlock[] = [];
  for (const block of document.blocks) {
    if (structuredBlockHasContent(block) && block.id === document.primaryBlockId) {
      ordered.unshift(block);
    } else if (structuredBlockHasContent(block)) {
      ordered.push(block);
    }
  }
  const lines: string[] = [];
  for (const block of ordered) {
    lines.push(structuredBlockPlainText(block));
  }
  return lines.join('\n');
}

// 旧帖子（无 V2 文档）的字段投影 → 「标签：值」行
export function structuredPairsPlainText(pairs: StructuredFieldPair[]): string {
  const lines: string[] = [];
  for (const pair of pairs) {
    if (pair.value.trim().length === 0) {
      continue;
    }
    lines.push(pair.label + '：' + pair.value.trim());
  }
  return lines.join('\n');
}

// 帖子正文内容 → 纯文本：结构化信息（V2 文档优先，旧帖回退字段投影）+ 正文，
// 段落之间空一行。**不含标题**——标题由头部自己的长按菜单单独复制，两者不混；
// 无可复制内容时返回 ''。
export function postContentTextOf(content: string,
  document: StructuredDocument | null | undefined, legacyPairs: StructuredFieldPair[]): string {
  const parts: string[] = [];
  const docText: string = structuredDocumentPlainText(document);
  if (docText.length > 0) {
    parts.push(docText);
  } else {
    const pairText: string = structuredPairsPlainText(legacyPairs);
    if (pairText.length > 0) {
      parts.push(pairText);
    }
  }
  const c: string = content.trim();
  if (c.length > 0) {
    parts.push(c);
  }
  return parts.join('\n\n');
}
