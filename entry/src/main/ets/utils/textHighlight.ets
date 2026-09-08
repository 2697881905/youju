// 正文高亮分段解析：@昵称 与 #话题# 高亮展示（与后端 MENTION_RE / TOPIC_RE 同口径）
// 返回 span 段列表，供 Text 内 Span 渲染；mention/tag 段带原始词（用于点击回调）
export interface HighlightSegment {
  type: 'text' | 'mention' | 'tag';
  raw: string; // 原文（含 @ / # ）
  name: string; // mention → 昵称；tag → 话题词（不含符号）
}

// 复合正则：优先匹配合法 @提及 与 #话题#；非法（长度不足/含空格）视为普通文本
const HIGHLIGHT_RE = /(@[^@\s，。！？、；：""''《》（）【】]{2,20}|#[^#\s，。！？、；：""''《》（）【】]{2,15}#)/g;

export function parseHighlightSegments(text: string): HighlightSegment[] {
  const segs: HighlightSegment[] = [];
  let last = 0;
  HIGHLIGHT_RE.lastIndex = 0;
  let m: RegExpExecArray | null;
  while ((m = HIGHLIGHT_RE.exec(text)) !== null) {
    if (m.index > last) {
      segs.push({ type: 'text', raw: text.slice(last, m.index), name: '' });
    }
    const raw = m[0];
    if (raw.startsWith('@')) {
      segs.push({ type: 'mention', raw: raw, name: raw.slice(1) });
    } else {
      segs.push({ type: 'tag', raw: raw, name: raw.slice(1, -1) });
    }
    last = m.index + raw.length;
  }
  if (last < text.length) {
    segs.push({ type: 'text', raw: text.slice(last), name: '' });
  }
  return segs;
}