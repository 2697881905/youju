// 敏感词服务单元测试：Aho-Corasick checkText 命中/未命中
import * as fs from 'fs';
import * as path from 'path';
import { sensitiveWordService } from './sensitiveWordService';

describe('sensitiveWordService - Aho-Corasick 检测', () => {
  beforeAll(() => {
    // 直接加载词数组（不走文件），避免依赖词库文件
    sensitiveWordService.loadWords(['色情', '赌博', 'gender_war', '诈骗']);
  });

  it('命中敏感词返回 true', () => {
    expect(sensitiveWordService.checkText('这是一条色情内容')).toBe(true);
    expect(sensitiveWordService.checkText('网上赌博平台')).toBe(true);
    expect(sensitiveWordService.checkText('gender_war test')).toBe(true);
    expect(sensitiveWordService.checkText('电信诈骗')).toBe(true);
  });

  it('未命中敏感词返回 false', () => {
    expect(sensitiveWordService.checkText('这是一条正常内容')).toBe(false);
    expect(sensitiveWordService.checkText('有据 HarmonyOS')).toBe(false);
    expect(sensitiveWordService.checkText('')).toBe(false);
  });

  it('大小写不敏感（统一转小写匹配）', () => {
    expect(sensitiveWordService.checkText('GENDER_WAR')).toBe(true);
    expect(sensitiveWordService.checkText('Gender_War')).toBe(true);
  });

  it('敏感词作为子串也能命中', () => {
    expect(sensitiveWordService.checkText('aaaa色情bbbb')).toBe(true);
    expect(sensitiveWordService.checkText('去赌博吧')).toBe(true);
  });

  it('兼容全角字符、零宽字符和分隔符绕过', () => {
    expect(sensitiveWordService.checkText('色\u200b情')).toBe(true);
    expect(sensitiveWordService.checkText('色-情')).toBe(true);
    expect(sensitiveWordService.checkText('ＧＥＮＤＥＲ＿ＷＡＲ')).toBe(true);
  });

  it('兼容常见字母数字替换写法', () => {
    sensitiveWordService.loadWords(['scam', '色情']);
    expect(sensitiveWordService.checkText('sc@ m')).toBe(true);
    expect(sensitiveWordService.checkText('色 情')).toBe(true);
  });

  it('Aho-Corasick 能识别共享前缀和后缀词', () => {
    sensitiveWordService.loadWords(['he', 'she', 'hers', 'his']);
    expect(sensitiveWordService.checkText('ushers')).toBe(true);
    expect(sensitiveWordService.checkText('历史记录')).toBe(false);
  });

  it('内置词库已覆盖主要场景且规模达标', () => {
    const generalPath = path.resolve(__dirname, '../../data/sensitive-words.txt');
    const genderPath = path.resolve(__dirname, '../../data/gender-war-words.txt');
    const readWords = (filePath: string): string[] => fs.readFileSync(filePath, 'utf-8')
      .split(/\r?\n/u)
      .map((line: string) => line.trim())
      .filter((line: string) => line.length > 0 && !line.startsWith('#'));
    const generalWords = readWords(generalPath);
    const genderWords = readWords(genderPath);

    expect(generalWords.length).toBeGreaterThanOrEqual(450);
    expect(genderWords.length).toBeGreaterThanOrEqual(80);
    sensitiveWordService.loadFromFiles(['data/sensitive-words.txt', 'data/gender-war-words.txt']);
    expect(sensitiveWordService.checkText('请勿参与网络刷单诈骗')).toBe(true);
    expect(sensitiveWordService.checkText('这是一篇正常的学习经验分享')).toBe(false);
  });

  it('词库加载后 isLoaded 为 true', () => {
    expect(sensitiveWordService.isLoaded()).toBe(true);
  });
});
