// 剪贴板帖子链接识别：「复制打开有据」分享链路的落地侧。
// 只负责「读剪贴板 → 提取 youju.chat/post/{id} → 会话内节流与去重」，不做跳转；
// 是否打开由用户在确认面板上决定（不静默跳转）。30s 节流避免每次回前台
// 都触发系统的「读取剪贴板」提示骚扰用户。
import pasteboard from '@ohos.pasteboard';

const CHECK_THROTTLE_MS: number = 30 * 1000;

let lastCheckAt: number = 0;
// 本会话已处理（已提示 / 已打开 / 拉取失败）的帖子 id：同一链接不再重复打扰
const handledIds: number[] = [];

// 从任意文本（抖音式分享文案 / 裸链接）中提取有据帖子链接的 id；无匹配返回 0
export function extractPostIdFromText(text: string): number {
  const m: RegExpMatchArray | null = text.match(/youju\.chat\/post\/(\d+)/);
  if (m === null || m.length < 2) {
    return 0;
  }
  const id: number = parseInt(m[1], 10);
  return isNaN(id) ? 0 : id;
}

// 读剪贴板并提取待打开的帖子 id。节流窗口内 / 剪贴板为空 / 无链接 / 已处理过 → 返回 0。
export async function readClipboardPostId(): Promise<number> {
  const now: number = Date.now();
  if (now - lastCheckAt < CHECK_THROTTLE_MS) {
    return 0;
  }
  lastCheckAt = now;
  let text: string = '';
  try {
    const data: pasteboard.PasteData = await pasteboard.getSystemPasteboard().getData();
    text = data.getPrimaryText();
  } catch (e) {
    return 0;
  }
  if (text.length === 0) {
    return 0;
  }
  const id: number = extractPostIdFromText(text);
  if (id <= 0 || handledIds.indexOf(id) >= 0) {
    return 0;
  }
  return id;
}

// 标记某帖子 id 本会话不再提示（幂等）。应用内「复制链接」成功后也调用，
// 避免自己复制完、回前台时又被提示打开自己刚复制的帖子。
export function markClipboardIdHandled(id: number): void {
  if (id > 0 && handledIds.indexOf(id) < 0) {
    handledIds.push(id);
  }
}
