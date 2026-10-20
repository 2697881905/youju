// 去 AI 味的机器检查。
//
// 规则来自 human-writing 的硬禁令，加上这个产品自己的语气要求。分两级：
//   hard —— 命中就不能写库（机械句式、商业黑话、冒号破折号）
//   warn —— 只是提醒，可能合理（「其实」「确实」密度、破折号式顿号）
//
// 这里只管「能正则化的那一半」。三段式排比、所有段落同一个骨架、假的精确数据
// 这三样机器测不准，靠人工抽读，规则写在方案文档里。

export type ViolationSeverity = 'hard' | 'warn';

export interface StyleViolation {
  rule: string;
  severity: ViolationSeverity;
  match: string;
  index: number;
}

interface Rule {
  name: string;
  severity: ViolationSeverity;
  pattern: RegExp;
}

// 冒号单独处理：既要挡正文里的「结论：」，又不能误伤时间写法和英文缩写。
// 产品里没有代码块，所以直接全挡，写稿时改写成「十点半」「四比三」这种口语。
const HARD_RULES: Rule[] = [
  { name: '中文冒号', severity: 'hard', pattern: /：/g },
  { name: '英文冒号', severity: 'hard', pattern: /:/g },
  { name: '破折号', severity: 'hard', pattern: /—|——|–/g },
  { name: '翻案句-不是而是', severity: 'hard', pattern: /不是[^。！？\n]{0,14}而是/g },
  { name: '翻案句-并非而是', severity: 'hard', pattern: /并非[^。！？\n]{0,14}而是/g },
  { name: '翻案句-与其说', severity: 'hard', pattern: /与其说[^。！？\n]{0,14}不如说/g },
  { name: '翻案句-看似实则', severity: 'hard', pattern: /看似[^。！？\n]{0,14}实则/g },
  { name: '翻案句-不只还', severity: 'hard', pattern: /不只[^。！？\n]{0,10}还/g },
  { name: '路标词-首先', severity: 'hard', pattern: /首先[，,]/g },
  { name: '路标词-其次', severity: 'hard', pattern: /其次[，,]/g },
  { name: '路标词-总之', severity: 'hard', pattern: /总之|综上|由此可见|不难发现/g },
  { name: '路标词-值得注意', severity: 'hard', pattern: /值得注意|需要指出|值得一提的是/g },
  { name: '路标词-换句话说', severity: 'hard', pattern: /换句话说|简单来说|说白了|说到底|归根结底/g },
  { name: '黑话-商业', severity: 'hard', pattern: /赋能|闭环|抓手|深耕|打造|极致|一站式|全方位|焕新|颗粒度|底层逻辑|方法论|价值锚点|认知升级/g },
  { name: '套话-升华', severity: 'hard', pattern: /让我们一起|让我们共同|愿每一个|致敬每一个|在这个[^。！？\n]{0,8}的时代/g },
];

const WARN_RULES: Rule[] = [
  // 「其实」「确实」「真的」按出现频次判定，见 densityWarnings，不在这里逐次报
  { name: '程度词堆叠', severity: 'warn', pattern: /非常|十分(?!钟|分|之)|极其|格外/g },
  { name: '括号补充过多', severity: 'warn', pattern: /（[^）]{0,30}）/g },
  { name: '感叹号', severity: 'warn', pattern: /！/g },
  { name: '省略号', severity: 'warn', pattern: /\.\.\.|……/g },
];

const ALL_RULES: Rule[] = HARD_RULES.concat(WARN_RULES);

export function findStyleViolations(text: string): StyleViolation[] {
  const out: StyleViolation[] = [];
  if (typeof text !== 'string' || text.length === 0) return out;
  for (const rule of ALL_RULES) {
    const pattern = new RegExp(rule.pattern.source, rule.pattern.flags);
    let match = pattern.exec(text);
    while (match !== null) {
      out.push({ rule: rule.name, severity: rule.severity, match: match[0], index: match.index });
      if (match.index === pattern.lastIndex) pattern.lastIndex += 1;
      match = pattern.exec(text);
    }
  }
  return out;
}

/**
 * 密度类警告单独判定：单帖出现一两次「其实」是正常口语，
 * 一篇 300 字里出现五次才是模型腔。所以先收集次数，再按长度折算。
 */
export function densityWarnings(text: string): StyleViolation[] {
  const out: StyleViolation[] = [];
  const length = Math.max(1, text.length);
  const buckets: Array<{ rule: string; pattern: RegExp; per: number }> = [
    { rule: '虚词密度-其实', pattern: /其实/g, per: 260 },
    { rule: '虚词密度-确实', pattern: /确实/g, per: 260 },
    { rule: '虚词密度-真的', pattern: /真的/g, per: 260 },
  ];
  for (const bucket of buckets) {
    const matches = text.match(bucket.pattern);
    const count = matches ? matches.length : 0;
    const allowed = Math.max(1, Math.floor(length / bucket.per));
    if (count > allowed) {
      out.push({ rule: bucket.rule, severity: 'warn', match: `${count} 次`, index: 0 });
    }
  }
  return out;
}

/** 句长标准差。低于阈值说明每句都差不多长，读起来是机器在换气。 */
export function sentenceLengthSpread(text: string): { count: number; stdDev: number } {
  const sentences = text
    .split(/[。！？\n]+/)
    .map((s) => s.trim())
    .filter((s) => s.length > 0);
  if (sentences.length < 3) return { count: sentences.length, stdDev: 99 };
  const lengths = sentences.map((s) => s.length);
  const mean = lengths.reduce((a, b) => a + b, 0) / lengths.length;
  const variance = lengths.reduce((sum, n) => sum + (n - mean) ** 2, 0) / lengths.length;
  return { count: sentences.length, stdDev: Math.sqrt(variance) };
}
