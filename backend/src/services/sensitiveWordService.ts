// 敏感词检测服务（单例，Aho-Corasick 多模式匹配）。
// 词库在启动时构建为自动机，运行时无需 IO，单次扫描复杂度为 O(n)。
import * as fs from 'fs';
import * as path from 'path';

interface AutomatonNode {
  children: Map<string, number>;
  fail: number;
  terminal: boolean;
}

const ZERO_WIDTH_RE = /[\u0000-\u001f\u007f\u00ad\u034f\u061c\u180e\u200b-\u200f\u202a-\u202e\u2060-\u2064\u2066-\u206f\uFE00-\uFE0F\uFEFF]/u;
const LETTER_OR_NUMBER_RE = /[\p{L}\p{N}]/u;

// 常见的拉丁字母/数字替换写法。只做低风险的 ASCII 归一化，中文词条不会被改变。
const HOMOGLYPH_MAP: ReadonlyMap<string, string> = new Map([
  ['@', 'a'], ['4', 'a'],
  ['0', 'o'],
  ['1', 'i'], ['!', 'i'], ['|', 'i'],
  ['3', 'e'],
  ['5', 's'], ['$', 's'],
  ['7', 't'],
]);

class SensitiveWordService {
  private nodes: AutomatonNode[] = [this.createNode()];
  private loaded: boolean = false;
  private wordCount: number = 0;

  private createNode(): AutomatonNode {
    return { children: new Map<string, number>(), fail: 0, terminal: false };
  }

  /**
   * 从多个词库文件加载敏感词并构建自动机。
   * filePaths 为相对于 process.cwd()（即 backend/目录）的路径数组。
   * 文件不存在时告警并继续加载其他文件；如果全部缺失则安全降级为空词库。
   */
  loadFromFiles(filePaths: string[]): void {
    const wordSet = new Set<string>();

    for (const fp of filePaths) {
      const absPath = path.resolve(process.cwd(), fp);
      try {
        const content = fs.readFileSync(absPath, 'utf-8');
        for (const line of content.split(/\r?\n/u)) {
          const raw = line.trim();
          if (raw.length === 0 || raw.startsWith('#')) {
            continue;
          }
          const word = this.normalizeWord(raw);
          if (word.length > 0) {
            wordSet.add(word);
          }
        }
      } catch (e) {
        console.warn(`[SensitiveWordService] 词库文件加载失败: ${fp}`);
      }
    }

    this.build(wordSet);
    console.log(`[SensitiveWordService] 词库加载完成，共 ${this.wordCount} 个敏感词`);
  }

  /** 直接传入词数组构建自动机（供测试和管理端热更新使用）。 */
  loadWords(words: string[]): void {
    const wordSet = new Set<string>();
    for (const raw of words) {
      const word = this.normalizeWord(raw);
      if (word.length > 0) {
        wordSet.add(word);
      }
    }
    this.build(wordSet);
  }

  private build(words: Set<string>): void {
    this.nodes = [this.createNode()];
    this.wordCount = words.size;

    for (const word of words) {
      this.insert(word);
      const compact = this.compact(word);
      if (compact.length > 0 && compact !== word) {
        this.insert(compact);
      }
    }
    this.buildFailureLinks();
    this.loaded = true;
  }

  /** Unicode 兼容归一化 + 去除不可见字符 + 常见 ASCII 替换归一化。 */
  private normalizeWord(value: string): string {
    return this.normalize(value.trim());
  }

  private normalize(value: string): string {
    let result = '';
    // NFKD 可将全角字符折叠为半角，并允许下面的组合音标清理。
    const normalized = value.normalize('NFKD').toLowerCase();
    for (const ch of normalized) {
      if (ZERO_WIDTH_RE.test(ch) || /\p{M}/u.test(ch)) {
        continue;
      }
      result += HOMOGLYPH_MAP.get(ch) ?? ch;
    }
    return result;
  }

  /** 去除空格、标点和符号，用于识别“敏 感 词”“敏-感-词”等分隔符绕过。 */
  private compact(value: string): string {
    let result = '';
    for (const ch of value) {
      if (LETTER_OR_NUMBER_RE.test(ch)) {
        result += ch;
      }
    }
    return result;
  }

  private insert(word: string): void {
    let nodeIndex = 0;
    for (const ch of word) {
      const existing = this.nodes[nodeIndex].children.get(ch);
      if (existing !== undefined) {
        nodeIndex = existing;
        continue;
      }
      const childIndex = this.nodes.length;
      this.nodes.push(this.createNode());
      this.nodes[nodeIndex].children.set(ch, childIndex);
      nodeIndex = childIndex;
    }
    this.nodes[nodeIndex].terminal = true;
  }

  private buildFailureLinks(): void {
    const queue: number[] = [];
    for (const childIndex of this.nodes[0].children.values()) {
      this.nodes[childIndex].fail = 0;
      queue.push(childIndex);
    }

    let cursor = 0;
    while (cursor < queue.length) {
      const nodeIndex = queue[cursor++];
      const node = this.nodes[nodeIndex];
      for (const [ch, childIndex] of node.children) {
        let fallback = node.fail;
        while (fallback !== 0 && !this.nodes[fallback].children.has(ch)) {
          fallback = this.nodes[fallback].fail;
        }
        const fallbackChild = this.nodes[fallback].children.get(ch);
        if (fallbackChild !== undefined && fallbackChild !== childIndex) {
          this.nodes[childIndex].fail = fallbackChild;
        } else {
          this.nodes[childIndex].fail = 0;
        }
        this.nodes[childIndex].terminal = this.nodes[childIndex].terminal
          || this.nodes[this.nodes[childIndex].fail].terminal;
        queue.push(childIndex);
      }
    }
  }

  private scan(text: string): boolean {
    let nodeIndex = 0;
    for (const ch of text) {
      while (nodeIndex !== 0 && !this.nodes[nodeIndex].children.has(ch)) {
        nodeIndex = this.nodes[nodeIndex].fail;
      }
      const next = this.nodes[nodeIndex].children.get(ch);
      nodeIndex = next === undefined ? 0 : next;
      if (this.nodes[nodeIndex].terminal) {
        return true;
      }
    }
    return false;
  }

  /**
   * 检测文本是否包含任意敏感词。
   * 同时扫描原始归一化文本和去分隔符文本，避免常见变形绕过。
   * 返回 true=命中，false=未命中；不暴露具体命中词。
   */
  checkText(text: string): boolean {
    if (!text || text.length === 0 || this.wordCount === 0) {
      return false;
    }
    const normalized = this.normalize(text);
    if (normalized.length === 0) {
      return false;
    }
    if (this.scan(normalized)) {
      return true;
    }
    const compact = this.compact(normalized);
    return compact !== normalized && compact.length > 0 && this.scan(compact);
  }

  isLoaded(): boolean {
    return this.loaded;
  }
}

export const sensitiveWordService = new SensitiveWordService();
