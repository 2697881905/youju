import { extractMentionNames } from './notificationService';

describe('extractMentionNames（评论 @提及 解析）', () => {
  it('提取合法 @昵称（2-20 字）', () => {
    expect(extractMentionNames('谢谢 @张三 提醒')).toEqual(['张三']);
    expect(extractMentionNames('@李四 @王五 都在')).toEqual(['李四', '王五']);
  });

  it('去重且保留首次顺序', () => {
    expect(extractMentionNames('@张三 好，@张三 再来说')).toEqual(['张三']);
  });

  it('长度不足 / 含标点 / 锚点符号等不命中', () => {
    expect(extractMentionNames('@a 太短')).toEqual([]);
    expect(extractMentionNames('@张三。')).toEqual(['张三']); // 标点前正常截断
    expect(extractMentionNames('@三')).toEqual([]); // 单字不命中
    expect(extractMentionNames('@@ 双锚点')).toEqual([]); // 连续 @' 无合法昵称
    expect(extractMentionNames('@ 空格后')).toEqual([]); // @后无紧邻字符
  });

  it('空串与纯文本返回空', () => {
    expect(extractMentionNames('')).toEqual([]);
    expect(extractMentionNames('没有提及')).toEqual([]);
  });
});