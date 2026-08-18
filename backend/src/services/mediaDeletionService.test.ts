import { mediaKeysFromValues } from './mediaDeletionService';

describe('mediaKeysFromValues', () => {
  it('只提取受控 cos 引用并去重', () => {
    expect(mediaKeysFromValues([
      'cos://posts/2026/08/a',
      ['cos://avatars/2026/08/b', 'cos://posts/2026/08/a'],
      'https://legacy.example/image.jpg',
      'cos://posts/../unsafe',
    ])).toEqual(['posts/2026/08/a', 'avatars/2026/08/b']);
  });
});
