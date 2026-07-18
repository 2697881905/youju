// 敏感词检测服务（单例，Trie 树实现）
// 启动时从词库文件加载到内存，后续请求直接调用 checkText()，无 IO 开销。
import * as fs from 'fs';
import * as path from 'path';

// Trie 节点
interface TrieNode {
  children: Map<string, TrieNode>;
  isEnd: boolean;
}

class SensitiveWordService {
  private root: TrieNode;
  private loaded: boolean;

  constructor() {
    this.root = { children: new Map(), isEnd: false };
    this.loaded = false;
  }

  /**
   * 从多个词库文件加载敏感词并构建 Trie 树。
   * filePaths 为相对于 process.cwd()（即 backend/ 目录）的路径数组。
   * 文件不存在时日志告警但不崩溃（降级为空词库，不拦截）。
   */
  loadFromFiles(filePaths: string[]): void {
    // 重置 Trie，避免重复加载导致旧词残留
    this.root = { children: new Map(), isEnd: false };
    const wordSet = new Set<string>();

    for (const fp of filePaths) {
      const absPath = path.resolve(process.cwd(), fp);
      try {
        const content = fs.readFileSync(absPath, 'utf-8');
        const lines = content.split('\n');
        for (const line of lines) {
          const word = line.trim().toLowerCase();
          if (word.length > 0) {
            wordSet.add(word);
          }
        }
      } catch (e) {
        console.warn(`[SensitiveWordService] 词库文件加载失败: ${fp}，降级为空词库`);
      }
    }

    for (const word of wordSet) {
      this.insert(word);
    }

    this.loaded = true;
    console.log(`[SensitiveWordService] 词库加载完成，共 ${wordSet.size} 个敏感词`);
  }

  /**
   * 直接传入词数组构建 Trie（供测试使用）。
   */
  loadWords(words: string[]): void {
    this.root = { children: new Map(), isEnd: false };
    const wordSet = new Set<string>();
    for (const w of words) {
      const word = w.trim().toLowerCase();
      if (word.length > 0) {
        wordSet.add(word);
      }
    }
    for (const word of wordSet) {
      this.insert(word);
    }
    this.loaded = true;
  }

  // 向 Trie 插入单个词（已转小写）
  private insert(word: string): void {
    let node = this.root;
    for (const ch of word) {
      const child = node.children.get(ch);
      if (child) {
        node = child;
      } else {
        const newNode: TrieNode = { children: new Map(), isEnd: false };
        node.children.set(ch, newNode);
        node = newNode;
      }
    }
    node.isEnd = true;
  }

  /**
   * 检测文本是否包含任意敏感词。
   * 返回 true=命中 false=未命中（不暴露具体命中词）。
   * 算法：遍历每个起始位置 i，沿 Trie 向下匹配，任一节点 isEnd=true 即命中。
   */
  checkText(text: string): boolean {
    if (!text || text.length === 0) {
      return false;
    }
    const lower = text.toLowerCase();
    const len = lower.length;

    for (let i = 0; i < len; i++) {
      let node = this.root;
      for (let j = i; j < len; j++) {
        const ch = lower[j];
        const child = node.children.get(ch);
        if (!child) {
          break;
        }
        node = child;
        if (node.isEnd) {
          return true;
        }
      }
    }
    return false;
  }

  isLoaded(): boolean {
    return this.loaded;
  }
}

// 全局单例
export const sensitiveWordService = new SensitiveWordService();
