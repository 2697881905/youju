import { normalizeMediaRefInput } from './mediaRef';

describe('normalizeMediaRefInput', () => {
  it('accepts canonical COS media refs', () => {
    const r = normalizeMediaRefInput('cos://posts/2026/01/9f1c3b2e-1111-4222-8333-444455556666');
    expect(r.ok).toBe(true);
    expect(r.ref).toBe('cos://posts/2026/01/9f1c3b2e-1111-4222-8333-444455556666');
  });

  it('rejects COS refs with path traversal or unknown folders', () => {
    expect(normalizeMediaRefInput('cos://posts/2026/01/..%2f..%2fetc').ok).toBe(false);
    expect(normalizeMediaRefInput('cos://evil/2026/01/9f1c3b2e-1111-4222-8333-444455556666').ok).toBe(false);
    expect(normalizeMediaRefInput('cos://').ok).toBe(false);
  });

  it('accepts /uploads/ paths and rewrites LAN-host absolute URLs to relative', () => {
    expect(normalizeMediaRefInput('/uploads/avatars/2026/01/abc.jpg').ok).toBe(true);
    const r = normalizeMediaRefInput('http://192.168.1.100:3000/uploads/avatars/2026/01/abc.jpg');
    expect(r.ok).toBe(true);
    expect(r.ref).toBe('/uploads/avatars/2026/01/abc.jpg');
    const lan = normalizeMediaRefInput('http://10.0.2.2:3000/uploads/posts/2026/02/x.png');
    expect(lan.ok).toBe(true);
    expect(lan.ref).toBe('/uploads/posts/2026/02/x.png');
  });

  it('rejects external links and non-string input (tracking pixel vector)', () => {
    expect(normalizeMediaRefInput('https://attacker.com/pixel?uid=1').ok).toBe(false);
    // 公网主机的 /uploads/ 路径 = 伪造外链（本地模式只可能来自 localhost/局域网）
    expect(normalizeMediaRefInput('https://evil.com/uploads/x.png').ok).toBe(false);
    expect(normalizeMediaRefInput('https://api.youju.chat/uploads/x.png').ok).toBe(false);
    expect(normalizeMediaRefInput('data:image/png;base64,AAAA').ok).toBe(false);
    expect(normalizeMediaRefInput('javascript:alert(1)').ok).toBe(false);
    expect(normalizeMediaRefInput(42).ok).toBe(false);
    expect(normalizeMediaRefInput('').ok).toBe(false);
  });

  it('rejects uploads paths with traversal', () => {
    expect(normalizeMediaRefInput('/uploads/../secrets.json').ok).toBe(false);
  });
});
