export function formatCount(n?: number): string {
  if (!n) {
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
  const diff = Date.now() - new Date(iso).getTime();
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
