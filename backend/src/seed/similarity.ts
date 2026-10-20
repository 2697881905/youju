// 近似查重：把文本压成 3-gram 集合算 Jaccard。
//
// 造 300 多条帖子，最容易出的问题是「同一个意思换个说法写两遍」——单看每一篇都通顺，
// 放在一个圈子里就是复制粘贴。用字符级 3-gram 而不是词级，是因为中文没有空格，
// 而且这类重复往往连词序都差不多。

const PUNCTUATION = /[\s，。！？、；：「」“”‘’（）【】《》…—\-~·,.!?;:'"()\[\]<>]/g;

export function normalizeForSimilarity(text: string): string {
  return String(text ?? '').replace(PUNCTUATION, '');
}

export function trigramSet(text: string): Set<string> {
  const normalized = normalizeForSimilarity(text);
  const grams = new Set<string>();
  if (normalized.length < 3) {
    if (normalized.length > 0) grams.add(normalized);
    return grams;
  }
  for (let i = 0; i <= normalized.length - 3; i += 1) {
    grams.add(normalized.slice(i, i + 3));
  }
  return grams;
}

export function jaccard(a: Set<string>, b: Set<string>): number {
  if (a.size === 0 || b.size === 0) return 0;
  let intersection = 0;
  const [small, large] = a.size <= b.size ? [a, b] : [b, a];
  for (const item of small) {
    if (large.has(item)) intersection += 1;
  }
  return intersection / (a.size + b.size - intersection);
}

export interface SimilarityHit {
  leftId: string;
  rightId: string;
  score: number;
  severity: 'hard' | 'warn';
}

export const SIMILARITY_HARD = 0.55;
export const SIMILARITY_WARN = 0.4;

/**
 * 全库两两比对。331 条帖子就是 5 万多次比较，每次几百个 gram，
 * 跑一次秒级，不值得上更复杂的索引。
 */
export function findSimilarPairs(
  items: Array<{ id: string; text: string }>,
): SimilarityHit[] {
  const sets = items.map((item) => ({ id: item.id, grams: trigramSet(item.text) }));
  const hits: SimilarityHit[] = [];
  for (let i = 0; i < sets.length; i += 1) {
    for (let j = i + 1; j < sets.length; j += 1) {
      const score = jaccard(sets[i].grams, sets[j].grams);
      if (score >= SIMILARITY_WARN) {
        hits.push({
          leftId: sets[i].id,
          rightId: sets[j].id,
          score: Number(score.toFixed(3)),
          severity: score >= SIMILARITY_HARD ? 'hard' : 'warn',
        });
      }
    }
  }
  return hits.sort((a, b) => b.score - a.score);
}
