function addText(out: string[], value: unknown): void {
  if (typeof value !== 'string') return;
  const text = value.trim();
  if (text.length === 0 || out.includes(text)) return;
  out.push(text);
}

// 将高信号结构化内容收敛到独立检索列，避免依赖数据库 JSON 路径方言。
export function buildStructuredSearchText(document: unknown, legacyData: unknown): string | null {
  const out: string[] = [];
  if (typeof document === 'object' && document !== null && !Array.isArray(document)) {
    const doc = document as Record<string, unknown>;
    if (Array.isArray(doc.blocks)) {
      for (const raw of doc.blocks) {
        if (typeof raw !== 'object' || raw === null || Array.isArray(raw)) continue;
        const block = raw as Record<string, unknown>;
        addText(out, block.title);
        addText(out, block.value);
        addText(out, block.unit);
        addText(out, block.helper);
        addText(out, block.leftLabel);
        addText(out, block.leftValue);
        addText(out, block.rightLabel);
        addText(out, block.rightValue);
        if (Array.isArray(block.items)) {
          for (const item of block.items) addText(out, item);
        }
      }
    }
  }
  if (typeof legacyData === 'object' && legacyData !== null && !Array.isArray(legacyData)) {
    const legacy = legacyData as Record<string, unknown>;
    for (const key of ['pros', 'cons', 'rating', 'targetAudience', 'pitfallExperience', 'lossAmount',
      'correctApproach', 'tools', 'steps', 'timeDifficulty', 'planA', 'planB']) {
      const value = legacy[key];
      if (typeof value === 'number') addText(out, String(value));
      else addText(out, value);
    }
  }
  if (out.length === 0) return null;
  return out.join(' ').slice(0, 8000);
}
