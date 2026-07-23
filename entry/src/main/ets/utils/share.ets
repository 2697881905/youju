// 分享工具（占位实现）
// 说明：当前线上域名尚未确定（上线阻塞项之一），SHARE_BASE 为占位值。
// 待真实生产域名确定后，仅需修改 SHARE_BASE 一处即可全局生效，无需改调用点。
import pasteboard from '@ohos.pasteboard';

// TODO(上线): 替换为真实生产域名（域名确定后改这一行即可）
const SHARE_BASE: string = 'https://bigbluebook.app';

// 帖子分享链接：占位域名 + /post/{id}
export function buildPostShareUrl(postId: number): string {
  return SHARE_BASE + '/post/' + String(postId);
}

// 分享文案（标题 + 链接），用于系统分享面板接入后使用
export function buildShareText(title: string, postId: number): string {
  const t: string = title && title.length > 0 ? title : '大蓝书帖子';
  return t + ' ' + buildPostShareUrl(postId);
}

// 复制文本到系统剪贴板；失败抛出，由调用方 toast 兜底
export function copyToClipboard(text: string): void {
  const pb = pasteboard.getSystemPasteboard();
  pb.setData(pasteboard.createPlainTextData(text));
}
