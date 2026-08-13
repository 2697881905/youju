// 分享工具（占位实现）
// 说明：当前线上域名尚未确定（上线阻塞项之一），SHARE_BASE 为占位值。
// 待真实生产域名确定后，仅需修改 SHARE_BASE 一处即可全局生效，无需改调用点。
import pasteboard from '@ohos.pasteboard';

// TODO(上线): 替换为真实生产域名（域名确定后改这一行即可）
const SHARE_BASE: string = 'https://youju.app';

// 帖子分享链接：占位域名 + /post/{id}
export function buildPostShareUrl(postId: number): string {
  return SHARE_BASE + '/post/' + String(postId);
}

// 个人主页分享链接：占位域名 + /user/{id}
export function buildProfileShareUrl(userId: number): string {
  return SHARE_BASE + '/user/' + String(userId);
}

// 分享文案（标题 + 链接），用于系统分享面板接入后使用
export function buildShareText(title: string, postId: number): string {
  const t: string = title && title.length > 0 ? title : '有据帖子';
  return t + ' ' + buildPostShareUrl(postId);
}

export function buildProfileShareText(nickname: string, userId: number): string {
  const name: string = nickname && nickname.length > 0 ? nickname : '有据用户';
  return '来有据看看 ' + name + ' 的个人主页 ' + buildProfileShareUrl(userId);
}

// 复制文本到系统剪贴板；失败抛出，由调用方 toast 兜底
export function copyToClipboard(text: string): void {
  const pb = pasteboard.getSystemPasteboard();
  pb.setData(pasteboard.createPlainTextData(text));
}
