// @提及 编辑辅助：检测输入中的“进行中 @提及”并做选择回填
// 与后端 MENTION_RE / 前端 textHighlight 同口径：@ 后允许昵称字符为除
// 「@、空白与常见中英标点」以外的任意字符（1..20 位，后端要求 2-20，选择面板允许 0 位以支持联想）。
// 检测策略：取全文最后一个 '@'，其后的“词尾”只含合法昵称字符时视为进行中提及
// （即用户正在把 @昵称 输入在光标处/文末），此时弹出候选列表。

// 昵称终止符集合（命中即认为 @ 提及不完整/结束）
const MENTION_TERMINATORS: string = `@ \n\t，。！？、；：""''《》（）【】`;
const MAX_MENTION_KEYWORD_LENGTH: number = 20;

export interface AtMentionMatch {
  atIndex: number; // '@' 所在下标
  keyword: string; // '@' 之后已输入的昵称片段（可为空）
}

// 无进行中 @提及时返回 null
export function findActiveAtMention(text: string): AtMentionMatch | null {
  if (text === null || text.length === 0) {
    return null;
  }
  const at: number = text.lastIndexOf('@');
  if (at < 0) {
    return null;
  }
  const tail: string = text.slice(at + 1);
  if (tail.length > MAX_MENTION_KEYWORD_LENGTH) {
    return null;
  }
  for (let i = 0; i < tail.length; i++) {
    if (MENTION_TERMINATORS.indexOf(tail.charAt(i)) >= 0) {
      return null;
    }
  }
  const match: AtMentionMatch = { atIndex: at, keyword: tail };
  return match;
}

// 点选候选后回填：保留 '@' 前内容，替换 '@ 之后的待定片段为「@昵称 」
export function applyAtMention(text: string, atIndex: number, nickname: string): string {
  if (atIndex < 0) {
    return text + '@' + nickname + ' ';
  }
  return text.slice(0, atIndex) + '@' + nickname + ' ';
}
