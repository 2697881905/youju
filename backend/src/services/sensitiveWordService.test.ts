// 敏感词服务单元测试：Trie 树 checkText 命中/未命中
import { sensitiveWordService } from './sensitiveWordService';

describe('sensitiveWordService - Trie 检测', () => {
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
    expect(sensitiveWordService.checkText('大蓝书 HarmonyOS')).toBe(false);
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

  it('isLoaded 在 loadWords 后为 true', () => {
    expect(sensitiveWordService.isLoaded()).toBe(true);
  });
});
