export function formatCount(n?: number): string {
  if (!n || !isFinite(n)) {
    // undefined/0/NaN/Infinity 统一按 0 处理，避免出现 "Infinityw" 类异常文案
    return '0';
  }
  if (n >= 10000) {
    return (n / 10000).toFixed(1) + 'w';
  }
  return n.toString();
}

export function timeAgo(iso?: string): string {
  if (!iso) {
    return '';
  }
  // 无效日期字符串（格式异常/被截断）→ NaN，返回空串而非 "Invalid Date"
  const t: number = new Date(iso).getTime();
  if (Number.isNaN(t)) {
    return '';
  }
  const diff: number = Date.now() - t;
  const m = Math.floor(diff / 60000);
  if (m < 1) {
    return '刚刚';
  }
  if (m < 60) {
    return m + '分钟前';
  }
  const h = Math.floor(m / 60);
  if (h < 24) {
    return h + '小时前';
  }
  const d = Math.floor(h / 24);
  if (d < 30) {
    return d + '天前';
  }
  return new Date(iso).toLocaleDateString();
}
