// 剪贴板帖子链接识别：「复制打开有据」分享链路的落地侧。
// 只负责「读剪贴板 → 提取 youju.chat/post/{id} → 会话内节流与去重」，不做跳转；
// 是否打开由用户在确认面板上决定（不静默跳转）。30s 节流避免每次回前台
// 都触发系统的「读取剪贴板」提示骚扰用户。
import pasteboard from '@ohos.pasteboard';
import { abilityAccessCtrl, bundleManager, common, PermissionRequestResult, Permissions } from '@kit.AbilityKit';

const CHECK_THROTTLE_MS: number = 30 * 1000;
const PASTEBOARD_PERMISSION: Permissions = 'ohos.permission.READ_PASTEBOARD';

let lastCheckAt: number = 0;
// 本会话已处理（已提示 / 已打开 / 拉取失败）的帖子 id：同一链接不再重复打扰
const handledIds: number[] = [];

// API12 起后台读剪贴板需 READ_PASTEBOARD（user_grant，module.json5 已声明）。
// 已授权直读过；未授权先走一次系统授权弹窗。拒绝后系统会记忆选择，
// 后续 request 不再弹窗、getData 返回 201 —— 由调用方静默降级，功能自动失效。
async function ensurePasteboardReadPermission(ctx: common.UIAbilityContext): Promise<boolean> {
  const atManager: abilityAccessCtrl.AtManager = abilityAccessCtrl.createAtManager();
  try {
    const bundleInfo: bundleManager.BundleInfo = await bundleManager.getBundleInfoForSelf(
      bundleManager.BundleFlag.GET_BUNDLE_INFO_WITH_APPLICATION);
    const status: abilityAccessCtrl.GrantStatus = await atManager.checkAccessToken(
      bundleInfo.appInfo.accessTokenId, PASTEBOARD_PERMISSION);
    if (status === abilityAccessCtrl.GrantStatus.PERMISSION_GRANTED) {
      return true;
    }
  } catch (e) {
    // 查询失败不阻断：继续尝试走申请弹窗
  }
  try {
    // PermissionRequestResult 是 @ohos.abilityAccessCtrl 的顶层类型导出（非命名空间成员）
    const result: PermissionRequestResult = await atManager.requestPermissionsFromUser(
      ctx, [PASTEBOARD_PERMISSION]);
    return result.authResults.length > 0 && result.authResults[0] === abilityAccessCtrl.GrantStatus.PERMISSION_GRANTED;
  } catch (e) {
    return false;
  }
}

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
export async function readClipboardPostId(ctx: common.UIAbilityContext): Promise<number> {
  const now: number = Date.now();
  if (now - lastCheckAt < CHECK_THROTTLE_MS) {
    return 0;
  }
  lastCheckAt = now;
  const granted: boolean = await ensurePasteboardReadPermission(ctx);
  if (!granted) {
    return 0;
  }
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
